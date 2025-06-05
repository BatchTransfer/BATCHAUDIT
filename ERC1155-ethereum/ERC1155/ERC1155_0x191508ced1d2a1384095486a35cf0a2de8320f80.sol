// File: @openzeppelin/contracts/access/Ownable.sol
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


// File: contracts/CBSProxy.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Sig.sol";

interface IToken {
    function supplyLimit(uint256 id) external returns (uint256);

    function totalSupply(uint256 id) external returns (uint256);

    function mintFT(address to, uint256 tokenID, uint256 quantity) external;

    function mintNFT(address to, uint256 tokenID) external;

    function batchMintNFT(address to, uint256[] calldata ids) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
}

contract CBSProxy is Ownable {
    address public token;
    mapping(address => bool) public authorized;

    function setAuthorized(address addr, bool allowed) public onlyOwner {
        authorized[addr] = allowed;
    }

    function setTokenAddress(address addr) public onlyOwner {
        token = addr;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public {
        require(authorized[_msgSender()], "Not authorized.");

        _transferOrMint(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public {
        require(authorized[_msgSender()], "Not authorized.");
        require(ids.length == amounts.length, "Array mismatch.");

        for (uint i = 0; i < ids.length; i++) {
            _transferOrMint(from, to, ids[i], amounts[i], data);
        }
    }

    function _transferOrMint(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) internal {
        // If the supply limit of the token ID is 1, we know it's an NFT, meaning it could be transferred or minted.
        if (IToken(token).supplyLimit(id) == 1) {
            _transferOrMintNFT(from, to, id, data);
            return;
        }

        // If the supply limit is NOT 1, it's a FT. FTs don't exist on chain when they are custodially held, so we
        // always mint.
        IToken(token).mintFT(to, id, amount);
    }

    function _transferOrMintNFT(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) internal {
        if (IToken(token).totalSupply(id) == 1) {
            IToken(token).safeTransferFrom(from, to, id, 1, data);
            return;
        }

        IToken(token).mintNFT(to, id);
    }
}


// File: contracts/Sig.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library Sig {
    function verify(
        bytes memory signature,
        bytes32 digestHash,
        address expected
    ) internal pure returns (bool) {
        address std = getSigner(signature, digestHash);
        if (std == expected) {
            return true;
        }

        address packed = getSignerPacked(signature, digestHash);
        if (packed == expected) {
            return true;
        }

        return false;
    }

    function getSigner(
        bytes memory signature,
        bytes32 digestHash
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        bytes32 signed = getMessageHash(digestHash);
        return ecrecover(signed, v, r, s);
    }

    function getSignerPacked(
        bytes memory signature,
        bytes32 digestHash
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        bytes32 signed = getMessageHashPacked(digestHash);
        return ecrecover(signed, v, r, s);
    }

    function getMessageHash(
        bytes32 digestHash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode("\x19Ethereum Signed Message:\n32", digestHash)
            );
    }

    function getMessageHashPacked(
        bytes32 digestHash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", digestHash)
            );
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }
}


