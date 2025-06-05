// File: @openzeppelin/contracts/cryptography/ECDSA.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        // Check the signature length
        if (signature.length != 65) {
            revert("ECDSA: invalid signature length");
        }

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return recover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover-bytes32-bytes-} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
        require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * replicates the behavior of the
     * https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_sign[`eth_sign`]
     * JSON-RPC method.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}


// File: @openzeppelin/contracts/math/Math.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
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
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}


// File: @openzeppelin/contracts/math/SafeMath.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}


// File: @openzeppelin/contracts/token/ERC20/SafeERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


// File: @openzeppelin/contracts/utils/Counters.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../math/SafeMath.sol";

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented or decremented by one. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 * Since it is not possible to overflow a 256 bit integer with increments of one, `increment` can skip the {SafeMath}
 * overflow check, thereby saving gas. This does assume however correct usage, in that the underlying `_value` is never
 * directly accessed.
 */
library Counters {
    using SafeMath for uint256;

    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        // The {SafeMath} overflow check can be skipped here, see the comment at the top
        counter._value += 1;
    }

    function decrement(Counter storage counter) internal {
        counter._value = counter._value.sub(1);
    }
}


// File: @openzeppelin/contracts/utils/SafeCast.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;


/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value < 2**128, "SafeCast: value doesn\'t fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value < 2**64, "SafeCast: value doesn\'t fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value < 2**32, "SafeCast: value doesn\'t fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value < 2**16, "SafeCast: value doesn\'t fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value < 2**8, "SafeCast: value doesn\'t fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= -2**127 && value < 2**127, "SafeCast: value doesn\'t fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= -2**63 && value < 2**63, "SafeCast: value doesn\'t fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= -2**31 && value < 2**31, "SafeCast: value doesn\'t fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= -2**15 && value < 2**15, "SafeCast: value doesn\'t fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= -2**7 && value < 2**7, "SafeCast: value doesn\'t fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value < 2**255, "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}


// File: contracts/beanstalk/AppStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IDiamondCut.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Account
 * @author Publius
 * @notice Stores Farmer-level Beanstalk state.
 * @dev {Account.State} is the primary struct that is referenced from {Storage.State}. 
 * All other structs in {Account} are referenced in {Account.State}. Each unique
 * Ethereum address is a Farmer.
 */
contract Account {
    /**
     * @notice Stores a Farmer's Plots and Pod allowances.
     * @param plots A Farmer's Plots. Maps from Plot index to Pod amount.
     * @param podAllowances An allowance mapping for Pods similar to that of the ERC-20 standard. Maps from spender address to allowance amount.
     */
    struct Field {
        mapping(uint256 => uint256) plots;
        mapping(address => uint256) podAllowances;
    }

    /**
     * @notice Stores a Farmer's Deposits and Seeds per Deposit, and formerly stored Withdrawals.
     * @param withdrawals DEPRECATED: Silo V1 Withdrawals are no longer referenced.
     * @param deposits Unripe Bean/LP Deposits (previously Bean/LP Deposits).
     * @param depositSeeds BDV of Unripe LP Deposits / 4 (previously # of Seeds in corresponding LP Deposit).
     */
    struct AssetSilo {
        mapping(uint32 => uint256) withdrawals;
        mapping(uint32 => uint256) deposits;
        mapping(uint32 => uint256) depositSeeds;
    }

    /**
     * @notice Represents a Deposit of a given Token in the Silo at a given Season.
     * @param amount The amount of Tokens in the Deposit.
     * @param bdv The Bean-denominated value of the total amount of Tokens in the Deposit.
     * @dev `amount` and `bdv` are packed as uint128 to save gas.
     */
    struct Deposit {
        uint128 amount; // ───┐ 16
        uint128 bdv; // ──────┘ 16 (32/32)
    }

    /**
     * @notice Stores a Farmer's Stalk and Seeds balances.
     * @param stalk Balance of the Farmer's Stalk.
     * @param seeds DEPRECATED – Balance of the Farmer's Seeds. Seeds are no longer referenced as of Silo V3.
     */
    struct Silo {
        uint256 stalk;
        uint256 seeds;
    }
    
    /**
     * @notice Stores a Farmer's germinating stalk.
     * @param odd - stalk from assets deposited in odd seasons.
     * @param even - stalk from assets deposited in even seasons.
     */
    struct FarmerGerminatingStalk {
        uint128 odd;
        uint128 even;
    }
    
    /**
     * @notice This struct stores the mow status for each Silo-able token, for each farmer. 
     * This gets updated each time a farmer mows, or adds/removes deposits.
     * @param lastStem The last cumulative grown stalk per bdv index at which the farmer mowed.
     * @param bdv The bdv of all of a farmer's deposits of this token type.
     * 
     */
    struct MowStatus {
        int96 lastStem; // ───┐ 12
        uint128 bdv; // ──────┘ 16 (28/32)
    }

    /**
     * @notice Stores a Farmer's Season of Plenty (SOP) balances.
     * @param roots The number of Roots a Farmer had when it started Raining.
     * @param plentyPerRoot The global Plenty Per Root index at the last time a Farmer updated their Silo.
     * @param plenty The balance of a Farmer's plenty. Plenty can be claimed directly for 3CRV.
     */
    struct SeasonOfPlenty {
        uint256 roots;
        uint256 plentyPerRoot;
        uint256 plenty;
    }
    
    /**
     * @notice Defines the state object for a Farmer.
     * @param field A Farmer's Field storage.
     * @param bean A Farmer's Unripe Bean Deposits only as a result of Replant (previously held the V1 Silo Deposits/Withdrawals for Beans).
     * @param lp A Farmer's Unripe LP Deposits as a result of Replant of BEAN:ETH Uniswap v2 LP Tokens (previously held the V1 Silo Deposits/Withdrawals for BEAN:ETH Uniswap v2 LP Tokens).
     * @param s A Farmer's Silo storage.
     * @param deprecated_votedUntil DEPRECATED – Replant removed on-chain governance including the ability to vote on BIPs.
     * @param lastUpdate The Season in which the Farmer last updated their Silo.
     * @param lastSop The last Season that a SOP occured at the time the Farmer last updated their Silo.
     * @param lastRain The last Season that it started Raining at the time the Farmer last updated their Silo.
     * @param deprecated_deltaRoots DEPRECATED – BIP-39 introduced germination.
     * @param deprecated_lastSIs DEPRECATED – In Silo V1.2, the Silo reward mechanism was updated to no longer need to store the number of the Supply Increases at the time the Farmer last updated their Silo.
     * @param deprecated_proposedUntil DEPRECATED – Replant removed on-chain governance including the ability to propose BIPs.
     * @param deprecated_sop DEPRECATED – Replant reset the Season of Plenty mechanism
     * @param roots A Farmer's Root balance.
     * @param deprecated_wrappedBeans DEPRECATED – Replant generalized Internal Balances. Wrapped Beans are now stored at the AppStorage level.
     * @param legacyV2Deposits DEPRECATED - SiloV2 was retired in favor of Silo V3. A Farmer's Silo Deposits stored as a map from Token address to Season of Deposit to Deposit.
     * @param withdrawals Withdraws were removed in zero withdraw upgrade - A Farmer's Withdrawals from the Silo stored as a map from Token address to Season the Withdrawal becomes Claimable to Withdrawn amount of Tokens.
     * @param sop A Farmer's Season of Plenty storage.
     * @param depositAllowances A mapping of `spender => Silo token address => amount`.
     * @param tokenAllowances Internal balance token allowances.
     * @param depositPermitNonces A Farmer's current deposit permit nonce
     * @param tokenPermitNonces A Farmer's current token permit nonce
     * @param legacyV3Deposits DEPRECATED: Silo V3 deposits. Deprecated in favor of SiloV3.1 mapping from depositId to Deposit.
     * @param mowStatuses A mapping of Silo-able token address to MowStatus.
     * @param isApprovedForAll A mapping of ERC1155 operator to approved status. ERC1155 compatability.
     * @param farmerGerminating A Farmer's germinating stalk. Seperated into odd and even stalk.
     * @param deposits SiloV3.1 deposits. A mapping from depositId to Deposit. SiloV3.1 introduces greater precision for deposits.
     */
    struct State {
        Field field; // A Farmer's Field storage.

        /*
         * @dev (Silo V1) A Farmer's Unripe Bean Deposits only as a result of Replant
         *
         * Previously held the V1 Silo Deposits/Withdrawals for Beans.

         * NOTE: While the Silo V1 format is now deprecated, this storage slot is used for gas
         * efficiency to store Unripe BEAN deposits. See {LibUnripeSilo} for more.
         */
        AssetSilo bean; 

        /*
         * @dev (Silo V1) Unripe LP Deposits as a result of Replant.
         * 
         * Previously held the V1 Silo Deposits/Withdrawals for BEAN:ETH Uniswap v2 LP Tokens.
         * 
         * BEAN:3CRV and BEAN:LUSD tokens prior to Replant were stored in the Silo V2
         * format in the `s.a[account].legacyV2Deposits` mapping.
         *
         * NOTE: While the Silo V1 format is now deprecated, unmigrated Silo V1 deposits are still
         * stored in this storage slot. See {LibUnripeSilo} for more.
         * 
         */
        AssetSilo lp; 

        /*
         * @dev Holds Silo specific state for each account.
         */
        Silo s;
        
        uint32 votedUntil; // DEPRECATED – Replant removed on-chain governance including the ability to vote on BIPs.
        uint32 lastUpdate; // The Season in which the Farmer last updated their Silo.
        uint32 lastSop; // The last Season that a SOP occured at the time the Farmer last updated their Silo.
        uint32 lastRain; // The last Season that it started Raining at the time the Farmer last updated their Silo.
        uint128 deprecated_deltaRoots; // DEPRECATED - BIP-39 introduced germination. 
        SeasonOfPlenty deprecated; // DEPRECATED – Replant reset the Season of Plenty mechanism
        uint256 roots; // A Farmer's Root balance.
        uint256 deprecated_wrappedBeans; // DEPRECATED – Replant generalized Internal Balances. Wrapped Beans are now stored at the AppStorage level.
        mapping(address => mapping(uint32 => Deposit)) legacyV2Deposits; // Legacy Silo V2 Deposits stored as a map from Token address to Season of Deposit to Deposit. NOTE: While the Silo V2 format is now deprecated, unmigrated Silo V2 deposits are still stored in this mapping.
        mapping(address => mapping(uint32 => uint256)) withdrawals; // Zero withdraw eliminates a need for withdraw mapping, but is kept for legacy
        SeasonOfPlenty sop; // A Farmer's Season Of Plenty storage.
        mapping(address => mapping(address => uint256)) depositAllowances; // Spender => Silo Token
        mapping(address => mapping(IERC20 => uint256)) tokenAllowances; // Token allowances
        uint256 depositPermitNonces; // A Farmer's current deposit permit nonce
        uint256 tokenPermitNonces; // A Farmer's current token permit nonce
        mapping(uint256 => Deposit) legacyV3Deposits; // NOTE: Legacy SiloV3 Deposits stored as a map from uint256 to Deposit. This is an concat of the token address and the CGSPBDV for a ERC20 deposit.
        mapping(address => MowStatus) mowStatuses; // Store a MowStatus for each Whitelisted Silo token
        mapping(address => bool) isApprovedForAll; // ERC1155 isApprovedForAll mapping 
        
        // Germination
        FarmerGerminatingStalk farmerGerminating; // A Farmer's germinating stalk.

        // Silo v3.1
        mapping(uint256 => Deposit) deposits; // Silo v3.1 Deposits stored as a map from uint256 to Deposit. This is an concat of the token address and the stem for a ERC20 deposit.
    }
}

/**
 * @title Storage
 * @author Publius
 * @notice Stores system-level Beanstalk state.
 */
contract Storage {
    /**
     * @notice DEPRECATED: System-level contract addresses.
     * @dev After Replant, Beanstalk stores Token addresses as constants to save gas.
     */
    struct Contracts {
        address bean;
        address pair;
        address pegPair;
        address weth;
    }

    /**
     * @notice System-level Field state variables.
     * @param soil The number of Soil currently available. Adjusted during {Sun.stepSun}.
     * @param beanSown The number of Bean sown within the current Season. Reset during {Weather.calcCaseId}.
     * @param pods The pod index; the total number of Pods ever minted.
     * @param harvested The harvested index; the total number of Pods that have ever been Harvested.
     * @param harvestable The harvestable index; the total number of Pods that have ever been Harvestable. Included previously Harvested Beans.
     */
    struct Field {
        uint128 soil; // ──────┐ 16
        uint128 beanSown; // ──┘ 16 (32/32)
        uint256 pods;
        uint256 harvested;
        uint256 harvestable;
    }

    /**
     * @notice DEPRECATED: Contained data about each BIP (Beanstalk Improvement Proposal).
     * @dev Replant moved governance off-chain. This struct is left for future reference.
     * 
     */
    struct Bip {
        address proposer; // ───┐ 20
        uint32 start; //        │ 4 (24)
        uint32 period; //       │ 4 (28)
        bool executed; // ──────┘ 1 (29/32)
        int pauseOrUnpause; 
        uint128 timestamp;
        uint256 roots;
        uint256 endTotalRoots;
    }

    /**
     * @notice DEPRECATED: Contained data for the DiamondCut associated with each BIP.
     * @dev Replant moved governance off-chain. This struct is left for future reference.
     * @dev {Storage.DiamondCut} stored DiamondCut-related data for each {Bip}.
     */
    struct DiamondCut {
        IDiamondCut.FacetCut[] diamondCut;
        address initAddress;
        bytes initData;
    }

    /**
     * @notice DEPRECATED: Contained all governance-related data, including a list of BIPs, votes for each BIP, and the DiamondCut needed to execute each BIP.
     * @dev Replant moved governance off-chain. This struct is left for future reference.
     * @dev {Storage.Governance} stored all BIPs and Farmer voting information.
     */
    struct Governance {
        uint32[] activeBips;
        uint32 bipIndex;
        mapping(uint32 => DiamondCut) diamondCuts;
        mapping(uint32 => mapping(address => bool)) voted;
        mapping(uint32 => Bip) bips;
    }

    /**
     * @notice System-level Silo state; contains deposit and withdrawal data for a particular whitelisted Token.
     * @param deposited The total amount of this Token currently Deposited in the Silo.
     * @param depositedBdv The total bdv of this Token currently Deposited in the Silo.
     * @param withdrawn The total amount of this Token currently Withdrawn From the Silo.
     * @dev {Storage.State} contains a mapping from Token address => AssetSilo.
     * Currently, the bdv of deposits are asynchronous, and require an on-chain transaction to update.
     * Thus, the total bdv of deposits cannot be calculated, and must be stored and updated upon a bdv change.
     * 
     * 
     * Note that "Withdrawn" refers to the amount of Tokens that have been Withdrawn
     * but not yet Claimed. This will be removed in a future BIP.
     */
    struct AssetSilo {
        uint128 deposited;
        uint128 depositedBdv;
        uint256 withdrawn;
    }

    /**
     * @notice Whitelist Status a token that has been Whitelisted before.
     * @param token the address of the token.
     * @param a whether the address is whitelisted.
     * @param isWhitelistedLp whether the address is a whitelisted LP token.
     * @param isWhitelistedWell whether the address is a whitelisted Well token.
     */

    struct WhitelistStatus {
        address token;
        bool isWhitelisted;
        bool isWhitelistedLp;
        bool isWhitelistedWell;
    }

    /**
     * @notice System-level Silo state variables.
     * @param stalk The total amount of active Stalk (including Earned Stalk, excluding Grown Stalk).
     * @param deprecated_seeds DEPRECATED: The total amount of active Seeds (excluding Earned Seeds).
     * @dev seeds are no longer used internally. Balance is wiped to 0 from the mayflower update. see {mowAndMigrate}.
     * @param roots The total amount of Roots.
     */
    struct Silo {
        uint256 stalk;
        uint256 deprecated_seeds; 
        uint256 roots;
    }

    /**
     * @notice System-level Curve Metapool Oracle state variables.
     * @param initialized True if the Oracle has been initialzed. It needs to be initialized on Deployment and re-initialized each Unpause.
     * @param startSeason The Season the Oracle started minting. Used to ramp up delta b when oracle is first added.
     * @param balances The cumulative reserve balances of the pool at the start of the Season (used for computing time weighted average delta b).
     * @param timestamp DEPRECATED: The timestamp of the start of the current Season. `LibCurveMinting` now uses `s.season.timestamp` instead of storing its own for gas efficiency purposes.
     * @dev Currently refers to the time weighted average deltaB calculated from the BEAN:3CRV pool.
     */
    struct CurveMetapoolOracle {
        bool initialized; // ────┐ 1
        uint32 startSeason; // ──┘ 4 (5/32)
        uint256[2] balances;
        uint256 timestamp;
    }

    /**
     * @notice System-level Rain balances. Rain occurs when P > 1 and the Pod Rate Excessively Low.
     * @dev The `raining` storage variable is stored in the Season section for a gas efficient read operation.
     * @param deprecated Previously held Rain start and Rain status variables. Now moved to Season struct for gas efficiency.
     * @param pods The number of Pods when it last started Raining.
     * @param roots The number of Roots when it last started Raining.
     */
    struct Rain {
        uint256 deprecated;
        uint256 pods;
        uint256 roots;
    }

    /**
     * @notice System-level Season state variables.
     * @param current The current Season in Beanstalk.
     * @param lastSop The Season in which the most recent consecutive series of Seasons of Plenty started.
     * @param withdrawSeasons The number of Seasons required to Withdraw a Deposit.
     * @param lastSopSeason The Season in which the most recent consecutive series of Seasons of Plenty ended.
     * @param rainStart Stores the most recent Season in which Rain started.
     * @param raining True if it is Raining (P > 1, Pod Rate Excessively Low).
     * @param fertilizing True if Beanstalk has Fertilizer left to be paid off.
     * @param sunriseBlock The block of the start of the current Season.
     * @param abovePeg Boolean indicating whether the previous Season was above or below peg.
     * @param stemStartSeason // season in which the stem storage method was introduced.
     * @param stemScaleSeason // season in which the stem v1.1 was introduced, where stems are not truncated anymore.
     * This allows for greater precision of stems, and requires a soft migration (see {LibTokenSilo.removeDepositFromAccount})
     * @param start The timestamp of the Beanstalk deployment rounded down to the nearest hour.
     * @param period The length of each season in Beanstalk in seconds.
     * @param timestamp The timestamp of the start of the current Season.
     */
    struct Season {
        uint32 current; // ─────────────────┐ 4  
        uint32 lastSop; //                  │ 4 (8)
        uint8 withdrawSeasons; //           │ 1 (9)
        uint32 lastSopSeason; //            │ 4 (13)
        uint32 rainStart; //                │ 4 (17)
        bool raining; //                    │ 1 (18)
        bool fertilizing; //                │ 1 (19)
        uint32 sunriseBlock; //             │ 4 (23)
        bool abovePeg; //                   | 1 (24)
        uint16 stemStartSeason; //          | 2 (26)
        uint16 stemScaleSeason; //──────────┘ 2 (28/32)
        uint256 start;
        uint256 period;
        uint256 timestamp;
    }

    /**
     * @notice System-level Weather state variables.
     * @param deprecated 2 slots that were previously used.
     * @param lastDSoil Delta Soil; the number of Soil purchased last Season.
     * @param lastSowTime The number of seconds it for Soil to sell out last Season.
     * @param thisSowTime The number of seconds it for Soil to sell out this Season.
     * @param t The Temperature; the maximum interest rate during the current Season for sowing Beans in Soil. Adjusted each Season.
     */
    struct Weather {
        uint256[2] deprecated;
        uint128 lastDSoil;  // ───┐ 16 (16)
        uint32 lastSowTime; //    │ 4  (20)
        uint32 thisSowTime; //    │ 4  (24)
        uint32 t; // ─────────────┘ 4  (28/32)
    }

    /**
     * @notice Describes a Fundraiser.
     * @param payee The address to be paid after the Fundraiser has been fully funded.
     * @param token The token address that used to raise funds for the Fundraiser.
     * @param total The total number of Tokens that need to be raised to complete the Fundraiser.
     * @param remaining The remaining number of Tokens that need to to complete the Fundraiser.
     * @param start The timestamp at which the Fundraiser started (Fundraisers cannot be started and funded in the same block).
     */
    struct Fundraiser {
        address payee;
        address token;
        uint256 total;
        uint256 remaining;
        uint256 start;
    }

    /**
     * @notice Describes the settings for each Token that is Whitelisted in the Silo.
     * @param selector The encoded BDV function selector for the token that pertains to 
     * an external view Beanstalk function with the following signature:
     * ```
     * function tokenToBdv(uint256 amount) external view returns (uint256);
     * ```
     * It is called by `LibTokenSilo` through the use of `delegatecall`
     * to calculate a token's BDV at the time of Deposit.
     * @param stalkEarnedPerSeason represents how much Stalk one BDV of the underlying deposited token
     * grows each season. In the past, this was represented by seeds. This is stored as 1e6, plus stalk is stored
     * as 1e10, so 1 legacy seed would be 1e6 * 1e10.
     * @param stalkIssuedPerBdv The Stalk Per BDV that the Silo grants in exchange for Depositing this Token.
     * previously called stalk.
     * @param milestoneSeason The last season in which the stalkEarnedPerSeason for this token was updated.
     * @param milestoneStem The cumulative amount of grown stalk per BDV for this token at the last stalkEarnedPerSeason update.
     * @param encodeType determine the encoding type of the selector.
     * a encodeType of 0x00 means the selector takes an input amount.
     * 0x01 means the selector takes an input amount and a token.
     * @param gpSelector The encoded gaugePoint function selector for the token that pertains to 
     * an external view Beanstalk function with the following signature:
     * ```
     * function gaugePoints(
     *  uint256 currentGaugePoints,
     *  uint256 optimalPercentDepositedBdv,
     *  uint256 percentOfDepositedBdv
     *  ) external view returns (uint256);
     * ```
     * @param lwSelector The encoded liquidityWeight function selector for the token that pertains to 
     * an external view Beanstalk function with the following signature `function liquidityWeight()`
     * @param optimalPercentDepositedBdv The target percentage of the total LP deposited BDV for this token. 6 decimal precision.
     * @param gaugePoints the amount of Gauge points this LP token has in the LP Gauge. Only used for LP whitelisted assets.
     * GaugePoints has 18 decimal point precision (1 Gauge point = 1e18).

     * @dev A Token is considered Whitelisted if there exists a non-zero {SiloSettings} selector.
     */
    struct SiloSettings {
        bytes4 selector; // ────────────────────┐ 4
        uint32 stalkEarnedPerSeason; //         │ 4  (8)
        uint32 stalkIssuedPerBdv; //            │ 4  (12)
        uint32 milestoneSeason; //              │ 4  (16)
        int96 milestoneStem; //                 │ 12 (28)
        bytes1 encodeType; //                   │ 1  (29)
        int24 deltaStalkEarnedPerSeason; // ────┘ 3  (32)
        bytes4 gpSelector; //    ────────────────┐ 4  
        bytes4 lwSelector; //                    │ 4  (8)
        uint128 gaugePoints; //                  │ 16 (24)
        uint64 optimalPercentDepositedBdv; //  ──┘ 8  (32)
    }

    /**
     * @notice Describes the settings for each Unripe Token in Beanstalk.
     * @param underlyingToken The address of the Token underlying the Unripe Token.
     * @param balanceOfUnderlying The number of Tokens underlying the Unripe Tokens (redemption pool).
     * @param merkleRoot The Merkle Root used to validate a claim of Unripe Tokens.
     * @dev An Unripe Token is a vesting Token that is redeemable for a a pro rata share
     * of the `balanceOfUnderlying`, subject to a penalty based on the percent of
     * Unfertilized Beans paid back.
     * 
     * There were two Unripe Tokens added at Replant: 
     *  - Unripe Bean, with its `underlyingToken` as BEAN;
     *  - Unripe LP, with its `underlyingToken` as BEAN:3CRV LP.
     * 
     * Unripe Tokens are initially distributed through the use of a `merkleRoot`.
     * 
     * The existence of a non-zero {UnripeSettings} implies that a Token is an Unripe Token.
     */
    struct UnripeSettings {
        address underlyingToken;
        uint256 balanceOfUnderlying;
        bytes32 merkleRoot;
    }

    /**
     * @notice System level variables used in the seed Gauge System.
     * @param averageGrownStalkPerBdvPerSeason The average Grown Stalk Per BDV 
     * that beanstalk issues each season.
     * @param beanToMaxLpGpPerBdvRatio a scalar of the gauge points(GP) per bdv 
     * issued to the largest LP share and Bean. 6 decimal precision.
     * @dev a beanToMaxLpGpPerBdvRatio of 0 means LP should be incentivized the most,
     * and that beans will have the minimum seeds ratio. see {LibGauge.getBeanToMaxLpGpPerBdvRatioScaled}
     */
    struct SeedGauge {
        uint128 averageGrownStalkPerBdvPerSeason;
        uint128 beanToMaxLpGpPerBdvRatio;
    }

    /**
     * @notice Stores the twaReserves for each well during the sunrise function.
     */
    struct TwaReserves {
        uint128 reserve0;
        uint128 reserve1;
    }

    /**
     * @notice Stores the total germination amounts for each whitelisted token.
     */
    struct Deposited {
        uint128 amount;
        uint128 bdv;
    }

    /** 
     * @notice Stores the system level germination data.
     */
    struct TotalGerminating {
        mapping(address => Deposited) deposited;
    }

    struct Sr {
	    uint128 stalk;
	    uint128 roots;
    }
}

