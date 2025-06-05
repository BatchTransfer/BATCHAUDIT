// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

/*
  ______                       _______                             __ 
 /      \                     |       \                           |  \
|  ▓▓▓▓▓▓\  ______    ______  | ▓▓▓▓▓▓▓\  ______   _______    ____| ▓▓
| ▓▓__| ▓▓ /      \  /      \ | ▓▓__/ ▓▓ /      \ |       \  /      ▓▓
| ▓▓    ▓▓|  ▓▓▓▓▓▓\|  ▓▓▓▓▓▓\| ▓▓    ▓▓|  ▓▓▓▓▓▓\| ▓▓▓▓▓▓▓\|  ▓▓▓▓▓▓▓
| ▓▓▓▓▓▓▓▓| ▓▓  | ▓▓| ▓▓    ▓▓| ▓▓▓▓▓▓▓\| ▓▓  | ▓▓| ▓▓  | ▓▓| ▓▓  | ▓▓
| ▓▓  | ▓▓| ▓▓__/ ▓▓| ▓▓▓▓▓▓▓▓| ▓▓__/ ▓▓| ▓▓__/ ▓▓| ▓▓  | ▓▓| ▓▓__| ▓▓
| ▓▓  | ▓▓| ▓▓    ▓▓ \▓▓     \| ▓▓    ▓▓ \▓▓    ▓▓| ▓▓  | ▓▓ \▓▓    ▓▓
 \▓▓   \▓▓| ▓▓▓▓▓▓▓   \▓▓▓▓▓▓▓ \▓▓▓▓▓▓▓   \▓▓▓▓▓▓  \▓▓   \▓▓  \▓▓▓▓▓▓▓
          | ▓▓                                                        
          | ▓▓                                                        
           \▓▓                                                         
 * App:             https://Ape.Bond
 * Medium:          https://ApeBond.medium.com
 * Twitter:         https://twitter.com/ApeBond
 * Telegram:        https://t.me/ape_bond
 * Announcements:   https://t.me/ApeBond_news
 * Discord:         https://ApeBond.click/discord
 * Reddit:          https://ApeBond.click/reddit
 * Instagram:       https://instagram.com/ape.bond
 * GitHub:          https://github.com/ApeSwapFinance
 */

import "./IApeBondRefillable.sol";
import "./ApeBond.sol";

