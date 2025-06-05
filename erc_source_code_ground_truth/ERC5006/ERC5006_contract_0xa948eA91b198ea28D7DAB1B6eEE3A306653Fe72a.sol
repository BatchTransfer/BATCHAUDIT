// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "./Bank.sol";
import "./IBank1155.sol";
import "./W5006Factory.sol";

contract Bank1155 is Bank, W5006Factory, ERC1155Receiver, IBank1155 {
    //               total amount
    mapping(bytes32 => uint256) internal frozenAmountMap;
    //                  lender & amount
    mapping(bytes32 => Renting) internal rentingMap;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address admin_,
        address w5006Impl_
    ) public initializer {
        _initOwnable(owner_, admin_);
        _initW5006(w5006Impl_);
    }

    function _get5006(
        TokenType tokenType,
        address oNFT
    ) internal view returns (address addr5006) {
        if (tokenType == TokenType.ERC5006) {
            addr5006 = oNFT;
        } else if (tokenType == TokenType.ERC1155) {
            addr5006 = oNFT_w5006[oNFT];
            if (addr5006 == address(0)) {
                revert("w5006 is not deployed");
            }
        } else {
            revert("invalid token type");
        }
    }

    function _frozenKey(
        address oNFT,
        uint256 oNFTId,
        address from
    ) internal pure returns (bytes32 key) {
        key = keccak256(abi.encode(oNFT, oNFTId, from));
    }

    function _rentingKey(
        address oNFT,
        uint256 oNFTId,
        address lender,
        uint256 recordId
    ) internal pure returns (bytes32 key) {
        key = keccak256(abi.encode(oNFT, oNFTId, lender, recordId));
    }

    function frozenAmountOf(
        address oNFT,
        uint256 oNFTId,
        address from
    ) external view returns (uint256) {
        bytes32 fkey = _frozenKey(oNFT, oNFTId, from);
        return frozenAmountMap[fkey];
    }

    function createUserRecord(RecordParam memory param) external onlyMarket {
        IERC1155(param.oNFT).safeTransferFrom(
            param.owner,
            address(this),
            param.oNFTId,
            param.oNFTAmount,
            ""
        );

        address addr5006 = _get5006(param.tokenType, param.oNFT);
        uint256 recordId;
        if (param.tokenType == TokenType.ERC5006) {
            recordId = IERC5006(addr5006).createUserRecord(
                address(this),
                param.user,
                param.oNFTId,
                SafeCast.toUint64(param.oNFTAmount),
                SafeCast.toUint64(param.expiry)
            );
        } else if (param.tokenType == TokenType.ERC1155) {
            recordId = IWrappedInERC5006(addr5006).stakeAndCreateUserRecord(
                param.oNFTId,
                SafeCast.toUint64(param.oNFTAmount),
                param.user,
                SafeCast.toUint64(param.expiry)
            );
        }

        param.recordId = recordId;
        bytes32 rentingKey = _rentingKey(
            param.oNFT,
            param.oNFTId,
            param.owner,
            recordId
        );
        rentingMap[rentingKey] = Renting(param.owner, param.oNFTAmount);
        bytes32 fkey = _frozenKey(param.oNFT, param.oNFTId, param.owner);
        frozenAmountMap[fkey] += param.oNFTAmount;
        emit CreateUserRecord(param);
    }

    function _deleteUserRecord(RentingRecord calldata param) internal {
        address addr5006 = _get5006(param.tokenType, param.oNFT);
        IERC5006.UserRecord memory record = IERC5006(addr5006).userRecordOf(
            param.recordId
        );
        if (record.amount == 0) return;
        if (record.expiry > block.timestamp) return;
        bytes32 rentingKey = _rentingKey(
            param.oNFT,
            param.oNFTId,
            param.lender,
            param.recordId
        );
        require(
            rentingMap[rentingKey].lender == param.lender,
            "invalid lender"
        );
        require(
            rentingMap[rentingKey].amount == record.amount,
            "invalid amount"
        );
        if (param.tokenType == TokenType.ERC1155) {
            IWrappedInERC5006(addr5006).redeemRecord(
                param.recordId,
                param.lender
            );
        } else {
            IERC5006(addr5006).deleteUserRecord(param.recordId);
            IERC1155(param.oNFT).safeTransferFrom(
                address(this),
                param.lender,
                record.tokenId,
                record.amount,
                ""
            );
        }

        bytes32 fkey = _frozenKey(param.oNFT, param.oNFTId, param.lender);
        frozenAmountMap[fkey] -= record.amount;
        delete rentingMap[rentingKey];
        emit DeleteUserRecord(param);
    }

    function deleteUserRecords(RentingRecord[] calldata toDeletes) external nonReentrant{
        for (uint256 i = 0; i < toDeletes.length; i++) {
            _deleteUserRecord(toDeletes[i]);
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC1155Receiver) returns (bool) {
        return
            interfaceId == type(IBank1155).interfaceId ||
            ERC1155Receiver.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../lib/OwnableUpgradeable.sol";
import "../erc5006/IERC5006.sol";
import "../erc5006/IWrappedInERC5006.sol";

abstract contract W5006Factory is OwnableUpgradeable {
    event DeployW5006(address w5006, address originalAddress);

    address public w5006Impl;
    mapping(address => address) public oNFT_w5006;

    function _initW5006(address w5006Impl_) internal {
        require(
            IERC165(w5006Impl_).supportsInterface(type(IERC5006).interfaceId),
            "not ERC5006"
        );
        w5006Impl = w5006Impl_;
    }

    function setW5006Impl(address w5006Impl_) public onlyAdmin {
        _initW5006(w5006Impl_);
    }

    function _deployW5006(address oNFT) internal returns (address w5006) {
        require(
            IERC165(oNFT).supportsInterface(type(IERC1155).interfaceId),
            "oNFT is not ERC1155"
        );
        require(
            !IERC165(oNFT).supportsInterface(type(IERC5006).interfaceId),
            "oNFT is ERC5006 already"
        );
        w5006 = Clones.clone(w5006Impl);
        IWrappedIn(w5006).initializeWrap(oNFT);
        emit DeployW5006(w5006, oNFT);
    }

    function deployW5006(address oNFT) public {
        require(oNFT_w5006[oNFT] == address(0), "deployed already");
        address w5006 = _deployW5006(oNFT);
        oNFT_w5006[oNFT] = w5006;
        IERC1155(oNFT).setApprovalForAll(w5006, true);
    }

    function registerW5006(address oNFT, address w5006) public onlyAdmin {
        require(oNFT_w5006[oNFT] == address(0), "deployed already");
        require(
            IERC165(w5006).supportsInterface(type(IWrappedIn).interfaceId),
            "not wNFT"
        );
        require(
            IERC165(w5006).supportsInterface(type(IERC5006).interfaceId),
            "not ERC5006"
        );
        require(
            IWrappedInERC5006(w5006).originalAddress() == oNFT,
            "invalid oNFT"
        );
        oNFT_w5006[oNFT] = w5006;
        IERC1155(oNFT).setApprovalForAll(w5006, true);
    }

    function w5006Of(address oNFT) public view returns (address) {
        return oNFT_w5006[oNFT];
    }
}// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "./IBank.sol";

abstract contract Bank is ReentrancyGuardUpgradeable, IBank {
    address public market;
    uint256[64] private __gap;

    modifier onlyMarket() {
        require(msg.sender == market, "only market");
        _;
    }

    function bindMarket(address market_) external {
        require(market_ != address(0), "market_ cannot be Zero Address");
        if (market == address(0)) {
            market = market_;
        } else {
            require(market == market_, "market was bind");
        }
    }
}// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import {TokenType} from "../constant/TokenEnums.sol";
import "../erc5006/IERC5006.sol";

interface IBank1155 {
    struct RecordParam {
        uint256 recordId;
        TokenType tokenType;
        address oNFT;
        uint256 oNFTId;
        uint256 oNFTAmount;
        address owner;
        address user;
        uint256 expiry;
    }

    struct RentingRecord{
        TokenType tokenType;
        address oNFT;
        uint256 oNFTId;
        address lender;
        uint256 recordId;
    }

    struct Renting{
        address lender;
        uint256 amount;
    }

    event CreateUserRecord(RecordParam param);

    event DeleteUserRecord(RentingRecord param);

    function createUserRecord(RecordParam memory param) external;

    function deleteUserRecords(RentingRecord[] calldata toDeletes) external;

    function frozenAmountOf(
        address oNFT,
        uint256 oNFTId,
        address from
    ) external view returns (uint256);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/utils/ERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../IERC1155Receiver.sol";
import "../../../utils/introspection/ERC165.sol";

/**
 * @dev _Available since v3.1._
 */
abstract contract ERC1155Receiver is ERC165, IERC1155Receiver {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

interface IERC5006 {
    struct UserRecord {
        uint256 tokenId;
        address owner;
        uint64 amount;
        address user;
        uint64 expiry;
    }
    /**
     * @dev Emitted when permission (for `user` to use `amount` of `tokenId` token owned by `owner`
     * until `expiry`) is given.
     */
    event CreateUserRecord(
        uint256 recordId,
        uint256 tokenId,
        uint64 amount,
        address owner,
        address user,
        uint64 expiry
    );
    /**
     * @dev Emitted when record of `recordId` is deleted. 
     */
    event DeleteUserRecord(uint256 recordId);

    /**
     * @dev Returns the usable amount of `tokenId` tokens  by `account`.
     */
    function usableBalanceOf(address account, uint256 tokenId)
        external
        view
        returns (uint256);

    /**
     * @dev Returns the amount of frozen tokens of token type `id` by `account`.
     */
    function frozenBalanceOf(address account, uint256 tokenId)
        external
        view
        returns (uint256);

    /**
     * @dev Returns the `UserRecord` of `recordId`.
     */
    function userRecordOf(uint256 recordId)
        external
        view
        returns (UserRecord memory);

    /**
     * @dev Gives permission to `user` to use `amount` of `tokenId` token owned by `owner` until `expiry`.
     *
     * Emits a {CreateUserRecord} event.
     *
     * Requirements:
     *
     * - If the caller is not `owner`, it must be have been approved to spend ``owner``'s tokens
     * via {setApprovalForAll}.
     * - `owner` must have a balance of tokens of type `id` of at least `amount`.
     * - `user` cannot be the zero address.
     * - `amount` must be greater than 0.
     * - `expiry` must after the block timestamp.
     */
    function createUserRecord(
        address owner,
        address user,
        uint256 tokenId,
        uint64 amount,
        uint64 expiry
    ) external returns (uint256);

    /**
     * @dev Atomically delete `record` of `recordId` by the caller.
     *
     * Emits a {DeleteUserRecord} event.
     *
     * Requirements:
     *
     * - the caller must have allowance.
     */
    function deleteUserRecord(uint256 recordId) external;
}// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "./IWrappedIn.sol";
import "./IERC5006.sol";

interface IWrappedInERC5006 is IERC5006, IWrappedIn {
    function stakeAndCreateUserRecord(
        uint256 tokenId,
        uint64 amount,
        address to,
        uint64 expiry
    ) external returns (uint256);

    function redeemRecord(uint256 recordId, address to) external;

    function originalAddress() external view returns (address);
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {TokenType} from "../constant/TokenEnums.sol";
import {NFT} from "../constant/BaseStructs.sol";

interface IBank is IERC165 {
    function bindMarket(address market_) external;
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.13;

enum TokenType {
    ERC721,
    ERC721_subNFT, //Reserved Field
    ERC721_vNFT, //Reserved Field
    ERC1155,
    ERC4907,
    ERC5006,
    ERC20,
    NATIVE
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.13;

import {TokenType} from "./TokenEnums.sol";

enum SignatureVersion {
    EIP712,
    EIP1271
}

struct NFT {
    TokenType tokenType;
    address token;
    uint256 tokenId;
    uint256 amount;
}

struct Fee {
    uint16 rate;
    address payable recipient;
}

struct Signature {
    bytes signature;
    SignatureVersion signatureVersion;
}

struct Metadata {
    bytes32 metadataHash;
    address checker;
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}