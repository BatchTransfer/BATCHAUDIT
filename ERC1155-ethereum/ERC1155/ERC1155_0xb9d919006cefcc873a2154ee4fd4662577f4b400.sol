// File: contracts/ethereum/rounds/TimedRound.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { AssetRound } from './base/AssetRound.sol';
import { Asset, PackedAsset } from '../lib/types/Common.sol';
import { ITimedRound } from '../interfaces/ITimedRound.sol';
import { AssetHelper } from '../lib/utils/AssetHelper.sol';
import { MerkleProof } from '../lib/utils/MerkleProof.sol';
import { Selector, RoundType } from '../Constants.sol';
import { Uint256 } from '../lib/utils/Uint256.sol';

contract TimedRound is ITimedRound, AssetRound {
    using { Uint256.mask250 } for bytes32;
    using { AssetHelper.pack } for Asset;
    using { AssetHelper.packMany } for Asset[];

    /// @notice The amount of time before an asset provider can reclaim unclaimed assets
    uint256 public constant RECLAIM_UNCLAIMED_ASSETS_AFTER = 4 weeks;

    /// @notice The amount of time before the security council can emergency withdraw assets
    uint256 public constant EMERGENCY_WITHDRAW_ASSETS_AFTER = 8 weeks;

    /// @notice Maximum winner count for this strategy
    uint256 public constant MAX_WINNER_COUNT = 25;

    /// @notice The minimum proposal submission period duration
    uint256 public constant MIN_PROPOSAL_PERIOD_DURATION = 60 minutes;

    /// @notice The minimum vote period duration
    uint256 public constant MIN_VOTE_PERIOD_DURATION = 60 minutes;

    /// @notice The current state of the timed round. `Active` upon deployment.
    RoundState public state;

    /// @notice The timestamp at which the round was finalized. `0` if not finalized.
    uint40 public finalizedAt;

    /// @notice The timestamp at which the proposal period starts. `0` if not registered.
    uint40 public proposalPeriodStartTimestamp;

    /// @notice The proposal period duration in seconds. `0` if not registered.
    uint40 public proposalPeriodDuration;

    /// @notice The vote period duration in seconds. `0` if not registered.
    uint40 public votePeriodDuration;

    /// @notice The number of possible winners. `0` if not registered.
    uint16 public winnerCount;

    constructor(
        uint256 _classHash,
        address _propHouse,
        address _starknet,
        address _messenger,
        uint256 _roundFactory,
        uint256 _executionRelayer,
        address _manager
    )
        AssetRound(
            RoundType.TIMED,
            _classHash,
            _propHouse,
            _starknet,
            _messenger,
            _roundFactory,
            _executionRelayer,
            _manager
        )
    {}

    /// @notice Initialize the round by defining the round's configuration
    /// and registering it on L2.
    /// @dev This function is only callable by the prop house contract
    function initialize(bytes calldata data) external payable onlyPropHouse {
        _register(abi.decode(data, (RoundConfig)));
    }

    /// @notice Checks if the `user` is a winner in the round when no assets were offered
    /// @param user The Ethereum address of the user
    /// @param proposalId The winning proposal ID
    /// @param position The rank or order of a winner in the round
    /// @param proof The Merkle proof verifying the user's inclusion at the specified position in the round's winner list
    function isWinner(
        address user,
        uint256 proposalId,
        uint256 position,
        bytes32[] calldata proof
    ) external view returns (bool) {
        return MerkleProof.verify(proof, winnerMerkleRoot, keccak256(abi.encode(user, proposalId, position)));
    }

    /// @notice Checks if the `user` is a winner in the round when assets were offered
    /// @param user The Ethereum address of the user
    /// @param proposalId The winning proposal ID
    /// @param position The rank or order of a winner in the round
    /// @param asset The asset that was won by the user
    /// @param proof The Merkle proof verifying the user's inclusion in the round's winner list
    function isAssetWinner(
        address user,
        uint256 proposalId,
        uint256 position,
        Asset calldata asset,
        bytes32[] calldata proof
    ) public view returns (bool) {
        return MerkleProof.verify(
            proof,
            winnerMerkleRoot,
            _computeClaimLeaf(proposalId, position, user, asset.pack())
        );
    }

    /// @notice Cancel the timed round
    /// @dev This function is only callable by the round manager
    function cancel() external payable onlyRoundManager {
        _cancel();

        emit RoundCancelled();
    }

    /// @notice Cancel the timed round in the event of an emergency
    /// @dev This function is only callable by the owner of the security council
    function emergencyCancel() external payable onlySecurityCouncil {
        _cancel();

        emit RoundEmergencyCancelled();
    }

    /// @notice Finalize the round by consuming the merkle root from Starknet.
    /// @param merkleRootLow The lower half of the split merkle root
    /// @param merkleRootHigh The higher half of the split merkle root
    function finalize(uint256 merkleRootLow, uint256 merkleRootHigh) external {
        if (state != RoundState.Active) {
            revert FINALIZATION_NOT_AVAILABLE();
        }

        uint256[] memory payload = new uint256[](2);
        payload[0] = merkleRootLow;
        payload[1] = merkleRootHigh;

        // This function will revert if the message does not exist
        starknet.consumeMessageFromL2(executionRelayer, payload);

        // Reconstruct the merkle root, store it, and move the round to the finalized state
        winnerMerkleRoot = bytes32((merkleRootHigh << 128) + merkleRootLow);
        finalizedAt = uint40(block.timestamp);
        state = RoundState.Finalized;

        emit RoundFinalized();
    }

    /// @notice Claim a round award asset to a custom recipient
    /// @param recipient The asset recipient
    /// @param proposalId The winning proposal ID
    /// @param position The rank or order of the winner in the round
    /// @param asset The asset to claim
    /// @param proof The merkle proof used to verify the validity of the asset payout
    function claimTo(
        address recipient,
        uint256 proposalId,
        uint256 position,
        Asset calldata asset,
        bytes32[] calldata proof
    ) external {
        _claimTo(recipient, proposalId, position, asset, proof);
    }

    /// @notice Claim a round award asset to the caller
    /// @param proposalId The winning proposal ID
    /// @param position The rank or order of the winner in the round
    /// @param asset The asset to claim
    /// @param proof The merkle proof used to verify the validity of the asset payout
    function claim(uint256 proposalId, uint256 position, Asset calldata asset, bytes32[] calldata proof) external {
        _claimTo(msg.sender, proposalId, position, asset, proof);
    }

    /// @notice Reclaim assets to a custom recipient
    /// @param recipient The asset recipient
    /// @param assets The assets to reclaim
    function reclaimTo(address recipient, Asset[] calldata assets) public {
        // prettier-ignore
        // Reclamation is only available when the round has been cancelled OR
        // the round has been finalized and is in the reclamation period
        if (state == RoundState.Active || (state == RoundState.Finalized && block.timestamp - finalizedAt < RECLAIM_UNCLAIMED_ASSETS_AFTER)) {
            revert RECLAMATION_NOT_AVAILABLE();
        }
        _reclaimTo(recipient, assets);
    }

    /// @notice Reclaim assets to the caller
    /// @param assets The assets to reclaim
    function reclaim(Asset[] calldata assets) external {
        reclaimTo(msg.sender, assets);
    }

    /// @notice Emergency withdraw assets to a custom recipient
    /// @param recipient The asset recipient
    /// @param assets The assets to withdraw
    /// @dev This function is only callable by the security council once enough time has passed
    /// since the round was scheduled to end.
    function emergencyWithdrawTo(address recipient, Asset[] calldata assets) external onlySecurityCouncil {
        uint256 scheduledEnd = proposalPeriodStartTimestamp + proposalPeriodDuration + votePeriodDuration;
        if (block.timestamp < scheduledEnd || block.timestamp - scheduledEnd < EMERGENCY_WITHDRAW_ASSETS_AFTER) {
            revert EMERGENCY_WITHDRAWAL_NOT_AVAILABLE();
        }
        for (uint256 i = 0; i < assets.length; ++i) {
            _transfer(assets[i], address(this), payable(recipient));
        }
    }

    // prettier-ignore
    /// @notice Generate the payload required to register the round on L2
    /// @param config The round configuration
    function getRegistrationPayload(RoundConfig memory config) public view returns (uint256[] memory payload) {
        uint256 vsCount = config.votingStrategies.length;
        uint256 vsParamFlatCount = config.votingStrategyParamsFlat.length;
        uint256 psCount = config.proposingStrategies.length;
        uint256 psParamsFlatCount = config.proposingStrategyParamsFlat.length;

        uint256 strategyParamsCount = vsCount + vsParamFlatCount + psCount + psParamsFlatCount;

        payload = new uint256[](14 + strategyParamsCount);

        // `payload[0]` is reserved for the round address, which is
        // set in the messenger contract for security purposes.
        payload[1] = classHash;

        // L2 strategy params
        payload[2] = 11 + strategyParamsCount;
        payload[3] = 10 + strategyParamsCount;
        payload[4] = _computeAwardHash(config.awards);
        payload[5] = config.proposalPeriodStartTimestamp;
        payload[6] = config.proposalPeriodDuration;
        payload[7] = config.votePeriodDuration;
        payload[8] = config.winnerCount;

        payload[9] = config.proposalThreshold;

        uint256 offset = 10;
        (payload, offset) = _addStrategies(payload, offset, config.proposingStrategies, config.proposingStrategyParamsFlat);
        (payload, ) = _addStrategies(payload, ++offset, config.votingStrategies, config.votingStrategyParamsFlat);
        return payload;
    }

    /// @notice Define the configuration and register the round on L2.
    /// Duplicate voting strategies are handled on L2.
    /// @param config The round configuration
    function _register(RoundConfig memory config) internal {
        _validate(config);

        // Set the proposal period start timestamp to the current block timestamp if it is in the past.
        config.proposalPeriodStartTimestamp = _max(config.proposalPeriodStartTimestamp, uint40(block.timestamp));

        // Write round metadata to storage. This will be consumed by the token URI later.
        proposalPeriodStartTimestamp = config.proposalPeriodStartTimestamp;
        proposalPeriodDuration = config.proposalPeriodDuration;
        votePeriodDuration = config.votePeriodDuration;
        winnerCount = config.winnerCount;

        // Forward ETH to the meta-transaction relayer, if set.
        uint256 etherRemaining = msg.value;
        if (config.metaTx.deposit > 0) {
            if (config.metaTx.relayer == address(0)) revert NO_META_TX_RELAYER_PROVIDED();
            if (config.metaTx.deposit > etherRemaining) revert INSUFFICIENT_ETHER_SUPPLIED();

            _transferETH(payable(config.metaTx.relayer), config.metaTx.deposit);
            etherRemaining -= config.metaTx.deposit;
        }

        // Register the round on L2
        messenger.sendMessageToL2{ value: etherRemaining }(roundFactory, Selector.REGISTER_ROUND, getRegistrationPayload(config));

        emit RoundRegistered(
            config.awards,
            config.metaTx,
            config.proposalThreshold,
            config.proposingStrategies,
            config.proposingStrategyParamsFlat,
            config.votingStrategies,
            config.votingStrategyParamsFlat,
            config.proposalPeriodStartTimestamp,
            config.proposalPeriodDuration,
            config.votePeriodDuration,
            config.winnerCount
        );
    }

    // prettier-ignore
    /// @notice Revert if the round configuration is invalid
    /// @param config The round configuration
    function _validate(RoundConfig memory config) internal pure {
        if (config.proposalPeriodDuration < MIN_PROPOSAL_PERIOD_DURATION) {
            revert PROPOSAL_PERIOD_DURATION_TOO_SHORT();
        }
        if (config.votePeriodDuration < MIN_VOTE_PERIOD_DURATION) {
            revert VOTE_PERIOD_DURATION_TOO_SHORT();
        }
        if (config.winnerCount == 0 || config.winnerCount > MAX_WINNER_COUNT) {
            revert WINNER_COUNT_OUT_OF_RANGE();
        }
        if (config.proposalThreshold != 0 && config.proposingStrategies.length == 0) {
            revert NO_PROPOSING_STRATEGIES_PROVIDED();
        }
        if (config.votingStrategies.length == 0) {
            revert NO_VOTING_STRATEGIES_PROVIDED();
        }
        if (config.awards.length != 0 && config.awards.length != config.winnerCount) {
            if (config.awards.length != 1) {
                revert AWARD_LENGTH_MISMATCH();
            }
            if (config.awards[0].amount % config.winnerCount != 0) {
                revert AWARD_AMOUNT_NOT_MULTIPLE_OF_WINNER_COUNT();
            }
        }
    }

    /// @notice Cancel the timed round
    function _cancel() internal {
        if (state != RoundState.Active) {
            revert CANCELLATION_NOT_AVAILABLE();
        }
        state = RoundState.Cancelled;

        // Notify Starknet of the cancellation
        _notifyRoundCancelled();
    }

    /// @notice Claim a round award asset to a custom recipient
    /// @param recipient The asset recipient
    /// @param proposalId The winning proposal ID
    /// @param position The position or rank of the proposal in the winners list
    /// @param asset The asset to claim
    /// @param proof The merkle proof used to verify the validity of the asset payout
    function _claimTo(
        address recipient,
        uint256 proposalId,
        uint256 position,
        Asset calldata asset,
        bytes32[] calldata proof
    ) internal {
        if (isClaimed(proposalId)) {
            revert ALREADY_CLAIMED();
        }
        PackedAsset memory packed = asset.pack();
        if (!MerkleProof.verify(proof, winnerMerkleRoot, _computeClaimLeaf(proposalId, position, msg.sender, packed))) {
            revert INVALID_MERKLE_PROOF();
        }
        _setClaimed(proposalId);
        _transfer(asset, address(this), payable(recipient));

        emit AssetClaimed(proposalId, msg.sender, recipient, packed);
    }

    /// @dev Computes a leaf in the winner merkle tree used to release assets to winners.
    /// @param proposalId The winning proposal ID
    /// @param position The position or rank of the proposal in the winners list
    /// @param user The user claiming the assets
    /// @param packed The packed asset that's being claimed
    function _computeClaimLeaf(uint256 proposalId, uint256 position, address user, PackedAsset memory packed) internal pure returns (bytes32) {
        return keccak256(abi.encode(proposalId, position, user, packed));
    }

    /// @notice Compute the award hash for the round, returning `0` if
    /// there are no awards.
    /// @param awards The round awards
    function _computeAwardHash(Asset[] memory awards) internal pure returns (uint256) {
        if (awards.length == 0) {
            return 0;
        }
        return keccak256(abi.encode(awards.packMany())).mask250();
    }

    /// @dev Returns the largest of two numbers.
    /// @param a The first number
    /// @param b The second number
    function _max(uint40 a, uint40 b) internal pure returns (uint40) {
        return a > b ? a : b;
    }
}


