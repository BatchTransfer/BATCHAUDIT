// File: @openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// File: @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}


// File: @openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
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


// File: @openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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


// File: @openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
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
    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
     */
    function forceApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
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
        IERC20PermitUpgradeable token,
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
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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
    function _callOptionalReturnBool(IERC20Upgradeable token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && AddressUpgradeable.isContract(address(token));
    }
}


// File: @openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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


// File: @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// File: @openzeppelin/contracts/utils/structs/BitMaps.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/structs/BitMaps.sol)
pragma solidity ^0.8.0;

/**
 * @dev Library for managing uint256 to bool mapping in a compact and efficient way, providing the keys are sequential.
 * Largely inspired by Uniswap's https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol[merkle-distributor].
 */
library BitMaps {
    struct BitMap {
        mapping(uint256 => uint256) _data;
    }

    /**
     * @dev Returns whether the bit at `index` is set.
     */
    function get(BitMap storage bitmap, uint256 index) internal view returns (bool) {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        return bitmap._data[bucket] & mask != 0;
    }

    /**
     * @dev Sets the bit at `index` to the boolean `value`.
     */
    function setTo(BitMap storage bitmap, uint256 index, bool value) internal {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }

    /**
     * @dev Sets the bit at `index`.
     */
    function set(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] |= mask;
    }

    /**
     * @dev Unsets the bit at `index`.
     */
    function unset(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] &= ~mask;
    }
}


// File: contracts/interfaces/IVault.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import { Assets, Fees, TradeDetailed } from "../utils/DataTypes.sol";

/// @title NF3 Vault Interface
/// @author NF3 Exchange
/// @dev This interface defines all the functions related to assets transfer and assets escrow.

interface IVault {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    enum VaultErrorCodes {
        CALLER_NOT_ALLOWED,
        INVALID_ADDRESS
    }