/**
 * @title AppStorage
 * @author Publius
 * @notice Defines the state object for Beanstalk.
 * @param deprecated_index DEPRECATED: Was the index of the BEAN token in the BEAN:ETH Uniswap V2 pool.
 * @param deprecated_cases DEPRECATED: The 24 Weather cases used in cases V1 (array has 32 items, but caseId = 3 (mod 4) are not cases)
 * @param paused True if Beanstalk is Paused.
 * @param pausedAt The timestamp at which Beanstalk was last paused.
 * @param season Storage.Season
 * @param c Storage.Contracts
 * @param f Storage.Field
 * @param g Storage.Governance
 * @param co Storage.CurveMetapoolOracle
 * @param r Storage.Rain
 * @param s Storage.Silo
 * @param reentrantStatus An intra-transaction state variable to protect against reentrance.
 * @param w Storage.Weather
 * @param earnedBeans The number of Beans distributed to the Silo that have not yet been Deposited as a result of the Earn function being called.
 * @param deprecated DEPRECATED - 14 slots that used to store state variables which have been deprecated through various updates. Storage slots can be left alone or reused.
 * @param a mapping (address => Account.State)
 * @param deprecated_bip0Start DEPRECATED - bip0Start was used to aid in a migration that occured alongside BIP-0.
 * @param deprecated_hotFix3Start DEPRECATED - hotFix3Start was used to aid in a migration that occured alongside HOTFIX-3.
 * @param fundraisers A mapping from Fundraiser ID to Storage.Fundraiser.
 * @param fundraiserIndex The number of Fundraisers that have occured.
 * @param deprecated_isBudget DEPRECATED - Budget Facet was removed in BIP-14. 
 * @param podListings A mapping from Plot Index to the hash of the Pod Listing.
 * @param podOrders A mapping from the hash of a Pod Order to the amount of Pods that the Pod Order is still willing to buy.
 * @param siloBalances A mapping from Token address to Silo Balance storage (amount deposited and withdrawn).
 * @param ss A mapping from Token address to Silo Settings for each Whitelisted Token. If a non-zero storage exists, a Token is whitelisted.
 * @param deprecated2 DEPRECATED - 2 slots that used to store state variables which have been deprecated through various updates. Storage slots can be left alone or reused.
 * @param deprecated_newEarnedStalk the amount of earned stalk issued this season. Since 1 stalk = 1 bean, it represents the earned beans as well.
 * @param sops A mapping from Season to Plenty Per Root (PPR) in that Season. Plenty Per Root is 0 if a Season of Plenty did not occur.
 * @param internalTokenBalance A mapping from Farmer address to Token address to Internal Balance. It stores the amount of the Token that the Farmer has stored as an Internal Balance in Beanstalk.
 * @param unripeClaimed True if a Farmer has Claimed an Unripe Token. A mapping from Farmer to Unripe Token to its Claim status.
 * @param u Unripe Settings for a given Token address. The existence of a non-zero Unripe Settings implies that the token is an Unripe Token. The mapping is from Token address to Unripe Settings.
 * @param fertilizer A mapping from Fertilizer Id to the supply of Fertilizer for each Id.
 * @param nextFid A linked list of Fertilizer Ids ordered by Id number. Fertilizer Id is the Beans Per Fertilzer level at which the Fertilizer no longer receives Beans. Sort in order by which Fertilizer Id expires next.
 * @param activeFertilizer The number of active Fertilizer.
 * @param fertilizedIndex The total number of Fertilizer Beans.
 * @param unfertilizedIndex The total number of Unfertilized Beans ever.
 * @param fFirst The lowest active Fertilizer Id (start of linked list that is stored by nextFid). 
 * @param fLast The highest active Fertilizer Id (end of linked list that is stored by nextFid). 
 * @param bpf The cumulative Beans Per Fertilizer (bfp) minted over all Season.
 * @param deprecated_vestingPeriodRoots deprecated - removed in BIP-39 in favor of germination.
 * @param recapitalized The number of USDC that has been recapitalized in the Barn Raise.
 * @param isFarm Stores whether the function is wrapped in the `farm` function (1 if not, 2 if it is).
 * @param ownerCandidate Stores a candidate address to transfer ownership to. The owner must claim the ownership transfer.
 * @param wellOracleSnapshots A mapping from Well Oracle address to the Well Oracle Snapshot.
 * @param deprecated_beanEthPrice DEPRECATED - The price of bean:eth, originally used to calculate the incentive reward. Deprecated in favor of calculating using twaReserves.
 * @param twaReserves A mapping from well to its twaReserves. Stores twaReserves during the sunrise function. Returns 1 otherwise for each asset. Currently supports 2 token wells.
 * @param migratedBdvs Stores the total migrated BDV since the implementation of the migrated BDV counter. See {LibLegacyTokenSilo.incrementMigratedBdv} for more info.
 * @param usdEthPrice  Stores the usdEthPrice during the sunrise() function. Returns 1 otherwise.
 * @param seedGauge Stores the seedGauge.
 * @param casesV2 Stores the 144 Weather and seedGauge cases.
 * @param oddGerminating Stores germinating data during odd seasons.
 * @param evenGerminating Stores germinating data during even seasons.
 * @param whitelistedStatues Stores a list of Whitelist Statues for all tokens that have been Whitelisted and have not had their Whitelist Status manually removed.
 * @param sopWell Stores the well that will be used upon a SOP. Unintialized until a SOP occurs, and is kept constant afterwards.
 */
struct AppStorage {
    uint8 deprecated_index;
    int8[32] deprecated_cases; 
    bool paused; // ────────┐ 1 
    uint128 pausedAt; // ───┘ 16 (17/32)
    Storage.Season season;
    Storage.Contracts c;
    Storage.Field f;
    Storage.Governance g;
    Storage.CurveMetapoolOracle co;
    Storage.Rain r;
    Storage.Silo s;
    uint256 reentrantStatus;
    Storage.Weather w;

    uint256 earnedBeans;
    uint256[14] deprecated;
    mapping (address => Account.State) a;
    uint32 deprecated_bip0Start; // ─────┐ 4
    uint32 deprecated_hotFix3Start; // ──┘ 4 (8/32)
    mapping (uint32 => Storage.Fundraiser) fundraisers;
    uint32 fundraiserIndex; // 4 (4/32)
    mapping (address => bool) deprecated_isBudget;
    mapping(uint256 => bytes32) podListings;
    mapping(bytes32 => uint256) podOrders;
    mapping(address => Storage.AssetSilo) siloBalances;
    mapping(address => Storage.SiloSettings) ss;
    uint256[2] deprecated2;
    uint128 deprecated_newEarnedStalk; // ──────┐ 16
    uint128 deprecated_vestingPeriodRoots; // ──┘ 16 (32/32)
    mapping (uint32 => uint256) sops;

    // Internal Balances
    mapping(address => mapping(IERC20 => uint256)) internalTokenBalance;

    // Unripe
    mapping(address => mapping(address => bool)) unripeClaimed;
    mapping(address => Storage.UnripeSettings) u;

    // Fertilizer
    mapping(uint128 => uint256) fertilizer;
    mapping(uint128 => uint128) nextFid;
    uint256 activeFertilizer;
    uint256 fertilizedIndex;
    uint256 unfertilizedIndex;
    uint128 fFirst;
    uint128 fLast;
    uint128 bpf;
    uint256 recapitalized;

    // Farm
    uint256 isFarm;

    // Ownership
    address ownerCandidate;

    // Well
    mapping(address => bytes) wellOracleSnapshots;

    uint256 deprecated_beanEthPrice;

    // Silo V3 BDV Migration
    mapping(address => uint256) migratedBdvs;

    // Well/Curve + USD Price Oracle
    mapping(address => Storage.TwaReserves) twaReserves;
    mapping(address => uint256) usdTokenPrice;

    // Seed Gauge
    Storage.SeedGauge seedGauge;
    bytes32[144] casesV2;

    // Germination
    Storage.TotalGerminating oddGerminating;
    Storage.TotalGerminating evenGerminating;

    // mapping from season => unclaimed germinating stalk and roots 
    mapping(uint32 => Storage.Sr) unclaimedGerminating;

    Storage.WhitelistStatus[] whitelistStatuses;

    address sopWell;
}

// File: contracts/beanstalk/ReentrancyGuard.sol

// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;
import "./AppStorage.sol";

/**
 * @author Beanstalk Farms
 * @title Variation of Oepn Zeppelins reentrant guard to include Silo Update
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts%2Fsecurity%2FReentrancyGuard.sol
**/
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    AppStorage internal s;
    
    modifier nonReentrant() {
        require(s.reentrantStatus != _ENTERED, "ReentrancyGuard: reentrant call");
        s.reentrantStatus = _ENTERED;
        _;
        s.reentrantStatus = _NOT_ENTERED;
    }
}

// File: contracts/beanstalk/silo/SiloFacet/Silo.sol
/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity =0.7.6;
pragma abicoder v2;

import {AppStorage, Storage} from "contracts/beanstalk/AppStorage.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ReentrancyGuard} from "contracts/beanstalk/ReentrancyGuard.sol";
import {LibSafeMath128} from "contracts/libraries/LibSafeMath128.sol";
import {LibSafeMath32} from "contracts/libraries/LibSafeMath32.sol";
import {LibGerminate} from "contracts/libraries/Silo/LibGerminate.sol";
import {LibTokenSilo} from "contracts/libraries/Silo/LibTokenSilo.sol";
import {LibSilo} from "contracts/libraries/Silo/LibSilo.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/SafeCast.sol";
import {LibBytes} from "contracts/libraries/LibBytes.sol";
import {C} from "contracts/C.sol";
import {IWell} from "contracts/interfaces/basin/IWell.sol";

/**
 * @title Silo
 * @author Publius, Pizzaman1337, Brean
 * @notice Provides utility functions for claiming Silo rewards, including:
 *
 * - Grown Stalk (see "Mow")
 * - Earned Beans, Earned Stalk (see "Plant")
 * - 3CRV earned during a Flood (see "Flood")
 *
 * For backwards compatibility, a Flood is sometimes referred to by its old name
 * "Season of Plenty".
 */
 
contract Silo is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using LibSafeMath128 for uint128;

    //////////////////////// EVENTS ////////////////////////    

    /**
     * @notice Emitted when the deposit associated with the Earned Beans of
     * `account` are Planted.
     * @param account Owns the Earned Beans
     * @param beans The amount of Earned Beans claimed by `account`.
     */
    event Plant(
        address indexed account,
        uint256 beans
    );

    /**
     * @notice Emitted when 3CRV paid to `account` during a Flood is Claimed.
     * @param account Owns and receives the assets paid during a Flood.
     * @param plenty The amount of 3CRV claimed by `account`. This is the amount
     * that `account` has been paid since their last {ClaimPlenty}.
     * 
     * @dev Flood was previously called a "Season of Plenty". For backwards
     * compatibility, the event has not been changed. For more information on 
     * Flood, see: {Weather.sop}.
     */
    event ClaimPlenty(
        address indexed account,
        address token,
        uint256 plenty
    );


    /**
     * @notice Emitted when `account` gains or loses Stalk.
     * @param account The account that gained or lost Stalk.
     * @param delta The change in Stalk.
     * @param deltaRoots The change in Roots.
     *   
     * @dev {StalkBalanceChanged} should be emitted anytime a Deposit is added, removed or transferred AND
     * anytime an account Mows Grown Stalk.
     * @dev BIP-24 included a one-time re-emission of {SeedsBalanceChanged} for accounts that had
     * executed a Deposit transfer between the Replant and BIP-24 execution. For more, see:
     * [BIP-24](https://github.com/BeanstalkFarms/Beanstalk-Governance-Proposals/blob/master/bip/bip-24-fungible-bdv-support.md)
     * [Event-24-Event-Emission](https://github.com/BeanstalkFarms/Event-24-Event-Emission)
     */
    event StalkBalanceChanged(
        address indexed account,
        int256 delta,
        int256 deltaRoots
    );

    //////////////////////// INTERNAL: MOW ////////////////////////

    /**
     * @dev Claims the Grown Stalk for `msg.sender`. Requires token address to mow.
     */
    modifier mowSender(address token) {
        LibSilo._mow(msg.sender, token);
        _;
    }

    //////////////////////// INTERNAL: PLANT ////////////////////////

    /**
     * @dev Plants the Plantable BDV of `account` associated with its Earned
     * Beans.
     * 
     * For more info on Planting, see: {SiloFacet-plant}
     */
     
    function _plant(address account) internal returns (uint256 beans, int96 stemTip) {
        // Need to Mow for `account` before we calculate the balance of 
        // Earned Beans.
    
        LibSilo._mow(account, C.BEAN);
        uint256 accountStalk = s.a[account].s.stalk;

        // Calculate balance of Earned Beans.
        beans = LibSilo._balanceOfEarnedBeans(accountStalk, s.a[account].roots);
        stemTip = LibTokenSilo.stemTipForToken(C.BEAN);
        if (beans == 0) return (0, stemTip);
        
        // Reduce the Silo's supply of Earned Beans.
        // SafeCast unnecessary because beans is <= s.earnedBeans.
        s.earnedBeans = s.earnedBeans.sub(uint128(beans));
        
        // Deposit Earned Beans if there are any. Note that 1 Bean = 1 BDV.
        LibTokenSilo.addDepositToAccount(
            account,
            C.BEAN,
            stemTip,
            beans, // amount
            beans, // bdv
            LibTokenSilo.Transfer.emitTransferSingle
        );

        // Earned Stalk associated with Earned Beans generate more Earned Beans automatically (i.e., auto compounding).
        // Earned Stalk are minted when Earned Beans are minted during Sunrise. See {Sun.sol:rewardToSilo} for details.
        // Similarly, `account` does not receive additional Roots from Earned Stalk during a Plant.
        // The following lines allocate Earned Stalk that has already been minted to `account`.
        // Constant is used here rather than s.ss[BEAN].stalkIssuedPerBdv
        // for gas savings.
        uint256 stalk = beans.mul(C.STALK_PER_BEAN);
        s.a[account].s.stalk = accountStalk.add(stalk);

        emit StalkBalanceChanged(account, int256(stalk), 0);
        emit Plant(account, beans);
    }

    //////////////////////// INTERNAL: SEASON OF PLENTY ////////////////////////

    /**
     * @dev Gas optimization: An account can call `{SiloFacet:claimPlenty}` even
     * if `s.a[account].sop.plenty == 0`. This would emit a ClaimPlenty event
     * with an amount of 0.
     */
    function _claimPlenty(address account) internal {
        // Plenty is earned in the form of the sop token.
        uint256 plenty = s.a[account].sop.plenty;
        IWell well = IWell(s.sopWell);
        IERC20[] memory tokens = well.tokens();
        IERC20 sopToken = tokens[0] != C.bean() ? tokens[0] : tokens[1];
        sopToken.safeTransfer(account, plenty);
        delete s.a[account].sop.plenty;

        emit ClaimPlenty(account, address(sopToken), plenty);
    }
}


// File: contracts/beanstalk/silo/SiloFacet/SiloFacet.sol
/*
 * SPDX-License-Identifier: MIT
 */

pragma solidity =0.7.6;
pragma abicoder v2;

import "./TokenSilo.sol";
import "contracts/libraries/Token/LibTransfer.sol";
import "contracts/libraries/Silo/LibSiloPermit.sol";

/**
 * @title SiloFacet
 * @author Publius, Brean, Pizzaman1337
 * @notice SiloFacet is the entry point for all Silo functionality.
 * 
 * SiloFacet           public functions for modifying an account's Silo.
 * ↖ TokenSilo         accounting & storage for Deposits, Withdrawals, allowances
 * ↖ Silo              accounting & storage for Stalk, and Roots.
 * ↖ SiloExit          public view funcs for total balances, account balances 
 *                     & other account state.
 * ↖ ReentrancyGuard   provides reentrancy guard modifier and access to {C}.
 *
 * 
 */
contract SiloFacet is TokenSilo {

    using SafeMath for uint256;
    using LibSafeMath32 for uint32;

    //////////////////////// DEPOSIT ////////////////////////

    /** 
     * @notice Deposits an ERC20 into the Silo.
     * @dev farmer is issued stalk and seeds based on token (i.e non-whitelisted tokens do not get any)
     * @param token address of ERC20
     * @param amount tokens to be transfered
     * @param mode source of funds (INTERNAL, EXTERNAL, EXTERNAL_INTERNAL, INTERNAL_TOLERANT)
     * @dev Depositing should:
     * 
     *  1. Transfer `amount` of `token` from `account` to Beanstalk.
     *  2. Calculate the current Bean Denominated Value (BDV) for `amount` of `token`.
     *  3. Create or update a Deposit entry for `account` in the current Season.
     *  4. Mint Stalk to `account`.
     *  5. Emit an `AddDeposit` event.
     * 
     */
    function deposit(
        address token,
        uint256 _amount,
        LibTransfer.From mode
    ) 
        external
        payable 
        nonReentrant 
        mowSender(token) 
        returns (uint256 amount, uint256 _bdv, int96 stem)
    {
        amount = LibTransfer.receiveToken(
            IERC20(token),
            _amount,
            msg.sender,
            mode
        );
        (_bdv, stem) = _deposit(msg.sender, token, amount);
    }

    //////////////////////// WITHDRAW ////////////////////////

    /** 
     * @notice Withdraws an ERC20 Deposit from the Silo.
     * @param token Address of the whitelisted ERC20 token to Withdraw.
     * @param stem The stem to Withdraw from.
     * @param amount Amount of `token` to Withdraw.
     *
     * @dev When Withdrawing a Deposit, the user must burn all of the Stalk
     * associated with it, including:
     *
     * - base Stalk, received based on the BDV of the Deposit.
     * - Grown Stalk, grown from BDV and stalkEarnedPerSeason while the deposit was held in the Silo.
     *
     * Note that the Grown Stalk associated with a Deposit is a function of the 
     * delta between the current Season and the Season in which a Deposit was made.
     * 
     * Typically, a Farmer wants to withdraw more recent Deposits first, since
     * these require less Stalk to be burned. This functionality is the default
     * provided by the Beanstalk SDK, but is NOT provided at the contract level.
     * 
     */
    function withdrawDeposit(
        address token,
        int96 stem,
        uint256 amount,
        LibTransfer.To mode
    ) external payable mowSender(token) nonReentrant {
        _withdrawDeposit(msg.sender, token, stem, amount);
        LibTransfer.sendToken(IERC20(token), amount, msg.sender, mode);
    }

    /** 
     * @notice Claims ERC20s from multiple Withdrawals.
     * @param token Address of the whitelisted ERC20 token to Withdraw.
     * @param stems stems to Withdraw from.
     * @param amounts Amounts of `token` to Withdraw from corresponding `stems`.
     * 
     * deposits.
     * @dev Clients should factor in gas costs when withdrawing from multiple
     * 
     * For example, if a user wants to withdraw X Beans, it may be preferable to
     * withdraw from 1 older Deposit, rather than from multiple recent Deposits,
     * if the difference in stems is minimal to save on gas.
     */

    function withdrawDeposits(
        address token,
        int96[] calldata stems,
        uint256[] calldata amounts,
        LibTransfer.To mode
    ) external payable mowSender(token) nonReentrant {
        uint256 amount = _withdrawDeposits(msg.sender, token, stems, amounts);
        LibTransfer.sendToken(IERC20(token), amount, msg.sender, mode);
    }


    //////////////////////// TRANSFER ////////////////////////

    /** 
     * @notice Transfer a single Deposit.
     * @param sender Current owner of Deposit.
     * @param recipient Destination account of Deposit.
     * @param token Address of the whitelisted ERC20 token to Transfer.
     * @param stem stem of Deposit from which to Transfer.
     * @param amount Amount of `token` to Transfer.
     * @return _bdv The BDV included in this transfer, now owned by `recipient`.
     *
     * @dev An allowance is required if `sender !== msg.sender`
     * 
     * The {mowSender} modifier is not used here because _both_ the `sender` and
     * `recipient` need their Silo updated, since both accounts experience a
     * change in deposited BDV. See {Silo-_mow}.
     */
    function transferDeposit(
        address sender,
        address recipient,
        address token,
        int96 stem,
        uint256 amount
    ) public payable nonReentrant returns (uint256 _bdv) {
        if (sender != msg.sender) {
            LibSiloPermit._spendDepositAllowance(sender, msg.sender, token, amount);
        }
        LibSilo._mow(sender, token);
        // Need to update the recipient's Silo as well.
        LibSilo._mow(recipient, token);
        _bdv = _transferDeposit(sender, recipient, token, stem, amount);
    }

    /** 
     * @notice Transfers multiple Deposits.
     * @param sender Source of Deposit.
     * @param recipient Destination of Deposit.
     * @param token Address of the whitelisted ERC20 token to Transfer.
     * @param stem stem of Deposit to Transfer. 
     * @param amounts Amounts of `token` to Transfer from corresponding `stem`.
     * @return bdvs Array of BDV transferred from each Season, now owned by `recipient`.
     *
     * @dev An allowance is required if `sender !== msg.sender`. There must be enough allowance
     * to transfer all of the requested Deposits, otherwise the transaction should revert.
     * 
     * The {mowSender} modifier is not used here because _both_ the `sender` and
     * `recipient` need their Silo updated, since both accounts experience a
     * change in Seeds. See {Silo-_mow}.
     */
    function transferDeposits(
        address sender,
        address recipient,
        address token,
        int96[] calldata stem,
        uint256[] calldata amounts
    ) public payable nonReentrant returns (uint256[] memory bdvs) {
        require(amounts.length > 0, "Silo: amounts array is empty");
        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; ++i) {
            require(amounts[i] > 0, "Silo: amount in array is 0");
            totalAmount = totalAmount.add(amounts[i]);
        }

        if (sender != msg.sender) {
            LibSiloPermit._spendDepositAllowance(sender, msg.sender, token, totalAmount);
        }
       
        LibSilo._mow(sender, token);
        // Need to update the recipient's Silo as well.
        LibSilo._mow(recipient, token);
        bdvs = _transferDeposits(sender, recipient, token, stem, amounts);
    }

    

    /**
     * @notice Transfer a single Deposit, conforming to the ERC1155 standard.
     * @param sender Source of Deposit.
     * @param recipient Destination of Deposit.
     * @param depositId ID of Deposit to Transfer.
     * @param amount Amount of `token` to Transfer.
     * 
     * @dev the depositID is the token address and stem of a deposit, 
     * concatinated into a single uint256.
     * 
     */
    function safeTransferFrom(
        address sender, 
        address recipient, 
        uint256 depositId, 
        uint256 amount,
        bytes calldata
    ) external {
        require(recipient != address(0), "ERC1155: transfer to the zero address");
        // allowance requirements are checked in transferDeposit
        (address token, int96 cumulativeGrownStalkPerBDV) = 
            LibBytes.unpackAddressAndStem(depositId);
        transferDeposit(
            sender, 
            recipient,
            token, 
            cumulativeGrownStalkPerBDV, 
            amount
        );
    }

    /**
     * @notice Transfer a multiple Deposits, conforming to the ERC1155 standard.
     * @param sender Source of Deposit.
     * @param recipient Destination of Deposit.
     * @param depositIds list of ID of deposits to Transfer.
     * @param amounts list of amounts of `token` to Transfer.
     * 
     * @dev {transferDeposits} can be used to transfer multiple deposits, but only 
     * if they are all of the same token. Since the ERC1155 standard requires the abilty
     * to transfer any set of depositIDs, the {transferDeposits} function cannot be used here.
     */
    function safeBatchTransferFrom(
        address sender, 
        address recipient, 
        uint256[] calldata depositIds, 
        uint256[] calldata amounts, 
        bytes calldata
    ) external {
        require(depositIds.length == amounts.length, "Silo: depositIDs and amounts arrays must be the same length");
        require(recipient != address(0), "ERC1155: transfer to the zero address");
        // allowance requirements are checked in transferDeposit
        address token;
        int96 stem;
        for(uint i; i < depositIds.length; ++i) {
            (token, stem) = 
                LibBytes.unpackAddressAndStem(depositIds[i]);
            transferDeposit(
                sender, 
                recipient,
                token, 
                stem, 
                amounts[i]
            );
        }
    }

    //////////////////////// YIELD DISTRUBUTION ////////////////////////

    /**
     * @notice Claim Grown Stalk for `account`.
     * @dev See {Silo-_mow}.
     */
    function mow(address account, address token) external payable {
        LibSilo._mow(account, token);
    }

    //function to mow multiple tokens given an address
    function mowMultiple(address account, address[] calldata tokens) external payable {
        for (uint256 i; i < tokens.length; ++i) {
            LibSilo._mow(account, tokens[i]);
        }
    }


    /** 
     * @notice Claim Earned Beans and their associated Stalk and Plantable Seeds for
     * `msg.sender`.
     *
     * The Stalk associated with Earned Beans is commonly called "Earned Stalk".
     * Earned Stalk DOES contribute towards the Farmer's Stalk when earned beans is issued.
     * 
     * The Seeds associated with Earned Beans are commonly called "Plantable
     * Seeds". The word "Plantable" is used to highlight that these Seeds aren't 
     * yet earning the Farmer new Stalk. In other words, Seeds do NOT automatically
     * compound; they must first be Planted with {plant}.
     * 
     * In practice, when Seeds are Planted, all Earned Beans are Deposited in 
     * the current Season.
     */
    function plant() external payable returns (uint256 beans, int96 stem) {
        return _plant(msg.sender);
    }

    /** 
     * @notice Claim rewards from a Flood (Was Season of Plenty)
     */
    function claimPlenty() external payable {
        _claimPlenty(msg.sender);
    }

}


