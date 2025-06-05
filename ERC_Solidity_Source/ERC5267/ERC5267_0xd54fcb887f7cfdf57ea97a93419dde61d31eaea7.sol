// File: contracts/tokens/KycERC20.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import "../interfaces/IKycERC20.sol";
import "../integration/KeyringGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 @notice This contract illustrates how an immutable KeyringGuard can be wrapped around collateral tokens 
 (e.g. DAI Token). Specify the token to wrap and the new name/symbol of the wrapped token - then good to go!
 Tokens can only be transferred to an address that maintains compliance with the configured policy.
 */

contract KycERC20 is IKycERC20, ERC20Permit, ERC20Wrapper, KeyringGuard {
        
    using SafeERC20 for IERC20;

    string private constant MODULE = "KycERC20";

    /**
     * @param config Keyring contract addresses. See IKycERC20. 
     * @param policyId_ The unique identifier of a Policy.
     * @param maximumConsentPeriod_ The upper limit for user consent deadlines. 
     * @param name_ The name of the new wrapped token. Passed to ERC20.constructor to set the ERC20.name
     * @param symbol_ The symbol for the new wrapped token. Passed to ERC20.constructor to set the ERC20.symbol
     */
    constructor(
        KeyringConfig memory config,
        uint32 policyId_,
        uint32 maximumConsentPeriod_,
        string memory name_,
        string memory symbol_
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        ERC20Wrapper(IERC20(config.collateralToken))
        KeyringGuard(config, policyId_, maximumConsentPeriod_)
    {
        if (config.collateralToken == NULL_ADDRESS)
            revert Unacceptable({
                reason: "collateral token cannot be empty"
            });
        if (bytes(name_).length == 0)
            revert Unacceptable({
                reason: "name_ cannot be empty"
            });
        if (bytes(symbol_).length == 0)
            revert Unacceptable({
                reason: "symbol_ cannot be empty"
            });
    }

    /**
     * @notice Returns decimals based on the underlying token decimals
     * @return uint8 decimals integer
     */
    function decimals() public view override(ERC20, ERC20Wrapper) returns (uint8) {
        return ERC20Wrapper.decimals();
    }

    /**
     * @notice Deposit underlying tokens and mint the same number of wrapped tokens.
     * @param trader Recipient of the wrapped tokens
     * @param amount Quantity of underlying tokens from _msgSender() to exchange for wrapped tokens (to account) at 1:1
     */
    function depositFor(address trader, uint256 amount)
        public
        override(IKycERC20, ERC20Wrapper)
        returns (bool)
    {
        if(trader != _msgSender()) {
            if (!isAuthorized(_msgSender(), trader)) 
                revert Unacceptable({
                    reason: "trader not authorized"
                });
            }
        return ERC20Wrapper.depositFor(trader, amount);
    }

    /**
     * @notice Burn a number of wrapped tokens and withdraw the same number of underlying tokens.
     * @param trader Recipient of the underlying tokens
     * @param amount Quantity of wrapped tokens from _msgSender() to exchange for underlying tokens (to account) at 1:1
     */
    function withdrawTo(address trader, uint256 amount)
        public
        override(IKycERC20, ERC20Wrapper)
        returns (bool)
    {
        if(trader != _msgSender()) {
            if (!isAuthorized(_msgSender(), trader)) 
                revert Unacceptable({
                    reason: "trader not authorized"
                });
            }
        return ERC20Wrapper.withdrawTo(trader, amount);
    }

    /**
     * @notice Wraps the inherited ERC20.transfer function with the keyringCompliance guard.
     * @param to The recipient of amount 
     * @param amount The amount to transfer.
     * @return bool True if successfully executed.
     */
    function transfer(address to, uint256 amount)
        public
        override(IERC20, ERC20)
        checkKeyring(_msgSender(), to)
        returns (bool)
    {
        return ERC20.transfer(to, amount);
    }

    /**
     * @notice Wraps the inherited ERC20.transferFrom function with the keyringCompliance guard.
     * @param from The sender of amount 
     * @param to The recipient of amount 
     * @param amount The amount to be deducted from the to's allowance.
     * @return bool True if successfully executed.
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        override(IERC20, ERC20)
        checkKeyring(from, to)
        returns (bool)
    {
        return ERC20.transferFrom(from, to, amount);
    }

    /**
     * @notice Returns ERC2771 signer if msg.sender is a trusted forwarder, otherwise returns msg.sender.
     * @return sender User deemed to have signed the transaction.
     */
    function _msgSender()
        internal
        view
        virtual
        override(KeyringAccessControl, Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    /**
     * @notice Returns msg.data if not from a trusted forwarder, or truncated msg.data if the signer was 
     * appended to msg.data
     * @dev Although not currently used, this function forms part of ERC2771 so is included for completeness.
     * @return data Data deemed to be the msg.data
     */
    function _msgData()
        internal
        view
        virtual
        override(KeyringAccessControl, Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }
    
}


// File: contracts/interfaces/IKycERC20.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 @notice Issues wrapped DAI tokens that can only be transferred to holders that maintain
 compliance with the configured policy.
 */

interface IKycERC20 is IERC20 {
    
    function depositFor(address account, uint256 amount) external returns (bool);
    
    function withdrawTo(address account, uint256 amount) external returns (bool);
}


// File: contracts/integration/KeyringGuard.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import "../interfaces/IKeyringGuard.sol";
import "../interfaces/IRuleRegistry.sol";
import "../interfaces/IPolicyManager.sol";
import "../interfaces/IUserPolicies.sol";
import "../interfaces/IWalletCheck.sol";
import "../interfaces/IKeyringCredentials.sol";
import "../interfaces/IExemptionsManager.sol";
import "../consent/Consent.sol";

/**
 * @notice KeyringGuard implementation that uses immutable configuration parameters and presents 
 * a simplified modifier for use in derived contracts.
 */

contract KeyringGuard is IKeyringGuard, Consent {
    using AddressSet for AddressSet.Set;

    uint8 private constant VERSION = 1;
    bytes32 private constant NULL_BYTES32 = bytes32(0);
    address internal constant NULL_ADDRESS = address(0);

    address public immutable keyringCredentials;
    address public immutable policyManager;
    address public immutable userPolicies;
    address public immutable exemptionsManager;
    uint32 public immutable admissionPolicyId;
    bytes32 public immutable universeRule;
    bytes32 public immutable emptyRule;

    /**
     * @dev Modifier checks ZK credentials and trader wallets for sender and receiver.
     */
    modifier checkKeyring(address from, address to) {
        if (!isAuthorized(from, to))
            revert Unacceptable({
                reason: "trader not authorized"
            });
        _;
    }

    /**
     * @param config Keyring contract addresses.
     * @param admissionPolicyId_ The unique identifier of a Policy against which user accounts will be compared.
     * @param maximumConsentPeriod_ The upper limit for user consent deadlines. 
     */
    constructor(
        KeyringConfig memory config,
        uint32 admissionPolicyId_,
        uint32 maximumConsentPeriod_
    ) Consent(config.trustedForwarder, maximumConsentPeriod_) {

        if (config.keyringCredentials == NULL_ADDRESS) revert Unacceptable({ reason: "credentials_ cannot be empty" });
        if (config.policyManager == NULL_ADDRESS) revert Unacceptable({ reason: "policyManager_ cannot be empty" });
        if (config.userPolicies == NULL_ADDRESS) revert Unacceptable({ reason: "userPolicies_ cannot be empty" });
        if (config.exemptionsManager == NULL_ADDRESS) 
            revert Unacceptable({ reason: "exemptionsManager_ cannot be empty"});
        if (!IPolicyManager(config.policyManager).isPolicy(admissionPolicyId_))
            revert Unacceptable({ reason: "admissionPolicyId not found" });
        if (IPolicyManager(config.policyManager).policyDisabled(admissionPolicyId_))
            revert Unacceptable({ reason: "admissionPolicy is disabled" });
           
        keyringCredentials = config.keyringCredentials;
        policyManager = config.policyManager;
        userPolicies = config.userPolicies;
        exemptionsManager = config.exemptionsManager;
        admissionPolicyId = admissionPolicyId_;
        (universeRule, emptyRule) = IRuleRegistry(IPolicyManager(config.policyManager).ruleRegistry()).genesis();

        if (universeRule == NULL_BYTES32)
            revert Unacceptable({ reason: "the universe rule is not defined in the PolicyManager's RuleRegistry" });
        if (emptyRule == NULL_BYTES32)
            revert Unacceptable({ reason: "the empty rule is not defined in the PolicyManager's RuleRegistry" });

        emit KeyringGuardConfigured(
            config.keyringCredentials,
            config.policyManager,
            config.userPolicies,
            admissionPolicyId_,
            universeRule,
            emptyRule
        );
    }

    /**
     * @notice Checks keyringCache for cached PII credential. 
     * @param observer The user who must consent to reliance on degraded services.
     * @param subject The subject to inspect.
     * @return passed True if cached credential is new enough, or if degraded service mitigation is possible
     * and the user has provided consent. 
     */
    function checkZKPIICache(address observer, address subject) public override returns (bool passed) {
        passed = IKeyringCredentials(keyringCredentials).checkCredential(
            observer,
            subject,
            admissionPolicyId
        );
    }

    /**
     * @notice Check the trader wallet against all wallet checks in the policy configuration. 
     * @param observer The user who must consent to reliance on degraded services.
     * @param subject The subject to inspect.
     * @return passed True if the wallet check is new enough, or if the degraded service mitigation is possible
     * and the user has provided consent. 
     */
    function checkTraderWallet(address observer, address subject) public override returns (bool passed) {
       
        address[] memory walletChecks = IPolicyManager(policyManager).policyWalletChecks(admissionPolicyId);

        for (uint256 i = 0; i < walletChecks.length; i++) {
            if (!IWalletCheck(walletChecks[i]).checkWallet(
                observer, 
                subject, 
                admissionPolicyId
            )) return false;
        }
        return true;
    }

    /**
     * @notice Check from and to addresses for compliance. 
     * @param from First trader wallet to inspect. 
     * @param to Second trader wallet to inspect. 
     * @return passed True, if both parties are compliant.
     * @dev Both parties are compliant, where compliant means:
     *  - they have a cached credential and if required, a wallet check 
     *  - they are an approved counterparty of the other party
     *  - they can rely on degraded service mitigation, and their counterparty consents
     *  - the policy exempts them from compliance checks, usually reserved for contracts
     */
    function isAuthorized(address from, address to) public override returns (bool passed) {
        
        bool fromIsApprovedByTo;
        bool toIsApprovedByFrom;
        bool fromExempt;
        bool toExempt;

        // A party is compliant if it is exempt. 

        fromExempt = IExemptionsManager(exemptionsManager).isPolicyExemption(
            admissionPolicyId,
            from
        );
        toExempt = IExemptionsManager(exemptionsManager).isPolicyExemption(
            admissionPolicyId,
            to
        );

        // If both parties are exempt, allow the trade. 
        
        if(fromExempt && toExempt) return true;

        // If the policy is disabled and both parties consent, allow all trades.
        // If the policy is disabled and one or more parties does not consent, block trade. 
       
        if(IPolicyManager(policyManager).policyDisabled(admissionPolicyId)) {
            if (
                userConsentDeadlines[from] > block.timestamp || fromExempt &&
                userConsentDeadlines[to] > block.timestamp || toExempt) 
            {
                return true;
            } else {
                return false;
            }
        }

        // A party is compliant if the counterparty approves interactions with them.

        bool policyAllowApprovedCounterparties = 
            IPolicyManager(policyManager).policyAllowApprovedCounterparties(admissionPolicyId);

        if (policyAllowApprovedCounterparties) {
            fromIsApprovedByTo = IUserPolicies(userPolicies).isApproved(to, from);
            toIsApprovedByFrom = IUserPolicies(userPolicies).isApproved(from, to);
        }

        // Is not authorized if wallet check or cached credential does not pass.
        // Cache may rely on degraded service mitigation and user consent.

        if (!fromExempt && !fromIsApprovedByTo) {
            if (!checkTraderWallet(to, from)) return false;
            if (!checkZKPIICache(to, from)) return false;
        }

        if (!toExempt && !toIsApprovedByFrom) {
            if (!checkTraderWallet(from, to)) return false; 
            if (!checkZKPIICache(from, to)) return false;
        }

        // Trade is acceptable
        return true;
    }
}


// File: @openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/ERC20Permit.sol)

pragma solidity ^0.8.0;

import "./IERC20Permit.sol";
import "../ERC20.sol";
import "../../../utils/cryptography/ECDSA.sol";
import "../../../utils/cryptography/EIP712.sol";
import "../../../utils/Counters.sol";

/**
 * @dev Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * _Available since v3.4._
 */
abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712 {
    using Counters for Counters.Counter;

    mapping(address => Counters.Counter) private _nonces;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
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
    constructor(string memory name) EIP712(name, "1") {}

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

        bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "ERC20Permit: invalid signature");

        _approve(owner, spender, value);
    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view virtual override returns (uint256) {
        return _nonces[owner].current();
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
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }
}


// File: @openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/ERC20Wrapper.sol)

pragma solidity ^0.8.0;

import "../ERC20.sol";
import "../utils/SafeERC20.sol";

/**
 * @dev Extension of the ERC20 token contract to support token wrapping.
 *
 * Users can deposit and withdraw "underlying tokens" and receive a matching number of "wrapped tokens". This is useful
 * in conjunction with other modules. For example, combining this wrapping mechanism with {ERC20Votes} will allow the
 * wrapping of an existing "basic" ERC20 into a governance token.
 *
 * _Available since v4.2._
 */
abstract contract ERC20Wrapper is ERC20 {
    IERC20 private immutable _underlying;

    constructor(IERC20 underlyingToken) {
        require(underlyingToken != this, "ERC20Wrapper: cannot self wrap");
        _underlying = underlyingToken;
    }

    /**
     * @dev See {ERC20-decimals}.
     */
    function decimals() public view virtual override returns (uint8) {
        try IERC20Metadata(address(_underlying)).decimals() returns (uint8 value) {
            return value;
        } catch {
            return super.decimals();
        }
    }

    /**
     * @dev Returns the address of the underlying ERC-20 token that is being wrapped.
     */
    function underlying() public view returns (IERC20) {
        return _underlying;
    }

    /**
     * @dev Allow a user to deposit underlying tokens and mint the corresponding number of wrapped tokens.
     */
    function depositFor(address account, uint256 amount) public virtual returns (bool) {
        address sender = _msgSender();
        require(sender != address(this), "ERC20Wrapper: wrapper can't deposit");
        SafeERC20.safeTransferFrom(_underlying, sender, address(this), amount);
        _mint(account, amount);
        return true;
    }

    /**
     * @dev Allow a user to burn a number of wrapped tokens and withdraw the corresponding number of underlying tokens.
     */
    function withdrawTo(address account, uint256 amount) public virtual returns (bool) {
        _burn(_msgSender(), amount);
        SafeERC20.safeTransfer(_underlying, account, amount);
        return true;
    }

    /**
     * @dev Mint wrapped token to cover any underlyingTokens that would have been transferred by mistake. Internal
     * function that can be exposed with access control if desired.
     */
    function _recover(address account) internal virtual returns (uint256) {
        uint256 value = _underlying.balanceOf(address(this)) - totalSupply();
        _mint(account, value);
        return value;
    }
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


// File: contracts/interfaces/IKeyringGuard.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

/**
 * @notice KeyringGuard implementation that uses immutables and presents a simplified modifier.
 */

interface IKeyringGuard {

    struct KeyringConfig {
        address trustedForwarder;
        address collateralToken;
        address keyringCredentials;
        address policyManager;
        address userPolicies;
        address exemptionsManager;
    }

    event KeyringGuardConfigured(
        address keyringCredentials,
        address policyManager,
        address userPolicies,
        uint32 admissionPolicyId,
        bytes32 universeRule,
        bytes32 emptyRule
    );

    function checkZKPIICache(address observer, address subject) external returns (bool passed);

    function checkTraderWallet(address observer, address subject) external returns (bool passed);

    function isAuthorized(address from, address to) external returns (bool passed);
}

// File: contracts/interfaces/IRuleRegistry.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import "../lib/Bytes32Set.sol";

interface IRuleRegistry {

    enum Operator {
        Base,
        Union,
        Intersection,
        Complement
    }

    struct Rule {
        string description;
        string uri;
        Bytes32Set.Set operandSet;
        Operator operator;
        bool toxic;
    }

    event RuleRegistryDeployed(address deployer, address trustedForwarder);

    event RuleRegistryInitialized(
        address admin,
        string universeDescription,
        string universeUri,
        string emptyDescription,
        string emptyUri,
        bytes32 universeRule,
        bytes32 emptyRule
    );

    event CreateRule(
        address indexed user,
        bytes32 indexed ruleId,
        string description,
        string uri,
        bool toxic,
        Operator operator,
        bytes32[] operands
    );

    event SetToxic(address admin, bytes32 ruleId, bool isToxic);

    function ROLE_RULE_ADMIN() external view returns (bytes32);

    function init(
        string calldata universeDescription,
        string calldata universeUri,
        string calldata emptyDescription,
        string calldata emptyUri
    ) external;

    function createRule(
        string calldata description,
        string calldata uri,
        Operator operator,
        bytes32[] calldata operands
    ) external returns (bytes32 ruleId);

    function setToxic(bytes32 ruleId, bool toxic) external;

    function genesis() external view returns (bytes32 universeRule, bytes32 emptyRule);

    function ruleCount() external view returns (uint256 count);

    function ruleAtIndex(uint256 index) external view returns (bytes32 ruleId);

    function isRule(bytes32 ruleId) external view returns (bool isIndeed);

    function rule(bytes32 ruleId)
        external
        view
        returns (
            string memory description,
            string memory uri,
            Operator operator,
            uint256 operandCount
        );

    function ruleDescription(bytes32 ruleId) external view returns (string memory description);

    function ruleUri(bytes32 ruleId) external view returns (string memory uri);

    function ruleIsToxic(bytes32 ruleId) external view returns (bool isIndeed);

    function ruleOperator(bytes32 ruleId) external view returns (Operator operator);

    function ruleOperandCount(bytes32 ruleId) external view returns (uint256 count);

    function ruleOperandAtIndex(bytes32 ruleId, uint256 index)
        external
        view
        returns (bytes32 operandId);

    function generateRuleId(
        string calldata description,
        Operator operator,
        bytes32[] calldata operands
    ) external pure returns (bytes32 ruleId);

}


// File: contracts/interfaces/IPolicyManager.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import "../lib/PolicyStorage.sol";

interface IPolicyManager {

    event PolicyManagerDeployed(
        address deployer, 
        address trustedForwarder, 
        address ruleRegistry);
    
    event PolicyManagerInitialized(address admin);

    event CreatePolicy(
        address indexed owner,
        uint32 indexed policyId,
        PolicyStorage.PolicyScalar policyScalar,
        address[] attestors,
        address[] walletChecks,
        bytes32 policyOwnerRole,
        bytes32 policyUserAdminRole
    );

    event DisablePolicy(address user, uint32 policyId);

    event UpdatePolicyScalar(
        address indexed owner,
        uint32 indexed policyId,
        PolicyStorage.PolicyScalar policyScalar,
        uint256 deadline);

    event UpdatePolicyDescription(address indexed owner, uint32 indexed policyId, string description, uint256 deadline);
    
    event UpdatePolicyRuleId(address indexed owner, uint32 indexed policyId, bytes32 indexed ruleId, uint256 deadline);

    event UpdatePolicyTtl(address indexed owner, uint32 indexed policyId, uint128 ttl, uint256 deadline);

    event UpdatePolicyGracePeriod(
        address indexed owner, 
        uint32 indexed policyId, 
        uint128 gracePeriod, 
        uint256 deadline);

    event UpdatePolicyLock(address indexed owner, uint32 indexed policyId, bool locked, uint256 deadline);

    event UpdatePolicyAllowApprovedCounterparties(
        address indexed owner, 
        uint32 indexed policyId, 
        bool allowApprovedCounterparties, 
        uint256 deadline);

    event UpdatePolicyDisablementPeriod(
        address indexed admin, 
        uint32 indexed policyId, 
        uint256 disablementPeriod, 
        uint256 deadline
    );

    event PolicyDisabled(address indexed sender, uint32 indexed policyId);

    event UpdatePolicyDeadline(address indexed owner, uint32 indexed policyId, uint256 deadline);

    event AddPolicyAttestors(
        address indexed owner,
        uint32 indexed policyId,
        address[] attestors,
        uint256 deadline
    );
    
    event RemovePolicyAttestors(
        address indexed owner,
        uint32 indexed policyId,
        address[] attestor,
        uint256 deadline
    );

    event AddPolicyWalletChecks(
        address indexed owner,
        uint32 indexed policyId,
        address[] walletChecks,
        uint256 deadline
    );

    event RemovePolicyWalletChecks(
        address indexed owner,
        uint32 indexed policyId,
        address[] walletChecks,
        uint256 deadline
    );

    event AddPolicyBackdoor(
        address indexed owner,
        uint32 indexed policyId,
        bytes32 backdoorId,
        uint256 deadline
    );

    event RemovePolicyBackdoor(
        address indexed owner,
        uint32 indexed policyId,
        bytes32 backdoorId,
        uint256 deadline
    );  

    event AdmitAttestor(address indexed admin, address indexed attestor, string uri);
    
    event UpdateAttestorUri(address indexed admin, address indexed attestor, string uri);
    
    event RemoveAttestor(address indexed admin, address indexed attestor);

    event AdmitWalletCheck(address indexed admin, address indexed walletCheck);

    event RemoveWalletCheck(address indexed admin, address indexed walletCheck);

    event AdmitBackdoor(address indexed admin, bytes32 id, uint256[2] pubKey);

    event MinimumPolicyDisablementPeriodUpdated(uint256 newPeriod);

    function ROLE_POLICY_CREATOR() external view returns (bytes32);

    function ROLE_GLOBAL_ATTESTOR_ADMIN() external view returns (bytes32);

    function ROLE_GLOBAL_WALLETCHECK_ADMIN() external view returns (bytes32);

    function ROLE_GLOBAL_VALIDATION_ADMIN() external view returns (bytes32);

    function ROLE_GLOBAL_BACKDOOR_ADMIN() external view returns (bytes32);

    function ruleRegistry() external view returns (address);

    function init() external;

    function createPolicy(
        PolicyStorage.PolicyScalar calldata policyScalar,
        address[] calldata attestors,
        address[] calldata walletChecks
    ) external returns (uint32 policyId, bytes32 policyOwnerRoleId, bytes32 policyUserAdminRoleId);

    function disablePolicy(uint32 policyId) external;

    function updatePolicyScalar(
        uint32 policyId,
        PolicyStorage.PolicyScalar calldata policyScalar,
        uint256 deadline
    ) external;

    function updatePolicyDescription(uint32 policyId, string memory descriptionUtf8, uint256 deadline) external;

    function updatePolicyRuleId(uint32 policyId, bytes32 ruleId, uint256 deadline) external;

    function updatePolicyTtl(uint32 policyId, uint32 ttl, uint256 deadline) external;

    function updatePolicyGracePeriod(uint32 policyId, uint32 gracePeriod, uint256 deadline) external;

    function updatePolicyAllowApprovedCounterparties(
        uint32 policyId, 
        bool allowApprovedCounterparties,uint256 deadline
    ) external;
    
    function updatePolicyLock(uint32 policyId, bool locked, uint256 deadline) external;

    function updatePolicyDisablementPeriod(uint32 policyId, uint256 disablementPeriod, uint256 deadline) external;

    function setDeadline(uint32 policyId, uint256 deadline) external;

    function addPolicyAttestors(uint32 policyId, address[] calldata attestors, uint256 deadline) external;

    function removePolicyAttestors(uint32 policyId, address[] calldata attestors, uint256 deadline) external;

    function addPolicyWalletChecks(uint32 policyId, address[] calldata walletChecks, uint256 deadline) external;

    function removePolicyWalletChecks(uint32 policyId, address[] calldata walletChecks, uint256 deadline) external;

    function addPolicyBackdoor(uint32 policyId, bytes32 backdoorId, uint256 deadline) external;

    function removePolicyBackdoor(uint32 policyId, bytes32 backdoorId, uint256 deadline) external;

    function admitAttestor(address attestor, string calldata uri) external;

    function updateAttestorUri(address attestor, string calldata uri) external;

    function removeAttestor(address attestor) external;

    function admitWalletCheck(address walletCheck) external;

    function removeWalletCheck(address walletCheck) external;

    function admitBackdoor(uint256[2] memory pubKey) external;

    function updateMinimumPolicyDisablementPeriod(uint256 minimumDisablementPeriod) external;

    function policyOwnerRole(uint32 policyId) external pure returns (bytes32 ownerRole);

    function policy(uint32 policyId)
        external
        returns (
            PolicyStorage.PolicyScalar memory scalar,
            address[] memory attestors,
            address[] memory walletChecks,
            bytes32[] memory backdoorRegimes,
            uint256 deadline
        );

    function policyRawData(uint32 policyId)
        external
        view
        returns(
            uint256 deadline,
            PolicyStorage.PolicyScalar memory scalarActive,
            PolicyStorage.PolicyScalar memory scalarPending,
            address[] memory attestorsActive,
            address[] memory attestorsPendingAdditions,
            address[] memory attestorsPendingRemovals,
            address[] memory walletChecksActive,
            address[] memory walletChecksPendingAdditions,
            address[] memory walletChecksPendingRemovals,
            bytes32[] memory backdoorsActive,
            bytes32[] memory backdoorsPendingAdditions,
            bytes32[] memory backdoorsPendingRemovals);

    function policyScalarActive(uint32 policyId) 
        external 
        returns (PolicyStorage.PolicyScalar memory scalarActive);

    function policyRuleId(uint32 policyId)
        external
        returns (bytes32 ruleId);

    function policyTtl(uint32 policyId) 
        external
        returns (uint32 ttl);

    function policyAllowApprovedCounterparties(uint32 policyId) 
        external
        returns (bool isAllowed);

    function policyDisabled(uint32 policyId) external view returns (bool isDisabled);

    function policyCanBeDisabled(uint32 policyId) 
        external
        returns (bool canIndeed);

    function policyAttestorCount(uint32 policyId) external returns (uint256 count);

    function policyAttestorAtIndex(uint32 policyId, uint256 index)
        external
        returns (address attestor);

    function policyAttestors(uint32 policyId) external returns (address[] memory attestors);

    function isPolicyAttestor(uint32 policyId, address attestor)
        external
        returns (bool isIndeed);

    function policyWalletCheckCount(uint32 policyId) external returns (uint256 count);

    function policyWalletCheckAtIndex(uint32 policyId, uint256 index)
        external
        returns (address walletCheck);

    function policyWalletChecks(uint32 policyId) external returns (address[] memory walletChecks);

    function isPolicyWalletCheck(uint32 policyId, address walletCheck)
        external
        returns (bool isIndeed);

    function policyBackdoorCount(uint32 policyId) external returns (uint256 count);

    function policyBackdoorAtIndex(uint32 policyId, uint256 index) external returns (bytes32 backdoorId);

    function policyBackdoors(uint32 policyId) external returns (bytes32[] memory backdoors);

    function isPolicyBackdoor(uint32 policyId, bytes32 backdoorId) external returns (bool isIndeed);

    function policyCount() external view returns (uint256 count);

    function isPolicy(uint32 policyId) external view returns (bool isIndeed);

    function globalAttestorCount() external view returns (uint256 count);

    function globalAttestorAtIndex(uint256 index) external view returns (address attestor);

    function isGlobalAttestor(address attestor) external view returns (bool isIndeed);

    function globalWalletCheckCount() external view returns (uint256 count);

    function globalWalletCheckAtIndex(uint256 index) external view returns(address walletCheck);

    function isGlobalWalletCheck(address walletCheck) external view returns (bool isIndeed);

    function globalBackdoorCount() external view returns (uint256 count);

    function globalBackdoorAtIndex(uint256 index) external view returns (bytes32 backdoorId);

    function isGlobalBackdoor(bytes32 backdoorId) external view returns (bool isIndeed);    

    function backdoorPubKey(bytes32 backdoorId) external view returns (uint256[2] memory pubKey);
    
    function attestorUri(address attestor) external view returns (string memory);

    function hasRole(bytes32 role, address user) external view returns (bool);

    function minimumPolicyDisablementPeriod()  external view returns (uint256 period);
  }


// File: contracts/interfaces/IUserPolicies.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface IUserPolicies {

    event Deployed(address trustedForwarder, address policyManager);

    event SetUserPolicy(address indexed trader, uint32 indexed policyId);

    event AddApprovedCounterparty(address indexed, address indexed approved);

    event RemoveApprovedCounterparty(address indexed, address indexed approved);

    function userPolicies(address trader) external view returns (uint32);

    function setUserPolicy(uint32 policyId) external;

    function addApprovedCounterparty(address approved) external;

    function addApprovedCounterparties(address[] calldata approved) external;

    function removeApprovedCounterparty(address approved) external;

    function removeApprovedCounterparties(address[] calldata approved) external;

    function approvedCounterpartyCount(address trader) external view returns (uint256 count);

    function approvedCounterpartyAtIndex(address trader, uint256 index) external view returns (address approved);

    function isApproved(address trader, address counterparty) external view returns (bool isIndeed);
}

// File: contracts/interfaces/IWalletCheck.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface IWalletCheck {

    event Deployed(
        address indexed admin, 
        address trustedForwarder,
        address policyManager,
        uint256 maximumConsentPeriod,
        string uri);

    event UpdateUri(address indexed admin, string uri);
    
    event SetWalletCheck(address indexed admin, address indexed wallet, bool isWhitelisted);

    function ROLE_WALLETCHECK_LIST_ADMIN() external view returns (bytes32);

    function ROLE_WALLETCHECK_META_ADMIN() external view returns (bytes32);

    function updateUri(string calldata uri_) external;

    function setWalletCheck(address wallet, bool whitelisted, uint256 timestamp) external;

    function checkWallet(
        address observer, 
        address wallet,
        uint32 admissionPolicyId
    ) external returns (bool passed);
}