    error VaultError(VaultErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emits when assets are transffered from a user to the vault
    /// @param assets Assets struct that is transfered
    /// @param from Address from which assets are transfered
    event AssetsReceived(Assets assets, address indexed from);

    /// @dev Emits when assets are transffered to a user from the vault
    /// @param assets Assets struct that is transfered
    /// @param to Address to which assets are transfered
    event AssetsSent(Assets assets, address indexed to);

    /// @dev Emits when fees is transferred from buyer and seller
    /// @param fees Fees details that are taken from buyer and seller
    /// @param user Address of the user who paid the fee
    event FeeTransferred(Fees fees, address indexed user);

    /// @dev Emits when new core contract address has set.
    /// @param oldCoreAddress Previous core contract address
    /// @param newCoreAddress New core contract address
    event CoreSet(address oldCoreAddress, address newCoreAddress);

    /// -----------------------------------------------------------------------
    /// Transfer actions
    /// -----------------------------------------------------------------------

    /// @dev Receive assets from seller and buyer, also deducts fees while receiving assets
    ///      Restricted function can only be called by the core contract
    /// @param trade Trade details from which assets need to be received
    /// @param buyerFees Fees details for buyer
    /// @param sellerFees Fees details for seller
    function receiveAssets(
        TradeDetailed calldata trade,
        Fees calldata buyerFees,
        Fees calldata sellerFees
    ) external returns (bool);

    /// @dev Sends locked assets to the mentioned address. Restricted function, can only be called
    ///      by the core contract
    /// @param assets Assets details that need to be sent
    /// @param to Address to which assets need to be sent
    function sendAssets(
        Assets memory assets,
        address to
    ) external returns (bool);

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @dev Set core contract's address. Restricted function, can only be called by owner
    /// @param coreAddress Address of the new core contract
    function setCoreAddress(address coreAddress) external;
}


// File: contracts/libraries/TokenTransferrerConstants.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/*
 * -------------------------- Disambiguation & Other Notes ---------------------
 *    - The term "head" is used as it is in the documentation for ABI encoding,
 *      but only in reference to dynamic types, i.e. it always refers to the
 *      offset or pointer to the body of a dynamic type. In calldata, the head
 *      is always an offset (relative to the parent object), while in memory,
 *      the head is always the pointer to the body. More information found here:
 *      https://docs.soliditylang.org/en/v0.8.17/abi-spec.html#argument-encoding
 *        - Note that the length of an array is separate from and precedes the
 *          head of the array.
 *
 *    - The term "body" is used in place of the term "head" used in the ABI
 *      documentation. It refers to the start of the data for a dynamic type,
 *      e.g. the first word of a struct or the first word of the first element
 *      in an array.
 *
 *    - The term "pointer" is used to describe the absolute position of a value
 *      and never an offset relative to another value.
 *        - The suffix "_ptr" refers to a memory pointer.
 *        - The suffix "_cdPtr" refers to a calldata pointer.
 *
 *    - The term "offset" is used to describe the position of a value relative
 *      to some parent value. For example, OrderParameters_conduit_offset is the
 *      offset to the "conduit" value in the OrderParameters struct relative to
 *      the start of the body.
 *        - Note: Offsets are used to derive pointers.
 *
 *    - Some structs have pointers defined for all of their fields in this file.
 *      Lines which are commented out are fields that are not used in the
 *      codebase but have been left in for readability.
 */

uint256 constant ThirtyOneBytes = 0x1f;
uint256 constant OneWord = 0x20;
uint256 constant TwoWords = 0x40;
uint256 constant ThreeWords = 0x60;

uint256 constant OneWordShift = 0x5;
uint256 constant TwoWordsShift = 0x6;

uint256 constant FreeMemoryPointerSlot = 0x40;
uint256 constant ZeroSlot = 0x60;
uint256 constant DefaultFreeMemoryPointer = 0x80;

uint256 constant Slot0x80 = 0x80;
uint256 constant Slot0xA0 = 0xa0;
uint256 constant Slot0xC0 = 0xc0;

uint256 constant Generic_error_selector_offset = 0x1c;

// abi.encodeWithSignature("transferFrom(address,address,uint256)")
uint256 constant ERC20_transferFrom_signature = (
    0x23b872dd00000000000000000000000000000000000000000000000000000000
);
uint256 constant ERC20_transferFrom_sig_ptr = 0x0;
uint256 constant ERC20_transferFrom_from_ptr = 0x04;
uint256 constant ERC20_transferFrom_to_ptr = 0x24;
uint256 constant ERC20_transferFrom_amount_ptr = 0x44;
uint256 constant ERC20_transferFrom_length = 0x64; // 4 + 32 * 3 == 100

// abi.encodeWithSignature(
//     "safeTransferFrom(address,address,uint256,uint256,bytes)"
// )
uint256 constant ERC1155_safeTransferFrom_signature = (
    0xf242432a00000000000000000000000000000000000000000000000000000000
);
uint256 constant ERC1155_safeTransferFrom_sig_ptr = 0x0;
uint256 constant ERC1155_safeTransferFrom_from_ptr = 0x04;
uint256 constant ERC1155_safeTransferFrom_to_ptr = 0x24;
uint256 constant ERC1155_safeTransferFrom_id_ptr = 0x44;
uint256 constant ERC1155_safeTransferFrom_amount_ptr = 0x64;
uint256 constant ERC1155_safeTransferFrom_data_offset_ptr = 0x84;
uint256 constant ERC1155_safeTransferFrom_data_length_ptr = 0xa4;
uint256 constant ERC1155_safeTransferFrom_length = 0xc4; // 4 + 32 * 6 == 196
uint256 constant ERC1155_safeTransferFrom_data_length_offset = 0xa0;

// abi.encodeWithSignature(
//     "safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)"
// )
uint256 constant ERC1155_safeBatchTransferFrom_signature = (
    0x2eb2c2d600000000000000000000000000000000000000000000000000000000
);

// bytes4 constant ERC1155_safeBatchTransferFrom_selector = bytes4(
//     bytes32(ERC1155_safeBatchTransferFrom_signature)
// );

uint256 constant ERC721_transferFrom_signature = (
    0x23b872dd00000000000000000000000000000000000000000000000000000000
);
uint256 constant ERC721_transferFrom_sig_ptr = 0x0;
uint256 constant ERC721_transferFrom_from_ptr = 0x04;
uint256 constant ERC721_transferFrom_to_ptr = 0x24;
uint256 constant ERC721_transferFrom_id_ptr = 0x44;
uint256 constant ERC721_transferFrom_length = 0x64; // 4 + 32 * 3 == 100

/*
 *  error NoContract(address account)
 *    - Defined in TokenTransferrerErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 *    - 0x00: account
 * Revert buffer is memory[0x1c:0x40]
 */
uint256 constant NoContract_error_selector = 0x5f15d672;
uint256 constant NoContract_error_account_ptr = 0x20;
uint256 constant NoContract_error_length = 0x24;

/*
 *  error TokenTransferGenericFailure(
 *      address token,
 *      address from,
 *      address to,
 *      uint256 identifier,
 *      uint256 amount
 *  )
 *    - Defined in TokenTransferrerErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 *    - 0x20: token
 *    - 0x40: from
 *    - 0x60: to
 *    - 0x80: identifier
 *    - 0xa0: amount
 * Revert buffer is memory[0x1c:0xc0]
 */
uint256 constant TokenTransferGenericFailure_error_selector = 0xf486bc87;
uint256 constant TokenTransferGenericFailure_error_token_ptr = 0x20;
uint256 constant TokenTransferGenericFailure_error_from_ptr = 0x40;
uint256 constant TokenTransferGenericFailure_error_to_ptr = 0x60;
uint256 constant TokenTransferGenericFailure_error_identifier_ptr = 0x80;
uint256 constant TokenTransferGenericFailure_err_identifier_ptr = 0x80;
uint256 constant TokenTransferGenericFailure_error_amount_ptr = 0xa0;
uint256 constant TokenTransferGenericFailure_error_length = 0xa4;

uint256 constant ExtraGasBuffer = 0x20;
uint256 constant CostPerWord = 0x3;
uint256 constant MemoryExpansionCoefficientShift = 0x9;

// Values are offset by 32 bytes in order to write the token to the beginning
// in the event of a revert
uint256 constant BatchTransfer1155Params_ptr = 0x24;
uint256 constant BatchTransfer1155Params_ids_head_ptr = 0x64;
uint256 constant BatchTransfer1155Params_amounts_head_ptr = 0x84;
uint256 constant BatchTransfer1155Params_data_head_ptr = 0xa4;
uint256 constant BatchTransfer1155Params_data_length_basePtr = 0xc4;
uint256 constant BatchTransfer1155Params_calldata_baseSize = 0xc4;

uint256 constant BatchTransfer1155Params_ids_length_ptr = 0xc4;

uint256 constant BatchTransfer1155Params_ids_length_offset = 0xa0;
// uint256 constant BatchTransfer1155Params_amounts_length_baseOffset = 0xc0;
// uint256 constant BatchTransfer1155Params_data_length_baseOffset = 0xe0;

uint256 constant ConduitBatch1155Transfer_usable_head_size = 0x80;

uint256 constant ConduitBatch1155Transfer_from_offset = 0x20;
uint256 constant ConduitBatch1155Transfer_ids_head_offset = 0x60;
// uint256 constant ConduitBatch1155Transfer_amounts_head_offset = 0x80;
uint256 constant ConduitBatch1155Transfer_ids_length_offset = 0xa0;
uint256 constant ConduitBatch1155Transfer_amounts_length_baseOffset = 0xc0;
// uint256 constant ConduitBatch1155Transfer_calldata_baseSize = 0xc0;

// Note: abbreviated version of above constant to adhere to line length limit.
uint256 constant ConduitBatchTransfer_amounts_head_offset = 0x80;

uint256 constant Invalid1155BatchTransferEncoding_ptr = 0x00;
uint256 constant Invalid1155BatchTransferEncoding_length = 0x04;
uint256 constant Invalid1155BatchTransferEncoding_selector = (
    0xeba2084c00000000000000000000000000000000000000000000000000000000
);

uint256 constant ERC1155BatchTransferGenericFailure_error_signature = (
    0xafc445e200000000000000000000000000000000000000000000000000000000
);
uint256 constant ERC1155BatchTransferGenericFailure_token_ptr = 0x04;
uint256 constant ERC1155BatchTransferGenericFailure_ids_offset = 0xc0;

/*
 *  error BadReturnValueFromERC20OnTransfer(
 *      address token, address from, address to, uint256 amount
 *  )
 *    - Defined in TokenTransferrerErrors.sol
 *  Memory layout:
 *    - 0x00: Left-padded selector (data begins at 0x1c)
 *    - 0x00: token
 *    - 0x20: from
 *    - 0x40: to
 *    - 0x60: amount
 * Revert buffer is memory[0x1c:0xa0]
 */
uint256 constant BadReturnValueFromERC20OnTransfer_error_selector = 0x98891923;
uint256 constant BadReturnValueFromERC20OnTransfer_error_token_ptr = 0x20;
uint256 constant BadReturnValueFromERC20OnTransfer_error_from_ptr = 0x40;
uint256 constant BadReturnValueFromERC20OnTransfer_error_to_ptr = 0x60;
uint256 constant BadReturnValueFromERC20OnTransfer_error_amount_ptr = 0x80;
uint256 constant BadReturnValueFromERC20OnTransfer_error_length = 0x84;


// File: contracts/libraries/TokenTransferrerErrors.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/**
 * @title TokenTransferrerErrors
 */
interface TokenTransferrerErrors {
    /**
     * @dev Revert with an error when an ERC721 transfer with amount other than
     *      one is attempted.
     *
     * @param amount The amount of the ERC721 tokens to transfer.
     */
    error InvalidERC721TransferAmount(uint256 amount);