// File: contracts/beanstalk/silo/SiloFacet/TokenSilo.sol
/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity =0.7.6;
pragma abicoder v2;

import "./Silo.sol";

/**
 * @title TokenSilo
 * @author Publius, Brean, Pizzaman1337
 * @notice This contract contains functions for depositing, withdrawing and
 * claiming whitelisted Silo tokens.
 *
 * "Removing a Deposit" only removes from the `account`; the total amount
 * deposited in the Silo is decremented during withdrawal, _after_ a Withdrawal
 * is created. See "Finish Removal".
 */
contract TokenSilo is Silo {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using LibSafeMath32 for uint32;

    /**
     * @notice Emitted when `account` adds a single Deposit to the Silo.
     *
     * There is no "AddDeposits" event because there is currently no operation in which Beanstalk
     * creates multiple Deposits in different stems:
     *
     *  - `deposit()` always places the user's deposit in the current season.
     *  - `convert()` collapses multiple deposits into a single Season to prevent loss of Stalk.
     *
     * @param account The account that added a Deposit.
     * @param token Address of the whitelisted ERC20 token that was deposited.
     * @param stem The stem index that this `amount` was added to.
     * @param amount Amount of `token` added to `stem`.
     * @param bdv The BDV associated with `amount` of `token` at the time of Deposit.
     */
    event AddDeposit(
        address indexed account,
        address indexed token,
        int96 stem,
        uint256 amount,
        uint256 bdv
    );

    /**
     * @notice Emitted when `account` removes a single Deposit from the Silo.
     *
     * Occurs during `withdraw()` and `convert()` operations.
     *
     * @param account The account that removed a Deposit.
     * @param token Address of the whitelisted ERC20 token that was removed.
     * @param stem The stem that this `amount` was removed from.
     * @param amount Amount of `token` removed from `stem`.
     */
    event RemoveDeposit(
        address indexed account,
        address indexed token,
        int96 stem,
        uint256 amount,
        uint256 bdv
    );

    /**
     * @notice Emitted when `account` removes multiple Deposits from the Silo.
     * Occurs during `withdraw()` and `convert()` operations.
     * Gas optimization: emit 1 `RemoveDeposits` instead of N `RemoveDeposit` events.
     *
     * @param account The account that removed Deposits.
     * @param token Address of the whitelisted ERC20 token that was removed.
     * @param stems stems of Deposit to remove from.
     * @param amounts Amounts of `token` to remove from corresponding `stems`.
     * @param amount Sum of `amounts`.
     */
    event RemoveDeposits(
        address indexed account,
        address indexed token,
        int96[] stems,
        uint256[] amounts,
        uint256 amount,
        uint256[] bdvs
    );

    // ERC1155 events

    /**
     * @notice Emitted when a Deposit is created, removed, or transferred.
     *
     * @param operator the address that performed the operation.
     * @param from the address the Deposit is being transferred from.
     * @param to the address the Deposit is being transferred to.
     * @param id the depositID of the Deposit.
     * @param value the amount of the Deposit.
     */
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    /**
     * @notice Emitted when multiple deposits are withdrawn or transferred.
     *
     * @dev This event is emitted in `convert()`
     *
     * @param operator the address that performed the operation.
     * @param from the address the Deposit is being transferred from.
     * @param to the address the Deposit is being transferred to.
     * @param ids the depositIDs of the Deposit.
     * @param values the amounts of the Deposit.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    //////////////////////// DEPOSIT ////////////////////////

    /**
     * @dev Handle deposit accounting.
     *
     * - {LibTokenSilo.deposit} calculates BDV, adds a Deposit to `account`, and
     *   increments the total amount Deposited.
     * - {LibSilo.mintStalk} mints the Stalk associated with
     *   the Deposit.
     *
     * This step should enforce that new Deposits are placed into the current
     * `LibTokenSilo.stemTipForToken(token)`.
     */
    function _deposit(
        address account,
        address token,
        uint256 amount
    ) internal returns (uint256 stalk, int96 stem) {
        LibGerminate.Germinate germ;
        (stalk, germ) = LibTokenSilo.deposit(
            account,
            token,
            stem = LibTokenSilo.stemTipForToken(token),
            amount
        );
        LibSilo.mintGerminatingStalk(account, stalk.toUint128(), germ);
    }

    //////////////////////// WITHDRAW ////////////////////////

    /**
     * @notice Handles withdraw accounting.
     *
     * - {LibSilo._removeDepositFromAccount} calculates the stalk
     * assoicated with a given deposit, and removes the deposit from the account.
     * emits `RemoveDeposit` and `TransferSingle` events.
     *
     * - {_withdraw} updates the total value deposited in the silo, and burns
     * the stalk assoicated with the deposits.
     *
     */
    function _withdrawDeposit(address account, address token, int96 stem, uint256 amount) internal {
        // Remove the Deposit from `account`.
        (
            uint256 initialStalkRemoved, 
            uint256 grownStalkRemoved, 
            uint256 bdvRemoved, 
            LibGerminate.Germinate germinate
        ) = LibSilo._removeDepositFromAccount(
                account,
                token,
                stem,
                amount,
                LibTokenSilo.Transfer.emitTransferSingle
            );
        if (germinate == LibGerminate.Germinate.NOT_GERMINATING) {
            // remove the deposit from totals
            _withdraw(account, token, amount, bdvRemoved, initialStalkRemoved.add(grownStalkRemoved));
        } else {
            // remove deposit from germination, and burn the grown stalk.
            // grown stalk does not germinate and is not counted in germinating totals.
            _withdrawGerminating(
                account,
                token,
                amount,
                bdvRemoved,
                initialStalkRemoved,
                germinate
            );

            if (grownStalkRemoved > 0) {
                LibSilo.burnActiveStalk(
                    account, 
                    grownStalkRemoved
                ); 
            }
        }
    }

    /**
     * @notice Handles withdraw accounting for multiple deposits.
     *
     * - {LibSilo._removeDepositsFromAccount} removes the deposits from the account,
     * and returns the total tokens, stalk, and bdv removed from the account.
     *
     * - {_withdraw} updates the total value deposited in the silo, and burns
     * the stalk assoicated with the deposits.
     *
     */
    function _withdrawDeposits(
        address account,
        address token,
        int96[] calldata stems,
        uint256[] calldata amounts
    ) internal returns (uint256) {
        require(stems.length == amounts.length, "Silo: Crates, amounts are diff lengths.");

        LibSilo.AssetsRemoved memory ar = LibSilo._removeDepositsFromAccount(
            account,
            token,
            stems,
            amounts,
            LibSilo.ERC1155Event.EMIT_BATCH_EVENT
        );

        // withdraw deposits that are not germinating.
        if (ar.active.tokens > 0) {
            _withdraw(account, token, ar.active.tokens, ar.active.bdv, ar.active.stalk);
        }
       
        // withdraw Germinating deposits from odd seasons
        if (ar.odd.tokens > 0) {
            _withdrawGerminating(
                account,
                token,
                ar.odd.tokens,
                ar.odd.bdv,
                ar.odd.stalk,
                LibGerminate.Germinate.ODD
            );
        }

        // withdraw Germinating deposits from even seasons
        if (ar.even.tokens > 0) {
            _withdrawGerminating(
                account,
                token,
                ar.even.tokens,
                ar.even.bdv,
                ar.even.stalk,
                LibGerminate.Germinate.EVEN
            );
        }

        if (ar.grownStalkFromGermDeposits > 0) {
            LibSilo.burnActiveStalk(
                account, 
                ar.grownStalkFromGermDeposits
            ); 
        }

        // we return the summation of all tokens removed from the silo.
        // to be used in {SiloFacet.withdrawDeposits}.
        return ar.active.tokens.add(ar.odd.tokens).add(ar.even.tokens);
    }

    /**
     * @dev internal helper function for withdraw accounting.
     */
    function _withdraw(
        address account,
        address token,
        uint256 amount,
        uint256 bdv,
        uint256 stalk
    ) private {
        // Decrement total deposited in the silo.
        LibTokenSilo.decrementTotalDeposited(token, amount, bdv);
        // Burn stalk and roots associated with the stalk.
        LibSilo.burnActiveStalk(account, stalk); 
    }

    /**
     * @dev internal helper function for withdraw accounting with germination.
     * @param germinateState determines whether to withdraw from odd or even germination.
     */
    function _withdrawGerminating(
        address account,
        address token,
        uint256 amount,
        uint256 bdv,
        uint256 stalk,
        LibGerminate.Germinate germinateState
    ) private {
        // Deposited Earned Beans do not germinate. Thus, when withdrawing a Bean Deposit
        // with a Germinating Stem, Beanstalk needs to determine how many of the Beans
        // were Planted vs Deposited from a Circulating/Farm balance. 
        // If a Farmer's Germinating Stalk for a given Season is less than the number of 
        // Deposited Beans in that Season, then it is assumed that the excess Beans were
        // Planted.
        if (token == C.BEAN) {
            (uint256 germinatingStalk, uint256 earnedBeansStalk) = LibSilo.checkForEarnedBeans(account, stalk, germinateState);
            // set the bdv and amount accordingly to the stalk. 
            stalk = germinatingStalk;
            uint256 earnedBeans = earnedBeansStalk.div(C.STALK_PER_BEAN);

            amount = amount.sub(earnedBeans);
            // note: the 1 Bean = 1 BDV assumption cannot be made here for input `bdv`, 
            // as a user converting a germinating LP deposit into bean may have an inflated bdv.
            // thus, amount and bdv are decremented by the earnedBeans (where the 1 Bean = 1 BDV assumption can be made).
            bdv = bdv.sub(earnedBeans);

            // burn the earned bean stalk (which is active).
            LibSilo.burnActiveStalk(account,  earnedBeansStalk);
            // calculate earnedBeans and decrement totalDeposited.
            LibTokenSilo.decrementTotalDeposited(C.BEAN, earnedBeans, earnedBeans);
        }
        // Decrement from total germinating.
        LibTokenSilo.decrementTotalGerminating(token, amount, bdv, germinateState); // Decrement total Germinating in the silo.
        LibSilo.burnGerminatingStalk(account, stalk.toUint128(), germinateState); // Burn stalk and roots associated with the stalk.
    }

    //////////////////////// TRANSFER ////////////////////////

    /**
     * @notice Intenral transfer logic accounting.
     *
     * @dev Removes `amount` of a single Deposit from `sender` and transfers
     * it to `recipient`. No Stalk are burned, and the total amount of
     * Deposited `token` in the Silo doesn't change.
     */
    function _transferDeposit(
        address sender,
        address recipient,
        address token,
        int96 stem,
        uint256 amount
    ) internal returns (uint256) {
        (
            uint256 initialStalk,
            uint256 activeStalk,
            uint256 bdv,
            LibGerminate.Germinate germ
        ) = LibSilo._removeDepositFromAccount(
                sender,
                token,
                stem,
                amount,
                LibTokenSilo.Transfer.noEmitTransferSingle
            );
        LibTokenSilo.addDepositToAccount(
            recipient,
            token,
            stem,
            amount,
            bdv,
            LibTokenSilo.Transfer.noEmitTransferSingle
        );

        if (germ == LibGerminate.Germinate.NOT_GERMINATING) {
            LibSilo.transferStalk(sender, recipient, initialStalk.add(activeStalk));
        } else {
            if (token == C.BEAN) {
                (uint256 senderGerminatingStalk, uint256 senderEarnedBeansStalk) = LibSilo.checkForEarnedBeans(sender, initialStalk, germ);
                // if initial stalk is greater than the sender's germinating stalk, then the sender is sending an 
                // Earned Bean Deposit. The active stalk is incremented and the
                // initial stalk is decremented by the sender's earnedBeansStalk.
                if(senderEarnedBeansStalk > 0) {
                    activeStalk = activeStalk.add(senderEarnedBeansStalk);
                    initialStalk = senderGerminatingStalk;
                }
            }
            LibSilo.transferGerminatingStalk(sender, recipient, initialStalk, germ);
            // a germinating deposit may have grown stalk, or in the case of a Earned Bean Deposit,
            // active stalk will need to be transferred.
            if (activeStalk > 0) {
                LibSilo.transferStalk(
                    sender,
                    recipient, 
                    activeStalk
                ); 
            }
        }

        /**
         * the current beanstalk system uses {AddDeposit}
         * and {RemoveDeposit} events to represent a transfer.
         * However, the ERC1155 standard has a dedicated {TransferSingle} event,
         * which is used here.
         */
        emit TransferSingle(
            msg.sender,
            sender,
            recipient,
            LibBytes.packAddressAndStem(token, stem),
            amount
        );

        return bdv;
    }

    /**
     * @notice Intenral transfer logic accounting for multiple deposits.
     *
     * @dev Removes `amounts` of multiple Deposits from `sender` and transfers
     * them to `recipient`. No Stalk are burned, and the total amount of
     * Deposited `token` in the Silo doesn't change.
     */
    function _transferDeposits(
        address sender,
        address recipient,
        address token,
        int96[] calldata stems,
        uint256[] calldata amounts
    ) internal returns (uint256[] memory) {
        require(stems.length == amounts.length, "Silo: Crates, amounts are diff lengths.");

        LibSilo.AssetsRemoved memory ar;
        uint256[] memory bdvs = new uint256[](stems.length);
        uint256[] memory removedDepositIDs = new uint256[](stems.length);

        // get the germinating stem for the token
        LibGerminate.GermStem memory germStem = LibGerminate.getGerminatingStem(token);
        // Similar to {removeDepositsFromAccount}, however the Deposit is also
        // added to the recipient's account during each iteration.
        for (uint256 i; i < stems.length; ++i) {
            LibGerminate.Germinate germ = LibGerminate._getGerminationState(
                stems[i],
                germStem
            );
            uint256 crateBdv = LibTokenSilo.removeDepositFromAccount(
                sender,
                token,
                stems[i],
                amounts[i]
            );
            LibTokenSilo.addDepositToAccount(
                recipient,
                token,
                stems[i],
                amounts[i],
                crateBdv,
                LibTokenSilo.Transfer.noEmitTransferSingle
            );
            uint256 crateStalk = LibSilo.stalkReward(
                stems[i],
                germStem.stemTip,
                crateBdv.toUint128()
            );

            // if the deposit is germinating, increment germinating bdv and stalk,
            // otherwise increment deposited values.
            ar.active.tokens = ar.active.tokens.add(amounts[i]);
            if (germ == LibGerminate.Germinate.NOT_GERMINATING) {
                ar.active.bdv = ar.active.bdv.add(crateBdv);
                ar.active.stalk = ar.active.stalk.add(crateStalk);
            } else {
                if (germ == LibGerminate.Germinate.ODD) {
                    ar.odd.bdv = ar.odd.bdv.add(crateBdv);
                    ar.odd.stalk = ar.odd.stalk.add(crateStalk);
                } else {
                    ar.even.bdv = ar.even.bdv.add(crateBdv);
                    ar.even.stalk = ar.even.stalk.add(crateStalk);
                }
            }
            bdvs[i] = crateBdv;
            removedDepositIDs[i] = uint256(LibBytes.packAddressAndStem(token, stems[i]));
        }

        // transfer regular and germinating stalk (if appliable)
        LibSilo.transferStalkAndGerminatingStalk(sender, recipient, token, ar);

        /**
         *  The current beanstalk system uses a mix of {AddDeposit}
         *  and {RemoveDeposits} events to represent a batch transfer.
         *  However, the ERC1155 standard has a dedicated {batchTransfer} event,
         *  which is used here.
         */
        emit LibSilo.TransferBatch(msg.sender, sender, recipient, removedDepositIDs, amounts);
        // emit RemoveDeposits event (tokens removed are summation).
        emit RemoveDeposits(
            sender,
            token,
            stems, 
            amounts,
            ar.active.tokens, 
            bdvs
        );

        return bdvs;
    }

}


// File: contracts/C.sol
// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "./interfaces/IBean.sol";
import "./interfaces/ICurve.sol";
import "./interfaces/IFertilizer.sol";
import "./interfaces/IProxyAdmin.sol";
import "./libraries/Decimal.sol";

/**
 * @title C
 * @author Publius
 * @notice Contains constants used throughout Beanstalk.
 */
library C {
    using Decimal for Decimal.D256;
    using SafeMath for uint256;

    //////////////////// Globals ////////////////////

    uint256 internal constant PRECISION = 1e18;
    uint256 private constant CHAIN_ID = 1;
    bytes constant BYTES_ZERO = new bytes(0);

    /// @dev The block time for the chain in seconds.
    uint256 internal constant BLOCK_LENGTH_SECONDS = 12;

    //////////////////// Season ////////////////////

    /// @dev The length of a Season meaured in seconds.
    uint256 private constant CURRENT_SEASON_PERIOD = 3600; // 1 hour
    uint256 internal constant SOP_PRECISION = 1e24;

    //////////////////// Silo ////////////////////

    uint256 internal constant SEEDS_PER_BEAN = 2;
    uint256 internal constant STALK_PER_BEAN = 10000;
    uint256 private constant ROOTS_BASE = 1e12;

    //////////////////// Exploit Migration ////////////////////

    uint256 private constant UNRIPE_LP_PER_DOLLAR = 1884592; // 145_113_507_403_282 / 77_000_000
    uint256 private constant ADD_LP_RATIO = 866616;
    uint256 private constant INITIAL_HAIRCUT = 185564685220298701;

    //////////////////// Contracts ////////////////////

    address internal constant BEAN = 0xBEA0000029AD1c77D3d5D23Ba2D8893dB9d1Efab;
    address internal constant CURVE_BEAN_METAPOOL = 0xc9C32cd16Bf7eFB85Ff14e0c8603cc90F6F2eE49;

    address internal constant UNRIPE_BEAN = 0x1BEA0050E63e05FBb5D8BA2f10cf5800B6224449;
    address internal constant UNRIPE_LP = 0x1BEA3CcD22F4EBd3d37d731BA31Eeca95713716D;

    address private constant CURVE_3_POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address private constant THREE_CRV = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;

    address private constant FERTILIZER = 0x402c84De2Ce49aF88f5e2eF3710ff89bFED36cB6;
    address private constant FERTILIZER_ADMIN = 0xfECB01359263C12Aa9eD838F878A596F0064aa6e;

    address private constant TRI_CRYPTO = 0xc4AD29ba4B3c580e6D59105FFf484999997675Ff;
    address private constant TRI_CRYPTO_POOL = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46;
    address private constant CURVE_ZAP = 0xA79828DF1850E8a3A3064576f380D90aECDD3359;

    address private constant UNRIPE_CURVE_BEAN_LUSD_POOL = 0xD652c40fBb3f06d6B58Cb9aa9CFF063eE63d465D;
    address private constant UNRIPE_CURVE_BEAN_METAPOOL = 0x3a70DfA7d2262988064A2D051dd47521E43c9BdD;

    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant UNIV3_ETH_USDC_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // 0.05% pool
    address internal constant UNIV3_ETH_USDT_POOL = 0x11b815efB8f581194ae79006d24E0d814B7697F6; // 0.05% pool

    // Use external contract for block.basefee as to avoid upgrading existing contracts to solidity v8
    address private constant BASE_FEE_CONTRACT = 0x84292919cB64b590C0131550483707E43Ef223aC;

    //////////////////// Well ////////////////////

    uint256 internal constant WELL_MINIMUM_BEAN_BALANCE = 1000_000_000; // 1,000 Beans
    address internal constant BEANSTALK_PUMP = 0xBA510f10E3095B83a0F33aa9ad2544E22570a87C;
    address internal constant BEAN_ETH_WELL = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd;
    // The index of the Bean and Weth token addresses in all BEAN/ETH Wells.
    uint256 internal constant BEAN_INDEX = 0;
    uint256 internal constant ETH_INDEX = 1;

    function getSeasonPeriod() internal pure returns (uint256) {
        return CURRENT_SEASON_PERIOD;
    }

    function getBlockLengthSeconds() internal pure returns (uint256) {
        return BLOCK_LENGTH_SECONDS;
    }

    function getChainId() internal pure returns (uint256) {
        return CHAIN_ID;
    }

    function getSeedsPerBean() internal pure returns (uint256) {
        return SEEDS_PER_BEAN;
    }

    function getStalkPerBean() internal pure returns (uint256) {
      return STALK_PER_BEAN;
    }

    function getRootsBase() internal pure returns (uint256) {
        return ROOTS_BASE;
    }

    /**
     * @dev The pre-exploit BEAN:3CRV Curve metapool address.
     */
    function unripeLPPool1() internal pure returns (address) {
        return UNRIPE_CURVE_BEAN_METAPOOL;
    }

    /**
     * @dev The pre-exploit BEAN:LUSD Curve plain pool address.
     */
    function unripeLPPool2() internal pure returns (address) {
        return UNRIPE_CURVE_BEAN_LUSD_POOL;
    }

    function unripeBean() internal pure returns (IERC20) {
        return IERC20(UNRIPE_BEAN);
    }

    function unripeLP() internal pure returns (IERC20) {
        return IERC20(UNRIPE_LP);
    }

    function bean() internal pure returns (IBean) {
        return IBean(BEAN);
    }

    function usdc() internal pure returns (IERC20) {
        return IERC20(USDC);
    }

    function curveMetapool() internal pure returns (ICurvePool) {
        return ICurvePool(CURVE_BEAN_METAPOOL);
    }

    function curve3Pool() internal pure returns (I3Curve) {
        return I3Curve(CURVE_3_POOL);
    }
    
    function curveZap() internal pure returns (ICurveZap) {
        return ICurveZap(CURVE_ZAP);
    }

    function curveZapAddress() internal pure returns (address) {
        return CURVE_ZAP;
    }

    function curve3PoolAddress() internal pure returns (address) {
        return CURVE_3_POOL;
    }

    function threeCrv() internal pure returns (IERC20) {
        return IERC20(THREE_CRV);
    }

    function UniV3EthUsdc() internal pure returns (address){
        return UNIV3_ETH_USDC_POOL;
    }

    function fertilizer() internal pure returns (IFertilizer) {
        return IFertilizer(FERTILIZER);
    }

    function fertilizerAddress() internal pure returns (address) {
        return FERTILIZER;
    }

    function fertilizerAdmin() internal pure returns (IProxyAdmin) {
        return IProxyAdmin(FERTILIZER_ADMIN);
    }

    function triCryptoPoolAddress() internal pure returns (address) {
        return TRI_CRYPTO_POOL;
    }

    function triCrypto() internal pure returns (IERC20) {
        return IERC20(TRI_CRYPTO);
    }

    function unripeLPPerDollar() internal pure returns (uint256) {
        return UNRIPE_LP_PER_DOLLAR;
    }

    function dollarPerUnripeLP() internal pure returns (uint256) {
        return 1e12/UNRIPE_LP_PER_DOLLAR;
    }

    function exploitAddLPRatio() internal pure returns (uint256) {
        return ADD_LP_RATIO;
    }

    function precision() internal pure returns (uint256) {
        return PRECISION;
    }

    function initialRecap() internal pure returns (uint256) {
        return INITIAL_HAIRCUT;
    }

}

