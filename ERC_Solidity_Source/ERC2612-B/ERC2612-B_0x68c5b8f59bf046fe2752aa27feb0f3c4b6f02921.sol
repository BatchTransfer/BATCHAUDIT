// File: contracts/Subs.sol
pragma solidity ^0.8.19;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {BoringBatchable} from "./fork/BoringBatchable.sol";
import {AaveV3Adapter} from "./yield/AaveV3Adapter.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

contract Subs is BoringBatchable, AaveV3Adapter {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    uint public immutable periodDuration;
    address public immutable feeCollector;
    uint public currentPeriod; // Invariant: currentPeriod < block.timestamp
    uint public sharesAccumulator;
    mapping(address => mapping(uint256 => uint256)) public receiverAmountToExpire;
    struct ReceiverBalance {
        uint256 balance;
        uint256 amountPerPeriod;
        uint256 lastUpdate; // Invariant: lastUpdate <= currentPeriod
    }
    mapping(address => ReceiverBalance) public receiverBalances;
    mapping(uint256 => uint256) public sharesPerPeriod;
    mapping(bytes32 => bool) public subs;

    event NewSubscription(address owner, uint initialPeriod, uint expirationDate, uint amountPerCycle, address receiver, uint256 accumulator, uint256 initialShares, bytes32 subId, bytes32 paymentId);
    event NewDelayedSubscription(address owner, uint initialPeriod, uint expirationDate, uint amountPerCycle, address receiver, uint256 accumulator, uint256 initialShares, bytes32 subId, uint instantPayment, bytes32 paymentId);
    event Unsubscribe(bytes32 subId);

    constructor(uint _periodDuration, address _vault, address _feeCollector, uint _currentPeriod, address rewardRecipient_,
        address stakingRewards_, address owner_) AaveV3Adapter(_vault, rewardRecipient_, stakingRewards_, owner_){
        // periodDuration MUST NOT be a very small number, otherwise loops could end growing big and blowing up gas costs
        // At 500-600 cycles you start running into ethereum's gas limit per block, which would make it impossible to call the contract
        // We solve that by adding a method that lets users update state partially, so you can split a 20 years update into 4 calls that update 5 years each
        // however there's still the problem of gas costs growing so much that cost to do all those updates would be prohibitive,
        // So we enforce a minimum of 1 week for periodDuration, which keeps the max gas costs bounded (it would take >10yrs for it to grow bigger than the current gas limit per block)
        require(_periodDuration >= 7 days, "periodDuration too smol");
        periodDuration = _periodDuration;
        currentPeriod = _currentPeriod;
        require(currentPeriod < block.timestamp);
        feeCollector = _feeCollector;
    }

    function _updateGlobal(uint limit) private { // invariant: limit <= block.timestamp
        if(block.timestamp > currentPeriod + periodDuration){
            uint shares = convertToShares(DIVISOR);
            do {
                sharesPerPeriod[currentPeriod] = shares;
                currentPeriod += periodDuration;
                sharesAccumulator += shares; // This could be optimized with `sharesAccumulator += ((block.timestamp - currentPeriod - 1)/periodDuration)*shares;`, but not worth it
            } while(limit > currentPeriod + periodDuration);
        }
    }

    function min(uint a, uint b) pure internal returns (uint) {
        return a>b?b:a;
    }

    function _updateReceiver(address receiver, uint limit) private {
        ReceiverBalance storage bal = receiverBalances[receiver];
        uint lastUpdate = bal.lastUpdate;
        if(lastUpdate + periodDuration < block.timestamp){
            _updateGlobal(limit); // if lastUpdate is up to date then currentPeriod must be up to date since lastUpdate is only updated after calling _updateGlobal()
            if(lastUpdate == 0){
                lastUpdate = currentPeriod;
            } else {
                // This optimization can increase costs a little on subscribe() but decreases costs a lot when _updateReceiver() hasnt been called in a long time
                uint balance = bal.balance;
                uint amountPerPeriod = bal.amountPerPeriod;
                uint limitToFill = min(currentPeriod, limit);
                do {
                    // invariant: here lastUpdate < currentPeriod is always true
                    amountPerPeriod -= receiverAmountToExpire[receiver][lastUpdate];
                    balance += (amountPerPeriod * sharesPerPeriod[lastUpdate]) / DIVISOR;
                    lastUpdate += periodDuration;
                } while (lastUpdate < limitToFill);
                bal.balance = balance;
                bal.amountPerPeriod = amountPerPeriod;
            }
            bal.lastUpdate = lastUpdate;
        }
    }

    // This allows partial updates in case an update to current timestamp results in gas costs higher than the block limit
    // By splitting this into multiple partial calls you could get around the block limit and ensure that any funds can still be withdrawn even if called after >10yr
    function partialUpdateReceiver(address receiver, uint limit) external {
        require(limit < block.timestamp, "limit too big");
        _updateReceiver(receiver, limit);
    }

    function getSubId(address owner, uint initialPeriod, uint expirationDate,
        uint amountPerCycle, address receiver, uint256 accumulator, uint256 initialShares) public pure returns (bytes32 id){
        id = keccak256(
            abi.encode(
                owner,
                initialPeriod,
                expirationDate, // needed to undo receiverAmountToExpire
                amountPerCycle,
                receiver,
                accumulator,
                initialShares
            )
        );
    }

    function _subscribe(address receiver, uint amountPerCycle, uint256 amountForFuture, uint claimableThisPeriod) internal
        returns (uint expirationDate, uint256, bytes32) {
        uint amount = amountForFuture + claimableThisPeriod;
        // If subscribed when timestamp == currentPeriod with cycles == 0, this will revert, which is fine since such subscription is for 0 seconds
        uint cycles = amountForFuture/amountPerCycle;
        (uint shares) = deposit(amount);
        asset.safeTransferFrom(msg.sender, address(this), amount);
        uint expiration = currentPeriod + periodDuration*cycles;
        // Setting receiverAmountToExpire here makes the implicit assumption than all calls to convertToShares(DIVISOR) within _updateGlobal() in the future will return a lower number than the one returned right now,
        // in other words, that the underlying vault will never lose money and its pricePerShare() will not go down
        // If vault were to lose money, contract will keep working, but it will have bad debt, so the last users to withdraw won't be able to
        receiverAmountToExpire[receiver][expiration] += amountPerCycle;
        receiverBalances[receiver].amountPerPeriod += amountPerCycle;
        receiverBalances[receiver].balance += (shares * claimableThisPeriod) / amount; // if claimableThisPeriod = 0 && cycles == 0 this will revert, but thats fine since thats a useless sub
        uint sharesLeft = (amountForFuture * shares) / amount;
        bytes32 subId = getSubId(msg.sender, currentPeriod, expiration, amountPerCycle, receiver, sharesAccumulator, sharesLeft);
        require(subs[subId] == false, "duplicated sub");
        subs[subId] = true;
        return (expiration, sharesLeft, subId);
    }

    function subscribe(address receiver, uint amountPerCycle, uint256 amountForFuture, bytes32 paymentId) external {
        _updateReceiver(receiver, block.timestamp);
        // block.timestamp <= currentPeriod + periodDuration is enforced in _updateGlobal() and currentPeriod < block.timestamp
        // so 0 <= (currentPeriod + periodDuration - block.timestamp) <= periodDuration
        // thus this will never underflow and claimableThisPeriod <= amountPerCycle
        uint claimableThisPeriod = (amountPerCycle * (currentPeriod + periodDuration - block.timestamp)) / periodDuration;
        (uint expirationDate, uint256 sharesLeft, bytes32 subId) = _subscribe(receiver, amountPerCycle, amountForFuture, claimableThisPeriod);
        emit NewSubscription(msg.sender, currentPeriod, expirationDate, amountPerCycle, receiver, sharesAccumulator, sharesLeft, subId, paymentId);
    }

    // Copy of subscribe() but with claimableThisPeriod set by the user
    // This is for users that have unsubscribed during the current period but want to subscribe again
    // If they call subscribe() they would have to pay for the remaining of the current period, which they have already paid for
    // This function allows them to delay the subscription till the beginning of the next period to avoid that
    // Also, it can be used for users that are upgrading their subscription
    // ---
    // This could be gas optimized by copying over the code of _subscribe() and removing operations associated with claimableThisPeriod
    // like setting receiverBalances[receiver].balance. This saves 200 gas for subscribe() and 3k gas for subscribeForNextPeriod()
    // However that adds a lot of code that could introduce bugs, and subscribeForNextPeriod() should be rarely called
    // So I don't think that optimization is worth the security trade-offs
    function subscribeForNextPeriod(address receiver, uint amountPerCycle, uint256 amountForFuture, uint256 instantPayment, bytes32 paymentId) external {
        require(amountForFuture >= amountPerCycle, "amountForFuture < amountPerCycle");
        _updateReceiver(receiver, block.timestamp);
        (uint expirationDate, uint256 sharesLeft, bytes32 subId) = _subscribe(receiver, amountPerCycle, amountForFuture, instantPayment);
        emit NewDelayedSubscription(msg.sender, currentPeriod, expirationDate, amountPerCycle, receiver, sharesAccumulator, sharesLeft, subId, instantPayment, paymentId);
    }

    function unsubscribe(uint initialPeriod, uint expirationDate, uint amountPerCycle, address receiver, uint256 accumulator, uint256 initialShares) external {
        _updateGlobal(block.timestamp);
        bytes32 subId = getSubId(msg.sender, initialPeriod, expirationDate, amountPerCycle, receiver, accumulator, initialShares);
        require(subs[subId] == true, "sub doesn't exist");
        delete subs[subId];
        if(expirationDate >= block.timestamp){
            // Most common case, solved in O(1)
            uint sharesPaid = (sharesAccumulator - accumulator).mulDivUp(amountPerCycle, DIVISOR);
            // sharesLeft can underflow if either share price goes down or because of rounding
            // however that's fine because in those cases there's nothing left to withdraw
            uint sharesLeft = initialShares - sharesPaid;
            redeem(sharesLeft, msg.sender);
            receiverAmountToExpire[receiver][expirationDate] -= amountPerCycle;
            receiverAmountToExpire[receiver][currentPeriod] += amountPerCycle;
        } else {
            // Uncommon case, its just claiming yield generated after sub expired
            uint subsetAccumulator = 0;
            while(initialPeriod < expirationDate){
                subsetAccumulator += sharesPerPeriod[initialPeriod];
                initialPeriod += periodDuration;
            }
            redeem(initialShares - subsetAccumulator.mulDivUp(amountPerCycle, DIVISOR), msg.sender);
        }
        emit Unsubscribe(subId);
    }

    function claim(uint256 amount) external {
        _updateReceiver(msg.sender, block.timestamp);
        receiverBalances[msg.sender].balance -= amount;
        redeem((amount * 99) / 100, msg.sender); // feeCollector can't fully claim in 1 tx but leaving as is to keep code simple
        receiverBalances[feeCollector].balance += amount / 100;
    }
}