    /**
     * @dev Revert with an error when attempting to fulfill an order where an
     *      item has an amount of zero.
     */
    error MissingItemAmount();

    /**
     * @dev Revert with an error when attempting to fulfill an order where an
     *      item has unused parameters. This includes both the token and the
     *      identifier parameters for native transfers as well as the identifier
     *      parameter for ERC20 transfers. Note that the conduit does not
     *      perform this check, leaving it up to the calling channel to enforce
     *      when desired.
     */
    error UnusedItemParameters();

    /**
     * @dev Revert with an error when an ERC20, ERC721, or ERC1155 token
     *      transfer reverts.
     *
     * @param token      The token for which the transfer was attempted.
     * @param from       The source of the attempted transfer.
     * @param to         The recipient of the attempted transfer.
     * @param identifier The identifier for the attempted transfer.
     * @param amount     The amount for the attempted transfer.
     */
    error TokenTransferGenericFailure(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount
    );

    /**
     * @dev Revert with an error when a batch ERC1155 token transfer reverts.
     *
     * @param token       The token for which the transfer was attempted.
     * @param from        The source of the attempted transfer.
     * @param to          The recipient of the attempted transfer.
     * @param identifiers The identifiers for the attempted transfer.
     * @param amounts     The amounts for the attempted transfer.
     */
    error ERC1155BatchTransferGenericFailure(
        address token,
        address from,
        address to,
        uint256[] identifiers,
        uint256[] amounts
    );

    /**
     * @dev Revert with an error when an ERC20 token transfer returns a falsey
     *      value.
     *
     * @param token      The token for which the ERC20 transfer was attempted.
     * @param from       The source of the attempted ERC20 transfer.
     * @param to         The recipient of the attempted ERC20 transfer.
     * @param amount     The amount for the attempted ERC20 transfer.
     */
    error BadReturnValueFromERC20OnTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    );

    /**
     * @dev Revert with an error when an account being called as an assumed
     *      contract does not have code and returns no data.
     *
     * @param account The account that should contain code.
     */
    error NoContract(address account);

    /**
     * @dev Revert with an error when attempting to execute an 1155 batch
     *      transfer using calldata not produced by default ABI encoding or with
     *      different lengths for ids and amounts arrays.
     */
    error Invalid1155BatchTransferEncoding();
}


// File: contracts/utils/DataTypes.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import { BitMaps } from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

// -----------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------

uint8 constant SELLER_BITMASK = 0x1; // 00000001
uint8 constant BUYER_BITMASK = 0x2; // 00000010
uint256 constant GAS_REQUIRED_FOR_ERC20 = 60_000;
uint256 constant GAS_REQUIRED_FOR_ERC721 = 80_000;
uint256 constant GAS_REQUIRED_FOR_ERC1155 = 60_000;
uint256 constant BASE_GAS_REQUIRED = 250_000;
uint256 constant BASE_GAS_FOR_FORWARDING = 150_000;

// -----------------------------------------------------------------------
// Typed structs
// -----------------------------------------------------------------------

/// @dev Common Assets type, packing bundle of NFTs and FTs.
/// @param assets Array of individual tokens along with their details
struct Assets {
    AssetData[] assets;
}

/// @dev Type for individual asset along with it's details
/// @param token token address
/// @param assetType type of asset represented by the address
/// @param tokenId tokenId in case of ERC721 and ERC1155 tokens. Set to 0 in case of ERC20 token
/// @param amount amount of token for ERC20 and ERC1155 tokens. Set to 1 in case of ERC721 token
struct AssetData {
    address token;
    AssetType assetType;
    uint256 tokenId;
    uint256 amount;
}

/// @dev Set of assets on both the chains, representing one side of offering by the user
/// @param primaryChainAssets Assets existing on primary chain of the trade
/// @param secondaryChainAssets Assets exisitng on secondary chain of
struct AssetsSet {
    Assets primaryChainAssets;
    Assets secondaryChainAssets;
}

/// @dev Fees to be sent to admin
/// @param to Address which will receive the fees
/// @param token ERC20 token address used for fees
/// @param amount Amount of token to be transferred
struct Fees {
    address to;
    address token;
    uint256 amount;
}

/// @dev Trade offer proposed by one of the user
/// @param offeringAssets AssetsSet offered by the seller
/// @param considerationAssets AssetsSet requested from the buyer
/// @param buyerFees Fee to be paid by the buyer
/// @param sellerFees Fee to be paid by the seller
/// @param owner Owner of the trade offer. aka seller
/// @param timePeriod Expiration timestamp of the offer
/// @param nonce Nonce of the trade
/// @param tradeIntendedFor Address to which the trade is targetted to. To be used in case of
///        private P2P trades. Can be set to address(0) to allow anyone to accept the trade
/// @param primaryChainId Wormhole chain Id of the primary chain
/// @param secondaryChainId Wormhole chain Id of the secondary chain
struct TradeOffer {
    AssetsSet offeringAssets;
    AssetsSet considerationAssets;
    Fees buyerFees;
    Fees sellerFees;
    address owner;
    uint256 timePeriod;
    uint256 nonce;
    address tradeIntendedFor;
    uint256 primaryChainId; // wormhole chain Id
    uint256 secondaryChainId; // wormhole chain Id
}