// File: contracts/interfaces/basin/IWell.sol
// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Call is the struct that contains the target address and extra calldata of a generic call.
 */
struct Call {
    address target; // The address the call is executed on.
    bytes data; // Extra calldata to be passed during the call
}

/**
 * @title IWell is the interface for the Well contract.
 *
 * In order for a Well to be verified using a permissionless on-chain registry, a Well Implementation should:
 * - Not be able to self-destruct (Aquifer's registry would be vulnerable to a metamorphic contract attack)
 * - Not be able to change its tokens, Well Function, Pumps and Well Data
 */
interface IWell {
    /**
     * @notice Emitted when a Swap occurs.
     * @param fromToken The token swapped from
     * @param toToken The token swapped to
     * @param amountIn The amount of `fromToken` transferred into the Well
     * @param amountOut The amount of `toToken` transferred out of the Well
     * @param recipient The address that received `toToken`
     */
    event Swap(IERC20 fromToken, IERC20 toToken, uint256 amountIn, uint256 amountOut, address recipient);

    /**
     * @notice Emitted when liquidity is added to the Well.
     * @param tokenAmountsIn The amount of each token added to the Well
     * @param lpAmountOut The amount of LP tokens minted
     * @param recipient The address that received the LP tokens
     */
    event AddLiquidity(uint256[] tokenAmountsIn, uint256 lpAmountOut, address recipient);

    /**
     * @notice Emitted when liquidity is removed from the Well as multiple underlying tokens.
     * @param lpAmountIn The amount of LP tokens burned
     * @param tokenAmountsOut The amount of each underlying token removed
     * @param recipient The address that received the underlying tokens
     * @dev Gas cost scales with `n` tokens.
     */
    event RemoveLiquidity(uint256 lpAmountIn, uint256[] tokenAmountsOut, address recipient);

    /**
     * @notice Emitted when liquidity is removed from the Well as a single underlying token.
     * @param lpAmountIn The amount of LP tokens burned
     * @param tokenOut The underlying token removed
     * @param tokenAmountOut The amount of `tokenOut` removed
     * @param recipient The address that received the underlying tokens
     * @dev Emitting a separate event when removing liquidity as a single token
     * saves gas, since `tokenAmountsOut` in {RemoveLiquidity} must emit a value
     * for each token in the Well.
     */
    event RemoveLiquidityOneToken(uint256 lpAmountIn, IERC20 tokenOut, uint256 tokenAmountOut, address recipient);

    /**
     * @notice Emitted when a Shift occurs.
     * @param reserves The ending reserves after a shift
     * @param toToken The token swapped to
     * @param amountOut The amount of `toToken` transferred out of the Well
     * @param recipient The address that received `toToken`
     */
    event Shift(uint256[] reserves, IERC20 toToken, uint256 amountOut, address recipient);

    /**
     * @notice Emitted when a Sync occurs.
     * @param reserves The ending reserves after a sync
     * @param lpAmountOut The amount of LP tokens received from the sync.
     * @param recipient The address that received the LP tokens
     */
    event Sync(uint256[] reserves, uint256 lpAmountOut, address recipient);

    //////////////////// WELL DEFINITION ////////////////////

    /**
     * @notice Returns a list of ERC20 tokens supported by the Well.
     */
    function tokens() external view returns (IERC20[] memory);

    /**
     * @notice Returns the Well function as a Call struct.
     * @dev Contains the address of the Well function contract and extra data to
     * pass during calls.
     *
     * **Well functions** define a relationship between the reserves of the
     * tokens in the Well and the number of LP tokens.
     *
     * A Well function MUST implement {IWellFunction}.
     */
    function wellFunction() external view returns (Call memory);

    /**
     * @notice Returns the Pumps attached to the Well as Call structs.
     * @dev Contains the addresses of the Pumps contract and extra data to pass
     * during calls.
     *
     * **Pumps** are on-chain oracles that are updated every time the Well is
     * interacted with.
     *
     * A Pump is not required for Well operation. For Wells without a Pump:
     * `pumps().length = 0`.
     *
     * An attached Pump MUST implement {IPump}.
     */
    function pumps() external view returns (Call[] memory);

    /**
     * @notice Returns the Well data that the Well was bored with.
     * @dev The existence and signature of Well data is determined by each individual implementation.
     */
    function wellData() external view returns (bytes memory);

    /**
     * @notice Returns the Aquifer that created this Well.
     * @dev Wells can be permissionlessly bored in an Aquifer.
     *
     * Aquifers stores the implementation that was used to bore the Well.
     */
    function aquifer() external view returns (address);

    /**
     * @notice Returns the tokens, Well Function, Pumps and Well Data associated
     * with the Well as well as the Aquifer that deployed the Well.
     */
    function well()
        external
        view
        returns (
            IERC20[] memory _tokens,
            Call memory _wellFunction,
            Call[] memory _pumps,
            bytes memory _wellData,
            address _aquifer
        );

    //////////////////// SWAP: FROM ////////////////////

    /**
     * @notice Swaps from an exact amount of `fromToken` to a minimum amount of `toToken`.
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param amountIn The amount of `fromToken` to spend
     * @param minAmountOut The minimum amount of `toToken` to receive
     * @param recipient The address to receive `toToken`
     * @param deadline The timestamp after which this operation is invalid
     * @return amountOut The amount of `toToken` received
     */
    function swapFrom(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /**
     * @notice Swaps from an exact amount of `fromToken` to a minimum amount of `toToken` and supports fee on transfer tokens.
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param amountIn The amount of `fromToken` to spend
     * @param minAmountOut The minimum amount of `toToken` to take from the Well. Note that if `toToken` charges a fee on transfer, `recipient` will receive less than this amount.
     * @param recipient The address to receive `toToken`
     * @param deadline The timestamp after which this operation is invalid
     * @return amountOut The amount of `toToken` transferred from the Well. Note that if `toToken` charges a fee on transfer, `recipient` may receive less than this amount.
     * @dev Can also be used for tokens without a fee on transfer, but is less gas efficient.
     */
    function swapFromFeeOnTransfer(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /**
     * @notice Gets the amount of one token received for swapping an amount of another token.
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param amountIn The amount of `fromToken` to spend
     * @return amountOut The amount of `toToken` to receive
     */
    function getSwapOut(IERC20 fromToken, IERC20 toToken, uint256 amountIn) external view returns (uint256 amountOut);

    //////////////////// SWAP: TO ////////////////////

    /**
     * @notice Swaps from a maximum amount of `fromToken` to an exact amount of `toToken`.
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param maxAmountIn The maximum amount of `fromToken` to spend
     * @param amountOut The amount of `toToken` to receive
     * @param recipient The address to receive `toToken`
     * @param deadline The timestamp after which this operation is invalid
     * @return amountIn The amount of `toToken` received
     */
    function swapTo(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 maxAmountIn,
        uint256 amountOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountIn);

    /**
     * @notice Gets the amount of one token that must be spent to receive an amount of another token during a swap.
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param amountOut The amount of `toToken` desired
     * @return amountIn The amount of `fromToken` that must be spent
     */
    function getSwapIn(IERC20 fromToken, IERC20 toToken, uint256 amountOut) external view returns (uint256 amountIn);

    //////////////////// SHIFT ////////////////////

    /**
     * @notice Shifts at least `minAmountOut` excess tokens held by the Well into `tokenOut` and delivers to `recipient`.
     * @param tokenOut The token to shift into
     * @param minAmountOut The minimum amount of `tokenOut` to receive
     * @param recipient The address to receive the token
     * @return amountOut The amount of `tokenOut` received
     * @dev Can be used in a multicall using a contract like Pipeline to perform gas efficient swaps.
     * No deadline is needed since this function does not use the user's assets. If adding liquidity in a multicall,
     * then a deadline check can be added to the multicall.
     */
    function shift(IERC20 tokenOut, uint256 minAmountOut, address recipient) external returns (uint256 amountOut);

    /**
     * @notice Calculates the amount of the token out received from shifting excess tokens held by the Well.
     * @param tokenOut The token to shift into
     * @return amountOut The amount of `tokenOut` received
     */
    function getShiftOut(IERC20 tokenOut) external returns (uint256 amountOut);

    //////////////////// ADD LIQUIDITY ////////////////////

    /**
     * @notice Adds liquidity to the Well as multiple tokens in any ratio.
     * @param tokenAmountsIn The amount of each token to add; MUST match the indexing of {Well.tokens}
     * @param minLpAmountOut The minimum amount of LP tokens to receive
     * @param recipient The address to receive the LP tokens
     * @param deadline The timestamp after which this operation is invalid
     * @return lpAmountOut The amount of LP tokens received
     */
    function addLiquidity(
        uint256[] memory tokenAmountsIn,
        uint256 minLpAmountOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 lpAmountOut);

    /**
     * @notice Adds liquidity to the Well as multiple tokens in any ratio and supports
     * fee on transfer tokens.
     * @param tokenAmountsIn The amount of each token to add; MUST match the indexing of {Well.tokens}
     * @param minLpAmountOut The minimum amount of LP tokens to receive
     * @param recipient The address to receive the LP tokens
     * @param deadline The timestamp after which this operation is invalid
     * @return lpAmountOut The amount of LP tokens received
     * @dev Can also be used for tokens without a fee on transfer, but is less gas efficient.
     */
    function addLiquidityFeeOnTransfer(
        uint256[] memory tokenAmountsIn,
        uint256 minLpAmountOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 lpAmountOut);

    /**
     * @notice Gets the amount of LP tokens received from adding liquidity as multiple tokens in any ratio.
     * @param tokenAmountsIn The amount of each token to add; MUST match the indexing of {Well.tokens}
     * @return lpAmountOut The amount of LP tokens received
     */
    function getAddLiquidityOut(uint256[] memory tokenAmountsIn) external view returns (uint256 lpAmountOut);

    //////////////////// REMOVE LIQUIDITY: BALANCED ////////////////////

    /**
     * @notice Removes liquidity from the Well as all underlying tokens in a balanced ratio.
     * @param lpAmountIn The amount of LP tokens to burn
     * @param minTokenAmountsOut The minimum amount of each underlying token to receive; MUST match the indexing of {Well.tokens}
     * @param recipient The address to receive the underlying tokens
     * @param deadline The timestamp after which this operation is invalid
     * @return tokenAmountsOut The amount of each underlying token received
     */
    function removeLiquidity(
        uint256 lpAmountIn,
        uint256[] calldata minTokenAmountsOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory tokenAmountsOut);

    /**
     * @notice Gets the amount of each underlying token received from removing liquidity in a balanced ratio.
     * @param lpAmountIn The amount of LP tokens to burn
     * @return tokenAmountsOut The amount of each underlying token received
     */
    function getRemoveLiquidityOut(uint256 lpAmountIn) external view returns (uint256[] memory tokenAmountsOut);

    //////////////////// REMOVE LIQUIDITY: ONE TOKEN ////////////////////

    /**
     * @notice Removes liquidity from the Well as a single underlying token.
     * @param lpAmountIn The amount of LP tokens to burn
     * @param tokenOut The underlying token to receive
     * @param minTokenAmountOut The minimum amount of `tokenOut` to receive
     * @param recipient The address to receive the underlying tokens
     * @param deadline The timestamp after which this operation is invalid
     * @return tokenAmountOut The amount of `tokenOut` received
     */
    function removeLiquidityOneToken(
        uint256 lpAmountIn,
        IERC20 tokenOut,
        uint256 minTokenAmountOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 tokenAmountOut);

    /**
     * @notice Gets the amount received from removing liquidity from the Well as a single underlying token.
     * @param lpAmountIn The amount of LP tokens to burn
     * @param tokenOut The underlying token to receive
     * @return tokenAmountOut The amount of `tokenOut` received
     *
     */
    function getRemoveLiquidityOneTokenOut(
        uint256 lpAmountIn,
        IERC20 tokenOut
    ) external view returns (uint256 tokenAmountOut);

    //////////////////// REMOVE LIQUIDITY: IMBALANCED ////////////////////

    /**
     * @notice Removes liquidity from the Well as multiple underlying tokens in any ratio.
     * @param maxLpAmountIn The maximum amount of LP tokens to burn
     * @param tokenAmountsOut The amount of each underlying token to receive; MUST match the indexing of {Well.tokens}
     * @param recipient The address to receive the underlying tokens
     * @return lpAmountIn The amount of LP tokens burned
     */
    function removeLiquidityImbalanced(
        uint256 maxLpAmountIn,
        uint256[] calldata tokenAmountsOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 lpAmountIn);

    /**
     * @notice Gets the amount of LP tokens to burn from removing liquidity as multiple underlying tokens in any ratio.
     * @param tokenAmountsOut The amount of each underlying token to receive; MUST match the indexing of {Well.tokens}
     * @return lpAmountIn The amount of LP tokens burned
     */
    function getRemoveLiquidityImbalancedIn(uint256[] calldata tokenAmountsOut)
        external
        view
        returns (uint256 lpAmountIn);

    //////////////////// RESERVES ////////////////////

    /**
     * @notice Syncs the Well's reserves with the Well's balances of underlying tokens. If the reserves
     * increase, mints at least `minLpAmountOut` LP Tokens to `recipient`.
     * @param recipient The address to receive the LP tokens
     * @param minLpAmountOut The minimum amount of LP tokens to receive
     * @return lpAmountOut The amount of LP tokens received
     * @dev Can be used in a multicall using a contract like Pipeline to perform gas efficient additions of liquidity.
     * No deadline is needed since this function does not use the user's assets. If adding liquidity in a multicall,
     * then a deadline check can be added to the multicall.
     * If `sync` decreases the Well's reserves, then no LP tokens are minted and `lpAmountOut` must be 0.
     */
    function sync(address recipient, uint256 minLpAmountOut) external returns (uint256 lpAmountOut);

    /**
     * @notice Calculates the amount of LP Tokens received from syncing the Well's reserves with the Well's balances.
     * @return lpAmountOut The amount of LP tokens received
     */
    function getSyncOut() external view returns (uint256 lpAmountOut);

    /**
     * @notice Sends excess tokens held by the Well to the `recipient`.
     * @param recipient The address to send the tokens
     * @return skimAmounts The amount of each token skimmed
     * @dev No deadline is needed since this function does not use the user's assets.
     */
    function skim(address recipient) external returns (uint256[] memory skimAmounts);

    /**
     * @notice Gets the reserves of each token held by the Well.
     */
    function getReserves() external view returns (uint256[] memory reserves);

    /**
     * @notice Returns whether or not the Well is initialized if it requires initialization.
     * If a Well does not require initialization, it should always return `true`.
     */
    function isInitialized() external view returns (bool);
}

// File: contracts/interfaces/IBean.sol
// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IBean
 * @author Publius
 * @notice Bean Interface
 */
abstract contract IBean is IERC20 {
    function burn(uint256 amount) public virtual;
    function burnFrom(address account, uint256 amount) public virtual;
    function mint(address account, uint256 amount) public virtual;
    function symbol() public view virtual returns (string memory);
}


// File: contracts/interfaces/ICurve.sol
// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity =0.7.6;

interface ICurvePool {
    function A_precise() external view returns (uint256);
    function get_balances() external view returns (uint256[2] memory);
    function totalSupply() external view returns (uint256);
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external returns (uint256);
    function balances(int128 i) external view returns (uint256);
    function fee() external view returns (uint256);
    function coins(uint256 i) external view returns (address);
    function get_virtual_price() external view returns (uint256);
    function calc_token_amount(uint256[2] calldata amounts, bool deposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface ICurveZap {
    function add_liquidity(address _pool, uint256[4] memory _deposit_amounts, uint256 _min_mint_amount) external returns (uint256);
    function calc_token_amount(address _pool, uint256[4] memory _amounts, bool _is_deposit) external returns (uint256);
}

interface ICurvePoolR {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy, address receiver) external returns (uint256);
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy, address receiver) external returns (uint256);
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount, address receiver) external returns (uint256);
}

interface ICurvePool2R {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount, address reciever) external returns (uint256);
    function remove_liquidity(uint256 _burn_amount, uint256[2] memory _min_amounts, address reciever) external returns (uint256[2] calldata);
    function remove_liquidity_imbalance(uint256[2] memory _amounts, uint256 _max_burn_amount, address reciever) external returns (uint256);
}

interface ICurvePool3R {
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount, address reciever) external returns (uint256);
    function remove_liquidity(uint256 _burn_amount, uint256[3] memory _min_amounts, address reciever) external returns (uint256[3] calldata);
    function remove_liquidity_imbalance(uint256[3] memory _amounts, uint256 _max_burn_amount, address reciever) external returns (uint256);
}

interface ICurvePool4R {
    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount, address reciever) external returns (uint256);
    function remove_liquidity(uint256 _burn_amount, uint256[4] memory _min_amounts, address reciever) external returns (uint256[4] calldata);
    function remove_liquidity_imbalance(uint256[4] memory _amounts, uint256 _max_burn_amount, address reciever) external returns (uint256);
}

interface I3Curve {
    function get_virtual_price() external view returns (uint256);
}

interface ICurveFactory {
    function get_coins(address _pool) external view returns (address[4] calldata);
    function get_underlying_coins(address _pool) external view returns (address[8] calldata);
}

interface ICurveCryptoFactory {
    function get_coins(address _pool) external view returns (address[8] calldata);
}

interface ICurvePoolC {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external returns (uint256);
}

interface ICurvePoolNoReturn {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external;
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external;
    function remove_liquidity(uint256 _burn_amount, uint256[3] memory _min_amounts) external;
    function remove_liquidity_imbalance(uint256[3] memory _amounts, uint256 _max_burn_amount) external;
    function remove_liquidity_one_coin(uint256 _token_amount, uint256 i, uint256 min_amount) external;
}

interface ICurvePoolNoReturn128 {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;
}


// File: contracts/interfaces/IDiamondCut.sol
// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity =0.7.6;
/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
/******************************************************************************/

interface IDiamondCut {
    enum FacetCutAction {Add, Replace, Remove}

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}


// File: contracts/interfaces/IFertilizer.sol
// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity =0.7.6;

interface IFertilizer {
    struct Balance {
        uint128 amount;
        uint128 lastBpf;
    }
    function beanstalkUpdate(
        address account,
        uint256[] memory ids,
        uint128 bpf
    ) external returns (uint256);
    function beanstalkMint(address account, uint256 id, uint128 amount, uint128 bpf) external;
    function balanceOfFertilized(address account, uint256[] memory ids) external view returns (uint256);
    function balanceOfUnfertilized(address account, uint256[] memory ids) external view returns (uint256);
    function lastBalanceOf(address account, uint256 id) external view returns (Balance memory);
    function lastBalanceOfBatch(address[] memory account, uint256[] memory id) external view returns (Balance[] memory);
    function setURI(string calldata newuri) external;
}

// File: contracts/interfaces/IProxyAdmin.sol
// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity =0.7.6;
interface IProxyAdmin {
    function upgrade(address proxy, address implementation) external;
}


// File: contracts/libraries/Decimal.sol
/*
 SPDX-License-Identifier: MIT
*/

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title Decimal
 * @author dYdX
 *
 * Library that defines a fixed-point number with 18 decimal places.
 */
library Decimal {
    using SafeMath for uint256;

    // ============ Constants ============

    uint256 constant BASE = 10**18;

    // ============ Structs ============


    struct D256 {
        uint256 value;
    }

    // ============ Static Functions ============

    function zero()
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: 0 });
    }

    function one()
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: BASE });
    }

    function from(
        uint256 a
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: a.mul(BASE) });
    }

    function ratio(
        uint256 a,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: getPartial(a, BASE, b) });
    }

    // ============ Self Functions ============

    function add(
        D256 memory self,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.add(b.mul(BASE)) });
    }

    function sub(
        D256 memory self,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.sub(b.mul(BASE)) });
    }

    function sub(
        D256 memory self,
        uint256 b,
        string memory reason
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.sub(b.mul(BASE), reason) });
    }

    function mul(
        D256 memory self,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.mul(b) });
    }

    function div(
        D256 memory self,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.div(b) });
    }

    function pow(
        D256 memory self,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        if (b == 0) {
            return one();
        }

        D256 memory temp = D256({ value: self.value });
        for (uint256 i = 1; i < b; ++i) {
            temp = mul(temp, self);
        }

        return temp;
    }

    function add(
        D256 memory self,
        D256 memory b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.add(b.value) });
    }

    function sub(
        D256 memory self,
        D256 memory b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.sub(b.value) });
    }

    function sub(
        D256 memory self,
        D256 memory b,
        string memory reason
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.sub(b.value, reason) });
    }

    function mul(
        D256 memory self,
        D256 memory b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: getPartial(self.value, b.value, BASE) });
    }

    function div(
        D256 memory self,
        D256 memory b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: getPartial(self.value, BASE, b.value) });
    }

    function equals(D256 memory self, D256 memory b) internal pure returns (bool) {
        return self.value == b.value;
    }

    function greaterThan(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) == 2;
    }

    function lessThan(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) == 0;
    }

    function greaterThanOrEqualTo(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) > 0;
    }

    function lessThanOrEqualTo(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) < 2;
    }

    function isZero(D256 memory self) internal pure returns (bool) {
        return self.value == 0;
    }

    function asUint256(D256 memory self) internal pure returns (uint256) {
        return self.value.div(BASE);
    }

    // ============ Core Methods ============

    function getPartial(
        uint256 target,
        uint256 numerator,
        uint256 denominator
    )
    private
    pure
    returns (uint256)
    {
        return target.mul(numerator).div(denominator);
    }

    function compareTo(
        D256 memory a,
        D256 memory b
    )
    private
    pure
    returns (uint256)
    {
        if (a.value == b.value) {
            return 1;
        }
        return a.value > b.value ? 2 : 0;
    }
}


// File: contracts/libraries/LibAppStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

// Import all of AppStorage to give importers of LibAppStorage access to {Account}, etc.
import "../beanstalk/AppStorage.sol";

/**
 * @title LibAppStorage 
 * @author Publius
 * @notice Allows libaries to access Beanstalk's state.
 */
library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}


// File: contracts/libraries/LibBytes.sol
/**
 * SPDX-License-Identifier: MIT
 **/
 
pragma solidity =0.7.6;

/* 
* @author: Malteasy
* @title: LibBytes
*/

