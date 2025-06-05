// Chain: POLYGON - File: @openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

pragma solidity ^0.8.20;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {ERC165Upgradeable} from "../utils/introspection/ERC165Upgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControl, ERC165Upgradeable {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;


    /// @custom:storage-location erc7201:openzeppelin.storage.AccessControl
    struct AccessControlStorage {
        mapping(bytes32 role => RoleData) _roles;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.AccessControl")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AccessControlStorageLocation = 0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800;

    function _getAccessControlStorage() private pure returns (AccessControlStorage storage $) {
        assembly {
            $.slot := AccessControlStorageLocation
        }
    }

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        AccessControlStorage storage $ = _getAccessControlStorage();
        bytes32 previousAdminRole = getRoleAdmin(role);
        $._roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (!hasRole(role, account)) {
            $._roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (hasRole(role, account)) {
            $._roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
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
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
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
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.20;

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
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
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
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
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
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.20;

import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Initializable} from "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC1967-compliant implementation pointing to self.
     * See {_onlyProxy}.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.20;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {ContextUpgradeable} from "../../utils/ContextUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165Upgradeable} from "../../utils/introspection/ERC165Upgradeable.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 */
abstract contract ERC1155Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC1155, IERC1155MetadataURI, IERC1155Errors {
    using Arrays for uint256[];
    using Arrays for address[];

    /// @custom:storage-location erc7201:openzeppelin.storage.ERC1155
    struct ERC1155Storage {
        mapping(uint256 id => mapping(address account => uint256)) _balances;

        mapping(address account => mapping(address operator => bool)) _operatorApprovals;

        // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
        string _uri;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC1155")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC1155StorageLocation = 0x88be536d5240c274a3b1d3a1be54482fd9caa294f08c62a7cde569f49a3c4500;

    function _getERC1155Storage() private pure returns (ERC1155Storage storage $) {
        assembly {
            $.slot := ERC1155StorageLocation
        }
    }

    /**
     * @dev See {_setURI}.
     */
    function __ERC1155_init(string memory uri_) internal onlyInitializing {
        __ERC1155_init_unchained(uri_);
    }

    function __ERC1155_init_unchained(string memory uri_) internal onlyInitializing {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256 /* id */) public view virtual returns (string memory) {
        ERC1155Storage storage $ = _getERC1155Storage();
        return $._uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     */
    function balanceOf(address account, uint256 id) public view virtual returns (uint256) {
        ERC1155Storage storage $ = _getERC1155Storage();
        return $._balances[id][account];
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
    ) public view virtual returns (uint256[] memory) {
        if (accounts.length != ids.length) {
            revert ERC1155InvalidArrayLength(ids.length, accounts.length);
        }

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts.unsafeMemoryAccess(i), ids.unsafeMemoryAccess(i));
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual returns (bool) {
        ERC1155Storage storage $ = _getERC1155Storage();
        return $._operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public virtual {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert ERC1155MissingApprovalForAll(sender, from);
        }
        _safeTransferFrom(from, to, id, value, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert ERC1155MissingApprovalForAll(sender, from);
        }
        _safeBatchTransferFrom(from, to, ids, values, data);
    }

    /**
     * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`. Will mint (or burn) if `from`
     * (or `to`) is the zero address.
     *
     * Emits a {TransferSingle} event if the arrays contain one element, and {TransferBatch} otherwise.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement either {IERC1155Receiver-onERC1155Received}
     *   or {IERC1155Receiver-onERC1155BatchReceived} and return the acceptance magic value.
     * - `ids` and `values` must have the same length.
     *
     * NOTE: The ERC-1155 acceptance check is not performed in this function. See {_updateWithAcceptanceCheck} instead.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual {
        ERC1155Storage storage $ = _getERC1155Storage();
        if (ids.length != values.length) {
            revert ERC1155InvalidArrayLength(ids.length, values.length);
        }

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids.unsafeMemoryAccess(i);
            uint256 value = values.unsafeMemoryAccess(i);

            if (from != address(0)) {
                uint256 fromBalance = $._balances[id][from];
                if (fromBalance < value) {
                    revert ERC1155InsufficientBalance(from, fromBalance, value, id);
                }
                unchecked {
                    // Overflow not possible: value <= fromBalance
                    $._balances[id][from] = fromBalance - value;
                }
            }

            if (to != address(0)) {
                $._balances[id][to] += value;
            }
        }

        if (ids.length == 1) {
            uint256 id = ids.unsafeMemoryAccess(0);
            uint256 value = values.unsafeMemoryAccess(0);
            emit TransferSingle(operator, from, to, id, value);
        } else {
            emit TransferBatch(operator, from, to, ids, values);
        }
    }

    /**
     * @dev Version of {_update} that performs the token acceptance check by calling
     * {IERC1155Receiver-onERC1155Received} or {IERC1155Receiver-onERC1155BatchReceived} on the receiver address if it
     * contains code (eg. is a smart contract at the moment of execution).
     *
     * IMPORTANT: Overriding this function is discouraged because it poses a reentrancy risk from the receiver. So any
     * update to the contract state after this function would break the check-effect-interaction pattern. Consider
     * overriding {_update} instead.
     */
    function _updateWithAcceptanceCheck(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal virtual {
        _update(from, to, ids, values);
        if (to != address(0)) {
            address operator = _msgSender();
            if (ids.length == 1) {
                uint256 id = ids.unsafeMemoryAccess(0);
                uint256 value = values.unsafeMemoryAccess(0);
                _doSafeTransferAcceptanceCheck(operator, from, to, id, value, data);
            } else {
                _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, values, data);
            }
        }
    }

    /**
     * @dev Transfers a `value` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `value` amount.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(from, to, ids, values, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     * - `ids` and `values` must have the same length.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        _updateWithAcceptanceCheck(from, to, ids, values, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the values in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        ERC1155Storage storage $ = _getERC1155Storage();
        $._uri = newuri;
    }

    /**
     * @dev Creates a `value` amount of tokens of type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(address to, uint256 id, uint256 value, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(address(0), to, ids, values, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `values` must have the same length.
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        _updateWithAcceptanceCheck(address(0), to, ids, values, data);
    }

    /**
     * @dev Destroys a `value` amount of tokens of type `id` from `from`
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `value` amount of tokens of type `id`.
     */
    function _burn(address from, uint256 id, uint256 value) internal {
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(from, address(0), ids, values, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `value` amount of tokens of type `id`.
     * - `ids` and `values` must have the same length.
     */
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory values) internal {
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        _updateWithAcceptanceCheck(from, address(0), ids, values, "");
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the zero address.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        ERC1155Storage storage $ = _getERC1155Storage();
        if (operator == address(0)) {
            revert ERC1155InvalidOperator(address(0));
        }
        $._operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Performs an acceptance check by calling {IERC1155-onERC1155Received} on the `to` address
     * if it contains code at the moment of execution.
     */
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, value, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    // Tokens rejected
                    revert ERC1155InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert ERC1155InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev Performs a batch acceptance check by calling {IERC1155-onERC1155BatchReceived} on the `to` address
     * if it contains code at the moment of execution.
     */
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, values, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    // Tokens rejected
                    revert ERC1155InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert ERC1155InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev Creates an array in memory with only one value for each of the elements provided.
     */
    function _asSingletonArrays(
        uint256 element1,
        uint256 element2
    ) private pure returns (uint256[] memory array1, uint256[] memory array2) {
        /// @solidity memory-safe-assembly
        assembly {
            // Load the free memory pointer
            array1 := mload(0x40)
            // Set array length to 1
            mstore(array1, 1)
            // Store the single element at the next word after the length (where content starts)
            mstore(add(array1, 0x20), element1)

            // Repeat for next array locating it right after the first array
            array2 := add(array1, 0x40)
            mstore(array2, 1)
            mstore(add(array2, 0x20), element2)

            // Update the free memory pointer by pointing after the second array
            mstore(0x40, add(array2, 0x40))
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/extensions/ERC1155URIStorage.sol)

pragma solidity ^0.8.20;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1155Upgradeable} from "../ERC1155Upgradeable.sol";
import {Initializable} from "../../../proxy/utils/Initializable.sol";

/**
 * @dev ERC1155 token with storage based token URI management.
 * Inspired by the ERC721URIStorage extension
 */
abstract contract ERC1155URIStorageUpgradeable is Initializable, ERC1155Upgradeable {
    using Strings for uint256;

    /// @custom:storage-location erc7201:openzeppelin.storage.ERC1155URIStorage
    struct ERC1155URIStorageStorage {
        // Optional base URI
        string _baseURI;

        // Optional mapping for token URIs
        mapping(uint256 tokenId => string) _tokenURIs;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC1155URIStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC1155URIStorageStorageLocation = 0x89fc852226e759c7c636cf34d732f0198fc56a54876b2374a52beb7b0c558600;

    function _getERC1155URIStorageStorage() private pure returns (ERC1155URIStorageStorage storage $) {
        assembly {
            $.slot := ERC1155URIStorageStorageLocation
        }
    }

    function __ERC1155URIStorage_init() internal onlyInitializing {
        __ERC1155URIStorage_init_unchained();
    }

    function __ERC1155URIStorage_init_unchained() internal onlyInitializing {
        ERC1155URIStorageStorage storage $ = _getERC1155URIStorageStorage();
        $._baseURI = "";
    }
    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the concatenation of the `_baseURI`
     * and the token-specific uri if the latter is set
     *
     * This enables the following behaviors:
     *
     * - if `_tokenURIs[tokenId]` is set, then the result is the concatenation
     *   of `_baseURI` and `_tokenURIs[tokenId]` (keep in mind that `_baseURI`
     *   is empty per default);
     *
     * - if `_tokenURIs[tokenId]` is NOT set then we fallback to `super.uri()`
     *   which in most cases will contain `ERC1155._uri`;
     *
     * - if `_tokenURIs[tokenId]` is NOT set, and if the parents do not have a
     *   uri value set, then the result is empty.
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        ERC1155URIStorageStorage storage $ = _getERC1155URIStorageStorage();
        string memory tokenURI = $._tokenURIs[tokenId];

        // If token URI is set, concatenate base URI and tokenURI (via string.concat).
        return bytes(tokenURI).length > 0 ? string.concat($._baseURI, tokenURI) : super.uri(tokenId);
    }

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */
    function _setURI(uint256 tokenId, string memory tokenURI) internal virtual {
        ERC1155URIStorageStorage storage $ = _getERC1155URIStorageStorage();
        $._tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    /**
     * @dev Sets `baseURI` as the `_baseURI` for all tokens
     */
    function _setBaseURI(string memory baseURI) internal virtual {
        ERC1155URIStorageStorage storage $ = _getERC1155URIStorageStorage();
        $._baseURI = baseURI;
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Context.sol)

pragma solidity ^0.8.20;
import {Initializable} from "../proxy/utils/Initializable.sol";

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
}


// Chain: POLYGON - File: @openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

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
 */
abstract contract ERC165Upgradeable is Initializable, IERC165 {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Pausable
    struct PausableStorage {
        bool _paused;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Pausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PausableStorageLocation = 0xcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300;

    function _getPausableStorage() private pure returns (PausableStorage storage $) {
        assembly {
            $.slot := PausableStorageLocation
        }
    }

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        PausableStorage storage $ = _getPausableStorage();
        return $._paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
        emit Unpaused(_msgSender());
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;
import {Initializable} from "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /// @custom:storage-location erc7201:openzeppelin.storage.ReentrancyGuard
    struct ReentrancyGuardStorage {
        uint256 _status;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ReentrancyGuardStorageLocation = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    function _getReentrancyGuardStorage() private pure returns (ReentrancyGuardStorage storage $) {
        assembly {
            $.slot := ReentrancyGuardStorageLocation
        }
    }

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        $._status = NOT_ENTERED;
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
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if ($._status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        $._status = ENTERED;
    }

    function _nonReentrantAfter() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        $._status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        return $._status == ENTERED;
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts/access/IAccessControl.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/IAccessControl.sol)

pragma solidity ^0.8.20;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}


// Chain: POLYGON - File: @openzeppelin/contracts/interfaces/draft-IERC1822.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.20;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}


// Chain: POLYGON - File: @openzeppelin/contracts/interfaces/draft-IERC6093.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}


// Chain: POLYGON - File: @openzeppelin/contracts/proxy/beacon/IBeacon.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}


// Chain: POLYGON - File: @openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/ERC1967/ERC1967Utils.sol)

pragma solidity ^0.8.20;

import {IBeacon} from "../beacon/IBeacon.sol";
import {Address} from "../../utils/Address.sol";
import {StorageSlot} from "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 */
library ERC1967Utils {
    // We re-declare ERC-1967 events here because they can't be used directly from IERC1967.
    // This will be fixed in Solidity 0.8.21. At that point we should remove these events.
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.20;

import {IERC1155} from "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
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
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` amount of tokens of type `id` are transferred from `from` to `to` by `operator`.
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
     * @dev Returns the value of tokens of token type `id` owned by `account`.
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
     * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`.
     *
     * WARNING: This function can potentially allow a reentrancy attack when transferring tokens
     * to an untrusted contract, when invoking {onERC1155Received} on the receiver.
     * Ensure to follow the checks-effects-interactions pattern and consider employing
     * reentrancy guards when interacting with untrusted contracts.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `value` amount.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     *
     * WARNING: This function can potentially allow a reentrancy attack when transferring tokens
     * to an untrusted contract, when invoking {onERC1155BatchReceived} on the receiver.
     * Ensure to follow the checks-effects-interactions pattern and consider employing
     * reentrancy guards when interacting with untrusted contracts.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `values` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external;
}


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev Interface that must be implemented by smart contracts in order to receive
 * ERC-1155 token transfers.
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


// Chain: POLYGON - File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

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
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts/utils/Arrays.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Arrays.sol)

pragma solidity ^0.8.20;

import {StorageSlot} from "./StorageSlot.sol";
import {Math} from "./math/Math.sol";

/**
 * @dev Collection of functions related to array types.
 */
library Arrays {
    using StorageSlot for bytes32;

    /**
     * @dev Searches a sorted `array` and returns the first index that contains
     * a value greater or equal to `element`. If no such index exists (i.e. all
     * values in the array are strictly less than `element`), the array length is
     * returned. Time complexity O(log n).
     *
     * `array` is expected to be sorted in ascending order, and to contain no
     * repeated elements.
     */
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;

        if (high == 0) {
            return 0;
        }

        while (low < high) {
            uint256 mid = Math.average(low, high);

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds towards zero (it does integer division with truncation).
            if (unsafeAccess(array, mid).value > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && unsafeAccess(array, low - 1).value == element) {
            return low - 1;
        } else {
            return low;
        }
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeAccess(address[] storage arr, uint256 pos) internal pure returns (StorageSlot.AddressSlot storage) {
        bytes32 slot;
        // We use assembly to calculate the storage slot of the element at index `pos` of the dynamic array `arr`
        // following https://docs.soliditylang.org/en/v0.8.20/internals/layout_in_storage.html#mappings-and-dynamic-arrays.

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getAddressSlot();
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeAccess(bytes32[] storage arr, uint256 pos) internal pure returns (StorageSlot.Bytes32Slot storage) {
        bytes32 slot;
        // We use assembly to calculate the storage slot of the element at index `pos` of the dynamic array `arr`
        // following https://docs.soliditylang.org/en/v0.8.20/internals/layout_in_storage.html#mappings-and-dynamic-arrays.

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getBytes32Slot();
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeAccess(uint256[] storage arr, uint256 pos) internal pure returns (StorageSlot.Uint256Slot storage) {
        bytes32 slot;
        // We use assembly to calculate the storage slot of the element at index `pos` of the dynamic array `arr`
        // following https://docs.soliditylang.org/en/v0.8.20/internals/layout_in_storage.html#mappings-and-dynamic-arrays.

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getUint256Slot();
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeMemoryAccess(uint256[] memory arr, uint256 pos) internal pure returns (uint256 res) {
        assembly {
            res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
        }
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeMemoryAccess(address[] memory arr, uint256 pos) internal pure returns (address res) {
        assembly {
            res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts/utils/introspection/IERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

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
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
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
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
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
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
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
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

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

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
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

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
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
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
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
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
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
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
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
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
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
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts/utils/math/SignedMath.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.20;

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


// Chain: POLYGON - File: @openzeppelin/contracts/utils/StorageSlot.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

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
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
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


// Chain: POLYGON - File: @openzeppelin/contracts/utils/Strings.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Strings.sol)

pragma solidity ^0.8.20;

import {Math} from "./math/Math.sol";
import {SignedMath} from "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

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
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
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
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
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
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}


// Chain: POLYGON - File: src/contracts/libraries/LibTheBadge.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

library LibTheBadge {
    /**
     * =========================
     * Types
     * =========================
     */
    enum PaymentType {
        ProtocolFee,
        CreatorMintFee,
        UserRegistrationFee,
        UserVerificationFee
    }
    /**
     * =========================
     * Errors
     * =========================
     */
    error TheBadge__SBT();
    error TheBadge__controller_invalidController();
    error TheBadge__controller_controllerIsPaused();

    error TheBadge__requestBadge_badgeModelNotFound();
    error TheBadge__requestBadge_badgeModelIsSuspended();
    error TheBadge__requestBadge_wrongValue();
    error TheBadge__requestBadge_badgeNotMintable();
    error TheBadge__requestBadge_isPaused();
    error TheBadge__requestBadge_isSuspended();
    error TheBadge__requestBadge_isDeprecated();
    error TheBadge__requestBadge_controllerIsPaused();
    error TheBadge__requestBadge_badgeNotFound();
    error TheBadge__requestBadge_badgeNotClaimable();

    error TheBadge__mint_protocolFeesPaymentFailed();
    error TheBadge__mint_creatorFeesPaymentFailed();
    error TheBadge__mintInBatch_badgeModelsArrayEmpty();
    error TheBadge__mintInBatch_invalidParamsLength();
    error TheBadge__calculateFee_protocolFeesInvalidValues();

    error TheBadge__theBadgeUsers_method_execution_failed();
    error TheBadge__theBadgeModels_method_execution_failed();
    error TheBadge__theBadge_method_execution_failed();
    error TheBadge__proxy_method_not_supported();
}


// Chain: POLYGON - File: src/contracts/libraries/LibTheBadgeModels.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

library LibTheBadgeModels {
    /**
     * =========================
     * Errors
     * =========================
     */
    error TheBadge__addBadgeModelController_emptyName();
    error TheBadge__addBadgeModelController_alreadySet();
    error TheBadge__addBadgeModelController_notFound();
    error TheBadge__updateBadgeModel_badgeModelNotFound();
    error TheBadge__createBadgeModel_wrongValue();
    error TheBadge__updateBadgeModel_notBadgeModelOwner();
    error TheBadge__badgeModel_isSuspended();
    error TheBadge__badgeModel_badgeModelNotFound();
    error TheBadge__badgeModel_badgeModelNotUpgradeable();
    error TheBadge__method_not_supported();
}


// Chain: POLYGON - File: src/contracts/libraries/LibTheBadgeStore.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

library LibTheBadgeStore {
    /**
     * =========================
     * Errors
     * =========================
     */
    error TheBadge__Store_OperationNotPermitted();
    error TheBadge__Store_InvalidContractAddress();
    error TheBadge__Store_ContractNameAlreadyExists();
    error TheBadge__Store_InvalidContractName();
    error TheBadge__Store_InvalidUserAddress();
    error TheBadge__Store_InvalidBadgeID();
}


// Chain: POLYGON - File: src/contracts/libraries/LibTheBadgeUsers.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

library LibTheBadgeUsers {
    enum VerificationStatus {
        VerificationSubmitted, // The user submitted a request to verify himself
        Verified, // The verification was granted to the user
        VerificationRejected // The verification was rejected after qhe submission
    }

    /**
     * =========================
     * Errors
     * =========================
     */
    error TheBadge__onlyUser_userNotFound();
    error TheBadge__onlyCreator_senderIsNotACreator();
    error TheBadge__onlyCreator_senderIsAlreadyACreator();
    error TheBadge__users__onlyCreator_creatorIsSuspended();

    error TheBadge__registerUser_wrongValue();
    error TheBadge__registerUser_alreadyRegistered();
    error TheBadge__updateUser_notFound();
    error TheBadge__updateUser_wrongMetadata();

    error TheBadge__verifyUser_wrongValue();
    error TheBadge__verifyUser_verificationProtocolFeesPaymentFailed();
    error TheBadge__verifyUser__userVerificationAlreadyStarted();
    error TheBadge__verifyUser__userVerificationNotStarted();
    error TheBadge__verifyUser__userVerificationRejected();
}


// Chain: POLYGON - File: src/contracts/thebadge/TheBadge.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ERC1155URIStorageUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { TheBadgeRoles } from "./TheBadgeRoles.sol";
import { ITheBadge } from "../../interfaces/ITheBadge.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IBadgeModelController } from "../../interfaces/IBadgeModelController.sol";
import { TheBadgeStore } from "./TheBadgeStore.sol";
import { TheBadgeUsers } from "./TheBadgeUsers.sol";
import { TheBadgeUsersStore } from "./TheBadgeUsersStore.sol";
import { LibTheBadge } from "../libraries/LibTheBadge.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @custom:security-contact hello@thebadge.com
contract TheBadge is
    Initializable,
    ERC1155Upgradeable,
    ERC1155URIStorageUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    TheBadgeRoles,
    ITheBadge,
    ReentrancyGuardUpgradeable
{
    TheBadgeStore public _badgeStore;
    TheBadgeUsers public _badgeUsers;
    string public name;
    string public symbol;

    /**
     * =========================
     * Events
     * =========================
     */
    event Initialize(address indexed admin);
    event PaymentMade(
        address indexed recipient,
        address payer,
        uint256 amount,
        LibTheBadge.PaymentType indexed paymentType,
        uint256 indexed badgeModelId,
        string controllerName
    );
    event BadgeRequested(
        uint256 indexed badgeModelID,
        uint256 indexed badgeID,
        address indexed recipient,
        address controller,
        uint256 controllerBadgeId
    );
    event BadgeClaimed(uint256 indexed badgeId, address indexed origin, address indexed destination);
    event ProtocolSettingsUpdated();

    /**
     * =========================
     * Modifiers
     * =========================
     */

    function validateBadgeModelMintable(uint256 badgeModelId) internal view {
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(badgeModelId);
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );

        if (_badgeModel.creator == address(0)) {
            revert LibTheBadge.TheBadge__requestBadge_badgeModelNotFound();
        }

        if (_badgeModel.paused) {
            revert LibTheBadge.TheBadge__requestBadge_isPaused();
        }

        if (_badgeModel.suspended) {
            revert LibTheBadge.TheBadge__requestBadge_isSuspended();
        }

        if (_badgeModel.deprecated) {
            revert LibTheBadge.TheBadge__requestBadge_isDeprecated();
        }

        if (_badgeModelController.paused) {
            revert LibTheBadge.TheBadge__requestBadge_controllerIsPaused();
        }

        TheBadgeUsersStore.User memory user = _badgeUsers.getUser(_badgeModel.creator);
        if (user.suspended == true) {
            revert LibTheBadge.TheBadge__requestBadge_badgeModelIsSuspended();
        }
    }

    modifier onlyBadgeModelMintable(uint256 badgeModelId) {
        validateBadgeModelMintable(badgeModelId);
        _;
    }

    modifier onlyBadgeModelMintableBatch(uint256[] memory badgeModelIds) {
        if (badgeModelIds.length == 0) {
            revert LibTheBadge.TheBadge__mintInBatch_badgeModelsArrayEmpty();
        }

        for (uint256 i = 0; i < badgeModelIds.length; i++) {
            uint256 badgeModelId = badgeModelIds[i];
            validateBadgeModelMintable(badgeModelId);
        }

        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // See https://docs.openzeppelin.com/learn/upgrading-smart-contracts#initialization
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address badgeStore, address badgeUsers) public initializer {
        __ERC1155_init("");
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(VERIFIER_ROLE, admin);
        _badgeStore = TheBadgeStore(payable(badgeStore));
        _badgeUsers = TheBadgeUsers(payable(badgeUsers));
        name = "TheBadge";
        symbol = "BGD";
        emit Initialize(admin);
    }

    /*
     * @notice Receives a badgeModel, and user account, the token data ipfsURI and the controller's data and mints the badge for the user
     * @param badgeModelId id of theBadgeModel
     * @param account the recipient address of the badge, if empty and it's allowed, its stored on the controller's address until its claimed
     * @param tokenURI url of the data of the token stored in IPFS
     * @param data metaEvidence for the controller
     */
    function mint(
        uint256 badgeModelId,
        address account,
        string memory tokenURI,
        bytes memory data
    ) external payable onlyBadgeModelMintable(badgeModelId) nonReentrant {
        mintLogic(badgeModelId, account, tokenURI, data);
    }

    function mintInBatch(
        uint256[] memory badgeModelIds,
        address[] memory recipients,
        string[] memory tokenURIs,
        bytes[] memory data
    ) external payable onlyBadgeModelMintableBatch(badgeModelIds) nonReentrant {
        if (
            badgeModelIds.length != recipients.length ||
            (badgeModelIds.length != tokenURIs.length && badgeModelIds.length != data.length)
        ) {
            revert LibTheBadge.TheBadge__mintInBatch_invalidParamsLength();
        }

        uint256 totalValue = 0;

        for (uint256 i = 0; i < badgeModelIds.length; i++) {
            uint256 badgeModelId = badgeModelIds[i];
            address recipient = recipients[i];
            string memory tokenURI = tokenURIs[i];
            bytes memory userData = data[i];

            // Call the existing mint function
            mintLogic(badgeModelId, recipient, tokenURI, userData);

            // Update the total value
            totalValue += msg.value;
        }

        // Refund any excess value sent with the batch minting
        if (totalValue > msg.value) {
            payable(msg.sender).transfer(totalValue - msg.value);
        }
    }

    function mintLogic(uint256 badgeModelId, address account, string memory tokenURI, bytes memory data) internal {
        // Re-declaring variables reduces the stack tree and avoid compilation errors
        uint256 _badgeModelId = badgeModelId;
        address _account = account;
        address _mintingAccount = _account;
        bytes memory _data = data;
        string memory _tokenURI = tokenURI;

        if (msg.value < mintValue(_badgeModelId)) {
            revert LibTheBadge.TheBadge__requestBadge_wrongValue();
        }

        // Distribute fees
        payProtocolFees(_badgeModelId);

        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(_badgeModelId);
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );
        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);

        // If no recipient has been defined, we ask the controller if it's allowed to temporally store
        // the asset within his address until the user claims the ownership
        if (_account == address(0)) {
            if (!controller.isMintableToController(_badgeModelId, _account)) {
                revert LibTheBadge.TheBadge__requestBadge_badgeNotMintable();
            }
            _mintingAccount = _badgeModelController.controller;
        }

        // save asset info
        uint256 badgeId = _badgeStore.getCurrentBadgeIdCounter();

        // Mints the badge on the controller
        uint256 controllerBadgeId = controller.mint{ value: controller.mintValue(_badgeModelId) }(
            _msgSender(),
            _badgeModelId,
            badgeId,
            _data,
            _mintingAccount
        );

        // Mints the badge on the ERC1155 collection
        _setURI(badgeId, _tokenURI);
        // Account: badge recipient; badgeId: the id of the badge; value: amount of badges to create (always 1), data: data of the badge (always null)
        // For details check: https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/token/ERC1155/ERC1155Upgradeable.sol#L303C72-L303C76
        _mint(_mintingAccount, badgeId, 1, "0x");

        // Stores the badge
        uint256 dueDate = calculateBadgeDueDate(_badgeModel.validFor, 0, false, controller.isAutomaticClaimable());
        TheBadgeStore.Badge memory badge = TheBadgeStore.Badge(_badgeModelId, _mintingAccount, dueDate, true);
        _badgeStore.addBadge(badgeId, badge);
        emit BadgeRequested(
            _badgeModelId,
            badgeId,
            _mintingAccount,
            _badgeModelController.controller,
            controllerBadgeId
        );
    }

    /**
     * @notice Given a badgeId and data related to the recipient, claims the given badge to the recipient address
     * @param badgeId the id of the badge
     * @param data containing information related to the recipient address
     */
    function claim(uint256 badgeId, bytes calldata data) public {
        uint256 badgeModelId = getBadgeModelIdFromBadgeId(badgeId);
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(badgeModelId);
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );
        TheBadgeStore.Badge memory badge = _badgeStore.getBadge(badgeId);
        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);

        if (badge.initialized == false) {
            revert LibTheBadge.TheBadge__requestBadge_badgeNotClaimable();
        }

        if (controller.isClaimable(badgeId) == false) {
            revert LibTheBadge.TheBadge__requestBadge_badgeNotClaimable();
        }

        address tempStoredBadgeAddress = badge.account;
        if (tempStoredBadgeAddress == address(0)) {
            tempStoredBadgeAddress = address(_badgeModelController.controller);
        }
        address claimAddress = controller.claim(badgeId, data, _msgSender());
        uint256 dueDate = calculateBadgeDueDate(
            _badgeModel.validFor,
            badge.dueDate,
            true,
            controller.isAutomaticClaimable()
        );
        _badgeStore.updateBadgeDueDate(badgeId, dueDate);
        _badgeStore.transferBadge(badgeId, tempStoredBadgeAddress, claimAddress);
        emit BadgeClaimed(badgeId, tempStoredBadgeAddress, claimAddress);
    }

    /**
     * @notice Given a badge and the evidenceHash, submits a challenge against the controller
     * @param badgeId the id of the badge
     * @param data encoded ipfs hash containing the evidence to generate the challenge
     */
    function challenge(uint256 badgeId, bytes calldata data) external payable {
        uint256 badgeModelId = getBadgeModelIdFromBadgeId(badgeId);
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(badgeModelId);
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );
        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);

        controller.challenge{ value: (msg.value) }(badgeId, data, _msgSender());
    }

    /**
     * @notice Given a badge and the evidenceHash, submits a removal request against the controller
     * @param badgeId the id of the badge
     * @param data encoded ipfs hash containing the evidence to generate the removal request
     */
    function removeItem(uint256 badgeId, bytes calldata data) external payable {
        uint256 badgeModelId = getBadgeModelIdFromBadgeId(badgeId);
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(badgeModelId);
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );
        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);

        controller.removeItem{ value: (msg.value) }(badgeId, data, _msgSender());
    }

    /**
     * @notice Given a badge and the evidenceHash, adds more evidence to a case
     * @param badgeId the id of the badge
     * @param data encoded ipfs hash adding more evidence to a submission
     */
    function submitEvidence(uint256 badgeId, bytes calldata data) external {
        uint256 badgeModelId = getBadgeModelIdFromBadgeId(badgeId);
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(badgeModelId);
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );
        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);

        controller.submitEvidence(badgeId, data, _msgSender());
    }

    /*
     * @notice Updates the value of the protocol: _mintBadgeDefaultFee
     * @param _mintBadgeDefaultFee the default fee that TheBadge protocol charges for each mint (in bps)
     */
    function updateMintBadgeDefaultProtocolFee(uint256 _mintBadgeDefaultFee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _badgeStore.updateMintBadgeDefaultProtocolFee(_mintBadgeDefaultFee);
        emit ProtocolSettingsUpdated();
    }

    /*
     * @notice Updates the value of the protocol: _claimProtocolFee
     * @param _claimProtocolFee the fee that TheBadge protocol charges for the claim execution
     */
    function updateClaimBadgeProtocolFee(uint256 _claimProtocolFee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _badgeStore.updateClaimBadgeProtocolFee(_claimProtocolFee);
        emit ProtocolSettingsUpdated();
    }

    /*
     * @notice Updates the value of the protocol: _createBadgeModelValue
     * @param _createBadgeModelValue the default fee that TheBadge protocol charges for each badge model creation (in bps)
     */
    function updateCreateBadgeModelProtocolFee(uint256 _createBadgeModelValue) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _badgeStore.updateCreateBadgeModelProtocolFee(_createBadgeModelValue);
        emit ProtocolSettingsUpdated();
    }

    function payProtocolFees(uint256 _badgeModelId) internal {
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(_badgeModelId);
        // Gas costs of the claim function sponsored by the creator on behalf of the user
        uint256 claimBadgeProtocolFee = _badgeStore.claimBadgeProtocolFee();
        // TheBadge revenue from the creator's fee
        uint256 theBadgeFee = calculateFee(_badgeModel.mintCreatorFee, _badgeModel.mintProtocolFee);
        // Final revenue of the creator
        uint256 creatorPayment = _badgeModel.mintCreatorFee - theBadgeFee;

        address feeCollector = _badgeStore.feeCollector();
        // Stores both the revenue fee plus the fees required for sponsoring the claim
        (bool protocolFeeSent, ) = payable(feeCollector).call{ value: theBadgeFee + claimBadgeProtocolFee }("");
        if (protocolFeeSent == false) {
            revert LibTheBadge.TheBadge__mint_protocolFeesPaymentFailed();
        }
        emit PaymentMade(
            feeCollector,
            _msgSender(),
            theBadgeFee,
            LibTheBadge.PaymentType.ProtocolFee,
            _badgeModelId,
            "0x"
        );

        (bool creatorFeeSent, ) = payable(_badgeModel.creator).call{ value: creatorPayment }("");
        if (creatorFeeSent == false) {
            revert LibTheBadge.TheBadge__mint_creatorFeesPaymentFailed();
        }
        emit PaymentMade(
            _badgeModel.creator,
            feeCollector,
            creatorPayment,
            LibTheBadge.PaymentType.CreatorMintFee,
            _badgeModelId,
            "0x"
        );
    }

    function calculateBadgeDueDate(
        uint256 validForConfig,
        uint256 currentDueDate,
        bool isClaimEvent,
        bool isAutomaticClaimable
    ) internal view returns (uint256) {
        // Is the badge does not expire, the expiration is not defined.
        if (validForConfig == 0) {
            return 0;
        }

        // If the badge can be automatically claimed after mint and it's the CLAIM event
        // The dueDate was already defined before the CLAIM, no extra calculations are needed
        if (isClaimEvent && isAutomaticClaimable) {
            return currentDueDate;
        }

        // If its not the claim event but its automatically claimable
        // Or it's the claim event and it's not automatically claimable
        // The dueDate should be defined now
        if (isClaimEvent || isAutomaticClaimable) {
            return block.timestamp + validForConfig;
        }

        // If the badge can't be automatically claimed before CLAIM, and it's not the CLAIM event
        // The dueDate should be left empty until the CLAIM event occurs
        return 0;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /*
     * ERC-20
     * @notice Given an user account and a badgeId, returns 1 if the user has the badge or 0 if not
     * @param account address of the user
     * @param badgeId identifier of the badge inside a badgeModel
     */
    function balanceOf(
        address account,
        uint256 badgeId
    ) public view override(ERC1155Upgradeable, ITheBadge) returns (uint256) {
        TheBadgeStore.Badge memory _badge = _badgeStore.getBadge(badgeId);

        if (_badge.initialized == false || _badge.account != account) {
            return 0;
        }

        if (isExpired(badgeId) == true) {
            return 0;
        }

        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(_badge.badgeModelId);

        // The badgeModel has been suspended for breaking the TYC
        if (_badgeModel.suspended == true) {
            return 0;
        }

        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );
        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);

        return controller.isAssetActive(badgeId) ? 1 : 0;
    }

    /*
     * @notice given an account address and a badgeModelId returns how many badges of each model owns the user
     * @param account user address
     * @param badgeModelId ID of the badgeModel
     */
    function balanceOfBadgeModel(address account, uint256 badgeModelId) public view returns (uint256) {
        uint256[] memory userMintedBadgesByBadgeModel = _badgeStore.getUserMintedBadgesByBadgeModel(
            badgeModelId,
            account
        );
        if (userMintedBadgesByBadgeModel.length == 0) {
            return 0;
        }

        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(badgeModelId);
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );
        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);

        uint256 balance = 0;
        for (uint256 i = 0; i < userMintedBadgesByBadgeModel.length; i++) {
            uint256 badgeId = userMintedBadgesByBadgeModel[i];
            if (isExpired(badgeId) == false && controller.isAssetActive(badgeId)) {
                balance++;
            }
        }

        return balance;
    }

    /*
     * @notice Given a badgeId, returns true if the badge has expired (dueDate <= currentTime)
     * if the badge is configured as an all-time badge or if the dueTime didn't arrived yet, returns false
     * @param account address of the user
     * @param badgeId identifier of the badge inside a badgeModel
     */
    function isExpired(uint256 badgeId) public view returns (bool) {
        TheBadgeStore.Badge memory _badge = _badgeStore.getBadge(badgeId);

        if (_badge.initialized == false) {
            return false;
        }

        // Badge configured to be life-time
        if (_badge.dueDate == 0) {
            return false;
        }

        return _badge.dueDate <= block.timestamp ? true : false;
    }

    /**
     * @notice Returns true if the badge is ready to be claimed to its destination address, otherwise returns false
     * @param badgeId the badgeId
     */
    function isClaimable(uint256 badgeId) external view returns (bool) {
        TheBadgeStore.Badge memory badge = _badgeStore.getBadge(badgeId);

        if (badge.initialized == false) {
            revert LibTheBadge.TheBadge__requestBadge_badgeNotClaimable();
        }

        uint256 badgeModelId = getBadgeModelIdFromBadgeId(badgeId);
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(badgeModelId);
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );

        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);

        return controller.isClaimable(badgeId);
    }

    /**
     * @notice Given a badgeId, returns the cost to challenge the item
     * @param badgeId the id of the badge
     */
    function getChallengeDepositValue(uint256 badgeId) public view override(ITheBadge) returns (uint256) {
        uint256 badgeModelId = getBadgeModelIdFromBadgeId(badgeId);
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(badgeModelId);
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );
        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);

        return controller.getChallengeDepositValue(badgeId);
    }

    /**
     * @notice Given a badgeId, returns the cost to challenge to remove the item
     * @param badgeId the id of the badge
     */
    function getRemovalDepositValue(uint256 badgeId) public view override(ITheBadge) returns (uint256) {
        uint256 badgeModelId = getBadgeModelIdFromBadgeId(badgeId);
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(badgeModelId);
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );
        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);

        return controller.getRemovalDepositValue(badgeId);
    }

    /*
     * @notice Receives the mintCreatorFee and the mintProtocolFee in bps and returns how much is the protocol fee
     * @param mintCreatorFee fee that the creator charges for each mint
     * @param mintProtocolFeeInBps fee that TheBadge protocol charges from the creator revenue
     */
    function calculateFee(uint256 mintCreatorFee, uint256 mintProtocolFeeInBps) internal pure returns (uint256) {
        if (mintCreatorFee <= 0) {
            return 0;
        }
        if ((mintCreatorFee * mintProtocolFeeInBps) < 10_000) {
            revert LibTheBadge.TheBadge__calculateFee_protocolFeesInvalidValues();
        }
        return (mintCreatorFee * mintProtocolFeeInBps) / 10_000;
    }

    /**
     * @notice Given a badgeId, returns the id of its model if exists
     * @param badgeId the id of the badge
     */
    function getBadgeModelIdFromBadgeId(uint256 badgeId) internal view returns (uint256) {
        TheBadgeStore.Badge memory _badge = _badgeStore.getBadge(badgeId);

        if (_badge.initialized == false) {
            revert LibTheBadge.TheBadge__requestBadge_badgeNotFound();
        }
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(_badge.badgeModelId);

        if (_badgeModel.creator == address(0)) {
            revert LibTheBadge.TheBadge__requestBadge_badgeModelNotFound();
        }
        return _badge.badgeModelId;
    }

    /*
     * @notice given badgeModelId returns the cost of minting that badge (controller minting fee + mintCreatorFee + theBadgeClaimFee)
     * @param badgeModelId the id of the badgeModel
     */
    function mintValue(uint256 badgeModelId) public view returns (uint256) {
        TheBadgeStore.BadgeModel memory _badgeModel = _badgeStore.getBadgeModel(badgeModelId);
        uint256 theBadgeClaimFee = _badgeStore.claimBadgeProtocolFee();

        if (_badgeModel.creator == address(0)) {
            revert LibTheBadge.TheBadge__requestBadge_badgeModelNotFound();
        }

        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            _badgeModel.controllerName
        );

        IBadgeModelController controller = IBadgeModelController(_badgeModelController.controller);
        return controller.mintValue(badgeModelId) + _badgeModel.mintCreatorFee + theBadgeClaimFee;
    }

    /**
     * =========================
     * Overrides
     * =========================
     */

    /*
     * @notice Given a badgeId returns the uri of the erc115 badge token
     * @param badgeId id of a badge inside a model
     */
    function uri(
        uint256 badgeId
    )
        public
        view
        virtual
        override(ERC1155URIStorageUpgradeable, ERC1155Upgradeable, ITheBadge)
        returns (string memory)
    {
        return super.uri(badgeId);
    }

    /**
     * @notice ERC1155 _setApprovalForAll method, returns a soul-bonded token revert message
     */
    function _setApprovalForAll(address, address, bool) internal pure override {
        revert LibTheBadge.TheBadge__SBT();
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal override whenNotPaused {
        // Check if the from address is one of the badgeModelControllers
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelControllerByAddress(
            from
        );

        if (from != address(0) && _badgeModelController.initialized == false) {
            revert LibTheBadge.TheBadge__SBT();
        }

        super._update(from, to, ids, amounts);
    }

    // solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155Upgradeable, AccessControlUpgradeable, ITheBadge) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;

    // tslint:disable-next-line:no-empty
    receive() external payable {}
}