/// @dev Compressed trade data that needs to be stored on chain for each trade
///      consumes 2 slots in the storage
/// @param tradeConstantsHash Hash of the constants involved in the trade
/// @param status Current status of the trade
/// @param withdrawBitmap bit 0 represents seller's withdraw status. but 1 represnts
///        buyer's withdraw status. Used to ensure seller and buyer each withdraw only once
/// @param recoveryRequested flag used to mark if recovery of the trade is requested
struct Trade {
    bytes32 tradeContantsHash; // size 32 bytes => slot 1
    Status status; // size 1 byte => slot 2
    uint8 withdrawBitmap; // size 1 byte => slot 2
    bool recoveryRequested; // size 1 byte => slot 2
}

/// @dev Helper struct packing all the constatns involved in a trade
/// @param offeringAssets Assets offered on the current chain by the seller
/// @param considerationAssets Assets requested by the seller on the current chain
/// @param seller Address of the seller
/// @param buyer Address of the buyer
struct TradeConstants {
    Assets offeringAssets;
    Assets considerationAssets;
    address seller;
    address buyer;
}

/// @dev Actual trade data with all the details of the trade
/// @param tradeOfferHash Hash of the acutal trade offer used as uinque id.
///        Using hash because impossible to keep id's on multiple chains in sync
/// @param offeringAssets Assets offered on the current chain by the seller
/// @param considerationAssets Assets requested by the seller on the current chain
/// @param seller Address of the seller
/// @param status Current status of the trade
/// @param buyer Address of the buyer
/// @param withdrawBitmap bit 0 represents seller's withdraw status. but 1 represnts
///        buyer's withdraw status. Used to ensure seller and buyer each withdraw only once
/// @param recoveryRequested flag used to mark if recovery of the trade is requested
struct TradeDetailed {
    bytes32 tradeOfferHash;
    Assets offeringAssets;
    Assets considerationAssets;
    address seller;
    Status status;
    address buyer;
    uint8 withdrawBitmap;
    bool recoveryRequested;
}

/// @dev wormhole to be emmited when a trade has been accepted on one chain and needs
///      to be processed on other chain
/// @param payloadType Type of payload sent in the message. Used for selecting appropriate
///        function while receiving wormhole messages
/// @param tradeOfferHash Hash of the trade offer. Used as id
/// @param offeringAssets Assets offered on current chain
/// @param considerationAssets Assets requested on current chain
/// @param seller Address of the seller
/// @param buyer Address of the buyer
/// @param primaryChainId wormhole chain id of the primary chain
/// @param secondaryChainId wormhole chain id of the secondary chain
struct TradeAcceptMessage {
    PayloadType payloadType;
    bytes32 tradeOfferHash;
    Assets offeringAssets;
    Assets considerationAssets;
    address seller;
    address buyer;
    uint16 primaryChainId; // wormhole chain Id
    uint16 secondaryChainId; // wormhole chain Id
}

/// @dev wormhole message to be emmited when a trade has completed processing on
///      the secondary chain. Used to mark result of the trade
/// @param payloadType Type of payload sent in the message. Used for selecting appropriate
///        function while receiving wormhole messages
/// @param tradeOfferHash Hash of the trade offer. Used as id
/// @param result Final result of the trade
/// @param primaryChainId wormhole chain id of the primary chain
/// @param secondaryChainId wormhole chain id of the secondary chain
struct TradeResultMessage {
    PayloadType payloadType;
    bytes32 tradeOfferHash;
    Result result;
    uint16 primaryChainId; // wormhole chain Id
    uint16 secondaryChainId; // wormhole chain Id
}

/// @dev Struct to pack data regarding the gas forwarding during wormhole
///      message passing
/// @param forwardingValue Value to be passed in the message
/// @param nonce Nonce of the message
/// @param owner Owner of the message
struct ForwardingGas {
    uint256 forwardingValue;
    uint256 nonce;
    address owner;
}

/// @dev Struct to pack storage state for the protcol
/// @param wormholeRelayer wormhole core contract address
/// @param consistencyLevel number of confirmations for wormhole messages
/// @param gasSignatureAdmin admin's address who will sign the gas signatures
/// @param wormholeChainId wormhole chain id of current network
/// @param vaultAddress assets vault for the system
/// @param targetContractToChainId mapping from target contract on other chain to
///        their wormhole chain id
/// @param targetChainIdToContract mapping from wormhole chain id to target contract
///        on other chain
/// @param nonce Mapping of users and their nonce in form of bitmap
/// @param gasForwardingNonce Bitmap for gas forwarding struct of admin signature
/// @param trades trade data mapped to it's hash
/// @param consumedMessages consumed messages, used to prevent reentrancy and
///        replay
/// @param types mapping of token addresses and their Types
struct State {
    address wormholeRelayer;
    uint8 consistencyLevel;
    address gasSignatureAdmin;
    uint16 wormholeChainId;
    address vaultAddress;
    mapping(address => uint16) targetContractToChainId;
    mapping(uint16 => address) targetChainIdToContract;
    mapping(address => BitMaps.BitMap) nonce;
    BitMaps.BitMap gasForwardingNonce;
    mapping(bytes32 => Trade) trades;
    mapping(bytes32 => bool) consumedMessages;
    mapping(address => AssetType) types;
}

// -----------------------------------------------------------------------
// Enums
// -----------------------------------------------------------------------

enum Status {
    IDLE, // default status
    PENDING, // pulled funds on primary chain and sent message to secondary chain
    FAILED, // Could not pull funds on other chain so will revert on primary chain
    SUCCESS // succesfully pulled funds on both the chains and swapped assets can now be withdrawn
}

enum Result {
    SUCCESS, // trade was succesfull on secondary chain
    FAILED // trade failed on secondary chain
}

