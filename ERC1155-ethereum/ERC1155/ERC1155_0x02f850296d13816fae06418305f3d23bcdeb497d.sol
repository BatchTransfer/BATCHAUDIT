// File: src/contracts/strategies/NFTXInventoryStakingStrategy.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, NoRewardsAvailableToClaim} from '@floor/utils/Errors.sol';

import {BaseStrategy, InsufficientPosition, ZeroAmountReceivedFromWithdraw} from '@floor/strategies/BaseStrategy.sol';

import {INFTXVault} from '@floor-interfaces/nftx/NFTXVault.sol';
import {INFTXInventoryStaking} from '@floor-interfaces/nftx/NFTXInventoryStaking.sol';
import {INFTXStakingZap} from '@floor-interfaces/nftx/NFTXStakingZap.sol';
import {INFTXUnstakingInventoryZap} from '@floor-interfaces/nftx/NFTXUnstakingInventoryZap.sol';

/**
 * Supports an Inventory Staking position against a single NFTX vault. This strategy
 * will hold the corresponding xToken against deposits.
 *
 * The contract will extend the {BaseStrategy} to ensure it conforms to the required
 * logic and functionality. Only functions that have varied internal logic have been
 * included in this interface with function documentation to explain.
 *
 * @dev This contract does not support PUNK tokens. If a strategy needs to be established
 * then it should be done through another, bespoke contract.
 *
 * https://etherscan.io/address/0x3E135c3E981fAe3383A5aE0d323860a34CfAB893#readProxyContract
 */
