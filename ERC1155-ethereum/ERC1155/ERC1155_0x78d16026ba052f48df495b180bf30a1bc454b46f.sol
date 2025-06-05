// File: src/StakedALTXterioVault.sol
// SPDX-License-Identifier: agpl-3.0
// Copyright (c) 2024, Alt Research Ltd.
pragma solidity =0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {StakedMultiToken} from "./StakedMultiToken.sol";

contract StakedALTXterioVault is StakedMultiToken {
    constructor(IERC20 altToken_, uint40 stakingStartTimestamp_) StakedMultiToken(altToken_, stakingStartTimestamp_) {}

    event URIUpdated(string);

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
        emit URIUpdated(newuri);
    }

    function name() external pure returns (string memory) {
        return "Staked ALT (XTER Vault)";
    }

    function symbol() external pure returns (string memory) {
        return "STALTXTER";
    }

    function decimals() external pure returns (uint256) {
        return 18;
    }
}


// File: lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC20Permit} from "../extensions/IERC20Permit.sol";
import {Address} from "../../../utils/Address.sol";

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
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
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

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
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
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}


// File: src/StakedMultiToken.sol
// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.23;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ERC1155SupplyUpgradeable,
    ERC1155Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

import {IStakedMultiToken} from "./interfaces/IStakedMultiToken.sol";
import {DistributionData, RewardDistribution} from "./RewardDistribution.sol";
import {AlertSystem} from "./AlertSystem.sol";
import {OperatorRegistry} from "./OperatorRegistry.sol";
import {
    ArrayLengthMismatch,
    ZeroVotingStake,
    FrozenOperator,
    InsufficientAmount,
    LessThanMinStakeToVote,
    ZeroAddress,
    NotOperator,
    AlreadyRegistered,
    InvalidBPS,
    ZeroExchangeRate,
    ZeroAmount,
    InvalidCooldownAmount,
    InsufficientCooldown,
    ZeroUnstakeable,
    InvalidDestination,
    GreaterThanMaxCooldownSec,
    StakingNotStartedYet,
    InvalidStakingStartTime,
    NotSupported
} from "./Errors.sol";