/// @title ApeBondRefillable
/// @author ApeSwap.Finance
/// @notice Provides a method of refilling ApeBond contracts without needing owner rights
/// @dev Extends ApeBond
contract ApeBondRefillable is IApeBondRefillable, ApeBond {
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    event BillRefilled(address payoutToken, uint256 amountAdded);

    /**
     *  @notice Transfer payoutTokens from sender to customTreasury and update maxTotalPayout
     *  @param _refillAmount amount of payoutTokens to refill the ApeBond with
     */
    function refillPayoutToken(uint256 _refillAmount) external override nonReentrant onlyRole(OPERATIONS_ROLE) {
        require(_refillAmount > 0, "Amount is 0");
        require(customTreasury.billContract(address(this)), "Bill is disabled");
        uint256 balanceBefore = payoutToken.balanceOf(address(customTreasury));
        payoutToken.safeTransferFrom(msg.sender, address(customTreasury), _refillAmount);
        uint256 refillAmount = payoutToken.balanceOf(address(customTreasury)) - balanceBefore;
        require(refillAmount > 0, "No refill made");
        uint256 maxTotalPayout = terms.maxTotalPayout + refillAmount;
        terms.maxTotalPayout = maxTotalPayout;
        emit BillRefilled(address(payoutToken), refillAmount);
        emit MaxTotalPayoutChanged(maxTotalPayout);
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (access/AccessControlEnumerable.sol)

pragma solidity ^0.8.0;

import "./IAccessControlEnumerableUpgradeable.sol";
import "./AccessControlUpgradeable.sol";
import "../utils/structs/EnumerableSetUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Extension of {AccessControl} that allows enumerating the members of each role.
 */
abstract contract AccessControlEnumerableUpgradeable is Initializable, IAccessControlEnumerableUpgradeable, AccessControlUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    mapping(bytes32 => EnumerableSetUpgradeable.AddressSet) private _roleMembers;

    function __AccessControlEnumerable_init() internal onlyInitializing {
    }

    function __AccessControlEnumerable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view virtual override returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view virtual override returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Overload {_grantRole} to track enumerable memberships
     */
    function _grantRole(bytes32 role, address account) internal virtual override {
        super._grantRole(role, account);
        _roleMembers[role].add(account);
    }

    /**
     * @dev Overload {_revokeRole} to track enumerable memberships
     */
    function _revokeRole(bytes32 role, address account) internal virtual override {
        super._revokeRole(role, account);
        _roleMembers[role].remove(account);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

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
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721EnumerableUpgradeable is IERC721Upgradeable {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
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
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
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
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
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
     * - The `operator` cannot be the caller.
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
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;
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

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
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
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}// SPDX-License-Identifier: MIT
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
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

/*
  ______                       _______                             __ 
 /      \                     |       \                           |  \
|  ▓▓▓▓▓▓\  ______    ______  | ▓▓▓▓▓▓▓\  ______   _______    ____| ▓▓
| ▓▓__| ▓▓ /      \  /      \ | ▓▓__/ ▓▓ /      \ |       \  /      ▓▓
| ▓▓    ▓▓|  ▓▓▓▓▓▓\|  ▓▓▓▓▓▓\| ▓▓    ▓▓|  ▓▓▓▓▓▓\| ▓▓▓▓▓▓▓\|  ▓▓▓▓▓▓▓
| ▓▓▓▓▓▓▓▓| ▓▓  | ▓▓| ▓▓    ▓▓| ▓▓▓▓▓▓▓\| ▓▓  | ▓▓| ▓▓  | ▓▓| ▓▓  | ▓▓
| ▓▓  | ▓▓| ▓▓__/ ▓▓| ▓▓▓▓▓▓▓▓| ▓▓__/ ▓▓| ▓▓__/ ▓▓| ▓▓  | ▓▓| ▓▓__| ▓▓
| ▓▓  | ▓▓| ▓▓    ▓▓ \▓▓     \| ▓▓    ▓▓ \▓▓    ▓▓| ▓▓  | ▓▓ \▓▓    ▓▓
 \▓▓   \▓▓| ▓▓▓▓▓▓▓   \▓▓▓▓▓▓▓ \▓▓▓▓▓▓▓   \▓▓▓▓▓▓  \▓▓   \▓▓  \▓▓▓▓▓▓▓
          | ▓▓                                                        
          | ▓▓                                                        
           \▓▓                                                         
 * App:             https://Ape.Bond
 * Medium:          https://ApeBond.medium.com
 * Twitter:         https://twitter.com/ApeBond
 * Telegram:        https://t.me/ape_bond
 * Announcements:   https://t.me/ApeBond_news
 * Discord:         https://ApeBond.click/discord
 * Reddit:          https://ApeBond.click/reddit
 * Instagram:       https://instagram.com/ape.bond
 * GitHub:          https://github.com/ApeSwapFinance
 */

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./IApeBond.sol";
import "./ApeBondAccessControlUpgradeable.sol";
import "../IBondTreasury.sol";
import "../IBondNft.sol";
import "../curves/LinearVestingCurve.sol";
import "../interfaces/IVersionable.sol";

/**
 * @title ApeBond (ApeSwap Treasury Bill)
 * @author ApeSwap
 * @notice
 * - Control Variable is scaled up by 100x compared to v1.X.X.
 * - principalToken MUST NOT be a fee-on-transfer token
 * - payoutToken MAY be a fee-on-transfer, but it is HIGHLY recommended that
 *     the ApeBond and BondTreasury contracts are whitelisted from the
 *     fee-on-transfer. This is because the payoutToken makes multiple hops
 *     between contracts.
 * - DAO address deprecated and refactored to discountManager in v2.2.0
 */
contract ApeBond is
    IApeBond,
    Initializable,
    ApeBondAccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IVersionable
{
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    /* ======== VERSION ======== */

    string public constant override VERSION = "2.2.0";

    /* ======== EVENTS ======== */

    event FeeToChanged(address indexed newFeeTo);
    event MaxTotalPayoutChanged(uint256 newMaxTotalPayout);
    event UpdateClaimApproval(address indexed owner, address indexed approvedAccount, bool approved);
    event BillCreated(uint256 deposit, uint256 payout, uint256 expires, uint256 indexed billId);
    event BillClaimed(uint256 indexed billId, address indexed recipient, uint256 payout, uint256 remaining);
    event BillPriceChanged(uint256 internalPrice, uint256 debtRatio);
    event SetFees(uint256[] fees, uint256[] tierCeilings);
    event BillInitialized(BondTerms billTerms, uint256 lastDecay);
    event TermsSet(PARAMETER parameter, uint input);
    event ControlVariableAdjustment(uint256 initialBCV, uint256 newBCV);

    /* ======== STRUCTS ======== */

    struct FeeTiers {
        uint256 tierCeilings; // principal billed till next tier
        uint256 fees; // in millionths (i.e. 1e4 = 1%)
    }

    /* ======== STATE VARIABLES ======== */

    IERC20MetadataUpgradeable public payoutToken; // token paid for principal
    IERC20MetadataUpgradeable public principalToken; // inflow token
    IBondTreasury public customTreasury; // pays for and receives principal
    address public feeTo; // receives fee

    IBondNft public billNft;
    EnumerableSetUpgradeable.UintSet private billIssuedIds;
    IVestingCurve public vestingCurve;

    uint256 public totalPrincipalBilled;
    uint256 public totalPayoutGiven;
    uint256 public payoutTokenInitialSupply;

    BondTerms public terms; // stores terms for new bills
    FeeTiers[] public feeTiers; // stores fee tiers

    mapping(uint256 => Bill) public billInfo; // stores bill information for nfts
    mapping(address => mapping(address => bool)) public redeemerApproved; // Stores user approved redeemers

    uint256 public totalDebt; // total value of outstanding bills; used for pricing
    uint256 public lastDecay; // reference block for debt decay

    bool public feeInPayout;
    uint256 public constant MAX_FEE = 1e6;
    uint256 public lastBCVUpdateTimestamp; // Timestamp of the last BCV adjustment
    uint256 public minBCVUpdateInterval; // Minimum time between BCV adjustments in seconds

    /**
     * "Storage gaps are a convention for reserving storage slots in a base contract, allowing future
     *  versions of that contract to use up those slots without affecting the storage layout of child contracts."
     *
     *  For more info, see "Storage Gaps" at https://docs.openzeppelin.com/
     */
    uint256[50] private __gap;

    /* ======== MODIFIERS ======== */

    /* ======== INITIALIZATION ======== */

    function initialize(
        IBondTreasury _customTreasury,
        BondCreationDetails calldata _billCreationDetails,
        BondTerms calldata _billTerms,
        BondAccounts calldata _billAccounts,
        address[] calldata _billOperators
    ) public initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        __ApeBondAccessControlUpgradeable__init(
            _billCreationDetails.initialOwner,
            _billAccounts.discountManager,
            _billOperators
        );

        require(address(_customTreasury) != address(0), "customTreasury cannot be zero");
        customTreasury = _customTreasury;
        require(_billCreationDetails.payoutToken == _customTreasury.payoutToken());
        payoutToken = IERC20MetadataUpgradeable(_billCreationDetails.payoutToken);
        payoutTokenInitialSupply = payoutToken.totalSupply();
        require(_billCreationDetails.principalToken != address(0), "principalToken cannot be zero");
        principalToken = IERC20MetadataUpgradeable(_billCreationDetails.principalToken);
        uint256 currentTimestamp = block.timestamp;
        if (address(_billCreationDetails.vestingCurve) == address(0)) {
            vestingCurve = new LinearVestingCurve();
        } else {
            /// @dev Validate vesting curve
            _billCreationDetails.vestingCurve.getVestedPayoutAtTime(
                1e18,
                4000,
                currentTimestamp - 2000,
                currentTimestamp
            );
            vestingCurve = _billCreationDetails.vestingCurve;
        }
        require(_billAccounts.feeTo != address(0), "feeTo cannot be zero");
        feeTo = _billAccounts.feeTo;

        require(_billAccounts.billNft != address(0), "billNft cannot be zero");
        billNft = IBondNft(_billAccounts.billNft);
        require(_billCreationDetails.initialOwner != address(0), "owner cannot be zero");

        _setFeeTiers(_billCreationDetails.fees, _billCreationDetails.tierCeilings);
        feeInPayout = _billCreationDetails.feeInPayout;

        // Check and set billTerms
        require(currentDebt() == 0, "Debt must be 0");
        require(_billTerms.vestingTerm >= 129600, "Vesting must be >= 36 hours");
        require(_billTerms.controlVariable > 0, "CV must be above 1");

        terms = _billTerms;

        totalDebt = _billTerms.initialDebt;
        lastDecay = currentTimestamp;
        minBCVUpdateInterval = 6 hours;
        emit BillInitialized(_billTerms, currentTimestamp);
    }

    /* ======== OWNER FUNCTIONS ======== */

    enum PARAMETER {
        VESTING,
        MAX_PAYOUT,
        MAX_DEBT,
        MIN_PRICE,
        MAX_TOTAL_PAYOUT
    }

    /**
     *  @notice set parameters for new bills
     *  @param _parameter PARAMETER
     *  @param _input uint
     */
    function setBondTerms(PARAMETER _parameter, uint256 _input) external onlyOwner {
        if (_parameter == PARAMETER.VESTING) {
            // 0
            require(_input >= 129600, "Vesting must be >= 36 hours");
            terms.vestingTerm = _input;
        } else if (_parameter == PARAMETER.MAX_PAYOUT) {
            // 1
            terms.maxPayout = _input;
        } else if (_parameter == PARAMETER.MAX_DEBT) {
            // 2
            terms.maxDebt = _input;
        } else if (_parameter == PARAMETER.MIN_PRICE) {
            // 3
            terms.minimumPrice = _input;
        } else if (_parameter == PARAMETER.MAX_TOTAL_PAYOUT) {
            // 4
            require(_input >= totalPayoutGiven, "maxTotalPayout cannot be below totalPayoutGiven");
            terms.maxTotalPayout = _input;
        }
        emit TermsSet(_parameter, _input);
    }

    /**
     *  @notice helper function to view the maxTotalPayout
     *  @dev backward compatibility for V1
     *  @return uint256 max amount of payoutTokens to offer
     */
    function getMaxTotalPayout() external view returns (uint256) {
        return terms.maxTotalPayout;
    }

    /**
     *  @notice set the maxTotalPayout of payoutTokens
     *  @param _maxTotalPayout uint256 max amount of payoutTokens to offer
     */
    function setMaxTotalPayout(uint256 _maxTotalPayout) external onlyOwnerOrRole(OPERATIONS_ROLE) {
        require(_maxTotalPayout >= totalPayoutGiven, "maxTotalPayout <= totalPayout");
        terms.maxTotalPayout = _maxTotalPayout;
        emit MaxTotalPayoutChanged(_maxTotalPayout);
    }

    /**
     *  @notice Set fees based on totalPrincipalBilled
     *  @param fees Fee settings which corelate to the tierCeilings
     *  @param tierCeilings totalPrincipalBilled amount used to determine when to move to the next fee
     *
     *  Requirements
     *
     *  - tierCeilings MUST be in ascending order
     */
    function setFeeTiers(
        uint256[] memory fees,
        uint256[] memory tierCeilings
    ) external onlyOwnerOrRole(OPERATIONS_ROLE) {
        _setFeeTiers(fees, tierCeilings);
    }

    /**
     *  @notice set bond minimum price
     *  @param _target Final minimum price
     */
    function setMinPrice(uint256 _target) external onlyOwnerOrRoles(OPERATIONS_ROLE, DISCOUNT_MANAGER_ROLE) {
        require(_target > 0, "Target must be above 0");
        terms.minimumPrice = _target;
        emit TermsSet(PARAMETER.MIN_PRICE, _target);
    }

    /**
     *  @notice set control variable adjustment
     *  @param _target Final BCV to be adjusted to
     */
    function setBCV(uint256 _target) external onlyOwnerOrRoles(OPERATIONS_ROLE, DISCOUNT_MANAGER_ROLE) {
        require(_target > 0, "Target must be above 0");

        /// @dev in case bondManager key is leaked we have minBCVUpdateInterval seconds to react within the bound of max increase/decrease
        require(lastBCVUpdateTimestamp + minBCVUpdateInterval <= block.timestamp, "Too soon");
        //  Prevents a malicious actor from setting the BVC too high or low too fast
        uint256 maxChange;
        if (_target > terms.controlVariable) {
            /// @dev This is allowing a max price increase of 30% per adjustment
            maxChange = (terms.controlVariable * 300) / 1000;
            if (maxChange == 0) maxChange = 1;
            require(terms.controlVariable + maxChange >= _target, "Increment too large");
        } else {
            /// @dev This is allowing a max price decrease of 10% per adjustment
            maxChange = (terms.controlVariable * 100) / 1000;
            if (maxChange == 0) maxChange = 1;
            require(terms.controlVariable - maxChange <= _target, "Decrement too large");
            /// @dev Lower to avoid malicious exploits due to key leak
        }

        uint initial = terms.controlVariable;
        lastBCVUpdateTimestamp = block.timestamp;
        terms.controlVariable = _target;
        emit ControlVariableAdjustment(initial, terms.controlVariable);
    }

    /**
     *  @notice Change the minimum slope
     *  @param _newBCVUpdateInterval The new minimum slope
     */
    function changeBCVUpdateInterval(uint256 _newBCVUpdateInterval) external onlyOwner {
        require(_newBCVUpdateInterval > 0, "Invalid update interval");
        minBCVUpdateInterval = _newBCVUpdateInterval;
    }

    /**
     *  @notice change address of Treasury
     *  @param _feeTo address
     */
    function changeFeeTo(address _feeTo) external onlyOwner {
        require(_feeTo != address(0), "Cannot be address(0)");
        feeTo = _feeTo;
        emit FeeToChanged(feeTo);
    }

    /**
     * @notice Pauses the contract
     */
    function pause() public onlyOwnerOrRoles(OPERATIONS_ROLE, DISCOUNT_MANAGER_ROLE) {
        _pause();
    }

    /**
     *  @notice Unpauses the contract
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     *  @notice Transfer tokens to owner
     *  @param _token Token to transfer
     */
    function transferStuckToken(address _token, uint256 _amount) external onlyOwner {
        IERC20MetadataUpgradeable token = IERC20MetadataUpgradeable(_token);
        uint256 balance = token.balanceOf(address(this));
        if (_amount == 0 || _amount > balance) {
            token.safeTransfer(owner(), balance);
        } else {
            token.safeTransfer(owner(), _amount);
        }
    }

    /* ======== USER FUNCTIONS ======== */

    /**
     *  @notice Purchase a bill by depositing principalTokens
     *  @param _amount Amount of principalTokens to deposit/purchase a bill
     *  @param _maxPrice Max price willing to pay for for this deposit
     *  @param _depositor Address which will own the bill
     *  @return uint256 payout amount in payoutTokens
     *
     * Requirements
     * - Only Contracts can deposit on behalf of other accounts. Otherwise msg.sender MUST == _depositor.
     * - principalToken MUST NOT be a reflect token
     */
    function deposit(
        uint256 _amount,
        uint256 _maxPrice,
        address _depositor
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(_depositor != address(0), "Invalid address");
        require(msg.sender == _depositor || AddressUpgradeable.isContract(msg.sender), "no deposits to other address");

        _decayDebt();
        uint256 truePrice = trueBillPrice();
        require(_maxPrice >= truePrice, "Slippage more than max price"); // slippage protection
        // Calculate payout and fee
        uint256 depositAmount = _amount;
        uint256 payout;
        uint256 fee;
        if (feeInPayout) {
            (payout, fee) = payoutFor(_amount); // payout and fee is computed
        } else {
            (payout, fee) = payoutFor(_amount); // payout and fee is computed
            depositAmount -= fee;
        }
        // Increase totalDebt by amount deposited
        totalDebt += _amount;
        require(totalDebt <= terms.maxDebt, "Max capacity reached");
        require(payout >= 10 ** payoutToken.decimals() / 10000, "Bill too small"); // must be > 0.0001 payout token ( underflow protection )
        require(payout <= maxPayout(), "Bill too large"); // size protection because there is no slippage
        totalPayoutGiven += payout; // total payout increased
        require(totalPayoutGiven <= terms.maxTotalPayout, "Max total payout exceeded");
        totalPrincipalBilled += depositAmount; // total billed increased
        // Transfer principal token to BillContract
        principalToken.safeTransferFrom(msg.sender, address(this), _amount);
        principalToken.approve(address(customTreasury), depositAmount);
        uint256 payoutBalanceBefore = payoutToken.balanceOf(address(this));
        if (feeInPayout) {
            // Deposits principal and receives payout tokens
            customTreasury.deposit_FeeInPayout(address(principalToken), depositAmount, payout, fee, feeTo);
        } else {
            // Deposits principal and receives payout tokens
            customTreasury.deposit(address(principalToken), depositAmount, payout);
            if (fee != 0) {
                // if fee, send to treasury
                principalToken.safeTransfer(feeTo, fee);
            }
        }
        uint256 payoutBalanceAdded = payoutToken.balanceOf(address(this)) - payoutBalanceBefore;
        // Create BillNFT
        uint256 billId = billNft.mint(_depositor, address(this));

        billInfo[billId] = Bill({
            payout: payoutBalanceAdded,
            payoutClaimed: 0,
            vesting: terms.vestingTerm,
            vestingTerm: terms.vestingTerm,
            vestingStartTimestamp: block.timestamp,
            lastClaimTimestamp: block.timestamp,
            truePricePaid: truePrice
        });
        billIssuedIds.add(billId);
        emit BillCreated(_amount, payoutBalanceAdded, block.timestamp + terms.vestingTerm, billId);
        emit BillPriceChanged(billPrice(), debtRatio());
        return payout;
    }

    /**
     *  @notice Claim bill for user
     *  @dev Can only be redeemed by: Owner, BondNft or Approved Redeemer
     *  @param _billId uint256
     *  @return uint
     *
     * Requirements:
     *
     * - billId MUST be valid
     * - bill for billId MUST have a claimablePayout
     * - MUST be called by Owner, Approved Claimer of BondNft
     */
    function claim(uint256 _billId) external nonReentrant whenNotPaused returns (uint256) {
        return _claim(_billId);
    }

    /**
     *  @notice Claim multiple bills for user
     *  @param _billIds Array of billIds to claim
     *  @return payout Total payout claimed
     */
    function batchClaim(uint256[] calldata _billIds) public nonReentrant whenNotPaused returns (uint256 payout) {
        uint256 length = _billIds.length;
        for (uint i = 0; i < length; i++) {
            payout += _claim(_billIds[i]);
        }
    }

    /**
     * @notice Claim bill for user
     *
     * See {ApeBond-claim}.
     */
    function _claim(uint256 _billId) internal returns (uint256) {
        Bill storage bill = billInfo[_billId];
        require(bill.lastClaimTimestamp > 0, "not a valid bill id");
        // verify claim approval
        address _owner = billNft.ownerOf(_billId);
        require(
            msg.sender == _owner || msg.sender == address(billNft) || redeemerApproved[_owner][msg.sender],
            "not approved"
        );
        // verify payout
        uint256 payout = claimablePayout(_billId);
        require(payout > 0, "nothing to claim");
        // adjust payout values
        bill.payoutClaimed += payout;
        // adjust vesting timestamps
        uint256 timeElapsed = block.timestamp - bill.lastClaimTimestamp;
        bill.vesting = timeElapsed >= bill.vesting ? 0 : bill.vesting - timeElapsed;
        bill.lastClaimTimestamp = block.timestamp;
        // transfer, emit and return payout
        payoutToken.safeTransfer(_owner, payout);
        emit BillClaimed(_billId, _owner, payout, bill.payout);
        return payout;
    }

    /**
     *  @notice Allows or disallows a third party address to claim bills on behalf of user
     *  @dev Claims are ALWAYS sent to the owner, regardless of which account redeems
     *  @param approvedAccount Address of account which can claim on behalf of msg.sender
     *  @param approved Set approval state to true or false
     */
    function setClaimApproval(address approvedAccount, bool approved) external {
        redeemerApproved[msg.sender][approvedAccount] = approved;
        emit UpdateClaimApproval(msg.sender, approvedAccount, approved);
    }

    /**
     * @dev See {ApeBond-claim}.
     * @notice Leaving for backward compatibility for V1
     */
    function redeem(uint256 _billId) external nonReentrant whenNotPaused returns (uint256) {
        return _claim(_billId);
    }

    /**
     * @dev See {ApeBond-batchClaim}.
     * @notice Leaving for backward compatibility for V1
     */
    function batchRedeem(uint256[] calldata _billIds) external returns (uint256 payout) {
        return batchClaim(_billIds);
    }

    /* ======== INTERNAL HELPER FUNCTIONS ======== */

    /**
     *  @notice reduce total debt
     */
    function _decayDebt() internal {
        totalDebt -= debtDecay();
        lastDecay = block.timestamp;
    }

    /**
     *  @notice Set fees based on totalPrincipalBilled
     *  @param fees Fee settings which corelate to the tierCeilings
     *  @param tierCeilings totalPrincipalBilled amount used to determine when to move to the next fee
     *
     *  Requirements
     *
     *  - tierCeilings MUST be in ascending order
     */
    function _setFeeTiers(uint256[] memory fees, uint256[] memory tierCeilings) internal {
        require(tierCeilings.length == fees.length, "tier length != fee length");
        // Remove old fees
        uint feeTiersLength = feeTiers.length;
        if (feeTiersLength > 0) {
            for (uint256 j; j < feeTiersLength; j++) {
                feeTiers.pop();
            }
        }
        // Validate and setup new FeeTiers
        uint256 previousCeiling;
        for (uint256 i; i < tierCeilings.length; i++) {
            require(fees[i] < MAX_FEE, "Invalid fee");
            require(i == 0 || previousCeiling < tierCeilings[i], "only increasing order");
            previousCeiling = tierCeilings[i];
            if (getFeeTierLength() > i) {
                /// @dev feeTiers.pop() appears to leave the first element
                feeTiers[i] = FeeTiers({tierCeilings: tierCeilings[i], fees: fees[i]});
            } else {
                feeTiers.push(FeeTiers({tierCeilings: tierCeilings[i], fees: fees[i]}));
            }
        }
        require(fees.length == getFeeTierLength(), "feeTier mismatch");
        emit SetFees(fees, tierCeilings);
    }

    /* ======== VIEW FUNCTIONS ======== */

    /**
     *  @notice get bill info for given billId
     *  @param billId Id of the bill NFT
     *  @return Bill bill details
     */
    function getBillInfo(uint256 billId) external view returns (Bill memory) {
        return billInfo[billId];
    }

    /**
     *  @notice calculate current bill premium
     *  @return price_ uint Price is denominated using 18 decimals
     */
    function billPrice() public view returns (uint256 price_) {
        /// @dev 1e2 * 1e(principalTokenDecimals + 18) * 1e16 / 1e(principalTokenDecimals) / 1e18 = 1e18
        price_ = (terms.controlVariable * debtRatio() * 1e16) / 10 ** principalToken.decimals() / 1e18;
        if (price_ < terms.minimumPrice) {
            price_ = terms.minimumPrice;
        }
    }

    /**
     *  @notice calculate true bill price a user pays including the fee
     *  @return price_ uint
     */
    function trueBillPrice() public view returns (uint256 price_) {
        price_ = (billPrice() * MAX_FEE) / (MAX_FEE - currentFee());
    }

    /**
     *  @notice determine maximum bill size
     *  @return uint
     */
    function maxPayout() public view returns (uint256) {
        return terms.maxPayout;
    }

    /**
     *  @notice calculate user's expected payout for given principal amount.
     *  @dev If feeInPayout flag is set, the _fee will be returned in payout tokens
     *  If feeInPayout flag is NOT set, the _fee will be returned in principal tokens
     *  @param _amount uint Amount of principal tokens to deposit
     *  @return _payout uint Amount of payoutTokens given principal tokens
     *  @return _fee uint Fee is payout or principal tokens depending on feeInPayout flag
     */
    function payoutFor(uint256 _amount) public view returns (uint256 _payout, uint256 _fee) {
        if (feeInPayout) {
            // Using amount of principalTokens, find the amount of payout tokens by dividing by billPrice.
            uint256 total = customTreasury.valueOfToken(address(principalToken), _amount * 1e18) / billPrice();
            // _fee is denominated in payoutToken decimals
            _fee = (total * currentFee()) / MAX_FEE;
            _payout = total - _fee;
        } else {
            // feeInPrincipal
            // _fee is denominated in principalToken decimals
            _fee = (_amount * currentFee()) / MAX_FEE;
            // Using amount of principalTokens - _fee, find the amount of payout tokens by dividing by billPrice.
            _payout = customTreasury.valueOfToken(address(principalToken), (_amount - _fee) * 1e18) / billPrice();
        }
    }

    /**
     *  @notice calculate current ratio of debt to payout token supply
     *  @notice protocols using this system should be careful when quickly adding large %s to total supply
     *  @dev scaled by 1e18 to support 6 decimal principal token and debt. This avoids issues with rounding
     *  @return debtRatio_ uint debtRatio denominated in principalToken decimals
     */
    function debtRatio() public view returns (uint256 debtRatio_) {
        debtRatio_ = (currentDebt() * 10 ** payoutToken.decimals() * 1e18) / payoutTokenInitialSupply;
    }

    /**
     *  @notice calculate debt factoring in decay
     *  @return uint currentDebt denominated in principalToken decimals
     */
    function currentDebt() public view returns (uint256) {
        return totalDebt - debtDecay();
    }

    /**
     *  @notice amount to decay total debt by
     *  @return decay_ uint debtDecay denominated in principalToken decimals
     */
    function debtDecay() public view returns (uint256 decay_) {
        if (terms.vestingTerm == 0) return totalDebt;
        uint256 timestampSinceLast = block.timestamp - lastDecay;
        decay_ = (totalDebt * timestampSinceLast) / terms.vestingTerm;
        if (decay_ > totalDebt) {
            decay_ = totalDebt;
        }
    }

    /**
     *  @notice Returns the number of seconds left until fully vested.
     *  @dev backward compatibility for V1
     *  @param _billId ID of Bill
     *  @return pendingVesting_ Number of seconds until vestingEnd timestamp
     */
    function pendingVesting(uint256 _billId) external view returns (uint256 pendingVesting_) {
        (, uint256 vestingEnd, ) = _billTimestamps(_billId);
        pendingVesting_ = 0;
        if (vestingEnd > block.timestamp) {
            pendingVesting_ = vestingEnd - block.timestamp;
        }
    }

    /**
     *  @notice Returns the total payout left for the billId passed. (i.e. claimablePayout + vestingPayout)
     *  @dev backward compatibility for V1
     *  @param _billId ID of Bill
     *  @return pendingPayout_ uint Payout value still remaining in bill
     */
    function pendingPayout(uint256 _billId) external view returns (uint256 pendingPayout_) {
        (, uint256 vestingPayoutCurrent, uint256 claimablePayoutCurrent) = _payoutsCurrent(_billId);
        pendingPayout_ = vestingPayoutCurrent + claimablePayoutCurrent;
    }

    /**
     *  @notice Return the vesting start and end times for a Bill by ID
     *  @dev Helper function for ERC5725
     *  @param _billId ID of Bill
     */
    function vestingPeriod(uint256 _billId) public view returns (uint256 vestingStart_, uint256 vestingEnd_) {
        (vestingStart_, vestingEnd_, ) = _billTimestamps(_billId);
    }

    /**
     *  @notice Return the amount of tokens locked in a Bill at the current block.timestamp
     *  @dev Helper function for ERC5725
     *  @param _billId ID of Bill
     */
    function vestingPayout(uint256 _billId) external view returns (uint256 vestingPayout_) {
        (, vestingPayout_, ) = _payoutsCurrent(_billId);
    }

    /**
     *  @notice Return the amount of tokens unlocked at a specific timestamp. Includes claimed tokens.
     *  @dev Helper function for ERC5725.
     *  @param _billId ID of Bill
     *  @param _timestamp timestamp to check
     */
    function vestedPayoutAtTime(uint256 _billId, uint256 _timestamp) external view returns (uint256 vestedPayout_) {
        (vestedPayout_, , ) = _payoutsAtTime(_billId, _timestamp);
    }

    /**
     *  @notice Return the amount of payout tokens which are available to be claimed for a Bill.
     *  @dev Helper function for ERC5725.
     *  @param _billId ID of Bill
     */
    function claimablePayout(uint256 _billId) public view returns (uint256 claimablePayout_) {
        (, , claimablePayout_) = _payoutsCurrent(_billId);
    }

    /**
     * @notice Calculate payoutsAtTime with current timestamp
     * @dev See {ApeBond-_payoutsAtTime}.
     */
    function _payoutsCurrent(
        uint256 _billId
    ) internal view returns (uint256 vestedPayout_, uint256 vestingPayout_, uint256 claimablePayout_) {
        return _payoutsAtTime(_billId, block.timestamp);
    }

    /**
     *  @notice Return the amount of tokens unlocked at a specific timestamp. Includes claimed tokens.
     *  @dev Helper function for ERC5725.
     *  @param _billId ID of Bill
     *  @param _timestamp timestamp to check
     */
    function _payoutsAtTime(
        uint256 _billId,
        uint256 _timestamp
    ) internal view returns (uint256 vestedPayout_, uint256 vestingPayout_, uint256 claimablePayout_) {
        Bill memory bill = billInfo[_billId];
        // Calculate vestedPayout
        uint256 fullPayout = bill.payout;
        vestedPayout_ = vestingCurve.getVestedPayoutAtTime(
            fullPayout,
            bill.vestingTerm,
            bill.vestingStartTimestamp,
            _timestamp
        );
        // Calculate vestingPayout
        vestingPayout_ = fullPayout - vestedPayout_;
        // Calculate claimablePayout
        uint256 payoutClaimed = bill.payoutClaimed;
        claimablePayout_ = 0;
        if (payoutClaimed < vestedPayout_) {
            claimablePayout_ = vestedPayout_ - payoutClaimed;
        }
    }

    function _billTimestamps(
        uint256 _billId
    ) internal view returns (uint256 vestingStart_, uint256 vestingEnd_, uint256 lastClaimTimestamp_) {
        Bill memory bill = billInfo[_billId];
        vestingStart_ = bill.vestingStartTimestamp;
        vestingEnd_ = vestingStart_ + bill.vestingTerm;
        lastClaimTimestamp_ = bill.lastClaimTimestamp;
    }

    /**
     *  @notice calculate all billNft ids for sender
     *  @return billNftIds uint[]
     */
    function userBillIds() external view returns (uint[] memory) {
        return getBillIds(msg.sender);
    }

    /**
     *  @notice calculate all billNft ids for user
     *  @return billNftIds uint[]
     */
    function getBillIds(address user) public view returns (uint[] memory) {
        uint balance = billNft.balanceOf(user);
        return getBillIdsInRange(user, 0, balance);
    }

    /**
     *  @notice calculate billNft ids in range for user
     *  @return billNftIds uint[]
     */
    function getBillIdsInRange(address user, uint256 start, uint256 end) public view returns (uint256[] memory) {
        uint256[] memory result = new uint[](end - start);
        uint256 resultIndex = 0;
        for (uint256 i = start; i < end; i++) {
            uint256 tokenId = billNft.tokenOfOwnerByIndex(user, i);
            if (billIssuedIds.contains(tokenId)) {
                result[resultIndex] = tokenId;
                resultIndex++;
            }
        }
        // Prune results into condensed array
        uint256[] memory prunedResult = new uint256[](resultIndex);
        for (uint256 j = 0; j < resultIndex; j++) {
            prunedResult[j] = result[j];
        }
        return prunedResult;
    }

    /**
     *  @notice current fee taken of each bill
     *  @return currentFee_ uint
     */
    function currentFee() public view returns (uint256 currentFee_) {
        uint256 tierLength = feeTiers.length;
        for (uint256 i; i < tierLength; i++) {
            if (totalPrincipalBilled <= feeTiers[i].tierCeilings || i == tierLength - 1) {
                return feeTiers[i].fees;
            }
        }
    }

    /**
     *  @notice Get the number of fee tiers configured
     *  @return tierLength_ uint
     */
    function getFeeTierLength() public view returns (uint256 tierLength_) {
        tierLength_ = feeTiers.length;
    }

    /**
     * From EnumerableSetUpgradeable...
     *
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function allIssuedBillIds() external view returns (uint256[] memory) {
        return billIssuedIds.values();
    }
}// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

/*
  ______                       _______                             __ 
 /      \                     |       \                           |  \
|  ▓▓▓▓▓▓\  ______    ______  | ▓▓▓▓▓▓▓\  ______   _______    ____| ▓▓
| ▓▓__| ▓▓ /      \  /      \ | ▓▓__/ ▓▓ /      \ |       \  /      ▓▓
| ▓▓    ▓▓|  ▓▓▓▓▓▓\|  ▓▓▓▓▓▓\| ▓▓    ▓▓|  ▓▓▓▓▓▓\| ▓▓▓▓▓▓▓\|  ▓▓▓▓▓▓▓
| ▓▓▓▓▓▓▓▓| ▓▓  | ▓▓| ▓▓    ▓▓| ▓▓▓▓▓▓▓\| ▓▓  | ▓▓| ▓▓  | ▓▓| ▓▓  | ▓▓
| ▓▓  | ▓▓| ▓▓__/ ▓▓| ▓▓▓▓▓▓▓▓| ▓▓__/ ▓▓| ▓▓__/ ▓▓| ▓▓  | ▓▓| ▓▓__| ▓▓
| ▓▓  | ▓▓| ▓▓    ▓▓ \▓▓     \| ▓▓    ▓▓ \▓▓    ▓▓| ▓▓  | ▓▓ \▓▓    ▓▓
 \▓▓   \▓▓| ▓▓▓▓▓▓▓   \▓▓▓▓▓▓▓ \▓▓▓▓▓▓▓   \▓▓▓▓▓▓  \▓▓   \▓▓  \▓▓▓▓▓▓▓
          | ▓▓                                                        
          | ▓▓                                                        
           \▓▓                                                         
 * App:             https://Ape.Bond
 * Medium:          https://ApeBond.medium.com
 * Twitter:         https://twitter.com/ApeBond
 * Telegram:        https://t.me/ape_bond
 * Announcements:   https://t.me/ApeBond_news
 * Discord:         https://ApeBond.click/discord
 * Reddit:          https://ApeBond.click/reddit
 * Instagram:       https://instagram.com/ape.bond
 * GitHub:          https://github.com/ApeSwapFinance
 */

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title ApeBondAccessControlUpgradeable
 * @notice This contract manages the ownership and role based access for ApeBond contracts
 */
contract ApeBondAccessControlUpgradeable is OwnableUpgradeable, AccessControlEnumerableUpgradeable {
    /* ======== STATE ======== */

    /// @notice Operations role, used to adjust specific settings on the bond
    bytes32 public constant OPERATIONS_ROLE = keccak256("OPERATIONS_ROLE");

    /// @notice Discount manager role, used to manage discounts
    bytes32 public constant DISCOUNT_MANAGER_ROLE = keccak256("DISCOUNT_MANAGER_ROLE");

    /* ======== INITIALIZATION ======== */

    function __ApeBondAccessControlUpgradeable__init(
        address _initialOwner,
        address _discountManager,
        address[] calldata _bondOperations
    ) internal onlyInitializing {
        __Ownable_init();
        _transferOwnership(_initialOwner);
        _grantRole(DISCOUNT_MANAGER_ROLE, _discountManager);
        _grantOperationsRole(_bondOperations);
    }

    /* ======== MODIFIERS ======== */

    modifier onlyOwnerOrRole(bytes32 role1) {
        require(msg.sender == owner() || hasRole(role1, msg.sender), "Caller is not owner or has required role");
        _;
    }

    modifier onlyOwnerOrRoles(bytes32 role1, bytes32 role2) {
        require(
            msg.sender == owner() || hasRole(role1, msg.sender) || hasRole(role2, msg.sender),
            "Caller is not owner or has required role"
        );
        _;
    }

    /* ======== onlyOwner FUNCTIONS ======== */

    /**
     * @notice Grant the ability to operate the bond
     * @param _bondOperations Array of addresses to whitelist as bond operations
     */
    function grantOperationsRole(address[] calldata _bondOperations) external onlyOwner {
        _grantOperationsRole(_bondOperations);
    }

    function _grantOperationsRole(address[] calldata _bondOperations) private {
        for (uint i = 0; i < _bondOperations.length; i++) {
            _grantRole(OPERATIONS_ROLE, _bondOperations[i]);
        }
    }

    /**
     * @notice Revoke the ability to operate bond
     * @param _bondOperations Array of addresses to revoke as bond operations
     */
    function revokeOperationsRole(address[] calldata _bondOperations) external onlyOwner {
        for (uint i = 0; i < _bondOperations.length; i++) {
            _revokeRole(OPERATIONS_ROLE, _bondOperations[i]);
        }
    }

    /**
     * @notice Grant the ability to manage discounts
     * @param _discountManager Address to grant discount manager role to
     */
    function grantDiscountManagerRole(address _discountManager) external onlyOwner {
        _grantRole(DISCOUNT_MANAGER_ROLE, _discountManager);
    }

    /**
     * @notice Revoke the ability to manage discounts
     * @param _discountManager Address to revoke discount manager role from
     */
    function revokeDiscountManagerRole(address _discountManager) external onlyOwner {
        _revokeRole(DISCOUNT_MANAGER_ROLE, _discountManager);
    }

    /**
     * @notice Grant a role
     * @param role The role to grant
     * @param account The address to grant the role to
     */
    function grantRole(
        bytes32 role,
        address account
    ) public override(AccessControlUpgradeable, IAccessControlUpgradeable) onlyOwner {
        _grantRole(role, account);
    }
}// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {IApeBondBase, IVestingCurve, IBondTreasury, IERC20MetadataUpgradeable} from "./IApeBondBase.sol";

interface IApeBond is IApeBondBase {
    /// @notice Info for bill holder
    /// @param payout Total payout value
    /// @param payoutClaimed Amount of payout claimed
    /// @param vesting Seconds left until vesting is complete
    /// @param vestingTerm Length of vesting in seconds
    /// @param vestingStartTimestamp Timestamp at start of vesting
    /// @param lastClaimTimestamp Last timestamp interaction
    /// @param truePricePaid Price paid (principal tokens per payout token) in ten-millionths - 4000000 = 0.4
    struct Bill {
        uint256 payout;
        uint256 payoutClaimed;
        uint256 vesting;
        uint256 vestingTerm;
        uint256 vestingStartTimestamp;
        uint256 lastClaimTimestamp;
        uint256 truePricePaid;
    }

    struct BondTerms {
        uint256 controlVariable;
        uint256 vestingTerm;
        uint256 minimumPrice;
        uint256 maxPayout;
        uint256 maxDebt;
        uint256 maxTotalPayout;
        uint256 initialDebt;
    }

    function initialize(
        IBondTreasury _customTreasury,
        BondCreationDetails memory _billCreationDetails,
        BondTerms memory _billTerms,
        BondAccounts memory _billAccounts,
        address[] memory _billOperators
    ) external;

    function getBillInfo(uint256 billId) external view returns (Bill memory);
}// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IBondTreasury} from "../IBondTreasury.sol";
import {IVestingCurve} from "../curves/IVestingCurve.sol";

interface IApeBondBase {
    /// @notice Details required to create a new bill
    /// @param payoutToken The token in which the payout will be made
    /// @param principalToken The token used to purchase the bill
    /// @param initialOwner The initial owner of the bill
    /// @param vestingCurve The vesting curve contract used for the bill
    /// @param tierCeilings The ceilings of each tier for the bill
    /// @param fees The fees associated with each tier
    /// @param feeInPayout Boolean indicating if the fee is taken from the payout
    struct BondCreationDetails {
        address payoutToken;
        address principalToken;
        address initialOwner;
        IVestingCurve vestingCurve;
        uint256[] tierCeilings;
        uint256[] fees;
        bool feeInPayout;
    }

    /// @notice Important accounts related to a ApeBond
    /// @param feeTo Account which receives the bill fees
    /// @param discountManager Account used to change the discount
    /// @param billNft BillNFT contract which mints the NFTs
    struct BondAccounts {
        address feeTo;
        address discountManager;
        address billNft;
    }

    function customTreasury() external returns (IBondTreasury);

    function claim(uint256 billId) external returns (uint256);

    function pendingVesting(uint256 billId) external view returns (uint256);

    function pendingPayout(uint256 billId) external view returns (uint256);

    function vestingPeriod(uint256 billId) external view returns (uint256 vestingStart_, uint256 vestingEnd_);

    function vestingPayout(uint256 billId) external view returns (uint256 vestingPayout_);

    function vestedPayoutAtTime(uint256 billId, uint256 timestamp) external view returns (uint256 vestedPayout_);

    function claimablePayout(uint256 billId) external view returns (uint256 claimablePayout_);

    function payoutToken() external view returns (IERC20MetadataUpgradeable);

    function principalToken() external view returns (IERC20MetadataUpgradeable);
}// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {IERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import {IERC5725Upgradeable} from "./interfaces/IERC5725.sol";

interface IBondNft is IERC5725Upgradeable, IERC721EnumerableUpgradeable {
    struct TokenData {
        uint256 tokenId;
        address billAddress;
    }

    function addMinter(address minter) external;

    function mint(address to, address billAddress) external returns (uint256);

    function mintMany(uint256 amount, address to, address billAddress) external;

    function lockURI() external;

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external;

    function claimMany(uint256[] calldata _tokenIds) external;

    function pendingPayout(uint256 tokenId) external view returns (uint256 pendingPayoutAmount);

    function pendingVesting(uint256 tokenId) external view returns (uint256 pendingSeconds);

    function allTokensDataOfOwner(address owner) external view returns (TokenData[] memory);

    function getTokensOfOwnerByIndexes(
        address owner,
        uint256 start,
        uint256 end
    ) external view returns (TokenData[] memory);

    function tokenDataOfOwnerByIndex(address owner, uint256 index) external view returns (TokenData memory tokenData);
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
/**
 * @title Non-Fungible Vesting Token Standard.
 * @notice A non-fungible token standard used to vest ERC-20 tokens over a vesting release curve
 *  scheduled using timestamps.
 * @dev Because this standard relies on timestamps for the vesting schedule, it's important to keep track of the
 *  tokens claimed per Vesting NFT so that a user cannot withdraw more tokens than allotted for a specific Vesting NFT.
 * @custom:interface-id 0xbd3a202b
 */
interface IERC5725Upgradeable is IERC721Upgradeable {
    /**
     *  This event is emitted when the payout is claimed through the claim function.
     *  @param tokenId the NFT tokenId of the assets being claimed.
     *  @param recipient The address which is receiving the payout.
     *  @param claimAmount The amount of tokens being claimed.
     */
    event PayoutClaimed(uint256 indexed tokenId, address indexed recipient, uint256 claimAmount);

    /**
     *  This event is emitted when an `owner` sets an address to manage token claims for all tokens.
     *  @param owner The address setting a manager to manage all tokens.
     *  @param spender The address being permitted to manage all tokens.
     *  @param approved A boolean indicating whether the spender is approved to claim for all tokens.
     */
    event ClaimApprovalForAll(address indexed owner, address indexed spender, bool approved);

    /**
     *  This event is emitted when an `owner` sets an address to manage token claims for a `tokenId`.
     *  @param owner The `owner` of `tokenId`.
     *  @param spender The address being permitted to manage a tokenId.
     *  @param tokenId The unique identifier of the token being managed.
     *  @param approved A boolean indicating whether the spender is approved to claim for `tokenId`.
     */
    event ClaimApproval(address indexed owner, address indexed spender, uint256 indexed tokenId, bool approved);

    /**
     * @notice Claim the pending payout for the NFT.
     * @dev MUST grant the claimablePayout value at the time of claim being called to `msg.sender`.
     *  MUST revert if not called by the token owner or approved users.
     *  MUST emit PayoutClaimed.
     *  SHOULD revert if there is nothing to claim.
     * @param tokenId The NFT token id.
     */
    function claim(uint256 tokenId) external;

    /**
     * @notice Number of tokens for the NFT which have been claimed at the current timestamp.
     * @param tokenId The NFT token id.
     * @return payout The total amount of payout tokens claimed for this NFT.
     */
    function claimedPayout(uint256 tokenId) external view returns (uint256 payout);

    /**
     * @notice Number of tokens for the NFT which can be claimed at the current timestamp.
     * @dev It is RECOMMENDED that this is calculated as the `vestedPayout()` subtracted from `payoutClaimed()`.
     * @param tokenId The NFT token id.
     * @return payout The amount of unlocked payout tokens for the NFT which have not yet been claimed.
     */
    function claimablePayout(uint256 tokenId) external view returns (uint256 payout);

    /**
     * @notice Total amount of tokens which have been vested at the current timestamp.
     *  This number also includes vested tokens which have been claimed.
     * @dev It is RECOMMENDED that this function calls `vestedPayoutAtTime`
     *  with `block.timestamp` as the `timestamp` parameter.
     * @param tokenId The NFT token id.
     * @return payout Total amount of tokens which have been vested at the current timestamp.
     */
    function vestedPayout(uint256 tokenId) external view returns (uint256 payout);

    /**
     * @notice Total amount of vested tokens at the provided timestamp.
     *  This number also includes vested tokens which have been claimed.
     * @dev `timestamp` MAY be both in the future and in the past.
     *  Zero MUST be returned if the timestamp is before the token was minted.
     * @param tokenId The NFT token id.
     * @param timestamp The timestamp to check on, can be both in the past and the future.
     * @return payout Total amount of tokens which have been vested at the provided timestamp.
     */
    function vestedPayoutAtTime(uint256 tokenId, uint256 timestamp) external view returns (uint256 payout);

    /**
     * @notice Number of tokens for an NFT which are currently vesting.
     * @dev The sum of vestedPayout and vestingPayout SHOULD always be the total payout.
     * @param tokenId The NFT token id.
     * @return payout The number of tokens for the NFT which are vesting until a future date.
     */
    function vestingPayout(uint256 tokenId) external view returns (uint256 payout);

    /**
     * @notice The start and end timestamps for the vesting of the provided NFT.
     *  MUST return the timestamp where no further increase in vestedPayout occurs for `vestingEnd`.
     * @param tokenId The NFT token id.
     * @return vestingStart The beginning of the vesting as a unix timestamp.
     * @return vestingEnd The ending of the vesting as a unix timestamp.
     */
    function vestingPeriod(uint256 tokenId) external view returns (uint256 vestingStart, uint256 vestingEnd);

    /**
     * @notice Token which is used to pay out the vesting claims.
     * @param tokenId The NFT token id.
     * @return token The token which is used to pay out the vesting claims.
     */
    function payoutToken(uint256 tokenId) external view returns (address token);

    /**
     * @notice Sets a global `operator` with permission to manage all tokens owned by the current `msg.sender`.
     * @param operator The address to let manage all tokens.
     * @param approved A boolean indicating whether the spender is approved to claim for all tokens.
     */
    function setClaimApprovalForAll(address operator, bool approved) external;

    /**
     * @notice Sets a tokenId `operator` with permission to manage a single `tokenId` owned by the `msg.sender`.
     * @param operator The address to let manage a single `tokenId`.
     * @param tokenId the `tokenId` to be managed.
     * @param approved A boolean indicating whether the spender is approved to claim for all tokens.
     */
    function setClaimApproval(address operator, bool approved, uint256 tokenId) external;

    /**
     * @notice Returns true if `owner` has set `operator` to manage all `tokenId`s.
     * @param owner The owner allowing `operator` to manage all `tokenId`s.
     * @param operator The address who is given permission to spend tokens on behalf of the `owner`.
     */
    function isClaimApprovedForAll(address owner, address operator) external view returns (bool isClaimApproved);

    /**
     * @notice Returns the operating address for a `tokenId`.
     *  If `tokenId` is not managed, then returns the zero address.
     * @param tokenId The NFT `tokenId` to query for a `tokenId` manager.
     */
    function getClaimApproved(uint256 tokenId) external view returns (address operator);
}