contract NFTXInventoryStakingStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    /// The NFTX vault ID that the strategy is attached to
    uint public vaultId;

    /// The underlying token will be the same as the address of the NFTX vault.
    IERC20 public vToken;

    /// The reward yield will be a vault xToken as defined by the InventoryStaking contract.
    IERC20 public xToken;

    /// The ERC721 / ERC1155 token asset for the NFTX vault
    address public assetAddress;

    /// Address of the NFTX Inventory Staking contract
    INFTXInventoryStaking public inventoryStaking;

    /// The NFTX zap addresses
    INFTXStakingZap public stakingZap;
    INFTXUnstakingInventoryZap public unstakingZap;

    /// Track the amount of deposit token, which in this instance will be recorded
    /// as the received xToken, and not the initial vToken.
    uint public deposits;

    /// Stores the temporary recipient of any ERC721 and ERC1155 tokens that are received
    /// by the contract.
    address private _nftReceiver;

    /**
     * Sets up our contract variables.
     *
     * @param _name The name of the strategy
     * @param _strategyId ID index of the strategy created
     * @param _initData Encoded data to be decoded
     */
    function initialize(bytes32 _name, uint _strategyId, bytes calldata _initData) public initializer {
        // Set our strategy name
        name = _name;

        // Set our strategy ID
        strategyId = _strategyId;

        // Extract the NFTX information from our initialisation bytes data
        (
            uint _vaultId,
            address _vToken,
            address _xToken,
            address _inventoryStaking,
            address _stakingZap,
            address _unstakingZap
        ) = abi.decode(_initData, (uint, address, address, address, address, address));

        // Map our NFTX information
        vaultId = _vaultId;
        vToken = IERC20(_vToken);
        xToken = IERC20(_xToken);
        stakingZap = INFTXStakingZap(_stakingZap);
        unstakingZap = INFTXUnstakingInventoryZap(_unstakingZap);
        inventoryStaking = INFTXInventoryStaking(_inventoryStaking);

        // Set our ERC721 / ERC1155 token asset address
        assetAddress = INFTXVault(_vToken).assetAddress();

        // Set the underlying token as valid to process
        _validTokens[_vToken] = true;

        // Transfer ownership to the caller
        _transferOwnership(msg.sender);
    }

    /**
     * Deposit underlying token or yield token to corresponding strategy.
     *
     * Requirements:
     *  - Caller should make sure the token is already transfered into the strategy contract.
     *  - Caller should make sure the deposit amount is greater than zero.
     *
     * - Get the vault ID from the underlying address (vault address)
     * - InventoryStaking.deposit(uint256 vaultId, uint256 _amount)
     *   - This deposit will be timelocked
     * - We receive xToken back to the strategy
     */
    function depositErc20(uint amount) external nonReentrant whenNotPaused {
        // Prevent users from trying to deposit nothing
        if (amount == 0) {
            revert CannotDepositZeroAmount();
        }

        // Transfer the underlying token from our caller
        vToken.safeTransferFrom(msg.sender, address(this), amount);

        // Approve the NFTX contract against our underlying token
        vToken.approve(address(inventoryStaking), amount);

        // Deposit the token into the NFTX contract
        inventoryStaking.deposit(vaultId, amount);

        // Increase the user's position and the total position for the strategy
        deposits += amount;
        emit Deposit(address(vToken), amount, msg.sender);
    }

    function depositErc721(uint[] calldata tokenIds) external nonReentrant whenNotPaused {
        // Pull tokens in
        uint tokensLength = tokenIds.length;
        for (uint i; i < tokensLength;) {
            IERC721(assetAddress).transferFrom(msg.sender, address(this), tokenIds[i]);
            unchecked {
                ++i;
            }
        }

        // Approve stakingZap
        IERC721(assetAddress).setApprovalForAll(address(stakingZap), true);

        // Push tokens out
        stakingZap.provideInventory721(vaultId, tokenIds);

        // Increase the user's position and the total position for the strategy
        deposits += (tokensLength * 1 ether);
        emit Deposit(address(vToken), (tokensLength * 1 ether), msg.sender);
    }

    function depositErc1155(uint[] calldata tokenIds, uint[] calldata amounts) external nonReentrant whenNotPaused {
        // Pull tokens in
        IERC1155(assetAddress).safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, '');

        // Approve stakingZap
        IERC1155(assetAddress).setApprovalForAll(address(stakingZap), true);

        // Push tokens out
        stakingZap.provideInventory1155(vaultId, tokenIds, amounts);

        // Increase the user's position and the total position for the strategy
        uint newDeposits;
        for (uint i; i < tokenIds.length;) {
            newDeposits += amounts[i];
            unchecked { ++i; }
        }

        deposits += (newDeposits * 1 ether);
        emit Deposit(address(vToken), (newDeposits * 1 ether), msg.sender);
    }

    /**
     * Withdraws an amount of our position from the NFTX strategy.
     *
     * @dev Implements `nonReentrant` through `_withdrawErc20`
     *
     * @param amount Amount of yield token to withdraw defined in vToken
     *
     * @return amount_ Amount of the underlying token returned
     */
    function withdrawErc20(address recipient, uint amount) external onlyOwner returns (uint amount_) {
        // Ensure our user has sufficient xToken balance to withdraw from
        if (amount > deposits) {
            revert InsufficientPosition(address(vToken), amount, deposits);
        }

        return _withdrawErc20(recipient, amount);
    }

    /**
     * Makes a call to a strategy to withdraw a percentage of the deposited holdings.
     *
     * @dev Implements `nonReentrant` through `_withdrawErc20`
     *
     * @param recipient Recipient of the withdrawal
     * @param percentage The 2 decimal accuracy of the percentage to withdraw (e.g. 100% = 10000)
     */
    function withdrawPercentage(address recipient, uint percentage)
        external
        override
        onlyOwner
        returns (address[] memory tokens_, uint[] memory amounts_)
    {
        // Get the total amount of xToken held by the strategy. From this we can reference
        // the amount of vToken that is held.
        uint amount = (deposits * percentage) / 100_00;

        // Set up our return arrays
        tokens_ = new address[](1);
        tokens_[0] = address(vToken);

        // Call our internal {withdrawErc20} function to move tokens to the caller
        amounts_ = new uint[](1);
        amounts_[0] = _withdrawErc20(recipient, amount);
    }

    function _withdrawErc20(address recipient, uint amount) internal nonReentrant returns (uint amount_) {
        // Prevent users from trying to claim nothing
        if (amount == 0) {
            revert CannotWithdrawZeroAmount();
        }

        // Convert the requested amount of vToken to xToken using the share value calculation
        uint xTokenEquivalent = amount * 1 ether / inventoryStaking.xTokenShareValue(vaultId);

        // Capture our starting vToken balance
        uint startTokenBalance = vToken.balanceOf(address(this));

        // Process our withdrawal against the NFTX contract to receive vToken into the strategy
        inventoryStaking.withdraw(vaultId, xTokenEquivalent);

        // Determine the amount of `vToken` received and raise an exception if we gain
        // no vToken in return.
        amount_ = vToken.balanceOf(address(this)) - startTokenBalance;
        if (amount_ == 0) {
            revert ZeroAmountReceivedFromWithdraw();
        }

        // Transfer the received token to the recipient
        vToken.safeTransfer(recipient, amount_);

        // Update our deposit amount based on the amount of vToken withdrawn
        deposits -= amount_;

        // Fire an event to show amount of token claimed and the recipient
        emit Withdraw(address(vToken), amount_, recipient);
    }

    /**
     * Withdraws an ERC721 token from the Inventory position. This will be pseudo-random.
     *
     * @dev Implements `nonReentrant` through `_unstakeInventory`
     */
    function withdrawErc721(address _recipient, uint _numNfts, uint _partial) external onlyOwner {
        _unstakeInventory(_recipient, _numNfts, _partial);
    }

    /**
     * Withdraws an ERC1155 token from the Inventory position. This will be pseudo-random.
     *
     * @dev Implements `nonReentrant` through `_unstakeInventory`
     */
    function withdrawErc1155(address _recipient, uint _numNfts, uint _partial) external onlyOwner {
        _unstakeInventory(_recipient, _numNfts, _partial);
    }

    function _unstakeInventory(address _recipient, uint _numNfts, uint _partial) internal nonReentrant {
        // Before we can withdraw, we need to allow the contract to manage our ERC20
        xToken.approve(address(unstakingZap), type(uint).max);

        // Set our NFT receiver so that our safe transfer will pass it on
        _nftReceiver = _recipient;

        // Get the start balance of the expected _partial token to receive if requested
        uint startTokenBalance = vToken.balanceOf(address(this));

        // Unstake our ERC721's and partial remaining tokens
        unstakingZap.unstakeInventory(vaultId, _numNfts, _partial);

        // Delete our NFT receiver to prevent unexpected transactions
        delete _nftReceiver;

        // Find the new balance of the tokens that we are withdrawing
        uint tokenDifference = vToken.balanceOf(address(this)) - startTokenBalance;

        // Ensure that we aren't withdrawing more than deposited
        if (tokenDifference > deposits) {
            revert InsufficientPosition(address(vToken), tokenDifference, deposits);
        }

        // Send the acquired vTokens to our recipient, and the inventory tokens will have
        // already been sent via the safe transfer.
        if (tokenDifference != 0) {
            vToken.safeTransfer(_recipient, tokenDifference);
        }

        // We can now reduce the users position and total position held by the strategy
        deposits -= tokenDifference;

        // Fire an event to show amount of token claimed and the recipient
        emit Withdraw(address(vToken), tokenDifference, _recipient);
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() public view override returns (address[] memory tokens_, uint[] memory amounts_) {
        // Set up our return arrays
        tokens_ = new address[](1);
        amounts_ = new uint[](1);

        // Assign our vtoken as the token to claim
        tokens_[0] = address(vToken);

        // Get the xToken balance held by the strategy and find the share of vToken that this
        // is equivalent to. By removing the deposits from this, it should show only the rewards
        // generated. We also check underflow as may have dust missing after a deposit.
        uint vTokenEquivalent = (xToken.balanceOf(address(this)) * inventoryStaking.xTokenShareValue(vaultId)) / 1 ether;
        amounts_[0] = (vTokenEquivalent < deposits) ? 0 : vTokenEquivalent - deposits;
    }

    /**
     * Extracts all rewards from third party and moves it to a recipient. This should
     * only be called by a specific action via the {StrategyFactory}.
     */
    function harvest(address _recipient) external override onlyOwner {
        (, uint[] memory amounts) = this.available();

        if (amounts[0] != 0) {
            // Withdraw our xToken to return vToken from the NFTX inventory staking contract
            inventoryStaking.withdraw(vaultId, (amounts[0] * 1 ether) / inventoryStaking.xTokenShareValue(vaultId));

            // We can now withdraw all of the vToken from the contract
            vToken.safeTransfer(_recipient, vToken.balanceOf(address(this)));

            unchecked {
                lifetimeRewards[address(vToken)] += amounts[0];
            }
        }

        emit Harvest(address(vToken), amounts[0]);
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() public view override returns (address[] memory) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = address(vToken);
        return tokens_;
    }

    /**
     * Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(address, /* _from */ address, /* _to */ uint _id, bytes memory /* _data */ ) public returns (bytes4) {
        require(msg.sender == assetAddress, 'Invalid asset');

        if (_nftReceiver != address(0)) {
            IERC721(assetAddress).safeTransferFrom(address(this), _nftReceiver, _id);
        }

        return this.onERC721Received.selector;
    }

    /**
     * Allows the contract to receive ERC1155 tokens.
     */
    function onERC1155Received(address, /* _from */ address, /* _to */ uint _id, uint _value, bytes calldata _data)
        public
        returns (bytes4)
    {
        require(msg.sender == assetAddress, 'Invalid asset');

        if (_nftReceiver != address(0)) {
            IERC1155(assetAddress).safeTransferFrom(address(this), _nftReceiver, _id, _value, _data);
        }

        return this.onERC1155Received.selector;
    }

    /**
     * Allows the contract to receive batch ERC1155 tokens.
     */
    function onERC1155BatchReceived(
        address, /* _from */
        address, /* _to */
        uint[] calldata _ids,
        uint[] calldata _values,
        bytes calldata _data
    ) external returns (bytes4) {
        require(msg.sender == assetAddress, 'Invalid asset');

        if (_nftReceiver != address(0)) {
            IERC1155(assetAddress).safeBatchTransferFrom(address(this), _nftReceiver, _ids, _values, _data);
        }

        return this.onERC1155BatchReceived.selector;
    }
}