// File: contracts/ethereum/rounds/base/AssetRound.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { Round } from './Round.sol';
import { IERC165 } from '../../interfaces/IERC165.sol';
import { AssetHelper } from '../../lib/utils/AssetHelper.sol';
import { IAssetRound } from '../../interfaces/IAssetRound.sol';
import { AssetController } from '../../lib/utils/AssetController.sol';
import { DepositReceiver } from '../../lib/utils/DepositReceiver.sol';
import { TokenHolder } from '../../lib/utils/TokenHolder.sol';
import { IManager } from '../../interfaces/IManager.sol';
import { ERC1155 } from '../../lib/token/ERC1155.sol';
import { Asset } from '../../lib/types/Common.sol';

abstract contract AssetRound is IAssetRound, Round, AssetController, TokenHolder, ERC1155, DepositReceiver {
    using { AssetHelper.toID } for Asset;

    /// @notice The Prop House manager contract
    IManager public immutable manager;

    /// @notice Determine if a winner has claimed their award asset
    /// @dev Proposal IDs map to bits in the uint256 mapping
    mapping(uint256 => uint256) private _assetClaimStatus;

    /// @notice The round implementation contract address
    address private immutable _implementation;

    constructor(
        bytes32 _kind,
        uint256 _classHash,
        address _propHouse,
        address _starknet,
        address _messenger,
        uint256 _roundFactory,
        uint256 _executionRelayer,
        address _manager
    ) Round(_kind, _classHash, _propHouse, _starknet, _messenger, _roundFactory, _executionRelayer) {
        manager = IManager(_manager);

        _implementation = address(this);
    }

    /// @notice Require that the caller is the prop house contract
    modifier onlySecurityCouncil() {
        if (msg.sender != manager.getSecurityCouncil()) {
            revert ONLY_SECURITY_COUNCIL();
        }
        _;
    }

    /// @notice Returns the deposit token URI for the provided token ID
    /// @param tokenId The deposit token ID
    function uri(uint256 tokenId) external view override returns (string memory) {
        return manager.getMetadataRenderer(_implementation).tokenURI(tokenId);
    }

    // prettier-ignore
    /// @notice If the contract implements an interface
    /// @param interfaceId The interface id
    function supportsInterface(bytes4 interfaceId) public view virtual override(DepositReceiver, TokenHolder, ERC1155, IERC165) returns (bool) {
        return DepositReceiver.supportsInterface(interfaceId) || TokenHolder.supportsInterface(interfaceId) || ERC1155.supportsInterface(interfaceId);
    }

    /// @notice Issue a deposit receipt
    /// @param depositor The depositor address
    /// @param id The token identifier
    /// @param amount The token amount
    /// @dev This function is only callable by the prop house contract
    function onDepositReceived(address depositor, uint256 id, uint256 amount) external onlyPropHouse {
        _mint(depositor, id, amount, new bytes(0));
    }

    /// @notice Issue deposit receipts
    /// @param depositor The depositor address
    /// @param ids The token identifiers
    /// @param amounts The token amounts
    /// @dev This function is only callable by the prop house contract
    function onDepositsReceived(
        address depositor,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyPropHouse {
        _batchMint(depositor, ids, amounts, new bytes(0));
    }

    /// @notice Determine whether an asset has been claimed for a specific proposal ID
    /// @param proposalId The proposal ID
    function isClaimed(uint256 proposalId) public view returns (bool claimed) {
        uint256 isBitSet = (_assetClaimStatus[proposalId >> 8] >> (proposalId & 0xff)) & 1;
        assembly {
            claimed := isBitSet
        }
    }

    /// @notice Reclaim assets to a custom recipient
    /// @param recipient The asset recipient
    /// @param assets The assets to reclaim
    function _reclaimTo(address recipient, Asset[] calldata assets) internal {
        uint256 assetCount = assets.length;
        address caller = msg.sender;

        for (uint256 i = 0; i < assetCount; ) {
            uint256 assetId = assets[i].toID();

            // Burn deposit credits. This will revert if the caller does not have enough credits.
            _burn(caller, assetId, assets[i].amount);

            // Transfer the asset to the recipient
            _transfer(assets[i], address(this), payable(recipient));

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Mark an asset as 'claimed' for the provided proposal ID
    /// @param proposalId The winning proposal ID
    function _setClaimed(uint256 proposalId) internal {
        _assetClaimStatus[proposalId >> 8] |= (1 << (proposalId & 0xff));
    }
}


// File: contracts/ethereum/lib/types/Common.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

/// @notice Supported asset types
enum AssetType {
    Native,
    ERC20,
    ERC721,
    ERC1155
}

/// @notice Common struct for all supported asset types
struct Asset {
    AssetType assetType;
    address token;
    uint256 identifier;
    uint256 amount;
}

/// @notice Packed asset information, which consists of an asset ID and amount
struct PackedAsset {
    uint256 assetId;
    uint256 amount;
}

/// @notice Merkle proof information for an incremental tree
struct IncrementalTreeProof {
    bytes32[] siblings;
    uint8[] pathIndices;
}

/// @notice A meta-transaction relayer address and deposit amount
struct MetaTransaction {
    address relayer;
    uint256 deposit;
}


// File: contracts/ethereum/interfaces/ITimedRound.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { Asset, MetaTransaction } from '../lib/types/Common.sol';

/// @notice Interface implemented by the timed round
interface ITimedRound {
    /// @notice All possible round states
    enum RoundState {
        Active,
        Cancelled,
        Finalized
    }

    /// @notice The timed round configuration
    struct RoundConfig {
        Asset[] awards;
        MetaTransaction metaTx;
        uint248 proposalThreshold;
        uint256[] proposingStrategies;
        uint256[] proposingStrategyParamsFlat;
        uint256[] votingStrategies;
        uint256[] votingStrategyParamsFlat;
        uint40 proposalPeriodStartTimestamp;
        uint40 proposalPeriodDuration;
        uint40 votePeriodDuration;
        uint16 winnerCount;
    }

    /// @notice Thrown when cancellation is attempted and the round is not active
    error CANCELLATION_NOT_AVAILABLE();

    /// @notice Thrown when finalization is attempted and the round is not active
    error FINALIZATION_NOT_AVAILABLE();

    /// @notice Thrown when asset reclamation is not available
    error RECLAMATION_NOT_AVAILABLE();

    /// @notice Thrown when emergency withdrawal is not available
    error EMERGENCY_WITHDRAWAL_NOT_AVAILABLE();

    /// @notice Thrown when the proposal period duration is too short
    error PROPOSAL_PERIOD_DURATION_TOO_SHORT();

    /// @notice Thrown when the vote period duration is too short
    error VOTE_PERIOD_DURATION_TOO_SHORT();

    /// @notice Thrown when the award length is greater than one and does not match the winner count
    error AWARD_LENGTH_MISMATCH();

    /// @notice Thrown when one award is split between winners and the amount is not a multiple of the winner count
    error AWARD_AMOUNT_NOT_MULTIPLE_OF_WINNER_COUNT();

    /// @notice Thrown when the winner count is zero or greater than the maximum allowable
    error WINNER_COUNT_OUT_OF_RANGE();

    /// @notice Thrown when the proposal threshold is non-zero and no proposing strategies are provided
    error NO_PROPOSING_STRATEGIES_PROVIDED();

    /// @notice Thrown when no voting strategies are provided
    error NO_VOTING_STRATEGIES_PROVIDED();

    /// @notice Thrown when the meta-transaction deposit amount is non-zero, but no relayer address is provided.
    error NO_META_TX_RELAYER_PROVIDED();

    /// @notice Thrown when an insufficient amount of ether is provided to `msg.value`
    error INSUFFICIENT_ETHER_SUPPLIED();

    /// @notice Emitted when the round is registered on L2
    /// @param awards The awards offered to round winners
    /// @param metaTx The meta-transaction relayer and deposit amount
    /// @param proposalThreshold The proposal threshold
    /// @param proposingStrategies The proposing strategy addresses
    /// @param proposingStrategyParamsFlat The flattened proposing strategy params
    /// @param votingStrategies The voting strategy addresses
    /// @param votingStrategyParamsFlat The flattened voting strategy params
    /// @param proposalPeriodStartTimestamp The timestamp at which the proposal period starts
    /// @param proposalPeriodDuration The proposal period duration in seconds
    /// @param votePeriodDuration The vote period duration in seconds
    /// @param winnerCount The number of possible winners
    event RoundRegistered(
        Asset[] awards,
        MetaTransaction metaTx,
        uint248 proposalThreshold,
        uint256[] proposingStrategies,
        uint256[] proposingStrategyParamsFlat,
        uint256[] votingStrategies,
        uint256[] votingStrategyParamsFlat,
        uint40 proposalPeriodStartTimestamp,
        uint40 proposalPeriodDuration,
        uint40 votePeriodDuration,
        uint16 winnerCount
    );

    /// @notice Emitted when the round is finalized
    event RoundFinalized();

    /// @notice Emitted when a round is cancelled by the round manager
    event RoundCancelled();

    /// @notice Emitted when a round is cancelled by the security council in an emergency
    event RoundEmergencyCancelled();

    /// @notice The current state of the timed round
    function state() external view returns (RoundState);

    /// @notice The timestamp at which the round was finalized. `0` if not finalized.
    function finalizedAt() external view returns (uint40);

    /// @notice The timestamp at which the proposal period starts. `0` when in pending state.
    function proposalPeriodStartTimestamp() external view returns (uint40);

    /// @notice The proposal period duration in seconds. `0` when in pending state.
    function proposalPeriodDuration() external view returns (uint40);

    /// @notice The vote period duration in seconds. `0` when in pending state.
    function votePeriodDuration() external view returns (uint40);

    /// @notice The number of possible winners. `0` when in pending state.
    function winnerCount() external view returns (uint16);
}


// File: contracts/ethereum/lib/utils/AssetHelper.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { Asset, AssetType, PackedAsset } from '../types/Common.sol';

library AssetHelper {
    /// @notice Returns the packed asset information for a single asset
    /// @param asset The asset information
    function pack(Asset memory asset) internal pure returns (PackedAsset memory packed) {
        unchecked {
            packed = PackedAsset({ assetId: toID(asset), amount: asset.amount });
        }
    }

    /// @notice Returns the packed asset information for the provided assets
    /// @param assets The asset information
    function packMany(Asset[] memory assets) internal pure returns (PackedAsset[] memory packed) {
        unchecked {
            uint256 assetCount = assets.length;
            packed = new PackedAsset[](assetCount);

            for (uint256 i = 0; i < assetCount; ++i) {
                packed[i] = pack(assets[i]);
            }
        }
    }

    /// @notice Calculates the asset IDs for the provided assets
    /// @param assets The asset information
    function toIDs(Asset[] memory assets) internal pure returns (uint256[] memory ids) {
        unchecked {
            uint256 assetCount = assets.length;
            ids = new uint256[](assetCount);

            for (uint256 i = 0; i < assetCount; ++i) {
                ids[i] = toID(assets[i]);
            }
        }
    }

    /// @dev Calculates the asset ID for the provided asset
    /// @param asset The asset information
    function toID(Asset memory asset) internal pure returns (uint256) {
        if (asset.assetType == AssetType.Native) {
            return uint256(asset.assetType);
        }
        if (asset.assetType == AssetType.ERC20) {
            return uint256(bytes32(abi.encodePacked(asset.assetType, asset.token)));
        }
        // prettier-ignore
        return uint256(
            bytes32(abi.encodePacked(asset.assetType, keccak256(abi.encodePacked(asset.token, asset.identifier))))
        );
    }
}


// File: contracts/ethereum/lib/utils/MerkleProof.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

/// @notice Gas optimized merkle proof verification library
library MerkleProof {
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool isValid) {
        /// @solidity memory-safe-assembly
        assembly {
            if mload(proof) {
                // Initialize `offset` to the offset of `proof` elements in memory.
                let offset := add(proof, 0x20)
                // Left shift by 5 is equivalent to multiplying by 0x20.
                let end := add(offset, shl(5, mload(proof)))
                // Iterate over proof elements to compute root hash.
                for {} 1 {} {
                    // Slot of `leaf` in scratch space.
                    // If the condition is true: 0x20, otherwise: 0x00.
                    let scratch := shl(5, gt(leaf, mload(offset)))
                    // Store elements to hash contiguously in scratch space.
                    // Scratch space is 64 bytes (0x00 - 0x3f) and both elements are 32 bytes.
                    mstore(scratch, leaf)
                    mstore(xor(scratch, 0x20), mload(offset))
                    // Reuse `leaf` to store the hash to reduce stack operations.
                    leaf := keccak256(0x00, 0x40)
                    offset := add(offset, 0x20)
                    if iszero(lt(offset, end)) { break }
                }
            }
            isValid := eq(leaf, root)
        }
    }
}


// File: contracts/ethereum/Constants.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

// ETH pseudo-token address
address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

// The maximum value that can be represented as an unsigned 250-bit integer
uint256 constant MAX_250_BIT_UNSIGNED = 0x03FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

/// @notice Starknet function selector constants
library Selector {
    // print(get_selector_from_name("register_round"))
    uint256 constant REGISTER_ROUND = 0x26490f901ea8ad5a245d987479919f1d20fbb0c164367e33ef09a9ea4ba8d04;

    // print(get_selector_from_name("cancel_round"))
    uint256 constant CANCEL_ROUND = 0x8af3ea41808c9515720e56add54a2d8008458a8bc5e347b791c6d75cd0e407;

    // print(get_selector_from_name("finalize_round"))
    uint256 constant FINALIZE_ROUND = 0x2445872c1b7a1219e1e75f2a60719ce0a68a8442fee1bdbee6c3c649340e6f3;

    // print(get_selector_from_name("route_call_to_round"))
    uint256 constant ROUTE_CALL_TO_ROUND = 0x24931ca109ce0ffa87913d91f12d6ac327550c015a573c7b17a187c29ed8c1a;
}

/// @notice Prop House metadata constants
library PHMetadata {
    // The Prop House NFT name
    string constant NAME = 'Prop House';

    // The Prop House entrypoint NFT symbol
    string constant SYMBOL = 'PROP';

    // The Prop House entrypoint NFT contract URI
    string constant URI = 'ipfs://bafkreiagexn2wbv5t63y2xbf6mmcx3rktrqxrsyzf5gl5l7c2lm3bkqjc4';
}

/// @notice Community house metadata constants
library CHMetadata {
    // The Community House type
    bytes32 constant TYPE = 'COMMUNITY';

    // The Community House NFT name
    string constant NAME = 'Community House';

    // The Community House NFT symbol
    string constant SYMBOL = 'COMM';
}

/// @notice Round type constants
library RoundType {
    // The Timed Round type
    bytes32 constant TIMED = 'TIMED';

    // The Infinite Round type
    bytes32 constant INFINITE = 'INFINITE';
}


// File: contracts/ethereum/lib/utils/Uint256.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { MAX_250_BIT_UNSIGNED } from '../../Constants.sol';

library Uint256 {
    /// @notice Split a uint256 into a high and low value
    /// @param value The uint256 value to split
    /// @dev This is useful for passing uint256 values to Starknet, whose felt
    /// type only supports 251 bits.
    function split(uint256 value) internal pure returns (uint256, uint256) {
        uint256 low = value & ((1 << 128) - 1);
        uint256 high = value >> 128;
        return (low, high);
    }

    /// Mask the passed `value` to 250 bits
    /// @param value The value to mask
    function mask250(bytes32 value) internal pure returns (uint256) {
        return uint256(value) & MAX_250_BIT_UNSIGNED;
    }

    /// @notice Convert an address to a uint256
    /// @param addr The address to convert
    function toUint256(address addr) internal pure returns (uint256) {
        return uint256(uint160(addr));
    }
}


// File: contracts/ethereum/rounds/base/Round.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { Clone } from 'solady/src/utils/Clone.sol';
import { IHouse } from '../../interfaces/IHouse.sol';
import { IRound } from '../../interfaces/IRound.sol';
import { IPropHouse } from '../../interfaces/IPropHouse.sol';
import { IStarknetCore } from '../../interfaces/IStarknetCore.sol';
import { IMessenger } from '../../interfaces/IMessenger.sol';
import { Uint256 } from '../../lib/utils/Uint256.sol';
import { Selector } from '../../Constants.sol';

abstract contract Round is IRound, Clone {
    using { Uint256.toUint256 } for address;

    /// @notice The round type
    bytes32 public immutable kind;

    /// @notice The hash of the Starknet round contract
    uint256 public immutable classHash;

    /// @notice The entrypoint for all house and round creation
    IPropHouse public immutable propHouse;

    /// @notice The Starknet Core contract
    IStarknetCore public immutable starknet;

    /// @notice The Starknet Messenger contract
    IMessenger public immutable messenger;

    /// @notice The Round Factory contract address on Starknet
    uint256 internal immutable roundFactory;

    /// @notice The execution relayer contract on Starknet
    uint256 public immutable executionRelayer;

    /// @notice The merkle root that contains winner information. `bytes32(0)` if not finalized.
    bytes32 public winnerMerkleRoot;

    /// @notice Get the address of the house on which this strategy belongs
    /// @dev Value is read using clone-with-immutable-args from contract's code region.
    function house() public pure returns (address) {
        return _getArgAddress(0);
    }

    /// @notice Get the round title
    /// @dev Value is read using clone-with-immutable-args from contract's code region.
    function title() public pure returns (string memory) {
        return string(_getArgBytes(21, _getArgUint8(20)));
    }

    /// @notice Get the round ID
    function id() public view returns (uint256) {
        return address(this).toUint256();
    }

    /// @param _kind The round type
    /// @param _classHash The hash of the Starknet round contract
    /// @param _propHouse The entrypoint for all house and round creation
    /// @param _starknet The Starknet Core contract
    /// @param _messenger The Starknet Messenger contract
    /// @param _roundFactory The Round Factory contract address on Starknet
    /// @param _executionRelayer The execution relayer contract on Starknet
    constructor(
        bytes32 _kind,
        uint256 _classHash,
        address _propHouse,
        address _starknet,
        address _messenger,
        uint256 _roundFactory,
        uint256 _executionRelayer
    ) {
        kind = _kind;
        classHash = _classHash;

        propHouse = IPropHouse(_propHouse);
        starknet = IStarknetCore(_starknet);
        messenger = IMessenger(_messenger);
        roundFactory = _roundFactory;
        executionRelayer = _executionRelayer;
    }

    /// @notice Require that the caller is the prop house contract
    modifier onlyPropHouse() {
        if (msg.sender != address(propHouse)) {
            revert ONLY_PROP_HOUSE();
        }
        _;
    }

    /// @notice Require that the caller is the round manager
    modifier onlyRoundManager() {
        if (msg.sender != IHouse(house()).ownerOf(id())) {
            revert ONLY_ROUND_MANAGER();
        }
        _;
    }

    /// @dev Route a call to the round contract on Starknet
    /// @param payload The payload to send to the round contract on Starknet
    function _callStarknetRound(uint256[] memory payload) internal {
        messenger.sendMessageToL2{ value: msg.value }(roundFactory, Selector.ROUTE_CALL_TO_ROUND, payload);
    }

    /// @dev Route a round cancellation call to the round contract on Starknet
    /// `payload[0]` - Round address
    /// `payload[2]` - Empty calldata array length
    function _notifyRoundCancelled() internal {
        uint256[] memory payload = new uint256[](3);
        payload[1] = Selector.CANCEL_ROUND;

        _callStarknetRound(payload);
    }

    /// @dev Add strategies and parameters to the payload
    /// @param payload The payload to add to
    /// @param offset The starting offset index
    /// @param strategies The strategy addresses to add
    /// @param params The flattened parameters to add
    function _addStrategies(
        uint256[] memory payload,
        uint256 offset,
        uint256[] memory strategies,
        uint256[] memory params
    ) internal pure returns (uint256[] memory, uint256) {
        unchecked {
            uint256 strategyCount = strategies.length;
            uint256 paramCount = params.length;

            // Add strategy count
            payload[offset] = strategyCount;

            // Add strategies
            for (uint256 i = 0; i < strategyCount; ++i) {
                uint256 strategy = strategies[i];
                if (strategy == 0) {
                    revert INVALID_STRATEGY(strategy);
                }
                payload[++offset] = strategy;
            }

            // Add parameter count
            payload[++offset] = paramCount;

            // Add parameters
            for (uint256 i = 0; i < paramCount; ++i) {
                payload[++offset] = params[i];
            }
            return (payload, offset);
        }
    }
}


// File: contracts/ethereum/interfaces/IERC165.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

/// @title IERC165
/// @notice Interface of the ERC165 standard, as defined in the https://eips.ethereum.org/EIPS/eip-165[EIP].
interface IERC165 {
    /// @dev Returns true if this contract implements the interface defined by
    /// `interfaceId`. See the corresponding
    /// https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
    /// to learn more about how these ids are created.
    /// This function call must use less than 30000 gas.
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File: contracts/ethereum/interfaces/IAssetRound.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { IRound } from './IRound.sol';
import { PackedAsset } from '../lib/types/Common.sol';

interface IAssetRound is IRound {
    /// @notice Thrown when an asset has already been claimed
    error ALREADY_CLAIMED();

    /// @notice Thrown when the provided merkle proof is invalid
    error INVALID_MERKLE_PROOF();

    /// @notice Thrown when the caller of a guarded function is not the security council
    error ONLY_SECURITY_COUNCIL();

    /// @notice Emitted when an asset is claimed by a winner
    /// @param proposalId The ID of the winning proposal
    /// @param claimer The address of the claimer (winner)
    /// @param recipient The recipient of the asset
    /// @param asset The ID and amount of the asset being claimed
    event AssetClaimed(uint256 proposalId, address claimer, address recipient, PackedAsset asset);

    /// @notice Emitted when an asset is claimed by a winner
    /// @param proposalId The ID of the winning proposal
    /// @param claimer The address of the claimer (winner)
    /// @param recipient The recipient of the asset
    /// @param assets The ID and amount of the assets being claimed
    event AssetsClaimed(uint256 proposalId, address claimer, address recipient, PackedAsset[] assets);
}


// File: contracts/ethereum/lib/utils/AssetController.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import { IERC1155 } from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { AssetType, Asset } from '../types/Common.sol';

abstract contract AssetController {
    using SafeERC20 for IERC20;

    /// @notice Thrown when unused asset parameters are populated
    error UNUSED_ASSET_PARAMETERS();

    /// @notice Thrown when an ether transfer does not succeed
    error ETHER_TRANSFER_FAILED();

    /// @notice Thrown when the ERC721 transfer amount is not equal to one
    error INVALID_ERC721_TRANSFER_AMOUNT();

    /// @notice Thrown when an unknown asset type is provided
    error INVALID_ASSET_TYPE();

    /// @notice Thrown when no asset amount is provided
    error MISSING_ASSET_AMOUNT();

    /// @dev Returns the balance of `asset` for `account`
    /// @param asset The asset to fetch the balance of
    /// @param account The account to fetch the balance for
    function _balanceOf(Asset memory asset, address account) internal view returns (uint256) {
        if (asset.assetType == AssetType.Native) {
            return account.balance;
        }
        if (asset.assetType == AssetType.ERC20) {
            return IERC20(asset.token).balanceOf(account);
        }
        if (asset.assetType == AssetType.ERC721) {
            return IERC721(asset.token).ownerOf(asset.identifier) == account ? 1 : 0;
        }
        if (asset.assetType == AssetType.ERC1155) {
            return IERC1155(asset.token).balanceOf(account, asset.identifier);
        }
        revert INVALID_ASSET_TYPE();
    }

    /// @dev Transfer a given asset from the provided `from` address to the `to` address
    /// @param asset The asset to transfer, including the asset amount
    /// @param source The account supplying the asset
    /// @param recipient The asset recipient
    function _transfer(Asset memory asset, address source, address payable recipient) internal {
        if (asset.assetType == AssetType.Native) {
            // Ensure neither the token nor the identifier parameters are set
            if ((uint160(asset.token) | asset.identifier) != 0) {
                revert UNUSED_ASSET_PARAMETERS();
            }

            _transferETH(recipient, asset.amount);
        } else if (asset.assetType == AssetType.ERC20) {
            // Ensure that no identifier is supplied
            if (asset.identifier != 0) {
                revert UNUSED_ASSET_PARAMETERS();
            }

            _transferERC20(asset.token, source, recipient, asset.amount);
        } else if (asset.assetType == AssetType.ERC721) {
            _transferERC721(asset.token, asset.identifier, source, recipient, asset.amount);
        } else if (asset.assetType == AssetType.ERC1155) {
            _transferERC1155(asset.token, asset.identifier, source, recipient, asset.amount);
        } else {
            revert INVALID_ASSET_TYPE();
        }
    }

    /// @notice Transfers one or more assets from the provided `from` address to the `to` address
    /// @param assets The assets to transfer, including the asset amounts
    /// @param source The account supplying the assets
    /// @param recipient The asset recipient
    function _transferMany(Asset[] memory assets, address source, address payable recipient) internal {
        uint256 assetCount = assets.length;
        for (uint256 i = 0; i < assetCount; ) {
            _transfer(assets[i], source, recipient);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Transfers ETH to a recipient address
    /// @param recipient The transfer recipient
    /// @param amount The amount of ETH to transfer
    function _transferETH(address payable recipient, uint256 amount) internal {
        _assertNonZeroAmount(amount);

        bool success;
        assembly {
            success := call(10000, recipient, amount, 0, 0, 0, 0)
        }
        if (!success) {
            revert ETHER_TRANSFER_FAILED();
        }
    }

    /// @notice Transfers ERC20 tokens from a provided account to a recipient address
    /// @param token The token to transfer
    /// @param source The transfer source
    /// @param recipient The transfer recipient
    /// @param amount The amount to transfer
    function _transferERC20(address token, address source, address recipient, uint256 amount) internal {
        _assertNonZeroAmount(amount);

        // Use `transfer` if the source is this contract
        if (source == address(this)) {
            IERC20(token).safeTransfer(recipient, amount);
        } else {
            IERC20(token).safeTransferFrom(source, recipient, amount);
        }
    }

    /// @notice Transfers an ERC721 token to a recipient address
    /// @param token The token to transfer
    /// @param identifier The ID of the token to transfer
    /// @param source The transfer source
    /// @param recipient The transfer recipient
    /// @param amount The token amount (Must be 1)
    function _transferERC721(
        address token,
        uint256 identifier,
        address source,
        address recipient,
        uint256 amount
    ) internal {
        if (amount != 1) {
            revert INVALID_ERC721_TRANSFER_AMOUNT();
        }
        IERC721(token).transferFrom(source, recipient, identifier);
    }

    /// @notice Transfers ERC1155 tokens to a recipient address
    /// @param token The token to transfer
    /// @param identifier The ID of the token to transfer
    /// @param source The transfer source
    /// @param recipient The transfer recipient
    /// @param amount The amount to transfer
    function _transferERC1155(
        address token,
        uint256 identifier,
        address source,
        address recipient,
        uint256 amount
    ) internal {
        _assertNonZeroAmount(amount);

        IERC1155(token).safeTransferFrom(source, recipient, identifier, amount, new bytes(0));
    }

    /// @dev Ensure that a given asset amount is not zero
    /// @param amount The amount to check
    function _assertNonZeroAmount(uint256 amount) internal pure {
        // Revert if the supplied amount is equal to zero
        if (amount == 0) {
            revert MISSING_ASSET_AMOUNT();
        }
    }
}


// File: contracts/ethereum/lib/utils/DepositReceiver.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { IDepositReceiver } from '../../interfaces/IDepositReceiver.sol';

abstract contract DepositReceiver is IDepositReceiver {
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IDepositReceiver).interfaceId;
    }
}


// File: contracts/ethereum/lib/utils/TokenHolder.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { ERC165 } from './ERC165.sol';
import { IERC165 } from '../../interfaces/IERC165.sol';
import { ERC721TokenReceiver, ERC1155TokenReceiver } from './TokenReceiver.sol';

/// @notice A contract which properly accepts and holds ERC721 & ERC1155 tokens.
abstract contract TokenHolder is ERC721TokenReceiver, ERC1155TokenReceiver, ERC165 {
    /// @notice If the contract implements an interface
    /// @param interfaceId The interface id
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(ERC721TokenReceiver).interfaceId ||
            interfaceId == type(ERC1155TokenReceiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}


// File: contracts/ethereum/interfaces/IManager.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { ITokenMetadataRenderer } from './ITokenMetadataRenderer.sol';

/// @notice Interface for the Manager contract
interface IManager {
    /// @notice Emitted when a house implementation is registered
    /// @param houseImpl The house implementation address
    /// @param houseType The house implementation type
    event HouseRegistered(address houseImpl, bytes32 houseType);

    /// @notice Emitted when a house implementation is unregistered
    /// @param houseImpl The house implementation address
    event HouseUnregistered(address houseImpl);

    /// @notice Emitted when a round implementation is registered on a house
    /// @param houseImpl The house implementation address
    /// @param roundImpl The round implementation address
    /// @param roundType The round implementation type
    event RoundRegistered(address houseImpl, address roundImpl, bytes32 roundType);

    /// @notice Emitted when a round implementation is unregistered on a house
    /// @param houseImpl The house implementation address
    /// @param roundImpl The round implementation address
    event RoundUnregistered(address houseImpl, address roundImpl);

    /// @notice Emitted when a metadata renderer is set for a contract
    /// @param addr The contract address
    /// @param renderer The renderer address
    event MetadataRendererSet(address addr, address renderer);

    /// @notice Emitted when the security council address is set
    /// @param securityCouncil The security council address
    event SecurityCouncilSet(address securityCouncil);

    /// @notice Determine if a house implementation is registered
    /// @param houseImpl The house implementation address
    function isHouseRegistered(address houseImpl) external view returns (bool);

    /// @notice Determine if a round implementation is registered on the provided house
    /// @param houseImpl The house implementation address
    /// @param roundImpl The round implementation address
    function isRoundRegistered(address houseImpl, address roundImpl) external view returns (bool);

    /// @notice Get the metadata renderer for a contract
    /// @param contract_ The contract address
    function getMetadataRenderer(address contract_) external view returns (ITokenMetadataRenderer);

    /// @notice Get the security council address
    function getSecurityCouncil() external view returns (address);
}


// File: contracts/ethereum/lib/token/ERC1155.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.17;

import { ERC1155TokenReceiver } from '../utils/TokenReceiver.sol';
import { IERC1155 } from '../../interfaces/IERC1155.sol';

/// @notice Minimalist and gas efficient standard ERC1155 implementation.
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
/// - Uses custom errors
/// - Does not revert on `_mint` & `_batchMint` if the receiver is a contract and does NOT implement the ERC1155TokenReceiver rules
abstract contract ERC1155 is IERC1155 {
    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    function uri(uint256 id) external view virtual returns (string memory);

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) {
            revert NOT_AUTHORIZED();
        }

        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(msg.sender, from, to, ids, amounts, data);

        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        // prettier-ignore
        if (to.code.length == 0 ? to == address(0) : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) != ERC1155TokenReceiver.onERC1155Received.selector) {
            revert UNSAFE_RECIPIENT();
        }
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        if (ids.length != amounts.length) {
            revert LENGTH_MISMATCH();
        }
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) {
            revert NOT_AUTHORIZED();
        }

        _beforeTokenTransfer(msg.sender, from, to, ids, amounts, data);

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        // prettier-ignore
        if (to.code.length == 0 ? to == address(0) : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) != ERC1155TokenReceiver.onERC1155BatchReceived.selector) {
            revert UNSAFE_RECIPIENT();
        }
    }

    function balanceOfBatch(
        address[] calldata owners,
        uint256[] calldata ids
    ) public view virtual returns (uint256[] memory balances) {
        if (owners.length != ids.length) {
            revert LENGTH_MISMATCH();
        }

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(msg.sender, address(0), to, ids, amounts, data);

        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        if (to.code.length == 0) {
            if (to == address(0)) {
                revert UNSAFE_RECIPIENT();
            }
        } else {
            // prettier-ignore
            try ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) returns (bytes4 response) {
                // `to` supports `ERC1155TokenReceiver`. Revert if an unexpected response is received.
                if (response != ERC1155TokenReceiver.onERC1155Received.selector) {
                    revert UNSAFE_RECIPIENT();
                }
            } catch {
                // We MUST check if `to` supports `ERC1155TokenReceiver`. If not, we take a less restrictive approach than
                // most implementations and do NOT revert. According to the spec, this is valid behavior.
                try ERC1155TokenReceiver(to).supportsInterface(0x4e2312e0 /* `ERC1155TokenReceiver` support */) returns (bool supported) {
                    if (supported) {
                        revert UNSAFE_RECIPIENT();
                    }
                } catch {}
            }
        }
    }

    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        if (idsLength != amounts.length) {
            revert LENGTH_MISMATCH();
        }

        _beforeTokenTransfer(msg.sender, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[to][ids[i]] += amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        if (to.code.length == 0) {
            if (to == address(0)) {
                revert UNSAFE_RECIPIENT();
            }
        } else {
            // prettier-ignore
            try ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) returns (bytes4 response) {
                // `to` supports `ERC1155TokenReceiver`. Revert if an unexpected response is received.
                if (response != ERC1155TokenReceiver.onERC1155BatchReceived.selector) {
                    revert UNSAFE_RECIPIENT();
                }
            } catch {
                // We MUST check if `to` supports `ERC1155TokenReceiver`. If not, we take a less restrictive approach than
                // most implementations and do NOT revert. According to the spec, this is valid behavior.
                try ERC1155TokenReceiver(to).supportsInterface(0x4e2312e0 /* `ERC1155TokenReceiver` support */) returns (bool supported) {
                    if (supported) {
                        revert UNSAFE_RECIPIENT();
                    }
                } catch {}
            }
        }
    }

    function _batchBurn(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        if (idsLength != amounts.length) {
            revert LENGTH_MISMATCH();
        }

        _beforeTokenTransfer(msg.sender, from, address(0), ids, amounts, '');

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[from][ids[i]] -= amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(msg.sender, from, address(0), ids, amounts, '');

        balanceOf[from][id] -= amount;

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory array) {
        array = new uint256[](1);
        array[0] = element;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}
}


