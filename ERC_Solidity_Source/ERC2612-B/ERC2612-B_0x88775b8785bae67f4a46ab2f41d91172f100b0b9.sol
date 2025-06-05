// File: @openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// File: @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

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
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
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
        if (_initialized < type(uint8).max) {
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


// File: @openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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


// File: @openzeppelin/contracts/interfaces/IERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";


// File: @openzeppelin/contracts/security/ReentrancyGuard.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}


// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol
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


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
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


// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

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
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
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


// File: @openzeppelin/contracts/utils/Address.sol
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


// File: @openzeppelin/contracts/utils/cryptography/ECDSA.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV // Deprecated in v4.8
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
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
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

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
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 message) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            message := keccak256(0x00, 0x3c)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 data) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "\x19\x01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            data := keccak256(ptr, 0x42)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Data with intended validator, created from a
     * `validator` and `data` according to the version 0 of EIP-191.
     *
     * See {recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x00", validator, data));
    }
}


// File: @openzeppelin/contracts/utils/math/Math.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

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
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
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
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

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
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
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
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
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
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
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
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}


// File: @openzeppelin/contracts/utils/math/SafeMath.sol
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


// File: @openzeppelin/contracts/utils/math/SignedMath.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}


// File: @openzeppelin/contracts/utils/Strings.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";
import "./math/SignedMath.sol";

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
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMath.abs(value))));
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

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}


// File: contracts/Exchange.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libs/LibUnitConverter.sol";
import "./libs/LibValidator.sol";
import "./libs/LibExchange.sol";
import "./libs/MarginalFunctionality.sol";
import "./libs/SafeTransferHelper.sol";
import "./OrionVault.sol";

/**
 * @title Exchange
 * @dev Exchange contract for the Orion Protocol
 * @author @wafflemakr
 */

/*

  Overflow safety:
  We do not use SafeMath and control overflows by
  not accepting large ints on input.

  Balances inside contract are stored as int192.

  Allowed input amounts are int112 or uint112: it is enough for all
  practically used tokens: for instance if decimal unit is 1e18, int112
  allow to encode up to 2.5e15 decimal units.
  That way adding/subtracting any amount from balances won't overflow, since
  minimum number of operations to reach max int is practically infinite: ~1e24.

  Allowed prices are uint64. Note, that price is represented as
  price per 1e8 tokens. That means that amount*price always fit uint256,
  while amount*price/1e8 not only fit int192, but also can be added, subtracted
  without overflow checks: number of malicious operations to overflow ~1e13.
*/