// File: lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

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
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

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
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// File: lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC721.sol)

pragma solidity ^0.8.0;

import "../token/ERC721/IERC721.sol";


// File: lib/openzeppelin-contracts/contracts/interfaces/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC1155.sol)

pragma solidity ^0.8.0;

import "../token/ERC1155/IERC1155.sol";


// File: src/contracts/utils/Errors.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * A collection of generic errors that can be referenced across multiple
 * contracts. Contract-specific errors should still be stored in their
 * individual Solidity files.
 */

/// If a NULL address tries to be stored which should not be accepted
error CannotSetNullAddress();

/// If the caller has entered an insufficient amount to process the action. This
/// will likely be a zero amount.
error InsufficientAmount();

/// If the caller enters a percentage value that is too high for the requirements
error PercentageTooHigh(uint amount);

/// If a required ETH or token `transfer` call fails
error TransferFailed();

/// If a user calls a deposit related function with a zero amount
error CannotDepositZeroAmount();

/// If a user calls a withdrawal related function with a zero amount
error CannotWithdrawZeroAmount();

/// If there are no rewards available to be claimed
error NoRewardsAvailableToClaim();

/// If the requested collection is not approved
/// @param collection Address of the collection requested
error CollectionNotApproved(address collection);

/// If the requested strategy implementation is not approved
/// @param strategyImplementation Address of the strategy implementation requested
error StrategyNotApproved(address strategyImplementation);