// File: /Users/prop-house/node_modules/solady/src/utils/Clone.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Class with helper read functions for clone with immutable args.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/Clone.sol)
/// @author Adapted from clones with immutable args by zefram.eth, Saw-mon & Natalie
/// (https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args)
abstract contract Clone {
    /// @dev Reads an immutable arg with type bytes.
    function _getArgBytes(uint256 argOffset, uint256 length)
        internal
        pure
        returns (bytes memory arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            // Grab the free memory pointer.
            arg := mload(0x40)
            // Store the array length.
            mstore(arg, length)
            // Copy the array.
            calldatacopy(add(arg, 0x20), add(offset, argOffset), length)
            // Allocate the memory, rounded up to the next 32 byte boudnary.
            mstore(0x40, and(add(add(arg, 0x3f), length), not(0x1f)))
        }
    }

    /// @dev Reads an immutable arg with type address.
    function _getArgAddress(uint256 argOffset) internal pure returns (address arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            arg := shr(0x60, calldataload(add(offset, argOffset)))
        }
    }

    /// @dev Reads an immutable arg with type uint256
    function _getArgUint256(uint256 argOffset) internal pure returns (uint256 arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    /// @dev Reads a uint256 array stored in the immutable args.
    function _getArgUint256Array(uint256 argOffset, uint256 length)
        internal
        pure
        returns (uint256[] memory arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            // Grab the free memory pointer.
            arg := mload(0x40)
            // Store the array length.
            mstore(arg, length)
            // Copy the array.
            calldatacopy(add(arg, 0x20), add(offset, argOffset), shl(5, length))
            // Allocate the memory.
            mstore(0x40, add(add(arg, 0x20), shl(5, length)))
        }
    }

    /// @dev Reads an immutable arg with type uint64.
    function _getArgUint64(uint256 argOffset) internal pure returns (uint64 arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            arg := shr(0xc0, calldataload(add(offset, argOffset)))
        }
    }

    /// @dev Reads an immutable arg with type uint8.
    function _getArgUint8(uint256 argOffset) internal pure returns (uint8 arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            arg := shr(0xf8, calldataload(add(offset, argOffset)))
        }
    }

    /// @return offset The offset of the packed immutable args in calldata.
    function _getImmutableArgsOffset() internal pure returns (uint256 offset) {
        /// @solidity memory-safe-assembly
        assembly {
            offset := sub(calldatasize(), shr(0xf0, calldataload(sub(calldatasize(), 2))))
        }
    }
}