contract Exchange is OrionVault {
	using LibValidator for LibValidator.Order;
	using SafeERC20 for IERC20;

	struct UpdateOrderBalanceData {
		uint buyType;
		uint sellType;
		int buyIn;
		int sellIn;
	}

	//  Flags for updateOrders
	//  All flags are explicit
	uint8 constant kSell = 0;
	uint8 constant kBuy = 1; //  if 0 - then sell
	uint8 constant kCorrectMatcherFeeByOrderAmount = 2;

	// EVENTS
	event NewAssetTransaction(
		address indexed beneficiary,
		address indexed recipient,
		address indexed assetAddress,
		bool isDeposit,
		uint112 amount,
		uint64 timestamp
	);

	event Trade(
		address indexed buyer,
		address indexed seller,
		address baseAsset,
		address quoteAsset,
		uint64 filledPrice,
		uint192 filledAmount,
		uint192 amountQuote,
		bytes32 tradeId
	);

	error IncorrectPosition();
	error OnlyMatcher();
	error AlreadyFilled();
	error Fallback();
	error Overflow();
	error EthDepositRejected();
	error NotCollateralAsset();

	modifier onlyMatcher() {
		if (msg.sender != _allowedMatcher) revert OnlyMatcher();
		_;
	}

	// MAIN FUNCTIONS

	/**
	 * @dev Since Exchange will work behind the Proxy contract it can not have constructor
	 */
	function initialize() public payable initializer {
		OwnableUpgradeable.__Ownable_init();
	}

	/**
	 * @dev set marginal settings
	 * @param _collateralAssets - list of addresses of assets which may be used as collateral
	 * @param _stakeRisk - risk coefficient for staked orion as uint8 (0=0, 255=1)
	 * @param _liquidationPremium - premium for liquidator as uint8 (0=0, 255=1)
	 * @param _priceOverdue - time after that price became outdated
	 * @param _positionOverdue - time after that liabilities became overdue and may be liquidated
	 */

	function updateMarginalSettings(
		address[] calldata _collateralAssets,
		uint8 _stakeRisk,
		uint8 _liquidationPremium,
		uint64 _priceOverdue,
		uint64 _positionOverdue
	) public onlyOwner {
		collateralAssets = _collateralAssets;
		stakeRisk = _stakeRisk;
		liquidationPremium = _liquidationPremium;
		priceOverdue = _priceOverdue;
		positionOverdue = _positionOverdue;
	}

	/**
	 * @dev set risk coefficients for collateral assets
	 * @param assets - list of assets
	 * @param risks - list of risks as uint8 (0=0, 255=1)
	 */
	function updateAssetRisks(address[] calldata assets, uint8[] calldata risks) public onlyOwner {
		for (uint256 i; i < assets.length; i++) assetRisks[assets[i]] = risks[i];
	}

	/**
	 * @dev Deposit ERC20 tokens to the exchange contract. Beneficiary is msg.sender
	 * @dev User needs to approve token contract first
	 * @param amount asset amount to deposit in its base unit
	 */
	function depositAsset(address assetAddress, uint112 amount) external {
		depositAssetTo(assetAddress, amount, msg.sender);
	}

	/**
	 * @dev Deposit ERC20 tokens to the exchange contract. Beneficiary is account
	 * @dev User needs to approve token contract first
	 * @param amount asset amount to deposit in its base unit
	 */
	function depositAssetTo(address assetAddress, uint112 amount, address account) public nonReentrant {
		uint256 actualAmount = IERC20(assetAddress).balanceOf(address(this));
		IERC20(assetAddress).safeTransferFrom(msg.sender, address(this), uint256(amount));
		actualAmount = IERC20(assetAddress).balanceOf(address(this)) - actualAmount;
		if (actualAmount < amount) revert NotEnoughBalance();
		generalDeposit(assetAddress, uint112(actualAmount), account);
	}

	/**
	 * @notice Deposit ETH to the exchange contract. Beneficiary is msg.sender
	 * @dev deposit event will be emitted with the amount in decimal format (10^8)
	 * @dev balance will be stored in decimal format too
	 */
	function deposit() external payable {
		depositTo(msg.sender);
	}

	/**
	 * @notice Deposit ETH to the exchange contract. Beneficiary is account
	 * @dev deposit event will be emitted with the amount in decimal format (10^8)
	 * @dev balance will be stored in decimal format too
	 */
	function depositTo(address account) public payable nonReentrant {
		generalDeposit(address(0), uint112(msg.value), account);
	}

	/**
	 * @dev internal implementation of deposits
	 */
	function generalDeposit(address assetAddress, uint112 amount, address account) internal {
		bool wasLiability = assetBalances[account][assetAddress] < 0;
		uint112 safeAmountDecimal = LibUnitConverter.baseUnitToDecimal(assetAddress, amount);
		assetBalances[account][assetAddress] += int192(uint192(safeAmountDecimal));
		emit LibExchange.BalanceChange(account, assetAddress, int192(uint192(safeAmountDecimal)));

		if (amount > 0)
			emit NewAssetTransaction(msg.sender, account, assetAddress, true, safeAmountDecimal, uint64(block.timestamp));
		if (wasLiability)
			MarginalFunctionality.updateLiability(
				account,
				assetAddress,
				liabilities,
				uint112(safeAmountDecimal),
				assetBalances[account][assetAddress]
			);
	}

	/**
	 * @dev Withdrawal of funds from the contract to provided address
	 * @param assetAddress address of the asset to withdraw
	 * @param amount asset amount to withdraw in its base unit
	 * @param to recipient address
	 */
	function withdrawTo(address assetAddress, uint112 amount, address to) public nonReentrant {
		uint112 safeAmountDecimal = LibUnitConverter.baseUnitToDecimal(assetAddress, amount);

		assetBalances[msg.sender][assetAddress] -= int192(uint192(safeAmountDecimal));
		emit LibExchange.BalanceChange(to, assetAddress, -int192(uint192(safeAmountDecimal)));

		if (assetBalances[msg.sender][assetAddress] < 0) revert NotEnoughBalance();
		if (!checkPosition(to)) revert IncorrectPosition();

		if (assetAddress == address(0)) {
			(bool success, ) = to.call{value: amount}("");
			if (!success) revert NotEnoughBalance();
		} else {
			IERC20(assetAddress).safeTransfer(to, amount);
		}

		emit NewAssetTransaction(msg.sender, to, assetAddress, false, safeAmountDecimal, uint64(block.timestamp));
	}
	/**
	 * @dev Withdrawal of remaining funds from the contract to the address
	 * @param assetAddress address of the asset to withdraw
	 * @param amount asset amount to withdraw in its base unit
	 */
	function withdraw(address assetAddress, uint112 amount) external {
		withdrawTo(assetAddress, amount, msg.sender);
	}

	/**
	 * @dev Get asset balance for a specific address
	 * @param assetAddress address of the asset to query
	 * @param user user address to query
	 */
	function getBalance(address assetAddress, address user) public view returns (int192) {
		return assetBalances[user][assetAddress];
	}

	/**
	 * @dev Batch query of asset balances for a user
	 * @param assetsAddresses array of addresses of the assets to query
	 * @param user user address to query
	 */
	function getBalances(
		address[] memory assetsAddresses,
		address user
	) public view returns (int192[] memory balances) {
		balances = new int192[](assetsAddresses.length);
		for (uint256 i; i < assetsAddresses.length; i++) {
			balances[i] = assetBalances[user][assetsAddresses[i]];
		}
	}

	/**
	 * @dev Batch query of asset liabilities for a user
	 * @param user user address to query
	 */
	function getLiabilities(
		address user
	) public view returns (MarginalFunctionality.Liability[] memory liabilitiesArray) {
		return liabilities[user];
	}

	/**
	 * @dev Return list of assets which can be used for collateral
	 */
	function getCollateralAssets() public view returns (address[] memory) {
		return collateralAssets;
	}

	/**
	 * @dev get filled amounts for a specific order
	 */
	function getFilledAmounts(
		bytes32 orderHash,
		LibValidator.Order memory order
	) public view returns (int192 totalFilled, int192 totalFeesPaid) {
		totalFilled = int192(filledAmounts[orderHash]); //It is safe to convert here: filledAmounts is result of ui112 additions
		totalFeesPaid = int192(
			uint192((uint256(order.matcherFee) * uint256(uint192(totalFilled))) / uint256(order.amount))
		); //matcherFee is u64; safe multiplication here
	}

	function updateFilledAmount(bytes32 orderHash, uint192 amount, uint112 filledBase) internal {
		uint192 total_amount = filledAmounts[orderHash];
		total_amount += filledBase; //it is safe to add ui112 to each other to get i192
		if (total_amount > amount) revert AlreadyFilled();
		filledAmounts[orderHash] = total_amount;
	}

	/**
     * @notice Settle a trade with two orders, filled price and amount
     * @dev 2 orders are submitted, it is necessary to match them:
        check conditions in orders for compliance filledPrice, filledAmount
        change balances on the contract respectively with buyer, seller, matcher
     * @param buyOrder structure of buy side order
     * @param sellOrder structure of sell side order
     * @param filledPrice price at which the order was settled
     * @param filledAmount amount settled between orders
     */
	function fillOrders(
		LibValidator.Order memory buyOrder,
		LibValidator.Order memory sellOrder,
		uint64 filledPrice,
		uint112 filledAmount
	) public nonReentrant {
		// --- VARIABLES --- //
		// Amount of quote asset
		uint256 _amountQuote = (uint256(filledAmount) * filledPrice) / (10 ** 8);
		if (_amountQuote >= type(uint112).max) revert Overflow();
		uint112 amountQuote = uint112(_amountQuote);

		// --- VALIDATIONS --- //

		// Validate signatures using eth typed sign V1
		(bytes32 buyOrderHash, bytes32 sellOrderHash) = LibValidator.checkOrdersInfo(
			buyOrder,
			sellOrder,
			msg.sender,
			filledAmount,
			filledPrice,
			block.timestamp,
			_allowedMatcher
		);

		// --- UPDATES --- //

		//updateFilledAmount
		updateFilledAmount(buyOrderHash, buyOrder.amount, filledAmount);
		updateFilledAmount(sellOrderHash, sellOrder.amount, filledAmount);

		// Update User's balances
		UpdateOrderBalanceData memory data;
		(data.buyType, data.buyIn) = LibExchange.updateOrderBalanceDebit(
			buyOrder,
			filledAmount,
			amountQuote,
			kBuy | kCorrectMatcherFeeByOrderAmount,
			assetBalances,
			liabilities
		);
		(data.sellType, data.sellIn) = LibExchange.updateOrderBalanceDebit(
			sellOrder,
			filledAmount,
			amountQuote,
			kSell | kCorrectMatcherFeeByOrderAmount,
			assetBalances,
			liabilities
		);

		LibExchange.creditUserAssets(
			data.buyType,
			buyOrder.senderAddress,
			data.buyIn,
			buyOrder.baseAsset,
			assetBalances,
			liabilities
		);
		LibExchange.creditUserAssets(
			data.sellType,
			sellOrder.senderAddress,
			data.sellIn,
			sellOrder.quoteAsset,
			assetBalances,
			liabilities
		);

		if (!checkPosition(buyOrder.senderAddress)) revert IncorrectPosition();
		if (!checkPosition(sellOrder.senderAddress)) revert IncorrectPosition();

		emit Trade(
			buyOrder.senderAddress,
			sellOrder.senderAddress,
			buyOrder.baseAsset,
			buyOrder.quoteAsset,
			filledPrice,
			filledAmount,
			amountQuote,
			keccak256(abi.encode(buyOrderHash, sellOrderHash))
		);
	}

	/**
	 * @dev wrapper for LibValidator methods, may be deleted.
	 */
	function validateOrder(LibValidator.Order memory order) public pure returns (bool isValid) {
		(isValid, ) = LibValidator.validateV3(order);
	}

	/**
	 * @dev check user marginal position (compare assets and liabilities)
	 * @return isPositive - boolean whether liabilities are covered by collateral or not
	 */
	function checkPosition(address user) public view returns (bool) {
		if (liabilities[user].length == 0) return true;
		return calcPosition(user).state == MarginalFunctionality.PositionState.POSITIVE;
	}

	/**
	 * @dev internal methods which collect all variables used by MarginalFunctionality to one structure
	 * @param user user address to query
	 * @return UsedConstants - MarginalFunctionality.UsedConstants structure
	 */
	function getConstants(address user) internal view returns (MarginalFunctionality.UsedConstants memory) {
		return
			MarginalFunctionality.UsedConstants(
				user,
				_oracleAddress,
				address(_orionToken),
				positionOverdue,
				priceOverdue,
				stakeRisk,
				liquidationPremium
			);
	}

	/**
	 * @dev calc user marginal position (compare assets and liabilities)
	 * @param user user address to query
	 * @return position - MarginalFunctionality.Position structure
	 */
	function calcPosition(address user) public view returns (MarginalFunctionality.Position memory) {
		MarginalFunctionality.UsedConstants memory constants = getConstants(user);

		return MarginalFunctionality.calcPosition(collateralAssets, liabilities, assetBalances, assetRisks, constants);
	}

	/**
     * @dev method to cover some of overdue broker liabilities and get ORN in exchange
            same as liquidation or margin call
     * @param broker - broker which will be liquidated
     * @param redeemedAsset - asset, liability of which will be covered
	 * @param collateralAsset - asset, with which liability will be covered
     * @param amount - amount of covered asset
     */
	function partiallyLiquidate(address broker, address redeemedAsset, address collateralAsset, uint112 amount) public {
		bool isCollateralAsset = false;
		for (uint i = 0; i < collateralAssets.length; ++i) {
			if (collateralAssets[i] == collateralAsset) {
				isCollateralAsset = true;
				break;
			}
		}
		if (!isCollateralAsset) revert NotCollateralAsset();
		MarginalFunctionality.UsedConstants memory constants = getConstants(broker);
		MarginalFunctionality.partiallyLiquidate(
			collateralAssets,
			liabilities,
			assetBalances,
			assetRisks,
			constants,
			redeemedAsset,
			collateralAsset,
			amount
		);
	}

	receive() external payable {
		if (msg.sender == tx.origin) revert EthDepositRejected();
	}

	/**
	 *  @dev  revert on fallback function
	 */
	fallback() external {
		revert Fallback();
	}

	/* Error Codes
        E1: Insufficient Balance, flavor S - stake, L - liabilities, P - Position, B,S - buyer, seller
        E2: Invalid Signature, flavor B,S - buyer, seller
        E3: Invalid Order Info, flavor G - general, M - wrong matcher, M2 unauthorized matcher, As - asset mismatch,
            AmB/AmS - amount mismatch (buyer,seller), PrB/PrS - price mismatch(buyer,seller), D - direction mismatch,
            U - Unit Converter Error, C - caller mismatch
        E4: Order expired, flavor B,S - buyer,seller
        E5: Contract not active,
        E6: Transfer error
        E7: Incorrect state prior to liquidation
        E8: Liquidator doesn't satisfy requirements
        E9: Data for liquidation handling is outdated
        E10: Incorrect state after liquidation
        E11: Amount overflow
        E12: Incorrect filled amount, flavor G,B,S: general(overflow), buyer order overflow, seller order overflow
        E14: Authorization error, sfs - seizeFromStake
        E15: Wrong passed params
        E16: Underlying protection mechanism error, flavor: R, I, O: Reentrancy, Initialization, Ownable
    */
}


// File: contracts/ExchangeStorage.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libs/MarginalFunctionality.sol";

// Base contract which contain state variable of the first version of Exchange
// deployed on mainnet. Changes of the state variables should be introduced
// not in that contract but down the inheritance chain, to allow safe upgrades
// More info about safe upgrades here:
// https://blog.openzeppelin.com/the-state-of-smart-contract-upgrades/#upgrade-patterns

