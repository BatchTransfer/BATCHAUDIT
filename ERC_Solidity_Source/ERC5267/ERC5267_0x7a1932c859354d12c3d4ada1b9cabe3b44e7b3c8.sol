// File: contracts/dependencies/chainlink/AggregatorV3Interface.sol
// SPDX-License-Identifier: MIT
// Chainlink Contracts v0.4.0 (v0.8/interfaces/AggregatorV3Interface.sol)
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}


// File: contracts/dependencies/openzeppelin/interfaces/IERC5267.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC5267.sol)

pragma solidity ^0.8.0;

interface IERC5267 {
    /**
     * @dev MAY be emitted to signal that the domain could have changed.
     */
    event EIP712DomainChanged();

    /**
     * @dev returns the fields and values that describe the domain separator used by this contract for EIP-712
     * signature.
     */
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}


// File: contracts/dependencies/openzeppelin/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/Address.sol";

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
            (isTopLevelCall && _initialized < 1) ||
                (!Address.isContract(address(this)) && _initialized == 1),
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
        require(
            !_initializing && _initialized < version,
            "Initializable: contract is already initialized"
        );
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


// File: contracts/dependencies/openzeppelin/token/ERC20/extensions/IERC20Metadata.sol
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


// File: contracts/dependencies/openzeppelin/token/ERC20/extensions/IERC20Permit.sol
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


// File: contracts/dependencies/openzeppelin/token/ERC20/IERC20.sol
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


// File: contracts/dependencies/openzeppelin/utils/Address.sol
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(target, data, value, "Address: low-level call with value failed");
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
    function functionStaticCall(
        address target,
        bytes memory data
    ) internal view returns (bytes memory) {
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
    function functionDelegateCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
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


// File: contracts/dependencies/openzeppelin/utils/Context.sol
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


// File: contracts/dependencies/openzeppelin/utils/Counters.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
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
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}


// File: contracts/dependencies/openzeppelin/utils/cryptography/ECDSA.sol
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
    function tryRecover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address, RecoverError) {
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
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs &
            bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
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
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
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
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s)
            );
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
    function toTypedDataHash(
        bytes32 domainSeparator,
        bytes32 structHash
    ) internal pure returns (bytes32 data) {
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
    function toDataWithIntendedValidatorHash(
        address validator,
        bytes memory data
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x00", validator, data));
    }
}


// File: contracts/dependencies/openzeppelin/utils/cryptography/EIP712.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/EIP712.sol)

pragma solidity ^0.8.8;

import "./ECDSA.sol";
import "../ShortStrings.sol";
import "../../interfaces/IERC5267.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * NOTE: In the upgradeable version of this contract, the cached values will correspond to the address, and the domain
 * separator of the implementation contract. This will cause the `_domainSeparatorV4` function to always rebuild the
 * separator from the immutable values, which is cheaper than accessing a cached version in cold storage.
 *
 * _Available since v3.4._
 *
 * @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
 */
abstract contract EIP712 is IERC5267 {
    using ShortStrings for *;

    bytes32 private constant _TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _cachedDomainSeparator;
    uint256 private immutable _cachedChainId;
    address private immutable _cachedThis;

    bytes32 private immutable _hashedName;
    bytes32 private immutable _hashedVersion;

    ShortString private immutable _name;
    ShortString private immutable _version;
    string private _nameFallback;
    string private _versionFallback;

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    constructor(string memory name, string memory version) {
        _name = name.toShortStringWithFallback(_nameFallback);
        _version = version.toShortStringWithFallback(_versionFallback);
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));

        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator();
        }
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return
            keccak256(
                abi.encode(_TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this))
            );
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
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
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev See {EIP-5267}.
     *
     * _Available since v4.9._
     */
    function eip712Domain()
        public
        view
        virtual
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            hex"0f", // 01111
            _name.toStringWithFallback(_nameFallback),
            _version.toStringWithFallback(_versionFallback),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }
}


// File: contracts/dependencies/openzeppelin/utils/math/Math.sol
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


// File: contracts/dependencies/openzeppelin/utils/math/SignedMath.sol
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


// File: contracts/dependencies/openzeppelin/utils/ShortStrings.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/ShortStrings.sol)

pragma solidity ^0.8.8;

import "./StorageSlot.sol";

// | string  | 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA   |
// | length  | 0x                                                              BB |
type ShortString is bytes32;

/**
 * @dev This library provides functions to convert short memory strings
 * into a `ShortString` type that can be used as an immutable variable.
 *
 * Strings of arbitrary length can be optimized using this library if
 * they are short enough (up to 31 bytes) by packing them with their
 * length (1 byte) in a single EVM word (32 bytes). Additionally, a
 * fallback mechanism can be used for every other case.
 *
 * Usage example:
 *
 * ```solidity
 * contract Named {
 *     using ShortStrings for *;
 *
 *     ShortString private immutable _name;
 *     string private _nameFallback;
 *
 *     constructor(string memory contractName) {
 *         _name = contractName.toShortStringWithFallback(_nameFallback);
 *     }
 *
 *     function name() external view returns (string memory) {
 *         return _name.toStringWithFallback(_nameFallback);
 *     }
 * }
 * ```
 */
library ShortStrings {
    // Used as an identifier for strings longer than 31 bytes.
    bytes32 private constant _FALLBACK_SENTINEL =
        0x00000000000000000000000000000000000000000000000000000000000000FF;

    error StringTooLong(string str);
    error InvalidShortString();

    /**
     * @dev Encode a string of at most 31 chars into a `ShortString`.
     *
     * This will trigger a `StringTooLong` error is the input string is too long.
     */
    function toShortString(string memory str) internal pure returns (ShortString) {
        bytes memory bstr = bytes(str);
        if (bstr.length > 31) {
            revert StringTooLong(str);
        }
        return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
    }

    /**
     * @dev Decode a `ShortString` back to a "normal" string.
     */
    function toString(ShortString sstr) internal pure returns (string memory) {
        uint256 len = byteLength(sstr);
        // using `new string(len)` would work locally but is not memory safe.
        string memory str = new string(32);
        /// @solidity memory-safe-assembly
        assembly {
            mstore(str, len)
            mstore(add(str, 0x20), sstr)
        }
        return str;
    }

    /**
     * @dev Return the length of a `ShortString`.
     */
    function byteLength(ShortString sstr) internal pure returns (uint256) {
        uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
        if (result > 31) {
            revert InvalidShortString();
        }
        return result;
    }

    /**
     * @dev Encode a string into a `ShortString`, or write it to storage if it is too long.
     */
    function toShortStringWithFallback(
        string memory value,
        string storage store
    ) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        } else {
            StorageSlot.getStringSlot(store).value = value;
            return ShortString.wrap(_FALLBACK_SENTINEL);
        }
    }

    /**
     * @dev Decode a string that was encoded to `ShortString` or written to storage using {setWithFallback}.
     */
    function toStringWithFallback(
        ShortString value,
        string storage store
    ) internal pure returns (string memory) {
        if (ShortString.unwrap(value) != _FALLBACK_SENTINEL) {
            return toString(value);
        } else {
            return store;
        }
    }

    /**
     * @dev Return the length of a string that was encoded to `ShortString` or written to storage using {setWithFallback}.
     *
     * WARNING: This will return the "byte length" of the string. This may not reflect the actual length in terms of
     * actual characters as the UTF-8 encoding of a single character can span over multiple bytes.
     */
    function byteLengthWithFallback(
        ShortString value,
        string storage store
    ) internal view returns (uint256) {
        if (ShortString.unwrap(value) != _FALLBACK_SENTINEL) {
            return byteLength(value);
        } else {
            return bytes(store).length;
        }
    }
}