// File: contracts/SubsFactory.sol
pragma solidity ^0.8.0;

import {Subs} from "./Subs.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {Owned} from "solmate/src/auth/Owned.sol";

contract SubsFactory is Owned {
    using SafeTransferLib for ERC20;

    uint256 public getContractCount;
    address[1000000000] public getContractByIndex;

    event SubsCreated(address subsContract, address token, uint periodDuration, address vault, address feeCollector, uint currentPeriod, address rewardRecipient, address stakingRewards, address owner);

    constructor() Owned(msg.sender) {}

    function createContract(uint _periodDuration, address _vault, address _feeCollector, uint _currentPeriod,
      address rewardRecipient_, address stakingRewards_, address owner_, uint256 unit) onlyOwner() external returns (Subs subsContract) {
        subsContract = new Subs(_periodDuration, _vault, _feeCollector, _currentPeriod, rewardRecipient_, stakingRewards_, owner_);
        ERC20 token = subsContract.asset();

        /*
        BaseAdapter is vulnerable to ERC4626 inflation attacks
        See https://docs.openzeppelin.com/contracts/5.x/erc4626

        To mitigate this we deposit some coins and burn the shares by assigning them to this contract, from which they can't be retrieved.
        */
        token.safeTransferFrom(msg.sender, address(this), unit); // unit needs to be high enough (eg ~1$ is enough)
        token.approve(address(subsContract), unit);
        subsContract.subscribeForNextPeriod(address(this), unit, unit, 0, "");

        // Append the new contract address to the array of deployed contracts
        uint256 index = getContractCount;
        getContractByIndex[index] = address(subsContract);
        unchecked{
            getContractCount = index + 1;
        }

        emit SubsCreated(address(subsContract), address(token), _periodDuration, _vault, _feeCollector, _currentPeriod, rewardRecipient_, stakingRewards_, owner_);
    }
}