contract ExchangeStorage {
	//order -> filledAmount
	mapping(bytes32 => uint192) public filledAmounts;

	// Get user balance by address and asset address
	mapping(address => mapping(address => int192)) internal assetBalances;
	// List of assets with negative balance for each user
	mapping(address => MarginalFunctionality.Liability[]) public liabilities;
	// List of assets which can be used as collateral and risk coefficients for them
	address[] internal collateralAssets;
	mapping(address => uint8) public assetRisks;
	// Risk coefficient for locked ORN
	uint8 public stakeRisk;
	// Liquidation premium
	uint8 public liquidationPremium;
	// Delays after which price and position become outdated
	uint64 public priceOverdue;
	uint64 public positionOverdue;

	// Base orion tokens (can be locked on stake)
	IERC20 _orionToken;
	// Address of price oracle contract
	address _oracleAddress;
	// Address from which matching of orders is allowed
	address _allowedMatcher;
    //Adding gap_ due to previous OwnableUpgradeable implementation
    uint256[48] private gap_;
}

// File: contracts/ExchangeWithAtomic.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "./Exchange.sol";
import "./libs/LibAtomic.sol";

contract ExchangeWithAtomic is Exchange {
	uint256[2] private gap;
	address public WETH;
	mapping(bytes32 => LibAtomic.LockInfo) public atomicSwaps;
	mapping(bytes32 => bool) public secrets;

	event AtomicLocked(address sender, address asset, bytes32 secretHash);
	event AtomicRedeemed(address sender, address receiver, address asset, bytes secret);
	event AtomicClaimed(address receiver, address asset, bytes secret);
	event AtomicRefunded(address receiver, address asset, bytes32 secretHash);

	function setBasicParams(
		address orionToken,
		address priceOracleAddress,
		address allowedMatcher,
		address WETH_
	) public onlyOwner {
		_orionToken = IERC20(orionToken);
		_oracleAddress = priceOracleAddress;
		_allowedMatcher = allowedMatcher;
		WETH = WETH_;
	}

	function fillAndLockAtomic(
		LibAtomic.CrossChainOrder memory userOrder,
		LibValidator.Order memory brokerOrder,
		uint64 filledPrice,
		uint64 filledAmount,
		uint64 lockOrderExpiration
	) public onlyMatcher {
		address lockAsset;
		uint64 lockAmount;
		if (userOrder.limitOrder.buySide == 1) {
			fillOrders(userOrder.limitOrder, brokerOrder, filledPrice, filledAmount);
			lockAsset = userOrder.limitOrder.baseAsset;
			lockAmount = filledAmount;
		} else {
			fillOrders(brokerOrder, userOrder.limitOrder, filledPrice, filledAmount);
			lockAsset = userOrder.limitOrder.quoteAsset;
			lockAmount = (filledAmount * filledPrice) / 10 ** 8;
		}

		LibAtomic.LockOrder memory lockOrder = LibAtomic.LockOrder({
			sender: userOrder.limitOrder.matcherAddress,
			asset: lockAsset,
			amount: lockAmount,
			expiration: lockOrderExpiration,
			targetChainId: userOrder.chainId,
			secretHash: userOrder.secretHash
		});

		_lockAtomic(userOrder.limitOrder.senderAddress, lockOrder);
	}

	function lockAtomicByMatcher(address account, LibAtomic.LockOrder memory lockOrder) external onlyMatcher {
		_lockAtomic(account, lockOrder);
	}

	function _lockAtomic(address account, LibAtomic.LockOrder memory lockOrder) internal nonReentrant {
		LibAtomic.doLockAtomic(account, lockOrder, atomicSwaps, assetBalances, liabilities);

		if (!checkPosition(account)) revert IncorrectPosition();

		emit AtomicLocked(lockOrder.sender, lockOrder.asset, lockOrder.secretHash);
	}

	function lockAtomic(LibAtomic.LockOrder memory swap) public payable {
		_lockAtomic(msg.sender, swap);
	}

	function redeemAtomic(LibAtomic.RedeemOrder calldata order, bytes calldata secret) public {
		LibAtomic.doRedeemAtomic(order, secret, secrets, assetBalances, liabilities);
		if (!checkPosition(order.sender)) revert IncorrectPosition();

		emit AtomicRedeemed(order.sender, order.receiver, order.asset, secret);
	}

	function redeem2Atomics(
		LibAtomic.RedeemOrder calldata order1,
		bytes calldata secret1,
		LibAtomic.RedeemOrder calldata order2,
		bytes calldata secret2
	) public {
		redeemAtomic(order1, secret1);
		redeemAtomic(order2, secret2);
	}

	function claimAtomic(address receiver, bytes calldata secret, bytes calldata matcherSignature) public {
		LibAtomic.LockInfo storage swap = LibAtomic.doClaimAtomic(
			receiver,
			secret,
			matcherSignature,
			_allowedMatcher,
			atomicSwaps,
			assetBalances,
			liabilities
		);

		emit AtomicClaimed(receiver, swap.asset, secret);
	}

	function refundAtomic(bytes32 secretHash) public {
		LibAtomic.LockInfo storage swap = LibAtomic.doRefundAtomic(secretHash, atomicSwaps, assetBalances, liabilities);

		emit AtomicRefunded(swap.sender, swap.asset, secretHash);
	}

	/* Error Codes
        E1: Insufficient Balance, flavor A - Atomic, PA - Position Atomic
        E17: Incorrect atomic secret, flavor: U - used, NF - not found, R - redeemed, E/NE - expired/not expired, ETH
   */
}


// File: contracts/ExchangeWithGenericSwap.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "./ExchangeWithAtomic.sol";
import "./libs/LibGenericSwap.sol";
import "./interfaces/IAggregationExecutor.sol";

contract ExchangeWithGenericSwap is ExchangeWithAtomic {
	using SafeERC20 for IERC20;
	using SafeTransferHelper for IERC20;

	error InsufficientBalance();
	error ZeroReturnAmount();

	/// @notice Fills user's limit order through pools, delegating all calls encoded in `data` to `executor`. See tests for usage examples
	/// @param order User signed limit order
	/// @param executor Aggregation executor that executes calls described in `data`
	/// @param desc Swap description
	/// @param data Encoded calls that `caller` should execute in between of swaps
	function fillThroughPools(
		uint112 filledAmount,
		LibValidator.Order calldata order,
		IAggregationExecutor executor,
		LibValidator.SwapDescription memory desc,
		bytes calldata permit,
		bytes calldata data
	) external onlyMatcher nonReentrant {
		bytes32 orderHash = LibValidator.checkOrderSingleMatch(order, desc, filledAmount, block.timestamp);
		// if destination token is equal to fee token then fee will be fully paid inside executor contract
		if (address(desc.dstToken) != order.matcherFeeAsset) {
			payMatcherFee(order);
		} else {
			desc.minReturnAmount -= order.matcherFee; // condition desc.minReturnAmount > order.matcher fee was checked in LibValidator
		}
		LibGenericSwap.transferToInitialSource(order.senderAddress, desc, permit, assetBalances, liabilities);
		LibGenericSwap.fillThroughPools(orderHash, order.senderAddress, executor, desc, data);
		updateFilledAmount(orderHash, order.amount, filledAmount);

	}

	/// @notice Performs a swap, delegating all calls encoded in `data` to `executor`. See tests for usage examples
	/// @param executor Aggregation executor that executes calls described in `data`
	/// @param desc Swap description
	/// @param data Encoded calls that `caller` should execute in between of swaps
	/// @return returnAmount Resulting token amount
	/// @return spentAmount Source token amount
	/// @return gasLeft Gas left
	function swap(
		IAggregationExecutor executor,
		LibValidator.SwapDescription memory desc,
		bytes calldata permit,
		bytes calldata data
	) public payable nonReentrant returns (uint256 returnAmount, uint256 spentAmount, uint256 gasLeft) {
		if (desc.minReturnAmount == 0) revert ZeroReturnAmount();
		LibGenericSwap.transferToInitialSource(msg.sender, desc, permit, assetBalances, liabilities);
		(returnAmount, spentAmount, gasLeft) = LibGenericSwap.swap(msg.sender, executor, desc, data);
	}

	function payMatcherFee(LibValidator.Order memory order) internal {
		LibExchange._updateBalance(
			order.senderAddress,
			order.matcherFeeAsset,
			-int(uint(order.matcherFee)),
			assetBalances,
			liabilities
		);
		if (assetBalances[order.senderAddress][order.matcherFeeAsset] < 0) revert InsufficientBalance();
		LibExchange._updateBalance(
			order.matcherAddress,
			order.matcherFeeAsset,
			int(uint(order.matcherFee)),
			assetBalances,
			liabilities
		);
	}
}


// File: contracts/helpers/RevertReasonForwarder.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title Revert reason forwarder.
library RevertReasonForwarder {
    /// @dev Forwards latest externall call revert.
    function reRevert() internal pure {
        // bubble up revert reason from latest external call
        assembly ("memory-safe") { // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, returndatasize())
            revert(ptr, returndatasize())
        }
    }
}

// File: contracts/interfaces/IAggregationExecutor.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;
pragma abicoder v1;

/// @title Interface for making arbitrary calls during swap
interface IAggregationExecutor {
	/// @notice Make calls on `msgSender` with specified data
	function callBytes(address msgSender, bytes calldata data) external payable; // 0x2636f7f8
}