// File: contracts/ethereum/interfaces/IHouse.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { IERC721 } from './IERC721.sol';

/// @notice Common House interface
interface IHouse is IERC721 {
    /// @notice Thrown when the caller is not the prop house contract
    error ONLY_PROP_HOUSE();

    /// @notice Thrown when the caller does not hold the house ownership token
    error ONLY_HOUSE_OWNER();

    /// @notice Thrown when the provided value does not fit into 8 bits
    error VALUE_DOES_NOT_FIT_IN_8_BITS();

    /// @notice The house type
    function kind() external view returns (bytes32);

    /// @notice Initialize the house
    /// @param data Initialization data
    function initialize(bytes calldata data) external;

    /// @notice Returns `true` if the provided address is a valid round on the house
    /// @param round The round to validate
    function isRound(address round) external view returns (bool);

    /// @notice Create a new round
    /// @param impl The round implementation contract
    /// @param title The round title
    /// @param creator The round creator address
    function createRound(address impl, string calldata title, address creator) external returns (address);
}


// File: contracts/ethereum/interfaces/IRound.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { IERC165 } from './IERC165.sol';

/// @notice Interface that must be implemented by all round types
interface IRound is IERC165 {
    /// @notice Thrown when the caller of a guarded function is not the prop house contract
    error ONLY_PROP_HOUSE();

