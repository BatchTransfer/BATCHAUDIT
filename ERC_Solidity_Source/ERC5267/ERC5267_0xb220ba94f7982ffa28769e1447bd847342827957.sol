// File: src/MurePool.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {
    ERC165Upgradeable, IERC165
} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {PoolMetrics, PoolParameters, PoolParameter, PoolErrorReason, Poolable} from "./interfaces/Poolable.sol";
import {PoolMetadata, PoolState} from "./interfaces/PoolMetadata.sol";
import {DepositRecord} from "./interfaces/Depositable.sol";
import {Delegatable} from "./interfaces/Delegatable.sol";
import {PoolApp} from "./interfaces/PoolApp.sol";
import {Depositable} from "./interfaces/Depositable.sol";
import {Refundable} from "./interfaces/Refundable.sol";
import {Config} from "./interfaces/Config.sol";
import {MureErrors} from "./libraries/MureErrors.sol";
import {POOL_OPERATOR_ROLE} from "./shared/Constants.sol";

/**
 * @title MurePool
 * @author Mure
 *
 * @notice Facilitates secure and configurable pool management, supporting operations such as
 * pool creation, deposits, withdrawals, and refunds.
 *
 * @dev Core implementation contract for pooled investments in the Mure protocol.
 * Utilizes the beacon proxy pattern to deploy multiple proxies, each representing
 * a distinct application within the protocol. The MureFactory contract handles
 * these deployments.
 *
 * Implements the EIP-712 standard for signature validation, preventing unauthorized access.
 * Relies on the MureConfig contract to verify EIP-712 signatures and manage the pool
 * creation process. Interaction with the MureConfig contract allows dynamic configuration
 * and signature validation.
 *
 * Security measures include the OpenZeppelin PausableUpgradeable pattern for emergency pausing,
 * ReentrancyGuardUpgradeable to prevent reentrancy attacks, and role based access control
 * through AccessControlUpgradeable.
 *
 * Flag-based functionality enables features like refundability, passthrough of funds, and more.
 * Provides hooks for custom functionality in pool-related operations
 *
 * Depending on the kind of application, the MurePool proxy instance could be linked to a MureDelegate
 * proxy instance for interacting with various plugins that the protocol provides.
 */