// File: src/contracts/strategies/BaseStrategy.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {InsufficientAmount} from '@floor/utils/Errors.sol';

import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';

/// If a zero amount is sent to be deposited
error ZeroAmountReceivedFromDeposit();

/// If a zero amount is sent to be withdrawn
error ZeroAmountReceivedFromWithdraw();

/// If the caller has an insufficient position to withdraw from
/// @param amount The amount requested to withdraw
/// @param position The amount available to withdraw for the caller
error InsufficientPosition(address token, uint amount, uint position);

/**
 * Provides underlying logic for all strategies that handles common logic. This includes
 * storing the total pending rewards and taking snapshots to maintain epoch earned yield.
 */
abstract contract BaseStrategy is IBaseStrategy, Initializable, Ownable, Pausable, ReentrancyGuard {
    /**
     * The human-readable name of the strategy.
     */
    bytes32 public name;

    /**
     * The numerical ID of the strategy that acts as an index for the {StrategyFactory}.
     *
     * @dev This must be set in the initializer function call.
     */
    uint public strategyId;

    /**
     * The amount of rewards claimed in the last claim call.
     */
    mapping(address => uint) public lastEpochRewards;

    /**
     * This will return the internally tracked value of tokens that have been harvested
     * by the strategy.
     */
    mapping(address => uint) public lifetimeRewards;

    /**
     * Maintain a list of active positions held by depositing users.
     */
    mapping(address => uint) public position;

    /**
     * Stores a list of tokens that the strategy supports.
     */
    mapping(address => bool) internal _validTokens;

    /**
     * Gets a read of new yield since the last call. This is what can be called when
     * the epoch ends to determine the amount generated within the epoch.
     *
     * @return tokens_ Tokens that have been generated as yield
     * @return amounts_ The amount of yield generated for the corresponding token
     */
    function snapshot() external onlyOwner returns (address[] memory tokens_, uint[] memory amounts_) {
        // Get all the available tokens
        (tokens_, amounts_) = this.totalRewards();

        // Find the token difference available
        uint length = amounts_.length;
        for (uint i; i < length;) {
            // Capture the current total rewards for the token
            uint totalRewardsForToken = amounts_[i];

            // Remove the last epoch rewards from our amount returned to show how much
            // additional has been earned in the epoch
            amounts_[i] -= lastEpochRewards[tokens_[i]];

            // We can then update our epoch rewards amount for the token
            lastEpochRewards[tokens_[i]] = totalRewardsForToken;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * The total amount of rewards generated by the strategy.
     */
    function totalRewards() public view returns (address[] memory tokens_, uint[] memory amounts_) {
        // Get all the available tokens
        (tokens_, amounts_) = this.available();
        uint tokensLength = tokens_.length;

        // Add our lifetime rewards
        for (uint i; i < tokensLength;) {
            amounts_[i] += lifetimeRewards[tokens_[i]];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() public view virtual returns (address[] memory, uint[] memory) {
        revert('Not implemented');
    }

    /**
     * Extracts all rewards from third party and moves it to a recipient. This should
     * only be called by a specific action.
     *
     * @dev The recipient _should_ always be set to the {Treasury} by the {StrategyFactory}.
     */
    function harvest(address /* _recipient */ ) external virtual onlyOwner {
        revert('Not implemented');
    }

    /**
     * Returns an array of tokens that the strategy supports.
     *
     * @return address[] The address of valid tokens
     */
    function validTokens() public view virtual returns (address[] memory) {
        revert('Not implemented');
    }

    /**
     * Allows for liquidation of the strategy based on a percentage value. This withdraws the
     * percentage of the underlying tokens that were initially deposited, using the relevant
     * withdraw functions.
     *
     * The tokens will be withdrawn to the caller of the function, so relevant permissions should
     * be checked.
     *
     * @dev This must be implemented in each strategy.
     *
     * @return The tokens that have been withdrawn
     * @return The amount of tokens withdrawn
     */
    function withdrawPercentage(address /* recipient */, uint /* percentage */) external virtual onlyOwner returns (address[] memory, uint[] memory) {
        revert('Not implemented');
    }

    /**
     * Pauses deposits from being made into the strategy.
     *
     * @dev This should only be called by a guardian or governor.
     *
     * @param _p Boolean value for if the strategy should be paused
     */
    function pause(bool _p) external onlyOwner {
        if (_p) _pause();
        else _unpause();
    }

    /**
     * Confirms that the requested single token is valid before processing a function.
     *
     * @param token A token address that must be valid
     */
    modifier onlyValidToken(address token) {
        require(_validTokens[token], 'Invalid token');
        _;
    }

    /**
     * Confirms that the requested tokens are all valid before processing a function.
     *
     * @param tokens An array of tokens that must all be valid
     */
    modifier onlyValidTokens(address[] memory tokens) {
        // Iterate over tokens to ensure that they are registered as valid. If they
        // aren't then we will revert the call before processing.
        uint length = tokens.length;
        for (uint i; i < length;) {
            require(_validTokens[tokens[i]], 'Invalid token');
            unchecked {
                ++i;
            }
        }

        _;
    }
}


// File: src/interfaces/nftx/NFTXVault.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXVault {
    function manager() external view returns (address);
    function assetAddress() external view returns (address);

    function is1155() external view returns (bool);
    function allowAllItems() external view returns (bool);
    function enableMint() external view returns (bool);
    function enableRandomRedeem() external view returns (bool);
    function enableTargetRedeem() external view returns (bool);
    function enableRandomSwap() external view returns (bool);
    function enableTargetSwap() external view returns (bool);

    function vaultId() external view returns (uint);
    function nftIdAt(uint holdingsIndex) external view returns (uint);
    function allHoldings() external view returns (uint[] memory);
    function totalHoldings() external view returns (uint);
    function mintFee() external view returns (uint);
    function randomRedeemFee() external view returns (uint);
    function targetRedeemFee() external view returns (uint);
    function randomSwapFee() external view returns (uint);
    function targetSwapFee() external view returns (uint);
    function vaultFees() external view returns (uint, uint, uint, uint, uint);

    function redeem(uint amount, uint[] calldata specificIds) external returns (uint[] calldata);

    function redeemTo(uint amount, uint[] calldata specificIds, address to) external returns (uint[] calldata);
}


// File: src/interfaces/nftx/NFTXInventoryStaking.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXInventoryStaking {
    function inventoryLockTimeErc20() external returns (uint);

    function __NFTXInventoryStaking_init(address _nftxVaultFactory) external;

    function setTimelockExcludeList(address addr) external;

    function setInventoryLockTimeErc20(uint time) external;

    function isAddressTimelockExcluded(address addr, uint vaultId) external view returns (bool);

    function deployXTokenForVault(uint vaultId) external;

    function receiveRewards(uint vaultId, uint amount) external returns (bool);

    function deposit(uint vaultId, uint _amount) external;

    function timelockMintFor(uint vaultId, uint amount, address to, uint timelockLength) external returns (uint);

    function withdraw(uint vaultId, uint _share) external;

    function xTokenShareValue(uint vaultId) external view returns (uint);

    function timelockUntil(uint vaultId, address who) external view returns (uint);

    function balanceOf(uint vaultId, address who) external view returns (uint);

    function xTokenAddr(address baseToken) external view returns (address);

    function vaultXToken(uint vaultId) external view returns (address);
}


// File: src/interfaces/nftx/NFTXStakingZap.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXStakingZap {
    function lpLockTime() external returns (uint);

    function inventoryLockTime() external returns (uint);

    function assignStakingContracts() external;

    function setTimelockExcludeList(address addr) external;

    function setLPLockTime(uint newLPLockTime) external;

    function setInventoryLockTime(uint newInventoryLockTime) external;

    function isAddressTimelockExcluded(address addr, uint vaultId) external view returns (bool);

    function provideInventory721(uint vaultId, uint[] calldata tokenIds) external;

    function provideInventory1155(uint vaultId, uint[] calldata tokenIds, uint[] calldata amounts) external;

    function addLiquidity721ETH(uint vaultId, uint[] calldata ids, uint minWethIn) external payable returns (uint);

    function addLiquidity721ETHTo(uint vaultId, uint[] memory ids, uint minWethIn, address to) external payable returns (uint);

    function addLiquidity1155ETH(uint vaultId, uint[] calldata ids, uint[] calldata amounts, uint minEthIn)
        external
        payable
        returns (uint);

    function addLiquidity1155ETHTo(uint vaultId, uint[] memory ids, uint[] memory amounts, uint minEthIn, address to)
        external
        payable
        returns (uint);

    function addLiquidity721(uint vaultId, uint[] calldata ids, uint minWethIn, uint wethIn) external returns (uint);

    function addLiquidity721To(uint vaultId, uint[] memory ids, uint minWethIn, uint wethIn, address to) external returns (uint);

    function addLiquidity1155(uint vaultId, uint[] memory ids, uint[] memory amounts, uint minWethIn, uint wethIn)
        external
        returns (uint);

    function addLiquidity1155To(uint vaultId, uint[] memory ids, uint[] memory amounts, uint minWethIn, uint wethIn, address to)
        external
        returns (uint);

    function rescue(address token) external;
}


// File: src/interfaces/nftx/NFTXUnstakingInventoryZap.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXUnstakingInventoryZap {
    function unstakeInventory(uint vaultId, uint numNfts, uint remainingPortionToUnstake) external payable;

    function maxNftsUsingXToken(uint vaultId, address staker, address slpToken) external returns (uint numNfts, bool shortByTinyAmount);
}


