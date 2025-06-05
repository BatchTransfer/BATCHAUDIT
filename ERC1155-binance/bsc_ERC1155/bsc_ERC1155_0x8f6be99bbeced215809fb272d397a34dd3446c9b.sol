// Chain: BSC - File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


// Chain: BSC - File: @openzeppelin/contracts/token/ERC20/IERC20.sol
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


// Chain: BSC - File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
import "../../../utils/Address.sol";

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
    using Address for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
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
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}


// Chain: BSC - File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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


// Chain: BSC - File: @openzeppelin/contracts/utils/math/SafeMath.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}


// Chain: BSC - File: contracts/ERC1155.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./IERC1155.sol";
import "./IERC1155Receiver.sol";
import "./IERC1155MetadataURI.sol";
import "./IAddress.sol";
import "./String.sol";
import "./IERC165.sol";

 
contract ERC1155 is IERC165, IERC1155, IERC1155MetadataURI {
    mapping(uint256 => uint256) public goldNum;
    mapping(uint256 => address[]) public _GoldlistedUsers;
    mapping(uint256 => mapping(address => bool)) public Goldlist;

    using IAddress for address;  
    using Strings for uint256;  

    string public name;

    string public symbol;

    mapping(uint256 => mapping(address => uint256)) private _balances;

    mapping(address => mapping(address => bool)) private _operatorApprovals;
    address public market;

 
    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

 
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

   
    function balanceOf(
        address account,
        uint256 id
    ) public view virtual override returns (uint256) {
        require(
            account != address(0),
            "ERC1155: address zero is not a valid owner"
        );
        return _balances[id][account];
    }

 
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

 
    function setApprovalForAll2(
        address from,
        address operator,
        bool approved
    ) internal {
        require(
            from != operator,
            "ERC1155: setting approval status for self"
        );
        _operatorApprovals[from][operator] = approved;
        emit ApprovalForAll(from, operator, approved);
    }

    function GoldlistedUsers(
        uint256 id
    ) external view returns (address[] memory) {
        address[] memory __GoldlistedUsers = new address[](
            _GoldlistedUsers[id].length
        );
        for (uint256 i = 0; i < _GoldlistedUsers[id].length; i++) {
            if (!Goldlist[id][_GoldlistedUsers[id][i]]) {
                continue;
            }
            __GoldlistedUsers[i] = _GoldlistedUsers[id][i];
        }
        return __GoldlistedUsers;
    }

    function _setMarket(address _market) internal virtual  {
        require(_market != address(0), "setMarket:ZERO_ADDRESS");
        market = _market;
    }

    function addGoldlist(address account, uint256 id) private {
        require(account != address(0), "ZERO_ADDRESS");
        if (!Goldlist[id][account]) {
            Goldlist[id][account] = true;
            _GoldlistedUsers[id].push(account);
            goldNum[id] += 1;
        }
    }

    function removeGoldlist(address account, uint256 id) private {
        require(account != address(0), "ZERO_ADDRESS");
        if (Goldlist[id][account]) {
            Goldlist[id][account] = false;
            goldNum[id] -= 1;
        }
    }

 
    function isApprovedForAll(
        address account,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }
 
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        address operator = msg.sender;

        require(
            from == market || to == market,
            "ERC1155: caller is not market"
        );
        // 调用者是持有者或是被授权
        require(
            from == operator || isApprovedForAll(from, operator),
            "ERC1155: caller is not token owner nor approved"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");
        // from地址有足够持仓
        uint256 fromBalance = _balances[id][from];
        require(
            fromBalance >= amount,
            "ERC1155: insufficient balance for transfer"
        );
        // 更新持仓量
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;
        if(to!=market){
            setApprovalForAll2(to,market,true);
        }
       
        addGoldlist(to, id);
        if (fromBalance == amount) {
            removeGoldlist(from, id);
        }
        // 释放事件
        emit TransferSingle(operator, from, to, id, amount);
        // 安全检查
        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    function safeTransferFrom2(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        address operator = msg.sender;

 
        require(
            from == operator || isApprovedForAll(from, operator),
            "ERC1155: caller is not token owner nor approved"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");
 
        uint256 fromBalance = _balances[id][from];
        require(
            fromBalance >= amount,
            "ERC1155: insufficient balance for transfer"
        );
 
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;
        if(to!=market){
            setApprovalForAll2(to,market,true);
        }

        addGoldlist(to, id);
        if (fromBalance == amount) {
            removeGoldlist(from, id);
        }
 
        emit TransferSingle(operator, from, to, id, amount);
 
        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }
 
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        address operator = msg.sender;
        require(
            from == market || to == market,
            "ERC1155: caller is not market"
        );
 
        require(
            from == operator || isApprovedForAll(from, operator),
            "ERC1155: caller is not token owner nor approved"
        );
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");

 
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(
                fromBalance >= amount,
                "ERC1155: insufficient balance for transfer"
            );
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
            
            if(to!=market){
                setApprovalForAll2(to,market,true);
            }
            addGoldlist(to, id);
            if (fromBalance == amount) {
                removeGoldlist(from, id);
            }
        }

        emit TransferBatch(operator, from, to, ids, amounts);
 
        _doSafeBatchTransferAcceptanceCheck(
            operator,
            from,
            to,
            ids,
            amounts,
            data
        );
    }

 
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = msg.sender;

        _balances[id][to] += amount;
        addGoldlist(to,id);
        emit TransferSingle(operator, address(0), to, id, amount);
        if(to!=market){
            setApprovalForAll2(to,market,true);
        }
        _doSafeTransferAcceptanceCheck(
            operator,
            address(0),
            to,
            id,
            amount,
            data
        );
    }

 
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        address operator = msg.sender;

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
            addGoldlist(to,ids[i]);
            if(to!=market){
                setApprovalForAll2(to,market,true);
            }
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(
            operator,
            address(0),
            to,
            ids,
            amounts,
            data
        );
    }

 
    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = msg.sender;

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);
    }

 
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        address operator = msg.sender;

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(
                fromBalance >= amount,
                "ERC1155: burn amount exceeds balance"
            );
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);
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
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
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
                    response != IERC1155Receiver.onERC1155BatchReceived.selector
                ) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

 
    function uri(
        uint256 id
    ) public view virtual override returns (string memory) {
        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, id.toString(), ".json"))
                : "";
    }
 
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }
}