// File: contracts/fork/BoringBatchable.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly

// WARNING!!!
// Combining BoringBatchable with msg.value can cause double spending issues
// https://www.paradigm.xyz/2021/08/two-rights-might-make-a-wrong/

interface IERC20Permit{
     /// @notice EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

contract BaseBoringBatchable {
    /// @dev Helper function to extract a useful revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this call can fail itself.
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    /// @notice Allows batched call to self (this contract).
    /// @param calls An array of inputs for each call.
    /// @param revertOnFail If True then reverts after a failed call and stops doing further calls.
    // F1: External is ok here because this is the batch function, adding it to a batch makes no sense
    // F2: Calls in the batch may be payable, delegatecall operates in the same context, so each call in the batch has access to msg.value
    // C3: The length of the loop is fully under user control, so can't be exploited
    // C7: Delegatecall is only used on the same contract, so it's safe
    function batch(bytes[] calldata calls, bool revertOnFail) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            if (!success && revertOnFail) {
                revert(_getRevertMsg(result));
            }
        }
    }
}

contract BoringBatchable is BaseBoringBatchable {
    /// @notice Call wrapper that performs `ERC20.permit` on `token`.
    /// Lookup `IERC20.permit`.
    // F6: Parameters can be used front-run the permit and the user's permit will fail (due to nonce or other revert)
    //     if part of a batch this could be used to grief once as the second call would not need the permit
    function permitToken(
        IERC20Permit token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        token.permit(from, to, amount, deadline, v, r, s);
    }
}

