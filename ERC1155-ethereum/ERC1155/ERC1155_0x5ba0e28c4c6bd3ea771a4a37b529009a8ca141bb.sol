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


// File: @openzeppelin/contracts/interfaces/IERC2981.sol
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


// File: @openzeppelin/contracts/token/common/ERC2981.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/common/ERC2981.sol)

pragma solidity ^0.8.0;

import "../../interfaces/IERC2981.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the NFT Royalty Standard, a standardized way to retrieve royalty payment information.
 *
 * Royalty information can be specified globally for all token ids via {_setDefaultRoyalty}, and/or individually for
 * specific token ids via {_setTokenRoyalty}. The latter takes precedence over the first.
 *
 * Royalty is specified as a fraction of sale price. {_feeDenominator} is overridable but defaults to 10000, meaning the
 * fee is specified in basis points by default.
 *
 * IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its payment. See
 * https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the EIP. Marketplaces are expected to
 * voluntarily pay royalties together with sales, but note that this standard is not yet widely supported.
 *
 * _Available since v4.5._
 */
abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view virtual override returns (address, uint256) {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    /**
     * @dev The denominator with which to interpret the fee set in {_setTokenRoyalty} and {_setDefaultRoyalty} as a
     * fraction of the sale price. Defaults to 10000 so fees are expressed in basis points, but may be customized by an
     * override.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Removes default royalty information.
     */
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Resets royalty information for the token id back to the global default.
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
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


// File: @openzeppelin/contracts/utils/math/Math.sol
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


// File: @openzeppelin/contracts/utils/Strings.sol
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


// File: contracts/common/OperatorFilterer.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice Optimized and flexible operator filterer to abide to OpenSea's
/// mandatory on-chain royalty enforcement in order for new collections to
/// receive royalties.
/// For more information, see:
/// See: https://github.com/ProjectOpenSea/operator-filter-registry
abstract contract OperatorFilterer {
    /// @dev The default OpenSea operator blocklist subscription.
    address internal constant _DEFAULT_SUBSCRIPTION =
        0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6;

    /// @dev The OpenSea operator filter registry.
    address internal constant _OPERATOR_FILTER_REGISTRY =
        0x000000000000AAeB6D7670E522A718067333cd4E;

    /// @dev Registers the current contract to OpenSea's operator filter,
    /// and subscribe to the default OpenSea operator blocklist.
    /// Note: Will not revert nor update existing settings for repeated registration.
    function _registerForOperatorFiltering() internal virtual {
        _registerForOperatorFiltering(_DEFAULT_SUBSCRIPTION, true);
    }

    /// @dev Registers the current contract to OpenSea's operator filter.
    /// Note: Will not revert nor update existing settings for repeated registration.
    function _registerForOperatorFiltering(
        address subscriptionOrRegistrantToCopy,
        bool subscribe
    ) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            let functionSelector := 0x7d3e3dbe // `registerAndSubscribe(address,address)`.

            // Clean the upper 96 bits of `subscriptionOrRegistrantToCopy` in case they are dirty.
            subscriptionOrRegistrantToCopy := shr(
                96,
                shl(96, subscriptionOrRegistrantToCopy)
            )

            for {

            } iszero(subscribe) {

            } {
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
            if iszero(
                call(
                    gas(),
                    _OPERATOR_FILTER_REGISTRY,
                    0,
                    0x00,
                    0x44,
                    0x00,
                    0x04
                )
            ) {
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
            if iszero(
                staticcall(
                    gas(),
                    _OPERATOR_FILTER_REGISTRY,
                    0x16,
                    0x44,
                    0x00,
                    0x00
                )
            ) {
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


// File: contracts/PlagueSupportsZachXBT.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC2981, ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ERC1155} from "solady/src/tokens/ERC1155.sol";
import {OperatorFilterer} from "./common/OperatorFilterer.sol";

/**
 * @title PlagueSupportsZachXBT
 * @custom:website www.plaguebrands.io/zachxbt
 * @author @ThePlagueNFT
 * @notice READ MORE - https://twitter.com/zachxbt/status/1669783717236342785
 *         1% of funds go to the artist, 99% goes to zachxbt directly.
 *         100% of royalties will also go to zachxbt
 * @dev Shoutout to vectorized.eth / @optimizoor / https://twitter.com/optimizoor
 *
 * \____    /____    ____ |  |__ \   \/  /\______   \__    ___/
 *   /     /\__  \ _/ ___\|  |  \ \     /  |    |  _/ |    |
 *  /     /_ / __ \\  \___|   Y  \/     \  |    |   \ |    |
 * /_______ (____  /\___  >___|  /___/\  \ |______  / |____|
 *         \/    \/     \/     \/      \_/        \/
 *
 */
contract PlagueSupportsZachXBT is ERC1155, OperatorFilterer, Ownable, ERC2981 {
    using Strings for uint256;

    uint256 private constant ONE_PERCENT = 10000000000000000;
    address private constant FALLBACK_DEPLOYER =
        0xeA9B1Ed511632e48dDD3E5A231cd2f5F3A3a4a9b;

    address public artistAddress;
    address public zachXBTAddress;
    bool public operatorFilteringEnabled;
    uint256 public price;
    bool public isMintOpen;
    string public baseURI = "";

    constructor() ERC1155() {
        _registerForOperatorFiltering();
        operatorFilteringEnabled = true;
        _setDefaultRoyalty(msg.sender, 500);
        price = 0.005 ether;
        isMintOpen = false;
    }

    /**
     * @dev Open edition mint, specify amount and payable ether
     * @param _amount The amount to mint
     */
    function mint(uint256 _amount) external payable {
        require(isMintOpen, "Mint is not active.");
        require(msg.value >= _amount * price, "Not enough funds.");
        _mint(msg.sender, 1, _amount, "");
    }

    function uri(uint256 id) public view override returns (string memory) {
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, id.toString(), ".json"))
                : "";
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes calldata data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public override onlyAllowedOperator(from) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC2981) returns (bool) {
        // Supports the following `interfaceId`s:
        // - IERC165: 0x01ffc9a7
        // - IERC1155: 0xd9b67a26
        // - IERC1155MetadataURI: 0x0e89341c
        // - IERC2981: 0x2a55205a
        return
            ERC1155.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) public onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function setOperatorFilteringEnabled(bool value) public onlyOwner {
        operatorFilteringEnabled = value;
    }

    function _operatorFilteringEnabled() internal view override returns (bool) {
        return operatorFilteringEnabled;
    }

    function _isPriorityOperator(
        address operator
    ) internal pure override returns (bool) {
        // OpenSea Seaport Conduit:
        // https://etherscan.io/address/0x1E0049783F008A0085193E00003D00cd54003c71
        // https://goerli.etherscan.io/address/0x1E0049783F008A0085193E00003D00cd54003c71
        return operator == address(0x1E0049783F008A0085193E00003D00cd54003c71);
    }

    /**
     * @notice Sets the mint open
     * @param _isMintOpen state of mint openness
     */
    function setMintIsOpen(bool _isMintOpen) public onlyOwner {
        isMintOpen = _isMintOpen;
    }

    /**
     * @notice Sets the price
     * @param _price price in wei
     */
    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    /**
     * @notice Sets base uri
     * @param _baseURI The uri of asset
     */
    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @notice Sets the withdraw wallets
     * @param artist - Artist address
     * @param zachxbt - ZachXBTs address
     */
    function setWithdrawWallets(
        address artist,
        address zachxbt
    ) public onlyOwner {
        artistAddress = artist;
        zachXBTAddress = zachxbt;
    }

    /// @notice Withdraw funds from contract to artist and zachxbt directly
    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool s1, ) = payable(artistAddress).call{value: amount * ONE_PERCENT}(
            ""
        );
        (bool s2, ) = payable(zachXBTAddress).call{
            value: amount * (ONE_PERCENT * 99)
        }("");
        if (s1 && s2) return;
        // fallback
        (bool s3, ) = payable(FALLBACK_DEPLOYER).call{value: amount}("");
        require(s3, "Payment failed");
    }
}


// File: solady/src/tokens/ERC1155.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple ERC1155 implementation.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/tokens/ERC1155.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts/token/ERC1155/ERC1155.sol)
/// Note:
/// The ERC1155 standard allows for self-approvals.
/// For performance, this implementation WILL NOT revert for such actions.
/// Please add any checks with overrides if desired.
abstract contract ERC1155 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The lengths of the input arrays are not the same.
    error ArrayLengthsMismatch();

    /// @dev Cannot mint or transfer to the zero address.
    error TransferToZeroAddress();

    /// @dev The recipient's balance has overflowed.
    error AccountBalanceOverflow();

    /// @dev Insufficient balance.
    error InsufficientBalance();

    /// @dev Only the token owner or an approved account can manage the tokens.
    error NotOwnerNorApproved();

    /// @dev Cannot safely transfer to a contract that does not implement
    /// the ERC1155Receiver interface.
    error TransferToNonERC1155ReceiverImplementer();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Emitted when `amount` of token `id` is transferred
    /// from `from` to `to` by `operator`.
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    /// @dev Emitted when `amounts` of token `ids` are transferred
    /// from `from` to `to` by `operator`.
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    /// @dev Emitted when `owner` enables or disables `operator` to manage all of their tokens.
    event ApprovalForAll(address indexed owner, address indexed operator, bool isApproved);

    /// @dev Emitted when the Uniform Resource Identifier (URI) for token `id`
    /// is updated to `value`. This event is not used in the base contract.
    /// You may need to emit this event depending on your URI logic.
    ///
    /// See: https://eips.ethereum.org/EIPS/eip-1155#metadata
    event URI(string value, uint256 indexed id);

    /// @dev `keccak256(bytes("TransferSingle(address,address,address,uint256,uint256)"))`.
    uint256 private constant _TRANSFER_SINGLE_EVENT_SIGNATURE =
        0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62;

    /// @dev `keccak256(bytes("TransferBatch(address,address,address,uint256[],uint256[])"))`.
    uint256 private constant _TRANSFER_BATCH_EVENT_SIGNATURE =
        0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb;

    /// @dev `keccak256(bytes("ApprovalForAll(address,address,bool)"))`.
    uint256 private constant _APPROVAL_FOR_ALL_EVENT_SIGNATURE =
        0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The `ownerSlotSeed` of a given owner is given by.
    /// ```
    ///     let ownerSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, owner))
    /// ```
    ///
    /// The balance slot of `owner` is given by.
    /// ```
    ///     mstore(0x20, ownerSlotSeed)
    ///     mstore(0x00, id)
    ///     let balanceSlot := keccak256(0x00, 0x40)
    /// ```
    ///
    /// The operator approval slot of `owner` is given by.
    /// ```
    ///     mstore(0x20, ownerSlotSeed)
    ///     mstore(0x00, operator)
    ///     let operatorApprovalSlot := keccak256(0x0c, 0x34)
    /// ```
    uint256 private constant _ERC1155_MASTER_SLOT_SEED = 0x9a31110384e0b0c9;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC1155 METADATA                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the URI for token `id`.
    ///
    /// You can either return the same templated URI for all token IDs,
    /// (e.g. "https://example.com/api/{id}.json"),
    /// or return a unique URI for each `id`.
    ///
    /// See: https://eips.ethereum.org/EIPS/eip-1155#metadata
    function uri(uint256 id) public view virtual returns (string memory);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          ERC1155                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the amount of `id` owned by `owner`.
    function balanceOf(address owner, uint256 id) public view virtual returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, _ERC1155_MASTER_SLOT_SEED)
            mstore(0x14, owner)
            mstore(0x00, id)
            result := sload(keccak256(0x00, 0x40))
        }
    }

    /// @dev Returns whether `operator` is approved to manage the tokens of `owner`.
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, _ERC1155_MASTER_SLOT_SEED)
            mstore(0x14, owner)
            mstore(0x00, operator)
            result := sload(keccak256(0x0c, 0x34))
        }
    }

    /// @dev Sets whether `operator` is approved to manage the tokens of the caller.
    ///
    /// Emits a {ApprovalForAll} event.
    function setApprovalForAll(address operator, bool isApproved) public virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Convert to 0 or 1.
            isApproved := iszero(iszero(isApproved))
            // Update the `isApproved` for (`msg.sender`, `operator`).
            mstore(0x20, _ERC1155_MASTER_SLOT_SEED)
            mstore(0x14, caller())
            mstore(0x00, operator)
            sstore(keccak256(0x0c, 0x34), isApproved)
            // Emit the {ApprovalForAll} event.
            mstore(0x00, isApproved)
            // forgefmt: disable-next-line
            log3(0x00, 0x20, _APPROVAL_FOR_ALL_EVENT_SIGNATURE, caller(), shr(96, shl(96, operator)))
        }
    }

    /// @dev Transfers `amount` of `id` from `from` to `to`.
    ///
    /// Requirements:
    /// - `to` cannot be the zero address.
    /// - `from` must have at least `amount` of `id`.
    /// - If the caller is not `from`,
    ///   it must be approved to manage the tokens of `from`.
    /// - If `to` refers to a smart contract, it must implement
    ///   {ERC1155-onERC1155Reveived}, which is called upon a batch transfer.
    ///
    /// Emits a {Transfer} event.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, to, _single(id), _single(amount), data);
        }
        /// @solidity memory-safe-assembly
        assembly {
            let fromSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, from))
            let toSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, to))
            mstore(0x20, fromSlotSeed)
            // Clear the upper 96 bits.
            from := shr(96, fromSlotSeed)
            to := shr(96, toSlotSeed)
            // Revert if `to` is the zero address.
            if iszero(to) {
                mstore(0x00, 0xea553b34) // `TransferToZeroAddress()`.
                revert(0x1c, 0x04)
            }
            // If the caller is not `from`, do the authorization check.
            if iszero(eq(caller(), from)) {
                mstore(0x00, caller())
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) // `NotOwnerNorApproved()`.
                    revert(0x1c, 0x04)
                }
            }
            // Subtract and store the updated balance of `from`.
            {
                mstore(0x00, id)
                let fromBalanceSlot := keccak256(0x00, 0x40)
                let fromBalance := sload(fromBalanceSlot)
                if gt(amount, fromBalance) {
                    mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                    revert(0x1c, 0x04)
                }
                sstore(fromBalanceSlot, sub(fromBalance, amount))
            }
            // Increase and store the updated balance of `to`.
            {
                mstore(0x20, toSlotSeed)
                let toBalanceSlot := keccak256(0x00, 0x40)
                let toBalanceBefore := sload(toBalanceSlot)
                let toBalanceAfter := add(toBalanceBefore, amount)
                if lt(toBalanceAfter, toBalanceBefore) {
                    mstore(0x00, 0x01336cea) // `AccountBalanceOverflow()`.
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalanceAfter)
            }
            // Emit a {TransferSingle} event.
            mstore(0x20, amount)
            log4(0x00, 0x40, _TRANSFER_SINGLE_EVENT_SIGNATURE, caller(), from, to)
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, to, _single(id), _single(amount), data);
        }
        /// @solidity memory-safe-assembly
        assembly {
            // Do the {onERC1155Received} check if `to` is a smart contract.
            if extcodesize(to) {
                // Prepare the calldata.
                let m := mload(0x40)
                // `onERC1155Received(address,address,uint256,uint256,bytes)`.
                mstore(m, 0xf23a6e61)
                mstore(add(m, 0x20), caller())
                mstore(add(m, 0x40), from)
                mstore(add(m, 0x60), id)
                mstore(add(m, 0x80), amount)
                mstore(add(m, 0xa0), 0xa0)
                calldatacopy(add(m, 0xc0), sub(data.offset, 0x20), add(0x20, data.length))
                // Revert if the call reverts.
                if iszero(call(gas(), to, 0, add(m, 0x1c), add(0xc4, data.length), m, 0x20)) {
                    if returndatasize() {
                        // Bubble up the revert if the call reverts.
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                    mstore(m, 0)
                }
                // Load the returndata and compare it with the function selector.
                if iszero(eq(mload(m), shl(224, 0xf23a6e61))) {
                    mstore(0x00, 0x9c05499b) // `TransferToNonERC1155ReceiverImplementer()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /// @dev Transfers `amounts` of `ids` from `from` to `to`.
    ///
    /// Requirements:
    /// - `to` cannot be the zero address.
    /// - `from` must have at least `amount` of `id`.
    /// - `ids` and `amounts` must have the same length.
    /// - If the caller is not `from`,
    ///   it must be approved to manage the tokens of `from`.
    /// - If `to` refers to a smart contract, it must implement
    ///   {ERC1155-onERC1155BatchReveived}, which is called upon a batch transfer.
    ///
    /// Emits a {TransferBatch} event.
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, to, ids, amounts, data);
        }
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(eq(ids.length, amounts.length)) {
                mstore(0x00, 0x3b800a46) // `ArrayLengthsMismatch()`.
                revert(0x1c, 0x04)
            }
            let fromSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, from))
            let toSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, to))
            mstore(0x20, fromSlotSeed)
            // Clear the upper 96 bits.
            from := shr(96, fromSlotSeed)
            to := shr(96, toSlotSeed)
            // Revert if `to` is the zero address.
            if iszero(to) {
                mstore(0x00, 0xea553b34) // `TransferToZeroAddress()`.
                revert(0x1c, 0x04)
            }
            // If the caller is not `from`, do the authorization check.
            if iszero(eq(caller(), from)) {
                mstore(0x00, caller())
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) // `NotOwnerNorApproved()`.
                    revert(0x1c, 0x04)
                }
            }
            // Loop through all the `ids` and update the balances.
            {
                let end := shl(5, ids.length)
                for { let i := 0 } iszero(eq(i, end)) { i := add(i, 0x20) } {
                    let amount := calldataload(add(amounts.offset, i))
                    // Subtract and store the updated balance of `from`.
                    {
                        mstore(0x20, fromSlotSeed)
                        mstore(0x00, calldataload(add(ids.offset, i)))
                        let fromBalanceSlot := keccak256(0x00, 0x40)
                        let fromBalance := sload(fromBalanceSlot)
                        if gt(amount, fromBalance) {
                            mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                            revert(0x1c, 0x04)
                        }
                        sstore(fromBalanceSlot, sub(fromBalance, amount))
                    }
                    // Increase and store the updated balance of `to`.
                    {
                        mstore(0x20, toSlotSeed)
                        let toBalanceSlot := keccak256(0x00, 0x40)
                        let toBalanceBefore := sload(toBalanceSlot)
                        let toBalanceAfter := add(toBalanceBefore, amount)
                        if lt(toBalanceAfter, toBalanceBefore) {
                            mstore(0x00, 0x01336cea) // `AccountBalanceOverflow()`.
                            revert(0x1c, 0x04)
                        }
                        sstore(toBalanceSlot, toBalanceAfter)
                    }
                }
            }
            // Emit a {TransferBatch} event.
            {
                let m := mload(0x40)
                // Copy the `ids`.
                mstore(m, 0x40)
                let n := add(0x20, shl(5, ids.length))
                let o := add(m, 0x40)
                calldatacopy(o, sub(ids.offset, 0x20), n)
                // Copy the `amounts`.
                mstore(add(m, 0x20), add(0x40, n))
                o := add(o, n)
                n := add(0x20, shl(5, amounts.length))
                calldatacopy(o, sub(amounts.offset, 0x20), n)
                n := sub(add(o, n), m)
                // Do the emit.
                log4(m, n, _TRANSFER_BATCH_EVENT_SIGNATURE, caller(), from, to)
            }
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransferCalldata(from, to, ids, amounts, data);
        }
        /// @solidity memory-safe-assembly
        assembly {
            // Do the {onERC1155BatchReceived} check if `to` is a smart contract.
            if extcodesize(to) {
                let m := mload(0x40)
                // Prepare the calldata.
                // `onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)`.
                mstore(m, 0xbc197c81)
                mstore(add(m, 0x20), caller())
                mstore(add(m, 0x40), from)
                // Copy the `ids`.
                mstore(add(m, 0x60), 0xa0)
                let n := add(0x20, shl(5, ids.length))
                let o := add(m, 0xc0)
                calldatacopy(o, sub(ids.offset, 0x20), n)
                // Copy the `amounts`.
                let s := add(0xa0, n)
                mstore(add(m, 0x80), s)
                o := add(o, n)
                n := add(0x20, shl(5, amounts.length))
                calldatacopy(o, sub(amounts.offset, 0x20), n)
                // Copy the `data`.
                mstore(add(m, 0xa0), add(s, n))
                o := add(o, n)
                n := add(0x20, data.length)
                calldatacopy(o, sub(data.offset, 0x20), n)
                n := sub(add(o, n), add(m, 0x1c))
                // Revert if the call reverts.
                if iszero(call(gas(), to, 0, add(m, 0x1c), n, m, 0x20)) {
                    if returndatasize() {
                        // Bubble up the revert if the call reverts.
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                    mstore(m, 0)
                }
                // Load the returndata and compare it with the function selector.
                if iszero(eq(mload(m), shl(224, 0xbc197c81))) {
                    mstore(0x00, 0x9c05499b) // `TransferToNonERC1155ReceiverImplementer()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /// @dev Returns the amounts of `ids` for `owners.
    ///
    /// Requirements:
    /// - `owners` and `ids` must have the same length.
    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(eq(ids.length, owners.length)) {
                mstore(0x00, 0x3b800a46) // `ArrayLengthsMismatch()`.
                revert(0x1c, 0x04)
            }
            balances := mload(0x40)
            mstore(balances, ids.length)
            let o := add(balances, 0x20)
            let end := shl(5, ids.length)
            mstore(0x40, add(end, o))
            // Loop through all the `ids` and load the balances.
            for { let i := 0 } iszero(eq(i, end)) { i := add(i, 0x20) } {
                let owner := calldataload(add(owners.offset, i))
                mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, shl(96, owner)))
                mstore(0x00, calldataload(add(ids.offset, i)))
                mstore(add(o, i), sload(keccak256(0x00, 0x40)))
            }
        }
    }

    /// @dev Returns true if this contract implements the interface defined by `interfaceId`.
    /// See: https://eips.ethereum.org/EIPS/eip-165
    /// This function call must use less than 30000 gas.
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let s := shr(224, interfaceId)
            // ERC165: 0x01ffc9a7, ERC1155: 0xd9b67a26, ERC1155MetadataURI: 0x0e89341c.
            result := or(or(eq(s, 0x01ffc9a7), eq(s, 0xd9b67a26)), eq(s, 0x0e89341c))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  INTERNAL MINT FUNCTIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Mints `amount` of `id` to `to`.
    ///
    /// Requirements:
    /// - `to` cannot be the zero address.
    /// - If `to` refers to a smart contract, it must implement
    ///   {ERC1155-onERC1155Reveived}, which is called upon a batch transfer.
    ///
    /// Emits a {Transfer} event.
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(address(0), to, _single(id), _single(amount), data);
        }
        /// @solidity memory-safe-assembly
        assembly {
            let to_ := shl(96, to)
            // Revert if `to` is the zero address.
            if iszero(to_) {
                mstore(0x00, 0xea553b34) // `TransferToZeroAddress()`.
                revert(0x1c, 0x04)
            }
            // Increase and store the updated balance of `to`.
            {
                mstore(0x20, _ERC1155_MASTER_SLOT_SEED)
                mstore(0x14, to)
                mstore(0x00, id)
                let toBalanceSlot := keccak256(0x00, 0x40)
                let toBalanceBefore := sload(toBalanceSlot)
                let toBalanceAfter := add(toBalanceBefore, amount)
                if lt(toBalanceAfter, toBalanceBefore) {
                    mstore(0x00, 0x01336cea) // `AccountBalanceOverflow()`.
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalanceAfter)
            }
            // Emit a {TransferSingle} event.
            mstore(0x00, id)
            mstore(0x20, amount)
            log4(0x00, 0x40, _TRANSFER_SINGLE_EVENT_SIGNATURE, caller(), 0, shr(96, to_))
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(address(0), to, _single(id), _single(amount), data);
        }
        if (_hasCode(to)) _checkOnERC1155Received(address(0), to, id, amount, data);
    }

    /// @dev Mints `amounts` of `ids` to `to`.
    ///
    /// Requirements:
    /// - `to` cannot be the zero address.
    /// - `ids` and `amounts` must have the same length.
    /// - If `to` refers to a smart contract, it must implement
    ///   {ERC1155-onERC1155BatchReveived}, which is called upon a batch transfer.
    ///
    /// Emits a {TransferBatch} event.
    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(address(0), to, ids, amounts, data);
        }
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(eq(mload(ids), mload(amounts))) {
                mstore(0x00, 0x3b800a46) // `ArrayLengthsMismatch()`.
                revert(0x1c, 0x04)
            }
            let to_ := shl(96, to)
            // Revert if `to` is the zero address.
            if iszero(to_) {
                mstore(0x00, 0xea553b34) // `TransferToZeroAddress()`.
                revert(0x1c, 0x04)
            }
            // Loop through all the `ids` and update the balances.
            {
                mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, to_))
                let end := shl(5, mload(ids))
                for { let i := 0 } iszero(eq(i, end)) {} {
                    i := add(i, 0x20)
                    let amount := mload(add(amounts, i))
                    // Increase and store the updated balance of `to`.
                    {
                        mstore(0x00, mload(add(ids, i)))
                        let toBalanceSlot := keccak256(0x00, 0x40)
                        let toBalanceBefore := sload(toBalanceSlot)
                        let toBalanceAfter := add(toBalanceBefore, amount)
                        if lt(toBalanceAfter, toBalanceBefore) {
                            mstore(0x00, 0x01336cea) // `AccountBalanceOverflow()`.
                            revert(0x1c, 0x04)
                        }
                        sstore(toBalanceSlot, toBalanceAfter)
                    }
                }
            }
            // Emit a {TransferBatch} event.
            {
                let m := mload(0x40)
                // Copy the `ids`.
                mstore(m, 0x40)
                let n := add(0x20, shl(5, mload(ids)))
                let o := add(m, 0x40)
                pop(staticcall(gas(), 4, ids, n, o, n))
                // Copy the `amounts`.
                mstore(add(m, 0x20), add(0x40, returndatasize()))
                o := add(o, returndatasize())
                n := add(0x20, shl(5, mload(amounts)))
                pop(staticcall(gas(), 4, amounts, n, o, n))
                n := sub(add(o, returndatasize()), m)
                // Do the emit.
                log4(m, n, _TRANSFER_BATCH_EVENT_SIGNATURE, caller(), 0, shr(96, to_))
            }
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(address(0), to, ids, amounts, data);
        }
        if (_hasCode(to)) _checkOnERC1155BatchReceived(address(0), to, ids, amounts, data);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  INTERNAL BURN FUNCTIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to `_burn(address(0), from, id, amount)`.
    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        _burn(address(0), from, id, amount);
    }

    /// @dev Destroys `amount` of `id` from `from`.
    ///
    /// Requirements:
    /// - `from` must have at least `amount` of `id`.
    /// - If `by` is not the zero address, it must be either `from`,
    ///   or approved to manage the tokens of `from`.
    ///
    /// Emits a {Transfer} event.
    function _burn(address by, address from, uint256 id, uint256 amount) internal virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, address(0), _single(id), _single(amount), "");
        }
        /// @solidity memory-safe-assembly
        assembly {
            let from_ := shl(96, from)
            mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, from_))
            // If `by` is not the zero address, and not equal to `from`,
            // check if it is approved to manage all the tokens of `from`.
            if iszero(or(iszero(shl(96, by)), eq(shl(96, by), from_))) {
                mstore(0x00, by)
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) // `NotOwnerNorApproved()`.
                    revert(0x1c, 0x04)
                }
            }
            // Decrease and store the updated balance of `from`.
            {
                mstore(0x00, id)
                let fromBalanceSlot := keccak256(0x00, 0x40)
                let fromBalance := sload(fromBalanceSlot)
                if gt(amount, fromBalance) {
                    mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                    revert(0x1c, 0x04)
                }
                sstore(fromBalanceSlot, sub(fromBalance, amount))
            }
            // Emit a {TransferSingle} event.
            mstore(0x00, id)
            mstore(0x20, amount)
            log4(0x00, 0x40, _TRANSFER_SINGLE_EVENT_SIGNATURE, caller(), shr(96, from_), 0)
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, address(0), _single(id), _single(amount), "");
        }
    }

    /// @dev Equivalent to `_batchBurn(address(0), from, ids, amounts)`.
    function _batchBurn(address from, uint256[] memory ids, uint256[] memory amounts)
        internal
        virtual
    {
        _batchBurn(address(0), from, ids, amounts);
    }

    /// @dev Destroys `amounts` of `ids` from `from`.
    ///
    /// Requirements:
    /// - `ids` and `amounts` must have the same length.
    /// - `from` must have at least `amounts` of `ids`.
    /// - If `by` is not the zero address, it must be either `from`,
    ///   or approved to manage the tokens of `from`.
    ///
    /// Emits a {TransferBatch} event.
    function _batchBurn(address by, address from, uint256[] memory ids, uint256[] memory amounts)
        internal
        virtual
    {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, address(0), ids, amounts, "");
        }
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(eq(mload(ids), mload(amounts))) {
                mstore(0x00, 0x3b800a46) // `ArrayLengthsMismatch()`.
                revert(0x1c, 0x04)
            }
            let from_ := shl(96, from)
            mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, from_))
            // If `by` is not the zero address, and not equal to `from`,
            // check if it is approved to manage all the tokens of `from`.
            let by_ := shl(96, by)
            if iszero(or(iszero(by_), eq(by_, from_))) {
                mstore(0x00, by)
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) // `NotOwnerNorApproved()`.
                    revert(0x1c, 0x04)
                }
            }
            // Loop through all the `ids` and update the balances.
            {
                let end := shl(5, mload(ids))
                for { let i := 0 } iszero(eq(i, end)) {} {
                    i := add(i, 0x20)
                    let amount := mload(add(amounts, i))
                    // Decrease and store the updated balance of `to`.
                    {
                        mstore(0x00, mload(add(ids, i)))
                        let fromBalanceSlot := keccak256(0x00, 0x40)
                        let fromBalance := sload(fromBalanceSlot)
                        if gt(amount, fromBalance) {
                            mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                            revert(0x1c, 0x04)
                        }
                        sstore(fromBalanceSlot, sub(fromBalance, amount))
                    }
                }
            }
            // Emit a {TransferBatch} event.
            {
                let m := mload(0x40)
                // Copy the `ids`.
                mstore(m, 0x40)
                let n := add(0x20, shl(5, mload(ids)))
                let o := add(m, 0x40)
                pop(staticcall(gas(), 4, ids, n, o, n))
                // Copy the `amounts`.
                mstore(add(m, 0x20), add(0x40, returndatasize()))
                o := add(o, returndatasize())
                n := add(0x20, shl(5, mload(amounts)))
                pop(staticcall(gas(), 4, amounts, n, o, n))
                n := sub(add(o, returndatasize()), m)
                // Do the emit.
                log4(m, n, _TRANSFER_BATCH_EVENT_SIGNATURE, caller(), shr(96, from_), 0)
            }
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, address(0), ids, amounts, "");
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                INTERNAL APPROVAL FUNCTIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Approve or remove the `operator` as an operator for `by`,
    /// without authorization checks.
    ///
    /// Emits a {ApprovalForAll} event.
    function _setApprovalForAll(address by, address operator, bool isApproved) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Convert to 0 or 1.
            isApproved := iszero(iszero(isApproved))
            // Update the `isApproved` for (`by`, `operator`).
            mstore(0x20, _ERC1155_MASTER_SLOT_SEED)
            mstore(0x14, by)
            mstore(0x00, operator)
            sstore(keccak256(0x0c, 0x34), isApproved)
            // Emit the {ApprovalForAll} event.
            mstore(0x00, isApproved)
            let m := shr(96, not(0))
            log3(0x00, 0x20, _APPROVAL_FOR_ALL_EVENT_SIGNATURE, and(m, by), and(m, operator))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                INTERNAL TRANSFER FUNCTIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to `_safeTransfer(address(0), from, to, id, amount, data)`.
    function _safeTransfer(address from, address to, uint256 id, uint256 amount, bytes memory data)
        internal
        virtual
    {
        _safeTransfer(address(0), from, to, id, amount, data);
    }

    /// @dev Transfers `amount` of `id` from `from` to `to`.
    ///
    /// Requirements:
    /// - `to` cannot be the zero address.
    /// - `from` must have at least `amount` of `id`.
    /// - If `by` is not the zero address, it must be either `from`,
    ///   or approved to manage the tokens of `from`.
    /// - If `to` refers to a smart contract, it must implement
    ///   {ERC1155-onERC1155Reveived}, which is called upon a batch transfer.
    ///
    /// Emits a {Transfer} event.
    function _safeTransfer(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, to, _single(id), _single(amount), data);
        }
        /// @solidity memory-safe-assembly
        assembly {
            let from_ := shl(96, from)
            let to_ := shl(96, to)
            // Revert if `to` is the zero address.
            if iszero(to_) {
                mstore(0x00, 0xea553b34) // `TransferToZeroAddress()`.
                revert(0x1c, 0x04)
            }
            mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, from_))
            // If `by` is not the zero address, and not equal to `from`,
            // check if it is approved to manage all the tokens of `from`.
            let by_ := shl(96, by)
            if iszero(or(iszero(by_), eq(by_, from_))) {
                mstore(0x00, by)
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) // `NotOwnerNorApproved()`.
                    revert(0x1c, 0x04)
                }
            }
            // Subtract and store the updated balance of `from`.
            {
                mstore(0x00, id)
                let fromBalanceSlot := keccak256(0x00, 0x40)
                let fromBalance := sload(fromBalanceSlot)
                if gt(amount, fromBalance) {
                    mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                    revert(0x1c, 0x04)
                }
                sstore(fromBalanceSlot, sub(fromBalance, amount))
            }
            // Increase and store the updated balance of `to`.
            {
                mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, to_))
                let toBalanceSlot := keccak256(0x00, 0x40)
                let toBalanceBefore := sload(toBalanceSlot)
                let toBalanceAfter := add(toBalanceBefore, amount)
                if lt(toBalanceAfter, toBalanceBefore) {
                    mstore(0x00, 0x01336cea) // `AccountBalanceOverflow()`.
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalanceAfter)
            }
            // Emit a {TransferSingle} event.
            mstore(0x20, amount)
            // forgefmt: disable-next-line
            log4(0x00, 0x40, _TRANSFER_SINGLE_EVENT_SIGNATURE, caller(), shr(96, from_), shr(96, to_))
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, to, _single(id), _single(amount), data);
        }
        if (_hasCode(to)) _checkOnERC1155Received(from, to, id, amount, data);
    }

    /// @dev Equivalent to `_safeBatchTransfer(address(0), from, to, ids, amounts, data)`.
    function _safeBatchTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        _safeBatchTransfer(address(0), from, to, ids, amounts, data);
    }

    /// @dev Transfers `amounts` of `ids` from `from` to `to`.
    ///
    /// Requirements:
    /// - `to` cannot be the zero address.
    /// - `ids` and `amounts` must have the same length.
    /// - `from` must have at least `amounts` of `ids`.
    /// - If `by` is not the zero address, it must be either `from`,
    ///   or approved to manage the tokens of `from`.
    /// - If `to` refers to a smart contract, it must implement
    ///   {ERC1155-onERC1155BatchReveived}, which is called upon a batch transfer.
    ///
    /// Emits a {TransferBatch} event.
    function _safeBatchTransfer(
        address by,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, to, ids, amounts, data);
        }
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(eq(mload(ids), mload(amounts))) {
                mstore(0x00, 0x3b800a46) // `ArrayLengthsMismatch()`.
                revert(0x1c, 0x04)
            }
            let from_ := shl(96, from)
            let to_ := shl(96, to)
            // Revert if `to` is the zero address.
            if iszero(to_) {
                mstore(0x00, 0xea553b34) // `TransferToZeroAddress()`.
                revert(0x1c, 0x04)
            }
            let fromSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, from_)
            let toSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, to_)
            mstore(0x20, fromSlotSeed)
            // If `by` is not the zero address, and not equal to `from`,
            // check if it is approved to manage all the tokens of `from`.
            let by_ := shl(96, by)
            if iszero(or(iszero(by_), eq(by_, from_))) {
                mstore(0x00, by)
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) // `NotOwnerNorApproved()`.
                    revert(0x1c, 0x04)
                }
            }
            // Loop through all the `ids` and update the balances.
            {
                let end := shl(5, mload(ids))
                for { let i := 0 } iszero(eq(i, end)) {} {
                    i := add(i, 0x20)
                    let amount := mload(add(amounts, i))
                    // Subtract and store the updated balance of `from`.
                    {
                        mstore(0x20, fromSlotSeed)
                        mstore(0x00, mload(add(ids, i)))
                        let fromBalanceSlot := keccak256(0x00, 0x40)
                        let fromBalance := sload(fromBalanceSlot)
                        if gt(amount, fromBalance) {
                            mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                            revert(0x1c, 0x04)
                        }
                        sstore(fromBalanceSlot, sub(fromBalance, amount))
                    }
                    // Increase and store the updated balance of `to`.
                    {
                        mstore(0x20, toSlotSeed)
                        let toBalanceSlot := keccak256(0x00, 0x40)
                        let toBalanceBefore := sload(toBalanceSlot)
                        let toBalanceAfter := add(toBalanceBefore, amount)
                        if lt(toBalanceAfter, toBalanceBefore) {
                            mstore(0x00, 0x01336cea) // `AccountBalanceOverflow()`.
                            revert(0x1c, 0x04)
                        }
                        sstore(toBalanceSlot, toBalanceAfter)
                    }
                }
            }
            // Emit a {TransferBatch} event.
            {
                let m := mload(0x40)
                // Copy the `ids`.
                mstore(m, 0x40)
                let n := add(0x20, shl(5, mload(ids)))
                let o := add(m, 0x40)
                pop(staticcall(gas(), 4, ids, n, o, n))
                // Copy the `amounts`.
                mstore(add(m, 0x20), add(0x40, returndatasize()))
                o := add(o, returndatasize())
                n := add(0x20, shl(5, mload(amounts)))
                pop(staticcall(gas(), 4, amounts, n, o, n))
                n := sub(add(o, returndatasize()), m)
                // Do the emit.
                log4(m, n, _TRANSFER_BATCH_EVENT_SIGNATURE, caller(), shr(96, from_), shr(96, to_))
            }
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, to, ids, amounts, data);
        }
        if (_hasCode(to)) _checkOnERC1155BatchReceived(from, to, ids, amounts, data);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    HOOKS FOR OVERRIDING                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Override this function to return true if `_beforeTokenTransfer` is used.
    /// The is to help the compiler avoid producing dead bytecode.
    function _useBeforeTokenTransfer() internal view virtual returns (bool) {
        return false;
    }

    /// @dev Hook that is called before any token transfer.
    /// This includes minting and burning, as well as batched variants.
    ///
    /// The same hook is called on both single and batched variants.
    /// For single transfers, the length of the `id` and `amount` arrays are 1.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    /// @dev Override this function to return true if `_afterTokenTransfer` is used.
    /// The is to help the compiler avoid producing dead bytecode.
    function _useAfterTokenTransfer() internal view virtual returns (bool) {
        return false;
    }

    /// @dev Hook that is called after any token transfer.
    /// This includes minting and burning, as well as batched variants.
    ///
    /// The same hook is called on both single and batched variants.
    /// For single transfers, the length of the `id` and `amount` arrays are 1.
    function _afterTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Helper for calling the `_afterTokenTransfer` hook.
    /// The is to help the compiler avoid producing dead bytecode.
    function _afterTokenTransferCalldata(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) private {
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, to, ids, amounts, data);
        }
    }

    /// @dev Returns if `a` has bytecode of non-zero length.
    function _hasCode(address a) private view returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := extcodesize(a) // Can handle dirty upper bits.
        }
    }

    /// @dev Perform a call to invoke {IERC1155Receiver-onERC1155Received} on `to`.
    /// Reverts if the target does not support the function correctly.
    function _checkOnERC1155Received(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        /// @solidity memory-safe-assembly
        assembly {
            // Prepare the calldata.
            let m := mload(0x40)
            // `onERC1155Received(address,address,uint256,uint256,bytes)`.
            mstore(m, 0xf23a6e61)
            mstore(add(m, 0x20), caller())
            mstore(add(m, 0x40), shr(96, shl(96, from)))
            mstore(add(m, 0x60), id)
            mstore(add(m, 0x80), amount)
            mstore(add(m, 0xa0), 0xa0)
            let n := mload(data)
            mstore(add(m, 0xc0), n)
            if n { pop(staticcall(gas(), 4, add(data, 0x20), n, add(m, 0xe0), n)) }
            // Revert if the call reverts.
            if iszero(call(gas(), to, 0, add(m, 0x1c), add(0xc4, n), m, 0x20)) {
                if returndatasize() {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                mstore(m, 0)
            }
            // Load the returndata and compare it with the function selector.
            if iszero(eq(mload(m), shl(224, 0xf23a6e61))) {
                mstore(0x00, 0x9c05499b) // `TransferToNonERC1155ReceiverImplementer()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Perform a call to invoke {IERC1155Receiver-onERC1155BatchReceived} on `to`.
    /// Reverts if the target does not support the function correctly.
    function _checkOnERC1155BatchReceived(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        /// @solidity memory-safe-assembly
        assembly {
            // Prepare the calldata.
            let m := mload(0x40)
            // `onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)`.
            mstore(m, 0xbc197c81)
            mstore(add(m, 0x20), caller())
            mstore(add(m, 0x40), shr(96, shl(96, from)))
            // Copy the `ids`.
            mstore(add(m, 0x60), 0xa0)
            let n := add(0x20, shl(5, mload(ids)))
            let o := add(m, 0xc0)
            pop(staticcall(gas(), 4, ids, n, o, n))
            // Copy the `amounts`.
            let s := add(0xa0, returndatasize())
            mstore(add(m, 0x80), s)
            o := add(o, returndatasize())
            n := add(0x20, shl(5, mload(amounts)))
            pop(staticcall(gas(), 4, amounts, n, o, n))
            // Copy the `data`.
            mstore(add(m, 0xa0), add(s, returndatasize()))
            o := add(o, returndatasize())
            n := add(0x20, mload(data))
            pop(staticcall(gas(), 4, data, n, o, n))
            n := sub(add(o, returndatasize()), add(m, 0x1c))
            // Revert if the call reverts.
            if iszero(call(gas(), to, 0, add(m, 0x1c), n, m, 0x20)) {
                if returndatasize() {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                mstore(m, 0)
            }
            // Load the returndata and compare it with the function selector.
            if iszero(eq(mload(m), shl(224, 0xbc197c81))) {
                mstore(0x00, 0x9c05499b) // `TransferToNonERC1155ReceiverImplementer()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Returns `x` in an array with a single element.
    function _single(uint256 x) private pure returns (uint256[] memory result) {
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x40))
            mstore(result, 1)
            mstore(add(result, 0x20), x)
        }
    }
}