// Chain: POLYGON - File: src/contracts/thebadge/TheBadgeRoles.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract TheBadgeRoles is AccessControlUpgradeable {
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant USER_MANAGER_ROLE = keccak256("USER_MANAGER_ROLE");
    bytes32 public constant CLAIMER_ROLE = keccak256("CLAIMER_ROLE");
}


// Chain: POLYGON - File: src/contracts/thebadge/TheBadgeStore.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { TheBadgeRoles } from "./TheBadgeRoles.sol";
import { LibTheBadgeModels } from "../libraries/LibTheBadgeModels.sol";
import { LibTheBadgeModels } from "../libraries/LibTheBadgeModels.sol";
import { LibTheBadgeStore } from "../libraries/LibTheBadgeStore.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TheBadgeStore is TheBadgeRoles, OwnableUpgradeable {
    /**
     * =========================
     * Events
     * =========================
     */
    // Event to log when a contract is added to the list
    event ContractAdded(string indexed _contractName, address indexed contractAddress);

    // Event to log when a contract is removed from the list
    event ContractRemoved(string indexed _contractName, address indexed contractAddress);

    // Event to log when a contract address is updated from the list
    event ContractUpdated(string indexed _contractName, address indexed contractAddress);

    /**
     * =========================
     * Modifiers
     * =========================
     */

    // Modifier to check if the caller is one of the allowedContractAddresses contracts
    modifier onlyPermittedContract() {
        if (allowedContractAddresses[_msgSender()] == false) {
            revert LibTheBadgeStore.TheBadge__Store_OperationNotPermitted();
        }

        _;
    }

    uint256 internal badgeModelIdsCounter;
    uint256 internal badgeIdsCounter;
    uint256 public createBadgeModelProtocolFee;
    uint256 public mintBadgeProtocolDefaultFeeInBps;
    address public feeCollector;

    /**
     * =========================
     * Types
     * =========================
     */

    /**
     * @param controller the smart contract that controls a badge model.
     * @param paused if the controller is paused, no operations can be done
     * @param initialized  When the struct is created its true, if the struct was never initialized, its false, used in validations
     */
    struct BadgeModelController {
        address controller;
        bool paused;
        bool initialized;
    }

    /**
     * Struct to use as arg to create a badge model
     */
    struct CreateBadgeModel {
        string metadata;
        string controllerName;
        uint256 mintCreatorFee;
        uint256 validFor;
    }

    /**
     * Struct to store generic information of a badge model.
     */
    struct BadgeModel {
        address creator;
        string controllerName;
        bool paused; // If true it cannot be mintable, configured by the badge model creator
        uint256 mintCreatorFee; // in bps (%). It is taken from mintCreatorFee
        uint256 validFor;
        uint256 mintProtocolFee; // amount that the protocol will charge for this
        bool initialized; // When the struct is created its true, if the struct was never initialized, its false, used in validations
        uint256 version; // The version of the badgeModel, used in case of updates.
        bool suspended; // If true, the badge has been suspended from the administrator of TB contract and users won't be able to interact with anymore
        bool deprecated; // If true, the badge cannot be minted anymore as there is a newer version for this badge, old badges are still valid to maintain backwards compatibility
        string metadata; // The ips hash metadata of the badgeModel
    }

    struct Badge {
        uint256 badgeModelId;
        address account; // The minting address owner of the badge
        uint256 dueDate;
        bool initialized; // When the struct is created its true, if the struct was never initialized, its false, used in validations
    }

    // Mapping to store contract addresses by name
    mapping(address => bool) public allowedContractAddresses;
    mapping(string => address) public allowedContractAddressesByContractName;
    mapping(string => BadgeModelController) public badgeModelControllers;
    mapping(address => BadgeModelController) public badgeModelControllersByAddress;
    mapping(uint256 => BadgeModel) public badgeModels;
    mapping(uint256 => Badge) public badges;
    mapping(uint256 => mapping(address => uint256[])) public userMintedBadgesByBadgeModel;

    uint256 public claimBadgeProtocolFee;

    /// @custom:oz-upgrades-unsafe-allow constructor
    // See https://docs.openzeppelin.com/learn/upgrading-smart-contracts#initialization
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _feeCollector) public initializer {
        __Ownable_init(admin);
        feeCollector = _feeCollector;
        createBadgeModelProtocolFee = uint256(0);
        mintBadgeProtocolDefaultFeeInBps = uint256(1000); // in bps (= 10%)
        claimBadgeProtocolFee = 0 ether;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * =========================
     * Getters
     * =========================
     */
    function getBadgeModelController(string memory controllerName) external view returns (BadgeModelController memory) {
        return badgeModelControllers[controllerName];
    }

    function getBadgeModelControllerByAddress(
        address controllerAddress
    ) external view returns (BadgeModelController memory) {
        return badgeModelControllersByAddress[controllerAddress];
    }

    function getBadgeModel(uint256 badgeModelId) external view returns (BadgeModel memory) {
        return badgeModels[badgeModelId];
    }

    function getBadge(uint256 badgeId) external view returns (Badge memory) {
        return badges[badgeId];
    }

    function getCurrentBadgeModelsIdCounter() external view returns (uint256) {
        return badgeModelIdsCounter;
    }

    function getCurrentBadgeIdCounter() external view returns (uint256) {
        return badgeIdsCounter;
    }

    function getUserMintedBadgesByBadgeModel(
        uint256 badgeModelId,
        address userAddress
    ) external view returns (uint256[] memory) {
        return userMintedBadgesByBadgeModel[badgeModelId][userAddress];
    }

    /**
     * =========================
     * Setters
     * =========================
     */

    function addBadgeModelController(
        string memory controllerName,
        BadgeModelController calldata badgeModelController
    ) external onlyPermittedContract {
        BadgeModelController storage _badgeModelController = badgeModelControllers[controllerName];
        if (_badgeModelController.controller != address(0)) {
            revert LibTheBadgeModels.TheBadge__addBadgeModelController_alreadySet();
        }
        badgeModelControllers[controllerName] = badgeModelController;
        badgeModelControllersByAddress[badgeModelController.controller] = badgeModelController;
    }

    function updateBadgeModelController(
        string memory controllerName,
        BadgeModelController calldata badgeModelController
    ) external onlyPermittedContract {
        BadgeModelController storage _badgeModelController = badgeModelControllers[controllerName];
        if (_badgeModelController.controller == address(0)) {
            revert LibTheBadgeModels.TheBadge__addBadgeModelController_notFound();
        }
        delete badgeModelControllersByAddress[_badgeModelController.controller];
        badgeModelControllers[controllerName] = badgeModelController;
        badgeModelControllersByAddress[badgeModelController.controller] = badgeModelController;
    }

    function addBadgeModel(BadgeModel calldata badgeModel) external onlyPermittedContract {
        badgeModels[badgeModelIdsCounter] = badgeModel;

        badgeModelIdsCounter++;
    }

    function updateBadgeModel(uint256 badgeModelId, BadgeModel calldata badgeModel) external onlyPermittedContract {
        BadgeModel storage _badgeModel = badgeModels[badgeModelId];

        if (_badgeModel.initialized == false) {
            revert LibTheBadgeModels.TheBadge__badgeModel_badgeModelNotFound();
        }

        _badgeModel.mintProtocolFee = badgeModel.mintProtocolFee;
        _badgeModel.mintCreatorFee = badgeModel.mintCreatorFee;
        _badgeModel.paused = badgeModel.paused;
        _badgeModel.deprecated = badgeModel.deprecated;
    }

    function updateBadgeModelMetadata(uint256 badgeModelId, string memory metadata) external onlyPermittedContract {
        BadgeModel storage _badgeModel = badgeModels[badgeModelId];

        if (_badgeModel.initialized == false) {
            revert LibTheBadgeModels.TheBadge__badgeModel_badgeModelNotFound();
        }

        _badgeModel.metadata = metadata;
    }

    function suspendBadgeModel(uint256 badgeModelId, bool suspended) external onlyPermittedContract {
        BadgeModel storage _badgeModel = badgeModels[badgeModelId];

        if (_badgeModel.initialized == false) {
            revert LibTheBadgeModels.TheBadge__badgeModel_badgeModelNotFound();
        }

        _badgeModel.suspended = suspended;
        _badgeModel.metadata = "ipfs://"; // TODO this can be hardcoded to a disabled ipfs hash
    }

    function addBadge(uint256 badgeId, Badge calldata badge) external onlyPermittedContract {
        uint256 _badgeModelId = badge.badgeModelId;
        address _account = badge.account;
        badges[badgeId] = badge;
        userMintedBadgesByBadgeModel[_badgeModelId][_account].push(badgeId);
        badgeIdsCounter++;
    }

    function transferBadge(uint256 badgeId, address origin, address destination) external onlyPermittedContract {
        Badge storage badge = badges[badgeId];
        if (origin == address(0) || destination == address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidUserAddress();
        }
        if (badge.initialized == false) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidBadgeID();
        }
        if (badge.account != origin) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidUserAddress();
        }

        badge.account = destination;
        uint256[] storage badgeList = userMintedBadgesByBadgeModel[badge.badgeModelId][origin];

        for (uint256 i = 0; i < badgeList.length; i++) {
            if (badgeList[i] == badgeId) {
                uint256 lastIndex = badgeList.length - 1;
                if (i != lastIndex) {
                    // Move the last element to the position of the removed element
                    badgeList[i] = badgeList[lastIndex];
                }
                badgeList.pop(); // Remove the last element
                break;
            }
        }

        userMintedBadgesByBadgeModel[badge.badgeModelId][destination].push(badgeId);
    }

    function updateBadgeDueDate(uint256 badgeId, uint256 dueDate) external onlyPermittedContract {
        Badge storage badge = badges[badgeId];

        if (badge.initialized == false) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidBadgeID();
        }

        badge.dueDate = dueDate;
    }

    /*
     * @notice Updates the value of the protocol: _mintBadgeDefaultFee
     * @param _mintBadgeDefaultFee the default fee that TheBadge protocol charges for each mint (in bps)
     */
    function updateMintBadgeDefaultProtocolFee(uint256 _mintBadgeDefaultFee) public onlyPermittedContract {
        mintBadgeProtocolDefaultFeeInBps = _mintBadgeDefaultFee;
    }

    /*
     * @notice Updates the value of the protocol: _claimProtocolFee
     * @param _claimProtocolFee the fee that TheBadge protocol charges for the claim execution
     */
    function updateClaimBadgeProtocolFee(uint256 _claimProtocolFee) public onlyPermittedContract {
        claimBadgeProtocolFee = _claimProtocolFee;
    }

    /*
     * @notice Updates the value of the protocol: _createBadgeModelValue
     * @param _createBadgeModelValue the default fee that TheBadge protocol charges for each badge model creation (in bps)
     */
    function updateCreateBadgeModelProtocolFee(uint256 _createBadgeModelValue) public onlyPermittedContract {
        createBadgeModelProtocolFee = _createBadgeModelValue;
    }

    // Function to add a contract to the list of permitted contracts
    function addPermittedContract(
        string memory _contractName,
        address _contractAddress
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_contractAddress == address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidContractAddress();
        }

        // Check if the contract name already exists
        if (allowedContractAddressesByContractName[_contractName] != address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_ContractNameAlreadyExists();
        }

        // Add the contract name and address to the mapping
        allowedContractAddressesByContractName[_contractName] = _contractAddress;
        allowedContractAddresses[_contractAddress] = true;

        emit ContractAdded(_contractName, _contractAddress);
    }

    // Function to remove a contract from the list of permitted contracts
    function removePermittedContract(string memory _contractName) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address contractAddress = allowedContractAddressesByContractName[_contractName];

        // Check if the contract name exists in the mapping
        if (contractAddress == address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidContractName();
        }

        // Remove the contract name and address from the mapping
        delete allowedContractAddressesByContractName[_contractName];
        delete allowedContractAddresses[contractAddress];

        emit ContractRemoved(_contractName, contractAddress);
    }

    // Function to update a contract address based on the contract name
    function updatePermittedContract(
        string memory _contractName,
        address _newContractAddress
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newContractAddress == address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidContractAddress();
        }

        // Check if the contract name exists in the mapping
        address oldContractAddress = allowedContractAddressesByContractName[_contractName];
        if (oldContractAddress == address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidContractName();
        }

        // Update the contract address associated with the contract name
        delete allowedContractAddresses[oldContractAddress];
        allowedContractAddressesByContractName[_contractName] = _newContractAddress;
        allowedContractAddresses[_newContractAddress] = true;

        emit ContractUpdated(_contractName, _newContractAddress);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;

    // tslint:disable-next-line:no-empty
    receive() external payable {}
}