// File: contracts/interfaces/IKeyringCredentials.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface IKeyringCredentials {
    
    event CredentialsDeployed(
        address deployer, 
        address trustedForwarder, 
        address policyManager, 
        uint256 maximumConsentPeriod);

    event CredentialsInitialized(address admin);

    event UpdateCredential(
        uint8 version, 
        address updater, 
        address indexed trader, 
        uint32 indexed admissionPolicyId);

    function ROLE_CREDENTIAL_UPDATER() external view returns (bytes32);

    function init() external;

    function setCredential(
        address trader,  
        uint32 admissionPolicyId,
        uint256 timestamp
    ) external;

    function checkCredential(
        address observer,
        address subject,
        uint32 admissionPolicyId
    ) external returns (bool passed);

    function keyGen(
        address trader,
        uint32 admissionPolicyId
    ) external pure returns (bytes32 key);

}


// File: contracts/interfaces/IExemptionsManager.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface IExemptionsManager {
   
    event ExemptionsManagerInitialized(address indexed admin, address indexed policyManager);

    event AdmitGlobalExemption(address indexed admin, address indexed exemption, string description);

    event UpdateGlobalExemption(address indexed admin, address indexed exemption, string description);

    event ApprovePolicyExemptions(address indexed admin, uint32 policyId, address indexed exemption);

    function ROLE_GLOBAL_EXEMPTIONS_ADMIN() external view returns (bytes32);

    function policyManager() external view returns (address);

    function exemptionDescriptions(address) external view returns (string memory);

    function init(address policyManager_) external;

    function admitGlobalExemption(address[] calldata exemptAddresses, string memory description) external;

    function updateGlobalExemption(address exemptAddress, string memory description) external;

    function approvePolicyExemptions(uint32 policyId, address[] memory exemptions) external;

    function globalExemptionsCount() external view returns (uint256 count);

    function globalExemptionAtIndex(uint256 index) external view returns (address exemption);

    function isGlobalExemption(address exemption) external view returns (bool isIndeed);

    function policyExemptionsCount(uint32 policyId) external view returns (uint256 count);

    function policyExemptionAtIndex(uint32 policyId, uint256 index) external view returns (address exemption);

    function isPolicyExemption(uint32 policyId, address exemption) external view returns (bool isIndeed);

}