enum PayloadType {
    PROCESS_TRADE, // function selector for processing trade on secondary chain
    COMPLETE_TRADE // function selector for completing trade on primary chain
}

enum AssetType {
    INVALID,
    ERC_20,
    ERC_721,
    ERC_1155
}


// File: contracts/vault/TokenTransferrer.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {
    BadReturnValueFromERC20OnTransfer_error_amount_ptr,
    BadReturnValueFromERC20OnTransfer_error_from_ptr,
    BadReturnValueFromERC20OnTransfer_error_length,
    BadReturnValueFromERC20OnTransfer_error_selector,
    BadReturnValueFromERC20OnTransfer_error_to_ptr,
    BadReturnValueFromERC20OnTransfer_error_token_ptr,
    CostPerWord,
    DefaultFreeMemoryPointer,
    ERC1155_safeTransferFrom_amount_ptr,
    ERC1155_safeTransferFrom_data_length_offset,
    ERC1155_safeTransferFrom_data_length_ptr,
    ERC1155_safeTransferFrom_data_offset_ptr,
    ERC1155_safeTransferFrom_from_ptr,
    ERC1155_safeTransferFrom_id_ptr,
    ERC1155_safeTransferFrom_length,
    ERC1155_safeTransferFrom_sig_ptr,
    ERC1155_safeTransferFrom_signature,
    ERC1155_safeTransferFrom_to_ptr,
    ERC20_transferFrom_amount_ptr,
    ERC20_transferFrom_from_ptr,
    ERC20_transferFrom_length,
    ERC20_transferFrom_sig_ptr,
    ERC20_transferFrom_signature,
    ERC20_transferFrom_to_ptr,
    ERC721_transferFrom_from_ptr,
    ERC721_transferFrom_id_ptr,
    ERC721_transferFrom_length,
    ERC721_transferFrom_sig_ptr,
    ERC721_transferFrom_signature,
    ERC721_transferFrom_to_ptr,
    ExtraGasBuffer,
    FreeMemoryPointerSlot,
    Generic_error_selector_offset,
    MemoryExpansionCoefficientShift,
    NoContract_error_account_ptr,
    NoContract_error_length,
    NoContract_error_selector,
    OneWord,
    OneWordShift,
    Slot0x80,
    Slot0xA0,
    Slot0xC0,
    ThirtyOneBytes,
    TokenTransferGenericFailure_err_identifier_ptr,
    TokenTransferGenericFailure_error_amount_ptr,
    TokenTransferGenericFailure_error_from_ptr,
    TokenTransferGenericFailure_error_identifier_ptr,
    TokenTransferGenericFailure_error_length,
    TokenTransferGenericFailure_error_selector,
    TokenTransferGenericFailure_error_to_ptr,
    TokenTransferGenericFailure_error_token_ptr,
    TwoWords,
    TwoWordsShift,
    ZeroSlot
} from "../libraries/TokenTransferrerConstants.sol";

import {
    TokenTransferrerErrors
} from "../libraries/TokenTransferrerErrors.sol";

/**
 * @title TokenTransferrer
 * @author 0age
 * @custom:coauthor d1ll0n
 * @custom:coauthor transmissions11
 * @notice TokenTransferrer is a library for performing optimized ERC20, ERC721,
 *         ERC1155, and batch ERC1155 transfers, used by both Seaport as well as
 *         by conduits deployed by the ConduitController. Use great caution when
 *         considering these functions for use in other codebases, as there are
 *         significant side effects and edge cases that need to be thoroughly
 *         understood and carefully addressed.
 */