// File: contracts/yield/AaveV3Adapter.sol
pragma solidity ^0.8.19;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface AToken {
    function UNDERLYING_ASSET_ADDRESS() view external returns (address);
    function POOL() view external returns (address);
}

interface IRewardsController {
    function claimAllRewards(address[] calldata assets, address to) external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}

contract AaveV3Adapter is BaseAdapter {
    ERC20 public immutable aToken;
    IPool public immutable lendingPool;
    IRewardsController public immutable rewardsController;

    constructor(
        address aToken_,
        address rewardRecipient_,
        address rewardsController_,
        address owner_
    ) BaseAdapter(AToken(aToken_).UNDERLYING_ASSET_ADDRESS(), rewardRecipient_, owner_) {
        lendingPool = IPool(AToken(aToken_).POOL());
        aToken = ERC20(aToken_);
        rewardsController = IRewardsController(rewardsController_);
        asset.approve(address(lendingPool), type(uint256).max);
    }

    // If the rewards are donated back to the vault, this mechanism is vulnerable to an attack where someone joins the pool, rewards are distributed, and then he leaves
    // this would allow that attacker to steal a part of the yield from everyone else
    // We solve this by donating to the pool at random times and keeping the txs private so its impossible to predict when a donation will happen and deposit right before
    function claimRewards() external {
        require(msg.sender == rewardRecipient, "not rewardRecipient");
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        rewardsController.claimAllRewards(assets, rewardRecipient);
    }

    function forceDeposit(uint assets) internal override {
        lendingPool.supply(address(asset), assets, address(this), 0);
    }

    function forceRedeem(uint assets, address receiver) internal override {
        lendingPool.withdraw(address(asset), assets, receiver);
    }

    function totalAssets() public view override returns (uint256) {
        return aToken.balanceOf(address(this)) + asset.balanceOf(address(this));
    }

    function refreshApproval() external override {
        asset.approve(address(lendingPool), 0);
        asset.approve(address(lendingPool), type(uint256).max);
    }
}

// File: contracts/yield/BaseAdapter.sol
pragma solidity ^0.8.19;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {Owned} from "solmate/src/auth/Owned.sol";

/*
This is vulnerable to ERC4626 inflation attacks!
See https://docs.openzeppelin.com/contracts/5.x/erc4626 and https://blog.openzeppelin.com/a-novel-defense-against-erc4626-inflation-attacks

This is solved through SubsFactory, which creates some shares upon deployment and burns them.
*/