// File: contracts/consent/Consent.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import "../interfaces/IConsent.sol";
import "../access/KeyringAccessControl.sol";

contract Consent is IConsent, KeyringAccessControl {

    uint256 private constant MINIMUM_MAX_CONSENT_PERIOD = 1 hours;
    uint256 public immutable override maximumConsentPeriod;

    /**
     * @dev Mapping of Traders to their associated consent deadlines.
     */
    mapping(address => uint256) public override userConsentDeadlines;

    /**
     * @param trustedForwarder The address of a trustedForwarder contract.
     * @param maximumConsentPeriod_ The upper limit for user consent deadlines. 
     */
    constructor(
        address trustedForwarder, 
        uint256 maximumConsentPeriod_
    ) 
        KeyringAccessControl(trustedForwarder)
    {
        if (maximumConsentPeriod_ < MINIMUM_MAX_CONSENT_PERIOD)
            revert Unacceptable({
                reason: "The maximum consent period must be at least 1 hour"
            });

        maximumConsentPeriod = maximumConsentPeriod_;
    }

    /**
     * @notice A user may grant consent to service mitigation measures. 
     * @dev The deadline must be no further in the future than the maximumConsentDeadline.
     * @param revocationDeadline The consent will automatically expire at the deadline. 
     */
    function grantDegradedServiceConsent(uint256 revocationDeadline) external override {
        if(revocationDeadline < block.timestamp)
            revert Unacceptable({
                reason: "revocation deadline cannot be in the past"
            });
        if(revocationDeadline > block.timestamp + maximumConsentPeriod)
            revert Unacceptable({
                reason: "revocation deadline is too far in the future"
            });
        userConsentDeadlines[_msgSender()] = revocationDeadline;
        emit GrantDegradedServiceConsent(_msgSender(), revocationDeadline);
    }

    /**
     * @notice A user may revoke their consent to mitigation measures. 
     */
    function revokeMitigationConsent() external override {
        userConsentDeadlines[_msgSender()] = 0;
        emit RevokeDegradedServiceConsent(_msgSender());
    }

    /**
     * @param user The user to inspect. 
     * @return doesIndeed True if the user's consent deadline is in the future.
     */
    function userConsentsToMitigation(address user) public view override returns (bool doesIndeed) {
        doesIndeed = userConsentDeadlines[user] >= block.timestamp;
    }

}