// File: contracts/dependencies/openzeppelin/utils/StorageSlot.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, `uint256`._
 * _Available since v4.9 for `string`, `bytes`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}


// File: contracts/dependencies/openzeppelin/utils/Strings.sol
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


// File: contracts/dependencies/openzeppelin/utils/structs/EnumerableSet.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}


// File: contracts/protocol/interfaces/IAddressResolver.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IAddressResolver {
    error UnmatchedInputs();

    event AddressImported(bytes32 name, address destination);

    function getAddress(bytes32 name, string calldata reason) external view returns (address);

    function getAddress(bytes32 name) external view returns (address);

    function getAddresses() external view returns (address[] memory);

    function getNames() external view returns (bytes32[] memory);
}


// File: contracts/protocol/interfaces/IBeaconProxyController.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IBeaconProxyController {
    error NoBeaconProxyContract();
    error InvalidProxyContract();

    event BeaconProxyUpdated(
        bytes32 indexed id,
        address indexed proxyAddress,
        address indexed newImplementationAddress,
        address oldImplementationAddress
    );

    function getBeaconProxyAddress(bytes32 beaconName) external view returns (address);

    function setFutureValueVaultImpl(address newImpl) external;

    function setLendingMarketImpl(address newImpl) external;

    function setZCTokenImpl(address newImpl) external;

    function deployFutureValueVault() external returns (address futureValueVault);

    function deployLendingMarket(
        bytes32 ccy,
        uint256 orderFeeRate,
        uint256 cbLimitRange
    ) external returns (address market);

    function deployZCToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address asset,
        uint256 maturity
    ) external returns (address futureValueToken);
}


// File: contracts/protocol/interfaces/ICurrencyController.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {PriceFeed} from "../storages/CurrencyControllerStorage.sol";

/**
 * @dev Currency Controller contract is responsible for managing supported
 * currencies in Secured Finance Protocol
 *
 * Contract links new currencies to ETH Chainlink price feeds, without existing price feed
 * contract owner is not able to add a new currency into the protocol
 */
interface ICurrencyController {
    error InvalidCurrency();
    error InvalidHaircut();
    error InvalidPriceFeed();
    error InvalidDecimals(address priceFeed, uint8 decimals);
    error InvalidPriceFeedInputs();
    error StalePriceFeed(
        address priceFeed,
        uint256 heartbeat,
        uint256 updatedAt,
        uint256 blockTimestamp
    );

    event CurrencyAdded(bytes32 indexed ccy, uint256 haircut);
    event CurrencyRemoved(bytes32 indexed ccy);

    event HaircutUpdated(bytes32 indexed ccy, uint256 haircut);

    event PriceFeedUpdated(bytes32 ccy, uint256 decimals, address[] indexed priceFeeds);

    function convert(
        bytes32 _fromCcy,
        bytes32 _toCcy,
        uint256 _amount
    ) external view returns (uint256 amount);

    function convert(
        bytes32 _fromCcy,
        bytes32 _toCcy,
        uint256[] calldata _amounts
    ) external view returns (uint256[] memory amounts);

    function convertToBaseCurrency(
        bytes32 _ccy,
        uint256 _amount
    ) external view returns (uint256 amount);

    function convertToBaseCurrency(
        bytes32 _ccy,
        int256 _amount
    ) external view returns (int256 amount);

    function convertToBaseCurrency(
        bytes32 _ccy,
        uint256[] calldata _amounts
    ) external view returns (uint256[] memory amounts);

    function convertFromBaseCurrency(
        bytes32 _ccy,
        uint256 _amountETH
    ) external view returns (uint256 amount);

    function convertFromBaseCurrency(
        bytes32 _ccy,
        uint256[] calldata _amounts
    ) external view returns (uint256[] memory amounts);

    function getDecimals(bytes32) external view returns (uint8);

    function getCurrencies() external view returns (bytes32[] memory);

    function getHaircut(bytes32 _ccy) external view returns (uint256);

    function getPriceFeed(bytes32 _ccy) external view returns (PriceFeed memory);

    function getLastPrice(bytes32 _ccy) external view returns (int256 price);

    function getAggregatedLastPrice(bytes32 _ccy) external view returns (int256);

    function currencyExists(bytes32 _ccy) external view returns (bool);

    function updatePriceFeed(
        bytes32 _ccy,
        uint8 _decimals,
        address[] calldata _priceFeeds,
        uint256[] calldata _heartbeats
    ) external;

    function addCurrency(
        bytes32 _ccy,
        uint8 _decimals,
        uint256 _haircut,
        address[] calldata _priceFeeds,
        uint256[] calldata _heartbeats
    ) external;

    function updateHaircut(bytes32 _ccy, uint256 _haircut) external;

    function removeCurrency(bytes32 _ccy) external;
}


// File: contracts/protocol/interfaces/IGenesisValueVault.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {AutoRollLog} from "../storages/GenesisValueVaultStorage.sol";

interface IGenesisValueVault {
    error NoCompoundFactorExists(uint256 maturity);
    error CompoundFactorIsZero();
    error ResidualAmountIsNotZero();
    error UnitPriceIsZero();
    error InvalidMaturity();
    error InvalidAmount();
    error InvalidOrderFeeRate();
    error CurrencyAlreadyInitialized();
    error InitialCompoundFactorAlreadyFinalized();
    error AutoRollLogAlreadyUpdated(uint256 currentMaturity, uint256 nextMaturity);
    error InsufficientBalance();
    error InsufficientLockedBalance();

