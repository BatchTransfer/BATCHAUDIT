// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Modified registry based on ERC6551Registry
// https://github.com/erc6551/reference/blob/main/src/ERC6551Registry.sol

import {IERC7656Registry} from "./IERC7656Registry.sol";

contract ERC7656Registry is IERC7656Registry {
  function create(
    address implementation,
    bytes32 salt,
    uint256 /* chainId */,
    address tokenContract,
    uint256 tokenId
  ) external override returns (address) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      // Memory Layout:
      // ----
      // 0x00   0xff                           (1 byte)
      // 0x01   registry (address)             (20 bytes)
      // 0x15   salt (bytes32)                 (32 bytes)
      // 0x35   Bytecode Hash (bytes32)        (32 bytes)
      // ----
      // 0x55   ERC-1167 Constructor + Header  (20 bytes)
      // 0x69   implementation (address)       (20 bytes)
      // 0x5D   ERC-1167 Footer                (15 bytes)
      // 0x8C   salt (uint256)                 (32 bytes)
      // 0xAC   chainId (uint256)              (32 bytes)
      // 0xCC   tokenContract (address)        (32 bytes)
      // 0xEC   tokenId (uint256)              (32 bytes)

      // Copy bytecode + constant data to memory
      calldatacopy(0x8c, 0x24, 0x80) // salt, chainId, tokenContract, tokenId
      mstore(0x6c, 0x5af43d82803e903d91602b57fd5bf3) // ERC-1167 footer
      mstore(0x5d, implementation) // implementation
      mstore(0x49, 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73) // ERC-1167 constructor + header

      // Copy create2 computation data to memory
      mstore8(0x00, 0xff) // 0xFF
      mstore(0x35, keccak256(0x55, 0xb7)) // keccak256(bytecode)
      mstore(0x01, shl(96, address())) // registry address
      mstore(0x15, salt) // salt

      // Compute account address
      let computed := keccak256(0x00, 0x55)

      // If the account has not yet been deployed
      if iszero(extcodesize(computed)) {
        // Deploy account contract
        let deployed := create2(0, 0x55, 0xb7, salt)

        // Revert if the deployment fails
        if iszero(deployed) {
          mstore(0x00, 0xd786d393) // `CreationFailed()`
          revert(0x1c, 0x04)
        }

        // Store account address in memory before salt and chainId
        mstore(0x6c, deployed)

        // Emit the Created event
        log4(
          0x6c,
          0x60,
          0xc6989e4f290074742210cbd6491de7ded9cfe2cd247932a53d31005007a6341a,
          implementation,
          tokenContract,
          tokenId
        )

        // Return the account address
        return(0x6c, 0x20)
      }

      // Otherwise, return the computed account address
      mstore(0x00, shr(96, shl(96, computed)))
      return(0x00, 0x20)
    }
  }

  function compute(
    address implementation,
    bytes32 salt,
    uint256 /* chainId */,
    address /* tokenContract */,
    uint256 /* tokenId */
  ) external view override returns (address) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      // Copy bytecode + constant data to memory
      calldatacopy(0x8c, 0x24, 0x80) // salt, chainId, tokenContract, tokenId
      mstore(0x6c, 0x5af43d82803e903d91602b57fd5bf3) // ERC-1167 footer
      mstore(0x5d, implementation) // implementation
      mstore(0x49, 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73) // ERC-1167 constructor + header

      // Copy create2 computation data to memory
      mstore8(0x00, 0xff) // 0xFF
      mstore(0x35, keccak256(0x55, 0xb7)) // keccak256(bytecode)
      mstore(0x01, shl(96, address())) // registry address
      mstore(0x15, salt) // salt

      // Store computed account address in memory
      mstore(0x00, shr(96, shl(96, keccak256(0x00, 0x55))))

      // Return computed account address
      return(0x00, 0x20)
    }
  }

  /// @dev Returns true if interfaceId is IERC7656Registry's interfaceId
  /// This contract does not explicitly extend IERC165 to keep the bytecode as small as possible
  function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
    return interfaceId == 0xc6bdc908;
  }
}

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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ContextUpgradeable} from "../../utils/ContextUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20, IERC20Metadata, IERC20Errors {
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC20
    struct ERC20Storage {
        mapping(address account => uint256) _balances;

        mapping(address account => mapping(address spender => uint256)) _allowances;

        uint256 _totalSupply;

        string _name;
        string _symbol;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        ERC20Storage storage $ = _getERC20Storage();
        $._name = name_;
        $._symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._symbol;
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
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
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
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            $._totalSupply += value;
        } else {
            uint256 fromBalance = $._balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                $._balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                $._totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                $._balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
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
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        $._allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC20Permit.sol)