contract TokenTransferrer is TokenTransferrerErrors {
    /**
     * @dev Internal function to transfer ERC20 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set on the
     *      contract performing the transfer.
     *
     * @param token      The ERC20 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     */
    function _performERC20Transfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        // Utilize assembly to perform an optimized ERC20 token transfer.
        assembly {
            // The free memory pointer memory slot will be used when populating
            // call data for the transfer; read the value and restore it later.
            let memPointer := mload(FreeMemoryPointerSlot)

            // Write call data into memory, starting with function selector.
            mstore(ERC20_transferFrom_sig_ptr, ERC20_transferFrom_signature)
            mstore(ERC20_transferFrom_from_ptr, from)
            mstore(ERC20_transferFrom_to_ptr, to)
            mstore(ERC20_transferFrom_amount_ptr, amount)

            // Make call & copy up to 32 bytes of return data to scratch space.
            // Scratch space does not need to be cleared ahead of time, as the
            // subsequent check will ensure that either at least a full word of
            // return data is received (in which case it will be overwritten) or
            // that no data is received (in which case scratch space will be
            // ignored) on a successful call to the given token.
            let callStatus := call(
                gas(),
                token,
                0,
                ERC20_transferFrom_sig_ptr,
                ERC20_transferFrom_length,
                0,
                OneWord
            )

            // Determine whether transfer was successful using status & result.
            let success := and(
                // Set success to whether the call reverted, if not check it
                // either returned exactly 1 (can't just be non-zero data), or
                // had no return data.
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                callStatus
            )

            // Handle cases where either the transfer failed or no data was
            // returned. Group these, as most transfers will succeed with data.
            // Equivalent to `or(iszero(success), iszero(returndatasize()))`
            // but after it's inverted for JUMPI this expression is cheaper.
            if iszero(and(success, iszero(iszero(returndatasize())))) {
                // If the token has no code or the transfer failed: Equivalent
                // to `or(iszero(success), iszero(extcodesize(token)))` but
                // after it's inverted for JUMPI this expression is cheaper.
                if iszero(and(iszero(iszero(extcodesize(token))), success)) {
                    // If the transfer failed:
                    if iszero(success) {
                        // If it was due to a revert:
                        if iszero(callStatus) {
                            // If it returned a message, bubble it up as long as
                            // sufficient gas remains to do so:
                            if returndatasize() {
                                // Ensure that sufficient gas is available to
                                // copy returndata while expanding memory where
                                // necessary. Start by computing the word size
                                // of returndata and allocated memory. Round up
                                // to the nearest full word.
                                let returnDataWords := shr(
                                    OneWordShift,
                                    add(returndatasize(), ThirtyOneBytes)
                                )

                                // Note: use the free memory pointer in place of
                                // msize() to work around a Yul warning that
                                // prevents accessing msize directly when the IR
                                // pipeline is activated.
                                let msizeWords := shr(OneWordShift, memPointer)

                                // Next, compute the cost of the returndatacopy.
                                let cost := mul(CostPerWord, returnDataWords)

                                // Then, compute cost of new memory allocation.
                                if gt(returnDataWords, msizeWords) {
                                    cost := add(
                                        cost,
                                        add(
                                            mul(
                                                sub(
                                                    returnDataWords,
                                                    msizeWords
                                                ),
                                                CostPerWord
                                            ),
                                            shr(
                                                MemoryExpansionCoefficientShift,
                                                sub(
                                                    mul(
                                                        returnDataWords,
                                                        returnDataWords
                                                    ),
                                                    mul(msizeWords, msizeWords)
                                                )
                                            )
                                        )
                                    )
                                }

                                // Finally, add a small constant and compare to
                                // gas remaining; bubble up the revert data if
                                // enough gas is still available.
                                if lt(add(cost, ExtraGasBuffer), gas()) {
                                    // Copy returndata to memory; overwrite
                                    // existing memory.
                                    returndatacopy(0, 0, returndatasize())

                                    // Revert, specifying memory region with
                                    // copied returndata.
                                    revert(0, returndatasize())
                                }
                            }

                            // Store left-padded selector with push4, mem[28:32]
                            mstore(
                                0,
                                TokenTransferGenericFailure_error_selector
                            )
                            mstore(
                                TokenTransferGenericFailure_error_token_ptr,
                                token
                            )
                            mstore(
                                TokenTransferGenericFailure_error_from_ptr,
                                from
                            )
                            mstore(TokenTransferGenericFailure_error_to_ptr, to)
                            mstore(
                                TokenTransferGenericFailure_err_identifier_ptr,
                                0
                            )
                            mstore(
                                TokenTransferGenericFailure_error_amount_ptr,
                                amount
                            )

                            // revert(abi.encodeWithSignature(
                            //     "TokenTransferGenericFailure(
                            //         address,address,address,uint256,uint256
                            //     )", token, from, to, identifier, amount
                            // ))
                            revert(
                                Generic_error_selector_offset,
                                TokenTransferGenericFailure_error_length
                            )
                        }

                        // Otherwise revert with a message about the token
                        // returning false or non-compliant return values.

                        // Store left-padded selector with push4, mem[28:32]
                        mstore(
                            0,
                            BadReturnValueFromERC20OnTransfer_error_selector
                        )
                        mstore(
                            BadReturnValueFromERC20OnTransfer_error_token_ptr,
                            token
                        )
                        mstore(
                            BadReturnValueFromERC20OnTransfer_error_from_ptr,
                            from
                        )
                        mstore(
                            BadReturnValueFromERC20OnTransfer_error_to_ptr,
                            to
                        )
                        mstore(
                            BadReturnValueFromERC20OnTransfer_error_amount_ptr,
                            amount
                        )

                        // revert(abi.encodeWithSignature(
                        //     "BadReturnValueFromERC20OnTransfer(
                        //         address,address,address,uint256
                        //     )", token, from, to, amount
                        // ))
                        revert(
                            Generic_error_selector_offset,
                            BadReturnValueFromERC20OnTransfer_error_length
                        )
                    }

                    // Otherwise, revert with error about token not having code:
                    // Store left-padded selector with push4, mem[28:32]
                    mstore(0, NoContract_error_selector)
                    mstore(NoContract_error_account_ptr, token)

                    // revert(abi.encodeWithSignature(
                    //      "NoContract(address)", account
                    // ))
                    revert(
                        Generic_error_selector_offset,
                        NoContract_error_length
                    )
                }

                // Otherwise, the token just returned no data despite the call
                // having succeeded; no need to optimize for this as it's not
                // technically ERC20 compliant.
            }

            // Restore the original free memory pointer.
            mstore(FreeMemoryPointerSlot, memPointer)

            // Restore the zero slot to zero.
            mstore(ZeroSlot, 0)
        }
    }

    /**
     * @dev Internal function to transfer an ERC721 token from a given
     *      originator to a given recipient. Sufficient approvals must be set on
     *      the contract performing the transfer. Note that this function does
     *      not check whether the receiver can accept the ERC721 token (i.e. it
     *      does not use `safeTransferFrom`).
     *
     * @param token      The ERC721 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param identifier The tokenId to transfer.
     */
    function _performERC721Transfer(
        address token,
        address from,
        address to,
        uint256 identifier
    ) internal {
        // Utilize assembly to perform an optimized ERC721 token transfer.
        assembly {
            // If the token has no code, revert.
            if iszero(extcodesize(token)) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, NoContract_error_selector)
                mstore(NoContract_error_account_ptr, token)

                // revert(abi.encodeWithSignature(
                //     "NoContract(address)", account
                // ))
                revert(Generic_error_selector_offset, NoContract_error_length)
            }

            // The free memory pointer memory slot will be used when populating
            // call data for the transfer; read the value and restore it later.
            let memPointer := mload(FreeMemoryPointerSlot)

            // Write call data to memory starting with function selector.
            mstore(ERC721_transferFrom_sig_ptr, ERC721_transferFrom_signature)
            mstore(ERC721_transferFrom_from_ptr, from)
            mstore(ERC721_transferFrom_to_ptr, to)
            mstore(ERC721_transferFrom_id_ptr, identifier)

            // Perform the call, ignoring return data.
            let success := call(
                gas(),
                token,
                0,
                ERC721_transferFrom_sig_ptr,
                ERC721_transferFrom_length,
                0,
                0
            )

            // If the transfer reverted:
            if iszero(success) {
                // If it returned a message, bubble it up as long as sufficient
                // gas remains to do so:
                if returndatasize() {
                    // Ensure that sufficient gas is available to copy
                    // returndata while expanding memory where necessary. Start
                    // by computing word size of returndata & allocated memory.
                    // Round up to the nearest full word.
                    let returnDataWords := shr(
                        OneWordShift,
                        add(returndatasize(), ThirtyOneBytes)
                    )

                    // Note: use the free memory pointer in place of msize() to
                    // work around a Yul warning that prevents accessing msize
                    // directly when the IR pipeline is activated.
                    let msizeWords := shr(OneWordShift, memPointer)

                    // Next, compute the cost of the returndatacopy.
                    let cost := mul(CostPerWord, returnDataWords)

                    // Then, compute cost of new memory allocation.
                    if gt(returnDataWords, msizeWords) {
                        cost := add(
                            cost,
                            add(
                                mul(
                                    sub(returnDataWords, msizeWords),
                                    CostPerWord
                                ),
                                shr(
                                    MemoryExpansionCoefficientShift,
                                    sub(
                                        mul(returnDataWords, returnDataWords),
                                        mul(msizeWords, msizeWords)
                                    )
                                )
                            )
                        )
                    }

                    // Finally, add a small constant and compare to gas
                    // remaining; bubble up the revert data if enough gas is
                    // still available.
                    if lt(add(cost, ExtraGasBuffer), gas()) {
                        // Copy returndata to memory; overwrite existing memory.
                        returndatacopy(0, 0, returndatasize())

                        // Revert, giving memory region with copied returndata.
                        revert(0, returndatasize())
                    }
                }

                // Otherwise revert with a generic error message.
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, TokenTransferGenericFailure_error_selector)
                mstore(TokenTransferGenericFailure_error_token_ptr, token)
                mstore(TokenTransferGenericFailure_error_from_ptr, from)
                mstore(TokenTransferGenericFailure_error_to_ptr, to)
                mstore(
                    TokenTransferGenericFailure_error_identifier_ptr,
                    identifier
                )
                mstore(TokenTransferGenericFailure_error_amount_ptr, 1)

                // revert(abi.encodeWithSignature(
                //     "TokenTransferGenericFailure(
                //         address,address,address,uint256,uint256
                //     )", token, from, to, identifier, amount
                // ))
                revert(
                    Generic_error_selector_offset,
                    TokenTransferGenericFailure_error_length
                )
            }

            // Restore the original free memory pointer.
            mstore(FreeMemoryPointerSlot, memPointer)

            // Restore the zero slot to zero.
            mstore(ZeroSlot, 0)
        }
    }

    /**
     * @dev Internal function to transfer ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set on
     *      the contract performing the transfer and contract recipients must
     *      implement the ERC1155TokenReceiver interface to indicate that they
     *      are willing to accept the transfer.
     *
     * @param token      The ERC1155 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param identifier The id to transfer.
     * @param amount     The amount to transfer.
     */
    function _performERC1155Transfer(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount
    ) internal {
        // Utilize assembly to perform an optimized ERC1155 token transfer.
        assembly {
            // If the token has no code, revert.
            if iszero(extcodesize(token)) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, NoContract_error_selector)
                mstore(NoContract_error_account_ptr, token)

                // revert(abi.encodeWithSignature(
                //     "NoContract(address)", account
                // ))
                revert(Generic_error_selector_offset, NoContract_error_length)
            }

            // The following memory slots will be used when populating call data
            // for the transfer; read the values and restore them later.
            let memPointer := mload(FreeMemoryPointerSlot)
            let slot0x80 := mload(Slot0x80)
            let slot0xA0 := mload(Slot0xA0)
            let slot0xC0 := mload(Slot0xC0)

            // Write call data into memory, beginning with function selector.
            mstore(
                ERC1155_safeTransferFrom_sig_ptr,
                ERC1155_safeTransferFrom_signature
            )
            mstore(ERC1155_safeTransferFrom_from_ptr, from)
            mstore(ERC1155_safeTransferFrom_to_ptr, to)
            mstore(ERC1155_safeTransferFrom_id_ptr, identifier)
            mstore(ERC1155_safeTransferFrom_amount_ptr, amount)
            mstore(
                ERC1155_safeTransferFrom_data_offset_ptr,
                ERC1155_safeTransferFrom_data_length_offset
            )
            mstore(ERC1155_safeTransferFrom_data_length_ptr, 0)

            // Perform the call, ignoring return data.
            let success := call(
                gas(),
                token,
                0,
                ERC1155_safeTransferFrom_sig_ptr,
                ERC1155_safeTransferFrom_length,
                0,
                0
            )

            // If the transfer reverted:
            if iszero(success) {
                // If it returned a message, bubble it up as long as sufficient
                // gas remains to do so:
                if returndatasize() {
                    // Ensure that sufficient gas is available to copy
                    // returndata while expanding memory where necessary. Start
                    // by computing word size of returndata & allocated memory.
                    // Round up to the nearest full word.
                    let returnDataWords := shr(
                        OneWordShift,
                        add(returndatasize(), ThirtyOneBytes)
                    )

                    // Note: use the free memory pointer in place of msize() to
                    // work around a Yul warning that prevents accessing msize
                    // directly when the IR pipeline is activated.
                    let msizeWords := shr(OneWordShift, memPointer)

                    // Next, compute the cost of the returndatacopy.
                    let cost := mul(CostPerWord, returnDataWords)

                    // Then, compute cost of new memory allocation.
                    if gt(returnDataWords, msizeWords) {
                        cost := add(
                            cost,
                            add(
                                mul(
                                    sub(returnDataWords, msizeWords),
                                    CostPerWord
                                ),
                                shr(
                                    MemoryExpansionCoefficientShift,
                                    sub(
                                        mul(returnDataWords, returnDataWords),
                                        mul(msizeWords, msizeWords)
                                    )
                                )
                            )
                        )
                    }

                    // Finally, add a small constant and compare to gas
                    // remaining; bubble up the revert data if enough gas is
                    // still available.
                    if lt(add(cost, ExtraGasBuffer), gas()) {
                        // Copy returndata to memory; overwrite existing memory.
                        returndatacopy(0, 0, returndatasize())

                        // Revert, giving memory region with copied returndata.
                        revert(0, returndatasize())
                    }
                }

                // Otherwise revert with a generic error message.

                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, TokenTransferGenericFailure_error_selector)
                mstore(TokenTransferGenericFailure_error_token_ptr, token)
                mstore(TokenTransferGenericFailure_error_from_ptr, from)
                mstore(TokenTransferGenericFailure_error_to_ptr, to)
                mstore(
                    TokenTransferGenericFailure_error_identifier_ptr,
                    identifier
                )
                mstore(TokenTransferGenericFailure_error_amount_ptr, amount)

                // revert(abi.encodeWithSignature(
                //     "TokenTransferGenericFailure(
                //         address,address,address,uint256,uint256
                //     )", token, from, to, identifier, amount
                // ))
                revert(
                    Generic_error_selector_offset,
                    TokenTransferGenericFailure_error_length
                )
            }

            mstore(Slot0x80, slot0x80) // Restore slot 0x80.
            mstore(Slot0xA0, slot0xA0) // Restore slot 0xA0.
            mstore(Slot0xC0, slot0xC0) // Restore slot 0xC0.

            // Restore the original free memory pointer.
            mstore(FreeMemoryPointerSlot, memPointer)

            // Restore the zero slot to zero.
            mstore(ZeroSlot, 0)
        }
    }
}


