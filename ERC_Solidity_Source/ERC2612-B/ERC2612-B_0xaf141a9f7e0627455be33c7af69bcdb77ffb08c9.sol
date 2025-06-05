// File: /Users/falconfree/Projects/Curio/vesting-contract/contracts/TokenVesting.sol
/*
 * Copyright ©️ 2020 Curio AG (Company Number FL-0002.594.728-9)
 * Incorporated and registered in Liechtenstein.
 *
 * Copyright ©️ 2020 Curio Capital AG (Company Number CHE-211.446.654)
 * Incorporated and registered in Zug, Switzerland.
 */
// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./access/Adminable.sol";

/**
 * @title TokenVesting
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period.
 * There are 3 types of vesting schedule: CONTINUOUS, MONTHLY (every 30 days), QUARTERLY (every 90 days).
 */
contract TokenVesting is Adminable {
    // The vesting schedule is time-based (i.e. using block timestamps as opposed to e.g. block numbers), and is
    // therefore sensitive to timestamp manipulation (which is something miners can do, to a certain degree). Therefore,
    // it is recommended to avoid using short time durations (less than a minute). Typical vesting schemes, with a
    // cliff period of a year and a duration of four years, are safe to use.
    // solhint-disable not-rely-on-time

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event ReservedAdded(address indexed beneficiary, uint256 reserved);
    event TokensReleased(address indexed beneficiary, address indexed transferredTo, uint256 amount);
    event TokensWithdrawnByAdmin(address indexed token, uint256 amount);

    // private VestingSchedule time constants
    uint256 private constant MONTHLY_TIME = 30 days;
    uint256 private constant QUARTERLY_TIME = 90 days;

    // TokenVesting name
    string public name;

    // ERC20 token which is being vested
    IERC20 public token;

    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    uint256 public cliff;       // the cliff time of the token vesting
    uint256 public start;       // the start time of the token vesting
    uint256 public duration;    // the duration of the token vesting

    // type of the token vesting
    enum VestingSchedule {CONTINUOUS, MONTHLY, QUARTERLY}
    VestingSchedule public schedule;

    // total reserved tokens for beneficiaries
    uint256 public reserved;

    // reserved tokens to beneficiary
    mapping(address => uint256) public reservedForBeneficiary;

    // total released (transferred) tokens
    uint256 public released;

    // released (transferred) tokens to beneficiary
    mapping(address => uint256) public releasedToBeneficiary;

    // array of beneficiaries for getters
    address[] internal beneficiaries;

    /**
     * @dev Creates a vesting contract that vests its balance of specific ERC20 token to the
     * beneficiaries, gradually in a linear fashion until start + duration. By then all
     * of the balance will have vested.
     * @param _token ERC20 token which is being vested
     * @param _cliffDuration duration in seconds of the cliff in which tokens will begin to vest
     * @param _start the time (as Unix time) at which point vesting starts
     * @param _duration duration in seconds of the period in which the tokens will vest
     * @param _schedule type of the token vesting: CONTINUOUS, MONTHLY, QUARTERLY
     * @param _name TokenVesting name
     */
    constructor(
        IERC20 _token,
        uint256 _start,
        uint256 _cliffDuration,
        uint256 _duration,
        VestingSchedule _schedule,
        string memory _name
    ) public {
        require(address(_token) != address(0), "TokenVesting: token is the zero address");
        require(_duration > 0, "TokenVesting: duration is 0");

        require(_cliffDuration <= _duration, "TokenVesting: cliff is longer than duration");
        require(_start.add(_duration) > block.timestamp, "TokenVesting: final time is before current time");

        token = _token;
        duration = _duration;
        cliff = _start.add(_cliffDuration);
        start = _start;
        schedule = _schedule;
        name = _name;
    }

    /**
     * @notice Calculates the total amount of vested tokens.
     */
    function totalVested() public view returns (uint256) {
        uint256 currentBalance = token.balanceOf(address(this));
        return currentBalance.add(released);
    }

    /**
     * @notice Calculates the amount that has already vested but hasn't been released yet.
     * @param _beneficiary Address of vested tokens beneficiary
     */
    function releasableAmount(address _beneficiary) public view returns (uint256) {
        return _vestedAmount(_beneficiary).sub(releasedToBeneficiary[_beneficiary]);
    }

    /**
     * @notice Get a beneficiary address with current index.
     */
    function getBeneficiary(uint256 index) public view returns (address) {
        return beneficiaries[index];
    }

    /**
     * @notice Get an array of beneficiary addresses.
     */
    function getBeneficiaries() public view returns (address[] memory) {
        return beneficiaries;
    }

    /**
     * @notice Adds beneficiaries to TokenVesting by admin.
     *
     * Requirements:
     * - can only be called by admin.
     *
     * @param _beneficiaries Addresses of beneficiaries
     * @param _amounts Amounts of tokens reserved for beneficiaries
     */
    function addBeneficiaries(
        address[] memory _beneficiaries,
        uint256[] memory _amounts
    ) external onlyAdmin {
        uint256 len = _beneficiaries.length;
        require(len == _amounts.length, "TokenVesting: Array lengths do not match");

        uint256 amountToBeneficiaries = 0;
        for (uint256 i = 0; i < len; i++) {
            amountToBeneficiaries = amountToBeneficiaries.add(_amounts[i]);

            // add new beneficiary to array
            if (reservedForBeneficiary[_beneficiaries[i]] == 0) {
                beneficiaries.push(_beneficiaries[i]);
            }

            reservedForBeneficiary[_beneficiaries[i]] = reservedForBeneficiary[_beneficiaries[i]].add(_amounts[i]);
            emit ReservedAdded(_beneficiaries[i], _amounts[i]);
        }

        reserved = reserved.add(amountToBeneficiaries);

        // check reserved condition
        require(reserved <= totalVested(), "TokenVesting: reserved exceeds totalVested");
    }

    /**
     * @notice Withdraws ERC20 token funds by admin (except vested token).
     *
     * Requirements:
     * - can only be called by admin.
     *
     * @param _token Token address (except vested token)
     * @param _amount The amount of token to withdraw
     **/
    function withdrawFunds(IERC20 _token, uint256 _amount) external onlyAdmin {
        require(_token != token, "TokenVesting: vested token is not available for withdrawal");
        _token.safeTransfer(msg.sender, _amount);
        emit TokensWithdrawnByAdmin(address(_token), _amount);
    }

    /**
     * @notice Withdraws ERC20 vested token by admin.
     *
     * Requirements:
     * - can only be called by admin.
     *
     * @param _amount The amount of token to withdraw
     **/
    function emergencyWithdraw(uint256 _amount) external onlyAdmin {
        require(block.timestamp < start, "TokenVesting: vesting has already started");
        token.safeTransfer(msg.sender, _amount);
        emit TokensWithdrawnByAdmin(address(token), _amount);
    }

    /**
     * @notice Transfers vested tokens to beneficiary.
     * @param _beneficiary Address of vested tokens beneficiary
     */
    function release(address _beneficiary) public {
        _release(_beneficiary, _beneficiary);
    }

    /**
     * @notice Transfers vested tokens of sender to specified address.
     * @param _transferTo Address to which tokens are transferred
     */
    function releaseToAddress(address _transferTo) public {
        _release(msg.sender, _transferTo);
    }

    /**
     * @dev Calculates the amount that has already vested.
     * @param _beneficiary Address of vested tokens beneficiary
     */
    function _vestedAmount(address _beneficiary) private view returns (uint256) {
        if (block.timestamp < cliff) {
            return 0;
        } else if (block.timestamp >= start.add(duration)) {
            return reservedForBeneficiary[_beneficiary];
        } else {
            return reservedForBeneficiary[_beneficiary].mul(_vestedPeriod()).div(duration);
        }
    }

    /**
     * @dev Calculates the duration of period that is already unlocked according to VestingSchedule type.
     */
    function _vestedPeriod() private view returns (uint256 period) {
        period = block.timestamp.sub(start);  // CONTINUOUS

        if (schedule == VestingSchedule.MONTHLY) {
            period = period.sub(period % MONTHLY_TIME);
        } else if (schedule == VestingSchedule.QUARTERLY) {
            period = period.sub(period % QUARTERLY_TIME);
        }
    }

    /**
     * @dev Transfers vested tokens.
     * @param _beneficiary Address of vested tokens beneficiary
     * @param _transferTo Address to which tokens are transferred
     */
    function _release(address _beneficiary, address _transferTo) private {
        uint256 unreleased = releasableAmount(_beneficiary);

        require(unreleased > 0, "TokenVesting: no tokens are due");

        releasedToBeneficiary[_beneficiary] = releasedToBeneficiary[_beneficiary].add(unreleased);
        released = released.add(unreleased);

        token.safeTransfer(_transferTo, unreleased);

        emit TokensReleased(_beneficiary, _transferTo, unreleased);
    }
}