contract MurePool is
    EIP712Upgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    ERC165Upgradeable,
    AccessControlUpgradeable,
    PoolApp
{
    /// @custom:storage-location erc7201:mure.MurePool
    struct MurePoolStorage {
        mapping(string => PoolState) pools;
        mapping(string => mapping(address => DepositRecord)) deposits;
        uint24 nonce;
    }

    /// @custom:storage-location erc7201:mure.PoolMetrics
    struct PoolMetricsStorage {
        mapping(string => PoolMetrics) poolMetrics;
    }

    /**
     * @dev Hash for storage location
     * `keccak256(abi.encode(uint256(keccak256("mure.MurePool")) - 1)) & ~bytes32(uint256(0xff))`
     */
    bytes32 private constant MurePoolStorageLocation =
        0x79bd164051f83036bb52eee1d9b6be5ba887eaf3a9d8907adbaadfa56c970700;

    /**
     * @dev Hash for storage location
     * `keccak256(abi.encode(uint256(keccak256("mure.PoolMetrics")) - 1)) & ~bytes32(uint256(0xff))`
     */
    bytes32 private constant PoolMetricsStorageLocation =
        0x1ca3e723ed845754b3d7cf12c13e1b284ab752e694e983a627f991c98b3a0700;

    /**
     * @dev Struct hash for validating deposits
     * `keccak256("Deposit(uint256 amount,string pool,address depositor,uint8 nonce)")`
     */
    bytes32 private constant DEPOSIT_HASH = 0xc5b44054231c7194afce4ed4062c5abd2c0cb26e0686f9ba69d2cfc04b490e33;

    /**
     * @dev Struct hash for validating pool creation
     * `keccak256("CreatePool(string pool,uint32 endTime,uint24 nonce)")`
     */
    bytes32 private constant CREATE_POOL_HASH = 0x38c6f9238aff6821963f06d84f958ebb018ff9e4343c962882ef7b3308ff1b4d;

    /**
     * @dev Address for the MureConfig contract
     * @dev Update config address
     */
    address constant MURE_CONFIG = 0xDc86A042e7a49B60EC1022ec2169B62cc2750457;

    /**
     * @dev Defines if the pool is initialized
     */
    uint16 constant INITIALIZED = 0x01;

    /**
     * @dev Defines if the pool is paused from any interaction
     */
    uint16 constant PAUSED = 0x02;

    /**
     * @dev Defines if deposits should pass straight to associtated raising wallet upon deposit
     * @notice `PASSTHROUGH_FUNDS` and `REFUNDABLE` cannot be set at the same time
     */
    uint16 constant PASSTHROUGH_FUNDS = 0x04;

    /**
     * @dev Defines if the pool is open for claiming refunds
     * @notice `PASSTHROUGH_FUNDS` and `REFUNDABLE` cannot be set at the same time
     */
    uint16 constant REFUNDABLE = 0x08;

    /**
     * @dev Defines if the pool is having tiers and gating
     */
    uint16 constant TIERED = 0x10;

    /**
     * @dev Defines if the pool is cross-chain enabled, pooling funds across different networks
     */
    uint16 constant CROSS_CHAIN = 0x20;

    /**
     * @dev Defines if the pool allows for use of delegated wallets for security
     */
    uint16 constant DELEGATED = 0x40;

    modifier poolValid(string calldata poolName) {
        if (!_poolExists(poolName)) {
            revert MureErrors.PoolNotFound();
        }
        _;
    }

    modifier poolActive(string calldata poolName) {
        if (_hasFlag(_getStorage().pools[poolName].flags, PAUSED)) {
            revert PoolPaused();
        }
        if (_poolComplete(poolName)) {
            revert PoolClosed();
        }
        _;
    }

    modifier poolNotPaused(string calldata poolName) {
        if (_hasFlag(_getStorage().pools[poolName].flags, PAUSED)) {
            revert PoolPaused();
        }
        _;
    }

    modifier valid(PoolParameters calldata params) {
        _verifyParams(params);
        _;
    }

    modifier onlyDelegateOrOperator() {
        address delegate = _getDelegateAddress();

        if (_msgSender() != delegate && !hasRole(POOL_OPERATOR_ROLE, _msgSender())) {
            revert MureErrors.Unauthorized();
        }
        _;
    }

    modifier onlyDelegate() {
        address delegate = _getDelegateAddress();

        if (_msgSender() != delegate) {
            revert MureErrors.Unauthorized();
        }
        _;
    }

    modifier notDelegated() {
        address delegate = _getDelegateAddress();

        if (delegate != address(0)) {
            revert MureErrors.Unauthorized();
        }
        _;
    }

    function initialize(string calldata name, string calldata version, address owner) external initializer {
        __EIP712_init(name, version);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(POOL_OPERATOR_ROLE, owner);
    }

    /**
     * @notice Creates a new pool with the specified parameters.
     * @dev Requires the pool to not already exist. Can only be called by a pool operator.
     * @param poolName the name of the pool to create
     * @param params the parameters for the new pool
     * @param sig the signature generated for pool creation for client
     */
    function createPool(string calldata poolName, PoolParameters calldata params, bytes memory sig)
        external
        onlyRole(POOL_OPERATOR_ROLE)
        valid(params)
    {
        if (_poolExists(poolName)) {
            revert PoolInitialized();
        }

        MurePoolStorage storage storage_ = _getStorage();

        // The MureConfig checks the validity of the signature
        Config(MURE_CONFIG).verifyMureSignature(_hashCreatePool(poolName, params.endTime), sig);

        storage_.pools[poolName] = PoolState({
            poolSize: params.poolSize,
            totalCollected: 0,
            endTime: params.endTime,
            signer: params.signer,
            depositors: 0,
            currency: params.currency,
            custodian: params.custodian,
            flags: params.flags | INITIALIZED // Ensure pool is always marked as `initialized`
        });

        unchecked {
            ++storage_.nonce;
        }

        emit PoolCreation(poolName);
    }

    /**
     * @notice Updates the specified pool with the provided parameters.
     * @dev Requires the pool to exist. Can only be called by a pool operator.
     * @dev Requires the updated pool size to be greater than or equal to the total amount collected.
     * @param poolName the name of the pool to update
     * @param params the updated parameters for the pool
     */
    function updatePool(string calldata poolName, PoolParameters calldata params)
        external
        onlyRole(POOL_OPERATOR_ROLE)
        valid(params)
        poolValid(poolName)
    {
        MurePoolStorage storage storage_ = _getStorage();
        PoolState storage state_ = storage_.pools[poolName];

        _verifyPoolSize(state_.totalCollected, params.poolSize);

        if (
            state_.totalCollected > 0
                && _hasFlag(state_.flags, PASSTHROUGH_FUNDS) != _hasFlag(params.flags, PASSTHROUGH_FUNDS)
        ) {
            revert IllegalPoolOperation(PoolErrorReason.ALREADY_INVESTED_POOL);
        }

        state_.poolSize = params.poolSize;
        state_.endTime = params.endTime;
        state_.signer = params.signer;
        state_.currency = params.currency;
        state_.custodian = params.custodian;
        state_.flags = params.flags | INITIALIZED; // Ensure pool is always marked as `initialized`

        emit PoolUpdate(poolName);
    }

    /**
     * @notice Updates the size of the specified pool.
     * @dev Requires the pool to exist. Can only be called by a pool operator.
     * @dev Requires the new pool size to be greater than or equal to the total amount collected.
     * @param poolName the name of the pool to update
     * @param poolSize the updated size of the pool
     */
    function updatePoolSize(string calldata poolName, uint256 poolSize)
        external
        onlyRole(POOL_OPERATOR_ROLE)
        poolValid(poolName)
    {
        PoolState storage pool = _getStorage().pools[poolName];

        _verifyPoolSize(pool.totalCollected, uint112(poolSize));

        pool.poolSize = uint112(poolSize);

        emit PoolUpdate(poolName);
    }

    /**
     * @notice Updates the end time of the specified pool.
     * @dev Requires the pool to exist. Can only be called by a pool operator.
     * @param poolName the name of the pool to update
     * @param endTime the updated end time for the pool
     */
    function updatePoolEndTime(string calldata poolName, uint256 endTime)
        external
        onlyRole(POOL_OPERATOR_ROLE)
        poolValid(poolName)
    {
        if (endTime < block.timestamp) {
            revert IllegalPoolState(PoolParameter.END_TIME);
        }

        _getStorage().pools[poolName].endTime = uint32(endTime);

        emit PoolUpdate(poolName);
    }

    /**
     * @notice Updates the signer of the specified pool.
     * @dev Requires the pool to exist. Can only be called by a pool operator.
     * @param poolName the name of the pool to update
     * @param _signer the updated signer for the pool
     */
    function updatePoolSigner(string calldata poolName, address _signer)
        external
        onlyRole(POOL_OPERATOR_ROLE)
        poolValid(poolName)
    {
        if (_signer == address(0)) {
            revert IllegalPoolState(PoolParameter.SIGNER);
        }

        _getStorage().pools[poolName].signer = _signer;

        emit PoolUpdate(poolName);
    }

    /**
     * @notice Pauses or unpauses the specified pool.
     * @dev Requires the pool to exist. Can only be called by a pool operator or delegate.
     * @param poolName the name of the pool to pause or unpause
     * @param pause a boolean representing whether to pause or unpause the pool
     */
    function updatePoolPaused(string calldata poolName, bool pause)
        external
        onlyDelegateOrOperator
        poolValid(poolName)
    {
        PoolState storage pool = _getStorage().pools[poolName];

        pool.flags = pause ? _activateFlag(pool.flags, PAUSED) : _deactivateFlag(pool.flags, PAUSED);

        emit PoolUpdate(poolName);
    }

    /**
     * @notice Updates whether the specified pool allows refunds or not.
     * @dev Requires the pool to exist. Can only be called by a pool operator.
     * @dev Requires that the pool does not have the `PASSTHROUGH_FUNDS` flag set if enabling refunds.
     * @param poolName the name of the pool to update
     * @param refundable a boolean representing whether refunds should be enabled or not
     */
    function updatePoolRefundable(string calldata poolName, bool refundable)
        external
        onlyDelegateOrOperator
        poolValid(poolName)
    {
        PoolState storage pool = _getStorage().pools[poolName];

        if (_hasFlag(pool.flags, PASSTHROUGH_FUNDS) && refundable) {
            revert IllegalPoolState(PoolParameter.FLAGS);
        }

        pool.flags = refundable ? _activateFlag(pool.flags, REFUNDABLE) : _deactivateFlag(pool.flags, REFUNDABLE);

        emit PoolUpdate(poolName);
    }

    /**
     * @notice Updates whether the specified pool passes funds through to the custodian directly or not.
     * @dev Requires the pool to exist. Can only be called by a pool operator.
     * @dev Requires that the pool does not have the `REFUNDABLE` flag set if enabling passthrough funds.
     * @param poolName the name of the pool to update
     * @param passthroughFunds a boolean representing whether to enable passthrough funds or not
     */
    function updatePoolPassthroughFunds(string calldata poolName, bool passthroughFunds)
        external
        onlyRole(POOL_OPERATOR_ROLE)
        poolValid(poolName)
    {
        PoolState storage pool = _getStorage().pools[poolName];

        if (_hasFlag(pool.flags, REFUNDABLE) && passthroughFunds) {
            revert IllegalPoolState(PoolParameter.FLAGS);
        }

        if (pool.totalCollected > 0) {
            revert IllegalPoolOperation(PoolErrorReason.ALREADY_INVESTED_POOL);
        }

        pool.flags = passthroughFunds
            ? _activateFlag(pool.flags, PASSTHROUGH_FUNDS)
            : _deactivateFlag(pool.flags, PASSTHROUGH_FUNDS);

        emit PoolUpdate(poolName);
    }

    /**
     * @notice Withdraws the total collected amount from the specified pool.
     * @dev Requires the pool to exist. Can only be called by a pool operator or the delegate if it is set.
     * @param poolName the name of the pool to withdraw from
     */
    function withdrawPoolFunds(string calldata poolName) external onlyDelegateOrOperator poolValid(poolName) {
        PoolState storage pool = _getStorage().pools[poolName];
        PoolMetrics storage poolMetrics = _getPoolMetricsStorage().poolMetrics[poolName];

        if (_hasFlag(pool.flags, PASSTHROUGH_FUNDS) || _hasFlag(pool.flags, REFUNDABLE)) {
            revert IllegalPoolOperation(PoolErrorReason.INVALID_POOL_TYPE);
        }

        uint256 amount = pool.totalCollected - poolMetrics.totalWithdrawn;
        poolMetrics.totalWithdrawn += uint112(amount);

        if (amount == 0) {
            revert IllegalPoolOperation(PoolErrorReason.POOL_EMPTY);
        }

        (uint256 fee, address feeRecipient) = Config(MURE_CONFIG).getPoolFee(address(this), poolName, amount);

        IERC20 currency = IERC20(pool.currency);
        currency.transfer(address(pool.custodian), amount - fee);

        if (fee > 0 && feeRecipient != address(0)) {
            currency.transfer(address(feeRecipient), fee);
        }

        emit Withdrawal(poolName, amount, address(pool.custodian), "");
    }

    /**
     * @notice Withdraw any token from the contract. This should only be used in emergencies
     * as this can withdraw capital from any pool, be it active or not. Always prefer using `withdrawPoolFunds`
     * over this function, unless you need clean up the contract by, e.g., burning garbage tokens.
     * @param receiver the address to which the token will be transferred
     * @param currency the address of the token contract
     */
    function withdrawCurrency(address receiver, address currency) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20 currency_ = IERC20(currency);
        uint256 balance = currency_.balanceOf(address(this));
        currency_.transfer(receiver, balance);

        emit Withdrawal("", balance, receiver, "");
    }

    /**
     * @notice Adds a deposit of the specified amount to the pool for the designated depositor.
     * @dev Requires the pool to exist. Can only be called by a pool operator.
     * @param poolName the name of the pool to add the deposit to
     * @param depositor the address of the depositor
     * @param amount the amount of the deposit
     */
    function addDeposit(string calldata poolName, address depositor, uint256 amount)
        external
        onlyRole(POOL_OPERATOR_ROLE)
        poolValid(poolName)
    {
        _addDeposit(poolName, depositor, amount, "");
        _getStorage().pools[poolName].totalCollected += uint112(amount);
    }

    /**
     * @notice Deducts the specified amount from the deposit of the designated depositor in the pool.
     * @dev Requires the pool to exist. Can only be called by a pool operator.
     * @param poolName the name of the pool to deduct the deposit from
     * @param depositor the address of the depositor
     * @param amount the amount to deduct
     */
    function deductDeposit(string calldata poolName, address depositor, uint256 amount)
        external
        onlyRole(POOL_OPERATOR_ROLE)
        poolValid(poolName)
    {
        _deductDeposit(poolName, depositor, amount, "");
        _getStorage().pools[poolName].totalCollected -= uint112(amount);
    }

    /**
     * @notice Moves the specified amount from one depositor's deposit to another in the pool.
     * @dev Requires the pool to exist. Can only be called by a pool operator.
     * @param poolName the name of the pool to move the deposit in
     * @param from the address of the depositor to deduct the deposit from
     * @param to the address of the depositor to add the deposit to
     * @param amount the amount to move
     */
    function moveDeposit(string calldata poolName, address from, address to, uint256 amount)
        external
        onlyRole(POOL_OPERATOR_ROLE)
        poolValid(poolName)
    {
        _deductDeposit(poolName, from, amount, "");
        _addDeposit(poolName, to, amount, "");
    }

    /**
     * @notice Adds or deducts balances on a per-depositor basis in batches.
     * @dev Requires the pool to exist. Can only be called by the contract owner.
     * @param poolName the name of the pool to move the deposit in
     * @param transactions the set of `Transaction`s to execute on the provided `poolName`
     */
    function batchDeposit(string calldata poolName, Transaction[] calldata transactions)
        external
        onlyRole(POOL_OPERATOR_ROLE)
        poolValid(poolName)
    {
        int256 totalDelta;

        Transaction calldata transaction;
        uint256 amount;

        for (uint256 i = 0; i < transactions.length;) {
            transaction = transactions[i];
            amount = transaction.amount;
            if (transaction.operation == Operation.Deposit) {
                _addDeposit(poolName, transaction.depositor, amount, "");
                unchecked {
                    totalDelta += int256(amount);
                }
            } else {
                _deductDeposit(poolName, transaction.depositor, amount, "");
                unchecked {
                    totalDelta -= int256(amount);
                }
            }

            unchecked {
                ++i;
            }
        }

        PoolState storage pool = _getStorage().pools[poolName];
        if (uint256(int256(int112(pool.totalCollected)) + totalDelta) > pool.poolSize) {
            revert PoolFull();
        }

        unchecked {
            if (totalDelta < 0) {
                pool.totalCollected -= uint112(int112(totalDelta));
            } else if (totalDelta > 0) {
                pool.totalCollected += uint112(int112(totalDelta));
            }
        }
    }

    /**
     * @notice Deposits `amount` of the relevant currency for the pool `poolName`.
     * This operation assumes that the contract is an approved spender of the depositor.
     * This operation is disabled for delegated pools, use depositFor instead
     *
     * @param poolName bytes32 representation of the pool name
     * @param amount the amount the user want to invest. Need that for accounting
     * @param sig the signatures generated for the user, including the amount.
     * and verifying the signature.
     */
    function deposit(string calldata poolName, uint256 amount, bytes calldata sig) external notDelegated {
        _deposit(poolName, amount, _msgSender(), "", sig);
    }

    /**
     * @notice Deposits `amount` of the relevant currency for the pool `poolName`.
     * This operation assumes that the contract is an approved spender of the depositor.
     * This operation is disabled for delegated pools, use depositFor instead
     *
     * @param poolName bytes32 representation of the pool name
     * @param amount the amount the user want to invest. Need that for accounting
     * @param data additional data as contextual data for off-chain validation
     * @param sig the signatures generated for the user, including the amount.
     * and verifying the signature.
     */
    function deposit(string calldata poolName, uint256 amount, bytes calldata data, bytes calldata sig)
        external
        notDelegated
    {
        _deposit(poolName, amount, _msgSender(), data, sig);
    }

    /**
     * @notice Deposits `amount` of the relevant currency for the pool `poolName`.
     * This operation assumes that the contract is an approved spender of the depositor.
     *
     * @param poolName bytes32 representation of the pool name
     * @param amount the amount the user want to invest. Need that for accounting
     * @param depositor address of the depositor.
     * @param sig the signatures generated for the user, including the amount.
     */
    function depositFor(string calldata poolName, uint256 amount, address depositor, bytes calldata sig)
        external
        onlyDelegate
    {
        _deposit(poolName, amount, depositor, "", sig);
    }

    /**
     * @notice Allows a user to refund their deposited amount from the specified pool.
     * This operation is disabled for delegated pools, use refundTo instead.
     * @dev Requires the pool to exist.
     * @dev Requires the pool to be not paused and must have the `REFUNDABLE` flag set.
     * @param poolName the name of the pool from which to refund
     */
    function refund(string calldata poolName) external notDelegated {
        uint256 amount = _getStorage().deposits[poolName][_msgSender()].amount;

        if (amount == 0) {
            revert DepositNotFound();
        }

        _refund(poolName, _msgSender(), amount, "");
    }

    /**
     * @notice Allows a user to refund their deposited amount from the specified pool.
     * This operation is disabled for delegated pools, use refundTo instead.
     * @dev Requires the pool to exist.
     * @dev Requires the pool to be not paused and must have the `REFUNDABLE` flag set.
     * @param poolName the name of the pool from which to refund
     * @param data additional data as contextual data for off-chain validation
     */
    function refund(string calldata poolName, bytes calldata data) external notDelegated {
        MurePoolStorage storage storage_ = _getStorage();
        uint256 amount = storage_.deposits[poolName][_msgSender()].amount;

        if (amount == 0) {
            revert DepositNotFound();
        }

        _refund(poolName, _msgSender(), amount, data);
    }

    /**
     * @notice Allows a refund of the deposited amount from the specified pool.
     * @dev Requires the pool to exist.
     * @dev Requires the pool to be not paused and must have the `REFUNDABLE` flag set.
     * @param poolName the name of the pool from which to refund
     * @param depositor address of the depositor
     */
    function refundTo(string calldata poolName, address depositor, uint256 amount) external onlyDelegate {
        _refund(poolName, depositor, amount, "");
    }

    /**
     * @notice Deposits the withdrawn pool funds back.
     * This operation assumes that the contract is an approved spender of the depositor.
     * @dev Transfers the original collected funds back to the pool app
     * @param poolName name of the pool
     * @param depositor the address of the depositor
     * @param amount the amount to be deposited back to the pool
     */
    function depositPoolFunds(string calldata poolName, address depositor, uint256 amount) external onlyDelegate {
        _depositPoolFunds(poolName, depositor, amount);
    }

    /**
     * @notice Retrieves the state of the specified pool.
     * @dev Requires the pool to exist.
     * @param poolName the name of the pool to retrieve the state of
     */
    function poolState(string calldata poolName) external view poolValid(poolName) returns (PoolState memory) {
        return _getStorage().pools[poolName];
    }

    /**
     * @notice Retrieves the metrics of the specified pool.
     * @dev Requires the pool to exist.
     * @param poolName the name of the pool to retrieve the metrics of
     */
    function poolMetrics(string calldata poolName) external view poolValid(poolName) returns (PoolMetrics memory) {
        return _getPoolMetricsStorage().poolMetrics[poolName];
    }

    /**
     * @notice Retrieves the amount deposited by the specified depositor in the specified pool.
     * @dev Requires the pool to exist.
     * @param poolName the name of the pool to retrieve the deposit from
     * @param depositor the address of the depositor
     */
    function deposited(string calldata poolName, address depositor)
        external
        view
        poolValid(poolName)
        returns (uint256)
    {
        return _getStorage().deposits[poolName][depositor].amount;
    }

    /**
     * @notice Retrieves the nonce of the specified depositor in the specified pool.
     * @dev Requires the pool to exist.
     * @param poolName the name of the pool to retrieve the nonce from
     * @param depositor the address of the depositor
     */
    function nonce(string calldata poolName, address depositor) external view poolValid(poolName) returns (uint8) {
        return _getStorage().deposits[poolName][depositor].nonce;
    }

    /**
     * @notice Retrieves the nonce for create pool signature generation.
     */
    function nonce() external view returns (uint24) {
        return _getStorage().nonce;
    }

    /**
     * @notice Checks if the specified pool exists.
     * @param pool the name of the pool to check for existence
     */
    function poolExists(string calldata pool) external view returns (bool) {
        return _poolExists(pool);
    }

    /**
     * @notice Checks if the specified pool is active.
     * @param poolName the name of the pool to check if it is active
     */
    function isPoolActive(string calldata poolName) external view returns (bool) {
        PoolState storage pool = _getStorage().pools[poolName];
        return (!_hasFlag(pool.flags, PAUSED) && pool.endTime > block.timestamp);
    }

    /**
     * @notice Checks if the specified pool is active.
     * @param poolName the name of the pool to check if it is active
     */
    function withdrawableAmount(string calldata poolName) external view returns (uint112) {
        return
            _getStorage().pools[poolName].totalCollected - _getPoolMetricsStorage().poolMetrics[poolName].totalWithdrawn;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Upgradeable, IERC165, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(PoolApp).interfaceId || interfaceId == type(PoolMetadata).interfaceId
            || interfaceId == type(Poolable).interfaceId || interfaceId == type(Refundable).interfaceId
            || interfaceId == type(Depositable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @notice Deposits `amount` of the relevant currency for the pool `poolName`.
     * This operation assumes that the contract is an approved spender of the depositor.
     * @param poolName bytes32 representation of the pool name
     * @param amount the amount the user want to invest. Need that for accounting
     * @param depositor address of the depositor.
     * @param data additional data as contextual data for off-chain validation
     * @param sig the signatures generated for the user, including the amount.
     * and verifying the signature.
     */
    function _deposit(
        string calldata poolName,
        uint256 amount,
        address depositor,
        bytes memory data,
        bytes calldata sig
    ) private whenNotPaused nonReentrant poolValid(poolName) poolActive(poolName) {
        PoolState storage pool = _getStorage().pools[poolName];

        _verifySignature(amount, poolName, depositor, pool.signer, sig);

        if (_hasFlag(pool.flags, PASSTHROUGH_FUNDS)) {
            amount -= _deductFee(poolName, depositor, pool.currency, amount);
        }

        _beforeDeposit(_getDelegateAddress(), poolName, amount, depositor, sig);
        _addDeposit(poolName, depositor, amount, data);
        pool.totalCollected += uint112(amount);
        // Add scope to avoid stack too deep
        {
            address destinationAddress = _hasFlag(pool.flags, PASSTHROUGH_FUNDS) ? pool.custodian : address(this);
            _transferUpdate(depositor, destinationAddress, amount, pool.currency);
        }

        _afterDeposit(_getDelegateAddress(), poolName, amount, depositor, sig);
    }

    /**
     * @notice Allows a user to refund their deposited amount from the specified pool.
     * @dev Requires the pool to exist.
     * @dev Requires the pool to be not paused and must have the `REFUNDABLE` flag set.
     * @param poolName the name of the pool from which to refund
     * @param depositor address of the depositor to refund from
     * @param amount the amount to refund
     * @param data additional data as contextual data for off-chain validation
     */
    function _refund(string calldata poolName, address depositor, uint256 amount, bytes memory data)
        private
        nonReentrant
        whenNotPaused
        poolNotPaused(poolName)
        poolValid(poolName)
    {
        PoolState storage pool = _getStorage().pools[poolName];

        address delegateAddress = _getDelegateAddress();
        _beforeRefund(delegateAddress, poolName, depositor);

        if (!_hasFlag(pool.flags, REFUNDABLE)) {
            revert MureErrors.Unauthorized();
        }

        _deductDeposit(poolName, depositor, amount, data);
        pool.totalCollected -= uint112(amount);

        _transferUpdate(address(this), depositor, amount, pool.currency);

        _afterRefund(delegateAddress, poolName, depositor, amount);

        emit Refund(poolName, amount, depositor, data);
    }

    /**
     * @notice Deposits the withdrawn pool funds back.
     * @dev Transfers the original collected funds back to the pool app
     * @param poolName name of the pool
     * @param depositor the address of the depositor
     * @param amount the amount to be deposited back to the pool
     */
    function _depositPoolFunds(string calldata poolName, address depositor, uint256 amount) private nonReentrant {
        PoolState storage pool = _getStorage().pools[poolName];
        PoolMetrics storage poolMetrics = _getPoolMetricsStorage().poolMetrics[poolName];

        poolMetrics.totalWithdrawn -= uint112(amount);

        _transferUpdate(depositor, address(this), amount, pool.currency);
    }

    /**
     * @dev Adds deposit `amount` to designated `poolName` under `depositor`.
     * As `totalCollected` is bound by `poolSize`, overflow is not possible unless `poolSize`
     * is in a disallowed state to begin with.
     */
    function _addDeposit(string calldata poolName, address depositor, uint256 amount, bytes memory data) private {
        MurePoolStorage storage storage_ = _getStorage();
        PoolState storage state_ = storage_.pools[poolName];
        DepositRecord storage deposit_ = storage_.deposits[poolName][depositor];

        if (state_.totalCollected + amount > state_.poolSize) {
            revert PoolFull();
        }

        unchecked {
            deposit_.amount += uint112(amount);
            ++deposit_.nonce;
            if (deposit_.amount == uint112(amount)) {
                ++state_.depositors;
            }
        }

        emit Deposit(poolName, amount, depositor, data);
    }

    /**
     * @dev Deducts deposit `amount` from designated `poolName` under `depositor`.
     * As `totalCollected` is the cumulative sum of all `depositor`s under `poolName`,
     * underflow is not possible unless `totalCollected` is in a disallowed state to begin with.
     */
    function _deductDeposit(string calldata poolName, address depositor, uint256 amount, bytes memory data) private {
        MurePoolStorage storage storage_ = _getStorage();
        PoolState storage state_ = storage_.pools[poolName];
        DepositRecord storage deposit_ = storage_.deposits[poolName][depositor];

        if (deposit_.amount < amount) {
            revert PoolError(PoolErrorReason.ARITHMETIC_OUT_OF_BOUNDS);
        }

        unchecked {
            deposit_.amount -= uint112(amount);
            ++deposit_.nonce;
            if (deposit_.amount == 0) {
                --state_.depositors;
            }
        }

        emit Withdrawal(poolName, amount, depositor, data);
    }

    /**
     * @dev Determines and transfers the mure fee on deposits.
     * @param poolName name of the pool
     * @param depositor the address of the depositor
     * @param currency the address of the currency being transferred
     * @param amount the amount of the currency being transferred
     */
    function _deductFee(string calldata poolName, address depositor, address currency, uint256 amount)
        private
        returns (uint256)
    {
        (uint256 fee, address feeRecipient) = Config(MURE_CONFIG).getPoolFee(address(this), poolName, amount);

        if (fee > 0 && feeRecipient != address(0)) {
            _transferUpdate(depositor, feeRecipient, fee, currency);
        }

        return fee;
    }

    /**
     * @dev Updates the transfer between two addresses with a specified amount of a given currency.
     * @param from the address from which the transfer is initiated
     * @param to the address to which the transfer is made
     * @param amount the amount of the currency being transferred
     * @param currency the address of the currency being transferred
     */
    function _transferUpdate(address from, address to, uint256 amount, address currency) private {
        IERC20 currency_ = IERC20(currency);
        bool success;
        if (from == address(this)) {
            success = currency_.transfer(to, amount);
        } else {
            success = currency_.transferFrom(from, to, amount);
        }

        if (!success) {
            revert PoolError(PoolErrorReason.TRANSFER_FAILURE);
        }
    }

    /**
     * @dev Checks whether a pool with the specified name exists.
     * @param pool the name of the pool being checked
     */
    function _poolExists(string calldata pool) private view returns (bool) {
        return _hasFlag(_getStorage().pools[pool].flags, INITIALIZED);
    }

    /**
     * @dev Verifies the validity of the specified pool parameters.
     * @param config the parameters of the pool being verified
     */
    function _verifyParams(PoolParameters calldata config) private view {
        if (config.endTime < block.timestamp) {
            revert IllegalPoolState(PoolParameter.END_TIME);
        }
        if (config.signer == address(0)) {
            revert IllegalPoolState(PoolParameter.SIGNER);
        }
        if (config.currency == address(0)) {
            revert IllegalPoolState(PoolParameter.CURRENCY);
        }
        if (config.custodian == address(0)) {
            revert IllegalPoolState(PoolParameter.CUSTODIAN);
        }
        if (_hasFlag(config.flags, PASSTHROUGH_FUNDS) && _hasFlag(config.flags, REFUNDABLE)) {
            revert IllegalPoolState(PoolParameter.FLAGS);
        }
    }

    /**
     * @dev Checks whether the specified pool has been completed.
     * @param poolName the name of the pool being checked
     */
    function _poolComplete(string calldata poolName) private view returns (bool) {
        PoolState storage state_ = _getStorage().pools[poolName];
        return state_.totalCollected == state_.poolSize || state_.endTime < block.timestamp;
    }

    /**
     * @dev Generates a hashed representation of the specified amount and pool name, along with the sender's nonce.
     * @param amount the amount of the deposit
     * @param poolName the name of the pool
     * @param depositor address of the depositor
     */
    function _hashDeposit(uint256 amount, string calldata poolName, address depositor) private view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    DEPOSIT_HASH,
                    amount,
                    keccak256(bytes(poolName)),
                    depositor,
                    _getStorage().deposits[poolName][depositor].nonce
                )
            )
        );
    }

    /**
     * @dev Generates a struct hash of the specified pool name and end time, along with the nonce.
     * @param poolName the name of the pool
     * @param endTime the endtime block timestamp for the pool
     */
    function _hashCreatePool(string calldata poolName, uint32 endTime) private view returns (bytes32) {
        return keccak256(abi.encode(CREATE_POOL_HASH, keccak256(bytes(poolName)), endTime, _getStorage().nonce));
    }

    /**
     * @dev Verifies the validity of the pool size for an existing pool.
     * @param totalCollected total collected amount for the pool being updated
     * @param newPoolSize new pool size for the pool being updated
     */
    function _verifyPoolSize(uint112 totalCollected, uint112 newPoolSize) private pure {
        if (totalCollected > newPoolSize) {
            revert IllegalPoolState(PoolParameter.POOL_SIZE);
        }
    }

    /**
     * @dev Checks whether a specific flag is activated within a set of flags.
     * @param flags the set of flags being checked
     * @param flag the flag being checked for activation
     */
    function _hasFlag(uint16 flags, uint16 flag) private pure returns (bool) {
        return flags & flag != 0;
    }

    /**
     * @dev Activates the specified flag within a set of flags.
     * @param flags the set of flags being modified
     * @param flag the flag being activated
     */
    function _activateFlag(uint16 flags, uint16 flag) private pure returns (uint16) {
        return flags | flag;
    }

    /**
     * @dev Deactivates the specified flag within a set of flags.
     * @param flags the set of flags being modified
     * @param flag the flag being deactivated
     */
    function _deactivateFlag(uint16 flags, uint16 flag) private pure returns (uint16) {
        return flags & ~flag;
    }

    /**
     * @dev Retrieves the delegate address from config.
     */
    function _getDelegateAddress() private returns (address delegate) {
        delegate = Config(MURE_CONFIG).getAppDelegate(address(this));
    }

    /**
     * @dev Performs delegate operations before deposit operation.
     * @param delegateAddress address of the delegate contract
     * @param poolName name of the pool
     * @param amount deposit amount
     * @param sig deposit signature
     */
    function _beforeDeposit(
        address delegateAddress,
        string calldata poolName,
        uint256 amount,
        address depositor,
        bytes calldata sig
    ) private {
        if (delegateAddress != address(0)) {
            Delegatable(delegateAddress).beforeDeposit(poolName, amount, depositor, sig);
        }
    }

    /**
     * @dev Performs delegate operations after deposit operation.
     * @param delegateAddress address of the delegate contract
     * @param poolName name of the pool
     * @param amount deposit amount
     * @param sig deposit signature
     */
    function _afterDeposit(
        address delegateAddress,
        string calldata poolName,
        uint256 amount,
        address depositor,
        bytes calldata sig
    ) private {
        if (delegateAddress != address(0)) {
            Delegatable(delegateAddress).afterDeposit(poolName, amount, depositor, sig);
        }
    }

    /**
     * @dev Performs delegate operations before refund operation.
     * @param delegateAddress address of the delegate contract
     * @param poolName name of the pool
     * @param depositor address of the depositor
     */
    function _beforeRefund(address delegateAddress, string calldata poolName, address depositor) private {
        if (delegateAddress != address(0)) {
            Delegatable(delegateAddress).beforeRefund(poolName, depositor);
        }
    }

    /**
     * @dev Performs delegate operations after refund operation.
     * @param delegateAddress address of the delegate contract
     * @param poolName name of the pool
     * @param depositor address of the depositor
     * @param amount the refund amount
     */
    function _afterRefund(address delegateAddress, string calldata poolName, address depositor, uint256 amount)
        private
    {
        if (delegateAddress != address(0)) {
            Delegatable(delegateAddress).afterRefund(poolName, depositor, amount);
        }
    }

    /**
     * @dev Retrieves the storage for the MurePool contract.
     */
    function _getStorage() private pure returns (MurePoolStorage storage $) {
        assembly {
            $.slot := MurePoolStorageLocation
        }
    }

    /**
     * @dev Retrieves the storage for the pool metrics.
     */
    function _getPoolMetricsStorage() private pure returns (PoolMetricsStorage storage $) {
        assembly {
            $.slot := PoolMetricsStorageLocation
        }
    }

    function _verifySignature(
        uint256 amount,
        string calldata poolName,
        address depositor,
        address signer,
        bytes calldata sig
    ) private view {
        if (!SignatureChecker.isValidSignatureNow(signer, _hashDeposit(amount, poolName, depositor), sig)) {
            revert MureErrors.Unauthorized();
        }
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol
// SPDX-License-Identifier: MIT
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


// File: lib/openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/SignatureChecker.sol)

pragma solidity ^0.8.20;

import {ECDSA} from "./ECDSA.sol";
import {IERC1271} from "../../interfaces/IERC1271.sol";

/**
 * @dev Signature verification helper that can be used instead of `ECDSA.recover` to seamlessly support both ECDSA
 * signatures from externally owned accounts (EOAs) as well as ERC1271 signatures from smart contract wallets like
 * Argent and Safe Wallet (previously Gnosis Safe).
 */
library SignatureChecker {
    /**
     * @dev Checks if a signature is valid for a given signer and data hash. If the signer is a smart contract, the
     * signature is validated against that smart contract using ERC1271, otherwise it's validated using `ECDSA.recover`.
     *
     * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
     * change through time. It could return true at block N and false at block N+1 (or the opposite).
     */
    function isValidSignatureNow(address signer, bytes32 hash, bytes memory signature) internal view returns (bool) {
        (address recovered, ECDSA.RecoverError error, ) = ECDSA.tryRecover(hash, signature);
        return
            (error == ECDSA.RecoverError.NoError && recovered == signer) ||
            isValidERC1271SignatureNow(signer, hash, signature);
    }

    /**
     * @dev Checks if a signature is valid for a given signer and data hash. The signature is validated
     * against the signer smart contract using ERC1271.
     *
     * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
     * change through time. It could return true at block N and false at block N+1 (or the opposite).
     */
    function isValidERC1271SignatureNow(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeCall(IERC1271.isValidSignature, (hash, signature))
        );
        return (success &&
            result.length >= 32 &&
            abi.decode(result, (bytes32)) == bytes32(IERC1271.isValidSignature.selector));
    }
}