    /// @notice Thrown when the caller of a guarded function is not the round manager
    error ONLY_ROUND_MANAGER();

    /// @notice Thrown when the address of a provided strategy is zero
    /// @param strategy The address of the strategy
    error INVALID_STRATEGY(uint256 strategy);

    /// @notice The round type
    function kind() external view returns (bytes32);

    /// @notice Get the round title
    function title() external pure returns (string memory);

    /// @notice Initialize the round
    /// @param data The optional round data. If empty, round registration is deferred.
    function initialize(bytes calldata data) external payable;

    /// @notice The house that the round belongs to
    function house() external view returns (address);

    /// @notice The round ID
    function id() external view returns (uint256);
}


// File: contracts/ethereum/interfaces/IPropHouse.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { Asset } from '../lib/types/Common.sol';
import { IERC721 } from './IERC721.sol';

/// @notice Interface implemented by the Prop House entry contract
interface IPropHouse is IERC721 {
    /// @notice House creation data, including the implementation contract and config
    struct House {
        address impl;
        bytes config;
    }

    /// @notice Round creation data, including the implementation contract, config, and other metadata
    struct Round {
        address impl;
        bytes config;
        string title;
        string description;
    }

    /// @notice Thrown when an insufficient amount of ether is provided to `msg.value`
    error INSUFFICIENT_ETHER_SUPPLIED();