library LibBytes {

    /*
    * @notice From Solidity Bytes Arrays Utils
    * @author Gonçalo Sá <goncalo.sa@consensys.net>
    */
    function toUint8(bytes memory _bytes, uint256 _start) internal pure returns (uint8) {
        require(_start + 1 >= _start, "toUint8_overflow");
        require(_bytes.length >= _start + 1 , "toUint8_outOfBounds");
        uint8 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x1), _start))
        }

        return tempUint;
    }

    /*
    * @notice From Solidity Bytes Arrays Utils
    * @author Gonçalo Sá <goncalo.sa@consensys.net>
    */
    function toUint32(bytes memory _bytes, uint256 _start) internal pure returns (uint32) {
        require(_start + 4 >= _start, "toUint32_overflow");
        require(_bytes.length >= _start + 4, "toUint32_outOfBounds");
        uint32 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x4), _start))
        }

        return tempUint;
    }

    /*
    * @notice From Solidity Bytes Arrays Utils
    * @author Gonçalo Sá <goncalo.sa@consensys.net>
    */
    function toUint256(bytes memory _bytes, uint256 _start) internal pure returns (uint256) {
        require(_start + 32 >= _start, "toUint256_overflow");
        require(_bytes.length >= _start + 32, "toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    /**
    * @notice Loads a slice of a calldata bytes array into memory
    * @param b The calldata bytes array to load from
    * @param start The start of the slice
    * @param length The length of the slice
    */
    function sliceToMemory(bytes calldata b, uint256 start, uint256 length) internal pure returns (bytes memory) {
        bytes memory memBytes = new bytes(length);
        for(uint256 i = 0; i < length; ++i) {
            memBytes[i] = b[start + i];
        }
        return memBytes;
    }

    function packAddressAndStem(address _address, int96 stem) internal pure returns (uint256) {
        return uint256(_address) << 96 | uint96(stem);
    }

    function unpackAddressAndStem(uint256 data) internal pure returns(address, int96) {
        return (address(uint160(data >> 96)), int96(int256(data)));
    }


}

// File: contracts/libraries/LibSafeMath128.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @author Publius
 * @title LibSafeMath128 is a uint128 variation of Open Zeppelin's Safe Math library.
**/
library LibSafeMath128 {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint128 a, uint128 b) internal pure returns (bool, uint128) {
        uint128 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint128 a, uint128 b) internal pure returns (bool, uint128) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint128 a, uint128 b) internal pure returns (bool, uint128) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint128 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint128 a, uint128 b) internal pure returns (bool, uint128) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint128 a, uint128 b) internal pure returns (bool, uint128) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint128 a, uint128 b) internal pure returns (uint128) {
        uint128 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint128 a, uint128 b) internal pure returns (uint128) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint128 a, uint128 b) internal pure returns (uint128) {
        if (a == 0) return 0;
        uint128 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint128 a, uint128 b) internal pure returns (uint128) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint128 a, uint128 b) internal pure returns (uint128) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint128 a, uint128 b, string memory errorMessage) internal pure returns (uint128) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint128 a, uint128 b, string memory errorMessage) internal pure returns (uint128) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint128 a, uint128 b, string memory errorMessage) internal pure returns (uint128) {
        require(b > 0, errorMessage);
        return a % b;
    }
}


// File: contracts/libraries/LibSafeMath32.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @author Publius
 * @title LibSafeMath32 is a uint32 variation of Open Zeppelin's Safe Math library.
**/
library LibSafeMath32 {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint32 a, uint32 b) internal pure returns (bool, uint32) {
        uint32 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint32 a, uint32 b) internal pure returns (bool, uint32) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint32 a, uint32 b) internal pure returns (bool, uint32) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint32 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint32 a, uint32 b) internal pure returns (bool, uint32) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint32 a, uint32 b) internal pure returns (bool, uint32) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint32 a, uint32 b) internal pure returns (uint32) {
        uint32 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint32 a, uint32 b) internal pure returns (uint32) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint32 a, uint32 b) internal pure returns (uint32) {
        if (a == 0) return 0;
        uint32 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint32 a, uint32 b) internal pure returns (uint32) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint32 a, uint32 b) internal pure returns (uint32) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        require(b > 0, errorMessage);
        return a % b;
    }
}


// File: contracts/libraries/LibSafeMathSigned128.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library LibSafeMathSigned128 {
    int128 constant private _INT128_MIN = -2**127;

    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int128 a, int128 b) internal pure returns (int128) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT128_MIN), "SignedSafeMath: multiplication overflow");

        int128 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(int128 a, int128 b) internal pure returns (int128) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT128_MIN), "SignedSafeMath: division overflow");

        int128 c = a / b;

        return c;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int128 a, int128 b) internal pure returns (int128) {
        int128 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int128 a, int128 b) internal pure returns (int128) {
        int128 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }
}

// File: contracts/libraries/LibSafeMathSigned96.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library LibSafeMathSigned96 {
    int96 constant private _INT96_MIN = -2**95;

    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int96 a, int96 b) internal pure returns (int96) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT96_MIN), "SignedSafeMath: multiplication overflow");

        int96 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(int96 a, int96 b) internal pure returns (int96) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT96_MIN), "SignedSafeMath: division overflow");

        int96 c = a / b;

        return c;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int96 a, int96 b) internal pure returns (int96) {
        int96 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int96 a, int96 b) internal pure returns (int96) {
        int96 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }
}

// File: contracts/libraries/Silo/LibGerminate.sol
// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import {LibAppStorage, Storage, AppStorage, Account} from "../LibAppStorage.sol";
import {LibSafeMath128} from "../LibSafeMath128.sol";
import {LibSafeMath32} from "../LibSafeMath32.sol";
import {LibSafeMathSigned96} from "../LibSafeMathSigned96.sol";
import {LibTokenSilo} from "./LibTokenSilo.sol";
import {LibSilo} from "./LibSilo.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/SafeCast.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {C} from "../../C.sol";

/**
 * @title LibGerminate
 * @author Brean
 * @notice LibGerminate handles logic associated with germination.
 * @dev "germinating" values are values that are currently inactive.
 * germinating values stay germinating until the 1 + the remainder of the current season as passed,
 * in which case they become active.
 *
 * The following are germinating:
 * - newly issued stalk (from new deposits or mowing)
 * - roots from newly issued stalk
 * - new bdv introduced in the silo.
 */
library LibGerminate {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using LibSafeMath32 for uint32;
    using LibSafeMath128 for uint128;
    using LibSafeMathSigned96 for int96;

    //////////////////////// EVENTS ////////////////////////

    /**
     * @notice emitted when the farmers germinating stalk changes.
     */
    event FarmerGerminatingStalkBalanceChanged(
        address indexed account,
        int256 deltaGerminatingStalk,
        Germinate germinationState
    );

    /**
     * @notice emitted when the total germinating amount/bdv changes.
     * @param germinationSeason the season the germination occured.
     * Does not always equal the current season.
     * @param token the token being updated.
     * @param deltaAmount the change in the total germinating amount.
     * @param deltaBdv the change in the total germinating bdv.
     */
    event TotalGerminatingBalanceChanged(
        uint256 germinationSeason,
        address indexed token,
        int256 deltaAmount,
        int256 deltaBdv
    );

    /**
     * @notice emitted when the total germinating stalk changes.
     * @param germinationSeason issuance season of germinating stalk
     * @param deltaGerminatingStalk the change in the total germinating stalk.
     * @dev the issuance season may differ from the season that this event was emitted in..
     */
    event TotalGerminatingStalkChanged(uint256 germinationSeason, int256 deltaGerminatingStalk);

    /**
     * @notice emitted at the sunrise function when the total stalk and roots are incremented.
     * @dev currently, stalk and roots can only increase at the end of `endTotalGermination`,
     * but is casted in the event to allow for future decreases.
     */
    event TotalStalkChangedFromGermination(int256 deltaStalk, int256 deltaRoots);

    struct GermStem {
        int96 germinatingStem;
        int96 stemTip;
    }
    /**
     * @notice Germinate determines what germination struct to use.
     * @dev "odd" and "even" refers to the value of the season counter.
     * "Odd" germinations are used when the season is odd, and vice versa.
     */
    enum Germinate {
        ODD,
        EVEN,
        NOT_GERMINATING
    }

    /**
     * @notice Ends the germination process of system-wide values.
     * @dev we calculate the unclaimed germinating roots of 2 seasons ago
     * as the roots of the stalk should be calculated based on the total stalk
     * when germination finishes, rather than when germination starts.
     */
    function endTotalGermination(uint32 season, address[] memory tokens) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // germination can only occur after season 3.
        if (season < 2) return;
        uint32 germinationSeason = season.sub(2);

        // base roots are used if there are no roots in the silo.
        // root calculation is skipped if no deposits have been made
        // in the season.
        uint128 finishedGerminatingStalk = s.unclaimedGerminating[germinationSeason].stalk;
        uint128 rootsFromGerminatingStalk;
        if (s.s.roots == 0) {
            rootsFromGerminatingStalk = finishedGerminatingStalk.mul(uint128(C.getRootsBase()));
        } else if (s.unclaimedGerminating[germinationSeason].stalk > 0) {
            rootsFromGerminatingStalk = s.s.roots.mul(finishedGerminatingStalk).div(s.s.stalk).toUint128();
        }
        s.unclaimedGerminating[germinationSeason].roots = rootsFromGerminatingStalk;
        // increment total stalk and roots based on unclaimed values.
        s.s.stalk = s.s.stalk.add(finishedGerminatingStalk);
        s.s.roots = s.s.roots.add(rootsFromGerminatingStalk);

        // increment total deposited and amounts for each token.
        Storage.TotalGerminating storage totalGerm;
        if (getSeasonGerminationState() == Germinate.ODD) {
            totalGerm = s.oddGerminating;
        } else {
            totalGerm = s.evenGerminating;
        }
        for (uint i; i < tokens.length; ++i) {
            // if the token has no deposits, skip.
            if (totalGerm.deposited[tokens[i]].amount == 0) {
                continue;
            }

            LibTokenSilo.incrementTotalDeposited(
                tokens[i],
                totalGerm.deposited[tokens[i]].amount,
                totalGerm.deposited[tokens[i]].bdv
            );

            // emit events.
            emit TotalGerminatingBalanceChanged(
                germinationSeason,
                tokens[i],
                -int256(totalGerm.deposited[tokens[i]].amount),
                -int256(totalGerm.deposited[tokens[i]].bdv)
            );
            // clear deposited values.
            delete totalGerm.deposited[tokens[i]];
        }

        // emit change in total germinating stalk.
        // safecast not needed as finishedGerminatingStalk is initially a uint128.
        emit TotalGerminatingStalkChanged(germinationSeason, -int256(finishedGerminatingStalk));
        emit TotalStalkChangedFromGermination(int256(finishedGerminatingStalk), int256(rootsFromGerminatingStalk));
    }

    /**
     * @notice contains logic for ending germination for stalk and roots.
     * @param account address of the account to end germination for.
     * @param lastMowedSeason the last season the account mowed.
     *
     * @dev `first` refers to the set of germinating stalk
     * and roots created in the season closest to the current season.
     * i.e if a user deposited in season 10 and 11, the `first` stalk
     * would be season 11.
     *
     * the germination process:
     * - increments the assoicated values (bdv, stalk, roots)
     * - clears the germination struct for the account.
     * 
     * @return firstGerminatingRoots the roots from the first germinating stalk.
     * used in {handleRainAndSops} to properly set the rain roots of a user,
     * if the user had deposited in the season prior to a rain.
     */
    function endAccountGermination(
        address account,
        uint32 lastMowedSeason,
        uint32 currentSeason
    ) internal returns (uint128 firstGerminatingRoots) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bool lastUpdateOdd = isSeasonOdd(lastMowedSeason);
        (uint128 firstStalk, uint128 secondStalk) = getGerminatingStalk(account, lastUpdateOdd);
        uint128 totalRootsFromGermination;
        uint128 germinatingStalk;

        // check to end germination for first stalk.
        // if last mowed season is greater or equal than (currentSeason - 1),
        // then the first stalk is still germinating.
        if (firstStalk > 0 && lastMowedSeason < currentSeason.sub(1)) {
            (uint128 roots, Germinate germState) = claimGerminatingRoots(
                account,
                lastMowedSeason,
                firstStalk,
                lastUpdateOdd
            );
            germinatingStalk = firstStalk;
            totalRootsFromGermination = roots;
            firstGerminatingRoots = roots;
            emit FarmerGerminatingStalkBalanceChanged(
                account,
                -int256(germinatingStalk),
                germState
            );
        }

        // check to end germination for second stalk.
        if (secondStalk > 0) {
            (uint128 roots, Germinate germState) = claimGerminatingRoots(
                account,
                lastMowedSeason.sub(1),
                secondStalk,
                !lastUpdateOdd
            );
            germinatingStalk = germinatingStalk.add(secondStalk);
            totalRootsFromGermination = totalRootsFromGermination.add(roots);
            emit FarmerGerminatingStalkBalanceChanged(account, -int256(germinatingStalk), germState);
        }

        // increment users stalk and roots.
        if (germinatingStalk > 0) {
            s.a[account].s.stalk = s.a[account].s.stalk.add(germinatingStalk);
            s.a[account].roots = s.a[account].roots.add(totalRootsFromGermination);

            // emit event. Active stalk is incremented, germinating stalk is decremented.
            emit LibSilo.StalkBalanceChanged(
                account,
                int256(germinatingStalk),
                int256(totalRootsFromGermination)
            );
        }
    }

    /**
     * @notice Claims the germinating roots of an account,
     * as well as clears the germinating stalk and roots.
     *
     * @param account address of the account to end germination for.
     * @param season the season to calculate the germinating roots for.
     * @param stalk the stalk to calculate the germinating roots for.
     * @param clearOdd whether to clear the odd or even germinating stalk.
     */
    function claimGerminatingRoots(
        address account,
        uint32 season,
        uint128 stalk,
        bool clearOdd
    ) private returns (uint128 roots, Germinate germState) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        roots = calculateGerminatingRoots(season, stalk);

        if (clearOdd) {
            delete s.a[account].farmerGerminating.odd;
            germState = Germinate.ODD;
        } else {
            delete s.a[account].farmerGerminating.even;
            germState = Germinate.EVEN;
        }

        // deduct from unclaimed values.
        s.unclaimedGerminating[season].stalk = s.unclaimedGerminating[season].stalk.sub(stalk);
        s.unclaimedGerminating[season].roots = s.unclaimedGerminating[season].roots.sub(roots);
    }

    /**
     * @notice calculates the germinating roots for a given stalk and season.
     * @param season the season to use when calculating the germinating roots.
     * @param stalk the stalk to calculate the germinating roots for.
     */
    function calculateGerminatingRoots(
        uint32 season,
        uint128 stalk
    ) private view returns (uint128 roots) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // if the stalk is equal to the remaining unclaimed germinating stalk,
        // then return the remaining unclaimed germinating roots.
        if (stalk == s.unclaimedGerminating[season].stalk) {
            roots = s.unclaimedGerminating[season].roots;
        } else {
            // calculate the roots. casted up to uint256 to prevent overflow,
            // and safecasted down.
            roots = uint256(stalk).mul(s.unclaimedGerminating[season].roots).div(
                s.unclaimedGerminating[season].stalk
            ).toUint128();
        }
    }

    /**
     * @notice returns the germinatingStalk of the account,
     * ordered based on the parity of lastUpdate.
     * @dev if lastUpdate is odd, then `firstStalk` is the odd stalk.
     */
    function getGerminatingStalk(
        address account,
        bool lastUpdateOdd
    ) internal view returns (uint128 firstStalk, uint128 secondStalk) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (lastUpdateOdd) {
            firstStalk = s.a[account].farmerGerminating.odd;
            secondStalk = s.a[account].farmerGerminating.even;
        } else {
            firstStalk = s.a[account].farmerGerminating.even;
            secondStalk = s.a[account].farmerGerminating.odd;
        }
    }

    /**
     * @notice returns the germinating stalk and roots that will finish germinating
     * upon an interaction with the silo.
     */
    function getFinishedGerminatingStalkAndRoots(
        address account,
        uint32 lastMowedSeason,
        uint32 currentSeason
    ) internal view returns (uint256 germinatingStalk, uint256 germinatingRoots) {
        // if user has mowed already,
        // then there are no germinating stalk and roots to finish.
        if (lastMowedSeason == currentSeason) {
            return (0, 0);
        }

        (uint128 firstStalk, uint128 secondStalk) = getGerminatingStalk(
            account,
            isSeasonOdd(lastMowedSeason)
        );

        // check to end germination for first stalk.
        // if last mowed season is the greater or equal than (currentSeason - 1),
        // then the first stalk is still germinating.
        if (firstStalk > 0 && lastMowedSeason < currentSeason.sub(1)) {
            germinatingStalk = firstStalk;
            germinatingRoots = calculateGerminatingRoots(lastMowedSeason, firstStalk);
        }

        // check to end germination for second stalk.
        if (secondStalk > 0) {
            germinatingStalk = germinatingStalk.add(secondStalk);
            germinatingRoots = germinatingRoots.add(
                calculateGerminatingRoots(lastMowedSeason.sub(1), secondStalk)
            );
        }
    }

    /**
     * @notice returns the stalk currently germinating for an account.
     * Does not include germinating stalk that will finish germinating
     * upon an interaction with the silo.
     */
    function getCurrentGerminatingStalk(
        address account,
        uint32 lastMowedSeason
    ) internal view returns (uint256 germinatingStalk) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // if the last mowed season is less than the current season - 1,
        // then there are no germinating stalk and roots (as all germinating assets have finished).
        if (lastMowedSeason < s.season.current.sub(1)) {
            return 0;
        } else {
            (uint128 firstStalk, uint128 secondStalk) = getGerminatingStalk(
                account,
                isSeasonOdd(lastMowedSeason)
            );
            germinatingStalk = firstStalk.add(secondStalk);
        }
    }

    /**
     * @notice returns the unclaimed germinating stalk and roots.
     */
    function getUnclaimedGerminatingStalkAndRoots(
        uint32 season
    ) internal view returns (Storage.Sr memory unclaimed) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        unclaimed = s.unclaimedGerminating[season];
    }

    /**
     * @notice returns the total germinating bdv and amount for a token.
     */
    function getTotalGerminatingForToken(
        address token
    ) internal view returns (uint256 bdv, uint256 amount) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return (
            s.oddGerminating.deposited[token].bdv.add(s.evenGerminating.deposited[token].bdv),
            s.oddGerminating.deposited[token].amount.add(s.evenGerminating.deposited[token].amount)
        );
    }

    /**
     * @notice determines whether a deposit (token + stem) should be germinating or not.
     * If germinating, determines whether the deposit should be set to even or odd.
     *
     * @dev `getGerminationState` should be used if the stemTip and germinatingStem
     * have not been calculated yet. Otherwise, use `_getGerminationState` for gas effiecnecy.
     */
    function getGerminationState(
        address token,
        int96 stem
    ) internal view returns (Germinate, int96) {
        GermStem memory germStem = getGerminatingStem(token);
        return (_getGerminationState(stem, germStem), germStem.stemTip);
    }

    /**
     * @notice returns the `germinating` stem of a token.
     * @dev the 'germinating' stem is the stem where deposits that have a stem
     * equal or higher than this value are germinating.
     */
    function getGerminatingStem(address token) internal view returns (GermStem memory germStem) {
        germStem.stemTip = LibTokenSilo.stemTipForToken(token);
        germStem.germinatingStem = _getGerminatingStem(token, germStem.stemTip);
    }

    /**
     * @notice returns the `germinating` stem of a token.
     * @dev the 'germinating' stem is the stem where deposits that have a stem
     * equal or higher than this value are germinating.
     */
    function _getGerminatingStem(address token, int96 stemTip) internal view returns (int96 stem) {
        return __getGerminatingStem(stemTip, getPrevStalkEarnedPerSeason(token));
    }

    /**
     * @notice Gas efficent version of `_getGerminatingStem`.
     *
     * @dev use when the stemTip and germinatingStem have already been calculated.
     * Assumes the same token is used.
     * prevStalkEarnedPerSeason is the stalkEarnedPerSeason of the previous season.
     * since `lastStemTip` + `prevStalkEarnedPerSeason` is the current stemTip, 
     * safeMath is not needed.
     */
    function __getGerminatingStem(
        int96 stemTip,
        int96 prevStalkEarnedPerSeason
    ) internal pure returns (int96 stem) {
        return stemTip - prevStalkEarnedPerSeason;
    }

    /**
     * @notice returns the stalkEarnedPerSeason of a token of the previous season.
     * @dev if the milestone season is not the current season, then the stalkEarnedPerSeason
     * hasn't changed from the previous season. Otherwise, we calculate the prevStalkEarnedPerSeason.
     */
    function getPrevStalkEarnedPerSeason(
        address token
    ) private view returns (uint32 prevStalkEarnedPerSeason) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (s.ss[token].milestoneSeason < s.season.current) {
            prevStalkEarnedPerSeason = s.ss[token].stalkEarnedPerSeason;
        } else {
            int24 deltaStalkEarnedPerSeason = s.ss[token].deltaStalkEarnedPerSeason;
            if (deltaStalkEarnedPerSeason >= 0) {
                prevStalkEarnedPerSeason =
                    s.ss[token].stalkEarnedPerSeason -
                    uint32(deltaStalkEarnedPerSeason);
            } else {
                prevStalkEarnedPerSeason =
                    s.ss[token].stalkEarnedPerSeason +
                    uint32(-deltaStalkEarnedPerSeason);
            }
        }
    }

    /**
     * @notice internal function for germination stem.
     * @dev a deposit is germinating if the stem is the stemTip or the germinationStem.
     * the 'germinationStem` is the stem of the token of the previous season.
     *
     * The function must check whether the stem is equal to the germinationStem,
     * to determine which germination state it is in.
     */
    function _getGerminationState(
        int96 stem,
        GermStem memory germData
    ) internal view returns (Germinate) {
        if (stem < germData.germinatingStem) {
            // if the stem of the deposit is lower than the germination stem,
            // then the deposit is not germinating.
            return Germinate.NOT_GERMINATING;
        } else {
            // return the gemination state based on whether the stem
            // is equal to the stemTip.
            // if the stem is equal to the stem tip, it is in the initial stages of germination.
            // if the stem is not equal to the stemTip, its in the germination process.
            if (stem == germData.stemTip) {
                return isCurrentSeasonOdd() ? Germinate.ODD : Germinate.EVEN;
            } else {
                return isCurrentSeasonOdd() ? Germinate.EVEN : Germinate.ODD;
            }
        }
    }

    /**
     * @notice returns the germination state for the current season.
     * @dev used in new deposits, as all new deposits are germinating.
     */
    function getSeasonGerminationState() internal view returns (Germinate) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return getGerminationStateForSeason(s.season.current);
    }

    /**
     * @notice returns the germination state for a given season.
     */
    function getGerminationStateForSeason(uint32 season) internal pure returns (Germinate) {
        return isSeasonOdd(season) ? Germinate.ODD : Germinate.EVEN;
    }

    /**
     * @notice returns whether the current season is odd. Used for Germination.
     * @dev even % 2 = 0 (false), odd % 2 = 1 (true)
     */
    function isCurrentSeasonOdd() internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return isSeasonOdd(s.season.current);
    }

    /**
     * @notice returns whether `season` is odd.
     */
    function isSeasonOdd(uint32 season) internal pure returns (bool) {
        return season.mod(2) == 0 ? false : true;
    }

}


// File: contracts/libraries/Silo/LibSilo.sol
/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity =0.7.6;
pragma abicoder v2;

import "../LibAppStorage.sol";
import {C} from "../../C.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/SafeCast.sol";
import {LibBytes} from "../LibBytes.sol";
import {LibTokenSilo} from "./LibTokenSilo.sol";
import {LibSafeMath128} from "../LibSafeMath128.sol";
import {LibSafeMath32} from "../LibSafeMath32.sol";
import {LibSafeMathSigned96} from "../LibSafeMathSigned96.sol";
import {LibGerminate} from "./LibGerminate.sol";
import {LibWhitelistedTokens} from "./LibWhitelistedTokens.sol";

