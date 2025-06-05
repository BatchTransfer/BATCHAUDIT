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


// File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT
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
}


// File: @openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/utils/ERC1155Holder.sol)

pragma solidity ^0.8.0;

import "./ERC1155Receiver.sol";

/**
 * Simple implementation of `ERC1155Receiver` that will allow a contract to hold ERC1155 tokens.
 *
 * IMPORTANT: When inheriting this contract, you must include a way to use the received tokens, otherwise they will be
 * stuck.
 *
 * @dev _Available since v3.1._
 */
contract ERC1155Holder is ERC1155Receiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}


// File: @openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol
// SPDX-License-Identifier: MIT
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
}


// File: @openzeppelin/contracts/utils/Context.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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
}


// File: @openzeppelin/contracts/utils/introspection/ERC165.sol
// SPDX-License-Identifier: MIT
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


// File: contracts/bridge/ERC1155LockerProxy.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import { IReceiverVerifier } from "../nfts/IReceiverVerifier.sol";
import { RouterEndpoint } from "../nfts/Structs.sol";
import { IERC1155Router } from "./interfaces/IERC1155Router.sol";
import { IERC1155LockerProxy } from "./interfaces/IERC1155LockerProxy.sol";

contract ERC1155LockerProxy is
    IERC1155LockerProxy,
    IReceiverVerifier,
    Ownable,
    ERC1155Holder
{
    /// @notice Address of ERC1155 contract.
    IERC1155 public immutable erc1155;

    /// @notice Router contract that send off cross chain message.
    address public router;

    /**
     * @param _router Router address
     * @param _erc1155 Erc1155 address
     */
    constructor(address _router, IERC1155 _erc1155) {
        router = _router;
        erc1155 = _erc1155;
    }

    receive() external payable {}

    /**
     * @notice Bridges over asset from the src address to destination address to destination chain.
     * @dev User has to setApprovalForAll to this contract first
     * @param _from The address that is bridging assets
     * @param _dstChainId Destination chain id
     * @param _to Destination address that will receive the assets
     * @param _tokenId Token id being bridged
     * @param _amount Amount of the token id being bridged
     */
    function sendFrom(
        address _from,
        uint16 _dstChainId,
        address _to,
        uint _tokenId,
        uint _amount
    ) external payable {
        _sendFrom(
            _from,
            _dstChainId,
            _to,
            _toSingletonArray(_tokenId),
            _toSingletonArray(_amount)
        );
    }

    /**
     * @notice Bridges over assets from the src address to destination address to destination chain.
     * @dev User has to setApprovalForAll to this contract first
     * @param _from The address that is bridging assets
     * @param _dstChainId Destination chain id
     * @param _to Destination address that will receive the assets
     * @param _tokenIds Token ids being bridged
     * @param _amounts Amounts of each token id being bridged
     */
    function sendBatchFrom(
        address _from,
        uint16 _dstChainId,
        address _to,
        uint[] memory _tokenIds,
        uint[] memory _amounts
    ) external payable {
        _sendFrom(_from, _dstChainId, _to, _tokenIds, _amounts);
    }

    /**
     * @notice Invoke handler
     * @param _from The address that is bridging assets
     * @param _ethValue Eth amount being passed in
     * @param _tokenIds Token ids to bridge
     * @param _tokenQuantities Amounts of each token id
     * @param _data arbitrary data that contains destination address and chain
     */
    function handleInvoke(
        address _from,
        RouterEndpoint calldata,
        uint256 _ethValue,
        uint256,
        uint256[] calldata _tokenIds,
        uint256[] calldata _tokenQuantities,
        bytes memory _data
    ) external {
        if (msg.sender != address(erc1155)) revert InvalidCaller();

        (address to, uint16 dstChainId) = abi.decode(_data, (address, uint16));

        _routerSend(
            _from,
            dstChainId,
            to,
            _tokenIds,
            _tokenQuantities,
            _ethValue
        );
    }

    /**
     * @notice Called by the Router when a message is received
     * @param _to The address that will have its tokens unlocked
     * @param _tokenIds TokenIds to unlock
     * @param _amounts Amount of tokens to unlock
     */
    function unlock(
        address _to,
        uint16 _srcChainId,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    ) external {
        if (msg.sender != router) revert InvalidCaller();

        erc1155.safeBatchTransferFrom(
            address(this),
            _to,
            _tokenIds,
            _amounts,
            ""
        );

        emit AssetsUnlocked(_to, _srcChainId, _tokenIds, _amounts);
    }

    /**
     * @notice Sets new router address
     * @dev Only callable by the owner.
     * @param _router new router address
     */
    function setRouter(address _router) external onlyOwner {
        router = _router;
        emit RouterSet(_router);
    }

    /**
     * @notice Helper function that checks for approval
     * @param _from The address that is bridging assets
     * @param _dstChainId Destination chain id
     * @param _to Destination address that will receive the assets
     * @param _tokenIds Token ids being bridged
     * @param _amounts Amounts of each token id being bridged
     */
    function _sendFrom(
        address _from,
        uint16 _dstChainId,
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) internal {
        if (
            _from != _msgSender() &&
            !erc1155.isApprovedForAll(_from, _msgSender())
        ) {
            revert InvalidCaller();
        }

        erc1155.safeBatchTransferFrom(
            _from,
            address(this),
            _tokenIds,
            _amounts,
            ""
        );

        _routerSend(_from, _dstChainId, _to, _tokenIds, _amounts, msg.value);
    }

    /**
     * @notice Helper function that calls the router
     * @param _from The address that is bridging assets
     * @param _dstChainId Destination chain id
     * @param _to Destination address that will receive the assets
     * @param _tokenIds Token ids being bridged
     * @param _amounts Amounts of each token id being bridged
     * @param _ethValue The amount of eth passed for paying bridging fees
     */
    function _routerSend(
        address _from,
        uint16 _dstChainId,
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        uint256 _ethValue
    ) internal {
        IERC1155Router(router).send{ value: _ethValue }(
            _from,
            _to,
            _dstChainId,
            _tokenIds,
            _amounts
        );

        emit AssetsLocked(_from, _to, _dstChainId, _tokenIds, _amounts);
    }

    /**
     * @notice Helper function to convert an element to a singleton list
     * @param _element The element to convert
     */
    function _toSingletonArray(
        uint256 _element
    ) internal pure returns (uint[] memory) {
        uint[] memory array = new uint[](1);
        array[0] = _element;
        return array;
    }
}


