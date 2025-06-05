// File: @openzeppelin/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

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
abstract contract Ownable is Context {
    address private _owner;

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
    constructor(address initialOwner) {
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
        return _owner;
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
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol
// SPDX-License-Identifier: MIT
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
}


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT
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
}


// File: @openzeppelin/contracts/utils/Context.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

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

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// File: @openzeppelin/contracts/utils/ReentrancyGuard.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

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
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
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
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}


// File: @openzeppelin/contracts/utils/structs/EnumerableSet.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

pragma solidity ^0.8.20;

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
        // Position is the index of the value in the `values` array plus 1.
        // Position 0 is used to mean a value is not in the set.
        mapping(bytes32 value => uint256) _positions;
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
            set._positions[value] = set._values.length;
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
        // We cache the value's position to prevent multiple reads from the same storage slot
        uint256 position = set._positions[value];

        if (position != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;

            if (valueIndex != lastIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the lastValue to the index where the value to delete is
                set._values[valueIndex] = lastValue;
                // Update the tracked position of the lastValue (that was just moved)
                set._positions[lastValue] = position;
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the tracked position for the deleted slot
            delete set._positions[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._positions[value] != 0;
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


// File: contracts/interface/ITokenLocker.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ITokenLocker{

    struct VestingLockParams {
        address token;
        uint24 tgeBps;
        uint24 cycleBps;
        address owner;
        uint256 amount;
        uint256 tgeTime;
        uint256 cycle;
    }

    struct LockInfo {
        uint256 lockId;
        address token;
        bool isLpToken;
        address pendingOwner;
        address owner;
        uint24 tgeBps; // In bips. Is 0 for normal locks
        uint24 cycleBps; // In bips. Is 0 for normal locks
        uint256 amount;
        uint256 startTime;
        uint256 endTime; // unlock time for normal locks, and TGE time for vesting locks
        uint256 cycle; // 0: normal locks
        uint256 unlockedAmount;
        bytes32 feeNameHash;
    }

    struct CumulativeLockInfo {
        address factory;
        uint256 amount;
    }

    struct FeeStruct {
        string name;
        uint256 lockFee;
        address lockFeeToken;
        uint24 lpFee;
    }

    event OnLock(
        uint256 indexed lockId,
        address token,
        address owner,
        uint256 amount,
        uint256 endTime
    );
    event OnUpdated(
        uint256 indexed lockId,
        address token,
        address owner,
        uint256 newAmount,
        uint256 newEndTime
    );
    event OnUnlock(
        uint256 indexed lockId,
        address token,
        address owner,
        uint256 amount,
        uint256 unlockedTime
    );
    event OnLockVested(
        uint256 indexed lockId,
        address token,
        address owner,
        uint256 unlockAmount,
        uint256 left,
        uint256 vestTime
    );
    event OnLockPendingTransfer(
        uint256 indexed lockId,
        address previousOwner,
        address newOwner
    );
    event OnLockTransferred(
        uint256 indexed lockId,
        address previousOwner,
        address newOwner
    );
    event FeeReceiverUpdated(address feeReceiver);
    event OnAddFee(bytes32 nameHash, string name, uint256 lockFee, address lockFeeToken, uint24 lpFee, bool isLp);
    event OnEditFee(bytes32 nameHash, string name, uint256 lockFee, address lockFeeToken, uint24 lpFee, bool isLp);

    function lock(
        address token_,
        string memory feeName_,
        address owner_,
        uint256 amount_,
        uint256 endTime_
    ) external payable returns (uint256 lockId);

    function lockWithPermit(
        address token_,
        string memory feeName_,
        address owner_,
        uint256 amount_,
        uint256 endTime_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable returns (uint256 lockId);

    function vestingLock(
        VestingLockParams memory params,
        string memory feeName_
    ) external payable returns (uint256 lockId);

    function vestingLockWithPermit(
        VestingLockParams memory params,
        string memory feeName_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable returns (uint256 lockId);

    function updateLock(
        uint256 lockId_,
        uint256 moreAmount_,
        uint256 newEndTime_
    ) external payable;

    function updateLockWitPermit(
        uint256 lockId_,
        uint256 moreAmount_,
        uint256 newEndTime_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    function transferLock(
        uint256 lockId_,
        address newOwner_
    ) external;

    function acceptLock(uint256 lockId_) external;

    function unlock(
        uint256 lockId_
    ) external;

    function withdrawableTokens(
        uint256 lockId_
    ) external view returns (uint256);
}

// File: contracts/interface/IUniswapV2Factory.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IUniswapV2Factory {
  event PairCreated(
    address indexed token0,
    address indexed token1,
    address pair,
    uint256
  );

  function feeTo() external view returns (address);

  function feeToSetter() external view returns (address);

  function getPair(address tokenA, address tokenB)
    external
    view
    returns (address pair);

  function allPairs(uint256) external view returns (address pair);

  function allPairsLength() external view returns (uint256);

  function createPair(address tokenA, address tokenB)
    external
    returns (address pair);

  function setFeeTo(address) external;

  function setFeeToSetter(address) external;
}


// File: contracts/interface/IUniswapV2Pair.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IUniswapV2Pair {
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);

  function name() external pure returns (string memory);

  function symbol() external pure returns (string memory);

  function decimals() external pure returns (uint8);

  function totalSupply() external view returns (uint256);

  function balanceOf(address owner) external view returns (uint256);

  function allowance(address owner, address spender)
    external
    view
    returns (uint256);

  function approve(address spender, uint256 value) external returns (bool);

  function transfer(address to, uint256 value) external returns (bool);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool);

  function DOMAIN_SEPARATOR() external view returns (bytes32);

  function PERMIT_TYPEHASH() external pure returns (bytes32);

  function nonces(address owner) external view returns (uint256);

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  event Mint(address indexed sender, uint256 amount0, uint256 amount1);
  event Burn(
    address indexed sender,
    uint256 amount0,
    uint256 amount1,
    address indexed to
  );
  event Swap(
    address indexed sender,
    uint256 amount0In,
    uint256 amount1In,
    uint256 amount0Out,
    uint256 amount1Out,
    address indexed to
  );
  event Sync(uint112 reserve0, uint112 reserve1);

  function MINIMUM_LIQUIDITY() external pure returns (uint256);

  function factory() external view returns (address);

  function token0() external view returns (address);

  function token1() external view returns (address);

  function getReserves()
    external
    view
    returns (
      uint112 reserve0,
      uint112 reserve1,
      uint32 blockTimestampLast
    );

  function price0CumulativeLast() external view returns (uint256);

  function price1CumulativeLast() external view returns (uint256);

  function kLast() external view returns (uint256);

  function mint(address to) external returns (uint256 liquidity);

  function burn(address to) external returns (uint256 amount0, uint256 amount1);

  function swap(
    uint256 amount0Out,
    uint256 amount1Out,
    address to,
    bytes calldata data
  ) external;

  function skim(address to) external;

  function sync() external;

  function initialize(address, address) external;
}


// File: contracts/libs/FullMath.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
  /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
  /// @param a The multiplicand
  /// @param b The multiplier
  /// @param denominator The divisor
  /// @return result The 256-bit result
  /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
  function mulDiv(
    uint256 a,
    uint256 b,
    uint256 denominator
  ) internal pure returns (uint256 result) {
    // 512-bit multiply [prod1 prod0] = a * b
    // Compute the product mod 2**256 and mod 2**256 - 1
    // then use the Chinese Remainder Theorem to reconstruct
    // the 512 bit result. The result is stored in two 256
    // variables such that product = prod1 * 2**256 + prod0
    uint256 prod0; // Least significant 256 bits of the product
    uint256 prod1; // Most significant 256 bits of the product
    assembly {
      let mm := mulmod(a, b, not(0))
      prod0 := mul(a, b)
      prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    // Handle non-overflow cases, 256 by 256 division
    if (prod1 == 0) {
      require(denominator > 0);
      assembly {
        result := div(prod0, denominator)
      }
      return result;
    }

    // Make sure the result is less than 2**256.
    // Also prevents denominator == 0
    require(denominator > prod1);

    ///////////////////////////////////////////////
    // 512 by 256 division.
    ///////////////////////////////////////////////

    // Make division exact by subtracting the remainder from [prod1 prod0]
    // Compute remainder using mulmod
    uint256 remainder;
    assembly {
      remainder := mulmod(a, b, denominator)
    }
    // Subtract 256 bit number from 512 bit number
    assembly {
      prod1 := sub(prod1, gt(remainder, prod0))
      prod0 := sub(prod0, remainder)
    }

    // Factor powers of two out of denominator
    // Compute largest power of two divisor of denominator.
    // Always >= 1.
    unchecked {
      uint256 twos = (type(uint256).max - denominator + 1) & denominator;
      // Divide denominator by power of two
      assembly {
        denominator := div(denominator, twos)
      }

      // Divide [prod1 prod0] by the factors of two
      assembly {
        prod0 := div(prod0, twos)
      }
      // Shift in bits from prod1 into prod0. For this we need
      // to flip `twos` such that it is 2**256 / twos.
      // If twos is zero, then it becomes one
      assembly {
        twos := add(div(sub(0, twos), twos), 1)
      }
      prod0 |= prod1 * twos;

      // Invert denominator mod 2**256
      // Now that denominator is an odd number, it has an inverse
      // modulo 2**256 such that denominator * inv = 1 mod 2**256.
      // Compute the inverse by starting with a seed that is correct
      // correct for four bits. That is, denominator * inv = 1 mod 2**4
      uint256 inv = (3 * denominator) ^ 2;
      // Now use Newton-Raphson iteration to improve the precision.
      // Thanks to Hensel's lifting lemma, this also works in modular
      // arithmetic, doubling the correct bits in each step.
      inv *= 2 - denominator * inv; // inverse mod 2**8
      inv *= 2 - denominator * inv; // inverse mod 2**16
      inv *= 2 - denominator * inv; // inverse mod 2**32
      inv *= 2 - denominator * inv; // inverse mod 2**64
      inv *= 2 - denominator * inv; // inverse mod 2**128
      inv *= 2 - denominator * inv; // inverse mod 2**256

      // Because the division is now exact we can divide by multiplying
      // with the modular inverse of denominator. This will give us the
      // correct result modulo 2**256. Since the precoditions guarantee
      // that the outcome is less than 2**256, this is the final result.
      // We don't need to compute the high bits of the result and prod1
      // is no longer required.
      result = prod0 * inv;
      return result;
    }
  }
}


// File: contracts/libs/SafeUniswapCall.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IUniswapV2Factory.sol";
import "../interface/IUniswapV2Pair.sol";
contract SafeUniswapCall {

    function checkIsPair(address pair) public view returns (bool isPair) {
        address factory = safeCallPair(pair, IUniswapV2Pair.factory.selector);
        if(factory == address(0)) return false;
        address token0 = safeCallPair(pair, IUniswapV2Pair.token0.selector);
        if(token0 == address(0)) return false;
        address token1 = safeCallPair(pair, IUniswapV2Pair.token1.selector);
        if(token1 == address(0)) return false;
        address _pair = safeCallFactory(factory, token0, token1);
        isPair = pair == _pair;
    }

    function safeCallFactory(address factory, address token0, address token1) public view returns(address addr) {
        (bool success, bytes memory result) = factory.staticcall(
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector, token0, token1)
        );

        if (success && result.length >= 32) {
            try SafeUniswapCall(this).decodeRet2Address(result) returns(address ret){
                addr = ret;
            }catch {}
        } 
    }

    function safeCallPair(address pair, bytes4 selector) public view returns(address addr) {
        (bool success, bytes memory result) = pair.staticcall(
            abi.encodeWithSelector(selector)
        );

        if (success && result.length >= 32) {
            try SafeUniswapCall(this).decodeRet2Address(result) returns(address ret){
                addr = ret;
            }catch {}
        } 
    }

    function decodeRet2Address(bytes memory input) public pure returns (address){
        return abi.decode(input, (address));
    }
}

