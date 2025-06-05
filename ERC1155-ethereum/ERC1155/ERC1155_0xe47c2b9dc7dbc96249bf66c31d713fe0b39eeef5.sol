// File: packages/contracts/lib/closedsea/src/OperatorFilterer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Optimized and flexible operator filterer to abide to OpenSea's
/// mandatory on-chain royalty enforcement in order for new collections to
/// receive royalties.
/// For more information, see:
/// See: https://github.com/ProjectOpenSea/operator-filter-registry
abstract contract OperatorFilterer {
    /// @dev The default OpenSea operator blocklist subscription.
    address internal constant _DEFAULT_SUBSCRIPTION = 0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6;

    /// @dev The OpenSea operator filter registry.
    address internal constant _OPERATOR_FILTER_REGISTRY = 0x000000000000AAeB6D7670E522A718067333cd4E;

    /// @dev Registers the current contract to OpenSea's operator filter,
    /// and subscribe to the default OpenSea operator blocklist.
    /// Note: Will not revert nor update existing settings for repeated registration.
    function _registerForOperatorFiltering() internal virtual {
        _registerForOperatorFiltering(_DEFAULT_SUBSCRIPTION, true);
    }

    /// @dev Registers the current contract to OpenSea's operator filter.
    /// Note: Will not revert nor update existing settings for repeated registration.
    function _registerForOperatorFiltering(address subscriptionOrRegistrantToCopy, bool subscribe)
        internal
        virtual
    {
        /// @solidity memory-safe-assembly
        assembly {
            let functionSelector := 0x7d3e3dbe // `registerAndSubscribe(address,address)`.

            // Clean the upper 96 bits of `subscriptionOrRegistrantToCopy` in case they are dirty.
            subscriptionOrRegistrantToCopy := shr(96, shl(96, subscriptionOrRegistrantToCopy))

            for {} iszero(subscribe) {} {
                if iszero(subscriptionOrRegistrantToCopy) {
                    functionSelector := 0x4420e486 // `register(address)`.
                    break
                }
                functionSelector := 0xa0af2903 // `registerAndCopyEntries(address,address)`.
                break
            }
            // Store the function selector.
            mstore(0x00, shl(224, functionSelector))
            // Store the `address(this)`.
            mstore(0x04, address())
            // Store the `subscriptionOrRegistrantToCopy`.
            mstore(0x24, subscriptionOrRegistrantToCopy)
            // Register into the registry.
            if iszero(call(gas(), _OPERATOR_FILTER_REGISTRY, 0, 0x00, 0x44, 0x00, 0x04)) {
                // If the function selector has not been overwritten,
                // it is an out-of-gas error.
                if eq(shr(224, mload(0x00)), functionSelector) {
                    // To prevent gas under-estimation.
                    revert(0, 0)
                }
            }
            // Restore the part of the free memory pointer that was overwritten,
            // which is guaranteed to be zero, because of Solidity's memory size limits.
            mstore(0x24, 0)
        }
    }

    /// @dev Modifier to guard a function and revert if the caller is a blocked operator.
    modifier onlyAllowedOperator(address from) virtual {
        if (from != msg.sender) {
            if (!_isPriorityOperator(msg.sender)) {
                if (_operatorFilteringEnabled()) _revertIfBlocked(msg.sender);
            }
        }
        _;
    }

    /// @dev Modifier to guard a function from approving a blocked operator..
    modifier onlyAllowedOperatorApproval(address operator) virtual {
        if (!_isPriorityOperator(operator)) {
            if (_operatorFilteringEnabled()) _revertIfBlocked(operator);
        }
        _;
    }

    /// @dev Helper function that reverts if the `operator` is blocked by the registry.
    function _revertIfBlocked(address operator) private view {
        /// @solidity memory-safe-assembly
        assembly {
            // Store the function selector of `isOperatorAllowed(address,address)`,
            // shifted left by 6 bytes, which is enough for 8tb of memory.
            // We waste 6-3 = 3 bytes to save on 6 runtime gas (PUSH1 0x224 SHL).
            mstore(0x00, 0xc6171134001122334455)
            // Store the `address(this)`.
            mstore(0x1a, address())
            // Store the `operator`.
            mstore(0x3a, operator)

            // `isOperatorAllowed` always returns true if it does not revert.
            if iszero(staticcall(gas(), _OPERATOR_FILTER_REGISTRY, 0x16, 0x44, 0x00, 0x00)) {
                // Bubble up the revert if the staticcall reverts.
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }

            // We'll skip checking if `from` is inside the blacklist.
            // Even though that can block transferring out of wrapper contracts,
            // we don't want tokens to be stuck.

            // Restore the part of the free memory pointer that was overwritten,
            // which is guaranteed to be zero, if less than 8tb of memory is used.
            mstore(0x3a, 0)
        }
    }

    /// @dev For deriving contracts to override, so that operator filtering
    /// can be turned on / off.
    /// Returns true by default.
    function _operatorFilteringEnabled() internal view virtual returns (bool) {
        return true;
    }

    /// @dev For deriving contracts to override, so that preferred marketplaces can
    /// skip operator filtering, helping users save gas.
    /// Returns false for all inputs by default.
    function _isPriorityOperator(address) internal view virtual returns (bool) {
        return false;
    }
}