    /// @notice Thrown when a provided house is invalid
    error INVALID_HOUSE();

    /// @notice Thrown when a provided round is invalid
    error INVALID_ROUND();

    /// @notice Thrown when a provided house implementation is invalid
    error INVALID_HOUSE_IMPL();

    /// @notice Thrown when a round implementation contract is invalid for a house
    error INVALID_ROUND_IMPL_FOR_HOUSE();

    /// @notice Thrown when a house attempts to pull tokens from a user who has not approved it
    error HOUSE_NOT_APPROVED_BY_USER();

    /// @notice Emitted when a house is created
    /// @param creator The house creator
    /// @param house The house contract address
    /// @param kind The house contract type
    event HouseCreated(address indexed creator, address indexed house, bytes32 kind);

    /// @notice Emitted when a round is created
    /// @param creator The round creator
    /// @param house The house that the round was created on
    /// @param round The round contract address
    /// @param kind The round contract type
    /// @param title The round title
    /// @param description The round description
    event RoundCreated(
        address indexed creator,
        address indexed house,
        address indexed round,
        bytes32 kind,
        string title,
        string description
    );

    /// @notice Emitted when an asset is deposited to a round
    /// @param from The user who deposited the asset
    /// @param round The round that received the asset
    /// @param asset The asset information
    event DepositToRound(address from, address round, Asset asset);

