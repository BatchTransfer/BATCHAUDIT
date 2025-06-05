// Chain: POLYGON - File: @ensdomains/buffer/contracts/Buffer.sol
// SPDX-License-Identifier: BSD-2-Clause
pragma solidity ^0.8.4;

/**
* @dev A library for working with mutable byte buffers in Solidity.
*
* Byte buffers are mutable and expandable, and provide a variety of primitives
* for appending to them. At any time you can fetch a bytes object containing the
* current contents of the buffer. The bytes object should not be stored between
* operations, as it may change due to resizing of the buffer.
*/
library Buffer {
    /**
    * @dev Represents a mutable buffer. Buffers have a current value (buf) and
    *      a capacity. The capacity may be longer than the current value, in
    *      which case it can be extended without the need to allocate more memory.
    */
    struct buffer {
        bytes buf;
        uint capacity;
    }

    /**
    * @dev Initializes a buffer with an initial capacity.
    * @param buf The buffer to initialize.
    * @param capacity The number of bytes of space to allocate the buffer.
    * @return The buffer, for chaining.
    */
    function init(buffer memory buf, uint capacity) internal pure returns(buffer memory) {
        if (capacity % 32 != 0) {
            capacity += 32 - (capacity % 32);
        }
        // Allocate space for the buffer data
        buf.capacity = capacity;
        assembly {
            let ptr := mload(0x40)
            mstore(buf, ptr)
            mstore(ptr, 0)
            let fpm := add(32, add(ptr, capacity))
            if lt(fpm, ptr) {
                revert(0, 0)
            }
            mstore(0x40, fpm)
        }
        return buf;
    }

    /**
    * @dev Initializes a new buffer from an existing bytes object.
    *      Changes to the buffer may mutate the original value.
    * @param b The bytes object to initialize the buffer with.
    * @return A new buffer.
    */
    function fromBytes(bytes memory b) internal pure returns(buffer memory) {
        buffer memory buf;
        buf.buf = b;
        buf.capacity = b.length;
        return buf;
    }

    function resize(buffer memory buf, uint capacity) private pure {
        bytes memory oldbuf = buf.buf;
        init(buf, capacity);
        append(buf, oldbuf);
    }

    /**
    * @dev Sets buffer length to 0.
    * @param buf The buffer to truncate.
    * @return The original buffer, for chaining..
    */
    function truncate(buffer memory buf) internal pure returns (buffer memory) {
        assembly {
            let bufptr := mload(buf)
            mstore(bufptr, 0)
        }
        return buf;
    }

    /**
    * @dev Appends len bytes of a byte string to a buffer. Resizes if doing so would exceed
    *      the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @param len The number of bytes to copy.
    * @return The original buffer, for chaining.
    */
    function append(buffer memory buf, bytes memory data, uint len) internal pure returns(buffer memory) {
        require(len <= data.length);

        uint off = buf.buf.length;
        uint newCapacity = off + len;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        uint dest;
        uint src;
        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Length of existing buffer data
            let buflen := mload(bufptr)
            // Start address = buffer address + offset + sizeof(buffer length)
            dest := add(add(bufptr, 32), off)
            // Update buffer length if we're extending it
            if gt(newCapacity, buflen) {
                mstore(bufptr, newCapacity)
            }
            src := add(data, 32)
        }

        // Copy word-length chunks while possible
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        unchecked {
            uint mask = (256 ** (32 - len)) - 1;
            assembly {
                let srcpart := and(mload(src), not(mask))
                let destpart := and(mload(dest), mask)
                mstore(dest, or(destpart, srcpart))
            }
        }

        return buf;
    }

    /**
    * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
    *      the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @return The original buffer, for chaining.
    */
    function append(buffer memory buf, bytes memory data) internal pure returns (buffer memory) {
        return append(buf, data, data.length);
    }

    /**
    * @dev Appends a byte to the buffer. Resizes if doing so would exceed the
    *      capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @return The original buffer, for chaining.
    */
    function appendUint8(buffer memory buf, uint8 data) internal pure returns(buffer memory) {
        uint off = buf.buf.length;
        uint offPlusOne = off + 1;
        if (off >= buf.capacity) {
            resize(buf, offPlusOne * 2);
        }

        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Address = buffer address + sizeof(buffer length) + off
            let dest := add(add(bufptr, off), 32)
            mstore8(dest, data)
            // Update buffer length if we extended it
            if gt(offPlusOne, mload(bufptr)) {
                mstore(bufptr, offPlusOne)
            }
        }

        return buf;
    }

    /**
    * @dev Appends len bytes of bytes32 to a buffer. Resizes if doing so would
    *      exceed the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @param len The number of bytes to write (left-aligned).
    * @return The original buffer, for chaining.
    */
    function append(buffer memory buf, bytes32 data, uint len) private pure returns(buffer memory) {
        uint off = buf.buf.length;
        uint newCapacity = len + off;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        unchecked {
            uint mask = (256 ** len) - 1;
            // Right-align data
            data = data >> (8 * (32 - len));
            assembly {
                // Memory address of the buffer data
                let bufptr := mload(buf)
                // Address = buffer address + sizeof(buffer length) + newCapacity
                let dest := add(bufptr, newCapacity)
                mstore(dest, or(and(mload(dest), not(mask)), data))
                // Update buffer length if we extended it
                if gt(newCapacity, mload(bufptr)) {
                    mstore(bufptr, newCapacity)
                }
            }
        }
        return buf;
    }

    /**
    * @dev Appends a bytes20 to the buffer. Resizes if doing so would exceed
    *      the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @return The original buffer, for chhaining.
    */
    function appendBytes20(buffer memory buf, bytes20 data) internal pure returns (buffer memory) {
        return append(buf, bytes32(data), 20);
    }

    /**
    * @dev Appends a bytes32 to the buffer. Resizes if doing so would exceed
    *      the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @return The original buffer, for chaining.
    */
    function appendBytes32(buffer memory buf, bytes32 data) internal pure returns (buffer memory) {
        return append(buf, data, 32);
    }

    /**
     * @dev Appends a byte to the end of the buffer. Resizes if doing so would
     *      exceed the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @param len The number of bytes to write (right-aligned).
     * @return The original buffer.
     */
    function appendInt(buffer memory buf, uint data, uint len) internal pure returns(buffer memory) {
        uint off = buf.buf.length;
        uint newCapacity = len + off;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        uint mask = (256 ** len) - 1;
        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Address = buffer address + sizeof(buffer length) + newCapacity
            let dest := add(bufptr, newCapacity)
            mstore(dest, or(and(mload(dest), not(mask)), data))
            // Update buffer length if we extended it
            if gt(newCapacity, mload(bufptr)) {
                mstore(bufptr, newCapacity)
            }
        }
        return buf;
    }
}


// Chain: POLYGON - File: @ensdomains/solsha1/contracts/SHA1.sol
pragma solidity ^0.8.4;

library SHA1 {
    event Debug(bytes32 x);

    function sha1(bytes memory data) internal pure returns(bytes20 ret) {
        assembly {
            // Get a safe scratch location
            let scratch := mload(0x40)

            // Get the data length, and point data at the first byte
            let len := mload(data)
            data := add(data, 32)

            // Find the length after padding
            let totallen := add(and(add(len, 1), 0xFFFFFFFFFFFFFFC0), 64)
            switch lt(sub(totallen, len), 9)
            case 1 { totallen := add(totallen, 64) }

            let h := 0x6745230100EFCDAB890098BADCFE001032547600C3D2E1F0

            function readword(ptr, off, count) -> result {
                result := 0
                if lt(off, count) {
                    result := mload(add(ptr, off))
                    count := sub(count, off)
                    if lt(count, 32) {
                        let mask := not(sub(exp(256, sub(32, count)), 1))
                        result := and(result, mask)
                    }
                }
            }

            for { let i := 0 } lt(i, totallen) { i := add(i, 64) } {
                mstore(scratch, readword(data, i, len))
                mstore(add(scratch, 32), readword(data, add(i, 32), len))

                // If we loaded the last byte, store the terminator byte
                switch lt(sub(len, i), 64)
                case 1 { mstore8(add(scratch, sub(len, i)), 0x80) }

                // If this is the last block, store the length
                switch eq(i, sub(totallen, 64))
                case 1 { mstore(add(scratch, 32), or(mload(add(scratch, 32)), mul(len, 8))) }

                // Expand the 16 32-bit words into 80
                for { let j := 64 } lt(j, 128) { j := add(j, 12) } {
                    let temp := xor(xor(mload(add(scratch, sub(j, 12))), mload(add(scratch, sub(j, 32)))), xor(mload(add(scratch, sub(j, 56))), mload(add(scratch, sub(j, 64)))))
                    temp := or(and(mul(temp, 2), 0xFFFFFFFEFFFFFFFEFFFFFFFEFFFFFFFEFFFFFFFEFFFFFFFEFFFFFFFEFFFFFFFE), and(div(temp, 0x80000000), 0x0000000100000001000000010000000100000001000000010000000100000001))
                    mstore(add(scratch, j), temp)
                }
                for { let j := 128 } lt(j, 320) { j := add(j, 24) } {
                    let temp := xor(xor(mload(add(scratch, sub(j, 24))), mload(add(scratch, sub(j, 64)))), xor(mload(add(scratch, sub(j, 112))), mload(add(scratch, sub(j, 128)))))
                    temp := or(and(mul(temp, 4), 0xFFFFFFFCFFFFFFFCFFFFFFFCFFFFFFFCFFFFFFFCFFFFFFFCFFFFFFFCFFFFFFFC), and(div(temp, 0x40000000), 0x0000000300000003000000030000000300000003000000030000000300000003))
                    mstore(add(scratch, j), temp)
                }

                let x := h
                let f := 0
                let k := 0
                for { let j := 0 } lt(j, 80) { j := add(j, 1) } {
                    switch div(j, 20)
                    case 0 {
                        // f = d xor (b and (c xor d))
                        f := xor(div(x, 0x100000000000000000000), div(x, 0x10000000000))
                        f := and(div(x, 0x1000000000000000000000000000000), f)
                        f := xor(div(x, 0x10000000000), f)
                        k := 0x5A827999
                    }
                    case 1{
                        // f = b xor c xor d
                        f := xor(div(x, 0x1000000000000000000000000000000), div(x, 0x100000000000000000000))
                        f := xor(div(x, 0x10000000000), f)
                        k := 0x6ED9EBA1
                    }
                    case 2 {
                        // f = (b and c) or (d and (b or c))
                        f := or(div(x, 0x1000000000000000000000000000000), div(x, 0x100000000000000000000))
                        f := and(div(x, 0x10000000000), f)
                        f := or(and(div(x, 0x1000000000000000000000000000000), div(x, 0x100000000000000000000)), f)
                        k := 0x8F1BBCDC
                    }
                    case 3 {
                        // f = b xor c xor d
                        f := xor(div(x, 0x1000000000000000000000000000000), div(x, 0x100000000000000000000))
                        f := xor(div(x, 0x10000000000), f)
                        k := 0xCA62C1D6
                    }
                    // temp = (a leftrotate 5) + f + e + k + w[i]
                    let temp := and(div(x, 0x80000000000000000000000000000000000000000000000), 0x1F)
                    temp := or(and(div(x, 0x800000000000000000000000000000000000000), 0xFFFFFFE0), temp)
                    temp := add(f, temp)
                    temp := add(and(x, 0xFFFFFFFF), temp)
                    temp := add(k, temp)
                    temp := add(div(mload(add(scratch, mul(j, 4))), 0x100000000000000000000000000000000000000000000000000000000), temp)
                    x := or(div(x, 0x10000000000), mul(temp, 0x10000000000000000000000000000000000000000))
                    x := or(and(x, 0xFFFFFFFF00FFFFFFFF000000000000FFFFFFFF00FFFFFFFF), mul(or(and(div(x, 0x4000000000000), 0xC0000000), and(div(x, 0x400000000000000000000), 0x3FFFFFFF)), 0x100000000000000000000))
                }

                h := and(add(h, x), 0xFFFFFFFF00FFFFFFFF00FFFFFFFF00FFFFFFFF00FFFFFFFF)
            }
            ret := mul(or(or(or(or(and(div(h, 0x100000000), 0xFFFFFFFF00000000000000000000000000000000), and(div(h, 0x1000000), 0xFFFFFFFF000000000000000000000000)), and(div(h, 0x10000), 0xFFFFFFFF0000000000000000)), and(div(h, 0x100), 0xFFFFFFFF00000000)), and(h, 0xFFFFFFFF)), 0x1000000000000000000000000)
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC20/ERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC20/IERC20.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC721/ERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to] += 1;
        }

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId, 1);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner = ERC721.ownerOf(tokenId);

        // Clear approvals
        delete _tokenApprovals[tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId, 1);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256, /* firstTokenId */
        uint256 batchSize
    ) internal virtual {
        if (batchSize > 1) {
            if (from != address(0)) {
                _balances[from] -= batchSize;
            }
            if (to != address(0)) {
                _balances[to] += batchSize;
            }
        }
    }

    /**
     * @dev Hook that is called after any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens were transferred to `to`.
     * - When `from` is zero, the tokens were minted for `to`.
     * - When `to` is zero, ``from``'s tokens were burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual {}
}


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}


// Chain: POLYGON - File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts/utils/Context.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/utils/introspection/ERC165.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/utils/introspection/IERC165.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/utils/math/Math.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts/utils/Strings.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/algorithms/Algorithm.sol
pragma solidity ^0.8.4;

/**
 * @dev An interface for contracts implementing a DNSSEC (signing) algorithm.
 */
interface Algorithm {
    /**
     * @dev Verifies a signature.
     * @param key The public key to verify with.
     * @param data The signed data to verify.
     * @param signature The signature to verify.
     * @return True iff the signature is valid.
     */
    function verify(
        bytes calldata key,
        bytes calldata data,
        bytes calldata signature
    ) external view virtual returns (bool);
}


// Chain: POLYGON - File: contracts/dnssec-oracle/algorithms/DummyAlgorithm.sol
pragma solidity ^0.8.4;

import "./Algorithm.sol";

/**
 * @dev Implements a dummy DNSSEC (signing) algorithm that approves all
 *      signatures, for testing.
 */
