// File: @openzeppelin/contracts/interfaces/IERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../utils/introspection/IERC165.sol";


// File: @openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.20;

import {IERC1155} from "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` amount of tokens of type `id` are transferred from `from` to `to` by `operator`.
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
     * @dev Returns the value of tokens of token type `id` owned by `account`.
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
     * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`.
     *
     * WARNING: This function can potentially allow a reentrancy attack when transferring tokens
     * to an untrusted contract, when invoking {onERC1155Received} on the receiver.
     * Ensure to follow the checks-effects-interactions pattern and consider employing
     * reentrancy guards when interacting with untrusted contracts.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `value` amount.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * WARNING: This function can potentially allow a reentrancy attack when transferring tokens
     * to an untrusted contract, when invoking {onERC1155BatchReceived} on the receiver.
     * Ensure to follow the checks-effects-interactions pattern and consider employing
     * reentrancy guards when interacting with untrusted contracts.
     *
     * Emits either a {TransferSingle} or a {TransferBatch} event, depending on the length of the array arguments.
     *
     * Requirements:
     *
     * - `ids` and `values` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external;
}


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

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
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// File: @openzeppelin/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

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
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

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


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

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


// File: contracts/diamond/IDiamondFacet.sol
// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.20;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

/// @notice Use at your own risk
interface IDiamondFacet is IERC165 {

    // NOTE: The override MUST remain 'pure'.
    function getFacetName() external pure returns (string memory);

    // NOTE: The override MUST remain 'pure'.
    function getFacetVersion() external pure returns (string memory);

    // NOTE: The override MUST remain 'pure'.
    function getFacetPI() external pure returns (string[] memory);

    // NOTE: The override MUST remain 'pure'.
    function getFacetProtectedPI() external pure returns (string[] memory);
}


// File: contracts/facets/_prizma/catalog/CatalogFacet.sol
// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "../../../diamond/IDiamondFacet.sol";
import "./ICatalog.sol";
import "./CatalogInternal.sol";

/// @notice Use at your own risk
contract CatalogFacet is IDiamondFacet, IERC1155MetadataURI, ICatalog {

    function getFacetName()
      external pure override returns (string memory) {
        return "catalog";
    }

    // CAUTION: Don't forget to update the version when adding new functionality
    function getFacetVersion()
      external pure override returns (string memory) {
        return "3.0.1";
    }

    function getFacetPI()
      external pure override returns (string[] memory) {
        string[] memory pi = new string[](12);
        pi[ 0] = "initializeCatalog(address)";
        pi[ 1] = "getRegistrar()";
        pi[ 2] = "addRegisteree(uint256,address,address)";
        pi[ 3] = "submitTransfer(uint256,address,address,uint256)";
        pi[ 4] = "balanceOf(address,uint256)";
        pi[ 5] = "balanceOfBatch(address[],uint256[])";
        pi[ 6] = "setApprovalForAll(address,bool)";
        pi[ 7] = "isApprovedForAll(address,address)";
        pi[ 8] = "safeTransferFrom(address,address,uint256,uint256,bytes)";
        pi[ 9] = "safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)";
        pi[10] = "uri(uint256)";
        pi[11] = "xMint(address,address,uint256,uint256)";
        return pi;
    }

    function getFacetProtectedPI()
      external pure override returns (string[] memory) {
        string[] memory pi = new string[](0);
        return pi;
    }

    function supportsInterface(bytes4 interfaceId)
      external pure override returns (bool) {
        return
            interfaceId == type(IDiamondFacet).interfaceId ||
            interfaceId == type(ICatalog).interfaceId ||
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId;
    }

    function initializeCatalog(
        address registrar
    ) external override {
        CatalogInternal._initialize(registrar);

    }

    function getRegistrar() external view returns (address) {
        return CatalogInternal._getRegistrar();
    }

    function addRegisteree(
        uint256 registereeId,
        address grantToken,
        address council
    ) external override {
        CatalogInternal._addRegisteree(registereeId, grantToken, council);
    }

    function submitTransfer(
        uint256 registereeId,
        address from,
        address to,
        uint256 amount
    ) external override {
        address caller = msg.sender;
        CatalogInternal._submitTransfer(
            caller, registereeId, from, to, amount);
    }

    function balanceOf(
        address account,
        uint256 registereeId
    ) external view override returns (uint256) {
        return CatalogInternal._balanceOf(account, registereeId);
    }

    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata registereeIds
    ) external view override returns (uint256[] memory) {
        return CatalogInternal._balanceOfBatch(accounts, registereeIds);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) external override {
        CatalogInternal._setApprovalForAll(operator, approved);
    }

    function isApprovedForAll(
        address account,
        address operator
    ) external view override returns (bool) {
        return CatalogInternal._isApprovedForAll(account, operator);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 registereeId,
        uint256 amount,
        bytes calldata data
    ) external override {
        CatalogInternal._safeTransferFrom(
            from, to, registereeId, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata registereeIds,
        uint256[] calldata amounts,
        bytes calldata data
    ) external pure override {
        CatalogInternal._safeBatchTransferFrom(
            from, to, registereeIds, amounts, data);
    }

    function uri(uint256 registereeId)
    external view override returns (string memory) {
        return CatalogInternal._uri(registereeId);
    }

    function xMint(
        address /* to */,
        address origTo,
        uint256 registereeId,
        uint256 nrOfTokens
    ) external payable {
        CatalogInternal._xMint(origTo, registereeId, nrOfTokens);
    }
}


// File: contracts/facets/_prizma/catalog/CatalogInternal.sol
// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../../../lib/IntegerSet.sol";
import "../registrar/IRegistrar.sol";
import "../council/ICouncil.sol";
import "./CatalogStorage.sol";

/// @notice Use at your own risk
library CatalogInternal {

    bytes32 public constant ZONE_ID = bytes32(uint256(1));
    bytes32 public constant REGISTEREES_SET_ID = bytes32(uint256(1));

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 registereeId,
        uint256 value
    );
    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );
    event URI(
        string value,
        uint256 indexed registereeId
    );

    function _initialize(
        address registrar
    ) internal {
        require(!__s().initialized, "CI:AI");
        __s().registrar = registrar;
        __s().initialized = true;
    }

    function _getRegistrar() internal view returns (address) {
        return __s().registrar;
    }

    function _addRegisteree(
        uint256 registereeId,
        address grantToken,
        address council
    ) internal {
        require(msg.sender == __s().registrar, "CATI:NREG");
        require(!__exists(registereeId), "CATI:EXT");
        require(__s().registerees[registereeId].registereeId == 0, "CATI:EXT2");
        __s().registerees[registereeId].registereeId = registereeId;
        __s().registerees[registereeId].grantToken = grantToken;
        __s().registerees[registereeId].council = council;
        IntegerSetLib._addItem(ZONE_ID, REGISTEREES_SET_ID, registereeId);
        emit TransferSingle(
            __s().registrar, address(0), council, registereeId,
                IERC20(grantToken).totalSupply());
    }

    function _submitTransfer(
        address caller,
        uint256 registereeId,
        address from,
        address to,
        uint256 amount
    ) internal {
        if(!__exists(registereeId))
        {
            return;
        }
        require(msg.sender == __s().registerees[registereeId].grantToken, "CATI:NST");
        emit TransferSingle(caller, from, to, registereeId, amount);
    }

    function _balanceOf(
        address account,
        uint256 registereeId
    ) internal view returns (uint256) {
        require(__exists(registereeId), "CATI:TNF");
        return IERC20(__s().registerees[registereeId].grantToken).balanceOf(account);
    }

    function _balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata registereeIds
    ) internal view returns (uint256[] memory) {
        require(accounts.length == registereeIds.length, "CATI:ILS");
        require(accounts.length > 0, "CATI:ZL");
        uint256[] memory balances = new uint256[](accounts.length);
        for (uint256 i = 1; i <= registereeIds.length; i++) {
            require(__exists(registereeIds[i]), "CATI:TNF");
            balances[i] = IERC20(__s().registerees[registereeIds[i]].grantToken).balanceOf(accounts[i]);
        }
        return balances;
    }

    function _setApprovalForAll(
        address operator,
        bool approved
    ) internal {
        __s().approvals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function _isApprovedForAll(
        address account,
        address operator
    ) internal view returns (bool) {
        return __s().approvals[account][operator];
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 registereeId,
        uint256 amount,
        bytes calldata /* data */
    ) internal {
        require(__exists(registereeId), "CATI:TNF");
        require(from == msg.sender || _isApprovedForAll(from, msg.sender), "CATI:NAPPR");
        IERC20(__s().registerees[registereeId].grantToken)
            .transferFrom(from, to, amount);
    }

    function _safeBatchTransferFrom(
        address /* from */,
        address /* to */,
        uint256[] calldata /* registereeIds */,
        uint256[] calldata /* amounts */,
        bytes calldata /* data */
    ) internal pure {
        revert("batch transfer is not supported");
    }

    function _uri(uint256 registereeId)
    internal view returns (string memory) {
        (,string memory details,,,,) = IRegistrar(__s().registrar).getRegistereeInfo(registereeId);
        return details;
    }

    function _xMint(
        address to,
        uint256 registereeId,
        uint256 nrOfTokens
    ) internal {
        require(__exists(registereeId), "CATI:TNF");
        ICouncil council = ICouncil(__s().registerees[registereeId].council);
        council.icoTransferTokensFromCouncil{ value: msg.value }(
            address(0), // payErc20
            msg.sender, // payer
            to,
            nrOfTokens
        );
    }

    function __exists(uint256 registereeId) internal view returns (bool) {
        return IntegerSetLib._hasItem(ZONE_ID, REGISTEREES_SET_ID, registereeId);
    }

    function __s() private pure returns (CatalogStorage.Layout storage) {
        return CatalogStorage.layout();
    }
}


// File: contracts/facets/_prizma/catalog/CatalogStorage.sol
// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.20;

/// @notice Use at your own risk. Just got the basic
///         idea from: https://github.com/solidstate-network/solidstate-solidity
library CatalogStorage {

    struct Registeree {
        uint256 registereeId;
        address grantToken;
        address council;

        // reserved for future usage
        mapping(bytes32 => bytes) extra;
    }

    struct Layout {
        bool initialized;

        address registrar;

        uint256 lastRegistereeId;
        mapping(uint256 => Registeree) registerees;

        mapping(address => mapping(address => bool)) approvals;

        // reserved for future usage
        mapping(bytes32 => bytes) extra;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("qomet-tech.contracts.facets.prizma.catalog.storage");

    function layout() internal pure returns (Layout storage s) {
        bytes32 slot = STORAGE_SLOT;
        /* solhint-disable no-inline-assembly */
        assembly {
            s.slot := slot
        }
        /* solhint-enable no-inline-assembly */
    }
}


// File: contracts/facets/_prizma/catalog/ICatalog.sol
// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.20;

/// @notice Use at your own risk
interface ICatalog {

    function initializeCatalog(
        address registrar
    ) external;

    function addRegisteree(
        uint256 registreeId,
        address grantToken,
        address council
    ) external;

    function submitTransfer(
        uint256 registereeId,
        address from,
        address to,
        uint256 amount
    ) external;
}


// File: contracts/facets/_prizma/council/ICouncil.sol
// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.20;

/// @notice Use at your own risk
interface ICouncil {

    struct CouncilInitializeParams {
        uint256 registereeId;
        address grantToken;
        address egw;
        uint256 egwPlanId;
        string paymentCurrency;
        uint256 proposalCreationFeeAmount;
        uint256 adminProposalCreationFeeAmount;
        uint256 icoTokenPriceAmount;
        uint256 icoFeeAmount;
        uint256 icoMaxCap;
        uint256 icoMintMinCap;
        uint256 icoMintMaxCap;
        address feeCollectionAccount;
        address icoCollectionAccount;
        address rac;
        bytes32 racSharedDomainId;
        bool useVotingWhiltelist;
    }

    function initializeCouncil(
        CouncilInitializeParams memory params
    ) external;

    function getAccountProposals(
        address account,
        bool onlyPending
    ) external view returns (uint256[] memory);

    function executeProposal(
        address executor,
        uint256 proposalId
    ) external;

    function executeAdminProposal(
        address executor,
        uint256 adminProposalId
    ) external;

    function icoTransferTokensFromCouncil(
        address payErc20,
        address payer,
        address to,
        uint256 nrOfTokens
    ) external payable;
}


// File: contracts/facets/_prizma/registrar/IRegistrar.sol
// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.20;

/// @notice Use at your own risk
interface IRegistrar {

    function initializeRegistrar(
        address registry,
        address catalog,
        string memory name,
        string memory details,
        address defaultUTR,
        address defaultTaskManager,
        address defaultAuthzSource
    ) external;

    function getRegistry() external view returns (address);

    function getCatalog() external view returns (address);

    function getRegistereeInfo(uint256 registereeId)
    external view returns (
        string memory,   // name of the registeree
        string memory,   // details of the registeree
        address,         // address of the GrantToken contract
        address,         // address of the Council contract
        string[] memory, // annexes attached to this instance of registeree
        string[] memory  // tags attached to this instance of registeree
    );

    struct RegisterParams {
        string name;
        string details;
        string grantTokenName;
        string grantTokenSymbol;
        uint256 nrOfGrantTokens;
        address[] councilAdmins;
        address[] councilCreators;
        address[] councilExecutors;
        address[] councilFinalizers;
        address egw;
        uint256 egwPlanId;
        string paymentCurrency;
        uint256 proposalCreationFeeAmount;
        uint256 adminProposalCreationFeeAmount;
        uint256 icoTokenPriceAmount;
        uint256 icoFeeAmount;
        uint256 icoMaxCap;
        uint256 icoMintMinCap;
        uint256 icoMintMaxCap;
        address feeCollectionAccount;
        address icoCollectionAccount;
        bool addRegistryEntry;
        bool addCatalogEntry;
        address rac;
        bytes32 racSharedDomainId;
        bool useVotingWhiltelist;
    }
    function register(
        RegisterParams memory params
    ) external;
}


// File: contracts/lib/IntegerSet.sol
// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.20;

/// @notice Use at your own risk. Just got the basic
///         setIdea from: https://github.com/solsetIdstate-network/solsetIdstate-solsetIdity
library IntegerSetStorage {

    struct IntegerSet {
        // list of integer items
        uint256[] items;
        // integer > index in the items array
        mapping(uint256 => uint256) itemsIndex;
        // integer > true if removed
        mapping(uint256 => bool) removedItems;
    }

    struct Zone {
        // set ID > set object
        mapping(bytes32 => IntegerSet) sets;
    }

    struct Layout {
        // zone ID > zone object
        mapping(bytes32 => Zone) zones;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("qomet-tech.contracts.lib.integer-set.storage");

    function layout() internal pure returns (Layout storage s) {
        bytes32 slot = STORAGE_SLOT;
        /* solhint-disable no-inline-assembly */
        assembly {
            s.slot := slot
        }
        /* solhint-enable no-inline-assembly */
    }
}

library IntegerSetLib {

    function _hasItem(
        bytes32 zoneId,
        bytes32 setId,
        uint256 item
    ) internal view returns (bool) {
        IntegerSetStorage.IntegerSet storage set = __s2(zoneId, setId);
        return set.itemsIndex[item] > 0 && !set.removedItems[item];
    }

    function _getItemsCount(
        bytes32 zoneId,
        bytes32 setId
    ) internal view returns (uint256) {
        IntegerSetStorage.IntegerSet storage set = __s2(zoneId, setId);
        return __getItemsCount(set, 0, 0, false);
    }

    function _getItems(
        bytes32 zoneId,
        bytes32 setId,
        uint256 startIndex,
        uint256 count,
        bool reverse
    ) internal view returns (uint256, uint256[] memory) {
        IntegerSetStorage.IntegerSet storage set = __s2(zoneId, setId);
        if (set.items.length == 0) {
            return (0, new uint256[](0));
        }
        uint256 total = __getItemsCount(set, 0, 0, reverse);
        uint256 resultSize = __getItemsCount(set, startIndex, count, reverse);
        uint256[] memory results = new uint256[](resultSize);
        uint256 j = 0;
        uint256 k = 0;

        uint256 start = !reverse ? 0 : set.items.length - 1;
        uint256 end = !reverse ? set.items.length - 1 : 0;
        uint256 i = start;
        while ((!reverse && i <= end) || (reverse && i >= end)) {
            uint256 item = set.items[i];
            if (!set.removedItems[item]) {
                if (k >= startIndex) {
                    results[j] = item;
                    j++;
                    if (count > 0 && j == count) {
                        return (total, results);
                    }
                }
                k++;
            }
            if (reverse && i == 0) { break; }
            if (!reverse) { i++; } else { i--; }
        }
        return (total, results);
    }

    function _addItem(
        bytes32 zoneId,
        bytes32 setId,
        uint256 item
    ) internal returns (bool) {
        IntegerSetStorage.IntegerSet storage set = __s2(zoneId, setId);
        if (set.itemsIndex[item] == 0) {
            set.items.push(item);
            set.itemsIndex[item] = __s2(zoneId, setId).items.length;
            return true;
        } else if (set.removedItems[item]) {
            set.removedItems[item] = false;
            return true;
        }
        return false;
    }

    function _removeItem(
        bytes32 zoneId,
        bytes32 setId,
        uint256 item
    ) internal returns (bool) {
        IntegerSetStorage.IntegerSet storage set = __s2(zoneId, setId);
        return __removeItem(set, item);
    }

    function _clear(
        bytes32 zoneId,
        bytes32 setId
    ) internal {
        IntegerSetStorage.IntegerSet storage set = __s2(zoneId, setId);
        for (uint256 i = 0; i < set.items.length; i++) {
            __removeItem(set, set.items[i]);
        }
    }

    function __getItemsCount(
        IntegerSetStorage.IntegerSet storage set,
        uint256 startIndex,
        uint256 count,
        bool reverse
    ) private view returns (uint256) {
        if (set.items.length == 0) {
            return 0;
        }
        uint256 j = 0;
        uint256 k = 0;
        uint256 start = !reverse ? 0 : set.items.length - 1;
        uint256 end = !reverse ? set.items.length - 1 : 0;
        uint256 i = start;
        while ((!reverse && i <= end) || (reverse && i >= end)) {
            uint256 item = set.items[i];
            if (!set.removedItems[item]) {
                if (k >= startIndex) {
                    j++;
                    if (count > 0 && j == count) {
                        return j;
                    }
                }
                k++;
            }
            if (reverse && i == 0) { break; }
            if (!reverse) { i++; } else { i--; }
        }
        return j;
    }

    function __removeItem(
        IntegerSetStorage.IntegerSet storage set,
        uint256 item
    ) private returns (bool) {
        if (set.itemsIndex[item] > 0 && !set.removedItems[item]) {
            set.removedItems[item] = true;
            return true;
        }
        return false;
    }

    function __s2(
        bytes32 zoneId,
        bytes32 setId
    ) private view returns (IntegerSetStorage.IntegerSet storage) {
        return __s().zones[zoneId].sets[setId];
    }

    function __s() private pure returns (IntegerSetStorage.Layout storage) {
        return IntegerSetStorage.layout();
    }
}