/// @dev The staked token should be deployed on Ethereum.
/// This is adapted from https://github.com/bgd-labs/aave-stk-v1-5/blob/8867dd5b1137d4d46acd9716fe98759cb16b1606/src/contracts/StakedTokenV3.sol
// solhint-disable not-rely-on-time, var-name-mixedcase
// slither-disable-start timestamp
abstract contract StakedMultiToken is IStakedMultiToken, ERC1155SupplyUpgradeable, RewardDistribution, AlertSystem {
    using SafeERC20 for IERC20;

    struct ProtocolConfig {
        address vault;
        /// @dev Seconds between starting cooldown and being able to update fee
        uint40 cooldownSeconds;
        Fee fee;
    }

    struct OperatorConfig {
        /// @dev Seconds between starting cooldown and being able to update fee
        uint40 cooldownSeconds;
        mapping(address => Fee) fees;
    }

    struct Fee {
        uint40 cooldownEndTimestamp;
        uint16 bps;
        uint16 pendingBPS;
    }

    /// @dev MAX_BPS the maximum number of basis points.
    /// 10000 basis points are equivalent to 100%.
    uint256 public constant MAX_BPS = 1e4;

    /// @dev total fee BPS should not exceed MAX_BPS
    uint16 public constant MAX_PROTOCOL_FEE_BPS = 2e3;

    /// @dev total fee BPS should not exceed MAX_BPS
    uint16 public constant MAX_OPERATOR_FEE_BPS = 2e3;

    uint40 public constant MAX_COOLDOWN_SEC = 4320000;

    IERC20 public immutable stakedToken;
    uint40 public immutable stakingStartTimestamp;

    ProtocolConfig public protocolConfig;

    OperatorConfig public operatorConfig;

    /// @dev Seconds between starting cooldown and being able to withdraw
    uint40 public cooldownSeconds;

    /// hash(operator, distribution id, staker) => rewardsBalance
    mapping(bytes32 => uint256) private _rewardsBalances;

    uint256 public totalStakedAmount;
    uint256 public totalCooldownAmount;
    uint256 public totalFrozenAmount;
    uint256 public totalFrozenCooldownAmount;

    // operator => total cooldown amount
    mapping(address => uint256) public totalCooldownAmounts;

    struct CooldownSnapshot {
        uint40 timestamp;
        uint216 amount;
    }

    mapping(address => mapping(address => CooldownSnapshot)) public cooldowns;

    /// @notice Minimum stake required to vote on an alert
    uint256 public minVotingStake;

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    // slither-disable-next-line unused-state
    uint256[39] private __gap;

    modifier onlyValidCooldownSec(uint40 cooldownSec_) {
        if (cooldownSec_ > MAX_COOLDOWN_SEC) {
            revert GreaterThanMaxCooldownSec();
        }
        _;
    }

    modifier onlyValidOperator(address operator) {
        if (!isOperator(operator)) {
            revert NotOperator();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IERC20 stakedToken_, uint40 stakingStartTimestamp_) {
        _disableInitializers();

        if (address(stakedToken_) == address(0)) {
            revert ZeroAddress();
        }

        if (stakingStartTimestamp_ <= block.timestamp) {
            revert InvalidStakingStartTime();
        }

        stakedToken = stakedToken_;
        stakingStartTimestamp = stakingStartTimestamp_;
    }

    ///////////////////////
    // External Functions
    ///////////////////////

    function initialize(
        address initialOwner_,
        string calldata uri_,
        uint40 cooldownSec_,
        uint40 cooldownSecForOperatorFeeUpdate_,
        uint40 cooldownSecForProtocolFeeUpdate_,
        address protocolFeeVault_,
        uint16 initialProtocolFeeBPS_,
        uint256 initialMinVotingStake_,
        uint16 initialExpiryDuration
    ) external initializer {
        if (initialOwner_ == address(0) || protocolFeeVault_ == address(0)) {
            revert ZeroAddress();
        }
        if (initialProtocolFeeBPS_ > MAX_PROTOCOL_FEE_BPS) {
            revert InvalidBPS();
        }

        __Pausable_init();
        // This is a multisig account
        __Ownable_init(initialOwner_);
        __ERC1155_init(uri_);
        __ERC1155Supply_init();
        __AlertSystem_init(initialExpiryDuration);
        _setProtocolFeeBPS(initialProtocolFeeBPS_);

        cooldownSeconds = cooldownSec_;
        operatorConfig.cooldownSeconds = cooldownSecForOperatorFeeUpdate_;

        protocolConfig.cooldownSeconds = cooldownSecForProtocolFeeUpdate_;
        protocolConfig.vault = protocolFeeVault_;

        minVotingStake = initialMinVotingStake_;
    }

    /// @inheritdoc IStakedMultiToken
    function registerOperator(address operator, uint16 feeBPS_) external onlyOwner {
        if (feeBPS_ > MAX_OPERATOR_FEE_BPS) {
            revert InvalidBPS();
        }

        if (isOperator(operator)) {
            revert AlreadyRegistered();
        }

        // slither-disable-next-line unused-return
        _addOperator(operator);

        _updateAllDistribution(totalVotingStake());
        _setOperatorFeeBPS(operator, feeBPS_);
        emit OperatorRegistered(operator);
    }

    /// @inheritdoc IStakedMultiToken
    function setMinVotingStake(uint256 minVotingStake_) external onlyOwner {
        minVotingStake = minVotingStake_;
        emit SetMinVotingStake(minVotingStake_);
    }

    /// @inheritdoc IStakedMultiToken
    function setCooldownSecForOperatorFee(uint40 cooldownSec_) external onlyOwner onlyValidCooldownSec(cooldownSec_) {
        operatorConfig.cooldownSeconds = cooldownSec_;
        emit SetCooldownSecForOperatorFee(cooldownSec_);
    }

    /// @inheritdoc IStakedMultiToken
    function setCooldownSecForProtocolFee(uint40 cooldownSec_) external onlyOwner onlyValidCooldownSec(cooldownSec_) {
        protocolConfig.cooldownSeconds = cooldownSec_;
        emit SetCooldownSecForProtocolFee(cooldownSec_);
    }

    /// @inheritdoc IStakedMultiToken
    function setCooldownSecForUnstaking(uint40 cooldownSec_) external onlyOwner onlyValidCooldownSec(cooldownSec_) {
        cooldownSeconds = cooldownSec_;
        emit SetCooldownSecForUnstaking(cooldownSec_);
    }

    /// @inheritdoc IStakedMultiToken
    function cooldownToUpdateProtocolFee(uint16 feeBPS_) external onlyOwner {
        if (feeBPS_ > MAX_PROTOCOL_FEE_BPS) {
            revert InvalidBPS();
        }
        uint40 cooldownEndTimestamp = uint40(block.timestamp) + protocolConfig.cooldownSeconds;
        protocolConfig.fee.cooldownEndTimestamp = cooldownEndTimestamp;
        protocolConfig.fee.pendingBPS = feeBPS_;
        emit CooldownToUpdateProtocolFee(feeBPS_, cooldownEndTimestamp);
    }

    /// @inheritdoc IStakedMultiToken
    function setProtocolFeeBPS() external onlyOwner {
        if (protocolConfig.fee.cooldownEndTimestamp > block.timestamp) {
            revert InsufficientCooldown();
        }
        _setProtocolFeeBPS(protocolConfig.fee.pendingBPS);
    }

    /// @inheritdoc IStakedMultiToken
    function setOperatorFeeBPS() external onlyOperator whenNotPaused {
        address operator = _msgSender();
        if (operatorConfig.fees[operator].cooldownEndTimestamp > block.timestamp) {
            revert InsufficientCooldown();
        }
        _setOperatorFeeBPS(operator, operatorConfig.fees[operator].pendingBPS);
    }

    /// @inheritdoc IStakedMultiToken
    function cooldownToUpdateOperatorFee(uint16 feeBPS_) external onlyOperator whenNotPaused {
        if (feeBPS_ > MAX_OPERATOR_FEE_BPS) {
            revert InvalidBPS();
        }
        address operator = _msgSender();
        uint40 cooldownEndTimestamp = uint40(block.timestamp) + operatorConfig.cooldownSeconds;
        operatorConfig.fees[operator].cooldownEndTimestamp = cooldownEndTimestamp;
        operatorConfig.fees[operator].pendingBPS = feeBPS_;

        emit CooldownToUpdateOperatorFee(operator, feeBPS_, cooldownEndTimestamp);
    }

    /// @inheritdoc IStakedMultiToken
    function stake(address to, address operator, uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (stakingStartTimestamp > block.timestamp) {
            revert StakingNotStartedYet();
        }
        address from = _msgSender();
        _updateCurrentUnclaimedRewards(to, operator, votingStake(to, operator));
        _stake(from, to, operator, amount);
    }

    /// @inheritdoc IStakedMultiToken
    function cooldownToUnstake(address operator, uint256 amountToAdd)
        external
        onlyValidOperator(operator)
        whenNotPaused
    {
        address from = _msgSender();
        uint256 balance = balanceOf(from, operator);

        CooldownSnapshot storage currentCooldown = cooldowns[operator][from];

        uint256 newCooldownAmount = amountToAdd + currentCooldown.amount;

        if (amountToAdd == 0 || newCooldownAmount > balance) {
            revert InvalidCooldownAmount();
        }

        _updateCurrentUnclaimedRewards(from, operator, votingStake(from, operator));

        emit CooldownToUnstake(from, operator, newCooldownAmount);

        currentCooldown.amount = uint216(newCooldownAmount);
        currentCooldown.timestamp = uint40(block.timestamp);

        totalCooldownAmounts[operator] += amountToAdd;
        totalCooldownAmount += amountToAdd;
        if (isFrozenOperator(operator)) {
            totalFrozenCooldownAmount += amountToAdd;
        }
    }

    /// @inheritdoc IStakedMultiToken
    /// @dev This function allows a token holder to transfer their voting stake from one operator to another.
    /// If the `amount` is 0 or the sender has a zero voting stake with the `fromOperator`, the transaction reverts.
    /// It first unstakes the voting stake from the `fromOperator` and then stakes the same amount with the `toOperator`.
    /// The function uses `_msgSender` to identify the caller.
    function switchOperator(address fromOperator, address toOperator, uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        if (fromOperator == toOperator) {
            revert InvalidDestination();
        }

        address sender = _msgSender();
        uint256 max = votingStake(sender, fromOperator);

        if (max == 0) {
            revert ZeroVotingStake();
        }

        uint256 amountToTransfer = (amount > max) ? max : amount;

        _updateCurrentUnclaimedRewards(sender, fromOperator, votingStake(sender, fromOperator));
        _unstake(sender, sender, fromOperator, amountToTransfer);

        _updateCurrentUnclaimedRewards(sender, toOperator, votingStake(sender, toOperator));
        _stake(sender, sender, toOperator, amountToTransfer);
    }

    /// @inheritdoc IStakedMultiToken
    function unstake(address to, address operator, uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        address from = _msgSender();
        CooldownSnapshot memory cooldownSnapshot = cooldowns[operator][from];
        if (block.timestamp < cooldownSnapshot.timestamp + cooldownSeconds) {
            revert InsufficientCooldown();
        }

        uint256 max = cooldownSnapshot.amount;
        if (max == 0) {
            revert ZeroUnstakeable();
        }

        _updateCurrentUnclaimedRewards(from, operator, votingStake(from, operator));

        uint256 amountToUnstake = (amount > max) ? max : amount;

        if (cooldownSnapshot.timestamp > 0) {
            if (cooldownSnapshot.amount - amountToUnstake == 0) {
                delete cooldowns[operator][from];
            } else {
                cooldowns[operator][from].amount -= uint216(amountToUnstake);
            }
            totalCooldownAmount -= amountToUnstake;
            totalCooldownAmounts[operator] -= amountToUnstake;
            if (isFrozenOperator(operator)) {
                totalFrozenCooldownAmount -= amountToUnstake;
            }
        }
        _unstake(from, to, operator, amountToUnstake);
    }

    /// @inheritdoc IStakedMultiToken
    function claimRewardsBatch(
        uint16[] calldata ids_,
        address[] calldata recipients_,
        address[] calldata operators_,
        uint256[] calldata amounts_
    ) external {
        // Check that all input arrays are of equal length
        if (ids_.length != recipients_.length || ids_.length != operators_.length || ids_.length != amounts_.length) {
            revert ArrayLengthMismatch();
        }

        // Proceed with claiming rewards for each set of parameters
        for (uint256 i; i < ids_.length; ++i) {
            claimRewards(ids_[i], recipients_[i], operators_[i], amounts_[i]);
        }
    }

    /// @inheritdoc IStakedMultiToken
    function claimRewards(uint16 distributionId, address to, address operator, uint256 amount)
        public
        onlyValidOperator(operator)
        whenNotPaused
    {
        address from = _msgSender();
        _updateCurrentUnclaimedRewards(from, operator, votingStake(from, operator));

        bytes32 key = rewardBalanceKey(distributionId, operator, from);
        uint256 unclaimedRewards = _rewardsBalances[key];

        uint256 amountToClaim = amount > unclaimedRewards ? unclaimedRewards : amount;

        // slither-disable-next-line incorrect-equality
        if (amountToClaim == 0) {
            revert ZeroAmount();
        }

        _rewardsBalances[key] = unclaimedRewards - amountToClaim;

        emit RewardsClaimed(from, to, operator, amountToClaim);

        DistributionData storage distribution = distributions[distributionId];

        // slither-disable-next-line arbitrary-send-erc20
        distribution.rewardToken.safeTransferFrom(distribution.rewardVault, to, amountToClaim);
    }

    /// @inheritdoc IStakedMultiToken
    function freezeOperator(address operator) external onlyOwner onlyOperatorNotFrozen(operator) {
        // before freezing, all distributions should be updated
        _updateAllDistribution(totalVotingStake());
        _freezeOperator(operator);
        totalFrozenAmount += totalSupply(operator);
        totalFrozenCooldownAmount += totalCooldownAmounts[operator];
        _clearVotes(operator);
    }

    /// @inheritdoc IStakedMultiToken
    function rewardBalance(uint16 distributionId, address operator, address staker) public view returns (uint256) {
        return _rewardsBalances[rewardBalanceKey(distributionId, operator, staker)];
    }

    /// @inheritdoc IStakedMultiToken
    function operatorFee(address operator)
        public
        view
        returns (uint40 cooldownEndTimestamp, uint16 bps, uint16 pendingBPS)
    {
        Fee memory fee = operatorConfig.fees[operator];
        cooldownEndTimestamp = fee.cooldownEndTimestamp;
        bps = fee.bps;
        pendingBPS = fee.pendingBPS;
    }

    /// @inheritdoc IStakedMultiToken
    function isActiveOperator(address operator) public view returns (bool) {
        return totalVotingStake(operator) >= minVotingStake && !isFrozenOperator(operator);
    }

    /// @inheritdoc IStakedMultiToken
    function totalActiveOperators() public view returns (uint256) {
        uint256 total;

        // Note: Assume the total number of operator is small
        address[] memory operatorArray = queryOperators(0, totalOperators());

        for (uint256 i; i < operatorArray.length; ++i) {
            if (isActiveOperator(operatorArray[i])) {
                unchecked {
                    ++total;
                }
            }
        }
        return total;
    }

    /// @inheritdoc IStakedMultiToken
    function balanceOf(address staker, address operator) public view returns (uint256) {
        return balanceOf(staker, addressToUint256(operator));
    }

    function totalVotingStake() public view returns (uint256) {
        return totalStakedAmount + totalFrozenCooldownAmount - totalFrozenAmount - totalCooldownAmount;
    }

    /// @inheritdoc IStakedMultiToken
    function totalVotingStake(address operator) public view returns (uint256) {
        return isFrozenOperator(operator) ? 0 : totalSupply(operator) - totalCooldownAmounts[operator];
    }

    /// @inheritdoc IStakedMultiToken
    function votingStake(address staker, address operator) public view returns (uint256) {
        return isFrozenOperator(operator) ? 0 : balanceOf(staker, operator) - cooldowns[operator][staker].amount;
    }

    /// @inheritdoc IStakedMultiToken
    function totalSupply(address operator) public view returns (uint256) {
        return totalSupply(addressToUint256(operator));
    }

    /// @inheritdoc IStakedMultiToken
    function activationThreshold() public view returns (uint256) {
        return (totalActiveOperators() * 2) / 3;
    }

    /// @inheritdoc IStakedMultiToken
    function isActiveAlert(uint128 voteCount) public view override(IStakedMultiToken, AlertSystem) returns (bool) {
        return voteCount >= activationThreshold();
    }

    /// @inheritdoc IStakedMultiToken
    function getAccruedRewards(uint16 distributionId, address staker, address operator)
        external
        view
        returns (uint256)
    {
        DistributionData storage distribution = distributions[distributionId];

        uint256 ditributionIndex = _getDistributionIndex(
            distributionId, distribution.index, _lastUpdateTimestamp(distribution), totalVotingStake()
        );
        uint256 userIndex = distribution.userIndices[operator][staker];

        uint256 accruedRewards = _getAccruedRewards(votingStake(staker, operator), ditributionIndex, userIndex);

        return accruedRewards;
    }

    /// @inheritdoc IStakedMultiToken
    function rewardBalanceKey(uint16 distributionId, address operator, address staker) public pure returns (bytes32) {
        return keccak256(abi.encode(distributionId, operator, staker));
    }

    /// @inheritdoc IStakedMultiToken
    function addressToUint256(address operator) public pure returns (uint256) {
        return uint256(uint160(operator));
    }

    ///////////////////////
    // Internal Functions
    ///////////////////////

    function _collectFee(uint16 distributionId, address operator, uint256 rewards)
        internal
        override
        returns (uint256)
    {
        DistributionData storage distribution = distributions[distributionId];
        IERC20 rewardToken = distribution.rewardToken;
        address rewardVault = distribution.rewardVault;

        // Calculate the protocol fee as a percentage of the rewards.
        uint256 protocolFeeAmount = (rewards * protocolConfig.fee.bps) / MAX_BPS;
        // Calculate the operator fee similarly as a percentage of the rewards.
        uint256 operatorFeeAmount = (rewards * operatorConfig.fees[operator].bps) / MAX_BPS;

        uint256 userRewards = rewards - (protocolFeeAmount + operatorFeeAmount);

        // Emit an event for the fee collection, providing transparency and traceability.
        emit CollectFee(distributionId, operator, protocolFeeAmount, operatorFeeAmount, userRewards);

        if (protocolFeeAmount > 0) {
            // slither-disable-next-line arbitrary-send-erc20
            rewardToken.safeTransferFrom(rewardVault, protocolConfig.vault, protocolFeeAmount);
        }

        if (operatorFeeAmount > 0) {
            // slither-disable-next-line arbitrary-send-erc20
            rewardToken.safeTransferFrom(rewardVault, operator, operatorFeeAmount);
        }

        // Return the remaining rewards after deducting both the protocol and operator fees.
        return userRewards;
    }

    function _setProtocolFeeBPS(uint16 feeBPS) internal {
        protocolConfig.fee.bps = feeBPS;
        emit SetProtocolFeeBPS(feeBPS);
    }

    function _setOperatorFeeBPS(address operator, uint16 feeBPS) internal {
        operatorConfig.fees[operator].bps = feeBPS;
        emit SetOperatorFeeBPS(operator, feeBPS);
    }

    function _stake(address from, address to, address operator, uint256 amount)
        internal
        onlyValidOperator(operator)
        onlyOperatorNotFrozen(operator)
    {
        emit Stake(from, to, operator, amount);

        // NOTE: Ensure users must transfer the stakedToken funds before receiving the funds and code execution from the receiver hook.
        stakedToken.safeTransferFrom(from, address(this), amount);

        _mint(to, addressToUint256(operator), amount, "");
        totalStakedAmount += amount;
    }

    function _unstake(address from, address to, address operator, uint256 amount)
        internal
        onlyValidOperator(operator)
    {
        emit Unstake(from, to, operator, amount);

        _burn(from, addressToUint256(operator), amount);
        totalStakedAmount -= amount;
        if (isFrozenOperator(operator)) {
            totalFrozenAmount -= amount;
        }

        if (!isActiveOperator(operator)) {
            _clearVotes(operator);
        }

        IERC20(stakedToken).safeTransfer(to, amount);
    }

    function _clearVotes(address operator) internal {
        // clear all the votes where the alert is not valid yet.
        bytes32[] memory hashes = votedAlerts[operator];
        for (uint256 i; i < hashes.length; ++i) {
            bytes32 messageHash = hashes[i];

            AlertData storage currentAlert = alerts[messageHash];
            // NOTE: vote count can be zero when admin has removed this alert
            if (!currentAlert.isActive && currentAlert.voteCount > 0) {
                currentAlert.voteCount--;
                delete currentAlert.voted[currentAlert.resetCount][operator];
            }
        }
        // reinitialize it
        votedAlerts[operator] = new bytes32[](0);
    }

    function _vote(bytes32 messageHash, uint40 expiry, address nodeKey) internal override(AlertSystem) {
        address operator = operators[nodeKey];

        // Revert if the operator is frozen
        if (isFrozenOperator(operator)) {
            revert FrozenOperator();
        }

        // Revert if the operator has less stake than the minimum required to vote
        if (totalVotingStake(operator) < minVotingStake) {
            revert LessThanMinStakeToVote();
        }

        super._vote(messageHash, expiry, nodeKey);
    }

    /// @dev Updates the user state related with his accrued rewards
    /// @param user Address of the user
    /// @param operator The identifier of the staking pool
    /// @param votingStake_ The current voting stake of the user
    function _updateCurrentUnclaimedRewards(address user, address operator, uint256 votingStake_) internal {
        for (uint16 distributionId = 1; distributionId <= totalDistributions; ++distributionId) {
            uint256 accruedRewards = _updateUser(distributionId, user, operator, votingStake_, totalVotingStake());
            if (accruedRewards != 0) {
                bytes32 key = rewardBalanceKey(distributionId, operator, user);
                _rewardsBalances[key] += accruedRewards;
                emit RewardsAccrued(user, operator, accruedRewards);
            }
        }
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override
        whenNotPaused
    {
        // When safeTransferFrom
        // Update unclaimed rewards first
        if (from != address(0) && to != address(0)) {
            // Assume the length of ids and values are the same.
            for (uint256 i; i < ids.length; ++i) {
                address operator = address(uint160(ids[i]));

                // Sender
                _updateCurrentUnclaimedRewards(from, operator, votingStake(from, operator));

                // Recipient
                if (from != to) {
                    _updateCurrentUnclaimedRewards(to, operator, votingStake(to, operator));
                }
            }
        }

        super._update(from, to, ids, values);

        // NOTE: cooldown amount cannot be transferred.
        // cooldown amount only can be unstaked.
        // balance - cooldown amount = votingStake
        for (uint256 i; i < ids.length; ++i) {
            address operator = address(uint160(ids[i]));
            CooldownSnapshot storage currentCooldown = cooldowns[operator][from];
            // Make sure the cooldown amount is not greater than the balance
            if (currentCooldown.amount > balanceOf(from, operator)) {
                revert InsufficientAmount();
            }
        }
    }
}


// File: lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol
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


// File: lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol
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


// File: lib/openzeppelin-contracts/contracts/utils/Address.sol
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/extensions/ERC1155Supply.sol)

pragma solidity ^0.8.20;

import {ERC1155Upgradeable} from "../ERC1155Upgradeable.sol";
import {Initializable} from "../../../proxy/utils/Initializable.sol";

/**
 * @dev Extension of ERC1155 that adds tracking of total supply per id.
 *
 * Useful for scenarios where Fungible and Non-fungible tokens have to be
 * clearly identified. Note: While a totalSupply of 1 might mean the
 * corresponding is an NFT, there is no guarantees that no other token with the
 * same id are not going to be minted.
 *
 * NOTE: This contract implies a global limit of 2**256 - 1 to the number of tokens
 * that can be minted.
 *
 * CAUTION: This extension should not be added in an upgrade to an already deployed contract.
 */
abstract contract ERC1155SupplyUpgradeable is Initializable, ERC1155Upgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC1155Supply
    struct ERC1155SupplyStorage {
        mapping(uint256 id => uint256) _totalSupply;
        uint256 _totalSupplyAll;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC1155Supply")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC1155SupplyStorageLocation = 0x4a593662ee04d27b6a00ebb31be7fe0c102c2ade82a7c5d764f2df05dc4e2800;

    function _getERC1155SupplyStorage() private pure returns (ERC1155SupplyStorage storage $) {
        assembly {
            $.slot := ERC1155SupplyStorageLocation
        }
    }

    function __ERC1155Supply_init() internal onlyInitializing {
    }

    function __ERC1155Supply_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Total value of tokens in with a given id.
     */
    function totalSupply(uint256 id) public view virtual returns (uint256) {
        ERC1155SupplyStorage storage $ = _getERC1155SupplyStorage();
        return $._totalSupply[id];
    }

    /**
     * @dev Total value of tokens.
     */
    function totalSupply() public view virtual returns (uint256) {
        ERC1155SupplyStorage storage $ = _getERC1155SupplyStorage();
        return $._totalSupplyAll;
    }

    /**
     * @dev Indicates whether any token exist with a given id, or not.
     */
    function exists(uint256 id) public view virtual returns (bool) {
        return totalSupply(id) > 0;
    }

    /**
     * @dev See {ERC1155-_update}.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        ERC1155SupplyStorage storage $ = _getERC1155SupplyStorage();
        super._update(from, to, ids, values);

        if (from == address(0)) {
            uint256 totalMintValue = 0;
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 value = values[i];
                // Overflow check required: The rest of the code assumes that totalSupply never overflows
                $._totalSupply[ids[i]] += value;
                totalMintValue += value;
            }
            // Overflow check required: The rest of the code assumes that totalSupplyAll never overflows
            $._totalSupplyAll += totalMintValue;
        }

        if (to == address(0)) {
            uint256 totalBurnValue = 0;
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 value = values[i];

                unchecked {
                    // Overflow not possible: values[i] <= balanceOf(from, ids[i]) <= totalSupply(ids[i])
                    $._totalSupply[ids[i]] -= value;
                    // Overflow not possible: sum_i(values[i]) <= sum_i(totalSupply(ids[i])) <= totalSupplyAll
                    totalBurnValue += value;
                }
            }
            unchecked {
                // Overflow not possible: totalBurnValue = sum_i(values[i]) <= sum_i(totalSupply(ids[i])) <= totalSupplyAll
                $._totalSupplyAll -= totalBurnValue;
            }
        }
    }
}


// File: src/interfaces/IStakedMultiToken.sol
// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.23;

/// @title IStakedMultiToken Interface
/// @notice Interface for the Staked MultiToken system, allowing for token staking, operator management, and reward distribution.
interface IStakedMultiToken {
    ////////////////
    // Events
    ////////////////

    event OperatorRegistered(address operator);
    event Stake(address indexed from, address indexed onBehalfOf, address operator, uint256 assets);

    event RewardsAccrued(address user, address operator, uint256 amount);
    event RewardsClaimed(address indexed from, address indexed to, address operator, uint256 amount);

    event CooldownToUnstake(address indexed user, address indexed operator, uint256 amount);
    event CooldownToUpdateProtocolFee(uint16 feeBPS, uint40 cooldownEndTimestamp);
    event CooldownToUpdateOperatorFee(address operator, uint16 feeBPS, uint40 cooldownEndTimestamp);

    event Unstake(address indexed from, address indexed to, address operator, uint256 assets);
    event SetOperatorFeeBPS(address operator, uint16 feeBPS);
    event SetProtocolFeeBPS(uint16 feeBPS);

    event SetMinVotingStake(uint256 minVotingStake);
    event SetCooldownSecForUnstaking(uint40 cooldownSeconds);
    event SetCooldownSecForOperatorFee(uint40 cooldownSeconds);
    event SetCooldownSecForProtocolFee(uint40 cooldownSeconds);
    event CollectFee(
        uint16 distributionId, address operator, uint256 protocolFee, uint256 operatorFee, uint256 userRewards
    );

    ////////////////
    // Functions
    ////////////////

    /// @notice Registers a new operator and sets their fee in basis points
    /// @param operator The address of the operator to register
    /// @param feeBPS The fee in basis points
    function registerOperator(address operator, uint16 feeBPS) external;

    /// @notice Freezes an operator, preventing them from performing certain actions
    /// @param operator The address of the operator to freeze
    function freezeOperator(address operator) external;

    /// @notice Gets the balance of a staker for a specific operator
    /// @param staker The address of the staker
    /// @param operator The address of the operator
    /// @return The balance of staked tokens
    function balanceOf(address staker, address operator) external view returns (uint256);

    /// @notice Gets the voting stake of a staker for a specific operator
    /// @param staker The address of the staker
    /// @param operator The address of the operator
    /// @return The voting stake amount
    function votingStake(address staker, address operator) external view returns (uint256);

    /// @notice Gets the total voting stake of a operator
    /// @param operator The address of the operator
    /// @return The total voting stake amount
    function totalVotingStake(address operator) external view returns (uint256);

    /// @notice Gets the total supply of staked tokens for a specific operator
    /// @param operator The address of the operator
    /// @return The total supply of staked tokens
    function totalSupply(address operator) external view returns (uint256);

    /// @notice Sets the minimum voting stake
    /// @param minVotingStake_ The minimum voting stake
    function setMinVotingStake(uint256 minVotingStake_) external;

    /// @notice Sets the cooldown seconds for operator fee updates
    /// @param cooldownSeconds_ The cooldown period in seconds
    function setCooldownSecForOperatorFee(uint40 cooldownSeconds_) external;

    /// @notice Sets the cooldown seconds for protocol fee updates
    /// @param cooldownSeconds_ The cooldown period in seconds
    function setCooldownSecForProtocolFee(uint40 cooldownSeconds_) external;

    /// @notice Sets the general cooldown period in seconds
    /// @param cooldownSeconds_ The cooldown period in seconds
    function setCooldownSecForUnstaking(uint40 cooldownSeconds_) external;

    /// @notice Initiates the cooldown period for protocol fee updates
    /// @param feeBPS The fee in basis points
    function cooldownToUpdateProtocolFee(uint16 feeBPS) external;

    /// @notice Initiates the cooldown period for operator fee updates
    /// @param feeBPS The fee in basis points
    function cooldownToUpdateOperatorFee(uint16 feeBPS) external;

    /// @notice Sets the protocol fee in basis points
    function setProtocolFeeBPS() external;

    /// @notice Sets the operator fee in basis points
    function setOperatorFeeBPS() external;

    /// @notice Claims accrued rewards for a staker
    /// @param distributionId The distribution ID
    /// @param to The address to send rewards to
    /// @param operator The address of the operator
    /// @param amount The amount of rewards to claim
    function claimRewards(uint16 distributionId, address to, address operator, uint256 amount) external;

    /// @notice Claims accrued rewards for multiple stakers in a single transaction.
    /// @param ids Array of distribution IDs for which rewards are being claimed.
    /// @param recipients Array of addresses to receive the claimed rewards, corresponding to each distribution ID.
    /// @param operators Array of operator addresses associated with each reward distribution, managing the distribution rules and potentially fees.
    /// @param amounts Array of amounts of rewards to be claimed for each distribution ID.
    function claimRewardsBatch(
        uint16[] calldata ids,
        address[] calldata recipients,
        address[] calldata operators,
        uint256[] calldata amounts
    ) external;

    /// @notice Stakes tokens on behalf of a user
    /// @param to The address on whose behalf tokens are being staked
    /// @param operator The address of the operator
    /// @param amount The amount of tokens to stake
    function stake(address to, address operator, uint256 amount) external;

    /// @notice Switches voting power from one operator to another for a specified amount.
    /// @param fromOperator The address of the current operator from which the voting power is being moved.
    /// @param toOperator The address of the new operator to which the voting power will be moved.
    /// @param amount The amount of voting power to transfer.
    function switchOperator(address fromOperator, address toOperator, uint256 amount) external;

    /// @notice Initiates the cooldown period for a user's staked tokens
    /// @param operator The address of the operator
    /// @param amountToAdd The amount of tokens to cooldown. This is additive.
    function cooldownToUnstake(address operator, uint256 amountToAdd) external;

    /// @notice Unstakes tokens and stops earning rewards
    /// @param to The address to unstake tokens to
    /// @param operator The address of the operator
    /// @param amount The amount of tokens to unstake
    function unstake(address to, address operator, uint256 amount) external;

    /// @notice Gets the accrued rewards for a staker within a specific distribution and operator context
    /// @param distributionId The distribution ID for which to query rewards
    /// @param staker The address of the staker
    /// @param operator The address of the operator
    /// @return The amount of accrued rewards
    function getAccruedRewards(uint16 distributionId, address staker, address operator)
        external
        view
        returns (uint256);

    /// @notice Gets the reward balance for a specific distribution, operator, and staker combination
    /// @param distributionId The ID of the distribution for which the reward balance is queried
    /// @param operator The address of the operator
    /// @param staker The address of the staker
    /// @return The amount of accrued rewards
    function rewardBalance(uint16 distributionId, address operator, address staker) external view returns (uint256);

    /// Gets operator fee information
    /// @param operator The address of the operator
    function operatorFee(address operator)
        external
        view
        returns (uint40 cooldownEndTimestamp, uint16 bps, uint16 pendingBPS);

    /// @notice Checks if an operator is active based on their total voting stake.
    /// @dev An operator is considered active if their total voting stake is at least the minimum required.
    /// @param operator The address of the operator to check.
    /// @return True if the operator's total voting stake is at least the minimum required, false otherwise.
    function isActiveOperator(address operator) external view returns (bool);

    /// @notice Counts the total number of active operators.
    /// @dev Iterates through all operators and counts those that are active.
    /// @return The total number of active operators.
    function totalActiveOperators() external view returns (uint256);

    /// @notice Calculates the activation threshold for alerts.
    /// @dev The activation threshold is determined as two-thirds of the total number of active operators.
    /// @return The calculated activation threshold.
    function activationThreshold() external view returns (uint256);

    /// @notice Determines if an alert is active based on the given vote count.
    /// @dev An alert is considered active if the vote count meets or exceeds the activation threshold.
    /// @param voteCount The number of votes to check against the activation threshold.
    /// @return True if the vote count meets or exceeds the activation threshold, false otherwise.
    function isActiveAlert(uint128 voteCount) external view returns (bool);

    /// @notice Generates a unique key for a reward balance based on distribution ID, operator, and staker
    /// @param distributionId The ID of the distribution
    /// @param operator The address of the operator
    /// @param staker The address of the staker
    /// @return A unique key for querying reward balances
    function rewardBalanceKey(uint16 distributionId, address operator, address staker)
        external
        pure
        returns (bytes32);

    /// @notice Converts an address to a `uint256` representation
    /// @param operator The address to convert
    /// @return The `uint256` representation of the address
    function addressToUint256(address operator) external pure returns (uint256);
}


// File: src/RewardDistribution.sol
// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.23;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ZeroAddress, InvalidDistributionStartTime, InvalidDistributionEndTime} from "./Errors.sol";
import {OperatorRegistry} from "./OperatorRegistry.sol";
import {IRewardDistribution} from "./interfaces/IRewardDistribution.sol";

struct DistributionData {
    uint128 emissionPerSecond;
    IERC20 rewardToken;
    /// @dev Address to pull from the rewards, needs to have approved this contract
    address rewardVault;
    uint40 startTime;
    uint40 endTime;
    uint256 index;
    uint40 updateTimestamp;
    mapping(address => mapping(address => uint256)) userIndices;
}

/// @dev Accounting contract to manage staking distributions
/// This is adapted from https://github.com/bgd-labs/aave-stk-v1-5/blob/8867dd5b1137d4d46acd9716fe98759cb16b1606/src/contracts/AaveDistributionManager.sol
// solhint-disable not-rely-on-time
abstract contract RewardDistribution is OperatorRegistry, IRewardDistribution {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION_FACTOR = 1e18;
    uint16 public totalDistributions;

    // Distribution ID => Distribution Data
    mapping(uint16 => DistributionData) public distributions;

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    // slither-disable-next-line unused-state
    uint256[48] private __gap;

    modifier onlyValidDistributionEndTime(uint40 endTime) {
        if (endTime < block.timestamp) {
            revert InvalidDistributionEndTime();
        }
        _;
    }

    ///////////////////////
    // External Functions
    ///////////////////////

    /// @inheritdoc IRewardDistribution
    function createDistribution(
        uint128 emissionPerSecond_,
        uint40 startTime_,
        uint40 endTime_,
        IERC20 rewardToken_,
        address rewardVault_
    ) external onlyOwner onlyValidDistributionEndTime(endTime_) {
        if (startTime_ <= block.timestamp) {
            revert InvalidDistributionStartTime();
        }

        if (startTime_ >= endTime_) {
            revert InvalidDistributionEndTime();
        }

        if (address(rewardToken_) == address(0)) {
            revert ZeroAddress();
        }
        if (rewardVault_ == address(0)) {
            revert ZeroAddress();
        }

        totalDistributions++;
        uint16 distributionId = totalDistributions;

        DistributionData storage distribution = distributions[distributionId];

        distribution.emissionPerSecond = emissionPerSecond_;
        distribution.startTime = startTime_;
        distribution.endTime = endTime_;
        distribution.rewardToken = rewardToken_;
        distribution.rewardVault = rewardVault_;
    }

    /// @inheritdoc IRewardDistribution
    function setDistributionEnd(uint16 distributionId, uint40 endTime)
        external
        onlyOwner
        onlyValidDistributionEndTime(endTime)
    {
        DistributionData storage distribution = distributions[distributionId];

        if (endTime <= distribution.startTime) {
            revert InvalidDistributionEndTime();
        }

        distribution.endTime = endTime;
    }

    /// @inheritdoc IRewardDistribution
    function distributionIndex(uint16 distributionId) external view returns (uint256) {
        return distributions[distributionId].index;
    }

    /// @inheritdoc IRewardDistribution
    function distributionUserIndex(uint16 distributionId, address operator, address staker)
        external
        view
        returns (uint256)
    {
        return distributions[distributionId].userIndices[operator][staker];
    }

    ///////////////////////
    // Internal Functions
    ///////////////////////

    /// @dev Updates the distribution index based on time elapsed and emission rate, respecting the distribution period and supply constraints.
    /// @param distributionId Identifier for the specific distribution.
    /// @param currentIndex The current index reflecting the accumulated distribution up to the last update.
    /// @param lastUpdateTimestamp_ Timestamp of the last update, used to calculate time elapsed.
    /// @param totalSupply The total token supply.
    /// @return The updated index, or the current index if conditions prevent recalculation (e.g., no time elapsed, emission rate or total supply is zero, outside distribution period).
    function _getDistributionIndex(
        uint16 distributionId,
        uint256 currentIndex,
        uint40 lastUpdateTimestamp_,
        uint256 totalSupply
    ) internal view returns (uint256) {
        DistributionData storage distribution = distributions[distributionId];
        if (
            // slither-disable-next-line incorrect-equality
            lastUpdateTimestamp_ == block.timestamp || distribution.emissionPerSecond == 0 || totalSupply == 0
                || block.timestamp < distribution.startTime || lastUpdateTimestamp_ >= distribution.endTime
        ) {
            return currentIndex;
        }

        uint256 currentTimestamp = block.timestamp > distribution.endTime ? distribution.endTime : block.timestamp;

        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp_;

        uint256 newIndex = (distribution.emissionPerSecond * timeDelta * PRECISION_FACTOR) / totalSupply;

        return newIndex + currentIndex;
    }

    /// @dev Iterates and updates each distribution's state for a given operator.
    /// @param totalStaked Total amount staked, affecting distribution indices.
    function _updateAllDistribution(uint256 totalStaked) internal {
        for (uint16 distributionId = 1; distributionId <= totalDistributions; ++distributionId) {
            _updateDistribution(distributionId, totalStaked);
        }
    }

    /// @dev Updates the state of one distribution, mainly rewards index and timestamp
    /// @param totalStaked Current total of staked assets for this distribution
    /// @return The new distribution index
    function _updateDistribution(uint16 distributionId, uint256 totalStaked) internal returns (uint256) {
        DistributionData storage distribution = distributions[distributionId];

        uint256 oldIndex = distribution.index;
        uint40 lastUpdateTimestamp = _lastUpdateTimestamp(distribution);

        // Note that it's inclusive
        if (distribution.endTime <= lastUpdateTimestamp || block.timestamp <= lastUpdateTimestamp) {
            return oldIndex;
        }

        uint256 newIndex = _getDistributionIndex(distributionId, oldIndex, lastUpdateTimestamp, totalStaked);

        if (newIndex != oldIndex) {
            distribution.index = newIndex;
            emit DistributionIndexUpdated(distributionId, newIndex);
        }

        distribution.updateTimestamp = uint40(block.timestamp);

        return newIndex;
    }

    /// @dev Updates the state of an user in a distribution
    /// @param user The user's address
    /// @param operator The id of the reference asset of the distribution
    /// @param stakedByUser Amount of tokens staked by the user in the distribution at the moment
    /// @param totalStaked Total tokens staked in the distribution
    /// @return The accrued rewards for the user until the moment
    function _updateUser(
        uint16 distributionId,
        address user,
        address operator,
        uint256 stakedByUser,
        uint256 totalStaked
    ) internal returns (uint256) {
        DistributionData storage distribution = distributions[distributionId];

        uint256 newIndex = _updateDistribution(distributionId, totalStaked);
        uint256 userIndex = distribution.userIndices[operator][user];

        uint256 accruedRewards = 0;

        if (userIndex != newIndex) {
            if (stakedByUser != 0) {
                accruedRewards = _getAccruedRewards(stakedByUser, newIndex, userIndex);
            }

            distribution.userIndices[operator][user] = newIndex;
            emit UserIndexUpdated(distributionId, user, operator, newIndex);
        }

        if (accruedRewards > 0) {
            accruedRewards = _collectFee(distributionId, operator, accruedRewards);
        }

        return accruedRewards;
    }

    function _lastUpdateTimestamp(DistributionData storage distribution) internal view returns (uint40) {
        return distribution.updateTimestamp < distribution.startTime
            ? distribution.startTime
            : distribution.updateTimestamp;
    }

    /// @dev Internal function for the calculation of user's rewards on a distribution
    /// @param stakedByUser Amount staked by the user on a distribution
    /// @param distributionIndex_ Current index of the distribution
    /// @param userIndex Index stored for the user, representation his staking moment
    /// @return The rewards
    function _getAccruedRewards(uint256 stakedByUser, uint256 distributionIndex_, uint256 userIndex)
        internal
        pure
        returns (uint256)
    {
        uint256 indexDelta = (distributionIndex_ - userIndex);
        return (stakedByUser * indexDelta) / PRECISION_FACTOR;
    }

    /// @dev Collects fees from the rewards and distributes them to the protocol and the operator.
    /// The fees are determined based on the `FEE_BPS` constant.
    /// @param distributionId Distribution ID
    /// @param operator The identifier of the asset or operation for which the fees are being collected.
    /// @param rewards The total amount of rewards from which fees will be deducted.
    /// @return The remaining rewards after deducting the protocol and operator fees.
    function _collectFee(uint16 distributionId, address operator, uint256 rewards) internal virtual returns (uint256);
}


// File: src/AlertSystem.sol
// SPDX-License-Identifier: agpl-3.0
// Copyright (c) 2024, Alt Research Ltd.
pragma solidity =0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {
    NotOperator,
    AlreadyRegistered,
    AlreadyAuthenticated,
    AlreadyRemoved,
    InvalidExpiryDuration,
    InvalidStartIndex,
    OperatorMismatch,
    NodeKeyNotAuthenticated,
    AlreadyVoted,
    AlreadyActiveAlert
} from "./Errors.sol";
import {IAlertSystem} from "./interfaces/IAlertSystem.sol";
import {OperatorRegistry} from "./OperatorRegistry.sol";

// solhint-disable not-rely-on-time, var-name-mixedcase
abstract contract AlertSystem is IAlertSystem, OperatorRegistry {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint40 public constant MAX_EXPIRY = type(uint40).max;

    // A struct for storing alert data
    struct AlertData {
        uint128 voteCount; // The total number of votes for this alert
        uint40 expiry; // The timestamp when the alert was created
        uint16 resetCount;
        bool isActive;
        // reset count => operator => voted
        mapping(uint16 => mapping(address => bool)) voted; // Tracks whether an address has voted on this alert
    }

    EnumerableSet.Bytes32Set private _messageHashes;

    uint16 public expiryDuration;

    // Maps operator addresses to unique node keys for secure one-to-one authentication.
    mapping(address => address) public nodeKeys;

    // Maps node keys back to operators, ensuring each node is tied to a single operator.
    mapping(address => address) public operators;

    /// @notice hash of message to alert data
    mapping(bytes32 => AlertData) public alerts;

    /// @notice operator => voted alert message hashes
    mapping(address => bytes32[]) public votedAlerts;

    uint256[44] private __gap;

    modifier onlyAuthenticatedNodeKey() {
        if (!isAuthenticated(_msgSender())) {
            revert NodeKeyNotAuthenticated();
        }
        _;
    }

    // solhint-disable-next-line func-name-mixedcase
    function __AlertSystem_init(uint16 initialExpiryDuration_) internal onlyInitializing {
        expiryDuration = initialExpiryDuration_;
    }

    ///////////////////////
    // External Functions
    ///////////////////////

    /// @inheritdoc IAlertSystem
    function removeAlert(bytes32 messageHash) external onlyOwner {
        // slither-disable-next-line mapping-deletion
        delete alerts[messageHash];
        _messageHashes.remove(messageHash);
        emit AlertRemoved(messageHash, _msgSender());
    }

    /// @inheritdoc IAlertSystem
    function setExpiryDuration(uint16 duration) external onlyOwner {
        expiryDuration = duration;
        emit ExpiryDurationUpdated(duration, _msgSender());
    }

    /// @inheritdoc IAlertSystem
    function registerNodeKey(address operator) external whenNotPaused {
        if (!isOperator(operator)) {
            revert NotOperator();
        }

        address nodeKey = _msgSender();

        if (nodeKeys[operator] != address(0)) {
            revert AlreadyRegistered();
        }

        operators[nodeKey] = operator;
        emit NodeKeyRegistered(nodeKey, operator);
    }

    /// @inheritdoc IAlertSystem
    function authenticateNodeKey(address nodeKey) external onlyOperator whenNotPaused {
        address operator = _msgSender();

        if (operators[nodeKey] != operator) {
            revert OperatorMismatch();
        }

        if (nodeKeys[operator] == nodeKey) {
            revert AlreadyAuthenticated();
        }

        nodeKeys[operator] = nodeKey;
        emit NodeKeyAuthenticated(nodeKey, operator);
    }

    function removeNodeKey() external onlyOperator whenNotPaused {
        address operator = _msgSender();
        address oldNodeKey = nodeKeys[operator];

        if (oldNodeKey == address(0)) {
            revert AlreadyRemoved();
        }

        // Clear both
        delete nodeKeys[operator];
        delete operators[oldNodeKey];

        emit NodeKeyRemoved(oldNodeKey, operator);
    }

    /// @inheritdoc IAlertSystem
    function voteForBlockAlert(uint256 blockNumber) external whenNotPaused onlyAuthenticatedNodeKey {
        // max expiry
        uint40 expiry = type(uint40).max;
        address nodeKey = _msgSender();
        _vote(keccak256(abi.encode(blockNumber)), expiry, nodeKey);
    }

    /// @inheritdoc IAlertSystem
    function voteForMessageAlert(string memory message) external whenNotPaused onlyAuthenticatedNodeKey {
        uint40 expiry = uint40(block.timestamp) + uint40(expiryDuration);
        address nodeKey = _msgSender();
        _vote(keccak256(abi.encode(message)), expiry, nodeKey);
    }
    /// @inheritdoc IAlertSystem

    function getVotedAlerts(address operator) external view returns (bytes32[] memory) {
        return votedAlerts[operator];
    }

    /// @inheritdoc IAlertSystem
    function isAuthenticated(address nodeKey) public view returns (bool) {
        return nodeKeys[operators[nodeKey]] == nodeKey;
    }

    /// @inheritdoc IAlertSystem
    function isActiveAlert(uint128 voteCount) public view virtual returns (bool);

    /// @inheritdoc IAlertSystem
    function totalAlerts() public view returns (uint256) {
        return _messageHashes.length();
    }

    /// @inheritdoc IAlertSystem
    function contains(bytes32 messageHash) public view returns (bool) {
        return _messageHashes.contains(messageHash);
    }

    /// @inheritdoc IAlertSystem
    function queryMessageHashes(uint256 start, uint256 querySize) external view returns (bytes32[] memory) {
        uint256 length = totalAlerts();

        if (start >= length) {
            revert InvalidStartIndex();
        }

        uint256 end = start + querySize;

        if (end > length) {
            end = length;
        }

        bytes32[] memory output = new bytes32[](end - start);

        for (uint256 i = start; i < end; ++i) {
            output[i - start] = _messageHashes.at(i);
        }

        return output;
    }

    ///////////////////////
    // Internal Functions
    ///////////////////////

    function _vote(bytes32 messageHash, uint40 expiry, address nodeKey) internal virtual {
        AlertData storage currentAlert = alerts[messageHash];

        if (currentAlert.isActive) {
            revert AlreadyActiveAlert();
        }

        if (currentAlert.expiry != 0 && currentAlert.expiry < block.timestamp) {
            currentAlert.resetCount++;
            currentAlert.voteCount = 0;
        }

        address operator = operators[nodeKey];
        uint16 resetCount = currentAlert.resetCount;
        // Ensure voting can be done only once per operator per alert
        if (currentAlert.voted[resetCount][operator]) {
            revert AlreadyVoted();
        }

        // Mark the sender as having voted and increment the vote count
        currentAlert.voted[resetCount][operator] = true;
        currentAlert.voteCount++;
        currentAlert.expiry = expiry;

        bool isActive = isActiveAlert(currentAlert.voteCount);
        currentAlert.isActive = isActive;

        if (!contains(messageHash)) {
            _messageHashes.add(messageHash);
        }

        emit AlertVoted(messageHash, operator, currentAlert.voteCount, isActive);

        bytes32[] memory currentVotedAlerts = votedAlerts[operator];

        bool voted;
        for (uint256 i; i < currentVotedAlerts.length; ++i) {
            if (messageHash == currentVotedAlerts[i]) {
                voted = true;
                break;
            }
        }

        if (!voted) {
            votedAlerts[operator].push(messageHash);
        }
    }
}


// File: src/OperatorRegistry.sol
// SPDX-License-Identifier: agpl-3.0
// Copyright (c) 2024, Alt Research Ltd.
pragma solidity =0.8.23;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IOperatorRegistry} from "./interfaces/IOperatorRegistry.sol";
import {FrozenOperator, NotOperator, InvalidStartIndex} from "./Errors.sol";

// solhint-disable not-rely-on-time, var-name-mixedcase
abstract contract OperatorRegistry is PausableUpgradeable, Ownable2StepUpgradeable, IOperatorRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Set of operator address for enumeration
    EnumerableSet.AddressSet private _operators;
    mapping(address => bool) private frozenOperators;

    uint256[48] private __gap;

    modifier onlyOperator() {
        if (!isOperator(_msgSender())) {
            revert NotOperator();
        }
        _;
    }

    modifier onlyOperatorNotFrozen(address operator) {
        // Revert if the operator is frozen
        if (isFrozenOperator(operator)) {
            revert FrozenOperator();
        }
        _;
    }

    ///////////////////////
    // External Functions
    ///////////////////////

    /// @inheritdoc IOperatorRegistry
    function pause() external onlyOwner {
        _pause();
    }

    /// @inheritdoc IOperatorRegistry
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc IOperatorRegistry
    function totalOperators() public view returns (uint256) {
        return _operators.length();
    }

    /// @inheritdoc IOperatorRegistry
    function isOperator(address operator) public view returns (bool) {
        return _operators.contains(operator);
    }

    /// @inheritdoc IOperatorRegistry
    function queryOperators(uint256 start, uint256 querySize) public view returns (address[] memory) {
        uint256 length = totalOperators();

        if (start >= length) {
            revert InvalidStartIndex();
        }

        uint256 end = start + querySize;

        if (end > length) {
            end = length;
        }

        address[] memory output = new address[](end - start);

        for (uint256 i = start; i < end; ++i) {
            output[i - start] = _operators.at(i);
        }

        return output;
    }

    function isFrozenOperator(address operator) public view returns (bool) {
        return frozenOperators[operator];
    }

    ///////////////////////
    // Internal Functions
    ///////////////////////

    function _addOperator(address operator) internal {
        _operators.add(operator);
        emit OperatorAdded(operator, _msgSender());
    }

    function _freezeOperator(address operator) internal {
        frozenOperators[operator] = true;
        emit Frozen(operator, _msgSender());
    }
}


// File: src/Errors.sol
// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.23;

error ArrayLengthMismatch();
error FrozenOperator();
error InsufficientAmount();
error ZeroVotingStake();
error ZeroAddress();
error NotOperator();
error NodeKeyNotAuthenticated();
error LessThanMinStakeToVote();
error AlreadyVoted();
error AlreadyActiveAlert();
error InvalidExpiryDuration();
error OperatorMismatch();
error InvalidStartIndex();
error InvalidStakingStartTime();
error InvalidDistributionStartTime();
error InvalidDistributionEndTime();
error AlreadyRegistered();
error AlreadyAuthenticated();
error AlreadyRemoved();
error InvalidBPS();
error ZeroExchangeRate();
error ZeroAmount();
error InvalidCooldownAmount();
error InsufficientCooldown();
error ZeroUnstakeable();
error InvalidDestination();
error GreaterThanMaxCooldownSec();
error StakingNotStartedYet();
error NotSupported();


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol
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


// File: src/interfaces/IRewardDistribution.sol
// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Interface for RewardDistribution
/// @notice This interface outlines the public and external functions for managing distribution of rewards in a staking contract.
interface IRewardDistribution {
    ////////////////
    // Events
    ////////////////

    /// @notice Indicates a distribution index was updated
    /// @dev This event should be emitted when a distribution's index is updated
    /// @param distributionID The ID of the distribution being updated
    /// @param index The new index after the update
    event DistributionIndexUpdated(uint256 indexed distributionID, uint256 index);

    /// @notice Indicates a user's index in a distribution was updated
    /// @dev This event should be emitted when a user's index within a distribution is updated
    /// @param distributionID The ID of the distribution being referenced
    /// @param user The address of the user for whom the index was updated
    /// @param operator The address of the operator associated with the distribution
    /// @param index The new user-specific index after the update
    event UserIndexUpdated(
        uint256 indexed distributionID, address indexed user, address indexed operator, uint256 index
    );

    ////////////////
    // Functions
    ////////////////

    /// @notice Creates a new distribution
    /// @param emissionPerSecond The amount of reward token emitted per second
    /// @param startTime The start time of the distribution in UNIX timestamp
    /// @param endTime The end time of the distribution in UNIX timestamp
    /// @param rewardToken The ERC20 token to be used as the reward. The rewardToken must be strictly ERC-20 compliant.
    /// @param rewardVault The address from which the reward tokens will be distributed
    /// @dev Emits a DistributionIndexUpdated event on success
    function createDistribution(
        uint128 emissionPerSecond,
        uint40 startTime,
        uint40 endTime,
        IERC20 rewardToken,
        address rewardVault
    ) external;

    /// @notice Sets the end time for an existing distribution
    /// @param distributionId The ID of the distribution to be modified
    /// @param endTime The new end time for the distribution
    /// @dev This action can only be performed by the owner of the contract
    function setDistributionEnd(uint16 distributionId, uint40 endTime) external;

    /// @notice Gets the current index of a distribution for an operator
    /// @param distributionId The ID of the distribution
    /// @return The current index of the distribution
    function distributionIndex(uint16 distributionId) external view returns (uint256);

    /// @notice Gets the user-specific index within a distribution for an operator-staker pair
    /// @param distributionId The ID of the distribution
    /// @param operator The address of the operator
    /// @param staker The address of the staker
    /// @return The current user-specific index within the distribution
    function distributionUserIndex(uint16 distributionId, address operator, address staker)
        external
        view
        returns (uint256);
}


// File: lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol
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


// File: src/interfaces/IAlertSystem.sol
// SPDX-License-Identifier: agpl-3.0
// Copyright (c) 2024, Alt Research Ltd.
pragma solidity =0.8.23;

/// @title Interface for AlertSystem
/// @notice This interface outlines the functionalities for managing alerts and votes in a contract system.
interface IAlertSystem {
    ///////////////////////
    // Events
    ///////////////////////

    /// @notice Emitted when the expiry duration is updated
    /// @param duration The new expiry duration
    /// @param admin The admin who updated the duration
    event ExpiryDurationUpdated(uint16 duration, address admin);

    /// @notice Emitted when an alert is removed
    /// @param messageHash The hash of the message corresponding to the removed alert
    /// @param admin The admin who removed the alert
    event AlertRemoved(bytes32 messageHash, address admin);

    /// @notice Emitted when a vote is cast for an alert
    /// @param messageHash The hash of the message corresponding to the alert voted on
    /// @param operator The operator address
    /// @param voteCount The current vote count after the vote
    /// @param isActive Whether the alert is active after the vote
    event AlertVoted(bytes32 messageHash, address operator, uint128 voteCount, bool isActive);

    /// @notice Emitted when a node key is registered for an operator
    /// @param nodeKey The node key that is registered
    /// @param operator The operator associated with the node key
    event NodeKeyRegistered(address nodeKey, address operator);

    /// @notice Emitted when a node key is authenticated
    /// @param nodeKey The node key authenticated
    /// @param operator The operator associated with the node key
    event NodeKeyAuthenticated(address nodeKey, address operator);

    /// @notice Emitted when a node key is removed
    /// @param nodeKey The node key removed
    /// @param operator The operator associated with the node key
    event NodeKeyRemoved(address nodeKey, address operator);

    ///////////////////////
    // External Functions
    ///////////////////////

    /// @notice Removes an alert from the system
    /// @param messageHash The hash of the message corresponding to the alert to remove
    function removeAlert(bytes32 messageHash) external;

    /// @notice Sets the expiry duration for alerts
    /// @param duration The new expiry duration
    function setExpiryDuration(uint16 duration) external;

    /// @notice Registers a node key for an operator
    /// @param operator The operator associated with the node key
    function registerNodeKey(address operator) external;

    /// @notice Authenticates a previously set node key, allowing it to participate in alert votes
    /// @param nodeKey The node key to authenticate
    function authenticateNodeKey(address nodeKey) external;

    /// @notice Removes the currently authenticated node key
    function removeNodeKey() external;

    /// @notice Votes for a block alert using the caller's node key
    /// @param blockNumber The block number to associate with the alert
    function voteForBlockAlert(uint256 blockNumber) external;

    /// @notice Votes for a message alert using the caller's node key
    /// @param message The message to associate with the alert
    function voteForMessageAlert(string calldata message) external;

    ///////////////////////
    // View Functions
    ///////////////////////

    /// @notice Checks if the given node key is authenticated
    /// @param nodeKey The address of the node key to verify authentication.
    /// @return bool Returns true if the node key is authenticated, false otherwise.
    function isAuthenticated(address nodeKey) external view returns (bool);

    /// @notice Gets a list of alerts voted on by a nodeKey
    /// @param nodeKey The node key to query for voted alerts
    /// @return An array of message hashes corresponding to alerts voted on by the node key
    function getVotedAlerts(address nodeKey) external view returns (bytes32[] memory);

    /// @notice Checks whether an alert with a given vote count is considered active
    /// @param voteCount The vote count of the alert
    /// @return True if the alert is active, false otherwise
    function isActiveAlert(uint128 voteCount) external view returns (bool);

    /// @notice Returns the total number of alerts in the system
    /// @return The total number of alerts
    function totalAlerts() external view returns (uint256);

    /// @notice Checks if a specific alert exists in the system
    /// @param messageHash The hash of the message corresponding to the alert
    /// @return True if the alert exists, false otherwise
    function contains(bytes32 messageHash) external view returns (bool);

    /// @notice Queries a range of message hashes from the system
    /// @param start The start index for querying
    /// @param querySize The number of message hashes to query
    /// @return An array of message hashes
    function queryMessageHashes(uint256 start, uint256 querySize) external view returns (bytes32[] memory);
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "./OwnableUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is specified at deployment time in the constructor for `Ownable`. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2StepUpgradeable is Initializable, OwnableUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable2Step
    struct Ownable2StepStorage {
        address _pendingOwner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable2Step")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant Ownable2StepStorageLocation = 0x237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c00;

    function _getOwnable2StepStorage() private pure returns (Ownable2StepStorage storage $) {
        assembly {
            $.slot := Ownable2StepStorageLocation
        }
    }

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    function __Ownable2Step_init() internal onlyInitializing {
    }

    function __Ownable2Step_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        Ownable2StepStorage storage $ = _getOwnable2StepStorage();
        return $._pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        Ownable2StepStorage storage $ = _getOwnable2StepStorage();
        $._pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        Ownable2StepStorage storage $ = _getOwnable2StepStorage();
        delete $._pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol
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


// File: src/interfaces/IOperatorRegistry.sol
// SPDX-License-Identifier: agpl-3.0
// Copyright (c) 2024, Alt Research Ltd.
pragma solidity =0.8.23;

/// @title Interface for OperatorRegistry
/// @notice This interface outlines the functionalities for managing and querying operators in a contract.
interface IOperatorRegistry {
    ////////////////
    // Events
    ////////////////

    /// @notice Emitted when a new operator is added
    /// @param operator The address of the operator added
    event OperatorAdded(address operator, address owner);

    /// @notice Emitted when an operator is frozen
    /// @param operator The address of the operator frozen
    /// @param owner The address of the owner who froze the operator
    event Frozen(address operator, address owner);

    ////////////////
    // Functions
    ////////////////

    /// @notice Triggers the stopped state.
    function pause() external;

    /// @notice Returns to normal state.
    function unpause() external;

    /// @notice Returns the total number of operators
    /// @return The total number of operators
    function totalOperators() external view returns (uint256);

    /// @notice Checks if the given address is an operator
    /// @param operator The address to check
    /// @return True if the address is an operator, false otherwise
    function isOperator(address operator) external view returns (bool);

    /// @notice Returns an array of operator addresses starting from the specified index up to the query size
    /// @param start The start index to retrieve operator addresses
    /// @param querySize The number of operator addresses to retrieve
    /// @return An array of operator addresses
    function queryOperators(uint256 start, uint256 querySize) external view returns (address[] memory);
}


// File: lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (token/ERC1155/IERC1155.sol)

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
     * WARNING: This function can potentially allow a reentrancy attack when transferring tokens
     * to an untrusted contract, when invoking {onERC1155BatchReceived} on the receiver.
     * Ensure to follow the checks-effects-interactions pattern and consider employing
     * reentrancy guards when interacting with untrusted contracts.
     *
     * Emits either a {TransferSingle} or a {TransferBatch} event, depending on the length of the array arguments.
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


// File: lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol
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


// File: lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

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

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// File: lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/ERC165Upgradeable.sol
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


// File: lib/openzeppelin-contracts/contracts/utils/Arrays.sol
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


// File: lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol
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


// File: lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol
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


// File: lib/openzeppelin-contracts/contracts/utils/math/Math.sol
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