// File: contracts/bridge/interfaces/IERC1155LockerProxy.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IERC1155LockerProxy {
    /**
     * @dev Raised when called by invalid caller
     */
    error InvalidCaller();

    event RouterSet(address indexed _router);
    event AssetsLocked(
        address indexed from,
        address indexed to,
        uint16 srcChainId,
        uint256[] tokenIds,
        uint256[] amounts
    );
    event AssetsUnlocked(
        address indexed to,
        uint16 srcChainId,
        uint256[] tokenIds,
        uint256[] amounts
    );

    function unlock(
        address _to,
        uint16 _srcChainId,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    ) external;
}


// File: contracts/bridge/interfaces/IERC1155Router.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IERC1155Router {
    event SendBatchToChain(
        uint16 indexed dstChainId,
        address indexed from,
        address indexed toAddress,
        uint[] tokenIds,
        uint[] amounts
    );
    event ReceiveBatchFromChain(
        uint16 indexed _srcChainId,
        address indexed _srcAddress,
        address indexed _toAddress,
        uint[] _tokenIds,
        uint[] _amounts
    );
    event LockerProxySet(address indexed lockerProxy);

    /**
     * @dev Raised when called by invalid caller
     */
    error InvalidCaller();

    error Unauthorized();

    function send(
        address _from,
        address _to,
        uint16 _dstChainId,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) external payable;
}


// File: contracts/bridge/ParallelPlanetfallLockerProxy.sol
pragma solidity 0.8.17;
// SPDX-License-Identifier: MIT

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155LockerProxy } from "./ERC1155LockerProxy.sol";

/// @title The Parallel Planetfall Locker Proxy contract.
/// @notice Used for bridging Parallel Planetfall nfts.
contract ParallelPlanetfallLockerProxy is ERC1155LockerProxy {
    /**
     * @param _router Router address
     * @param _erc1155 Erc1155 address
     */
    constructor(
        address _router,
        IERC1155 _erc1155
    ) ERC1155LockerProxy(_router, _erc1155) {}
}


// File: contracts/nfts/IReceiverVerifier.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Structs.sol";

interface IReceiverVerifier {
    function handleInvoke(
        address _userAddress,
        RouterEndpoint memory _routerEndpoint,
        uint256 _ethValue,
        uint256 _primeValue,
        uint256[] memory _tokenIds,
        uint256[] memory _tokenQuantities,
        bytes memory _data
    ) external;
}


// File: contracts/nfts/Structs.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

struct RouterEndpoint {
    address nftReceiver;
    address ethReceiver;
    address primeReceiver;
    address verifier;
}