    event Transfer(bytes32 indexed ccy, address indexed from, address indexed to, int256 value);
    event AutoRollExecuted(
        bytes32 indexed ccy,
        uint256 lendingCompoundFactor,
        uint256 borrowingCompoundFactor,
        uint256 unitPrice,
        uint256 currentMaturity,
        uint256 previousMaturity
    );
    event BalanceLocked(bytes32 indexed ccy, address indexed user, uint256 value);
    event BalanceUnlocked(bytes32 indexed ccy, address indexed user, uint256 value);

    function isAutoRolled(bytes32 _ccy, uint256 _maturity) external view returns (bool);

    function isInitialized(bytes32 ccy) external view returns (bool);

    function decimals(bytes32 ccy) external view returns (uint8);

    function getTotalLendingSupply(bytes32 ccy) external view returns (uint256);

    function getTotalBorrowingSupply(bytes32 ccy) external view returns (uint256);

    function getBalance(bytes32 ccy, address user) external view returns (int256);

    function getMaturityGenesisValue(bytes32 ccy, uint256 maturity) external view returns (int256);

    function getCurrentMaturity(bytes32 ccy) external view returns (uint256);

    function getLendingCompoundFactor(bytes32 ccy) external view returns (uint256);

    function getBorrowingCompoundFactor(bytes32 ccy) external view returns (uint256);

    function getAutoRollLog(
        bytes32 ccy,
        uint256 maturity
    ) external view returns (AutoRollLog memory);

    function getLatestAutoRollLog(bytes32 ccy) external view returns (AutoRollLog memory);

    function getTotalLockedBalance(bytes32 ccy) external view returns (uint256);

    function calculateFVFromFV(
        bytes32 ccy,
        uint256 basisMaturity,
        uint256 destinationMaturity,
        int256 futureValue
    ) external view returns (int256);

    function calculateGVFromFV(
        bytes32 ccy,
        uint256 basisMaturity,
        int256 futureValue
    ) external view returns (int256);

    function calculateFVFromGV(
        bytes32 ccy,
        uint256 basisMaturity,
        int256 genesisValue
    ) external view returns (int256);

    function getBalanceFluctuationByAutoRolls(
        bytes32 ccy,
        address user,
        uint256 maturity
    ) external view returns (int256 fluctuation);

    function calculateBalanceFluctuationByAutoRolls(
        bytes32 ccy,
        int256 balance,
        uint256 fromMaturity,
        uint256 toMaturity
    ) external view returns (int256 fluctuation);

    function initializeCurrencySetting(
        bytes32 ccy,
        uint8 decimals,
        uint256 compoundFactor,
        uint256 maturity
    ) external;

    function updateInitialCompoundFactor(bytes32 ccy, uint256 unitPrice) external;

    function updateDecimals(bytes32 _ccy, uint8 _decimals) external;

    function executeAutoRoll(
        bytes32 ccy,
        uint256 maturity,
        uint256 nextMaturity,
        uint256 unitPrice,
        uint256 orderFeeRate
    ) external;

    function updateGenesisValueWithFutureValue(
        bytes32 ccy,
        address user,
        uint256 basisMaturity,
        int256 fvAmount
    ) external;

    function updateGenesisValueWithResidualAmount(
        bytes32 ccy,
        address user,
        uint256 basisMaturity
    ) external;

    function lock(
        bytes32 ccy,
        address user,
        uint256 amount
    ) external returns (uint256 lockedAmount);

    function unlock(bytes32 ccy, address user, uint256 amount) external;

    function transferFrom(bytes32 ccy, address sender, address receiver, int256 amount) external;

    function cleanUpBalance(bytes32 ccy, address user, uint256 maturity) external;

    function executeForcedReset(bytes32 _ccy, address _user) external;

    function executeForcedReset(
        bytes32 _ccy,
        uint256 _maturity,
        address _user,
        int256 _amountInFV
    ) external returns (int256 removedAmount, int256 balance);
}


// File: contracts/protocol/interfaces/ILendingMarketController.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ProtocolTypes} from "../types/ProtocolTypes.sol";
import {ZCTokenInfo, TerminationCurrencyCache} from "../storages/LendingMarketControllerStorage.sol";

interface ILendingMarketController {
    error InvalidMaturity();
    error InvalidCurrency();
    error MarketTerminated();
    error NotTerminated();
    error AlreadyInitialized();

    struct AdditionalFunds {
        bytes32 ccy;
        uint256 workingLendOrdersAmount;
        uint256 claimableAmount;
        uint256 workingBorrowOrdersAmount;
        uint256 debtAmount;
        uint256 lentAmount;
        uint256 borrowedAmount;
    }

    struct CalculatedTotalFunds {
        uint256 plusDepositAmountInAdditionalFundsCcy;
        uint256 minusDepositAmountInAdditionalFundsCcy;
        uint256 workingLendOrdersAmount;
        uint256 claimableAmount;
        uint256 collateralAmount;
        uint256 lentAmount;
        uint256 workingBorrowOrdersAmount;
        uint256 debtAmount;
        uint256 borrowedAmount;
    }

    struct CalculatedFunds {
        uint256 workingLendOrdersAmount;
        uint256 claimableAmount;
        uint256 collateralAmount;
        uint256 unallocatedCollateralAmount;
        uint256 lentAmount;
        uint256 workingBorrowOrdersAmount;
        uint256 debtAmount;
        uint256 borrowedAmount;
    }

    struct GetOrderEstimationParams {
        bytes32 ccy;
        uint256 maturity;
        address user;
        ProtocolTypes.Side side;
        uint256 amount;
        uint256 unitPrice;
        uint256 additionalDepositAmount;
        bool ignoreBorrowedAmount;
    }

    function isValidMaturity(bytes32 _ccy, uint256 _maturity) external view returns (bool);

    function isTerminated() external view returns (bool);

    function isRedemptionRequired(address _user) external view returns (bool);

    function getMarketBasePeriod() external view returns (uint256);

    function getTerminationDate() external view returns (uint256);

    function getTerminationCurrencyCache(
        bytes32 _ccy
    ) external view returns (TerminationCurrencyCache memory);

    function getTerminationCollateralRatio(bytes32 _ccy) external view returns (uint256);

    function getMinDebtUnitPrice(bytes32 _ccy) external view returns (uint256);

    function getCurrentMinDebtUnitPrice(
        bytes32 _ccy,
        uint256 _maturity
    ) external view returns (uint256);

    function getGenesisDate(bytes32 ccy) external view returns (uint256);

    function getLendingMarket(bytes32 ccy) external view returns (address);

    function getFutureValueVault(bytes32 ccy) external view returns (address);

    function getOrderBookId(bytes32 _ccy, uint256 _maturity) external view returns (uint8);