// File: src/interfaces/Poolable.sol
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

/**
 * @dev Structure of parameters of a pool
 */
struct PoolParameters {
    uint112 poolSize;
    uint32 endTime; // uint32 => year 2106
    uint16 flags;
    address currency;
    address custodian;
    address signer;
}

/**
 * @dev Structure for pool metrics. Could be updated in future
 */
struct PoolMetrics {
    uint112 totalWithdrawn;
}

enum PoolParameter {
    POOL_SIZE,
    END_TIME, // UINT32 => YEAR 2106
    FLAGS,
    DEPOSITORS,
    CURRENCY,
    CUSTODIAN,
    SIGNER
}

enum PoolErrorReason {
    POOL_SIZE_TOO_SMALL,
    TRANSFER_FAILURE,
    ARITHMETIC_OUT_OF_BOUNDS,
    ALREADY_INVESTED_POOL,
    INVALID_POOL_TYPE,
    POOL_EMPTY
}

/**
 * @dev Interface for pool administration functionality and pool errors.
 * @author Mure
 */
interface Poolable {
    error PoolClosed();
    error PoolOpen();
    error PoolError(PoolErrorReason reason);
    error IllegalPoolState(PoolParameter param);
    error IllegalPoolOperation(PoolErrorReason reason);
    error PoolInitialized();
    error PoolFull();
    error PoolPaused();
    error PoolNotEmpty();