/**
 * @title LibSilo
 * @author Publius
 * @notice Contains functions for minting, burning, and transferring of
 * Stalk and Roots within the Silo.
 *
 * @dev Here, we refer to "minting" as the combination of
 * increasing the total balance of Stalk/Roots, as well as allocating
 * them to a particular account. However, in other places throughout Beanstalk
 * (like during the Sunrise), Beanstalk's total balance of Stalk increases
 * without allocating to a particular account. One example is {Sun-rewardToSilo}
 * which increases `s.s.stalk` but does not allocate it to any account. The
 * allocation occurs during `{SiloFacet-plant}`. Does this change how we should
 * call "minting"?
 *
 * In the ERC20 context, "minting" increases the supply of a token and allocates
 * the new tokens to an account in one action. I've adjusted the comments below
 * to use "mint" in the same sense.
 */
library LibSilo {
    using SafeMath for uint256;
    using LibSafeMath128 for uint128;
    using LibSafeMathSigned96 for int96;
    using LibSafeMath32 for uint32;
    using SafeCast for uint256;

    //////////////////////// ENUM ////////////////////////
    
    /**
     * @dev when a user removes multiple deposits, the
     * {TransferBatch} event is emitted. However, in the 
     * case of an enroot, the event is omitted (as the 
     * depositID does not change). This enum is
     * used to determine if the event should be emitted.
     */
    enum ERC1155Event {
        EMIT_BATCH_EVENT,
        NO_EMIT_BATCH_EVENT
    }
    

    uint128 internal constant PRECISION = 1e6;
    //////////////////////// EVENTS ////////////////////////

    /**
     * @notice Emitted when `account` gains or loses Stalk.
     * @param account The account that gained or lost Stalk.
     * @param delta The change in Stalk.
     * @param deltaRoots The change in Roots.
     *
     * @dev Should be emitted anytime a Deposit is added, removed or transferred
     * AND anytime an account Mows Grown Stalk.
     *
     * BIP-24 included a one-time re-emission of {StalkBalanceChanged} for
     * accounts that had executed a Deposit transfer between the Replant and
     * BIP-24 execution. For more, see:
     *
     * [BIP-24](https://bean.money/bip-24)
     * [Event-Emission](https://github.com/BeanstalkFarms/BIP-24-Event-Emission)
     */
    event StalkBalanceChanged(address indexed account, int256 delta, int256 deltaRoots);

    /**
     * @notice Emitted when a deposit is removed from the silo.
     *
     * @param account The account assoicated with the removed deposit.
     * @param token The token address of the removed deposit.
     * @param stem The stem of the removed deposit.
     * @param amount The amount of "token" removed from an deposit.
     * @param bdv The instanteous bdv removed from the deposit.
     */
    event RemoveDeposit(
        address indexed account,
        address indexed token,
        int96 stem,
        uint256 amount,
        uint256 bdv
    );

    /**
     * @notice Emitted when multiple deposits are removed from the silo.
     *
     * @param account The account assoicated with the removed deposit.
     * @param token The token address of the removed deposit.
     * @param stems A list of stems of the removed deposits.
     * @param amounts A list of amounts removed from the deposits.
     * @param amount the total summation of the amount removed.
     * @param bdvs A list of bdvs removed from the deposits.
     */
    event RemoveDeposits(
        address indexed account,
        address indexed token,
        int96[] stems,
        uint256[] amounts,
        uint256 amount,
        uint256[] bdvs
    );

    /**
     * AssetsRemoved contains the assets removed 
     * during a withdraw or convert. 
     * 
     * @dev seperated into 3 catagories:
     * active: non-germinating assets.
     * odd: odd germinating assets.
     * even: even germinating assets.
     * grownStalk from germinating depoists are seperated 
     * as that stalk is not germinating.
     */
    struct AssetsRemoved {
        Removed active;
        Removed odd; 
        Removed even;
        uint256 grownStalkFromGermDeposits;
    }

    struct Removed {
        uint256 tokens;
        uint256 stalk;
        uint256 bdv;
    }

    /**
     * @notice Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    //////////////////////// MINT ////////////////////////

   
    /**
     * @dev Mints Stalk and Roots to `account`.
     *
     * `roots` are an underlying accounting variable that is used to track
     * how many earned beans a user has.
     *
     * When a farmer's state is updated, the ratio should hold:
     *
     *  Total Roots     User Roots
     * ------------- = ------------
     *  Total Stalk     User Stalk
     *
     * @param account the address to mint Stalk and Roots to
     * @param stalk the amount of stalk to mint
     *
     * @dev Stalk that is not germinating are `active`, meaning that they 
     * are eligible for bean mints. To mint germinating stalk, use 
     * `mintGerminatingStalk`.
     */
    function mintActiveStalk(address account, uint256 stalk) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 roots;
        if (s.s.roots == 0) {
            roots = uint256(stalk.mul(C.getRootsBase()));
        } else {
            // germinating assets should be considered
            // when calculating roots
            roots = s.s.roots.mul(stalk).div(s.s.stalk);
        }

        // increment user and total stalk;
        s.s.stalk = s.s.stalk.add(stalk);
        s.a[account].s.stalk = s.a[account].s.stalk.add(stalk);

        // increment user and total roots
        s.s.roots = s.s.roots.add(roots);
        s.a[account].roots = s.a[account].roots.add(roots);

        emit StalkBalanceChanged(account, int256(stalk), int256(roots));
    }

    /**
     * @notice mintGerminatingStalk contains logic for minting stalk that is germinating.
     * @dev `germinating stalk` are newly issued stalk that are not eligible for bean mints,
     * until 2 `gm` calls have passed, at which point they are considered `grown stalk`.
     *
     * Since germinating stalk are not elgible for bean mints, when calculating the roots of these
     * stalk, it should use the stalk and roots of the system once the stalk is fully germinated,
     * rather than at the time of minting.
     */
    function mintGerminatingStalk(
        address account,
        uint128 stalk,
        LibGerminate.Germinate germ
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (germ == LibGerminate.Germinate.ODD) {
            s.a[account].farmerGerminating.odd = s.a[account].farmerGerminating.odd.add(stalk);
        } else {
            s.a[account].farmerGerminating.even = s.a[account].farmerGerminating.even.add(stalk);
        }

        // germinating stalk are either newly germinating, or partially germinated.
        // Thus they can only be incremented in the latest or previous season.
        uint32 germinationSeason = s.season.current;
        if (LibGerminate.getSeasonGerminationState() == germ) {
            s.unclaimedGerminating[germinationSeason].stalk =
                s.unclaimedGerminating[germinationSeason].stalk.add(stalk);
        } else {
            germinationSeason = germinationSeason.sub(1);
            s.unclaimedGerminating[germinationSeason].stalk = 
                s.unclaimedGerminating[germinationSeason].stalk
                .add(stalk);
        }

        // emit events.
        emit LibGerminate.FarmerGerminatingStalkBalanceChanged(account, stalk, germ);
        emit LibGerminate.TotalGerminatingStalkChanged(germinationSeason, stalk);
    }

    //////////////////////// BURN ////////////////////////

    /**
     * @notice Burns stalk and roots from an account.
     */
    function burnActiveStalk(address account, uint256 stalk) internal returns (uint256 roots) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (stalk == 0) return 0;

        // Calculate the amount of Roots for the given amount of Stalk.
        roots = s.s.roots.mul(stalk).div(s.s.stalk);
        if (roots > s.a[account].roots) roots = s.a[account].roots;

        // Decrease supply of Stalk; Remove Stalk from the balance of `account`
        s.s.stalk = s.s.stalk.sub(stalk);
        s.a[account].s.stalk = s.a[account].s.stalk.sub(stalk);

        // Decrease supply of Roots; Remove Roots from the balance of `account`
        s.s.roots = s.s.roots.sub(roots);
        s.a[account].roots = s.a[account].roots.sub(roots);

        // If it is Raining and the account now has less roots than the
        // account's current rain roots, set the account's rain roots
        // to the account's current roots and subtract the difference
        // from Beanstalk's total rain roots.
        if (s.a[account].sop.roots > s.a[account].roots) {
            uint256 deltaRoots = s.a[account].sop.roots.sub(s.a[account].roots);
            s.a[account].sop.roots = s.a[account].roots;
            s.r.roots = s.r.roots.sub(deltaRoots);
        }

        // emit event.
        emit StalkBalanceChanged(account, -int256(stalk), -int256(roots));
    }

    /**
     * @notice Burns germinating stalk.
     * @dev Germinating stalk does not have any roots assoicated with it.
     */
    function burnGerminatingStalk(
        address account,
        uint128 stalk,
        LibGerminate.Germinate germ
    ) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (germ == LibGerminate.Germinate.ODD) {
            s.a[account].farmerGerminating.odd = s.a[account].farmerGerminating.odd.sub(stalk);
        } else {
            s.a[account].farmerGerminating.even = s.a[account].farmerGerminating.even.sub(stalk);
        }

        // germinating stalk are either newly germinating, or partially germinated.
        // Thus they can only be decremented in the latest or previous season.
        uint32 germinationSeason = s.season.current;
        if (LibGerminate.getSeasonGerminationState() == germ) {
            s.unclaimedGerminating[germinationSeason].stalk = 
                s.unclaimedGerminating[germinationSeason].stalk.sub(stalk);
        } else {
            germinationSeason = germinationSeason.sub(1);
            s.unclaimedGerminating[germinationSeason].stalk = 
                s.unclaimedGerminating[germinationSeason].stalk
                .sub(stalk);
        }

        // emit events.
        emit LibGerminate.FarmerGerminatingStalkBalanceChanged(account, -int256(stalk), germ);
        emit LibGerminate.TotalGerminatingStalkChanged(germinationSeason, -int256(stalk));
    }

    //////////////////////// TRANSFER ////////////////////////

    /**
     * @notice Decrements the Stalk and Roots of `sender` and increments the Stalk
     * and Roots of `recipient` by the same amount.
     *
     */
    function transferStalk(address sender, address recipient, uint256 stalk) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 roots;
        roots = stalk == s.a[sender].s.stalk
            ? s.a[sender].roots
            : s.s.roots.sub(1).mul(stalk).div(s.s.stalk).add(1);

        // Subtract Stalk and Roots from the 'sender' balance.
        s.a[sender].s.stalk = s.a[sender].s.stalk.sub(stalk);
        s.a[sender].roots = s.a[sender].roots.sub(roots);
        emit StalkBalanceChanged(sender, -int256(stalk), -int256(roots));

        // Rain roots cannot be transferred, burn them
        if (s.a[sender].sop.roots > s.a[sender].roots) {
            uint256 deltaRoots = s.a[sender].sop.roots.sub(s.a[sender].roots);
            s.a[sender].sop.roots = s.a[sender].roots;
            s.r.roots = s.r.roots.sub(deltaRoots);
        }

        // Add Stalk and Roots to the 'recipient' balance.
        s.a[recipient].s.stalk = s.a[recipient].s.stalk.add(stalk);
        s.a[recipient].roots = s.a[recipient].roots.add(roots);
        emit StalkBalanceChanged(recipient, int256(stalk), int256(roots));
    }

    /**
     * @notice germinating counterpart of `transferStalk`.
     * @dev assumes stalk is germinating.
     */
    function transferGerminatingStalk(
        address sender,
        address recipient,
        uint256 stalk,
        LibGerminate.Germinate germState
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
         // Subtract Germinating Stalk from the 'sender' balance, 
         // and Add to the 'recipient' balance.
        if (germState == LibGerminate.Germinate.ODD) {
            s.a[sender].farmerGerminating.odd = s.a[sender].farmerGerminating.odd.sub(stalk.toUint128());
            s.a[recipient].farmerGerminating.odd = s.a[recipient].farmerGerminating.odd.add(stalk.toUint128());
        } else {
            s.a[sender].farmerGerminating.even = s.a[sender].farmerGerminating.even.sub(stalk.toUint128());
            s.a[recipient].farmerGerminating.even = s.a[recipient].farmerGerminating.even.add(stalk.toUint128());
        }

        // emit events.
        emit LibGerminate.FarmerGerminatingStalkBalanceChanged(sender, -int256(stalk), germState);
        emit LibGerminate.FarmerGerminatingStalkBalanceChanged(recipient, int256(stalk), germState);
    }

    /**
     * @notice transfers both stalk and Germinating Stalk.
     * @dev used in {TokenSilo._transferDeposits}
     */
    function transferStalkAndGerminatingStalk(
        address sender,
        address recipient,
        address token,
        AssetsRemoved memory ar
    ) external {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 stalkPerBDV = s.ss[token].stalkIssuedPerBdv;

        if (ar.odd.bdv > 0) {
            uint256 initialStalk = ar.odd.bdv.mul(stalkPerBDV);
            
            if (token == C.BEAN) {
                // check whether the Germinating Stalk transferred exceeds the farmers
                // Germinating Stalk. If so, the difference is considered from Earned 
                // Beans. Deduct the odd BDV and increment the activeBDV by the difference.
                (uint256 senderGerminatingStalk, uint256 earnedBeansStalk) = checkForEarnedBeans(
                    sender,
                    initialStalk,
                    LibGerminate.Germinate.ODD
                );
                if (earnedBeansStalk > 0) {
                    // increment the active stalk by the earned beans active stalk.
                    // decrement the germinatingStalk stalk by the earned beans active stalk.
                    ar.active.stalk = ar.active.stalk.add(earnedBeansStalk);
                    initialStalk = senderGerminatingStalk;
                }
            }
            // the inital Stalk issued for a Deposit is the 
            // only Stalk that can Germinate (i.e, Grown Stalk does not Germinate).
            transferGerminatingStalk(
                sender,
                recipient,
                initialStalk,
                LibGerminate.Germinate.ODD
            );
        }

        if (ar.even.bdv > 0) {
            uint256 initialStalk = ar.even.bdv.mul(stalkPerBDV);
           
            if (token == C.BEAN) {
                 // check whether the Germinating Stalk transferred exceeds the farmers
                // Germinating Stalk. If so, the difference is considered from Earned 
                // Beans. Deduct the even BDV and increment the active BDV by the difference.
                (uint256 senderGerminatingStalk, uint256 earnedBeansStalk) = checkForEarnedBeans(
                    sender,
                    initialStalk,
                    LibGerminate.Germinate.EVEN
                );
                if (earnedBeansStalk > 0) {
                    // increment the active stalk by the earned beans active stalk.
                    // decrement the germinatingStalk stalk by the earned beans active stalk.
                    ar.active.stalk = ar.active.stalk.add(earnedBeansStalk);
                    initialStalk = senderGerminatingStalk;
                }
            }
            // the inital Stalk issued for a Deposit is the 
            // only Stalk that can Germinate (i.e, Grown Stalk does not Germinate).
            transferGerminatingStalk(
                sender,
                recipient,
                initialStalk,
                LibGerminate.Germinate.EVEN
            );
        }

        // a Germinating Deposit may have Grown Stalk (which is not Germinating),
        // but the base Stalk is still Germinating.
        ar.active.stalk = ar.active.stalk // Grown Stalk from non-Germinating Deposits, and base stalk from Earned Bean Deposits.
            .add(ar.active.bdv.mul(stalkPerBDV)) // base stalk from non-germinating deposits.
            .add(ar.even.stalk) // grown stalk from Even Germinating Deposits.
            .add(ar.odd.stalk); // grown stalk from Odd Germinating Deposits.
        if (ar.active.stalk > 0) {
            transferStalk(sender, recipient, ar.active.stalk);
        }
    }

    /**
     * @dev Claims the Grown Stalk for `account` and applies it to their Stalk
     * balance. Also handles Season of Plenty related rain.
     *
     * This is why `_mow()` must be called before any actions that change Seeds,
     * including:
     *  - {SiloFacet-deposit}
     *  - {SiloFacet-withdrawDeposit}
     *  - {SiloFacet-withdrawDeposits}
     *  - {_plant}
     *  - {SiloFacet-transferDeposit(s)}
     */
    function _mow(address account, address token) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        
        // if the user has not migrated from siloV2, revert.
        (bool needsMigration, uint32 lastUpdate) = migrationNeeded(account);
        require(!needsMigration, "Silo: Migration needed");

        // if the user hasn't updated prior to the seedGauge/siloV3.1 update,
        // perform a one time `lastStem` scale.
        if (
            (lastUpdate < s.season.stemScaleSeason && lastUpdate > 0) || 
            (lastUpdate == s.season.stemScaleSeason && checkStemEdgeCase(account))
        ) {
            migrateStems(account);
        }

        uint32 currentSeason = s.season.current;
        
        // End account germination.
        uint128 firstGerminatingRoots;
        if (lastUpdate < currentSeason) {
            firstGerminatingRoots = LibGerminate.endAccountGermination(account, lastUpdate, currentSeason);
        }

        // sop data only needs to be updated once per season,
        // if it started raining and it's still raining, or there was a sop
        if (s.season.rainStart > s.season.stemStartSeason) {
            if ((lastUpdate <= s.season.rainStart || s.a[account].lastRain > 0) && lastUpdate <= currentSeason) {
                // Increments `plenty` for `account` if a Flood has occured.
                // Saves Rain Roots for `account` if it is Raining.
                handleRainAndSops(account, lastUpdate, firstGerminatingRoots);
            }
        }
        
        // Calculate the amount of Grown Stalk claimable by `account`.
        // Increase the account's balance of Stalk and Roots.
        __mow(account, token);

        // update lastUpdate for sop and germination calculations.
        s.a[account].lastUpdate = currentSeason;
    }

    /**
     * @dev Updates the mowStatus for the given account and token,
     * and mints Grown Stalk for the given account and token.
     */
    function __mow(
        address account,
        address token
    ) private {
        AppStorage storage s = LibAppStorage.diamondStorage();

        int96 _stemTip = LibTokenSilo.stemTipForToken(token);
        int96 _lastStem = s.a[account].mowStatuses[token].lastStem;
        uint128 _bdv = s.a[account].mowStatuses[token].bdv;

        // if:
        // 1: account has no bdv (new token deposit)
        // 2: the lastStem is the same as the stemTip (implying that a user has mowed),
        // then skip calculations to save gas.
        if (_bdv > 0) {
            if (_lastStem == _stemTip) {
                return;
            }

            // grown stalk does not germinate and is immediately included for bean mints.
            mintActiveStalk(account, _balanceOfGrownStalk(_lastStem, _stemTip, _bdv));
        }

        // If this `account` has no BDV, skip to save gas. Update lastStem.
        // (happen on initial deposit, since mow is called before any deposit)
        s.a[account].mowStatuses[token].lastStem = _stemTip;
        return;
    }

    /**
     * @notice returns the last season an account interacted with the silo.
     */
    function _lastUpdate(address account) internal view returns (uint32) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.a[account].lastUpdate;
    }

    /**
     * @dev internal logic to handle when beanstalk is raining.
     */
    function handleRainAndSops(address account, uint32 lastUpdate, uint128 firstGerminatingRoots) private {
        AppStorage storage s = LibAppStorage.diamondStorage();
        // If a Sop has occured since last update, calculate rewards and set last Sop.
        if (s.season.lastSopSeason > lastUpdate) {
            s.a[account].sop.plenty = balanceOfPlenty(account);
            s.a[account].lastSop = s.season.lastSop;
        }
        // If no roots, reset Sop counters variables
        if (s.a[account].roots == 0) {
            s.a[account].lastSop = s.season.rainStart;
            s.a[account].lastRain = 0;
            return;
        }
        if (s.season.raining) {
            // If rain started after update, set account variables to track rain.
            if (s.season.rainStart > lastUpdate) {
                s.a[account].lastRain = s.season.rainStart;
                s.a[account].sop.roots = s.a[account].roots;
                if (s.season.rainStart - 1 == lastUpdate) {
                    if (firstGerminatingRoots > 0) {
                        // if the account had just finished germinating roots this season (i.e,
                        // deposited in the previous season before raining, and mowed during a sop),
                        // Beanstalk will not allocate plenty to this deposit, and thus the roots
                        // needs to be deducted from the sop roots.
                        s.a[account].sop.roots = s.a[account].sop.roots.sub(firstGerminatingRoots);
                    }
                }
                
                //  s.a[account].roots includes newly finished germinating roots from a fresh deposit
                //  @ season before rainStart
            }
            // If there has been a Sop since rain started,
            // save plentyPerRoot in case another SOP happens during rain.
            if (s.season.lastSop == s.season.rainStart) {
                s.a[account].sop.plentyPerRoot = s.sops[s.season.lastSop];
            }
        } else if (s.a[account].lastRain > 0) {
            // Reset Last Rain if not raining.
            s.a[account].lastRain = 0;
        }
    }

    /**
     * @dev returns the balance of amount of grown stalk based on stems.
     * @param lastStem the stem assoicated with the last mow
     * @param latestStem the current stem for a given token
     * @param bdv the bdv used to calculate grown stalk
     */
    function _balanceOfGrownStalk(
        int96 lastStem,
        int96 latestStem,
        uint128 bdv
    ) internal pure returns (uint256) {
        return stalkReward(lastStem, latestStem, bdv);
    }

    /**
     * @dev returns the amount of `plenty` an account has.
     */
    function balanceOfPlenty(address account) internal view returns (uint256 plenty) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Account.State storage a = s.a[account];
        plenty = a.sop.plenty;
        uint256 previousPPR;

        // If lastRain > 0, then check if SOP occured during the rain period.
        if (s.a[account].lastRain > 0) {
            // if the last processed SOP = the lastRain processed season,
            // then we use the stored roots to get the delta.
            if (a.lastSop == a.lastRain) previousPPR = a.sop.plentyPerRoot;
            else previousPPR = s.sops[a.lastSop];
            uint256 lastRainPPR = s.sops[s.a[account].lastRain];

            // If there has been a SOP duing the rain sesssion since last update, process SOP.
            if (lastRainPPR > previousPPR) {
                uint256 plentyPerRoot = lastRainPPR - previousPPR;
                previousPPR = lastRainPPR;
                plenty = plenty.add(plentyPerRoot.mul(s.a[account].sop.roots).div(C.SOP_PRECISION));
            }
        } else {
            // If it was not raining, just use the PPR at previous SOP.
            previousPPR = s.sops[s.a[account].lastSop];
        }

        // Handle and SOPs that started + ended before after last Silo update.
        if (s.season.lastSop > _lastUpdate(account)) {
            uint256 plentyPerRoot = s.sops[s.season.lastSop].sub(previousPPR);
            plenty = plenty.add(plentyPerRoot.mul(s.a[account].roots).div(C.SOP_PRECISION));
        }
    }

    //////////////////////// REMOVE ////////////////////////

    /**
     * @dev Removes from a single Deposit, emits the RemoveDeposit event,
     * and returns the Stalk/BDV that were removed.
     *
     * Used in:
     * - {TokenSilo:_withdrawDeposit}
     * - {TokenSilo:_transferDeposit}
     */
    function _removeDepositFromAccount(
        address account,
        address token,
        int96 stem,
        uint256 amount,
        LibTokenSilo.Transfer transferType
    )
        internal
        returns (
            uint256 initialStalkRemoved,
            uint256 grownStalkRemoved,
            uint256 bdvRemoved,
            LibGerminate.Germinate germ
        )
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        int96 stemTip;
        (germ, stemTip) = LibGerminate.getGerminationState(token, stem);
        bdvRemoved = LibTokenSilo.removeDepositFromAccount(account, token, stem, amount);

        // the initial and grown stalk are seperated as there are instances
        // where the initial stalk issued for a deposit is germinating. Grown stalk never germinates,
        // and thus is not included in the germinating stalk.
        initialStalkRemoved = bdvRemoved.mul(s.ss[token].stalkIssuedPerBdv);

        grownStalkRemoved = stalkReward(stem, stemTip, bdvRemoved.toUint128());
        /**
         *  {_removeDepositFromAccount} is used for both withdrawing and transferring deposits.
         *  In the case of a withdraw, only the {TransferSingle} Event needs to be emitted.
         *  In the case of a transfer, a different {TransferSingle}/{TransferBatch}
         *  Event is emitted in {TokenSilo._transferDeposit(s)},
         *  and thus, this event is ommited.
         */
        if (transferType == LibTokenSilo.Transfer.emitTransferSingle) {
            // "removing" a deposit is equivalent to "burning" an ERC1155 token.
            emit LibTokenSilo.TransferSingle(
                msg.sender, // operator
                account, // from
                address(0), // to
                LibBytes.packAddressAndStem(token, stem), // depositid
                amount // token amount
            );
        }
        emit RemoveDeposit(account, token, stem, amount, bdvRemoved);
    }

    /**
     * @dev Removes from multiple Deposits, emits the RemoveDeposits
     * event, and returns the Stalk/BDV that were removed.
     *
     * Used in:
     * - {TokenSilo:_withdrawDeposits}
     * - {SiloFacet:enrootDeposits}
     *
     * @notice with the addition of germination, AssetsRemoved
     * keeps track of the germinating data.
     */
    function _removeDepositsFromAccount(
        address account,
        address token,
        int96[] calldata stems,
        uint256[] calldata amounts,
        ERC1155Event emission
    ) external returns (AssetsRemoved memory ar) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256[] memory bdvsRemoved = new uint256[](stems.length);
        uint256[] memory removedDepositIDs = new uint256[](stems.length);
        LibGerminate.GermStem memory germStem = LibGerminate.getGerminatingStem(token);
        for (uint256 i; i < stems.length; ++i) {
            LibGerminate.Germinate germState = LibGerminate._getGerminationState(
                stems[i],
                germStem
            );
            uint256 crateBdv = LibTokenSilo.removeDepositFromAccount(
                account,
                token,
                stems[i],
                amounts[i]
            );
            bdvsRemoved[i] = crateBdv;
            removedDepositIDs[i] = LibBytes.packAddressAndStem(token, stems[i]);
            uint256 crateStalk = stalkReward(stems[i], germStem.stemTip, crateBdv.toUint128());

            // if the deposit is germinating, decrement germinating values,
            // otherwise increment deposited values.
            if (germState == LibGerminate.Germinate.NOT_GERMINATING) {
                ar.active.bdv = ar.active.bdv.add(crateBdv);
                ar.active.stalk = ar.active.stalk.add(crateStalk);
                ar.active.tokens = ar.active.tokens.add(amounts[i]);
            } else {
                if (germState == LibGerminate.Germinate.ODD) {
                    ar.odd.bdv = ar.odd.bdv.add(crateBdv);
                    ar.odd.tokens = ar.odd.tokens.add(amounts[i]);
                } else {
                    ar.even.bdv = ar.even.bdv.add(crateBdv);
                    ar.even.tokens = ar.even.tokens.add(amounts[i]);
                }
                // grown stalk from germinating deposits do not germinate,
                // and thus must be added to the grown stalk.
                ar.grownStalkFromGermDeposits = ar.grownStalkFromGermDeposits.add(
                    crateStalk
                );
            }
        }

        // add initial stalk deposit to all stalk removed.
        {
            uint256 stalkIssuedPerBdv = s.ss[token].stalkIssuedPerBdv;
            if (ar.active.tokens > 0) {
                ar.active.stalk = ar.active.stalk.add(ar.active.bdv.mul(stalkIssuedPerBdv));
            }

            if (ar.odd.tokens > 0) {
                ar.odd.stalk = ar.odd.bdv.mul(stalkIssuedPerBdv);
            }

            if (ar.even.tokens > 0) {
                ar.even.stalk = ar.even.bdv.mul(stalkIssuedPerBdv);
            }
        }

        // "removing" deposits is equivalent to "burning" a batch of ERC1155 tokens.
        if (emission == ERC1155Event.EMIT_BATCH_EVENT) {
            emit TransferBatch(msg.sender, account, address(0), removedDepositIDs, amounts);
        }

        emit RemoveDeposits(
            account, 
            token, 
            stems, 
            amounts,
            ar.active.tokens.add(ar.odd.tokens).add(ar.even.tokens), 
            bdvsRemoved
        );
    }

    //////////////////////// UTILITIES ////////////////////////

    /**
     * @notice Calculates the Stalk reward based on the start and end
     * stems, and the amount of BDV deposited. Stems represent the
     * amount of grown stalk per BDV, so the difference between the
     * start index and end index (stem) multiplied by the amount of
     * bdv deposited will give the amount of stalk earned.
     * formula: stalk = bdv * (ΔstalkPerBdv)
     * 
     * @dev endStem must be larger than startStem.
     * 
     */
    function stalkReward(
        int96 startStem,
        int96 endStem,
        uint128 bdv
    ) internal pure returns (uint256) {
        uint128 reward = uint128(endStem.sub(startStem)).mul(bdv).div(PRECISION);

        return reward;
    }

    /**
     * @dev check whether the account needs to be migrated.
     */
    function migrationNeeded(address account) internal view returns (bool needsMigration, uint32 lastUpdate) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        lastUpdate = s.a[account].lastUpdate;
        needsMigration = lastUpdate > 0 && lastUpdate < s.season.stemStartSeason;
    }

    /**
     * @dev Internal function to compute `account` balance of Earned Beans.
     *
     * The number of Earned Beans is equal to the difference between:
     *  - the "expected" Stalk balance, determined from the account balance of
     *    Roots.
     *  - the "account" Stalk balance, stored in account storage.
     * divided by the number of Stalk per Bean.
     * The earned beans from the latest season
     */
    function _balanceOfEarnedBeans(
        uint256 accountStalk,
        uint256 accountRoots
    ) internal view returns (uint256 beans) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        // There will be no Roots before the first Deposit is made.
        if (s.s.roots == 0) return 0;

        uint256 stalk = s.s.stalk.mul(accountRoots).div(s.s.roots);

        // Beanstalk rounds down when minting Roots. Thus, it is possible that
        // balanceOfRoots / totalRoots * totalStalk < s.a[account].s.stalk.
        // As `account` Earned Balance balance should never be negative,
        // Beanstalk returns 0 instead.
        if (stalk <= accountStalk) return 0;

        // Calculate Earned Stalk and convert to Earned Beans.
        beans = (stalk - accountStalk).div(C.STALK_PER_BEAN); // Note: SafeMath is redundant here.
        if (beans > s.earnedBeans) return s.earnedBeans;

        return beans;
    }

    /**
     * @notice performs a one time update for the
     * users lastStem for all silo Tokens.
     * @dev Due to siloV3.1 update.
     */
    function migrateStems(address account) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        address[] memory siloTokens = LibWhitelistedTokens.getSiloTokens();
        for(uint i; i < siloTokens.length; i++) {
            // scale lastStem by 1e6, if the user has a lastStem.
            if (s.a[account].mowStatuses[siloTokens[i]].lastStem > 0) { 
                s.a[account].mowStatuses[siloTokens[i]].lastStem = 
                    s.a[account].mowStatuses[siloTokens[i]].lastStem.mul(int96(PRECISION));
            }
        }
    }

    /**
     * @dev An edge case can occur with the siloV3.1 update, where
     * A user updates their silo in the same season as the seedGauge update,
     * but prior to the seedGauge BIP execution (i.e the farmer mowed at the start of
     * the season, and the BIP was excuted mid-way through the season).
     * This function checks for that edge case and returns a boolean.
     */
    function checkStemEdgeCase(address account) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        address[] memory siloTokens = LibWhitelistedTokens.getSiloTokens();
        // for each silo token, divide the stemTip of the token with the users last stem.
        // if the answer is 1e6 or greater, the user has not updated.
        for(uint i; i < siloTokens.length; i++) {
            int96 lastStem = s.a[account].mowStatuses[siloTokens[i]].lastStem;
            if (lastStem > 0) {
                if (LibTokenSilo.stemTipForToken(siloTokens[i]).div(lastStem) >= int96(PRECISION)) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * @notice Returns the amount of Germinating Stalk 
     * for a given Germinate enum.
     * @dev When a Farmer attempts to withdraw Beans from a Deposit that has a Germinating Stem,
     * `checkForEarnedBeans` is called to determine how many of the Beans were Planted vs Deposited.
     * If a Farmer withdraws a Germinating Deposit with Earned Beans, only subtract the Germinating Beans
     * from the Germinating Balances
     * @return germinatingStalk stalk that is germinating for a given Germinate enum.
     * @return earnedBeanStalk the earned bean portion of stalk for a given Germinate enum.
     */
    function checkForEarnedBeans(
        address account,
        uint256 stalk,
        LibGerminate.Germinate germ
    ) internal view returns (uint256 germinatingStalk, uint256 earnedBeanStalk) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 farmerGerminatingStalk;
        if (germ == LibGerminate.Germinate.ODD) {
            farmerGerminatingStalk = s.a[account].farmerGerminating.odd;
        } else {
            farmerGerminatingStalk = s.a[account].farmerGerminating.even;
        }
        if (stalk > farmerGerminatingStalk) {
            return (farmerGerminatingStalk, stalk.sub(farmerGerminatingStalk));
        } else {
            return (stalk, 0);
        }
    }
}