// File: contracts/libs/TransferHelper.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

library TransferHelper {
    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with 'STF' if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with ST if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    /// @notice Approves the stipulated contract to spend the given allowance in the given token
    /// @dev Errors with 'SA' if transfer fails
    /// @param token The contract address of the token to be approved
    /// @param to The target of the approval
    /// @param value The amount of the given token the target will be allowed to spend
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `STE`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }
}


// File: contracts/TokenLocker.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interface/IUniswapV2Factory.sol";
import "./interface/IUniswapV2Pair.sol";
import "./interface/ITokenLocker.sol";

import "./libs/TransferHelper.sol";
import "./libs/FullMath.sol";
import "./libs/SafeUniswapCall.sol";

contract TokenLocker is ITokenLocker, SafeUniswapCall, Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // next lockId
    uint256 public nextLockId = 1;

    // lock detail
    mapping(uint256 lockId => LockInfo) public locks;

    // List of normal token lock ids for users
    mapping(address => EnumerableSet.UintSet) private userNormalLocks;
    // List of lp-token lock ids for users
    mapping(address => EnumerableSet.UintSet) private userLpLocks;

    // list of lock ids for token
    mapping(address => EnumerableSet.UintSet) private tokenLocks;

    // Cumulative lock info for token
    mapping(address => CumulativeLockInfo) public cumulativeInfos;

    // 
    uint256 constant DENOMINATOR = 10_000;

    // contains keccak(feeName)
    EnumerableSet.Bytes32Set private feeNameHashSet; 
    EnumerableSet.Bytes32Set private tokenSupportedFeeNames; 
    EnumerableSet.Bytes32Set private lpSupportedFeeNames; 
    // fees
    mapping(bytes32 nameHash => FeeStruct) public fees;
    address public feeReceiver;
    
    modifier validLockOwner(uint256 lockId_) {
        require(lockId_ < nextLockId, "Invalid lockId");
        require(locks[lockId_].owner == _msgSender(), "Not lock owner");
        _;
    }

    constructor(address feeReceiver_) Ownable(_msgSender()) {
        feeReceiver = feeReceiver_;
        addOrUpdateFee("TOKEN", 0, 12 * 10 ** 16, address(0), false);
        addOrUpdateFee("LP_ONLY", 50, 0, address(0), true);
        addOrUpdateFee("LP_AND_ETH", 25, 6 * 10 ** 16, address(0), true);
    }

    function addOrUpdateFee(string memory name_, uint24 lpFee_, uint256 lockFee_, address lockFeeToken_, bool isLp) public onlyOwner {
        bytes32 nameHash = keccak256(abi.encodePacked(name_));
        require(lpFee_ <= DENOMINATOR / 10, "lpFee");

        FeeStruct memory feeObj = FeeStruct(name_,  lockFee_, lockFeeToken_, lpFee_);
        fees[nameHash] = feeObj;
        if(feeNameHashSet.contains(nameHash)) {
            emit OnEditFee(nameHash, name_, lockFee_, lockFeeToken_, lpFee_, isLp);
        } else {
            feeNameHashSet.add(nameHash);
            emit OnAddFee(nameHash, name_, lockFee_, lockFeeToken_, lpFee_, isLp);
        }
        if(isLp) {
            if(!lpSupportedFeeNames.contains(nameHash))
                lpSupportedFeeNames.add(nameHash);
        } else {
            if(!tokenSupportedFeeNames.contains(nameHash))
                tokenSupportedFeeNames.add(nameHash);
        }
    }

    function updateFeeReceiver(address feeReceiver_) external onlyOwner {
        require(feeReceiver_ != address(0), "Zero Address");
        feeReceiver = feeReceiver_;
        emit FeeReceiverUpdated(feeReceiver_);
    }

    function _takeFee(address token_, uint256 amount, bytes32 nameHash) internal returns (bool isLpToken, uint256 newAmount){
        isLpToken = checkIsPair(token_);
        if(isLpToken) {
            require(lpSupportedFeeNames.contains(nameHash), "FeeName not supported for lpToken");
        }else {
            require(tokenSupportedFeeNames.contains(nameHash), "FeeName not supported for Token");
        }
        newAmount = amount;
        FeeStruct memory feeObj = fees[nameHash];
        if(isLpToken && feeObj.lpFee > 0) {
            uint256 lpFeeAmount = amount * feeObj.lpFee / DENOMINATOR;
            newAmount = amount - lpFeeAmount;
            TransferHelper.safeTransfer(token_, token_, lpFeeAmount);
            IUniswapV2Pair(token_).burn(feeReceiver);
        }
        if(feeObj.lockFee > 0) {
            if(feeObj.lockFeeToken == address(0)) {
                require(msg.value == feeObj.lockFee, "Fee");
                TransferHelper.safeTransferETH(feeReceiver, msg.value);
            } else {
                TransferHelper.safeTransferFrom(feeObj.lockFeeToken, _msgSender(), feeReceiver, feeObj.lockFee);
            }
        }
    }

    function _safeTransferFromEnsureAmount(
        address token_,
        address from_,
        uint256 amount_
    ) internal {
        uint256 balanceBefore = IERC20(token_).balanceOf(address(this));
        TransferHelper.safeTransferFrom(token_, from_, address(this), amount_);
        uint256 balanceAfter = IERC20(token_).balanceOf(address(this));
        require(balanceAfter - balanceBefore == amount_, "Received amount not enough");
        
    }

    function _addLock(
        address token_,
        bool isLpToken_,
        address owner_,
        uint256 amount_,
        uint256 endTime_,
        uint256 cycle_,
        uint24 tgeBps_,
        uint24 cycleBps_,
        bytes32 feeNameHash_
    ) internal returns (uint256 lockId) {
        lockId = nextLockId;
        locks[lockId] = LockInfo({
            lockId: lockId,
            token: token_,
            isLpToken: isLpToken_,
            pendingOwner: address(0),
            owner: owner_,
            amount: amount_,
            startTime: block.timestamp,
            endTime: endTime_,
            cycle: cycle_,
            tgeBps: tgeBps_,
            cycleBps: cycleBps_,
            unlockedAmount: 0,
            feeNameHash: feeNameHash_
        });
        nextLockId++;
    }

    /**
     * @dev should called in lock or lockWithPermit method
     */
    function _createLock( 
        address token_,
        string memory feeName_,
        address owner_,
        uint256 amount_,
        uint256 endTime_
    ) internal returns (uint256 lockId) {
        _safeTransferFromEnsureAmount(token_, _msgSender(), amount_);
        bytes32 nameHash = keccak256(abi.encodePacked(feeName_));
        (bool isLpToken_, uint256 newAmount) = _takeFee(token_, amount_, nameHash);
        lockId = _addLock(token_, isLpToken_, owner_, newAmount, endTime_, 0, 0, 0, nameHash);
        if(isLpToken_) {
            userLpLocks[owner_].add(lockId);
        } else {
            userNormalLocks[owner_].add(lockId);
        }
        tokenLocks[token_].add(lockId);
        cumulativeInfos[token_].amount += newAmount;
        emit OnLock(lockId, token_, owner_, newAmount, endTime_);
    }

    function lock(
        address token_,
        string memory feeName_,
        address owner_,
        uint256 amount_,
        uint256 endTime_
    ) external payable override nonReentrant returns (uint256 lockId) {
        require(token_ != address(0), "Invalid token");
        require(endTime_ > block.timestamp, "EndTime");
        require(amount_ > 0, "Amount is 0");
        
        lockId = _createLock(token_, feeName_, owner_, amount_, endTime_);
    }

    function lockWithPermit(
        address token_,
        string memory feeName_,
        address owner_,
        uint256 amount_,
        uint256 endTime_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override nonReentrant returns (uint256 lockId) {
        require(token_ != address(0), "Invalid token");
        require(endTime_ > block.timestamp, "EndTime <= currentTime");
        require(amount_ > 0, "Amount is 0");
        IERC20Permit(token_).permit(_msgSender(), address(this), amount_, deadline_, v, r, s);
        lockId = _createLock(token_, feeName_, owner_, amount_, endTime_);
    }

    function _vestingLock(VestingLockParams memory params, string memory feeName_) internal returns (uint256 lockId) {
        require(params.tgeTime > block.timestamp, "tgeTime <= currentTime");
        require(
            params.tgeBps > 0 && params.cycleBps > 0 
                && params.tgeBps + params.cycleBps <= DENOMINATOR, 
            "Invalid bips"
        );
        _safeTransferFromEnsureAmount(params.token, _msgSender(), params.amount);
        bytes32 nameHash = keccak256(abi.encodePacked(feeName_));
        (bool isLpToken, uint256 newAmount) = _takeFee(params.token, params.amount, nameHash);
        lockId = _addLock(
            params.token,
            isLpToken,
            params.owner,
            newAmount,
            params.tgeTime,
            params.cycle,
            params.tgeBps,
            params.cycleBps,
            nameHash
        );
        if(isLpToken) {
            userLpLocks[params.owner].add(lockId);
        } else {
            userNormalLocks[params.owner].add(lockId);
        }
        tokenLocks[params.token].add(lockId);
        cumulativeInfos[params.token].amount += newAmount;
        emit OnLock(lockId, params.token, params.owner, newAmount, params.tgeTime);
    }

    function vestingLock(
        VestingLockParams memory params,
        string memory feeName_
    ) external payable override nonReentrant returns (uint256 lockId) {
        require(params.token != address(0), "Invalid token");
        require(params.amount > 0, "Amount is 0");
        lockId = _vestingLock(params, feeName_);
    }

    function vestingLockWithPermit(
        VestingLockParams memory params,
        string memory feeName_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override nonReentrant returns (uint256 lockId) {
        require(params.token != address(0), "Invalid token");
        require(params.amount > 0, "Amount is 0");
        IERC20Permit(params.token).permit(_msgSender(), address(this), params.amount, deadline_, v, r, s);
        lockId = _vestingLock(params, feeName_);
    }

    function _updateLock(
        uint256 lockId_,
        uint256 moreAmount_,
        uint256 newEndTime_ 
    ) internal {
        LockInfo storage userLock = locks[lockId_];
        require(userLock.unlockedAmount == 0, "Unlocked");
        require(
            newEndTime_ > userLock.endTime && newEndTime_ > block.timestamp,
            "New EndTime not allowed"
        );
        address lockOwner = _msgSender();
        _safeTransferFromEnsureAmount(userLock.token, lockOwner, moreAmount_);
        (, uint256 newAmount) = _takeFee(userLock.token, moreAmount_, userLock.feeNameHash);

        userLock.amount += newAmount;
        userLock.endTime = newEndTime_;
        cumulativeInfos[userLock.token].amount += newAmount;
        emit OnUpdated(
            lockId_,
            userLock.token,
            lockOwner,
            userLock.amount,
            newEndTime_
        );
    }

    /**
     * @param lockId_  lockId in tokenLocks
     * @param moreAmount_  the amount to increase
     * @param newEndTime_  new endtime must gt old
     */
    function updateLock(
        uint256 lockId_,
        uint256 moreAmount_,
        uint256 newEndTime_
    ) external payable override validLockOwner(lockId_) nonReentrant {
        require(moreAmount_ > 0, "MoreAmount is 0");
        _updateLock(lockId_, moreAmount_, newEndTime_);
    }

    function updateLockWitPermit(
        uint256 lockId_,
        uint256 moreAmount_,
        uint256 newEndTime_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override validLockOwner(lockId_) nonReentrant {
        require(moreAmount_ > 0, "MoreAmount is 0");
        IERC20Permit(locks[lockId_].token).permit(_msgSender(), address(this), moreAmount_, deadline_, v, r, s);
        _updateLock(lockId_, moreAmount_, newEndTime_);
    }

    function transferLock(
        uint256 lockId_,
        address newOwner_
    ) external override validLockOwner(lockId_) {
        locks[lockId_].pendingOwner = newOwner_;
        emit OnLockPendingTransfer(lockId_, _msgSender(), newOwner_);
    }

    function acceptLock(uint256 lockId_) external override {
        require(lockId_ < nextLockId, "Invalid lockId");
        address newOwner = _msgSender();
        // check new owner
        require(newOwner == locks[lockId_].pendingOwner, "Not pendingOwner");
        // emit event
        emit OnLockTransferred(lockId_, locks[lockId_].owner, newOwner);

        if(locks[lockId_].isLpToken) {
            userLpLocks[locks[lockId_].owner].remove(lockId_);
            userLpLocks[newOwner].add(lockId_);
        } else {
            // remove lockId from owner
            userNormalLocks[locks[lockId_].owner].remove(lockId_);
            // add lockId to new Owner
            userNormalLocks[newOwner].add(lockId_);
        }
        // set owner
        locks[lockId_].pendingOwner = address(0);
        locks[lockId_].owner = newOwner;
    }

    function unlock(
        uint256 lockId_
    ) external override validLockOwner(lockId_) nonReentrant {
        LockInfo storage lockInfo = locks[lockId_];
        if (lockInfo.tgeBps > 0) {
            _vestingUnlock(lockInfo);
        } else {
            _normalUnlock(lockInfo);
        }
    }

    function _normalUnlock(LockInfo storage lockInfo) internal {
        require(block.timestamp >= lockInfo.endTime, "Before endTime");
        if(lockInfo.isLpToken) {
            userLpLocks[lockInfo.owner].remove(lockInfo.lockId);
        } else {
            userNormalLocks[lockInfo.owner].remove(lockInfo.lockId);
        }
        tokenLocks[lockInfo.token].remove(lockInfo.lockId);
        TransferHelper.safeTransfer(
            lockInfo.token,
            lockInfo.owner,
            lockInfo.amount
        );
        cumulativeInfos[lockInfo.token].amount -= lockInfo.amount;
        emit OnUnlock(
            lockInfo.lockId,
            lockInfo.token,
            lockInfo.owner,
            lockInfo.amount,
            block.timestamp
        );
        lockInfo.unlockedAmount = lockInfo.amount;
        lockInfo.amount = 0;
    }

    function _vestingUnlock(LockInfo storage lockInfo) internal {
        uint256 withdrawable = _withdrawableTokens(lockInfo);
        uint256 newTotalUnlockAmount = lockInfo.unlockedAmount + withdrawable;
        require(
            withdrawable > 0 && newTotalUnlockAmount <= lockInfo.amount,
            "Nothing to unlock"
        );
        uint256 left = lockInfo.amount - newTotalUnlockAmount;
        if (left == 0) {
            lockInfo.amount = 0;
            tokenLocks[lockInfo.token].remove(lockInfo.lockId);
            if(lockInfo.isLpToken) {
                userLpLocks[lockInfo.owner].remove(lockInfo.lockId);
            } else {
                userNormalLocks[lockInfo.owner].remove(lockInfo.lockId);
            }
            emit OnUnlock(
                lockInfo.lockId,
                lockInfo.token,
                msg.sender,
                newTotalUnlockAmount,
                block.timestamp
            );
        }
        lockInfo.unlockedAmount = newTotalUnlockAmount;

        TransferHelper.safeTransfer(
            lockInfo.token,
            lockInfo.owner,
            withdrawable
        );
        cumulativeInfos[lockInfo.token].amount -= withdrawable;
        emit OnLockVested(
            lockInfo.lockId,
            lockInfo.token,
            _msgSender(),
            withdrawable,
            left,
            block.timestamp
        );
    }

    function _withdrawableTokens(
        LockInfo memory userLock
    ) internal view returns (uint256) {
        if (userLock.amount == 0) return 0;
        if (userLock.unlockedAmount >= userLock.amount) return 0;
        if (block.timestamp < userLock.endTime) return 0;
        if (userLock.cycle == 0) return 0;

        uint256 tgeReleaseAmount = FullMath.mulDiv(
            userLock.amount,
            userLock.tgeBps,
            DENOMINATOR
        );
        uint256 cycleReleaseAmount = FullMath.mulDiv(
            userLock.amount,
            userLock.cycleBps,
            DENOMINATOR
        );
        uint256 currentTotal = 0;
        if (block.timestamp >= userLock.endTime) {
            currentTotal =
                (((block.timestamp - userLock.endTime) / userLock.cycle) *
                    cycleReleaseAmount) +
                tgeReleaseAmount;
        }
        uint256 withdrawable = 0;
        if (currentTotal > userLock.amount) {
            withdrawable = userLock.amount - userLock.unlockedAmount;
        } else {
            withdrawable = currentTotal - userLock.unlockedAmount;
        }
        return withdrawable;
    }

    function withdrawableTokens(
        uint256 lockId_
    ) external override view returns (uint256) {
        LockInfo memory userLock = locks[lockId_];
        return _withdrawableTokens(userLock);
    }

    function getUserNormalLocks(
        address user
    ) external view returns (uint256[] memory lockIds) {
        return userNormalLocks[user].values();
    }

    function getUserLpLocks(
        address user
    ) external view returns (uint256[] memory lockIds) {
        return userLpLocks[user].values();
    }

    function getTokenLocks(
        address token
    ) external view returns (uint256[] memory lockIds) {
        return tokenLocks[token].values();
    }

}