pragma solidity ^0.8.20;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC20Upgradeable} from "../ERC20Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "../../../utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "../../../utils/NoncesUpgradeable.sol";
import {Initializable} from "../../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
abstract contract ERC20PermitUpgradeable is Initializable, ERC20Upgradeable, IERC20Permit, EIP712Upgradeable, NoncesUpgradeable {
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    /**
     * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
     *
     * It's a good idea to use the same `name` that is defined as the ERC20 token name.
     */
    function __ERC20Permit_init(string memory name) internal onlyInitializing {
        __EIP712_init_unchained(name, "1");
    }

    function __ERC20Permit_init_unchained(string memory) internal onlyInitializing {}

    /**
     * @inheritdoc IERC20Permit
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        _approve(owner, spender, value);
    }

    /**
     * @inheritdoc IERC20Permit
     */
    function nonces(address owner) public view virtual override(IERC20Permit, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    /**
     * @inheritdoc IERC20Permit
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/EIP712.sol)

pragma solidity ^0.8.20;

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC5267} from "@openzeppelin/contracts/interfaces/IERC5267.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding scheme specified in the EIP requires a domain separator and a hash of the typed structured data, whose
 * encoding is very generic and therefore its implementation in Solidity is not feasible, thus this contract
 * does not implement the encoding itself. Protocols need to implement the type-specific encoding they need in order to
 * produce the hash of their typed data using a combination of `abi.encode` and `keccak256`.
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
 * separator of the implementation contract. This will cause the {_domainSeparatorV4} function to always rebuild the
 * separator from the immutable values, which is cheaper than accessing a cached version in cold storage.
 */
abstract contract EIP712Upgradeable is Initializable, IERC5267 {
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @custom:storage-location erc7201:openzeppelin.storage.EIP712
    struct EIP712Storage {
        /// @custom:oz-renamed-from _HASHED_NAME
        bytes32 _hashedName;
        /// @custom:oz-renamed-from _HASHED_VERSION
        bytes32 _hashedVersion;

        string _name;
        string _version;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.EIP712")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant EIP712StorageLocation = 0xa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d100;

    function _getEIP712Storage() private pure returns (EIP712Storage storage $) {
        assembly {
            $.slot := EIP712StorageLocation
        }
    }

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
    function __EIP712_init(string memory name, string memory version) internal onlyInitializing {
        __EIP712_init_unchained(name, version);
    }

    function __EIP712_init_unchained(string memory name, string memory version) internal onlyInitializing {
        EIP712Storage storage $ = _getEIP712Storage();
        $._name = name;
        $._version = version;

        // Reset prior values in storage if upgrading
        $._hashedName = 0;
        $._hashedVersion = 0;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return _buildDomainSeparator();
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash(), block.chainid, address(this)));
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
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev See {IERC-5267}.
     */
    function eip712Domain()
        public
        view
        virtual
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
        EIP712Storage storage $ = _getEIP712Storage();
        // If the hashed name and version in storage are non-zero, the contract hasn't been properly initialized
        // and the EIP712 domain is not reliable, as it will be missing name and version.
        require($._hashedName == 0 && $._hashedVersion == 0, "EIP712: Uninitialized");

        return (
            hex"0f", // 01111
            _EIP712Name(),
            _EIP712Version(),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    /**
     * @dev The name parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712Name() internal view virtual returns (string memory) {
        EIP712Storage storage $ = _getEIP712Storage();
        return $._name;
    }

    /**
     * @dev The version parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712Version() internal view virtual returns (string memory) {
        EIP712Storage storage $ = _getEIP712Storage();
        return $._version;
    }

    /**
     * @dev The hash of the name parameter for the EIP712 domain.
     *
     * NOTE: In previous versions this function was virtual. In this version you should override `_EIP712Name` instead.
     */
    function _EIP712NameHash() internal view returns (bytes32) {
        EIP712Storage storage $ = _getEIP712Storage();
        string memory name = _EIP712Name();
        if (bytes(name).length > 0) {
            return keccak256(bytes(name));
        } else {
            // If the name is empty, the contract may have been upgraded without initializing the new storage.
            // We return the name hash in storage if non-zero, otherwise we assume the name is empty by design.
            bytes32 hashedName = $._hashedName;
            if (hashedName != 0) {
                return hashedName;
            } else {
                return keccak256("");
            }
        }
    }

    /**
     * @dev The hash of the version parameter for the EIP712 domain.
     *
     * NOTE: In previous versions this function was virtual. In this version you should override `_EIP712Version` instead.
     */
    function _EIP712VersionHash() internal view returns (bytes32) {
        EIP712Storage storage $ = _getEIP712Storage();
        string memory version = _EIP712Version();
        if (bytes(version).length > 0) {
            return keccak256(bytes(version));
        } else {
            // If the version is empty, the contract may have been upgraded without initializing the new storage.
            // We return the version hash in storage if non-zero, otherwise we assume the version is empty by design.
            bytes32 hashedVersion = $._hashedVersion;
            if (hashedVersion != 0) {
                return hashedVersion;
            } else {
                return keccak256("");
            }
        }
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Nonces.sol)
pragma solidity ^0.8.20;
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Provides tracking nonces for addresses. Nonces will only increment.
 */
abstract contract NoncesUpgradeable is Initializable {
    /**
     * @dev The nonce used for an `account` is not the expected current nonce.
     */
    error InvalidAccountNonce(address account, uint256 currentNonce);

    /// @custom:storage-location erc7201:openzeppelin.storage.Nonces
    struct NoncesStorage {
        mapping(address account => uint256) _nonces;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Nonces")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NoncesStorageLocation = 0x5ab42ced628888259c08ac98db1eb0cf702fc1501344311d8b100cd1bfe4bb00;

    function _getNoncesStorage() private pure returns (NoncesStorage storage $) {
        assembly {
            $.slot := NoncesStorageLocation
        }
    }

    function __Nonces_init() internal onlyInitializing {
    }

    function __Nonces_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Returns the next unused nonce for an address.
     */
    function nonces(address owner) public view virtual returns (uint256) {
        NoncesStorage storage $ = _getNoncesStorage();
        return $._nonces[owner];
    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    function _useNonce(address owner) internal virtual returns (uint256) {
        NoncesStorage storage $ = _getNoncesStorage();
        // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
        // decremented or reset. This guarantees that the nonce never overflows.
        unchecked {
            // It is important to do x++ and not ++x here.
            return $._nonces[owner]++;
        }
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
     */
    function _useCheckedNonce(address owner, uint256 nonce) internal virtual {
        uint256 current = _useNonce(owner);
        if (nonce != current) {
            revert InvalidAccountNonce(owner, current);
        }
    }
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

pragma solidity ^0.8.20;

import {IAccessControl} from "./IAccessControl.sol";
import {Context} from "../utils/Context.sol";
import {ERC165} from "../utils/introspection/ERC165.sol";

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
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
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
        return _roles[role].hasRole[account];
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
        return _roles[role].adminRole;
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
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
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
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
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
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (governance/TimelockController.sol)

pragma solidity ^0.8.20;

import {AccessControl} from "../access/AccessControl.sol";
import {ERC721Holder} from "../token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "../token/ERC1155/utils/ERC1155Holder.sol";
import {Address} from "../utils/Address.sol";

/**
 * @dev Contract module which acts as a timelocked controller. When set as the
 * owner of an `Ownable` smart contract, it enforces a timelock on all
 * `onlyOwner` maintenance operations. This gives time for users of the
 * controlled contract to exit before a potentially dangerous maintenance
 * operation is applied.
 *
 * By default, this contract is self administered, meaning administration tasks
 * have to go through the timelock process. The proposer (resp executor) role
 * is in charge of proposing (resp executing) operations. A common use case is
 * to position this {TimelockController} as the owner of a smart contract, with
 * a multisig or a DAO as the sole proposer.
 */
contract TimelockController is AccessControl, ERC721Holder, ERC1155Holder {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    uint256 internal constant _DONE_TIMESTAMP = uint256(1);

    mapping(bytes32 id => uint256) private _timestamps;
    uint256 private _minDelay;

    enum OperationState {
        Unset,
        Waiting,
        Ready,
        Done
    }

    /**
     * @dev Mismatch between the parameters length for an operation call.
     */
    error TimelockInvalidOperationLength(uint256 targets, uint256 payloads, uint256 values);

    /**
     * @dev The schedule operation doesn't meet the minimum delay.
     */
    error TimelockInsufficientDelay(uint256 delay, uint256 minDelay);

    /**
     * @dev The current state of an operation is not as required.
     * The `expectedStates` is a bitmap with the bits enabled for each OperationState enum position
     * counting from right to left.
     *
     * See {_encodeStateBitmap}.
     */
    error TimelockUnexpectedOperationState(bytes32 operationId, bytes32 expectedStates);

    /**
     * @dev The predecessor to an operation not yet done.
     */
    error TimelockUnexecutedPredecessor(bytes32 predecessorId);

    /**
     * @dev The caller account is not authorized.
     */
    error TimelockUnauthorizedCaller(address caller);

    /**
     * @dev Emitted when a call is scheduled as part of operation `id`.
     */
    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );

    /**
     * @dev Emitted when a call is performed as part of operation `id`.
     */
    event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data);

    /**
     * @dev Emitted when new proposal is scheduled with non-zero salt.
     */
    event CallSalt(bytes32 indexed id, bytes32 salt);

    /**
     * @dev Emitted when operation `id` is cancelled.
     */
    event Cancelled(bytes32 indexed id);

    /**
     * @dev Emitted when the minimum delay for future operations is modified.
     */
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    /**
     * @dev Initializes the contract with the following parameters:
     *
     * - `minDelay`: initial minimum delay in seconds for operations
     * - `proposers`: accounts to be granted proposer and canceller roles
     * - `executors`: accounts to be granted executor role
     * - `admin`: optional account to be granted admin role; disable with zero address
     *
     * IMPORTANT: The optional admin can aid with initial configuration of roles after deployment
     * without being subject to delay, but this role should be subsequently renounced in favor of
     * administration through timelocked proposals. Previous versions of this contract would assign
     * this admin to the deployer automatically and should be renounced as well.
     */
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin) {
        // self administration
        _grantRole(DEFAULT_ADMIN_ROLE, address(this));

        // optional admin
        if (admin != address(0)) {
            _grantRole(DEFAULT_ADMIN_ROLE, admin);
        }

        // register proposers and cancellers
        for (uint256 i = 0; i < proposers.length; ++i) {
            _grantRole(PROPOSER_ROLE, proposers[i]);
            _grantRole(CANCELLER_ROLE, proposers[i]);
        }

        // register executors
        for (uint256 i = 0; i < executors.length; ++i) {
            _grantRole(EXECUTOR_ROLE, executors[i]);
        }

        _minDelay = minDelay;
        emit MinDelayChange(0, minDelay);
    }

    /**
     * @dev Modifier to make a function callable only by a certain role. In
     * addition to checking the sender's role, `address(0)` 's role is also
     * considered. Granting a role to `address(0)` is equivalent to enabling
     * this role for everyone.
     */
    modifier onlyRoleOrOpenRole(bytes32 role) {
        if (!hasRole(role, address(0))) {
            _checkRole(role, _msgSender());
        }
        _;
    }

    /**
     * @dev Contract might receive/hold ETH as part of the maintenance process.
     */
    receive() external payable {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns whether an id corresponds to a registered operation. This
     * includes both Waiting, Ready, and Done operations.
     */
    function isOperation(bytes32 id) public view returns (bool) {
        return getOperationState(id) != OperationState.Unset;
    }

    /**
     * @dev Returns whether an operation is pending or not. Note that a "pending" operation may also be "ready".
     */
    function isOperationPending(bytes32 id) public view returns (bool) {
        OperationState state = getOperationState(id);
        return state == OperationState.Waiting || state == OperationState.Ready;
    }

    /**
     * @dev Returns whether an operation is ready for execution. Note that a "ready" operation is also "pending".
     */
    function isOperationReady(bytes32 id) public view returns (bool) {
        return getOperationState(id) == OperationState.Ready;
    }

    /**
     * @dev Returns whether an operation is done or not.
     */
    function isOperationDone(bytes32 id) public view returns (bool) {
        return getOperationState(id) == OperationState.Done;
    }

    /**
     * @dev Returns the timestamp at which an operation becomes ready (0 for
     * unset operations, 1 for done operations).
     */
    function getTimestamp(bytes32 id) public view virtual returns (uint256) {
        return _timestamps[id];
    }

    /**
     * @dev Returns operation state.
     */
    function getOperationState(bytes32 id) public view virtual returns (OperationState) {
        uint256 timestamp = getTimestamp(id);
        if (timestamp == 0) {
            return OperationState.Unset;
        } else if (timestamp == _DONE_TIMESTAMP) {
            return OperationState.Done;
        } else if (timestamp > block.timestamp) {
            return OperationState.Waiting;
        } else {
            return OperationState.Ready;
        }
    }

    /**
     * @dev Returns the minimum delay in seconds for an operation to become valid.
     *
     * This value can be changed by executing an operation that calls `updateDelay`.
     */
    function getMinDelay() public view virtual returns (uint256) {
        return _minDelay;
    }

    /**
     * @dev Returns the identifier of an operation containing a single
     * transaction.
     */
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure virtual returns (bytes32) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    /**
     * @dev Returns the identifier of an operation containing a batch of
     * transactions.
     */
    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) public pure virtual returns (bytes32) {
        return keccak256(abi.encode(targets, values, payloads, predecessor, salt));
    }

    /**
     * @dev Schedule an operation containing a single transaction.
     *
     * Emits {CallSalt} if salt is nonzero, and {CallScheduled}.
     *
     * Requirements:
     *
     * - the caller must have the 'proposer' role.
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual onlyRole(PROPOSER_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        _schedule(id, delay);
        emit CallScheduled(id, 0, target, value, data, predecessor, delay);
        if (salt != bytes32(0)) {
            emit CallSalt(id, salt);
        }
    }

    /**
     * @dev Schedule an operation containing a batch of transactions.
     *
     * Emits {CallSalt} if salt is nonzero, and one {CallScheduled} event per transaction in the batch.
     *
     * Requirements:
     *
     * - the caller must have the 'proposer' role.
     */
    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual onlyRole(PROPOSER_ROLE) {
        if (targets.length != values.length || targets.length != payloads.length) {
            revert TimelockInvalidOperationLength(targets.length, payloads.length, values.length);
        }

        bytes32 id = hashOperationBatch(targets, values, payloads, predecessor, salt);
        _schedule(id, delay);
        for (uint256 i = 0; i < targets.length; ++i) {
            emit CallScheduled(id, i, targets[i], values[i], payloads[i], predecessor, delay);
        }
        if (salt != bytes32(0)) {
            emit CallSalt(id, salt);
        }
    }

    /**
     * @dev Schedule an operation that is to become valid after a given delay.
     */
    function _schedule(bytes32 id, uint256 delay) private {
        if (isOperation(id)) {
            revert TimelockUnexpectedOperationState(id, _encodeStateBitmap(OperationState.Unset));
        }
        uint256 minDelay = getMinDelay();
        if (delay < minDelay) {
            revert TimelockInsufficientDelay(delay, minDelay);
        }
        _timestamps[id] = block.timestamp + delay;
    }

    /**
     * @dev Cancel an operation.
     *
     * Requirements:
     *
     * - the caller must have the 'canceller' role.
     */
    function cancel(bytes32 id) public virtual onlyRole(CANCELLER_ROLE) {
        if (!isOperationPending(id)) {
            revert TimelockUnexpectedOperationState(
                id,
                _encodeStateBitmap(OperationState.Waiting) | _encodeStateBitmap(OperationState.Ready)
            );
        }
        delete _timestamps[id];

        emit Cancelled(id);
    }

    /**
     * @dev Execute an (ready) operation containing a single transaction.
     *
     * Emits a {CallExecuted} event.
     *
     * Requirements:
     *
     * - the caller must have the 'executor' role.
     */
    // This function can reenter, but it doesn't pose a risk because _afterCall checks that the proposal is pending,
    // thus any modifications to the operation during reentrancy should be caught.
    // slither-disable-next-line reentrancy-eth
    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual onlyRoleOrOpenRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperation(target, value, payload, predecessor, salt);

        _beforeCall(id, predecessor);
        _execute(target, value, payload);
        emit CallExecuted(id, 0, target, value, payload);
        _afterCall(id);
    }

    /**
     * @dev Execute an (ready) operation containing a batch of transactions.
     *
     * Emits one {CallExecuted} event per transaction in the batch.
     *
     * Requirements:
     *
     * - the caller must have the 'executor' role.
     */
    // This function can reenter, but it doesn't pose a risk because _afterCall checks that the proposal is pending,
    // thus any modifications to the operation during reentrancy should be caught.
    // slither-disable-next-line reentrancy-eth
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual onlyRoleOrOpenRole(EXECUTOR_ROLE) {
        if (targets.length != values.length || targets.length != payloads.length) {
            revert TimelockInvalidOperationLength(targets.length, payloads.length, values.length);
        }

        bytes32 id = hashOperationBatch(targets, values, payloads, predecessor, salt);

        _beforeCall(id, predecessor);
        for (uint256 i = 0; i < targets.length; ++i) {
            address target = targets[i];
            uint256 value = values[i];
            bytes calldata payload = payloads[i];
            _execute(target, value, payload);
            emit CallExecuted(id, i, target, value, payload);
        }
        _afterCall(id);
    }

    /**
     * @dev Execute an operation's call.
     */
    function _execute(address target, uint256 value, bytes calldata data) internal virtual {
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        Address.verifyCallResult(success, returndata);
    }

    /**
     * @dev Checks before execution of an operation's calls.
     */
    function _beforeCall(bytes32 id, bytes32 predecessor) private view {
        if (!isOperationReady(id)) {
            revert TimelockUnexpectedOperationState(id, _encodeStateBitmap(OperationState.Ready));
        }
        if (predecessor != bytes32(0) && !isOperationDone(predecessor)) {
            revert TimelockUnexecutedPredecessor(predecessor);
        }
    }

    /**
     * @dev Checks after execution of an operation's calls.
     */
    function _afterCall(bytes32 id) private {
        if (!isOperationReady(id)) {
            revert TimelockUnexpectedOperationState(id, _encodeStateBitmap(OperationState.Ready));
        }
        _timestamps[id] = _DONE_TIMESTAMP;
    }

    /**
     * @dev Changes the minimum timelock duration for future operations.
     *
     * Emits a {MinDelayChange} event.
     *
     * Requirements:
     *
     * - the caller must be the timelock itself. This can only be achieved by scheduling and later executing
     * an operation where the timelock is the target and the data is the ABI-encoded call to this function.
     */
    function updateDelay(uint256 newDelay) external virtual {
        address sender = _msgSender();
        if (sender != address(this)) {
            revert TimelockUnauthorizedCaller(sender);
        }
        emit MinDelayChange(_minDelay, newDelay);
        _minDelay = newDelay;
    }

    /**
     * @dev Encodes a `OperationState` into a `bytes32` representation where each bit enabled corresponds to
     * the underlying position in the `OperationState` enum. For example:
     *
     * 0x000...1000
     *   ^^^^^^----- ...
     *         ^---- Done
     *          ^--- Ready
     *           ^-- Waiting
     *            ^- Unset
     */
    function _encodeStateBitmap(OperationState operationState) internal pure returns (bytes32) {
        return bytes32(1 << uint8(operationState));
    }
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC5267.sol)

pragma solidity ^0.8.20;

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
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/utils/ERC1155Holder.sol)

pragma solidity ^0.8.20;

import {IERC165, ERC165} from "../../../utils/introspection/ERC165.sol";
import {IERC1155Receiver} from "../IERC1155Receiver.sol";

/**
 * @dev Simple implementation of `IERC1155Receiver` that will allow a contract to hold ERC1155 tokens.
 *
 * IMPORTANT: When inheriting this contract, you must include a way to use the received tokens, otherwise they will be
 * stuck.
 */
abstract contract ERC1155Holder is ERC165, IERC1155Receiver {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";
import {IERC20Metadata} from "./extensions/IERC20Metadata.sol";
import {Context} from "../../utils/Context.sol";
import {IERC20Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
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
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
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
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
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
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.20;

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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

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
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.20;

import {IERC721} from "./IERC721.sol";
import {IERC721Receiver} from "./IERC721Receiver.sol";
import {IERC721Metadata} from "./extensions/IERC721Metadata.sol";
import {Context} from "../../utils/Context.sol";
import {Strings} from "../../utils/Strings.sol";
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";
import {IERC721Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
abstract contract ERC721 is Context, ERC165, IERC721, IERC721Metadata, IERC721Errors {
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    mapping(uint256 tokenId => address) private _owners;

    mapping(address owner => uint256) private _balances;

    mapping(uint256 tokenId => address) private _tokenApprovals;

    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender());
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);

        return _getApproved(tokenId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        // Setting an "auth" arguments enables the `_isAuthorized` check which verifies that the token exists
        // (from != 0). Therefore, it is not needed to verify that the return value is not 0 here.
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     *
     * IMPORTANT: Any overrides to this function that add ownership of tokens not tracked by the
     * core ERC721 logic MUST be matched with the use of {_increaseBalance} to keep balances
     * consistent with ownership. The invariant to preserve is that for any address `a` the value returned by
     * `balanceOf(a)` must be equal to the number of tokens such that `_ownerOf(tokenId)` is `a`.
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev Returns the approved address for `tokenId`. Returns 0 if `tokenId` is not minted.
     */
    function _getApproved(uint256 tokenId) internal view virtual returns (address) {
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `owner`'s tokens, or `tokenId` in
     * particular (ignoring whether it is owned by `owner`).
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _isAuthorized(address owner, address spender, uint256 tokenId) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender || isApprovedForAll(owner, spender) || _getApproved(tokenId) == spender);
    }

    /**
     * @dev Checks if `spender` can operate on `tokenId`, assuming the provided `owner` is the actual owner.
     * Reverts if `spender` does not have approval from the provided `owner` for the given token or for all its assets
     * the `spender` for the specific `tokenId`.
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal view virtual {
        if (!_isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            } else {
                revert ERC721InsufficientApproval(spender, tokenId);
            }
        }
    }

    /**
     * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
     *
     * NOTE: the value is limited to type(uint128).max. This protect against _balance overflow. It is unrealistic that
     * a uint256 would ever overflow from increments when these increments are bounded to uint128 values.
     *
     * WARNING: Increasing an account's balance using this function tends to be paired with an override of the
     * {_ownerOf} function to resolve the ownership of the corresponding tokens so that balances and ownership
     * remain consistent with one another.
     */
    function _increaseBalance(address account, uint128 value) internal virtual {
        unchecked {
            _balances[account] += value;
        }
    }

    /**
     * @dev Transfers `tokenId` from its current owner to `to`, or alternatively mints (or burns) if the current owner
     * (or `to`) is the zero address. Returns the owner of the `tokenId` before the update.
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that
     * `auth` is either the owner of the token, or approved to operate on the token (by the owner).
     *
     * Emits a {Transfer} event.
     *
     * NOTE: If overriding this function in a way that tracks balances, see also {_increaseBalance}.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        address from = _ownerOf(tokenId);

        // Perform (optional) operator check
        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }

        // Execute the update
        if (from != address(0)) {
            // Clear approval. No need to re-authorize or emit the Approval event
            _approve(address(0), tokenId, address(0), false);

            unchecked {
                _balances[from] -= 1;
            }
        }

        if (to != address(0)) {
            unchecked {
                _balances[to] += 1;
            }
        }

        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        return from;
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
    }

    /**
     * @dev Mints `tokenId`, transfers it to `to` and checks for `to` acceptance.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        _checkOnERC721Received(address(0), to, tokenId, data);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal {
        address previousOwner = _update(address(0), tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        } else if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking that contract recipients
     * are aware of the ERC721 standard to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is like {safeTransferFrom} in the sense that it invokes
     * {IERC721Receiver-onERC721Received} on the receiver, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `tokenId` token must exist and be owned by `from`.
     * - `to` cannot be the zero address.
     * - `from` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeTransfer-address-address-uint256-}[`_safeTransfer`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that `auth` is
     * either the owner of the token, or approved to operate on all tokens held by this owner.
     *
     * Emits an {Approval} event.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address to, uint256 tokenId, address auth) internal {
        _approve(to, tokenId, auth, true);
    }

    /**
     * @dev Variant of `_approve` with an optional flag to enable or disable the {Approval} event. The event is not
     * emitted in the context of transfers.
     */
    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal virtual {
        // Avoid reading the owner unless necessary
        if (emitEvent || auth != address(0)) {
            address owner = _requireOwned(tokenId);

            // We do not use _isAuthorized because single-token approvals should not be able to call approve
            if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
                revert ERC721InvalidApprover(auth);
            }

            if (emitEvent) {
                emit Approval(owner, to, tokenId);
            }
        }

        _tokenApprovals[tokenId] = to;
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Requirements:
     * - operator can't be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` doesn't have a current owner (it hasn't been minted, or it has been burned).
     * Returns the owner.
     *
     * Overrides to ownership logic should be done to {_ownerOf}.
     */
    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target address. This will revert if the
     * recipient doesn't accept the token transfer. The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.20;

import {IERC721} from "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.20;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.20;

import {IERC721Receiver} from "../IERC721Receiver.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or
 * {IERC721-setApprovalForAll}.
 */
abstract contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/EIP712.sol)

pragma solidity ^0.8.20;

import {MessageHashUtils} from "./MessageHashUtils.sol";
import {ShortStrings, ShortString} from "../ShortStrings.sol";
import {IERC5267} from "../../interfaces/IERC5267.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding scheme specified in the EIP requires a domain separator and a hash of the typed structured data, whose
 * encoding is very generic and therefore its implementation in Solidity is not feasible, thus this contract
 * does not implement the encoding itself. Protocols need to implement the type-specific encoding they need in order to
 * produce the hash of their typed data using a combination of `abi.encode` and `keccak256`.
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
 * separator of the implementation contract. This will cause the {_domainSeparatorV4} function to always rebuild the
 * separator from the immutable values, which is cheaper than accessing a cached version in cold storage.
 *
 * @custom:oz-upgrades-unsafe-allow state-variable-immutable
 */
abstract contract EIP712 is IERC5267 {
    using ShortStrings for *;

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

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
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
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
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev See {IERC-5267}.
     */
    function eip712Domain()
        public
        view
        virtual
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
            _EIP712Name(),
            _EIP712Version(),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    /**
     * @dev The name parameter for the EIP712 domain.
     *
     * NOTE: By default this function reads _name which is an immutable value.
     * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
     */
    // solhint-disable-next-line func-name-mixedcase
    function _EIP712Name() internal view returns (string memory) {
        return _name.toStringWithFallback(_nameFallback);
    }

    /**
     * @dev The version parameter for the EIP712 domain.
     *
     * NOTE: By default this function reads _version which is an immutable value.
     * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
     */
    // solhint-disable-next-line func-name-mixedcase
    function _EIP712Version() internal view returns (string memory) {
        return _version.toStringWithFallback(_versionFallback);
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "./IERC165.sol";

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
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";

/**
 * @title ERC6551AccountProxy
 * This version of ERC6551AccountProxy is modified to work with the OpenZeppelin Contracts v5
 * The original version (working with OZ v4.9.x) can be found in https://github.com/erc6551/reference
 */
contract ERC6551AccountProxy is Proxy {
  /**
   * @notice The default implementation of the contract
   */
  address public immutable DEFAULT_IMPLEMENTATION;

  /**
   * @notice Error returned when the implementation is invalid
   */
  error InvalidImplementation();

  /**
   * @notice The function that allows to receive ether and generic calls
   */
  receive() external payable virtual {
    _fallback();
  }

  /**
   * @notice Constructor
   * @param _defaultImplementation The default implementation of the contract
   */
  constructor(address _defaultImplementation) {
    if (_defaultImplementation == address(0)) revert InvalidImplementation();
    DEFAULT_IMPLEMENTATION = _defaultImplementation;
  }

  /**
   * @notice Returns the implementation of the contract
   */
  function _implementation() internal view virtual override returns (address) {
    address implementation = ERC1967Utils.getImplementation();
    if (implementation == address(0)) return DEFAULT_IMPLEMENTATION;
    return implementation;
  }

  /**
   * @notice Fallback function that redirect all the calls not in this proxy to the implementation
   */
  function _fallback() internal virtual override {
    if (msg.data.length == 0) {
      if (ERC1967Utils.getImplementation() == address(0)) {
        ERC1967Utils.upgradeToAndCall(DEFAULT_IMPLEMENTATION, "");
        _delegate(DEFAULT_IMPLEMENTATION);
      }
    } else {
      super._fallback();
    }
  }
}// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

import {IERC165, IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC6551AccountLib} from "erc6551/lib/ERC6551AccountLib.sol";

import {IERC7656Contract} from "./IERC7656Contract.sol";

//import "hardhat/console.sol";

/**
 * @title ERC7656Contract.sol
 * @notice Abstract contract to link a contract to an NFT
 */
abstract contract ERC7656Contract is IERC7656Contract, IERC165 {
  function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
    return interfaceId == type(IERC7656Contract).interfaceId;
  }

  /**
   * @notice Returns the token linked to the contract
   */
  function token() public view virtual override returns (uint256, address, uint256) {
    return ERC6551AccountLib.token();
  }

  /**
   * @notice Returns the owner of the token
   */
  function owner() public view virtual override returns (address) {
    (uint256 chainId, address tokenContract_, uint256 tokenId_) = ERC6551AccountLib.token();
    if (chainId != block.chainid) return address(0);
    return IERC721(tokenContract_).ownerOf(tokenId_);
  }

  /**
   * @notice Returns the address of the token contract
   */
  function tokenAddress() public view virtual override returns (address) {
    (, address tokenContract_, ) = ERC6551AccountLib.token();
    return tokenContract_;
  }

  /**
   * @notice Returns the tokenId of the token
   */
  function tokenId() public view virtual override returns (uint256) {
    (, , uint256 tokenId_) = ERC6551AccountLib.token();
    return tokenId_;
  }

  /**
   * @notice Returns the implementation used when creating the contract
   */
  function implementation() public view virtual override returns (address) {
    return ERC6551AccountLib.implementation();
  }

  // @dev This empty reserved space is put in place to allow future versions to add new
  // variables without shifting down storage in the inheritance chain.
  // See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps

  uint256[50] private __gap;
}// SPDX-License-Identifier: MIT

/**
 * @title EIP-6454 Minimalistic Non-Transferable interface for NFTs
 * @notice see https://eips.ethereum.org/EIPS/eip-6454
 * @notice Note: the ERC-165 identifier for this interface is 0x91a6262f.
 * @authors Bruno Škvorc (@Swader), Francesco Sullo (@sullof), Steven Pineda (@steven2308), Stevan Bogosavljevic (@stevyhacker), Jan Turk (@ThunderDeliverer)
 */

pragma solidity ^0.8.20;

interface IERC6454 {
  /**
   * @notice Used to check whether the given token is transferable or not.
   * @notice If this function returns `false`, the transfer of the token MUST revert execution.
   * If the tokenId does not exist, this method MUST revert execution, unless the token is being checked for
   *  minting.
   * The `from` parameter MAY be used to also validate the approval of the token for transfer, but anyone
   *  interacting with this function SHOULD NOT rely on it as it is not mandated by the proposal.
   * @param tokenId ID of the token being checked
   * @param from Address from which the token is being transferred
   * @param to Address to which the token is being transferred
   * @return Boolean value indicating whether the given token is transferable
   */

  function isTransferable(uint256 tokenId, address from, address to) external view returns (bool);
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

// ERC165 interfaceId 0x6b61a747
interface IERC6982 {
  /**
   * @notice MUST be emitted when the contract is deployed to establish the default lock status
   * for all tokens. Also, MUST be emitted again if the default lock status changes,
   * to ensure the default status for all tokens (without a specific `Locked` event) is updated.
   */
  event DefaultLocked(bool locked);

  /**
   * @notice MUST be emitted when the lock status of a specific token changes.
   * This status overrides the default lock status for that specific token.
   */
  event Locked(uint256 indexed tokenId, bool locked);

  /**
   * @notice Returns the current default lock status for tokens.
   * The returned value MUST reflect the status indicated by the most recent `DefaultLocked` event.
   */
  function defaultLocked() external view returns (bool);

  /**
   * @notice Returns the lock status of a specific token.
   * If no `Locked` event has been emitted for the token, it MUST return the current default lock status.
   * The function MUST revert if the token does not exist.
   */
  function locked(uint256 tokenId) external view returns (bool);
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// this is a reduction of IERC6551Account focusing purely on the bond between the NFT and the contract

/**
 * @title IERC7656Contract.sol
 */
interface IERC7656Contract {
  /**
   * @notice Returns the token linked to the contract
   * @return chainId The chainId of the token
   * @return tokenContract The address of the token contract
   * @return tokenId The tokenId of the token
   */
  function token() external view returns (uint256 chainId, address tokenContract, uint256 tokenId);

  /**
   * @notice Returns the owner of the token
   */
  function owner() external view returns (address);

  /**
   * @notice Returns the address of the token contract
   */
  function tokenAddress() external view returns (address);

  /**
   * @notice Returns the tokenId of the token
   */
  function tokenId() external view returns (uint256);

  /**
   * @notice Returns the implementation used when creating the contract
   */
  function implementation() external view returns (address);
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC7656
 * @dev Modified registry based on ERC6551Registry
 * https://github.com/erc6551/reference/blob/main/src/ERC6551Registry.sol
 *
 * The ERC165 interfaceId is 0xc6bdc908
 * @notice Manages the creation of token linked accounts
 */
interface IERC7656Registry {
  /**
   * @notice The registry MUST emit the Created event upon successful contract creation.
   * @param contractAddress The address of the created contract
   * @param implementation The address of the implementation contract
   * @param salt The salt to use for the create2 operation
   * @param chainId The chain id of the chain where the contract is being created
   * @param tokenContract The address of the token contract
   * @param tokenId The id of the token
   */
  event Created(
    address contractAddress,
    address indexed implementation,
    bytes32 salt,
    uint256 chainId,
    address indexed tokenContract,
    uint256 indexed tokenId
  );

  /**
   * The registry MUST revert with CreationFailed error if the create2 operation fails.
   */
  error CreationFailed();

  /**
   * @notice Creates a token linked account for a non-fungible token.
   * If account has already been created, returns the account address without calling create2.
   * @param implementation The address of the implementation contract
   * @param salt The salt to use for the create2 operation
   * @param chainId The chain id of the chain where the account is being created
   * @param tokenContract The address of the token contract
   * @param tokenId The id of the token
   * Emits Created event.
   * @return account The address of the token linked account
   */
  function create(
    address implementation,
    bytes32 salt,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId
  ) external returns (address account);

  /**
   * @notice Returns the computed token linked account address for a non-fungible token.
   * @param implementation The address of the implementation contract
   * @param salt The salt to use for the create2 operation
   * @param chainId The chain id of the chain where the account is being created
   * @param tokenContract The address of the token contract
   * @param tokenId The id of the token
   * @return account The address of the token linked account
   */
  function compute(
    address implementation,
    bytes32 salt,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId
  ) external view returns (address account);
}// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC6551Registry} from "erc6551/interfaces/IERC6551Registry.sol";

import {ICrunaGuardian} from "../guardian/ICrunaGuardian.sol";
import {IERC7656Registry} from "../erc/IERC7656Registry.sol";

/**
 * @title Canonical
 * @notice Returns the address where registries and guardian have been deployed
 * @dev There are two set of addresses. In both, the registry are on the same addresses, but
 * the guardian has a different address for testing and deployment to localhost (using the 2nd
 * and 3rd hardhat standard wallets as proposer and executor).
 * This contract is for development and testing purposes only. When the package is published
 * to Npm, the addresses will be replaced by the actual addresses of the deployed contracts.
 */
library Canonical {

  /**
   * @notice Returns the ERC7656Registry contract
   */
  function erc7656Registry() internal pure returns (IERC7656Registry) {
    return IERC7656Registry(0x7656CCCC1d93430f4E43A7ea0981C01469c9D6A2);
  }

  /**
   * @notice Returns the ERC6551Registry contract
   */
  function erc6551Registry() internal pure returns (IERC6551Registry) {
    return IERC6551Registry(0x000000006551c19487814612e58FE06813775758);
  }

  /**
   * @notice Returns the CrunaGuardian contract
   */
  function crunaGuardian() internal pure returns (ICrunaGuardian) {
    return ICrunaGuardian(0x1Dc4c2d07e19edffBAe2822eB6c02E90Fb8fB788);
  }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC6551AccountProxy} from "../erc/ERC6551AccountProxy.sol";

/**
 * @title CrunaManagerProxy
 * @notice Proxy contract for the CrunaManager
 */
contract CrunaManagerProxy is ERC6551AccountProxy {
  /**
   * @notice Constructor
   * @param _initialImplementation Address of the initial implementation
   */
  constructor(address _initialImplementation) ERC6551AccountProxy(_initialImplementation) {}
}// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

// Author: Francesco Sullo <francesco@sullo.co>

import {CrunaManagedService} from "../services/CrunaManagedService.sol";

import {IVersioned} from "../utils/IVersioned.sol";
import {IERC7656Contract} from "../erc/IERC7656Contract.sol";

interface ICrunaManager is IERC7656Contract, IVersioned {
  /**
   * @notice A struct to keep info about plugged and unplugged services
   * @param proxyAddress The address of the first implementation of the plugin
   * @param salt The salt used during the deployment of the plugin.
   * It allows to  have multiple instances of the same plugin
   * @param timeLock The time lock for when a plugin is temporarily unauthorized from making transfers
   * @param canManageTransfer True if the plugin can manage transfers
   * @param canBeReset True if the plugin requires a reset when the vault is transferred
   * @param active True if the plugin is active
   * @param isERC6551Account True if the plugin is an ERC6551 account
   * @param trusted True if the plugin is trusted
   * @param banned True if the plugin is banned during the unplug process
   * @param unplugged True if the plugin has been unplugged
   */
  struct PluginConfig {
    address proxyAddress;
    bytes4 salt;
    uint32 timeLock;
    bool canManageTransfer;
    bool canBeReset;
    bool active;
    bool isERC6551Account;
    bool trusted;
    bool banned;
    bool unplugged;
  }

  /**
   * @notice The plugin element
   * @param nameId The bytes4 of the hash of the name of the plugin
   * All services' names must be unique, as well as their bytes4 Ids
   * An official registry will be set up to avoid collisions when services
   * development will be more active. Using the proxy address as a key is
   * not viable because services can be upgraded and the address can change.
   * @param salt The salt of the plugin
   * @param active True if the plugin is active
   */
  struct PluginElement {
    bytes4 nameId;
    bytes4 salt;
    // redundant to optimize gas usage
    bool active;
  }

  /**
   * @notice It enumerates the action that can be performed when changing the status of a plugin
   */
  enum PluginChange {
    Plug,
    Unplug,
    Disable,
    ReEnable,
    Authorize,
    DeAuthorize,
    UnplugForever,
    Reset
  }

  /**
   * @notice Event emitted when the manager call to the NFT to emit a Locked event fails.
   */
  event EmitLockedEventFailed();

  /**
   * @notice Event emitted when the `status` of `protector` changes
   */
  event ProtectorChange(address indexed protector, bool status);

  /**
   * @notice Event emitted when protectors and safe recipients are imported from another token
   */
  event ProtectorsAndSafeRecipientsImported(address[] protectors, address[] safeRecipients, uint256 fromTokenId);

  /**
   * @notice Event emitted when the `status` of `recipient` changes
   */
  event SafeRecipientChange(address indexed recipient, bool status);

  /**
   * @notice Event emitted when
   * the status of plugin identified by `name` and `salt`, and deployed to `pluginAddress` gets a specific `change`
   */
  event PluginStatusChange(string indexed name, bytes4 salt, address pluginAddress, uint256 change);

  /**
   * @notice Emitted when protectors and safe recipients are removed and all services are disabled (if they require it)
   * This event overrides any specific ProtectorChange, SafeRecipientChange and PluginStatusChange event
   */
  event Reset();

  /**
   * @notice Emitted when a plugin initially plugged despite being not trusted, is trusted by the CrunaGuardian
   */
  event PluginTrusted(string indexed name, bytes4 salt);

  /**
   * @notice Emitted when the implementation of the manager is upgraded
   * @param implementation_ The address of the new implementation
   * @param oldVersion The old version of the manager
   * @param newVersion The new version of the manager
   */
  event ImplementationUpgraded(address indexed implementation_, uint256 oldVersion, uint256 newVersion);

  /**
   * @notice Event emitted when the attempt to reset a plugin fails
   * When this happens, the token owner can unplug the plugin and mark it as banned to avoid future re-plugs
   */
  event PluginResetAttemptFailed(bytes4 _nameId, bytes4 salt);

  /**
   * @notice Returned when trying to upgrade the manager to an untrusted implementation
   */
  error UntrustedImplementation(address implementation);

  /**
   * @notice Returned when trying to upgrade to an older version of the manager
   */
  error InvalidVersion(uint256 oldVersion, uint256 newVersion);

  /**
   * @notice Returned when trying to plug a plugin that requires a new version of the manager
   */
  error PluginRequiresUpdatedManager(uint256 requiredVersion);

  /**
   * @notice Returned when the sender has no right to execute a function
   */
  error Forbidden();

  /**
   * @notice Returned when the sender is not a manager
   */
  error NotAManager(address sender);

  /**
   * @notice Returned when a protector is not found
   */
  error ProtectorNotFound(address protector);

  /**
   * @notice Returned when a protector is already set by the sender
   */
  error ProtectorAlreadySetByYou(address protector);

  /**
   * @notice Returned when a protector is already set
   */
  error ProtectorsAlreadySet();

  /**
   * @notice Returned when trying to set themself as a protector
   */
  error CannotBeYourself();

  /**
   * @notice Returned when the managed transfer is called not by the right plugin
   */
  error NotTheAuthorizedPlugin(address callingPlugin);

  /**
   * @notice Returned when the pluggin service is not a managed service
   */
  error UnmanagedService();

  /**
   * @notice Returned when there is no more space for services
   */
  error PluginNumberOverflow();

  /**
   * @notice Returned when the plugin has been banned and marked as not pluggable
   */
  error PluginHasBeenMarkedAsNotPluggable();

  /**
   * @notice Returned when a plugin has already been plugged
   */
  error PluginAlreadyPlugged();

  /**
   * @notice Returned when a plugin is not found
   */
  error PluginNotFound();

  /**
   * @notice Returned when trying to plug an unplugged plugin and the address of the implementation differ
   */
  error InconsistentProxyAddresses(address currentAddress, address proposedAddress);

  /**
   * @notice Returned when a plugin is not found or is disabled
   */
  error PluginNotFoundOrDisabled();

  /**
   * @dev Returned when tryng to re-enable a not-disabled plugin
   */
  error PluginNotDisabled();

  /**
   * @dev Returned when trying to disable a plugin that is already disabled
   */
  error PluginAlreadyDisabled();

  /**
   * @dev Returned when a plugin tries to transfer the NFT without authorization
   */
  error PluginNotAuthorizedToManageTransfer();

  /**
   * @dev Returned when a plugin has already been authorized
   */
  error PluginAlreadyAuthorized();

  /**
   * @dev Returned when a plugin has already been unauthorized
   */
  error PluginAlreadyUnauthorized();

  /**
   * @dev Returned when a plugin is not authorized to make transfers
   */
  error NotATransferPlugin();

  /**
   * @dev Returned when trying to plug a plugin that responds to a different nameId
   */
  error InvalidImplementation(bytes4 nameIdReturnedByPlugin, bytes4 proposedNameId);

  /**
   * @dev Returned when setting an invalid TimeLock when temporarily de-authorizing a plugin
   */
  error InvalidTimeLock(uint256 timeLock);

  /**
   * @dev Returned when calling a function with a validity overflowing the maximum value
   */
  error InvalidValidity();

  /**
   * @dev Returned when plugging plugin as ERC6551 while the plugin is not an ERC6551 account, or vice versa
   */
  error InvalidERC6551Status();

  /**
   * @dev Returned when trying to make a transfer with an untrusted plugin, when the NFT accepts only trusted ones
   */
  error UntrustedImplementationsNotAllowedToMakeTransfers();

  /**
   * @dev Returned if trying to trust a plugin that is still untrusted
   */
  error StillUntrusted();

  /**
   * @dev Returned if a plugin has already been trusted
   */
  error PluginAlreadyTrusted();

  /**
   * @dev Returned when trying to import protectors and safe recipients from the token itself
   */
  error CannotImportProtectorsAndSafeRecipientsFromYourself();

  /**
   * @dev Returned when the owner of the exporter token is different from the owner of the importer token
   */
  error NotTheSameOwner(address originSOwner, address owner);

  /**
   * @dev Returned when some safe recipients have already been set
   */
  error SafeRecipientsAlreadySet();

  /**
   * @dev Returned when the origin token has no protectors and no safe recipients
   */
  error NothingToImport();

  /**
   * @dev Returned when trying to change the status of a plugin to an unsupported mode
   */
  error UnsupportedPluginChange();

  /**
   * @dev Returned when trying to get the index of a plugin in the allPlugins array, but that index is out of bounds
   */
  error IndexOutOfBounds();

  /**
   * @dev Returned when trying to use a function that requires protectors, but no protectors are set
   */
  error ToBeUsedOnlyWhenProtectorsAreActive();

  /**
   * @dev It returns the configuration of a plugin by key
   * @param key The key of the plugin
   */
  function pluginByKey(bytes8 key) external view returns (PluginConfig memory);

  /**
   * @dev It returns the configuration of all currently plugged services
   */
  function allPlugins() external view returns (PluginElement[] memory);

  /**
   * @dev It returns an element of the array of all plugged services
   * @param index The index of the plugin in the array
   */
  function pluginByIndex(uint256 index) external view returns (PluginElement memory);

  /**
   * @dev During an upgrade allows the manager to perform adjustments if necessary.
   * The parameter is the version of the manager being replaced. This will allow the
   * new manager to know what to do to adjust the state of the new manager.
   */
  function migrate(uint256 /* version */) external;

  /**
   * @dev Find a specific protector
   */
  function findProtectorIndex(address protector_) external view returns (uint256);

  /**
   * @dev Returns true if the address is a protector.
   * @param protector_ The protector address.
   */
  function isProtector(address protector_) external view returns (bool);

  /**
   * @dev Returns true if there are protectors.
   */
  function hasProtectors() external view returns (bool);

  /**
   * @dev Returns true if the token is transferable (since the NFT is ERC6454)
   * @param to The address of the recipient.
   * If the recipient is a safe recipient, it returns true.
   */
  function isTransferable(address to) external view returns (bool);

  /**
   * @dev Returns true if the token is locked (since the NFT is ERC6982)
   */
  function locked() external view returns (bool);

  /**
   * @dev Counts how many protectors have been set
   */
  function countProtectors() external view returns (uint256);

  /**
   * @dev Counts the safe recipients
   */
  function countSafeRecipients() external view returns (uint256);

  /**
   * @dev Set a protector for the token
   * @param protector_ The protector address
   * @param status True to add a protector, false to remove it
   * @param timestamp The timestamp of the signature
   * @param validFor The validity of the signature
   * @param signature The signature of the protector
   * If no signature is required, the field timestamp must be 0
   * If the operations has been pre-approved by the protector, the signature should be replaced
   * by a shorter (invalid) one, to tell the signature validator to look for a pre-approval.
   */
  function setProtector(
    address protector_,
    bool status,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external;

  /**
   * @dev Imports protectors and safe recipients from another tokenId owned by the same owner
   * It requires that there are no protectors and no safe recipients in the current token, and
   * that the origin token has at least one protector or one safe recipient.
   */
  function importProtectorsAndSafeRecipientsFrom(uint256 tokenId) external;

  /**
   * @dev get the list of all protectors
   */
  function getProtectors() external view returns (address[] memory);

  /**
   * @dev Set a safe recipient for the token, i.e., an address that can receive the token without any restriction
   * even when protectors have been set.
   * @param recipient The recipient address
   * @param status True to add a safe recipient, false to remove it
   * @param timestamp The timestamp of the signature
   * @param validFor The validity of the signature
   * @param signature The signature of the protector
   */
  function setSafeRecipient(
    address recipient,
    bool status,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external;

  /**
   * @dev Check if an address is a safe recipient
   * @param recipient The recipient address
   * @return True if the recipient is a safe recipient
   */
  function isSafeRecipient(address recipient) external view returns (bool);

  /**
   * @dev Gets all safe recipients
   * @return An array with the list of all safe recipients
   */
  function getSafeRecipients() external view returns (address[] memory);

  /**
   * @dev It plugs a new plugin
   * @param name The name of the plugin
   * @param pluginProxy The address of the plugin implementation
   * @param canManageTransfer True if the plugin can manage transfers
   * @param isERC6551Account True if the plugin is an ERC6551 account
   * @param salt The salt used during the deployment of the plugin
   * @param data The data to be used during the initialization of the plugin
   * Notice that data cannot be verified by the Manager since they are used by the plugin
   * @param timestamp The timestamp of the signature
   * @param validFor The validity of the signature
   * @param signature The signature of the protector
   */
  function plug(
    string memory name,
    address pluginProxy,
    bool canManageTransfer,
    bool isERC6551Account,
    bytes4 salt,
    bytes memory data,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external;

  /**
   * @dev It changes the status of a plugin
   * @param name The name of the plugin
   * @param salt The salt used during the deployment of the plugin
   * @param change The type of change
   * @param timeLock_ The time lock for when a plugin is temporarily unauthorized from making transfers
   * @param timestamp The timestamp of the signature
   * @param validFor The validity of the signature
   * @param signature The signature of the protector
   */
  function changePluginStatus(
    string memory name,
    bytes4 salt,
    PluginChange change,
    uint256 timeLock_,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external;

  /**
   * @dev It trusts a plugin
   * @param name The name of the plugin
   * @param salt The salt used during the deployment of the plugin
   * No need for a signature by a protector because the safety of the plugin is
   * guaranteed by the CrunaGuardian.
   */
  function trustPlugin(string calldata name, bytes4 salt) external;

  /**
   * @dev It returns the address of a plugin
   * @param nameId_ The bytes4 of the hash of the name of the plugin
   * @param salt The salt used during the deployment of the plugin
   * The address is returned even if a plugin has not deployed yet.
   * @return The plugin address
   */
  function pluginAddress(bytes4 nameId_, bytes4 salt) external view returns (address payable);

  /**
   * @dev It returns a plugin by name and salt
   * @param nameId_ The bytes4 of the hash of the name of the plugin
   * @param salt The salt used during the deployment of the plugin
   * The plugin is returned even if a plugin has not deployed yet, which means that it will
   * revert during the execution.
   * @return The plugin
   */
  function plugin(bytes4 nameId_, bytes4 salt) external view returns (CrunaManagedService);

  /**
   * @dev It returns the number of services
   */
  function countPlugins() external view returns (uint256, uint256);

  /**
   * @dev Says if a plugin is currently plugged
   */
  function plugged(string calldata name, bytes4 salt) external view returns (bool);

  /**
   * @dev Returns the index of a plugin
   * @param name The name of the plugin
   * @param salt The salt used during the deployment of the plugin
   * @return a tuple with a true if the plugin is found, and the index of the plugin
   */
  function pluginIndex(string calldata name, bytes4 salt) external view returns (bool, uint256);

  /**
   * @dev Checks if a plugin is active
   * @param name The name of the plugin
   * @param salt The salt used during the deployment of the plugin
   * @return True if the plugin is active
   */
  function isPluginActive(string calldata name, bytes4 salt) external view returns (bool);

  /**
   * @dev returns the list of services' keys
   * Since the names of the services are not saved in the contract, the app calling for this function
   * is responsible for knowing the names of all the services.
   * In the future it would be good to have an official registry of all services to be able to reverse
   * from the nameId to the name as a string.
   * @param active True to get the list of active services, false to get the list of inactive services
   * @return The list of services' keys
   */
  function listPluginsKeys(bool active) external view returns (bytes8[] memory);

  /**
   * @dev It returns a pseudo address created from the name of a plugin and the salt used to deploy it.
   * Notice that abi.encodePacked does not risk to create collisions because the salt has fixed length
   * in the hashed bytes.
   * @param name The name of the plugin
   * @param _salt The salt used during the deployment of the plugin
   * @return The pseudo address of the plugin
   */
  function pseudoAddress(string calldata name, bytes4 _salt) external view returns (address);

  /**
   * @dev A special function that can be called only by authorized services to transfer the NFT.
   * @param pluginNameId The bytes4 of the hash of the name of the plugin
   * The plugin must be searched by the pluginNameId and the salt, and the function must verify that
   * the current sender is the plugin.
   * @param to The address of the recipient
   */
  function managedTransfer(bytes4 pluginNameId, address to) external;

  /**
   * @dev Allows the user to transfer the NFT when protectors are set
   * @param tokenId The id of the token
   * @param to The address of the recipient
   * @param timestamp The timestamp of the signature
   * @param validFor The validity of the signature
   * @param signature The signature of the protector
   * The function should revert if no protectors are set, inviting to use the standard
   * ERC721 transfer functions.
   */
  function protectedTransfer(
    uint256 tokenId,
    address to,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external;

  /**
   * @dev Upgrades the implementation of the manager
   * @param implementation_ The address of the new implementation
   */
  function upgrade(address implementation_) external;
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Author : Francesco Sullo <francesco@sullo.co>

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable, UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {TimeControlledNFT} from "../token/TimeControlledNFT.sol";
import {IVaultFactory} from "./IVaultFactory.sol";
import {IVersioned} from "../../utils/IVersioned.sol";

contract VaultFactory is
  IVaultFactory,
  IVersioned,
  Initializable,
  PausableUpgradeable,
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  UUPSUpgradeable
{
  error ZeroAddress();
  error InsufficientFunds();
  error UnsupportedStableCoin();
  error TransferFailed();
  error InvalidArguments();
  error InvalidDiscount();

  TimeControlledNFT public vault;
  uint256 public price;
  mapping(address => bool) public stableCoins;
  uint256 public discount;
  address[] private _stableCoins;

  /**
   * @custom:oz-upgrades-unsafe-allow constructor
   */
  constructor() {
    _disableInitializers();
  }

  function initialize(address payable vault_, address owner_) public initializer {
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();
    vault = TimeControlledNFT(vault_);
  }

  function version() external pure virtual returns (uint256) {
    return 1_000_000;
  }

  // solhint-disable-next-line no-empty-blocks
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  // @notice The price is in points, so that 1 point = 0.01 USD
  function setPrice(uint256 price_) external virtual override onlyOwner {
    // it is owner's responsibility to set a reasonable price
    price = price_;
    emit PriceSet(price);
  }

  function setStableCoin(address stableCoin, bool active) external virtual override onlyOwner {
    if (active) {
      // We check if less than 6 because TetherUSD has 6 decimals
      // It should revert if the stableCoin is not an ERC20
      if (ERC20(stableCoin).decimals() < 6) {
        revert UnsupportedStableCoin();
      }
      if (!stableCoins[stableCoin]) {
        stableCoins[stableCoin] = true;
        _stableCoins.push(stableCoin);
        emit StableCoinSet(stableCoin, active);
      }
    } else if (stableCoins[stableCoin]) {
      delete stableCoins[stableCoin];
      // no risk of going out of cash because the factory will support just a couple of stable coins
      uint256 len = _stableCoins.length;
      for (uint256 i; i < len; ) {
        if (_stableCoins[i] == stableCoin) {
          // since if found the stableCoin, len is > 0
          if (i != len - 1) {
            _stableCoins[i] = _stableCoins[len - 1];
          }
          _stableCoins.pop();
          emit StableCoinSet(stableCoin, active);
          break;
        }
        unchecked {
          ++i;
        }
      }
    }
  }

  function setDiscount(uint256 discount_) external virtual override onlyOwner {
    if (discount > price) revert InvalidDiscount();
    discount = discount_;
  }

  function finalPrice(address stableCoin) public view virtual override returns (uint256) {
    return (getPrice() * (10 ** ERC20(stableCoin).decimals())) / 100;
  }

  function getPrice() public view virtual override returns (uint256) {
    return price - discount;
  }

  function buyVaults(address stableCoin, uint256 amount) external virtual override nonReentrant whenNotPaused {
    uint256 payment = finalPrice(stableCoin) * amount;
    if (payment > ERC20(stableCoin).balanceOf(_msgSender())) revert InsufficientFunds();
    vault.safeMintAndActivate(_msgSender(), amount);
    // we manage only trusted stable coins, so no risk of reentrancy
    if (!ERC20(stableCoin).transferFrom(_msgSender(), address(this), payment)) revert TransferFailed();
  }

  function buyVaultsBatch(
    address stableCoin,
    address[] memory tos,
    uint256[] memory amounts
  ) external virtual override nonReentrant whenNotPaused {
    if (tos.length != amounts.length) revert InvalidArguments();
    uint256 amount = 0;
    for (uint256 i; i < tos.length; ) {
      unchecked {
        if (tos[i] == address(0)) {
          revert ZeroAddress();
        }
        amount += amounts[i];
        ++i;
      }
    }
    uint256 payment = finalPrice(stableCoin) * amount;
    if (payment > ERC20(stableCoin).balanceOf(_msgSender())) revert InsufficientFunds();
    for (uint256 i; i < tos.length; ) {
      if (amounts[i] != 0) {
        vault.safeMintAndActivate(tos[i], amounts[i]);
      }
      unchecked {
        ++i;
      }
    }
    // we manage only trusted stable coins, so no risk of reentrancy
    if (!ERC20(stableCoin).transferFrom(_msgSender(), address(this), payment)) revert TransferFailed();
  }

  function withdrawProceeds(address beneficiary, address stableCoin, uint256 amount) external virtual override onlyOwner {
    uint256 balance = ERC20(stableCoin).balanceOf(address(this));
    if (amount == 0) {
      amount = balance;
    }
    if (amount > balance) revert InsufficientFunds();
    if (!ERC20(stableCoin).transfer(beneficiary, amount)) revert TransferFailed();
  }

  function getStableCoins() external view virtual returns (address[] memory) {
    return _stableCoins;
  }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract TetherUSD is ERC20, Ownable2Step {
  constructor(address initialOwner) ERC20("Tether USD", "USDT") Ownable(initialOwner) {}

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return 6;
  }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract USDCoin is ERC20, Ownable2Step {
  constructor(address initialOwner) ERC20("USD Coin", "USDC") Ownable(initialOwner) {}

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC6551AccountProxy} from "../../erc/ERC6551AccountProxy.sol";

contract CrunaManagerProxyV2 is ERC6551AccountProxy {
  constructor(address _initialImplementation) ERC6551AccountProxy(_initialImplementation) {}

  function getImplementation() external view returns (address) {
    return _implementation();
  }
}// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {Initializable, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {CrunaService} from "../../services/CrunaService.sol";

//import "hardhat/console.sol";

contract FungibleService is CrunaService, Initializable, ERC20Upgradeable, ERC20PermitUpgradeable {
  using Strings for uint256;

  function mint(address to, uint256 amount) public onlyTokenOwner {
    _mint(to, amount);
  }

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("FungibleService"));
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(string memory name, string memory symbol) public initializer {
    __ERC20_init(name, symbol);
    __ERC20Permit_init(name);
  }

  function extraName() external view returns (string memory) {
    return string(abi.encodePacked("FT ", _vault().name(), " #", tokenId().toString()));
  }

  function _onBeforeInit(bytes memory data) internal override {
    // It ensures that we do not call initialize again, causing a revert
    if (bytes(name()).length == 0) {
      (string memory name, string memory symbol) = abi.decode(data, (string, string));
      initialize(name, symbol);
    }
  }
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IERC7656Contract} from "../erc/IERC7656Contract.sol";
import {IVersioned} from "../utils/IVersioned.sol";

/**
 * @title ICrunaService.sol
 * @notice Interface for services
 */
interface ICrunaService is IERC7656Contract, IVersioned {
  /**
   * @notice Error returned when trying to initialize the service if not authorized
   */
  error Forbidden();

  /**
   * @notice Initialize the plugin. It must be implemented, but can do nothing is no init is needed.
   */
  function init(bytes memory data) external;

  /**
   * @notice Called by the manager to know if the plugin is an ERC721 account
   */
  function isERC6551Account() external pure returns (bool);

  /**
   * @notice Called when deploying the service to check if it must be managed
   */
  function isManaged() external pure returns (bool);
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC6551AccountProxy} from "../../erc/ERC6551AccountProxy.sol";

/**
 * @title InheritanceCrunaPluginProxy
 * @notice Proxy contract for the InheritanceCrunaPlugin
 */
contract InheritanceCrunaPluginProxy is ERC6551AccountProxy {
  /**
   * @notice Constructor
   * @param _initialImplementation Address of the initial implementation
   */
  constructor(address _initialImplementation) ERC6551AccountProxy(_initialImplementation) {}
}// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

// Author: Francesco Sullo <francesco@sullo.co>
//
import {IERC165, ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IManagedNFT, ICrunaProtectedNFT} from "./ICrunaProtectedNFT.sol";
import {IERC6454} from "../erc/IERC6454.sol";
import {IERC6982} from "../erc/IERC6982.sol";
import {ICrunaManager} from "../manager/ICrunaManager.sol";
import {IVersioned} from "../utils/IVersioned.sol";
import {Deployed} from "../utils/Deployed.sol";
import {Canonical} from "../libs/Canonical.sol";
import {ICrunaService} from "../services/ICrunaService.sol";

//import "hardhat/console.sol";

/**
 * A convenient interface to mix nameId, version and default implementations
 */
interface IVersionedManager {
  // solhint-disable-next-line func-name-mixedcase
  function DEFAULT_IMPLEMENTATION() external pure returns (address);

  function version() external pure returns (uint256);

  function nameId() external pure returns (bytes4);
}

/**
 * @title CrunaProtectedNFT
 * @notice This contracts is a base for NFTs with protected transfers. It must be extended implementing
 * the _canManage function to define who can alter the contract. Two versions are provided in this repo,CrunaProtectedNFTTimeControlled.sol and CrunaProtectedNFTOwnable.sol. The first is the recommended one, since it allows a governance aligned with best practices. The second is simpler, and can be used in less critical scenarios. If none of them fits your needs, you can implement your own policy.
 */
abstract contract CrunaProtectedNFT is ICrunaProtectedNFT, IVersioned, IERC6454, IERC6982, Deployed, ERC721, ReentrancyGuard {
  using ECDSA for bytes32;
  using Strings for uint256;
  using Address for address;

  /**
   * @notice Set a convenient variable to refer to the contract itself
   */
  address internal immutable _SELF = address(this);

  /**
   * @notice The configuration of the NFT
   */
  NftConf internal _nftConf;

  /**
   * @notice The manager history
   */
  ManagerHistory[] internal _managerHistory;

  /**
   * @notice internal variable used to make protected NFT temporarily transferable.
   * It is set before the transfer and removed after it, during the manager transfer process.
   */
  mapping(uint256 tokenId => uint256 approved) internal _approvedTransfers;

  /**
   * @notice allows only the manager of a certain tokenId to call the function.
   * @param tokenId The id of the token.
   */
  modifier onlyManagerOf(uint256 tokenId) {
    if (_managerOf(tokenId) != _msgSender()) revert NotTheManager();
    _;
  }

  /// @dev see {ICrunaProtectedNFT-nftConf}
  function nftConf() external view virtual override returns (NftConf memory) {
    return _nftConf;
  }

  /// @dev see {ICrunaProtectedNFT-managerHistory}
  function managerHistory(uint256 index) external view virtual override returns (ManagerHistory memory) {
    if (index >= _nftConf.managerHistoryLength) revert InvalidIndex();
    return _managerHistory[index];
  }

  /// @dev see {IVersioned-version}
  function version() external pure virtual returns (uint256) {
    // semver 1.2.3 => 1002003 = 1e6 + 2e3 + 3
    return 1_000_000;
  }

  constructor(string memory name_, string memory symbol_) payable ERC721(name_, symbol_) {
    emit DefaultLocked(false);
  }

  /// @dev see {ICrunaProtectedNFT-init}
  function init(
    address managerAddress_,
    bool progressiveTokenIds_,
    uint96 nextTokenId_,
    uint96 maxTokenId_
  ) external virtual override {
    _canManage(true);
    if (_nftConf.managerHistoryLength != 0) revert AlreadyInitiated();
    if (managerAddress_ == address(0)) revert ZeroAddress();
    _nftConf = NftConf({
      progressiveTokenIds: progressiveTokenIds_,
      nextTokenId: nextTokenId_,
      maxTokenId: maxTokenId_,
      managerHistoryLength: 1,
      unusedField: 0
    });
    _managerHistory.push(ManagerHistory({managerAddress: managerAddress_, firstTokenId: nextTokenId_, lastTokenId: 0}));
  }

  /// @dev see {ICrunaProtectedNFT-setMaxTokenId}
  function setMaxTokenId(uint96 maxTokenId_) external virtual {
    _canManage(_nftConf.maxTokenId == 0);
    if (maxTokenId_ == 0) revert InvalidMaxTokenId();
    if (_nftConf.progressiveTokenIds)
      if (_nftConf.nextTokenId > maxTokenId_ + 1) revert InvalidMaxTokenId();
    _nftConf.maxTokenId = maxTokenId_;
    emit MaxTokenIdChange(maxTokenId_);
  }

  /// @dev see {ICrunaProtectedNFT-defaultManagerImplementation}
  function defaultManagerImplementation(uint256 _tokenId) external view virtual override returns (address) {
    return _defaultManagerImplementation(_tokenId);
  }

  /// @dev see {ICrunaProtectedNFT-upgradeDefaultManager}
  function upgradeDefaultManager(address payable newManagerProxy) external virtual nonReentrant {
    _canManage(false);
    if (!_nftConf.progressiveTokenIds) revert NotAvailableIfTokenIdsAreNotProgressive();
    IVersionedManager newManager = IVersionedManager(newManagerProxy);
    if (!Canonical.crunaGuardian().trustedImplementation(newManager.nameId(), newManager.DEFAULT_IMPLEMENTATION()))
      revert UntrustedImplementation(newManagerProxy);
    address lastEmitter = _managerHistory[_nftConf.managerHistoryLength - 1].managerAddress;
    if (newManager.version() <= IVersionedManager(lastEmitter).version()) revert CannotUpgradeToAnOlderVersion();
    _managerHistory[_nftConf.managerHistoryLength - 1].lastTokenId = _nftConf.nextTokenId - 1;
    _managerHistory.push(ManagerHistory({managerAddress: newManagerProxy, firstTokenId: _nftConf.nextTokenId, lastTokenId: 0}));
    _nftConf.managerHistoryLength++;
    emit DefaultManagerUpgrade(newManagerProxy);
  }

  /**
   * @notice see {ICrunaProtectedNFT-managedTransfer}.
   */
  function managedTransfer(
    bytes4 pluginNameId,
    uint256 tokenId,
    address to
  ) external payable virtual override onlyManagerOf(tokenId) {
    _approvedTransfers[tokenId] = 1;
    _approve(_managerOf(tokenId), tokenId, address(0));
    safeTransferFrom(ownerOf(tokenId), to, tokenId);
    _approve(address(0), tokenId, address(0));
    delete _approvedTransfers[tokenId];
    emit ManagedTransfer(pluginNameId, tokenId);
  }

  /// @dev see {ERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
    return
      interfaceId == type(IManagedNFT).interfaceId ||
      interfaceId == type(IERC6454).interfaceId ||
      interfaceId == type(IERC6982).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  /// @dev see {IERC6454-isTransferable}
  function isTransferable(uint256 tokenId, address from, address to) external view virtual override returns (bool) {
    return _isTransferable(tokenId, from, to);
  }

  /// @dev see {IERC6982-defaultLocked}
  function defaultLocked() external pure virtual override returns (bool) {
    return false;
  }

  /// @dev see {IERC6982-locked}
  function locked(uint256 tokenId) external view virtual override returns (bool) {
    return ICrunaManager(_managerOf(tokenId)).locked();
  }

  /**
   * @notice Emit a Locked event when a protector is set and the token becomes locked.
   * This function is not virtual because should not be overridden to avoid issues when
   * called by the manager (when protectors are set/unset)
   * Making it payable reduces the gas cost.
   */
  function emitLockedEvent(uint256 tokenId, bool locked_) external payable onlyManagerOf(tokenId) {
    emit Locked(tokenId, locked_);
  }

  /// @dev see {ICrunaProtectedNFT-plug}
  function plug(
    address implementation,
    bytes32 salt,
    uint256 tokenId,
    bool isERC6551Account,
    bytes memory data
  ) external payable virtual override {
    if (_msgSender() != ownerOf(tokenId)) revert NotTheTokenOwner();
    ICrunaService service = ICrunaService(implementation);
    if (service.isManaged()) revert ManagedService();
    address addr = _deploy(implementation, salt, _SELF, tokenId, isERC6551Account);
    service = ICrunaService(addr);
    /**
     * @dev it is the service responsibility to assure that `init` can be called only one time
     * The rationale for call `init` anytime is that an hostile agent can use the registry to deploy
     * a service that later cannot be initiated if the can be initiated only at the deployment.
     */
    service.init(data);
  }

  /// @dev see {ICrunaProtectedNFT-isDeployed}
  function isDeployed(
    address implementation,
    bytes32 salt,
    uint256 tokenId,
    bool isERC6551Account
  ) external view virtual returns (bool) {
    return _isDeployed(implementation, salt, _SELF, tokenId, isERC6551Account);
  }

  /// @dev see {ICrunaProtectedNFT-managerOf}
  function managerOf(uint256 tokenId) external view virtual returns (address) {
    return _managerOf(tokenId);
  }

  /**
   * @notice internal function to return the manager (for lesser gas consumption)
   * @param tokenId the id of the token
   * @return the address of the manager
   */
  function _managerOf(uint256 tokenId) internal view virtual returns (address) {
    return _addressOfDeployed(_defaultManagerImplementation(tokenId), 0x00, _SELF, tokenId, false);
  }

  /// @dev see {ICrunaProtectedNFT-addressOfDeployed}
  function addressOfDeployed(
    address implementation,
    bytes32 salt,
    uint256 tokenId,
    bool isERC6551Account
  ) external view virtual override returns (address) {
    return _addressOfDeployed(implementation, salt, _SELF, tokenId, isERC6551Account);
  }

  /**
   * @notice Returns the default implementation of the manager for a specific tokenId
   * @param _tokenId the tokenId
   * @return The address of the implementation
   */
  function _defaultManagerImplementation(uint256 _tokenId) internal view virtual returns (address) {
    if (_nftConf.managerHistoryLength == 1) return _managerHistory[0].managerAddress;
    uint256 len = _nftConf.managerHistoryLength;
    for (uint256 i; i < len; ) {
      if (
        _tokenId >= _managerHistory[i].firstTokenId &&
        (_managerHistory[i].lastTokenId == 0 || _tokenId <= _managerHistory[i].lastTokenId)
      ) return _managerHistory[i].managerAddress;
      unchecked {
        ++i;
      }
    }
    // should never happen
    return address(0);
  }

  /**
   * @notice Specify if the caller can call some function.
   * Must be overridden to specify who can manage changes during initialization and later
   * @param isInitializing If true, the function is being called during initialization, if false,
   * it is supposed to the called later. A time controlled NFT can allow the admin to call some
   * functions during the initialization, requiring later a standard proposal/execition process.
   */
  function _canManage(bool isInitializing) internal view virtual;

  /**
   * @notice see {ERC721-_update}.
   */
  function _update(address to, uint256 tokenId, address auth) internal virtual override(ERC721) returns (address) {
    if (_isTransferable(tokenId, _ownerOf(tokenId), to)) {
      return super._update(to, tokenId, auth);
    }
    revert NotTransferable();
  }

  /**
   * @notice Function to define a token as transferable or not, according to IERC6454
   * @param tokenId The id of the token.
   * @param from The address of the sender.
   * @param to The address of the recipient.
   * @return true if the token is transferable, false otherwise.
   */
  function _isTransferable(uint256 tokenId, address from, address to) internal view virtual returns (bool) {
    ICrunaManager manager = ICrunaManager(_managerOf(tokenId));
    // Burnings and self transfers are not allowed
    if (to == address(0) || from == to) return false;
    // if from zero, it is minting
    if (from == address(0)) return true;
    _requireOwned(tokenId);
    return manager.isTransferable(to) || _approvedTransfers[tokenId] == 1;
  }

  /**
   * @notice Mints tokens by amount.
   * @dev It works only if nftConf.progressiveTokenIds is true.
   * @param to The address of the recipient.
   * @param amount The amount of tokens to mint.
   */
  function _mintAndActivateByAmount(address to, uint256 amount) internal virtual {
    if (!_nftConf.progressiveTokenIds) revert NotAvailableIfTokenIdsAreNotProgressive();
    if (_nftConf.managerHistoryLength == 0) revert NftNotInitiated();
    uint256 tokenId = _nftConf.nextTokenId;
    for (uint256 i; i < amount; ) {
      unchecked {
        _mintAndActivate(to, tokenId++);
        ++i;
      }
    }
    _nftConf.nextTokenId = uint96(tokenId);
  }

  /**
   * @notice This function will mint a new token and initialize it.
   * @dev Use it carefully if nftConf.progressiveTokenIds is true. Usually, you may
   * want to do so if you reserved some specific token to the project itself, the DAO, etc.
   * An example:
   * You reserve 1000 tokens to the DAO, `nextTokenId` will be 1001.
   * If you have a function the uses directly _mintAndActivate you MUST set a check
   * to avoid minting tokens with higher id than `nextTokenId`. If than happens, when
   * you call again _mintAndActivateByAmount, if one of the supposed tokens is already minted,
   * the function will revert and the error may be unfixable.
   * @param to The address of the recipient.
   * @param tokenId The id of the token.
   */
  function _mintAndActivate(address to, uint256 tokenId) internal virtual {
    if (_nftConf.managerHistoryLength == 0) revert NftNotInitiated();
    if (
      tokenId > type(uint96).max ||
      (_nftConf.maxTokenId != 0 && tokenId > _nftConf.maxTokenId) ||
      (tokenId < _managerHistory[0].firstTokenId)
    ) revert InvalidTokenId();
    _deploy(_defaultManagerImplementation(tokenId), 0x00, _SELF, tokenId, false);
    _safeMint(to, tokenId++);
  }
}// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IManagedNFT} from "./IManagedNFT.sol";

/**
 * @title ICrunaProtectedNFT
 * @author Francesco Sullo <francesco@sullo.co>
 */
interface ICrunaProtectedNFT is IManagedNFT, IERC721 {
  /**
   * @notice Optimized configuration structure for the generic NFT
   *
   * TokenIds are uint96 for optimization purposes. In particular, having the tokenId as a uint96 allows
   * to encode the tokenId in the first 12 bytes of the storage slot, leaving the last 20 bytes for the token address
   * That allows services and other tools to save storage because tokenAddress + tokenId will take a single word.
   * For example, tokenAddress and tokenId can be encoded as
   * uint256 tokenAddressAndTokenId = uint256(tokenAddress) << 96 | tokenId;
   *
   * Elements:
   * - progressiveTokenIds is used to allow the upgrade of the default manager implementation. It is used to assure that the manager can be upgraded in a safe way.
   * - nextTokenId is the next tokenId to be used. It is used to mint new tokens if progressiveTokenIds is true.
   * - maxTokenId is the maximum tokenId that can be minted. It is used to limit the minting of new tokens.
   * - managerHistoryLength is the length of the manager history.
   */
  struct NftConf {
    uint96 nextTokenId;
    uint96 maxTokenId;
    bool progressiveTokenIds;
    uint8 managerHistoryLength;
    // for future changes
    uint8 unusedField;
  }

  /**
   * @notice Manager history structure
   * Elements:
   * - firstTokenId is the first tokenId using a specific manager.
   * - lastTokenId is the last tokenId managed by the same manager.
   * - managerAddress is the address of the manager.
   */
  struct ManagerHistory {
    uint96 firstTokenId;
    uint96 lastTokenId;
    address managerAddress;
  }

  // events

  /**
   * @notice Emitted when the default manager is upgraded
   * @param newManagerProxy The address of the new manager proxy
   */
  event DefaultManagerUpgrade(address indexed newManagerProxy);

  /**
   * @notice Emitted when the maxTokenId is changed
   * @param maxTokenId The new maxTokenId
   */
  event MaxTokenIdChange(uint96 maxTokenId);

  // errors

  /**
   * @notice Error returned when the caller is not the token owner
   */
  error NotTransferable();

  /**
   * @notice Error returned when the caller is not the manager
   */
  error NotTheManager();

  /**
   * @notice Error returned when the caller is not the token owner
   */
  error ZeroAddress();

  /**
   * @notice Error returned when the token is already initiated
   */
  error AlreadyInitiated();

  /**
   * @notice Error returned when the caller is not the token owner
   */
  error NotTheTokenOwner();

  /**
   * @notice Error returned when trying to upgrade to an older version
   */
  error CannotUpgradeToAnOlderVersion();

  /**
   * @notice Error returned when the new implementation of the manager is not trusted
   */
  error UntrustedImplementation(address implementation);

  /**
   * @notice Error returned when trying to call a function that requires progressive token ids
   */
  error NotAvailableIfTokenIdsAreNotProgressive();

  /**
   * @notice Error returned when the token id is invalid
   */
  error InvalidTokenId();

  /**
   * @notice Error returned when the NFT is not initiated
   */
  error NftNotInitiated();

  /**
   * @notice Error returned when trying too set an invalid MaxTokenId
   */
  error InvalidMaxTokenId();

  /**
   * @notice Error returned when an index is invalid
   */
  error InvalidIndex();

  /**
   * @notice Error returned if the sender is neither the manager nor the token owner
   */
  error OnlyTokenOwnerOrManager();

  /**
   * @notice Error returned when the token owner tries to deploy a service that must be managed
   */
  error ManagedService();

  // views

  /**
   * @notice Returns the configuration of the NFT
   */
  function nftConf() external view returns (NftConf memory);

  /**
   * @notice Returns the manager history for a specific index
   * @param index The index
   */
  function managerHistory(uint256 index) external view returns (ManagerHistory memory);

  /**
   * @notice set the maximum tokenId that can be minted
   * @param maxTokenId_ The new maxTokenId
   */
  function setMaxTokenId(uint96 maxTokenId_) external;

  /**
   * @notice Initialize the NFT
   * @param managerAddress_ The address of the manager
   * @param progressiveTokenIds_ If true, the tokenIds will be progressive
   * @param nextTokenId_ The next tokenId to be used.
   * If progressiveTokenIds_ == true and the project must reserve some tokens to
   * special addresses, community, etc. You set the nextTokenId_ to the first not reserved token.
   * Be careful, your function minting by tokenId MUST check that the tokenId is
   * not higher than nextTokenId. If not, when trying to mint tokens by amount, as soon as
   * nextTokenId reaches the minted tokenId, the function will revert, blocking any future minting.
   * If you code may risk so, set a function that allow you to correct the nextTokenId to skip
   * the token minted by mistake.
   * @param maxTokenId_ The maximum tokenId that can be minted (it can be 0 if no upper limit)
   */
  function init(address managerAddress_, bool progressiveTokenIds_, uint96 nextTokenId_, uint96 maxTokenId_) external;

  /**
   * @notice Returns the address of the default implementation of the manager for a tokenId
   * @param _tokenId The tokenId
   */
  function defaultManagerImplementation(uint256 _tokenId) external view returns (address);

  /**
   * @notice Upgrade the default manager for any following tokenId
   * @param newManagerProxy The address of the new manager proxy
   */
  function upgradeDefaultManager(address payable newManagerProxy) external;

  /**
   * @notice Return the address of the manager of a tokenId
   * @param tokenId The id of the token.
   */
  function managerOf(uint256 tokenId) external view returns (address);

  /**
   * @notice Returns the address of a deployed manager or plugin
   * @param implementation The address of the manager or plugin implementation
   * @param salt The salt
   * @param tokenId The tokenId
   * @param isERC6551Account Specifies the registry to use
   * True if the tokenId was deployed via ERC6551Registry,
   * false, it was deployed via ERC7656Registry
   * @return The address of the deployed manager or plugin
   */
  function addressOfDeployed(
    address implementation,
    bytes32 salt,
    uint256 tokenId,
    bool isERC6551Account
  ) external view returns (address);

  /**
   * @notice Deploys an unmanaged service
   * @param implementation The address of the service implementation
   * @param salt The salt
   * @param tokenId The tokenId
   * @param isERC6551Account Specifies the registry to use
   * True if the tokenId must be deployed via ERC6551Registry,
   * false, it must be deployed via ERC7656Registry
   */
  function plug(
    address implementation,
    bytes32 salt,
    uint256 tokenId,
    bool isERC6551Account,
    bytes memory data
  ) external payable;

  /**
   * @notice Returns if a plugin is deployed
   * @param implementation The address of the plugin implementation
   * @param salt The salt
   * @param tokenId The tokenId
   * @param isERC6551Account Specifies the registry to use
   * True if the tokenId was deployed via ERC6551Registry,
   * false, it was deployed via ERC7656Registry
   */
  function isDeployed(
    address implementation,
    bytes32 salt,
    uint256 tokenId,
    bool isERC6551Account
  ) external view returns (bool);
}// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

// Author: Francesco Sullo <francesco@sullo.co>

import {ERC7656Contract} from "../erc/ERC7656Contract.sol";
import {CrunaProtectedNFT} from "../token/CrunaProtectedNFT.sol";
import {INamed} from "../utils/INamed.sol";

import {ICommonBase} from "./ICommonBase.sol";

/**
 * @title CommonBase.sol
 * @notice Base contract for managers and services
 */
abstract contract CommonBase is ICommonBase, INamed, ERC7656Contract {
  /**
   * @notice Error returned when the caller is not the token owner
   */
  modifier onlyTokenOwner() {
    if (owner() != msg.sender) revert NotTheTokenOwner();
    _;
  }

  /**
   * @notice Returns the name id of the contract
   */
  function nameId() external view override returns (bytes4) {
    return _nameId();
  }

  /**
   * @notice Internal function that must be overridden by the contract to
   * return the name id of the contract
   */
  function _nameId() internal view virtual returns (bytes4);

  /**
   * @notice Returns the vault, i.e., the CrunaProtectedNFT contract
   */
  function vault() external view virtual returns (CrunaProtectedNFT) {
    return _vault();
  }

  /**
   * @notice Returns the vault, i.e., the CrunaProtectedNFT contract
   */
  function _vault() internal view virtual returns (CrunaProtectedNFT) {
    return CrunaProtectedNFT(tokenAddress());
  }

  // @dev This empty reserved space is put in place to allow future versions to add new
  // variables without shifting down storage in the inheritance chain.
  // See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps

  uint256[50] private __gap;
}// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

// Author: Francesco Sullo <francesco@sullo.co>
//
import {ERC6551AccountLib} from "erc6551/lib/ERC6551AccountLib.sol";

import {Canonical} from "../libs/Canonical.sol";

/**
 * @title Deployed
 * @notice This contract manages deploy-related functions
 */
abstract contract Deployed {
  /// @dev see {ICrunaProtectedNFT-isDeployed}
  function _isDeployed(
    address implementation,
    bytes32 salt,
    address tokenAddress,
    uint256 tokenId,
    bool isERC6551Account
  ) internal view virtual returns (bool) {
    address _addr = _addressOfDeployed(implementation, salt, tokenAddress, tokenId, isERC6551Account);
    uint32 size;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      size := extcodesize(_addr)
    }
    return (size != 0);
  }

  /**
   * @notice Internal function to return the address of a deployed token bound contract
   * @param implementation The address of the implementation
   * @param salt The salt
   * @param tokenId The tokenId
   * @param isERC6551Account If true, the tokenId has been deployed via ERC6551Registry, if false, via ERC7656Registry
   */
  function _addressOfDeployed(
    address implementation,
    bytes32 salt,
    address tokenAddress,
    uint256 tokenId,
    bool isERC6551Account
  ) internal view virtual returns (address) {
    return
      ERC6551AccountLib.computeAddress(
        isERC6551Account ? address(Canonical.erc6551Registry()) : address(Canonical.erc7656Registry()),
        implementation,
        salt,
        block.chainid,
        tokenAddress,
        tokenId
      );
  }

  /**
   * @notice This function deploys a token-linked contract (manager or plugin)
   * @param implementation The address of the implementation
   * @param salt The salt
   * @param tokenId The tokenId
   * @param isERC6551Account If true, the tokenId will be deployed via ERC6551Registry,
   * if false, via ERC7656Registry
   */
  function _deploy(
    address implementation,
    bytes32 salt,
    address tokenAddress,
    uint256 tokenId,
    bool isERC6551Account
  ) internal virtual returns (address) {
    if (isERC6551Account) {
      return Canonical.erc6551Registry().createAccount(implementation, salt, block.chainid, tokenAddress, tokenId);
    }
    return Canonical.erc7656Registry().create(implementation, salt, block.chainid, tokenAddress, tokenId);
  }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IERC6551Registry {
    /**
     * @dev The registry MUST emit the ERC6551AccountCreated event upon successful account creation.
     */
    event ERC6551AccountCreated(
        address account,
        address indexed implementation,
        bytes32 salt,
        uint256 chainId,
        address indexed tokenContract,
        uint256 indexed tokenId
    );

    /**
     * @dev The registry MUST revert with AccountCreationFailed error if the create2 operation fails.
     */
    error AccountCreationFailed();

    /**
     * @dev Creates a token bound account for a non-fungible token.
     *
     * If account has already been created, returns the account address without calling create2.
     *
     * Emits ERC6551AccountCreated event.
     *
     * @return account The address of the token bound account
     */
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address account);

    /**
     * @dev Returns the computed token bound account address for a non-fungible token.
     *
     * @return account The address of the token bound account
     */
    function account(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external view returns (address account);
}

contract ERC6551Registry is IERC6551Registry {
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address) {
        assembly {
            // Memory Layout:
            // ----
            // 0x00   0xff                           (1 byte)
            // 0x01   registry (address)             (20 bytes)
            // 0x15   salt (bytes32)                 (32 bytes)
            // 0x35   Bytecode Hash (bytes32)        (32 bytes)
            // ----
            // 0x55   ERC-1167 Constructor + Header  (20 bytes)
            // 0x69   implementation (address)       (20 bytes)
            // 0x5D   ERC-1167 Footer                (15 bytes)
            // 0x8C   salt (uint256)                 (32 bytes)
            // 0xAC   chainId (uint256)              (32 bytes)
            // 0xCC   tokenContract (address)        (32 bytes)
            // 0xEC   tokenId (uint256)              (32 bytes)

            // Silence unused variable warnings
            pop(chainId)

            // Copy bytecode + constant data to memory
            calldatacopy(0x8c, 0x24, 0x80) // salt, chainId, tokenContract, tokenId
            mstore(0x6c, 0x5af43d82803e903d91602b57fd5bf3) // ERC-1167 footer
            mstore(0x5d, implementation) // implementation
            mstore(0x49, 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73) // ERC-1167 constructor + header

            // Copy create2 computation data to memory
            mstore8(0x00, 0xff) // 0xFF
            mstore(0x35, keccak256(0x55, 0xb7)) // keccak256(bytecode)
            mstore(0x01, shl(96, address())) // registry address
            mstore(0x15, salt) // salt

            // Compute account address
            let computed := keccak256(0x00, 0x55)

            // If the account has not yet been deployed
            if iszero(extcodesize(computed)) {
                // Deploy account contract
                let deployed := create2(0, 0x55, 0xb7, salt)

                // Revert if the deployment fails
                if iszero(deployed) {
                    mstore(0x00, 0x20188a59) // `AccountCreationFailed()`
                    revert(0x1c, 0x04)
                }

                // Store account address in memory before salt and chainId
                mstore(0x6c, deployed)

                // Emit the ERC6551AccountCreated event
                log4(
                    0x6c,
                    0x60,
                    // `ERC6551AccountCreated(address,address,bytes32,uint256,address,uint256)`
                    0x79f19b3655ee38b1ce526556b7731a20c8f218fbda4a3990b6cc4172fdf88722,
                    implementation,
                    tokenContract,
                    tokenId
                )

                // Return the account address
                return(0x6c, 0x20)
            }

            // Otherwise, return the computed account address
            mstore(0x00, shr(96, shl(96, computed)))
            return(0x00, 0x20)
        }
    }

    function account(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external view returns (address) {
        assembly {
            // Silence unused variable warnings
            pop(chainId)
            pop(tokenContract)
            pop(tokenId)

            // Copy bytecode + constant data to memory
            calldatacopy(0x8c, 0x24, 0x80) // salt, chainId, tokenContract, tokenId
            mstore(0x6c, 0x5af43d82803e903d91602b57fd5bf3) // ERC-1167 footer
            mstore(0x5d, implementation) // implementation
            mstore(0x49, 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73) // ERC-1167 constructor + header

            // Copy create2 computation data to memory
            mstore8(0x00, 0xff) // 0xFF
            mstore(0x35, keccak256(0x55, 0xb7)) // keccak256(bytecode)
            mstore(0x01, shl(96, address())) // registry address
            mstore(0x15, salt) // salt

            // Store computed account address in memory
            mstore(0x00, shr(96, shl(96, keccak256(0x00, 0x55))))

            // Return computed account address
            return(0x00, 0x20)
        }
    }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC6551Registry {
    /**
     * @dev The registry MUST emit the ERC6551AccountCreated event upon successful account creation.
     */
    event ERC6551AccountCreated(
        address account,
        address indexed implementation,
        bytes32 salt,
        uint256 chainId,
        address indexed tokenContract,
        uint256 indexed tokenId
    );

    /**
     * @dev The registry MUST revert with AccountCreationFailed error if the create2 operation fails.
     */
    error AccountCreationFailed();

    /**
     * @dev Creates a token bound account for a non-fungible token.
     *
     * If account has already been created, returns the account address without calling create2.
     *
     * Emits ERC6551AccountCreated event.
     *
     * @return account The address of the token bound account
     */
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address account);

    /**
     * @dev Returns the computed token bound account address for a non-fungible token.
     *
     * @return account The address of the token bound account
     */
    function account(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external view returns (address account);
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Create2.sol";
import "./ERC6551BytecodeLib.sol";

library ERC6551AccountLib {
    function computeAddress(
        address registry,
        address _implementation,
        bytes32 _salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal pure returns (address) {
        bytes32 bytecodeHash = keccak256(
            ERC6551BytecodeLib.getCreationCode(
                _implementation, _salt, chainId, tokenContract, tokenId
            )
        );

        return Create2.computeAddress(_salt, bytecodeHash, registry);
    }

    function isERC6551Account(address account, address expectedImplementation, address registry)
        internal
        view
        returns (bool)
    {
        // invalid bytecode size
        if (account.code.length != 0xAD) return false;

        address _implementation = implementation(account);

        // implementation does not exist
        if (_implementation.code.length == 0) return false;

        // invalid implementation
        if (_implementation != expectedImplementation) return false;

        (bytes32 _salt, uint256 chainId, address tokenContract, uint256 tokenId) = context(account);

        return account
            == computeAddress(registry, _implementation, _salt, chainId, tokenContract, tokenId);
    }

    function implementation(address account) internal view returns (address _implementation) {
        assembly {
            // copy proxy implementation (0x14 bytes)
            extcodecopy(account, 0xC, 0xA, 0x14)
            _implementation := mload(0x00)
        }
    }

    function implementation() internal view returns (address _implementation) {
        return implementation(address(this));
    }

    function token(address account) internal view returns (uint256, address, uint256) {
        bytes memory encodedData = new bytes(0x60);

        assembly {
            // copy 0x60 bytes from end of context
            extcodecopy(account, add(encodedData, 0x20), 0x4d, 0x60)
        }

        return abi.decode(encodedData, (uint256, address, uint256));
    }

    function token() internal view returns (uint256, address, uint256) {
        return token(address(this));
    }

    function salt(address account) internal view returns (bytes32) {
        bytes memory encodedData = new bytes(0x20);

        assembly {
            // copy 0x20 bytes from beginning of context
            extcodecopy(account, add(encodedData, 0x20), 0x2d, 0x20)
        }

        return abi.decode(encodedData, (bytes32));
    }

    function salt() internal view returns (bytes32) {
        return salt(address(this));
    }

    function context(address account) internal view returns (bytes32, uint256, address, uint256) {
        bytes memory encodedData = new bytes(0x80);

        assembly {
            // copy full context (0x80 bytes)
            extcodecopy(account, add(encodedData, 0x20), 0x2D, 0x80)
        }

        return abi.decode(encodedData, (bytes32, uint256, address, uint256));
    }

    function context() internal view returns (bytes32, uint256, address, uint256) {
        return context(address(this));
    }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library ERC6551BytecodeLib {
    /**
     * @dev Returns the creation code of the token bound account for a non-fungible token.
     *
     * @return result The creation code of the token bound account
     */
    function getCreationCode(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal pure returns (bytes memory result) {
        assembly {
            result := mload(0x40) // Grab the free memory pointer
            // Layout the variables and bytecode backwards
            mstore(add(result, 0xb7), tokenId)
            mstore(add(result, 0x97), shr(96, shl(96, tokenContract)))
            mstore(add(result, 0x77), chainId)
            mstore(add(result, 0x57), salt)
            mstore(add(result, 0x37), 0x5af43d82803e903d91602b57fd5bf3)
            mstore(add(result, 0x28), implementation)
            mstore(add(result, 0x14), 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73)
            mstore(result, 0xb7) // Store the length
            mstore(0x40, add(result, 0xd7)) // Allocate the memory
        }
    }

    /**
     * @dev Returns the create2 address computed from `salt`, `bytecodeHash`, `deployer`.
     *
     * @return result The create2 address computed from `salt`, `bytecodeHash`, `deployer`
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer)
        internal
        pure
        returns (address result)
    {
        assembly {
            result := mload(0x40) // Grab the free memory pointer
            mstore8(result, 0xff)
            mstore(add(result, 0x35), bytecodeHash)
            mstore(add(result, 0x01), shl(96, deployer))
            mstore(add(result, 0x15), salt)
            result := keccak256(result, 0x55)
        }
    }
}