    event PoolCreation(string poolName);
    event PoolUpdate(string poolName);
    event Withdrawal(string poolName, uint256 indexed amount, address indexed to, bytes data);

    function createPool(string calldata poolName, PoolParameters calldata params, bytes calldata sig) external;

    function updatePool(string calldata poolName, PoolParameters calldata params) external;

    function poolMetrics(string calldata poolName) external view returns (PoolMetrics memory);
}


// File: src/interfaces/PoolMetadata.sol
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

/**
 * @dev Structure of a pool
 */
struct PoolState {
    uint112 totalCollected;
    uint112 poolSize;
    uint16 flags;
    uint16 depositors;
    uint32 endTime; // uint32 => year 2106
    address currency;
    address custodian;
    address signer;
}

/**
 * @dev Interface for pool information like its state and existence
 * @author Mure
 */
interface PoolMetadata {
    function isPoolActive(string calldata poolName) external view returns (bool);

    function poolExists(string calldata pool) external view returns (bool);

    function poolState(string calldata poolName) external view returns (PoolState memory);

    function withdrawableAmount(string calldata poolName) external view returns (uint112);
}


// File: src/interfaces/Depositable.sol
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

/**
 * @dev Structure of a deposit
 */
struct DepositRecord {
    uint112 amount;
    uint8 nonce;
}