    function getPendingOrderAmount(bytes32 _ccy, uint256 _maturity) external view returns (uint256);

    function getOrderEstimation(
        GetOrderEstimationParams calldata params
    )
        external
        view
        returns (
            uint256 lastUnitPrice,
            uint256 filledAmount,
            uint256 filledAmountInFV,
            uint256 orderFeeInFV,
            uint256 placedAmount,
            uint256 coverage,
            bool isInsufficientDepositAmount
        );

    function getMaturities(bytes32 ccy) external view returns (uint256[] memory);

    function getOrderBookIds(bytes32 ccy) external view returns (uint8[] memory);

    function getUsedCurrencies(address user) external view returns (bytes32[] memory);

    function getTotalPresentValue(bytes32 ccy, address user) external view returns (int256);

    function getTotalPresentValueInBaseCurrency(
        address user
    ) external view returns (int256 totalPresentValue);

    function getGenesisValue(
        bytes32 ccy,
        address user
    ) external view returns (int256 amount, int256 amountInPV, int256 amountInFV);

    function getPosition(
        bytes32 _ccy,
        uint256 _maturity,
        address _user
    ) external view returns (int256 presentValue, int256 futureValue);

    function getZCToken(bytes32 ccy, uint256 maturity) external view returns (address);

    function getZCTokenInfo(address zcToken) external view returns (ZCTokenInfo memory);

    function getWithdrawableZCTokenAmount(
        bytes32 ccy,
        uint256 maturity,
        address user
    ) external view returns (uint256 amount);

    function calculateFunds(
        bytes32 ccy,
        address user,
        uint256 liquidationThresholdRate
    ) external view returns (CalculatedFunds memory funds);

    function calculateTotalFundsInBaseCurrency(
        address user,
        AdditionalFunds calldata _additionalFunds,
        uint256 liquidationThresholdRate
    ) external view returns (CalculatedTotalFunds memory calculatedFunds);

    function isInitializedLendingMarket(bytes32 ccy) external view returns (bool);

    function initializeLendingMarket(
        bytes32 ccy,
        uint256 genesisDate,
        uint256 compoundFactor,
        uint256 orderFeeRate,
        uint256 circuitBreakerLimitRange,
        uint256 minDebtUnitPrice
    ) external;

    function createOrderBook(bytes32 ccy, uint256 openingDate, uint256 preOpeningDate) external;

    function executeOrder(
        bytes32 ccy,
        uint256 maturity,
        ProtocolTypes.Side side,
        uint256 amount,
        uint256 unitPrice
    ) external returns (bool);

    function depositAndExecuteOrder(
        bytes32 ccy,
        uint256 maturity,
        ProtocolTypes.Side side,
        uint256 amount,
        uint256 unitPrice
    ) external payable returns (bool);

    function depositWithPermitAndExecuteOrder(
        bytes32 ccy,
        uint256 maturity,
        ProtocolTypes.Side side,
        uint256 amount,
        uint256 unitPrice,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external returns (bool);

    function executePreOrder(
        bytes32 ccy,
        uint256 maturity,
        ProtocolTypes.Side side,
        uint256 amount,
        uint256 unitPrice
    ) external returns (bool);

    function depositAndExecutesPreOrder(
        bytes32 ccy,
        uint256 maturity,
        ProtocolTypes.Side side,
        uint256 amount,
        uint256 unitPrice
    ) external payable returns (bool);

    function depositWithPermitAndExecutePreOrder(
        bytes32 _ccy,
        uint256 _maturity,
        ProtocolTypes.Side _side,
        uint256 _amount,
        uint256 _unitPrice,
        uint256 _deadline,
        uint8 _permitV,
        bytes32 _permitR,
        bytes32 _permitS
    ) external returns (bool);

    function unwindPosition(bytes32 ccy, uint256 maturity) external returns (bool);

    function executeItayoseCall(bytes32 ccy, uint256 maturity) external returns (bool);

    function executeRedemption(bytes32 _ccy, uint256 _maturity) external returns (bool);

    function executeRepayment(bytes32 _ccy, uint256 _maturity) external returns (bool);

    function executeEmergencySettlement() external returns (bool);

    function executeLiquidationCall(
        bytes32 collateralCcy,
        bytes32 debtCcy,
        uint256 debtMaturity,
        address user
    ) external returns (bool);

    function executeForcedRepayment(
        bytes32 _collateralCcy,
        bytes32 _debtCcy,
        uint256 _debtMaturity,
        address _user
    ) external returns (bool);

    function cancelOrder(bytes32 ccy, uint256 maturity, uint48 orderId) external returns (bool);

    function rotateOrderBooks(bytes32 ccy) external;

    function executeEmergencyTermination() external;

    function pauseLendingMarket(bytes32 ccy) external returns (bool);

    function unpauseLendingMarket(bytes32 ccy) external returns (bool);

    function cleanUpAllFunds(address user) external returns (bool);

    function cleanUpFunds(bytes32 ccy, address user) external returns (uint256 activeOrderCount);

    function updateMinDebtUnitPrice(bytes32 _ccy, uint256 _minDebtUnitPrice) external;

    function withdrawZCToken(bytes32 _ccy, uint256 _maturity, uint256 _amount) external;

    function depositZCToken(bytes32 _ccy, uint256 _maturity, uint256 _amount) external;
}


// File: contracts/protocol/interfaces/IReserveFund.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IReserveFund {
    event Pause(address account);
    event Unpause(address account);

    function isPaused() external view returns (bool);

    function pause() external;

    function unpause() external;

    function deposit(bytes32 ccy, uint256 amount) external payable;

    function withdraw(bytes32 ccy, uint256 amount) external;
}


// File: contracts/protocol/interfaces/ITokenVault.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ProtocolTypes} from "../types/ProtocolTypes.sol";
import {ILendingMarketController} from "../interfaces/ILendingMarketController.sol";

interface ITokenVault {
    error UnregisteredCurrency();
    error InvalidCurrency();
    error InvalidToken();
    error InvalidAmount(bytes32 ccy, uint256 amount, uint256 msgValue);
    error AmountIsZero();
    error CallerNotBaseCurrency(address caller);
    error MarketTerminated();
    error RedemptionIsRequired();

    event Deposit(address indexed user, bytes32 ccy, uint256 amount, address caller);
    event Withdraw(address indexed user, bytes32 ccy, uint256 amount);
    event Transfer(bytes32 indexed ccy, address indexed from, address indexed to, uint256 amount);
    event CurrencyRegistered(bytes32 ccy, address tokenAddress, bool isCollateral);
    event CurrencyUpdated(bytes32 ccy, bool isCollateral);