// Chain: POLYGON - File: src/contracts/thebadge/TheBadgeUsers.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;
/**
 * =========================
 * Contains all the logic related to TheBadge users
 * =========================
 */

import { IBadgeModelController } from "../../interfaces/IBadgeModelController.sol";
import { ITheBadgeUsers } from "../../interfaces/ITheBadgeUsers.sol";
import { TheBadgeRoles } from "./TheBadgeRoles.sol";
import { LibTheBadgeUsers } from "../libraries/LibTheBadgeUsers.sol";
import { LibTheBadge } from "../libraries/LibTheBadge.sol";
import { TheBadgeStore } from "./TheBadgeStore.sol";
import { TheBadgeUsersStore } from "./TheBadgeUsersStore.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract TheBadgeUsers is ITheBadgeUsers, TheBadgeRoles, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    TheBadgeStore public _badgeStore;
    TheBadgeUsersStore public _badgeUsersStore;

    /**
     * =========================
     * Events
     * =========================
     */
    event Initialize(address indexed admin);
    event UserRegistered(address indexed user, string metadata);
    event UserVerificationRequested(address indexed user, string metadata, string controllerName);
    event UserVerificationExecuted(address indexed user, string controllerName, bool verify);
    event UpdatedUser(address indexed userAddress, string metadata, bool suspended, bool isCreator, bool deleted);
    event PaymentMade(
        address indexed recipient,
        address payer,
        uint256 amount,
        LibTheBadge.PaymentType indexed paymentType,
        uint256 indexed badgeModelId,
        string controllerName
    );
    event ProtocolSettingsUpdated();

    /**
     * =========================
     * Modifiers
     * =========================
     */
    modifier onlyRegisteredUser(address _user) {
        TheBadgeUsersStore.User memory user = _badgeUsersStore.getUser(_user);
        if (bytes(user.metadata).length == 0) {
            revert LibTheBadgeUsers.TheBadge__onlyUser_userNotFound();
        }
        if (user.suspended == true) {
            revert LibTheBadgeUsers.TheBadge__users__onlyCreator_creatorIsSuspended();
        }
        _;
    }

    modifier existingBadgeModelController(string memory controllerName) {
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            controllerName
        );
        if (_badgeModelController.controller == address(0)) {
            revert LibTheBadge.TheBadge__controller_invalidController();
        }
        if (_badgeModelController.initialized == false) {
            revert LibTheBadge.TheBadge__controller_invalidController();
        }
        if (_badgeModelController.paused) {
            revert LibTheBadge.TheBadge__controller_controllerIsPaused();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // See https://docs.openzeppelin.com/learn/upgrading-smart-contracts#initialization
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address badgeStore, address badgeUsersStore) public initializer {
        __Ownable_init(admin);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(USER_MANAGER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(VERIFIER_ROLE, admin);
        _badgeStore = TheBadgeStore(payable(badgeStore));
        _badgeUsersStore = TheBadgeUsersStore(payable(badgeUsersStore));
        emit Initialize(admin);
    }

    /**
     * =========================
     * Getters
     * =========================
     */
    function getUser(address userAddress) external view returns (TheBadgeUsersStore.User memory) {
        TheBadgeUsersStore.User memory user = _badgeUsersStore.getUser(userAddress);

        return user;
    }

    function getUserVerifyStatus(
        address controllerAddress,
        address userAddress
    ) external view returns (TheBadgeUsersStore.UserVerification memory) {
        return _badgeUsersStore.getUserVerifyStatus(controllerAddress, userAddress);
    }

    function getRegisterFee() external view returns (uint256) {
        return _badgeUsersStore.registerUserProtocolFee();
    }

    function getVerificationFee(
        string memory controllerName
    ) public view existingBadgeModelController(controllerName) returns (uint256) {
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            controllerName
        );
        return IBadgeModelController(_badgeModelController.controller).getVerifyUserProtocolFee();
    }

    function isUserVerified(
        address _user,
        string memory controllerName
    ) public view existingBadgeModelController(controllerName) returns (bool) {
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            controllerName
        );
        TheBadgeUsersStore.UserVerification memory verifyStatus = _badgeUsersStore.getUserVerifyStatus(
            _badgeModelController.controller,
            _user
        );
        if (
            verifyStatus.initialized == true &&
            verifyStatus.verificationStatus == LibTheBadgeUsers.VerificationStatus.Verified
        ) {
            return true;
        }
        return false;
    }

    /**
     * =========================
     * Setters
     * =========================
     */

    /**
     * @notice Register a new user
     * @param _metadata IPFS url with the metadata of the user
     */
    function registerUser(string memory _metadata, bool _isCompany) public payable {
        TheBadgeUsersStore.User memory user = _badgeUsersStore.getUser(_msgSender());
        if (bytes(user.metadata).length != 0) {
            revert LibTheBadgeUsers.TheBadge__registerUser_alreadyRegistered();
        }

        uint256 registerUserProtocolFee = _badgeUsersStore.registerUserProtocolFee();
        if (msg.value != registerUserProtocolFee) {
            revert LibTheBadgeUsers.TheBadge__registerUser_wrongValue();
        }
        if (msg.value > 0) {
            address feeCollector = _badgeStore.feeCollector();
            payable(feeCollector).transfer(msg.value);
            emit PaymentMade(
                feeCollector,
                _msgSender(),
                msg.value,
                LibTheBadge.PaymentType.UserRegistrationFee,
                0,
                "0x"
            );
        }

        user.metadata = _metadata;
        user.isCompany = _isCompany;
        user.isCreator = false;
        user.suspended = false;
        user.initialized = true;

        _badgeUsersStore.createUser(_msgSender(), user);
        emit UserRegistered(_msgSender(), user.metadata);
    }

    /**
     * @notice Allows users to update their profile metadata
     * @param _metadata IPFS url
     */
    function updateProfile(string memory _metadata) public {
        TheBadgeUsersStore.User memory user = _badgeUsersStore.getUser(_msgSender());

        if (bytes(user.metadata).length == 0) {
            revert LibTheBadgeUsers.TheBadge__updateUser_notFound();
        }

        if (bytes(_metadata).length == 0) {
            revert LibTheBadgeUsers.TheBadge__updateUser_wrongMetadata();
        }

        user.metadata = _metadata;
        _badgeUsersStore.updateUser(_msgSender(), user);
        emit UpdatedUser(_msgSender(), user.metadata, user.suspended, user.isCreator, false);
    }

    /**
     * @notice Given an user and new metadata, updates the metadata of the user
     * @param _userAddress user address
     * @param _metadata IPFS url
     */
    function updateUser(address _userAddress, string memory _metadata) public onlyRole(USER_MANAGER_ROLE) {
        TheBadgeUsersStore.User memory user = _badgeUsersStore.getUser(_userAddress);

        if (bytes(user.metadata).length == 0) {
            revert LibTheBadgeUsers.TheBadge__updateUser_notFound();
        }

        if (bytes(_metadata).length == 0) {
            revert LibTheBadgeUsers.TheBadge__updateUser_wrongMetadata();
        }

        user.metadata = _metadata;
        _badgeUsersStore.updateUser(_userAddress, user);
        emit UpdatedUser(_userAddress, user.metadata, user.suspended, user.isCreator, false);
    }

    /**
     * @notice Suspends or remove the suspension to the user, avoiding him to create badge models
     * @param _userAddress user address
     * @param suspended boolean
     */
    function suspendUser(address _userAddress, bool suspended) public onlyRole(PAUSER_ROLE) {
        TheBadgeUsersStore.User memory user = _badgeUsersStore.getUser(_userAddress);

        if (bytes(user.metadata).length == 0) {
            revert LibTheBadgeUsers.TheBadge__updateUser_notFound();
        }

        user.suspended = suspended;
        _badgeUsersStore.updateUser(_userAddress, user);
        emit UpdatedUser(_userAddress, user.metadata, suspended, user.isCreator, false);
    }

    /**
     * @notice Given an user, sets him as creator
     * @param _userAddress user address
     */
    function makeUserCreator(address _userAddress) public onlyRole(USER_MANAGER_ROLE) {
        TheBadgeUsersStore.User memory user = _badgeUsersStore.getUser(_userAddress);

        if (bytes(user.metadata).length == 0) {
            revert LibTheBadgeUsers.TheBadge__updateUser_notFound();
        }

        if (user.isCreator == true) {
            revert LibTheBadgeUsers.TheBadge__onlyCreator_senderIsAlreadyACreator();
        }

        user.isCreator = true;
        _badgeUsersStore.updateUser(_userAddress, user);
        emit UpdatedUser(_userAddress, user.metadata, user.suspended, user.isCreator, false);
    }

    /**
     * @notice Creates a request to Verify an user on behalf of the user
     * @param controllerName the controller to verify the user
     * @param evidenceUri IPFS uri with the evidence required for the verification
     */
    function submitUserVerification(
        address userToVerify,
        string memory controllerName,
        string memory evidenceUri
    )
        public
        payable
        onlyRole(VERIFIER_ROLE)
        onlyRegisteredUser(userToVerify)
        existingBadgeModelController(controllerName)
        nonReentrant
    {
        submitUserVerificationLogic(userToVerify, controllerName, evidenceUri);
    }

    /**
     * @notice Creates a request to Verify an user in an specific badgeModelController
     * @param evidenceUri IPFS uri with the evidence required for the verification
     */
    function submitUserVerification(
        string memory controllerName,
        string memory evidenceUri
    ) public payable onlyRegisteredUser(_msgSender()) existingBadgeModelController(controllerName) nonReentrant {
        submitUserVerificationLogic(_msgSender(), controllerName, evidenceUri);
    }

    /**
     * @notice Creates a request to Verify an user in an specific badgeModelController
     * @param _user user address to verify
     * @param controllerName id of the controller to execute the verification
     * @param verify true if the user should be verified, false otherwise
     */
    function executeUserVerification(
        address _user,
        string memory controllerName,
        bool verify
    ) public onlyRole(VERIFIER_ROLE) existingBadgeModelController(controllerName) onlyRegisteredUser(_user) {
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            controllerName
        );

        TheBadgeUsersStore.UserVerification memory _userVerification = _badgeUsersStore.getUserVerifyStatus(
            _badgeModelController.controller,
            _user
        );

        if (_userVerification.initialized == false) {
            revert LibTheBadgeUsers.TheBadge__verifyUser__userVerificationNotStarted();
        }

        LibTheBadgeUsers.VerificationStatus _verificationStatus = verify
            ? LibTheBadgeUsers.VerificationStatus.Verified
            : LibTheBadgeUsers.VerificationStatus.VerificationRejected;

        _badgeUsersStore.updateUserVerificationStatus(_badgeModelController.controller, _user, _verificationStatus);
        emit UserVerificationExecuted(_user, controllerName, verify);
    }

    /*
     * @notice Updates the value of the protocol: _registerCreatorValue
     * @param _registerCreatorValue the default fee that TheBadge protocol charges for each user registration (in bps)
     */
    function updateRegisterCreatorProtocolFee(uint256 _registerCreatorValue) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _badgeUsersStore.updateRegisterCreatorProtocolFee(_registerCreatorValue);
        emit ProtocolSettingsUpdated();
    }

    function submitUserVerificationLogic(
        address userToVerify,
        string memory controllerName,
        string memory evidenceUri
    ) internal {
        TheBadgeStore.BadgeModelController memory _badgeModelController = _badgeStore.getBadgeModelController(
            controllerName
        );
        TheBadgeUsersStore.User memory user = _badgeUsersStore.getUser(userToVerify);
        string memory _controllerName = controllerName;
        address feeCollector = _badgeStore.feeCollector();

        // The verification fee differs in each controller
        uint256 verifyCreatorProtocolFee = IBadgeModelController(_badgeModelController.controller)
            .getVerifyUserProtocolFee();

        if (msg.value != verifyCreatorProtocolFee) {
            revert LibTheBadgeUsers.TheBadge__verifyUser_wrongValue();
        }

        if (msg.value > 0) {
            // Transfers the verification fee to the collector
            (bool verifyCreatorProtocolFeeSent, ) = payable(feeCollector).call{ value: msg.value }("");
            if (verifyCreatorProtocolFeeSent == false) {
                revert LibTheBadgeUsers.TheBadge__verifyUser_verificationProtocolFeesPaymentFailed();
            }
            emit PaymentMade(
                feeCollector,
                userToVerify,
                msg.value,
                LibTheBadge.PaymentType.UserVerificationFee,
                0,
                _controllerName
            );
        }

        TheBadgeUsersStore.UserVerification memory _userVerification = _badgeUsersStore.getUserVerifyStatus(
            _badgeModelController.controller,
            userToVerify
        );

        if (_userVerification.initialized == true) {
            revert LibTheBadgeUsers.TheBadge__verifyUser__userVerificationAlreadyStarted();
        }

        _userVerification.user = userToVerify;
        _userVerification.userMetadata = user.metadata;
        _userVerification.verificationEvidence = evidenceUri;
        _userVerification.verificationStatus = LibTheBadgeUsers.VerificationStatus.VerificationSubmitted;
        _userVerification.verificationController = _badgeModelController.controller;
        _userVerification.initialized = true;

        _badgeUsersStore.createUserVerificationStatus(
            _badgeModelController.controller,
            userToVerify,
            _userVerification
        );
        emit UserVerificationRequested(userToVerify, evidenceUri, controllerName);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;

    // tslint:disable-next-line:no-empty
    receive() external payable {}
}