/**
 * @dev Interface for deposit functionality of pools.
 * @author Mure
 */
interface Depositable {
    event Deposit(string poolName, uint256 indexed amount, address indexed from, bytes data);

    function deposit(string calldata poolName, uint256 amount, bytes calldata sig) external;

    function deposit(string calldata poolName, uint256 amount, bytes calldata data, bytes calldata sig) external;

    function deposited(string calldata poolName, address depositor) external view returns (uint256);
}


// File: src/interfaces/Delegatable.sol
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {PoolMetadata} from "./PoolMetadata.sol";

struct PoolConfig {
    uint256 claimReserves;
    uint256 depositReserves;
    uint256 supply;
    uint16 plugins;
    uint16 feePercentage; // 0 to 10000
    address claimCurrency;
}

enum DelegateErrorReason {
    TRANSFER_FAILURE,
    INVALID_PERCENTAGE,
    ALREADY_DEPOSITED_FUNDS
}

/**
 * @dev Interface for Delegate core with support for ERC-165 detection.
 * @author Mure
 */
interface Delegatable is IERC165, PoolMetadata {
    error PluginDisabled(uint16 plugin);
    error PluginEnabled(uint16 plugin);
    error InvalidAmount();
    error DelegateError(DelegateErrorReason reason);

    event PoolFundsDeposit(string poolName, uint256 indexed refundFunds, uint256 indexed claimFunds);
    event FundTransfer(address indexed to, uint256 indexed amount, address indexed currency);
    event ConfigUpdate(string poolName);
    event PoolContractUpdate(address indexed poolContract);