// File: contracts/lib/Bytes32Set.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

/**
 * @notice Key sets with enumeration. Uses mappings for random and existence checks
 * and dynamic arrays for enumeration. Key uniqueness is enforced.
 * @dev This implementation has deletion disabled (removed) because doesn't require it. Therefore, keys
 are organized in order of insertion.
 */

library Bytes32Set {

    struct Set {
        mapping(bytes32 => uint256) keyPointers;
        bytes32[] keyList;
    }

    string private constant MODULE = "Bytes32Set";

    error Bytes32SetConsistency(string module, string method, string reason, string context);

    /**
     * @notice Insert a key to store.
     * @dev Duplicate keys are not permitted.
     * @param self A Set struct
     * @param key A value in the Set.
     * @param context A message string about interpretation of the issue. Normally the calling function.
     */
    function insert(
        Set storage self,
        bytes32 key,
        string memory context
    ) internal {
        if (exists(self, key))
            revert Bytes32SetConsistency({
                module: MODULE,
                method: "insert",
                reason: "exists",
                context: context
            });
        self.keyPointers[key] = self.keyList.length;
        self.keyList.push(key);
    }


    /**
     * @notice Remove a key from the store.
     * @dev The key to remove must exist.
     * @param self A Set struct
     * @param key An address to remove from the Set.
     * @param context A message string about interpretation of the issue. Normally the calling function.
     */
    function remove(
        Set storage self,
        bytes32 key,
        string memory context
    ) internal {
        if (!exists(self, key))
            revert Bytes32SetConsistency({
                module: MODULE,
                method: "remove",
                reason: "does not exist",
                context: context
            });
        bytes32 keyToMove = self.keyList[count(self) - 1];
        uint256 rowToReplace = self.keyPointers[key];
        self.keyPointers[keyToMove] = rowToReplace;
        self.keyList[rowToReplace] = keyToMove;
        delete self.keyPointers[key];
        self.keyList.pop();
    }

    /**
     * @notice Count the keys.
     * @param self A Set struct
     * @return uint256 Length of the `keyList` which is the count of keys contained in the Set.
     */
    function count(Set storage self) internal view returns (uint256) {
        return (self.keyList.length);
    }

    /**
     * @notice Check if a key exists in the Set.
     * @param self A Set struct
     * @param key A key to look for.
     * @return bool True if the key exists in the Set, otherwise false.
     */
    function exists(Set storage self, bytes32 key) internal view returns (bool) {
        if (self.keyList.length == 0) return false;
        return self.keyList[self.keyPointers[key]] == key;
    }

    /**
     * @notice Retrieve an bytes32 by its position in the Set. Use for enumeration.
     * @param self A Set struct
     * @param index The position in the Set to inspect.
     * @return bytes32 The key stored in the Set at the index position.
     */
    function keyAtIndex(Set storage self, uint256 index) internal view returns (bytes32) {
        return self.keyList[index];
    }
}


// File: contracts/lib/PolicyStorage.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import "./AddressSet.sol";
import "../interfaces/IRuleRegistry.sol";
import "../interfaces/IIdentityTree.sol";
import "../interfaces/IDegradable.sol";
import "../interfaces/IKeyringCredentials.sol";

/**
 @notice PolicyStorage attends to state management concerns for the PolicyManager. It establishes the
 storage layout and is responsible for internal state integrity and managing state transitions. The 
 PolicyManager is responsible for orchestration of the functions implemented here as well as access
 control. 
 */