// File: packages/contracts/lib/fount-contracts/src/community/FountCardCheck.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "openzeppelin/token/ERC1155/IERC1155.sol";

/**
 * @author Sam King (samkingstudio.eth) for Fount Gallery
 * @title  Fount Gallery Card Check
 * @notice Utility functions to check ownership of a Fount Gallery Patron Card NFT
 */
contract FountCardCheck {
    /// @dev Address of the Fount Gallery Patron Card contract
    IERC1155 internal _fountCard;

    /// @dev Does not own a Fount Gallery Patron Card
    error NotFountCardHolder();

    /**
     * @dev Does not own enough Fount Gallery Patron Cards
     * @param required The minimum amount of cards that need to be owned
     * @param owned The actualy amount of cards owned
     */
    error DoesNotHoldEnoughFountCards(uint256 required, uint256 owned);

    /**
     * @dev Init with the Fount Gallery Patron Card contract address
     * @param fountCard The Fount Gallery Patron Card contract address
     */
    constructor(address fountCard) {
        _fountCard = IERC1155(fountCard);
    }

    /**
     * @dev Modifier that only allows the caller to do something if they hold
     * a Fount Gallery Patron Card
     */
    modifier onlyWhenFountCardHolder() {
        if (_getFountCardBalance(msg.sender) < 1) revert NotFountCardHolder();
        _;
    }

    /**
     * @dev Modifier that only allows the caller to do something if they hold
     * at least a specific amount Fount Gallery Patron Cards
     * @param minAmount The minimum amount of cards that need to be owned
     */
    modifier onlyWhenHoldingMinFountCards(uint256 minAmount) {
        uint256 balance = _getFountCardBalance(msg.sender);
        if (minAmount > balance) revert DoesNotHoldEnoughFountCards(minAmount, balance);
        _;
    }

    /**
     * @dev Get the number of Fount Gallery Patron Cards an address owns
     * @param owner The owner address to query
     * @return balance The balance of the owner
     */
    function _getFountCardBalance(address owner) internal view returns (uint256 balance) {
        balance = _fountCard.balanceOf(owner, 1);
    }

    /**
     * @dev Check if an address holds at least one Fount Gallery Patron Card
     * @param owner The owner address to query
     * @return isHolder If the owner holds at least one card
     */
    function _isFountCardHolder(address owner) internal view returns (bool isHolder) {
        isHolder = _getFountCardBalance(owner) > 0;
    }
}


// File: packages/contracts/lib/fount-contracts/src/extensions/SwappableMetadata.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

/**
 * @author Sam King (samkingstudio.eth) for Fount Gallery
 * @title  Swappable metadata module
 * @notice Allows the use of a separate and swappable metadata contract
 */