// File: contracts/interfaces/IDaiLikePermit.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;
pragma abicoder v1;

/// @title Interface for DAI-style permits
interface IDaiLikePermit {
    function permit(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s) external;
}


// File: contracts/interfaces/IERC20Simple.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface IERC20Simple {
    function balanceOf(address account) external view returns (uint256);
	function decimals() external view returns (uint8);
}


// File: contracts/interfaces/IWETH.sol
// SPDX-License-Identifier: GNU
pragma solidity ^0.8.0;

interface IWETH {
	function deposit() external payable;

    function balanceOf(address account) external view returns(uint256);

	function transfer(address to, uint value) external returns (bool);

	function withdraw(uint) external;
}


// File: contracts/libs/LibAtomic.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./LibExchange.sol";
import "./LibValidator.sol";

library LibAtomic {
	using ECDSA for bytes32;

    struct LockOrder {
        address sender;
        uint64 expiration;
        address asset;
        uint64 amount;
        uint24 targetChainId;
        bytes32 secretHash;
    }

	struct LockInfo {
		address sender;
		uint64 expiration;
		bool used;
		address asset;
		uint64 amount;
		uint24 targetChainId;
	}

	struct ClaimOrder {
		address receiver;
		bytes32 secretHash;
	}

	struct RedeemOrder {
		address sender;
		address receiver;
		address claimReceiver;
		address asset;
		uint64 amount;
		uint64 expiration;
		bytes32 secretHash;
		bytes signature;
	}

    struct CrossChainOrder {
        LibValidator.Order limitOrder;
        uint24 chainId;
        bytes32 secretHash;
    }

	function doLockAtomic(
        address account,
		LockOrder memory swap,
		mapping(bytes32 => LockInfo) storage atomicSwaps,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => MarginalFunctionality.Liability[]) storage liabilities
	) public {
		require(swap.expiration / 1000 >= block.timestamp, "E17E");
		require(atomicSwaps[swap.secretHash].sender == address(0), "E17R");

		int remaining = int(uint(swap.amount));
		if (msg.value > 0) {
			require(swap.asset == address(0), "E17ETH");
			uint eth_sent = uint(LibUnitConverter.baseUnitToDecimal(address(0), msg.value));
			if (eth_sent < swap.amount) {
				remaining = int(uint(swap.amount)) - int(eth_sent);
			} else {
				swap.amount = uint64(eth_sent);
				remaining = 0;
			}
		}

		if (remaining > 0) {
			LibExchange._updateBalance(account, swap.asset, -1 * remaining, assetBalances, liabilities);
			require(assetBalances[account][swap.asset] >= 0, "E1A");
		}

		atomicSwaps[swap.secretHash] = LockInfo(
			swap.sender,
			swap.expiration,
			false,
			swap.asset,
			swap.amount,
			swap.targetChainId
		);
	}

	function doRedeemAtomic(
		LibAtomic.RedeemOrder calldata order,
		bytes calldata secret,
		mapping(bytes32 => bool) storage secrets,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => MarginalFunctionality.Liability[]) storage liabilities
	) public {
		require(!secrets[order.secretHash], "E17R");
		require(getEthSignedAtomicOrderHash(order).recover(order.signature) == order.sender, "E2");
		require(order.expiration / 1000 >= block.timestamp, "E4A");
		require(order.secretHash == keccak256(secret), "E17");
		secrets[order.secretHash] = true;

		LibExchange._updateBalance(order.sender, order.asset, -1 * int(uint(order.amount)), assetBalances, liabilities);

		LibExchange._updateBalance(order.receiver, order.asset, int(uint(order.amount)), assetBalances, liabilities);
	}

	function doClaimAtomic(
		address receiver,
		bytes calldata secret,
		bytes calldata matcherSignature,
		address allowedMatcher,
		mapping(bytes32 => LockInfo) storage atomicSwaps,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => MarginalFunctionality.Liability[]) storage liabilities
	) public returns (LockInfo storage swap) {
		bytes32 secretHash = keccak256(secret);
		bytes32 coHash = getEthSignedClaimOrderHash(ClaimOrder(receiver, secretHash));
		require(coHash.recover(matcherSignature) == allowedMatcher, "E2");

		swap = atomicSwaps[secretHash];
		require(swap.sender != address(0), "E17NF");
		//  require(swap.expiration/1000 >= block.timestamp, "E17E");
		require(!swap.used, "E17U");

		swap.used = true;
		LibExchange._updateBalance(receiver, swap.asset, int(uint(swap.amount)), assetBalances, liabilities);
	}

	function doRefundAtomic(
		bytes32 secretHash,
		mapping(bytes32 => LockInfo) storage atomicSwaps,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => MarginalFunctionality.Liability[]) storage liabilities
	) public returns (LockInfo storage swap) {
		swap = atomicSwaps[secretHash];
		require(swap.sender != address(0x0), "E17NF");
		require(swap.expiration / 1000 < block.timestamp, "E17NE");
		require(!swap.used, "E17U");

		swap.used = true;
		LibExchange._updateBalance(swap.sender, swap.asset, int(uint(swap.amount)), assetBalances, liabilities);
	}

	function getEthSignedAtomicOrderHash(RedeemOrder calldata _order) internal view returns (bytes32) {
		uint256 chId;
		assembly {
			chId := chainid()
		}
		return
			keccak256(
				abi.encodePacked(
					"atomicOrder",
					chId,
					_order.sender,
					_order.receiver,
					_order.claimReceiver,
					_order.asset,
					_order.amount,
					_order.expiration,
					_order.secretHash
				)
			).toEthSignedMessageHash();
	}

	function getEthSignedClaimOrderHash(ClaimOrder memory _order) internal view returns (bytes32) {
		uint256 chId;
		assembly {
			chId := chainid()
		}
		return
			keccak256(abi.encodePacked("claimOrder", chId, _order.receiver, _order.secretHash))
				.toEthSignedMessageHash();
	}
}


// File: contracts/libs/LibExchange.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MarginalFunctionality.sol";
import "./LibUnitConverter.sol";
import "./LibValidator.sol";
import "./SafeTransferHelper.sol";