library PolicyStorage {

    using AddressSet for AddressSet.Set;
    using Bytes32Set for Bytes32Set.Set;

    uint32 private constant MAX_POLICIES = 2 ** 20;
    uint32 private constant MAX_TTL = 2 * 365 days;
    uint256 public constant MAX_DISABLEMENT_PERIOD = 120 days;
    uint256 private constant MAX_BACKDOORS = 1;
    uint256 private constant UNIVERSAL_RULE = 0;
    address private constant NULL_ADDRESS = address(0);

    error Unacceptable(string reason);

    /// @dev The App struct contains the essential PolicyManager state including an array of Policies. 

    struct App {
        uint256 minimumPolicyDisablementPeriod;
        Policy[] policies;
        AddressSet.Set globalWalletCheckSet;
        AddressSet.Set globalAttestorSet;        
        mapping(address => string) attestorUris;
        Bytes32Set.Set backdoorSet;
        mapping(bytes32 => uint256[2]) backdoorPubKey;
    }

    /// @dev PolicyScalar contains the non-indexed values in a policy configuration.

    struct PolicyScalar {
        bytes32 ruleId;
        string descriptionUtf8;
        uint32 ttl;
        uint32 gracePeriod;
        bool allowApprovedCounterparties;
        uint256 disablementPeriod;
        bool locked;
    }

    /// @dev PolicyAttestors contains the active policy attestors as well as scheduled changes. 

    struct PolicyAttestors {
        AddressSet.Set activeSet;
        AddressSet.Set pendingAdditionSet;
        AddressSet.Set pendingRemovalSet;
    }

    /// @dev PolicyWalletChecks contains the active policy wallet checks as well as scheduled changes.

    struct PolicyWalletChecks {
        AddressSet.Set activeSet;
        AddressSet.Set pendingAdditionSet;
        AddressSet.Set pendingRemovalSet;
    }

    /// @dev PolicyBackdoors contain and active policy backdoors (identifiers) as well as scheduled changes. 

    struct PolicyBackdoors {
        Bytes32Set.Set activeSet;
        Bytes32Set.Set pendingAdditionSet;
        Bytes32Set.Set pendingRemovalSet;
    }

    /// @dev Policy contains the active and scheduled changes and the deadline when the changes will
    /// take effect.
    
    struct Policy {
        bool disabled;
        uint256 deadline;
        PolicyScalar scalarActive;
        PolicyScalar scalarPending;
        PolicyAttestors attestors;
        PolicyWalletChecks walletChecks;
        PolicyBackdoors backdoors;
    }

    /** 
     * @notice A policy can be disabled if the policy is deemed failed. 
     * @param policyObj The policy to disable.
     */
    function disablePolicy(
        Policy storage policyObj
    ) public 
    {
        if (!policyHasFailed(policyObj))
            revert Unacceptable({
                reason: "only failed policies can be disabled"
            });
        policyObj.disabled = true;
        policyObj.deadline = ~uint(0);
    }

    /**
     * @notice A policy is deemed failed if all attestors or any wallet check is inactive
     * over the policyDisablement period. 
     * @param policyObj The policy to inspect.
     * @return hasIndeed True if all attestors have failed or any wallet check has failed, 
     where "failure" is no updates over the policyDisablement period. 
     */
    function policyHasFailed(
        Policy storage policyObj
    ) public view returns (bool hasIndeed) 
    {
        if (policyObj.disabled == true) 
            revert Unacceptable({
                reason: "policy is already disabled"
            });
        
        uint256 i;
        uint256 disablementPeriod = policyObj.scalarActive.disablementPeriod;

        // If all attestors have failed
        bool allAttestorsHaveFailed = true;
        uint256 policyAttestorsCount = policyObj.attestors.activeSet.count();
        for (i=0; i<policyAttestorsCount; i++) {
            uint256 lastUpdate = IDegradable(policyObj.attestors.activeSet.keyAtIndex(i)).lastUpdate();
            // We ignore unitialized services to prevent interference with new policies.
            if (lastUpdate > 0) {
               if(block.timestamp < lastUpdate + disablementPeriod) {
                    allAttestorsHaveFailed = false;
               }
            } else {
                // No evidence of interrupted activity yet
                allAttestorsHaveFailed = false;
            }
        }

        if(!allAttestorsHaveFailed) {
            // If any wallet check has failed
            uint256 policyWalletChecksCount = policyObj.walletChecks.activeSet.count();
            for (i=0; i<policyWalletChecksCount; i++) {
                uint256 lastUpdate = IDegradable(policyObj.walletChecks.activeSet.keyAtIndex(i)).lastUpdate();
                if (lastUpdate > 0) {
                    if(block.timestamp > lastUpdate + disablementPeriod) return true;
                }
            }
        }
        hasIndeed = allAttestorsHaveFailed;
    }

    /**
     * @notice Updates the minimumPolicyDisablementPeriod property of the Policy struct.
     * @param self A storage reference to the App storage
     * @param minimumDisablementPeriod The new value for the minimumPolicyDisablementPeriod property.
     */
    function updateMinimumPolicyDisablementPeriod(
        App storage self, 
        uint256 minimumDisablementPeriod 
    ) public 
    {
        if (minimumDisablementPeriod >= MAX_DISABLEMENT_PERIOD) 
            revert Unacceptable({
                reason: "minimum disablement period is too long"
            });
        self.minimumPolicyDisablementPeriod = minimumDisablementPeriod;
    }

    /**
     * @notice The attestor admin can admit attestors into the global attestor whitelist. 
     * @param self PolicyManager App state.
     * @param attestor Address of the attestor's identity tree contract.
     * @param uri The URI refers to detailed information about the attestor.
     */
    function insertGlobalAttestor(
        App storage self,
        address attestor,
        string memory uri
    ) public
    {
        if (attestor == NULL_ADDRESS)
            revert Unacceptable({
                reason: "attestor cannot be empty"
            });
        if (bytes(uri).length == 0) 
            revert Unacceptable({
                reason: "uri cannot be empty"
            });        
        self.globalAttestorSet.insert(attestor, "PolicyStorage:insertGlobalAttestor");
        self.attestorUris[attestor] = uri;
    }

    /**
     * @notice The attestor admin can update the informational URIs for attestors on the whitelist.
     * @dev No onchain logic relies on the URI.
     * @param self PolicyManager App state.
     * @param attestor Address of an attestor's identity tree contract on the whitelist. 
     * @param uri The URI refers to detailed information about the attestor.
     */
    function updateGlobalAttestorUri(
        App storage self, 
        address attestor,
        string memory uri
    ) public
    {
        if (!self.globalAttestorSet.exists(attestor))
            revert Unacceptable({
                reason: "attestor not found"
            });
        if (bytes(uri).length == 0) 
            revert Unacceptable({
                reason: "uri cannot be empty"
            });  
        self.attestorUris[attestor] = uri;
    }

    /**
     * @notice The attestor admin can remove attestors from the whitelist.
     * @dev Does not remove attestors from policies that recognise the attestor to remove. 
     * @param self PolicyManager App state.
     * @param attestor Address of an attestor identity tree to remove from the whitelist. 
     */
    function removeGlobalAttestor(
        App storage self,
        address attestor
    ) public
    {
        self.globalAttestorSet.remove(attestor, "PolicyStorage:removeGlobalAttestor");
    }

    /**
     * @notice The wallet check admin can admit wallet check contracts into the system.
     * @dev Wallet checks implement the IWalletCheck interface.
     * @param self PolicyManager App state.
     * @param walletCheck The address of a Wallet Check to admit into the global whitelist.
     */
    function insertGlobalWalletCheck(
        App storage self,
        address walletCheck
    ) public
    {
        if (walletCheck == NULL_ADDRESS)
            revert Unacceptable({
                reason: "walletCheck cannot be empty"
            });
        self.globalWalletCheckSet.insert(walletCheck, "PolicyStorage:insertGlobalWalletCheck");
    }

    /**
     * @notice The wallet check admin can remove a wallet check from the system.
     * @dev Does not affect policies that utilize the wallet check. 
     * @param self PolicyManager App state.
     * @param walletCheck The address of a Wallet Check to admit into the global whitelist.
     */
    function removeGlobalWalletCheck(
        App storage self,
        address walletCheck
    ) public
    {
        self.globalWalletCheckSet.remove(walletCheck, "PolicyStorage:removeGlobalWalletCheck");
    }

    /**
     * @notice The backdoor admin can add a backdoor.
     * @dev pubKey must be unique.
     * @param self PolicyManager App state.
     * @param pubKey The public key for backdoor encryption. 
     */
    function insertGlobalBackdoor(
        App storage self, 
        uint256[2] calldata pubKey
    ) public returns (bytes32 id)
    {
        id = keccak256(abi.encodePacked(pubKey));
        self.backdoorPubKey[id] = pubKey;
        self.backdoorSet.insert(
                id,
                "PolicyStorage:insertGlobalBackdoor"
        );
    }

    /**
     * @notice Creates a new policy that is owned by the creator.
     * @dev Maximum unique policies is 2 ^ 20. Must be at least 1 attestor.
     * @param self PolicyManager App state.
     * @param policyScalar The new policy's non-indexed values. 
     * @param attestors A list of attestor identity tree contracts.
     * @param walletChecks The address of one or more Wallet Checks to add to the Policy.
     * @param ruleRegistry The address of the deployed RuleRegistry contract.
     * @return policyId A PolicyStorage struct.Id The unique identifier of a Policy.
     */
    function newPolicy(
        App storage self,
        PolicyScalar calldata policyScalar,
        address[] memory attestors,
        address[] memory walletChecks,
        address ruleRegistry
    ) public returns (uint32 policyId) 
    {
        (bytes32 universeRule, bytes32 emptyRule) = IRuleRegistry(ruleRegistry).genesis();
        
        // Check that there is at least one attestor for the policy
        if (
            attestors.length < 1 && 
            policyScalar.ruleId != universeRule &&
            policyScalar.ruleId != emptyRule) 
        {
            revert Unacceptable({
                reason: "every policy needs at least one attestor"
            });
        }
        
        uint256 i;
        self.policies.push();
        policyId = uint32(self.policies.length - 1);
        if (policyId >= MAX_POLICIES)
            revert Unacceptable({
                reason: "max policies exceeded"
            });
        Policy storage policyObj = policyRawData(self, policyId);
        uint256 deadline = block.timestamp;

        writePolicyScalar(
            self,
            policyId,
            policyScalar,
            ruleRegistry,
            deadline
        );

        processStaged(policyObj);

        for (i=0; i<attestors.length; i++) {
            address attestor = attestors[i];
            if (!self.globalAttestorSet.exists(attestor))
                revert Unacceptable({
                    reason: "attestor not found"
                });
            policyObj.attestors.activeSet.insert(attestor, "PolicyStorage:newPolicy");
        }

        for (i=0; i<walletChecks.length; i++) {
            address walletCheck = walletChecks[i];
            if (!self.globalWalletCheckSet.exists(walletCheck))
                revert Unacceptable({
                    reason: "walletCheck not found"
                });
            policyObj.walletChecks.activeSet.insert(walletCheck, "PolicyStorage:newPolicy");
        }
    }

    /**
     * @notice Returns the internal policy state without processing staged changes. 
     * @dev Staged changes with deadlines in the past are presented as pending. 
     * @param self PolicyManager App state.
     * @param policyId A PolicyStorage struct.Id The unique identifier of a Policy.
     * @return policyInfo Policy info in the internal storage format without processing.
     */
    function policyRawData(
        App storage self, 
        uint32 policyId
    ) public view returns (Policy storage policyInfo) 
    {
        policyInfo = self.policies[policyId];
    }

    /**
     * @param activeSet The active set of addresses.
     * @param additionSet The set of pending addresses to add to the active set.
     */
    function _processAdditions(
    AddressSet.Set storage activeSet, 
    AddressSet.Set storage additionSet
    ) private {
        uint256 count = additionSet.count();
        while (count > 0) {
            address entity = additionSet.keyAtIndex(additionSet.count() - 1);
            activeSet.insert(entity, "policyStorage:_processAdditions");
            additionSet.remove(entity, "policyStorage:_processAdditions");
            count--;
        }
    }

    /**
     * @param activeSet The active set of bytes32.
     * @param additionSet The set of pending bytes32 to add to the active set.
     */
    function _processAdditions(
    Bytes32Set.Set storage activeSet, 
    Bytes32Set.Set storage additionSet
    ) private {
        uint256 count = additionSet.count();
        while (count > 0) {
            bytes32 entity = additionSet.keyAtIndex(additionSet.count() - 1);
            activeSet.insert(entity, "policyStorage:_processAdditions");
            additionSet.remove(entity, "policyStorage:_processAdditions");
            count--;
        }
    }

    /**
     * @param activeSet The active set of addresses.
     * @param removalSet The set of pending addresses to remove from the active set.
     */
    function _processRemovals(
        AddressSet.Set storage activeSet, 
        AddressSet.Set storage removalSet
    ) private {
        uint256 count = removalSet.count();
        while (count > 0) {
            address entity = removalSet.keyAtIndex(removalSet.count() - 1);
            activeSet.remove(entity, "policyStorage:_processRemovals");
            removalSet.remove(entity, "policyStorage:_processRemovals");
            count--;
        }
    }

    /**
     * @param activeSet The active set of bytes32.
     * @param removalSet The set of pending bytes32 to remove from the active set.
     */
    function _processRemovals(
        Bytes32Set.Set storage activeSet, 
        Bytes32Set.Set storage removalSet
    ) private {
        uint256 count = removalSet.count();
        while (count > 0) {
            bytes32 entity = removalSet.keyAtIndex(removalSet.count() - 1);
            activeSet.remove(entity, "policyStorage:_processRemovals");
            removalSet.remove(entity, "policyStorage:_processRemovals");
            count--;
        }
    }

    /**
     * @notice Processes staged changes to the policy state if the deadline is in the past.
     * @dev Always call this before inspecting the the active policy state. .
     * @param policyObj A Policy object.
     */
    function processStaged(Policy storage policyObj) public {
        uint256 deadline = policyObj.deadline;
        if (deadline > 0 && deadline <= block.timestamp) {
            policyObj.scalarActive = policyObj.scalarPending;

            _processAdditions(policyObj.attestors.activeSet, policyObj.attestors.pendingAdditionSet);
            _processRemovals(policyObj.attestors.activeSet, policyObj.attestors.pendingRemovalSet);

            _processAdditions(policyObj.walletChecks.activeSet, policyObj.walletChecks.pendingAdditionSet);
            _processRemovals(policyObj.walletChecks.activeSet, policyObj.walletChecks.pendingRemovalSet);

            _processAdditions(policyObj.backdoors.activeSet, policyObj.backdoors.pendingAdditionSet);
            _processRemovals(policyObj.backdoors.activeSet, policyObj.backdoors.pendingRemovalSet);

            policyObj.deadline = 0;
        }
    }


    /**
     * @notice Prevents changes to locked and disabled Policies.
     * @dev Reverts if the active policy lock is set to true or the Policy is disabled.
     * @param policyObj A Policy object.
     */
    function checkLock(
        Policy storage policyObj
    ) public view 
    {
        if (isLocked(policyObj) || policyObj.disabled)
            revert Unacceptable({
                reason: "policy is locked"
            });
    }

    /**
     * @notice Inspect the active policy lock.
     * @param policyObj A Policy object.
     * @return isIndeed True if the active policy locked parameter is set to true. True value if PolicyStorage
     is locked, otherwise False.
     */
    function isLocked(Policy storage policyObj) public view returns(bool isIndeed) {
        isIndeed = policyObj.scalarActive.locked;
    }

    /**
     * @notice Processes staged changes if the current deadline has passed and updates the deadline. 
     * @dev The deadline must be at least as far in the future as the active policy gracePeriod. 
     * @param policyObj A Policy object.
     * @param deadline The timestamp when the staged changes will take effect. Overrides previous deadline.
     */
    function setDeadline(
        Policy storage policyObj, 
        uint256 deadline
    ) public
    {
        checkLock(policyObj);

        // Deadline of 0 allows staging of changes with no implementation schedule.
        // Positive deadlines must be at least graceTime seconds in the future.
     
        if (deadline != 0 && 
            (deadline < block.timestamp + policyObj.scalarActive.gracePeriod)
        )
            revert Unacceptable({
                reason: "deadline in the past or too soon"
        });
        policyObj.deadline = deadline;
    }

    /**
     * @notice Non-indexed Policy values can be updated in one step. 
     * @param self PolicyManager App state.
     * @param policyId A PolicyStorage struct.Id The unique identifier of a Policy.
     * @param policyScalar The new non-indexed properties. 
     * @param ruleRegistry The address of the deployed RuleRegistry contract. 
     * @param deadline The timestamp when the staged changes will take effect. Overrides previous deadline.
     */
    function writePolicyScalar(
        App storage self,
        uint32 policyId,
        PolicyStorage.PolicyScalar calldata policyScalar,
        address ruleRegistry,
        uint256 deadline
    ) public {
        PolicyStorage.Policy storage policyObj = policyRawData(self, policyId);
        processStaged(policyObj);
        writeRuleId(policyObj, policyScalar.ruleId, ruleRegistry);
        writeDescription(policyObj, policyScalar.descriptionUtf8);
        writeTtl(policyObj, policyScalar.ttl);
        writeGracePeriod(policyObj, policyScalar.gracePeriod);
        writeAllowApprovedCounterparties(policyObj, policyScalar.allowApprovedCounterparties);
        writePolicyLock(policyObj, policyScalar.locked);
        writeDisablementPeriod(self, policyId, policyScalar.disablementPeriod);
        setDeadline(policyObj, deadline);
    }

    /**
     * @notice Writes a new RuleId to the pending Policy changes in a Policy.
     * @param self A Policy object.
     * @param ruleId The unique identifier of a Rule.
     * @param ruleRegistry The address of the deployed RuleRegistry contract. 
     */
    function writeRuleId(
        Policy storage self, 
        bytes32 ruleId, 
        address ruleRegistry
    ) public
    {
        if (!IRuleRegistry(ruleRegistry).isRule(ruleId))
            revert Unacceptable({
                reason: "rule not found"
            });
        self.scalarPending.ruleId = ruleId;
    }

    /**
     * @notice Writes a new descriptionUtf8 to the pending Policy changes in a Policy.
     * @param self A Policy object.
     * @param descriptionUtf8 Policy description in UTF-8 format. 
     */
    function writeDescription(
        Policy storage self, 
        string memory descriptionUtf8
    ) public
    {
        if (bytes(descriptionUtf8).length == 0) 
            revert Unacceptable({
                reason: "descriptionUtf8 cannot be empty"
            });
        self.scalarPending.descriptionUtf8 = descriptionUtf8;
    }

    /**
     * @notice Writes a new ttl to the pending Policy changes in a Policy.
     * @param self A Policy object.
     * @param ttl The maximum acceptable credential age in seconds.
     */
    function writeTtl(
        Policy storage self,
        uint32 ttl
    ) public
    {
        if (ttl > MAX_TTL) 
            revert Unacceptable({ reason: "ttl exceeds maximum duration" });
        self.scalarPending.ttl = ttl;
    }

    /**
     * @notice Writes a new gracePeriod to the pending Policy changes in a Policy. 
     * @dev Deadlines must always be >= the active policy grace period. 
     * @param self A Policy object.
     * @param gracePeriod The minimum acceptable deadline.
     */
    function writeGracePeriod(
        Policy storage self,
        uint32 gracePeriod
    ) public
    {
        // 0 is acceptable
        self.scalarPending.gracePeriod = gracePeriod;
    }

    /**
     * @notice Writes a new allowApprovedCounterparties state in the pending Policy changes in a Policy. 
     * @param self A Policy object.
     * @param allowApprovedCounterparties True if whitelists are allowed, otherwise false.
     */
    function writeAllowApprovedCounterparties(
        Policy storage self,
        bool allowApprovedCounterparties
    ) public
    {
        self.scalarPending.allowApprovedCounterparties = allowApprovedCounterparties;
    }

    /**
     * @notice Writes a new locked state in the pending Policy changes in a Policy.
     * @param self A Policy object.
     * @param setPolicyLocked True if the policy is to be locked, otherwise false.
     */
    function writePolicyLock(
        Policy storage self,
        bool setPolicyLocked
    ) public
    {
        self.scalarPending.locked = setPolicyLocked;
    }

    /**
     * @notice Writes a new disablement deadline to the pending Policy changes of a Policy.
     * @dev If the provided disablement deadline is in the past, this function will revert. 
     * @param self A PolicyStorage object.
     * @param disablementPeriod The new disablement deadline to set, in seconds since the Unix epoch.
     *   If set to 0, the policy can be disabled at any time.
     *   If set to a non-zero value, the policy can only be disabled after that time.
     */

    function writeDisablementPeriod(
        App storage self,
        uint32 policyId,
        uint256 disablementPeriod
    ) public {
        // Check that the new disablement period is greater than or equal to the minimum
        if (disablementPeriod < self.minimumPolicyDisablementPeriod) {
            revert Unacceptable({
                reason: "disablement period is too short"
            });
        }
        if (disablementPeriod >= MAX_DISABLEMENT_PERIOD) {
            revert Unacceptable({
                reason: "disablement period is too long"
            });
        }
        Policy storage policyObj = self.policies[policyId];
        policyObj.scalarPending.disablementPeriod = disablementPeriod;
    }

    /**
     * @notice Writes attestors to pending Policy attestor additions. 
     * @param self PolicyManager App state.
     * @param policyObj A Policy object.
     * @param attestors The address of one or more Attestors to add to the Policy.
     */
    function writeAttestorAdditions(
        App storage self,
        Policy storage policyObj,
        address[] calldata attestors
    ) public
    {
        for (uint i = 0; i < attestors.length; i++) {
            _writeAttestorAddition(self, policyObj, attestors[i]);
        }        
    }

    /**
     * @notice Writes an attestor to pending Policy attestor additions. 
     * @dev If the attestor is scheduled to be remove, unschedules the removal. 
     * @param self PolicyManager App state.
     * @param policyObj A Policy object. 
     * @param attestor The address of an Attestor to add to the Policy.
     */
    function _writeAttestorAddition(
        App storage self,
        Policy storage policyObj,
        address attestor
    ) private
    {
        if (!self.globalAttestorSet.exists(attestor))
            revert Unacceptable({
                reason: "attestor not found"
            });
        if (policyObj.attestors.pendingRemovalSet.exists(attestor)) {
            policyObj.attestors.pendingRemovalSet.remove(attestor, "PolicyStorage:_writeAttestorAddition");
        } else {
            if (policyObj.attestors.activeSet.exists(attestor)) {
                revert Unacceptable({
                    reason: "attestor already in policy"
                });
            }
            policyObj.attestors.pendingAdditionSet.insert(attestor, "PolicyStorage:_writeAttestorAddition");
        }
    }

    /**
     * @notice Writes attestors to pending Policy attestor removals. 
     * @param self A Policy object.
     * @param attestors The address of one or more Attestors to remove from the Policy.
     */
    function writeAttestorRemovals(
        Policy storage self,
        address[] calldata attestors
    ) public
    {
        for (uint i = 0; i < attestors.length; i++) {
            _writeAttestorRemoval(self, attestors[i]);
        }
    }

    /**
     * @notice Writes an attestor to a Policy's pending attestor removals. 
     * @dev Cancels the addition if the attestor is scheduled to be added. 
     * @param self PolicyManager App state.
     * @param attestor The address of a Attestor to remove from the Policy.
     */
    function _writeAttestorRemoval(
        Policy storage self,
        address attestor
    ) private
    {
        
        uint currentAttestorCount = self.attestors.activeSet.count();
        uint pendingAdditionsCount = self.attestors.pendingAdditionSet.count();
        uint pendingRemovalsCount = self.attestors.pendingRemovalSet.count();

        if (currentAttestorCount + pendingAdditionsCount - pendingRemovalsCount < 2) {
            revert Unacceptable({
                reason: "Cannot remove the last attestor. Add a replacement first"
            });
        }
        
        if (self.attestors.pendingAdditionSet.exists(attestor)) {
            self.attestors.pendingAdditionSet.remove(attestor, "PolicyStorage:_writeAttestorRemoval");
        } else {
            if (!self.attestors.activeSet.exists(attestor)) {
                revert Unacceptable({
                    reason: "attestor not found"
                });
            }
            self.attestors.pendingRemovalSet.insert(attestor, "PolicyStorage:_writeAttestorRemoval");
        }
    }

    /**
     * @notice Writes wallet checks to a Policy's pending wallet check additions.
     * @param self PolicyManager App state.
     * @param policyObj A PolicyStorage object.
     * @param walletChecks The address of one or more Wallet Checks to add to the Policy.
     */
    function writeWalletCheckAdditions(
        App storage self,
        Policy storage policyObj,
        address[] memory walletChecks
    ) public
    {
        for (uint i = 0; i < walletChecks.length; i++) {
            _writeWalletCheckAddition(self, policyObj, walletChecks[i]);
        }
    }

    /**
     * @notice Writes a wallet check to a Policy's pending wallet check additions. 
     * @dev Cancels removal if the wallet check is scheduled for removal. 
     * @param self PolicyManager App state.
     * @param policyObj A Policy object. 
     * @param walletCheck The address of a Wallet Check to admit into the global whitelist.
     */
    function _writeWalletCheckAddition(
        App storage self,
        Policy storage policyObj,
        address walletCheck
    ) private
    {
        if (!self.globalWalletCheckSet.exists(walletCheck))
            revert Unacceptable({
                reason: "walletCheck not found"
            });
        if (policyObj.walletChecks.pendingRemovalSet.exists(walletCheck)) {
            policyObj.walletChecks.pendingRemovalSet.remove(walletCheck, "PolicyStorage:_writeWalletCheckAddition");
        } else {
            if (policyObj.walletChecks.activeSet.exists(walletCheck)) {
                revert Unacceptable({
                    reason: "walletCheck already in policy"
                });
            }
            if (policyObj.walletChecks.pendingAdditionSet.exists(walletCheck)) {
                revert Unacceptable({
                    reason: "walletCheck addition already scheduled"
                });
            }
            policyObj.walletChecks.pendingAdditionSet.insert(walletCheck, "PolicyStorage:_writeWalletCheckAddition");
        }
    }

    /**
     * @notice Writes wallet checks to a Policy's pending wallet check removals. 
     * @param self A Policy object.
     * @param walletChecks The address of one or more Wallet Checks to add to the Policy.
     */
    function writeWalletCheckRemovals(
        Policy storage self,
        address[] memory walletChecks
    ) public
    {
        for (uint i = 0; i < walletChecks.length; i++) {
            _writeWalletCheckRemoval(self, walletChecks[i]);
        }
    }

    /**
     * @notice Writes a wallet check to a Policy's pending wallet check removals. 
     * @dev Unschedules addition if the wallet check is present in the Policy's pending wallet check additions. 
     * @param self A Policy object.
     * @param walletCheck The address of a Wallet Check to remove from the Policy. 
     */
    function _writeWalletCheckRemoval(
        Policy storage self,
        address walletCheck
    ) private
    {
        if (self.walletChecks.pendingAdditionSet.exists(walletCheck)) {
            self.walletChecks.pendingAdditionSet.remove(walletCheck, "PolicyStorage:_writeWalletCheckRemoval");
        } else {
            if (!self.walletChecks.activeSet.exists(walletCheck)) {
                revert Unacceptable({
                    reason: "walletCheck is not in policy"
                });
            }
            if (self.walletChecks.pendingRemovalSet.exists(walletCheck)) {
                revert Unacceptable({
                    reason: "walletCheck removal already scheduled"
                });
            }
            self.walletChecks.pendingRemovalSet.insert(walletCheck, "PolicyStorage:_writeWalletCheckRemoval");
        }
    }

    /**
     * @notice Add a backdoor to a policy.
     * @param self The application state. 
     * @param policyObj A Policy object.
     * @param backdoorId The ID of a backdoor. 
     */
    function writeBackdoorAddition(
        App storage self,
        Policy storage policyObj,
        bytes32 backdoorId
    ) public {
        if (!self.backdoorSet.exists(backdoorId)) {
            revert Unacceptable({
                reason: "unknown backdoor"
            });
        }
        if (policyObj.backdoors.pendingRemovalSet.exists(backdoorId)) {
            policyObj.backdoors.pendingRemovalSet.remove(backdoorId, 
            "PolicyStorage:writeBackdoorAddition");
        } else {
            if (policyObj.backdoors.activeSet.exists(backdoorId)) {
                revert Unacceptable({
                    reason: "backdoor exists in policy"
                });
            }
            if (policyObj.backdoors.pendingAdditionSet.exists(backdoorId)) {
                revert Unacceptable({
                    reason: "backdoor addition already scheduled"
                });
            }
            policyObj.backdoors.pendingAdditionSet.insert(backdoorId, 
            "PolicyStorage:_writeWalletCheckAddition");
            _checkBackdoorConfiguration(policyObj);
        }
    }

    /**
     * @notice Writes a wallet check to a Policy's pending wallet check removals. 
     * @dev Unschedules addition if the wallet check is present in the Policy's pending wallet check additions. 
     * @param self A Policy object.
     * @param backdoorId The address of a Wallet Check to remove from the Policy. 
     */
    function writeBackdoorRemoval(
        Policy storage self,
        bytes32 backdoorId
    ) public
    {
        if (self.backdoors.pendingAdditionSet.exists(backdoorId)) {
            self.backdoors.pendingAdditionSet.remove(backdoorId, 
            "PolicyStorage:writeBackdoorRemoval");
        } else {
            if (!self.backdoors.activeSet.exists(backdoorId)) {
                revert Unacceptable({
                    reason: "backdoor is not in policy"
                });
            }
            if (self.backdoors.pendingRemovalSet.exists(backdoorId)) {
                revert Unacceptable({
                    reason: "backdoor removal already scheduled"
                });
            }
            self.backdoors.pendingRemovalSet.insert(backdoorId, 
            "PolicyStorage:writeBackdoorRemoval");
        }
    }

    /**
     * @notice Checks the net count of backdoors.
     * @dev Current zkVerifier supports only one backdoor per policy.
     * @param self A policy object.
     */
    function _checkBackdoorConfiguration(
        Policy storage self
    ) internal view {
        uint256 activeCount = self.backdoors.activeSet.count();
        uint256 pendingAdditionsCount = self.backdoors.pendingAdditionSet.count();
        uint256 pendingRemovalsCount = self.backdoors.pendingRemovalSet.count();
        if(activeCount + pendingAdditionsCount - pendingRemovalsCount > MAX_BACKDOORS) {
            revert Unacceptable({ reason: "too many backdoors requested" });
        }
    }

    /**********************************************************
     Inspection
     **********************************************************/

    /**
     * @param self Application state.
     * @param policyId The unique identifier of a Policy.
     * @return policyObj Policy object with staged updates processed.
     */
    function policy(App storage self, uint32 policyId)
        public
        returns (Policy storage policyObj)
    {
        policyObj = self.policies[policyId];
        processStaged(policyObj);
    }

}