abstract contract SwappableMetadata {
    /* ------------------------------------------------------------------------
                                   S T O R A G E
    ------------------------------------------------------------------------ */

    /// @notice Address of metadata contract
    address public metadata;

    /// @notice Flag for whether the metadata address can be updated or not
    bool public isMetadataLocked;

    /* ------------------------------------------------------------------------
                                    E R R O R S
    ------------------------------------------------------------------------ */

    error MetadataLocked();

    /* ------------------------------------------------------------------------
                                    E V E N T S
    ------------------------------------------------------------------------ */

    /**
     * @dev When the metadata contract has been set
     * @param metadataContract The new metadata contract address
     */
    event MetadataContractSet(address indexed metadataContract);

    /**
     * @dev When the metadata contract has been locked and is no longer swappable
     * @param metadataContract The final locked metadata contract address
     */
    event MetadataContractLocked(address indexed metadataContract);

    /* ------------------------------------------------------------------------
                                      I N I T
    ------------------------------------------------------------------------ */

    /**
     * @param metadata_ The address of the initial metadata contract
     */
    constructor(address metadata_) {
        metadata = metadata_;
        emit MetadataContractSet(metadata_);
    }

    /* ------------------------------------------------------------------------
                                     A D M I N
    ------------------------------------------------------------------------ */

    /**
     * @notice Sets the metadata address
     * @param metadata_ The new address of the metadata contract
     */
    function _setMetadataAddress(address metadata_) internal {
        if (isMetadataLocked) revert MetadataLocked();
        metadata = metadata_;
        emit MetadataContractSet(metadata_);
    }

    /**
     * @notice Sets the metadata address
     * @param metadata The new address of the metadata contract
     */
    function setMetadataAddress(address metadata) public virtual;

    /**
     * @dev Locks the metadata address preventing further updates
     */
    function _lockMetadata() internal {
        isMetadataLocked = true;
        emit MetadataContractLocked(metadata);
    }
}


// File: packages/contracts/lib/fount-contracts/src/utils/Royalties.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "openzeppelin/interfaces/IERC2981.sol";

/**
 * @author Sam King (samkingstudio.eth) for Fount Gallery
 * @title  Royalty payments
 * @notice Support for the royalty standard (ERC-2981)
 */
abstract contract Royalties is IERC2981 {
    /* ------------------------------------------------------------------------
                                   S T O R A G E
    ------------------------------------------------------------------------ */

    /// @dev Store information about token royalties
    struct RoyaltyInfo {
        address receiver;
        uint96 amount;
    }

    /// @dev The current royalty information
    RoyaltyInfo internal _royaltyInfo;

    /// @dev Interface id for the royalty information standard
    /// bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
    bytes4 internal constant ROYALTY_INTERFACE_ID = 0x2a55205a;

    /* ------------------------------------------------------------------------
                                    E R R O R S
    ------------------------------------------------------------------------ */

    error MoreThanOneHundredPercentRoyalty();

    /* ------------------------------------------------------------------------
                                    E V E N T S
    ------------------------------------------------------------------------ */

    event RoyaltyInfoSet(address indexed receiver, uint256 indexed amount);
    event RoyaltyInfoUpdated(address indexed receiver, uint256 indexed amount);

    /* ------------------------------------------------------------------------
                                      I N I T
    ------------------------------------------------------------------------ */

    /**
     * @param royaltiesReceiver The receiver of royalty payments
     * @param royaltiesAmount The royalty percentage with two decimals (10,000 = 100%)
     */
    constructor(address royaltiesReceiver, uint256 royaltiesAmount) {
        _royaltyInfo = RoyaltyInfo(royaltiesReceiver, uint96(royaltiesAmount));
        emit RoyaltyInfoSet(royaltiesReceiver, royaltiesAmount);
    }

    /* ------------------------------------------------------------------------
                                  E R C 2 9 8 1
    ------------------------------------------------------------------------ */

    /// @notice EIP-2981 royalty standard for on-chain royalties
    function royaltyInfo(uint256, uint256 salePrice)
        public
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = _royaltyInfo.receiver;
        royaltyAmount = (salePrice * _royaltyInfo.amount) / 100_00;
    }

    /* ------------------------------------------------------------------------
                                     A D M I N
    ------------------------------------------------------------------------ */

    /**
     * @dev Internal function to set the royalty information
     * @param receiver The receiver of royalty payments
     * @param amount The royalty percentage with two decimals (10,000 = 100%)
     */
    function _setRoyaltyInfo(address receiver, uint256 amount) internal {
        if (amount > 100_00) revert MoreThanOneHundredPercentRoyalty();
        _royaltyInfo = RoyaltyInfo(receiver, uint24(amount));
        emit RoyaltyInfoUpdated(receiver, amount);
    }
}