// Chain: POLYGON - File: src/contracts/thebadge/TheBadgeUsersStore.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { TheBadgeRoles } from "./TheBadgeRoles.sol";
import { LibTheBadgeUsers } from "../libraries/LibTheBadgeUsers.sol";
import { LibTheBadgeStore } from "../libraries/LibTheBadgeStore.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TheBadgeUsersStore is TheBadgeRoles, OwnableUpgradeable {
    /**
     * =========================
     * Events
     * =========================
     */

    // Event to log when a contract is added to the list
    event ContractAdded(string indexed _contractName, address indexed contractAddress);

    // Event to log when a contract is removed from the list
    event ContractRemoved(string indexed _contractName, address indexed contractAddress);

    // Event to log when a contract address is updated from the list
    event ContractUpdated(string indexed _contractName, address indexed contractAddress);

    /**
     * =========================
     * Modifiers
     * =========================
     */

    // Modifier to check if the caller is one of the allowedContractAddresses contracts
    modifier onlyPermittedContract() {
        if (allowedContractAddresses[_msgSender()] == false) {
            revert LibTheBadgeStore.TheBadge__Store_OperationNotPermitted();
        }

        _;
    }

    uint256 public registerUserProtocolFee;

    /**
     * =========================
     * Types
     * =========================
     */

    /**
     * @param metadata information related with the user.
     * @param isCompany true if the user is a company, otherwise is false (default value)
     * @param isCreator true if the user has created at least one badge model
     * @param suspended If true, the user is not allowed to do any actions and if it's a creator, their badges are not mintable anymore.
     * @param initialized When the struct is created its true, if the struct was never initialized, its false, used in validations
     */
    struct User {
        string metadata;
        bool isCompany;
        bool isCreator;
        bool suspended;
        bool initialized;
    }

    /**
     * @param user address of the user requested the verification
     * @param userMetadata ipfs hash of the metadata of the user
     * @param verificationEvidence ipfs hash of the metadata of the metadata uploaded as evidence to be verified
     * @param verificationStatus current status of the verification
     * @param verificationController address of the contract where it has been verified (thirdParty or community)
     * @param initialized When the struct is created its true, if the struct was never initialized, its false, used in validations
     */
    struct UserVerification {
        address user;
        string userMetadata;
        string verificationEvidence;
        LibTheBadgeUsers.VerificationStatus verificationStatus;
        address verificationController;
        bool initialized;
    }

    // Mapping to store contract addresses by name
    mapping(address => bool) public allowedContractAddresses;
    mapping(string => address) public allowedContractAddressesByContractName;
    mapping(address => User) public registeredUsers;
    mapping(address => mapping(address => UserVerification)) public verifiedUsersByControllerAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    // See https://docs.openzeppelin.com/learn/upgrading-smart-contracts#initialization
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __Ownable_init(admin);
        registerUserProtocolFee = uint256(0);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * =========================
     * Getters
     * =========================
     */
    function getUser(address userAddress) external view returns (User memory) {
        return registeredUsers[userAddress];
    }

    function getUserVerifyStatus(
        address controllerAddress,
        address userAddress
    ) external view returns (UserVerification memory) {
        return verifiedUsersByControllerAddress[controllerAddress][userAddress];
    }

    /**
     * =========================
     * Setters
     * =========================
     */
    function createUser(address userAddress, User calldata newUser) external onlyPermittedContract {
        User storage _user = registeredUsers[userAddress];
        if (_user.initialized == true) {
            revert LibTheBadgeUsers.TheBadge__registerUser_alreadyRegistered();
        }
        registeredUsers[userAddress] = newUser;
    }

    function updateUser(address userAddress, User calldata updatedUser) external onlyPermittedContract {
        User storage _user = registeredUsers[userAddress];
        if (_user.initialized == false) {
            revert LibTheBadgeUsers.TheBadge__updateUser_notFound();
        }
        registeredUsers[userAddress] = updatedUser;
    }

    /*
     * @notice Updates the value of the protocol: _registerCreatorValue
     * @param _registerCreatorValue the default fee that TheBadge protocol charges for each user registration (in bps)
     */
    function updateRegisterCreatorProtocolFee(uint256 _registerCreatorValue) public onlyPermittedContract {
        registerUserProtocolFee = _registerCreatorValue;
    }

    // Function to add a contract to the list of permitted contracts
    function addPermittedContract(
        string memory _contractName,
        address _contractAddress
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_contractAddress == address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidContractAddress();
        }

        // Check if the contract name already exists
        if (allowedContractAddressesByContractName[_contractName] != address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_ContractNameAlreadyExists();
        }

        // Add the contract name and address to the mapping
        allowedContractAddressesByContractName[_contractName] = _contractAddress;
        allowedContractAddresses[_contractAddress] = true;

        emit ContractAdded(_contractName, _contractAddress);
    }

    // Function to remove a contract from the list of permitted contracts
    function removePermittedContract(string memory _contractName) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address contractAddress = allowedContractAddressesByContractName[_contractName];

        // Check if the contract name exists in the mapping
        if (contractAddress == address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidContractName();
        }

        // Remove the contract name and address from the mapping
        delete allowedContractAddressesByContractName[_contractName];
        delete allowedContractAddresses[contractAddress];

        emit ContractRemoved(_contractName, contractAddress);
    }

    // Function to update a contract address based on the contract name
    function updatePermittedContract(
        string memory _contractName,
        address _newContractAddress
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newContractAddress == address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidContractAddress();
        }

        // Check if the contract name exists in the mapping
        address oldContractAddress = allowedContractAddressesByContractName[_contractName];
        if (oldContractAddress == address(0)) {
            revert LibTheBadgeStore.TheBadge__Store_InvalidContractName();
        }

        // Update the contract address associated with the contract name
        delete allowedContractAddresses[oldContractAddress];
        allowedContractAddressesByContractName[_contractName] = _newContractAddress;
        allowedContractAddresses[_newContractAddress] = true;

        emit ContractUpdated(_contractName, _newContractAddress);
    }

    /**
     * @notice Update a UserVerification details.
     * @param controllerAddress The address of the controller where the verification starts
     * @param userAddress the userAddress
     * @param user the new verification status of the user
     */
    function createUserVerificationStatus(
        address controllerAddress,
        address userAddress,
        UserVerification memory user
    ) external onlyPermittedContract {
        UserVerification memory _user = verifiedUsersByControllerAddress[controllerAddress][userAddress];

        if (_user.initialized == true) {
            revert LibTheBadgeUsers.TheBadge__registerUser_alreadyRegistered();
        }

        verifiedUsersByControllerAddress[controllerAddress][userAddress] = user;
    }

    /**
     * @notice Update a UserVerification details.
     * @param controllerAddress The address of the controller where the verification starts
     * @param userAddress the userAddress
     * @param _verificationStatus the new verification status of the user
     */
    function updateUserVerificationStatus(
        address controllerAddress,
        address userAddress,
        LibTheBadgeUsers.VerificationStatus _verificationStatus
    ) external onlyPermittedContract {
        UserVerification memory _user = verifiedUsersByControllerAddress[controllerAddress][userAddress];
        if (_user.initialized == false) {
            revert LibTheBadgeUsers.TheBadge__onlyUser_userNotFound();
        }
        _user.verificationStatus = _verificationStatus;
        verifiedUsersByControllerAddress[controllerAddress][userAddress] = _user;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;

    // tslint:disable-next-line:no-empty
    receive() external payable {}
}