    function beforeDeposit(string calldata poolName, uint256 amount, address depositor, bytes memory sig) external;

    function afterDeposit(string calldata poolName, uint256 amount, address depositor, bytes memory sig) external;

    function beforeRefund(string calldata poolName, address depositor) external;

    function afterRefund(string calldata poolName, address depositor, uint256 amount) external;

    function withdrawPoolFunds(string calldata poolName) external;

    function depositPoolFunds(string calldata poolName, uint256 refundFunds, uint256 claimFunds) external;

    function deposit(string calldata poolName, uint256 amount, bytes memory sig) external;

    function refund(string calldata poolName) external;

    function refund(string calldata poolName, address depositor, uint256 amount) external;

    function claim(string calldata poolName) external;

    function sendFunds(address to, uint256 amount, address currency) external;

    function poolConfig(string calldata poolName) external view returns (PoolConfig memory);

    function poolAddress() external view returns (address);

    function deposited(string calldata poolName, address depositor) external view returns (uint256);

    function getClaimCurrency(string calldata poolName) external view returns (address);
}


// File: src/interfaces/PoolApp.sol
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Poolable} from "./Poolable.sol";
import {Depositable} from "./Depositable.sol";
import {Refundable} from "./Refundable.sol";
import {PoolMetadata} from "./PoolMetadata.sol";