// File: packages/contracts/lib/fount-contracts/src/utils/Withdraw.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/token/ERC1155/IERC1155.sol";

/**
 * @author Sam King (samkingstudio.eth) for Fount Gallery
 * @title  Withdraw ETH and tokens module
 * @notice Allows the withdrawal of ETH, ERC20, ERC721, an ERC1155 tokens
 */
abstract contract Withdraw {
    /* ------------------------------------------------------------------------
                                    E R R O R S
    ------------------------------------------------------------------------ */

    error CannotWithdrawToZeroAddress();
    error WithdrawFailed();
    error BalanceTooLow();
    error ZeroBalance();

    /* ------------------------------------------------------------------------
                                  W I T H D R A W
    ------------------------------------------------------------------------ */

    function _withdrawETH(address to) internal {
        // Prevent withdrawing to the zero address
        if (to == address(0)) revert CannotWithdrawToZeroAddress();

        // Check there is eth to withdraw
        uint256 balance = address(this).balance;
        if (balance == 0) revert ZeroBalance();

        // Transfer funds
        (bool success, ) = payable(to).call{value: balance}("");
        if (!success) revert WithdrawFailed();
    }

    function _withdrawToken(address tokenAddress, address to) internal {
        // Prevent withdrawing to the zero address
        if (to == address(0)) revert CannotWithdrawToZeroAddress();

        // Check there are tokens to withdraw
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        if (balance == 0) revert ZeroBalance();

        // Transfer tokens
        bool success = IERC20(tokenAddress).transfer(to, balance);
        if (!success) revert WithdrawFailed();
    }

    function _withdrawERC721Token(
        address tokenAddress,
        uint256 id,
        address to
    ) internal {
        // Prevent withdrawing to the zero address
        if (to == address(0)) revert CannotWithdrawToZeroAddress();

        // Check the NFT is in this contract
        address owner = IERC721(tokenAddress).ownerOf(id);
        if (owner != address(this)) revert ZeroBalance();

        // Transfer NFT
        IERC721(tokenAddress).transferFrom(address(this), to, id);
    }

    function _withdrawERC1155Token(
        address tokenAddress,
        uint256 id,
        uint256 amount,
        address to
    ) internal {
        // Prevent withdrawing to the zero address
        if (to == address(0)) revert CannotWithdrawToZeroAddress();

        // Check the tokens are owned by this contract, and there's at least `amount`
        uint256 balance = IERC1155(tokenAddress).balanceOf(address(this), id);
        if (balance == 0) revert ZeroBalance();
        if (amount > balance) revert BalanceTooLow();

        // Transfer tokens
        IERC1155(tokenAddress).safeTransferFrom(address(this), to, id, amount, "");
    }
}


// File: packages/contracts/lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC165.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";


// File: packages/contracts/lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}


// File: packages/contracts/lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// File: packages/contracts/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}


// File: packages/contracts/lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}


// File: packages/contracts/lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File: packages/contracts/lib/solmate/src/auth/Owned.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnerUpdated(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnerUpdated(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function setOwner(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnerUpdated(msg.sender, newOwner);
    }
}


// File: packages/contracts/lib/solmate/src/tokens/ERC1155.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Minimalist and gas efficient standard ERC1155 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[to][ids[i]] += amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[from][ids[i]] -= amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[from][id] -= amount;

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}


// File: packages/contracts/src/Constants.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

uint256 constant CIRCULAR_TENSION_ID = 1;
uint256 constant FALLEN_ANGEL_ID = 2;
uint256 constant RED_NIGHT_ID = 3;


// File: packages/contracts/src/ERC1155Base.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {FountCardCheck} from "fount-contracts/community/FountCardCheck.sol";
import {SwappableMetadata} from "fount-contracts/extensions/SwappableMetadata.sol";
import {Royalties} from "fount-contracts/utils/Royalties.sol";
import {OperatorFilterer} from "closedsea/OperatorFilterer.sol";
import {Withdraw} from "fount-contracts/utils/Withdraw.sol";
import {IPayments} from "./interfaces/IPayments.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC165} from "openzeppelin/interfaces/IERC165.sol";
import {IMetadata} from "./interfaces/IMetadata.sol";