// File: /Users/falconfree/Projects/Curio/vesting-contract/contracts/access/Adminable.sol
/*
 * Copyright ©️ 2020 Curio AG (Company Number FL-0002.594.728-9)
 * Incorporated and registered in Liechtenstein.
 *
 * Copyright ©️ 2020 Curio Capital AG (Company Number CHE-211.446.654)
 * Incorporated and registered in Zug, Switzerland.
 */
// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/**
 * @title Adminable
 *
 * @dev Abstract contract provides a basic access control mechanism for Admin role.
 */
abstract contract Adminable {
    // statuses of admins addresses
    mapping(address => bool) public admins;

    event AdminPermissionSet(address indexed account, bool isAdmin);

    /**
     * @dev Creates a contract with msg.sender as first admin.
     */
    constructor() internal {
        admins[msg.sender] = true;
    }

    /**
     * @dev Throws if called by any account other than the admin.
     */
    modifier onlyAdmin {
        require(admins[msg.sender], "Adminable: permission denied");
        _;
    }

    /**
     * @dev Allows the admin to add or remove other admin account.
     *
     * Requirements:
     * - can only be called by admin.
     *
     * @param _admin The address of admin account to add or remove.
     * @param _status True if admin is added, false if removed.
     */
    function setAdminPermission(address _admin, bool _status) public onlyAdmin {
        _setAdminPermission(_admin, _status);
    }

    /**
     * @dev Allows the admin to add or remove many others admins.
     *
     * Requirements:
     * - can only be called by admin.
     * - the lengths of the arrays must be the same.
     *
     * @param _admins The array of addresses of admins accounts to add or remove.
     * @param _statuses Array of statuses of each address.
     */
    function setAdminPermissions(
        address[] memory _admins,
        bool[] memory _statuses
    ) public onlyAdmin {
        uint256 len = _admins.length;
        require(len == _statuses.length, "Adminable: Array lengths do not match");

        for (uint256 i = 0; i < len; i++) {
            _setAdminPermission(_admins[i], _statuses[i]);
        }
    }

    /**
     * @dev Sets the admin/not admin status for the specified address.
     *
     * Emits a {AdminPermissionSet} event with `account` set to new added
     * or removed admin address and `isAdmin` set to admin account status.
     *
     * @param _admin The address of admin account to add or remove.
     * @param _status True if admin is added, false if removed.
     */
    function _setAdminPermission(address _admin, bool _status) internal {
        admins[_admin] = _status;
        emit AdminPermissionSet(_admin, _status);
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
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
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
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
        require(b != 0, errorMessage);
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