/**
 * @dev Interface for MurePool core with support for ERC-165 detection.
 * @author Mure
 */
interface PoolApp is IERC165, Poolable, Depositable, Refundable, PoolMetadata {
    enum Operation {
        Deposit,
        Withdrawal
    }

    struct Transaction {
        address depositor;
        uint112 amount;
        Operation operation;
    }

    function withdrawPoolFunds(string calldata poolName) external;

    function depositFor(string calldata poolName, uint256 amount, address depositor, bytes memory sig) external;

    function refundTo(string calldata poolName, address depositor, uint256 amount) external;

    function nonce(string calldata poolName, address depositor) external view returns (uint8);

    function updatePoolPaused(string calldata poolName, bool pause) external;

    function updatePoolRefundable(string calldata poolName, bool refundable) external;

    function depositPoolFunds(string calldata poolName, address depositor, uint256 amount) external;
}


// File: src/interfaces/Refundable.sol
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

/**
 * @dev Interface for refund fuctioanlity for pools with support for ERC-165 detection.
 * @author Mure
 */
interface Refundable {
    error DepositNotFound();

    event Refund(string poolName, uint256 indexed amount, address indexed depositor, bytes data);

    function refund(string calldata poolName) external;

    function updatePoolRefundable(string calldata poolName, bool refundable) external;
}