/**
 * @author Fount Gallery
 * @title  ERC1155Base
 * @notice Base contract for Tormius 23 to inherit from
 *
 * Features:
 *   - Swappable metadata contract
 *   - On-chain royalties standard (EIP-2981)
 *   - Support for OpenSea's Operator Filterer to allow royalties
 */
abstract contract ERC1155Base is
    ERC1155,
    Owned,
    SwappableMetadata,
    Royalties,
    OperatorFilterer,
    Withdraw
{
    /* ------------------------------------------------------------------------
       S T O R A G E
    ------------------------------------------------------------------------ */

    string public name = "Tormius 23";
    string public symbol = "TOR23";

    /// @notice Contract information
    string public contractURI;

    /// @notice Approved minting addresses
    mapping(address => bool) public approvedMinters;

    /// @notice If operator filtering is applied
    bool public operatorFilteringEnabled;

    /// @notice Address where royalties/stuck funds should be sent
    address public payments;

    /* ------------------------------------------------------------------------
       E R R O R S
    ------------------------------------------------------------------------ */

    error CannotSetPaymentAddressToZero();

    /* ------------------------------------------------------------------------
       E V E N T S
    ------------------------------------------------------------------------ */

    event Init();

    /* ------------------------------------------------------------------------
       I N I T
    ------------------------------------------------------------------------ */

    /**
     * @param owner_ The owner of the contract
     * @param payments_ The admin of the contract
     * @param royaltiesAmount_ The royalty percentage with two decimals (10,000 = 100%)
     * @param metadata_ The initial metadata contract address
     */
    constructor(
        address owner_,
        address payments_,
        uint256 royaltiesAmount_,
        address metadata_
    ) ERC1155() Owned(owner_) SwappableMetadata(metadata_) Royalties(payments_, royaltiesAmount_) {
        payments = payments_;
        _registerForOperatorFiltering();
        operatorFilteringEnabled = true;
        emit Init();
    }

    /* ------------------------------------------------------------------------
       A D M I N
    ------------------------------------------------------------------------ */

    /** MINTERS ------------------------------------------------------------ */

    /**
     * @notice Admin function to set a minter address
     * @param minter The address of the new minter
     * @param approved If the minter is approved
     */
    function setMinter(address minter, bool approved) external onlyOwner {
        approvedMinters[minter] = approved;
    }

    /** METADATA ----------------------------------------------------------- */

    /**
     * @notice Admin function to set the metadata contract address
     * @param metadata The new metadata contract address
     */
    function setMetadataAddress(address metadata) public override onlyOwner {
        _setMetadataAddress(metadata);
    }

    /**
     * @notice Admin function to set the contract URI for marketplaces
     * @param contractURI_ The new contract URI
     */
    function setContractURI(string memory contractURI_) external onlyOwner {
        contractURI = contractURI_;
    }

    /** ROYALTIES ---------------------------------------------------------- */

    /**
     * @notice Admin function to set the royalty information
     * @param receiver The receiver of royalty payments
     * @param amount The royalty percentage with two decimals (10,000 = 100%)
     */
    function setRoyaltyInfo(address receiver, uint256 amount) external onlyOwner {
        _setRoyaltyInfo(receiver, amount);
    }

    /**
     * @notice Admin function to set whether OpenSea's Operator Filtering should be enabled
     * @param enabled If the operator filtering should be enabled
     */
    function setOperatorFilteringEnabled(bool enabled) external onlyOwner {
        operatorFilteringEnabled = enabled;
    }

    function registerForOperatorFiltering(
        address subscriptionOrRegistrantToCopy,
        bool subscribe
    ) external onlyOwner {
        _registerForOperatorFiltering(subscriptionOrRegistrantToCopy, subscribe);
    }

    /** PAYMENTS ----------------------------------------------------------- */

    /**
     * @notice Admin function to set the payment address for withdrawing stuck funds
     * @param paymentAddress The new address where payments should be sent upon withdrawal
     */
    function setPaymentAddress(address paymentAddress) external onlyOwner {
        if (paymentAddress == address(0)) revert CannotSetPaymentAddressToZero();
        payments = paymentAddress;
    }

    /* ------------------------------------------------------------------------
       R O T A L T I E S
    ------------------------------------------------------------------------ */

    /**
     * @notice Add interface for on-chain royalty standard
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, IERC165) returns (bool) {
        return interfaceId == ROYALTY_INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    /**
     * @notice Repeats the OpenSea Operator Filtering registration
     */
    function repeatRegistration() public {
        _registerForOperatorFiltering();
    }

    /**
     * @notice Override ERC-1155 `setApprovalForAll` to support OpenSea Operator Filtering
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @notice Override ERC-1155 `safeTransferFrom` to support OpenSea Operator Filtering
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @notice Override ERC-1155 `safeTransferFrom` to support OpenSea Operator Filtering
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual override onlyAllowedOperator(from) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Override `OperatorFilterer._operatorFilteringEnabled` to return whether
     * the operator filtering is enabled in this contract.
     */
    function _operatorFilteringEnabled() internal view virtual override returns (bool) {
        return operatorFilteringEnabled;
    }

    /* ------------------------------------------------------------------------
       W I T H D R A W
    ------------------------------------------------------------------------ */

    /**
     * @notice Admin function to withdraw stuck ETH
     * @dev Withdraws to the `payments` address. Reverts if the payments address is set to zero.
     */
    function withdrawETH() public {
        _withdrawETH(payments);
    }

    /**
     * @notice Admin function to withdraw stuck ERC-20 tokens
     * @dev Withdraws to the `payments` address. Reverts if the payments address is set to zero.
     */
    function withdrawTokens(address tokenAddress) public {
        _withdrawToken(tokenAddress, payments);
    }

    /* ------------------------------------------------------------------------
       E R C 1 1 5 5
    ------------------------------------------------------------------------ */

    /**
     * @notice Returns the token metadata
     * @return id The token id to get metadata for
     */
    function uri(uint256 id) public view override returns (string memory) {
        return IMetadata(metadata).tokenURI(id);
    }

    /**
     * @notice Burn a token. You can only burn tokens you own.
     * @param id The token id to burn
     * @param amount The amount to burn
     */
    function burn(uint256 id, uint256 amount) external {
        require(balanceOf[msg.sender][id] >= amount, "CANNOT_BURN");
        _burn(msg.sender, id, amount);
    }
}


