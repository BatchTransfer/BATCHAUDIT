// File: contracts/farms/ERC1155Farm.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import '../interfaces/IVault.sol';

contract ERC1155Farm is IVault, Ownable, ERC1155Holder {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event ClaimedRewards(
    address indexed user,
    uint256 indexed pid,
    uint256 amount
  );
  event EmergencyWithdraw(
    address indexed user,
    uint256 indexed pid,
    uint256 amount
  );

  /// @notice Detail of each user.
  struct UserInfo {
    uint256 amount; // How many tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
    //
    // We do some fancy math here. Basically, any point in time, the amount of reward
    // entitled to a user which is pending to be distributed is:
    //
    // pending reward = (user.amount * pool.accRewardPerShare) - user.rewardDebt
    //
    // Whenever a user deposits or withdraws tokens to a pool:
    //   1. The pool's `accRewardPerShare` (and `lastRewardBlock`) gets updated.
    //   2. User receives the pending reward sent to their address.
    //   3. User's `amount` gets updated.
    //   4. User's `rewardDebt` gets updated.
  }

  /// @notice Detail of each pool.
  struct PoolInfo {
    address token; // Token to stake.
    uint256 tokenId; // NFT ID
    uint256 allocPoint; // How many allocation points assigned to this pool. Rewards to distribute per block.
    uint256 accRewardPerShare; // Accumulated rewards per share.
  }

  /// @dev Reward token balance minus any pending rewards.
  uint256 private rewardTokenBalance;

  /// @dev Division precision.
  uint256 private precision = 1e12;

  /// @notice Total allocation points. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint;

  /// @notice Pending rewards awaiting for massUpdate.
  uint256 public pendingRewards;

  /// @notice Contract block deployment.
  uint256 public initialBlock;

  /// @notice Time of the contract deployment.
  uint256 public timeDeployed;

  /// @notice Total rewards accumulated since contract deployment.
  uint256 public totalCumulativeRewards;

  /// @notice Reward token.
  address public rewardToken;

  /// @notice Detail of each pool.
  PoolInfo[] public poolInfo;

  /// @notice Detail of each user who stakes tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;

  constructor(address _rewardToken) public {
    rewardToken = _rewardToken;
    initialBlock = block.number;
    timeDeployed = block.timestamp;
  }

  /// @notice Average fee generated since contract deployment.
  function avgFeesPerBlockTotal() external view returns (uint256 avgPerBlock) {
    return totalCumulativeRewards.div(block.number.sub(initialBlock));
  }

  /// @notice Average fee per second generated since contract deployment.
  function avgFeesPerSecondTotal()
    external
    view
    returns (uint256 avgPerSecond)
  {
    return totalCumulativeRewards.div(block.timestamp.sub(timeDeployed));
  }

  /// @notice Total pools.
  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  /// @notice Display user rewards for a specific pool.
  function pendingReward(uint256 _pid, address _user)
    public
    view
    returns (uint256)
  {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accRewardPerShare = pool.accRewardPerShare;

    return
      user.amount.mul(accRewardPerShare).div(precision).sub(user.rewardDebt);
  }

  /// @notice Add a new pool.
  function add(
    uint256 _allocPoint,
    address _token,
    uint256 _tokenId,
    bool _withUpdate
  ) public onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }

    uint256 length = poolInfo.length;

    for (uint256 pid = 0; pid < length; ++pid) {
      if (poolInfo[pid].token == _token) {
        require(
          poolInfo[pid].tokenId != _tokenId,
          'NFTRewardsVault: Token pool already added.'
        );
      }
    }

    totalAllocPoint = totalAllocPoint.add(_allocPoint);

    poolInfo.push(
      PoolInfo({
        token: _token,
        tokenId: _tokenId,
        allocPoint: _allocPoint,
        accRewardPerShare: 0
      })
    );
  }

  /// @notice Update the given pool's allocation point.
  function set(
    uint256 _pid,
    uint256 _allocPoint,
    bool _withUpdate
  ) public onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }

    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
      _allocPoint
    );
    poolInfo[_pid].allocPoint = _allocPoint;
  }

  /// @notice Updates rewards for all pools by adding pending rewards.
  /// Can spend a lot of gas.
  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    uint256 allRewards;

    for (uint256 pid = 0; pid < length; ++pid) {
      allRewards = allRewards.add(_updatePool(pid));
    }

    pendingRewards = pendingRewards.sub(allRewards);
  }

  /// @notice Function that is part of Vault's interface. It must be implemented.
  function update(uint256 amount) external override {
    amount; // silence warning.
    _addPendingRewards();
    massUpdatePools();
  }

  /// @notice Deposit tokens to vault for reward allocation.
  function deposit(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    massUpdatePools();

    // Transfer pending tokens to user
    _updateAndPayOutPending(_pid, msg.sender);

    //Transfer in the amounts from user
    if (_amount > 0) {
      IERC1155(pool.token).safeTransferFrom(
        address(msg.sender),
        address(this),
        pool.tokenId,
        _amount,
        ''
      );
      user.amount = user.amount.add(_amount);
    }

    user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(precision);
    emit Deposit(msg.sender, _pid, _amount);
  }

  // Withdraw  tokens from Vault.
  function withdraw(uint256 _pid, uint256 _amount) public {
    _withdraw(_pid, _amount, msg.sender, msg.sender);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  // !Caution this will remove all your pending rewards!
  function emergencyWithdraw(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    IERC1155(pool.token).safeTransferFrom(
      address(this),
      address(msg.sender),
      pool.tokenId,
      user.amount,
      ''
    );
    emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
    // No mass update dont update pending rewards
  }

  /// @notice Adds any rewards that were sent to the contract since last reward update.
  function _addPendingRewards() internal {
    uint256 newRewards =
      IERC20(rewardToken).balanceOf(address(this)).sub(rewardTokenBalance);

    if (newRewards > 0) {
      rewardTokenBalance = IERC20(rewardToken).balanceOf(address(this));
      pendingRewards = pendingRewards.add(newRewards);
      totalCumulativeRewards = totalCumulativeRewards.add(newRewards);
    }
  }

  // Low level withdraw function
  function _withdraw(
    uint256 _pid,
    uint256 _amount,
    address from,
    address to
  ) internal {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][from];
    require(
      user.amount >= _amount,
      'NFTRewardsVault: Withdraw amount is greater than user stake.'
    );
    massUpdatePools();
    _updateAndPayOutPending(_pid, from); // Update balance and claim rewards farmed

    if (_amount > 0) {
      user.amount = user.amount.sub(_amount);
      IERC1155(pool.token).safeTransferFrom(
        address(this),
        address(to),
        pool.tokenId,
        _amount,
        ''
      );
    }

    user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(precision);
    emit Withdraw(to, _pid, _amount);
  }

  /// @notice Allocates pending rewards to pool.
  function _updatePool(uint256 _pid)
    internal
    returns (uint256 poolShareRewards)
  {
    PoolInfo storage pool = poolInfo[_pid];

    uint256 stakedTokens;

    stakedTokens = IERC1155(pool.token).balanceOf(address(this), pool.tokenId);

    if (totalAllocPoint == 0 || stakedTokens == 0) {
      return 0;
    }

    poolShareRewards = pendingRewards.mul(pool.allocPoint).div(totalAllocPoint);
    pool.accRewardPerShare = pool.accRewardPerShare.add(
      poolShareRewards.mul(precision).div(stakedTokens)
    );
  }

  function _safeRewardTokenTransfer(address _to, uint256 _amount)
    internal
    returns (uint256 _claimed)
  {
    uint256 rewardTokenBal = IERC20(rewardToken).balanceOf(address(this));

    if (_amount > rewardTokenBal) {
      _claimed = rewardTokenBal;
      IERC20(rewardToken).transfer(_to, rewardTokenBal);
      rewardTokenBalance = IERC20(rewardToken).balanceOf(address(this));
    } else {
      _claimed = _amount;
      IERC20(rewardToken).transfer(_to, _amount);
      rewardTokenBalance = IERC20(rewardToken).balanceOf(address(this));
    }
  }

  function _updateAndPayOutPending(uint256 _pid, address _from) internal {
    uint256 pending = pendingReward(_pid, _from);

    if (pending > 0) {
      uint256 _amountClaimed = _safeRewardTokenTransfer(_from, pending);
      emit ClaimedRewards(_from, _pid, _amountClaimed);
    }
  }
}


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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

pragma solidity ^0.6.0;

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


// File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

import "../../introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);

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
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
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
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);

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
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}


// File: @openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./ERC1155Receiver.sol";

/**
 * @dev _Available since v3.1._
 */
contract ERC1155Holder is ERC1155Receiver {
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}


// File: @openzeppelin/contracts/math/SafeMath.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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


// File: @openzeppelin/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../GSN/Context.sol";
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
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


// File: contracts/interfaces/IVault.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

interface IVault {
  function update(uint256) external;
}


// File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

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
        // This method relies in extcodesize, which returns 0 for contracts in
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
        return _functionCallWithValue(target, data, 0, errorMessage);
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
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
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


// File: @openzeppelin/contracts/introspection/IERC165.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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


// File: @openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./IERC1155Receiver.sol";
import "../../introspection/ERC165.sol";

/**
 * @dev _Available since v3.1._
 */
abstract contract ERC1155Receiver is ERC165, IERC1155Receiver {
    constructor() public {
        _registerInterface(
            ERC1155Receiver(0).onERC1155Received.selector ^
            ERC1155Receiver(0).onERC1155BatchReceived.selector
        );
    }
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../../introspection/IERC165.sol";

/**
 * _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {

    /**
        @dev Handles the receipt of a single ERC1155 token type. This function is
        called at the end of a `safeTransferFrom` after the balance has been updated.
        To accept the transfer, this must return
        `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
        (i.e. 0xf23a6e61, or its own function selector).
        @param operator The address which initiated the transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param id The ID of the token being transferred
        @param value The amount of tokens being transferred
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
    */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    )
        external
        returns(bytes4);

    /**
        @dev Handles the receipt of a multiple ERC1155 token types. This function
        is called at the end of a `safeBatchTransferFrom` after the balances have
        been updated. To accept the transfer(s), this must return
        `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
        (i.e. 0xbc197c81, or its own function selector).
        @param operator The address which initiated the batch transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param ids An array containing ids of each token being transferred (order and length must match values array)
        @param values An array containing amounts of each token being transferred (order and length must match ids array)
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
    */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    )
        external
        returns(bytes4);
}


// File: @openzeppelin/contracts/introspection/ERC165.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts may inherit from this and call {_registerInterface} to declare
 * their support of an interface.
 */