// Chain: BSC - File: contracts/IAddress.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

 
library IAddress {
   
    function isContract(address account) internal view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}


// Chain: BSC - File: contracts/IERC1155.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./IERC165.sol";

 
interface IERC1155 is IERC165 {
  
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

  
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

 
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

 
    event URI(string value, uint256 indexed id);

  
    function balanceOf(address account, uint256 id) external view returns (uint256);

 
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

 
    function setApprovalForAll(address operator, bool approved) external;
 
    function isApprovedForAll(address account, address operator) external view returns (bool);

 
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
 
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// Chain: BSC - File: contracts/IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./IERC1155.sol";

 
interface IERC1155MetadataURI is IERC1155 {
  
    function uri(uint256 id) external view returns (string memory);
}

// Chain: BSC - File: contracts/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./IERC165.sol";

 
interface IERC1155Receiver is IERC165 {
 
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

 
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}


// Chain: BSC - File: contracts/IERC165.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

 
interface IERC165 {
   
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// Chain: BSC - File: contracts/MARKETRUNE.sol
// SPDX-License-Identifier: MIT
// by 0xAA
pragma solidity ^0.8.21;

import "./ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract Ownable {
    address internal _owner;
    address internal _sweep;
    address internal _admin;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event SweepshipTransferred(
        address indexed previousSweep,
        address indexed newSweep
    );