// Chain: POLYGON - File: src/interfaces/IBadgeModelController.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

interface IBadgeModelController {
    // Write
    function createBadgeModel(address callee, uint256 badgeModelId, bytes calldata data) external;

    function mint(
        address callee,
        uint256 badgeModelId,
        uint256 badgeId,
        bytes calldata data,
        address destinationAddress
    ) external payable returns (uint256);

    function claim(uint256 badgeId, bytes calldata data, address caller) external returns (address);

    function challenge(uint256 badgeId, bytes calldata data, address caller) external payable;

    function removeItem(uint256 badgeId, bytes calldata data, address caller) external payable;

    function submitEvidence(uint256 badgeId, bytes calldata data, address caller) external;

    // Write methods

    function updateVerifyUserProtocolFee(uint256 _verifyUserProtocolFee) external;

    // Read
    function mintValue(uint256 badgeModelId) external view returns (uint256);

    function isMintableToController(uint256 badgeModelId, address account) external view returns (bool);

    function isClaimable(uint256 badgeId) external view returns (bool);

    function isAssetActive(uint256 badgeId) external view returns (bool);

    function getChallengeDepositValue(uint256 badgeId) external view returns (uint256);

    function getRemovalDepositValue(uint256 badgeId) external view returns (uint256);

    function getVerifyUserProtocolFee() external view returns (uint256);