// File: contracts/libraries/Silo/LibSiloPermit.sol
/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "../../C.sol";
import "../LibAppStorage.sol";

/**
 * @title LibSiloPermit
 * @author Publius
 * @notice Contains functions to read and update Silo Deposit allowances with
 * permits.
 * @dev Permits must be signed off-chain.
 *
 * See here for details on signing Silo Deposit permits:
 * https://github.com/BeanstalkFarms/Beanstalk/blob/d2a9a232f50e1d474d976a2e29488b70c8d19461/protocol/utils/permit.js
 * 
 * The Beanstalk SDK also provides Javascript wrappers for permit functionality:
 * `permit`: https://github.com/BeanstalkFarms/Beanstalk-SDK/blob/df2684aee67241acdb89379d4d0c19322339436c/packages/sdk/src/lib/silo.ts#L657
 * `permits`: https://github.com/BeanstalkFarms/Beanstalk-SDK/blob/df2684aee67241acdb89379d4d0c19322339436c/packages/sdk/src/lib/silo.ts#L698
 */
library LibSiloPermit {

    bytes32 private constant DEPOSIT_PERMIT_HASHED_NAME = keccak256(bytes("SiloDeposit"));
    bytes32 private constant DEPOSIT_PERMIT_HASHED_VERSION = keccak256(bytes("1"));
    bytes32 private constant DEPOSIT_PERMIT_EIP712_TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant DEPOSIT_PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,address token,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant DEPOSITS_PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,address[] tokens,uint256[] values,uint256 nonce,uint256 deadline)");


    /**
     */
    event DepositApproval(
        address indexed owner,
        address indexed spender,
        address token,
        uint256 amount
    );

    /**
     * @dev Verifies the integrity of a Silo Deposit permit. 
     *
     * Only permits signed using the current nonce returned by {nonces}
     * will be approved.
     *
     * Should revert if:
     * - The permit has expired (deadline has passed)
     * - The signer recovered from the permit signature does not match the owner
     * 
     * See {LibSiloPermit} for a description of how to sign a permit.
     */
    function permit(
        address owner,
        address spender,
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        require(block.timestamp <= deadline, "Silo: permit expired deadline");
        bytes32 structHash = keccak256(
            abi.encode(
                DEPOSIT_PERMIT_TYPEHASH,
                owner,
                spender,
                token,
                value,
                _useNonce(owner),
                deadline
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "Silo: permit invalid signature");
    }

    /**
     * @dev Verifies the integrity of a Silo Deposits (multiple tokens & values)
     * permit. 
     *
     * Only permits signed using the current nonce returned by {nonces}
     * will be approved.
     * 
     * See {LibSiloPermit} for a description of how to sign a multi-token permit.
     */
    function permits(
        address owner,
        address spender,
        address[] memory tokens,
        uint256[] memory values,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        require(block.timestamp <= deadline, "Silo: permit expired deadline");
        bytes32 structHash = keccak256(
            abi.encode(
                DEPOSITS_PERMIT_TYPEHASH,
                owner,
                spender,
                keccak256(abi.encodePacked(tokens)),
                keccak256(abi.encodePacked(values)),
                _useNonce(owner),
                deadline
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "Silo: permit invalid signature");
    }

    /**
     * @dev Returns the current `nonce` for `owner`.
     * 
     * Use the current nonce to sign permits.
     */
    function nonces(address owner) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.a[owner].depositPermitNonces;
    }

    /**
     * @dev Returns and increments the current `nonce` for `owner`.
     */
    function _useNonce(address owner) internal returns (uint256 current) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        current = s.a[owner].depositPermitNonces;
        ++s.a[owner].depositPermitNonces;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return _buildDomainSeparator(
            DEPOSIT_PERMIT_EIP712_TYPE_HASH,
            DEPOSIT_PERMIT_HASHED_NAME,
            DEPOSIT_PERMIT_HASHED_VERSION
        );
    }

    /**
     * @dev See {_domainSeparatorV4}.
     */
    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 name,
        bytes32 version
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                typeHash,
                name,
                version,
                C.getChainId(),
                address(this)
            )
        );
    }

    /**
     * @dev Given an already hashed struct, this function returns the hash of
     * the fully encoded EIP712 message for this domain.
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer
     * of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }


    function _approveDeposit(address account, address spender, address token, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.a[account].depositAllowances[spender][token] = amount;
        emit DepositApproval(account, spender, token, amount);
    }

    //////////////////////// APPROVE ////////////////////////

    function _spendDepositAllowance(
        address owner,
        address spender,
        address token,
        uint256 amount
    ) internal {
        uint256 currentAllowance = depositAllowance(owner, spender, token);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Silo: insufficient allowance");
            _approveDeposit(owner, spender, token, currentAllowance - amount);
        }
    }
    
    function depositAllowance(
        address owner,
        address spender,
        address token
    ) public view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.a[owner].depositAllowances[spender][token];
    }
}

// File: contracts/libraries/Silo/LibTokenSilo.sol
/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/SafeCast.sol";
import {LibAppStorage, Storage, AppStorage, Account} from "../LibAppStorage.sol";
import {C} from "../../C.sol";
import {LibSafeMath32} from "contracts/libraries/LibSafeMath32.sol";
import {LibSafeMath128} from "contracts/libraries/LibSafeMath128.sol";
import {LibSafeMathSigned128} from "contracts/libraries/LibSafeMathSigned128.sol";
import {LibSafeMathSigned96} from "contracts/libraries/LibSafeMathSigned96.sol";
import {LibBytes} from "contracts/libraries/LibBytes.sol";
import {LibGerminate} from "contracts/libraries/Silo/LibGerminate.sol";
import {LibWhitelistedTokens} from "contracts/libraries/Silo/LibWhitelistedTokens.sol";

/**
 * @title LibTokenSilo
 * @author Publius, Pizzaman1337
 * @notice Contains functions for depositing, withdrawing and claiming
 * whitelisted Silo tokens.
 *
 * For functionality related to Stalk, and Roots, see {LibSilo}.
 */