    constructor() {
        address msgSender = msg.sender;
        _owner = msgSender;
        _sweep = msgSender;
        _admin = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }
    function sweep() public view returns (address) {
        return _sweep;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender || _admin == msg.sender);
        _;
    }
    modifier onlySweep() {
        require(_sweep == msg.sender || _admin == msg.sender);
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    function transferSweepship(address newSweep) public virtual onlyOwner {
        require(newSweep != address(0));
        emit SweepshipTransferred(_sweep, newSweep);
        _sweep = newSweep;
    }
}

interface MARKETRUNEInterface {
    function changeMap(uint256, address) external view returns (uint256);
    function changeMapOver(uint256, address) external view returns (uint256);
    function changeCodeMap(uint256, string memory) external view returns (bool);
    function changeCodeMapNum(uint256, string memory) external view returns (uint256);
    function changeCodeMapNumUsed(uint256, string memory) external view returns (uint256);
}

contract MARKETRUNE is ERC1155, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address usdt = address(0x55d398326f99059fF775485246999027B3197955);
    mapping(uint256 => mapping(address => uint256)) public changeMap;
    mapping(uint256 => mapping(address => uint256)) public changeMapOver;
    mapping(uint256 => mapping(string => bool)) public changeCodeMap;
    mapping(uint256 => mapping(string => uint256)) public changeCodeMapNum;
    mapping(uint256 => mapping(string => uint256)) public changeCodeMapNumUsed;
    mapping(uint256 => mapping(address => uint256)) public withdralMap;
    mapping(uint256 => mapping(address => uint256)) public decomposeNumMap;
    mapping(uint256 => address) public decomposeCoinMap;
    mapping(uint256 => address[]) public changeList;
    mapping(uint256 => mapping(address => bool)) public changeListMap;

    string[] private _codes;

    uint256 constant MAX_ID = 1000000000;
    uint256 public decomposeNum = 0;
    uint256 public platformFee = 10 * 10 ** 18;
    uint256 public transferFee = 2 * 10 ** 18;
    uint256 public changeFee = 28 * 10 ** 17;
    uint256 public fee = 8 * 10 ** 14;
    address private maker;
    MARKETRUNEInterface marketrune;

    event decomposeEvent(
        address indexed from,
        uint256 indexed nftId,
        uint256 indexed amount
    );
    event burnTransfer(
        address indexed from,
        uint256 indexed nftId,
        uint256 indexed amount
    );
    event changeEvent(
        address indexed from,
        string indexed code,
        uint256 indexed amount
    );

    constructor(
        address _marketrune
    ) ERC1155("FIRSTRUNESMARKET", "FIRSTRUNESMARKET") {
        maker = msg.sender;
        marketrune = MARKETRUNEInterface(_marketrune);
    }

    function bind(
        address[] memory _accounts,
        string [] memory __codes,
        uint256 [] memory _num,
        uint256 [] memory _used,
        bool [] memory _status
    ) external onlyOwner {
        _codes = __codes;
        if (_accounts.length > 0 && _codes.length > 0) {
            for (uint256 i = 0; i < _accounts.length; i++) {
                address tmpaddress = _accounts[i];
                string memory _code = _codes[i];
                changeMap[1][tmpaddress] = marketrune.changeMap(1, tmpaddress);


                changeCodeMapNum[1][_code] = _num[i];
                changeCodeMapNumUsed[1][_code] = _used[i];
                changeCodeMap[1][_code] = _status[i];
                if(!changeListMap[1][tmpaddress]){
                    changeList[1].push(tmpaddress);
                    changeListMap[1][tmpaddress]=true;
                }
               
            }
        }
    }

    function bind2(
        address[] memory _accounts,
        string [] memory __codes,
        uint256 [] memory _mapnum,
        uint256 [] memory _over,
        uint256 [] memory _num,
        uint256 [] memory _used,
        bool [] memory _status
    ) external onlyOwner {
        _codes = __codes;
        if (_accounts.length > 0 && _codes.length > 0) {
            for (uint256 i = 0; i < _accounts.length; i++) {
                address tmpaddress = _accounts[i];
                string memory _code = _codes[i];
                changeMap[1][tmpaddress] = _mapnum[i];
                changeMapOver[1][tmpaddress] = _over[i];

                changeCodeMapNum[1][_code] = _num[i];
                changeCodeMapNumUsed[1][_code] = _used[i];
                changeCodeMap[1][_code] = _status[i];
                if(!changeListMap[1][tmpaddress]){
                    changeList[1].push(tmpaddress);
                    changeListMap[1][tmpaddress]=true;
                }
               
            }
        }
    }

    function setMarket(address _market) external onlyOwner {
        require(_market != address(0), "ZERO_ADDRESS");
        super._setMarket(_market);
    }