contract DummyAlgorithm is Algorithm {
    function verify(
        bytes calldata,
        bytes calldata,
        bytes calldata
    ) external view override returns (bool) {
        return true;
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/algorithms/EllipticCurve.sol
pragma solidity ^0.8.4;

/**
 * @title   EllipticCurve
 *
 * @author  Tilman Drerup;
 *
 * @notice  Implements elliptic curve math; Parametrized for SECP256R1.
 *
 *          Includes components of code by Andreas Olofsson, Alexander Vlasov
 *          (https://github.com/BANKEX/CurveArithmetics), and Avi Asayag
 *          (https://github.com/orbs-network/elliptic-curve-solidity)
 *
 *          Source: https://github.com/tdrerup/elliptic-curve-solidity
 *
 * @dev     NOTE: To disambiguate public keys when verifying signatures, activate
 *          condition 'rs[1] > lowSmax' in validateSignature().
 */
contract EllipticCurve {
    // Set parameters for curve.
    uint256 constant a =
        0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC;
    uint256 constant b =
        0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B;
    uint256 constant gx =
        0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    uint256 constant gy =
        0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
    uint256 constant p =
        0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 constant n =
        0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;

    uint256 constant lowSmax =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    /**
     * @dev Inverse of u in the field of modulo m.
     */
    function inverseMod(uint256 u, uint256 m) internal pure returns (uint256) {
        unchecked {
            if (u == 0 || u == m || m == 0) return 0;
            if (u > m) u = u % m;

            int256 t1;
            int256 t2 = 1;
            uint256 r1 = m;
            uint256 r2 = u;
            uint256 q;

            while (r2 != 0) {
                q = r1 / r2;
                (t1, t2, r1, r2) = (t2, t1 - int256(q) * t2, r2, r1 - q * r2);
            }

            if (t1 < 0) return (m - uint256(-t1));

            return uint256(t1);
        }
    }

    /**
     * @dev Transform affine coordinates into projective coordinates.
     */
    function toProjectivePoint(
        uint256 x0,
        uint256 y0
    ) internal pure returns (uint256[3] memory P) {
        P[2] = addmod(0, 1, p);
        P[0] = mulmod(x0, P[2], p);
        P[1] = mulmod(y0, P[2], p);
    }

    /**
     * @dev Add two points in affine coordinates and return projective point.
     */
    function addAndReturnProjectivePoint(
        uint256 x1,
        uint256 y1,
        uint256 x2,
        uint256 y2
    ) internal pure returns (uint256[3] memory P) {
        uint256 x;
        uint256 y;
        (x, y) = add(x1, y1, x2, y2);
        P = toProjectivePoint(x, y);
    }

    /**
     * @dev Transform from projective to affine coordinates.
     */
    function toAffinePoint(
        uint256 x0,
        uint256 y0,
        uint256 z0
    ) internal pure returns (uint256 x1, uint256 y1) {
        uint256 z0Inv;
        z0Inv = inverseMod(z0, p);
        x1 = mulmod(x0, z0Inv, p);
        y1 = mulmod(y0, z0Inv, p);
    }

    /**
     * @dev Return the zero curve in projective coordinates.
     */
    function zeroProj()
        internal
        pure
        returns (uint256 x, uint256 y, uint256 z)
    {
        return (0, 1, 0);
    }

    /**
     * @dev Return the zero curve in affine coordinates.
     */
    function zeroAffine() internal pure returns (uint256 x, uint256 y) {
        return (0, 0);
    }

    /**
     * @dev Check if the curve is the zero curve.
     */
    function isZeroCurve(
        uint256 x0,
        uint256 y0
    ) internal pure returns (bool isZero) {
        if (x0 == 0 && y0 == 0) {
            return true;
        }
        return false;
    }

    /**
     * @dev Check if a point in affine coordinates is on the curve.
     */
    function isOnCurve(uint256 x, uint256 y) internal pure returns (bool) {
        if (0 == x || x == p || 0 == y || y == p) {
            return false;
        }

        uint256 LHS = mulmod(y, y, p); // y^2
        uint256 RHS = mulmod(mulmod(x, x, p), x, p); // x^3

        if (a != 0) {
            RHS = addmod(RHS, mulmod(x, a, p), p); // x^3 + a*x
        }
        if (b != 0) {
            RHS = addmod(RHS, b, p); // x^3 + a*x + b
        }

        return LHS == RHS;
    }

    /**
     * @dev Double an elliptic curve point in projective coordinates. See
     * https://www.nayuki.io/page/elliptic-curve-point-addition-in-projective-coordinates
     */
    function twiceProj(
        uint256 x0,
        uint256 y0,
        uint256 z0
    ) internal pure returns (uint256 x1, uint256 y1, uint256 z1) {
        uint256 t;
        uint256 u;
        uint256 v;
        uint256 w;

        if (isZeroCurve(x0, y0)) {
            return zeroProj();
        }

        u = mulmod(y0, z0, p);
        u = mulmod(u, 2, p);

        v = mulmod(u, x0, p);
        v = mulmod(v, y0, p);
        v = mulmod(v, 2, p);

        x0 = mulmod(x0, x0, p);
        t = mulmod(x0, 3, p);

        z0 = mulmod(z0, z0, p);
        z0 = mulmod(z0, a, p);
        t = addmod(t, z0, p);

        w = mulmod(t, t, p);
        x0 = mulmod(2, v, p);
        w = addmod(w, p - x0, p);

        x0 = addmod(v, p - w, p);
        x0 = mulmod(t, x0, p);
        y0 = mulmod(y0, u, p);
        y0 = mulmod(y0, y0, p);
        y0 = mulmod(2, y0, p);
        y1 = addmod(x0, p - y0, p);

        x1 = mulmod(u, w, p);

        z1 = mulmod(u, u, p);
        z1 = mulmod(z1, u, p);
    }

    /**
     * @dev Add two elliptic curve points in projective coordinates. See
     * https://www.nayuki.io/page/elliptic-curve-point-addition-in-projective-coordinates
     */
    function addProj(
        uint256 x0,
        uint256 y0,
        uint256 z0,
        uint256 x1,
        uint256 y1,
        uint256 z1
    ) internal pure returns (uint256 x2, uint256 y2, uint256 z2) {
        uint256 t0;
        uint256 t1;
        uint256 u0;
        uint256 u1;

        if (isZeroCurve(x0, y0)) {
            return (x1, y1, z1);
        } else if (isZeroCurve(x1, y1)) {
            return (x0, y0, z0);
        }

        t0 = mulmod(y0, z1, p);
        t1 = mulmod(y1, z0, p);

        u0 = mulmod(x0, z1, p);
        u1 = mulmod(x1, z0, p);

        if (u0 == u1) {
            if (t0 == t1) {
                return twiceProj(x0, y0, z0);
            } else {
                return zeroProj();
            }
        }

        (x2, y2, z2) = addProj2(mulmod(z0, z1, p), u0, u1, t1, t0);
    }

    /**
     * @dev Helper function that splits addProj to avoid too many local variables.
     */
    function addProj2(
        uint256 v,
        uint256 u0,
        uint256 u1,
        uint256 t1,
        uint256 t0
    ) private pure returns (uint256 x2, uint256 y2, uint256 z2) {
        uint256 u;
        uint256 u2;
        uint256 u3;
        uint256 w;
        uint256 t;

        t = addmod(t0, p - t1, p);
        u = addmod(u0, p - u1, p);
        u2 = mulmod(u, u, p);

        w = mulmod(t, t, p);
        w = mulmod(w, v, p);
        u1 = addmod(u1, u0, p);
        u1 = mulmod(u1, u2, p);
        w = addmod(w, p - u1, p);

        x2 = mulmod(u, w, p);

        u3 = mulmod(u2, u, p);
        u0 = mulmod(u0, u2, p);
        u0 = addmod(u0, p - w, p);
        t = mulmod(t, u0, p);
        t0 = mulmod(t0, u3, p);

        y2 = addmod(t, p - t0, p);

        z2 = mulmod(u3, v, p);
    }

    /**
     * @dev Add two elliptic curve points in affine coordinates.
     */
    function add(
        uint256 x0,
        uint256 y0,
        uint256 x1,
        uint256 y1
    ) internal pure returns (uint256, uint256) {
        uint256 z0;

        (x0, y0, z0) = addProj(x0, y0, 1, x1, y1, 1);

        return toAffinePoint(x0, y0, z0);
    }

    /**
     * @dev Double an elliptic curve point in affine coordinates.
     */
    function twice(
        uint256 x0,
        uint256 y0
    ) internal pure returns (uint256, uint256) {
        uint256 z0;

        (x0, y0, z0) = twiceProj(x0, y0, 1);

        return toAffinePoint(x0, y0, z0);
    }

    /**
     * @dev Multiply an elliptic curve point by a 2 power base (i.e., (2^exp)*P)).
     */
    function multiplyPowerBase2(
        uint256 x0,
        uint256 y0,
        uint256 exp
    ) internal pure returns (uint256, uint256) {
        uint256 base2X = x0;
        uint256 base2Y = y0;
        uint256 base2Z = 1;

        for (uint256 i = 0; i < exp; i++) {
            (base2X, base2Y, base2Z) = twiceProj(base2X, base2Y, base2Z);
        }

        return toAffinePoint(base2X, base2Y, base2Z);
    }

    /**
     * @dev Multiply an elliptic curve point by a scalar.
     */
    function multiplyScalar(
        uint256 x0,
        uint256 y0,
        uint256 scalar
    ) internal pure returns (uint256 x1, uint256 y1) {
        if (scalar == 0) {
            return zeroAffine();
        } else if (scalar == 1) {
            return (x0, y0);
        } else if (scalar == 2) {
            return twice(x0, y0);
        }

        uint256 base2X = x0;
        uint256 base2Y = y0;
        uint256 base2Z = 1;
        uint256 z1 = 1;
        x1 = x0;
        y1 = y0;

        if (scalar % 2 == 0) {
            x1 = y1 = 0;
        }

        scalar = scalar >> 1;

        while (scalar > 0) {
            (base2X, base2Y, base2Z) = twiceProj(base2X, base2Y, base2Z);

            if (scalar % 2 == 1) {
                (x1, y1, z1) = addProj(base2X, base2Y, base2Z, x1, y1, z1);
            }

            scalar = scalar >> 1;
        }

        return toAffinePoint(x1, y1, z1);
    }

    /**
     * @dev Multiply the curve's generator point by a scalar.
     */
    function multipleGeneratorByScalar(
        uint256 scalar
    ) internal pure returns (uint256, uint256) {
        return multiplyScalar(gx, gy, scalar);
    }

    /**
     * @dev Validate combination of message, signature, and public key.
     */
    function validateSignature(
        bytes32 message,
        uint256[2] memory rs,
        uint256[2] memory Q
    ) internal pure returns (bool) {
        // To disambiguate between public key solutions, include comment below.
        if (rs[0] == 0 || rs[0] >= n || rs[1] == 0) {
            // || rs[1] > lowSmax)
            return false;
        }
        if (!isOnCurve(Q[0], Q[1])) {
            return false;
        }

        uint256 x1;
        uint256 x2;
        uint256 y1;
        uint256 y2;

        uint256 sInv = inverseMod(rs[1], n);
        (x1, y1) = multiplyScalar(gx, gy, mulmod(uint256(message), sInv, n));
        (x2, y2) = multiplyScalar(Q[0], Q[1], mulmod(rs[0], sInv, n));
        uint256[3] memory P = addAndReturnProjectivePoint(x1, y1, x2, y2);

        if (P[2] == 0) {
            return false;
        }

        uint256 Px = inverseMod(P[2], p);
        Px = mulmod(P[0], mulmod(Px, Px, p), p);

        return Px % n == rs[0];
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/algorithms/ModexpPrecompile.sol
pragma solidity ^0.8.4;

library ModexpPrecompile {
    /**
     * @dev Computes (base ^ exponent) % modulus over big numbers.
     */
    function modexp(
        bytes memory base,
        bytes memory exponent,
        bytes memory modulus
    ) internal view returns (bool success, bytes memory output) {
        bytes memory input = abi.encodePacked(
            uint256(base.length),
            uint256(exponent.length),
            uint256(modulus.length),
            base,
            exponent,
            modulus
        );

        output = new bytes(modulus.length);

        assembly {
            success := staticcall(
                gas(),
                5,
                add(input, 32),
                mload(input),
                add(output, 32),
                mload(modulus)
            )
        }
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/algorithms/P256SHA256Algorithm.sol
pragma solidity ^0.8.4;

import "./Algorithm.sol";
import "./EllipticCurve.sol";
import "../../utils/BytesUtils.sol";

contract P256SHA256Algorithm is Algorithm, EllipticCurve {
    using BytesUtils for *;

    /**
     * @dev Verifies a signature.
     * @param key The public key to verify with.
     * @param data The signed data to verify.
     * @param signature The signature to verify.
     * @return True iff the signature is valid.
     */
    function verify(
        bytes calldata key,
        bytes calldata data,
        bytes calldata signature
    ) external view override returns (bool) {
        return
            validateSignature(
                sha256(data),
                parseSignature(signature),
                parseKey(key)
            );
    }

    function parseSignature(
        bytes memory data
    ) internal pure returns (uint256[2] memory) {
        require(data.length == 64, "Invalid p256 signature length");
        return [uint256(data.readBytes32(0)), uint256(data.readBytes32(32))];
    }

    function parseKey(
        bytes memory data
    ) internal pure returns (uint256[2] memory) {
        require(data.length == 68, "Invalid p256 key length");
        return [uint256(data.readBytes32(4)), uint256(data.readBytes32(36))];
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/algorithms/RSASHA1Algorithm.sol
pragma solidity ^0.8.4;

import "./Algorithm.sol";
import "./RSAVerify.sol";
import "../../utils/BytesUtils.sol";
import "@ensdomains/solsha1/contracts/SHA1.sol";

/**
 * @dev Implements the DNSSEC RSASHA1 algorithm.
 */
contract RSASHA1Algorithm is Algorithm {
    using BytesUtils for *;

    function verify(
        bytes calldata key,
        bytes calldata data,
        bytes calldata sig
    ) external view override returns (bool) {
        bytes memory exponent;
        bytes memory modulus;

        uint16 exponentLen = uint16(key.readUint8(4));
        if (exponentLen != 0) {
            exponent = key.substring(5, exponentLen);
            modulus = key.substring(
                exponentLen + 5,
                key.length - exponentLen - 5
            );
        } else {
            exponentLen = key.readUint16(5);
            exponent = key.substring(7, exponentLen);
            modulus = key.substring(
                exponentLen + 7,
                key.length - exponentLen - 7
            );
        }

        // Recover the message from the signature
        bool ok;
        bytes memory result;
        (ok, result) = RSAVerify.rsarecover(modulus, exponent, sig);

        // Verify it ends with the hash of our data
        return ok && SHA1.sha1(data) == result.readBytes20(result.length - 20);
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/algorithms/RSASHA256Algorithm.sol
pragma solidity ^0.8.4;

import "./Algorithm.sol";
import "./RSAVerify.sol";
import "../../utils/BytesUtils.sol";

/**
 * @dev Implements the DNSSEC RSASHA256 algorithm.
 */
contract RSASHA256Algorithm is Algorithm {
    using BytesUtils for *;

    function verify(
        bytes calldata key,
        bytes calldata data,
        bytes calldata sig
    ) external view override returns (bool) {
        bytes memory exponent;
        bytes memory modulus;

        uint16 exponentLen = uint16(key.readUint8(4));
        if (exponentLen != 0) {
            exponent = key.substring(5, exponentLen);
            modulus = key.substring(
                exponentLen + 5,
                key.length - exponentLen - 5
            );
        } else {
            exponentLen = key.readUint16(5);
            exponent = key.substring(7, exponentLen);
            modulus = key.substring(
                exponentLen + 7,
                key.length - exponentLen - 7
            );
        }

        // Recover the message from the signature
        bool ok;
        bytes memory result;
        (ok, result) = RSAVerify.rsarecover(modulus, exponent, sig);

        // Verify it ends with the hash of our data
        return ok && sha256(data) == result.readBytes32(result.length - 32);
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/algorithms/RSAVerify.sol
pragma solidity ^0.8.4;

import "./ModexpPrecompile.sol";
import "../../utils/BytesUtils.sol";

library RSAVerify {
    /**
     * @dev Recovers the input data from an RSA signature, returning the result in S.
     * @param N The RSA public modulus.
     * @param E The RSA public exponent.
     * @param S The signature to recover.
     * @return True if the recovery succeeded.
     */
    function rsarecover(
        bytes memory N,
        bytes memory E,
        bytes memory S
    ) internal view returns (bool, bytes memory) {
        return ModexpPrecompile.modexp(S, E, N);
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/digests/Digest.sol
pragma solidity ^0.8.4;

/**
 * @dev An interface for contracts implementing a DNSSEC digest.
 */
interface Digest {
    /**
     * @dev Verifies a cryptographic hash.
     * @param data The data to hash.
     * @param hash The hash to compare to.
     * @return True iff the hashed data matches the provided hash value.
     */
    function verify(
        bytes calldata data,
        bytes calldata hash
    ) external pure virtual returns (bool);
}


// Chain: POLYGON - File: contracts/dnssec-oracle/digests/DummyDigest.sol
pragma solidity ^0.8.4;

import "./Digest.sol";

/**
 * @dev Implements a dummy DNSSEC digest that approves all hashes, for testing.
 */
contract DummyDigest is Digest {
    function verify(
        bytes calldata,
        bytes calldata
    ) external pure override returns (bool) {
        return true;
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/digests/SHA1Digest.sol
pragma solidity ^0.8.4;

import "./Digest.sol";
import "../../utils/BytesUtils.sol";
import "@ensdomains/solsha1/contracts/SHA1.sol";

/**
 * @dev Implements the DNSSEC SHA1 digest.
 */
contract SHA1Digest is Digest {
    using BytesUtils for *;

    function verify(
        bytes calldata data,
        bytes calldata hash
    ) external pure override returns (bool) {
        require(hash.length == 20, "Invalid sha1 hash length");
        bytes32 expected = hash.readBytes20(0);
        bytes20 computed = SHA1.sha1(data);
        return expected == computed;
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/digests/SHA256Digest.sol
pragma solidity ^0.8.4;

import "./Digest.sol";
import "../../utils/BytesUtils.sol";

/**
 * @dev Implements the DNSSEC SHA256 digest.
 */
contract SHA256Digest is Digest {
    using BytesUtils for *;

    function verify(
        bytes calldata data,
        bytes calldata hash
    ) external pure override returns (bool) {
        require(hash.length == 32, "Invalid sha256 hash length");
        return sha256(data) == hash.readBytes32(0);
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/DNSSEC.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

abstract contract DNSSEC {
    bytes public anchors;

    struct RRSetWithSignature {
        bytes rrset;
        bytes sig;
    }

    event AlgorithmUpdated(uint8 id, address addr);
    event DigestUpdated(uint8 id, address addr);

    function verifyRRSet(
        RRSetWithSignature[] memory input
    ) external view virtual returns (bytes memory rrs, uint32 inception);

    function verifyRRSet(
        RRSetWithSignature[] memory input,
        uint256 now
    ) public view virtual returns (bytes memory rrs, uint32 inception);
}


// Chain: POLYGON - File: contracts/dnssec-oracle/DNSSECImpl.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "./Owned.sol";
import "./RRUtils.sol";
import "./DNSSEC.sol";
import "./algorithms/Algorithm.sol";
import "./digests/Digest.sol";
import "../utils/BytesUtils.sol";
import "@ensdomains/buffer/contracts/Buffer.sol";

/*
 * @dev An oracle contract that verifies and stores DNSSEC-validated DNS records.
 * @note This differs from the DNSSEC spec defined in RFC4034 and RFC4035 in some key regards:
 *       - NSEC & NSEC3 are not supported; only positive proofs are allowed.
 *       - Proofs involving wildcard names will not validate.
 *       - TTLs on records are ignored, as data is not stored persistently.
 *       - Canonical form of names is not checked; in ENS this is done on the frontend, so submitting
 *         proofs with non-canonical names will only result in registering unresolvable ENS names.
 */
contract DNSSECImpl is DNSSEC, Owned {
    using Buffer for Buffer.buffer;
    using BytesUtils for bytes;
    using RRUtils for *;

    uint16 constant DNSCLASS_IN = 1;

    uint16 constant DNSTYPE_DS = 43;
    uint16 constant DNSTYPE_DNSKEY = 48;

    uint256 constant DNSKEY_FLAG_ZONEKEY = 0x100;

    error InvalidLabelCount(bytes name, uint256 labelsExpected);
    error SignatureNotValidYet(uint32 inception, uint32 now);
    error SignatureExpired(uint32 expiration, uint32 now);
    error InvalidClass(uint16 class);
    error InvalidRRSet();
    error SignatureTypeMismatch(uint16 rrsetType, uint16 sigType);
    error InvalidSignerName(bytes rrsetName, bytes signerName);
    error InvalidProofType(uint16 proofType);
    error ProofNameMismatch(bytes signerName, bytes proofName);
    error NoMatchingProof(bytes signerName);

    mapping(uint8 => Algorithm) public algorithms;
    mapping(uint8 => Digest) public digests;

    /**
     * @dev Constructor.
     * @param _anchors The binary format RR entries for the root DS records.
     */
    constructor(bytes memory _anchors) {
        // Insert the 'trust anchors' - the key hashes that start the chain
        // of trust for all other records.
        anchors = _anchors;
    }

    /**
     * @dev Sets the contract address for a signature verification algorithm.
     *      Callable only by the owner.
     * @param id The algorithm ID
     * @param algo The address of the algorithm contract.
     */
    function setAlgorithm(uint8 id, Algorithm algo) public owner_only {
        algorithms[id] = algo;
        emit AlgorithmUpdated(id, address(algo));
    }

    /**
     * @dev Sets the contract address for a digest verification algorithm.
     *      Callable only by the owner.
     * @param id The digest ID
     * @param digest The address of the digest contract.
     */
    function setDigest(uint8 id, Digest digest) public owner_only {
        digests[id] = digest;
        emit DigestUpdated(id, address(digest));
    }

    /**
     * @dev Takes a chain of signed DNS records, verifies them, and returns the data from the last record set in the chain.
     *      Reverts if the records do not form an unbroken chain of trust to the DNSSEC anchor records.
     * @param input A list of signed RRSets.
     * @return rrs The RRData from the last RRSet in the chain.
     * @return inception The inception time of the signed record set.
     */
    function verifyRRSet(
        RRSetWithSignature[] memory input
    )
        external
        view
        virtual
        override
        returns (bytes memory rrs, uint32 inception)
    {
        return verifyRRSet(input, block.timestamp);
    }

    /**
     * @dev Takes a chain of signed DNS records, verifies them, and returns the data from the last record set in the chain.
     *      Reverts if the records do not form an unbroken chain of trust to the DNSSEC anchor records.
     * @param input A list of signed RRSets.
     * @param now The Unix timestamp to validate the records at.
     * @return rrs The RRData from the last RRSet in the chain.
     * @return inception The inception time of the signed record set.
     */
    function verifyRRSet(
        RRSetWithSignature[] memory input,
        uint256 now
    )
        public
        view
        virtual
        override
        returns (bytes memory rrs, uint32 inception)
    {
        bytes memory proof = anchors;
        for (uint256 i = 0; i < input.length; i++) {
            RRUtils.SignedSet memory rrset = validateSignedSet(
                input[i],
                proof,
                now
            );
            proof = rrset.data;
            inception = rrset.inception;
        }
        return (proof, inception);
    }

    /**
     * @dev Validates an RRSet against the already trusted RR provided in `proof`.
     *
     * @param input The signed RR set. This is in the format described in section
     *        5.3.2 of RFC4035: The RRDATA section from the RRSIG without the signature
     *        data, followed by a series of canonicalised RR records that the signature
     *        applies to.
     * @param proof The DNSKEY or DS to validate the signature against.
     * @param now The current timestamp.
     */
    function validateSignedSet(
        RRSetWithSignature memory input,
        bytes memory proof,
        uint256 now
    ) internal view returns (RRUtils.SignedSet memory rrset) {
        rrset = input.rrset.readSignedSet();

        // Do some basic checks on the RRs and extract the name
        bytes memory name = validateRRs(rrset, rrset.typeCovered);
        if (name.labelCount(0) != rrset.labels) {
            revert InvalidLabelCount(name, rrset.labels);
        }
        rrset.name = name;

        // All comparisons involving the Signature Expiration and
        // Inception fields MUST use "serial number arithmetic", as
        // defined in RFC 1982

        // o  The validator's notion of the current time MUST be less than or
        //    equal to the time listed in the RRSIG RR's Expiration field.
        if (!RRUtils.serialNumberGte(rrset.expiration, uint32(now))) {
            revert SignatureExpired(rrset.expiration, uint32(now));
        }

        // o  The validator's notion of the current time MUST be greater than or
        //    equal to the time listed in the RRSIG RR's Inception field.
        if (!RRUtils.serialNumberGte(uint32(now), rrset.inception)) {
            revert SignatureNotValidYet(rrset.inception, uint32(now));
        }

        // Validate the signature
        verifySignature(name, rrset, input, proof);

        return rrset;
    }

    /**
     * @dev Validates a set of RRs.
     * @param rrset The RR set.
     * @param typecovered The type covered by the RRSIG record.
     */
    function validateRRs(
        RRUtils.SignedSet memory rrset,
        uint16 typecovered
    ) internal pure returns (bytes memory name) {
        // Iterate over all the RRs
        for (
            RRUtils.RRIterator memory iter = rrset.rrs();
            !iter.done();
            iter.next()
        ) {
            // We only support class IN (Internet)
            if (iter.class != DNSCLASS_IN) {
                revert InvalidClass(iter.class);
            }

            if (name.length == 0) {
                name = iter.name();
            } else {
                // Name must be the same on all RRs. We do things this way to avoid copying the name
                // repeatedly.
                if (
                    name.length != iter.data.nameLength(iter.offset) ||
                    !name.equals(0, iter.data, iter.offset, name.length)
                ) {
                    revert InvalidRRSet();
                }
            }

            // o  The RRSIG RR's Type Covered field MUST equal the RRset's type.
            if (iter.dnstype != typecovered) {
                revert SignatureTypeMismatch(iter.dnstype, typecovered);
            }
        }
    }

    /**
     * @dev Performs signature verification.
     *
     * Throws or reverts if unable to verify the record.
     *
     * @param name The name of the RRSIG record, in DNS label-sequence format.
     * @param data The original data to verify.
     * @param proof A DS or DNSKEY record that's already verified by the oracle.
     */
    function verifySignature(
        bytes memory name,
        RRUtils.SignedSet memory rrset,
        RRSetWithSignature memory data,
        bytes memory proof
    ) internal view {
        // o  The RRSIG RR's Signer's Name field MUST be the name of the zone
        //    that contains the RRset.
        if (!name.isSubdomainOf(rrset.signerName)) {
            revert InvalidSignerName(name, rrset.signerName);
        }

        RRUtils.RRIterator memory proofRR = proof.iterateRRs(0);
        // Check the proof
        if (proofRR.dnstype == DNSTYPE_DS) {
            verifyWithDS(rrset, data, proofRR);
        } else if (proofRR.dnstype == DNSTYPE_DNSKEY) {
            verifyWithKnownKey(rrset, data, proofRR);
        } else {
            revert InvalidProofType(proofRR.dnstype);
        }
    }

    /**
     * @dev Attempts to verify a signed RRSET against an already known public key.
     * @param rrset The signed set to verify.
     * @param data The original data the signed set was read from.
     * @param proof The serialized DS or DNSKEY record to use as proof.
     */
    function verifyWithKnownKey(
        RRUtils.SignedSet memory rrset,
        RRSetWithSignature memory data,
        RRUtils.RRIterator memory proof
    ) internal view {
        // Check the DNSKEY's owner name matches the signer name on the RRSIG
        for (; !proof.done(); proof.next()) {
            bytes memory proofName = proof.name();
            if (!proofName.equals(rrset.signerName)) {
                revert ProofNameMismatch(rrset.signerName, proofName);
            }

            bytes memory keyrdata = proof.rdata();
            RRUtils.DNSKEY memory dnskey = keyrdata.readDNSKEY(
                0,
                keyrdata.length
            );
            if (verifySignatureWithKey(dnskey, keyrdata, rrset, data)) {
                return;
            }
        }
        revert NoMatchingProof(rrset.signerName);
    }

    /**
     * @dev Attempts to verify some data using a provided key and a signature.
     * @param dnskey The dns key record to verify the signature with.
     * @param rrset The signed RRSET being verified.
     * @param data The original data `rrset` was decoded from.
     * @return True iff the key verifies the signature.
     */
    function verifySignatureWithKey(
        RRUtils.DNSKEY memory dnskey,
        bytes memory keyrdata,
        RRUtils.SignedSet memory rrset,
        RRSetWithSignature memory data
    ) internal view returns (bool) {
        // TODO: Check key isn't expired, unless updating key itself

        // The Protocol Field MUST have value 3 (RFC4034 2.1.2)
        if (dnskey.protocol != 3) {
            return false;
        }

        // o The RRSIG RR's Signer's Name, Algorithm, and Key Tag fields MUST
        //   match the owner name, algorithm, and key tag for some DNSKEY RR in
        //   the zone's apex DNSKEY RRset.
        if (dnskey.algorithm != rrset.algorithm) {
            return false;
        }
        uint16 computedkeytag = keyrdata.computeKeytag();
        if (computedkeytag != rrset.keytag) {
            return false;
        }

        // o The matching DNSKEY RR MUST be present in the zone's apex DNSKEY
        //   RRset, and MUST have the Zone Flag bit (DNSKEY RDATA Flag bit 7)
        //   set.
        if (dnskey.flags & DNSKEY_FLAG_ZONEKEY == 0) {
            return false;
        }

        Algorithm algorithm = algorithms[dnskey.algorithm];
        if (address(algorithm) == address(0)) {
            return false;
        }
        return algorithm.verify(keyrdata, data.rrset, data.sig);
    }

    /**
     * @dev Attempts to verify a signed RRSET against an already known hash. This function assumes
     *      that the record
     * @param rrset The signed set to verify.
     * @param data The original data the signed set was read from.
     * @param proof The serialized DS or DNSKEY record to use as proof.
     */
    function verifyWithDS(
        RRUtils.SignedSet memory rrset,
        RRSetWithSignature memory data,
        RRUtils.RRIterator memory proof
    ) internal view {
        uint256 proofOffset = proof.offset;
        for (
            RRUtils.RRIterator memory iter = rrset.rrs();
            !iter.done();
            iter.next()
        ) {
            if (iter.dnstype != DNSTYPE_DNSKEY) {
                revert InvalidProofType(iter.dnstype);
            }

            bytes memory keyrdata = iter.rdata();
            RRUtils.DNSKEY memory dnskey = keyrdata.readDNSKEY(
                0,
                keyrdata.length
            );
            if (verifySignatureWithKey(dnskey, keyrdata, rrset, data)) {
                // It's self-signed - look for a DS record to verify it.
                if (
                    verifyKeyWithDS(rrset.signerName, proof, dnskey, keyrdata)
                ) {
                    return;
                }
                // Rewind proof iterator to the start for the next loop iteration.
                proof.nextOffset = proofOffset;
                proof.next();
            }
        }
        revert NoMatchingProof(rrset.signerName);
    }

    /**
     * @dev Attempts to verify a key using DS records.
     * @param keyname The DNS name of the key, in DNS label-sequence format.
     * @param dsrrs The DS records to use in verification.
     * @param dnskey The dnskey to verify.
     * @param keyrdata The RDATA section of the key.
     * @return True if a DS record verifies this key.
     */
    function verifyKeyWithDS(
        bytes memory keyname,
        RRUtils.RRIterator memory dsrrs,
        RRUtils.DNSKEY memory dnskey,
        bytes memory keyrdata
    ) internal view returns (bool) {
        uint16 keytag = keyrdata.computeKeytag();
        for (; !dsrrs.done(); dsrrs.next()) {
            bytes memory proofName = dsrrs.name();
            if (!proofName.equals(keyname)) {
                revert ProofNameMismatch(keyname, proofName);
            }

            RRUtils.DS memory ds = dsrrs.data.readDS(
                dsrrs.rdataOffset,
                dsrrs.nextOffset - dsrrs.rdataOffset
            );
            if (ds.keytag != keytag) {
                continue;
            }
            if (ds.algorithm != dnskey.algorithm) {
                continue;
            }

            Buffer.buffer memory buf;
            buf.init(keyname.length + keyrdata.length);
            buf.append(keyname);
            buf.append(keyrdata);
            if (verifyDSHash(ds.digestType, buf.buf, ds.digest)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Attempts to verify a DS record's hash value against some data.
     * @param digesttype The digest ID from the DS record.
     * @param data The data to digest.
     * @param digest The digest data to check against.
     * @return True iff the digest matches.
     */
    function verifyDSHash(
        uint8 digesttype,
        bytes memory data,
        bytes memory digest
    ) internal view returns (bool) {
        if (address(digests[digesttype]) == address(0)) {
            return false;
        }
        return digests[digesttype].verify(data, digest);
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/Owned.sol
pragma solidity ^0.8.4;

/**
 * @dev Contract mixin for 'owned' contracts.
 */
contract Owned {
    address public owner;

    modifier owner_only() {
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function setOwner(address newOwner) public owner_only {
        owner = newOwner;
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/RRUtils.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../utils/BytesUtils.sol";
import "@ensdomains/buffer/contracts/Buffer.sol";

/**
 * @dev RRUtils is a library that provides utilities for parsing DNS resource records.
 */
library RRUtils {
    using BytesUtils for *;
    using Buffer for *;

    /**
     * @dev Returns the number of bytes in the DNS name at 'offset' in 'self'.
     * @param self The byte array to read a name from.
     * @param offset The offset to start reading at.
     * @return The length of the DNS name at 'offset', in bytes.
     */
    function nameLength(
        bytes memory self,
        uint256 offset
    ) internal pure returns (uint256) {
        uint256 idx = offset;
        while (true) {
            assert(idx < self.length);
            uint256 labelLen = self.readUint8(idx);
            idx += labelLen + 1;
            if (labelLen == 0) {
                break;
            }
        }
        return idx - offset;
    }

    /**
     * @dev Returns a DNS format name at the specified offset of self.
     * @param self The byte array to read a name from.
     * @param offset The offset to start reading at.
     * @return ret The name.
     */
    function readName(
        bytes memory self,
        uint256 offset
    ) internal pure returns (bytes memory ret) {
        uint256 len = nameLength(self, offset);
        return self.substring(offset, len);
    }

    /**
     * @dev Returns the number of labels in the DNS name at 'offset' in 'self'.
     * @param self The byte array to read a name from.
     * @param offset The offset to start reading at.
     * @return The number of labels in the DNS name at 'offset', in bytes.
     */
    function labelCount(
        bytes memory self,
        uint256 offset
    ) internal pure returns (uint256) {
        uint256 count = 0;
        while (true) {
            assert(offset < self.length);
            uint256 labelLen = self.readUint8(offset);
            offset += labelLen + 1;
            if (labelLen == 0) {
                break;
            }
            count += 1;
        }
        return count;
    }

    uint256 constant RRSIG_TYPE = 0;
    uint256 constant RRSIG_ALGORITHM = 2;
    uint256 constant RRSIG_LABELS = 3;
    uint256 constant RRSIG_TTL = 4;
    uint256 constant RRSIG_EXPIRATION = 8;
    uint256 constant RRSIG_INCEPTION = 12;
    uint256 constant RRSIG_KEY_TAG = 16;
    uint256 constant RRSIG_SIGNER_NAME = 18;

    struct SignedSet {
        uint16 typeCovered;
        uint8 algorithm;
        uint8 labels;
        uint32 ttl;
        uint32 expiration;
        uint32 inception;
        uint16 keytag;
        bytes signerName;
        bytes data;
        bytes name;
    }

    function readSignedSet(
        bytes memory data
    ) internal pure returns (SignedSet memory self) {
        self.typeCovered = data.readUint16(RRSIG_TYPE);
        self.algorithm = data.readUint8(RRSIG_ALGORITHM);
        self.labels = data.readUint8(RRSIG_LABELS);
        self.ttl = data.readUint32(RRSIG_TTL);
        self.expiration = data.readUint32(RRSIG_EXPIRATION);
        self.inception = data.readUint32(RRSIG_INCEPTION);
        self.keytag = data.readUint16(RRSIG_KEY_TAG);
        self.signerName = readName(data, RRSIG_SIGNER_NAME);
        self.data = data.substring(
            RRSIG_SIGNER_NAME + self.signerName.length,
            data.length - RRSIG_SIGNER_NAME - self.signerName.length
        );
    }

    function rrs(
        SignedSet memory rrset
    ) internal pure returns (RRIterator memory) {
        return iterateRRs(rrset.data, 0);
    }

    /**
     * @dev An iterator over resource records.
     */
    struct RRIterator {
        bytes data;
        uint256 offset;
        uint16 dnstype;
        uint16 class;
        uint32 ttl;
        uint256 rdataOffset;
        uint256 nextOffset;
    }

    /**
     * @dev Begins iterating over resource records.
     * @param self The byte string to read from.
     * @param offset The offset to start reading at.
     * @return ret An iterator object.
     */
    function iterateRRs(
        bytes memory self,
        uint256 offset
    ) internal pure returns (RRIterator memory ret) {
        ret.data = self;
        ret.nextOffset = offset;
        next(ret);
    }

    /**
     * @dev Returns true iff there are more RRs to iterate.
     * @param iter The iterator to check.
     * @return True iff the iterator has finished.
     */
    function done(RRIterator memory iter) internal pure returns (bool) {
        return iter.offset >= iter.data.length;
    }

    /**
     * @dev Moves the iterator to the next resource record.
     * @param iter The iterator to advance.
     */
    function next(RRIterator memory iter) internal pure {
        iter.offset = iter.nextOffset;
        if (iter.offset >= iter.data.length) {
            return;
        }

        // Skip the name
        uint256 off = iter.offset + nameLength(iter.data, iter.offset);

        // Read type, class, and ttl
        iter.dnstype = iter.data.readUint16(off);
        off += 2;
        iter.class = iter.data.readUint16(off);
        off += 2;
        iter.ttl = iter.data.readUint32(off);
        off += 4;

        // Read the rdata
        uint256 rdataLength = iter.data.readUint16(off);
        off += 2;
        iter.rdataOffset = off;
        iter.nextOffset = off + rdataLength;
    }

    /**
     * @dev Returns the name of the current record.
     * @param iter The iterator.
     * @return A new bytes object containing the owner name from the RR.
     */
    function name(RRIterator memory iter) internal pure returns (bytes memory) {
        return
            iter.data.substring(
                iter.offset,
                nameLength(iter.data, iter.offset)
            );
    }

    /**
     * @dev Returns the rdata portion of the current record.
     * @param iter The iterator.
     * @return A new bytes object containing the RR's RDATA.
     */
    function rdata(
        RRIterator memory iter
    ) internal pure returns (bytes memory) {
        return
            iter.data.substring(
                iter.rdataOffset,
                iter.nextOffset - iter.rdataOffset
            );
    }

    uint256 constant DNSKEY_FLAGS = 0;
    uint256 constant DNSKEY_PROTOCOL = 2;
    uint256 constant DNSKEY_ALGORITHM = 3;
    uint256 constant DNSKEY_PUBKEY = 4;

    struct DNSKEY {
        uint16 flags;
        uint8 protocol;
        uint8 algorithm;
        bytes publicKey;
    }

    function readDNSKEY(
        bytes memory data,
        uint256 offset,
        uint256 length
    ) internal pure returns (DNSKEY memory self) {
        self.flags = data.readUint16(offset + DNSKEY_FLAGS);
        self.protocol = data.readUint8(offset + DNSKEY_PROTOCOL);
        self.algorithm = data.readUint8(offset + DNSKEY_ALGORITHM);
        self.publicKey = data.substring(
            offset + DNSKEY_PUBKEY,
            length - DNSKEY_PUBKEY
        );
    }

    uint256 constant DS_KEY_TAG = 0;
    uint256 constant DS_ALGORITHM = 2;
    uint256 constant DS_DIGEST_TYPE = 3;
    uint256 constant DS_DIGEST = 4;

    struct DS {
        uint16 keytag;
        uint8 algorithm;
        uint8 digestType;
        bytes digest;
    }

    function readDS(
        bytes memory data,
        uint256 offset,
        uint256 length
    ) internal pure returns (DS memory self) {
        self.keytag = data.readUint16(offset + DS_KEY_TAG);
        self.algorithm = data.readUint8(offset + DS_ALGORITHM);
        self.digestType = data.readUint8(offset + DS_DIGEST_TYPE);
        self.digest = data.substring(offset + DS_DIGEST, length - DS_DIGEST);
    }

    function isSubdomainOf(
        bytes memory self,
        bytes memory other
    ) internal pure returns (bool) {
        uint256 off = 0;
        uint256 counts = labelCount(self, 0);
        uint256 othercounts = labelCount(other, 0);

        while (counts > othercounts) {
            off = progress(self, off);
            counts--;
        }

        return self.equals(off, other, 0);
    }

    function compareNames(
        bytes memory self,
        bytes memory other
    ) internal pure returns (int256) {
        if (self.equals(other)) {
            return 0;
        }

        uint256 off;
        uint256 otheroff;
        uint256 prevoff;
        uint256 otherprevoff;
        uint256 counts = labelCount(self, 0);
        uint256 othercounts = labelCount(other, 0);

        // Keep removing labels from the front of the name until both names are equal length
        while (counts > othercounts) {
            prevoff = off;
            off = progress(self, off);
            counts--;
        }

        while (othercounts > counts) {
            otherprevoff = otheroff;
            otheroff = progress(other, otheroff);
            othercounts--;
        }

        // Compare the last nonequal labels to each other
        while (counts > 0 && !self.equals(off, other, otheroff)) {
            prevoff = off;
            off = progress(self, off);
            otherprevoff = otheroff;
            otheroff = progress(other, otheroff);
            counts -= 1;
        }

        if (off == 0) {
            return -1;
        }
        if (otheroff == 0) {
            return 1;
        }

        return
            self.compare(
                prevoff + 1,
                self.readUint8(prevoff),
                other,
                otherprevoff + 1,
                other.readUint8(otherprevoff)
            );
    }

    /**
     * @dev Compares two serial numbers using RFC1982 serial number math.
     */
    function serialNumberGte(
        uint32 i1,
        uint32 i2
    ) internal pure returns (bool) {
        unchecked {
            return int32(i1) - int32(i2) >= 0;
        }
    }

    function progress(
        bytes memory body,
        uint256 off
    ) internal pure returns (uint256) {
        return off + 1 + body.readUint8(off);
    }

    /**
     * @dev Computes the keytag for a chunk of data.
     * @param data The data to compute a keytag for.
     * @return The computed key tag.
     */
    function computeKeytag(bytes memory data) internal pure returns (uint16) {
        /* This function probably deserves some explanation.
         * The DNSSEC keytag function is a checksum that relies on summing up individual bytes
         * from the input string, with some mild bitshifting. Here's a Naive solidity implementation:
         *
         *     function computeKeytag(bytes memory data) internal pure returns (uint16) {
         *         uint ac;
         *         for (uint i = 0; i < data.length; i++) {
         *             ac += i & 1 == 0 ? uint16(data.readUint8(i)) << 8 : data.readUint8(i);
         *         }
         *         return uint16(ac + (ac >> 16));
         *     }
         *
         * The EVM, with its 256 bit words, is exceedingly inefficient at doing byte-by-byte operations;
         * the code above, on reasonable length inputs, consumes over 100k gas. But we can make the EVM's
         * large words work in our favour.
         *
         * The code below works by treating the input as a series of 256 bit words. It first masks out
         * even and odd bytes from each input word, adding them to two separate accumulators `ac1` and `ac2`.
         * The bytes are separated by empty bytes, so as long as no individual sum exceeds 2^16-1, we're
         * effectively summing 16 different numbers with each EVM ADD opcode.
         *
         * Once it's added up all the inputs, it has to add all the 16 bit values in `ac1` and `ac2` together.
         * It does this using the same trick - mask out every other value, shift to align them, add them together.
         * After the first addition on both accumulators, there's enough room to add the two accumulators together,
         * and the remaining sums can be done just on ac1.
         */
        unchecked {
            require(data.length <= 8192, "Long keys not permitted");
            uint256 ac1;
            uint256 ac2;
            for (uint256 i = 0; i < data.length + 31; i += 32) {
                uint256 word;
                assembly {
                    word := mload(add(add(data, 32), i))
                }
                if (i + 32 > data.length) {
                    uint256 unused = 256 - (data.length - i) * 8;
                    word = (word >> unused) << unused;
                }
                ac1 +=
                    (word &
                        0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >>
                    8;
                ac2 += (word &
                    0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF);
            }
            ac1 =
                (ac1 &
                    0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) +
                ((ac1 &
                    0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >>
                    16);
            ac2 =
                (ac2 &
                    0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) +
                ((ac2 &
                    0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >>
                    16);
            ac1 = (ac1 << 8) + ac2;
            ac1 =
                (ac1 &
                    0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) +
                ((ac1 &
                    0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >>
                    32);
            ac1 =
                (ac1 &
                    0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) +
                ((ac1 &
                    0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >>
                    64);
            ac1 =
                (ac1 &
                    0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) +
                (ac1 >> 128);
            ac1 += (ac1 >> 16) & 0xFFFF;
            return uint16(ac1);
        }
    }
}


// Chain: POLYGON - File: contracts/dnssec-oracle/SHA1.sol
pragma solidity >=0.8.4;

library SHA1 {
    event Debug(bytes32 x);

    function sha1(bytes memory data) internal pure returns (bytes20 ret) {
        assembly {
            // Get a safe scratch location
            let scratch := mload(0x40)

            // Get the data length, and point data at the first byte
            let len := mload(data)
            data := add(data, 32)

            // Find the length after padding
            let totallen := add(and(add(len, 1), 0xFFFFFFFFFFFFFFC0), 64)
            switch lt(sub(totallen, len), 9)
            case 1 {
                totallen := add(totallen, 64)
            }

            let h := 0x6745230100EFCDAB890098BADCFE001032547600C3D2E1F0

            function readword(ptr, off, count) -> result {
                result := 0
                if lt(off, count) {
                    result := mload(add(ptr, off))
                    count := sub(count, off)
                    if lt(count, 32) {
                        let mask := not(sub(exp(256, sub(32, count)), 1))
                        result := and(result, mask)
                    }
                }
            }

            for {
                let i := 0
            } lt(i, totallen) {
                i := add(i, 64)
            } {
                mstore(scratch, readword(data, i, len))
                mstore(add(scratch, 32), readword(data, add(i, 32), len))

                // If we loaded the last byte, store the terminator byte
                switch lt(sub(len, i), 64)
                case 1 {
                    mstore8(add(scratch, sub(len, i)), 0x80)
                }

                // If this is the last block, store the length
                switch eq(i, sub(totallen, 64))
                case 1 {
                    mstore(
                        add(scratch, 32),
                        or(mload(add(scratch, 32)), mul(len, 8))
                    )
                }

                // Expand the 16 32-bit words into 80
                for {
                    let j := 64
                } lt(j, 128) {
                    j := add(j, 12)
                } {
                    let temp := xor(
                        xor(
                            mload(add(scratch, sub(j, 12))),
                            mload(add(scratch, sub(j, 32)))
                        ),
                        xor(
                            mload(add(scratch, sub(j, 56))),
                            mload(add(scratch, sub(j, 64)))
                        )
                    )
                    temp := or(
                        and(
                            mul(temp, 2),
                            0xFFFFFFFEFFFFFFFEFFFFFFFEFFFFFFFEFFFFFFFEFFFFFFFEFFFFFFFEFFFFFFFE
                        ),
                        and(
                            div(temp, 0x80000000),
                            0x0000000100000001000000010000000100000001000000010000000100000001
                        )
                    )
                    mstore(add(scratch, j), temp)
                }
                for {
                    let j := 128
                } lt(j, 320) {
                    j := add(j, 24)
                } {
                    let temp := xor(
                        xor(
                            mload(add(scratch, sub(j, 24))),
                            mload(add(scratch, sub(j, 64)))
                        ),
                        xor(
                            mload(add(scratch, sub(j, 112))),
                            mload(add(scratch, sub(j, 128)))
                        )
                    )
                    temp := or(
                        and(
                            mul(temp, 4),
                            0xFFFFFFFCFFFFFFFCFFFFFFFCFFFFFFFCFFFFFFFCFFFFFFFCFFFFFFFCFFFFFFFC
                        ),
                        and(
                            div(temp, 0x40000000),
                            0x0000000300000003000000030000000300000003000000030000000300000003
                        )
                    )
                    mstore(add(scratch, j), temp)
                }

                let x := h
                let f := 0
                let k := 0
                for {
                    let j := 0
                } lt(j, 80) {
                    j := add(j, 1)
                } {
                    switch div(j, 20)
                    case 0 {
                        // f = d xor (b and (c xor d))
                        f := xor(
                            div(x, 0x100000000000000000000),
                            div(x, 0x10000000000)
                        )
                        f := and(div(x, 0x1000000000000000000000000000000), f)
                        f := xor(div(x, 0x10000000000), f)
                        k := 0x5A827999
                    }
                    case 1 {
                        // f = b xor c xor d
                        f := xor(
                            div(x, 0x1000000000000000000000000000000),
                            div(x, 0x100000000000000000000)
                        )
                        f := xor(div(x, 0x10000000000), f)
                        k := 0x6ED9EBA1
                    }
                    case 2 {
                        // f = (b and c) or (d and (b or c))
                        f := or(
                            div(x, 0x1000000000000000000000000000000),
                            div(x, 0x100000000000000000000)
                        )
                        f := and(div(x, 0x10000000000), f)
                        f := or(
                            and(
                                div(x, 0x1000000000000000000000000000000),
                                div(x, 0x100000000000000000000)
                            ),
                            f
                        )
                        k := 0x8F1BBCDC
                    }
                    case 3 {
                        // f = b xor c xor d
                        f := xor(
                            div(x, 0x1000000000000000000000000000000),
                            div(x, 0x100000000000000000000)
                        )
                        f := xor(div(x, 0x10000000000), f)
                        k := 0xCA62C1D6
                    }
                    // temp = (a leftrotate 5) + f + e + k + w[i]
                    let temp := and(
                        div(
                            x,
                            0x80000000000000000000000000000000000000000000000
                        ),
                        0x1F
                    )
                    temp := or(
                        and(
                            div(x, 0x800000000000000000000000000000000000000),
                            0xFFFFFFE0
                        ),
                        temp
                    )
                    temp := add(f, temp)
                    temp := add(and(x, 0xFFFFFFFF), temp)
                    temp := add(k, temp)
                    temp := add(
                        div(
                            mload(add(scratch, mul(j, 4))),
                            0x100000000000000000000000000000000000000000000000000000000
                        ),
                        temp
                    )
                    x := or(
                        div(x, 0x10000000000),
                        mul(temp, 0x10000000000000000000000000000000000000000)
                    )
                    x := or(
                        and(
                            x,
                            0xFFFFFFFF00FFFFFFFF000000000000FFFFFFFF00FFFFFFFF
                        ),
                        mul(
                            or(
                                and(div(x, 0x4000000000000), 0xC0000000),
                                and(div(x, 0x400000000000000000000), 0x3FFFFFFF)
                            ),
                            0x100000000000000000000
                        )
                    )
                }

                h := and(
                    add(h, x),
                    0xFFFFFFFF00FFFFFFFF00FFFFFFFF00FFFFFFFF00FFFFFFFF
                )
            }
            ret := mul(
                or(
                    or(
                        or(
                            or(
                                and(
                                    div(h, 0x100000000),
                                    0xFFFFFFFF00000000000000000000000000000000
                                ),
                                and(
                                    div(h, 0x1000000),
                                    0xFFFFFFFF000000000000000000000000
                                )
                            ),
                            and(div(h, 0x10000), 0xFFFFFFFF0000000000000000)
                        ),
                        and(div(h, 0x100), 0xFFFFFFFF00000000)
                    ),
                    and(h, 0xFFFFFFFF)
                ),
                0x1000000000000000000000000
            )
        }
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/BaseRegistrarImplementation.sol
pragma solidity >=0.8.4;

import "../registry/ENS.sol";
import "./IBaseRegistrar.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BaseRegistrarImplementation is ERC721, IBaseRegistrar, Ownable {
    // A map of expiry times
    mapping(uint256 => uint256) expiries;
    // The ENS registry
    ENS public ens;
    // The namehash of the TLD this registrar owns (eg, .eth)
    bytes32 public baseNode;
    // A map of addresses that are authorised to register and renew names.
    mapping(address => bool) public controllers;
    uint256 public constant GRACE_PERIOD = 90 days;
    bytes4 private constant INTERFACE_META_ID =
        bytes4(keccak256("supportsInterface(bytes4)"));
    bytes4 private constant ERC721_ID =
        bytes4(
            keccak256("balanceOf(address)") ^
                keccak256("ownerOf(uint256)") ^
                keccak256("approve(address,uint256)") ^
                keccak256("getApproved(uint256)") ^
                keccak256("setApprovalForAll(address,bool)") ^
                keccak256("isApprovedForAll(address,address)") ^
                keccak256("transferFrom(address,address,uint256)") ^
                keccak256("safeTransferFrom(address,address,uint256)") ^
                keccak256("safeTransferFrom(address,address,uint256,bytes)")
        );
    bytes4 private constant RECLAIM_ID =
        bytes4(keccak256("reclaim(uint256,address)"));

    bool public UNLIMITED_TIME = false;

    /**
     * v2.1.3 version of _isApprovedOrOwner which calls ownerOf(tokenId) and takes grace period into consideration instead of ERC721.ownerOf(tokenId);
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.1.3/contracts/token/ERC721/ERC721.sol#L187
     * @dev Returns whether the given spender can transfer a given token ID
     * @param spender address of the spender to query
     * @param tokenId uint256 ID of the token to be transferred
     * @return bool whether the msg.sender is approved for the given token ID,
     *    is an operator of the owner, or is the owner of the token
     */
    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view override returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }

    constructor(ENS _ens, bytes32 _baseNode) ERC721("", "") {
        ens = _ens;
        baseNode = _baseNode;
    }

    modifier live() {
        require(ens.owner(baseNode) == address(this));
        _;
    }

    modifier onlyController() {
        require(controllers[msg.sender]);
        _;
    }

    /**
     * @dev Gets the owner of the specified token ID. Names become unowned
     *      when their registration expires.
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(
        uint256 tokenId
    ) public view override(IERC721, ERC721) returns (address) {
        require(expiries[tokenId] > block.timestamp);
        return super.ownerOf(tokenId);
    }

    // Authorises a controller, who can register and renew domains.
    function addController(address controller) external override onlyOwner {
        controllers[controller] = true;
        emit ControllerAdded(controller);
    }

    // Revoke controller permission for an address.
    function removeController(address controller) external override onlyOwner {
        controllers[controller] = false;
        emit ControllerRemoved(controller);
    }

    // Set the resolver for the TLD this registrar manages.
    function setResolver(address resolver) external override onlyOwner {
        ens.setResolver(baseNode, resolver);
    }

    // set the global value of UNLIMITED_TIME
    function setUnlimitedDuration(bool _unlimitedDuration) external onlyOwner {
        UNLIMITED_TIME = _unlimitedDuration;
    }

    // Returns the unlimitedDuration state of the registrar
    function getUnlimitedDuration() external view returns (bool) {
        return UNLIMITED_TIME;
    }

    // Returns the expiration timestamp of the specified id.
    function nameExpires(uint256 id) external view override returns (uint256) {
        return expiries[id];
    }

    // Returns true iff the specified name is available for registration.
    function available(uint256 id) public view override returns (bool) {
        // Not available if it's registered here or in its grace period.
        return expiries[id] + GRACE_PERIOD < block.timestamp;
    }

    /**
     * @dev Register a name.
     * @param id The token ID (keccak256 of the label).
     * @param owner The address that should own the registration.
     * @param duration Duration in seconds for the registration.
     */
    function register(
        uint256 id,
        address owner,
        uint256 duration
    ) external override returns (uint256) {
        return _register(id, owner, duration, true);
    }

    /**
     * @dev Register a name, without modifying the registry.
     * @param id The token ID (keccak256 of the label).
     * @param owner The address that should own the registration.
     * @param duration Duration in seconds for the registration.
     */
    function registerOnly(
        uint256 id,
        address owner,
        uint256 duration
    ) external returns (uint256) {
        return _register(id, owner, duration, false);
    }

    function _register(
        uint256 id,
        address owner,
        uint256 duration,
        bool updateRegistry
    ) internal live onlyController returns (uint256) {
        require(available(id));

        // if (UNLIMITED_TIME) {
        //     // Set expiry far into the future
        //     expiries[id] = type(uint256).max;
        // } else {
            require(
                block.timestamp + duration + GRACE_PERIOD >
                    block.timestamp + GRACE_PERIOD
            ); // Prevent future overflow
            expiries[id] = block.timestamp + duration;
        // }

        if (_exists(id)) {
            // Name was previously owned, and expired
            _burn(id);
        }
        _mint(owner, id);
        if (updateRegistry) {
            ens.setSubnodeOwner(baseNode, bytes32(id), owner);
        }

        emit NameRegistered(id, owner, expiries[id]);

        return expiries[id];
    }

    function renew(
        uint256 id,
        uint256 duration
    ) external override live onlyController returns (uint256) {
        require(expiries[id] + GRACE_PERIOD >= block.timestamp); // Name must be registered here or in grace period
        require(
            expiries[id] + duration + GRACE_PERIOD > duration + GRACE_PERIOD
        ); // Prevent future overflow

        expiries[id] += duration;
        emit NameRenewed(id, expiries[id]);
        return expiries[id];
    }

    /**
     * @dev Reclaim ownership of a name in ENS, if you own it in the registrar.
     */
    function reclaim(uint256 id, address owner) external override live {
        require(_isApprovedOrOwner(msg.sender, id));
        ens.setSubnodeOwner(baseNode, bytes32(id), owner);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view override(ERC721, IERC165) returns (bool) {
        return
            interfaceID == INTERFACE_META_ID ||
            interfaceID == ERC721_ID ||
            interfaceID == RECLAIM_ID;
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/BulkRenewal.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "../registry/ENS.sol";
import "./ETHRegistrarController.sol";
import "./IETHRegistrarController.sol";
import "../resolvers/Resolver.sol";
import "./IBulkRenewal.sol";
import "./IPriceOracle.sol";

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";


contract BulkRenewal is IBulkRenewal {
    // set based on network
    // bytes32 private constant ETH_NAMEHASH = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    bytes32 private constant ETH_NAMEHASH = 0x423ba58fb1ed8a39f711b6e11be3c3565659581128c3108f38b0d1f90cc398f2; // namehash('ecld') polygon
    // bytes32 private constant ETH_NAMEHASH = 0x312aaca3ac8032f81987e8517e993b798f14784dc873e9b4b93d6f18456511aa; // namehash('etny') bloxberg
    ENS public immutable ens;

    constructor(ENS _ens) {
        ens = _ens;
    }

    function getController() internal view returns (ETHRegistrarController) {
        Resolver r = Resolver(ens.resolver(ETH_NAMEHASH));
        return
            ETHRegistrarController(
                r.interfaceImplementer(
                    ETH_NAMEHASH,
                    type(IETHRegistrarController).interfaceId
                )
            );
    }

    function rentPrice(
        string[] calldata names,
        uint256 duration
    ) external view override returns (uint256 total) {
        ETHRegistrarController controller = getController();
        uint256 length = names.length;
        for (uint256 i = 0; i < length; ) {
            IPriceOracle.Price memory price = controller.rentPrice(
                names[i],
                duration
            );
            unchecked {
                ++i;
                total += (price.base + price.premium);
            }
        }
    }

    function renewAll(
        string[] calldata names,
        uint256 duration
    ) external payable override {
        ETHRegistrarController controller = getController();
        uint256 length = names.length;
        uint256 total;
        for (uint256 i = 0; i < length; ) {
            IPriceOracle.Price memory price = controller.rentPrice(
                names[i],
                duration
            );
            uint256 totalPrice = price.base + price.premium;
            controller.renew(names[i], duration);
            unchecked {
                ++i;
                total += totalPrice;
            }
        }
        // Send any excess funds back
        payable(msg.sender).transfer(address(this).balance);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) external pure returns (bool) {
        return
            interfaceID == type(IERC165).interfaceId ||
            interfaceID == type(IBulkRenewal).interfaceId;
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/DummyOracle.sol
pragma solidity >=0.8.4;

contract DummyOracle {
    int256 value;

    constructor(int256 _value) public {
        set(_value);
    }

    function set(int256 _value) public {
        value = _value;
    }

    function latestAnswer() public view returns (int256) {
        return value;
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/DummyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DummyToken is ERC20 {
    constructor(string memory symbol) ERC20("DummyToken", symbol) {
        _mint(msg.sender, 100000 * 10**18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// Chain: POLYGON - File: contracts/ethregistrar/ETHRegistrarController.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {BaseRegistrarImplementation} from "./BaseRegistrarImplementation.sol";
import {StringUtils} from "../utils/StringUtils.sol";
import {Resolver} from "../resolvers/Resolver.sol";
import {ENS} from "../registry/ENS.sol";
import {ReverseRegistrar} from "../reverseRegistrar/ReverseRegistrar.sol";
import {ReverseClaimer} from "../reverseRegistrar/ReverseClaimer.sol";
import {IETHRegistrarController, IPriceOracle} from "./IETHRegistrarController.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {INameWrapper} from "../wrapper/INameWrapper.sol";
import {ERC20Recoverable} from "../utils/ERC20Recoverable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error CommitmentTooNew(bytes32 commitment);
error CommitmentTooOld(bytes32 commitment);
error NameNotAvailable(string name);
error DurationTooShort(uint256 duration);
error ResolverRequiredWhenDataSupplied();
error UnexpiredCommitmentExists(bytes32 commitment);
error InsufficientValue();
error Unauthorised(bytes32 node);
error MaxCommitmentAgeTooLow();
error MaxCommitmentAgeTooHigh();

/**
 * @dev A registrar controller for registering and renewing names at fixed cost.
 */
contract ETHRegistrarController is
    Ownable,
    IETHRegistrarController,
    IERC165,
    ERC20Recoverable,
    ReverseClaimer
{
    using StringUtils for *;
    using Address for address;

    uint256 public constant MIN_REGISTRATION_DURATION = 28 days;
    // set based on network
    // bytes32 private constant ETH_NODE = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae; // namehash('eth')
    // IERC20 public token = IERC20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8); // eth should not be needed
    // set variable for token address

    bytes32 private constant ETH_NODE = 0x423ba58fb1ed8a39f711b6e11be3c3565659581128c3108f38b0d1f90cc398f2; // namehash('ecld') polygon
    IERC20 public token = IERC20(0x9927809B61122B2af3f3b3A3303875e0687b8eE3);  // tecld
    // IERC20 public token = IERC20(0xc6920888988cAcEeA7ACCA0c96f2D65b05eE22Ba);  // ecld

    // bytes32 private constant ETH_NODE = 0x312aaca3ac8032f81987e8517e993b798f14784dc873e9b4b93d6f18456511aa; // namehash('etny') bloxberg
    // IERC20 public token = IERC20(0x549A6E06BB2084100148D50F51CF77a3436C3Ae7); // etny
    // IERC20 public token = IERC20(0x02882F03097fE8cD31afbdFbB5D72a498B41112c); // tetny


    bool public UNLIMITED_TIME = true;
    uint64 private constant MAX_EXPIRY = type(uint64).max;
    BaseRegistrarImplementation immutable base;
    IPriceOracle public immutable prices;
    uint256 public immutable minCommitmentAge;
    uint256 public immutable maxCommitmentAge;
    ReverseRegistrar public immutable reverseRegistrar;
    INameWrapper public immutable nameWrapper;

    mapping(bytes32 => uint256) public commitments;

    event NameRegistered(
        string name,
        bytes32 indexed label,
        address indexed owner,
        uint256 baseCost,
        uint256 premium,
        uint256 expires
    );
    event NameRenewed(
        string name,
        bytes32 indexed label,
        uint256 cost,
        uint256 expires
    );

    constructor(
        BaseRegistrarImplementation _base,
        IPriceOracle _prices,
        uint256 _minCommitmentAge,
        uint256 _maxCommitmentAge,
        ReverseRegistrar _reverseRegistrar,
        INameWrapper _nameWrapper,
        ENS _ens
    ) ReverseClaimer(_ens, msg.sender) {
        if (_maxCommitmentAge <= _minCommitmentAge) {
            revert MaxCommitmentAgeTooLow();
        }
        if (_maxCommitmentAge > block.timestamp) {
            revert MaxCommitmentAgeTooHigh();
        }

        base = _base;
        prices = _prices;
        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
        reverseRegistrar = _reverseRegistrar;
        nameWrapper = _nameWrapper;
    }

    // set the global value of UNLIMITED_TIME
    function setUnlimitedDuration(bool _unlimitedDuration) external onlyOwner {
        UNLIMITED_TIME = _unlimitedDuration;
    }

    function getUnlimitedDuration() external view returns (bool) {
        return UNLIMITED_TIME;
    }

    function rentPrice(
        string memory name,
        uint256 duration
    ) public view override returns (IPriceOracle.Price memory price) {
        bytes32 label = keccak256(bytes(name));
        price = prices.price(name, base.nameExpires(uint256(label)), duration);
    }

    function valid(string memory name) public pure returns (bool) {
        return name.strlen() >= 3;
    }

    function available(string memory name) public view override returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && base.available(uint256(label));
    }

    function makeCommitment(
        string memory name,
        address owner,
        uint256 duration,
        bytes32 secret,
        address resolver,
        bytes[] calldata data,
        bool reverseRecord,
        uint16 ownerControlledFuses
    ) public view override returns (bytes32) {
        bytes32 label = keccak256(bytes(name));
        if (data.length > 0 && resolver == address(0)) {
            revert ResolverRequiredWhenDataSupplied();
        }

        if (UNLIMITED_TIME) {
            duration = 18446744075394;
        }
        return
            keccak256(
                abi.encode(
                    label,
                    owner,
                    duration,
                    secret,
                    resolver,
                    data,
                    reverseRecord,
                    ownerControlledFuses
                )
            );
    }

    function commit(bytes32 commitment) public override {
        if (commitments[commitment] + maxCommitmentAge >= block.timestamp) {
            revert UnexpiredCommitmentExists(commitment);
        }
        commitments[commitment] = block.timestamp;
    }


    function checkTokenAllowance(address owner, address spender) public view returns (uint256) {
        return token.allowance(owner, spender);
    }
    function setToken(IERC20 _token) public onlyOwner {
        token = _token;
    }

    function getTokenBalance(address holder) public view returns (uint256) {
        return token.balanceOf(holder);
    }


    function register(
        string calldata name,
        address owner,
        uint256 duration,
        bytes32 secret,
        address resolver,
        bytes[] calldata data,
        bool reverseRecord,
        uint16 ownerControlledFuses
    ) public override {
        uint256 priceDuration = duration;
        if (UNLIMITED_TIME) {
            duration = 18446744075394;
            priceDuration = 100*10**18;
        } else {
            duration = duration * 1 days;
            IPriceOracle.Price memory price = rentPrice(name, duration);
            priceDuration = (price.base + price.premium);
        }
        uint256 tokenAllowance = token.allowance(msg.sender, address(this));

        _consumeCommitment(
            name,
            duration,
            makeCommitment(
                name,
                owner,
                duration,
                secret,
                resolver,
                data,
                reverseRecord,
                ownerControlledFuses
            )
        );

        uint256 expires = nameWrapper.registerAndWrapETH2LD(
            name,
            owner,
            duration,
            resolver,
            ownerControlledFuses
        );

        if (data.length > 0) {
            _setRecords(resolver, keccak256(bytes(name)), data);
        }

        if (reverseRecord) {
            _setReverseRecord(name, resolver, msg.sender);
        }

        emit NameRegistered(
            name,
            keccak256(bytes(name)),
            owner,
            priceDuration,
            0,
            expires
        );
        if (tokenAllowance < (priceDuration)) {
            revert("Not enough tokens allowed for transfer");
        }

        if (token.balanceOf(msg.sender) < (priceDuration)) {
            revert("Not enough tokens for payment");
        }
        // Transfer the tokens from the user's account to the contract
        bool success = token.transferFrom(msg.sender, address(this), priceDuration);
        if (!success) {
            revert("Token transfer failed");
        }
    }

    function renew(
        string calldata name,
        uint256 duration
    ) external override {
        bytes32 labelhash = keccak256(bytes(name));
        uint256 tokenId = uint256(labelhash);
        IPriceOracle.Price memory price = rentPrice(name, duration);
        // if (msg.value < price.base) {
        //     revert InsufficientValue();
        // }
        uint256 expires = nameWrapper.renew(tokenId, duration);

        // if (msg.value > price.base) {
        //     payable(msg.sender).transfer(msg.value - price.base);
        // }
        uint256 totalCost = price.base;
        uint256 tokenAllowance = token.allowance(msg.sender, address(this));

        if (tokenAllowance < totalCost) {
            revert("Not enough tokens allowed for transfer");
        }

        if (token.balanceOf(msg.sender) < totalCost) {
            revert("Not enough tokens for payment");
        }

        // Transfer the tokens from the user's account to the contract
        bool success = token.transferFrom(msg.sender, address(this), totalCost);
        require(success, "Token transfer failed");

        // if (token.balanceOf(msg.sender) > totalCost) {
        //     token.transfer(msg.sender, token.balanceOf(msg.sender) - totalCost);
        // }

        emit NameRenewed(name, labelhash, price.base, expires);
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    function withdrawToken() public onlyOwner {
        token.transferFrom(address(this), owner(), token.balanceOf(address(this)));
    }

    function supportsInterface(
        bytes4 interfaceID
    ) external pure returns (bool) {
        return
            interfaceID == type(IERC165).interfaceId ||
            interfaceID == type(IETHRegistrarController).interfaceId;
    }

    /* Internal functions */

    function _consumeCommitment(
        string memory name,
        uint256 duration,
        bytes32 commitment
    ) internal {
        // Require an old enough commitment.
        if (commitments[commitment] + minCommitmentAge > block.timestamp) {
            revert CommitmentTooNew(commitment);
        }

        // If the commitment is too old, or the name is registered, stop
        if (commitments[commitment] + maxCommitmentAge <= block.timestamp) {
            revert CommitmentTooOld(commitment);
        }
        if (!available(name)) {
            revert NameNotAvailable(name);
        }

        delete (commitments[commitment]);

        if (duration < MIN_REGISTRATION_DURATION) {
            revert DurationTooShort(duration);
        }
    }

    function _setRecords(
        address resolverAddress,
        bytes32 label,
        bytes[] calldata data
    ) internal {
        // use hardcoded .eth namehash
        bytes32 nodehash = keccak256(abi.encodePacked(ETH_NODE, label));
        Resolver resolver = Resolver(resolverAddress);
        resolver.multicallWithNodeCheck(nodehash, data);
    }

    function _setReverseRecord(
        string memory name,
        address resolver,
        address owner
    ) internal {
        reverseRegistrar.setNameForAddr(
            msg.sender,
            owner,
            resolver,
            // set based on network
            // string.concat(name, ".eth") // mainnet
            string.concat(name, ".ecld") // polygon
            // string.concat(name, ".etny") // bloxberg
        );
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/ExponentialPremiumPriceOracle.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "./StablePriceOracle.sol";

contract ExponentialPremiumPriceOracle is StablePriceOracle {
    uint256 constant GRACE_PERIOD = 90 days;
    uint256 immutable startPremium;
    uint256 immutable endValue;

    constructor(
        AggregatorInterface _usdOracle,
        uint256[] memory _rentPrices,
        uint256 _startPremium,
        uint256 totalDays
    ) StablePriceOracle(_usdOracle, _rentPrices) {
        startPremium = _startPremium;
        endValue = _startPremium >> totalDays;
    }

    uint256 constant PRECISION = 1e18;
    uint256 constant bit1 = 999989423469314432; // 0.5 ^ 1/65536 * (10 ** 18)
    uint256 constant bit2 = 999978847050491904; // 0.5 ^ 2/65536 * (10 ** 18)
    uint256 constant bit3 = 999957694548431104;
    uint256 constant bit4 = 999915390886613504;
    uint256 constant bit5 = 999830788931929088;
    uint256 constant bit6 = 999661606496243712;
    uint256 constant bit7 = 999323327502650752;
    uint256 constant bit8 = 998647112890970240;
    uint256 constant bit9 = 997296056085470080;
    uint256 constant bit10 = 994599423483633152;
    uint256 constant bit11 = 989228013193975424;
    uint256 constant bit12 = 978572062087700096;
    uint256 constant bit13 = 957603280698573696;
    uint256 constant bit14 = 917004043204671232;
    uint256 constant bit15 = 840896415253714560;
    uint256 constant bit16 = 707106781186547584;

    /**
     * @dev Returns the pricing premium in internal base units.
     */
    function _premium(
        string memory,
        uint256 expires,
        uint256
    ) internal view override returns (uint256) {
        expires = expires + GRACE_PERIOD;
        if (expires > block.timestamp) {
            return 0;
        }

        uint256 elapsed = block.timestamp - expires;
        uint256 premium = decayedPremium(startPremium, elapsed);
        if (premium >= endValue) {
            return premium - endValue;
        }
        return 0;
    }

    /**
     * @dev Returns the premium price at current time elapsed
     * @param startPremium starting price
     * @param elapsed time past since expiry
     */
    function decayedPremium(
        uint256 startPremium,
        uint256 elapsed
    ) public pure returns (uint256) {
        uint256 daysPast = (elapsed * PRECISION) / 1 days;
        uint256 intDays = daysPast / PRECISION;
        uint256 premium = startPremium >> intDays;
        uint256 partDay = (daysPast - intDays * PRECISION);
        uint256 fraction = (partDay * (2 ** 16)) / PRECISION;
        uint256 totalPremium = addFractionalPremium(fraction, premium);
        return totalPremium;
    }

    function addFractionalPremium(
        uint256 fraction,
        uint256 premium
    ) internal pure returns (uint256) {
        if (fraction & (1 << 0) != 0) {
            premium = (premium * bit1) / PRECISION;
        }
        if (fraction & (1 << 1) != 0) {
            premium = (premium * bit2) / PRECISION;
        }
        if (fraction & (1 << 2) != 0) {
            premium = (premium * bit3) / PRECISION;
        }
        if (fraction & (1 << 3) != 0) {
            premium = (premium * bit4) / PRECISION;
        }
        if (fraction & (1 << 4) != 0) {
            premium = (premium * bit5) / PRECISION;
        }
        if (fraction & (1 << 5) != 0) {
            premium = (premium * bit6) / PRECISION;
        }
        if (fraction & (1 << 6) != 0) {
            premium = (premium * bit7) / PRECISION;
        }
        if (fraction & (1 << 7) != 0) {
            premium = (premium * bit8) / PRECISION;
        }
        if (fraction & (1 << 8) != 0) {
            premium = (premium * bit9) / PRECISION;
        }
        if (fraction & (1 << 9) != 0) {
            premium = (premium * bit10) / PRECISION;
        }
        if (fraction & (1 << 10) != 0) {
            premium = (premium * bit11) / PRECISION;
        }
        if (fraction & (1 << 11) != 0) {
            premium = (premium * bit12) / PRECISION;
        }
        if (fraction & (1 << 12) != 0) {
            premium = (premium * bit13) / PRECISION;
        }
        if (fraction & (1 << 13) != 0) {
            premium = (premium * bit14) / PRECISION;
        }
        if (fraction & (1 << 14) != 0) {
            premium = (premium * bit15) / PRECISION;
        }
        if (fraction & (1 << 15) != 0) {
            premium = (premium * bit16) / PRECISION;
        }
        return premium;
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/IBaseRegistrar.sol
import "../registry/ENS.sol";
import "./IBaseRegistrar.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IBaseRegistrar is IERC721 {
    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);
    event NameMigrated(
        uint256 indexed id,
        address indexed owner,
        uint256 expires
    );
    event NameRegistered(
        uint256 indexed id,
        address indexed owner,
        uint256 expires
    );
    event NameRenewed(uint256 indexed id, uint256 expires);

    // Authorises a controller, who can register and renew domains.
    function addController(address controller) external;

    // Revoke controller permission for an address.
    function removeController(address controller) external;

    // Set the resolver for the TLD this registrar manages.
    function setResolver(address resolver) external;

    // Returns the expiration timestamp of the specified label hash.
    function nameExpires(uint256 id) external view returns (uint256);

    // Returns true if the specified name is available for registration.
    function available(uint256 id) external view returns (bool);

    /**
     * @dev Register a name.
     */
    function register(
        uint256 id,
        address owner,
        uint256 duration
    ) external returns (uint256);

    function renew(uint256 id, uint256 duration) external returns (uint256);

    /**
     * @dev Reclaim ownership of a name in ENS, if you own it in the registrar.
     */
    function reclaim(uint256 id, address owner) external;
}


// Chain: POLYGON - File: contracts/ethregistrar/IBulkRenewal.sol
interface IBulkRenewal {
    function rentPrice(
        string[] calldata names,
        uint256 duration
    ) external view returns (uint256 total);

    function renewAll(
        string[] calldata names,
        uint256 duration
    ) external payable;
}


// Chain: POLYGON - File: contracts/ethregistrar/IETHRegistrarController.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "./IPriceOracle.sol";

interface IETHRegistrarController {
    function rentPrice(
        string memory,
        uint256
    ) external view returns (IPriceOracle.Price memory);

    function available(string memory) external returns (bool);

    function makeCommitment(
        string memory,
        address,
        uint256,
        bytes32,
        address,
        bytes[] calldata,
        bool,
        uint16
    ) external view returns (bytes32);

    function commit(bytes32) external;

    function register(
        string calldata,
        address,
        uint256,
        bytes32,
        address,
        bytes[] calldata,
        bool,
        uint16
    ) external;

    function renew(string calldata, uint256) external;
}


// Chain: POLYGON - File: contracts/ethregistrar/ILinearPremiumPriceOracle.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

interface ILinearPremiumPriceOracle {
    function timeUntilPremium(
        uint256 expires,
        uint256 amount
    ) external view returns (uint256);
}


// Chain: POLYGON - File: contracts/ethregistrar/IPriceOracle.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

interface IPriceOracle {
    struct Price {
        uint256 base;
        uint256 premium;
    }

    /**
     * @dev Returns the price to register or renew a name.
     * @param name The name being registered or renewed.
     * @param expires When the name presently expires (0 if this is a new registration).
     * @param duration How long the name is being registered or extended for, in seconds.
     * @return base premium tuple of base price + premium price
     */
    function price(
        string calldata name,
        uint256 expires,
        uint256 duration
    ) external view returns (Price calldata);
}


// Chain: POLYGON - File: contracts/ethregistrar/LinearPremiumPriceOracle.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "./SafeMath.sol";
import "./StablePriceOracle.sol";

contract LinearPremiumPriceOracle is StablePriceOracle {
    using SafeMath for *;

    uint256 immutable GRACE_PERIOD = 90 days;

    uint256 public immutable initialPremium;
    uint256 public immutable premiumDecreaseRate;

    bytes4 private constant TIME_UNTIL_PREMIUM_ID =
        bytes4(keccak256("timeUntilPremium(uint,uint"));

    constructor(
        AggregatorInterface _usdOracle,
        uint256[] memory _rentPrices,
        uint256 _initialPremium,
        uint256 _premiumDecreaseRate
    ) public StablePriceOracle(_usdOracle, _rentPrices) {
        initialPremium = _initialPremium;
        premiumDecreaseRate = _premiumDecreaseRate;
    }

    function _premium(
        string memory name,
        uint256 expires,
        uint256 /*duration*/
    ) internal view override returns (uint256) {
        expires = expires.add(GRACE_PERIOD);
        if (expires > block.timestamp) {
            // No premium for renewals
            return 0;
        }

        // Calculate the discount off the maximum premium
        uint256 discount = premiumDecreaseRate.mul(
            block.timestamp.sub(expires)
        );

        // If we've run out the premium period, return 0.
        if (discount > initialPremium) {
            return 0;
        }

        return initialPremium - discount;
    }

    /**
     * @dev Returns the timestamp at which a name with the specified expiry date will have
     *      the specified re-registration price premium.
     * @param expires The timestamp at which the name expires.
     * @param amount The amount, in wei, the caller is willing to pay
     * @return The timestamp at which the premium for this domain will be `amount`.
     */
    function timeUntilPremium(
        uint256 expires,
        uint256 amount
    ) external view returns (uint256) {
        amount = weiToAttoUSD(amount);
        require(amount <= initialPremium);

        expires = expires.add(GRACE_PERIOD);

        uint256 discount = initialPremium.sub(amount);
        uint256 duration = discount.div(premiumDecreaseRate);
        return expires.add(duration);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            (interfaceID == TIME_UNTIL_PREMIUM_ID) ||
            super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/mocks/DummyProxyRegistry.sol
pragma solidity >=0.8.4;

contract DummyProxyRegistry {
    address target;

    constructor(address _target) public {
        target = _target;
    }

    function proxies(address a) external view returns (address) {
        return target;
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/SafeMath.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/StablePriceOracle.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "./IPriceOracle.sol";
import "../utils/StringUtils.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface AggregatorInterface {
    function latestAnswer() external view returns (int256);
}

// StablePriceOracle sets a price in USD, based on an oracle.
contract StablePriceOracle is IPriceOracle {
    using StringUtils for *;

    // Rent in base price units by length
    uint256 public immutable price1Letter;
    uint256 public immutable price2Letter;
    uint256 public immutable price3Letter;
    uint256 public immutable price4Letter;
    uint256 public immutable price5Letter;

    // Oracle address
    AggregatorInterface public immutable usdOracle;

    event RentPriceChanged(uint256[] prices);

    constructor(AggregatorInterface _usdOracle, uint256[] memory _rentPrices) {
        usdOracle = _usdOracle;
        price1Letter = _rentPrices[0];
        price2Letter = _rentPrices[1];
        price3Letter = _rentPrices[2];
        price4Letter = _rentPrices[3];
        price5Letter = _rentPrices[4];
    }

    function price(
        string calldata name,
        uint256 expires,
        uint256 duration
    ) external view override returns (IPriceOracle.Price memory) {
        uint256 len = name.strlen();
        uint256 basePrice;

        if (len >= 5) {
            basePrice = price5Letter * duration;
        } else if (len == 4) {
            basePrice = price4Letter * duration;
        } else if (len == 3) {
            basePrice = price3Letter * duration;
        } else if (len == 2) {
            basePrice = price2Letter * duration;
        } else {
            basePrice = price1Letter * duration;
        }

        return
            IPriceOracle.Price({
                base: attoUSDToWei(basePrice),
                premium: attoUSDToWei(_premium(name, expires, duration))
            });
    }

    /**
     * @dev Returns the pricing premium in wei.
     */
    function premium(
        string calldata name,
        uint256 expires,
        uint256 duration
    ) external view returns (uint256) {
        return attoUSDToWei(_premium(name, expires, duration));
    }

    /**
     * @dev Returns the pricing premium in internal base units.
     */
    function _premium(
        string memory name,
        uint256 expires,
        uint256 duration
    ) internal view virtual returns (uint256) {
        return 0;
    }

    function attoUSDToWei(uint256 amount) internal view returns (uint256) {
        uint256 ethPrice = uint256(usdOracle.latestAnswer());
        return (amount * 1e8) / ethPrice;
    }

    function weiToAttoUSD(uint256 amount) internal view returns (uint256) {
        uint256 ethPrice = uint256(usdOracle.latestAnswer());
        return (amount * ethPrice) / 1e8;
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual returns (bool) {
        return
            interfaceID == type(IERC165).interfaceId ||
            interfaceID == type(IPriceOracle).interfaceId;
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/StaticBulkRenewal.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "./ETHRegistrarController.sol";
import "./IBulkRenewal.sol";
import "./IPriceOracle.sol";

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract StaticBulkRenewal is IBulkRenewal {
    ETHRegistrarController controller;

    constructor(ETHRegistrarController _controller) {
        controller = _controller;
    }

    function rentPrice(
        string[] calldata names,
        uint256 duration
    ) external view override returns (uint256 total) {
        uint256 length = names.length;
        for (uint256 i = 0; i < length; ) {
            IPriceOracle.Price memory price = controller.rentPrice(
                names[i],
                duration
            );
            unchecked {
                ++i;
                total += (price.base + price.premium);
            }
        }
    }

    function renewAll(
        string[] calldata names,
        uint256 duration
    ) external payable override {
        uint256 length = names.length;
        uint256 total;
        for (uint256 i = 0; i < length; ) {
            IPriceOracle.Price memory price = controller.rentPrice(
                names[i],
                duration
            );
            uint256 totalPrice = price.base + price.premium;
            controller.renew(names[i], duration);
            unchecked {
                ++i;
                total += totalPrice;
            }
        }
        // Send any excess funds back
        payable(msg.sender).transfer(address(this).balance);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) external pure returns (bool) {
        return
            interfaceID == type(IERC165).interfaceId ||
            interfaceID == type(IBulkRenewal).interfaceId;
    }
}


// Chain: POLYGON - File: contracts/ethregistrar/TestResolver.sol
pragma solidity >=0.8.4;

/**
 * @dev A test resolver implementation
 */
contract TestResolver {
    mapping(bytes32 => address) addresses;

    constructor() public {}

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return interfaceID == 0x01ffc9a7 || interfaceID == 0x3b3b57de;
    }

    function addr(bytes32 node) public view returns (address) {
        return addresses[node];
    }

    function setAddr(bytes32 node, address addr) public {
        addresses[node] = addr;
    }
}


// Chain: POLYGON - File: contracts/registry/ENS.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface ENS {
    // Logged when the owner of a node assigns a new owner to a subnode.
    event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

    // Logged when the owner of a node transfers ownership to a new account.
    event Transfer(bytes32 indexed node, address owner);

    // Logged when the resolver for a node changes.
    event NewResolver(bytes32 indexed node, address resolver);

    // Logged when the TTL of a node changes
    event NewTTL(bytes32 indexed node, uint64 ttl);

    // Logged when an operator is added or removed.
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    ) external;

    function setSubnodeRecord(
        bytes32 node,
        bytes32 label,
        address owner,
        address resolver,
        uint64 ttl
    ) external;

    function setSubnodeOwner(
        bytes32 node,
        bytes32 label,
        address owner
    ) external returns (bytes32);

    function setResolver(bytes32 node, address resolver) external;

    function setOwner(bytes32 node, address owner) external;

    function setTTL(bytes32 node, uint64 ttl) external;

    function setApprovalForAll(address operator, bool approved) external;

    function owner(bytes32 node) external view returns (address);

    function resolver(bytes32 node) external view returns (address);

    function ttl(bytes32 node) external view returns (uint64);

    function recordExists(bytes32 node) external view returns (bool);

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);
}


// Chain: POLYGON - File: contracts/registry/ENSRegistry.sol
pragma solidity >=0.8.4;

import "./ENS.sol";

/**
 * The ENS registry contract.
 */
contract ENSRegistry is ENS {
    struct Record {
        address owner;
        address resolver;
        uint64 ttl;
    }

    mapping(bytes32 => Record) records;
    mapping(address => mapping(address => bool)) operators;

    // Permits modifications only by the owner of the specified node.
    modifier authorised(bytes32 node) {
        address owner = records[node].owner;
        require(owner == msg.sender || operators[owner][msg.sender]);
        _;
    }

    /**
     * @dev Constructs a new ENS registry.
     */
    constructor() public {
        records[0x0].owner = msg.sender;
    }

    /**
     * @dev Sets the record for a node.
     * @param node The node to update.
     * @param owner The address of the new owner.
     * @param resolver The address of the resolver.
     * @param ttl The TTL in seconds.
     */
    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    ) external virtual override {
        setOwner(node, owner);
        _setResolverAndTTL(node, resolver, ttl);
    }

    /**
     * @dev Sets the record for a subnode.
     * @param node The parent node.
     * @param label The hash of the label specifying the subnode.
     * @param owner The address of the new owner.
     * @param resolver The address of the resolver.
     * @param ttl The TTL in seconds.
     */
    function setSubnodeRecord(
        bytes32 node,
        bytes32 label,
        address owner,
        address resolver,
        uint64 ttl
    ) external virtual override {
        bytes32 subnode = setSubnodeOwner(node, label, owner);
        _setResolverAndTTL(subnode, resolver, ttl);
    }

    /**
     * @dev Transfers ownership of a node to a new address. May only be called by the current owner of the node.
     * @param node The node to transfer ownership of.
     * @param owner The address of the new owner.
     */
    function setOwner(
        bytes32 node,
        address owner
    ) public virtual override authorised(node) {
        _setOwner(node, owner);
        emit Transfer(node, owner);
    }

    /**
     * @dev Transfers ownership of a subnode keccak256(node, label) to a new address. May only be called by the owner of the parent node.
     * @param node The parent node.
     * @param label The hash of the label specifying the subnode.
     * @param owner The address of the new owner.
     */
    function setSubnodeOwner(
        bytes32 node,
        bytes32 label,
        address owner
    ) public virtual override authorised(node) returns (bytes32) {
        bytes32 subnode = keccak256(abi.encodePacked(node, label));
        _setOwner(subnode, owner);
        emit NewOwner(node, label, owner);
        return subnode;
    }

    /**
     * @dev Sets the resolver address for the specified node.
     * @param node The node to update.
     * @param resolver The address of the resolver.
     */
    function setResolver(
        bytes32 node,
        address resolver
    ) public virtual override authorised(node) {
        emit NewResolver(node, resolver);
        records[node].resolver = resolver;
    }

    /**
     * @dev Sets the TTL for the specified node.
     * @param node The node to update.
     * @param ttl The TTL in seconds.
     */
    function setTTL(
        bytes32 node,
        uint64 ttl
    ) public virtual override authorised(node) {
        emit NewTTL(node, ttl);
        records[node].ttl = ttl;
    }

    /**
     * @dev Enable or disable approval for a third party ("operator") to manage
     *  all of `msg.sender`'s ENS records. Emits the ApprovalForAll event.
     * @param operator Address to add to the set of authorized operators.
     * @param approved True if the operator is approved, false to revoke approval.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) external virtual override {
        operators[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev Returns the address that owns the specified node.
     * @param node The specified node.
     * @return address of the owner.
     */
    function owner(
        bytes32 node
    ) public view virtual override returns (address) {
        address addr = records[node].owner;
        if (addr == address(this)) {
            return address(0x0);
        }

        return addr;
    }

    /**
     * @dev Returns the address of the resolver for the specified node.
     * @param node The specified node.
     * @return address of the resolver.
     */
    function resolver(
        bytes32 node
    ) public view virtual override returns (address) {
        return records[node].resolver;
    }

    /**
     * @dev Returns the TTL of a node, and any records associated with it.
     * @param node The specified node.
     * @return ttl of the node.
     */
    function ttl(bytes32 node) public view virtual override returns (uint64) {
        return records[node].ttl;
    }

    /**
     * @dev Returns whether a record has been imported to the registry.
     * @param node The specified node.
     * @return Bool if record exists
     */
    function recordExists(
        bytes32 node
    ) public view virtual override returns (bool) {
        return records[node].owner != address(0x0);
    }

    /**
     * @dev Query if an address is an authorized operator for another address.
     * @param owner The address that owns the records.
     * @param operator The address that acts on behalf of the owner.
     * @return True if `operator` is an approved operator for `owner`, false otherwise.
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) external view virtual override returns (bool) {
        return operators[owner][operator];
    }

    function _setOwner(bytes32 node, address owner) internal virtual {
        records[node].owner = owner;
    }

    function _setResolverAndTTL(
        bytes32 node,
        address resolver,
        uint64 ttl
    ) internal {
        if (resolver != records[node].resolver) {
            records[node].resolver = resolver;
            emit NewResolver(node, resolver);
        }

        if (ttl != records[node].ttl) {
            records[node].ttl = ttl;
            emit NewTTL(node, ttl);
        }
    }
}


// Chain: POLYGON - File: contracts/registry/ENSRegistryWithFallback.sol
pragma solidity >=0.8.4;

import "./ENS.sol";
import "./ENSRegistry.sol";

/**
 * The ENS registry contract.
 */
contract ENSRegistryWithFallback is ENSRegistry {
    ENS public old;

    /**
     * @dev Constructs a new ENS registrar.
     */
    constructor(ENS _old) public ENSRegistry() {
        old = _old;
    }

    /**
     * @dev Returns the address of the resolver for the specified node.
     * @param node The specified node.
     * @return address of the resolver.
     */
    function resolver(bytes32 node) public view override returns (address) {
        if (!recordExists(node)) {
            return old.resolver(node);
        }

        return super.resolver(node);
    }

    /**
     * @dev Returns the address that owns the specified node.
     * @param node The specified node.
     * @return address of the owner.
     */
    function owner(bytes32 node) public view override returns (address) {
        if (!recordExists(node)) {
            return old.owner(node);
        }

        return super.owner(node);
    }

    /**
     * @dev Returns the TTL of a node, and any records associated with it.
     * @param node The specified node.
     * @return ttl of the node.
     */
    function ttl(bytes32 node) public view override returns (uint64) {
        if (!recordExists(node)) {
            return old.ttl(node);
        }

        return super.ttl(node);
    }

    function _setOwner(bytes32 node, address owner) internal override {
        address addr = owner;
        if (addr == address(0x0)) {
            addr = address(this);
        }

        super._setOwner(node, addr);
    }
}


// Chain: POLYGON - File: contracts/registry/FIFSRegistrar.sol
pragma solidity >=0.8.4;

import "./ENS.sol";

/**
 * A registrar that allocates subdomains to the first person to claim them.
 */
contract FIFSRegistrar {
    ENS ens;
    bytes32 rootNode;

    modifier only_owner(bytes32 label) {
        address currentOwner = ens.owner(
            keccak256(abi.encodePacked(rootNode, label))
        );
        require(currentOwner == address(0x0) || currentOwner == msg.sender);
        _;
    }

    /**
     * Constructor.
     * @param ensAddr The address of the ENS registry.
     * @param node The node that this registrar administers.
     */
    constructor(ENS ensAddr, bytes32 node) public {
        ens = ensAddr;
        rootNode = node;
    }

    /**
     * Register a name, or change the owner of an existing registration.
     * @param label The hash of the label to register.
     * @param owner The address of the new owner.
     */
    function register(bytes32 label, address owner) public only_owner(label) {
        ens.setSubnodeOwner(rootNode, label, owner);
    }
}


// Chain: POLYGON - File: contracts/registry/TestRegistrar.sol
pragma solidity >=0.8.4;

import "./ENS.sol";

/**
 * A registrar that allocates subdomains to the first person to claim them, but
 * expires registrations a fixed period after they're initially claimed.
 */
contract TestRegistrar {
    uint256 constant registrationPeriod = 4 weeks;

    ENS public immutable ens;
    bytes32 public immutable rootNode;
    mapping(bytes32 => uint256) public expiryTimes;

    /**
     * Constructor.
     * @param ensAddr The address of the ENS registry.
     * @param node The node that this registrar administers.
     */
    constructor(ENS ensAddr, bytes32 node) {
        ens = ensAddr;
        rootNode = node;
    }

    /**
     * Register a name that's not currently registered
     * @param label The hash of the label to register.
     * @param owner The address of the new owner.
     */
    function register(bytes32 label, address owner) public {
        require(expiryTimes[label] < block.timestamp);

        expiryTimes[label] = block.timestamp + registrationPeriod;
        ens.setSubnodeOwner(rootNode, label, owner);
    }
}


// Chain: POLYGON - File: contracts/resolvers/IMulticallable.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IMulticallable {
    function multicall(
        bytes[] calldata data
    ) external returns (bytes[] memory results);

    function multicallWithNodeCheck(
        bytes32,
        bytes[] calldata data
    ) external returns (bytes[] memory results);
}


// Chain: POLYGON - File: contracts/resolvers/mocks/DummyNameWrapper.sol
pragma solidity ^0.8.4;

/**
 * @dev Implements a dummy NameWrapper which returns the caller's address
 */
contract DummyNameWrapper {
    function ownerOf(uint256 /* id */) public view returns (address) {
        return tx.origin;
    }
}


// Chain: POLYGON - File: contracts/resolvers/Multicallable.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IMulticallable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

abstract contract Multicallable is IMulticallable, ERC165 {
    function _multicall(
        bytes32 nodehash,
        bytes[] calldata data
    ) internal returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            if (nodehash != bytes32(0)) {
                bytes32 txNamehash = bytes32(data[i][4:36]);
                require(
                    txNamehash == nodehash,
                    "multicall: All records must have a matching namehash"
                );
            }
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );
            require(success);
            results[i] = result;
        }
        return results;
    }

    // This function provides an extra security check when called
    // from priviledged contracts (such as EthRegistrarController)
    // that can set records on behalf of the node owners
    function multicallWithNodeCheck(
        bytes32 nodehash,
        bytes[] calldata data
    ) external returns (bytes[] memory results) {
        return _multicall(nodehash, data);
    }

    function multicall(
        bytes[] calldata data
    ) public override returns (bytes[] memory results) {
        return _multicall(bytes32(0), data);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(IMulticallable).interfaceId ||
            super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/resolvers/OwnedResolver.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./profiles/ABIResolver.sol";
import "./profiles/AddrResolver.sol";
import "./profiles/ContentHashResolver.sol";
import "./profiles/DNSResolver.sol";
import "./profiles/InterfaceResolver.sol";
import "./profiles/NameResolver.sol";
import "./profiles/PubkeyResolver.sol";
import "./profiles/TextResolver.sol";
import "./profiles/ExtendedResolver.sol";

/**
 * A simple resolver anyone can use; only allows the owner of a node to set its
 * address.
 */
contract OwnedResolver is
    Ownable,
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    DNSResolver,
    InterfaceResolver,
    NameResolver,
    PubkeyResolver,
    TextResolver,
    ExtendedResolver
{
    function isAuthorised(bytes32) internal view override returns (bool) {
        return msg.sender == owner();
    }

    function supportsInterface(
        bytes4 interfaceID
    )
        public
        view
        virtual
        override(
            ABIResolver,
            AddrResolver,
            ContentHashResolver,
            DNSResolver,
            InterfaceResolver,
            NameResolver,
            PubkeyResolver,
            TextResolver
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/resolvers/profiles/ABIResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "./IABIResolver.sol";
import "../ResolverBase.sol";

abstract contract ABIResolver is IABIResolver, ResolverBase {
    mapping(uint64 => mapping(bytes32 => mapping(uint256 => bytes))) versionable_abis;

    /**
     * Sets the ABI associated with an ENS node.
     * Nodes may have one ABI of each content type. To remove an ABI, set it to
     * the empty string.
     * @param node The node to update.
     * @param contentType The content type of the ABI
     * @param data The ABI data.
     */
    function setABI(
        bytes32 node,
        uint256 contentType,
        bytes calldata data
    ) external virtual authorised(node) {
        // Content types must be powers of 2
        require(((contentType - 1) & contentType) == 0);

        versionable_abis[recordVersions[node]][node][contentType] = data;
        emit ABIChanged(node, contentType);
    }

    /**
     * Returns the ABI associated with an ENS node.
     * Defined in EIP205.
     * @param node The ENS node to query
     * @param contentTypes A bitwise OR of the ABI formats accepted by the caller.
     * @return contentType The content type of the return value
     * @return data The ABI data
     */
    function ABI(
        bytes32 node,
        uint256 contentTypes
    ) external view virtual override returns (uint256, bytes memory) {
        mapping(uint256 => bytes) storage abiset = versionable_abis[
            recordVersions[node]
        ][node];

        for (
            uint256 contentType = 1;
            contentType <= contentTypes;
            contentType <<= 1
        ) {
            if (
                (contentType & contentTypes) != 0 &&
                abiset[contentType].length > 0
            ) {
                return (contentType, abiset[contentType]);
            }
        }

        return (0, bytes(""));
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(IABIResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/resolvers/profiles/AddrResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "../ResolverBase.sol";
import "./IAddrResolver.sol";
import "./IAddressResolver.sol";

abstract contract AddrResolver is
    IAddrResolver,
    IAddressResolver,
    ResolverBase
{
    uint256 private constant COIN_TYPE_ETH = 60;

    mapping(uint64 => mapping(bytes32 => mapping(uint256 => bytes))) versionable_addresses;

    /**
     * Sets the address associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param a The address to set.
     */
    function setAddr(
        bytes32 node,
        address a
    ) external virtual authorised(node) {
        setAddr(node, COIN_TYPE_ETH, addressToBytes(a));
    }

    /**
     * Returns the address associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated address.
     */
    function addr(
        bytes32 node
    ) public view virtual override returns (address payable) {
        bytes memory a = addr(node, COIN_TYPE_ETH);
        if (a.length == 0) {
            return payable(0);
        }
        return bytesToAddress(a);
    }

    function setAddr(
        bytes32 node,
        uint256 coinType,
        bytes memory a
    ) public virtual authorised(node) {
        emit AddressChanged(node, coinType, a);
        if (coinType == COIN_TYPE_ETH) {
            emit AddrChanged(node, bytesToAddress(a));
        }
        versionable_addresses[recordVersions[node]][node][coinType] = a;
    }

    function addr(
        bytes32 node,
        uint256 coinType
    ) public view virtual override returns (bytes memory) {
        return versionable_addresses[recordVersions[node]][node][coinType];
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(IAddrResolver).interfaceId ||
            interfaceID == type(IAddressResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }

    function bytesToAddress(
        bytes memory b
    ) internal pure returns (address payable a) {
        require(b.length == 20);
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12))
        }
    }

    function addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}


// Chain: POLYGON - File: contracts/resolvers/profiles/ContentHashResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "../ResolverBase.sol";
import "./IContentHashResolver.sol";

abstract contract ContentHashResolver is IContentHashResolver, ResolverBase {
    mapping(uint64 => mapping(bytes32 => bytes)) versionable_hashes;

    /**
     * Sets the contenthash associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param hash The contenthash to set
     */
    function setContenthash(
        bytes32 node,
        bytes calldata hash
    ) external virtual authorised(node) {
        versionable_hashes[recordVersions[node]][node] = hash;
        emit ContenthashChanged(node, hash);
    }

    /**
     * Returns the contenthash associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated contenthash.
     */
    function contenthash(
        bytes32 node
    ) external view virtual override returns (bytes memory) {
        return versionable_hashes[recordVersions[node]][node];
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(IContentHashResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/resolvers/profiles/DNSResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "../ResolverBase.sol";
import "../../dnssec-oracle/RRUtils.sol";
import "./IDNSRecordResolver.sol";
import "./IDNSZoneResolver.sol";

abstract contract DNSResolver is
    IDNSRecordResolver,
    IDNSZoneResolver,
    ResolverBase
{
    using RRUtils for *;
    using BytesUtils for bytes;

    // Zone hashes for the domains.
    // A zone hash is an EIP-1577 content hash in binary format that should point to a
    // resource containing a single zonefile.
    // node => contenthash
    mapping(uint64 => mapping(bytes32 => bytes)) private versionable_zonehashes;

    // The records themselves.  Stored as binary RRSETs
    // node => version => name => resource => data
    mapping(uint64 => mapping(bytes32 => mapping(bytes32 => mapping(uint16 => bytes))))
        private versionable_records;

    // Count of number of entries for a given name.  Required for DNS resolvers
    // when resolving wildcards.
    // node => version => name => number of records
    mapping(uint64 => mapping(bytes32 => mapping(bytes32 => uint16)))
        private versionable_nameEntriesCount;

    /**
     * Set one or more DNS records.  Records are supplied in wire-format.
     * Records with the same node/name/resource must be supplied one after the
     * other to ensure the data is updated correctly. For example, if the data
     * was supplied:
     *     a.example.com IN A 1.2.3.4
     *     a.example.com IN A 5.6.7.8
     *     www.example.com IN CNAME a.example.com.
     * then this would store the two A records for a.example.com correctly as a
     * single RRSET, however if the data was supplied:
     *     a.example.com IN A 1.2.3.4
     *     www.example.com IN CNAME a.example.com.
     *     a.example.com IN A 5.6.7.8
     * then this would store the first A record, the CNAME, then the second A
     * record which would overwrite the first.
     *
     * @param node the namehash of the node for which to set the records
     * @param data the DNS wire format records to set
     */
    function setDNSRecords(
        bytes32 node,
        bytes calldata data
    ) external virtual authorised(node) {
        uint16 resource = 0;
        uint256 offset = 0;
        bytes memory name;
        bytes memory value;
        bytes32 nameHash;
        uint64 version = recordVersions[node];
        // Iterate over the data to add the resource records
        for (
            RRUtils.RRIterator memory iter = data.iterateRRs(0);
            !iter.done();
            iter.next()
        ) {
            if (resource == 0) {
                resource = iter.dnstype;
                name = iter.name();
                nameHash = keccak256(abi.encodePacked(name));
                value = bytes(iter.rdata());
            } else {
                bytes memory newName = iter.name();
                if (resource != iter.dnstype || !name.equals(newName)) {
                    setDNSRRSet(
                        node,
                        name,
                        resource,
                        data,
                        offset,
                        iter.offset - offset,
                        value.length == 0,
                        version
                    );
                    resource = iter.dnstype;
                    offset = iter.offset;
                    name = newName;
                    nameHash = keccak256(name);
                    value = bytes(iter.rdata());
                }
            }
        }
        if (name.length > 0) {
            setDNSRRSet(
                node,
                name,
                resource,
                data,
                offset,
                data.length - offset,
                value.length == 0,
                version
            );
        }
    }

    /**
     * Obtain a DNS record.
     * @param node the namehash of the node for which to fetch the record
     * @param name the keccak-256 hash of the fully-qualified name for which to fetch the record
     * @param resource the ID of the resource as per https://en.wikipedia.org/wiki/List_of_DNS_record_types
     * @return the DNS record in wire format if present, otherwise empty
     */
    function dnsRecord(
        bytes32 node,
        bytes32 name,
        uint16 resource
    ) public view virtual override returns (bytes memory) {
        return versionable_records[recordVersions[node]][node][name][resource];
    }

    /**
     * Check if a given node has records.
     * @param node the namehash of the node for which to check the records
     * @param name the namehash of the node for which to check the records
     */
    function hasDNSRecords(
        bytes32 node,
        bytes32 name
    ) public view virtual returns (bool) {
        return (versionable_nameEntriesCount[recordVersions[node]][node][
            name
        ] != 0);
    }

    /**
     * setZonehash sets the hash for the zone.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param hash The zonehash to set
     */
    function setZonehash(
        bytes32 node,
        bytes calldata hash
    ) external virtual authorised(node) {
        uint64 currentRecordVersion = recordVersions[node];
        bytes memory oldhash = versionable_zonehashes[currentRecordVersion][
            node
        ];
        versionable_zonehashes[currentRecordVersion][node] = hash;
        emit DNSZonehashChanged(node, oldhash, hash);
    }

    /**
     * zonehash obtains the hash for the zone.
     * @param node The ENS node to query.
     * @return The associated contenthash.
     */
    function zonehash(
        bytes32 node
    ) external view virtual override returns (bytes memory) {
        return versionable_zonehashes[recordVersions[node]][node];
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(IDNSRecordResolver).interfaceId ||
            interfaceID == type(IDNSZoneResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }

    function setDNSRRSet(
        bytes32 node,
        bytes memory name,
        uint16 resource,
        bytes memory data,
        uint256 offset,
        uint256 size,
        bool deleteRecord,
        uint64 version
    ) private {
        bytes32 nameHash = keccak256(name);
        bytes memory rrData = data.substring(offset, size);
        if (deleteRecord) {
            if (
                versionable_records[version][node][nameHash][resource].length !=
                0
            ) {
                versionable_nameEntriesCount[version][node][nameHash]--;
            }
            delete (versionable_records[version][node][nameHash][resource]);
            emit DNSRecordDeleted(node, name, resource);
        } else {
            if (
                versionable_records[version][node][nameHash][resource].length ==
                0
            ) {
                versionable_nameEntriesCount[version][node][nameHash]++;
            }
            versionable_records[version][node][nameHash][resource] = rrData;
            emit DNSRecordChanged(node, name, resource, rrData);
        }
    }
}


// Chain: POLYGON - File: contracts/resolvers/profiles/ExtendedDNSResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../resolvers/profiles/IExtendedDNSResolver.sol";
import "../../resolvers/profiles/IAddressResolver.sol";
import "../../resolvers/profiles/IAddrResolver.sol";
import "../../resolvers/profiles/ITextResolver.sol";
import "../../utils/HexUtils.sol";
import "../../utils/BytesUtils.sol";

/**
 * @dev Resolves names on ENS by interpreting record data stored in a DNS TXT record.
 *      This resolver implements the IExtendedDNSResolver interface, meaning that when
 *      a DNS name specifies it as the resolver via a TXT record, this resolver's
 *      resolve() method is invoked, and is passed any additional information from that
 *      text record. This resolver implements a simple text parser allowing a variety
 *      of records to be specified in text, which will then be used to resolve the name
 *      in ENS.
 *
 *      To use this, set a TXT record on your DNS name in the following format:
 *          ENS1 <address or name of ExtendedDNSResolver> <record data>
 *
 *      For example:
 *          ENS1 2.dnsname.ens.eth a[60]=0x1234...
 *
 *      The record data consists of a series of key=value pairs, separated by spaces. Keys
 *      may have an optional argument in square brackets, and values may be either unquoted
 *       - in which case they may not contain spaces - or single-quoted. Single quotes in
 *      a quoted value may be backslash-escaped.
 *
 *
 *                                       ┌────────┐
 *                                       │ ┌───┐  │
 *        ┌──────────────────────────────┴─┤" "│◄─┴────────────────────────────────────────┐
 *        │                                └───┘                                           │
 *        │  ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌────────────┐    ┌───┐ │
 *      ^─┴─►│key├─┬─►│"["├───►│arg├───►│"]"├─┬─►│"="├─┬─►│"'"├───►│quoted_value├───►│"'"├─┼─$
 *           └───┘ │  └───┘    └───┘    └───┘ │  └───┘ │  └───┘    └────────────┘    └───┘ │
 *                 └──────────────────────────┘        │          ┌──────────────┐         │
 *                                                     └─────────►│unquoted_value├─────────┘
 *                                                                └──────────────┘
 *
 *      Record types:
 *       - a[<coinType>] - Specifies how an `addr()` request should be resolved for the specified
 *         `coinType`. Ethereum has `coinType` 60. The value must be 0x-prefixed hexadecimal, and will
 *         be returned unmodified; this means that non-EVM addresses will need to be translated
 *         into binary format and then encoded in hex.
 *         Examples:
 *          - a[60]=0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7
 *          - a[0]=0x00149010587f8364b964fcaa70687216b53bd2cbd798
 *       - a[e<chainId>] - Specifies how an `addr()` request should be resolved for the specified
 *         `chainId`. The value must be 0x-prefixed hexadecimal. When encoding an address for an
 *         EVM-based cryptocurrency that uses a chainId instead of a coinType, this syntax *must*
 *         be used in place of the coin type - eg, Optimism is `a[e10]`, not `a[2147483658]`.
 *         A list of supported cryptocurrencies for both syntaxes can be found here:
 *           https://github.com/ensdomains/address-encoder/blob/master/docs/supported-cryptocurrencies.md
 *         Example:
 *          - a[e10]=0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7
 *       - t[<key>] - Specifies how a `text()` request should be resolved for the specified `key`.
 *         Examples:
 *          - t[com.twitter]=nicksdjohnson
 *          - t[url]='https://ens.domains/'
 *          - t[note]='I\'m great'
 */
contract ExtendedDNSResolver is IExtendedDNSResolver, IERC165 {
    using HexUtils for *;
    using BytesUtils for *;
    using Strings for *;

    uint256 private constant COIN_TYPE_ETH = 60;

    error NotImplemented();
    error InvalidAddressFormat(bytes addr);

    function supportsInterface(
        bytes4 interfaceId
    ) external view virtual override returns (bool) {
        return interfaceId == type(IExtendedDNSResolver).interfaceId;
    }

    function resolve(
        bytes calldata /* name */,
        bytes calldata data,
        bytes calldata context
    ) external pure override returns (bytes memory) {
        bytes4 selector = bytes4(data);
        if (selector == IAddrResolver.addr.selector) {
            return _resolveAddr(context);
        } else if (selector == IAddressResolver.addr.selector) {
            return _resolveAddress(data, context);
        } else if (selector == ITextResolver.text.selector) {
            return _resolveText(data, context);
        }
        revert NotImplemented();
    }

    function _resolveAddress(
        bytes calldata data,
        bytes calldata context
    ) internal pure returns (bytes memory) {
        (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
        bytes memory value;
        // Per https://docs.ens.domains/ensip/11#specification
        if (coinType & 0x80000000 != 0) {
            value = _findValue(
                context,
                bytes.concat(
                    "a[e",
                    bytes((coinType & 0x7fffffff).toString()),
                    "]="
                )
            );
        } else {
            value = _findValue(
                context,
                bytes.concat("a[", bytes(coinType.toString()), "]=")
            );
        }
        if (value.length == 0) {
            return value;
        }
        (bytes memory record, bool valid) = value.hexToBytes(2, value.length);
        if (!valid) revert InvalidAddressFormat(value);
        return record;
    }

    function _resolveAddr(
        bytes calldata context
    ) internal pure returns (bytes memory) {
        bytes memory value = _findValue(context, "a[60]=");
        if (value.length == 0) {
            return value;
        }
        (bytes memory record, bool valid) = value.hexToBytes(2, value.length);
        if (!valid) revert InvalidAddressFormat(value);
        return record;
    }

    function _resolveText(
        bytes calldata data,
        bytes calldata context
    ) internal pure returns (bytes memory) {
        (, string memory key) = abi.decode(data[4:], (bytes32, string));
        bytes memory value = _findValue(
            context,
            bytes.concat("t[", bytes(key), "]=")
        );
        return value;
    }

    uint256 constant STATE_START = 0;
    uint256 constant STATE_IGNORED_KEY = 1;
    uint256 constant STATE_IGNORED_KEY_ARG = 2;
    uint256 constant STATE_VALUE = 3;
    uint256 constant STATE_QUOTED_VALUE = 4;
    uint256 constant STATE_UNQUOTED_VALUE = 5;
    uint256 constant STATE_IGNORED_VALUE = 6;
    uint256 constant STATE_IGNORED_QUOTED_VALUE = 7;
    uint256 constant STATE_IGNORED_UNQUOTED_VALUE = 8;

    /**
     * @dev Implements a DFA to parse the text record, looking for an entry
     *      matching `key`.
     * @param data The text record to parse.
     * @param key The exact key to search for.
     * @return value The value if found, or an empty string if `key` does not exist.
     */
    function _findValue(
        bytes memory data,
        bytes memory key
    ) internal pure returns (bytes memory value) {
        // Here we use a simple state machine to parse the text record. We
        // process characters one at a time; each character can trigger a
        // transition to a new state, or terminate the DFA and return a value.
        // For states that expect to process a number of tokens, we use
        // inner loops for efficiency reasons, to avoid the need to go
        // through the outer loop and switch statement for every character.
        uint256 state = STATE_START;
        uint256 len = data.length;
        for (uint256 i = 0; i < len; ) {
            if (state == STATE_START) {
                // Look for a matching key.
                if (data.equals(i, key, 0, key.length)) {
                    i += key.length;
                    state = STATE_VALUE;
                } else {
                    state = STATE_IGNORED_KEY;
                }
            } else if (state == STATE_IGNORED_KEY) {
                for (; i < len; i++) {
                    if (data[i] == "=") {
                        state = STATE_IGNORED_VALUE;
                        i += 1;
                        break;
                    } else if (data[i] == "[") {
                        state = STATE_IGNORED_KEY_ARG;
                        i += 1;
                        break;
                    }
                }
            } else if (state == STATE_IGNORED_KEY_ARG) {
                for (; i < len; i++) {
                    if (data[i] == "]") {
                        state = STATE_IGNORED_VALUE;
                        i += 1;
                        if (data[i] == "=") {
                            i += 1;
                        }
                        break;
                    }
                }
            } else if (state == STATE_VALUE) {
                if (data[i] == "'") {
                    state = STATE_QUOTED_VALUE;
                    i += 1;
                } else {
                    state = STATE_UNQUOTED_VALUE;
                }
            } else if (state == STATE_QUOTED_VALUE) {
                uint256 start = i;
                uint256 valueLen = 0;
                bool escaped = false;
                for (; i < len; i++) {
                    if (escaped) {
                        data[start + valueLen] = data[i];
                        valueLen += 1;
                        escaped = false;
                    } else {
                        if (data[i] == "\\") {
                            escaped = true;
                        } else if (data[i] == "'") {
                            return data.substring(start, valueLen);
                        } else {
                            data[start + valueLen] = data[i];
                            valueLen += 1;
                        }
                    }
                }
            } else if (state == STATE_UNQUOTED_VALUE) {
                uint256 start = i;
                for (; i < len; i++) {
                    if (data[i] == " ") {
                        return data.substring(start, i - start);
                    }
                }
                return data.substring(start, len - start);
            } else if (state == STATE_IGNORED_VALUE) {
                if (data[i] == "'") {
                    state = STATE_IGNORED_QUOTED_VALUE;
                    i += 1;
                } else {
                    state = STATE_IGNORED_UNQUOTED_VALUE;
                }
            } else if (state == STATE_IGNORED_QUOTED_VALUE) {
                bool escaped = false;
                for (; i < len; i++) {
                    if (escaped) {
                        escaped = false;
                    } else {
                        if (data[i] == "\\") {
                            escaped = true;
                        } else if (data[i] == "'") {
                            i += 1;
                            while (data[i] == " ") {
                                i += 1;
                            }
                            state = STATE_START;
                            break;
                        }
                    }
                }
            } else {
                assert(state == STATE_IGNORED_UNQUOTED_VALUE);
                for (; i < len; i++) {
                    if (data[i] == " ") {
                        while (data[i] == " ") {
                            i += 1;
                        }
                        state = STATE_START;
                        break;
                    }
                }
            }
        }
        return "";
    }
}


// Chain: POLYGON - File: contracts/resolvers/profiles/ExtendedResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract ExtendedResolver {
    function resolve(
        bytes memory /* name */,
        bytes memory data
    ) external view returns (bytes memory) {
        (bool success, bytes memory result) = address(this).staticcall(data);
        if (success) {
            return result;
        } else {
            // Revert with the reason provided by the call
            assembly {
                revert(add(result, 0x20), mload(result))
            }
        }
    }
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IABIResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IABIResolver {
    event ABIChanged(bytes32 indexed node, uint256 indexed contentType);

    /**
     * Returns the ABI associated with an ENS node.
     * Defined in EIP205.
     * @param node The ENS node to query
     * @param contentTypes A bitwise OR of the ABI formats accepted by the caller.
     * @return contentType The content type of the return value
     * @return data The ABI data
     */
    function ABI(
        bytes32 node,
        uint256 contentTypes
    ) external view returns (uint256, bytes memory);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IAddressResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/**
 * Interface for the new (multicoin) addr function.
 */
interface IAddressResolver {
    event AddressChanged(
        bytes32 indexed node,
        uint256 coinType,
        bytes newAddress
    );

    function addr(
        bytes32 node,
        uint256 coinType
    ) external view returns (bytes memory);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IAddrResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/**
 * Interface for the legacy (ETH-only) addr function.
 */
interface IAddrResolver {
    event AddrChanged(bytes32 indexed node, address a);

    /**
     * Returns the address associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated address.
     */
    function addr(bytes32 node) external view returns (address payable);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IContentHashResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IContentHashResolver {
    event ContenthashChanged(bytes32 indexed node, bytes hash);

    /**
     * Returns the contenthash associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated contenthash.
     */
    function contenthash(bytes32 node) external view returns (bytes memory);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IDNSRecordResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IDNSRecordResolver {
    // DNSRecordChanged is emitted whenever a given node/name/resource's RRSET is updated.
    event DNSRecordChanged(
        bytes32 indexed node,
        bytes name,
        uint16 resource,
        bytes record
    );
    // DNSRecordDeleted is emitted whenever a given node/name/resource's RRSET is deleted.
    event DNSRecordDeleted(bytes32 indexed node, bytes name, uint16 resource);

    /**
     * Obtain a DNS record.
     * @param node the namehash of the node for which to fetch the record
     * @param name the keccak-256 hash of the fully-qualified name for which to fetch the record
     * @param resource the ID of the resource as per https://en.wikipedia.org/wiki/List_of_DNS_record_types
     * @return the DNS record in wire format if present, otherwise empty
     */
    function dnsRecord(
        bytes32 node,
        bytes32 name,
        uint16 resource
    ) external view returns (bytes memory);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IDNSZoneResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IDNSZoneResolver {
    // DNSZonehashChanged is emitted whenever a given node's zone hash is updated.
    event DNSZonehashChanged(
        bytes32 indexed node,
        bytes lastzonehash,
        bytes zonehash
    );

    /**
     * zonehash obtains the hash for the zone.
     * @param node The ENS node to query.
     * @return The associated contenthash.
     */
    function zonehash(bytes32 node) external view returns (bytes memory);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IExtendedDNSResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IExtendedDNSResolver {
    function resolve(
        bytes memory name,
        bytes memory data,
        bytes memory context
    ) external view returns (bytes memory);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IExtendedResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IExtendedResolver {
    function resolve(
        bytes memory name,
        bytes memory data
    ) external view returns (bytes memory);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IInterfaceResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IInterfaceResolver {
    event InterfaceChanged(
        bytes32 indexed node,
        bytes4 indexed interfaceID,
        address implementer
    );

    /**
     * Returns the address of a contract that implements the specified interface for this name.
     * If an implementer has not been set for this interfaceID and name, the resolver will query
     * the contract at `addr()`. If `addr()` is set, a contract exists at that address, and that
     * contract implements EIP165 and returns `true` for the specified interfaceID, its address
     * will be returned.
     * @param node The ENS node to query.
     * @param interfaceID The EIP 165 interface ID to check for.
     * @return The address that implements this interface, or 0 if the interface is unsupported.
     */
    function interfaceImplementer(
        bytes32 node,
        bytes4 interfaceID
    ) external view returns (address);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/INameResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface INameResolver {
    event NameChanged(bytes32 indexed node, string name);

    /**
     * Returns the name associated with an ENS node, for reverse records.
     * Defined in EIP181.
     * @param node The ENS node to query.
     * @return The associated name.
     */
    function name(bytes32 node) external view returns (string memory);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/InterfaceResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../ResolverBase.sol";
import "./AddrResolver.sol";
import "./IInterfaceResolver.sol";

abstract contract InterfaceResolver is IInterfaceResolver, AddrResolver {
    mapping(uint64 => mapping(bytes32 => mapping(bytes4 => address))) versionable_interfaces;

    /**
     * Sets an interface associated with a name.
     * Setting the address to 0 restores the default behaviour of querying the contract at `addr()` for interface support.
     * @param node The node to update.
     * @param interfaceID The EIP 165 interface ID.
     * @param implementer The address of a contract that implements this interface for this node.
     */
    function setInterface(
        bytes32 node,
        bytes4 interfaceID,
        address implementer
    ) external virtual authorised(node) {
        versionable_interfaces[recordVersions[node]][node][
            interfaceID
        ] = implementer;
        emit InterfaceChanged(node, interfaceID, implementer);
    }

    /**
     * Returns the address of a contract that implements the specified interface for this name.
     * If an implementer has not been set for this interfaceID and name, the resolver will query
     * the contract at `addr()`. If `addr()` is set, a contract exists at that address, and that
     * contract implements EIP165 and returns `true` for the specified interfaceID, its address
     * will be returned.
     * @param node The ENS node to query.
     * @param interfaceID The EIP 165 interface ID to check for.
     * @return The address that implements this interface, or 0 if the interface is unsupported.
     */
    function interfaceImplementer(
        bytes32 node,
        bytes4 interfaceID
    ) external view virtual override returns (address) {
        address implementer = versionable_interfaces[recordVersions[node]][
            node
        ][interfaceID];
        if (implementer != address(0)) {
            return implementer;
        }

        address a = addr(node);
        if (a == address(0)) {
            return address(0);
        }

        (bool success, bytes memory returnData) = a.staticcall(
            abi.encodeWithSignature(
                "supportsInterface(bytes4)",
                type(IERC165).interfaceId
            )
        );
        if (!success || returnData.length < 32 || returnData[31] == 0) {
            // EIP 165 not supported by target
            return address(0);
        }

        (success, returnData) = a.staticcall(
            abi.encodeWithSignature("supportsInterface(bytes4)", interfaceID)
        );
        if (!success || returnData.length < 32 || returnData[31] == 0) {
            // Specified interface not supported by target
            return address(0);
        }

        return a;
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(IInterfaceResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IPubkeyResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IPubkeyResolver {
    event PubkeyChanged(bytes32 indexed node, bytes32 x, bytes32 y);

    /**
     * Returns the SECP256k1 public key associated with an ENS node.
     * Defined in EIP 619.
     * @param node The ENS node to query
     * @return x The X coordinate of the curve point for the public key.
     * @return y The Y coordinate of the curve point for the public key.
     */
    function pubkey(bytes32 node) external view returns (bytes32 x, bytes32 y);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/ITextResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface ITextResolver {
    event TextChanged(
        bytes32 indexed node,
        string indexed indexedKey,
        string key,
        string value
    );

    /**
     * Returns the text data associated with an ENS node and key.
     * @param node The ENS node to query.
     * @param key The text data key to query.
     * @return The associated text data.
     */
    function text(
        bytes32 node,
        string calldata key
    ) external view returns (string memory);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/IVersionableResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IVersionableResolver {
    event VersionChanged(bytes32 indexed node, uint64 newVersion);

    function recordVersions(bytes32 node) external view returns (uint64);
}


// Chain: POLYGON - File: contracts/resolvers/profiles/NameResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "../ResolverBase.sol";
import "./INameResolver.sol";

abstract contract NameResolver is INameResolver, ResolverBase {
    mapping(uint64 => mapping(bytes32 => string)) versionable_names;

    /**
     * Sets the name associated with an ENS node, for reverse records.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     */
    function setName(
        bytes32 node,
        string calldata newName
    ) external virtual authorised(node) {
        versionable_names[recordVersions[node]][node] = newName;
        emit NameChanged(node, newName);
    }

    /**
     * Returns the name associated with an ENS node, for reverse records.
     * Defined in EIP181.
     * @param node The ENS node to query.
     * @return The associated name.
     */
    function name(
        bytes32 node
    ) external view virtual override returns (string memory) {
        return versionable_names[recordVersions[node]][node];
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(INameResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/resolvers/profiles/PubkeyResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "../ResolverBase.sol";
import "./IPubkeyResolver.sol";

abstract contract PubkeyResolver is IPubkeyResolver, ResolverBase {
    struct PublicKey {
        bytes32 x;
        bytes32 y;
    }

    mapping(uint64 => mapping(bytes32 => PublicKey)) versionable_pubkeys;

    /**
     * Sets the SECP256k1 public key associated with an ENS node.
     * @param node The ENS node to query
     * @param x the X coordinate of the curve point for the public key.
     * @param y the Y coordinate of the curve point for the public key.
     */
    function setPubkey(
        bytes32 node,
        bytes32 x,
        bytes32 y
    ) external virtual authorised(node) {
        versionable_pubkeys[recordVersions[node]][node] = PublicKey(x, y);
        emit PubkeyChanged(node, x, y);
    }

    /**
     * Returns the SECP256k1 public key associated with an ENS node.
     * Defined in EIP 619.
     * @param node The ENS node to query
     * @return x The X coordinate of the curve point for the public key.
     * @return y The Y coordinate of the curve point for the public key.
     */
    function pubkey(
        bytes32 node
    ) external view virtual override returns (bytes32 x, bytes32 y) {
        uint64 currentRecordVersion = recordVersions[node];
        return (
            versionable_pubkeys[currentRecordVersion][node].x,
            versionable_pubkeys[currentRecordVersion][node].y
        );
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(IPubkeyResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/resolvers/profiles/TextResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "../ResolverBase.sol";
import "./ITextResolver.sol";

abstract contract TextResolver is ITextResolver, ResolverBase {
    mapping(uint64 => mapping(bytes32 => mapping(string => string))) versionable_texts;

    /**
     * Sets the text data associated with an ENS node and key.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param key The key to set.
     * @param value The text data value to set.
     */
    function setText(
        bytes32 node,
        string calldata key,
        string calldata value
    ) external virtual authorised(node) {
        versionable_texts[recordVersions[node]][node][key] = value;
        emit TextChanged(node, key, key, value);
    }

    /**
     * Returns the text data associated with an ENS node and key.
     * @param node The ENS node to query.
     * @param key The text data key to query.
     * @return The associated text data.
     */
    function text(
        bytes32 node,
        string calldata key
    ) external view virtual override returns (string memory) {
        return versionable_texts[recordVersions[node]][node][key];
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(ITextResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/resolvers/PublicResolver.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "../registry/ENS.sol";
import "./profiles/ABIResolver.sol";
import "./profiles/AddrResolver.sol";
import "./profiles/ContentHashResolver.sol";
import "./profiles/DNSResolver.sol";
import "./profiles/InterfaceResolver.sol";
import "./profiles/NameResolver.sol";
import "./profiles/PubkeyResolver.sol";
import "./profiles/TextResolver.sol";
import "./Multicallable.sol";
import {ReverseClaimer} from "../reverseRegistrar/ReverseClaimer.sol";
import {INameWrapper} from "../wrapper/INameWrapper.sol";

/**
 * A simple resolver anyone can use; only allows the owner of a node to set its
 * address.
 */
contract PublicResolver is
    Multicallable,
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    DNSResolver,
    InterfaceResolver,
    NameResolver,
    PubkeyResolver,
    TextResolver,
    ReverseClaimer
{
    ENS immutable ens;
    INameWrapper immutable nameWrapper;
    address immutable trustedETHController;
    address immutable trustedReverseRegistrar;

    /**
     * A mapping of operators. An address that is authorised for an address
     * may make any changes to the name that the owner could, but may not update
     * the set of authorisations.
     * (owner, operator) => approved
     */
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * A mapping of delegates. A delegate that is authorised by an owner
     * for a name may make changes to the name's resolver, but may not update
     * the set of token approvals.
     * (owner, name, delegate) => approved
     */
    mapping(address => mapping(bytes32 => mapping(address => bool)))
        private _tokenApprovals;

    // Logged when an operator is added or removed.
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // Logged when a delegate is approved or  an approval is revoked.
    event Approved(
        address owner,
        bytes32 indexed node,
        address indexed delegate,
        bool indexed approved
    );

    constructor(
        ENS _ens,
        INameWrapper wrapperAddress,
        address _trustedETHController,
        address _trustedReverseRegistrar
    ) ReverseClaimer(_ens, msg.sender) {
        ens = _ens;
        nameWrapper = wrapperAddress;
        trustedETHController = _trustedETHController;
        trustedReverseRegistrar = _trustedReverseRegistrar;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external {
        require(
            msg.sender != operator,
            "ERC1155: setting approval status for self"
        );

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(
        address account,
        address operator
    ) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev Approve a delegate to be able to updated records on a node.
     */
    function approve(bytes32 node, address delegate, bool approved) external {
        require(msg.sender != delegate, "Setting delegate status for self");

        _tokenApprovals[msg.sender][node][delegate] = approved;
        emit Approved(msg.sender, node, delegate, approved);
    }

    /**
     * @dev Check to see if the delegate has been approved by the owner for the node.
     */
    function isApprovedFor(
        address owner,
        bytes32 node,
        address delegate
    ) public view returns (bool) {
        return _tokenApprovals[owner][node][delegate];
    }

    function isAuthorised(bytes32 node) internal view override returns (bool) {
        if (
            msg.sender == trustedETHController ||
            msg.sender == trustedReverseRegistrar
        ) {
            return true;
        }
        address owner = ens.owner(node);
        if (owner == address(nameWrapper)) {
            owner = nameWrapper.ownerOf(uint256(node));
        }
        return
            owner == msg.sender ||
            isApprovedForAll(owner, msg.sender) ||
            isApprovedFor(owner, node, msg.sender);
    }

    function supportsInterface(
        bytes4 interfaceID
    )
        public
        view
        override(
            Multicallable,
            ABIResolver,
            AddrResolver,
            ContentHashResolver,
            DNSResolver,
            InterfaceResolver,
            NameResolver,
            PubkeyResolver,
            TextResolver
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/resolvers/Resolver.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./profiles/IABIResolver.sol";
import "./profiles/IAddressResolver.sol";
import "./profiles/IAddrResolver.sol";
import "./profiles/IContentHashResolver.sol";
import "./profiles/IDNSRecordResolver.sol";
import "./profiles/IDNSZoneResolver.sol";
import "./profiles/IInterfaceResolver.sol";
import "./profiles/INameResolver.sol";
import "./profiles/IPubkeyResolver.sol";
import "./profiles/ITextResolver.sol";
import "./profiles/IExtendedResolver.sol";

/**
 * A generic resolver interface which includes all the functions including the ones deprecated
 */
interface Resolver is
    IERC165,
    IABIResolver,
    IAddressResolver,
    IAddrResolver,
    IContentHashResolver,
    IDNSRecordResolver,
    IDNSZoneResolver,
    IInterfaceResolver,
    INameResolver,
    IPubkeyResolver,
    ITextResolver,
    IExtendedResolver
{
    /* Deprecated events */
    event ContentChanged(bytes32 indexed node, bytes32 hash);

    function setApprovalForAll(address, bool) external;

    function approve(bytes32 node, address delegate, bool approved) external;

    function isApprovedForAll(address account, address operator) external;

    function isApprovedFor(
        address owner,
        bytes32 node,
        address delegate
    ) external;

    function setABI(
        bytes32 node,
        uint256 contentType,
        bytes calldata data
    ) external;

    function setAddr(bytes32 node, address addr) external;

    function setAddr(bytes32 node, uint256 coinType, bytes calldata a) external;

    function setContenthash(bytes32 node, bytes calldata hash) external;

    function setDnsrr(bytes32 node, bytes calldata data) external;

    function setName(bytes32 node, string calldata _name) external;

    function setPubkey(bytes32 node, bytes32 x, bytes32 y) external;

    function setText(
        bytes32 node,
        string calldata key,
        string calldata value
    ) external;

    function setInterface(
        bytes32 node,
        bytes4 interfaceID,
        address implementer
    ) external;

    function multicall(
        bytes[] calldata data
    ) external returns (bytes[] memory results);

    function multicallWithNodeCheck(
        bytes32 nodehash,
        bytes[] calldata data
    ) external returns (bytes[] memory results);

    /* Deprecated functions */
    function content(bytes32 node) external view returns (bytes32);

    function multihash(bytes32 node) external view returns (bytes memory);

    function setContent(bytes32 node, bytes32 hash) external;

    function setMultihash(bytes32 node, bytes calldata hash) external;
}


// Chain: POLYGON - File: contracts/resolvers/ResolverBase.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./profiles/IVersionableResolver.sol";

abstract contract ResolverBase is ERC165, IVersionableResolver {
    mapping(bytes32 => uint64) public recordVersions;

    function isAuthorised(bytes32 node) internal view virtual returns (bool);

    modifier authorised(bytes32 node) {
        require(isAuthorised(node));
        _;
    }

    /**
     * Increments the record version associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     */
    function clearRecords(bytes32 node) public virtual authorised(node) {
        recordVersions[node]++;
        emit VersionChanged(node, recordVersions[node]);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(IVersionableResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }
}


// Chain: POLYGON - File: contracts/reverseRegistrar/IReverseRegistrar.sol
pragma solidity >=0.8.4;

interface IReverseRegistrar {
    function setDefaultResolver(address resolver) external;

    function claim(address owner) external returns (bytes32);

    function claimForAddr(
        address addr,
        address owner,
        address resolver
    ) external returns (bytes32);

    function claimWithResolver(
        address owner,
        address resolver
    ) external returns (bytes32);

    function setName(string memory name) external returns (bytes32);

    function setNameForAddr(
        address addr,
        address owner,
        address resolver,
        string memory name
    ) external returns (bytes32);

    function node(address addr) external pure returns (bytes32);
}


// Chain: POLYGON - File: contracts/reverseRegistrar/ReverseClaimer.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {ENS} from "../registry/ENS.sol";
import {IReverseRegistrar} from "../reverseRegistrar/IReverseRegistrar.sol";

contract ReverseClaimer {
    bytes32 constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    constructor(ENS ens, address claimant) {
        IReverseRegistrar reverseRegistrar = IReverseRegistrar(
            ens.owner(ADDR_REVERSE_NODE)
        );
        reverseRegistrar.claim(claimant);
    }
}


// Chain: POLYGON - File: contracts/reverseRegistrar/ReverseRegistrar.sol
pragma solidity >=0.8.4;

import "../registry/ENS.sol";
import "./IReverseRegistrar.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../root/Controllable.sol";

abstract contract NameResolver {
    function setName(bytes32 node, string memory name) public virtual;
}

bytes32 constant lookup = 0x3031323334353637383961626364656600000000000000000000000000000000;

bytes32 constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

// namehash('addr.reverse')

contract ReverseRegistrar is Ownable, Controllable, IReverseRegistrar {
    ENS public immutable ens;
    NameResolver public defaultResolver;

    event ReverseClaimed(address indexed addr, bytes32 indexed node);
    event DefaultResolverChanged(NameResolver indexed resolver);

    /**
     * @dev Constructor
     * @param ensAddr The address of the ENS registry.
     */
    constructor(ENS ensAddr) {
        ens = ensAddr;

        // Assign ownership of the reverse record to our deployer
        ReverseRegistrar oldRegistrar = ReverseRegistrar(
            ensAddr.owner(ADDR_REVERSE_NODE)
        );
        if (address(oldRegistrar) != address(0x0)) {
            oldRegistrar.claim(msg.sender);
        }
    }

    modifier authorised(address addr) {
        require(
            addr == msg.sender ||
                controllers[msg.sender] ||
                ens.isApprovedForAll(addr, msg.sender) ||
                ownsContract(addr),
            "ReverseRegistrar: Caller is not a controller or authorised by address or the address itself"
        );
        _;
    }

    function setDefaultResolver(address resolver) public override onlyOwner {
        require(
            address(resolver) != address(0),
            "ReverseRegistrar: Resolver address must not be 0"
        );
        defaultResolver = NameResolver(resolver);
        emit DefaultResolverChanged(NameResolver(resolver));
    }

    /**
     * @dev Transfers ownership of the reverse ENS record associated with the
     *      calling account.
     * @param owner The address to set as the owner of the reverse record in ENS.
     * @return The ENS node hash of the reverse record.
     */
    function claim(address owner) public override returns (bytes32) {
        return claimForAddr(msg.sender, owner, address(defaultResolver));
    }

    /**
     * @dev Transfers ownership of the reverse ENS record associated with the
     *      calling account.
     * @param addr The reverse record to set
     * @param owner The address to set as the owner of the reverse record in ENS.
     * @param resolver The resolver of the reverse node
     * @return The ENS node hash of the reverse record.
     */
    function claimForAddr(
        address addr,
        address owner,
        address resolver
    ) public override authorised(addr) returns (bytes32) {
        bytes32 labelHash = sha3HexAddress(addr);
        bytes32 reverseNode = keccak256(
            abi.encodePacked(ADDR_REVERSE_NODE, labelHash)
        );
        emit ReverseClaimed(addr, reverseNode);
        ens.setSubnodeRecord(ADDR_REVERSE_NODE, labelHash, owner, resolver, 0);
        return reverseNode;
    }

    /**
     * @dev Transfers ownership of the reverse ENS record associated with the
     *      calling account.
     * @param owner The address to set as the owner of the reverse record in ENS.
     * @param resolver The address of the resolver to set; 0 to leave unchanged.
     * @return The ENS node hash of the reverse record.
     */
    function claimWithResolver(
        address owner,
        address resolver
    ) public override returns (bytes32) {
        return claimForAddr(msg.sender, owner, resolver);
    }

    /**
     * @dev Sets the `name()` record for the reverse ENS record associated with
     * the calling account. First updates the resolver to the default reverse
     * resolver if necessary.
     * @param name The name to set for this address.
     * @return The ENS node hash of the reverse record.
     */
    function setName(string memory name) public override returns (bytes32) {
        return
            setNameForAddr(
                msg.sender,
                msg.sender,
                address(defaultResolver),
                name
            );
    }

    /**
     * @dev Sets the `name()` record for the reverse ENS record associated with
     * the account provided. Updates the resolver to a designated resolver
     * Only callable by controllers and authorised users
     * @param addr The reverse record to set
     * @param owner The owner of the reverse node
     * @param resolver The resolver of the reverse node
     * @param name The name to set for this address.
     * @return The ENS node hash of the reverse record.
     */
    function setNameForAddr(
        address addr,
        address owner,
        address resolver,
        string memory name
    ) public override returns (bytes32) {
        bytes32 node = claimForAddr(addr, owner, resolver);
        NameResolver(resolver).setName(node, name);
        return node;
    }

    /**
     * @dev Returns the node hash for a given account's reverse records.
     * @param addr The address to hash
     * @return The ENS node hash.
     */
    function node(address addr) public pure override returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr))
            );
    }

    /**
     * @dev An optimised function to compute the sha3 of the lower-case
     *      hexadecimal representation of an Ethereum address.
     * @param addr The address to hash
     * @return ret The SHA3 hash of the lower-case hexadecimal encoding of the
     *         input address.
     */
    function sha3HexAddress(address addr) private pure returns (bytes32 ret) {
        assembly {
            for {
                let i := 40
            } gt(i, 0) {

            } {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }

    function ownsContract(address addr) internal view returns (bool) {
        try Ownable(addr).owner() returns (address owner) {
            return owner == msg.sender;
        } catch {
            return false;
        }
    }
}


// Chain: POLYGON - File: contracts/root/Controllable.sol
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Controllable is Ownable {
    mapping(address => bool) public controllers;

    event ControllerChanged(address indexed controller, bool enabled);

    modifier onlyController() {
        require(
            controllers[msg.sender],
            "Controllable: Caller is not a controller"
        );
        _;
    }

    function setController(address controller, bool enabled) public onlyOwner {
        controllers[controller] = enabled;
        emit ControllerChanged(controller, enabled);
    }
}


// Chain: POLYGON - File: contracts/root/Ownable.sol
pragma solidity ^0.8.4;

contract Ownable {
    address public owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(isOwner(msg.sender));
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function isOwner(address addr) public view returns (bool) {
        return owner == addr;
    }
}


// Chain: POLYGON - File: contracts/root/Root.sol
pragma solidity ^0.8.4;

import "../registry/ENS.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Controllable.sol";

contract Root is Ownable, Controllable {
    bytes32 private constant ROOT_NODE = bytes32(0);

    bytes4 private constant INTERFACE_META_ID =
        bytes4(keccak256("supportsInterface(bytes4)"));

    event TLDLocked(bytes32 indexed label);

    ENS public ens;
    mapping(bytes32 => bool) public locked;

    constructor(ENS _ens) public {
        ens = _ens;
    }

    function setSubnodeOwner(
        bytes32 label,
        address owner
    ) external onlyController {
        require(!locked[label]);
        ens.setSubnodeOwner(ROOT_NODE, label, owner);
    }

    function setResolver(address resolver) external onlyOwner {
        ens.setResolver(ROOT_NODE, resolver);
    }

    function lock(bytes32 label) external onlyOwner {
        emit TLDLocked(label);
        locked[label] = true;
    }

    function supportsInterface(
        bytes4 interfaceID
    ) external pure returns (bool) {
        return interfaceID == INTERFACE_META_ID;
    }
}


// Chain: POLYGON - File: contracts/utils/BytesUtils.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library BytesUtils {
    error OffsetOutOfBoundsError(uint256 offset, uint256 length);

    /*
     * @dev Returns the keccak-256 hash of a byte range.
     * @param self The byte string to hash.
     * @param offset The position to start hashing at.
     * @param len The number of bytes to hash.
     * @return The hash of the byte range.
     */
    function keccak(
        bytes memory self,
        uint256 offset,
        uint256 len
    ) internal pure returns (bytes32 ret) {
        require(offset + len <= self.length);
        assembly {
            ret := keccak256(add(add(self, 32), offset), len)
        }
    }

    /**
     * @dev Returns the ENS namehash of a DNS-encoded name.
     * @param self The DNS-encoded name to hash.
     * @param offset The offset at which to start hashing.
     * @return The namehash of the name.
     */
    function namehash(
        bytes memory self,
        uint256 offset
    ) internal pure returns (bytes32) {
        (bytes32 labelhash, uint256 newOffset) = readLabel(self, offset);
        if (labelhash == bytes32(0)) {
            require(offset == self.length - 1, "namehash: Junk at end of name");
            return bytes32(0);
        }
        return
            keccak256(abi.encodePacked(namehash(self, newOffset), labelhash));
    }

    /**
     * @dev Returns the keccak-256 hash of a DNS-encoded label, and the offset to the start of the next label.
     * @param self The byte string to read a label from.
     * @param idx The index to read a label at.
     * @return labelhash The hash of the label at the specified index, or 0 if it is the last label.
     * @return newIdx The index of the start of the next label.
     */
    function readLabel(
        bytes memory self,
        uint256 idx
    ) internal pure returns (bytes32 labelhash, uint256 newIdx) {
        require(idx < self.length, "readLabel: Index out of bounds");
        uint256 len = uint256(uint8(self[idx]));
        if (len > 0) {
            labelhash = keccak(self, idx + 1, len);
        } else {
            labelhash = bytes32(0);
        }
        newIdx = idx + len + 1;
    }

    /*
     * @dev Returns a positive number if `other` comes lexicographically after
     *      `self`, a negative number if it comes before, or zero if the
     *      contents of the two bytes are equal.
     * @param self The first bytes to compare.
     * @param other The second bytes to compare.
     * @return The result of the comparison.
     */
    function compare(
        bytes memory self,
        bytes memory other
    ) internal pure returns (int256) {
        return compare(self, 0, self.length, other, 0, other.length);
    }

    /*
     * @dev Returns a positive number if `other` comes lexicographically after
     *      `self`, a negative number if it comes before, or zero if the
     *      contents of the two bytes are equal. Comparison is done per-rune,
     *      on unicode codepoints.
     * @param self The first bytes to compare.
     * @param offset The offset of self.
     * @param len    The length of self.
     * @param other The second bytes to compare.
     * @param otheroffset The offset of the other string.
     * @param otherlen    The length of the other string.
     * @return The result of the comparison.
     */
    function compare(
        bytes memory self,
        uint256 offset,
        uint256 len,
        bytes memory other,
        uint256 otheroffset,
        uint256 otherlen
    ) internal pure returns (int256) {
        if (offset + len > self.length) {
            revert OffsetOutOfBoundsError(offset + len, self.length);
        }
        if (otheroffset + otherlen > other.length) {
            revert OffsetOutOfBoundsError(otheroffset + otherlen, other.length);
        }

        uint256 shortest = len;
        if (otherlen < len) shortest = otherlen;

        uint256 selfptr;
        uint256 otherptr;

        assembly {
            selfptr := add(self, add(offset, 32))
            otherptr := add(other, add(otheroffset, 32))
        }
        for (uint256 idx = 0; idx < shortest; idx += 32) {
            uint256 a;
            uint256 b;
            assembly {
                a := mload(selfptr)
                b := mload(otherptr)
            }
            if (a != b) {
                // Mask out irrelevant bytes and check again
                uint256 mask;
                if (shortest - idx >= 32) {
                    mask = type(uint256).max;
                } else {
                    mask = ~(2 ** (8 * (idx + 32 - shortest)) - 1);
                }
                int256 diff = int256(a & mask) - int256(b & mask);
                if (diff != 0) return diff;
            }
            selfptr += 32;
            otherptr += 32;
        }

        return int256(len) - int256(otherlen);
    }

    /*
     * @dev Returns true if the two byte ranges are equal.
     * @param self The first byte range to compare.
     * @param offset The offset into the first byte range.
     * @param other The second byte range to compare.
     * @param otherOffset The offset into the second byte range.
     * @param len The number of bytes to compare
     * @return True if the byte ranges are equal, false otherwise.
     */
    function equals(
        bytes memory self,
        uint256 offset,
        bytes memory other,
        uint256 otherOffset,
        uint256 len
    ) internal pure returns (bool) {
        return keccak(self, offset, len) == keccak(other, otherOffset, len);
    }

    /*
     * @dev Returns true if the two byte ranges are equal with offsets.
     * @param self The first byte range to compare.
     * @param offset The offset into the first byte range.
     * @param other The second byte range to compare.
     * @param otherOffset The offset into the second byte range.
     * @return True if the byte ranges are equal, false otherwise.
     */
    function equals(
        bytes memory self,
        uint256 offset,
        bytes memory other,
        uint256 otherOffset
    ) internal pure returns (bool) {
        return
            keccak(self, offset, self.length - offset) ==
            keccak(other, otherOffset, other.length - otherOffset);
    }

    /*
     * @dev Compares a range of 'self' to all of 'other' and returns True iff
     *      they are equal.
     * @param self The first byte range to compare.
     * @param offset The offset into the first byte range.
     * @param other The second byte range to compare.
     * @return True if the byte ranges are equal, false otherwise.
     */
    function equals(
        bytes memory self,
        uint256 offset,
        bytes memory other
    ) internal pure returns (bool) {
        return
            self.length == offset + other.length &&
            equals(self, offset, other, 0, other.length);
    }

    /*
     * @dev Returns true if the two byte ranges are equal.
     * @param self The first byte range to compare.
     * @param other The second byte range to compare.
     * @return True if the byte ranges are equal, false otherwise.
     */
    function equals(
        bytes memory self,
        bytes memory other
    ) internal pure returns (bool) {
        return
            self.length == other.length &&
            equals(self, 0, other, 0, self.length);
    }

    /*
     * @dev Returns the 8-bit number at the specified index of self.
     * @param self The byte string.
     * @param idx The index into the bytes
     * @return The specified 8 bits of the string, interpreted as an integer.
     */
    function readUint8(
        bytes memory self,
        uint256 idx
    ) internal pure returns (uint8 ret) {
        return uint8(self[idx]);
    }

    /*
     * @dev Returns the 16-bit number at the specified index of self.
     * @param self The byte string.
     * @param idx The index into the bytes
     * @return The specified 16 bits of the string, interpreted as an integer.
     */
    function readUint16(
        bytes memory self,
        uint256 idx
    ) internal pure returns (uint16 ret) {
        require(idx + 2 <= self.length);
        assembly {
            ret := and(mload(add(add(self, 2), idx)), 0xFFFF)
        }
    }

    /*
     * @dev Returns the 32-bit number at the specified index of self.
     * @param self The byte string.
     * @param idx The index into the bytes
     * @return The specified 32 bits of the string, interpreted as an integer.
     */
    function readUint32(
        bytes memory self,
        uint256 idx
    ) internal pure returns (uint32 ret) {
        require(idx + 4 <= self.length);
        assembly {
            ret := and(mload(add(add(self, 4), idx)), 0xFFFFFFFF)
        }
    }

    /*
     * @dev Returns the 32 byte value at the specified index of self.
     * @param self The byte string.
     * @param idx The index into the bytes
     * @return The specified 32 bytes of the string.
     */
    function readBytes32(
        bytes memory self,
        uint256 idx
    ) internal pure returns (bytes32 ret) {
        require(idx + 32 <= self.length);
        assembly {
            ret := mload(add(add(self, 32), idx))
        }
    }

    /*
     * @dev Returns the 32 byte value at the specified index of self.
     * @param self The byte string.
     * @param idx The index into the bytes
     * @return The specified 32 bytes of the string.
     */
    function readBytes20(
        bytes memory self,
        uint256 idx
    ) internal pure returns (bytes20 ret) {
        require(idx + 20 <= self.length);
        assembly {
            ret := and(
                mload(add(add(self, 32), idx)),
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000000
            )
        }
    }

    /*
     * @dev Returns the n byte value at the specified index of self.
     * @param self The byte string.
     * @param idx The index into the bytes.
     * @param len The number of bytes.
     * @return The specified 32 bytes of the string.
     */
    function readBytesN(
        bytes memory self,
        uint256 idx,
        uint256 len
    ) internal pure returns (bytes32 ret) {
        require(len <= 32);
        require(idx + len <= self.length);
        assembly {
            let mask := not(sub(exp(256, sub(32, len)), 1))
            ret := and(mload(add(add(self, 32), idx)), mask)
        }
    }

    function memcpy(uint256 dest, uint256 src, uint256 len) private pure {
        // Copy word-length chunks while possible
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        unchecked {
            uint256 mask = (256 ** (32 - len)) - 1;
            assembly {
                let srcpart := and(mload(src), not(mask))
                let destpart := and(mload(dest), mask)
                mstore(dest, or(destpart, srcpart))
            }
        }
    }

    /*
     * @dev Copies a substring into a new byte string.
     * @param self The byte string to copy from.
     * @param offset The offset to start copying at.
     * @param len The number of bytes to copy.
     */
    function substring(
        bytes memory self,
        uint256 offset,
        uint256 len
    ) internal pure returns (bytes memory) {
        require(offset + len <= self.length);

        bytes memory ret = new bytes(len);
        uint256 dest;
        uint256 src;

        assembly {
            dest := add(ret, 32)
            src := add(add(self, 32), offset)
        }
        memcpy(dest, src, len);

        return ret;
    }

    // Maps characters from 0x30 to 0x7A to their base32 values.
    // 0xFF represents invalid characters in that range.
    bytes constant base32HexTable =
        hex"00010203040506070809FFFFFFFFFFFFFF0A0B0C0D0E0F101112131415161718191A1B1C1D1E1FFFFFFFFFFFFFFFFFFFFF0A0B0C0D0E0F101112131415161718191A1B1C1D1E1F";

    /**
     * @dev Decodes unpadded base32 data of up to one word in length.
     * @param self The data to decode.
     * @param off Offset into the string to start at.
     * @param len Number of characters to decode.
     * @return The decoded data, left aligned.
     */
    function base32HexDecodeWord(
        bytes memory self,
        uint256 off,
        uint256 len
    ) internal pure returns (bytes32) {
        require(len <= 52);

        uint256 ret = 0;
        uint8 decoded;
        for (uint256 i = 0; i < len; i++) {
            bytes1 char = self[off + i];
            require(char >= 0x30 && char <= 0x7A);
            decoded = uint8(base32HexTable[uint256(uint8(char)) - 0x30]);
            require(decoded <= 0x20);
            if (i == len - 1) {
                break;
            }
            ret = (ret << 5) | decoded;
        }

        uint256 bitlen = len * 5;
        if (len % 8 == 0) {
            // Multiple of 8 characters, no padding
            ret = (ret << 5) | decoded;
        } else if (len % 8 == 2) {
            // Two extra characters - 1 byte
            ret = (ret << 3) | (decoded >> 2);
            bitlen -= 2;
        } else if (len % 8 == 4) {
            // Four extra characters - 2 bytes
            ret = (ret << 1) | (decoded >> 4);
            bitlen -= 4;
        } else if (len % 8 == 5) {
            // Five extra characters - 3 bytes
            ret = (ret << 4) | (decoded >> 1);
            bitlen -= 1;
        } else if (len % 8 == 7) {
            // Seven extra characters - 4 bytes
            ret = (ret << 2) | (decoded >> 3);
            bitlen -= 3;
        } else {
            revert();
        }

        return bytes32(ret << (256 - bitlen));
    }

    /**
     * @dev Finds the first occurrence of the byte `needle` in `self`.
     * @param self The string to search
     * @param off The offset to start searching at
     * @param len The number of bytes to search
     * @param needle The byte to search for
     * @return The offset of `needle` in `self`, or 2**256-1 if it was not found.
     */
    function find(
        bytes memory self,
        uint256 off,
        uint256 len,
        bytes1 needle
    ) internal pure returns (uint256) {
        for (uint256 idx = off; idx < off + len; idx++) {
            if (self[idx] == needle) {
                return idx;
            }
        }
        return type(uint256).max;
    }
}


// Chain: POLYGON - File: contracts/utils/DummyRevertResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

contract DummyRevertResolver {
    function resolve(
        bytes calldata,
        bytes calldata
    ) external pure returns (bytes memory) {
        revert("Not Supported");
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}


// Chain: POLYGON - File: contracts/utils/ERC20Recoverable.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
    @notice Contract is used to recover ERC20 tokens sent to the contract by mistake.
 */

contract ERC20Recoverable is Ownable {
    /**
    @notice Recover ERC20 tokens sent to the contract by mistake.
    @dev The contract is Ownable and only the owner can call the recover function.
    @param _to The address to send the tokens to.
@param _token The address of the ERC20 token to recover
    @param _amount The amount of tokens to recover.
 */
    function recoverFunds(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }
}


// Chain: POLYGON - File: contracts/utils/HexUtils.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library HexUtils {
    /**
     * @dev Attempts to parse bytes32 from a hex string
     * @param str The string to parse
     * @param idx The offset to start parsing at
     * @param lastIdx The (exclusive) last index in `str` to consider. Use `str.length` to scan the whole string.
     */
    function hexStringToBytes32(
        bytes memory str,
        uint256 idx,
        uint256 lastIdx
    ) internal pure returns (bytes32, bool) {
        require(lastIdx - idx <= 64);
        (bytes memory r, bool valid) = hexToBytes(str, idx, lastIdx);
        if (!valid) {
            return (bytes32(0), false);
        }
        bytes32 ret;
        assembly {
            ret := shr(mul(4, sub(64, sub(lastIdx, idx))), mload(add(r, 32)))
        }
        return (ret, true);
    }

    function hexToBytes(
        bytes memory str,
        uint256 idx,
        uint256 lastIdx
    ) internal pure returns (bytes memory r, bool valid) {
        uint256 hexLength = lastIdx - idx;
        if (hexLength % 2 == 1) {
            revert("Invalid string length");
        }
        r = new bytes(hexLength / 2);
        valid = true;
        assembly {
            // check that the index to read to is not past the end of the string
            if gt(lastIdx, mload(str)) {
                revert(0, 0)
            }

            function getHex(c) -> ascii {
                // chars 48-57: 0-9
                if and(gt(c, 47), lt(c, 58)) {
                    ascii := sub(c, 48)
                    leave
                }
                // chars 65-70: A-F
                if and(gt(c, 64), lt(c, 71)) {
                    ascii := add(sub(c, 65), 10)
                    leave
                }
                // chars 97-102: a-f
                if and(gt(c, 96), lt(c, 103)) {
                    ascii := add(sub(c, 97), 10)
                    leave
                }
                // invalid char
                ascii := 0xff
            }

            let ptr := add(str, 32)
            for {
                let i := idx
            } lt(i, lastIdx) {
                i := add(i, 2)
            } {
                let byte1 := getHex(byte(0, mload(add(ptr, i))))
                let byte2 := getHex(byte(0, mload(add(ptr, add(i, 1)))))
                // if either byte is invalid, set invalid and break loop
                if or(eq(byte1, 0xff), eq(byte2, 0xff)) {
                    valid := false
                    break
                }
                let combined := or(shl(4, byte1), byte2)
                mstore8(add(add(r, 32), div(sub(i, idx), 2)), combined)
            }
        }
    }

    /**
     * @dev Attempts to parse an address from a hex string
     * @param str The string to parse
     * @param idx The offset to start parsing at
     * @param lastIdx The (exclusive) last index in `str` to consider. Use `str.length` to scan the whole string.
     */
    function hexToAddress(
        bytes memory str,
        uint256 idx,
        uint256 lastIdx
    ) internal pure returns (address, bool) {
        if (lastIdx - idx < 40) return (address(0x0), false);
        (bytes32 r, bool valid) = hexStringToBytes32(str, idx, lastIdx);
        return (address(uint160(uint256(r))), valid);
    }

    /**
     * @dev Attempts to convert an address to a hex string
     * @param addr The _addr to parse
     */
    function addressToHex(address addr) internal pure returns (string memory) {
        bytes memory hexString = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 byteValue = bytes1(uint8(uint160(addr) >> (8 * (19 - i))));
            bytes1 highNibble = bytes1(uint8(byteValue) / 16);
            bytes1 lowNibble = bytes1(
                uint8(byteValue) - 16 * uint8(highNibble)
            );
            hexString[2 * i] = _nibbleToHexChar(highNibble);
            hexString[2 * i + 1] = _nibbleToHexChar(lowNibble);
        }
        return string(hexString);
    }

    function _nibbleToHexChar(
        bytes1 nibble
    ) internal pure returns (bytes1 hexChar) {
        if (uint8(nibble) < 10) return bytes1(uint8(nibble) + 0x30);
        else return bytes1(uint8(nibble) + 0x57);
    }
}


// Chain: POLYGON - File: contracts/utils/LowLevelCallUtils.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

library LowLevelCallUtils {
    using Address for address;

    /**
     * @dev Makes a static call to the specified `target` with `data`. Return data can be fetched with
     *      `returnDataSize` and `readReturnData`.
     * @param target The address to staticcall.
     * @param data The data to pass to the call.
     * @return success True if the call succeeded, or false if it reverts.
     */
    function functionStaticCall(
        address target,
        bytes memory data
    ) internal view returns (bool success) {
        return functionStaticCall(target, data, gasleft());
    }

    /**
     * @dev Makes a static call to the specified `target` with `data` using `gasLimit`. Return data can be fetched with
     *      `returnDataSize` and `readReturnData`.
     * @param target The address to staticcall.
     * @param data The data to pass to the call.
     * @param gasLimit The gas limit to use for the call.
     * @return success True if the call succeeded, or false if it reverts.
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        uint256 gasLimit
    ) internal view returns (bool success) {
        require(
            target.isContract(),
            "LowLevelCallUtils: static call to non-contract"
        );
        assembly {
            success := staticcall(
                gasLimit,
                target,
                add(data, 32),
                mload(data),
                0,
                0
            )
        }
    }

    /**
     * @dev Returns the size of the return data of the most recent external call.
     */
    function returnDataSize() internal pure returns (uint256 len) {
        assembly {
            len := returndatasize()
        }
    }

    /**
     * @dev Reads return data from the most recent external call.
     * @param offset Offset into the return data.
     * @param length Number of bytes to return.
     */
    function readReturnData(
        uint256 offset,
        uint256 length
    ) internal pure returns (bytes memory data) {
        data = new bytes(length);
        assembly {
            returndatacopy(add(data, 32), offset, length)
        }
    }

    /**
     * @dev Reverts with the return data from the most recent external call.
     */
    function propagateRevert() internal pure {
        assembly {
            returndatacopy(0, 0, returndatasize())
            revert(0, returndatasize())
        }
    }
}


// Chain: POLYGON - File: contracts/utils/NameEncoder.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BytesUtils} from "../utils/BytesUtils.sol";

library NameEncoder {
    using BytesUtils for bytes;

    function dnsEncodeName(
        string memory name
    ) internal pure returns (bytes memory dnsName, bytes32 node) {
        uint8 labelLength = 0;
        bytes memory bytesName = bytes(name);
        uint256 length = bytesName.length;
        dnsName = new bytes(length + 2);
        node = 0;
        if (length == 0) {
            dnsName[0] = 0;
            return (dnsName, node);
        }

        // use unchecked to save gas since we check for an underflow
        // and we check for the length before the loop
        unchecked {
            for (uint256 i = length - 1; i >= 0; i--) {
                if (bytesName[i] == ".") {
                    dnsName[i + 1] = bytes1(labelLength);
                    node = keccak256(
                        abi.encodePacked(
                            node,
                            bytesName.keccak(i + 1, labelLength)
                        )
                    );
                    labelLength = 0;
                } else {
                    labelLength += 1;
                    dnsName[i + 1] = bytesName[i];
                }
                if (i == 0) {
                    break;
                }
            }
        }

        node = keccak256(
            abi.encodePacked(node, bytesName.keccak(0, labelLength))
        );

        dnsName[0] = bytes1(labelLength);
        return (dnsName, node);
    }
}


// Chain: POLYGON - File: contracts/utils/StringUtils.sol
pragma solidity >=0.8.4;

library StringUtils {
    /**
     * @dev Returns the length of a given string
     *
     * @param s The string to measure the length of
     * @return The length of the input string
     */
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;
        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    /**
     * @dev Escapes special characters in a given string
     *
     * @param str The string to escape
     * @return The escaped string
     */
    function escape(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        uint extraChars = 0;

        // count extra space needed for escaping
        for (uint i = 0; i < strBytes.length; i++) {
            if (_needsEscaping(strBytes[i])) {
                extraChars++;
            }
        }

        // allocate buffer with the exact size needed
        bytes memory buffer = new bytes(strBytes.length + extraChars);
        uint index = 0;

        // escape characters
        for (uint i = 0; i < strBytes.length; i++) {
            if (_needsEscaping(strBytes[i])) {
                buffer[index++] = "\\";
                buffer[index++] = _getEscapedChar(strBytes[i]);
            } else {
                buffer[index++] = strBytes[i];
            }
        }

        return string(buffer);
    }

    // determine if a character needs escaping
    function _needsEscaping(bytes1 char) private pure returns (bool) {
        return
            char == '"' ||
            char == "/" ||
            char == "\\" ||
            char == "\n" ||
            char == "\r" ||
            char == "\t";
    }

    // get the escaped character
    function _getEscapedChar(bytes1 char) private pure returns (bytes1) {
        if (char == "\n") return "n";
        if (char == "\r") return "r";
        if (char == "\t") return "t";
        return char;
    }
}


// Chain: POLYGON - File: contracts/utils/TestBytesUtils.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {BytesUtils} from "./BytesUtils.sol";

contract TestBytesUtils {
    using BytesUtils for *;

    function readLabel(
        bytes calldata name,
        uint256 offset
    ) public pure returns (bytes32, uint256) {
        return name.readLabel(offset);
    }

    function namehash(
        bytes calldata name,
        uint256 offset
    ) public pure returns (bytes32) {
        return name.namehash(offset);
    }
}


// Chain: POLYGON - File: contracts/utils/TestHexUtils.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {HexUtils} from "./HexUtils.sol";

contract TestHexUtils {
    using HexUtils for *;

    function hexToBytes(
        bytes calldata name,
        uint256 idx,
        uint256 lastInx
    ) public pure returns (bytes memory, bool) {
        return name.hexToBytes(idx, lastInx);
    }

    function hexStringToBytes32(
        bytes calldata name,
        uint256 idx,
        uint256 lastInx
    ) public pure returns (bytes32, bool) {
        return name.hexStringToBytes32(idx, lastInx);
    }

    function hexToAddress(
        bytes calldata input,
        uint256 idx,
        uint256 lastInx
    ) public pure returns (address, bool) {
        return input.hexToAddress(idx, lastInx);
    }
}


// Chain: POLYGON - File: contracts/utils/TestNameEncoder.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {NameEncoder} from "./NameEncoder.sol";

contract TestNameEncoder {
    using NameEncoder for string;

    function encodeName(
        string memory name
    ) public pure returns (bytes memory, bytes32) {
        return name.dnsEncodeName();
    }
}


// Chain: POLYGON - File: contracts/wrapper/Controllable.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Controllable is Ownable {
    mapping(address => bool) public controllers;

    event ControllerChanged(address indexed controller, bool active);

    function setController(address controller, bool active) public onlyOwner {
        controllers[controller] = active;
        emit ControllerChanged(controller, active);
    }

    modifier onlyController() {
        require(
            controllers[msg.sender],
            "Controllable: Caller is not a controller"
        );
        _;
    }
}


// Chain: POLYGON - File: contracts/wrapper/ERC1155Fuse.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/* This contract is a variation on ERC1155 with the additions of _setData, getData and _beforeTransfer and ownerOf. _setData and getData allows the use of the other 96 bits next to the address of the owner for extra data. We use this to store 'fuses' that control permissions that can be burnt. 32 bits are used for the fuses themselves and 64 bits are used for the expiry of the name. When a name has expired, its fuses will be be set back to 0 */

abstract contract ERC1155Fuse is ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;
    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    mapping(uint256 => uint256) public _tokens;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    // Mapping from token ID to approved address
    mapping(uint256 => address) internal _tokenApprovals;

    /**************************************************************************
     * ERC721 methods
     *************************************************************************/

    function ownerOf(uint256 id) public view virtual returns (address) {
        (address owner, , ) = getData(id);
        return owner;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(
        uint256 tokenId
    ) public view virtual returns (address) {
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(
        address account,
        uint256 id
    ) public view virtual override returns (uint256) {
        require(
            account != address(0),
            "ERC1155: balance query for the zero address"
        );
        address owner = ownerOf(id);
        if (owner == account) {
            return 1;
        }
        return 0;
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        require(
            accounts.length == ids.length,
            "ERC1155: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override {
        require(
            msg.sender != operator,
            "ERC1155: setting approval status for self"
        );

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(
        address account,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev Returns the Name's owner address and fuses
     */
    function getData(
        uint256 tokenId
    ) public view virtual returns (address owner, uint32 fuses, uint64 expiry) {
        uint256 t = _tokens[tokenId];
        owner = address(uint160(t));
        expiry = uint64(t >> 192);
        fuses = uint32(t >> 160);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "ERC1155: caller is not owner nor approved"
        );

        _transfer(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "ERC1155: transfer caller is not owner nor approved"
        );

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            (address oldOwner, uint32 fuses, uint64 expiry) = getData(id);

            _beforeTransfer(id, fuses, expiry);

            require(
                amount == 1 && oldOwner == from,
                "ERC1155: insufficient balance for transfer"
            );
            _setData(id, to, fuses, expiry);
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(
            msg.sender,
            from,
            to,
            ids,
            amounts,
            data
        );
    }

    /**************************************************************************
     * Internal/private methods
     *************************************************************************/

    /**
     * @dev Sets the Name's owner address and fuses
     */
    function _setData(
        uint256 tokenId,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal virtual {
        _tokens[tokenId] =
            uint256(uint160(owner)) |
            (uint256(fuses) << 160) |
            (uint256(expiry) << 192);
    }

    function _beforeTransfer(
        uint256 id,
        uint32 fuses,
        uint64 expiry
    ) internal virtual;

    function _clearOwnerAndFuses(
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal virtual returns (address, uint32);

    function _mint(
        bytes32 node,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal virtual {
        uint256 tokenId = uint256(node);
        (address oldOwner, uint32 oldFuses, uint64 oldExpiry) = getData(
            uint256(node)
        );

        uint32 parentControlledFuses = (uint32(type(uint16).max) << 16) &
            oldFuses;

        if (oldExpiry > expiry) {
            expiry = oldExpiry;
        }

        if (oldExpiry >= block.timestamp) {
            fuses = fuses | parentControlledFuses;
        }

        require(oldOwner == address(0), "ERC1155: mint of existing token");
        require(owner != address(0), "ERC1155: mint to the zero address");
        require(
            owner != address(this),
            "ERC1155: newOwner cannot be the NameWrapper contract"
        );

        _setData(tokenId, owner, fuses, expiry);
        emit TransferSingle(msg.sender, address(0x0), owner, tokenId, 1);
        _doSafeTransferAcceptanceCheck(
            msg.sender,
            address(0),
            owner,
            tokenId,
            1,
            ""
        );
    }

    function _burn(uint256 tokenId) internal virtual {
        (address oldOwner, uint32 fuses, uint64 expiry) = ERC1155Fuse.getData(
            tokenId
        );
        (, fuses) = _clearOwnerAndFuses(oldOwner, fuses, expiry);
        // Clear approvals
        delete _tokenApprovals[tokenId];
        // Fuses and expiry are kept on burn
        _setData(tokenId, address(0x0), fuses, expiry);
        emit TransferSingle(msg.sender, oldOwner, address(0x0), tokenId, 1);
    }

    function _transfer(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        (address oldOwner, uint32 fuses, uint64 expiry) = getData(id);

        _beforeTransfer(id, fuses, expiry);

        require(
            amount == 1 && oldOwner == from,
            "ERC1155: insufficient balance for transfer"
        );

        if (oldOwner == to) {
            return;
        }

        _setData(id, to, fuses, expiry);

        emit TransferSingle(msg.sender, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (
                    response != IERC1155Receiver(to).onERC1155Received.selector
                ) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (
                    response !=
                    IERC1155Receiver(to).onERC1155BatchReceived.selector
                ) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    /* ERC721 internal functions */

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }
}


// Chain: POLYGON - File: contracts/wrapper/IMetadataService.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

interface IMetadataService {
    function uri(uint256) external view returns (string memory);
}


// Chain: POLYGON - File: contracts/wrapper/INameWrapper.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "../registry/ENS.sol";
import "../ethregistrar/IBaseRegistrar.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./IMetadataService.sol";
import "./INameWrapperUpgrade.sol";

uint32 constant CANNOT_UNWRAP = 1;
uint32 constant CANNOT_BURN_FUSES = 2;
uint32 constant CANNOT_TRANSFER = 4;
uint32 constant CANNOT_SET_RESOLVER = 8;
uint32 constant CANNOT_SET_TTL = 16;
uint32 constant CANNOT_CREATE_SUBDOMAIN = 32;
uint32 constant CANNOT_APPROVE = 64;
//uint16 reserved for parent controlled fuses from bit 17 to bit 32
uint32 constant PARENT_CANNOT_CONTROL = 1 << 16;
uint32 constant IS_DOT_ETH = 1 << 17;
uint32 constant CAN_EXTEND_EXPIRY = 1 << 18;
uint32 constant CAN_DO_EVERYTHING = 0;
uint32 constant PARENT_CONTROLLED_FUSES = 0xFFFF0000;
// all fuses apart from IS_DOT_ETH
uint32 constant USER_SETTABLE_FUSES = 0xFFFDFFFF;

interface INameWrapper is IERC1155 {
    event NameWrapped(
        bytes32 indexed node,
        bytes name,
        address owner,
        uint32 fuses,
        uint64 expiry
    );

    event NameUnwrapped(bytes32 indexed node, address owner);

    event FusesSet(bytes32 indexed node, uint32 fuses);
    event ExpiryExtended(bytes32 indexed node, uint64 expiry);

    function ens() external view returns (ENS);

    function registrar() external view returns (IBaseRegistrar);

    function metadataService() external view returns (IMetadataService);

    function names(bytes32) external view returns (bytes memory);

    function name() external view returns (string memory);

    function upgradeContract() external view returns (INameWrapperUpgrade);

    function supportsInterface(bytes4 interfaceID) external view returns (bool);

    function wrap(
        bytes calldata name,
        address wrappedOwner,
        address resolver
    ) external;

    function wrapETH2LD(
        string calldata label,
        address wrappedOwner,
        uint16 ownerControlledFuses,
        address resolver
    ) external returns (uint64 expires);

    function registerAndWrapETH2LD(
        string calldata label,
        address wrappedOwner,
        uint256 duration,
        address resolver,
        uint16 ownerControlledFuses
    ) external returns (uint256 registrarExpiry);

    function renew(
        uint256 labelHash,
        uint256 duration
    ) external returns (uint256 expires);

    function unwrap(bytes32 node, bytes32 label, address owner) external;

    function unwrapETH2LD(
        bytes32 label,
        address newRegistrant,
        address newController
    ) external;

    function upgrade(bytes calldata name, bytes calldata extraData) external;

    function setFuses(
        bytes32 node,
        uint16 ownerControlledFuses
    ) external returns (uint32 newFuses);

    function setChildFuses(
        bytes32 parentNode,
        bytes32 labelhash,
        uint32 fuses,
        uint64 expiry
    ) external;

    function setSubnodeRecord(
        bytes32 node,
        string calldata label,
        address owner,
        address resolver,
        uint64 ttl,
        uint32 fuses,
        uint64 expiry
    ) external returns (bytes32);

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    ) external;

    function setSubnodeOwner(
        bytes32 node,
        string calldata label,
        address newOwner,
        uint32 fuses,
        uint64 expiry
    ) external returns (bytes32);

    function extendExpiry(
        bytes32 node,
        bytes32 labelhash,
        uint64 expiry
    ) external returns (uint64);

    function canModifyName(
        bytes32 node,
        address addr
    ) external view returns (bool);

    function setResolver(bytes32 node, address resolver) external;

    function setTTL(bytes32 node, uint64 ttl) external;

    function ownerOf(uint256 id) external view returns (address owner);

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function getData(
        uint256 id
    ) external view returns (address, uint32, uint64);

    function setMetadataService(IMetadataService _metadataService) external;

    function uri(uint256 tokenId) external view returns (string memory);

    function setUpgradeContract(INameWrapperUpgrade _upgradeAddress) external;

    function allFusesBurned(
        bytes32 node,
        uint32 fuseMask
    ) external view returns (bool);

    function isWrapped(bytes32) external view returns (bool);

    function isWrapped(bytes32, bytes32) external view returns (bool);
}


// Chain: POLYGON - File: contracts/wrapper/INameWrapperUpgrade.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

interface INameWrapperUpgrade {
    function wrapFromUpgrade(
        bytes calldata name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry,
        address approved,
        bytes calldata extraData
    ) external;
}


// Chain: POLYGON - File: contracts/wrapper/mocks/ERC1155ReceiverMock.sol
// Based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/test/token/ERC1155/ERC1155.behaviour.js
// Copyright (c) 2016-2020 zOS Global Limited

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract ERC1155ReceiverMock is IERC1155Receiver, ERC165 {
    bytes4 private _recRetval;
    bool private _recReverts;
    bytes4 private _batRetval;
    bool private _batReverts;

    event Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes data
    );
    event BatchReceived(
        address operator,
        address from,
        uint256[] ids,
        uint256[] values,
        bytes data
    );

    constructor(
        bytes4 recRetval,
        bool recReverts,
        bytes4 batRetval,
        bool batReverts
    ) {
        _recRetval = recRetval;
        _recReverts = recReverts;
        _batRetval = batRetval;
        _batReverts = batReverts;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        require(!_recReverts, "ERC1155ReceiverMock: reverting on receive");
        emit Received(operator, from, id, value, data);
        return _recRetval;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        require(
            !_batReverts,
            "ERC1155ReceiverMock: reverting on batch receive"
        );
        emit BatchReceived(operator, from, ids, values, data);
        return _batRetval;
    }
}


// Chain: POLYGON - File: contracts/wrapper/mocks/TestUnwrap.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../../registry/ENS.sol";
import "../../ethregistrar/IBaseRegistrar.sol";
import {BytesUtils} from "../../utils/BytesUtils.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestUnwrap is Ownable {
    using BytesUtils for bytes;

    // set based on network
    // bytes32 private constant ETH_NODE = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    bytes32 private constant ETH_NODE = 0x423ba58fb1ed8a39f711b6e11be3c3565659581128c3108f38b0d1f90cc398f2; // namehash('ecld') polygon
    // bytes32 private constant ETH_NODE = 0x312aaca3ac8032f81987e8517e993b798f14784dc873e9b4b93d6f18456511aa; // namehash('etny') bloxberg

    ENS public immutable ens;
    IBaseRegistrar public immutable registrar;
    mapping(address => bool) public approvedWrapper;

    constructor(ENS _ens, IBaseRegistrar _registrar) {
        ens = _ens;
        registrar = _registrar;
    }

    function setWrapperApproval(
        address wrapper,
        bool approved
    ) public onlyOwner {
        approvedWrapper[wrapper] = approved;
    }

    function wrapETH2LD(
        string calldata label,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry,
        address resolver
    ) public {
        _unwrapETH2LD(keccak256(bytes(label)), wrappedOwner, msg.sender);
    }

    function setSubnodeRecord(
        bytes32 parentNode,
        string memory label,
        address newOwner,
        address resolver,
        uint64 ttl,
        uint32 fuses,
        uint64 expiry
    ) public {
        bytes32 node = _makeNode(parentNode, keccak256(bytes(label)));
        _unwrapSubnode(node, newOwner, msg.sender);
    }

    function wrapFromUpgrade(
        bytes calldata name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry,
        address approved,
        bytes calldata extraData
    ) public {
        (bytes32 labelhash, uint256 offset) = name.readLabel(0);
        bytes32 parentNode = name.namehash(offset);
        bytes32 node = _makeNode(parentNode, labelhash);

        if (parentNode == ETH_NODE) {
            _unwrapETH2LD(labelhash, wrappedOwner, msg.sender);
        } else {
            _unwrapSubnode(node, wrappedOwner, msg.sender);
        }
    }

    function _unwrapETH2LD(
        bytes32 labelhash,
        address wrappedOwner,
        address sender
    ) private {
        uint256 tokenId = uint256(labelhash);
        address registrant = registrar.ownerOf(tokenId);

        require(
            approvedWrapper[sender] &&
                sender == registrant &&
                registrar.isApprovedForAll(registrant, address(this)),
            "Unauthorised"
        );

        registrar.reclaim(tokenId, wrappedOwner);
        registrar.transferFrom(registrant, wrappedOwner, tokenId);
    }

    function _unwrapSubnode(
        bytes32 node,
        address newOwner,
        address sender
    ) private {
        address owner = ens.owner(node);

        require(
            approvedWrapper[sender] &&
                owner == sender &&
                ens.isApprovedForAll(owner, address(this)),
            "Unauthorised"
        );

        ens.setOwner(node, newOwner);
    }

    function _makeNode(
        bytes32 node,
        bytes32 labelhash
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(node, labelhash));
    }
}


// Chain: POLYGON - File: contracts/wrapper/mocks/UpgradedNameWrapperMock.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import {INameWrapperUpgrade} from "../INameWrapperUpgrade.sol";
import "../../registry/ENS.sol";
import "../../ethregistrar/IBaseRegistrar.sol";
import {BytesUtils} from "../../utils/BytesUtils.sol";

contract UpgradedNameWrapperMock is INameWrapperUpgrade {
    using BytesUtils for bytes;
    // set based on network
    // bytes32 private constant ETH_NODE = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    bytes32 private constant ETH_NODE = 0x423ba58fb1ed8a39f711b6e11be3c3565659581128c3108f38b0d1f90cc398f2; // namehash('ecld') polygon
    // bytes32 private constant ETH_NODE = 0x312aaca3ac8032f81987e8517e993b798f14784dc873e9b4b93d6f18456511aa; // namehash('etny') bloxberg
    ENS public immutable ens;
    IBaseRegistrar public immutable registrar;

    constructor(ENS _ens, IBaseRegistrar _registrar) {
        ens = _ens;
        registrar = _registrar;
    }

    event NameUpgraded(
        bytes name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry,
        address approved,
        bytes extraData
    );

    function wrapFromUpgrade(
        bytes calldata name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry,
        address approved,
        bytes calldata extraData
    ) public {
        (bytes32 labelhash, uint256 offset) = name.readLabel(0);
        bytes32 parentNode = name.namehash(offset);
        bytes32 node = _makeNode(parentNode, labelhash);

        if (parentNode == ETH_NODE) {
            address registrant = registrar.ownerOf(uint256(labelhash));
            require(
                msg.sender == registrant &&
                    registrar.isApprovedForAll(registrant, address(this)),
                "No approval for registrar"
            );
        } else {
            address owner = ens.owner(node);
            require(
                msg.sender == owner &&
                    ens.isApprovedForAll(owner, address(this)),
                "No approval for registry"
            );
        }
        emit NameUpgraded(
            name,
            wrappedOwner,
            fuses,
            expiry,
            approved,
            extraData
        );
    }

    function _makeNode(
        bytes32 node,
        bytes32 labelhash
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(node, labelhash));
    }
}


// Chain: POLYGON - File: contracts/wrapper/NameWrapper.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {ERC1155Fuse, IERC165, IERC1155MetadataURI} from "./ERC1155Fuse.sol";
import {Controllable} from "./Controllable.sol";
import {INameWrapper, CANNOT_UNWRAP, CANNOT_BURN_FUSES, CANNOT_TRANSFER, CANNOT_SET_RESOLVER, CANNOT_SET_TTL, CANNOT_CREATE_SUBDOMAIN, CANNOT_APPROVE, PARENT_CANNOT_CONTROL, CAN_DO_EVERYTHING, IS_DOT_ETH, CAN_EXTEND_EXPIRY, PARENT_CONTROLLED_FUSES, USER_SETTABLE_FUSES} from "./INameWrapper.sol";
import {INameWrapperUpgrade} from "./INameWrapperUpgrade.sol";
import {IMetadataService} from "./IMetadataService.sol";
import {ENS} from "../registry/ENS.sol";
import {IReverseRegistrar} from "../reverseRegistrar/IReverseRegistrar.sol";
import {ReverseClaimer} from "../reverseRegistrar/ReverseClaimer.sol";
import {IBaseRegistrar} from "../ethregistrar/IBaseRegistrar.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BytesUtils} from "../utils/BytesUtils.sol";
import {ERC20Recoverable} from "../utils/ERC20Recoverable.sol";

error Unauthorised(bytes32 node, address addr);
error IncompatibleParent();
error IncorrectTokenType();
error LabelMismatch(bytes32 labelHash, bytes32 expectedLabelhash);
error LabelTooShort();
error LabelTooLong(string label);
error IncorrectTargetOwner(address owner);
error CannotUpgrade();
error OperationProhibited(bytes32 node);
error NameIsNotWrapped();
error NameIsStillExpired();

contract NameWrapper is
    Ownable,
    ERC1155Fuse,
    INameWrapper,
    Controllable,
    IERC721Receiver,
    ERC20Recoverable,
    ReverseClaimer
{
    using BytesUtils for bytes;

    ENS public immutable ens;
    IBaseRegistrar public immutable registrar;
    IMetadataService public metadataService;
    mapping(bytes32 => bytes) public names;
    string public constant name = "NameWrapper";

    uint64 private constant GRACE_PERIOD = 90 days;
    // set based on network
    // bytes32 private constant ETH_NODE = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae; // namehash('eth')
    // bytes32 private constant ETH_LABELHASH = 0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0; // keccak256("eth")

    bytes32 private constant ETH_NODE = 0x423ba58fb1ed8a39f711b6e11be3c3565659581128c3108f38b0d1f90cc398f2; // namehash('ecld') polygon
    bytes32 private constant ETH_LABELHASH = 0xdefecd9e87c66606fdf161ada3b1674d3ae8f8ac3aaa4245136b10460d1659a8; // keccak256("ecld")

    // bytes32 private constant ETH_NODE = 0x312aaca3ac8032f81987e8517e993b798f14784dc873e9b4b93d6f18456511aa; // namehash('etny') bloxberg
    // bytes32 private constant ETH_LABELHASH = 0x8550fc0c05da5a9720a89199512a5f1c234bd58bc848c5841a17302ed35d83fc; // keccak256("etny")

    bytes32 private constant ROOT_NODE =
        0x0000000000000000000000000000000000000000000000000000000000000000;

    INameWrapperUpgrade public upgradeContract;
    uint64 private constant MAX_EXPIRY = type(uint64).max;

    constructor(
        ENS _ens,
        IBaseRegistrar _registrar,
        IMetadataService _metadataService
    ) ReverseClaimer(_ens, msg.sender) {
        ens = _ens;
        registrar = _registrar;
        metadataService = _metadataService;

        /* Burn PARENT_CANNOT_CONTROL and CANNOT_UNWRAP fuses for ROOT_NODE and ETH_NODE and set expiry to max */

        _setData(
            uint256(ETH_NODE),
            address(0),
            uint32(PARENT_CANNOT_CONTROL | CANNOT_UNWRAP),
            MAX_EXPIRY
        );
        _setData(
            uint256(ROOT_NODE),
            address(0),
            uint32(PARENT_CANNOT_CONTROL | CANNOT_UNWRAP),
            MAX_EXPIRY
        );
        names[ROOT_NODE] = "\x00";
        // set based on network
        // names[ETH_NODE] = "\x03eth\x00";
        names[ETH_NODE] = "\x03ecld\x00";
        // names[ETH_NODE] = "\x03etny\x00";
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Fuse, INameWrapper) returns (bool) {
        return
            interfaceId == type(INameWrapper).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /* ERC1155 Fuse */

    /**
     * @notice Gets the owner of a name
     * @param id Label as a string of the .eth domain to wrap
     * @return owner The owner of the name
     */

    function ownerOf(
        uint256 id
    ) public view override(ERC1155Fuse, INameWrapper) returns (address owner) {
        return super.ownerOf(id);
    }

    /**
     * @notice Gets the owner of a name
     * @param id Namehash of the name
     * @return operator Approved operator of a name
     */

    function getApproved(
        uint256 id
    )
        public
        view
        override(ERC1155Fuse, INameWrapper)
        returns (address operator)
    {
        address owner = ownerOf(id);
        if (owner == address(0)) {
            return address(0);
        }
        return super.getApproved(id);
    }

    /**
     * @notice Approves an address for a name
     * @param to address to approve
     * @param tokenId name to approve
     */

    function approve(
        address to,
        uint256 tokenId
    ) public override(ERC1155Fuse, INameWrapper) {
        (, uint32 fuses, ) = getData(tokenId);
        if (fuses & CANNOT_APPROVE == CANNOT_APPROVE) {
            revert OperationProhibited(bytes32(tokenId));
        }
        super.approve(to, tokenId);
    }

    /**
     * @notice Gets the data for a name
     * @param id Namehash of the name
     * @return owner Owner of the name
     * @return fuses Fuses of the name
     * @return expiry Expiry of the name
     */

    function getData(
        uint256 id
    )
        public
        view
        override(ERC1155Fuse, INameWrapper)
        returns (address owner, uint32 fuses, uint64 expiry)
    {
        (owner, fuses, expiry) = super.getData(id);

        (owner, fuses) = _clearOwnerAndFuses(owner, fuses, expiry);
    }

    /* Metadata service */

    /**
     * @notice Set the metadata service. Only the owner can do this
     * @param _metadataService The new metadata service
     */

    function setMetadataService(
        IMetadataService _metadataService
    ) public onlyOwner {
        metadataService = _metadataService;
    }

    /**
     * @notice Get the metadata uri
     * @param tokenId The id of the token
     * @return string uri of the metadata service
     */

    function uri(
        uint256 tokenId
    )
        public
        view
        override(INameWrapper, IERC1155MetadataURI)
        returns (string memory)
    {
        return metadataService.uri(tokenId);
    }

    /**
     * @notice Set the address of the upgradeContract of the contract. only admin can do this
     * @dev The default value of upgradeContract is the 0 address. Use the 0 address at any time
     * to make the contract not upgradable.
     * @param _upgradeAddress address of an upgraded contract
     */

    function setUpgradeContract(
        INameWrapperUpgrade _upgradeAddress
    ) public onlyOwner {
        if (address(upgradeContract) != address(0)) {
            registrar.setApprovalForAll(address(upgradeContract), false);
            ens.setApprovalForAll(address(upgradeContract), false);
        }

        upgradeContract = _upgradeAddress;

        if (address(upgradeContract) != address(0)) {
            registrar.setApprovalForAll(address(upgradeContract), true);
            ens.setApprovalForAll(address(upgradeContract), true);
        }
    }

    /**
     * @notice Checks if msg.sender is the owner or operator of the owner of a name
     * @param node namehash of the name to check
     */

    modifier onlyTokenOwner(bytes32 node) {
        if (!canModifyName(node, msg.sender)) {
            revert Unauthorised(node, msg.sender);
        }

        _;
    }

    /**
     * @notice Checks if owner or operator of the owner
     * @param node namehash of the name to check
     * @param addr which address to check permissions for
     * @return whether or not is owner or operator
     */

    function canModifyName(
        bytes32 node,
        address addr
    ) public view returns (bool) {
        (address owner, uint32 fuses, uint64 expiry) = getData(uint256(node));
        return
            (owner == addr || isApprovedForAll(owner, addr)) &&
            !_isETH2LDInGracePeriod(fuses, expiry);
    }

    /**
     * @notice Checks if owner/operator or approved by owner
     * @param node namehash of the name to check
     * @param addr which address to check permissions for
     * @return whether or not is owner/operator or approved
     */

    function canExtendSubnames(
        bytes32 node,
        address addr
    ) public view returns (bool) {
        (address owner, uint32 fuses, uint64 expiry) = getData(uint256(node));
        return
            (owner == addr ||
                isApprovedForAll(owner, addr) ||
                getApproved(uint256(node)) == addr) &&
            !_isETH2LDInGracePeriod(fuses, expiry);
    }

    /**
     * @notice Wraps a .eth domain, creating a new token and sending the original ERC721 token to this contract
     * @dev Can be called by the owner of the name on the .eth registrar or an authorised caller on the registrar
     * @param label Label as a string of the .eth domain to wrap
     * @param wrappedOwner Owner of the name in this contract
     * @param ownerControlledFuses Initial owner-controlled fuses to set
     * @param resolver Resolver contract address
     */

    function wrapETH2LD(
        string calldata label,
        address wrappedOwner,
        uint16 ownerControlledFuses,
        address resolver
    ) public returns (uint64 expiry) {
        uint256 tokenId = uint256(keccak256(bytes(label)));
        address registrant = registrar.ownerOf(tokenId);
        if (
            registrant != msg.sender &&
            !registrar.isApprovedForAll(registrant, msg.sender)
        ) {
            revert Unauthorised(
                _makeNode(ETH_NODE, bytes32(tokenId)),
                msg.sender
            );
        }

        // transfer the token from the user to this contract
        registrar.transferFrom(registrant, address(this), tokenId);

        // transfer the ens record back to the new owner (this contract)
        registrar.reclaim(tokenId, address(this));

        expiry = uint64(registrar.nameExpires(tokenId)) + GRACE_PERIOD;

        _wrapETH2LD(
            label,
            wrappedOwner,
            ownerControlledFuses,
            expiry,
            resolver
        );
    }

    /**
     * @dev Registers a new .eth second-level domain and wraps it.
     *      Only callable by authorised controllers.
     * @param label The label to register (Eg, 'foo' for 'foo.eth').
     * @param wrappedOwner The owner of the wrapped name.
     * @param duration The duration, in seconds, to register the name for.
     * @param resolver The resolver address to set on the ENS registry (optional).
     * @param ownerControlledFuses Initial owner-controlled fuses to set
     * @return registrarExpiry The expiry date of the new name on the .eth registrar, in seconds since the Unix epoch.
     */

    function registerAndWrapETH2LD(
        string calldata label,
        address wrappedOwner,
        uint256 duration,
        address resolver,
        uint16 ownerControlledFuses
    ) external onlyController returns (uint256 registrarExpiry) {
        uint256 tokenId = uint256(keccak256(bytes(label)));
        registrarExpiry = registrar.register(tokenId, address(this), duration);
        _wrapETH2LD(
            label,
            wrappedOwner,
            ownerControlledFuses,
            uint64(registrarExpiry) + GRACE_PERIOD,
            resolver
        );
    }

    /**
     * @notice Renews a .eth second-level domain.
     * @dev Only callable by authorised controllers.
     * @param tokenId The hash of the label to register (eg, `keccak256('foo')`, for 'foo.eth').
     * @param duration The number of seconds to renew the name for.
     * @return expires The expiry date of the name on the .eth registrar, in seconds since the Unix epoch.
     */

    function renew(
        uint256 tokenId,
        uint256 duration
    ) external onlyController returns (uint256 expires) {
        bytes32 node = _makeNode(ETH_NODE, bytes32(tokenId));

        uint256 registrarExpiry = registrar.renew(tokenId, duration);

        // Do not set anything in wrapper if name is not wrapped
        try registrar.ownerOf(tokenId) returns (address registrarOwner) {
            if (
                registrarOwner != address(this) ||
                ens.owner(node) != address(this)
            ) {
                return registrarExpiry;
            }
        } catch {
            return registrarExpiry;
        }

        // Set expiry in Wrapper
        uint64 expiry = uint64(registrarExpiry) + GRACE_PERIOD;

        // Use super to allow names expired on the wrapper, but not expired on the registrar to renew()
        (address owner, uint32 fuses, ) = super.getData(uint256(node));
        _setData(node, owner, fuses, expiry);

        return registrarExpiry;
    }

    /**
     * @notice Wraps a non .eth domain, of any kind. Could be a DNSSEC name vitalik.xyz or a subdomain
     * @dev Can be called by the owner in the registry or an authorised caller in the registry
     * @param name The name to wrap, in DNS format
     * @param wrappedOwner Owner of the name in this contract
     * @param resolver Resolver contract
     */

    function wrap(
        bytes calldata name,
        address wrappedOwner,
        address resolver
    ) public {
        (bytes32 labelhash, uint256 offset) = name.readLabel(0);
        bytes32 parentNode = name.namehash(offset);
        bytes32 node = _makeNode(parentNode, labelhash);

        names[node] = name;

        if (parentNode == ETH_NODE) {
            revert IncompatibleParent();
        }

        address owner = ens.owner(node);

        if (owner != msg.sender && !ens.isApprovedForAll(owner, msg.sender)) {
            revert Unauthorised(node, msg.sender);
        }

        if (resolver != address(0)) {
            ens.setResolver(node, resolver);
        }

        ens.setOwner(node, address(this));

        _wrap(node, name, wrappedOwner, 0, 0);
    }

    /**
     * @notice Unwraps a .eth domain. e.g. vitalik.eth
     * @dev Can be called by the owner in the wrapper or an authorised caller in the wrapper
     * @param labelhash Labelhash of the .eth domain
     * @param registrant Sets the owner in the .eth registrar to this address
     * @param controller Sets the owner in the registry to this address
     */

    function unwrapETH2LD(
        bytes32 labelhash,
        address registrant,
        address controller
    ) public onlyTokenOwner(_makeNode(ETH_NODE, labelhash)) {
        if (registrant == address(this)) {
            revert IncorrectTargetOwner(registrant);
        }
        _unwrap(_makeNode(ETH_NODE, labelhash), controller);
        registrar.safeTransferFrom(
            address(this),
            registrant,
            uint256(labelhash)
        );
    }

    /**
     * @notice Unwraps a non .eth domain, of any kind. Could be a DNSSEC name vitalik.xyz or a subdomain
     * @dev Can be called by the owner in the wrapper or an authorised caller in the wrapper
     * @param parentNode Parent namehash of the name e.g. vitalik.xyz would be namehash('xyz')
     * @param labelhash Labelhash of the name, e.g. vitalik.xyz would be keccak256('vitalik')
     * @param controller Sets the owner in the registry to this address
     */

    function unwrap(
        bytes32 parentNode,
        bytes32 labelhash,
        address controller
    ) public onlyTokenOwner(_makeNode(parentNode, labelhash)) {
        if (parentNode == ETH_NODE) {
            revert IncompatibleParent();
        }
        if (controller == address(0x0) || controller == address(this)) {
            revert IncorrectTargetOwner(controller);
        }
        _unwrap(_makeNode(parentNode, labelhash), controller);
    }

    /**
     * @notice Sets fuses of a name
     * @param node Namehash of the name
     * @param ownerControlledFuses Owner-controlled fuses to burn
     * @return Old fuses
     */

    function setFuses(
        bytes32 node,
        uint16 ownerControlledFuses
    )
        public
        onlyTokenOwner(node)
        operationAllowed(node, CANNOT_BURN_FUSES)
        returns (uint32)
    {
        // owner protected by onlyTokenOwner
        (address owner, uint32 oldFuses, uint64 expiry) = getData(
            uint256(node)
        );
        _setFuses(node, owner, ownerControlledFuses | oldFuses, expiry, expiry);
        return oldFuses;
    }

    /**
     * @notice Extends expiry for a name
     * @param parentNode Parent namehash of the name e.g. vitalik.xyz would be namehash('xyz')
     * @param labelhash Labelhash of the name, e.g. vitalik.xyz would be keccak256('vitalik')
     * @param expiry When the name will expire in seconds since the Unix epoch
     * @return New expiry
     */

    function extendExpiry(
        bytes32 parentNode,
        bytes32 labelhash,
        uint64 expiry
    ) public returns (uint64) {
        bytes32 node = _makeNode(parentNode, labelhash);

        if (!_isWrapped(node)) {
            revert NameIsNotWrapped();
        }

        // this flag is used later, when checking fuses
        bool canExtendSubname = canExtendSubnames(parentNode, msg.sender);
        // only allow the owner of the name or owner of the parent name
        if (!canExtendSubname && !canModifyName(node, msg.sender)) {
            revert Unauthorised(node, msg.sender);
        }

        (address owner, uint32 fuses, uint64 oldExpiry) = getData(
            uint256(node)
        );

        // Either CAN_EXTEND_EXPIRY must be set, or the caller must have permission to modify the parent name
        if (!canExtendSubname && fuses & CAN_EXTEND_EXPIRY == 0) {
            revert OperationProhibited(node);
        }

        // Max expiry is set to the expiry of the parent
        (, , uint64 maxExpiry) = getData(uint256(parentNode));
        expiry = _normaliseExpiry(expiry, oldExpiry, maxExpiry);

        _setData(node, owner, fuses, expiry);
        emit ExpiryExtended(node, expiry);
        return expiry;
    }

    /**
     * @notice Upgrades a domain of any kind. Could be a .eth name vitalik.eth, a DNSSEC name vitalik.xyz, or a subdomain
     * @dev Can be called by the owner or an authorised caller
     * @param name The name to upgrade, in DNS format
     * @param extraData Extra data to pass to the upgrade contract
     */

    function upgrade(bytes calldata name, bytes calldata extraData) public {
        bytes32 node = name.namehash(0);

        if (address(upgradeContract) == address(0)) {
            revert CannotUpgrade();
        }

        if (!canModifyName(node, msg.sender)) {
            revert Unauthorised(node, msg.sender);
        }

        (address currentOwner, uint32 fuses, uint64 expiry) = getData(
            uint256(node)
        );

        address approved = getApproved(uint256(node));

        _burn(uint256(node));

        upgradeContract.wrapFromUpgrade(
            name,
            currentOwner,
            fuses,
            expiry,
            approved,
            extraData
        );
    }

    /**
    /* @notice Sets fuses of a name that you own the parent of
     * @param parentNode Parent namehash of the name e.g. vitalik.xyz would be namehash('xyz')
     * @param labelhash Labelhash of the name, e.g. vitalik.xyz would be keccak256('vitalik')
     * @param fuses Fuses to burn
     * @param expiry When the name will expire in seconds since the Unix epoch
     */

    function setChildFuses(
        bytes32 parentNode,
        bytes32 labelhash,
        uint32 fuses,
        uint64 expiry
    ) public {
        bytes32 node = _makeNode(parentNode, labelhash);
        _checkFusesAreSettable(node, fuses);
        (address owner, uint32 oldFuses, uint64 oldExpiry) = getData(
            uint256(node)
        );
        if (owner == address(0) || ens.owner(node) != address(this)) {
            revert NameIsNotWrapped();
        }
        // max expiry is set to the expiry of the parent
        (, uint32 parentFuses, uint64 maxExpiry) = getData(uint256(parentNode));
        if (parentNode == ROOT_NODE) {
            if (!canModifyName(node, msg.sender)) {
                revert Unauthorised(node, msg.sender);
            }
        } else {
            if (!canModifyName(parentNode, msg.sender)) {
                revert Unauthorised(parentNode, msg.sender);
            }
        }

        _checkParentFuses(node, fuses, parentFuses);

        expiry = _normaliseExpiry(expiry, oldExpiry, maxExpiry);

        // if PARENT_CANNOT_CONTROL has been burned and fuses have changed
        if (
            oldFuses & PARENT_CANNOT_CONTROL != 0 &&
            oldFuses | fuses != oldFuses
        ) {
            revert OperationProhibited(node);
        }
        fuses |= oldFuses;
        _setFuses(node, owner, fuses, oldExpiry, expiry);
    }

    /**
     * @notice Sets the subdomain owner in the registry and then wraps the subdomain
     * @param parentNode Parent namehash of the subdomain
     * @param label Label of the subdomain as a string
     * @param owner New owner in the wrapper
     * @param fuses Initial fuses for the wrapped subdomain
     * @param expiry When the name will expire in seconds since the Unix epoch
     * @return node Namehash of the subdomain
     */

    function setSubnodeOwner(
        bytes32 parentNode,
        string calldata label,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) public onlyTokenOwner(parentNode) returns (bytes32 node) {
        bytes32 labelhash = keccak256(bytes(label));
        node = _makeNode(parentNode, labelhash);
        _checkCanCallSetSubnodeOwner(parentNode, node);
        _checkFusesAreSettable(node, fuses);
        bytes memory name = _saveLabel(parentNode, node, label);
        expiry = _checkParentFusesAndExpiry(parentNode, node, fuses, expiry);

        if (!_isWrapped(node)) {
            ens.setSubnodeOwner(parentNode, labelhash, address(this));
            _wrap(node, name, owner, fuses, expiry);
        } else {
            _updateName(parentNode, node, label, owner, fuses, expiry);
        }
    }

    /**
     * @notice Sets the subdomain owner in the registry with records and then wraps the subdomain
     * @param parentNode parent namehash of the subdomain
     * @param label label of the subdomain as a string
     * @param owner new owner in the wrapper
     * @param resolver resolver contract in the registry
     * @param ttl ttl in the registry
     * @param fuses initial fuses for the wrapped subdomain
     * @param expiry When the name will expire in seconds since the Unix epoch
     * @return node Namehash of the subdomain
     */

    function setSubnodeRecord(
        bytes32 parentNode,
        string memory label,
        address owner,
        address resolver,
        uint64 ttl,
        uint32 fuses,
        uint64 expiry
    ) public onlyTokenOwner(parentNode) returns (bytes32 node) {
        bytes32 labelhash = keccak256(bytes(label));
        node = _makeNode(parentNode, labelhash);
        _checkCanCallSetSubnodeOwner(parentNode, node);
        _checkFusesAreSettable(node, fuses);
        _saveLabel(parentNode, node, label);
        expiry = _checkParentFusesAndExpiry(parentNode, node, fuses, expiry);
        if (!_isWrapped(node)) {
            ens.setSubnodeRecord(
                parentNode,
                labelhash,
                address(this),
                resolver,
                ttl
            );
            _storeNameAndWrap(parentNode, node, label, owner, fuses, expiry);
        } else {
            ens.setSubnodeRecord(
                parentNode,
                labelhash,
                address(this),
                resolver,
                ttl
            );
            _updateName(parentNode, node, label, owner, fuses, expiry);
        }
    }

    /**
     * @notice Sets records for the name in the ENS Registry
     * @param node Namehash of the name to set a record for
     * @param owner New owner in the registry
     * @param resolver Resolver contract
     * @param ttl Time to live in the registry
     */

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    )
        public
        onlyTokenOwner(node)
        operationAllowed(
            node,
            CANNOT_TRANSFER | CANNOT_SET_RESOLVER | CANNOT_SET_TTL
        )
    {
        ens.setRecord(node, address(this), resolver, ttl);
        if (owner == address(0)) {
            (, uint32 fuses, ) = getData(uint256(node));
            if (fuses & IS_DOT_ETH == IS_DOT_ETH) {
                revert IncorrectTargetOwner(owner);
            }
            _unwrap(node, address(0));
        } else {
            address oldOwner = ownerOf(uint256(node));
            _transfer(oldOwner, owner, uint256(node), 1, "");
        }
    }

    /**
     * @notice Sets resolver contract in the registry
     * @param node namehash of the name
     * @param resolver the resolver contract
     */

    function setResolver(
        bytes32 node,
        address resolver
    ) public onlyTokenOwner(node) operationAllowed(node, CANNOT_SET_RESOLVER) {
        ens.setResolver(node, resolver);
    }

    /**
     * @notice Sets TTL in the registry
     * @param node Namehash of the name
     * @param ttl TTL in the registry
     */

    function setTTL(
        bytes32 node,
        uint64 ttl
    ) public onlyTokenOwner(node) operationAllowed(node, CANNOT_SET_TTL) {
        ens.setTTL(node, ttl);
    }

    /**
     * @dev Allows an operation only if none of the specified fuses are burned.
     * @param node The namehash of the name to check fuses on.
     * @param fuseMask A bitmask of fuses that must not be burned.
     */

    modifier operationAllowed(bytes32 node, uint32 fuseMask) {
        (, uint32 fuses, ) = getData(uint256(node));
        if (fuses & fuseMask != 0) {
            revert OperationProhibited(node);
        }
        _;
    }

    /**
     * @notice Check whether a name can call setSubnodeOwner/setSubnodeRecord
     * @dev Checks both CANNOT_CREATE_SUBDOMAIN and PARENT_CANNOT_CONTROL and whether not they have been burnt
     *      and checks whether the owner of the subdomain is 0x0 for creating or already exists for
     *      replacing a subdomain. If either conditions are true, then it is possible to call
     *      setSubnodeOwner
     * @param parentNode Namehash of the parent name to check
     * @param subnode Namehash of the subname to check
     */

    function _checkCanCallSetSubnodeOwner(
        bytes32 parentNode,
        bytes32 subnode
    ) internal view {
        (
            address subnodeOwner,
            uint32 subnodeFuses,
            uint64 subnodeExpiry
        ) = getData(uint256(subnode));

        // check if the registry owner is 0 and expired
        // check if the wrapper owner is 0 and expired
        // If either, then check parent fuses for CANNOT_CREATE_SUBDOMAIN
        bool expired = subnodeExpiry < block.timestamp;
        if (
            expired &&
            // protects a name that has been unwrapped with PCC and doesn't allow the parent to take control by recreating it if unexpired
            (subnodeOwner == address(0) ||
                // protects a name that has been burnt and doesn't allow the parent to take control by recreating it if unexpired
                ens.owner(subnode) == address(0))
        ) {
            (, uint32 parentFuses, ) = getData(uint256(parentNode));
            if (parentFuses & CANNOT_CREATE_SUBDOMAIN != 0) {
                revert OperationProhibited(subnode);
            }
        } else {
            if (subnodeFuses & PARENT_CANNOT_CONTROL != 0) {
                revert OperationProhibited(subnode);
            }
        }
    }

    /**
     * @notice Checks all Fuses in the mask are burned for the node
     * @param node Namehash of the name
     * @param fuseMask The fuses you want to check
     * @return Boolean of whether or not all the selected fuses are burned
     */

    function allFusesBurned(
        bytes32 node,
        uint32 fuseMask
    ) public view returns (bool) {
        (, uint32 fuses, ) = getData(uint256(node));
        return fuses & fuseMask == fuseMask;
    }

    /**
     * @notice Checks if a name is wrapped
     * @param node Namehash of the name
     * @return Boolean of whether or not the name is wrapped
     */

    function isWrapped(bytes32 node) public view returns (bool) {
        bytes memory name = names[node];
        if (name.length == 0) {
            return false;
        }
        (bytes32 labelhash, uint256 offset) = name.readLabel(0);
        bytes32 parentNode = name.namehash(offset);
        return isWrapped(parentNode, labelhash);
    }

    /**
     * @notice Checks if a name is wrapped in a more gas efficient way
     * @param parentNode Namehash of the name
     * @param labelhash Namehash of the name
     * @return Boolean of whether or not the name is wrapped
     */

    function isWrapped(
        bytes32 parentNode,
        bytes32 labelhash
    ) public view returns (bool) {
        bytes32 node = _makeNode(parentNode, labelhash);
        bool wrapped = _isWrapped(node);
        if (parentNode != ETH_NODE) {
            return wrapped;
        }
        try registrar.ownerOf(uint256(labelhash)) returns (address owner) {
            return owner == address(this);
        } catch {
            return false;
        }
    }

    function onERC721Received(
        address to,
        address,
        uint256 tokenId,
        bytes calldata data
    ) public returns (bytes4) {
        //check if it's the eth registrar ERC721
        if (msg.sender != address(registrar)) {
            revert IncorrectTokenType();
        }

        (
            string memory label,
            address owner,
            uint16 ownerControlledFuses,
            address resolver
        ) = abi.decode(data, (string, address, uint16, address));

        bytes32 labelhash = bytes32(tokenId);
        bytes32 labelhashFromData = keccak256(bytes(label));

        if (labelhashFromData != labelhash) {
            revert LabelMismatch(labelhashFromData, labelhash);
        }

        // transfer the ens record back to the new owner (this contract)
        registrar.reclaim(uint256(labelhash), address(this));

        uint64 expiry = uint64(registrar.nameExpires(tokenId)) + GRACE_PERIOD;

        _wrapETH2LD(label, owner, ownerControlledFuses, expiry, resolver);

        return IERC721Receiver(to).onERC721Received.selector;
    }

    /***** Internal functions */

    function _beforeTransfer(
        uint256 id,
        uint32 fuses,
        uint64 expiry
    ) internal override {
        // For this check, treat .eth 2LDs as expiring at the start of the grace period.
        if (fuses & IS_DOT_ETH == IS_DOT_ETH) {
            expiry -= GRACE_PERIOD;
        }

        if (expiry < block.timestamp) {
            // Transferable if the name was not emancipated
            if (fuses & PARENT_CANNOT_CONTROL != 0) {
                revert("ERC1155: insufficient balance for transfer");
            }
        } else {
            // Transferable if CANNOT_TRANSFER is unburned
            if (fuses & CANNOT_TRANSFER != 0) {
                revert OperationProhibited(bytes32(id));
            }
        }

        // delete token approval if CANNOT_APPROVE has not been burnt
        if (fuses & CANNOT_APPROVE == 0) {
            delete _tokenApprovals[id];
        }
    }

    function _clearOwnerAndFuses(
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal view override returns (address, uint32) {
        if (expiry < block.timestamp) {
            if (fuses & PARENT_CANNOT_CONTROL == PARENT_CANNOT_CONTROL) {
                owner = address(0);
            }
            fuses = 0;
        }

        return (owner, fuses);
    }

    function _makeNode(
        bytes32 node,
        bytes32 labelhash
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(node, labelhash));
    }

    function _addLabel(
        string memory label,
        bytes memory name
    ) internal pure returns (bytes memory ret) {
        if (bytes(label).length < 1) {
            revert LabelTooShort();
        }
        if (bytes(label).length > 255) {
            revert LabelTooLong(label);
        }
        return abi.encodePacked(uint8(bytes(label).length), label, name);
    }

    function _mint(
        bytes32 node,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal override {
        _canFusesBeBurned(node, fuses);
        (address oldOwner, , ) = super.getData(uint256(node));
        if (oldOwner != address(0)) {
            // burn and unwrap old token of old owner
            _burn(uint256(node));
            emit NameUnwrapped(node, address(0));
        }
        super._mint(node, owner, fuses, expiry);
    }

    function _wrap(
        bytes32 node,
        bytes memory name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry
    ) internal {
        _mint(node, wrappedOwner, fuses, expiry);
        emit NameWrapped(node, name, wrappedOwner, fuses, expiry);
    }

    function _storeNameAndWrap(
        bytes32 parentNode,
        bytes32 node,
        string memory label,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal {
        bytes memory name = _addLabel(label, names[parentNode]);
        _wrap(node, name, owner, fuses, expiry);
    }

    function _saveLabel(
        bytes32 parentNode,
        bytes32 node,
        string memory label
    ) internal returns (bytes memory) {
        bytes memory name = _addLabel(label, names[parentNode]);
        names[node] = name;
        return name;
    }

    function _updateName(
        bytes32 parentNode,
        bytes32 node,
        string memory label,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal {
        (address oldOwner, uint32 oldFuses, uint64 oldExpiry) = getData(
            uint256(node)
        );
        bytes memory name = _addLabel(label, names[parentNode]);
        if (names[node].length == 0) {
            names[node] = name;
        }
        _setFuses(node, oldOwner, oldFuses | fuses, oldExpiry, expiry);
        if (owner == address(0)) {
            _unwrap(node, address(0));
        } else {
            _transfer(oldOwner, owner, uint256(node), 1, "");
        }
    }

    // wrapper function for stack limit
    function _checkParentFusesAndExpiry(
        bytes32 parentNode,
        bytes32 node,
        uint32 fuses,
        uint64 expiry
    ) internal view returns (uint64) {
        (, , uint64 oldExpiry) = getData(uint256(node));
        (, uint32 parentFuses, uint64 maxExpiry) = getData(uint256(parentNode));
        _checkParentFuses(node, fuses, parentFuses);
        return _normaliseExpiry(expiry, oldExpiry, maxExpiry);
    }

    function _checkParentFuses(
        bytes32 node,
        uint32 fuses,
        uint32 parentFuses
    ) internal pure {
        bool isBurningParentControlledFuses = fuses & PARENT_CONTROLLED_FUSES !=
            0;

        bool parentHasNotBurnedCU = parentFuses & CANNOT_UNWRAP == 0;

        if (isBurningParentControlledFuses && parentHasNotBurnedCU) {
            revert OperationProhibited(node);
        }
    }

    function _normaliseExpiry(
        uint64 expiry,
        uint64 oldExpiry,
        uint64 maxExpiry
    ) private pure returns (uint64) {
        // Expiry cannot be more than maximum allowed
        // .eth names will check registrar, non .eth check parent
        if (expiry > maxExpiry) {
            expiry = maxExpiry;
        }
        // Expiry cannot be less than old expiry
        if (expiry < oldExpiry) {
            expiry = oldExpiry;
        }

        return expiry;
    }

    function _wrapETH2LD(
        string memory label,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry,
        address resolver
    ) private {
        bytes32 labelhash = keccak256(bytes(label));
        bytes32 node = _makeNode(ETH_NODE, labelhash);
        // hardcode dns-encoded eth string for gas savings
        // set based on network
        // bytes memory name = _addLabel(label, "\x03eth\x00");
        bytes memory name = _addLabel(label, "\x03ecld\x00");
        // bytes memory name = _addLabel(label, "\x03etny\x00");
        names[node] = name;

        _wrap(
            node,
            name,
            wrappedOwner,
            fuses | PARENT_CANNOT_CONTROL | IS_DOT_ETH,
            expiry
        );

        if (resolver != address(0)) {
            ens.setResolver(node, resolver);
        }
    }

    function _unwrap(bytes32 node, address owner) private {
        if (allFusesBurned(node, CANNOT_UNWRAP)) {
            revert OperationProhibited(node);
        }

        // Burn token and fuse data
        _burn(uint256(node));
        ens.setOwner(node, owner);

        emit NameUnwrapped(node, owner);
    }

    function _setFuses(
        bytes32 node,
        address owner,
        uint32 fuses,
        uint64 oldExpiry,
        uint64 expiry
    ) internal {
        _setData(node, owner, fuses, expiry);
        emit FusesSet(node, fuses);
        if (expiry > oldExpiry) {
            emit ExpiryExtended(node, expiry);
        }
    }

    function _setData(
        bytes32 node,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal {
        _canFusesBeBurned(node, fuses);
        super._setData(uint256(node), owner, fuses, expiry);
    }

    function _canFusesBeBurned(bytes32 node, uint32 fuses) internal pure {
        // If a non-parent controlled fuse is being burned, check PCC and CU are burnt
        if (
            fuses & ~PARENT_CONTROLLED_FUSES != 0 &&
            fuses & (PARENT_CANNOT_CONTROL | CANNOT_UNWRAP) !=
            (PARENT_CANNOT_CONTROL | CANNOT_UNWRAP)
        ) {
            revert OperationProhibited(node);
        }
    }

    function _checkFusesAreSettable(bytes32 node, uint32 fuses) internal pure {
        if (fuses | USER_SETTABLE_FUSES != USER_SETTABLE_FUSES) {
            // Cannot directly burn other non-user settable fuses
            revert OperationProhibited(node);
        }
    }

    function _isWrapped(bytes32 node) internal view returns (bool) {
        return
            ownerOf(uint256(node)) != address(0) &&
            ens.owner(node) == address(this);
    }

    function _isETH2LDInGracePeriod(
        uint32 fuses,
        uint64 expiry
    ) internal view returns (bool) {
        return
            fuses & IS_DOT_ETH == IS_DOT_ETH &&
            expiry - GRACE_PERIOD < block.timestamp;
    }
}


// Chain: POLYGON - File: contracts/wrapper/StaticMetadataService.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

contract StaticMetadataService {
    string private _uri;

    constructor(string memory _metaDataUri) {
        _uri = _metaDataUri;
    }

    function uri(uint256) public view returns (string memory) {
        return _uri;
    }
}


// Chain: POLYGON - File: contracts/wrapper/test/NameGriefer.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {INameWrapper} from "../INameWrapper.sol";
import {ENS} from "../../registry/ENS.sol";
import {BytesUtils} from "../../utils/BytesUtils.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract NameGriefer is IERC1155Receiver {
    using BytesUtils for *;

    ENS public immutable ens;
    INameWrapper public immutable wrapper;

    constructor(INameWrapper _wrapper) {
        wrapper = _wrapper;
        ENS _ens = _wrapper.ens();
        ens = _ens;
        _ens.setApprovalForAll(address(_wrapper), true);
    }

    function destroy(bytes calldata name) public {
        wrapper.wrap(name, address(this), address(0));
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        require(operator == address(this), "Operator must be us");
        require(from == address(0), "Token must be new");

        // Unwrap the name
        bytes memory name = wrapper.names(bytes32(id));
        (bytes32 labelhash, uint256 offset) = name.readLabel(0);
        bytes32 parentNode = name.namehash(offset);
        wrapper.unwrap(parentNode, labelhash, address(this));

        // Here we can do something with the name before it's permanently burned, like
        // set the resolver or create subdomains.

        return NameGriefer.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external override returns (bytes4) {
        return NameGriefer.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceID
    ) external view override returns (bool) {
        return
            interfaceID == 0x01ffc9a7 || // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
            interfaceID == 0x4e2312e0; // ERC-1155 `ERC1155TokenReceiver` support (i.e. `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")) ^ bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`).
    }
}


// Chain: POLYGON - File: contracts/wrapper/test/TestNameWrapperReentrancy.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "../INameWrapper.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract TestNameWrapperReentrancy is ERC165, IERC1155Receiver {
    INameWrapper nameWrapper;
    address owner;
    bytes32 parentNode;
    bytes32 labelHash;
    uint256 tokenId;

    constructor(
        address _owner,
        INameWrapper _nameWrapper,
        bytes32 _parentNode,
        bytes32 _labelHash
    ) {
        owner = _owner;
        nameWrapper = _nameWrapper;
        parentNode = _parentNode;
        labelHash = _labelHash;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address,
        address,
        uint256 _id,
        uint256,
        bytes calldata
    ) public override returns (bytes4) {
        tokenId = _id;
        nameWrapper.unwrap(parentNode, labelHash, owner);

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

    function claimToOwner() public {
        nameWrapper.safeTransferFrom(address(this), owner, tokenId, 1, "");
    }
}


// Chain: POLYGON - File: test/registry/mocks/DummyResolver.sol
pragma solidity >=0.8.4;

contract DummyResolver {
    mapping(bytes32 => string) public name;

    function setName(bytes32 node, string memory _name) public {
        name[node] = _name;
    }
}


// Chain: POLYGON - File: test/reverseRegistrar/mocks/MockReverseClaimerImplementer.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {ENS} from "../../../contracts/registry/ENS.sol";
import {ReverseClaimer} from "../../../contracts/reverseRegistrar/ReverseClaimer.sol";

contract MockReverseClaimerImplementer is ReverseClaimer {
    constructor(ENS ens, address claimant) ReverseClaimer(ens, claimant) {}
}


// Chain: POLYGON - File: test/utils/mocks/DummyOffchainResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../../../contracts/resolvers/profiles/ITextResolver.sol";
import "../../../contracts/resolvers/profiles/IExtendedResolver.sol";

error OffchainLookup(
    address sender,
    string[] urls,
    bytes callData,
    bytes4 callbackFunction,
    bytes extraData
);

contract DummyOffchainResolver is IExtendedResolver, ERC165 {
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IExtendedResolver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function resolve(
        bytes calldata /* name */,
        bytes calldata data
    ) external view returns (bytes memory) {
        string[] memory urls = new string[](1);
        urls[0] = "https://example.com/";

        if (bytes4(data) == bytes4(0x12345678)) {
            return abi.encode("foo");
        }
        revert OffchainLookup(
            address(this),
            urls,
            data,
            DummyOffchainResolver.resolveCallback.selector,
            data
        );
    }

    function addr(bytes32) external pure returns (address) {
        return 0x69420f05A11f617B4B74fFe2E04B2D300dFA556F;
    }

    function resolveCallback(
        bytes calldata response,
        bytes calldata extraData
    ) external view returns (bytes memory) {
        require(
            keccak256(response) == keccak256(extraData),
            "Response data error"
        );
        if (bytes4(extraData) == bytes4(keccak256("name(bytes32)"))) {
            // set based on network
            return abi.encode("offchain.test.eth");
            // return abi.encode("offchain.test.ecld");
            // return abi.encode("offchain.test.etny");
        }
        return abi.encode(address(this));
    }
}


// Chain: POLYGON - File: test/utils/mocks/LegacyResolver.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

contract LegacyResolver {
    function addr(bytes32 /* node */) public view returns (address) {
        return address(this);
    }
}


// Chain: POLYGON - File: test/utils/mocks/MockERC20.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        address[] memory addresses
    ) ERC20(name, symbol) {
        _mint(msg.sender, 100 * 10 ** uint256(decimals()));

        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], 100 * 10 ** uint256(decimals()));
        }
    }
}


// Chain: POLYGON - File: test/utils/mocks/MockOffchainResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../../../contracts/resolvers/profiles/IExtendedResolver.sol";

error OffchainLookup(
    address sender,
    string[] urls,
    bytes callData,
    bytes4 callbackFunction,
    bytes extraData
);

contract MockOffchainResolver is IExtendedResolver, ERC165 {
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IExtendedResolver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function resolve(
        bytes calldata /* name */,
        bytes calldata data
    ) external view returns (bytes memory) {
        string[] memory urls = new string[](1);
        urls[0] = "https://example.com/";
        revert OffchainLookup(
            address(this),
            urls,
            data,
            MockOffchainResolver.resolveCallback.selector,
            data
        );
    }

    function addr(bytes32) external pure returns (bytes memory) {
        return abi.encode("onchain");
    }

    function resolveCallback(
        bytes calldata response,
        bytes calldata extraData
    ) external view returns (bytes memory) {
        (, bytes memory callData, ) = abi.decode(
            extraData,
            (bytes, bytes, bytes4)
        );
        if (bytes4(callData) == bytes4(keccak256("addr(bytes32)"))) {
            (bytes memory result, , ) = abi.decode(
                response,
                (bytes, uint64, bytes)
            );
            return result;
        }
        return abi.encode(address(this));
    }
}


// Chain: POLYGON - File: test/utils/mocks/StringUtilsTest.sol
// SPDX-License-Identifier: MIT
import "../../../contracts/utils/StringUtils.sol";

library StringUtilsTest {
    function testEscape(
        string calldata testStr
    ) public pure returns (string memory) {
        return StringUtils.escape(testStr);
    }
}