    function isCovered(
        address user,
        bytes32 ccy
    ) external view returns (bool isEnoughCollateral, bool isEnoughDepositInOrderCcy);

    function isCollateral(bytes32 ccy) external view returns (bool);

    function isCollateral(bytes32[] calldata ccys) external view returns (bool[] memory);

    function isRegisteredCurrency(bytes32 ccy) external view returns (bool);

    function getTokenAddress(bytes32 ccy) external view returns (address);

    function getCollateralCurrencies() external view returns (bytes32[] memory);

    function getWithdrawableCollateral(address user) external view returns (uint256);

    function getWithdrawableCollateral(bytes32 ccy, address user) external view returns (uint256);

    function getCoverage(address user) external view returns (uint256);

    function getTotalUnusedCollateralAmount(address user) external view returns (uint256);

    function getTotalCollateralAmount(address user) external view returns (uint256);

    function getCollateralDetail(
        address user
    )
        external
        view
        returns (uint256 totalCollateral, uint256 totalUsedCollateral, uint256 totalDeposit);

    function getCollateralAmount(address user, bytes32 ccy) external view returns (uint256);

    function getBorrowableAmount(address user, bytes32 ccy) external view returns (uint256);

    function getLiquidationAmount(
        address user,
        bytes32 liquidationCcy,
        uint256 liquidationAmountMaximum
    ) external view returns (uint256 liquidationAmount, uint256 protocolFee, uint256 liquidatorFee);

    function getTotalDepositAmount(bytes32 ccy) external view returns (uint256);

    function getDepositAmount(address user, bytes32 ccy) external view returns (uint256);

    function getUsedCurrencies(address user) external view returns (bytes32[] memory);

    function calculateCoverage(
        address user,
        ILendingMarketController.AdditionalFunds memory funds
    ) external view returns (uint256 coverage, bool isInsufficientDepositAmount);

    function calculateLiquidationFees(
        uint256 liquidationAmount
    ) external view returns (uint256 protocolFee, uint256 liquidatorFee);

    function registerCurrency(bytes32 ccy, address tokenAddress, bool isCollateral) external;

    function updateCurrency(bytes32 ccy, bool isCollateral) external;

    function deposit(bytes32 ccy, uint256 amount) external payable;

    function depositTo(bytes32 ccy, uint256 amount, address onBehalfOf) external payable;

    function depositFrom(address user, bytes32 ccy, uint256 amount) external payable;

