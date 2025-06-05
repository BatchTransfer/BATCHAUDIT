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


// File: @openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol
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


// File: contracts/Minimal1155SBT.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

/**
 * @author SanLeo461, on behalf of Moonlings
 */
contract Minimal1155SBT is IERC1155, IERC1155MetadataURI, ERC165 {
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant START_BALANCES_SLOT = uint256(keccak256('1155sbt.start_balances')) - 1;

    error TokenIsSoulbound();

    // Used as the URI for every token as there is only 1 token ID.
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId || interfaceId == type(IERC1155MetadataURI).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        require(id == TOKEN_ID, "ERC1155: invalid token ID");
        return 0;
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address, /* operator */ bool /* approved */ ) public pure override {
        revert TokenIsSoulbound();
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address, /* account */ address /* operator */ ) public pure override returns (bool) {
        return false;
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address, /* from */
        address, /* to */
        uint256, /* id */
        uint256, /* amount */
        bytes memory /* data */
    ) public virtual override {
        revert TokenIsSoulbound();
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address, /* from */
        address, /* to */
        uint256[] memory, /* ids */
        uint256[] memory, /* amounts */
        bytes memory /* data */
    ) public virtual override {
        revert TokenIsSoulbound();
    }

    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
        emit URI(newuri, TOKEN_ID);
    }
}


// File: contracts/MoonlingsSBT.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./Minimal1155SBT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author SanLeo461, on behalf of Moonlings
 */
contract MoonlingsSBT is Minimal1155SBT, Ownable {
    bool public canAirdrop = true;
    uint256 public supply = 0;

    string public name = "GMoonling to You - Moonpass";
    string public symbol = "GMLING";

    uint256 private _storageCounter = START_BALANCES_SLOT;
    uint256 private _storageUpto = 0;

    constructor(string memory uri_) Minimal1155SBT(uri_) {}

    function airdrop(bytes calldata addresses) external onlyOwner {
        require(canAirdrop, "Airdrop has been disabled");
        require(addresses.length % 20 == 0, "Invalid addresses length");

        uint256 _storageCounterVal = _storageCounter;
        uint256  _storageUptoVal = _storageUpto;
        supply += addresses.length / 20;
        

        assembly {
            let sz := div(addresses.length, 20)
            let storageCounter := _storageCounterVal
            let currentStoreAcc := sload(_storageCounterVal)
            let upto := _storageUptoVal
            let operator := caller()
            let zeroAddress := 0
            let signature := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
            mstore(0x40, 1)
            mstore(0x60, 1)
            for {
                let i := 0
            } lt(i, sz) {
                i := add(i, 1)
            } {
                let offset := mul(i, 20)
                let toAirdropTo := shr(96, calldataload(add(addresses.offset, offset)))
                log4(0x40, 0x40, signature, operator, zeroAddress, toAirdropTo)
                
                switch gt(upto, 11)
                case 0 {
                    currentStoreAcc := or(currentStoreAcc, shl(sub(96, mul(upto, 8)), toAirdropTo))
                    upto := add(upto, 20)
                }
                default {
                    let overlap := sub(upto, 12)
                    let toStore := or(currentStoreAcc, shr(mul(overlap, 8), toAirdropTo))

                    sstore(storageCounter, toStore)
                    storageCounter := add(storageCounter, 1)
                    currentStoreAcc := shl(sub(256, mul(overlap, 8)), toAirdropTo)
                    upto := overlap
                }
            }
            if gt(upto, 0) {
                sstore(storageCounter, currentStoreAcc)
            }
            _storageCounterVal := storageCounter
            _storageUptoVal := upto
        }
        _storageCounter = _storageCounterVal;
        _storageUpto = _storageUptoVal;
    }

    function getAddressIndexed(uint256 index) public view returns (address toReturn) {
        uint256 startBalancesSlot = START_BALANCES_SLOT;

        assembly {
            toReturn := 0
            let storageCounter := startBalancesSlot
            let slotIn := div(mul(20, index), 32)
            let indexIn := mod(mul(20, index), 32)
            let slot := sload(add(storageCounter, slotIn))
            toReturn := shl(mul(indexIn, 8), slot)
            switch gt(indexIn, 12)
            case 0 {
                toReturn := shr(96, toReturn)
            }
            default {
                let overlap := sub(indexIn, 12)
                toReturn := shl(mul(overlap, 8), shr(add(96, mul(overlap, 8)), toReturn))
                let slot2 := sload(add(storageCounter, add(slotIn, 1)))
                toReturn := or(toReturn, shr(sub(256, mul(overlap, 8)), slot2))
            }
        }
    }

    function _isAddressIncluded(address toFind, uint256 begin, uint256 end) internal view returns (bool ret) {
        uint160 toFindInt = uint160(toFind);
        uint256 len = end - begin;
        if (len == 0) {
            return false;
        } else if (len == 1) {
            return toFind == getAddressIndexed(begin);
        }

        uint256 mid = begin + len / 2;
        uint160 midAddr = uint160(getAddressIndexed(mid));
        if (uint160(midAddr) > toFindInt) {
            return _isAddressIncluded(toFind, begin, mid);
        } else if (uint160(midAddr) < toFindInt) {
            return _isAddressIncluded(toFind, mid, end);
        }
        return true;
    }

    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        require(id == TOKEN_ID, "ERC1155: invalid token ID");
        return _isAddressIncluded(account, 0, supply) ? 1 : 0;
    }

    function setURI(string memory uri_) external onlyOwner {
        _setURI(uri_);
    }

    function renounceAirdropRights() external onlyOwner {
        canAirdrop = false;
    }
}