library LibExchange {
	using SafeERC20 for IERC20;

	//  Flags for updateOrders
	//      All flags are explicit
	uint8 public constant kSell = 0;
	uint8 public constant kBuy = 1; //  if 0 - then sell
	uint8 public constant kCorrectMatcherFeeByOrderAmount = 2;

	event NewTrade(
		address indexed buyer,
		address indexed seller,
		address baseAsset,
		address quoteAsset,
		uint64 filledPrice,
		uint192 filledAmount,
		uint192 amountQuote
	);

	event Trade(
		address indexed buyer,
		address indexed seller,
		address baseAsset,
		address quoteAsset,
		uint64 filledPrice,
		uint192 filledAmount,
		uint192 amountQuote,
		bytes32 tradeId
	);

	event BalanceChange(address user, address asset, int192 delta);

	function _updateBalance(
		address user,
		address asset,
		int amount,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => MarginalFunctionality.Liability[]) storage liabilities
	) internal returns (uint tradeType) {
		// 0 - in contract, 1 - from wallet
		int beforeBalance = int(assetBalances[user][asset]);
		int afterBalance = beforeBalance + amount;
		require((amount >= 0 && afterBalance >= beforeBalance) || (amount < 0 && afterBalance < beforeBalance), "E11");

		if (amount > 0 && beforeBalance < 0) {
			MarginalFunctionality.updateLiability(
				user,
				asset,
				liabilities,
				uint112(uint256(amount)),
				int192(afterBalance)
			);
		} else if (beforeBalance >= 0 && afterBalance < 0) {
			if (asset != address(0)) {
				afterBalance += int(_tryDeposit(asset, uint(-1 * afterBalance), user));
			}

			// If we failed to deposit balance is still negative then we move user into liability
			if (afterBalance < 0) {
				setLiability(user, asset, int192(afterBalance), liabilities);
			} else {
				tradeType = beforeBalance > 0 ? 0 : 1;
			}
		}

		if (beforeBalance != afterBalance) {
			require(afterBalance >= type(int192).min && afterBalance <= type(int192).max, "E11");
			int192 delta = int192(afterBalance) - assetBalances[user][asset];
			assetBalances[user][asset] = int192(afterBalance);
			emit BalanceChange(user, asset, delta);
		}
	}

	/**
	 * @dev method to add liability
	 * @param user - user which created liability
	 * @param asset - liability asset
	 * @param balance - current negative balance
	 */
	function setLiability(
		address user,
		address asset,
		int192 balance,
		mapping(address => MarginalFunctionality.Liability[]) storage liabilities
	) internal {
		liabilities[user].push(
			MarginalFunctionality.Liability({
				asset: asset,
				timestamp: uint64(block.timestamp),
				outstandingAmount: uint192(-balance)
			})
		);
	}

	function _tryDeposit(address asset, uint amount, address user) internal returns (uint) {
		uint256 amountInBase = uint256(LibUnitConverter.decimalToBaseUnit(asset, amount));

		// Query allowance before trying to transferFrom
		if (
			IERC20(asset).balanceOf(user) >= amountInBase &&
			IERC20(asset).allowance(user, address(this)) >= amountInBase
		) {
			SafeERC20.safeTransferFrom(IERC20(asset), user, address(this), amountInBase);
			return amount;
		} else {
			return 0;
		}
	}

	function creditUserAssets(
		uint tradeType,
		address user,
		int amount,
		address asset,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => MarginalFunctionality.Liability[]) storage liabilities
	) internal {
		int beforeBalance = int(assetBalances[user][asset]);
		int remainingAmount = amount + beforeBalance;
		require(
			(amount >= 0 && remainingAmount >= beforeBalance) || (amount < 0 && remainingAmount < beforeBalance),
			"E11"
		);
		int sentAmount = 0;

		if (tradeType == 0 && asset == address(0) && user.balance < 1e16) {
			tradeType = 1;
		}

		if (tradeType == 1 && amount > 0 && remainingAmount > 0) {
			uint amountInBase = uint(LibUnitConverter.decimalToBaseUnit(asset, uint(amount)));
			uint contractBalance = asset == address(0) ? address(this).balance : IERC20(asset).balanceOf(address(this));
			if (contractBalance >= amountInBase) {
				SafeTransferHelper.safeTransferTokenOrETH(asset, user, amountInBase);
				sentAmount = amount;
			}
		}
		int toUpdate = amount - sentAmount;
		if (toUpdate != 0) {
			_updateBalance(user, asset, toUpdate, assetBalances, liabilities);
		}
	}

	struct SwapBalanceChanges {
		int amountOut;
		address assetOut;
		int amountIn;
		address assetIn;
	}

	/**
	 *  @notice update user balances and send matcher fee
	 *  @param flags uint8, see constants for possible flags of order
	 */
	function updateOrderBalanceDebit(
		LibValidator.Order memory order,
		uint112 amountBase,
		uint112 amountQuote,
		uint8 flags,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => MarginalFunctionality.Liability[]) storage liabilities
	) internal returns (uint tradeType, int actualIn) {
		bool isSeller = (flags & kBuy) == 0;

		{
			//  Stack too deep
			bool isCorrectFee = ((flags & kCorrectMatcherFeeByOrderAmount) != 0);

			if (isCorrectFee) {
				// matcherFee: u64, filledAmount u128 => matcherFee*filledAmount fit u256
				// result matcherFee fit u64
				order.matcherFee = uint64((uint256(order.matcherFee) * amountBase) / order.amount); //rewrite in memory only
			}
		}

		if (amountBase > 0) {
			SwapBalanceChanges memory swap;

			(swap.amountOut, swap.amountIn) = isSeller
				? (-1 * int(uint(amountBase)), int(uint(amountQuote)))
				: (-1 * int(uint(amountQuote)), int(uint(amountBase)));

			(swap.assetOut, swap.assetIn) = isSeller
				? (order.baseAsset, order.quoteAsset)
				: (order.quoteAsset, order.baseAsset);

			uint feeTradeType = 1;
			if (order.matcherFeeAsset == swap.assetOut) {
				swap.amountOut -= int(uint(order.matcherFee));
			} else if (order.matcherFeeAsset == swap.assetIn) {
				swap.amountIn -= int(uint(order.matcherFee));
			} else {
				feeTradeType = _updateBalance(
					order.senderAddress,
					order.matcherFeeAsset,
					-1 * int256(uint256(order.matcherFee)),
					assetBalances,
					liabilities
				);
			}

			tradeType =
				feeTradeType &
				_updateBalance(order.senderAddress, swap.assetOut, swap.amountOut, assetBalances, liabilities);

			actualIn = swap.amountIn;

			_updateBalance(
				order.matcherAddress,
				order.matcherFeeAsset,
				int256(uint256(order.matcherFee)),
				assetBalances,
				liabilities
			);
		}
	}
}


// File: contracts/libs/LibGenericSwap.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./LibValidator.sol";
import "./LibExchange.sol";
import "../interfaces/IAggregationExecutor.sol";
import "../utils/Errors.sol";

