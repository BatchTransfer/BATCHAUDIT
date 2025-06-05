// File: @openzeppelin/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

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
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

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
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

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


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


// File: @openzeppelin/contracts/utils/Context.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol
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


// File: contracts/comics/ComicPurchase.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import { IComicPurchase } from "./interfaces/IComicPurchase.sol";

import { EchelonGateways } from "../prime-token/EchelonGateways.sol";

contract ComicPurchase is IComicPurchase, Ownable, EchelonGateways {
    IERC20 public prime = IERC20(0xb23d80f5FefcDDaa212212F028021B41DEd428CF);

    /// @notice Mapping of comic token id to comic supply
    mapping(uint256 => uint256) public parallelComicsSupply;
    /// @notice Mapping of comic token id to comics purchased
    mapping(uint256 => uint256) public parallelComicsPurchased;

    /// @notice Allowlist that bypasses the disabled variable
    mapping(address => bool) public allowlist;
    /// @notice Disabled state
    bool public isDisabled = true;

    /// @notice comic price
    uint256 public comicPrice = 3 ether;

    /// @notice Address to get the comics from
    address public pullFromAddress = 0x716E6b6873038a8243F5EB44e2b09D85DEFf45Ec;
    /// @notice Parallel Alpha contract
    IERC1155 public parallelComic =
        IERC1155(0x6A82872743217A0988E4d72975D74432CfDeF9D7);

    /**
     * @notice Function invoked by the prime token contract to handle totalCardCount increase and emit payment event
     * @param _from The address of the original msg.sender
     * @param _id An id passed by the caller to represent any arbitrary and potentially off-chain event id
     * @param _primeValue The amount of prime that was sent from the prime token contract
     * @param _data Catch-all param to allow the caller to pass additional data to the handler, includes the amount of cards they want to purchase
     */
    function handleInvokeEchelon(
        address _from,
        address,
        address,
        uint256 _id,
        uint256,
        uint256 _primeValue,
        bytes memory _data
    ) public payable {
        if (msg.sender != address(prime)) {
            revert InvalidCaller();
        }

        if (isDisabled && !allowlist[_from]) revert Disabled();

        (uint256[] memory comicIds, uint256[] memory comicAmounts) = abi.decode(
            _data,
            (uint256[], uint256[])
        );

        uint256 totalPrice = 0;

        for (uint256 i = 0; i < comicIds.length; i++) {
            if (
                parallelComicsPurchased[comicIds[i]] >=
                parallelComicsSupply[comicIds[i]]
            ) revert SoldOut(comicIds[i]);

            parallelComicsPurchased[comicIds[i]] += comicAmounts[i];

            totalPrice += comicPrice * comicAmounts[i];
        }

        if (totalPrice != _primeValue) revert InvalidPayment(_primeValue);

        parallelComic.safeBatchTransferFrom(
            pullFromAddress,
            _from,
            comicIds,
            comicAmounts,
            ""
        );

        emit ComicsPurchased(_from, comicIds, comicAmounts, _id);
    }

    /** @notice Set the prime token address
     *  @param _prime prime token address
     */
    function setPrimeAddress(IERC20 _prime) external onlyOwner {
        prime = _prime;
        emit SetPrimeAddress(address(_prime));
    }

    /**
     * @notice Sets the disabled state
     * @dev Only callable by the owner
     * @param _isDisabled The new disabled state
     */
    function setDisabled(bool _isDisabled) external onlyOwner {
        isDisabled = _isDisabled;

        emit IsDisabledSet(_isDisabled);
    }

    /**
     * @notice Sets the parallel comic contract
     * @dev Only callable by the owner
     * @param _parallelComic The new parallel comic contract
     */
    function setParallelComic(IERC1155 _parallelComic) external onlyOwner {
        parallelComic = IERC1155(_parallelComic);

        emit ParallelComicSet(address(_parallelComic));
    }

    /**
     * @notice Sets the pull from address
     * @dev Only callable by the owner
     * @param _pullFromAddress The new pull from address
     */
    function setPullFromAddress(address _pullFromAddress) external onlyOwner {
        pullFromAddress = _pullFromAddress;

        emit PullFromAddressSet(_pullFromAddress);
    }

    /**
     * @notice Sets the comic price
     * @dev Only callable by the owner
     * @param _comicPrice The new comic price
     */
    function setComicPrice(uint256 _comicPrice) external onlyOwner {
        comicPrice = _comicPrice;

        emit ComicPriceSet(_comicPrice);
    }

    /**
     * @notice Sets the comics
     * @dev Only callable by the owner
     * @param _comicIds The comic ids
     * @param _comicSupplies The comic supplies
     */
    function setComics(
        uint256[] calldata _comicIds,
        uint256[] calldata _comicSupplies
    ) external onlyOwner {
        if (_comicIds.length != _comicSupplies.length) revert InvalidLength();

        for (uint256 i = 0; i < _comicIds.length; i++) {
            parallelComicsSupply[_comicIds[i]] = _comicSupplies[i];
            parallelComicsPurchased[_comicIds[i]] = 0;
        }

        emit ComicsSet(_comicIds, _comicSupplies);
    }

    /**
     * @notice Sets the allowlist
     * @dev Only callable by the owner
     * @param _allowlist The new allowlist
     * @param _val The new value
     */
    function setAllowlist(
        address[] calldata _allowlist,
        bool _val
    ) external onlyOwner {
        for (uint256 i = 0; i < _allowlist.length; i++) {
            allowlist[_allowlist[i]] = _val;
        }

        emit AllowlistSet(_allowlist, _val);
    }
}


// File: contracts/comics/interfaces/IComicPurchase.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IComicPurchase {
    event ComicsPurchased(
        address indexed buyer,
        uint256[] comicIds,
        uint256[] comicAmounts,
        uint256 id
    );
    event SetPrimeAddress(address primeAddress);

    event IsDisabledSet(bool isDisabled);

    event ParallelComicSet(address parallelComic);

    event PullFromAddressSet(address pullFromAddress);

    event ComicPriceSet(uint256 comicPrice);

    event ComicsSet(uint256[] comicIds, uint256[] comicAmounts);

    event AllowlistSet(address[] allowlist, bool isAllowlisted);

    error InvalidCaller();

    error Disabled();

    error InvalidPayment(uint256 value);

    error SoldOut(uint256 comicId);

    error InvalidLength();
}


// File: contracts/prime-token/EchelonGateways.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface EchelonGateways {
    // Invoked by the Prime Token contract to handle arbitrary functionalities by the given gateway
    function handleInvokeEchelon(
        address from,
        address ethDestination,
        address primeDestination,
        uint256 id,
        uint256 ethValue,
        uint256 primeValue,
        bytes calldata data
    ) external payable;
}