// File: contracts/lib/AddressSet.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

/**
 * @notice Key sets with enumeration and delete. Uses mappings for random access and existence checks,
 * and dynamic arrays for enumeration. Key uniqueness is enforced.
 * @dev Sets are unordered. Delete operations reorder keys.
 */

library AddressSet {

    struct Set {
        mapping(address => uint256) keyPointers;
        address[] keyList;
    }

    string private constant MODULE = "AddressSet";

    error AddressSetConsistency(string module, string method, string reason, string context);

    /**
     * @notice Insert a key to store.
     * @dev Duplicate keys are not permitted.
     * @param self A Set struct
     * @param key A key to insert cast as an address.
     * @param context A message string about interpretation of the issue. Normally the calling function.
     */
    function insert(
        Set storage self,
        address key,
        string memory context
    ) internal {
        if (exists(self, key))
            revert AddressSetConsistency({
                module: MODULE,
                method: "insert",
                reason: "exists",
                context: context
            });
        self.keyList.push(key);
        self.keyPointers[key] = self.keyList.length - 1;
    }

    /**
     * @notice Remove a key from the store.
     * @dev The key to remove must exist.
     * @param self A Set struct
     * @param key An address to remove from the Set.
     * @param context A message string about interpretation of the issue. Normally the calling function.
     */
    function remove(
        Set storage self,
        address key,
        string memory context
    ) internal {
        if (!exists(self, key))
            revert AddressSetConsistency({
                module: MODULE,
                method: "remove",
                reason: "does not exist",
                context: context
            });
        address keyToMove = self.keyList[count(self) - 1];
        uint256 rowToReplace = self.keyPointers[key];
        self.keyPointers[keyToMove] = rowToReplace;
        self.keyList[rowToReplace] = keyToMove;
        delete self.keyPointers[key];
        self.keyList.pop();
    }

    /**
     * @notice Count the keys.
     * @param self A Set struct
     * @return uint256 Length of the `keyList`, which correspond to the number of elements
     * stored in the `keyPointers` mapping.
     */
    function count(Set storage self) internal view returns (uint256) {
        return (self.keyList.length);
    }

    /**
     * @notice Check if a key exists in the Set.
     * @param self A Set struct
     * @param key An address to look for in the Set.
     * @return bool True if the key exists in the Set, otherwise false.
     */
    function exists(Set storage self, address key) internal view returns (bool) {
        if (self.keyList.length == 0) return false;
        return self.keyList[self.keyPointers[key]] == key;
    }

    /**
     * @notice Retrieve an address by its position in the set. Use for enumeration.
     * @param self A Set struct
     * @param index The internal index to inspect.
     * @return address Address value stored at the index position in the Set.
     */
    function keyAtIndex(Set storage self, uint256 index) internal view returns (address) {
        return self.keyList[index];
    }
}