library LibGenericSwap {
	using SafeERC20 for IERC20;
	using SafeTransferHelper for IERC20;

	uint256 private constant _USE_EXCHANGE_BALANCE = 1 << 255;
	event OrionPoolSwap(
		address sender,
		address st,
		address rt,
		uint256 st_r,
		uint256 st_a,
		uint256 rt_r,
		uint256 rt_a,
		address f
	);

	error EthDepositRejected();
	error InsufficientReturnAmount();
	error InsufficientBalance();
	error ZeroMinReturnAmount();

	function fillThroughPools(
		bytes32 orderHash,
		address senderAddress,
		IAggregationExecutor executor,
		LibValidator.SwapDescription memory desc,
		bytes calldata data
	) external {
		uint112 filledAmount;
		uint112 quoteAmount;
		// stack too deep
		{
			(uint256 returnAmount, uint256 spentAmount, ) = swap(senderAddress, executor, desc, data);
			filledAmount = LibUnitConverter.baseUnitToDecimal(address(desc.srcToken), spentAmount);
			quoteAmount = LibUnitConverter.baseUnitToDecimal(address(desc.dstToken), returnAmount);
		}

		emit LibExchange.Trade(
			senderAddress,
			address(this),
			address(desc.srcToken),
			address(desc.dstToken),
			uint64((quoteAmount * 1e8) / filledAmount),
			filledAmount,
			quoteAmount,
			keccak256(abi.encode(orderHash, filledAmount))
		);
	}

	function swap(
		address sender,
		IAggregationExecutor executor,
		LibValidator.SwapDescription memory desc,
		bytes calldata data
	) public returns (uint256 returnAmount, uint256 spentAmount, uint256 gasLeft) {
		(uint112 amount, uint112 minReturnAmount) = (
			LibUnitConverter.decimalToBaseUnit(address(desc.srcToken), desc.amount),
			LibUnitConverter.decimalToBaseUnit(address(desc.dstToken), desc.minReturnAmount)
		);
		if (minReturnAmount == 0) revert ZeroMinReturnAmount();
		address payable dstReceiver = (desc.dstReceiver == address(0)) ? payable(sender) : desc.dstReceiver;

		returnAmount = desc.dstToken.uniBalanceOf(dstReceiver);
		_execute(sender, executor, data);
		returnAmount = desc.dstToken.uniBalanceOf(dstReceiver) - returnAmount;

		if (returnAmount < minReturnAmount) revert InsufficientReturnAmount();

		gasLeft = gasleft();
		spentAmount = amount;

		emit OrionPoolSwap(
			sender,
			address(desc.srcToken),
			address(desc.dstToken),
			spentAmount,
			spentAmount,
			returnAmount,
			returnAmount,
			address(0xA6E4Ce17474d790fb25E779F9317c55963D2cbdf)
		);
	}

	function transferToInitialSource(
		address sender,
		LibValidator.SwapDescription memory desc,
		bytes calldata permit,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => MarginalFunctionality.Liability[]) storage liabilities
	) external {
		bool srcETH = SafeTransferHelper.isETH(desc.srcToken);
		bool useExchangeBalance = desc.flags & _USE_EXCHANGE_BALANCE != 0;
		uint112 amount = LibUnitConverter.decimalToBaseUnit(address(desc.srcToken), desc.amount);

		if (!srcETH) {
			if (permit.length > 0) {
				desc.srcToken.safePermit(permit);
			}
		}

		if (useExchangeBalance) {
			if ((srcETH && (msg.value >= amount)) || (!srcETH && (msg.value != 0))) revert Errors.InvalidMsgValue();

			int updateAmount = -int(desc.amount);
			if (srcETH) {
				uint112 valueInDecimal = LibUnitConverter.baseUnitToDecimal(address(0), msg.value);
				updateAmount += int(uint(valueInDecimal));
			}
			if (updateAmount != 0) {
				LibExchange._updateBalance(sender, address(desc.srcToken), updateAmount, assetBalances, liabilities);
			}
			if (assetBalances[sender][address(desc.srcToken)] < 0) revert InsufficientBalance();

			desc.srcToken.uniTransfer(desc.srcReceiver, amount);
		} else {
			if (msg.value != (srcETH ? amount : 0)) revert Errors.InvalidMsgValue();

			if (!srcETH) {
				desc.srcToken.safeTransferFrom(sender, desc.srcReceiver, amount);
			}
		}
	}

	function _execute(address srcTokenOwner, IAggregationExecutor executor, bytes calldata data) private {
		bytes4 callBytesSelector = executor.callBytes.selector;
		assembly {
			// solhint-disable-line no-inline-assembly
			let ptr := mload(0x40)
			mstore(ptr, callBytesSelector)
			mstore(add(ptr, 0x04), srcTokenOwner)
			calldatacopy(add(ptr, 0x24), data.offset, data.length)

			if iszero(call(gas(), executor, callvalue(), ptr, add(0x24, data.length), 0, 0)) {
				returndatacopy(ptr, 0, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}
}


// File: contracts/libs/LibUnitConverter.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "../interfaces/IERC20Simple.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library LibUnitConverter {
	using SafeMath for uint;

	/**
        @notice convert asset amount from8 decimals (10^8) to its base unit
     */
	function decimalToBaseUnit(address assetAddress, uint amount) internal view returns (uint112 baseValue) {
		uint256 result;

		if (assetAddress == address(0)) {
			result = amount.mul(1 ether).div(10 ** 8); // 18 decimals
		} else {
			uint decimals = IERC20Simple(assetAddress).decimals();

			result = amount.mul(10 ** decimals).div(10 ** 8);
		}

		require(result < uint112(type(int112).max), "E3U");
		baseValue = uint112(result);
	}

	/**
        @notice convert asset amount from its base unit to 8 decimals (10^8)
     */
	function baseUnitToDecimal(address assetAddress, uint amount) internal view returns (uint112 decimalValue) {
		uint256 result;

		if (assetAddress == address(0)) {
			result = amount.mul(10 ** 8).div(1 ether);
		} else {
			uint decimals = IERC20Simple(assetAddress).decimals();

			result = amount.mul(10 ** 8).div(10 ** decimals);
		}
		require(result < uint112(type(int112).max), "E3U");
		decimalValue = uint112(result);
	}
}


// File: contracts/libs/LibValidator.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

library LibValidator {
	using ECDSA for bytes32;

	string public constant DOMAIN_NAME = "Orion Exchange";
	string public constant DOMAIN_VERSION = "1";
	uint256 public constant CHAIN_ID = 1;
	bytes32 public constant DOMAIN_SALT = 0xf2d857f4a3edcb9b78b4d503bfe733db1e3f6cdc2b7971ee739626c97e86a557;

	bytes32 public constant EIP712_DOMAIN_TYPEHASH =
		keccak256(abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,bytes32 salt)"));
	bytes32 public constant ORDER_TYPEHASH =
		keccak256(
			abi.encodePacked(
				"Order(address senderAddress,address matcherAddress,address baseAsset,address quoteAsset,address matcherFeeAsset,uint64 amount,uint64 price,uint64 matcherFee,uint64 nonce,uint64 expiration,uint8 buySide)"
			)
		);

	bytes32 public constant DOMAIN_SEPARATOR =
		keccak256(
			abi.encode(
				EIP712_DOMAIN_TYPEHASH,
				keccak256(bytes(DOMAIN_NAME)),
				keccak256(bytes(DOMAIN_VERSION)),
				CHAIN_ID,
				DOMAIN_SALT
			)
		);

	struct Order {
		address senderAddress;
		address matcherAddress;
		address baseAsset;
		address quoteAsset;
		address matcherFeeAsset;
		uint64 amount;
		uint64 price;
		uint64 matcherFee;
		uint64 nonce;
		uint64 expiration;
		uint8 buySide; // buy or sell
		bytes signature;
	}

	struct SwapDescription {
		IERC20 srcToken;
		IERC20 dstToken;
		address payable srcReceiver;
		address payable dstReceiver;
		uint256 amount;
		uint256 minReturnAmount;
		uint256 flags;
	}

	/**
	 * @dev validate order signature
	 */
	function validateV3(Order memory order) public pure returns (bool, bytes32) {
		bytes32 orderHash = getTypeValueHash(order);
		bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, orderHash));

		return (digest.recover(order.signature) == order.senderAddress, orderHash);
	}

	/**
	 * @return hash order
	 */
	function getTypeValueHash(Order memory _order) internal pure returns (bytes32) {
		return
			keccak256(
				abi.encode(
					ORDER_TYPEHASH,
					_order.senderAddress,
					_order.matcherAddress,
					_order.baseAsset,
					_order.quoteAsset,
					_order.matcherFeeAsset,
					_order.amount,
					_order.price,
					_order.matcherFee,
					_order.nonce,
					_order.expiration,
					_order.buySide
				)
			);
	}

	/**
	 * @dev basic checks of matching orders against each other
	 */
	function checkOrdersInfo(
		Order memory buyOrder,
		Order memory sellOrder,
		address sender,
		uint256 filledAmount,
		uint256 filledPrice,
		uint256 currentTime,
		address allowedMatcher
	) public pure returns (bytes32 buyOrderHash, bytes32 sellOrderHash) {
		bool isBuyOrderValid;
		bool isSellOrderValid;
		(isBuyOrderValid, buyOrderHash) = validateV3(buyOrder);
		(isSellOrderValid, sellOrderHash) = validateV3(sellOrder);
		require(isBuyOrderValid, "E2B");
		require(isSellOrderValid, "E2S");

		// Same matcher address
		require(buyOrder.matcherAddress == sender && sellOrder.matcherAddress == sender, "E3M");

		if (allowedMatcher != address(0)) {
			require(buyOrder.matcherAddress == allowedMatcher, "E3M2");
		}

		// Check matching assets
		require(buyOrder.baseAsset == sellOrder.baseAsset && buyOrder.quoteAsset == sellOrder.quoteAsset, "E3As");

		// Check order amounts
		require(filledAmount <= buyOrder.amount, "E3AmB");
		require(filledAmount <= sellOrder.amount, "E3AmS");

		// Check Price values
		require(filledPrice <= buyOrder.price, "E3");
		require(filledPrice >= sellOrder.price, "E3");

		// Check Expiration Time. Convert to seconds first
		require(buyOrder.expiration / 1000 >= currentTime, "E4B");
		require(sellOrder.expiration / 1000 >= currentTime, "E4S");

		require(buyOrder.buySide == 1 && sellOrder.buySide == 0, "E3D");
	}

	function getEthSignedOrderHash(Order memory _order) public pure returns (bytes32) {
		return
			keccak256(
				abi.encodePacked(
					"order",
					_order.senderAddress,
					_order.matcherAddress,
					_order.baseAsset,
					_order.quoteAsset,
					_order.matcherFeeAsset,
					_order.amount,
					_order.price,
					_order.matcherFee,
					_order.nonce,
					_order.expiration,
					_order.buySide
				)
			).toEthSignedMessageHash();
	}

	function checkOrderSingleMatch(
		Order memory order,
		SwapDescription memory desc,
		uint256 filledAmount,
		uint256 currentTime
	) internal pure returns (bytes32 orderHash) {
		bool isOrderValid;
		(isOrderValid, orderHash) = validateV3(order);
		require(isOrderValid, "E2B");

		uint256 amountQuote = (uint256(filledAmount) * order.price) / 10 ** 8;

		uint256 amount_spend;
		uint256 amount_receive;
		if (order.buySide == 1) {
			require(order.quoteAsset == address(desc.srcToken) && order.baseAsset == address(desc.dstToken), "E3As");
			(amount_spend, amount_receive) = (amountQuote, filledAmount);
		} else {
			require(order.baseAsset == address(desc.srcToken) && order.quoteAsset == address(desc.dstToken), "E3As");
			(amount_spend, amount_receive) = (filledAmount, amountQuote);
		}

		require(order.senderAddress == desc.dstReceiver, "IncorrectReceiver");
		require(amount_spend == desc.amount, "IncorrectAmount");
		require(amount_receive >= desc.minReturnAmount, "IncorrectAmount");
		require(filledAmount <= order.amount, "E3AmB");
		require(order.expiration / 1000 >= currentTime, "E4B");
		if (address(desc.dstToken) == order.matcherFeeAsset) {
			require(desc.minReturnAmount > order.matcherFee);
		}
	}
}


// File: contracts/libs/MarginalFunctionality.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;
pragma experimental ABIEncoderV2;
import "../PriceOracleInterface.sol";
import "./LibExchange.sol";