// File: lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

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


// File: lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Permit.sol)

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


// File: lib/openzeppelin-contracts/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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


// File: lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

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
}


// File: lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

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
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
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
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// File: lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
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
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}


// File: lib/openzeppelin-contracts/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
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
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
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


// File: lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/Initializable.sol)

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
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
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
            (isTopLevelCall && _initialized < 1) || (!Address.isContract(address(this)) && _initialized == 1),
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
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
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


// File: lib/openzeppelin-contracts/contracts/security/Pausable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
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
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
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
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


// File: src/interfaces/strategies/BaseStrategy.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Strategies will hold the logic for interacting with external platforms to stake
 * and harvest reward yield. Each strategy will require its own strategy implementation
 * to allow for different immutable variables to be defined during construct.
 *
 * This will follow a similar approach to how NFTX offer their eligibility module
 * logic, with a lot of the power coming from inheritence.
 *
 * When constructed, we want to give the {Treasury} a max uint approval of the yield
 * and underlying tokens.
 */
interface IBaseStrategy {
    /// @dev When strategy receives a deposit
    event Deposit(address token, uint amount, address caller);

    /// @dev When strategy is harvested
    event Harvest(address token, uint amount);

    /// @dev When a staked user exits their position
    event Withdraw(address token, uint amount, address recipient);