contract ERC165 is IERC165 {
    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    constructor () internal {
        // Derived contracts need only register support for their own interfaces,
        // we register support for ERC165 itself here
        _registerInterface(_INTERFACE_ID_ERC165);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     *
     * Time complexity O(1), guaranteed to always use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`. Support of the actual ERC165 interface is automatic and
     * registering its interface id is not required.
     *
     * See {IERC165-supportsInterface}.
     *
     * Requirements:
     *
     * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
     */
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}


// File: @openzeppelin/contracts/GSN/Context.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


// File: contracts/NFTRewardsVault.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import './farms/ERC1155Farm.sol';

contract NFTRewardsVault is ERC1155Farm {
  constructor(address _rewardToken) public ERC1155Farm(_rewardToken) {}
}


// File: contracts/TreasuryVault.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './interfaces/IVault.sol';

contract TreasuryVault is IVault {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event LPRewardDistributed(uint256 amount);
  event TreasuryDeposit(uint256 amount);

  address public tdao;
  address public rewardsVault;
  address public treasury;

  uint256 public rewardFee = 9000;
  uint256 public constant BASE = 10000;

  constructor(
    address _tdao,
    address _RewardsVault,
    address _treasuryAddress
  ) public {
    tdao = _tdao;
    rewardsVault = _RewardsVault;
    treasury = _treasuryAddress;
  }

  function update(uint256 amount) external override {
    amount; // Silence warning;

    uint256 _balance = IERC20(tdao).balanceOf(address(this));

    if (_balance < 100) {
      return;
    }

    uint256 rewardShare = _balance.mul(rewardFee).div(BASE);
    uint256 treasuryShare = _balance.sub(rewardShare);

    IERC20(tdao).safeTransfer(rewardsVault, rewardShare);
    IERC20(tdao).safeTransfer(treasury, treasuryShare);

    IVault(rewardsVault).update(rewardShare);

    emit LPRewardDistributed(rewardShare);
    emit TreasuryDeposit(treasuryShare);
  }

  function sendERC20ToTreasury(address token) external {
    IERC20(token).safeTransfer(
      treasury,
      IERC20(token).balanceOf(address(this))
    );
  }
}


// File: contracts/utils/TribRouterLLE.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16 <0.7.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import '../interfaces/ILockedLiquidityEvent.sol';
import '../interfaces/ITDAO.sol';
import '../interfaces/IWETH.sol';
import '../interfaces/IBalancer.sol';
import '../interfaces/IContribute.sol';
import '../interfaces/IDetailERC20.sol';

contract TribRouterLLE {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public pair;
  address public weth;
  address public mUSD;
  address public trib;
  address public tribMinter;
  address public tDao;
  address public lockedLiquidityEvent;

  event TribPurchased(
    address indexed from,
    uint256 amountIn,
    uint256 amountOut
  );
  event EthToMUSDConversion(
    uint256 amountIn,
    uint256 amountOut,
    uint256 spotPrice
  );
  event AddedLiquidity(
    address indexed from,
    uint256 amountIn,
    uint256 amountOut
  );

  constructor(
    address _pair,
    address _tribMinter,
    address _tDao
  ) public {
    pair = _pair;
    tribMinter = _tribMinter;
    tDao = _tDao;

    trib = IContribute(tribMinter).token();
    address[] memory tokens;
    address tokenA;
    address tokenB;
    tokens = IBalancer(pair).getCurrentTokens();
    tokenA = tokens[0];
    tokenB = tokens[1];
    weth = keccak256(bytes(IDetailERC20(tokenA).symbol())) ==
      keccak256(bytes('WETH'))
      ? tokenA
      : tokenB;
    mUSD = weth == tokenA ? tokenB : tokenA;
    lockedLiquidityEvent = ITDAO(tDao).lockedLiquidityEvent();

    _approveMax(weth, pair);
    _approveMax(mUSD, tribMinter);
    _approveMax(trib, lockedLiquidityEvent);
  }

  receive() external payable {
    _addLiquidityWithEth();
  }

  // @notice Calculates the amount of TRIB given Eth amount.
  function calcTribOut(uint256 amount) external view returns (uint256 tribOut) {
    uint256 amountMUSD = _calcMUSDOut(amount);
    tribOut = IContribute(tribMinter).getReserveToTokensTaxed(amountMUSD);
  }

  // @notice Purchases Trib using Weth.
  // @TODO - Call external function that adds liquidity to LLE.
  function addLiquidity(uint256 amount) external {
    require(amount != 0, 'TribRouterLLE: Must deposit Weth.');
    IERC20(weth).safeTransferFrom(msg.sender, address(this), amount);
    _addLiquidity(msg.sender, amount);
  }

  function _addLiquidityWithEth() internal {
    uint256 amountIn = msg.value;
    IWETH(weth).deposit{value: amountIn}();
    require(
      IERC20(weth).balanceOf(address(this)) != 0,
      'TribRouterLLE: Weth deposit failed.'
    );
    _addLiquidity(msg.sender, amountIn);
  }

  function _addLiquidity(address _account, uint256 _amount) internal {
    uint256 amountMUSD = _convertWethToMUSD(_amount);
    uint256 amountTrib = _buyTrib(_account, amountMUSD);

    if (
      IERC20(trib).allowance(address(this), lockedLiquidityEvent) < amountTrib
    ) {
      _approveMax(trib, lockedLiquidityEvent);
    }

    ILockedLiquidityEvent(lockedLiquidityEvent).addLiquidityFor(
      _account,
      amountTrib
    );

    emit AddedLiquidity(_account, _amount, amountTrib);
  }

  // @notice Estimates amount of mUSD to be purchased given Eth amount.
  function _calcMUSDOut(uint256 _amount)
    internal
    view
    returns (uint256 _amountMUSD)
  {
    uint256 amountIn = _amount;
    uint256 weightMUSD = IBalancer(pair).getNormalizedWeight(mUSD);
    uint256 weightWeth = IBalancer(pair).getNormalizedWeight(weth);
    uint256 balanceMUSD = IERC20(mUSD).balanceOf(pair);
    uint256 balanceWeth = IERC20(weth).balanceOf(pair);
    uint256 swapFee = IBalancer(pair).getSwapFee();

    _amountMUSD = IBalancer(pair).calcOutGivenIn(
      balanceWeth,
      weightWeth,
      balanceMUSD,
      weightMUSD,
      amountIn,
      swapFee
    );
  }

  // @notice Converts Weth to mUSD.
  function _convertWethToMUSD(uint256 _amount)
    internal
    returns (uint256 _amountMUSD)
  {
    uint256 amountIn = _amount;

    uint256 price = IBalancer(pair).getSpotPrice(mUSD, weth);
    uint256 minAmount = price.mul(amountIn).div(1e18);
    uint256 range = 10;
    uint256 min = minAmount.sub(minAmount.div(range));
    uint256 max = price.add(price.div(range));

    if (IERC20(weth).allowance(address(this), pair) < amountIn) {
      _approveMax(weth, pair);
    }

    uint256 spotPriceAfter;

    (_amountMUSD, spotPriceAfter) = IBalancer(pair).swapExactAmountIn(
      weth,
      amountIn,
      mUSD,
      min,
      max
    );

    emit EthToMUSDConversion(amountIn, _amountMUSD, spotPriceAfter);
  }

  // @notice Sends mUSD to minter in order to buy Trib.
  function _buyTrib(address _account, uint256 _amount)
    internal
    returns (uint256 _totalTrib)
  {
    uint256 amount = _amount;

    if (IERC20(mUSD).allowance(address(this), tribMinter) < amount) {
      _approveMax(mUSD, tribMinter);
    }

    _totalTrib = IContribute(tribMinter).getReserveToTokensTaxed(amount);
    IContribute(tribMinter).invest(amount);

    emit TribPurchased(_account, _amount, _totalTrib);
  }

  // @notice Approves max. uint value for gas savings.
  function _approveMax(address _token, address _spender) internal {
    IERC20(_token).safeApprove(_spender, uint256(-1));
  }
}


// File: contracts/interfaces/ILockedLiquidityEvent.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

interface ILockedLiquidityEvent {
  function highestDeposit() external view returns (address, uint256);

  function startTradingTime() external view returns (uint256);

  function addLiquidity(uint256) external;

  function addLiquidityFor(address, uint256) external;
}


// File: contracts/interfaces/ITDAO.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

interface ITDAO {
  function startLiquidityEventTime() external view returns (uint256);

  function maxSupply() external view returns (uint256);

  function governance() external view returns (address);

  function feeController() external view returns (address);

  function feeSplitter() external view returns (address);

  function lockedLiquidityEvent() external view returns (address);

  function claimERC20(address, address) external;

  function setTreasuryVault(address) external;

  function setTrigFee(uint256) external;

  function setFee(uint256) external;

  function editNoFeeList(address, bool) external;

  function editBlackList(address, bool) external;

  function setDependencies(
    address,
    address,
    address
  ) external;

  function delegates(address) external view returns (address);

  function delegate(address) external;

  function getCurrentVotes(address account) external view returns (uint256);

  function getPriorVotes(address, uint256) external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function allowance(address owner, address spender)
    external
    view
    returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);
}


// File: contracts/interfaces/IWETH.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

interface IWETH {
  function deposit() external payable;
}


// File: contracts/interfaces/IBalancer.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

interface IBalancer {
  function swapExactAmountOut(
    address tokenIn,
    uint256 maxAmountIn,
    address tokenOut,
    uint256 tokenAmountOut,
    uint256 maxPrice
  ) external returns (uint256 tokenAmountIn, uint256 spotPriceAfter);

  function swapExactAmountIn(
    address tokenIn,
    uint256 tokenAmountIn,
    address tokenOut,
    uint256 minAmountOut,
    uint256 maxPrice
  ) external returns (uint256 tokenAmountOut, uint256 spotPriceAfter);

  function calcOutGivenIn(
    uint256 tokenBalanceIn,
    uint256 tokenWeightIn,
    uint256 tokenBalanceOut,
    uint256 tokenWeightOut,
    uint256 tokenAmountIn,
    uint256 swapFee
  ) external view returns (uint256);

  function getSpotPrice(address tokenIn, address tokenOut)
    external
    view
    returns (uint256);

  function getNormalizedWeight(address token) external view returns (uint256);

  function getSwapFee() external view returns (uint256);

  function getCurrentTokens() external view returns (address[] memory);

  function drip(address) external;
}


// File: contracts/interfaces/IContribute.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

/**
 * This interface is only to facilitate
 * interacting with the contract in remix.ethereum.org
 * after it has been deployed to a testnet or mainnet.
 *
 * Just copy/paste the interface in Remix and deploy
 * at contract address.
 */

interface IContribute {
  function TAX() external view returns (uint256);

  function DIVIDER() external view returns (uint256);

  function GME() external view returns (bool);

  function token() external view returns (address);

  function genesis() external view returns (address);

  function genesisAveragePrice() external view returns (uint256);

  function genesisReserve() external view returns (uint256);

  function totalInterestClaimed() external view returns (uint256);

  function totalReserve() external view returns (uint256);

  function reserve() external view returns (address);

  function vault() external view returns (address);

  function genesisInvest(uint256) external;

  function concludeGME() external;

  function invest(uint256) external;

  function sell(uint256) external;

  function claimInterest() external;

  function totalClaimRequired() external view returns (uint256);

  function claimRequired(uint256) external view returns (uint256);

  function totalContributed() external view returns (uint256);

  function getInterest() external view returns (uint256);

  function getTotalSupply() external view returns (uint256);

  function getBurnedTokensAmount() external view returns (uint256);

  function getCurrentTokenPrice() external view returns (uint256);

  function getReserveToTokensTaxed(uint256) external view returns (uint256);

  function getTokensToReserveTaxed(uint256) external view returns (uint256);

  function getReserveToTokens(uint256) external view returns (uint256);

  function getTokensToReserve(uint256) external view returns (uint256);
}


// File: contracts/interfaces/IDetailERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

interface IDetailERC20 {
  function symbol() external view returns (string memory);
}


// File: contracts/LockedLiquidityEvent.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol';

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

import './interfaces/ITDAO.sol';
import './interfaces/IFeeSplitter.sol';
import './interfaces/INFTRewardsVault.sol';
import './interfaces/IVault.sol';
import './TRIG.sol';

contract LockedLiquidityEvent is ERC1155Holder {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event LiquidityAddition(address indexed account, uint256 value);
  event TransferredNFT(address indexed account, uint32[7] amount);
  event DivinityClaimed(address indexed account);
  event TrigClaimed(address indexed account, uint256 value);

  struct HighestDeposit {
    address account;
    uint256 amount;
  }

  /// @notice Time required to pass before TDAO transfers can succeed
  uint256 public constant GRACE_PERIOD = 1 hours;

  /// @notice Minimum amount of TDAO which needs to be deposited
  /// for the Divinity NFT to be claimed
  uint256 public constant MIN_PRICE_DIVINITY_NFT = 50000 ether;

  IUniswapV2Router02 public uniswapRouterV2;
  IUniswapV2Factory public uniswapFactory;
  HighestDeposit public highestDeposit;

  /// @notice Time when LLE starts
  uint256 public startTime;

  /// @notice Time when LLE ends
  uint256 public endTime;

  /// @notice Exact time when trading with Uniswap is allowed
  uint256 public startTradingTime;

  /// @notice Total TRIB contributed in LLE event
  uint256 public totalContributed;

  /// @notice Trig tokens per TRIB unit sold
  uint256 public trigTokensPerUnit;

  address public tdao;
  address public tokenB;
  address public nft;
  address public trig;
  address public tokenUniswapPair;
  address public burnAddress = 0x000000000000000000000000000000000000dEaD;

  /// @notice LLE completion flag
  bool public eventCompleted;

  /// @notice Unique NFT index that was not allocated during the LLE
  uint32[] public nftTreasuryIndex;

  /// @notice Initial allocation for each NFT with Divnity exception
  uint32[] public nftAllocation = [10, 8, 6, 5, 4, 2, 1];

  /// @notice Supply tracker for each NFT with Divnity exception
  uint32[] public nftSupply = [10, 8, 6, 5, 4, 2, 1];

  /// @notice Minimum TRIB required to distribute each NFT
  uint32[] public nftMin = [500, 2000, 5000, 10000, 20000, 50000, 100000];

  /// @notice TRIB contributed by address
  mapping(address => uint256) public contributed;

  modifier onlyGovernance() {
    address governance = ITDAO(tdao).governance();
    require(
      governance != address(0),
      'LockedLiquidityEvent: Governance is not set.'
    );
    require(
      msg.sender == governance,
      'LockedLiquidityEvent: Only governance can call this function.'
    );
    _;
  }

  constructor(
    address _router,
    address _factory,
    address _tdao,
    address _tokenB,
    address _nft,
    uint256 _startTime,
    uint256 _endTime
  ) public {
    require(
      _startTime < _endTime,
      'LockedLiquidityEvent: Must start before the end.'
    );
    tdao = _tdao;
    tokenB = _tokenB;
    nft = _nft;
    startTime = _startTime;
    endTime = _endTime;
    startTradingTime = _endTime.add(GRACE_PERIOD);
    uniswapRouterV2 = IUniswapV2Router02(_router);
    uniswapFactory = IUniswapV2Factory(_factory);
    tokenUniswapPair = _createUniswapPair(tdao, tokenB);
    trig = address(new TRIG('Contribute Rig', 'TRIG'));
  }

  /// @notice Time in seconds left for the Liquidity Pool Event.
  function timeRemaining() external view returns (uint256 remaining) {
    if (ongoing()) {
      remaining = endTime.sub(block.timestamp);
    }
  }

  /// @notice Is Locked Liquidity Event ongoing.
  function ongoing() public view virtual returns (bool) {
    return (endTime > block.timestamp && block.timestamp >= startTime);
  }

  /// @notice Deposits tokenB to the contract, allocates and distributes NFT
  /// to the account.
  function addLiquidity(uint256 amount) external {
    require(
      _addLiquidity(msg.sender, amount),
      'LockedLiquidityEvent: Failed to add liquidity.'
    );
    _allocateHighestDeposit(msg.sender, amount);
    _processNFT(msg.sender, amount);
  }

  /// @notice Deposits tokenB to the contract in behalf of someone else,
  /// allocates and distributes NFT to the account.
  function addLiquidityFor(address account, uint256 amount) external {
    require(
      _addLiquidityFor(msg.sender, account, amount),
      'LockedLiquidityEvent: Failed to add liquidity.'
    );
    _allocateHighestDeposit(account, amount);
    _processNFT(account, amount);
  }

  /// @notice Locks liquidity in the Uniswap Pool,
  /// mints UNI-LP and TRIG tokens.
  function lockLiquidity() external {
    require(ongoing() == false, 'LockedLiquidityEvent: LLE ongoing.');
    require(
      eventCompleted == false,
      'LockedLiquidityEvent: LLE already finished.'
    );
    require(
      totalContributed != 0,
      'LockedLiquidityEvent: Contribution must be greater than zero.'
    );

    IUniswapV2Pair pair = IUniswapV2Pair(tokenUniswapPair);

    IERC20(tdao).safeTransfer(
      address(pair),
      IERC20(tdao).balanceOf(address(this))
    );
    IERC20(tokenB).safeTransfer(address(pair), totalContributed);

    pair.mint(address(this));
    require(
      pair.balanceOf(address(this)) != 0,
      'LockedLiquidityEvent: Failed to mint LP tokens.'
    );

    trigTokensPerUnit = IERC20(trig).totalSupply().mul(1e18).div(
      totalContributed
    );

    _depositUnclaimedTier();
    _burnRemainingNFTs();

    eventCompleted = true;
  }

  /// @notice Allows contributors to claim TRIG tokens.
  function claimTrig() external {
    require(eventCompleted, 'LockedLiquidityEvent: Event not over yet.');
    require(
      contributed[msg.sender] != 0,
      'LockedLiquidityEvent: Nothing to claim.'
    );

    uint256 amountTrigToTransfer =
      contributed[msg.sender].mul(trigTokensPerUnit).div(1e18);

    contributed[msg.sender] = 0;

    _processHighestDeposit(msg.sender);

    IERC20(trig).safeTransfer(msg.sender, amountTrigToTransfer);

    emit TrigClaimed(msg.sender, amountTrigToTransfer);
  }

  function claimERC20(address erc20, address recipient)
    external
    onlyGovernance
  {
    if (erc20 == tokenUniswapPair) {
      require(
        block.timestamp > startTradingTime.add(365 days),
        'LockedLiquidityEvent: Can only claim LP tokens after one year.'
      );
    }
    IERC20(erc20).safeTransfer(
      recipient,
      IERC20(erc20).balanceOf(address(this))
    );
  }

  function claimTreasuryNFTRewards() external {
    require(eventCompleted, 'LockedLiquidityEvent: Event not over yet.');
    require(
      nftTreasuryIndex.length != 0,
      'LockedLiquidityEvent: Treasury has not NFTs staking.'
    );

    address nftRewardsVault =
      IFeeSplitter(ITDAO(tdao).feeSplitter()).nftRewardsVault();
    address treasuryVault =
      IFeeSplitter(ITDAO(tdao).feeSplitter()).treasuryVault();

    for (uint8 i = 0; i < nftTreasuryIndex.length; i++) {
      INFTRewardsVault(nftRewardsVault).withdraw(nftTreasuryIndex[i], 0);
    }

    uint256 amount = IERC20(tdao).balanceOf(address(this));

    IERC20(tdao).safeTransfer(treasuryVault, amount);

    IVault(treasuryVault).update(amount);
  }

  function _addLiquidity(address _account, uint256 _amount)
    internal
    returns (bool)
  {
    require(ongoing(), 'LockedLiquidityEvent: Locked Liquidity Event over.');
    require(
      _amount > 0,
      'LockedLiquidityEvent: Must add value greater than 0.'
    );

    IERC20(tokenB).safeTransferFrom(_account, address(this), _amount);
    contributed[_account] = contributed[_account].add(_amount);
    totalContributed = totalContributed.add(_amount);

    emit LiquidityAddition(_account, _amount);

    return true;
  }

  function _addLiquidityFor(
    address _from,
    address _to,
    uint256 _amount
  ) internal returns (bool) {
    require(ongoing(), 'LockedLiquidityEvent: Liquidity Pool Event over.');
    require(
      _amount > 0,
      'LockedLiquidityEvent: Must add value greater than 0.'
    );

    IERC20(tokenB).safeTransferFrom(_from, address(this), _amount);
    contributed[_to] = contributed[_to].add(_amount);
    totalContributed = totalContributed.add(_amount);

    emit LiquidityAddition(_to, _amount);

    return true;
  }

  /// @notice Uniswap Pair Contract creation.
  function _createUniswapPair(address _tokenA, address _tokenB)
    internal
    returns (address)
  {
    require(
      tokenUniswapPair == address(0),
      'LiquidityPool: pool already created'
    );
    address uniPair = uniswapFactory.createPair(_tokenA, _tokenB);
    return uniPair;
  }

  function _allocateHighestDeposit(address _account, uint256 _amount) internal {
    if (_amount > highestDeposit.amount && _amount >= MIN_PRICE_DIVINITY_NFT) {
      highestDeposit.account = _account;
      highestDeposit.amount = _amount;
    }
  }

  function _depositUnclaimedTier() internal {
    address nftRewardsVault =
      IFeeSplitter(ITDAO(tdao).feeSplitter()).nftRewardsVault();
    IERC1155(nft).setApprovalForAll(nftRewardsVault, true);

    for (uint8 i = 0; i < nftAllocation.length; i++) {
      if (nftSupply[i] == nftAllocation[i]) {
        nftTreasuryIndex.push(i);
        nftSupply[i] -= 1;
      }
    }

    if (highestDeposit.account == address(0)) {
      nftTreasuryIndex.push(7);
    }

    for (uint8 i = 0; i < nftTreasuryIndex.length; i++) {
      INFTRewardsVault(nftRewardsVault).deposit(nftTreasuryIndex[i], 1);
    }
  }

  function _burnRemainingNFTs() internal {
    for (uint8 i = 0; i < nftSupply.length; i++) {
      if (nftSupply[i] != 0) {
        uint256 _amount = nftSupply[i];
        nftSupply[i] = 0;
        IERC1155(nft).safeTransferFrom(
          address(this),
          burnAddress,
          i,
          _amount,
          bytes('0x0')
        );
      }
    }
  }

  function _processHighestDeposit(address _account) internal {
    if (_account != highestDeposit.account) {
      return;
    }

    _transferHighestDepositNFT(_account);
  }

  function _transferHighestDepositNFT(address _account) internal {
    IERC1155(nft).safeTransferFrom(address(this), _account, 7, 1, bytes('0x0'));

    emit DivinityClaimed(_account);
  }

  function _shouldTransferNFT(uint32[7] memory _allocatedAmounts)
    internal
    pure
    returns (bool _result)
  {
    for (uint8 i = 0; i < _allocatedAmounts.length; i++) {
      if (_allocatedAmounts[i] != 0) {
        _result = true;
        break;
      }
    }
  }

  function _processNFT(address _account, uint256 _amount) internal {
    uint32[7] memory _allocatedAmounts = _allocateNFT(_amount);

    if (!_shouldTransferNFT(_allocatedAmounts)) {
      return;
    }

    _transferNFT(_account, _allocatedAmounts);
  }

  function _transferNFT(address _account, uint32[7] memory _allocatedAmounts)
    internal
  {
    uint256[] memory _amounts = new uint256[](7);
    uint256[] memory _indexes = new uint256[](7);

    for (uint8 i = 0; i < _allocatedAmounts.length; i++) {
      _amounts[i] = (_allocatedAmounts[i]);
      _indexes[i] = i;
    }

    IERC1155(nft).safeBatchTransferFrom(
      address(this),
      _account,
      _indexes,
      _amounts,
      bytes('0x0')
    );

    emit TransferredNFT(_account, _allocatedAmounts);
  }

  function _allocateNFT(uint256 _amount) internal returns (uint32[7] memory) {
    uint32 _remaining = uint32(_amount.div(1e18));
    uint32[7] memory _rewards;

    for (uint256 i = nftSupply.length; i > 0; i--) {
      uint256 _index = i - 1;

      if (nftSupply[_index] == 0) {
        break;
      }

      while (_remaining >= nftMin[_index]) {
        if (nftSupply[_index] != 0) {
          uint32 _attainable = _remaining / nftMin[_index];
          if (_attainable <= nftSupply[_index]) {
            nftSupply[_index] = nftSupply[_index] - _attainable;
            _remaining = _remaining - _attainable * nftMin[_index];
            _rewards[_index] = _attainable;
          } else {
            _attainable = nftSupply[_index];
            nftSupply[_index] = 0;
            _remaining = _remaining - _attainable * nftMin[_index];
            _rewards[_index] = _attainable;
          }
        } else {
          break;
        }
      }
    }
    return _rewards;
  }
}


// File: @uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol
pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}


// File: @uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol
pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}


// File: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol
pragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


// File: contracts/interfaces/IFeeSplitter.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

interface IFeeSplitter {
  function nftRewardsVault() external view returns (address);

  function trigRewardsVault() external view returns (address);

  function treasuryVault() external view returns (address);

  function setTreasuryVault(address) external;

  function setTrigFee(uint256) external;

  function setKeeperFee(uint256) external;

  function update() external;
}


// File: contracts/interfaces/INFTRewardsVault.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

interface INFTRewardsVault {
  function update(uint256) external;

  function deposit(uint256, uint256) external;

  function withdraw(uint256, uint256) external;
}


// File: contracts/TRIG.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TRIG is ERC20 {
  uint256 public constant MAX_SUPPLY = 1000 ether;

  constructor(string memory name, string memory symbol)
    public
    ERC20(name, symbol)
  {
    _mint(msg.sender, MAX_SUPPLY);
  }
}


// File: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol
pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}


// File: @openzeppelin/contracts/token/ERC20/ERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../../GSN/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
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
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
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
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}


// File: @openzeppelin/contracts/token/ERC1155/ERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./IERC1155.sol";
import "./IERC1155MetadataURI.sol";
import "./IERC1155Receiver.sol";
import "../../GSN/Context.sol";
import "../../introspection/ERC165.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

/**
 *
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using SafeMath for uint256;
    using Address for address;

    // Mapping from token ID to account balances
    mapping (uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping (address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /*
     *     bytes4(keccak256('balanceOf(address,uint256)')) == 0x00fdd58e
     *     bytes4(keccak256('balanceOfBatch(address[],uint256[])')) == 0x4e1273f4
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,uint256,bytes)')) == 0xf242432a
     *     bytes4(keccak256('safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)')) == 0x2eb2c2d6
     *
     *     => 0x00fdd58e ^ 0x4e1273f4 ^ 0xa22cb465 ^
     *        0xe985e9c5 ^ 0xf242432a ^ 0x2eb2c2d6 == 0xd9b67a26
     */
    bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;

    /*
     *     bytes4(keccak256('uri(uint256)')) == 0x0e89341c
     */
    bytes4 private constant _INTERFACE_ID_ERC1155_METADATA_URI = 0x0e89341c;

    /**
     * @dev See {_setURI}.
     */
    constructor (string memory uri) public {
        _setURI(uri);

        // register the supported interfaces to conform to ERC1155 via ERC165
        _registerInterface(_INTERFACE_ID_ERC1155);

        // register the supported interfaces to conform to ERC1155MetadataURI via ERC165
        _registerInterface(_INTERFACE_ID_ERC1155_METADATA_URI);
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
    function uri(uint256) external view override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
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
    )
        public
        view
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            require(accounts[i] != address(0), "ERC1155: batch balance query for the zero address");
            batchBalances[i] = _balances[ids[i]][accounts[i]];
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(_msgSender() != operator, "ERC1155: setting approval status for self");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        public
        virtual
        override
    {
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

        _balances[id][from] = _balances[id][from].sub(amount, "ERC1155: insufficient balance for transfer");
        _balances[id][to] = _balances[id][to].add(amount);

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        public
        virtual
        override
    {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            _balances[id][from] = _balances[id][from].sub(
                amount,
                "ERC1155: insufficient balance for transfer"
            );
            _balances[id][to] = _balances[id][to].add(amount);
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
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
        _uri = newuri;
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `account`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(address account, uint256 id, uint256 amount, bytes memory data) internal virtual {
        require(account != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), account, _asSingletonArray(id), _asSingletonArray(amount), data);

        _balances[id][account] = _balances[id][account].add(amount);
        emit TransferSingle(operator, address(0), account, id, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), account, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] = amounts[i].add(_balances[ids[i]][to]);
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `account`
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens of token type `id`.
     */
    function _burn(address account, uint256 id, uint256 amount) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

        _balances[id][account] = _balances[id][account].sub(
            amount,
            "ERC1155: burn amount exceeds balance"
        );

        emit TransferSingle(operator, account, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(address account, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

        for (uint i = 0; i < ids.length; i++) {
            _balances[ids[i]][account] = _balances[ids[i]][account].sub(
                amounts[i],
                "ERC1155: burn amount exceeds balance"
            );
        }

        emit TransferBatch(operator, account, address(0), ids, amounts);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal virtual
    { }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        private
    {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver(to).onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
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
    )
        private
    {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
                if (response != IERC1155Receiver(to).onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

import "./IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
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


// File: contracts/FeeERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/IFeeController.sol';
import './interfaces/IFeeSplitter.sol';

contract FeeERC20 is ERC20, Ownable {
  using SafeMath for uint256;

  address public governance;

  address public feeController;

  address public feeSplitter;

  address public lockedLiquidityEvent;

  /// @dev Maximum supply of TDAO
  uint256 public constant MAX_SUPPLY = 5000e18;

  bool private _setupComplete;

  modifier onlyGovernance() {
    require(governance == msg.sender, 'FeeERC20: Caller is not governance.');
    _;
  }

  constructor(string memory _name, string memory _symbol)
    public
    ERC20(_name, _symbol)
  {}

  // @notice Allows governance to set a new treasury address
  // @param _treasury New treasury address to be set
  function setTreasuryVault(address _treasuryVault) external onlyGovernance {
    IFeeSplitter(feeSplitter).setTreasuryVault(_treasuryVault);
  }

  // @notice Sets the percentage of the fee that goes to TRIG holders
  // @param _trigFee It can be between 5000 (50%) and 9000 (90%)
  function setTrigFee(uint256 _trigFee) external onlyGovernance {
    IFeeSplitter(feeSplitter).setTrigFee(_trigFee);
  }

  // @notice Sets the percentage of the fee that goes to the keeper
  // @param _keeperFee Must be below 10 (0.1%)
  function setKeeperFee(uint256 _keeperFee) external onlyGovernance {
    IFeeSplitter(feeSplitter).setKeeperFee(_keeperFee);
  }

  // @notice Sets the percentage of the transfer that will be charged as fee
  // @param _fee It can be between 10 (0.1%) and 1000 (10%)
  function setFee(uint256 _fee) external onlyGovernance {
    IFeeController(feeController).setFee(_fee);
  }

  // @notice Sets addresse that will not be charged fee while sending TDAO
  // @param _address Address of the account that can send TDAO without fees
  // @param _noFee True for no fees
  function editNoFeeList(address _address, bool _noFee)
    external
    onlyGovernance
  {
    IFeeController(feeController).editNoFeeList(_address, _noFee);
  }

  // @notice Sets addresse that will be blocked from sending or receiving TDAO
  // @param _address Address of the account that will be blocked
  // @param _block True if the address should be blocked
  function editBlockList(address _address, bool _block)
    external
    onlyGovernance
  {
    IFeeController(feeController).editBlockList(_address, _block);
  }

  function setLockedLiquidityEvent(address _lockedLiquidityEvent)
    external
    onlyOwner
  {
    require(lockedLiquidityEvent == address(0), 'FeeERC20: LLE already set.');
    lockedLiquidityEvent = _lockedLiquidityEvent;
  }

  function setDependencies(
    address _feeController,
    address _feeSplitter,
    address _governance
  ) external onlyOwner {
    feeController = _feeController;
    feeSplitter = _feeSplitter;
    governance = _governance;
    _mint(lockedLiquidityEvent, MAX_SUPPLY);
    renounceOwnership();
    _setupComplete = true;
  }

  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    _transferWithFee(_msgSender(), recipient, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    _transferWithFee(sender, recipient, amount);
    uint256 _allowance = allowance(sender, _msgSender());
    uint256 _remaining =
      _allowance.sub(amount, 'FeeERC20: transfer amount exceeds allowance');
    _approve(sender, _msgSender(), _remaining);
    return true;
  }

  function _transferWithFee(
    address sender,
    address recipient,
    uint256 amount
  ) internal {
    require(_setupComplete, 'FeeERC20: Must set up dependencies.');

    (uint256 amountMinusFee, uint256 fee) =
      IFeeController(feeController).applyFee(sender, recipient, amount);

    require(
      amountMinusFee.add(fee) == amount,
      'FeeERC20: Fee plus transfer amount should be equal to total amount'
    );

    _transfer(sender, recipient, amountMinusFee);

    if (fee != 0) {
      _transfer(sender, feeSplitter, fee);
    }
  }
}


// File: contracts/interfaces/IFeeController.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

interface IFeeController {
  function isPaused() external view returns (bool);

  function isFeeless(address) external view returns (bool);

  function isBlocked(address) external view returns (bool);

  function setFee(uint256) external;

  function editNoFeeList(address, bool) external;

  function editBlockList(address, bool) external;

  function applyFee(
    address,
    address,
    uint256
  ) external view returns (uint256, uint256);
}


// File: contracts/TDAO.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './FeeERC20.sol';
import './LockedLiquidityEvent.sol';

/// @title Contribute DAO
/// @notice Contribute's Decentralized Autonomous Organization.
/// @author Kento Sadim

/// “Gradually and then suddenly.”

contract TDAO is FeeERC20 {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  /// @dev A record of each accounts delegate
  mapping(address => address) internal _delegates;

  /// @notice A checkpoint for marking number of votes from a given block
  struct Checkpoint {
    uint32 fromBlock;
    uint256 votes;
  }

  /// @notice A record of votes checkpoints for each account, by index
  mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

  /// @notice The number of checkpoints for each account
  mapping(address => uint32) public numCheckpoints;

  /// @notice The EIP-712 typehash for the contract's domain
  bytes32 public constant DOMAIN_TYPEHASH =
    keccak256(
      'EIP712Domain(string name,uint256 chainId,address verifyingContract)'
    );

  /// @notice The EIP-712 typehash for the delegation struct used by the contract
  bytes32 public constant DELEGATION_TYPEHASH =
    keccak256('Delegation(address delegatee,uint256 nonce,uint256 expiry)');

  /// @notice A record of states for signing / validating signatures
  mapping(address => uint256) public nonces;

  /// @notice An event thats emitted when an account changes its delegate
  event DelegateChanged(
    address indexed delegator,
    address indexed fromDelegate,
    address indexed toDelegate
  );

  /// @notice An event thats emitted when a delegate account's vote balance changes
  event DelegateVotesChanged(
    address indexed delegate,
    uint256 previousBalance,
    uint256 newBalance
  );

  constructor(string memory _name, string memory _symbol)
    public
    FeeERC20(_name, _symbol)
  {}

  /**
   * @notice Allows governance to claim any ERC20 token sent to the contract
   * @param erc20 Token address to claim
   * @param recipient Address which will receive the tokens
   */
  function claimERC20(address erc20, address recipient)
    external
    onlyGovernance
  {
    IERC20(erc20).safeTransfer(
      recipient,
      IERC20(erc20).balanceOf(address(this))
    );
  }

  /**
   * @notice Delegate votes from `msg.sender` to `delegatee`
   * @param delegator The address to get delegatee for
   */
  function delegates(address delegator) external view returns (address) {
    return _delegates[delegator];
  }

  /**
   * @notice Delegate votes from `msg.sender` to `delegatee`
   * @param delegatee The address to delegate votes to
   */
  function delegate(address delegatee) external {
    return _delegate(msg.sender, delegatee);
  }

  /**
   * @notice Delegates votes from signatory to `delegatee`
   * @param delegatee The address to delegate votes to
   * @param nonce The contract state required to match the signature
   * @param expiry The time at which to expire the signature
   * @param v The recovery byte of the signature
   * @param r Half of the ECDSA signature pair
   * @param s Half of the ECDSA signature pair
   */
  function delegateBySig(
    address delegatee,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    bytes32 domainSeparator =
      keccak256(
        abi.encode(
          DOMAIN_TYPEHASH,
          keccak256(bytes(name())),
          getChainId(),
          address(this)
        )
      );

    bytes32 structHash =
      keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));

    bytes32 digest =
      keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));

    address signatory = ecrecover(digest, v, r, s);
    require(signatory != address(0), 'DRC::delegateBySig: invalid signature');
    require(nonce == nonces[signatory]++, 'DRC::delegateBySig: invalid nonce');
    require(now <= expiry, 'DRC::delegateBySig: signature expired');
    return _delegate(signatory, delegatee);
  }

  /**
   * @notice Gets the current votes balance for `account`
   * @param account The address to get votes balance
   * @return The number of current votes for `account`
   */
  function getCurrentVotes(address account) external view returns (uint256) {
    uint32 nCheckpoints = numCheckpoints[account];
    return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
  }

  /**
   * @notice Determine the prior number of votes for an account as of a block number
   * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
   * @param account The address of the account to check
   * @param blockNumber The block number to get the vote balance at
   * @return The number of votes the account had as of the given block
   */
  function getPriorVotes(address account, uint256 blockNumber)
    external
    view
    returns (uint256)
  {
    require(
      blockNumber < block.number,
      'DRC::getPriorVotes: not yet determined'
    );

    uint32 nCheckpoints = numCheckpoints[account];
    if (nCheckpoints == 0) {
      return 0;
    }

    // First check most recent balance
    if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
      return checkpoints[account][nCheckpoints - 1].votes;
    }

    // Next check implicit zero balance
    if (checkpoints[account][0].fromBlock > blockNumber) {
      return 0;
    }

    uint32 lower = 0;
    uint32 upper = nCheckpoints - 1;
    while (upper > lower) {
      uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
      Checkpoint memory cp = checkpoints[account][center];
      if (cp.fromBlock == blockNumber) {
        return cp.votes;
      } else if (cp.fromBlock < blockNumber) {
        lower = center;
      } else {
        upper = center - 1;
      }
    }
    return checkpoints[account][lower].votes;
  }

  function _delegate(address delegator, address delegatee) internal {
    address currentDelegate = _delegates[delegator];
    uint256 delegatorBalance = balanceOf(delegator);
    _delegates[delegator] = delegatee;

    emit DelegateChanged(delegator, currentDelegate, delegatee);

    _moveDelegates(currentDelegate, delegatee, delegatorBalance);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    _moveDelegates(_delegates[from], _delegates[to], amount);
  }

  function _moveDelegates(
    address srcRep,
    address dstRep,
    uint256 amount
  ) internal {
    if (srcRep != dstRep && amount > 0) {
      if (srcRep != address(0)) {
        // decrease old representative
        uint32 srcRepNum = numCheckpoints[srcRep];
        uint256 srcRepOld =
          srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
        uint256 srcRepNew = srcRepOld.sub(amount);
        _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
      }

      if (dstRep != address(0)) {
        // increase new representative
        uint32 dstRepNum = numCheckpoints[dstRep];
        uint256 dstRepOld =
          dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
        uint256 dstRepNew = dstRepOld.add(amount);
        _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
      }
    }
  }

  function _writeCheckpoint(
    address delegatee,
    uint32 nCheckpoints,
    uint256 oldVotes,
    uint256 newVotes
  ) internal {
    uint32 blockNumber =
      safe32(
        block.number,
        'DRC::_writeCheckpoint: block number exceeds 32 bits'
      );

    if (
      nCheckpoints > 0 &&
      checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber
    ) {
      checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
    } else {
      checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
      numCheckpoints[delegatee] = nCheckpoints + 1;
    }

    emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
  }

  function safe32(uint256 n, string memory errorMessage)
    internal
    pure
    returns (uint32)
  {
    require(n < 2**32, errorMessage);
    return uint32(n);
  }

  function getChainId() internal pure returns (uint256) {
    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    return chainId;
  }
}


// File: contracts/governance/Guardian.sol
// SPDX-License-Identifier: Copyright 2020 Compound Labs, Inc.

// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Copyright 2020 Compound Labs, Inc.
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

pragma solidity >=0.5.0 <0.7.0;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../TDAO.sol';

contract Guardian {
  using SafeMath for uint256;

  /// @notice The name of this contract
  string public constant name = 'Governor Guardian';

  /// @notice The address of the Contribute Protocol Timelock
  TimelockInterface public timelock;

  /// @notice The address of the Contribute governance token
  TDAO public tdao;

  /// @notice The address of the Governor Guardian
  address public guardian;

  /// @notice The total number of proposals
  uint256 public proposalCount;

  struct Proposal {
    // Unique id for looking up a proposal
    uint256 id;
    // Creator of the proposal
    address proposer;
    // The timestamp that the proposal will be available for execution, set once the vote succeeds
    uint256 eta;
    // the ordered list of target addresses for calls to be made
    address[] targets;
    // The ordered list of values (i.e. msg.value) to be passed to the calls to be made
    uint256[] values;
    // The ordered list of function signatures to be called
    string[] signatures;
    // The ordered list of calldata to be passed to each call
    bytes[] calldatas;
    // The block at which voting begins: holders must delegate their votes prior to this block
    uint256 startBlock;
    // The block at which voting ends: votes must be cast prior to this block
    uint256 endBlock;
    // Current number of votes in favor of this proposal
    uint256 forVotes;
    // Current number of votes in opposition to this proposal
    uint256 againstVotes;
    // Flag marking whether the proposal has been canceled
    bool canceled;
    // Flag marking whether the proposal has been executed
    bool executed;
    // Receipts of ballots for the entire set of voters
    mapping(address => Receipt) receipts;
  }

  /// @notice Ballot receipt record for a voter
  struct Receipt {
    // Whether or not a vote has been cast
    bool hasVoted;
    // Whether or not the voter supports the proposal
    bool support;
    // The number of votes the voter had, which were cast
    uint256 votes;
  }

  /// @notice Possible states that a proposal may be in
  enum ProposalState {
    Pending,
    Active,
    Canceled,
    Defeated,
    Succeeded,
    Queued,
    Expired,
    Executed
  }

  /// @notice The official record of all proposals ever proposed
  mapping(uint256 => Proposal) public proposals;

  /// @notice The latest proposal for each proposer
  mapping(address => uint256) public latestProposalIds;

  /// @notice The EIP-712 typehash for the contract's domain
  bytes32 public constant DOMAIN_TYPEHASH =
    keccak256(
      'EIP712Domain(string name,uint256 chainId,address verifyingContract)'
    );

  /// @notice The EIP-712 typehash for the ballot struct used by the contract
  bytes32 public constant BALLOT_TYPEHASH =
    keccak256('Ballot(uint256 proposalId,bool support)');

  /// @notice An event emitted when a new proposal is created
  event ProposalCreated(
    uint256 id,
    address proposer,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 startBlock,
    uint256 endBlock,
    string description
  );

  /// @notice An event emitted when a vote has been cast on a proposal
  event VoteCast(
    address voter,
    uint256 proposalId,
    bool support,
    uint256 votes
  );

  /// @notice An event emitted when a proposal has been canceled
  event ProposalCanceled(uint256 id);

  /// @notice An event emitted when a proposal has been queued in the Timelock
  event ProposalQueued(uint256 id, uint256 eta);

  /// @notice An event emitted when a proposal has been executed in the Timelock
  event ProposalExecuted(uint256 id);

  constructor(
    address timelock_,
    address token_,
    address guardian_
  ) public {
    timelock = TimelockInterface(timelock_);
    tdao = TDAO(token_);
    guardian = guardian_;
  }

  /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
  function quorumVotes() public view returns (uint256) {
    return tdao.totalSupply().div(5);
  } // 20% of the total supply

  /// @notice The number of votes required in order for a voter to become a proposer
  function proposalThreshold() public view returns (uint256) {
    return tdao.totalSupply().div(100);
  } // 1% of the total supply

  /// @notice The maximum number of actions that can be included in a proposal
  function proposalMaxOperations() public pure returns (uint256) {
    return 10;
  } // 10 actions

  /// @notice The delay before voting on a proposal may take place, once proposed
  function votingDelay() public pure returns (uint256) {
    return 1;
  } // 1 block

  /// @notice The duration of voting on a proposal, in blocks
  function votingPeriod() public pure returns (uint256) {
    return 11520;
  } // ~2 days in blocks (assuming 15s blocks)

  function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
  ) public returns (uint256) {
    require(
      tdao.getPriorVotes(msg.sender, block.number.sub(1)) > proposalThreshold(),
      'Guardian::propose: proposer votes below proposal threshold'
    );
    require(
      targets.length == values.length &&
        targets.length == signatures.length &&
        targets.length == calldatas.length,
      'Guardian::propose: proposal function information arity mismatch'
    );
    require(targets.length != 0, 'Guardian::propose: must provide actions');
    require(
      targets.length <= proposalMaxOperations(),
      'Guardian::propose: too many actions'
    );

    uint256 latestProposalId = latestProposalIds[msg.sender];
    if (latestProposalId != 0) {
      ProposalState proposersLatestProposalState = state(latestProposalId);
      require(
        proposersLatestProposalState != ProposalState.Active,
        'Guardian::propose: one live proposal per proposer, found an already active proposal'
      );
      require(
        proposersLatestProposalState != ProposalState.Pending,
        'Guardian::propose: one live proposal per proposer, found an already pending proposal'
      );
    }

    uint256 startBlock = block.number.add(votingDelay());
    uint256 endBlock = startBlock.add(votingPeriod());

    proposalCount++;
    Proposal memory newProposal =
      Proposal({
        id: proposalCount,
        proposer: msg.sender,
        eta: 0,
        targets: targets,
        values: values,
        signatures: signatures,
        calldatas: calldatas,
        startBlock: startBlock,
        endBlock: endBlock,
        forVotes: 0,
        againstVotes: 0,
        canceled: false,
        executed: false
      });

    proposals[newProposal.id] = newProposal;
    latestProposalIds[newProposal.proposer] = newProposal.id;

    emit ProposalCreated(
      newProposal.id,
      msg.sender,
      targets,
      values,
      signatures,
      calldatas,
      startBlock,
      endBlock,
      description
    );
    return newProposal.id;
  }

  function queue(uint256 proposalId) public {
    require(
      state(proposalId) == ProposalState.Succeeded,
      'Guardian::queue: proposal can only be queued if it is succeeded'
    );
    Proposal storage proposal = proposals[proposalId];
    uint256 eta = block.timestamp.add(timelock.delay());
    for (uint256 i = 0; i < proposal.targets.length; i++) {
      _queueOrRevert(
        proposal.targets[i],
        proposal.values[i],
        proposal.signatures[i],
        proposal.calldatas[i],
        eta
      );
    }
    proposal.eta = eta;
    emit ProposalQueued(proposalId, eta);
  }

  function _queueOrRevert(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) internal {
    require(
      !timelock.queuedTransactions(
        keccak256(abi.encode(target, value, signature, data, eta))
      ),
      'Guardian::_queueOrRevert: proposal action already queued at eta'
    );
    timelock.queueTransaction(target, value, signature, data, eta);
  }

  function execute(uint256 proposalId) public payable {
    require(
      state(proposalId) == ProposalState.Queued,
      'Guardian::execute: proposal can only be executed if it is queued'
    );
    Proposal storage proposal = proposals[proposalId];
    proposal.executed = true;
    for (uint256 i = 0; i < proposal.targets.length; i++) {
      timelock.executeTransaction{value: proposal.values[i]}(
        proposal.targets[i],
        proposal.values[i],
        proposal.signatures[i],
        proposal.calldatas[i],
        proposal.eta
      );
    }
    emit ProposalExecuted(proposalId);
  }

  function cancel(uint256 proposalId) public {
    ProposalState state = state(proposalId);
    require(
      state != ProposalState.Executed,
      'Guardian::cancel: cannot cancel executed proposal'
    );

    Proposal storage proposal = proposals[proposalId];
    require(
      msg.sender == guardian ||
        tdao.getPriorVotes(proposal.proposer, block.number.sub(1)) <
        proposalThreshold(),
      'Guardian::cancel: proposer above threshold'
    );

    proposal.canceled = true;
    for (uint256 i = 0; i < proposal.targets.length; i++) {
      timelock.cancelTransaction(
        proposal.targets[i],
        proposal.values[i],
        proposal.signatures[i],
        proposal.calldatas[i],
        proposal.eta
      );
    }

    emit ProposalCanceled(proposalId);
  }

  function getActions(uint256 proposalId)
    public
    view
    returns (
      address[] memory targets,
      uint256[] memory values,
      string[] memory signatures,
      bytes[] memory calldatas
    )
  {
    Proposal storage p = proposals[proposalId];
    return (p.targets, p.values, p.signatures, p.calldatas);
  }

  function getReceipt(uint256 proposalId, address voter)
    public
    view
    returns (Receipt memory)
  {
    return proposals[proposalId].receipts[voter];
  }

  function state(uint256 proposalId) public view returns (ProposalState) {
    require(
      proposalCount >= proposalId && proposalId > 0,
      'Guardian::state: invalid proposal id'
    );
    Proposal storage proposal = proposals[proposalId];
    if (proposal.canceled) {
      return ProposalState.Canceled;
    } else if (block.number <= proposal.startBlock) {
      return ProposalState.Pending;
    } else if (block.number <= proposal.endBlock) {
      return ProposalState.Active;
    } else if (
      proposal.forVotes <= proposal.againstVotes ||
      proposal.forVotes < quorumVotes()
    ) {
      return ProposalState.Defeated;
    } else if (proposal.eta == 0) {
      return ProposalState.Succeeded;
    } else if (proposal.executed) {
      return ProposalState.Executed;
    } else if (block.timestamp >= proposal.eta.add(timelock.GRACE_PERIOD())) {
      return ProposalState.Expired;
    } else {
      return ProposalState.Queued;
    }
  }

  function castVote(uint256 proposalId, bool support) public {
    return _castVote(msg.sender, proposalId, support);
  }

  function castVoteBySig(
    uint256 proposalId,
    bool support,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public {
    bytes32 domainSeparator =
      keccak256(
        abi.encode(
          DOMAIN_TYPEHASH,
          keccak256(bytes(name)),
          getChainId(),
          address(this)
        )
      );
    bytes32 structHash =
      keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
    bytes32 digest =
      keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
    address signatory = ecrecover(digest, v, r, s);
    require(
      signatory != address(0),
      'Guardian::castVoteBySig: invalid signature'
    );
    return _castVote(signatory, proposalId, support);
  }

  function _castVote(
    address voter,
    uint256 proposalId,
    bool support
  ) internal {
    require(
      state(proposalId) == ProposalState.Active,
      'Guardian::_castVote: voting is closed'
    );
    Proposal storage proposal = proposals[proposalId];
    Receipt storage receipt = proposal.receipts[voter];
    require(
      receipt.hasVoted == false,
      'Guardian::_castVote: voter already voted'
    );
    uint256 votes = tdao.getPriorVotes(voter, proposal.startBlock);

    if (support) {
      proposal.forVotes = proposal.forVotes.add(votes);
    } else {
      proposal.againstVotes = proposal.againstVotes.add(votes);
    }

    receipt.hasVoted = true;
    receipt.support = support;
    receipt.votes = votes;

    emit VoteCast(voter, proposalId, support, votes);
  }

  function __acceptAdmin() public {
    require(
      msg.sender == guardian,
      'Guardian::__acceptAdmin: sender must be gov guardian'
    );
    timelock.acceptAdmin();
  }

  function __abdicate() public {
    require(
      msg.sender == guardian,
      'Guardian::__abdicate: sender must be gov guardian'
    );
    guardian = address(0);
  }

  function __queueSetTimelockPendingAdmin(address newPendingAdmin, uint256 eta)
    public
  {
    require(
      msg.sender == guardian,
      'Guardian::__queueSetTimelockPendingAdmin: sender must be gov guardian'
    );
    timelock.queueTransaction(
      address(timelock),
      0,
      'setPendingAdmin(address)',
      abi.encode(newPendingAdmin),
      eta
    );
  }

  function __executeSetTimelockPendingAdmin(
    address newPendingAdmin,
    uint256 eta
  ) public {
    require(
      msg.sender == guardian,
      'Guardian::__executeSetTimelockPendingAdmin: sender must be gov guardian'
    );
    timelock.executeTransaction(
      address(timelock),
      0,
      'setPendingAdmin(address)',
      abi.encode(newPendingAdmin),
      eta
    );
  }

  function getChainId() internal pure returns (uint256) {
    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    return chainId;
  }
}

interface TimelockInterface {
  function delay() external view returns (uint256);

  function GRACE_PERIOD() external view returns (uint256);

  function acceptAdmin() external;

  function queuedTransactions(bytes32 hash) external view returns (bool);

  function queueTransaction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
  ) external returns (bytes32);

  function cancelTransaction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
  ) external;

  function executeTransaction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
  ) external payable returns (bytes memory);
}


// File: contracts/governance/Governor.sol
// SPDX-License-Identifier: Copyright 2020 Compound Labs, Inc.

// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Copyright 2020 Compound Labs, Inc.
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

pragma solidity >=0.5.0 <0.7.0;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../TDAO.sol';
import '../LockedLiquidityEvent.sol';

contract Governor {
  using SafeMath for uint256;

  /// @notice The name of this contract
  string public constant name = 'Contribute Governor';

  /// @notice The address of the Contribute Protocol Timelock
  TimelockInterface public timelock;

  /// @notice The address of the Contribute governance token
  TDAO public tdao;

  /// @notice The address of the Governor Guardian
  address public guardian;

  /// @notice The total number of proposals
  uint256 public proposalCount;

  uint256 public timeDeployed;

  uint256 public gracePeriod = 30 days;

  struct Proposal {
    // Unique id for looking up a proposal
    uint256 id;
    // Creator of the proposal
    address proposer;
    // The timestamp that the proposal will be available for execution, set once the vote succeeds
    uint256 eta;
    // the ordered list of target addresses for calls to be made
    address[] targets;
    // The ordered list of values (i.e. msg.value) to be passed to the calls to be made
    uint256[] values;
    // The ordered list of function signatures to be called
    string[] signatures;
    // The ordered list of calldata to be passed to each call
    bytes[] calldatas;
    // The block at which voting begins: holders must delegate their votes prior to this block
    uint256 startBlock;
    // The block at which voting ends: votes must be cast prior to this block
    uint256 endBlock;
    // Current number of votes in favor of this proposal
    uint256 forVotes;
    // Current number of votes in opposition to this proposal
    uint256 againstVotes;
    // Flag marking whether the proposal has been canceled
    bool canceled;
    // Flag marking whether the proposal has been executed
    bool executed;
    // Receipts of ballots for the entire set of voters
    mapping(address => Receipt) receipts;
  }

  /// @notice Ballot receipt record for a voter
  struct Receipt {
    // Whether or not a vote has been cast
    bool hasVoted;
    // Whether or not the voter supports the proposal
    bool support;
    // The number of votes the voter had, which were cast
    uint256 votes;
  }

  /// @notice Possible states that a proposal may be in
  enum ProposalState {
    Pending,
    Active,
    Canceled,
    Defeated,
    Succeeded,
    Queued,
    Expired,
    Executed
  }

  /// @notice The official record of all proposals ever proposed
  mapping(uint256 => Proposal) public proposals;

  /// @notice The latest proposal for each proposer
  mapping(address => uint256) public latestProposalIds;

  /// @notice The EIP-712 typehash for the contract's domain
  bytes32 public constant DOMAIN_TYPEHASH =
    keccak256(
      'EIP712Domain(string name,uint256 chainId,address verifyingContract)'
    );

  /// @notice The EIP-712 typehash for the ballot struct used by the contract
  bytes32 public constant BALLOT_TYPEHASH =
    keccak256('Ballot(uint256 proposalId,bool support)');

  /// @notice An event emitted when a new proposal is created
  event ProposalCreated(
    uint256 id,
    address proposer,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 startBlock,
    uint256 endBlock,
    string description
  );

  /// @notice An event emitted when a vote has been cast on a proposal
  event VoteCast(
    address voter,
    uint256 proposalId,
    bool support,
    uint256 votes
  );

  /// @notice An event emitted when a proposal has been canceled
  event ProposalCanceled(uint256 id);

  /// @notice An event emitted when a proposal has been queued in the Timelock
  event ProposalQueued(uint256 id, uint256 eta);

  /// @notice An event emitted when a proposal has been executed in the Timelock
  event ProposalExecuted(uint256 id);

  modifier gracePeriodCheck() {
    address pair =
      LockedLiquidityEvent(tdao.lockedLiquidityEvent()).tokenUniswapPair();

    require(
      tdao.balanceOf(pair) < tdao.totalSupply().mul(3).div(4) ||
        block.timestamp > timeDeployed.add(gracePeriod) ||
        proposalCount != 0,
      'Governor::gracePeriodCheck: Minimum amount of tokens in circulation has not been met'
    );
    _;
  }

  constructor(
    address timelock_,
    address token_,
    address guardian_
  ) public {
    timelock = TimelockInterface(timelock_);
    tdao = TDAO(token_);
    guardian = guardian_;
    timeDeployed = block.timestamp;
  }

  /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
  function quorumVotes() public view returns (uint256) {
    return tdao.totalSupply().div(20);
  } // 5% of the total supply

  /// @notice The number of votes required in order for a voter to become a proposer
  function proposalThreshold() public view returns (uint256) {
    return tdao.totalSupply().div(100);
  } // 1% of the total supply

  /// @notice The maximum number of actions that can be included in a proposal
  function proposalMaxOperations() public pure returns (uint256) {
    return 10;
  } // 10 actions

  /// @notice The delay before voting on a proposal may take place, once proposed
  function votingDelay() public pure returns (uint256) {
    return 1;
  } // 1 block

  /// @notice The duration of voting on a proposal, in blocks
  function votingPeriod() public pure returns (uint256) {
    return 17280;
  } // ~3 days in blocks (assuming 15s blocks)

  function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
  ) public gracePeriodCheck returns (uint256) {
    require(
      tdao.getPriorVotes(msg.sender, block.number.sub(1)) > proposalThreshold(),
      'Governor::propose: proposer votes below proposal threshold'
    );
    require(
      targets.length == values.length &&
        targets.length == signatures.length &&
        targets.length == calldatas.length,
      'Governor::propose: proposal function information arity mismatch'
    );
    require(targets.length != 0, 'Governor::propose: must provide actions');
    require(
      targets.length <= proposalMaxOperations(),
      'Governor::propose: too many actions'
    );

    uint256 latestProposalId = latestProposalIds[msg.sender];
    if (latestProposalId != 0) {
      ProposalState proposersLatestProposalState = state(latestProposalId);
      require(
        proposersLatestProposalState != ProposalState.Active,
        'Governor::propose: one live proposal per proposer, found an already active proposal'
      );
      require(
        proposersLatestProposalState != ProposalState.Pending,
        'Governor::propose: one live proposal per proposer, found an already pending proposal'
      );
    }

    uint256 startBlock = block.number.add(votingDelay());
    uint256 endBlock = startBlock.add(votingPeriod());

    proposalCount++;
    Proposal memory newProposal =
      Proposal({
        id: proposalCount,
        proposer: msg.sender,
        eta: 0,
        targets: targets,
        values: values,
        signatures: signatures,
        calldatas: calldatas,
        startBlock: startBlock,
        endBlock: endBlock,
        forVotes: 0,
        againstVotes: 0,
        canceled: false,
        executed: false
      });

    proposals[newProposal.id] = newProposal;
    latestProposalIds[newProposal.proposer] = newProposal.id;

    emit ProposalCreated(
      newProposal.id,
      msg.sender,
      targets,
      values,
      signatures,
      calldatas,
      startBlock,
      endBlock,
      description
    );
    return newProposal.id;
  }

  function queue(uint256 proposalId) public {
    require(
      state(proposalId) == ProposalState.Succeeded,
      'Governor::queue: proposal can only be queued if it is succeeded'
    );
    Proposal storage proposal = proposals[proposalId];
    uint256 eta = block.timestamp.add(timelock.delay());
    for (uint256 i = 0; i < proposal.targets.length; i++) {
      _queueOrRevert(
        proposal.targets[i],
        proposal.values[i],
        proposal.signatures[i],
        proposal.calldatas[i],
        eta
      );
    }
    proposal.eta = eta;
    emit ProposalQueued(proposalId, eta);
  }

  function _queueOrRevert(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) internal {
    require(
      !timelock.queuedTransactions(
        keccak256(abi.encode(target, value, signature, data, eta))
      ),
      'Governor::_queueOrRevert: proposal action already queued at eta'
    );
    timelock.queueTransaction(target, value, signature, data, eta);
  }

  function execute(uint256 proposalId) public payable {
    require(
      state(proposalId) == ProposalState.Queued,
      'Governor::execute: proposal can only be executed if it is queued'
    );
    Proposal storage proposal = proposals[proposalId];
    proposal.executed = true;
    for (uint256 i = 0; i < proposal.targets.length; i++) {
      timelock.executeTransaction{value: proposal.values[i]}(
        proposal.targets[i],
        proposal.values[i],
        proposal.signatures[i],
        proposal.calldatas[i],
        proposal.eta
      );
    }
    emit ProposalExecuted(proposalId);
  }

  function cancel(uint256 proposalId) public {
    ProposalState state = state(proposalId);
    require(
      state != ProposalState.Executed,
      'Governor::cancel: cannot cancel executed proposal'
    );

    Proposal storage proposal = proposals[proposalId];
    require(
      msg.sender == guardian ||
        tdao.getPriorVotes(proposal.proposer, block.number.sub(1)) <
        proposalThreshold(),
      'Governor::cancel: proposer above threshold'
    );

    proposal.canceled = true;
    for (uint256 i = 0; i < proposal.targets.length; i++) {
      timelock.cancelTransaction(
        proposal.targets[i],
        proposal.values[i],
        proposal.signatures[i],
        proposal.calldatas[i],
        proposal.eta
      );
    }

    emit ProposalCanceled(proposalId);
  }

  function getActions(uint256 proposalId)
    public
    view
    returns (
      address[] memory targets,
      uint256[] memory values,
      string[] memory signatures,
      bytes[] memory calldatas
    )
  {
    Proposal storage p = proposals[proposalId];
    return (p.targets, p.values, p.signatures, p.calldatas);
  }

  function getReceipt(uint256 proposalId, address voter)
    public
    view
    returns (Receipt memory)
  {
    return proposals[proposalId].receipts[voter];
  }

  function state(uint256 proposalId) public view returns (ProposalState) {
    require(
      proposalCount >= proposalId && proposalId > 0,
      'Governor::state: invalid proposal id'
    );
    Proposal storage proposal = proposals[proposalId];
    if (proposal.canceled) {
      return ProposalState.Canceled;
    } else if (block.number <= proposal.startBlock) {
      return ProposalState.Pending;
    } else if (block.number <= proposal.endBlock) {
      return ProposalState.Active;
    } else if (
      proposal.forVotes <= proposal.againstVotes ||
      proposal.forVotes < quorumVotes()
    ) {
      return ProposalState.Defeated;
    } else if (proposal.eta == 0) {
      return ProposalState.Succeeded;
    } else if (proposal.executed) {
      return ProposalState.Executed;
    } else if (block.timestamp >= proposal.eta.add(timelock.GRACE_PERIOD())) {
      return ProposalState.Expired;
    } else {
      return ProposalState.Queued;
    }
  }

  function castVote(uint256 proposalId, bool support) public {
    return _castVote(msg.sender, proposalId, support);
  }

  function castVoteBySig(
    uint256 proposalId,
    bool support,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public {
    bytes32 domainSeparator =
      keccak256(
        abi.encode(
          DOMAIN_TYPEHASH,
          keccak256(bytes(name)),
          getChainId(),
          address(this)
        )
      );
    bytes32 structHash =
      keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
    bytes32 digest =
      keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
    address signatory = ecrecover(digest, v, r, s);
    require(
      signatory != address(0),
      'Governor::castVoteBySig: invalid signature'
    );
    return _castVote(signatory, proposalId, support);
  }

  function _castVote(
    address voter,
    uint256 proposalId,
    bool support
  ) internal {
    require(
      state(proposalId) == ProposalState.Active,
      'Governor::_castVote: voting is closed'
    );
    Proposal storage proposal = proposals[proposalId];
    Receipt storage receipt = proposal.receipts[voter];
    require(
      receipt.hasVoted == false,
      'Governor::_castVote: voter already voted'
    );
    uint256 votes = tdao.getPriorVotes(voter, proposal.startBlock);

    if (support) {
      proposal.forVotes = proposal.forVotes.add(votes);
    } else {
      proposal.againstVotes = proposal.againstVotes.add(votes);
    }

    receipt.hasVoted = true;
    receipt.support = support;
    receipt.votes = votes;

    emit VoteCast(voter, proposalId, support, votes);
  }

  function __acceptAdmin() public {
    require(
      msg.sender == guardian,
      'Governor::__acceptAdmin: sender must be gov guardian'
    );
    timelock.acceptAdmin();
  }

  function __transferGuardianship(address newGuardian) public {
    require(
      msg.sender == guardian,
      'Governor::__transferGuardianship: sender must be gov guardian'
    );
    guardian = newGuardian;
  }

  function __abdicate() public {
    require(
      msg.sender == guardian,
      'Governor::__abdicate: sender must be gov guardian'
    );
    guardian = address(0);
  }

  function __queueSetTimelockPendingAdmin(address newPendingAdmin, uint256 eta)
    public
  {
    require(
      msg.sender == guardian,
      'Governor::__queueSetTimelockPendingAdmin: sender must be gov guardian'
    );
    timelock.queueTransaction(
      address(timelock),
      0,
      'setPendingAdmin(address)',
      abi.encode(newPendingAdmin),
      eta
    );
  }

  function __executeSetTimelockPendingAdmin(
    address newPendingAdmin,
    uint256 eta
  ) public {
    require(
      msg.sender == guardian,
      'Governor::__executeSetTimelockPendingAdmin: sender must be gov guardian'
    );
    timelock.executeTransaction(
      address(timelock),
      0,
      'setPendingAdmin(address)',
      abi.encode(newPendingAdmin),
      eta
    );
  }

  function getChainId() internal pure returns (uint256) {
    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    return chainId;
  }
}

interface TimelockInterface {
  function delay() external view returns (uint256);

  function GRACE_PERIOD() external view returns (uint256);

  function acceptAdmin() external;

  function queuedTransactions(bytes32 hash) external view returns (bool);

  function queueTransaction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
  ) external returns (bytes32);

  function cancelTransaction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
  ) external;

  function executeTransaction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
  ) external payable returns (bytes memory);
}


// File: contracts/FeeSplitter.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './interfaces/ILockedLiquidityEvent.sol';
import './interfaces/ITDAO.sol';
import './interfaces/IVault.sol';

contract FeeSplitter {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event HodlerMadeWhole(address indexed account, uint256 amount);
  event TrigRewardDistributed(uint256 amount);
  event NFTRewardDistributed(uint256 amount);
  event TreasuryDeposit(uint256 amount);

  address public tdao;
  address public nftRewardsVault;
  address public trigRewardsVault;
  address public treasuryVault;

  uint256 public interval = 30 days;
  uint256 public trigFee = 5000;
  uint256 public keeperFee = 10;
  uint256 public constant BASE = 10000;
  uint256 public hodlerRequiredAmount = 1 ether;

  uint256[5] public timestamps;
  uint256[5] public treasuryFees = [9000, 9200, 9400, 9600, 9800];

  modifier onlyHodler() {
    require(
      IERC20(tdao).balanceOf(msg.sender) >= hodlerRequiredAmount,
      'FeeSplitter: You must have at least 1 TDAO to call this function.'
    );
    _;
  }

  modifier onlyTDAO() {
    require(msg.sender == tdao, 'FeeSplitter: Function call not allowed.');
    _;
  }

  constructor(
    address _tdao,
    address _trigRewardsVault,
    address _nftRewardsVault,
    address _treasuryAddress
  ) public {
    tdao = _tdao;
    trigRewardsVault = _trigRewardsVault;
    nftRewardsVault = _nftRewardsVault;
    treasuryVault = _treasuryAddress;

    timestamps = _setTimestamps(
      ILockedLiquidityEvent(ITDAO(tdao).lockedLiquidityEvent())
        .startTradingTime()
    );
  }

  function update() external onlyHodler {
    uint256 amount = IERC20(tdao).balanceOf(address(this));

    if (amount < BASE) {
      return;
    }

    uint256 keeperShare = amount.mul(keeperFee).div(BASE);
    uint256 discounted = amount.sub(keeperShare);

    uint256 trigShare = discounted.mul(trigFee).div(BASE);
    uint256 remaining = discounted.sub(trigShare);
    (uint256 nftRewardsShare, uint256 treasuryShare) =
      _splitRemainingFees(remaining);

    IERC20(tdao).safeTransfer(msg.sender, keeperShare);
    IERC20(tdao).safeTransfer(trigRewardsVault, trigShare);
    IERC20(tdao).safeTransfer(nftRewardsVault, nftRewardsShare);
    IERC20(tdao).safeTransfer(treasuryVault, treasuryShare);

    IVault(trigRewardsVault).update(trigShare);
    IVault(nftRewardsVault).update(nftRewardsShare);
    IVault(treasuryVault).update(treasuryShare);

    emit HodlerMadeWhole(msg.sender, keeperShare);
    emit TrigRewardDistributed(trigShare);
    emit NFTRewardDistributed(nftRewardsShare);
    emit TreasuryDeposit(treasuryShare);
  }

  function setTreasuryVault(address _treasuryVault) external onlyTDAO {
    require(
      _treasuryVault != address(0),
      'FeeSplitter: Treasury must be set to a valid address.'
    );
    treasuryVault = _treasuryVault;
  }

  function setTrigFee(uint256 _trigFee) external onlyTDAO {
    require(
      _trigFee >= 5000 && _trigFee <= 9000,
      'FeeSplitter: Trig fee out of bounds.'
    );
    trigFee = _trigFee;
  }

  function setKeeperFee(uint256 _keeperFee) external onlyTDAO {
    require(_keeperFee <= 10, 'FeeSplitter: Keeper fee is out of bounds.');
    keeperFee = _keeperFee;
  }

  function keeperReward() external view returns (uint256 reward) {
    reward = IERC20(tdao).balanceOf(address(this)).mul(keeperFee).div(BASE);
  }

  function _splitRemainingFees(uint256 _amount)
    internal
    view
    returns (uint256 _nftRewardsAllocation, uint256 _treasuryAllocation)
  {
    uint256 _now = block.timestamp;

    for (uint8 i = uint8(timestamps.length.sub(1)); i >= 0; i--) {
      if (_now > timestamps[i]) {
        _treasuryAllocation = _amount.mul(treasuryFees[i]).div(BASE);
        _nftRewardsAllocation = _amount.sub(_treasuryAllocation);
        break;
      }
    }
  }

  function _setTimestamps(uint256 _startTime)
    internal
    view
    returns (uint256[5] memory)
  {
    uint256[5] memory _timestamps;
    for (uint8 i = 0; i < 5; i++) {
      _timestamps[i] = _startTime.add(interval.mul(i));
    }
    return _timestamps;
  }
}


// File: contracts/FeeController.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import './libraries/UniswapV2Library.sol';

import './interfaces/IFeeSplitter.sol';
import './interfaces/ILockedLiquidityEvent.sol';
import './interfaces/ITDAO.sol';

contract FeeController {
  using SafeMath for uint256;

  address public pairWETH;
  address public pairWBTC;
  address public pairUSDC;
  address public pairMUSD;
  address public pairTRI;
  address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
  address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public MUSD = 0xe2f2a5C287993345a840Db3B0845fbC70f5935a5;
  address public TRI = 0xc299004a310303D1C0005Cb14c70ccC02863924d;

  address public pair;
  address public tdao;
  address public feeSplitter;
  address public lle;

  uint256 public fee = 100; // max 1000 = 10% artificial clamp
  uint256 public constant BASE = 10000; // fee/base => 100/10000 => 0.01 => 1.0%

  mapping(address => bool) private _noFeeList;
  mapping(address => bool) private _blockList;

  modifier onlyTDAO() {
    require(msg.sender == tdao, 'FeeController: Function call not allowed.');
    _;
  }

  constructor(
    address _tdao,
    address _addressTokenB,
    address _addressFactory,
    address _feeSplitter
  ) public {
    tdao = _tdao;
    pair = IUniswapV2Factory(_addressFactory).getPair(_addressTokenB, tdao);
    feeSplitter = _feeSplitter;
    lle = address(ITDAO(tdao).lockedLiquidityEvent());
    require(
      lle != address(0),
      'FeeController: Must first deploy and set LockedLiquidityEvent'
    );

    pairWETH = UniswapV2Library.pairFor(_addressFactory, WETH, tdao);
    pairWBTC = UniswapV2Library.pairFor(_addressFactory, WBTC, tdao);
    pairUSDC = UniswapV2Library.pairFor(_addressFactory, USDC, tdao);
    pairMUSD = UniswapV2Library.pairFor(_addressFactory, MUSD, tdao);
    pairTRI = UniswapV2Library.pairFor(_addressFactory, TRI, tdao);

    _editNoFeeList(pairWETH, true);
    _editNoFeeList(pairWBTC, true);
    _editNoFeeList(pairUSDC, true);
    _editNoFeeList(pairMUSD, true);
    _editNoFeeList(pairTRI, true);
    _editNoFeeList(pair, true);

    _editNoFeeList(lle, true);
    _editNoFeeList(feeSplitter, true);
    _editNoFeeList(_treasuryVault(), true);

    _editNoFeeList(IFeeSplitter(feeSplitter).nftRewardsVault(), true);
    _editNoFeeList(IFeeSplitter(feeSplitter).trigRewardsVault(), true);
  }

  function isPaused() external view returns (bool) {
    return _isPaused();
  }

  function isFeeless(address account) external view returns (bool) {
    return _noFeeList[account];
  }

  function isBlocked(address account) external view returns (bool) {
    return _blockList[account];
  }

  function setFee(uint256 _fee) external onlyTDAO {
    require(
      _fee >= 10 && _fee <= 1000,
      'FeeController: Fee must be in between 10 and 1000'
    );
    fee = _fee;
  }

  function editNoFeeList(address _address, bool _noFee) external onlyTDAO {
    require(
      _address != feeSplitter,
      'FeeController: Cannot charge fees to fee splitter.'
    );
    require(
      _address != _treasuryVault(),
      'FeeController: Cannot charge fees to treasury.'
    );
    require(
      _address != IFeeSplitter(feeSplitter).nftRewardsVault(),
      'FeeController: Cannot charge fees to NFT reward vault.'
    );
    require(
      _address != IFeeSplitter(feeSplitter).trigRewardsVault(),
      'FeeController: Cannot charge fees to Trig reward vault.'
    );

    _editNoFeeList(_address, _noFee);
  }

  function editBlockList(address _address, bool _block) external onlyTDAO {
    require(_address != pair, 'FeeController: Cannot block main Uniswap pair.');
    require(
      _address != _treasuryVault(),
      'FeeController: Cannot block treasury.'
    );
    require(
      _address != feeSplitter,
      'FeeController: Cannot block fee splitter.'
    );
    require(
      _address != IFeeSplitter(feeSplitter).nftRewardsVault(),
      'FeeController: Cannot block NFT reward vault.'
    );
    require(
      _address != IFeeSplitter(feeSplitter).trigRewardsVault(),
      'FeeController: Cannot block Trig reward vault.'
    );

    _editBlockList(_address, _block);
  }

  function applyFee(
    address sender,
    address recipient,
    uint256 amount
  )
    external
    view
    returns (uint256 transferToRecipientAmount, uint256 transferToFeeAmount)
  {
    require(!_blockList[sender], 'FeeController: Sender account is blocked.');
    require(
      !_blockList[recipient],
      'FeeController: Recipient account is blocked.'
    );

    if (recipient != pair) {
      require(!_isPaused(), 'FeeController: Trading has not started.');
    }

    if (_noFeeList[sender]) {
      // Do not charge a fee when vault is sending. Avoid infinite loop.
      // Do not charge a fee when pair is sending. No fees on buy.
      transferToFeeAmount = 0;
      transferToRecipientAmount = amount;
    } else {
      transferToFeeAmount = amount.mul(fee).div(BASE);
      transferToRecipientAmount = amount.sub(transferToFeeAmount);
    }
  }

  function _treasuryVault() internal view returns (address) {
    return IFeeSplitter(feeSplitter).treasuryVault();
  }

  function _isPaused() internal view returns (bool) {
    return block.timestamp < ILockedLiquidityEvent(lle).startTradingTime();
  }

  function _editNoFeeList(address _address, bool _noFee) internal {
    _noFeeList[_address] = _noFee;
  }

  function _editBlockList(address _address, bool _block) internal {
    _blockList[_address] = _block;
  }
}


// File: contracts/libraries/UniswapV2Library.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

library UniswapV2Library {
  using SafeMath for uint256;

  // returns sorted token addresses, used to handle return values from pairs sorted in this order
  function sortTokens(address tokenA, address tokenB)
    internal
    pure
    returns (address token0, address token1)
  {
    require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
  }

  // calculates the CREATE2 address for a pair without making any external calls
  function pairFor(
    address factory,
    address tokenA,
    address tokenB
  ) internal pure returns (address pair) {
    (address token0, address token1) = sortTokens(tokenA, tokenB);
    pair = address(
      uint256(
        keccak256(
          abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1)),
            hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
          )
        )
      )
    );
  }

  // fetches and sorts the reserves for a pair
  function getReserves(
    address factory,
    address tokenA,
    address tokenB
  ) internal view returns (uint256 reserveA, uint256 reserveB) {
    (address token0, ) = sortTokens(tokenA, tokenB);
    (uint256 reserve0, uint256 reserve1, ) =
      IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
    (reserveA, reserveB) = tokenA == token0
      ? (reserve0, reserve1)
      : (reserve1, reserve0);
  }

  // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
  function quote(
    uint256 amountA,
    uint256 reserveA,
    uint256 reserveB
  ) internal pure returns (uint256 amountB) {
    require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
    require(
      reserveA > 0 && reserveB > 0,
      'UniswapV2Library: INSUFFICIENT_LIQUIDITY'
    );
    amountB = amountA.mul(reserveB) / reserveA;
  }

  // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
  function getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
  ) internal pure returns (uint256 amountOut) {
    require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
    require(
      reserveIn > 0 && reserveOut > 0,
      'UniswapV2Library: INSUFFICIENT_LIQUIDITY'
    );
    uint256 amountInWithFee = amountIn.mul(997);
    uint256 numerator = amountInWithFee.mul(reserveOut);
    uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
    amountOut = numerator / denominator;
  }

  // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
  function getAmountIn(
    uint256 amountOut,
    uint256 reserveIn,
    uint256 reserveOut
  ) internal pure returns (uint256 amountIn) {
    require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
    require(
      reserveIn > 0 && reserveOut > 0,
      'UniswapV2Library: INSUFFICIENT_LIQUIDITY'
    );
    uint256 numerator = reserveIn.mul(amountOut).mul(1000);
    uint256 denominator = reserveOut.sub(amountOut).mul(997);
    amountIn = (numerator / denominator).add(1);
  }

  // performs chained getAmountOut calculations on any number of pairs
  function getAmountsOut(
    address factory,
    uint256 amountIn,
    address[] memory path
  ) internal view returns (uint256[] memory amounts) {
    require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
    amounts = new uint256[](path.length);
    amounts[0] = amountIn;
    for (uint256 i; i < path.length - 1; i++) {
      (uint256 reserveIn, uint256 reserveOut) =
        getReserves(factory, path[i], path[i + 1]);
      amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
    }
  }
}


// File: contracts/farms/ERC20Farm.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import '../interfaces/IVault.sol';

contract ERC20Farm is IVault, Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event ClaimedRewards(
    address indexed user,
    uint256 indexed pid,
    uint256 amount
  );
  event EmergencyWithdraw(
    address indexed user,
    uint256 indexed pid,
    uint256 amount
  );

  /// @notice Detail of each user.
  struct UserInfo {
    uint256 amount; // How many tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
    //
    // We do some fancy math here. Basically, any point in time, the amount of reward
    // entitled to a user which is pending to be distributed is:
    //
    // pending reward = (user.amount * pool.accRewardPerShare) - user.rewardDebt
    //
    // Whenever a user deposits or withdraws tokens to a pool:
    //   1. The pool's `accRewardPerShare` (and `lastRewardBlock`) gets updated.
    //   2. User receives the pending reward sent to their address.
    //   3. User's `amount` gets updated.
    //   4. User's `rewardDebt` gets updated.
  }

  /// @notice Detail of each pool.
  struct PoolInfo {
    address token; // Token to stake.
    uint256 allocPoint; // How many allocation points assigned to this pool. Rewards to distribute per block.
    uint256 accRewardPerShare; // Accumulated rewards per share.
  }

  /// @dev Reward token balance minus any pending rewards.
  uint256 private rewardTokenBalance;

  /// @dev Division precision.
  uint256 private precision = 1e12;

  /// @notice Total allocation points. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint;

  /// @notice Pending rewards awaiting for massUpdate.
  uint256 public pendingRewards;

  /// @notice Contract block deployment.
  uint256 public initialBlock;

  /// @notice Time of the contract deployment.
  uint256 public timeDeployed;

  /// @notice Total rewards accumulated since contract deployment.
  uint256 public totalCumulativeRewards;

  /// @notice Reward token.
  address public rewardToken;

  /// @notice Detail of each pool.
  PoolInfo[] public poolInfo;

  /// @notice Detail of each user who stakes tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;

  constructor(address _rewardToken) public {
    rewardToken = _rewardToken;
    initialBlock = block.number;
    timeDeployed = block.timestamp;
  }

  /// @notice Average fee generated since contract deployment.
  function avgFeesPerBlockTotal() external view returns (uint256 avgPerBlock) {
    return totalCumulativeRewards.div(block.number.sub(initialBlock));
  }

  /// @notice Average fee per second generated since contract deployment.
  function avgFeesPerSecondTotal()
    external
    view
    returns (uint256 avgPerSecond)
  {
    return totalCumulativeRewards.div(block.timestamp.sub(timeDeployed));
  }

  /// @notice Total pools.
  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  /// @notice Display user rewards for a specific pool.
  function pendingReward(uint256 _pid, address _user)
    public
    view
    returns (uint256)
  {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accRewardPerShare = pool.accRewardPerShare;

    return
      user.amount.mul(accRewardPerShare).div(precision).sub(user.rewardDebt);
  }

  /// @notice Add a new pool.
  function add(
    uint256 _allocPoint,
    address _token,
    bool _withUpdate
  ) public onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }

    uint256 length = poolInfo.length;

    for (uint256 pid = 0; pid < length; ++pid) {
      require(
        poolInfo[pid].token != _token,
        'TrigRewardsVault: Token pool already added.'
      );
    }

    totalAllocPoint = totalAllocPoint.add(_allocPoint);

    poolInfo.push(
      PoolInfo({token: _token, allocPoint: _allocPoint, accRewardPerShare: 0})
    );
  }

  /// @notice Update the given pool's allocation point.
  function set(
    uint256 _pid,
    uint256 _allocPoint,
    bool _withUpdate
  ) public onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }

    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
      _allocPoint
    );
    poolInfo[_pid].allocPoint = _allocPoint;
  }

  /// @notice Updates rewards for all pools by adding pending rewards.
  /// Can spend a lot of gas.
  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    uint256 allRewards;

    for (uint256 pid = 0; pid < length; ++pid) {
      allRewards = allRewards.add(_updatePool(pid));
    }

    pendingRewards = pendingRewards.sub(allRewards);
  }

  /// @notice Function that is part of Vault's interface. It must be implemented.
  function update(uint256 amount) external override {
    amount; // silence warning.
    _addPendingRewards();
    massUpdatePools();
  }

  /// @notice Deposit tokens to vault for reward allocation.
  function deposit(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    massUpdatePools();
    // Transfer pending tokens to user
    _updateAndPayOutPending(_pid, msg.sender);

    //Transfer in the amounts from user
    if (_amount > 0) {
      IERC20(pool.token).safeTransferFrom(
        address(msg.sender),
        address(this),
        _amount
      );
      user.amount = user.amount.add(_amount);
    }

    user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(precision);
    emit Deposit(msg.sender, _pid, _amount);
  }

  // Withdraw  tokens from Vault.
  function withdraw(uint256 _pid, uint256 _amount) public {
    _withdraw(_pid, _amount, msg.sender, msg.sender);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  // !Caution this will remove all your pending rewards!
  function emergencyWithdraw(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    IERC20(pool.token).safeTransfer(address(msg.sender), user.amount);

    emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
    // No mass update dont update pending rewards
  }

  /// @notice Adds any rewards that were sent to the contract since last reward update.
  function _addPendingRewards() internal {
    uint256 newRewards =
      IERC20(rewardToken).balanceOf(address(this)).sub(rewardTokenBalance);

    if (newRewards > 0) {
      rewardTokenBalance = IERC20(rewardToken).balanceOf(address(this));
      pendingRewards = pendingRewards.add(newRewards);
      totalCumulativeRewards = totalCumulativeRewards.add(newRewards);
    }
  }

  // Low level withdraw function
  function _withdraw(
    uint256 _pid,
    uint256 _amount,
    address from,
    address to
  ) internal {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][from];
    require(
      user.amount >= _amount,
      'TrigRewardsVault: Withdraw amount is greater than user stake.'
    );

    massUpdatePools();
    _updateAndPayOutPending(_pid, from); // Update balance and claim rewards farmed

    if (_amount > 0) {
      user.amount = user.amount.sub(_amount);
      IERC20(pool.token).safeTransfer(address(to), _amount);
    }

    user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(precision);
    emit Withdraw(to, _pid, _amount);
  }

  /// @notice Allocates pending rewards to pool.
  function _updatePool(uint256 _pid)
    internal
    returns (uint256 poolShareRewards)
  {
    PoolInfo storage pool = poolInfo[_pid];

    uint256 stakedTokens;

    stakedTokens = IERC20(pool.token).balanceOf(address(this));

    if (totalAllocPoint == 0 || stakedTokens == 0) {
      return 0;
    }

    poolShareRewards = pendingRewards.mul(pool.allocPoint).div(totalAllocPoint);
    pool.accRewardPerShare = pool.accRewardPerShare.add(
      poolShareRewards.mul(precision).div(stakedTokens)
    );
  }

  function _safeRewardTokenTransfer(address _to, uint256 _amount)
    internal
    returns (uint256 _claimed)
  {
    uint256 rewardTokenBal = IERC20(rewardToken).balanceOf(address(this));

    if (_amount > rewardTokenBal) {
      _claimed = rewardTokenBal;
      IERC20(rewardToken).transfer(_to, rewardTokenBal);
      rewardTokenBalance = IERC20(rewardToken).balanceOf(address(this));
    } else {
      _claimed = _amount;
      IERC20(rewardToken).transfer(_to, _amount);
      rewardTokenBalance = IERC20(rewardToken).balanceOf(address(this));
    }
  }

  function _updateAndPayOutPending(uint256 _pid, address _from) internal {
    uint256 pending = pendingReward(_pid, _from);

    if (pending > 0) {
      uint256 _amountClaimed = _safeRewardTokenTransfer(_from, pending);
      emit ClaimedRewards(_from, _pid, _amountClaimed);
    }
  }
}


// File: contracts/TrigRewardsVault.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import './farms/ERC20Farm.sol';

contract TrigRewardsVault is ERC20Farm {
  constructor(address _rewardToken) public ERC20Farm(_rewardToken) {}
}


// File: contracts/RewardsVault.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import './farms/ERC20Farm.sol';

contract RewardsVault is ERC20Farm {
  constructor(address _rewardToken) public ERC20Farm(_rewardToken) {}
}


// File: contracts/NFT.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.7.0;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';

contract NFT is ERC1155 {
  uint256 public constant VISIONARY = 0;
  uint256 public constant EXPLORER = 1;
  uint256 public constant ALCHEMIST = 2;
  uint256 public constant VOYAGER = 3;
  uint256 public constant LEGEND = 4;
  uint256 public constant SUPREME = 5;
  uint256 public constant IMMORTAL = 6;
  uint256 public constant DIVINITY = 7;

  constructor(string memory uri) public ERC1155(uri) {
    _mint(msg.sender, VISIONARY, 10, '');
    _mint(msg.sender, EXPLORER, 8, '');
    _mint(msg.sender, ALCHEMIST, 6, '');
    _mint(msg.sender, VOYAGER, 5, '');
    _mint(msg.sender, LEGEND, 4, '');
    _mint(msg.sender, SUPREME, 2, '');
    _mint(msg.sender, IMMORTAL, 1, '');
    _mint(msg.sender, DIVINITY, 1, '');
  }
}


// File: contracts/libraries/MathUtils.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16 <0.7.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

library MathUtils {
  using SafeMath for uint256;

  /// @notice Calculates the square root of a given value.
  function sqrt(uint256 y) internal pure returns (uint256 z) {
    if (y > 3) {
      z = y;
      uint256 x = y / 2 + 1;
      while (x < z) {
        z = x;
        x = (y / x + x) / 2;
      }
    } else if (y != 0) {
      z = 1;
    }
  }

  /// @notice Rounds a division result.
  function roundedDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0, 'div by 0');

    uint256 halfB = (b.mod(2) == 0) ? (b.div(2)) : (b.div(2).add(1));
    return (a.mod(b) >= halfB) ? (a.div(b).add(1)) : (a.div(b));
  }
}


// File: contracts/governance/GuardianTimelock.sol
// SPDX-License-Identifier: MIT
// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Copyright 2020 Compound Labs, Inc.
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Ctrl+f for XXX to see all the modifications.

// XXX: pragma solidity ^0.5.16;
pragma solidity >=0.5.0 <0.7.0;

// XXX: import "./SafeMath.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';

contract GuardianTimelock {
  using SafeMath for uint256;

  event NewAdmin(address indexed newAdmin);
  event NewPendingAdmin(address indexed newPendingAdmin);
  event NewDelay(uint256 indexed newDelay);
  event CancelTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );
  event ExecuteTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );
  event QueueTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );

  uint256 public constant GRACE_PERIOD = 5 days;
  uint256 public constant MINIMUM_DELAY = 30 minutes;
  uint256 public constant MAXIMUM_DELAY = 15 days;

  address public admin;
  address public pendingAdmin;
  uint256 public delay;
  bool public admin_initialized;

  mapping(bytes32 => bool) public queuedTransactions;

  constructor(address admin_, uint256 delay_) public {
    require(
      delay_ >= MINIMUM_DELAY,
      'GuardianTimelock::constructor: Delay must exceed minimum delay.'
    );
    require(
      delay_ <= MAXIMUM_DELAY,
      'GuardianTimelock::constructor: Delay must not exceed maximum delay.'
    );

    admin = admin_;
    delay = delay_;
    admin_initialized = false;
  }

  // XXX: function() external payable { }
  receive() external payable {}

  function setDelay(uint256 delay_) public {
    require(
      msg.sender == address(this),
      'GuardianTimelock::setDelay: Call must come from Timelock.'
    );
    require(
      delay_ >= MINIMUM_DELAY,
      'GuardianTimelock::setDelay: Delay must exceed minimum delay.'
    );
    require(
      delay_ <= MAXIMUM_DELAY,
      'GuardianTimelock::setDelay: Delay must not exceed maximum delay.'
    );
    delay = delay_;

    emit NewDelay(delay);
  }

  function acceptAdmin() public {
    require(
      msg.sender == pendingAdmin,
      'GuardianTimelock::acceptAdmin: Call must come from pendingAdmin.'
    );
    admin = msg.sender;
    pendingAdmin = address(0);

    emit NewAdmin(admin);
  }

  function setPendingAdmin(address pendingAdmin_) public {
    // allows one time setting of admin for deployment purposes
    if (admin_initialized) {
      require(
        msg.sender == address(this),
        'GuardianTimelock::setPendingAdmin: Call must come from Timelock.'
      );
    } else {
      require(
        msg.sender == admin,
        'GuardianTimelock::setPendingAdmin: First call must come from admin.'
      );
      admin_initialized = true;
    }
    pendingAdmin = pendingAdmin_;

    emit NewPendingAdmin(pendingAdmin);
  }

  function queueTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) public returns (bytes32) {
    require(
      msg.sender == admin,
      'GuardianTimelock::queueTransaction: Call must come from admin.'
    );
    require(
      eta >= getBlockTimestamp().add(delay),
      'GuardianTimelock::queueTransaction: Estimated execution block must satisfy delay.'
    );

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    queuedTransactions[txHash] = true;

    emit QueueTransaction(txHash, target, value, signature, data, eta);
    return txHash;
  }

  function cancelTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) public {
    require(
      msg.sender == admin,
      'GuardianTimelock::cancelTransaction: Call must come from admin.'
    );

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    queuedTransactions[txHash] = false;

    emit CancelTransaction(txHash, target, value, signature, data, eta);
  }

  function executeTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) public payable returns (bytes memory) {
    require(
      msg.sender == admin,
      'GuardianTimelock::executeTransaction: Call must come from admin.'
    );

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    require(
      queuedTransactions[txHash],
      "GuardianTimelock::executeTransaction: Transaction hasn't been queued."
    );
    require(
      getBlockTimestamp() >= eta,
      "GuardianTimelock::executeTransaction: Transaction hasn't surpassed time lock."
    );
    require(
      getBlockTimestamp() <= eta.add(GRACE_PERIOD),
      'GuardianTimelock::executeTransaction: Transaction is stale.'
    );

    queuedTransactions[txHash] = false;

    bytes memory callData;

    if (bytes(signature).length == 0) {
      callData = data;
    } else {
      callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
    }

    // solium-disable-next-line security/no-call-value
    (bool success, bytes memory returnData) =
      target.call{value: value}(callData);
    require(
      success,
      'GuardianTimelock::executeTransaction: Transaction execution reverted.'
    );

    emit ExecuteTransaction(txHash, target, value, signature, data, eta);

    return returnData;
  }

  function getBlockTimestamp() internal view returns (uint256) {
    // solium-disable-next-line security/no-block-members
    return block.timestamp;
  }
}


// File: contracts/governance/GovernorTimelock.sol
// SPDX-License-Identifier: MIT
// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Copyright 2020 Compound Labs, Inc.
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Ctrl+f for XXX to see all the modifications.

// XXX: pragma solidity ^0.5.16;
pragma solidity >=0.5.0 <0.7.0;

// XXX: import "./SafeMath.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';

contract GovernorTimelock {
  using SafeMath for uint256;

  event NewAdmin(address indexed newAdmin);
  event NewPendingAdmin(address indexed newPendingAdmin);
  event NewDelay(uint256 indexed newDelay);
  event CancelTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );
  event ExecuteTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );
  event QueueTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );

  uint256 public constant GRACE_PERIOD = 14 days;
  uint256 public constant MINIMUM_DELAY = 2 days;
  uint256 public constant MAXIMUM_DELAY = 30 days;

  address public admin;
  address public pendingAdmin;
  uint256 public delay;
  bool public admin_initialized;

  mapping(bytes32 => bool) public queuedTransactions;

  constructor(address admin_, uint256 delay_) public {
    require(
      delay_ >= MINIMUM_DELAY,
      'GovernorTimelock::constructor: Delay must exceed minimum delay.'
    );
    require(
      delay_ <= MAXIMUM_DELAY,
      'GovernorTimelock::constructor: Delay must not exceed maximum delay.'
    );

    admin = admin_;
    delay = delay_;
    admin_initialized = false;
  }

  // XXX: function() external payable { }
  receive() external payable {}

  function setDelay(uint256 delay_) public {
    require(
      msg.sender == address(this),
      'GovernorTimelock::setDelay: Call must come from Timelock.'
    );
    require(
      delay_ >= MINIMUM_DELAY,
      'GovernorTimelock::setDelay: Delay must exceed minimum delay.'
    );
    require(
      delay_ <= MAXIMUM_DELAY,
      'GovernorTimelock::setDelay: Delay must not exceed maximum delay.'
    );
    delay = delay_;

    emit NewDelay(delay);
  }

  function acceptAdmin() public {
    require(
      msg.sender == pendingAdmin,
      'GovernorTimelock::acceptAdmin: Call must come from pendingAdmin.'
    );
    admin = msg.sender;
    pendingAdmin = address(0);

    emit NewAdmin(admin);
  }

  function setPendingAdmin(address pendingAdmin_) public {
    // allows one time setting of admin for deployment purposes
    if (admin_initialized) {
      require(
        msg.sender == address(this),
        'GovernorTimelock::setPendingAdmin: Call must come from Timelock.'
      );
    } else {
      require(
        msg.sender == admin,
        'GovernorTimelock::setPendingAdmin: First call must come from admin.'
      );
      admin_initialized = true;
    }
    pendingAdmin = pendingAdmin_;

    emit NewPendingAdmin(pendingAdmin);
  }

  function queueTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) public returns (bytes32) {
    require(
      msg.sender == admin,
      'GovernorTimelock::queueTransaction: Call must come from admin.'
    );
    require(
      eta >= getBlockTimestamp().add(delay),
      'GovernorTimelock::queueTransaction: Estimated execution block must satisfy delay.'
    );

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    queuedTransactions[txHash] = true;

    emit QueueTransaction(txHash, target, value, signature, data, eta);
    return txHash;
  }

  function cancelTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) public {
    require(
      msg.sender == admin,
      'GovernorTimelock::cancelTransaction: Call must come from admin.'
    );

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    queuedTransactions[txHash] = false;

    emit CancelTransaction(txHash, target, value, signature, data, eta);
  }

  function executeTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) public payable returns (bytes memory) {
    require(
      msg.sender == admin,
      'GovernorTimelock::executeTransaction: Call must come from admin.'
    );

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    require(
      queuedTransactions[txHash],
      "GovernorTimelock::executeTransaction: Transaction hasn't been queued."
    );
    require(
      getBlockTimestamp() >= eta,
      "GovernorTimelock::executeTransaction: Transaction hasn't surpassed time lock."
    );
    require(
      getBlockTimestamp() <= eta.add(GRACE_PERIOD),
      'GovernorTimelock::executeTransaction: Transaction is stale.'
    );

    queuedTransactions[txHash] = false;

    bytes memory callData;

    if (bytes(signature).length == 0) {
      callData = data;
    } else {
      callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
    }

    // solium-disable-next-line security/no-call-value
    (bool success, bytes memory returnData) =
      target.call{value: value}(callData);
    require(
      success,
      'GovernorTimelock::executeTransaction: Transaction execution reverted.'
    );

    emit ExecuteTransaction(txHash, target, value, signature, data, eta);

    return returnData;
  }

  function getBlockTimestamp() internal view returns (uint256) {
    // solium-disable-next-line security/no-block-members
    return block.timestamp;
  }
}


// File: contracts/interfaces/IGovernorAlpha.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

interface IGovernor {
  function cancel(uint256 proposalId) external;

  function __acceptAdmin() external;

  function __abdicate() external;

  function __queueSetTimelockPendingAdmin(address newPendingAdmin, uint256 eta)
    external;

  function __executeSetTimelockPendingAdmin(
    address newPendingAdmin,
    uint256 eta
  ) external;
}


// File: contracts/libraries/Math.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

// a library for performing various math operations

library Math {
  function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = x < y ? x : y;
  }

  // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
  function sqrt(uint256 y) internal pure returns (uint256 z) {
    if (y > 3) {
      z = y;
      uint256 x = y / 2 + 1;
      while (x < z) {
        z = x;
        x = (y / x + x) / 2;
      }
    } else if (y != 0) {
      z = 1;
    }
  }
}


// File: contracts/libraries/StringLibrary.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

import './UintLibrary.sol';

library StringLibrary {
  using UintLibrary for uint256;

  function append(string memory _a, string memory _b)
    internal
    pure
    returns (string memory)
  {
    bytes memory _ba = bytes(_a);
    bytes memory _bb = bytes(_b);
    bytes memory bab = new bytes(_ba.length + _bb.length);
    uint256 k = 0;
    for (uint256 i = 0; i < _ba.length; i++) bab[k++] = _ba[i];
    for (uint256 i = 0; i < _bb.length; i++) bab[k++] = _bb[i];
    return string(bab);
  }

  function append(
    string memory _a,
    string memory _b,
    string memory _c
  ) internal pure returns (string memory) {
    bytes memory _ba = bytes(_a);
    bytes memory _bb = bytes(_b);
    bytes memory _bc = bytes(_c);
    bytes memory bbb = new bytes(_ba.length + _bb.length + _bc.length);
    uint256 k = 0;
    for (uint256 i = 0; i < _ba.length; i++) bbb[k++] = _ba[i];
    for (uint256 i = 0; i < _bb.length; i++) bbb[k++] = _bb[i];
    for (uint256 i = 0; i < _bc.length; i++) bbb[k++] = _bc[i];
    return string(bbb);
  }

  function recover(
    string memory message,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) internal pure returns (address) {
    bytes memory msgBytes = bytes(message);
    bytes memory fullMessage =
      concat(
        bytes('\x19Ethereum Signed Message:\n'),
        bytes(msgBytes.length.toString()),
        msgBytes,
        new bytes(0),
        new bytes(0),
        new bytes(0),
        new bytes(0)
      );
    return ecrecover(keccak256(fullMessage), v, r, s);
  }

  function concat(
    bytes memory _ba,
    bytes memory _bb,
    bytes memory _bc,
    bytes memory _bd,
    bytes memory _be,
    bytes memory _bf,
    bytes memory _bg
  ) internal pure returns (bytes memory) {
    bytes memory resultBytes =
      new bytes(
        _ba.length +
          _bb.length +
          _bc.length +
          _bd.length +
          _be.length +
          _bf.length +
          _bg.length
      );
    uint256 k = 0;
    for (uint256 i = 0; i < _ba.length; i++) resultBytes[k++] = _ba[i];
    for (uint256 i = 0; i < _bb.length; i++) resultBytes[k++] = _bb[i];
    for (uint256 i = 0; i < _bc.length; i++) resultBytes[k++] = _bc[i];
    for (uint256 i = 0; i < _bd.length; i++) resultBytes[k++] = _bd[i];
    for (uint256 i = 0; i < _be.length; i++) resultBytes[k++] = _be[i];
    for (uint256 i = 0; i < _bf.length; i++) resultBytes[k++] = _bf[i];
    for (uint256 i = 0; i < _bg.length; i++) resultBytes[k++] = _bg[i];
    return resultBytes;
  }
}


// File: contracts/libraries/UintLibrary.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.7.0;

library UintLibrary {
  function toString(uint256 _i) internal pure returns (string memory) {
    if (_i == 0) {
      return '0';
    }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len - 1;
    while (_i != 0) {
      bstr[k--] = bytes1(uint8(48 + (_i % 10)));
      _i /= 10;
    }
    return string(bstr);
  }
}