library MarginalFunctionality {
	// We have the following approach: when liability is created we store
	// timestamp and size of liability. If the subsequent trade will deepen
	// this liability or won't fully cover it timestamp will not change.
	// However once outstandingAmount is covered we check whether balance on
	// that asset is positive or not. If not, liability still in the place but
	// time counter is dropped and timestamp set to `now`.
	struct Liability {
		address asset;
		uint64 timestamp;
		uint192 outstandingAmount;
	}

	enum PositionState {
		POSITIVE,
		NEGATIVE, // weighted position below 0
		OVERDUE, // liability is not returned for too long
		NOPRICE, // some assets has no price or expired
		INCORRECT // some of the basic requirements are not met: too many liabilities, no locked stake, etc
	}

	struct Position {
		PositionState state;
		int256 weightedPosition; // sum of weighted collateral minus liabilities
		int256 totalPosition; // sum of unweighted (total) collateral minus liabilities
		int256 totalLiabilities; // total liabilities value
	}

	// Constants from Exchange contract used for calculations
	struct UsedConstants {
		address user;
		address _oracleAddress;
		address _orionTokenAddress;
		uint64 positionOverdue;
		uint64 priceOverdue;
		uint8 stakeRisk;
		uint8 liquidationPremium;
	}

	/**
	 * @dev method to multiply numbers with uint8 based percent numbers
	 */
	function uint8Percent(int192 _a, uint8 _b) internal pure returns (int192 c) {
		int a = int256(_a);
		int b = int256(uint256(_b));
		int d = 255;
		c = int192((a > 65536) ? (a / d) * b : (a * b) / d);
	}

	/**
	 * @dev method to fetch asset prices in ORN tokens
	 */
	function getAssetPrice(address asset, address oracle) internal view returns (uint64 price, uint64 timestamp) {
		PriceOracleInterface.PriceDataOut memory assetPriceData = PriceOracleInterface(oracle).assetPrices(asset);
		(price, timestamp) = (assetPriceData.price, assetPriceData.timestamp);
	}

	/**
     * @dev method to calc weighted and absolute collateral value
     * @notice it only count for assets in collateralAssets list, all other
               assets will add 0 to position.
     * @return outdated whether any price is outdated
     * @return weightedPosition in ORN
     * @return totalPosition in ORN
     */
	function calcAssets(
		address[] storage collateralAssets,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => uint8) storage assetRisks,
		address user,
		address orionTokenAddress,
		address oracleAddress,
		uint64 priceOverdue
	) internal view returns (bool outdated, int192 weightedPosition, int192 totalPosition) {
		uint256 collateralAssetsLength = collateralAssets.length;
		for (uint256 i = 0; i < collateralAssetsLength; i++) {
			address asset = collateralAssets[i];
			if (assetBalances[user][asset] < 0) continue; // will be calculated in calcLiabilities
			(uint64 price, uint64 timestamp) = (1e8, 0xfffffff000000000);

			if (asset != orionTokenAddress) {
				(price, timestamp) = getAssetPrice(asset, oracleAddress);
			}

			// balance: i192, price u64 => balance*price fits i256
			// since generally balance <= N*maxInt112 (where N is number operations with it),
			// assetValue <= N*maxInt112*maxUInt64/1e8.
			// That is if N<= 2**17 *1e8 = 1.3e13  we can neglect overflows here

			uint8 specificRisk = assetRisks[asset];
			int192 balance = assetBalances[user][asset];
			int256 _assetValue = (int256(balance) * int256(uint256(price))) / 1e8;
			int192 assetValue = int192(_assetValue);

			// Overflows logic holds here as well, except that N is the number of
			// operations for all assets

			if (assetValue > 0) {
				weightedPosition += uint8Percent(assetValue, specificRisk);
				totalPosition += assetValue;
				outdated = outdated || ((timestamp + priceOverdue) < block.timestamp);
			}
		}

		return (outdated, weightedPosition, totalPosition);
	}

	/**
	 * @dev method to calc liabilities
	 * @return outdated whether any price is outdated
	 * @return overdue whether any liability is overdue
	 * @return weightedPosition weightedLiability == totalLiability in ORN
	 * @return totalPosition totalLiability in ORN
	 */
	function calcLiabilities(
		mapping(address => Liability[]) storage liabilities,
		mapping(address => mapping(address => int192)) storage assetBalances,
		address user,
		address oracleAddress,
		uint64 positionOverdue,
		uint64 priceOverdue
	) internal view returns (bool outdated, bool overdue, int192 weightedPosition, int192 totalPosition) {
		uint256 liabilitiesLength = liabilities[user].length;

		for (uint256 i = 0; i < liabilitiesLength; i++) {
			Liability storage liability = liabilities[user][i];
			int192 balance = assetBalances[user][liability.asset];
			(uint64 price, uint64 timestamp) = getAssetPrice(liability.asset, oracleAddress);
			// balance: i192, price u64 => balance*price fits i256
			// since generally balance <= N*maxInt112 (where N is number operations with it),
			// assetValue <= N*maxInt112*maxUInt64/1e8.
			// That is if N<= 2**17 *1e8 = 1.3e13  we can neglect overflows here

			int192 liabilityValue = int192((int256(balance) * int256(uint256(price))) / 1e8);
			weightedPosition += liabilityValue; //already negative since balance is negative
			totalPosition += liabilityValue;
			overdue = overdue || ((liability.timestamp + positionOverdue) < block.timestamp);
			outdated = outdated || ((timestamp + priceOverdue) < block.timestamp);
		}

		return (outdated, overdue, weightedPosition, totalPosition);
	}

	/**
	 * @dev method to calc Position
	 * @return result position structure
	 */
	function calcPosition(
		address[] storage collateralAssets,
		mapping(address => Liability[]) storage liabilities,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => uint8) storage assetRisks,
		UsedConstants memory constants
	) public view returns (Position memory result) {
		(bool outdatedPrice, int192 weightedPosition, int192 totalPosition) = calcAssets(
			collateralAssets,
			assetBalances,
			assetRisks,
			constants.user,
			constants._orionTokenAddress,
			constants._oracleAddress,
			constants.priceOverdue
		);

		(bool _outdatedPrice, bool overdue, int192 _weightedPosition, int192 _totalPosition) = calcLiabilities(
			liabilities,
			assetBalances,
			constants.user,
			constants._oracleAddress,
			constants.positionOverdue,
			constants.priceOverdue
		);

		weightedPosition += _weightedPosition;
		totalPosition += _totalPosition;
		outdatedPrice = outdatedPrice || _outdatedPrice;
		if (_totalPosition < 0) {
			result.totalLiabilities = _totalPosition;
		}
		if (weightedPosition < 0) {
			result.state = PositionState.NEGATIVE;
		}
		if (outdatedPrice) {
			result.state = PositionState.NOPRICE;
		}
		if (overdue) {
			result.state = PositionState.OVERDUE;
		}
		result.weightedPosition = weightedPosition;
		result.totalPosition = totalPosition;
	}

	/**
	 * @dev method removes liability
	 */
	function removeLiability(address user, address asset, mapping(address => Liability[]) storage liabilities) public {
		uint256 length = liabilities[user].length;

		for (uint256 i = 0; i < length; i++) {
			if (liabilities[user][i].asset == asset) {
				if (length > 1) {
					liabilities[user][i] = liabilities[user][length - 1];
				}
				liabilities[user].pop();
				break;
			}
		}
	}

	/**
	 * @dev method update liability
	 * @notice implement logic for outstandingAmount (see Liability description)
	 */
	function updateLiability(
		address user,
		address asset,
		mapping(address => Liability[]) storage liabilities,
		uint112 depositAmount,
		int192 currentBalance
	) internal {
		if (currentBalance >= 0) {
			removeLiability(user, asset, liabilities);
		} else {
			uint256 i;
			uint256 liabilitiesLength = liabilities[user].length;
			for (; i < liabilitiesLength - 1; i++) {
				if (liabilities[user][i].asset == asset) break;
			}
			Liability storage liability = liabilities[user][i];
			if (depositAmount >= liability.outstandingAmount) {
				liability.outstandingAmount = uint192(-currentBalance);
				liability.timestamp = uint64(block.timestamp);
			} else {
				liability.outstandingAmount -= depositAmount;
			}
		}
	}

	/**
     * @dev partially liquidate, that is cover some asset liability to get
            ORN from misbehavior broker
     */
	function partiallyLiquidate(
		address[] storage collateralAssets,
		mapping(address => Liability[]) storage liabilities,
		mapping(address => mapping(address => int192)) storage assetBalances,
		mapping(address => uint8) storage assetRisks,
		UsedConstants memory constants,
		address redeemedAsset,
		address collateralAsset,
		uint112 amount
	) public {
		//Note: constants.user - is broker who will be liquidated
		Position memory initialPosition = calcPosition(
			collateralAssets,
			liabilities,
			assetBalances,
			assetRisks,
			constants
		);
		require(
			initialPosition.state == PositionState.NEGATIVE || initialPosition.state == PositionState.OVERDUE,
			"E7"
		);
		address liquidator = msg.sender;
		require(assetBalances[liquidator][redeemedAsset] >= int192(uint192(amount)), "E8");
		require(assetBalances[constants.user][redeemedAsset] < 0, "E15");
		assetBalances[liquidator][redeemedAsset] -= int192(uint192(amount));
		assetBalances[constants.user][redeemedAsset] += int192(uint192(amount));

		emit LibExchange.BalanceChange(liquidator, redeemedAsset, -int192(uint192(amount)));
		emit LibExchange.BalanceChange(constants.user, redeemedAsset, int192(uint192(amount)));

		if (assetBalances[constants.user][redeemedAsset] >= 0)
			removeLiability(constants.user, redeemedAsset, liabilities);

		(uint64 price, uint64 ts1) = getAssetPrice(redeemedAsset, constants._oracleAddress);
		require(ts1 + constants.priceOverdue > block.timestamp, "E9"); //Price is outdated

		if (collateralAsset != constants._orionTokenAddress) { //
			(uint64 collateralPrice, uint64 ts2) = getAssetPrice(collateralAsset, constants._oracleAddress);
			require(ts2 + constants.priceOverdue > block.timestamp, "E9"); //Price is outdated
			price = (price * 1e8) / collateralPrice;
		}

		reimburseLiquidator(
			amount,
			price,
			collateralAsset,
			liquidator,
			assetBalances,
			constants.liquidationPremium,
			constants.user
		);

		Position memory finalPosition = calcPosition(
			collateralAssets,
			liabilities,
			assetBalances,
			assetRisks,
			constants
		);
		require(
			uint(finalPosition.state) < 3 && //POSITIVE,NEGATIVE or OVERDUE
				(finalPosition.weightedPosition > initialPosition.weightedPosition),
			"E10"
		); //Incorrect state position after liquidation
		if (finalPosition.state == PositionState.POSITIVE)
			require(finalPosition.weightedPosition < 10e8, "Can not liquidate to very positive state");
	}

	/**
	 * @dev reimburse liquidator with collateral: first from stake, than from broker balance
	 */
	function reimburseLiquidator(
		uint112 amount,
		uint64 price,
		address collateralAsset,
		address liquidator,
		mapping(address => mapping(address => int192)) storage assetBalances,
		uint8 liquidationPremium,
		address user
	) internal {
		int192 collateralAmount = int192((int256(uint256(amount)) * int256(uint256(price))) / 1e8);
		collateralAmount += uint8Percent(collateralAmount, liquidationPremium); //Liquidation premium

		int192 onBalanceCollateral = assetBalances[user][collateralAsset];

		require(onBalanceCollateral >= collateralAmount, "E10");
		assetBalances[user][collateralAsset] -= collateralAmount;
		assetBalances[liquidator][collateralAsset] += collateralAmount;

		emit LibExchange.BalanceChange(user, collateralAsset, -collateralAmount);
		emit LibExchange.BalanceChange(liquidator, collateralAsset, collateralAmount);
	}
}


