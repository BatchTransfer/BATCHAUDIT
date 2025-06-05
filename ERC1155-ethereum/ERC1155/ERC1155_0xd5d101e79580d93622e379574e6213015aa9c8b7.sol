// File: CuriosProxy.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./interfaces/ICuriosForProxy.sol";
import "@openzeppelin/v4.9.2/access/Ownable.sol";

contract CuriosProxy is Ownable {
    ICuriosForProxy public CURIOS;
    IPoppetsForProxy public POPPETS;
    mapping(address => bool) public isApproved;
    uint256[][] private _amounts;

    // this should be amounts: [[0], [1], [1,1], [1,1,1], [1,1,1,1], [1,1,1,1,1], [1,1,1,1,1,1], [1,1,1,1,1,1,1]]
    constructor(address _curios, address _poppets, uint256[][] memory amounts) {
        CURIOS = ICuriosForProxy(_curios);
        POPPETS = IPoppetsForProxy(_poppets);

        // _amounts.push([0]);
        // _amounts.push([1]);
        // _amounts.push([1, 1]);
        // _amounts.push([1, 1, 1]);
        // _amounts.push([1, 1, 1, 1]);
        // _amounts.push([1, 1, 1, 1, 1]);
        // _amounts.push([1, 1, 1, 1, 1, 1]);

        _amounts = amounts;

        isApproved[_poppets] = true;
    }

    modifier onlyApproved() {
        if (!isApproved[msg.sender]) {
            revert(
                "CurioProxy: Only approved addresses can call this function"
            );
        }
        _;
    }

    function approve(address _address) external onlyOwner {
        isApproved[_address] = true;
    }

    function revoke(address _address) external onlyOwner {
        isApproved[_address] = false;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 /* amount */,
        bytes calldata data
    ) external onlyApproved {
        CURIOS.safeTransferFrom(from, to, id, 1, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata /* amounts */,
        bytes calldata data
    ) external onlyApproved {
        CURIOS.safeBatchTransferFrom(from, to, ids, _amounts[ids.length], data);
    }

    function mintFromPoppets(uint[] calldata ids) external onlyApproved {
        CURIOS.mintFromPoppets(ids);
    }

    function mintFromPack(
        address to_,
        uint[] calldata ids
    ) external onlyApproved {
        CURIOS.mintFromPack(to_, ids);
    }

    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256) {
        return CURIOS.balanceOf(account, id);
    }

    function allOwnedBy(
        address account,
        uint256 end_common
    ) external view returns (uint256[] memory, uint256[] memory) {
        uint256 count = 0;
        uint256 balance = 0;
        uint256 end_special = CURIOS.nextToken();

        end_common += 1;

        for (uint256 i = 0; i < end_special; i++) {
            balance = CURIOS.balanceOf(account, i);
            if (balance > 0) {
                count++;
            }
        }

        for (uint256 i = 100_000; i < end_common; i++) {
            balance = CURIOS.balanceOf(account, i);
            if (balance > 0) {
                count++;
            }
        }

        uint256[] memory ownedTokens = new uint256[](count);
        uint256[] memory balances = new uint256[](count);

        count = 0;

        for (uint256 i = 0; i < end_special; ++i) {
            balance = CURIOS.balanceOf(account, i);

            if (balance > 0) {
                ownedTokens[count] = i;
                balances[count] = balance;
                count++;
            }
        }

        for (uint256 i = 100_000; i < end_common; ++i) {
            balance = CURIOS.balanceOf(account, i);
            if (balance > 0) {
                ownedTokens[count] = i;
                balances[count] = balance;
                count++;
            }
        }

        return (ownedTokens, balances);
    }

    function withdraw() public payable {
        (bool sent, ) = payable(owner()).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    /**
     * @dev Returns an array of token IDs owned by `owner`.
     *
     * This function scans the ownership mapping and is O(`totalSupply`) in complexity.
     * It is meant to be called off-chain.
     *
     * See {ERC721AQueryable-tokensOfOwnerIn} for splitting the scan into
     * multiple smaller scans if the collection is large enough to cause
     * an out-of-gas error (10K collections should be fine).
     */
    function poppetsOwnedBy(
        address owner
    ) external view returns (uint256[] memory) {
        unchecked {
            uint256 tokenIdsIdx;
            address currOwnershipAddr;
            uint256 tokenIdsLength = POPPETS.balanceOf(owner);
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);

            for (uint256 i = 1; tokenIdsIdx != tokenIdsLength; ++i) {
                currOwnershipAddr = POPPETS.ownerOf(i);

                if (currOwnershipAddr == owner) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            return tokenIds;
        }
    }
}


// File: .cache/OpenZeppelin/v4.9.2/access/Ownable.sol
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


// File: .cache/OpenZeppelin/v4.9.2/utils/Context.sol
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


// File: interfaces/ICuriosForProxy.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ICuriosForProxy {
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

    function mintFromPoppets(uint[] calldata ids) external;

    function mintFromPack(address to_, uint[] calldata ids) external;

    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);

    function nextToken() external view returns (uint256);
}

interface IPoppetsForProxy {
    function balanceOf(address account) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);
}