// File: contracts/interfaces/IIdentityTree.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface IIdentityTree {

    event Deployed(
        address admin, 
        address trustedForwarder_, 
        address policyManager_, 
        uint256 maximumConsentPeriod);
    
    event SetMerkleRootBirthday(bytes32 merkleRoot, uint256 birthday);

    struct PolicyMitigation {
        uint256 mitigationFreshness;
        uint256 degradationPeriod;
    }

    function ROLE_AGGREGATOR() external view returns (bytes32);
   
    function setMerkleRootBirthday(bytes32 root, uint256 birthday) external;

    function checkRoot(
        address observer, 
        bytes32 merkleRoot,
        uint32 admissionPolicyId
    ) external returns (bool passed);

    function merkleRootCount() external view returns (uint256 count);

    function merkleRootAtIndex(uint256 index) external view returns (bytes32 merkleRoot);

    function isMerkleRoot(bytes32 merkleRoot) external view returns (bool isIndeed);

    function latestRoot() external view returns (bytes32 root);
}


// File: contracts/interfaces/IDegradable.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface IDegradable {

    event SetPolicyParameters(
        address indexed admin, 
        uint32 indexed policyId, 
        uint256 degradationPeriod, 
        uint256 degradationFreshness);

    struct MitigationParameters {
        uint256 degradationPeriod;
        uint256 degradationFreshness;
    }

    function ROLE_SERVICE_SUPERVISOR() external view returns (bytes32);

    function defaultDegradationPeriod() external view returns (uint256);

    function defaultFreshnessPeriod() external view returns (uint256);

    function policyManager() external view returns (address);

    function lastUpdate() external view returns (uint256);

    function subjectUpdates(bytes32 subject) external view returns (uint256 timestamp);

    function setPolicyParameters(
        uint32 policyId,
        uint256 degradationPeriod,
        uint256 degradationFreshness
    ) external;

    function canMitigate(
        address observer, 
        bytes32 subject, 
        uint32 policyId
    ) external view returns (bool canIndeed) ;

    function isDegraded(uint32 policyId) external view returns (bool isIndeed);

    function isMitigationQualified(
        bytes32 subject,
        uint32 policyId
    ) external view returns (bool qualifies);

    function degradationPeriod(uint32 policyId) external view returns (uint256 inSeconds);

    function degradationFreshness(uint32 policyId) external view returns (uint256 inSeconds);

    function mitigationCutoff(uint32 policyId) external view returns (uint256 cutoffTime);
}