    /**
     * Allows the strategy to be initialised.
     */
    function initialize(bytes32 name, uint strategyId, bytes calldata initData) external;

    /**
     * Name of the strategy.
     */
    function name() external view returns (bytes32);

    /**
     * The numerical ID of the strategy that acts as an index for the {StrategyFactory}.
     */
    function strategyId() external view returns (uint);

    /**
     * Total rewards generated by the strategy in all time. This is pure bragging rights.
     */
    function lifetimeRewards(address token) external returns (uint amount_);

    /**
     * The amount of rewards claimed in the last claim call.
     */
    function lastEpochRewards(address token) external returns (uint amount_);

    /**
     * Gets rewards that are available to harvest.
     */
    function available() external returns (address[] memory, uint[] memory);

    /**
     * Extracts all rewards from third party and moves it to a recipient. This should
     * only be called by a specific action.
     *
     * @dev This _should_ always be imposed to be the {Treasury} by the {StrategyFactory}.
     */
    function harvest(address /* _recipient */ ) external;

    /**
     * Returns an array of tokens that the strategy supports.
     *
     * @return address[] The address of valid tokens
     */
    function validTokens() external view returns (address[] memory);

    /**
     * Makes a call to a strategy to withdraw a percentage of the deposited holdings.
     *
     * @param recipient Strategy address to be updated
     * @param percentage The 2 decimal accuracy of the percentage to withdraw (e.g. 100% = 10000)
     *
     * @return address[] Array of tokens withdrawn
     * @return uint[] Amounts of respective tokens withdrawn
     */
    function withdrawPercentage(address recipient, uint percentage) external returns (address[] memory, uint[] memory);

    /**
     * Pauses deposits from being made into the strategy. This should only be called by
     * a guardian or governor.
     *
     * @param _p Boolean value for if the strategy should be paused
     */
    function pause(bool _p) external;

    /**
     * Gets a read of new yield since the last call. This is what can be called when
     * the epoch ends to determine the amount generated within the epoch.
     */
    function snapshot() external returns (address[] memory, uint[] memory);
}


// File: lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol
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


// File: lib/openzeppelin-contracts/contracts/utils/Context.sol
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