    /// @notice Emitted when one or more assets are deposited to a round
    /// @param from The user who deposited the asset(s)
    /// @param round The round that received the asset(s)
    /// @param assets The asset information
    event BatchDepositToRound(address from, address round, Asset[] assets);

    /// @notice Returns `true` if the passed `house` address is valid
    /// @param house The house address
    function isHouse(address house) external view returns (bool);

    /// @notice Returns `true` if the passed `round` address is valid on any house
    /// @param round The round address
    function isRound(address round) external view returns (bool);
}


// File: contracts/ethereum/interfaces/IStarknetCore.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

interface IStarknetCore {
    /// @notice Send a message to an L2 contract and return the hash of the message
    /// @param toAddress The callee address
    /// @param selector The function selector
    /// @param payload The message payload
    function sendMessageToL2(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload
    ) external payable returns (bytes32);

    /// @notice Starts the cancellation of an L1 to L2 message
    /// @param toAddress The callee address
    /// @param selector The function selector
    /// @param payload The message payload
    /// @param nonce The message nonce
    function startL1ToL2MessageCancellation(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload,
        uint256 nonce
    ) external;

    /// @notice Cancels an L1 to L2 message, this function should be called messageCancellationDelay() seconds
    /// after the call to startL1ToL2MessageCancellation()
    /// @param selector The function selector
    /// @param payload The message payload
    /// @param nonce The message nonce
    function cancelL1ToL2Message(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload,
        uint256 nonce
    ) external;