// File: contracts/interfaces/IConsent.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface IConsent {

    event GrantDegradedServiceConsent(address indexed user, uint256 revocationDeadline);

    event RevokeDegradedServiceConsent(address indexed user);

    function maximumConsentPeriod() external view returns (uint256);

    function userConsentDeadlines(address user) external view returns (uint256);

    function grantDegradedServiceConsent(uint256 revocationDeadline) external;

    function revokeMitigationConsent() external;

    function userConsentsToMitigation(address user) external view returns (bool doesIndeed);

}


// File: contracts/access/KeyringAccessControl.sol
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

/**
 @notice This contract manages the role-based access control via _checkRole() with meaningful 
 error messages if the user does not have the requested role. This contract is inherited by 
 PolicyManager, RuleRegistry, KeyringCredentials, IdentityTree, WalletCheck and 
 KeyringZkCredentialUpdater.
 */

abstract contract KeyringAccessControl is ERC2771Context, AccessControl {

    address private constant NULL_ADDRESS = address(0);

    // Reservations hold space in upgradeable contracts for future versions of this module.
    bytes32[50] private _reservedSlots;

    error Unacceptable(string reason);

    error Unauthorized(
        address sender,
        string module,
        string method,
        bytes32 role,
        string reason,
        string context
    );

    /**
     * @param trustedForwarder Contract address that is allowed to relay message signers.
     */
    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {
        if (trustedForwarder == NULL_ADDRESS)
            revert Unacceptable({
                reason: "trustedForwarder cannot be empty"
            });
    }

    /**
     * @notice Disables incomplete ERC165 support inherited from oz/AccessControl.sol
     * @return bool Never returned.
     * @dev Always reverts. Do not rely on ERC165 support to interact with this contract.
     */
    function supportsInterface(bytes4 /*interfaceId */) public view virtual override returns (bool) {
        revert Unacceptable ({ reason: "ERC2165 is unsupported" });
    }

    /**
     * @notice Role-based access control.
     * @dev Reverts if the account is missing the role.
     * @param role The role to check. 
     * @param account An address to check for the role.
     * @param context For reporting purposes. Usually the function that requested the permission check.
     */
    function _checkRole(
        bytes32 role,
        address account,
        string memory context
    ) internal view {
        if (!hasRole(role, account))
            revert Unauthorized({
                sender: account,
                module: "KeyringAccessControl",
                method: "_checkRole",
                role: role,
                reason: "sender does not have the required role",
                context: context
            });
    }

    /**
     * @notice Returns ERC2771 signer if msg.sender is a trusted forwarder, otherwise returns msg.sender.
     * @return sender User deemed to have signed the transaction.
     */
    function _msgSender()
        internal
        view
        virtual
        override(Context, ERC2771Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    /**
     * @notice Returns msg.data if not from a trusted forwarder, or truncated msg.data if the signer was 
     appended to msg.data
     * @dev Although not currently used, this function forms part of ERC2771 so is included for completeness.
     * @return data Data deemed to be the msg.data
     */
    function _msgData()
        internal
        view
        virtual
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }
}


// File: @openzeppelin/contracts/access/AccessControl.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

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
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
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
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(account),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
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
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
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
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
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
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
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
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}


// File: @openzeppelin/contracts/metatx/ERC2771Context.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (metatx/ERC2771Context.sol)

pragma solidity ^0.8.9;

import "../utils/Context.sol";

/**
 * @dev Context variant with ERC2771 support.
 */
abstract contract ERC2771Context is Context {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable _trustedForwarder;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) {
        _trustedForwarder = trustedForwarder;
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}


// File: @openzeppelin/contracts/access/IAccessControl.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
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
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
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


// File: @openzeppelin/contracts/token/ERC20/ERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
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
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

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
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
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
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
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
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
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
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
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
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
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

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
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

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
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

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
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

        _allowances[owner][spender] = amount;
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


// File: @openzeppelin/contracts/utils/cryptography/EIP712.sol
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
        return keccak256(abi.encode(_TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
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


// File: @openzeppelin/contracts/utils/Counters.sol
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


// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol
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


// File: @openzeppelin/contracts/utils/ShortStrings.sol
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
    bytes32 private constant _FALLBACK_SENTINEL = 0x00000000000000000000000000000000000000000000000000000000000000FF;

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
    function toShortStringWithFallback(string memory value, string storage store) internal returns (ShortString) {
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
    function toStringWithFallback(ShortString value, string storage store) internal pure returns (string memory) {
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
    function byteLengthWithFallback(ShortString value, string storage store) internal view returns (uint256) {
        if (ShortString.unwrap(value) != _FALLBACK_SENTINEL) {
            return byteLength(value);
        } else {
            return bytes(store).length;
        }
    }
}


// File: @openzeppelin/contracts/interfaces/IERC5267.sol
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


// File: @openzeppelin/contracts/utils/StorageSlot.sol
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