// File: packages/contracts/src/RedNight.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import {ERC1155Base} from "./ERC1155Base.sol";
import {RED_NIGHT_ID} from "./Constants.sol";
import {IRedNight} from "./interfaces/IRedNight.sol";

/**
 * @author Fount Gallery
 * @title  Tormius 23: "Red Night"
 * @notice
 * Features:
 *   - Red Night Open Edition
 *   - Shared metadata contract with the 1/1 from the same collection
 *   - On-chain royalties standard (EIP-2981)
 *   - Support for OpenSea's Operator Filterer to allow royalties
 */
contract RedNight is IRedNight, ERC1155Base {
    /* ------------------------------------------------------------------------
       I N I T
    ------------------------------------------------------------------------ */

    /**
     * @param owner_ The owner of the contract
     * @param payments_ The address where payments should be sent
     * @param royaltiesAmount_ The royalty percentage with two decimals (10,000 = 100%)
     * @param metadata_ The initial metadata contract address
     */
    constructor(
        address owner_,
        address payments_,
        uint256 royaltiesAmount_,
        address metadata_
    ) ERC1155Base(owner_, payments_, royaltiesAmount_, metadata_) {}

    /* ------------------------------------------------------------------------
       M I N T
    ------------------------------------------------------------------------ */

    /**
     * @notice Mints an edition of "Red Night"
     * @dev Only approved addresses can mint, for example the sale contract
     * @param to The address to mint to
     */
    function mintRedNight(address to) external {
        require(approvedMinters[msg.sender], "Only approved addresses can mint");
        _mint(to, RED_NIGHT_ID, 1, "");
    }
}


// File: packages/contracts/src/interfaces/IMetadata.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

interface IMetadata {
    function tokenURI(uint256 id) external view returns (string memory);
}


// File: packages/contracts/src/interfaces/IPayments.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

interface IPayments {
    function releaseAllETH() external;

    function releaseAllToken(address tokenAddress) external;
}


// File: packages/contracts/src/interfaces/IRedNight.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

interface IRedNight {
    function mintRedNight(address to) external;
}