    function depositWithPermitTo(
        bytes32 ccy,
        uint256 amount,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external;

    function depositWithPermitFrom(
        address user,
        bytes32 ccy,
        uint256 amount,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external;

    function withdraw(bytes32 ccy, uint256 amount) external;

    function addDepositAmount(address user, bytes32 ccy, uint256 amount) external;

    function removeDepositAmount(address user, bytes32 ccy, uint256 amount) external;

    function cleanUpUsedCurrencies(address user, bytes32 ccy) external;

    function executeForcedReset(address user, bytes32 ccy) external returns (uint256 removedAmount);

    function transferFrom(
        bytes32 ccy,
        address sender,
        address receiver,
        uint256 amount
    ) external returns (uint256 untransferredAmount);

    function pause() external;

    function unpause() external;

    function getLiquidationThresholdRate() external view returns (uint256 rate);
}


// File: contracts/protocol/interfaces/IZCToken.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from "../../dependencies/openzeppelin/token/ERC20/IERC20.sol";

interface IZCToken is IERC20 {
    function asset() external view returns (address);

    function maturity() external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}


// File: contracts/protocol/libraries/AddressResolverLib.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Contracts} from "../libraries/Contracts.sol";
import {IBeaconProxyController} from "../interfaces/IBeaconProxyController.sol";
import {ICurrencyController} from "../interfaces/ICurrencyController.sol";
import {IGenesisValueVault} from "../interfaces/IGenesisValueVault.sol";
import {ILendingMarketController} from "../interfaces/ILendingMarketController.sol";
import {IReserveFund} from "../interfaces/IReserveFund.sol";
import {ITokenVault} from "../interfaces/ITokenVault.sol";
import {MixinAddressResolverStorage as Storage} from "../storages/mixins/MixinAddressResolverStorage.sol";

library AddressResolverLib {
    error MissingAddress(string name);

    function getAddress(bytes32 name) internal view returns (address) {
        address _foundAddress = Storage.slot().addressCache[name];
        if (_foundAddress == address(0)) revert MissingAddress(string(abi.encodePacked(name)));
        return _foundAddress;
    }

    function beaconProxyController() internal view returns (IBeaconProxyController) {
        return IBeaconProxyController(getAddress(Contracts.BEACON_PROXY_CONTROLLER));
    }

    function currencyController() internal view returns (ICurrencyController) {
        return ICurrencyController(getAddress(Contracts.CURRENCY_CONTROLLER));
    }

    function genesisValueVault() internal view returns (IGenesisValueVault) {
        return IGenesisValueVault(getAddress(Contracts.GENESIS_VALUE_VAULT));
    }

    function lendingMarketController() internal view returns (ILendingMarketController) {
        return ILendingMarketController(getAddress(Contracts.LENDING_MARKET_CONTROLLER));
    }

    function reserveFund() internal view returns (IReserveFund) {
        return IReserveFund(getAddress(Contracts.RESERVE_FUND));
    }

    function tokenVault() internal view returns (ITokenVault) {
        return ITokenVault(getAddress(Contracts.TOKEN_VAULT));
    }
}


// File: contracts/protocol/libraries/Contracts.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

library Contracts {
    bytes32 internal constant BEACON_PROXY_CONTROLLER = "BeaconProxyController";
    bytes32 internal constant CURRENCY_CONTROLLER = "CurrencyController";
    bytes32 internal constant GENESIS_VALUE_VAULT = "GenesisValueVault";
    bytes32 internal constant LENDING_MARKET_CONTROLLER = "LendingMarketController";
    bytes32 internal constant RESERVE_FUND = "ReserveFund";
    bytes32 internal constant TOKEN_VAULT = "TokenVault";
}

library BeaconContracts {
    bytes32 internal constant FUTURE_VALUE_VAULT = "FutureValueVault";
    bytes32 internal constant LENDING_MARKET = "LendingMarket";
    bytes32 internal constant ZC_TOKEN = "ZCToken";
}


// File: contracts/protocol/mixins/MixinAddressResolver.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {AddressResolverLib} from "../libraries/AddressResolverLib.sol";
import {IAddressResolver} from "../interfaces/IAddressResolver.sol";
import {IBeaconProxyController} from "../interfaces/IBeaconProxyController.sol";
import {ICurrencyController} from "../interfaces/ICurrencyController.sol";
import {IGenesisValueVault} from "../interfaces/IGenesisValueVault.sol";
import {ILendingMarketController} from "../interfaces/ILendingMarketController.sol";
import {IReserveFund} from "../interfaces/IReserveFund.sol";
import {ITokenVault} from "../interfaces/ITokenVault.sol";
import {MixinAddressResolverStorage as Storage} from "../storages/mixins/MixinAddressResolverStorage.sol";

contract MixinAddressResolver {
    event CacheUpdated(bytes32 name, address destination);

    error OnlyAcceptedContract(string name);
    error ResolverAlreadyRegistered();

    modifier onlyLendingMarketController() {
        if (msg.sender != address(AddressResolverLib.lendingMarketController()))
            revert OnlyAcceptedContract("LendingMarketController");
        _;
    }

    /**
     * @notice Returns the contract names used in this contract.
     * @dev The contract name list is in `./libraries/Contracts.sol`.
     */
    function requiredContracts() public pure virtual returns (bytes32[] memory contracts) {}

    function buildCache() public {
        // The resolver must call this function whenever it updates its state
        bytes32[] memory contractNames = requiredContracts();
        for (uint256 i; i < contractNames.length; i++) {
            bytes32 name = contractNames[i];
            // Note: can only be invoked once the resolver has all the targets needed added
            address destination = Storage.slot().resolver.getAddress(
                name,
                string(abi.encodePacked("Resolver missing target: ", name))
            );
            Storage.slot().addressCache[name] = destination;
            emit CacheUpdated(name, destination);
        }
    }

    function isResolverCached() external view returns (bool) {
        bytes32[] memory contractNames = requiredContracts();
        for (uint256 i; i < contractNames.length; i++) {
            bytes32 name = contractNames[i];
            // false if our cache is invalid or if the resolver doesn't have the required address
            if (
                Storage.slot().resolver.getAddress(name) != Storage.slot().addressCache[name] ||
                Storage.slot().addressCache[name] == address(0)
            ) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Register the Address Resolver contract
     * @param _resolver The address of the Address Resolver contract
     */
    function registerAddressResolver(address _resolver) internal {
        if (address(Storage.slot().resolver) != address(0)) revert ResolverAlreadyRegistered();
        Storage.slot().resolver = IAddressResolver(_resolver);
    }

    function getAddress(bytes32 name) internal view returns (address) {
        return AddressResolverLib.getAddress(name);
    }

    function resolver() public view returns (IAddressResolver) {
        return Storage.slot().resolver;
    }

    function beaconProxyController() internal view returns (IBeaconProxyController) {
        return AddressResolverLib.beaconProxyController();
    }

    function currencyController() internal view returns (ICurrencyController) {
        return AddressResolverLib.currencyController();
    }

    function genesisValueVault() internal view returns (IGenesisValueVault) {
        return AddressResolverLib.genesisValueVault();
    }

    function reserveFund() internal view returns (IReserveFund) {
        return AddressResolverLib.reserveFund();
    }

    function lendingMarketController() internal view returns (ILendingMarketController) {
        return AddressResolverLib.lendingMarketController();
    }

    function tokenVault() internal view returns (ITokenVault) {
        return AddressResolverLib.tokenVault();
    }
}


// File: contracts/protocol/storages/CurrencyControllerStorage.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "../../dependencies/chainlink/AggregatorV3Interface.sol";
import "../../dependencies/openzeppelin/utils/structs/EnumerableSet.sol";

struct PriceFeed {
    AggregatorV3Interface[] instances;
    uint256[] heartbeats;
}

library CurrencyControllerStorage {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256("sf.storage.currencyController")) - 1);

    struct Storage {
        // Protocol currencies
        EnumerableSet.Bytes32Set currencies;
        mapping(bytes32 ccy => uint256 haircut) haircuts;
        // Total cached decimals of the price feeds
        mapping(bytes32 ccy => uint8 decimals) decimalsCaches;
        mapping(bytes32 ccy => PriceFeed priceFeed) priceFeeds;
    }

    function slot() internal pure returns (Storage storage r) {
        bytes32 _slot = STORAGE_SLOT;
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := _slot
        }
    }
}


// File: contracts/protocol/storages/GenesisValueVaultStorage.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

struct MaturityUnitPrice {
    uint256 unitPrice;
    uint256 compoundFactor;
    uint256 next;
    uint256 prev;
}

struct AutoRollLog {
    uint256 unitPrice;
    uint256 lendingCompoundFactor;
    uint256 borrowingCompoundFactor;
    uint256 next;
    uint256 prev;
}

library GenesisValueVaultStorage {
    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256("sf.storage.genesisValueVault")) - 1);

    struct Storage {
        mapping(bytes32 ccy => bool isInitialized) isInitialized;
        mapping(bytes32 ccy => uint256 compoundFactor) initialCompoundFactors;
        mapping(bytes32 ccy => uint256 compoundFactor) lendingCompoundFactors;
        mapping(bytes32 ccy => uint256 compoundFactor) borrowingCompoundFactors;
        mapping(bytes32 ccy => uint256 maturity) currentMaturity;
        mapping(bytes32 ccy => uint8 decimals) decimals;
        mapping(bytes32 ccy => mapping(address user => int256 balance)) balances;
        mapping(bytes32 ccy => uint256 amount) totalLendingSupplies;
        mapping(bytes32 ccy => uint256 amount) totalBorrowingSupplies;
        // Total amount supplied per maturity
        mapping(bytes32 ccy => mapping(uint256 maturity => int256 balance)) maturityBalances;
        mapping(bytes32 ccy => mapping(uint256 maturity => AutoRollLog log)) autoRollLogs;
        // Maturity when the user receives the balance on the target currency
        mapping(bytes32 ccy => mapping(address user => uint256 maturity)) userMaturities;
        mapping(bytes32 ccy => uint256 balance) totalLockedBalances;
    }

    function slot() internal pure returns (Storage storage r) {
        bytes32 _slot = STORAGE_SLOT;
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := _slot
        }
    }
}


// File: contracts/protocol/storages/LendingMarketControllerStorage.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "../../dependencies/openzeppelin/utils/structs/EnumerableSet.sol";

struct ObservationPeriodLog {
    uint256 totalAmount;
    uint256 totalFutureValue;
}

struct TerminationCurrencyCache {
    int256 price;
    uint8 decimals;
}

struct ZCTokenInfo {
    bytes32 ccy;
    uint256 maturity;
}