    /// @notice Consume a message that was sent from an L2 contract and return the hash of the message
    /// @param fromAddress The caller address
    /// @param payload The message payload
    function consumeMessageFromL2(uint256 fromAddress, uint256[] calldata payload) external returns (bytes32);
}


// File: contracts/ethereum/interfaces/IMessenger.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { IStarknetCore } from './IStarknetCore.sol';

interface IMessenger {
    /// @notice Thrown when the caller of a guarded function is not a valid round
    error ONLY_ROUND();

    /// @notice Returns the Starknet core contract instance
    function starknet() external view returns (IStarknetCore);

    /// @notice Send a message to an L2 contract and return the hash of the message
    /// @param toAddress The callee address
    /// @param selector The function selector
    /// @param payload The message payload
    function sendMessageToL2(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload
    ) external payable returns (bytes32);

    /// @notice Starts the cancellation of an L1 to L2 message
    /// @param toAddress The callee address
    /// @param selector The function selector
    /// @param payload The message payload
    /// @param nonce The message cancellation nonce
    function startL1ToL2MessageCancellation(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload,
        uint256 nonce
    ) external;

    /// @notice Cancels an L1 to L2 message, this function should be called messageCancellationDelay() seconds
    /// after the call to startL1ToL2MessageCancellation()
    /// @param selector The function selector
    /// @param payload The message payload
    /// @param nonce The message cancellation nonce
    function cancelL1ToL2Message(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload,
        uint256 nonce
    ) external;
}


// File: /Users/prop-house/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol
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


// File: /Users/prop-house/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/IERC721.sol)

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


// File: /Users/prop-house/node_modules/@openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

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


// File: /Users/prop-house/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

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
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
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


// File: contracts/ethereum/interfaces/IDepositReceiver.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { IRound } from './IRound.sol';

/// @notice Interface that can be implemented by rounds that receive deposits
interface IDepositReceiver is IRound {
    /// @notice A callback that is called when a deposit is received
    function onDepositReceived(address depositor, uint256 id, uint256 amount) external;

    /// @notice A callback that is called when a batch of deposits is received
    function onDepositsReceived(address depositor, uint256[] calldata ids, uint256[] calldata amounts) external;
}


// File: contracts/ethereum/lib/utils/ERC165.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { IERC165 } from '../../interfaces/IERC165.sol';

abstract contract ERC165 is IERC165 {
    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


// File: contracts/ethereum/lib/utils/TokenReceiver.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

import { IERC165 } from '../../interfaces/IERC165.sol';

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
abstract contract ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
abstract contract ERC1155TokenReceiver is IERC165 {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external view virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external view virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}


// File: contracts/ethereum/interfaces/ITokenMetadataRenderer.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

interface ITokenMetadataRenderer {
    /// @notice Returns metadata for `tokenId` as a Base64-JSON blob
    /// @param tokenId The token ID
    function tokenURI(uint256 tokenId) external view returns (string memory);
}


// File: contracts/ethereum/interfaces/IERC1155.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

/// @title IERC1155
/// @notice The external ERC1155 events, errors, and functions
interface IERC1155 {
    /// @notice Thrown when the caller is not authorized
    error NOT_AUTHORIZED();

    /// @notice Thrown when the receiver is the zero address or fails to accept the transfer
    error UNSAFE_RECIPIENT();

    /// @notice Thrown when provided array lengths are not equal
    error LENGTH_MISMATCH();

    /// @notice Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /// @notice Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all transfers
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /// @notice Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
    /// `approved`
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /// @notice Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI
    event URI(string value, uint256 indexed id);

    /// @notice Returns the amount of tokens of token type `id` owned by `account`
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /// @notice Batched version of {balanceOf}
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    /// @notice Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`
    function setApprovalForAll(address operator, bool approved) external;

    /// @notice Returns true if `operator` is approved to transfer `account`'s tokens
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /// @notice Transfers `amount` tokens of token type `id` from `from` to `to`
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /// @notice Batched version of {safeTransferFrom}
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// File: contracts/ethereum/interfaces/IERC721.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.17;

/// @title IERC721
/// @notice The external ERC721 events, errors, and functions
interface IERC721 {
    /// @dev Thrown when a caller is not authorized to approve or transfer a token
    error INVALID_APPROVAL();

    /// @dev Thrown when a transfer is called with the incorrect token owner
    error INVALID_OWNER();

    /// @dev Thrown when a transfer is attempted to address(0)
    error INVALID_RECIPIENT();

    /// @dev Thrown when an existing token is called to be minted
    error ALREADY_MINTED();

    /// @dev Thrown when a non-existent token is called to be burned
    error NOT_MINTED();

    /// @dev Thrown when address(0) is incorrectly provided
    error ADDRESS_ZERO();

    /// @notice Emitted when a token is transferred from sender to recipient
    /// @param from The sender address
    /// @param to The recipient address
    /// @param tokenId The ERC-721 token id
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /// @notice Emitted when an owner approves an account to manage a token
    /// @param owner The owner address
    /// @param approved The account address
    /// @param tokenId The ERC-721 token id
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /// @notice Emitted when an owner sets an approval for a spender to manage all tokens
    /// @param owner The owner address
    /// @param operator The spender address
    /// @param approved If the approval is being set or removed
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @notice Emitted when the contract URI is updated
    /// @param uri The updated contract URI
    event ContractURIUpdated(string uri);

    /// @notice Contract-level metadata
    function contractURI() external view returns (string memory);

    /// @notice The number of tokens owned
    /// @param owner The owner address
    function balanceOf(address owner) external view returns (uint256);

    /// @notice The owner of a token
    /// @param tokenId The ERC-721 token id
    function ownerOf(uint256 tokenId) external view returns (address);

    /// @notice The account approved to manage a token
    /// @param tokenId The ERC-721 token id
    function getApproved(uint256 tokenId) external view returns (address);

    /// @notice If an operator is authorized to manage all of an owner's tokens
    /// @param owner The owner address
    /// @param operator The operator address
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /// @notice Authorizes an account to manage a token
    /// @param to The account address
    /// @param tokenId The ERC-721 token id
    function approve(address to, uint256 tokenId) external;

    /// @notice Authorizes an account to manage all tokens
    /// @param operator The account address
    /// @param approved If permission is being given or removed
    function setApprovalForAll(address operator, bool approved) external;

    /// @notice Safe transfers a token from sender to recipient with additional data
    /// @param from The sender address
    /// @param to The recipient address
    /// @param tokenId The ERC-721 token id
    /// @param data The additional data sent in the call to the recipient
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /// @notice Safe transfers a token from sender to recipient
    /// @param from The sender address
    /// @param to The recipient address
    /// @param tokenId The ERC-721 token id
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /// @notice Transfers a token from sender to recipient
    /// @param from The sender address
    /// @param to The recipient address
    /// @param tokenId The ERC-721 token id
    function transferFrom(address from, address to, uint256 tokenId) external;
}


// File: /Users/prop-house/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol
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


// File: /Users/prop-house/node_modules/@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol
// SPDX-License-Identifier: MIT
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


// File: /Users/prop-house/node_modules/@openzeppelin/contracts/utils/Address.sol
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