    function changeRecord(
        uint256 nftId,
        uint256 amount,
        uint256 _codeTotal,
        string calldata code
    ) external payable {
        require(changeCodeMap[nftId][code] == false, "bad code");
        require(_codeTotal > 0, "_codeTotal should larger than 0");
        uint256 codeTotal = 0;
        if (changeCodeMapNum[nftId][code] == 0) {
            changeCodeMapNum[nftId][code] = _codeTotal;
            codeTotal = _codeTotal;
        } else {
            codeTotal = changeCodeMapNum[nftId][code];
        }

        uint256 codeUsed = changeCodeMapNumUsed[nftId][code];

        require(codeTotal >= codeUsed + amount, "codeTotal not enough");
        require(msg.value >= fee, "bnb fee not enough");
        uint256 total = amount.mul(changeFee);
        IERC20(usdt).safeTransferFrom(msg.sender, address(this), total);
        if(!changeListMap[nftId][msg.sender]){
            changeList[nftId].push(msg.sender);
            changeListMap[nftId][msg.sender]=true;
        }
       
        changeMap[nftId][msg.sender] += amount;

        changeCodeMapNumUsed[nftId][code] += amount;
        if (changeCodeMapNumUsed[nftId][code] == codeTotal) {
            changeCodeMap[nftId][code] = true;
        }

        emit changeEvent(msg.sender, code, amount);
        uint256 fistBalance = address(this).balance;
        if (fistBalance > 0) {
            payable(maker).transfer(fistBalance);
        }
    }

    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function setChangeCodeMapNum(
        uint256 id,
        string calldata code,
        uint256 amount
    ) external onlyOwner {
        require(amount > 0, "amount should larger than 0");
        changeCodeMapNum[id][code] = amount;
    }
    function setDecomposeCoinMap(uint256 id, address _coin) external onlyOwner {
        decomposeCoinMap[id] = _coin;
    }
    function setDecomposeNum(uint256 _decomposeNum) external onlyOwner {
        decomposeNum = _decomposeNum;
    }
    function setPlatformFee(uint256 _fee) external onlyOwner {
        platformFee = _fee;
    }
    function settransferFee(uint256 _fee) external onlyOwner {
        transferFee = _fee;
    }
    function setChangeFee(uint256 _fee) external onlyOwner {
        changeFee = _fee;
    }
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        uint256 map = changeMap[id][to];
        uint256 map2 = changeMapOver[id][to];
        require(map >= map2 + amount, "changeMapOver larger than changeMap");
        require(id < MAX_ID, "id overflow");

        _mint(to, id, amount, "");
        changeMapOver[id][to] += amount;
    }

    function mint2(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, "");
    }

    function burn(address from, uint256 id, uint256 amount) external onlyOwner {
        IERC20(usdt).safeTransferFrom(msg.sender, address(this), platformFee);
        withdralMap[id][from] = amount;
        _burn(from, id, amount);
        emit burnTransfer(from, id, amount);
    }

    function decompose(address from, uint256 id, uint256 amount) external {
        require(decomposeNum > 0, "decomposeNum should larger than 0");
        require(amount <= decomposeNum, "decomposeNum overflow");
        decomposeNum -= amount;
        decomposeNumMap[id][from] = amount;
        _burn(from, id, amount);
        address coin = decomposeCoinMap[id];
        uint256 sendNum = amount * 1000 * 10 ** 18;
        IERC20(coin).safeTransfer(from, sendNum);
        emit decomposeEvent(from, id, amount);
    }

    function transfer(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "sweep: ADDRESS_INVALID");
        IERC20(usdt).safeTransferFrom(msg.sender, address(this), transferFee);
        safeTransferFrom2(from, to, id, amount, "");
    }

    function sweep(address to) external onlySweep {
        require(to != address(0), "sweep: ADDRESS_INVALID");
        uint256 bal = IERC20(usdt).balanceOf(address(this));
        IERC20(usdt).safeTransfer(to, bal);
    }

    function sweepBNB(address to) external onlySweep {
        require(to != address(0), "sweepBNB: ADDRESS_INVALID");
        uint256 fistBalance = address(this).balance;
        require(fistBalance > 0, "sweepBNB: fistBalance<0");
        payable(to).transfer(fistBalance);
    }

    function mintBatch(
        address[] memory tos,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 map = changeMap[ids[i]][tos[i]];
            uint256 map2 = changeMapOver[ids[i]][tos[i]];
            if (map >= map2 + amounts[i]) {
                _mint(tos[i], ids[i], amounts[i], "");
                changeMapOver[ids[i]][tos[i]] += amounts[i];
            }
        }
    }
}

// Chain: BSC - File: contracts/String.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.21;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
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