library LendingMarketControllerStorage {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256("sf.storage.lendingMarketController")) - 1);

    struct Storage {
        uint256 marketBasePeriod;
        uint256 terminationDate;
        mapping(bytes32 ccy => TerminationCurrencyCache currency) terminationCurrencyCaches;
        mapping(bytes32 ccy => uint256 ratio) terminationCollateralRatios;
        mapping(bytes32 ccy => uint8[] orderBookIds) orderBookIdLists;
        mapping(bytes32 ccy => address lendingMarket) lendingMarkets;
        mapping(bytes32 ccy => address futureValueVault) futureValueVaults;
        mapping(bytes32 ccy => uint256 unitPrice) minDebtUnitPrices;
        mapping(bytes32 ccy => uint256 genesisDate) genesisDates;
        mapping(bytes32 ccy => mapping(uint256 maturity => uint256 amount)) pendingOrderAmounts;
        // Order book id history to get order book id from maturity
        mapping(bytes32 ccy => mapping(uint256 maturity => uint8 orderBookIds)) maturityOrderBookIds;
        // List of maturity that the user has open orders or positions
        mapping(bytes32 ccy => mapping(address user => EnumerableSet.UintSet maturities)) usedMaturities;
        // Observation period logs that is used for auto-rolls
        mapping(bytes32 ccy => mapping(uint256 maturity => ObservationPeriodLog log)) observationPeriodLogs;
        // List of currency that the user has open orders or positions
        mapping(address user => EnumerableSet.Bytes32Set currency) usedCurrencies;
        mapping(address user => bool isRedeemed) isRedeemed;
        mapping(bytes32 ccy => mapping(uint256 maturity => address token)) zcTokens;
        mapping(address token => ZCTokenInfo) zcTokenInfo;
    }

    function slot() internal pure returns (Storage storage r) {
        bytes32 _slot = STORAGE_SLOT;
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := _slot
        }
    }
}


// File: contracts/protocol/storages/mixins/MixinAddressResolverStorage.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IAddressResolver} from "../../interfaces/IAddressResolver.sol";

library MixinAddressResolverStorage {
    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256("sf.storage.mixinAddressResolver")) - 1);

    struct Storage {
        IAddressResolver resolver;
        mapping(bytes32 contractName => address contractAddress) addressCache;
    }

    function slot() internal pure returns (Storage storage r) {
        bytes32 _slot = STORAGE_SLOT;
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := _slot
        }
    }
}


// File: contracts/protocol/storages/utils/EIP712UpgradeableStorage.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "../../../dependencies/openzeppelin/utils//ShortStrings.sol";

library EIP712UpgradeableStorage {
    using ShortStrings for *;

    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256("sf.storage.eip712UpgradeableStorage")) - 1);

    struct Storage {
        bytes32 cachedDomainSeparator;
        uint256 cachedChainId;
        address cachedThis;
        bytes32 hashedName;
        bytes32 hashedVersion;
        ShortString name;
        ShortString version;
        string nameFallback;
        string versionFallback;
    }

    function slot() internal pure returns (Storage storage r) {
        bytes32 _slot = STORAGE_SLOT;
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := _slot
        }
    }
}


// File: contracts/protocol/storages/utils/ERC20PermitUpgradeableStorage.sol
import "../../../dependencies/openzeppelin/utils/Counters.sol";

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

library ERC20PermitUpgradeableStorage {
    using Counters for Counters.Counter;

    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256("sf.storage.erc20PermitUpgradeable")) - 1);

    struct Storage {
        mapping(address => Counters.Counter) nonces;
    }

    function slot() internal pure returns (Storage storage r) {
        bytes32 _slot = STORAGE_SLOT;
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := _slot
        }
    }
}


// File: contracts/protocol/storages/utils/ERC20UpgradeableStorage.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

library ERC20UpgradeableStorage {
    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256("sf.storage.erc20Upgradeable")) - 1);

    struct Storage {
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
        string name;
        string symbol;
    }

    function slot() internal pure returns (Storage storage r) {
        bytes32 _slot = STORAGE_SLOT;
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := _slot
        }
    }
}


// File: contracts/protocol/storages/ZCTokenStorage.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

library ZCTokenStorage {
    bytes32 internal constant STORAGE_SLOT = bytes32(uint256(keccak256("sf.storage.zcToken")) - 1);

    struct Storage {
        uint8 decimals;
        address asset;
        uint256 maturity;
    }

    function slot() internal pure returns (Storage storage r) {
        bytes32 _slot = STORAGE_SLOT;
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := _slot
        }
    }
}


// File: contracts/protocol/types/ProtocolTypes.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

/**
 * @dev ProtocolTypes is a base-level contract that holds common Secured Finance protocol types
 * @author Secured Finance
 */
library ProtocolTypes {
    enum Side {
        LEND,
        BORROW
    }
}


// File: contracts/protocol/utils/EIP712Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/EIP712.sol)

pragma solidity ^0.8.8;

import "../../dependencies/openzeppelin/utils/cryptography/ECDSA.sol";
import "../../dependencies/openzeppelin/utils//ShortStrings.sol";
import "../../dependencies/openzeppelin/interfaces/IERC5267.sol";

import {EIP712UpgradeableStorage as Storage} from "../storages/utils/EIP712UpgradeableStorage.sol";

/**
 * @notice This contract is from OpenZeppelin Contracts that implements the EIP 712 standard
 * for hashing and signing of typed structured data.
 */
abstract contract EIP712Upgradeable is IERC5267 {
    using ShortStrings for *;

    bytes32 private constant _TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    function __EIP712_initialize(string memory name, string memory version) internal {
        Storage.slot().name = name.toShortStringWithFallback(Storage.slot().nameFallback);
        Storage.slot().version = version.toShortStringWithFallback(Storage.slot().versionFallback);
        Storage.slot().hashedName = keccak256(bytes(name));
        Storage.slot().hashedVersion = keccak256(bytes(version));

        Storage.slot().cachedChainId = block.chainid;
        Storage.slot().cachedDomainSeparator = _buildDomainSeparator();
        Storage.slot().cachedThis = address(this);
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (
            address(this) == Storage.slot().cachedThis &&
            block.chainid == Storage.slot().cachedChainId
        ) {
            return Storage.slot().cachedDomainSeparator;
        } else {
            return _buildDomainSeparator();
        }
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _TYPE_HASH,
                    Storage.slot().hashedName,
                    Storage.slot().hashedVersion,
                    block.chainid,
                    address(this)
                )
            );
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
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
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev See {EIP-5267}.
     *
     * _Available since v4.9._
     */
    function eip712Domain()
        public
        view
        virtual
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            hex"0f", // 01111
            Storage.slot().name.toStringWithFallback(Storage.slot().nameFallback),
            Storage.slot().version.toStringWithFallback(Storage.slot().versionFallback),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }
}