// File: contracts/vault/Vault.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import { VaultStorage } from "./VaultStorage.sol";
import { Assets, AssetType, Fees, TradeDetailed } from "../utils/DataTypes.sol";
import { TokenTransferrer } from "./TokenTransferrer.sol";
import {
    OwnableUpgradeable,
    Initializable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {
    SafeERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @title NF3 Vault
/// @author NF3 Exchange
/// @notice This contract inherits from VaultStorage contract and IVault interface.
/// @dev This contract acts as the pathway for transfering assets between two addresses.
/// @dev It also locks the assets as an escrow when a trade is processing on other chains

contract Vault is
    VaultStorage,
    Initializable,
    OwnableUpgradeable,
    TokenTransferrer
{
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ===== INIT ===== */

    /// @dev Initialize
    function initialize() public initializer {
        __Ownable_init();
    }

    /// -----------------------------------------------------------------------
    /// Transfer actions
    /// -----------------------------------------------------------------------

    /// @notice Inherit from IVault
    function receiveAssets(
        TradeDetailed calldata trade,
        Fees calldata buyerFees,
        Fees calldata sellerFees
    ) external override onlyCore returns (bool) {
        // receive fees from seller and buyer
        if (buyerFees.amount > 0) _transferFees(buyerFees, trade.buyer);

        if (sellerFees.amount > 0) _transferFees(sellerFees, trade.seller);

        // receive offering assets
        _receiveAssets(trade.offeringAssets, trade.seller);

        // recieve consideration assets
        _receiveAssets(trade.considerationAssets, trade.buyer);

        return true;
    }

    /// @notice Inherit from IVault
    function sendAssets(
        Assets memory _assets,
        address _to
    ) external override onlyCore returns (bool) {
        unchecked {
            uint256 i;
            for (i = 0; i < _assets.assets.length; i++) {
                if (_assets.assets[i].assetType == AssetType.ERC_721) {
                    _performERC721Transfer(
                        _assets.assets[i].token,
                        address(this),
                        _to,
                        _assets.assets[i].tokenId
                    );
                } else if (_assets.assets[i].assetType == AssetType.ERC_20) {
                    IERC20Upgradeable(_assets.assets[i].token).safeTransfer(
                        _to,
                        _assets.assets[i].amount
                    );
                } else {
                    _performERC1155Transfer(
                        _assets.assets[i].token,
                        address(this),
                        _to,
                        _assets.assets[i].tokenId,
                        _assets.assets[i].amount
                    );
                }
            }
        }
        emit AssetsSent(_assets, _to);

        return true;
    }

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @notice Inherit from IVault
    function setCoreAddress(address coreAddress_) external override onlyOwner {
        _setCoreAddress(coreAddress_);
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    /// @dev helper function to receive a set of asset from _from address to the vault
    /// @param _assets Assets that need to be received
    /// @param _from Address from which assets need to be received
    function _receiveAssets(Assets memory _assets, address _from) internal {
        unchecked {
            uint256 i;
            for (i = 0; i < _assets.assets.length; i++) {
                if (_assets.assets[i].assetType == AssetType.ERC_721) {
                    _performERC721Transfer(
                        _assets.assets[i].token,
                        _from,
                        address(this),
                        _assets.assets[i].tokenId
                    );
                } else if (_assets.assets[i].assetType == AssetType.ERC_20) {
                    _performERC20Transfer(
                        _assets.assets[i].token,
                        _from,
                        address(this),
                        _assets.assets[i].amount
                    );
                } else {
                    _performERC1155Transfer(
                        _assets.assets[i].token,
                        _from,
                        address(this),
                        _assets.assets[i].tokenId,
                        _assets.assets[i].amount
                    );
                }
            }
        }
        emit AssetsReceived(_assets, _from);
    }

    /// @dev helper function to transfer fees from buyer and seller to the fee recipeint
    /// @param _fees Fees struct that needs to be transfered
    /// @param _user Address which will pay the fees
    function _transferFees(Fees memory _fees, address _user) internal {
        _performERC20Transfer(_fees.token, _user, _fees.to, _fees.amount);

        emit FeeTransferred(_fees, _user);
    }

    /// @dev See {IERC721Receiver - onERC721Received}
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    /// @dev See {IERC1155Receiver - onERC1155Received}
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    /// @dev storage gap
    // solhint-disable-next-line
    uint[50] __gap;
}


// File: contracts/vault/VaultStorage.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import { IVault } from "../interfaces/IVault.sol";

/// @title NF3 Vault Storage
/// @author NF3 Exchange
/// @notice This is an abstract contract that inherits from IVault interface.
/// @dev This contract acts as a storage provider for the main Vault contract

abstract contract VaultStorage is IVault {
    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice Core contract's address
    address public coreAddress;

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier onlyCore() {
        if (msg.sender != coreAddress) {
            revert VaultError(VaultErrorCodes.CALLER_NOT_ALLOWED);
        }
        _;
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    /// @dev internal function to set core contract's address
    /// @param coreAddress_ address of the new core contract
    function _setCoreAddress(address coreAddress_) internal {
        if (coreAddress_ == address(0)) {
            revert VaultError(VaultErrorCodes.INVALID_ADDRESS);
        }
        emit CoreSet(coreAddress, coreAddress_);
        coreAddress = coreAddress_;
    }
}