library LibTokenSilo {
    using SafeMath for uint256;
    using LibSafeMath128 for uint128;
    using LibSafeMath32 for uint32;
    using LibSafeMathSigned128 for int128;
    using SafeCast for int128;
    using SafeCast for uint256;
    using LibSafeMathSigned96 for int96;

    uint256 constant PRECISION = 1e6; // increased precision from to silo v3.1.


    //////////////////////// ENUM ////////////////////////
    /**
     * @dev when a user deposits or withdraws a deposit, the
     * {TrasferSingle} event is emitted. However, in the case
     * of a transfer, this emission is ommited. This enum is
     * used to determine if the event should be emitted.
     */
    enum Transfer {
        emitTransferSingle,
        noEmitTransferSingle
    }

    //////////////////////// EVENTS ////////////////////////

    /**
     * @dev IMPORTANT: copy of {TokenSilo-AddDeposit}, check there for details.
     */
    event AddDeposit(
        address indexed account,
        address indexed token,
        int96 stem,
        uint256 amount,
        uint256 bdv
    );

    /**
     * @dev IMPORTANT: copy of {TokenSilo-RemoveDeposit}, check there for details.
     */
    event RemoveDeposit(
        address indexed account,
        address indexed token,
        int96 stem,
        uint256 amount,
        uint256 bdv
    );

    // added as the ERC1155 deposit upgrade
    event TransferSingle(
        address indexed operator,
        address indexed sender,
        address indexed recipient,
        uint256 depositId,
        uint256 amount
    );

    //////////////////////// ACCOUNTING: TOTALS GERMINATING ////////////////////////

    /**
     * @notice Increment the total amount and bdv of `token` germinating in the Silo.
     * @dev when an asset is `deposited` in the silo, it is not immediately eliable for
     * bean mints. It must `germinate` (stay deposited the silo) for a certain
     * amount of seasons (the remainer of the current season + 1). This function
     * increments the total amount and bdv germinating in the silo. The {sunrise}
     * function ends the germination process for even or odd germinating deposits.
     *
     * This protects beanstalk from flashloan attacks, and makes `totalDeposited` and
     * `totalDepositedBdv` significantly more MEV resistant.
     */
    function incrementTotalGerminating(
        address token,
        uint256 amount,
        uint256 bdv,
        LibGerminate.Germinate germ
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Storage.TotalGerminating storage germinate;

        // verify germ is valid
        if (germ == LibGerminate.Germinate.ODD) {
            germinate = s.oddGerminating;
        } else if (germ == LibGerminate.Germinate.EVEN) {
            germinate = s.evenGerminating;
        } else {
            revert("invalid germinationMode"); // should not ever get here
        }

        // increment germinating amount and bdv.
        germinate.deposited[token].amount = germinate.deposited[token].amount.add(
            amount.toUint128()
        );
        germinate.deposited[token].bdv = germinate.deposited[token].bdv.add(bdv.toUint128());

        // emit event.
        emit LibGerminate.TotalGerminatingBalanceChanged(
            s.season.current,
            token,
            int256(amount),
            int256(bdv)
        );
    }

    /**
     * @notice Decrement the total amount and bdv of `token` germinating in the Silo.
     * @dev `decrementTotalGerminating` should be used when removing deposits
     * that are < 2 seasons old.
     */
    function decrementTotalGerminating(
        address token,
        uint256 amount,
        uint256 bdv,
        LibGerminate.Germinate germ
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Storage.TotalGerminating storage germinate;

        // verify germ is valid
        if (germ == LibGerminate.Germinate.ODD) {
            germinate = s.oddGerminating;
        } else if (germ == LibGerminate.Germinate.EVEN) {
            germinate = s.evenGerminating;
        } else {
            revert("invalid germinationMode"); // should not ever get here
        }

        // decrement germinating amount and bdv.
        germinate.deposited[token].amount = germinate.deposited[token].amount.sub(
            amount.toUint128()
        );
        germinate.deposited[token].bdv = germinate.deposited[token].bdv.sub(bdv.toUint128());
    
        emit LibGerminate.TotalGerminatingBalanceChanged(
            LibGerminate.getSeasonGerminationState() == germ ? 
                s.season.current : 
                s.season.current - 1,
            token,
            -int256(amount),
            -int256(bdv)
        );
    }

    /**
     * @notice Increment the total bdv of `token` germinating in the Silo. Used in Enroot.
     */
    function incrementTotalGerminatingBdv(
        address token,
        uint256 bdv,
        LibGerminate.Germinate germ
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (germ == LibGerminate.Germinate.ODD) {
            // increment odd germinating
            s.oddGerminating.deposited[token].bdv = s.oddGerminating.deposited[token].bdv.add(
                bdv.toUint128()
            );
        } else if (germ == LibGerminate.Germinate.EVEN) {
            // increment even germinating
            s.evenGerminating.deposited[token].bdv = s.evenGerminating.deposited[token].bdv.add(
                bdv.toUint128()
            );
        } else {
            revert("invalid germinationMode"); // should not ever get here
        }

        emit LibGerminate.TotalGerminatingBalanceChanged(
            LibGerminate.getSeasonGerminationState() == germ ? 
                s.season.current : 
                s.season.current - 1,
            token,
            0,
            int256(bdv)
        );
    }

    //////////////////////// ACCOUNTING: TOTALS ////////////////////////

    /**
     * @dev Increment the total amount and bdv of `token` deposited in the Silo.
     * @dev `IncrementTotalDeposited` should be used when removing deposits that are
     * >= 2 seasons old (ex. when a user converts).
     */
    function incrementTotalDeposited(address token, uint256 amount, uint256 bdv) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.siloBalances[token].deposited = s.siloBalances[token].deposited.add(amount.toUint128());
        s.siloBalances[token].depositedBdv = s.siloBalances[token].depositedBdv.add(
            bdv.toUint128()
        );
    }

    /**
     * @notice Decrement the total amount and bdv of `token` deposited in the Silo.
     * @dev `decrementTotalDeposited` should be used when removing deposits that are
     * >= 2 seasons old.
     */
    function decrementTotalDeposited(address token, uint256 amount, uint256 bdv) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.siloBalances[token].deposited = s.siloBalances[token].deposited.sub(amount.toUint128());
        s.siloBalances[token].depositedBdv = s.siloBalances[token].depositedBdv.sub(
            bdv.toUint128()
        );
    }

    /**
     * @notice Increment the total bdv of `token` deposited in the Silo. Used in Enroot.
     */
    function incrementTotalDepositedBdv(address token, uint256 bdv) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.siloBalances[token].depositedBdv = s.siloBalances[token].depositedBdv.add(
            bdv.toUint128()
        );
    }

    //////////////////////// ADD DEPOSIT ////////////////////////

    /**
     * @return stalk The amount of Stalk received for this Deposit.
     *
     * @dev Calculate the current BDV for `amount` of `token`, then perform
     * Deposit accounting.
     */
    function deposit(
        address account,
        address token,
        int96 stem,
        uint256 amount
    ) internal returns (uint256, LibGerminate.Germinate) {
        uint256 bdv = beanDenominatedValue(token, amount);
        return depositWithBDV(account, token, stem, amount, bdv);
    }

    /**
     * @dev Once the BDV received for Depositing `amount` of `token` is known,
     * add a Deposit for `account` and update the total amount Deposited.
     *
     * `s.ss[token].stalkIssuedPerBdv` stores the number of Stalk per BDV for `token`.
     */
    function depositWithBDV(
        address account,
        address token,
        int96 stem,
        uint256 amount,
        uint256 bdv
    ) internal returns (uint256 stalk, LibGerminate.Germinate germ) {
        require(bdv > 0, "Silo: No Beans under Token.");
        AppStorage storage s = LibAppStorage.diamondStorage();

        // determine whether the deposit is odd or even germinating
        germ = LibGerminate.getSeasonGerminationState();

        // all new deposits will increment total germination.
        incrementTotalGerminating(token, amount, bdv, germ);
        
        addDepositToAccount(
            account,
            token,
            stem,
            amount,
            bdv,
            Transfer.emitTransferSingle
        );

        stalk = bdv.mul(s.ss[token].stalkIssuedPerBdv);
    }

    /**
     * @dev Add `amount` of `token` to a user's Deposit in `stemTipForToken`. Requires a
     * precalculated `bdv`.
     *
     * If a Deposit doesn't yet exist, one is created. Otherwise, the existing
     * Deposit is updated.
     *
     * `amount` & `bdv` are downcasted uint256 -> uint128 to optimize storage cost,
     * since both values can be packed into one slot.
     *
     * Unlike {removeDepositFromAccount}, this function DOES EMIT an
     * {AddDeposit} event. See {removeDepositFromAccount} for more details.
     */
    function addDepositToAccount(
        address account,
        address token,
        int96 stem,
        uint256 amount,
        uint256 bdv,
        Transfer transferType
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 depositId = LibBytes.packAddressAndStem(token, stem);

        // add amount and bdv to the deposits.
        s.a[account].deposits[depositId].amount = s.a[account].deposits[depositId].amount.add(
            amount.toUint128()
        );
        s.a[account].deposits[depositId].bdv = s.a[account].deposits[depositId].bdv.add(
            bdv.toUint128()
        );

        // SafeMath unnecessary b/c crateBDV <= type(uint128).max
        s.a[account].mowStatuses[token].bdv = s.a[account].mowStatuses[token].bdv.add(
            bdv.toUint128()
        );

        /**
         *  {addDepositToAccount} is used for both depositing and transferring deposits.
         *  In the case of a deposit, only the {TransferSingle} Event needs to be emitted.
         *  In the case of a transfer, a different {TransferSingle}/{TransferBatch}
         *  Event is emitted in {TokenSilo._transferDeposit(s)},
         *  and thus, this event is ommited.
         */
        if (transferType == Transfer.emitTransferSingle) {
            emit TransferSingle(
                msg.sender, // operator
                address(0), // from
                account, // to
                depositId, // depositID
                amount // token amount
            );
        }
        emit AddDeposit(account, token, stem, amount, bdv);
    }

    //////////////////////// REMOVE DEPOSIT ////////////////////////

    /**
     * @dev Remove `amount` of `token` from a user's Deposit in `stem`.
     *
     * A "Crate" refers to the existing Deposit in storage at:
     *  `s.a[account].deposits[token][stem]`
     *
     * Partially removing a Deposit should scale its BDV proportionally. For ex.
     * removing 80% of the tokens from a Deposit should reduce its BDV by 80%.
     *
     * During an update, `amount` & `bdv` are cast uint256 -> uint128 to
     * optimize storage cost, since both values can be packed into one slot.
     *
     * This function DOES **NOT** EMIT a {RemoveDeposit} event. This
     * asymmetry occurs because {removeDepositFromAccount} is called in a loop
     * in places where multiple deposits are removed simultaneously, including
     * {TokenSilo-removeDepositsFromAccount} and {TokenSilo-_transferDeposits}.
     */

    function removeDepositFromAccount(
        address account,
        address token,
        int96 stem,
        uint256 amount
    ) internal returns (uint256 crateBDV) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 depositId = LibBytes.packAddressAndStem(token, stem);

        uint256 crateAmount = s.a[account].deposits[depositId].amount;
        crateBDV = s.a[account].deposits[depositId].bdv;
        // if amount is > crateAmount, check if user has a legacy deposit:
        if (amount > crateAmount) { 
            // get the absolute stem value.
            uint256 absStem = stem > 0 ? uint256(stem) : uint256(-stem);
            // only stems with modulo 1e6 can have a legacy deposit.
            if (absStem.mod(1e6) == 0) {
                (crateAmount, crateBDV) = migrateLegacyStemDeposit(
                    account,
                    token,
                    stem,
                    crateAmount,
                    crateBDV
                );
            }
        }
        require(amount <= crateAmount, "Silo: Crate balance too low.");

        // Partial remove
        if (amount < crateAmount) {
            // round up removal of BDV. (x - 1)/y + 1
            // https://stackoverflow.com/questions/17944
            uint256 removedBDV = amount.sub(1).mul(crateBDV).div(crateAmount).add(1);
            uint256 updatedBDV = crateBDV.sub(removedBDV);
            uint256 updatedAmount = crateAmount.sub(amount);

            // SafeCast unnecessary b/c updatedAmount <= crateAmount and updatedBDV <= crateBDV, 
            // which are both <= type(uint128).max
            s.a[account].deposits[depositId].amount = updatedAmount.toUint128();
            s.a[account].deposits[depositId].bdv = updatedBDV.toUint128();
            
            s.a[account].mowStatuses[token].bdv = s.a[account].mowStatuses[token].bdv.sub(
                removedBDV.toUint128()
            );

            return removedBDV;
        }
        // Full remove
        if (crateAmount > 0) delete s.a[account].deposits[depositId];

        // SafeMath unnecessary b/c crateBDV <= type(uint128).max
        s.a[account].mowStatuses[token].bdv = s.a[account].mowStatuses[token].bdv.sub(
            crateBDV.toUint128()
        );
    }

    //////////////////////// GETTERS ////////////////////////

    /**
     * @dev Calculate the BDV ("Bean Denominated Value") for `amount` of `token`.
     *
     * Makes a call to a BDV function defined in the SiloSettings for this
     * `token`. See {AppStorage.sol:Storage-SiloSettings} for more information.
     */
    function beanDenominatedValue(
        address token,
        uint256 amount
    ) internal view returns (uint256 bdv) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.ss[token].selector != bytes4(0), "Silo: Token not whitelisted");

        (bool success, bytes memory data) = address(this).staticcall(
            encodeBdvFunction(token, s.ss[token].encodeType, s.ss[token].selector, amount)
        );

        if (!success) {
            if (data.length == 0) revert();
            assembly {
                revert(add(32, data), mload(data))
            }
        }

        assembly {
            bdv := mload(add(data, add(0x20, 0)))
        }
    }

    function encodeBdvFunction(
        address token,
        bytes1 encodeType,
        bytes4 selector,
        uint256 amount
    ) internal pure returns (bytes memory callData) {
        if (encodeType == 0x00) {
            callData = abi.encodeWithSelector(selector, amount);
        } else if (encodeType == 0x01) {
            callData = abi.encodeWithSelector(selector, token, amount);
        } else {
            revert("Silo: Invalid encodeType");
        }
    }

    /**
     * @dev Locate the `amount` and `bdv` for a user's Deposit in storage.
     *
     * Silo V3 Deposits are stored within each {Account} as a mapping of:
     *  `uint256 DepositID => { uint128 amount, uint128 bdv }`
     *  The DepositID is the concatination of the token address and the stem.
     *
     * Silo V2 deposits are only usable after a successful migration, see
     * mowAndMigrate within the Migration facet.
     *
     */
    function getDeposit(
        address account,
        address token,
        int96 stem
    ) internal view returns (uint256 amount, uint256 bdv) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 depositId = LibBytes.packAddressAndStem(token, stem);
        amount = s.a[account].deposits[depositId].amount;
        bdv = s.a[account].deposits[depositId].bdv;
    }

    /**
     * @dev Get the number of Stalk per BDV per Season for a whitelisted token.
     * 6 decimal precision: 1e10 units = 1 stalk per season
     */
    function stalkEarnedPerSeason(address token) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return uint256(s.ss[token].stalkEarnedPerSeason);
    }

    /**
     * @dev Get the number of Stalk per BDV for a whitelisted token. Formerly just stalk.
     */
    function stalkIssuedPerBdv(address token) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return uint256(s.ss[token].stalkIssuedPerBdv);
    }

    /**
     * @dev returns the cumulative stalk per BDV (stemTip) for a whitelisted token.
     */
    function stemTipForToken(
        address token
    ) internal view returns (int96 _stemTip) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        // SafeCast unnecessary because all casted variables are types smaller that int96.
        _stemTip =
            s.ss[token].milestoneStem +
            int96(s.ss[token].stalkEarnedPerSeason).mul(
                int96(s.season.current).sub(int96(s.ss[token].milestoneSeason))
            );
    }

    /**
     * @dev returns the amount of grown stalk a deposit has earned.
     */
    function grownStalkForDeposit(
        address account,
        address token,
        int96 stem
    ) internal view returns (uint grownStalk) {
        // stemTipForToken(token) > depositGrownStalkPerBdv for all valid Deposits
        int96 _stemTip = stemTipForToken(token);
        require(stem <= _stemTip, "Silo: Invalid Deposit");
        // The check in the above line guarantees that subtraction result is positive
        // and thus the cast to `uint256` is safe.
        uint deltaStemTip = uint256(_stemTip.sub(stem));
        // no stalk has grown if the stem is equal to the stemTip.
        if (deltaStemTip == 0) return 0;
        (, uint bdv) = getDeposit(account, token, stem);

        grownStalk = deltaStemTip.mul(bdv).div(PRECISION);
    }

    /**
     * @dev returns the amount of grown stalk a deposit would have, based on the stem of the deposit.
     */
    function calculateStalkFromStemAndBdv(
        address token,
        int96 grownStalkIndexOfDeposit,
        uint256 bdv
    ) internal view returns (int96 grownStalk) {
        // current latest grown stalk index
        int96 _stemTipForToken = stemTipForToken(address(token));

        return _stemTipForToken.sub(grownStalkIndexOfDeposit).mul(toInt96(bdv));
    }

    /**
     * @notice returns the grown stalk and germination state of a deposit,
     * based on the amount of grown stalk it has earned.
     */
    function calculateStemForTokenFromGrownStalk(
        address token,
        uint256 grownStalk,
        uint256 bdv
    ) internal view returns (int96 stem, LibGerminate.Germinate germ) {
        LibGerminate.GermStem memory germStem = LibGerminate.getGerminatingStem(token);
        stem = germStem.stemTip.sub(toInt96(grownStalk.mul(PRECISION).div(bdv)));
        germ = LibGerminate._getGerminationState(stem, germStem);
    }

    /**
     * @dev returns the amount of grown stalk a deposit would have, based on the stem of the deposit.
     * Similar to calculateStalkFromStemAndBdv, but has an additional check to prevent division by 0.
     */
    function grownStalkAndBdvToStem(
        address token,
        uint256 grownStalk,
        uint256 bdv
    ) internal view returns (int96 cumulativeGrownStalk) {
        // first get current latest grown stalk index
        int96 _stemTipForToken = stemTipForToken(token);
        // then calculate how much stalk each individual bdv has grown
        // there's a > 0 check here, because if you have a small amount of unripe bean deposit, the bdv could
        // end up rounding to zero, then you get a divide by zero error and can't migrate without losing that deposit

        // prevent divide by zero error
        int96 grownStalkPerBdv = bdv > 0 ? toInt96(grownStalk.mul(PRECISION).div(bdv)) : 0;

        // subtract from the current latest index, so we get the index the deposit should have happened at
        return _stemTipForToken.sub(grownStalkPerBdv);
    }

    /**
     * @notice internal logic for migrating a legacy deposit.
     * @dev 
     */
    function migrateLegacyStemDeposit(
        address account, 
        address token,
        int96 newStem,
        uint256 crateAmount,
        uint256 crateBdv
    ) internal returns (uint256, uint256) { 
        AppStorage storage s = LibAppStorage.diamondStorage();
        // divide the newStem by 1e6 to get the legacy stem.
        uint256 legacyDepositId = LibBytes.packAddressAndStem(token, newStem.div(1e6));
        uint256 legacyAmount = s.a[account].legacyV3Deposits[legacyDepositId].amount;
        uint256 legacyBdv = s.a[account].legacyV3Deposits[legacyDepositId].bdv;
        crateAmount = crateAmount.add(legacyAmount);
        crateBdv = crateBdv.add(legacyBdv);
        delete s.a[account].legacyV3Deposits[legacyDepositId];

        // Emit burn events.
        emit TransferSingle(
            msg.sender,
            account,
            address(0),
            legacyDepositId,
            legacyAmount
        );

        emit RemoveDeposit(
            account,
            token,
            newStem.div(1e6),
            legacyAmount,
            legacyBdv
        );

        // Emit mint events.
        emit TransferSingle(
            msg.sender,
            address(0),
            account,
            LibBytes.packAddressAndStem(token, newStem),
            legacyAmount
        );

        emit AddDeposit(
            account,
            token,
            newStem,
            legacyAmount,
            legacyBdv
        );

        return (crateAmount, crateBdv);
    }

    function toInt96(uint256 value) internal pure returns (int96) {
        require(value <= uint256(type(int96).max), "SafeCast: value doesn't fit in an int96");
        return int96(value);
    }
}


// File: contracts/libraries/Silo/LibWhitelistedTokens.sol
/*
 SPDX-License-Identifier: MIT
*/

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import {C} from "../../C.sol";
import {AppStorage, Storage, LibAppStorage} from "contracts/libraries/LibAppStorage.sol";

/**
 * @title LibWhitelistedTokens
 * @author Brean, Brendan
 * @notice LibWhitelistedTokens holds different lists of types of Whitelisted Tokens.
 * 
 * @dev manages the WhitelistStatuses for all tokens in the Silo in order to track lists.
 * Note: dewhitelisting a token doesn't remove it's WhitelistStatus entirely–It just modifies it.
 * Once a token has no more Deposits in the Silo, it's WhitelistStatus should be removed through calling `removeWhitelistStatus`.
 */
library LibWhitelistedTokens {


    /** 
     * @notice Emitted when a Whitelis Status is added.
     */
    event AddWhitelistStatus(
        address token,
        uint256 index,
        bool isWhitelisted,
        bool isWhitelistedLp,
        bool isWhitelistedWell
    );

    /**
     * @notice Emitted when a Whitelist Status is removed.
     */
    event RemoveWhitelistStatus(
        address token,
        uint256 index
    );

    /**
     * @notice Emitted when a Whitelist Status is updated.
     */
    event UpdateWhitelistStatus(
        address token,
        uint256 index,
        bool isWhitelisted,
        bool isWhitelistedLp,
        bool isWhitelistedWell
    );

    /**
     * @notice Returns all tokens that are currently or previously in the silo, 
     * including Unripe tokens.
     * @dev includes Dewhitelisted tokens with existing Deposits.
     */
    function getSiloTokens() internal view returns (address[] memory tokens) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 numberOfSiloTokens = s.whitelistStatuses.length;

        tokens = new address[](numberOfSiloTokens);

        for (uint256 i = 0; i < numberOfSiloTokens; i++) {
            tokens[i] = s.whitelistStatuses[i].token;
        }
    }

    /**
     * @notice Returns the current Whitelisted tokens, including Unripe tokens.
     */
    function getWhitelistedTokens() internal view returns (address[] memory tokens) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 numberOfSiloTokens = s.whitelistStatuses.length;
        uint256 tokensLength;
    
        tokens = new address[](numberOfSiloTokens);

        for (uint256 i = 0; i < numberOfSiloTokens; i++) {
            if (s.whitelistStatuses[i].isWhitelisted) {
                tokens[tokensLength++] = s.whitelistStatuses[i].token;
            }
        }
        assembly {
            mstore(tokens, tokensLength)
        }
    }

    /**
     * @notice Returns the current Whitelisted LP tokens. 
     * @dev Unripe LP is not an LP token.
     */
    function getWhitelistedLpTokens() internal view returns (address[] memory tokens) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 numberOfSiloTokens = s.whitelistStatuses.length;
        uint256 tokensLength;

        tokens = new address[](numberOfSiloTokens);

        for (uint256 i = 0; i < numberOfSiloTokens; i++) {
            if (s.whitelistStatuses[i].isWhitelistedLp) {
                // assembly {
                //     mstore(tokens, add(mload(tokens), 1))
                // }
                tokens[tokensLength++] = s.whitelistStatuses[i].token;
            }
        }
        assembly {
            mstore(tokens, tokensLength)
        }
    }

    /**
     * @notice Returns the current Whitelisted Well LP tokens.
     */
    function getWhitelistedWellLpTokens() internal view returns (address[] memory tokens) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 numberOfSiloTokens = s.whitelistStatuses.length;
        uint256 tokensLength;

        tokens = new address[](numberOfSiloTokens);

        for (uint256 i = 0; i < numberOfSiloTokens; i++) {
            if (s.whitelistStatuses[i].isWhitelistedWell) {
                tokens[tokensLength++] = s.whitelistStatuses[i].token;
            }
        }
        assembly {
            mstore(tokens, tokensLength)
        }
    }

    /**
     * @notice Returns the Whitelist statues for all tokens that have been whitelisted and not manually removed.
     */
    function getWhitelistedStatuses() internal view returns (Storage.WhitelistStatus[] memory _whitelistStatuses) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        _whitelistStatuses = s.whitelistStatuses;
    }

    /**
     * @notice Returns the Whitelist status for a given token.
     */
    function getWhitelistedStatus(address token) internal view returns (Storage.WhitelistStatus memory _whitelistStatus) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 tokenStatusIndex = findWhitelistStatusIndex(token);
        _whitelistStatus = s.whitelistStatuses[tokenStatusIndex];
    }

    /**
     * @notice Adds a Whitelist Status for a given `token`.
     */
    function addWhitelistStatus(address token, bool isWhitelisted, bool isWhitelistedLp, bool isWhitelistedWell) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.whitelistStatuses.push(Storage.WhitelistStatus(
            token,
            isWhitelisted,
            isWhitelistedLp,
            isWhitelistedWell
        ));

        emit AddWhitelistStatus(token, s.whitelistStatuses.length - 1, isWhitelisted, isWhitelistedLp, isWhitelistedWell);
    }

    /**
     * @notice Modifies the exisiting Whitelist Status of `token`.
     */
    function updateWhitelistStatus(address token, bool isWhitelisted, bool isWhitelistedLp, bool isWhitelistedWell) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 tokenStatusIndex = findWhitelistStatusIndex(token);
        s.whitelistStatuses[tokenStatusIndex].isWhitelisted = isWhitelisted;
        s.whitelistStatuses[tokenStatusIndex].isWhitelistedLp = isWhitelistedLp;
        s.whitelistStatuses[tokenStatusIndex].isWhitelistedWell = isWhitelistedWell;

        emit UpdateWhitelistStatus(
            token,
            tokenStatusIndex,
            isWhitelisted,
            isWhitelistedLp,
            isWhitelistedWell
        );
    }

    /**
     * @notice Removes `token`'s Whitelist Status.
     */
    function removeWhitelistStatus(address token) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 tokenStatusIndex = findWhitelistStatusIndex(token);
        s.whitelistStatuses[tokenStatusIndex] = s.whitelistStatuses[s.whitelistStatuses.length - 1];
        s.whitelistStatuses.pop();

        emit RemoveWhitelistStatus(token, tokenStatusIndex);
    }

    /**
     * @notice Finds the index of a given `token`'s Whitelist Status.
     */
    function findWhitelistStatusIndex(address token) private view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 whitelistedStatusLength = s.whitelistStatuses.length;
        uint256 i;
        while (s.whitelistStatuses[i].token != token) {
            i++;
            if (i >= whitelistedStatusLength) {
                revert("LibWhitelistedTokens: Token not found");
            }
        }
        return i;
    }

    /**
     * @notice checks if a token is whitelisted.
     * @dev checks whether a token is in the whitelistStatuses array. If it is,
     * verify whether `isWhitelisted` is set to false.
     * @param token the token to check.
     */
    function checkWhitelisted(address token) internal view returns (bool isWhitelisted, bool previouslyWhitelisted) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 whitelistedStatusLength = s.whitelistStatuses.length;
        uint256 i;
        while (s.whitelistStatuses[i].token != token) {
            i++;
            if (i >= whitelistedStatusLength) {
                // if the token does not appear in the array
                // it has not been whitelisted nor dewhitelisted.
                return (false, false);
            }
        }

        if (s.whitelistStatuses[i].isWhitelisted) {
            // token is whitelisted.
            return (true, false);
        } else {
            // token has been whitelisted previously.
            return (false, true);
        }
    }
}


// File: contracts/libraries/Token/LibBalance.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/SafeCast.sol";
import {AppStorage, LibAppStorage} from "../LibAppStorage.sol";

/**
 * @title LibInternalBalance
 * @author LeoFib, Publius
 * @notice Handles internal read/write functions for Internal User Balances.
 * Largely inspired by Balancer's Vault.
 */
library LibBalance {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SafeCast for uint256;

    /**
     * @notice Emitted when an account's Internal Balance changes.
     * @param account The account whose balance changed.
     * @param token Which token balance changed.
     * @param delta The amount the balance increased (if positive) or decreased (if negative).
     */
    event InternalBalanceChanged(
        address indexed account,
        IERC20 indexed token,
        int256 delta
    );

    /**
     * @dev Returns the sum of `account`'s Internal and External (ERC20) balance of `token`
     */
    function getBalance(address account, IERC20 token)
        internal
        view
        returns (uint256 balance)
    {
        balance = token.balanceOf(account).add(
            getInternalBalance(account, token)
        );
        return balance;
    }

    /**
     * @dev Increases `account`'s Internal Balance of `token` by `amount`.
     */
    function increaseInternalBalance(
        address account,
        IERC20 token,
        uint256 amount
    ) internal {
        uint256 currentBalance = getInternalBalance(account, token);
        uint256 newBalance = currentBalance.add(amount);
        setInternalBalance(account, token, newBalance, amount.toInt256());
    }

    /**
     * @dev Decreases `account`'s Internal Balance of `token` by `amount`. If `allowPartial` is true, this function
     * doesn't revert if `account` doesn't have enough balance, and sets it to zero and returns the deducted amount
     * instead.
     */
    function decreaseInternalBalance(
        address account,
        IERC20 token,
        uint256 amount,
        bool allowPartial
    ) internal returns (uint256 deducted) {
        uint256 currentBalance = getInternalBalance(account, token);
        require(
            allowPartial || (currentBalance >= amount),
            "Balance: Insufficient internal balance"
        );

        deducted = Math.min(currentBalance, amount);
        // By construction, `deducted` is lower or equal to `currentBalance`, 
        // so we don't need to use checked arithmetic.
        uint256 newBalance = currentBalance - deducted;
        setInternalBalance(account, token, newBalance, -(deducted.toInt256()));
    }

    /**
     * @dev Sets `account`'s Internal Balance of `token` to `newBalance`.
     *
     * Emits an {InternalBalanceChanged} event. This event includes `delta`, which is the amount the balance increased
     * (if positive) or decreased (if negative). To avoid reading the current balance in order to compute the delta,
     * this function relies on the caller providing it directly.
     */
    function setInternalBalance(
        address account,
        IERC20 token,
        uint256 newBalance,
        int256 delta
    ) private {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.internalTokenBalance[account][token] = newBalance;
        emit InternalBalanceChanged(account, token, delta);
    }

    /**
     * @dev Returns `account`'s Internal Balance of `token`.
     */
    function getInternalBalance(address account, IERC20 token)
        internal
        view
        returns (uint256 balance)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        balance = s.internalTokenBalance[account][token];
    }
}


// File: contracts/libraries/Token/LibTransfer.sol
// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../interfaces/IBean.sol";
import "./LibBalance.sol";

/**
 * @title LibTransfer
 * @author Publius
 * @notice Handles the recieving and sending of Tokens to/from internal Balances.
 */
library LibTransfer {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    enum From {
        EXTERNAL,
        INTERNAL,
        EXTERNAL_INTERNAL,
        INTERNAL_TOLERANT
    }
    enum To {
        EXTERNAL,
        INTERNAL
    }

    function transferToken(
        IERC20 token,
        address sender,
        address recipient,
        uint256 amount,
        From fromMode,
        To toMode
    ) internal returns (uint256 transferredAmount) {
        if (fromMode == From.EXTERNAL && toMode == To.EXTERNAL) {
            uint256 beforeBalance = token.balanceOf(recipient);
            token.safeTransferFrom(sender, recipient, amount);
            return token.balanceOf(recipient).sub(beforeBalance);
        }
        amount = receiveToken(token, amount, sender, fromMode);
        sendToken(token, amount, recipient, toMode);
        return amount;
    }

    function receiveToken(
        IERC20 token,
        uint256 amount,
        address sender,
        From mode
    ) internal returns (uint256 receivedAmount) {
        if (amount == 0) return 0;
        if (mode != From.EXTERNAL) {
            receivedAmount = LibBalance.decreaseInternalBalance(
                sender,
                token,
                amount,
                mode != From.INTERNAL
            );
            if (amount == receivedAmount || mode == From.INTERNAL_TOLERANT)
                return receivedAmount;
        }
        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(sender, address(this), amount - receivedAmount);
        return
            receivedAmount.add(
                token.balanceOf(address(this)).sub(beforeBalance)
            );
    }

    function sendToken(
        IERC20 token,
        uint256 amount,
        address recipient,
        To mode
    ) internal {
        if (amount == 0) return;
        if (mode == To.INTERNAL)
            LibBalance.increaseInternalBalance(recipient, token, amount);
        else token.safeTransfer(recipient, amount);
    }

    function burnToken(
        IBean token,
        uint256 amount,
        address sender,
        From mode
    ) internal returns (uint256 burnt) {
        // burnToken only can be called with Unripe Bean, Unripe Bean:3Crv or Bean token, which are all Beanstalk tokens.
        // Beanstalk's ERC-20 implementation uses OpenZeppelin's ERC20Burnable
        // which reverts if burnFrom function call cannot burn full amount.
        if (mode == From.EXTERNAL) {
            token.burnFrom(sender, amount);
            burnt = amount;
        } else {
            burnt = LibTransfer.receiveToken(token, amount, sender, mode);
            token.burn(burnt);
        }
    }

    function mintToken(
        IBean token,
        uint256 amount,
        address recipient,
        To mode
    ) internal {
        if (mode == To.EXTERNAL) {
            token.mint(recipient, amount);
        } else {
            token.mint(address(this), amount);
            LibTransfer.sendToken(token, amount, recipient, mode);
        }
    }
}