// File: src/interfaces/Config.sol
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @dev Interface for MureConfig core with support for ERC-165 detection.
 * @author Mure
 */
interface Config is IERC165 {
    /// @dev Must not revert, should return address(0) incase delegate does not exist
    function getAppDelegate(address poolApp) external returns (address);

    function setAppDelegate(address poolApp, address delegate) external;

    function verifyMureSignature(bytes32 structHash, bytes memory signature) external;

    function toggleWhitelistedSigner(address mureSigner_) external;

    function getFeeContractAddress() external view returns (address);

    function setMureFeeContract(address feeContractAddress) external;

    function getPoolFee(address poolApp, string calldata poolName, uint256 amount)
        external
        returns (uint256 feeAmount, address recipient);
}


// File: src/libraries/MureErrors.sol
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

/**
 * @dev Library with global errors for Mure
 * @author Mure
 */
library MureErrors {
    /**
     * @dev thrown when address is invalid, eg: zero address
     */
    error InvalidAddress(address addr);

    /**
     * @dev thrown when a signature has expired before verification
     */
    error SignatureExpired();

    /**
     * @dev thrown when any restricted operation is performed by an unauthorized entity
     */
    error Unauthorized();

    /**
     * @dev thrown when address is not a valid delegate
     */
    error InvalidDelegate();

    /**
     * @dev thrown when pool with given parameters is not found
     */
    error PoolNotFound();

    /**
     * @dev thrown when fee is invalid
     */
    error InvalidFee();
}


// File: src/shared/Constants.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @dev Role allows user to create and update pools along with pool administration
 */
bytes32 constant POOL_OPERATOR_ROLE = keccak256("POOL_OPERATOR");


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol
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


// File: lib/openzeppelin-contracts/contracts/access/IAccessControl.sol
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


// File: lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/MessageHashUtils.sol)

pragma solidity ^0.8.20;

import {Strings} from "../Strings.sol";

/**
 * @dev Signature message hash utilities for producing digests to be consumed by {ECDSA} recovery or signing.
 *
 * The library provides methods for generating a hash of a message that conforms to the
 * https://eips.ethereum.org/EIPS/eip-191[EIP 191] and https://eips.ethereum.org/EIPS/eip-712[EIP 712]
 * specifications.
 */
library MessageHashUtils {
    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing a bytes32 `messageHash` with
     * `"\x19Ethereum Signed Message:\n32"` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * NOTE: The `messageHash` parameter is intended to be the result of hashing a raw message with
     * keccak256, although any bytes32 value can be safely used because the final digest will
     * be re-hashed.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing an arbitrary `message` with
     * `"\x19Ethereum Signed Message:\n" + len(message)` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes memory message) internal pure returns (bytes32) {
        return
            keccak256(bytes.concat("\x19Ethereum Signed Message:\n", bytes(Strings.toString(message.length)), message));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x00` (data with intended validator).
     *
     * The digest is calculated by prefixing an arbitrary `data` with `"\x19\x00"` and the intended
     * `validator` address. Then hashing the result.
     *
     * See {ECDSA-recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"19_00", validator, data));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-712 typed data (EIP-191 version `0x01`).
     *
     * The digest is calculated from a `domainSeparator` and a `structHash`, by prefixing them with
     * `\x19\x01` and hashing the result. It corresponds to the hash signed by the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`] JSON-RPC method as part of EIP-712.
     *
     * See {ECDSA-recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
    }
}


// File: lib/openzeppelin-contracts/contracts/interfaces/IERC5267.sol
// SPDX-License-Identifier: MIT
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
}


// File: lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.20;

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
        InvalidSignatureS
    }

    /**
     * @dev The signature derives the `address(0)`.
     */
    error ECDSAInvalidSignature();

    /**
     * @dev The signature has an invalid length.
     */
    error ECDSAInvalidSignatureLength(uint256 length);

    /**
     * @dev The signature has an S value that is in the upper half order.
     */
    error ECDSAInvalidSignatureS(bytes32 s);

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with `signature` or an error. This will not
     * return address(0) without also returning an error description. Errors are documented using an enum (error type)
     * and a bytes32 providing additional information about the error.
     *
     * If no error is returned, then the address can be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError, bytes32) {
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
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError, bytes32) {
        unchecked {
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            // We do not check for an overflow here since the shift operation results in 0 or 1.
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        }
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError, bytes32) {
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
            return (address(0), RecoverError.InvalidSignatureS, s);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature, bytes32(0));
        }

        return (signer, RecoverError.NoError, bytes32(0));
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, v, r, s);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Optionally reverts with the corresponding custom error according to the `error` argument provided.
     */
    function _throwError(RecoverError error, bytes32 errorArg) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert ECDSAInvalidSignature();
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert ECDSAInvalidSignatureLength(uint256(errorArg));
        } else if (error == RecoverError.InvalidSignatureS) {
            revert ECDSAInvalidSignatureS(errorArg);
        }
    }
}


// File: lib/openzeppelin-contracts/contracts/interfaces/IERC1271.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC1271.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}


// File: lib/openzeppelin-contracts/contracts/utils/Strings.sol
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


// File: lib/openzeppelin-contracts/contracts/utils/math/SignedMath.sol
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