    function isBadgeModelMetadataUpgradeable() external view returns (bool);

    function isBadgeModelMetadataUpdatable() external view returns (bool);

    function isAutomaticClaimable() external view returns (bool);
}


// Chain: POLYGON - File: src/interfaces/ITheBadge.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface ITheBadge is IERC1155 {
    // Write methods
    function mint(uint256 badgeModelId, address account, string memory tokenURI, bytes memory data) external payable;

    function mintInBatch(
        uint256[] memory badgeModelIds,
        address[] memory recipients,
        string[] memory tokenURIs,
        bytes[] memory data
    ) external payable;

    function claim(uint256 badgeId, bytes calldata data) external;

    function challenge(uint256 badgeId, bytes calldata data) external payable;

    function removeItem(uint256 badgeId, bytes calldata data) external payable;

    function submitEvidence(uint256 badgeId, bytes calldata data) external;

    function updateMintBadgeDefaultProtocolFee(uint256 _mintBadgeDefaultFee) external;

    function updateClaimBadgeProtocolFee(uint256 _claimProtocolFee) external;

    function updateCreateBadgeModelProtocolFee(uint256 _createBadgeModelValue) external;

    function pause() external;

    function unpause() external;

    // Read methods
    function balanceOf(address account, uint256 badgeId) external view returns (uint256);

    function balanceOfBadgeModel(address account, uint256 badgeModelId) external view returns (uint256);

    function isExpired(uint256 badgeId) external view returns (bool);

    function isClaimable(uint256 badgeId) external view returns (bool);

    function getChallengeDepositValue(uint256 badgeId) external view returns (uint256);

    function getRemovalDepositValue(uint256 badgeId) external view returns (uint256);

    function mintValue(uint256 badgeModelId) external returns (uint256);

    function uri(uint256 badgeId) external view returns (string memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// Chain: POLYGON - File: src/interfaces/ITheBadgeUsers.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { TheBadgeUsersStore } from "../contracts/thebadge/TheBadgeUsersStore.sol";

interface ITheBadgeUsers {
    // Read methods
    function getUser(address _user) external view returns (TheBadgeUsersStore.User memory);

    function getUserVerifyStatus(
        address controllerAddress,
        address userAddress
    ) external view returns (TheBadgeUsersStore.UserVerification memory);

    function getRegisterFee() external view returns (uint256);

    function getVerificationFee(string memory controllerName) external view returns (uint256);

    function isUserVerified(address _user, string memory controllerName) external view returns (bool);

    // Write methods
    function registerUser(string memory _metadata, bool _isCompany) external payable;

    function updateProfile(string memory _metadata) external;

    function updateUser(address _creator, string memory _metadata) external;

    function suspendUser(address _creator, bool suspended) external;

    function makeUserCreator(address _creator) external;

    function submitUserVerification(string memory controllerName, string memory evidenceUri) external payable;

    function executeUserVerification(address _user, string memory controllerName, bool verify) external;

    function updateRegisterCreatorProtocolFee(uint256 _registerCreatorValue) external;
}