// File: contracts/protocol/utils/ERC20PermitUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/ERC20Permit.sol)

pragma solidity ^0.8.0;

import "../../dependencies/openzeppelin/token/ERC20/extensions/IERC20Permit.sol";
import "../../dependencies/openzeppelin/utils/cryptography/ECDSA.sol";
import "../../dependencies/openzeppelin/utils/cryptography/EIP712.sol";
import "../../dependencies/openzeppelin/utils/Counters.sol";

import {EIP712Upgradeable} from "./EIP712Upgradeable.sol";
import {ERC20Upgradeable} from "./ERC20Upgradeable.sol";
import {ERC20PermitUpgradeableStorage as Storage} from "../storages/utils/ERC20PermitUpgradeableStorage.sol";

/**
 * @notice This contract is from OpenZeppelin Contracts that implements the ERC20 Permit extension allowing approvals
 * to be made via signatures, as defined in EIP-2612.
 */
abstract contract ERC20PermitUpgradeable is ERC20Upgradeable, IERC20Permit, EIP712Upgradeable {
    using Counters for Counters.Counter;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    /**
     * @dev In previous versions `_PERMIT_TYPEHASH` was declared as `immutable`.
     * However, to ensure consistency with the upgradeable transpiler, we will continue
     * to reserve a slot.
     * @custom:oz-renamed-from _PERMIT_TYPEHASH
     */
    // solhint-disable-next-line var-name-mixedcase
    bytes32 private _PERMIT_TYPEHASH_DEPRECATED_SLOT;

    /**
     * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
     *
     * It's a good idea to use the same `name` that is defined as the ERC20 token name.
     */
    function __ERC20Permit_initialize(string memory name) internal {
        EIP712Upgradeable.__EIP712_initialize(name, "1");
    }

    /**
     * @dev See {IERC20Permit-permit}.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline)
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "ERC20Permit: invalid signature");

        _approve(owner, spender, value);
    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view virtual override returns (uint256) {
        return Storage.slot().nonces[owner].current();
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     *
     * _Available since v4.1._
     */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        Counters.Counter storage nonce = Storage.slot().nonces[owner];
        current = nonce.current();
        nonce.increment();
    }
}


// File: contracts/protocol/utils/ERC20Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "../../dependencies/openzeppelin/token/ERC20/IERC20.sol";
import "../../dependencies/openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "../../dependencies/openzeppelin/utils/Context.sol";

import {ERC20UpgradeableStorage as Storage} from "../storages/utils/ERC20UpgradeableStorage.sol";

/**
 * @notice This contract is from OpenZeppelin Contracts that implements the ERC20 token standard.
 */
contract ERC20Upgradeable is Context, IERC20, IERC20Metadata {
    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_initialize(string memory name_, string memory symbol_) internal {
        Storage.slot().name = name_;
        Storage.slot().symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return Storage.slot().name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return Storage.slot().symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
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
        return Storage.slot().totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return Storage.slot().balances[account];
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
    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return Storage.slot().allowances[owner][spender];
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
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
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
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = Storage.slot().balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            Storage.slot().balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            Storage.slot().balances[to] += amount;
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

        Storage.slot().totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            Storage.slot().balances[account] += amount;
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

        uint256 accountBalance = Storage.slot().balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            Storage.slot().balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            Storage.slot().totalSupply -= amount;
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
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        Storage.slot().allowances[owner][spender] = amount;
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
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
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
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

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
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}


// File: contracts/protocol/utils/Proxyable.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "../../dependencies/openzeppelin/utils/StorageSlot.sol";
import "../../dependencies/openzeppelin/proxy/utils/Initializable.sol";

abstract contract Proxyable is Initializable {
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant _BEACON_SLOT =
        0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    modifier onlyProxy() {
        require(_getImplementation() != address(0), "Must be called from proxy contract");
        _;
    }

    modifier onlyBeacon() {
        require(_getBeacon() != address(0), "Must be called from beacon contract");
        _;
    }

    /**
     * @notice Gets the revision number of the contract
     * @return The revision number
     */
    function getRevision() external pure virtual returns (uint256) {
        return 0x1;
    }

    function _getImplementation() private view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }
}


// File: contracts/protocol/ZCToken.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

// interfaces
import {IZCToken} from "./interfaces/IZCToken.sol";
// libraries
import {Contracts} from "./libraries/Contracts.sol";
// mixins
import {MixinAddressResolver} from "./mixins/MixinAddressResolver.sol";
// utils
import {Proxyable} from "./utils/Proxyable.sol";
import {ERC20PermitUpgradeable} from "./utils/ERC20PermitUpgradeable.sol";
// storage
import {ZCTokenStorage as Storage} from "./storages/ZCTokenStorage.sol";

/**
 * @notice Implements a token that represents zero-coupon bonds.
 */
contract ZCToken is IZCToken, MixinAddressResolver, ERC20PermitUpgradeable, Proxyable {
    /**
     * @notice Initializes the contract.
     * @param _resolver The address resolver to be used.
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _decimals The number of decimals the token uses
     * @param _asset The address of the token's underlying asset
     * @param _maturity The maturity of the token
     */
    function initialize(
        address _resolver,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _asset,
        uint256 _maturity
    ) external initializer onlyBeacon {
        Storage.slot().asset = _asset;
        Storage.slot().maturity = _maturity;
        Storage.slot().decimals = _decimals;

        registerAddressResolver(_resolver);
        __ERC20_initialize(_name, _symbol);
        __ERC20Permit_initialize(_name);

        buildCache();
    }

    // @inheritdoc MixinAddressResolver
    function requiredContracts() public pure override returns (bytes32[] memory contracts) {
        contracts = new bytes32[](1);
        contracts[0] = Contracts.LENDING_MARKET_CONTROLLER;
    }

    // @inheritdoc ERC20Upgradeable
    function decimals() public view virtual override returns (uint8) {
        return Storage.slot().decimals;
    }

    /**
     * @notice Gets the address of the token's underlying asset
     * @return The address of the token's underlying asset
     */
    function asset() external view override returns (address) {
        return Storage.slot().asset;
    }

    /**
     * @notice Gets the maturity of the token
     * @return The maturity of the token
     */
    function maturity() external view override returns (uint256) {
        return Storage.slot().maturity;
    }

    /**
     * @notice Mints new tokens
     * @param to The address to receive the new tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyLendingMarketController {
        _mint(to, amount);
    }

    /**
     * @notice Burns tokens
     * @param from The address to burn the tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyLendingMarketController {
        _burn(from, amount);
    }
}