// File: contracts/libs/SafeTransferHelper.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IWETH.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../helpers/RevertReasonForwarder.sol";
import "../interfaces/IDaiLikePermit.sol";


library SafeTransferHelper {
	using SafeERC20 for IERC20;

	error InsufficientBalance();
	error ForceApproveFailed();
	error ApproveCalledOnETH();
	error NotEnoughValue();
	error FromIsNotSender();
	error ToIsNotThis();
	error ETHTransferFailed();
	error SafePermitBadLength();

	uint256 private constant _RAW_CALL_GAS_LIMIT = 5000;
	IERC20 private constant _ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
	IERC20 private constant _ZERO_ADDRESS = IERC20(address(0));

	/// @dev Returns true if `token` is ETH.
	function isETH(IERC20 token) internal pure returns (bool) {
		return (token == _ZERO_ADDRESS || token == _ETH_ADDRESS);
	}

	/// @dev Returns `account` ERC20 `token` balance.
	function uniBalanceOf(IERC20 token, address account) internal view returns (uint256) {
		if (isETH(token)) {
			return account.balance;
		} else {
			return token.balanceOf(account);
		}
	}

	/// @dev `token` transfer `to` `amount`.
	/// Note that this function does nothing in case of zero amount.
	/// @dev `token` transfer `to` `amount`.
	/// Note that this function does nothing in case of zero amount.
	function uniTransfer(IERC20 token, address payable to, uint256 amount) internal {
		if (amount > 0) {
			if (isETH(token)) {
				if (address(this).balance < amount) revert InsufficientBalance();
				// solhint-disable-next-line avoid-low-level-calls
				(bool success, ) = to.call{value: amount, gas: _RAW_CALL_GAS_LIMIT}("");
				if (!success) revert ETHTransferFailed();
			} else {
				token.safeTransfer(to, amount);
			}
		}
	}

	/// @dev Reverts if `token` is ETH, otherwise performs ERC20 forceApprove.
	function uniApprove(IERC20 token, address to, uint256 amount) internal {
		if (isETH(token)) revert ApproveCalledOnETH();

		forceApprove(token, to, amount);
	}

	/// @dev If `approve(from, to, amount)` fails, try to `approve(from, to, 0)` before retry.
	function forceApprove(IERC20 token, address spender, uint256 value) internal {
		if (!_makeCall(token, token.approve.selector, spender, value)) {
			if (
				!_makeCall(token, token.approve.selector, spender, 0) ||
				!_makeCall(token, token.approve.selector, spender, value)
			) {
				revert ForceApproveFailed();
			}
		}
	}

	function safeAutoTransferFrom(address weth, address token, address from, address to, uint value) internal {
		if (isETH(IERC20(token))) {
			require(from == address(this), "TransferFrom: this");
			IWETH(weth).deposit{value: value}();
			assert(IWETH(weth).transfer(to, value));
		} else {
			if (from == address(this)) {
				SafeERC20.safeTransfer(IERC20(token), to, value);
			} else {
				SafeERC20.safeTransferFrom(IERC20(token), from, to, value);
			}
		}
	}

	function safeAutoTransferTo(address weth, address token, address to, uint value) internal {
		if (address(this) != to) {
			if (isETH(IERC20(token))) {
				IWETH(weth).withdraw(value);
				Address.sendValue(payable(to), value);
			} else {
				SafeERC20.safeTransfer(IERC20(token), to, value);
			}
		}
	}

	function safeTransferTokenOrETH(address token, address to, uint value) internal {
		if (value > 0) {
			if (isETH(IERC20(token))) {
				if (address(this).balance < value) revert InsufficientBalance();
				// solhint-disable-next-line avoid-low-level-calls
				(bool success, ) = to.call{value: value, gas: _RAW_CALL_GAS_LIMIT}("");
				if (!success) revert ETHTransferFailed();
			} else {
				IERC20(token).safeTransfer(to, value);
			}
		}
	}

	function safePermit(IERC20 token, bytes calldata permit) internal {
		bool success;
		if (permit.length == 32 * 7) {
			// solhint-disable-next-line avoid-low-level-calls
			success = _makeCalldataCall(token, IERC20Permit.permit.selector, permit);
		} else if (permit.length == 32 * 8) {
			// solhint-disable-next-line avoid-low-level-calls
			success = _makeCalldataCall(token, IDaiLikePermit.permit.selector, permit);
		} else {
			revert SafePermitBadLength();
		}

		if (!success) {
			RevertReasonForwarder.reRevert();
		}
	}

    function _makeCall(IERC20 token, bytes4 selector, address to, uint256 amount) private returns (bool success) {
		assembly ("memory-safe") {
			// solhint-disable-line no-inline-assembly
			let data := mload(0x40)

			mstore(data, selector)
			mstore(add(data, 0x04), to)
			mstore(add(data, 0x24), amount)
			success := call(gas(), token, 0, data, 0x44, 0x0, 0x20)
			if success {
				switch returndatasize()
				case 0 {
					success := gt(extcodesize(token), 0)
				}
				default {
					success := and(gt(returndatasize(), 31), eq(mload(0), 1))
				}
			}
		}
	}

	function _makeCalldataCall(IERC20 token, bytes4 selector, bytes calldata args) private returns (bool done) {
		/// @solidity memory-safe-assembly
		assembly {
			// solhint-disable-line no-inline-assembly
			let len := add(4, args.length)
			let data := mload(0x40)

			mstore(data, selector)
			calldatacopy(add(data, 0x04), args.offset, args.length)
			let success := call(gas(), token, 0, data, len, 0x0, 0x20)
			done := and(success, or(iszero(returndatasize()), and(gt(returndatasize(), 31), eq(mload(0), 1))))
		}
	}
}


// File: contracts/OrionVault.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ExchangeStorage.sol";
import "./libs/LibExchange.sol";

abstract contract OrionVault is ExchangeStorage, ReentrancyGuard, OwnableUpgradeable {
    error NotEnoughBalance();
	enum StakePhase {
		NOTSTAKED,
		LOCKED,
		RELEASING,
		READYTORELEASE,
		FROZEN
	}

	struct Stake {
		uint64 amount; // 100m ORN in circulation fits uint64
		StakePhase phase;
		uint64 lastActionTimestamp;
	}

	uint64 constant releasingDuration = 3600 * 24;
	mapping(address => Stake) private stakingData;

	/**
	 * @dev Returns locked or frozen stake balance only
	 * @param user address
	 */
	function getLockedStakeBalance(address user) public view returns (uint256) {
		return stakingData[user].amount;
	}

	/**
	 * @dev Request stake unlock for msg.sender
	 * @dev If stake phase is LOCKED, that changes phase to RELEASING
	 * @dev If stake phase is READYTORELEASE, that withdraws stake to balance
	 * @dev Note, both unlock and withdraw is impossible if user has liabilities
	 */
	function requestReleaseStake() public {
		address user = _msgSender();
		Stake storage stake = stakingData[user];
		assetBalances[user][address(_orionToken)] += int192(uint192(stake.amount));
		emit LibExchange.BalanceChange(user, address(_orionToken), int192(uint192(stake.amount)));
		stake.amount = 0;
		stake.phase = StakePhase.NOTSTAKED;
	}

	/**
	 * @dev Lock some orions from exchange balance sheet
	 * @param amount orions in 1e-8 units to stake
	 */
	function lockStake(uint64 amount) public {
		address user = _msgSender();
		if (assetBalances[user][address(_orionToken)] < int192(uint192(amount))) revert NotEnoughBalance();
		Stake storage stake = stakingData[user];

		assetBalances[user][address(_orionToken)] -= int192(uint192(amount));
		emit LibExchange.BalanceChange(user, address(_orionToken), -int192(uint192(amount)));

		stake.amount += amount;
	}
}


// File: contracts/PriceOracleDataTypes.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface PriceOracleDataTypes {
	struct PriceDataOut {
		uint64 price;
		uint64 timestamp;
	}
}


// File: contracts/PriceOracleInterface.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PriceOracleDataTypes.sol";

interface PriceOracleInterface is PriceOracleDataTypes {
	function assetPrices(address) external view returns (PriceDataOut memory);

	function givePrices(address[] calldata assetAddresses) external view returns (PriceDataOut[] memory);
}


// File: contracts/utils/Errors.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;
pragma abicoder v1;

library Errors {
	error ReturnAmountIsNotEnough();
	error InvalidMsgValue();
	error ERC20TransferFailed();
}