abstract contract BaseAdapter is Owned {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    ERC20 public immutable asset;
    address public rewardRecipient;
    uint public immutable DIVISOR; // This is just a constant to query convertToShares and then divide result, vault.convertToShares(DIVISOR) must never revert
    uint public totalSupply;

    constructor(
        address asset_,
        address rewardRecipient_,
        address owner_
    ) Owned(owner_) {
        asset = ERC20(asset_);
        rewardRecipient = rewardRecipient_;
        DIVISOR = 10**asset.decimals(); // Even if decimals() changes later this will still work fine
    }

    function setRewardRecipient(address _rewardRecipient) external onlyOwner() {
        rewardRecipient = _rewardRecipient;
    }

    // There's an argument for not caller-restricting this:
    //   redeem() doesn't support withdrawing money from both asset and vault, so in the case where the last user wants to withdraw
    //    and only 50% of money is in the vault, owner could increase minBalanceToTriggerDeposit to max to prevent new vault deposits
    //    and prevent the user from getting the money, asking for a ransom.
    //    If this method was not caller-restricted, user could simply call it to solve that situation
    // However the danger seems too high for now since this makes it possible for an attacker to withdraw and deposit into vault at will
    // so in the first version it will be caller-restricted
    function triggerDeposit(uint amount, uint maxToPull) external onlyOwner() {
        forceDepositAndCheck(amount, maxToPull);
    }

    // In some cases totalAssets() after coins are deposited into the yield vault, this could be used in an attack so this function ensures this never happens
    function forceDepositAndCheck(uint amount, uint maxToPull) internal {
        uint oldTotalAssets = totalAssets();
        forceDeposit(amount);
        uint newTotalAssets = totalAssets();
        if(newTotalAssets < oldTotalAssets){
            uint pullAmount = oldTotalAssets - newTotalAssets;
            require(pullAmount < maxToPull, ">maxToPull");
            asset.safeTransferFrom(msg.sender, address(this), pullAmount);
        }
    }

    function forceDeposit(uint assets) internal virtual;

    // Yield buffer
    //   Most of the gas cost in calls to subscribe() comes moving the coins into the yield-generating vault
    //   For small subscriptions this means that users might end up paying more in gas costs than the yield they generate,
    //   so to greatly reduce gas costs and amortize them among all users we've implemented a yield buffer.
    //   When new coins are deposited they'll be simply stored in the contract, with no extra gas costs,
    //   then, when we trigger it, all coins will be moved to the yield vault, thus aggregating all these user deposits
    //   into a single large deposit for which we pay O(1) gas, thus amortizing costs.
    //   This means that some money will sit idle and not earn any yield, but thats ok.
    //   This also applies for withdrawals, if we have enough money in the buffer we'll just use that so we don't have to pull money from vault
    function deposit(uint256 assets) internal returns (uint shares) {
        shares = totalSupply == 0 ? assets : assets.mulDivDown(totalSupply, totalAssets());
        totalSupply += shares;
    }

    function forceRedeem(uint assets, address receiver) internal virtual;

    function redeem(uint256 shares, address receiver) internal {
        uint assets = convertToAssets(shares);
        totalSupply -= shares;
        if(assets <= asset.balanceOf(address(this))){
            asset.safeTransfer(receiver, assets);
        } else {
            forceRedeem(assets, receiver);
        }
    }

    function totalAssets() public view virtual returns (uint256);

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }

    function refreshApproval() external virtual;
}


// File: solmate/src/auth/Owned.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}


// File: solmate/src/tokens/ERC20.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}


// File: solmate/src/utils/FixedPointMathLib.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAX_UINT256 = 2**256 - 1;

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            // Divide x * y by the denominator.
            z := div(mul(x, y), denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            // If x * y modulo the denominator is strictly greater than 0,
            // 1 is added to round up the division of x * y by the denominator.
            z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Mod x by y. Note this will return
            // 0 instead of reverting if y is zero.
            z := mod(x, y)
        }
    }

    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Divide x by y. Note this will return
            // 0 instead of reverting if y is zero.
            r := div(x, y)
        }
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Add 1 to x * y if x % y > 0. Note this will
            // return 0 instead of reverting if y is zero.
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}


// File: solmate/src/utils/SafeTransferLib.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "../tokens/ERC20.sol";

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "from" argument.
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "APPROVE_FAILED");
    }
}


