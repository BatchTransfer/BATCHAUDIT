// Chain: POLYGON - File: TwTStakingFacet.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {LibTwTShadowcornDefense} from "LibTwTShadowcornDefense.sol";

contract TwTStakingFacet {
    function twtGetMultipleMinionStakingPoints(
        uint24[5] memory minionPoolIds,
        uint24[5] memory minionPoolAmounts
    ) external view returns (uint56 totalStakingPoints) {
        return
            LibTwTShadowcornDefense.twtGetMultipleMinionStakingPoints(
                minionPoolIds,
                minionPoolAmounts
            );
    }

    function twtBatchUnstakeShadowcornSquads(
        uint8 regionId,
        uint24 minionSquadsUnstakeCount
    ) external {
        LibTwTShadowcornDefense.twtBatchUnstakeShadowcornSquads(
            regionId,
            minionSquadsUnstakeCount,
            msg.sender
        );
    }
}


// Chain: POLYGON - File: LibTwTShadowcornDefense.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LibExternalAddress} from "LibExternalAddress.sol";
import {IMinionStats} from "IMinionStats.sol";
import {LibTwTModifier} from "LibTwTModifier.sol";
import {IShadowcornStatsFacet} from "IShadowcornStatsFacet.sol";
import {IERC721} from "IERC721.sol";
import {LibTwTSeason} from "LibTwTSeason.sol";
import {TerminusFacet} from "TerminusFacet.sol";
import {LibEvents} from "LibEvents.sol";
import {LibTwTAdmin} from "LibTwTAdmin.sol";
import {LibTwTMinions} from "LibTwTMinions.sol";
import {LibTwTRewards} from "LibTwTRewards.sol";
import {LibTwTWave} from "LibTwTWave.sol";
import {IStakingFacet} from "IStakingFacet.sol";
import {LibGasReturner} from "LibGasReturner.sol";

library LibTwTShadowcornDefense {
    /// @notice Position to store the storage
    bytes32 private constant TWT_SHADOWCORN_DEFENSE_STORAGE_POSITION =
        keccak256("CryptoUnicorns.TwT.ShadowcornDefense.Storage");

    uint256 private constant ITEMS_PER_PAGE = 12;

    struct LibTwTShadowcornDefenseStorage {
        uint40 lastSquadId;
        uint24 maxBatchQuantityForMinionSquads;
        mapping(uint40 squadId => ShadowcornSquad squad) squadById;
        mapping(uint16 seasonId => uint24 maxSquadSize) maxSquadSizeBySeason;
        mapping(address account => uint40[] squadIds) stakedSquadsByUser;
        mapping(uint40 squadId => uint256 index) shadowcornSquadIdToIndexInSquadsByUser;
        mapping(uint16 seasonId => uint24 maxSquadLimit) maxUnstakableMinionSquadsLimit;
    }

    struct ShadowcornSquad {
        //slot 1
        address sender; // 20 bytes
        uint40 squadId; // 5 bytes
        uint24 damageModifiers; // 3 bytes
        uint24 totalStats; // 3 bytes
        uint8 regionId; // 1 byte
        // slot 2
        uint24[5] minionAmounts; // 15 bytes
        uint24[5] poolIds; // 15 bytes
        //slot 3
        uint8[] minionClasses;
        // slot 4
        uint24 staminaModifiers; // 3 bytes
        uint24 shadowcornOverseerTokenId; // 3 bytes
        uint24 seasonId; // 3 bytes
        // 23 bytes free
    }

    function twtShadowcornDefenseStorage()
        internal
        pure
        returns (LibTwTShadowcornDefenseStorage storage sds)
    {
        bytes32 position = TWT_SHADOWCORN_DEFENSE_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sds.slot := position
        }
    }

    struct DraftSquadPlacement {
        uint56 dominationPointsToAward;
        uint24 shadowcornOverseerTokenId;
        uint24 squadSize;
        uint16 seasonId;
        uint8 regionId;
        IMinionStats.MinionStats[5] minionStats;
        uint8[] minionClasses;
        uint24[5] minionAmounts;
        uint8 amountOfDifferentClasses;
    }

    function twtGetMaxBatchQuantityForMinionSquads()
        internal
        view
        returns (uint24)
    {
        return twtShadowcornDefenseStorage().maxBatchQuantityForMinionSquads;
    }

    function twtSetMaxBatchQuantityForMinionSquads(
        uint24 maxBatchQuantity
    ) internal {
        require(
            maxBatchQuantity > 0,
            "SD-013"
        );

        twtShadowcornDefenseStorage()
            .maxBatchQuantityForMinionSquads = maxBatchQuantity;
    }

    function twtGetMultipleMinionStakingPoints(
        uint24[5] memory minionPoolIds,
        uint24[5] memory minionPoolAmounts
    ) internal view returns (uint56 totalStakingPoints) {
        for (uint256 i = 0; i < minionPoolIds.length; ++i) {
            if (minionPoolIds[i] > 0) {
                totalStakingPoints +=
                    LibTwTAdmin.twtGetMinionPoolStakingPoints(
                        minionPoolIds[i]
                    ) *
                    minionPoolAmounts[i];
            }
        }
    }

    function twtValidateUserCanDefendRegionAndGetData(
        address user,
        uint8 regionId,
        uint24 shadowcornOverseerTokenId,
        uint24[5] memory poolIds,
        uint24[5] memory minionAmounts,
        uint24 batchQuantity
    ) internal view returns (DraftSquadPlacement memory draftSquadPlacement) {
        {
            bool someZeroAppeared = false;
            for (uint256 i = 0; i < poolIds.length; ++i) {
                if (someZeroAppeared) {
                    require(
                        poolIds[i] == 0 && minionAmounts[i] == 0,
                        "SD-012"
                    );
                } else {
                    if (poolIds[i] > 0) {
                        require(
                            minionAmounts[i] > 0,
                            "SD-011"
                        );
                        draftSquadPlacement.amountOfDifferentClasses++;
                    } else {
                        someZeroAppeared = true;
                        require(
                            minionAmounts[i] == 0,
                            "SD-010"
                        );
                    }
                }
            }
        }
        // Check batch quantity is > 0 and < limit
        require(
            batchQuantity > 0 &&
                batchQuantity <= twtGetMaxBatchQuantityForMinionSquads(),
            "SD-009"
        );

        // Enforce shadowcorn is valid
        require(
            shadowcornOverseerTokenId > 0,
            "SD-008"
        );

        {
            // Enforce user owns shadowcorn
            IERC721 shadowcornContract = IERC721(
                LibExternalAddress.getShadowcornAddress()
            );

            IStakingFacet.StakeData memory stakeData = IStakingFacet(
                LibExternalAddress.getMinionHatcheryAddress()
            ).getStakingInfoByShadowcornId(shadowcornOverseerTokenId);

            if (stakeData.staker != user) {
                require(
                    shadowcornContract.ownerOf(shadowcornOverseerTokenId) ==
                        user,
                    "SD-007"
                );
            }
        }

        LibTwTRewards.enforceRegionIdIsValid(regionId);

        (
            LibTwTSeason.TwTSeasonState seasonState,
            uint16 seasonId
        ) = LibTwTSeason.twtGetCurrentSeason();

        // Cast pool ids to uint256
        uint256[] memory castedPoolIds = new uint256[](poolIds.length);
        for (uint256 i = 0; i < poolIds.length; ++i) {
            castedPoolIds[i] = uint256(poolIds[i]);
        }

        (
            IMinionStats.MinionStats[] memory minionStats,
            uint8[] memory minionClasses
        ) = IMinionStats(LibExternalAddress.getShadowcornItemsAddress())
                .getMinionPoolStatsAndClassesMultiple(castedPoolIds);

        for (uint256 i = 0; i < poolIds.length; ++i) {
            if (poolIds[i] == 0) {
                break;
            }
            LibTwTAdmin.enforcePoolIdIsMinionPoolId(poolIds[i]);
        }

        draftSquadPlacement
            .dominationPointsToAward = twtGetMultipleMinionStakingPoints(
            poolIds,
            minionAmounts
        );

        draftSquadPlacement.squadSize = enforceSquadHasValidSize(
            minionAmounts,
            seasonId
        );

        // Enforce current season is preseason or active
        require(
            seasonState == LibTwTSeason.TwTSeasonState.PRESEASON ||
                seasonState == LibTwTSeason.TwTSeasonState.ACTIVE,
            "SD-006"
        );

        draftSquadPlacement.regionId = regionId;
        draftSquadPlacement
            .shadowcornOverseerTokenId = shadowcornOverseerTokenId;
        draftSquadPlacement.minionStats = [
            minionStats[0],
            minionStats[1],
            minionStats[2],
            minionStats[3],
            minionStats[4]
        ];
        draftSquadPlacement.minionClasses = minionClasses;
        draftSquadPlacement.minionAmounts = minionAmounts;
        draftSquadPlacement.seasonId = seasonId;
    }

    function twtGetShadowcornSquadById(
        uint40 squadId
    ) internal view returns (ShadowcornSquad memory) {
        return twtShadowcornDefenseStorage().squadById[squadId];
    }

    function twtRemoveMinionSquadFromUserSquads(
        address user,
        uint40 minionSquadId
    ) internal {
        LibTwTShadowcornDefenseStorage
            storage sds = twtShadowcornDefenseStorage();
        uint256 index = sds.shadowcornSquadIdToIndexInSquadsByUser[
            minionSquadId
        ];
        uint40[] storage squads = sds.stakedSquadsByUser[user];
        uint40 lastMinionSquadId = squads[squads.length - 1];
        squads[index] = squads[squads.length - 1];
        squads.pop();
        delete sds.shadowcornSquadIdToIndexInSquadsByUser[minionSquadId];
        sds.shadowcornSquadIdToIndexInSquadsByUser[lastMinionSquadId] = index;
    }

    function twtAddMinionSquadToUserSquads(
        address user,
        uint40 minionSquadId
    ) internal {
        LibTwTShadowcornDefenseStorage
            storage sds = twtShadowcornDefenseStorage();
        sds.stakedSquadsByUser[user].push(minionSquadId);
        sds.shadowcornSquadIdToIndexInSquadsByUser[minionSquadId] =
            sds.stakedSquadsByUser[user].length -
            1;
    }

    function twtCheckStakedSquadExists(
        uint40 minionSquadId
    ) internal view returns (bool) {
        return
            twtShadowcornDefenseStorage()
                .shadowcornSquadIdToIndexInSquadsByUser[minionSquadId] != 0;
    }

    function twtGetShadowcornSquadsByUser(
        address user,
        uint32 _pageNumber
    )
        internal
        view
        returns (
            ShadowcornSquad[] memory squads,
            uint256[] memory unlockableWaves,
            bool moreEntriesExist,
            uint256 totalEntries
        )
    {
        LibTwTShadowcornDefenseStorage
            storage sds = twtShadowcornDefenseStorage();
        uint40[] memory userSquads = sds.stakedSquadsByUser[user];
        totalEntries = userSquads.length;
        uint256 start = _pageNumber * ITEMS_PER_PAGE;
        uint count = totalEntries - start;
        if (count > ITEMS_PER_PAGE) {
            count = ITEMS_PER_PAGE;
            moreEntriesExist = true;
        }
        squads = new ShadowcornSquad[](count);
        unlockableWaves = new uint256[](count);
        for (uint256 i = 0; i < count; ++i) {
            uint256 index = start + i;
            uint40 squadId = userSquads[index];
            squads[i] = sds.squadById[squadId];
            unlockableWaves[i] = LibTwTMinions
                .twtGetMinionSquadUnlockableWaveId(squadId);
        }
    }

    function twtGetTodayShadowcornDominationPointsForAllRegions(
        uint16 seasonId
    ) internal view returns (uint56[5] memory shadowcornDominationPoints) {
        uint256 waveId = LibTwTWave.twtGetCurrentWaveId();
        for (uint8 i = 1; i < 6; ++i) {
            shadowcornDominationPoints[i - 1] = LibTwTRewards
                .twtGetShadowcornDominationPointsBySeasonRegionAndWave(
                    seasonId,
                    i,
                    waveId
                );
        }
    }

    function twtShadowcornDefendRegion(
        uint8 regionId,
        uint24 shadowcornOverseerTokenId,
        uint24[5] memory poolIds,
        uint24[5] memory minionAmounts,
        uint24 batchQuantity,
        address user
    ) internal {
        uint256 availableGas = gasleft();
        LibTwTShadowcornDefenseStorage
            storage sds = twtShadowcornDefenseStorage();

        DraftSquadPlacement
            memory draftSquadPlacement = twtValidateUserCanDefendRegionAndGetData(
                user,
                regionId,
                shadowcornOverseerTokenId,
                poolIds,
                minionAmounts,
                batchQuantity
            );

        (
            uint24 totalStats,
            uint24 damageModifiers,
            uint24 staminaModifiers
        ) = twtPrecalcSquadTotalStatsAndModifiers(draftSquadPlacement);

        {
            uint24[5] memory minionAmountsToTransfer;
            //  Transfer all minions in one move
            if (batchQuantity > 1) {
                for (
                    uint256 i = 0;
                    i < draftSquadPlacement.amountOfDifferentClasses;
                    ++i
                ) {
                    minionAmountsToTransfer[i] =
                        minionAmounts[i] *
                        batchQuantity;
                }
            } else {
                minionAmountsToTransfer = minionAmounts;
            }

            uint24[] memory castedMinionAmountsToTransfer = new uint24[](
                draftSquadPlacement.amountOfDifferentClasses
            );
            uint24[] memory castedMinionPoolIdsToTransfer = new uint24[](
                draftSquadPlacement.amountOfDifferentClasses
            );

            for (uint24 i = 0; i < castedMinionAmountsToTransfer.length; ++i) {
                castedMinionAmountsToTransfer[i] = minionAmountsToTransfer[i];
                castedMinionPoolIdsToTransfer[i] = poolIds[i];
            }

            transferMinions(
                user,
                address(this),
                castedMinionPoolIdsToTransfer,
                castedMinionAmountsToTransfer
            );
        }

        uint40[] memory squadIds = new uint40[](batchQuantity);
        // Iterate batchQuantity times to place minion squads in batch
        for (uint256 i = 0; i < batchQuantity; ++i) {
            squadIds[i] = ++sds.lastSquadId;

            // Add squad to squads array (LibTwTMinions)
            LibTwTMinions.twtAddMinionSquadToArray(
                draftSquadPlacement.seasonId,
                regionId,
                sds.lastSquadId
            );

            // Set minion squad unlockable wave id (LibTwTMinions)
            LibTwTMinions.twtSetMinionSquadUnlockableWaveId(
                draftSquadPlacement.seasonId,
                sds.lastSquadId
            );

            sds.squadById[sds.lastSquadId] = ShadowcornSquad({
                squadId: sds.lastSquadId,
                shadowcornOverseerTokenId: draftSquadPlacement
                    .shadowcornOverseerTokenId,
                poolIds: poolIds,
                minionAmounts: draftSquadPlacement.minionAmounts,
                minionClasses: draftSquadPlacement.minionClasses,
                sender: user,
                totalStats: totalStats,
                damageModifiers: damageModifiers,
                staminaModifiers: staminaModifiers,
                seasonId: draftSquadPlacement.seasonId,
                regionId: draftSquadPlacement.regionId
            });

            twtAddMinionSquadToUserSquads(user, sds.lastSquadId);
        }

        // Add stakePts to user for this wave (LibTwTRewards)
        LibTwTRewards.twtBatchAddShadowcornStakingPts(
            draftSquadPlacement.seasonId,
            regionId,
            squadIds,
            draftSquadPlacement.dominationPointsToAward,
            user
        );

        emit LibEvents.TwTShadowcornDefendedRegion(
            user,
            draftSquadPlacement.seasonId,
            draftSquadPlacement.regionId,
            draftSquadPlacement.shadowcornOverseerTokenId,
            poolIds,
            draftSquadPlacement.minionAmounts,
            batchQuantity,
            block.timestamp,
            sds.lastSquadId
        );

        LibGasReturner.returnGasToUser(
            LibGasReturner.GasReturnerTransactionType.DEFEND,
            (availableGas - gasleft()),
            payable(user)
        );
    }

    function enforceSquadHasValidSize(
        uint24[5] memory minionAmounts,
        uint16 seasonId
    ) internal view returns (uint24 squadSize) {
        squadSize = 0;
        for (uint256 i = 0; i < minionAmounts.length; ++i) {
            squadSize += minionAmounts[i];
        }

        require(
            squadSize > 0 &&
                squadSize <=
                twtShadowcornDefenseStorage().maxSquadSizeBySeason[seasonId],
            "SD-005"
        );
    }

    function transferMinions(
        address from,
        address to,
        uint24[] memory poolIds,
        uint24[] memory minionAmounts
    ) private {
        // cast pool ids and minion amounts to uint256
        uint256[] memory castedPoolIds = new uint256[](poolIds.length);
        uint256[] memory castedMinionAmounts = new uint256[](
            minionAmounts.length
        );
        for (uint256 i = 0; i < poolIds.length; ++i) {
            castedPoolIds[i] = uint256(poolIds[i]);
            castedMinionAmounts[i] = uint256(minionAmounts[i]);
        }

        TerminusFacet(LibExternalAddress.getShadowcornItemsAddress())
            .safeBatchTransferFrom(
                from, // from
                to, // to
                castedPoolIds, // pool ids
                castedMinionAmounts, // pool amounts
                "" // data
            );
    }

    function twtBatchUnstakeShadowcornSquads(
        uint8 regionId,
        uint24 minionSquadsUnstakeCount,
        address user
    ) internal {
        validateUnstakeRequirements(regionId, minionSquadsUnstakeCount, user);

        uint40[] memory squadsToUnstake = getSquadsToUnstake(
            user,
            minionSquadsUnstakeCount
        );

        (
            uint24[] memory poolIds,
            uint24[] memory minionAmounts
        ) = handleUnstakeSquads(squadsToUnstake, regionId, user);

        // remove minion wave pts
        LibTwTRewards.twtRemoveMinionWavePts(
            LibTwTSeason.twtGetCurrentSeasonId(),
            regionId,
            user
        );

        transferMinions(address(this), user, poolIds, minionAmounts);

        emit LibEvents.TwtBatchShadowcornSquadsUnstaked(
            user,
            LibTwTSeason.twtGetCurrentSeasonId(),
            regionId,
            squadsToUnstake,
            block.timestamp
        );
    }

    function validateUnstakeRequirements(
        uint8 regionId,
        uint24 minionSquadsUnstakeCount,
        address user
    ) internal view {
        LibTwTRewards.enforceRegionIdIsValid(regionId);

        require(
            LibTwTSeason.twtValidateSeasonState(
                LibTwTSeason.twtGetCurrentSeasonId(),
                LibTwTSeason.TwTSeasonState.CLOSED
            ),
            "SD-004"
        );

        uint24 maxUnstakableSquadsLimit = twtGetMaxUnstakableMinionSquadsLimit(
            LibTwTSeason.twtGetCurrentSeasonId()
        );

        require(
            minionSquadsUnstakeCount > 0 &&
                minionSquadsUnstakeCount <= maxUnstakableSquadsLimit,
            "SD-003"
        );

        require(
            twtShadowcornDefenseStorage().stakedSquadsByUser[user].length > 0,
            "SD-002"
        );
    }

    function getSquadsToUnstake(
        address user,
        uint24 minionSquadsUnstakeCount
    ) internal view returns (uint40[] memory squadsToUnstake) {
        uint40[] memory userSquads = twtShadowcornDefenseStorage()
            .stakedSquadsByUser[user];
        uint256 squadsLength = userSquads.length;
        require(
            squadsLength > 0,
            "SD-001"
        );
        if (squadsLength < minionSquadsUnstakeCount) {
            minionSquadsUnstakeCount = uint24(squadsLength);
        }

        squadsToUnstake = new uint40[](minionSquadsUnstakeCount);
        for (uint256 i = 0; i < minionSquadsUnstakeCount; ++i) {
            squadsToUnstake[i] = userSquads[squadsLength - 1 - i];
        }

        return squadsToUnstake;
    }

    function handleUnstakeSquads(
        uint40[] memory squadsToUnstake,
        uint8 regionId,
        address user
    )
        internal
        returns (uint24[] memory poolIds, uint24[] memory minionAmounts)
    {
        poolIds = new uint24[](30);
        minionAmounts = new uint24[](30);
        uint256 lastNonZeroIndex = 0;
        for (
            uint256 squadToUnstakeIdx = 0;
            squadToUnstakeIdx < squadsToUnstake.length;
            squadToUnstakeIdx++
        ) {
            uint40 squadId = squadsToUnstake[squadToUnstakeIdx];

            LibTwTMinions.twtRemoveMinionSquadFromArray(
                LibTwTSeason.twtGetCurrentSeasonId(),
                regionId,
                squadId
            );
            twtRemoveMinionSquadFromUserSquads(user, squadId);
            ShadowcornSquad memory squad = twtShadowcornDefenseStorage()
                .squadById[squadId];
            bool[5] memory foundPreviousResult = [
                false,
                false,
                false,
                false,
                false
            ];
            for (uint256 i = 0; i < squad.poolIds.length; ++i) {
                if (squad.poolIds[i] == 0) {
                    break;
                }
                for (uint256 j = 0; j <= lastNonZeroIndex; ++j) {
                    if (poolIds[j] == squad.poolIds[i]) {
                        minionAmounts[j] += squad.minionAmounts[i];
                        foundPreviousResult[i] = true;
                    }
                }
            }
            for (uint256 i = 0; i < foundPreviousResult.length; ++i) {
                if (squad.poolIds[i] == 0) {
                    break;
                }
                if (!foundPreviousResult[i]) {
                    lastNonZeroIndex++;
                    poolIds[lastNonZeroIndex] = squad.poolIds[i];
                    minionAmounts[lastNonZeroIndex] = squad.minionAmounts[i];
                }
            }

            delete twtShadowcornDefenseStorage().squadById[squadId];
        }

        //set new length of poolIds and minionAmounts to lastNonZeroIndex + 1
        lastNonZeroIndex++;
        assembly {
            mstore(poolIds, lastNonZeroIndex)
        }
        assembly {
            mstore(minionAmounts, lastNonZeroIndex)
        }
        return (poolIds, minionAmounts);
    }

    function twtBatchRemoveMinionSquadFromArray(
        uint16 seasonId,
        uint8 regionId,
        uint40[] memory minionSquadIds
    ) internal {
        for (uint256 i = 0; i < minionSquadIds.length; ++i) {
            LibTwTMinions.twtRemoveMinionSquadFromArray(
                seasonId,
                regionId,
                minionSquadIds[i]
            );
        }
    }

    function twtPrecalcSquadTotalStatsAndModifiers(
        DraftSquadPlacement memory draftSquadPlacement
    )
        internal
        view
        returns (
            uint24 totalStats,
            uint24 damageModifiers,
            uint24 staminaModifiers
        )
    {
        // TODO: Get this 2 things in one call.
        (
            uint256 shadowcornOverseerClass,
            uint256 shadowcornOverseerRarity,

        ) = IShadowcornStatsFacet(LibExternalAddress.getShadowcornAddress())
                .getClassRarityAndStat(
                    draftSquadPlacement.shadowcornOverseerTokenId,
                    0
                );
        for (
            uint256 i = 0;
            i < draftSquadPlacement.amountOfDifferentClasses;
            ++i
        ) {
            (
                totalStats,
                damageModifiers,
                staminaModifiers
            ) = twtUpdateMinionSquadStatsAndModifiers(
                ShadowcornSquadInformation({
                    totalStats: totalStats,
                    damageModifiers: damageModifiers,
                    staminaModifiers: staminaModifiers,
                    minionAmounts: draftSquadPlacement.minionAmounts[i],
                    squadSize: draftSquadPlacement.squadSize,
                    minionStats: draftSquadPlacement.minionStats[i],
                    minionClass: draftSquadPlacement.minionClasses[i]
                }),
                draftSquadPlacement.regionId,
                shadowcornOverseerClass,
                shadowcornOverseerRarity
            );
        }
        totalStats += getShadowcornOverseerTotalStats(
            draftSquadPlacement.shadowcornOverseerTokenId
        );
        //convert minion stats to unicorn stats
        totalStats = totalStats * 8;
    }

    struct ShadowcornSquadInformation {
        uint24 totalStats;
        uint24 damageModifiers;
        uint24 staminaModifiers;
        uint24 minionAmounts;
        uint24 squadSize;
        uint8 minionClass;
        IMinionStats.MinionStats minionStats;
    }

    function twtUpdateMinionSquadStatsAndModifiers(
        // TODO: check that multiple structs are using the same attributes
        ShadowcornSquadInformation memory shadowcornSquadInformation,
        uint8 regionId,
        uint256 shadowcornOverseerClass,
        uint256 shadowcornOverseerRarity
    )
        internal
        view
        returns (
            uint24 updatedTotalStats,
            uint24 updatedDamageModifiers,
            uint24 updatedStaminaModifiers
        )
    {
        (
            uint24 minionTotalStats,
            uint24 minionTotalDamageModifiers,
            uint24 minionTotalStaminaModifiers
        ) = twtGetMinionTotalStatsAndModifiers(
                regionId,
                shadowcornSquadInformation.minionStats,
                shadowcornSquadInformation.minionClass,
                shadowcornOverseerClass,
                shadowcornOverseerRarity
            );

        updatedTotalStats =
            shadowcornSquadInformation.totalStats +
            (minionTotalStats * shadowcornSquadInformation.minionAmounts);
        updatedDamageModifiers =
            shadowcornSquadInformation.damageModifiers +
            ((minionTotalDamageModifiers *
                shadowcornSquadInformation.minionAmounts) /
                shadowcornSquadInformation.squadSize);
        updatedStaminaModifiers =
            shadowcornSquadInformation.staminaModifiers +
            ((minionTotalStaminaModifiers *
                shadowcornSquadInformation.minionAmounts) /
                shadowcornSquadInformation.squadSize);
    }

    function getShadowcornOverseerTotalStats(
        uint24 shadowcornOverseerTokenId
    ) private view returns (uint24 shadowcornOverseerTotalStats) {
        (
            uint256 might,
            uint256 wickedness,
            uint256 tenacity,
            uint256 cunning,
            uint256 arcana
        ) = IShadowcornStatsFacet(LibExternalAddress.getShadowcornAddress())
                .getStats(shadowcornOverseerTokenId);

        shadowcornOverseerTotalStats =
            (uint24(might + wickedness + tenacity + cunning + arcana) *
                LibTwTAdmin.twtGetOverseerStatsBonusForCurrentSeason()) /
            100;
    }

    function twtGetMinionTotalStatsAndModifiers(
        uint8 regionId,
        IMinionStats.MinionStats memory minionStats,
        uint8 minionClass,
        uint256 shadowcornOverseerClass,
        uint256 shadowcornOverseerRarity
    ) internal view returns (uint24, uint24, uint24) {
        (
            uint24 totalDamageModifiersAmount,
            uint24 totalStaminaModifiersAmount
        ) = LibTwTModifier.twtGetTotalModifiersAmountForMinion(
                minionClass,
                shadowcornOverseerClass,
                shadowcornOverseerRarity,
                regionId
            );

        // Sum all minion stats
        uint24 minionTotalStats = (
            uint24(
                minionStats.might +
                    minionStats.wickedness +
                    minionStats.tenacity +
                    minionStats.cunning +
                    minionStats.arcana
            )
        );

        return (
            minionTotalStats,
            totalDamageModifiersAmount,
            totalStaminaModifiersAmount
        );
    }

    function twtSetMaxSquadSizeBySeason(
        uint16 seasonId,
        uint24 maxSquadSize
    ) internal {
        twtShadowcornDefenseStorage().maxSquadSizeBySeason[
            seasonId
        ] = maxSquadSize;
    }

    function twtGetMaxSquadSizeBySeason(
        uint16 seasonId
    ) internal view returns (uint24) {
        return twtShadowcornDefenseStorage().maxSquadSizeBySeason[seasonId];
    }

    function twtGetShadowcornOpponentSquads(
        uint40[3] memory squadIds
    ) internal view returns (ShadowcornSquad[3] memory shadowcornSquads) {
        LibTwTShadowcornDefenseStorage
            storage sds = twtShadowcornDefenseStorage();
        uint256 length = squadIds.length;
        for (uint256 i = 0; i < length; ++i) {
            shadowcornSquads[i] = sds.squadById[squadIds[i]];
        }
    }

    function twtPreviewShadowcornSquadStats(
        uint8 regionId,
        uint24 shadowcornOverseerTokenId,
        uint24[5] memory poolIds,
        uint24[5] memory minionAmounts
    )
        internal
        view
        returns (
            uint24 shadowcornSquadStamina,
            uint24 shadowcornSquadBaseDamage,
            uint24 shadowcornSquadMinDamage,
            uint24 shadowcornSquadMaxDamage,
            uint24 damageFromModifiers
        )
    {
        IMinionStats.MinionStats memory emptyMinionStat = IMinionStats
            .MinionStats({
                might: 0,
                wickedness: 0,
                tenacity: 0,
                cunning: 0,
                arcana: 0
            });
        DraftSquadPlacement memory draftSquadPlacement = DraftSquadPlacement({
            regionId: regionId,
            shadowcornOverseerTokenId: shadowcornOverseerTokenId,
            minionStats: [
                emptyMinionStat,
                emptyMinionStat,
                emptyMinionStat,
                emptyMinionStat,
                emptyMinionStat
            ],
            minionClasses: new uint8[](5),
            minionAmounts: minionAmounts,
            squadSize: 0,
            seasonId: LibTwTSeason.twtGetCurrentSeasonId(),
            dominationPointsToAward: 0,
            amountOfDifferentClasses: 0
        });
        {
            // Cast pool ids to uint256
            uint256[] memory castedPoolIds = new uint256[](poolIds.length);
            for (uint256 i = 0; i < poolIds.length; ++i) {
                castedPoolIds[i] = uint256(poolIds[i]);
            }

            (
                IMinionStats.MinionStats[] memory minionStats,
                uint8[] memory minionClasses
            ) = IMinionStats(LibExternalAddress.getShadowcornItemsAddress())
                    .getMinionPoolStatsAndClassesMultiple(castedPoolIds);

            draftSquadPlacement.minionClasses = minionClasses;
            draftSquadPlacement.minionStats = [
                minionStats[0],
                minionStats[1],
                minionStats[2],
                minionStats[3],
                minionStats[4]
            ];
        }

        for (uint256 i = 0; i < minionAmounts.length; ++i) {
            if (poolIds[i] != 0) {
                ++draftSquadPlacement.amountOfDifferentClasses;
            }
            draftSquadPlacement.squadSize += minionAmounts[i];
        }

        (
            uint24 totalStats,
            uint24 damageModifiers,
            uint24 staminaModifiers
        ) = twtPrecalcSquadTotalStatsAndModifiers(draftSquadPlacement);

        shadowcornSquadStamina = uint24(
            (uint256(totalStats) * (10000 + uint256(staminaModifiers))) / 10000
        );
        shadowcornSquadBaseDamage = uint24(
            (uint256(totalStats) * (10000 + uint256(damageModifiers))) / 10000
        );

        damageFromModifiers = uint24(
            (uint256(totalStats) * uint256(damageModifiers)) / 10000
        );
        // We are estimating minimum damage, for that we estimate that the opponent will have 7x the damage this team has and rolls are of minimum luck.
        // Since shadowcornTeamDamage = Minion Damage * (1+((Minion Damage/Unicorn Damage)/10))
        // And this is before luck. Luck is a range between 0.75 and 1.25
        // minShadowcornTeamDamage = Minion Damage * (1 + (1/7)/10)) * 0.75
        // (1 + (1/7)/10)) * 0.75 = 0.76
        shadowcornSquadMinDamage = uint24(
            (uint256(shadowcornSquadBaseDamage) * 760) / 1000
        );
        // We are estimating maximum damage, for that we estimate that the opponent will have 1/7th the damage this team has and rolls are of maximum luck.
        // Since shadowcornTeamDamage = Minion Damage * (1+((Minion Damage/Unicorn Damage)/10))
        // And this is before luck. Luck is a range between 0.75 and 1.25
        // maxShadowcornTeamDamage = Minion Damage * (1 + (7/10)) * 1.25
        // (1 + (7/10)) * 1.25 = 2.125
        shadowcornSquadMaxDamage = uint24(
            (uint256(shadowcornSquadBaseDamage) * 2125) / 1000
        );
    }

    function twtGetTotalSquadsBySeasonAndRegion(
        uint16 seasonId,
        uint8 regionId
    ) internal view returns (uint256 totalSquads) {
        return LibTwTMinions.twtGetMinionSquadIdsLength(seasonId, regionId);
    }

    function twtSetMaxUnstakableMinionSquadsLimit(
        uint16 seasonId,
        uint24 limit
    ) internal {
        twtShadowcornDefenseStorage().maxUnstakableMinionSquadsLimit[
            seasonId
        ] = limit;
    }

    function twtGetMaxUnstakableMinionSquadsLimit(
        uint16 seasonId
    ) internal view returns (uint24 limit) {
        return
            twtShadowcornDefenseStorage().maxUnstakableMinionSquadsLimit[
                seasonId
            ];
    }

    // TODO: move to common repo
    function appendUintArrays(
        uint256[] memory a,
        uint256[] memory b
    ) internal pure returns (uint256[] memory result) {
        result = new uint256[](a.length + b.length);
        uint256 i;
        for (i = 0; i < a.length; ++i) {
            result[i] = a[i];
        }
        for (i = 0; i < b.length; ++i) {
            result[i + a.length] = b[i];
        }
        return result;
    }

    function appendUint24Arrays(
        uint24[] memory a,
        uint24[5] memory b
    ) internal pure returns (uint24[] memory result) {
        result = new uint24[](a.length + b.length);
        uint256 i;
        for (i = 0; i < a.length; ++i) {
            result[i] = a[i];
        }
        for (i = 0; i < b.length; ++i) {
            result[i + a.length] = b[i];
        }
        return result;
    }
}


// Chain: POLYGON - File: LibExternalAddress.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibExternalAddress { 
    bytes32 constant EXTERNAL_ADDRESS_STORAGE_POSITION =
        keccak256("CryptoUnicorns.ExternalAddress.Storage");
    struct ExternalAddressStorage {
        address shadowcornItemsAddress;
        address shadowcornAddress;
        address unicornAddress;
        address gameBankAddress;
        address deadWalletAddress;
        address unimAddress;
        address darkMarksAddress;
        address rbwAddress;
        address minionHatcheryAddress;
    }

    function externalAddressStorage() internal
        pure
        returns (ExternalAddressStorage storage ds)
    {
        bytes32 position = EXTERNAL_ADDRESS_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function getMinionHatcheryAddress() internal view returns (address) {
        return externalAddressStorage().minionHatcheryAddress;
    }

    function setMinionHatcheryAddress(address _address) internal {
        externalAddressStorage().minionHatcheryAddress = _address;
    }

    function getDarkMarksAddress() internal view returns (address) {
        return externalAddressStorage().darkMarksAddress;
    }

    function setDarkMarksAddress(address _address) internal {
        externalAddressStorage().darkMarksAddress = _address;
    }

    function getUNIMAddress() internal view returns (address) {
        return externalAddressStorage().unimAddress;
    }

    function setUNIMAddress(address _address) internal {
        externalAddressStorage().unimAddress = _address;
    }

    function getRBWAddress() internal view returns (address) {
        return externalAddressStorage().rbwAddress;
    }

    function setRBWAddress(address _address) internal {
        externalAddressStorage().rbwAddress = _address;
    }

    function getShadowcornItemsAddress() internal view returns (address) {
        return externalAddressStorage().shadowcornItemsAddress;
    }
    
    function setShadowcornItemsAddress(address _address) internal {
        externalAddressStorage().shadowcornItemsAddress = _address;
    }

    function getShadowcornAddress() internal view returns (address) {
        return externalAddressStorage().shadowcornAddress;
    }

    function setShadowcornAddress(address _address) internal {
        externalAddressStorage().shadowcornAddress = _address;
    }
    function getUnicornAddress() internal view returns(address) {
        return externalAddressStorage().unicornAddress;
    }
    function setUnicornAddress(address _address) internal {
        externalAddressStorage().unicornAddress = _address;
    }
    
    function getGameBankAddress() internal view returns (address) {
        return externalAddressStorage().gameBankAddress;
    }

    function setGameBankAddress(address _address) internal {
        externalAddressStorage().gameBankAddress = _address;
    }

    function getDeadWalletAddress() internal view returns (address) {
        return externalAddressStorage().deadWalletAddress;
    }

    function setDeadWalletAddress(address _address) internal {
        externalAddressStorage().deadWalletAddress = _address;
    }
}

// Chain: POLYGON - File: IMinionStats.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IMinionStats {
    function getMinionPoolStats(uint256 poolId) external view returns(MinionStats memory);
    function getMinionPoolStatsAndClassesMultiple(uint256[] memory poolIds) external view returns(MinionStats[] memory, uint8[] memory);
    struct MinionStats {
        uint256 might;
        uint256 wickedness;
        uint256 tenacity;
        uint256 cunning;
        uint256 arcana;
    }
}

// Chain: POLYGON - File: LibTwTModifier.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LibTwTSeason} from "LibTwTSeason.sol";
import {IMinionStats} from "IMinionStats.sol";
import {LibTwTShadowcornDefense} from "LibTwTShadowcornDefense.sol";
import {IUnicornStatCache} from "IUnicornStats.sol";


library LibTwTModifier {
    /// @notice Position to store the storage
    bytes32 private constant TWT_MODIFIER_STORAGE_POSITION =
        keccak256("CryptoUnicorns.TwT.Modifier.Storage");

    struct LibTwTModifierStorage {
        mapping(uint16 seasonId => mapping(uint8 regionId => TwTRegionModifier)) regionModifiersBySeason;
    }

    struct TwTRegionModifier {
        // Unicorn modifiers
        uint8[] affectedUnicornClasses;
        uint16[] affectedUnicornClassModifierPercentages; // Percentage amount. For example: 1700 = 17%
        bool affectMythicUnicorns;
        uint16 modifierPercentageForMythicUnicorns; // Percentage amount. For example: 1700 = 17%
        bool affectGenesisUnicorns;
        uint16 modifierPercentageForGenesisUnicorns; // Percentage amount. For example: 1700 = 17%

        // Minion/Shadowcorn modifiers
        uint8 affectedMinionClass;
        uint16 affectedMinionClassModifierPercentage; // Percentage amount. For example: 1700 = 17%
        uint8 affectedShadowcornRarity;
        uint16 affectedShadowcornRarityModifierPercentage; // Percentage amount. For example: 1700 = 17%
    }

    function twtGetRegionModifiersByCurrentSeason(uint8 regionId) internal view returns (TwTRegionModifier memory) {
        (,uint16 currentSeasonId) = LibTwTSeason.twtGetCurrentSeason();

        return twtModifierStorage().regionModifiersBySeason[currentSeasonId][regionId];
    }

    function twtGetModifiersForAllRegions(uint16 seasonId) internal view returns (LibTwTModifier.TwTRegionModifier[5] memory) {
        LibTwTModifier.TwTRegionModifier[5] memory regionModifiers;

        for (uint8 i = 0; i < 5; ++i) {
            regionModifiers[i] = twtModifierStorage().regionModifiersBySeason[seasonId][i+1];
        }

        return regionModifiers;
    }

    function twtGetRegionModifiersBySeason(uint16 seasonId, uint8 regionId) internal view returns (TwTRegionModifier memory) {
        return twtModifierStorage().regionModifiersBySeason[seasonId][regionId];
    }

    function twtSetRegionModifiersBySeason(uint16 seasonId, uint8 regionId, TwTRegionModifier memory regionModifier) internal {
        // Check if shadowcorn class is valid
        require(regionModifier.affectedMinionClass > 0 && regionModifier.affectedMinionClass <= 5, "M-001");

        // Check if all unicorn classes are valid. 0 is Heart, so that value is valid.
        for (uint8 i = 0; i < regionModifier.affectedUnicornClasses.length; ++i) {
            require(regionModifier.affectedUnicornClasses[i] <= 8, "M-002");
        }

        // Check if affectedShadowcornRarity is valid
        require(regionModifier.affectedShadowcornRarity <= 3, "M-003");

        twtModifierStorage().regionModifiersBySeason[seasonId][regionId] = regionModifier;
    }

    function twtClearAllRegionModifiers(uint16 seasonId) internal {
        for (uint8 i = 0 ; i < 5 ; ++i) {
            delete twtModifierStorage().regionModifiersBySeason[seasonId][i];
        }
    }

    // TODO: Move to UnicornDNA
    uint256 private constant HEART = 0;
    uint256 private constant RAINBOW = 1;
    uint256 private constant CLOUD = 2;
    uint256 private constant FLOWER = 3;
    uint256 private constant CANDY = 4;
    uint256 private constant OMNOM = 5;
    uint256 private constant CRYSTAL = 6;
    uint256 private constant MOON = 7;
    uint256 private constant STAR = 8;

    // TODO: Move to MH-common
    uint256 private constant FIRE = 1;
    uint256 private constant SLIME = 2;
    uint256 private constant VOLT = 3;
    uint256 private constant SOUL = 4;
    uint256 private constant NEBULA = 5;

    /*
     * 10% * number of RPS matches (up to 3)
     * Scores are boosted based on Unicorn/Class Matching between two Squads
     * - Unicorn Squads
     *   - RPS Matches against Volt = number of distinctive matches between a Cloud/Omnom Unicorn and Volt Minions
     *   - RPS Matches against Soul = number of distinctive matches between a Candy/Crystal Unicorn and Soul Minions
     *   - RPS Matches against Slime = number of distinctive matches between a Rainbow/Star Unicorn and Slime Minions
     *   - RPS Matches against Fire = number of distinctive matches between a Heart/Flower/Moon Unicorn and Fire Minions
     *   - No Unicorns have an advantage against Nebula Minions
     * - Minion Squads
     *   - RPS Matches against Candy/Crystal = number of distinctive matches between a Fire Minion and a Candy/Crystal Unicorn
     *   - RPS Matches against Rainbow/Star = number of distinctive matches between a Volt Minion and a Rainbow/Star Unicorn
     *   - RPS Matches against Heart/Flower/Moon = number of distinctive matches between a Soul Minion and a Heart/Flower/Moon Unicorn
     *   - RPS Matches against Cloud/Omnom = number of distinctive matches between a Slime Minion and Cloud/Omnom Unicorn
     *   - Nebula Minions don’t have an advantage against Unicorns
    */
    function getRPSModifier(IUnicornStatCache.Stats[] memory unicornsInformation, LibTwTShadowcornDefense.ShadowcornSquad memory shadowcornSquad) internal view returns(uint24 shadowcornTeamRPSBonus, uint24 unicornTeamRPSBonus) {
        uint24[] memory minionAmountsThatLostRPSAgainstUnicorns = new uint24[](shadowcornSquad.minionAmounts.length);
        uint24[] memory minionAmountsThatWonRPSAgainstUnicorns = new uint24[](shadowcornSquad.minionAmounts.length);

        LibTwTShadowcornDefense.ShadowcornSquad memory shadowcornSquadTemporaryForShadowcorns = shadowcornSquad;

        for(uint256 i = 0; i < unicornsInformation.length; ++i) {
            bool unicornAlreadyWonRPS = false;
            bool unicornAlreadyWasBeatenInRPS = false;
            for(uint256 j = 0; j < shadowcornSquad.minionClasses.length; ++j) {
                if(!unicornAlreadyWonRPS && (shadowcornSquad.minionAmounts[j] - minionAmountsThatLostRPSAgainstUnicorns[j]) > 0 && unicornWinsRPSMatch(unicornsInformation[i].class, shadowcornSquad.minionClasses[j])) {
                    unicornTeamRPSBonus += 1000;
                    minionAmountsThatLostRPSAgainstUnicorns[j]++;
                    unicornAlreadyWonRPS = true;
                }
                if(!unicornAlreadyWasBeatenInRPS && (shadowcornSquad.minionAmounts[j] - minionAmountsThatWonRPSAgainstUnicorns[j]) > 0 && minionWinsRPSMatch(unicornsInformation[i].class, shadowcornSquad.minionClasses[j])) {
                    shadowcornTeamRPSBonus += 1000;
                    minionAmountsThatWonRPSAgainstUnicorns[j]++;
                    unicornAlreadyWasBeatenInRPS = true;
                }
            }
        }
    }
    function unicornWinsRPSMatch(uint8 unicornClass, uint8 minionClass) internal pure returns(bool) {
        if(unicornClass == OMNOM || unicornClass == CLOUD) {
            return minionClass == VOLT;
        }
        if(unicornClass == CANDY || unicornClass == CRYSTAL) {
            return minionClass == SOUL;
        }
        if(unicornClass == RAINBOW || unicornClass == STAR) {
            return minionClass == SLIME;
        }
        if(unicornClass == HEART || unicornClass == FLOWER || unicornClass == MOON) {
            return minionClass == FIRE;
        }
        return false;
    }
    function minionWinsRPSMatch(uint8 unicornClass, uint8 minionClass) internal pure returns(bool) {
        if(minionClass == FIRE) {
            return unicornClass == CANDY || unicornClass == CRYSTAL;
        }
        if(minionClass == SLIME) {
            return unicornClass == OMNOM || unicornClass == CLOUD;
        }
        if(minionClass == VOLT) {
            return unicornClass == RAINBOW || unicornClass == STAR;
        }
        if(minionClass == SOUL) {
            return unicornClass == HEART || unicornClass == FLOWER || unicornClass == MOON;
        }
        return false;
    }


    function twtGetTotalModifiersAmountForMinion(uint8 minionClass, uint256 shadowcornOverseerClass, uint256 shadowcornOverseerRarity, uint8 regionId) internal view returns(uint24 totalDamageModifiersAmount, uint24 totalStaminaModifiersAmount ) {
        /*
         * Modifiers are percentages * 100.
         * for example: 1700 = 17%
         */
        // Get Shadowcorn modifier: % Modifier to Minion Stats based minion class and on Shadowcorn overseer (class and rarity)
        uint24 shadowcornModifier = twtGetShadowcornModifierForMinion(minionClass, shadowcornOverseerClass, shadowcornOverseerRarity);
        // Get region modifier to minion stats: % Modifier to selected stats based on Region combat occurs in
        uint24 regionModifier = twtGetRegionModifierForMinion(minionClass, regionId, shadowcornOverseerRarity);

        return (shadowcornModifier + regionModifier, shadowcornModifier);
    }

function twtGetTotalModifiersAmountForUnicorn(IUnicornStatCache.Stats memory unicornInfo, uint8 regionId) internal view returns(uint24) {
        uint24 genesisBonus = twtGetGenesisBonusForUnicorn(unicornInfo.origin);
        uint24 mythicBonus = twtGetMythicBonusForUnicorn(unicornInfo.mythicCount);
        uint24 regionBonus = twtGetRegionBonusForUnicorn(unicornInfo.class, regionId);
        return (genesisBonus + mythicBonus + regionBonus);
    }

    function twtGetGenesisBonusForUnicorn(bool isGenesis) internal pure returns(uint24){
        // Genesis Bonus	 +50% Stats Used
        if(isGenesis) {
            return 5000;
        }
        return 0;
    }

    function twtGetMythicBonusForUnicorn(uint8 amountOfMythicParts) internal view returns(uint24){
        // Single Mythic Bonus	 +5% Stats Used
        // Double Mythic Bonus	 +11% Stat Used
        // Triple Mythic Bonus	 +18% Stats Used
        // Quad Mythic Bonus	 +26% Stats Used
        // Epic Mythic Bonus	 +35% Stats Used
        // Legendary Mythic Bonus	 +45% Stats Used
        if(amountOfMythicParts == 1) {
            return 500;
        }
        if(amountOfMythicParts == 2) {
            return 1100;
        }
        if(amountOfMythicParts == 3) {
            return 1800;
        }
        if(amountOfMythicParts == 4) {
            return 2600;
        }
        if(amountOfMythicParts == 5) {
            return 3500;
        }
        if(amountOfMythicParts == 6) {
            return 4500;
        }
        return 0;
    }

    function twtGetShadowcornModifierForMinion(uint8 minionClass, uint256 shadowcornOverseerClass, uint256 shadowcornOverseerRarity) private pure returns(uint24) {
        uint24 modifierAmount = 0;

        if (shadowcornOverseerClass == uint256(minionClass)) {
            if(shadowcornOverseerRarity == 1) {
                modifierAmount = 2000;
            }
            if(shadowcornOverseerRarity == 2) {
                modifierAmount = 4000;
            }
            if(shadowcornOverseerRarity == 3) {
                modifierAmount = 6000;
            }
        }

        return modifierAmount;
    }

    function twtGetRegionModifierForMinion(uint8 minionClass, uint8 regionId, uint256 shadowcornRarityId) private view returns(uint24) {
        LibTwTModifier.TwTRegionModifier memory regionModifier = LibTwTModifier.twtGetRegionModifiersByCurrentSeason(regionId);

        uint24 modifierAmount = 0;

        if (regionModifier.affectedMinionClass == minionClass) {
            modifierAmount += regionModifier.affectedMinionClassModifierPercentage;
        }

        if (regionModifier.affectedShadowcornRarity == shadowcornRarityId) {
            modifierAmount += regionModifier.affectedShadowcornRarityModifierPercentage;
        }

        return modifierAmount;
    }

    function twtGetRegionBonusForUnicorn(uint8 unicornClass, uint8 regionId) internal view returns(uint24){
        // TODO: Implement region bonus for mythic (differ by mythicality?) and genesis unicorns
        LibTwTModifier.TwTRegionModifier memory regionModifier = LibTwTModifier.twtGetRegionModifiersByCurrentSeason(regionId);
        uint24 bonus = 0;
        for(uint256 i = 0; i < regionModifier.affectedUnicornClasses.length; ++i){
            if(regionModifier.affectedUnicornClasses[i] == unicornClass) {
                bonus += regionModifier.affectedUnicornClassModifierPercentages[i];
                break;
            }
        }
        return bonus;
    }

    function twtModifierStorage()
        internal
        pure
        returns (LibTwTModifierStorage storage lss)
    {
        bytes32 position = TWT_MODIFIER_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            lss.slot := position
        }
    }
}


// Chain: POLYGON - File: LibTwTSeason.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {LibEvents} from "LibEvents.sol";
import {LibTwTRewards} from "LibTwTRewards.sol";
import {LibTwTShadowcornDefense} from "LibTwTShadowcornDefense.sol";
import {LibTwTUnicornAttack} from "LibTwTUnicornAttack.sol";

library LibTwTSeason {
    /// @notice Position to store the storage
    bytes32 private constant TWT_SEASON_STORAGE_POSITION =
        keccak256("CryptoUnicorns.TwT.Season.Storage");

    enum TwTSeasonState {
        NONE, // 0
        UNSTARTED, // 1
        PRESEASON, // 2
        ACTIVE, // 3
        CLAIM_REMAINING_REWARDS, // 4
        CLOSED // 5
    }

    /// @notice DO NOT REORDER THIS STRUCT
    struct LibTwTSeasonStorage {
        uint16 currentSeasonId;
        uint16 seasonsCount;
        mapping(uint16 => TwTSeasonState) seasonIdToSeasonState;
    }

    /// @notice This function is used to create a season
    function twtCreateSeason() internal {
        LibTwTSeasonStorage storage lss = twtSeasonStorage();
        if (lss.currentSeasonId != 0) {
            require(
                twtValidateSeasonState(lss.seasonsCount, TwTSeasonState.CLOSED),
                "S-006"
            );
        }

        ++lss.seasonsCount;
        uint16 seasonId = lss.seasonsCount;

        lss.seasonIdToSeasonState[seasonId] = TwTSeasonState.UNSTARTED;

        emit LibEvents.TwTSeasonCreated(seasonId, msg.sender);
    }

    /// @notice Update season state
    /// @dev This function is used to update the season state. It will revert if the state is not valid (or equals to ACTIVE), or if the season does not exist.
    /// @param seasonId The season id
    /// @param newState The new state
    function twtUpdateSeasonState(
        uint16 seasonId,
        TwTSeasonState newState
    ) internal {
        LibTwTSeasonStorage storage lss = twtSeasonStorage();
        TwTSeasonState oldState = lss.seasonIdToSeasonState[seasonId];

        // Check if season exists
        require(
            oldState != TwTSeasonState.NONE,
            "S-005"
        );

        // Check new state is advancing the season's current state
        require(
            uint256(newState) == uint256(oldState) + 1,
            "S-004"
        );

        // Set season state
        lss.seasonIdToSeasonState[seasonId] = newState;

        emit LibEvents.TwTSeasonStateUpdated(
            seasonId,
            uint256(oldState),
            uint256(newState),
            msg.sender
        );
    }

    /// @notice Get season state
    /// @param seasonId The season id
    /// @return state The season state
    function twtGetSeasonStateById(
        uint16 seasonId
    ) internal view returns (TwTSeasonState state) {
        state = twtSeasonStorage().seasonIdToSeasonState[seasonId];
    }

    /// @notice Get current season
    /// @return state The current season state
    /// @return seasonId The current season id
    function twtGetCurrentSeason()
        internal
        view
        returns (TwTSeasonState state, uint16 seasonId)
    {
        LibTwTSeasonStorage storage lss = twtSeasonStorage();
        seasonId = lss.currentSeasonId;
        state = lss.seasonIdToSeasonState[seasonId];
    }

    /// @notice Get current season id
    /// @return seasonId The current season id
    function twtGetCurrentSeasonId() internal view returns (uint16 seasonId) {
        LibTwTSeasonStorage storage lss = twtSeasonStorage();
        seasonId = lss.currentSeasonId;
    }

    /// @notice Set current season by id
    /// @dev This function is used to set the current season. It will fail if the season does not exist.
    /// @param seasonId The season id
    function twtSetCurrentSeason(uint16 seasonId) internal {
        LibTwTSeasonStorage storage lss = twtSeasonStorage();
        TwTSeasonState seasonState = lss.seasonIdToSeasonState[seasonId];

        // Check if season exists
        require(
            seasonState != TwTSeasonState.NONE,
            "S-003"
        );

        uint16 oldSeasonId = lss.currentSeasonId;
        if (oldSeasonId != 0) {
            require(
                twtValidateSeasonState(oldSeasonId, TwTSeasonState.CLOSED),
                "S-002"
            );
        }

        // Set new season to active and save id
        lss.currentSeasonId = seasonId;

        emit LibEvents.TwTCurrentSeasonChanged(
            seasonId,
            oldSeasonId,
            msg.sender
        );
    }

    function enforceSeasonIsPreseasonOrActive(uint16 seasonId) internal view {
        require(
            twtSeasonStorage().seasonIdToSeasonState[seasonId] ==
                TwTSeasonState.PRESEASON ||
                twtSeasonStorage().seasonIdToSeasonState[seasonId] ==
                TwTSeasonState.ACTIVE,
            "S-001"
        );
    }

    /// @notice Get domination points for both factions by user
    /// @param user The user address
    /// @return shadowcornDominationPoints The domination points for shadowcorn for all 5 regions
    /// @return unicornDominationPoints The domination points for unicorn for all 5 regions
    function twtGetSeasonalDominationPointsByAccount(
        uint16 seasonId,
        address user
    )
        internal
        view
        returns (
            uint56[5] memory shadowcornDominationPoints,
            uint56[5] memory unicornDominationPoints
        )
    {
        for (uint8 i = 1; i < 6; ++i) {
            shadowcornDominationPoints[i - 1] = LibTwTRewards
                .twtGetShadowcornDominationPointsBySeasonRegionAccount(
                    seasonId,
                    i,
                    user
                );
            unicornDominationPoints[i - 1] = LibTwTRewards
                .twtGetUnicornDominationPointsBySeasonRegionAccount(
                    seasonId,
                    i,
                    user
                );
        }
    }

    /// @notice Get domination points for both factions for all regions
    /// @param seasonId The season id
    /// @return shadowcornDominationPoints The domination points for shadowcorn for all 5 regions
    /// @return unicornDominationPoints The domination points for unicorn for all 5 regions
    function twtGetSeasonalDominationPointsForAllRegions(
        uint16 seasonId
    )
        internal
        view
        returns (
            uint56[5] memory shadowcornDominationPoints,
            uint56[5] memory unicornDominationPoints
        )
    {
        for (uint8 i = 1; i < 6; ++i) {
            shadowcornDominationPoints[i - 1] = LibTwTRewards
                .twtGetShadowcornDominationPointsBySeasonRegion(seasonId, i);
            unicornDominationPoints[i - 1] = LibTwTRewards
                .twtGetUnicornDominationPointsBySeasonRegion(seasonId, i);
        }
    }

    /// @notice Get season rewards and status by season and region
    /// @param seasonId The season id
    /// @return totalSquads The total squads for all 5 regions
    /// @return totalBattles The total battles for all 5 regions
    /// @return rewards The rewards for all 5 regions
    function twtGetSeasonRewardsAndStatusBySeasonAndRegion(
        uint16 seasonId
    )
        internal
        view
        returns (
            uint256[5] memory totalSquads,
            uint256[5] memory totalBattles,
            LibTwTRewards.SeasonReward[][5] memory rewards
        )
    {
        for (uint8 i = 1; i < 6; ++i) {
            totalSquads[i - 1] = LibTwTShadowcornDefense
                .twtGetTotalSquadsBySeasonAndRegion(seasonId, i);
            totalBattles[i - 1] = LibTwTUnicornAttack
                .twtGetTotalBattlesBySeasonAndRegion(seasonId, i);

            LibTwTRewards.SeasonReward[] memory regionRewards = LibTwTRewards
                .twtGetSeasonRewardsForRegion(seasonId, i);
            rewards[i - 1] = new LibTwTRewards.SeasonReward[](
                regionRewards.length
            );

            for (uint256 j = 0; j < regionRewards.length; ++j) {
                rewards[i - 1][j] = regionRewards[j];
            }
        }
    }

    function twtValidateSeasonState(
        uint16 seasonId,
        TwTSeasonState state
    ) internal view returns (bool) {
        return twtSeasonStorage().seasonIdToSeasonState[seasonId] == state;
    }

    function twtSeasonStorage()
        internal
        pure
        returns (LibTwTSeasonStorage storage lss)
    {
        bytes32 position = TWT_SEASON_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            lss.slot := position
        }
    }
}


// Chain: POLYGON - File: LibEvents.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IDiamondCut} from "IDiamondCut.sol";
import {LibTwTRewards} from "LibTwTRewards.sol";
import {LibTwTUnicornAttack} from "LibTwTUnicornAttack.sol";
import {LibGasReturner} from "LibGasReturner.sol";

library LibEvents {
    event DiamondCut(
        IDiamondCut.FacetCut[] _diamondCut,
        address _init,
        bytes _calldata
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // TwT events
    event TwTPermissionChanged(
        address indexed user,
        bool wasAdmin,
        bool isAdmin
    );
    event TwTCurrentSeasonChanged(
        uint16 indexed newCurrentSeasonId,
        uint16 indexed oldCurrentSeasonId,
        address indexed admin
    );
    event TwTSeasonStateUpdated(
        uint16 indexed seasonId,
        uint256 oldSeasonState,
        uint256 newSeasonState,
        address indexed admin
    );

    // TwT Combat events

    event TwTShadowcornDefendedRegion(
        address indexed user,
        uint16 indexed seasonId,
        uint8 indexed regionId,
        uint24 shadowcornOverseerTokenId,
        uint24[5] poolIds,
        uint24[5] minionAmounts,
        uint24 batchQuantity,
        uint256 stakedAtTime,
        uint40 squadId
    );

    event TwTBeginUnicornAttackRegion(
        uint56 indexed matchId,
        uint256 indexed vrfReqId,
        address indexed user,
        uint8 regionId,
        uint64[3] tokenIds,
        uint40 shadowcornSquadId
    );
    event TwTFinishUnicornAttackRegion(
        uint56 indexed matchId,
        uint256 indexed vrfReqId,
        address indexed attacker,
        LibTwTUnicornAttack.Match resultingMatch,
        uint24 unicornTeamDamageDealt,
        uint24 shadowcornTeamDamageDealt
    );

    // TwT Season Admin events
    event TwTSeasonCreated(uint16 indexed seasonId, address indexed admin);
    event TwTSeasonScheduleChanged(
        uint16 indexed seasonId,
        uint256 startStakeTime,
        uint256 startAttackTime
    );
    event TwTSeasonRewardsChanged(
        uint16 indexed seasonId,
        LibTwTRewards.SeasonReward[] rewardsBefore,
        LibTwTRewards.SeasonReward[] rewardsAfter
    );

    // TwT Minion pool
    event TwTMinionPoolIdsChanged(uint24[] oldPools, uint24[] newPools);

    // Twt Rewards
    event TwTRewardsChanged(uint16 indexed seasonId, uint8 indexed regionId);

    /// Emitted when VRF updates a player's RNG seed
    event TwTRNGSeedChanged(
        address indexed unicornPlayer,
        uint256 indexed newSeed,
        uint256 indexed oldSeed
    );

    event TwTBegunNewWave(
        uint256 newWaveId,
        uint256 prevWaveTime,
        uint256 newWaveTime
    );

    event TwTDamageCalculationExtraInfo(
        LibTwTUnicornAttack.DamageCalculationExtraInfo extraInfo
    );

    event TwTBatchAddedShadowcornStakingPts(
        address indexed player,
        uint16 indexed seasonId,
        uint8 indexed regionId,
        uint256 waveId,
        uint40[] minionSquadIds,
        uint56 amountPerSquad,
        uint56 totalAmount
    );

    event TwTAddedShadowcornCombatPts(
        address indexed player,
        uint16 indexed seasonId,
        uint8 indexed regionId,
        uint256 waveId,
        uint40 minionSquadId,
        uint56 amount
    );

    event TwTAddedUnicornCombatPts(
        address indexed player,
        uint16 indexed seasonId,
        uint8 indexed regionId,
        uint256 waveId,
        uint56 amount
    );

    event TwTClaimedUnicornRewards(
        address indexed player,
        uint16 indexed seasonId,
        uint8 indexed regionId,
        uint256[] playerRewards
    );

    event TwTClaimedShadowcornRewards(
        address indexed player,
        uint16 indexed seasonId,
        uint8 indexed regionId,
        uint256[] playerRewards
    );

    event TwTFactionControlDeclared(
        uint16 indexed seasonId,
        uint8 indexed regionId,
        uint256 waveId,
        LibTwTRewards.FactionType indexed factionId
    );

    event TwTClaimableRewardsUpdated(
        uint16 indexed seasonId,
        uint8 indexed regionId,
        uint256 indexed waveId,
        uint256[] claimableShadowcornRewards,
        uint256[] claimableUnicornRewards
    );

    event TwtBatchShadowcornSquadsUnstaked(
        address indexed player,
        uint16 indexed seasonId,
        uint8 indexed regionId,
        uint40[] minionSquadIds,
        uint256 unstakedAtTime
    );

    // Gas returner
    event GasReturnerMaxGasReturnedPerTransactionChanged(
        uint256 oldMaxGasReturnedPerTransaction,
        uint256 newMaxGasReturnedPerTransaction,
        address indexed admin
    );

    event GasReturnedToUser(
        uint256 amountReturned,
        uint256 txPrice,
        uint256 gasSpent,
        address indexed user,
        bool indexed success,
        LibGasReturner.GasReturnerTransactionType indexed transactionType
    );

    // Unicorn Rescuer
    event TwTUnicornReturned(
        uint256 vrfRequestId,
        uint256 indexed matchId,
        uint256 indexed unicornTokenId,
        address indexed player
    );

    event TwTUnicornReturnSkipped(
        uint256 vrfRequestId,
        uint256 indexed matchId,
        uint256 indexed unicornTokenId,
        address indexed currentOwner
    );
}


// Chain: POLYGON - File: IDiamondCut.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Adapted from the Diamond 3 reference implementation by Nick Mudge:
// https://github.com/mudgen/diamond-3-hardhat

interface IDiamondCut {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }
    // Add=0, Replace=1, Remove=2

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;
}


// Chain: POLYGON - File: LibTwTRewards.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {LibUnicornQueue} from "LibUnicornQueue.sol";
import {LibMinionQueue} from "LibMinionQueue.sol";
import {LibEvents} from "LibEvents.sol";
import {LibComponent} from "LibComponent.sol";
import {LibTwTWave} from "LibTwTWave.sol";
import {IERC1155} from "ERC1155.sol";
import {IERC20} from "IERC20.sol";
import {IUNIMControllerFacet} from "IUNIMControllerFacet.sol";
import {IDarkMarksControllerFacet} from "IDarkMarksControllerFacet.sol";
import {LibExternalAddress} from "LibExternalAddress.sol";
import {LibTwTSeason} from "LibTwTSeason.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external returns (bool);
}

interface IERC1155Mintable is IERC1155 {
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
}

library LibTwTRewards {
    /// @notice Position to store the storage
    bytes32 private constant TWT_REWARDS_STORAGE_POSITION =
        keccak256("CryptoUnicorns.TwT.Rewards.Storage");

    using LibUnicornQueue for LibUnicornQueue.QueueStorage;
    using LibMinionQueue for LibMinionQueue.QueueStorage;

    /// @notice DO NOT REORDER THIS STRUCT
    struct LibTwTRewardsStorage {
        mapping(uint16 seasonId => mapping(uint8 regionId => SeasonReward[] rewards)) regionRewards; // Region-specific rewards
        mapping(uint16 seasonId => mapping(uint8 regionId => mapping(uint256 waveId => SeasonReward[] rewards))) waveRewards; // Region-specific daily rewards
        mapping(uint16 seasonId => mapping(uint8 regionId => mapping(uint256 waveId => FactionType faction))) factionControlMap; // Region-specific faction control mapping
        mapping(uint16 seasonId => mapping(uint8 regionId => LibUnicornQueue.QueueStorage)) unicornQueue; // Region-specific unicorn reward queue
        mapping(uint16 seasonId => mapping(uint8 regionId => LibMinionQueue.QueueStorage)) minionQueue; // Region-specific minion reward queue
        mapping(uint16 seasonId => mapping(uint8 regionId => uint56 dominationPoints)) shadowcornDominationPointsBySeasonRegion; // Region-specific domination points for shadowcorns
        mapping(uint16 seasonId => mapping(uint8 regionId => uint56 dominationPoints)) unicornDominationPointsBySeasonRegion; // Region-specific domination points for unicorns
        mapping(uint16 seasonId => mapping(uint8 regionId => mapping(address account => uint56 dominationPoints))) shadowcornDominationPointsBySeasonRegionAccount; // Account-specific domination points for shadowcorns
        mapping(uint16 seasonId => mapping(uint8 regionId => mapping(address account => uint56 dominationPoints))) unicornDominationPointsBySeasonRegionAccount; // Account-specific domination points for unicorns
    }

    struct SeasonReward {
        LibComponent.Component component; // uint256 amount; uint128 assetType; uint128 poolId; address asset;
        uint256 shadowcornBaseAmount; //  SCs always get this `amount`
        uint256 shadowcornControlAmount; //  Extra `amount` for each controlled region
        uint256 unicornBaseAmount; //  Unis always get this `amount`
        uint256 unicornControlAmount; //  Extra `amount` for each controlled region
        TransferType transferType; //  MINT_BURN, or TRANSFER
        uint256 claimableShadowcornRewards; //  Amount of rewards that can be claimed by shadowcorns
        uint256 claimableUnicornRewards; //  Amount of rewards that can be claimed by unicorns
    }

    enum TransferType {
        NONE,
        MINT_BURN,
        TRANSFER
    }

    enum FactionType {
        NONE,
        SHADOWCORN,
        UNICORN
    }

    /// @notice Add a reward for a season and region
    /// @param seasonId The season id
    /// @param regionId The region id
    /// @param component The component to reward (from LibComponent)
    /// @param splits The percents to split the reward between shadowcorn and unicorn
    /// @param transferType The type of transfer to use for the reward
    function twtAddSeasonReward(
        uint16 seasonId,
        uint8 regionId,
        LibComponent.Component memory component,
        uint256[] memory splits, // [shadowcornBaseAmount, shadowcornControlAmount, unicornBaseAmount, unicornControlAmount]
        TransferType transferType
    ) internal {
        require(
            splits.length == 4,
            "R-022"
        );

        require(
            splits[0] + splits[1] <= component.amount,
            "R-021"
        );
        require(
            splits[2] + splits[3] <= component.amount,
            "R-020"
        );
        require(
            splits[0] + splits[1] + splits[2] <= component.amount,
            "R-019"
        );
        require(
            splits[0] + splits[2] + splits[3] <= component.amount,
            "R-018"
        );

        enforceRegionIdIsValid(regionId);

        // initialize the daily rewards queue for the region if not initialized
        LibUnicornQueue.QueueStorage storage unicornQueue = twtRewardsStorage()
            .unicornQueue[seasonId][regionId];

        LibMinionQueue.QueueStorage storage minionQueue = twtRewardsStorage()
            .minionQueue[seasonId][regionId];

        if (!unicornQueue.isInitialized()) {
            unicornQueue.initialize();
        }

        if (!minionQueue.isInitialized()) {
            minionQueue.initialize();
        }

        twtRewardsStorage().regionRewards[seasonId][regionId].push(
            SeasonReward({
                component: component,
                shadowcornBaseAmount: splits[0],
                shadowcornControlAmount: splits[1],
                unicornBaseAmount: splits[2],
                unicornControlAmount: splits[3],
                transferType: transferType,
                claimableShadowcornRewards: 0,
                claimableUnicornRewards: 0
            })
        );
    }

    /// @notice Clear all rewards for a season and region
    /// @param seasonId The season id
    /// @param regionId The region id
    function twtClearSeasonRewards(uint16 seasonId, uint8 regionId) internal {
        enforceRegionIdIsValid(regionId);
        delete twtRewardsStorage().regionRewards[seasonId][regionId];
    }

    /// @notice Get all rewards for a season and region
    /// @param seasonId The season id
    /// @param regionId The region id
    /// @return rewards An array of rewards
    function twtGetSeasonRewardsForRegion(
        uint16 seasonId,
        uint8 regionId
    ) internal view returns (SeasonReward[] memory rewards) {
        enforceRegionIdIsValid(regionId);
        rewards = twtRewardsStorage().regionRewards[seasonId][regionId];
    }

    /// @notice Get all rewards for a season for all regions
    /// @param seasonId The season id
    /// @return rewards An array of rewards for each region
    function twtGetSeasonRewards(
        uint16 seasonId
    ) internal view returns (SeasonReward[][5] memory rewards) {
        mapping(uint8 => SeasonReward[])
            storage seasonRewards = twtRewardsStorage().regionRewards[seasonId];
        for (uint8 i = 0; i < 5; ++i) {
            rewards[i] = seasonRewards[i + 1];
        }
    }

    function twtAddUnicornCombatPts(
        uint16 seasonId,
        uint8 regionId,
        uint56 dominationPoints,
        address user
    ) internal {
        // require that the season and region are valid
        enforceRegionIdIsValid(regionId);

        // require that the queue for season and region id is initialized
        require(
            twtIsUnicornQueueInitialized(seasonId, regionId),
            "R-017"
        );

        // begin the next wave if the current wave is over
        uint256 waveId = twtBeginNextWaveIfCurrentIsOver(seasonId, regionId);

        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];
        if (unicornQueue.waveIdExistsInQueue(waveId)) {
            unicornQueue.addToWavePts(waveId, dominationPoints, user);
        } else {
            unicornQueue.enqueue(waveId, dominationPoints, user);
        }

        // add domination points to the region
        ltrs.unicornDominationPointsBySeasonRegion[seasonId][
            regionId
        ] += dominationPoints;

        // add domination points to the account
        ltrs.unicornDominationPointsBySeasonRegionAccount[seasonId][regionId][
            user
        ] += dominationPoints;

        emit LibEvents.TwTAddedUnicornCombatPts(
            user,
            seasonId,
            regionId,
            waveId,
            dominationPoints
        );
    }

    function twtBatchAddShadowcornStakingPts(
        uint16 seasonId,
        uint8 regionId,
        uint40[] memory minionSquadIds,
        uint56 stakingPts,
        address user
    ) internal {
        (
            LibMinionQueue.QueueStorage storage minionQueue,
            uint256 waveId
        ) = checkWaveAndEnqueueToMinionQueueIfNecessary(seasonId, regionId);
        for (uint256 i = 0; i < minionSquadIds.length; ++i) {
            minionQueue.addToWaveStakingPts(
                waveId,
                stakingPts,
                minionSquadIds[i],
                user
            );
        }
        uint56 totalStakingPtsAdded = stakingPts *
            uint56(minionSquadIds.length);
        updateGlobalMappingsForMinionStakingPts(
            seasonId,
            regionId,
            totalStakingPtsAdded,
            user
        );

        emit LibEvents.TwTBatchAddedShadowcornStakingPts(
            user,
            seasonId,
            regionId,
            waveId,
            minionSquadIds,
            stakingPts,
            totalStakingPtsAdded
        );
    }

    function checkWaveAndEnqueueToMinionQueueIfNecessary(
        uint16 seasonId,
        uint8 regionId
    )
        private
        returns (
            LibMinionQueue.QueueStorage storage minionQueue,
            uint256 waveId
        )
    {
        // require that the season and region are valid
        enforceRegionIdIsValid(regionId);

        // require that the queue for season and region id is initialized
        require(
            twtIsMinionQueueInitialized(seasonId, regionId),
            "R-016"
        );

        // begin the next wave if the current wave is over
        waveId = twtBeginNextWaveIfCurrentIsOver(seasonId, regionId);

        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        minionQueue = ltrs.minionQueue[seasonId][regionId];
        if (!minionQueue.waveIdExistsInQueue(waveId)) {
            minionQueue.enqueue(waveId);
        }
    }

    function updateGlobalMappingsForMinionStakingPts(
        uint16 seasonId,
        uint8 regionId,
        uint56 stakingPts,
        address user
    ) private {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        // add domination points to the region
        ltrs.shadowcornDominationPointsBySeasonRegion[seasonId][
            regionId
        ] += stakingPts;

        // add domination points to the account
        ltrs.shadowcornDominationPointsBySeasonRegionAccount[seasonId][
            regionId
        ][user] += stakingPts;
    }

    function twtAddShadowcornCombatPts(
        uint16 seasonId,
        uint8 regionId,
        uint40 minionSquadId,
        uint56 combatPts,
        address user
    ) internal {
        // require that the season and region are valid
        enforceRegionIdIsValid(regionId);

        // require that the queue for season and region id is initialized
        require(
            twtIsMinionQueueInitialized(seasonId, regionId),
            "R-015"
        );

        // begin the next wave if the current wave is over
        uint256 waveId = twtBeginNextWaveIfCurrentIsOver(seasonId, regionId);

        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibMinionQueue.QueueStorage storage minionQueue = ltrs.minionQueue[
            seasonId
        ][regionId];
        if (!minionQueue.waveIdExistsInQueue(waveId)) {
            minionQueue.enqueue(waveId);
        }
        minionQueue.addToWaveCombatPts(waveId, minionSquadId, combatPts);

        // add domination points to the region
        ltrs.shadowcornDominationPointsBySeasonRegion[seasonId][
            regionId
        ] += combatPts;

        // add domination points to the account
        ltrs.shadowcornDominationPointsBySeasonRegionAccount[seasonId][
            regionId
        ][user] += combatPts;

        emit LibEvents.TwTAddedShadowcornCombatPts(
            user,
            seasonId,
            regionId,
            waveId,
            minionSquadId,
            combatPts
        );
    }

    // TODO: test claim unicorn rewards function
    function twtClaimUnicornRewards(
        uint16 seasonId,
        uint8 regionId,
        address player
    ) internal {
        require(
            LibTwTSeason.twtValidateSeasonState(
                seasonId,
                LibTwTSeason.TwTSeasonState.ACTIVE
            ) ||
                LibTwTSeason.twtValidateSeasonState(
                    seasonId,
                    LibTwTSeason.TwTSeasonState.CLAIM_REMAINING_REWARDS
                ),
            "R-014"
        );
        // require that the season and region are valid
        enforceRegionIdIsValid(regionId);
        // // require that the queue for season and region id is initialized
        require(
            twtIsUnicornQueueInitialized(seasonId, regionId),
            "R-013"
        );
        // // begin the next wave if the current wave is over
        uint256 waveId = twtBeginNextWaveIfCurrentIsOver(seasonId, regionId);
        // // get the rewards to be claimed
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        uint256[] memory playerRewards = twtGetUnicornPlayerRewards(
            seasonId,
            regionId,
            player
        );
        SeasonReward[] memory regionRewards = ltrs.regionRewards[seasonId][
            regionId
        ];
        require(
            playerRewards.length == regionRewards.length,
            "R-012"
        );

        if (checkNonZeroUintArray(playerRewards)) {
            // reduce unicorn claimable rewards from each wave
            twtReduceClaimableRewards(seasonId, regionId, player, false);
            // remove unicorn wave pts
            twtRemoveUnicornWavePts(seasonId, regionId, player);
            // reward distribution
            twtDistributeRewards(
                seasonId,
                regionId,
                waveId,
                playerRewards,
                player
            );
            emit LibEvents.TwTClaimedUnicornRewards(
                player,
                seasonId,
                regionId,
                playerRewards
            );
        }
    }

    function twtDistributeRewards(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId,
        uint256[] memory playerRewards,
        address player
    ) internal {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        // SeasonReward[] memory waveRewards = ltrs.waveRewards[seasonId][
        //     regionId
        // ][waveId];
        SeasonReward[] memory regionRewards = ltrs.regionRewards[seasonId][
            regionId
        ];

        // reward distribution
        for (uint256 i = 0; i < playerRewards.length; ++i) {
            if (playerRewards[i] > 0) {
                if (regionRewards[i].component.assetType == 20) {
                    if (
                        regionRewards[i].transferType == TransferType.MINT_BURN
                    ) {
                        // mint erc20 tokens
                        if (
                            regionRewards[i].component.asset ==
                            LibExternalAddress.getUNIMAddress()
                        ) {
                            IUNIMControllerFacet(
                                LibExternalAddress.getGameBankAddress()
                            ).mintUNIM(player, playerRewards[i]);
                        } else if (
                            regionRewards[i].component.asset ==
                            LibExternalAddress.getDarkMarksAddress()
                        ) {
                            IDarkMarksControllerFacet(
                                LibExternalAddress.getGameBankAddress()
                            ).mintDarkMarks(player, playerRewards[i]);
                        } else {
                            IERC20Mintable(regionRewards[i].component.asset)
                                .mint(player, playerRewards[i]);
                        }
                    } else if (
                        (regionRewards[i].transferType == TransferType.TRANSFER)
                    ) {
                        // transfer erc20 tokens
                        IERC20Mintable(regionRewards[i].component.asset)
                            .transfer(player, playerRewards[i]);
                    }
                } else if (regionRewards[i].component.assetType == 1155) {
                    if (
                        regionRewards[i].transferType == TransferType.MINT_BURN
                    ) {
                        // mint erc1155 tokens
                        IERC1155Mintable(regionRewards[i].component.asset).mint(
                            player,
                            regionRewards[i].component.poolId,
                            playerRewards[i],
                            ""
                        );
                    } else if (
                        regionRewards[i].transferType == TransferType.TRANSFER
                    ) {
                        // transfer erc1155 tokens
                        IERC1155Mintable(regionRewards[i].component.asset)
                            .safeTransferFrom(
                                address(this),
                                player,
                                regionRewards[i].component.poolId,
                                playerRewards[i],
                                ""
                            );
                    }
                } else {
                    revert("R-023");
                }
            }
        }
    }

    // TODO: test this function
    function twtClaimShadowcornRewards(
        uint16 seasonId,
        uint8 regionId,
        address player
    ) internal {
        // require that the season state is valid
        require(
            LibTwTSeason.twtValidateSeasonState(
                seasonId,
                LibTwTSeason.TwTSeasonState.ACTIVE
            ) ||
                LibTwTSeason.twtValidateSeasonState(
                    seasonId,
                    LibTwTSeason.TwTSeasonState.CLAIM_REMAINING_REWARDS
                ),
            "R-011"
        );
        // require that the season and region are valid
        enforceRegionIdIsValid(regionId);
        // require that the queue for season and region id is initialized
        require(
            twtIsMinionQueueInitialized(seasonId, regionId),
            "R-010"
        );

        // begin the next wave if the current wave is over
        uint256 waveId = twtBeginNextWaveIfCurrentIsOver(seasonId, regionId);

        // get the rewards to be claimed
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();

        uint256[] memory playerRewards = twtGetShadowcornPlayerRewards(
            seasonId,
            regionId,
            player
        );

        SeasonReward[] memory regionRewards = ltrs.regionRewards[seasonId][
            regionId
        ];

        require(
            playerRewards.length == regionRewards.length,
            "R-009"
        );

        if (checkNonZeroUintArray(playerRewards)) {
            // reduce shadowcorn claimable rewards from each wave
            twtReduceClaimableRewards(seasonId, regionId, player, true);

            // remove minion wave pts
            twtRemoveMinionWavePts(seasonId, regionId, player);

            // reward distribution
            twtDistributeRewards(
                seasonId,
                regionId,
                waveId,
                playerRewards,
                player
            );

            emit LibEvents.TwTClaimedShadowcornRewards(
                player,
                seasonId,
                regionId,
                playerRewards
            );
        }
    }

    function twtReduceClaimableRewards(
        uint16 seasonId,
        uint8 regionId,
        address player,
        bool isShadowcorn
    ) internal {
        (uint256 startWaveId, uint256 endWaveId, ) = twtGetWaveIdRange();

        // loop from today's wave id back to the 6 waves before
        for (
            uint256 waveCounter = startWaveId;
            waveCounter > endWaveId;
            waveCounter--
        ) {
            twtReduceClaimableRewardsByWaveId(
                seasonId,
                regionId,
                waveCounter,
                player,
                isShadowcorn
            );
        }
    }

    function twtReduceClaimableRewardsByWaveId(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId,
        address player,
        bool isShadowcorn
    ) internal {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        SeasonReward[] storage waveRewards = ltrs.waveRewards[seasonId][
            regionId
        ][waveId];
        SeasonReward[] storage regionRewards = ltrs.regionRewards[seasonId][
            regionId
        ];

        uint256[] memory playerWaveRewards = new uint256[](waveRewards.length);

        // calculate rewards by wave id
        if (isShadowcorn) {
            playerWaveRewards = twtShadowcornPlayerRewardsByWaveId(
                seasonId,
                regionId,
                waveId,
                player
            );
            for (uint256 i = 0; i < waveRewards.length; ++i) {
                require(
                    waveRewards[i].claimableShadowcornRewards >=
                        playerWaveRewards[i],
                    "R-008"
                );

                require(
                    regionRewards[i].claimableShadowcornRewards >=
                        playerWaveRewards[i],
                    "R-007"
                );

                waveRewards[i].claimableShadowcornRewards -= playerWaveRewards[
                    i
                ];

                regionRewards[i]
                    .claimableShadowcornRewards -= playerWaveRewards[i];
            }
        } else {
            playerWaveRewards = twtUnicornPlayerRewardsByWaveId(
                seasonId,
                regionId,
                waveId,
                player
            );
            for (uint256 i = 0; i < waveRewards.length; ++i) {
                require(
                    regionRewards[i].claimableUnicornRewards >=
                        playerWaveRewards[i],
                    "R-006"
                );
                require(
                    waveRewards[i].claimableUnicornRewards >=
                        playerWaveRewards[i],
                    "R-005"
                );
                waveRewards[i].claimableUnicornRewards -= playerWaveRewards[i];
                regionRewards[i].claimableUnicornRewards -= playerWaveRewards[
                    i
                ];
            }
        }
    }

    function twtRemoveMinionWavePts(
        uint16 seasonId,
        uint8 regionId,
        address user
    ) internal {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibMinionQueue.QueueStorage storage minionQueue = ltrs.minionQueue[
            seasonId
        ][regionId];

        (uint256 startWaveId, uint256 endWaveId, ) = twtGetWaveIdRange();

        // loop from today's wave id back to the 6 waves before
        for (
            uint256 waveCounter = startWaveId;
            waveCounter > endWaveId;
            waveCounter--
        ) {
            minionQueue.removeMinionSquadStakingPts(waveCounter, user);
            minionQueue.removeMinionSquadCombatPts(waveCounter, user);
            minionQueue.removeMinionSquadsByAccountAndWaveId(waveCounter, user);
        }
    }

    function twtRemoveUnicornWavePts(
        uint16 seasonId,
        uint8 regionId,
        address user
    ) internal {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];

        (
            uint256 startWaveId,
            uint256 endWaveId,
            uint256 currentWaveCount
        ) = twtGetWaveIdRange();

        // loop from today's wave id back to the 6 waves before
        for (
            uint256 waveCounter = startWaveId;
            waveCounter > endWaveId;
            waveCounter--
        ) {
            unicornQueue.removeAccountWavePts(waveCounter, user);
        }
    }

    function twtGetShadowcornPlayerRewards(
        uint16 seasonId,
        uint8 regionId,
        address player
    ) internal view returns (uint256[] memory playerRewards) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        SeasonReward[] memory regionRewards = ltrs.regionRewards[seasonId][
            regionId
        ];

        (
            uint256 startWaveId,
            uint256 endWaveId,
            uint256 currentWaveCount
        ) = twtGetWaveIdRange();

        playerRewards = new uint256[](regionRewards.length);
        uint256[] memory playerWaveRewards = new uint256[](
            regionRewards.length
        );

        // loop from today's wave id back to the 6 waves before
        for (
            uint256 waveCounter = startWaveId;
            waveCounter > endWaveId;
            waveCounter--
        ) {
            // calculate rewards by wave id
            playerWaveRewards = twtShadowcornPlayerRewardsByWaveId(
                seasonId,
                regionId,
                waveCounter,
                player
            );
            require(
                playerWaveRewards.length == regionRewards.length,
                "R-004"
            );

            for (uint256 j = 0; j < regionRewards.length; ++j) {
                playerRewards[j] = playerRewards[j] + playerWaveRewards[j];
            }
        }
    }

    function twtBeginNextWaveIfCurrentIsOver(
        uint16 seasonId,
        uint8 regionId
    ) internal returns (uint256 waveId) {
        if (LibTwTWave.twtIsWaveExpired()) {
            for (uint8 i = 1; i < 6; ++i) {
                twtDeclareFactionControl(seasonId, i);
            }

            waveId = LibTwTWave.twtBeginNewWave();

            for (uint8 i = 1; i < 6; ++i) {
                twtSetDailyWaveRewards(seasonId, i, waveId);
            }
        } else {
            (waveId, ) = LibTwTWave.twtCalculateCurrentWaveData();
        }
        return waveId;
    }

    function twtDeclareFactionControl(
        uint16 seasonId,
        uint8 regionId
    ) internal {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        // find last wave id
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];
        LibMinionQueue.QueueStorage storage minionQueue = ltrs.minionQueue[
            seasonId
        ][regionId];

        // find unicorn and shadowcorn last wave id
        (uint256 unicornLastWaveId, ) = unicornQueue.peekLast();
        (uint256 minionLastWaveId, , ) = minionQueue.peekLast();

        uint256 lastWaveId = unicornLastWaveId > minionLastWaveId
            ? unicornLastWaveId
            : minionLastWaveId;

        if (
            ltrs.factionControlMap[seasonId][regionId][lastWaveId] ==
            FactionType.NONE
        ) {
            uint56 shadowcornPts = minionQueue.getStakingPtsByWaveId(
                lastWaveId
            ) + minionQueue.getCombatPtsByWaveId(lastWaveId);
            uint56 unicornPts = unicornQueue.twtGetUnicornPtsByWaveId(
                lastWaveId
            );

            FactionType controllingFactionType = unicornPts >= shadowcornPts
                ? FactionType.UNICORN
                : FactionType.SHADOWCORN;

            // set faction control
            twtSetFactionControl(
                seasonId,
                regionId,
                lastWaveId,
                controllingFactionType
            );
        }
    }

    function twtInitializeWaveCount() internal {
        LibTwTWave.LibTwTWaveStorage storage ltws = LibTwTWave.twtWaveStorage();
        ltws.waveCount = ltws.waveCount + 1;
        ltws.waveTime = LibTwTWave.twtCalculateMidnightUTCTime();

        // set the daily wave rewards for the current wave
        for (uint8 i = 1; i < 6; ++i) {
            twtSetDailyWaveRewards(1, i, ltws.waveCount);
        }
        // setting initialized to true
        ltws.initialized = true;
    }

    function twtSetDailyWaveRewards(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId
    ) internal {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        SeasonReward[] memory regionRewards = ltrs.regionRewards[seasonId][
            regionId
        ];
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];

        LibMinionQueue.QueueStorage storage minionQueue = ltrs.minionQueue[
            seasonId
        ][regionId];

        uint256[] memory unclaimedShadowcornRewards = new uint256[](
            regionRewards.length
        );

        uint256[] memory unclaimedUnicornRewards = new uint256[](
            regionRewards.length
        );

        if (LibTwTWave.twtWaveStorage().initialized) {
            if (
                unicornQueue.hasOutdatedWaves(waveId) ||
                minionQueue.hasOutdatedWaves(waveId)
            ) {
                (
                    unclaimedShadowcornRewards,
                    unclaimedUnicornRewards
                ) = twtCalculateUnclaimedRewardsByWaveId(
                    seasonId,
                    regionId,
                    waveId
                );
                twtDequeueUnicornQueue(seasonId, regionId, waveId);
                twtDequeueMinionQueue(seasonId, regionId);
            }
        }

        // set the daily wave rewards for the current wave
        ltrs.waveRewards[seasonId][regionId][waveId] = ltrs.regionRewards[
            seasonId
        ][regionId];

        for (uint8 i = 0; i < regionRewards.length; ++i) {
            ltrs
            .waveRewards[seasonId][regionId][waveId][i]
                .shadowcornBaseAmount += unclaimedShadowcornRewards[i];
            ltrs
            .waveRewards[seasonId][regionId][waveId][i]
                .unicornBaseAmount += unclaimedUnicornRewards[i];
            ltrs
            .waveRewards[seasonId][regionId][waveId][i]
                .claimableShadowcornRewards = 0;
            ltrs
            .waveRewards[seasonId][regionId][waveId][i]
                .claimableUnicornRewards = 0;
        }
    }

    function twtCalculateUnclaimedRewardsByWaveId(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId
    )
        internal
        view
        returns (
            uint256[] memory unclaimedShadowcornRewards,
            uint256[] memory unclaimedUnicornRewards
        )
    {
        // find the wave ids that are out of range and add their rewards

        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];

        // get the current wave id
        // (uint256 currentWaveId, ) = LibTwTWave.twtCalculateCurrentWaveData();
        if (waveId <= 7) {
            SeasonReward[] memory dailyRewards = ltrs.waveRewards[seasonId][
                regionId
            ][waveId];
            unclaimedShadowcornRewards = new uint256[](dailyRewards.length);
            unclaimedUnicornRewards = new uint256[](dailyRewards.length);
            return (unclaimedShadowcornRewards, unclaimedUnicornRewards);
        }

        uint256[] memory unclaimedShadowcornRewardsByWaveId;
        uint256[] memory unclaimedUnicornRewardsByWaveId;

        // get last claimable wave id
        uint256 lastClaimableWaveId = waveId - 7;
        // get the first wave id in the queue
        (uint256 firstWaveId, ) = unicornQueue.peek();

        require(
            firstWaveId <= lastClaimableWaveId,
            "R-003"
        );

        // loop from the first wave id to the last claimable wave id
        for (uint256 i = firstWaveId; i < lastClaimableWaveId; ++i) {
            // get the unclaimed rewards for the wave id
            (
                unclaimedShadowcornRewardsByWaveId,
                unclaimedUnicornRewardsByWaveId
            ) = twtGetUnclaimedRewardsByWaveId(seasonId, regionId, i);
            unclaimedShadowcornRewards = addArrays(
                unclaimedShadowcornRewards,
                unclaimedShadowcornRewardsByWaveId
            );
            unclaimedUnicornRewards = addArrays(
                unclaimedUnicornRewards,
                unclaimedUnicornRewardsByWaveId
            );
        }
    }

    // TODO: move to common repo
    function addArrays(
        uint256[] memory array1,
        uint256[] memory array2
    ) public pure returns (uint256[] memory) {
        require(
            array1.length == array2.length,
            "GA-003"
        );

        uint256[] memory result = new uint256[](array1.length);

        for (uint i = 0; i < array1.length; ++i) {
            result[i] = array1[i] + array2[i];
        }

        return result;
    }

    // TODO: move to common repo
    function checkNonZeroUintArray(
        uint256[] memory array
    ) public pure returns (bool) {
        for (uint i = 0; i < array.length; ++i) {
            if (array[i] != 0) {
                return true;
            }
        }
        return false;
    }

    function twtDequeueUnicornQueue(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId
    ) internal {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];

        // get dequeue count
        uint256 dequeueCount = unicornQueue.getDequeueCount(waveId);

        // dequeue the unicorn queue that is out of range
        for (uint256 i = 0; i < dequeueCount; ++i) {
            unicornQueue.dequeue();
        }
    }

    function twtDequeueMinionQueue(uint16 seasonId, uint8 regionId) internal {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibMinionQueue.QueueStorage storage minionQueue = ltrs.minionQueue[
            seasonId
        ][regionId];

        uint256 waveId = LibTwTWave.twtGetCurrentWaveId();

        // get dequeue count
        uint256 dequeueCount = minionQueue.getDequeueCount(waveId);

        // dequeue the minion queue that is out of range
        for (uint256 i = 0; i < dequeueCount; ++i) {
            minionQueue.dequeue();
        }
    }

    function twtIsUnicornQueueInitialized(
        uint16 seasonId,
        uint8 regionId
    ) internal view returns (bool) {
        return
            twtRewardsStorage()
            .unicornQueue[seasonId][regionId].isInitialized();
    }

    function twtIsMinionQueueInitialized(
        uint16 seasonId,
        uint8 regionId
    ) internal view returns (bool) {
        return
            twtRewardsStorage().minionQueue[seasonId][regionId].isInitialized();
    }

    function twtGetUnicornQueueLength(
        uint16 seasonId,
        uint8 regionId
    ) internal view returns (uint256 length) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];
        return unicornQueue.length();
    }

    function twtGetUnicornQueue(
        uint16 seasonId,
        uint8 regionId
    )
        internal
        view
        returns (uint256[] memory waveIdsArray, uint56[] memory ptsArray)
    {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];
        uint256 queueLen = unicornQueue.length();
        waveIdsArray = new uint256[](queueLen);
        ptsArray = new uint56[](queueLen);

        for (uint256 i = 0; i < queueLen; ++i) {
            (uint256 waveId, uint56 points) = unicornQueue.at(i);
            waveIdsArray[i] = waveId;
            ptsArray[i] = points;
        }

        return (waveIdsArray, ptsArray);
    }

    /// @notice Get the wave IDs for the start and end of a specified range based on the current wave count.
    /// @dev If the current wave count is greater than 1, the startWaveId is set to currentWaveCount - 1.
    ///      If the current wave count is greater or equal to 7, the endWaveId is set to currentWaveCount - 7.
    ///      Otherwise, startWaveId and endWaveId are set to 0.
    /// @return startWaveId The starting wave ID of the range.
    /// @return endWaveId The ending wave ID of the range.
    /// @return currentWaveCount The current wave count at the time of calling this function.
    function twtGetWaveIdRange()
        internal
        view
        returns (
            uint256 startWaveId,
            uint256 endWaveId,
            uint256 currentWaveCount
        )
    {
        (currentWaveCount, ) = LibTwTWave.twtCalculateCurrentWaveData();

        if (currentWaveCount > 1) {
            startWaveId = currentWaveCount - 1;
        } else {
            startWaveId = 0;
        }

        if (currentWaveCount >= 7) {
            endWaveId = currentWaveCount - 7;
        } else {
            endWaveId = 0;
        }

        return (startWaveId, endWaveId, currentWaveCount);
    }

    function twtGetUnicornPlayerRewardsForAllRegions(
        uint16 seasonId,
        address user
    ) internal view returns (uint256[] memory playerRewards) {
        uint256[] memory firstRegionRewards = twtGetUnicornPlayerRewards(
            seasonId,
            1,
            user
        );
        playerRewards = new uint256[](firstRegionRewards.length);

        // IMPORTANT: regions should all have the same rewards length
        for (uint8 i = 1; i < 6; ++i) {
            uint256[] memory regionRewards = twtGetUnicornPlayerRewards(
                seasonId,
                i,
                user
            );
            for (uint256 j = 0; j < regionRewards.length; ++j) {
                playerRewards[j] += regionRewards[j];
            }
        }
    }

    function twtGetShadowcornPlayerRewardsForAllRegions(
        uint16 seasonId,
        address user
    ) internal view returns (uint256[] memory playerRewards) {
        uint256[] memory firstRegionRewards = twtGetShadowcornPlayerRewards(
            seasonId,
            1,
            user
        );
        playerRewards = new uint256[](firstRegionRewards.length);

        // IMPORTANT: regions should all have the same rewards length
        for (uint8 i = 1; i < 6; ++i) {
            uint256[] memory regionRewards = twtGetShadowcornPlayerRewards(
                seasonId,
                i,
                user
            );
            for (uint256 j = 0; j < regionRewards.length; ++j) {
                playerRewards[j] += regionRewards[j];
            }
        }
    }

    // TODO: Add tests to ensure that the correct wave rewards are being returned
    function twtGetUnicornPlayerRewards(
        uint16 seasonId,
        uint8 regionId,
        address player
    ) internal view returns (uint256[] memory playerRewards) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        SeasonReward[] memory regionRewards = ltrs.regionRewards[seasonId][
            regionId
        ];

        (
            uint256 startWaveId,
            uint256 endWaveId,
            uint256 currentWaveCount
        ) = twtGetWaveIdRange();

        playerRewards = new uint256[](regionRewards.length);
        uint256[] memory playerWaveRewards = new uint256[](
            regionRewards.length
        );

        // loop from today's wave id back to the 6 waves before
        for (
            uint256 waveCounter = startWaveId;
            waveCounter > endWaveId;
            waveCounter--
        ) {
            // calculate rewards by wave id
            playerWaveRewards = twtUnicornPlayerRewardsByWaveId(
                seasonId,
                regionId,
                waveCounter,
                player
            );
            require(
                playerWaveRewards.length == regionRewards.length,
                "R-002"
            );
            for (uint256 j = 0; j < regionRewards.length; ++j) {
                playerRewards[j] = playerRewards[j] + playerWaveRewards[j];
            }
        }
    }

    // TODO: Add tests to ensure that the correct wave rewards are being returned
    function twtUnicornPlayerRewardsByWaveId(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId,
        address player
    ) internal view returns (uint256[] memory waveRewards) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();

        uint56 playerPts = twtGetUnicornPtsForPlayerByWaveId(
            seasonId,
            regionId,
            waveId,
            player
        );

        uint56 totalPts = twtGetUnicornPtsByWaveId(seasonId, regionId, waveId);
        SeasonReward[] memory dailyRewards = ltrs.waveRewards[seasonId][
            regionId
        ][waveId];

        SeasonReward[] memory regionRewards = ltrs.regionRewards[seasonId][
            regionId
        ];

        waveRewards = new uint256[](regionRewards.length);

        if (totalPts == 0) {
            return waveRewards;
        }

        bool isFactionControl = false;
        if (
            twtGetFactionControl(seasonId, regionId, waveId) ==
            FactionType.UNICORN
        ) {
            isFactionControl = true;
        }

        // loop through the daily rewards
        for (uint256 i = 0; i < dailyRewards.length; ++i) {
            waveRewards[i] = dailyRewards[i].unicornBaseAmount;
            // check faction control logic to add unicornControlAmount
            if (isFactionControl) {
                waveRewards[i] += dailyRewards[i].unicornControlAmount;
            }
            waveRewards[i] = (waveRewards[i] * playerPts) / totalPts;
        }
    }

    // TODO: Add tests to ensure that the correct wave rewards are being returned
    function twtShadowcornPlayerRewardsByWaveId(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId,
        address player
    ) internal view returns (uint256[] memory waveRewards) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();

        (
            uint56 myStakingPts,
            uint56 myCombatPts
        ) = twtGetShadowcornPtsForPlayerByWaveId(
                seasonId,
                regionId,
                waveId,
                player
            );

        (
            uint56 totalStakingPts,
            uint56 totalCombatPts
        ) = twtGetShadowcornPtsByWaveId(seasonId, regionId, waveId);
        SeasonReward[] memory dailyRewards = ltrs.waveRewards[seasonId][
            regionId
        ][waveId];

        SeasonReward[] memory regionRewards = ltrs.regionRewards[seasonId][
            regionId
        ];

        waveRewards = new uint256[](regionRewards.length);

        if (totalStakingPts == 0 && totalCombatPts == 0) {
            return waveRewards;
        }

        bool isFactionControl = false;
        if (
            twtGetFactionControl(seasonId, regionId, waveId) ==
            FactionType.SHADOWCORN
        ) {
            isFactionControl = true;
        }

        // loop through the daily rewards
        for (uint256 i = 0; i < dailyRewards.length; ++i) {
            uint256 rewardPool = dailyRewards[i].shadowcornBaseAmount;
            // check faction control logic to add shadowcornControlAmount
            if (isFactionControl) {
                rewardPool += dailyRewards[i].shadowcornControlAmount;
            }

            uint256 stakingRewardPool;
            uint256 combatRewardPool;
            uint256 myStakingRewards;
            uint256 myCombatRewards;
            if (totalStakingPts != 0) {
                stakingRewardPool =
                    (rewardPool * totalStakingPts) /
                    (totalStakingPts + totalCombatPts);
                myStakingRewards =
                    (myStakingPts * stakingRewardPool) /
                    totalStakingPts;
            }
            if (totalCombatPts != 0) {
                combatRewardPool =
                    (rewardPool * totalCombatPts) /
                    (totalStakingPts + totalCombatPts);
                myCombatRewards =
                    (myCombatPts * combatRewardPool) /
                    totalCombatPts;
            }
            waveRewards[i] = myStakingRewards + myCombatRewards;
        }
    }

    function twtGetUnclaimedRewardsByWaveId(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId
    )
        internal
        view
        returns (
            uint256[] memory unclaimedShadowcornRewards,
            uint256[] memory unclaimedUnicornRewards
        )
    {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        SeasonReward[] memory regionRewards = ltrs.regionRewards[seasonId][
            regionId
        ];
        SeasonReward[] memory dailyRewards = ltrs.waveRewards[seasonId][
            regionId
        ][waveId];
        unclaimedShadowcornRewards = new uint256[](regionRewards.length);
        unclaimedUnicornRewards = new uint256[](regionRewards.length);
        // loop through the daily rewards
        for (uint256 i = 0; i < dailyRewards.length; ++i) {
            // add checking faction control logic and modify unicornControlAmount
            unclaimedShadowcornRewards[i] = dailyRewards[i]
                .claimableShadowcornRewards;
            unclaimedUnicornRewards[i] = dailyRewards[i]
                .claimableUnicornRewards;
        }
    }

    function twtGetUnicornPtsForPlayerByWaveId(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId,
        address player
    ) internal view returns (uint56 pts) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];

        pts = unicornQueue.getAccountWavePts(waveId, player);
    }

    function twtGetShadowcornPtsForPlayerByWaveId(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId,
        address player
    ) internal view returns (uint56 stakingPts, uint56 combatPts) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibMinionQueue.QueueStorage storage minionQueue = ltrs.minionQueue[
            seasonId
        ][regionId];

        stakingPts = minionQueue.getAccountStakingPtsByWaveId(waveId, player);
        combatPts = minionQueue.getAccountCombatPtsByWaveId(waveId, player);
    }

    function twtGetStakingPtsByMinionSquadId(
        uint16 seasonId,
        uint8 regionId,
        uint40 minionSquadId
    ) internal view returns (uint56 pts) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibMinionQueue.QueueStorage storage minionQueue = ltrs.minionQueue[
            seasonId
        ][regionId];

        pts = minionQueue.getStakingPtsByMinionSquadId(minionSquadId);
    }

    function twtGetMinionSquadsByAccountAndWaveId(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId,
        address account
    ) internal view returns (uint40[] memory minionSquadIds) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibMinionQueue.QueueStorage storage minionQueue = ltrs.minionQueue[
            seasonId
        ][regionId];

        minionSquadIds = minionQueue.getMinionSquadsByAccountAndWaveId(
            account,
            waveId
        );
    }

    function twtGetUnicornPtsByWaveId(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId
    ) internal view returns (uint56 pts) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];

        pts = unicornQueue.twtGetUnicornPtsByWaveId(waveId);
    }

    function twtGetShadowcornPtsByWaveId(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId
    ) internal view returns (uint56 stakingPts, uint56 combatPts) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibMinionQueue.QueueStorage storage minionQueue = ltrs.minionQueue[
            seasonId
        ][regionId];

        stakingPts = minionQueue.getStakingPtsByWaveId(waveId);
        combatPts = minionQueue.getCombatPtsByWaveId(waveId);
    }

    function twtSetFactionControl(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId,
        FactionType faction
    ) internal {
        twtRewardsStorage().factionControlMap[seasonId][regionId][
            waveId
        ] = faction;
        SeasonReward[] storage waveRewards = twtRewardsStorage().waveRewards[
            seasonId
        ][regionId][waveId];

        SeasonReward[] storage regionRewards = twtRewardsStorage()
            .regionRewards[seasonId][regionId];

        uint256[] memory claimableShadowcornRewardsArray = new uint256[](
            waveRewards.length
        );
        uint256[] memory claimableUnicornRewardsArray = new uint256[](
            waveRewards.length
        );

        for (uint256 i = 0; i < waveRewards.length; ++i) {
            if (faction == FactionType.SHADOWCORN) {
                waveRewards[i].claimableShadowcornRewards =
                    waveRewards[i].shadowcornBaseAmount +
                    waveRewards[i].shadowcornControlAmount;
                regionRewards[i].claimableShadowcornRewards =
                    waveRewards[i].shadowcornBaseAmount +
                    waveRewards[i].shadowcornControlAmount;
                waveRewards[i].claimableUnicornRewards = waveRewards[i]
                    .unicornBaseAmount;
                regionRewards[i].claimableUnicornRewards = waveRewards[i]
                    .unicornBaseAmount;
            } else {
                waveRewards[i].claimableShadowcornRewards = waveRewards[i]
                    .shadowcornBaseAmount;
                regionRewards[i].claimableShadowcornRewards = waveRewards[i]
                    .shadowcornBaseAmount;
                waveRewards[i].claimableUnicornRewards =
                    waveRewards[i].unicornBaseAmount +
                    waveRewards[i].unicornControlAmount;
                regionRewards[i].claimableUnicornRewards =
                    waveRewards[i].unicornBaseAmount +
                    waveRewards[i].unicornControlAmount;
            }

            claimableShadowcornRewardsArray[i] = waveRewards[i]
                .claimableShadowcornRewards;
            claimableUnicornRewardsArray[i] = waveRewards[i]
                .claimableUnicornRewards;
        }

        emit LibEvents.TwTFactionControlDeclared(
            seasonId,
            regionId,
            waveId,
            faction
        );

        emit LibEvents.TwTClaimableRewardsUpdated(
            seasonId,
            regionId,
            waveId,
            claimableShadowcornRewardsArray,
            claimableUnicornRewardsArray
        );
    }

    function twtGetFactionControl(
        uint16 seasonId,
        uint8 regionId,
        uint256 waveId
    ) internal view returns (FactionType faction) {
        faction = twtRewardsStorage().factionControlMap[seasonId][regionId][
            waveId
        ];
    }

    function twtGetShadowcornDominationPointsBySeasonRegion(
        uint16 seasonId,
        uint8 regionId
    ) internal view returns (uint56 dominationPoints) {
        dominationPoints = twtRewardsStorage()
            .shadowcornDominationPointsBySeasonRegion[seasonId][regionId];
    }

    function twtGetUnicornDominationPointsBySeasonRegion(
        uint16 seasonId,
        uint8 regionId
    ) internal view returns (uint56 dominationPoints) {
        dominationPoints = twtRewardsStorage()
            .unicornDominationPointsBySeasonRegion[seasonId][regionId];
    }

    function enforceRegionIdIsValid(uint8 regionId) internal pure {
        require(
            regionId >= 1 && regionId <= 5,
            "R-001"
        );
    }

    function twtGetShadowcornDominationPointsBySeasonRegionAccount(
        uint16 seasonId,
        uint8 regionId,
        address account
    ) internal view returns (uint56 dominationPoints) {
        dominationPoints = twtRewardsStorage()
            .shadowcornDominationPointsBySeasonRegionAccount[seasonId][
                regionId
            ][account];
    }

    function twtGetUnicornDominationPointsBySeasonRegionAccount(
        uint16 seasonId,
        uint8 regionId,
        address account
    ) internal view returns (uint56 dominationPoints) {
        dominationPoints = twtRewardsStorage()
            .unicornDominationPointsBySeasonRegionAccount[seasonId][regionId][
                account
            ];
    }

    function twtGetShadowcornDominationPointsBySeasonRegionAndWave(
        uint16 seasonId,
        uint8 regionId,
        uint256 wave
    ) internal view returns (uint56 dominationPoints) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibMinionQueue.QueueStorage storage minionQueue = ltrs.minionQueue[
            seasonId
        ][regionId];

        dominationPoints =
            minionQueue.getStakingPtsByWaveId(wave) +
            minionQueue.getCombatPtsByWaveId(wave);

        return dominationPoints;
    }

    function twtGetUnicornDominationPointsBySeasonRegionAndWave(
        uint16 seasonId,
        uint8 regionId,
        uint256 wave
    ) internal view returns (uint56 dominationPoints) {
        LibTwTRewardsStorage storage ltrs = twtRewardsStorage();
        LibUnicornQueue.QueueStorage storage unicornQueue = ltrs.unicornQueue[
            seasonId
        ][regionId];

        dominationPoints = unicornQueue.twtGetUnicornPtsByWaveId(wave);

        return dominationPoints;
    }

    function twtRewardsStorage()
        internal
        pure
        returns (LibTwTRewardsStorage storage ltrs)
    {
        bytes32 position = TWT_REWARDS_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ltrs.slot := position
        }
    }
}


// Chain: POLYGON - File: LibUnicornQueue.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title LibUnicornQueue
/// @author Shiva Shanmuganathan
/// @dev Implementation of the queue data structure, providing a library with struct definition for queue storage in consuming contracts.
/// @notice This library provides functionalities to manage a queue data structure, allowing contracts to enqueue and dequeue items.
library LibUnicornQueue {
    struct QueueStorage {
        mapping(uint256 idx => uint256 waveId) idxToWaveId;
        mapping(uint256 waveId => uint56 points) waveIdToPts;
        mapping(address account => mapping(uint256 waveId => uint56 points)) accountToWaveIdToPts;
        uint256 first;
        uint256 last;
    }

    /// @dev Initializes the queue by setting the first and last indices.
    /// @param queue The queue to initialize.
    function initialize(QueueStorage storage queue) internal {
        queue.first = 1;
        queue.last = 0;
    }

    /// @dev Enqueues a new item into the queue.
    /// @param queue The queue to enqueue the item into.
    /// @param waveId The waveId of the item.
    /// @param points The points associated with the item.
    function enqueue(
        QueueStorage storage queue,
        uint256 waveId,
        uint56 points,
        address user
    ) internal {
        enforceQueueInitialized(queue);
        queue.idxToWaveId[++queue.last] = waveId;
        queue.waveIdToPts[waveId] = points;
        queue.accountToWaveIdToPts[user][waveId] = points;
    }

    /// @dev Dequeues an item from the front of the queue.
    /// @param queue The queue to dequeue an item from.
    /// @return waveId The waveId of the dequeued item.
    /// @return points The points associated with the dequeued item.
    function dequeue(
        QueueStorage storage queue
    ) internal returns (uint256 waveId, uint56 points) {
        enforceQueueInitialized(queue);
        if (isEmpty(queue)) {
            return (0, 0);
        }

        waveId = queue.idxToWaveId[queue.first];
        points = queue.waveIdToPts[waveId];

        delete queue.waveIdToPts[waveId];
        delete queue.idxToWaveId[queue.first];

        queue.first = queue.first + 1;
    }

    /// @notice Adds to the points associated with a given wave ID in the queue.
    /// @param queue The storage reference to the queue being updated.
    /// @param waveId The wave ID for which the points is being updated.
    /// @param points The amount to add to the existing points associated with the wave ID.
    /// require The specified wave ID must match the last wave ID in the queue.
    function addToWavePts(
        QueueStorage storage queue,
        uint256 waveId,
        uint56 points,
        address user
    ) internal {
        queue.waveIdToPts[waveId] += points;
        queue.accountToWaveIdToPts[user][waveId] += points;
    }

    function getAccountWavePts(
        QueueStorage storage queue,
        uint256 waveId,
        address user
    ) internal view returns (uint56) {
        return queue.accountToWaveIdToPts[user][waveId];
    }

    function removeAccountWavePts(
        QueueStorage storage queue,
        uint256 waveId,
        address user
    ) internal {
        queue.accountToWaveIdToPts[user][waveId] = 0;
    }

    /// @dev Checks if the queue has been initialized.
    /// @param queue The queue to check.
    /// @return isQueueInitialized True if the queue is initialized, false otherwise.
    function isInitialized(
        QueueStorage storage queue
    ) internal view returns (bool isQueueInitialized) {
        return queue.first != 0;
    }

    /// @dev Checks if the queue is initialized and raises an error if not.
    /// @param queue The queue to check for initialization.
    function enforceQueueInitialized(QueueStorage storage queue) internal view {
        require(
            isInitialized(queue),
            "UQ-002"
        );
    }

    /// @dev Function to check if the queue is not empty.
    /// @param queue The queue to check.
    function enforceNonEmptyQueue(QueueStorage storage queue) internal view {
        require(!isEmpty(queue), "UQ-001");
    }

    /// @dev Returns the length of the queue.
    /// @param queue The queue to get the length of.
    /// @return queueLength The length of the queue.
    function length(
        QueueStorage storage queue
    ) internal view returns (uint256 queueLength) {
        if (queue.last < queue.first) {
            return 0;
        }
        return queue.last - queue.first + 1;
    }

    /// @dev Checks if the queue is empty.
    /// @param queue The queue to check.
    /// @return isQueueEmpty True if the queue is empty, false otherwise.
    function isEmpty(
        QueueStorage storage queue
    ) internal view returns (bool isQueueEmpty) {
        return length(queue) == 0;
    }

    /// @dev Returns the item at the front of the queue without dequeuing it.
    /// @param queue The queue to get the front item from.
    /// @return waveId The waveId of the front item.
    /// @return points The points associated with the front item.
    function peek(
        QueueStorage storage queue
    ) internal view returns (uint256 waveId, uint56 points) {
        waveId = queue.idxToWaveId[queue.first];
        points = queue.waveIdToPts[waveId];
    }

    /// @dev Returns the item at the end of the queue without dequeuing it.
    /// @param queue The queue to get the last item from.
    /// @return waveId The waveId of the last item.
    /// @return points The points associated with the last item.
    function peekLast(
        QueueStorage storage queue
    ) internal view returns (uint256 waveId, uint56 points) {
        waveId = queue.idxToWaveId[queue.last];
        points = queue.waveIdToPts[waveId];
    }

    /// @dev Returns the item at the given index in the queue.
    /// @param queue The queue to get the item from.
    /// @param idx The index of the item to retrieve.
    /// @return waveId The waveId of the item at the given index.
    /// @return points The points associated with the item at the given index.
    function at(
        QueueStorage storage queue,
        uint256 idx
    ) internal view returns (uint256 waveId, uint56 points) {
        idx = idx + queue.first;
        waveId = queue.idxToWaveId[idx];
        points = queue.waveIdToPts[waveId];
    }

    /// @notice Checks if a given wave ID exists in the specified queue.
    /// @param queue The storage reference to the queue being checked.
    /// @param waveId The wave ID to check for existence in the queue.
    /// @return waveExists A boolean value indicating whether the specified wave ID exists in the queue.
    function waveIdExistsInQueue(
        QueueStorage storage queue,
        uint256 waveId
    ) internal view returns (bool waveExists) {
        if (queue.waveIdToPts[waveId] == 0) {
            return false;
        }
        return true;
    }

    /// @notice Retrieves the points associated with a given wave ID in the specified queue.
    /// @param queue The storage reference to the queue from which the points is being retrieved.
    /// @param waveId The wave ID for which the points is being fetched.
    /// @return points The points associated with the specified wave ID.
    function twtGetUnicornPtsByWaveId(
        QueueStorage storage queue,
        uint256 waveId
    ) internal view returns (uint56 points) {
        return queue.waveIdToPts[waveId];
    }

    /// @dev Returns the dequeue count for waves more than 7 days old (or 7 waves ago) from the provided waveId.
    /// @param queue The queue to get the dequeue count from.
    /// @param waveId The waveId from which to count older waves.
    /// @return dequeueCount The count of waves more than 7 days old.
    function getDequeueCount(
        QueueStorage storage queue,
        uint256 waveId
    ) internal view returns (uint256) {
        uint256 dequeueCount = 0;
        uint256 waveIdFromQueue;

        // If queue length is 0, there's nothing to dequeue.
        if (length(queue) == 0) {
            return 0;
        }

        // Loop over the queue from the end to the beginning.
        for (uint256 i = 0; i < length(queue); ++i) {
            // Get the waveIdFromQueue at index i
            (waveIdFromQueue, ) = at(queue, i);

            // If the waveIdFromQueue is more than 7 days old, increment dequeueCount and continue.
            if (waveId - 6 > waveIdFromQueue) {
                ++dequeueCount;
            } else {
                // If the waveIdFromQueue is within 7 days, break the loop.
                break;
            }
        }

        return dequeueCount;
    }

    /// @notice Checks if the queue has any waves that are considered outdated based on the given wave ID.
    /// @param queue The storage reference to the queue being checked.
    /// @param waveId The wave ID used to determine if there are any outdated waves in the queue.
    /// @return waveExists A boolean value indicating whether there are outdated waves in the queue.
    function hasOutdatedWaves(
        QueueStorage storage queue,
        uint256 waveId
    ) internal view returns (bool waveExists) {
        (uint256 waveIdFromQueueStart, ) = peek(queue);
        return waveId - waveIdFromQueueStart + 1 > 7;
    }
}


// Chain: POLYGON - File: LibMinionQueue.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title LibMinionQueue
/// @author Shiva Shanmuganathan
/// @dev Implementation of the queue data structure, providing a library with struct definition for queue storage in consuming contracts.
/// @notice This library provides functionalities to manage a queue data structure, allowing contracts to enqueue and dequeue items.
library LibMinionQueue {
    struct QueueStorage {
        // queue with waveId and domination points [staking and combat points]
        mapping(uint256 idx => uint256 waveId) idxToWaveId;
        mapping(uint256 waveId => uint56 stakingPts) waveIdToStakingPts;
        mapping(uint256 waveId => uint56 combatPts) waveIdToCombatPts;
        // minion squad id to wave id
        mapping(uint40 minionSquadId => uint256 waveId) stakedMinionSquadToWaveId;
        // minion squad id to staking points
        mapping(uint40 minionSquadId => uint56 stakingPts) minionSquadToStakingPts;
        // minion squad id to combat points
        mapping(uint40 minionSquadId => mapping(uint256 waveId => uint56 combatPts)) minionSquadToWaveIdToCombatPts;
        // account to wave id to minion squads
        mapping(address account => mapping(uint256 waveId => uint40[] minionSquadIds)) accountToWaveIdToMinionSquads;
        // minion squad id to account
        mapping(uint40 minionSquadId => address account) minionSquadIdToAccount;
        // queue first and last indices
        uint256 first;
        uint256 last;
    }

    /// @dev Initializes the queue by setting the first and last indices.
    /// @param queue The queue to initialize.
    function initialize(QueueStorage storage queue) internal {
        queue.first = 1;
        queue.last = 0;
    }

    /// @dev Enqueues a new item into the queue.
    /// @param queue The queue to enqueue the item into.
    /// @param waveId The waveId of the item.
    function enqueue(QueueStorage storage queue, uint256 waveId) internal {
        enforceQueueInitialized(queue);
        queue.idxToWaveId[++queue.last] = waveId;
    }

    /// @dev Dequeues an item from the front of the queue.
    /// @param queue The queue to dequeue an item from.
    /// @return waveId The waveId of the dequeued item.
    /// @return stakingPts
    /// @return combatPts
    function dequeue(
        QueueStorage storage queue
    ) internal returns (uint256 waveId, uint56 stakingPts, uint56 combatPts) {
        enforceQueueInitialized(queue);
        if (isEmpty(queue)) {
            return (0, 0, 0);
        }
        waveId = queue.idxToWaveId[queue.first];
        stakingPts = queue.waveIdToStakingPts[waveId];
        combatPts = queue.waveIdToCombatPts[waveId];

        delete queue.waveIdToStakingPts[waveId];
        delete queue.waveIdToCombatPts[waveId];
        delete queue.idxToWaveId[queue.first];
        queue.first = queue.first + 1;
    }

    /// @notice Adds to the points associated with a given wave ID in the queue.
    /// @param queue The storage reference to the queue being updated.
    /// @param waveId The wave ID for which the points is being updated.
    /// @param combatPts The amount to add to the existing points associated with the wave ID.
    /// require The specified wave ID must match the last wave ID in the queue.
    function addToWaveCombatPts(
        QueueStorage storage queue,
        uint256 waveId,
        uint40 minionSquadId,
        uint56 combatPts
    ) internal {
        address user = queue.minionSquadIdToAccount[minionSquadId];
        queue.accountToWaveIdToMinionSquads[user][waveId].push(minionSquadId);
        queue.minionSquadToWaveIdToCombatPts[minionSquadId][
            waveId
        ] += combatPts;
        queue.waveIdToCombatPts[waveId] += combatPts;
    }

    function addToWaveStakingPts(
        QueueStorage storage queue,
        uint256 waveId,
        uint56 stakingPts,
        uint40 minionSquadId,
        address user
    ) internal {
        queue.accountToWaveIdToMinionSquads[user][waveId].push(minionSquadId);
        queue.stakedMinionSquadToWaveId[minionSquadId] = waveId;
        queue.minionSquadToStakingPts[minionSquadId] = stakingPts;
        queue.waveIdToStakingPts[waveId] += stakingPts;
        queue.minionSquadIdToAccount[minionSquadId] = user;
    }

    function removeMinionSquadsByAccountAndWaveId(
        QueueStorage storage queue,
        uint256 waveId,
        address user
    ) internal {
        delete queue.accountToWaveIdToMinionSquads[user][waveId];
    }

    function removeMinionSquadStakingPts(
        QueueStorage storage queue,
        uint256 waveId,
        address user
    ) internal {
        uint40[] memory minionSquadIds = queue.accountToWaveIdToMinionSquads[
            user
        ][waveId];
        for (uint256 i = 0; i < minionSquadIds.length; ++i) {
            delete queue.minionSquadToStakingPts[minionSquadIds[i]];
        }
    }

    function removeMinionSquadCombatPts(
        QueueStorage storage queue,
        uint256 waveId,
        address user
    ) internal {
        uint40[] memory minionSquadIds = queue.accountToWaveIdToMinionSquads[
            user
        ][waveId];
        for (uint256 i = 0; i < minionSquadIds.length; ++i) {
            delete queue.minionSquadToWaveIdToCombatPts[minionSquadIds[i]][
                waveId
            ];
        }
    }

    function getAccountStakingPtsByWaveId(
        QueueStorage storage queue,
        uint256 waveId,
        address user
    ) internal view returns (uint56) {
        uint40[] memory minionSquadIds = queue.accountToWaveIdToMinionSquads[
            user
        ][waveId];
        uint56 totalStakingPts;
        for (uint256 i = 0; i < minionSquadIds.length; ++i) {
            totalStakingPts += queue.minionSquadToStakingPts[minionSquadIds[i]];
        }

        return totalStakingPts;
    }

    function getAccountCombatPtsByWaveId(
        QueueStorage storage queue,
        uint256 waveId,
        address user
    ) internal view returns (uint56 totalCombatPts) {
        uint40[] memory minionSquadIds = queue.accountToWaveIdToMinionSquads[
            user
        ][waveId];
        for (uint256 i = 0; i < minionSquadIds.length; ++i) {
            totalCombatPts += queue.minionSquadToWaveIdToCombatPts[
                minionSquadIds[i]
            ][waveId];
        }
        return totalCombatPts;
    }

    function getMinionSquadsByAccountAndWaveId(
        QueueStorage storage queue,
        address user,
        uint256 waveId
    ) internal view returns (uint40[] memory) {
        return queue.accountToWaveIdToMinionSquads[user][waveId];
    }

    /// @dev Checks if the queue has been initialized.
    /// @param queue The queue to check.
    /// @return isQueueInitialized True if the queue is initialized, false otherwise.
    function isInitialized(
        QueueStorage storage queue
    ) internal view returns (bool isQueueInitialized) {
        return queue.first != 0;
    }

    /// @dev Checks if the queue is initialized and raises an error if not.
    /// @param queue The queue to check for initialization.
    function enforceQueueInitialized(QueueStorage storage queue) internal view {
        require(
            isInitialized(queue),
            "MQ-001"
        );
    }

    /// @dev Function to check if the queue is not empty.
    /// @param queue The queue to check.
    function enforceNonEmptyQueue(QueueStorage storage queue) internal view {
        require(!isEmpty(queue), "MQ-002");
    }

    /// @dev Returns the length of the queue.
    /// @param queue The queue to get the length of.
    /// @return queueLength The length of the queue.
    function length(
        QueueStorage storage queue
    ) internal view returns (uint256 queueLength) {
        if (queue.last < queue.first) {
            return 0;
        }
        return queue.last - queue.first + 1;
    }

    /// @dev Checks if the queue is empty.
    /// @param queue The queue to check.
    /// @return isQueueEmpty True if the queue is empty, false otherwise.
    function isEmpty(
        QueueStorage storage queue
    ) internal view returns (bool isQueueEmpty) {
        return length(queue) == 0;
    }

    function peek(
        QueueStorage storage queue
    )
        internal
        view
        returns (uint256 waveId, uint56 stakingPts, uint56 combatPts)
    {
        waveId = queue.idxToWaveId[queue.first];
        stakingPts = queue.waveIdToStakingPts[waveId];
        combatPts = queue.waveIdToCombatPts[waveId];
    }

    function peekLast(
        QueueStorage storage queue
    )
        internal
        view
        returns (uint256 waveId, uint56 stakingPts, uint56 combatPts)
    {
        waveId = queue.idxToWaveId[queue.last];
        stakingPts = queue.waveIdToStakingPts[waveId];
        combatPts = queue.waveIdToCombatPts[waveId];
    }

    function at(
        QueueStorage storage queue,
        uint256 idx
    )
        internal
        view
        returns (uint256 waveId, uint56 stakingPts, uint56 combatPts)
    {
        idx = idx + queue.first;
        waveId = queue.idxToWaveId[idx];
        stakingPts = queue.waveIdToStakingPts[waveId];
        combatPts = queue.waveIdToCombatPts[waveId];
    }

    /// @notice Checks if a given wave ID exists in the specified queue.
    /// @param queue The storage reference to the queue being checked.
    /// @param waveId The wave ID to check for existence in the queue.
    /// @return waveExists A boolean value indicating whether the specified wave ID exists in the queue.
    function waveIdExistsInQueue(
        QueueStorage storage queue,
        uint256 waveId
    ) internal view returns (bool waveExists) {
        if (
            queue.waveIdToStakingPts[waveId] == 0 &&
            queue.waveIdToCombatPts[waveId] == 0
        ) {
            return false;
        }
        return true;
    }

    function getStakingPtsByWaveId(
        QueueStorage storage queue,
        uint256 waveId
    ) internal view returns (uint56 stakingPts) {
        return queue.waveIdToStakingPts[waveId];
    }

    function getCombatPtsByWaveId(
        QueueStorage storage queue,
        uint256 waveId
    ) internal view returns (uint56 combatPts) {
        return queue.waveIdToCombatPts[waveId];
    }

    function getStakingPtsByMinionSquadId(
        QueueStorage storage queue,
        uint40 minionSquadId
    ) internal view returns (uint56 stakingPts) {
        return queue.minionSquadToStakingPts[minionSquadId];
    }

    function getCombatPtsByMinionSquadAndWaveId(
        QueueStorage storage queue,
        uint40 minionSquadId,
        uint256 waveId
    ) internal view returns (uint56 combatPts) {
        return queue.minionSquadToWaveIdToCombatPts[minionSquadId][waveId];
    }

    function getAccountByMinionSquadId(
        QueueStorage storage queue,
        uint40 minionSquadId
    ) internal view returns (address account) {
        return queue.minionSquadIdToAccount[minionSquadId];
    }

    function getWaveIdByStakedMinionSquadId(
        QueueStorage storage queue,
        uint40 minionSquadId
    ) internal view returns (uint256 waveId) {
        return queue.stakedMinionSquadToWaveId[minionSquadId];
    }

    /// @dev Returns the dequeue count for waves that contain empty queue items.
    /// @param queue The queue to get the dequeue count from.
    /// @return dequeueCount The count of waves that are empty.
    function getDequeueCount(
        QueueStorage storage queue,
        uint256 waveId
    ) internal view returns (uint256 dequeueCount) {
        uint256 waveIdFromQueue;
        // If queue length is 0, there's nothing to dequeue.
        if (length(queue) == 0) {
            return 0;
        }

        for (uint256 i = 0; i < length(queue); ++i) {
            // Get the waveIdFromQueue at index i
            (waveIdFromQueue, , ) = at(queue, i);
            if (waveId - 6 > waveIdFromQueue) {
                ++dequeueCount;
            } else {
                break;
            }
        }

        return dequeueCount;
    }

    // This method should be called when unstaking (with isMinionSquadLocked) or eliminating minion squads
    function removeStakedMinions(
        QueueStorage storage queue,
        uint40 minionSquadId
    ) internal {
        uint256 waveId = queue.stakedMinionSquadToWaveId[minionSquadId];
        delete queue.minionSquadToWaveIdToCombatPts[minionSquadId][waveId];
        delete queue.minionSquadToStakingPts[minionSquadId];
        delete queue.minionSquadIdToAccount[minionSquadId];
        delete queue.stakedMinionSquadToWaveId[minionSquadId];
    }

    /// @notice Checks if the queue has any waves that are considered outdated based on the given wave ID.
    /// @param queue The storage reference to the queue being checked.
    /// @param waveId The wave ID used to determine if there are any outdated waves in the queue.
    /// @return waveExists A boolean value indicating whether there are outdated waves in the queue.
    function hasOutdatedWaves(
        QueueStorage storage queue,
        uint256 waveId
    ) internal view returns (bool waveExists) {
        (uint256 waveIdFromQueueStart, , ) = peek(queue);
        return (waveId - waveIdFromQueueStart + 1 > 7);
    }
}


// Chain: POLYGON - File: LibComponent.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @author Ignacio Borovsky
library LibComponent {
    struct Component {
        uint256 amount;
        uint128 assetType;         
        uint128 poolId;  
        address asset;              
    }

    enum TransferType {
        NONE,
        MINT_BURN,
        TRANSFER
    }

    struct Cost {
        Component component;
        TransferType transferType;
    }
}

// Chain: POLYGON - File: LibTwTWave.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibTime} from "LibTime.sol";
import {LibEvents} from "LibEvents.sol";

library LibTwTWave {
    /// @notice Position to store the storage
    bytes32 private constant TWT_WAVE_STORAGE_POSITION =
        keccak256("CryptoUnicorns.TwT.Wave.Storage");

    struct LibTwTWaveStorage {
        uint256 waveTime; // Timestamp of the current reward wave
        uint256 waveCount; // Number of reward waves
        bool initialized; // Whether the storage has been initialized
    }

    /// @notice Begins the current reward wave
    /// @dev Should be called whenever a new reward wave starts.
    /// @dev This should happen approximately every 24 hours depending on user minion creation.
    /// @dev Updates unclaimed reward quantities.
    /// @custom:emits BegunNewWave
    function twtBeginNewWave() internal returns (uint256 waveId) {
        LibTwTWaveStorage storage ltws = twtWaveStorage();
        uint256 lastWaveTime = ltws.waveTime;
        (ltws.waveCount, ltws.waveTime) = twtCalculateCurrentWaveData();
        emit LibEvents.TwTBegunNewWave(
            ltws.waveCount,
            lastWaveTime,
            ltws.waveTime
        );
        return ltws.waveCount;
    }

    /// @notice Checks if the current reward wave has expired.
    /// @dev Returns true if the time elapsed since the last wave started is greater than or equal to the duration of a reward wave (24 hours).
    /// @return isExpired True if the current reward wave is expired, otherwise false.
    function twtIsWaveExpired() internal view returns (bool isExpired) {
        LibTwTWaveStorage storage ltws = twtWaveStorage();
        return block.timestamp - ltws.waveTime >= LibTime.SECONDS_PER_DAY;
    }

    /// @notice Calculate Current Wave Data
    /// @dev Calculates the current wave count and the corresponding wave time in UTC, considering midnight as the beginning of a new wave.
    /// @return currentWaveCount The current wave count, including any new waves since the last recorded wave time.
    /// @return currentWaveTime The timestamp of the beginning of the current wave, corresponding to midnight UTC on the current day.
    function twtCalculateCurrentWaveData()
        internal
        view
        returns (uint256 currentWaveCount, uint256 currentWaveTime)
    {
        LibTwTWaveStorage storage ltws = twtWaveStorage();
        uint256 lastWaveTime = ltws.waveTime;
        currentWaveTime = twtCalculateMidnightUTCTime();
        uint256 waveCountToAdd = (currentWaveTime - lastWaveTime) /
            LibTime.SECONDS_PER_DAY;
        currentWaveCount = ltws.waveCount + waveCountToAdd;
    }

    function twtGetCurrentWaveId() internal view returns (uint256 waveId) {
        (waveId, ) = twtCalculateCurrentWaveData();
    }

    function twtGetWaveCount() internal view returns (uint256 waveCount) {
        LibTwTWaveStorage storage ltws = twtWaveStorage();
        waveCount = ltws.waveCount;
    }

    /// @notice Calculate Midnight UTC Time
    /// @dev Calculates the timestamp corresponding to midnight UTC of the current day. This is used to identify the beginning of a new wave.
    /// @return newWaveTime The timestamp representing midnight UTC on the current day.
    function twtCalculateMidnightUTCTime()
        internal
        view
        returns (uint256 newWaveTime)
    {
        (uint year, uint month, uint day) = LibTime._daysToDate(
            block.timestamp / LibTime.SECONDS_PER_DAY
        );
        newWaveTime = LibTime.timestampFromDate(year, month, day);
    }

    function twtWaveStorage()
        internal
        pure
        returns (LibTwTWaveStorage storage ltws)
    {
        bytes32 position = TWT_WAVE_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ltws.slot := position
        }
    }
}


// Chain: POLYGON - File: LibTime.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ----------------------------------------------------------------------------
// BokkyPooBah's DateTime Library v1.01
//
// A gas-efficient Solidity date and time library
//
// https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary
//
// Tested date range 1970/01/01 to 2345/12/31
//
// Conventions:
// Unit      | Range         | Notes
// :-------- |:-------------:|:-----
// timestamp | >= 0          | Unix timestamp, number of seconds since 1970/01/01 00:00:00 UTC
// year      | 1970 ... 2345 |
// month     | 1 ... 12      |
// day       | 1 ... 31      |
// hour      | 0 ... 23      |
// minute    | 0 ... 59      |
// second    | 0 ... 59      |
// dayOfWeek | 1 ... 7       | 1 = Monday, ..., 7 = Sunday
//
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2018-2019. The MIT Licence.
// ----------------------------------------------------------------------------

library LibTime {
    uint constant SECONDS_PER_WEEK = 7 * 24 * 60 * 60;
    uint constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint constant SECONDS_PER_HOUR = 60 * 60;
    uint constant SECONDS_PER_MINUTE = 60;
    int constant OFFSET19700101 = 2440588;

    uint constant DOW_MON = 1;
    uint constant DOW_TUE = 2;
    uint constant DOW_WED = 3;
    uint constant DOW_THU = 4;
    uint constant DOW_FRI = 5;
    uint constant DOW_SAT = 6;
    uint constant DOW_SUN = 7;

    // ------------------------------------------------------------------------
    // Calculate the number of days from 1970/01/01 to year/month/day using
    // the date conversion algorithm from
    //   https://aa.usno.navy.mil/faq/JD_formula.html
    // and subtracting the offset 2440588 so that 1970/01/01 is day 0
    //
    // days = day
    //      - 32075
    //      + 1461 * (year + 4800 + (month - 14) / 12) / 4
    //      + 367 * (month - 2 - (month - 14) / 12 * 12) / 12
    //      - 3 * ((year + 4900 + (month - 14) / 12) / 100) / 4
    //      - offset
    // ------------------------------------------------------------------------
    function _daysFromDate(
        uint year,
        uint month,
        uint day
    ) internal pure returns (uint _days) {
        require(year >= 1970);
        int _year = int(year);
        int _month = int(month);
        int _day = int(day);

        int __days = _day -
            32075 +
            (1461 * (_year + 4800 + (_month - 14) / 12)) /
            4 +
            (367 * (_month - 2 - ((_month - 14) / 12) * 12)) /
            12 -
            (3 * ((_year + 4900 + (_month - 14) / 12) / 100)) /
            4 -
            OFFSET19700101;

        _days = uint(__days);
    }

    // ------------------------------------------------------------------------
    // Calculate year/month/day from the number of days since 1970/01/01 using
    // the date conversion algorithm from
    //   http://aa.usno.navy.mil/faq/docs/JD_Formula.php
    // and adding the offset 2440588 so that 1970/01/01 is day 0
    //
    // int L = days + 68569 + offset
    // int N = 4 * L / 146097
    // L = L - (146097 * N + 3) / 4
    // year = 4000 * (L + 1) / 1461001
    // L = L - 1461 * year / 4 + 31
    // month = 80 * L / 2447
    // dd = L - 2447 * month / 80
    // L = month / 11
    // month = month + 2 - 12 * L
    // year = 100 * (N - 49) + year + L
    // ------------------------------------------------------------------------
    function _daysToDate(
        uint _days
    ) internal pure returns (uint year, uint month, uint day) {
        int __days = int(_days);

        int L = __days + 68569 + OFFSET19700101;
        int N = (4 * L) / 146097;
        L = L - (146097 * N + 3) / 4;
        int _year = (4000 * (L + 1)) / 1461001;
        L = L - (1461 * _year) / 4 + 31;
        int _month = (80 * L) / 2447;
        int _day = L - (2447 * _month) / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint(_year);
        month = uint(_month);
        day = uint(_day);
    }

    function timestampFromDate(
        uint year,
        uint month,
        uint day
    ) internal pure returns (uint timestamp) {
        timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY;
    }

    function timestampFromDateTime(
        uint year,
        uint month,
        uint day,
        uint hour,
        uint minute,
        uint second
    ) internal pure returns (uint timestamp) {
        timestamp =
            _daysFromDate(year, month, day) *
            SECONDS_PER_DAY +
            hour *
            SECONDS_PER_HOUR +
            minute *
            SECONDS_PER_MINUTE +
            second;
    }

    function timestampToDate(
        uint timestamp
    ) internal pure returns (uint year, uint month, uint day) {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }

    function timestampToDateTime(
        uint timestamp
    )
        internal
        pure
        returns (
            uint year,
            uint month,
            uint day,
            uint hour,
            uint minute,
            uint second
        )
    {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        uint secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
        secs = secs % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
        second = secs % SECONDS_PER_MINUTE;
    }

    function isValidDate(
        uint year,
        uint month,
        uint day
    ) internal pure returns (bool valid) {
        if (year >= 1970 && month > 0 && month <= 12) {
            uint daysInMonth = _getDaysInMonth(year, month);
            if (day > 0 && day <= daysInMonth) {
                valid = true;
            }
        }
    }

    function isValidDateTime(
        uint year,
        uint month,
        uint day,
        uint hour,
        uint minute,
        uint second
    ) internal pure returns (bool valid) {
        if (isValidDate(year, month, day)) {
            if (hour < 24 && minute < 60 && second < 60) {
                valid = true;
            }
        }
    }

    function isLeapYear(uint timestamp) internal pure returns (bool leapYear) {
        (uint year, , ) = _daysToDate(timestamp / SECONDS_PER_DAY);
        leapYear = _isLeapYear(year);
    }

    function _isLeapYear(uint year) internal pure returns (bool leapYear) {
        leapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    }

    function isWeekDay(uint timestamp) internal pure returns (bool weekDay) {
        weekDay = getDayOfWeek(timestamp) <= DOW_FRI;
    }

    function isWeekEnd(uint timestamp) internal pure returns (bool weekEnd) {
        weekEnd = getDayOfWeek(timestamp) >= DOW_SAT;
    }

    function getDaysInMonth(
        uint timestamp
    ) internal pure returns (uint daysInMonth) {
        (uint year, uint month, ) = _daysToDate(timestamp / SECONDS_PER_DAY);
        daysInMonth = _getDaysInMonth(year, month);
    }

    function _getDaysInMonth(
        uint year,
        uint month
    ) internal pure returns (uint daysInMonth) {
        if (
            month == 1 ||
            month == 3 ||
            month == 5 ||
            month == 7 ||
            month == 8 ||
            month == 10 ||
            month == 12
        ) {
            daysInMonth = 31;
        } else if (month != 2) {
            daysInMonth = 30;
        } else {
            daysInMonth = _isLeapYear(year) ? 29 : 28;
        }
    }

    // 1 = Monday, 7 = Sunday
    function getDayOfWeek(
        uint timestamp
    ) internal pure returns (uint dayOfWeek) {
        uint _days = timestamp / SECONDS_PER_DAY;
        dayOfWeek = ((_days + 3) % 7) + 1;
    }

    function getYear(uint timestamp) internal pure returns (uint year) {
        (year, , ) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }

    function getMonth(uint timestamp) internal pure returns (uint month) {
        (, month, ) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }

    function getDay(uint timestamp) internal pure returns (uint day) {
        (, , day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }

    function getHour(uint timestamp) internal pure returns (uint hour) {
        uint secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
    }

    function getMinute(uint timestamp) internal pure returns (uint minute) {
        uint secs = timestamp % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
    }

    function getSecond(uint timestamp) internal pure returns (uint second) {
        second = timestamp % SECONDS_PER_MINUTE;
    }

    function addYears(
        uint timestamp,
        uint _years
    ) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(
            timestamp / SECONDS_PER_DAY
        );
        year += _years;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp =
            _daysFromDate(year, month, day) *
            SECONDS_PER_DAY +
            (timestamp % SECONDS_PER_DAY);
        require(newTimestamp >= timestamp);
    }

    function addMonths(
        uint timestamp,
        uint _months
    ) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(
            timestamp / SECONDS_PER_DAY
        );
        month += _months;
        year += (month - 1) / 12;
        month = ((month - 1) % 12) + 1;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp =
            _daysFromDate(year, month, day) *
            SECONDS_PER_DAY +
            (timestamp % SECONDS_PER_DAY);
        require(newTimestamp >= timestamp);
    }

    function addDays(
        uint timestamp,
        uint _days
    ) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _days * SECONDS_PER_DAY;
        require(newTimestamp >= timestamp);
    }

    function addHours(
        uint timestamp,
        uint _hours
    ) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _hours * SECONDS_PER_HOUR;
        require(newTimestamp >= timestamp);
    }

    function addMinutes(
        uint timestamp,
        uint _minutes
    ) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _minutes * SECONDS_PER_MINUTE;
        require(newTimestamp >= timestamp);
    }

    function addSeconds(
        uint timestamp,
        uint _seconds
    ) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp + _seconds;
        require(newTimestamp >= timestamp);
    }

    function subYears(
        uint timestamp,
        uint _years
    ) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(
            timestamp / SECONDS_PER_DAY
        );
        year -= _years;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp =
            _daysFromDate(year, month, day) *
            SECONDS_PER_DAY +
            (timestamp % SECONDS_PER_DAY);
        require(newTimestamp <= timestamp);
    }

    function subMonths(
        uint timestamp,
        uint _months
    ) internal pure returns (uint newTimestamp) {
        (uint year, uint month, uint day) = _daysToDate(
            timestamp / SECONDS_PER_DAY
        );
        uint yearMonth = year * 12 + (month - 1) - _months;
        year = yearMonth / 12;
        month = (yearMonth % 12) + 1;
        uint daysInMonth = _getDaysInMonth(year, month);
        if (day > daysInMonth) {
            day = daysInMonth;
        }
        newTimestamp =
            _daysFromDate(year, month, day) *
            SECONDS_PER_DAY +
            (timestamp % SECONDS_PER_DAY);
        require(newTimestamp <= timestamp);
    }

    function subDays(
        uint timestamp,
        uint _days
    ) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _days * SECONDS_PER_DAY;
        require(newTimestamp <= timestamp);
    }

    function subHours(
        uint timestamp,
        uint _hours
    ) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _hours * SECONDS_PER_HOUR;
        require(newTimestamp <= timestamp);
    }

    function subMinutes(
        uint timestamp,
        uint _minutes
    ) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _minutes * SECONDS_PER_MINUTE;
        require(newTimestamp <= timestamp);
    }

    function subSeconds(
        uint timestamp,
        uint _seconds
    ) internal pure returns (uint newTimestamp) {
        newTimestamp = timestamp - _seconds;
        require(newTimestamp <= timestamp);
    }

    function diffYears(
        uint fromTimestamp,
        uint toTimestamp
    ) internal pure returns (uint _years) {
        require(fromTimestamp <= toTimestamp);
        (uint fromYear, , ) = _daysToDate(fromTimestamp / SECONDS_PER_DAY);
        (uint toYear, , ) = _daysToDate(toTimestamp / SECONDS_PER_DAY);
        _years = toYear - fromYear;
    }

    function diffMonths(
        uint fromTimestamp,
        uint toTimestamp
    ) internal pure returns (uint _months) {
        require(fromTimestamp <= toTimestamp);
        (uint fromYear, uint fromMonth, ) = _daysToDate(
            fromTimestamp / SECONDS_PER_DAY
        );
        (uint toYear, uint toMonth, ) = _daysToDate(
            toTimestamp / SECONDS_PER_DAY
        );
        _months = toYear * 12 + toMonth - fromYear * 12 - fromMonth;
    }

    function diffDays(
        uint fromTimestamp,
        uint toTimestamp
    ) internal pure returns (uint _days) {
        require(fromTimestamp <= toTimestamp);
        _days = (toTimestamp - fromTimestamp) / SECONDS_PER_DAY;
    }

    function diffHours(
        uint fromTimestamp,
        uint toTimestamp
    ) internal pure returns (uint _hours) {
        require(fromTimestamp <= toTimestamp);
        _hours = (toTimestamp - fromTimestamp) / SECONDS_PER_HOUR;
    }

    function diffMinutes(
        uint fromTimestamp,
        uint toTimestamp
    ) internal pure returns (uint _minutes) {
        require(fromTimestamp <= toTimestamp);
        _minutes = (toTimestamp - fromTimestamp) / SECONDS_PER_MINUTE;
    }

    function diffSeconds(
        uint fromTimestamp,
        uint toTimestamp
    ) internal pure returns (uint _seconds) {
        require(fromTimestamp <= toTimestamp);
        _seconds = toTimestamp - fromTimestamp;
    }
}


// Chain: POLYGON - File: ERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC1155.sol";
import "IERC1155Receiver.sol";
import "IERC1155MetadataURI.sol";
import "Address.sol";
import "Context.sol";
import "ERC165.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
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
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
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
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
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
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
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
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
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
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
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
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
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
     * - If `account` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(account != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), account, _asSingletonArray(id), _asSingletonArray(amount), data);

        _balances[id][account] += amount;
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
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
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
    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

        uint256 accountBalance = _balances[id][account];
        require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][account] = accountBalance - amount;
        }

        emit TransferSingle(operator, account, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balances[id][account];
            require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][account] = accountBalance - amount;
            }
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
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
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
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
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


// Chain: POLYGON - File: IERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC165.sol";

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
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

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
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

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


// Chain: POLYGON - File: IERC165.sol
// SPDX-License-Identifier: MIT

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


// Chain: POLYGON - File: IERC1155Receiver.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC165.sol";

/**
 * @dev _Available since v3.1._
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
    ) external returns (bytes4);

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
    ) external returns (bytes4);
}


// Chain: POLYGON - File: IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC1155.sol";

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


// Chain: POLYGON - File: Address.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
        assembly {
            size := extcodesize(account)
        }
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
        return functionCall(target, data, "Address: low-level call failed");
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
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
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

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


// Chain: POLYGON - File: Context.sol
// SPDX-License-Identifier: MIT

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


// Chain: POLYGON - File: ERC165.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC165.sol";

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


// Chain: POLYGON - File: IERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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


// Chain: POLYGON - File: IUNIMControllerFacet.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IUNIMControllerFacet {
    /*
     * @notice Whitelist a user or contract to create new UNIM tokens.
     * @dev Can only be called by the Diamond owner of the UNIM contract.
     * @param minter - Public address of the user or contract allow
     */
    function allowAddressToMintUNIM(address minter) external;

    /*
     * @notice Revoke a user's or contract's permission to create new UNIM tokens.
     * @dev Can only be called by the Diamond owner of the UNIM contract.
     * @param minter - Public address of the user or contract to revoke
     */
    function denyAddressToMintUNIM(address minter) external;

    /*
     * @notice Print the list of wallets and contracts who can create UNIM tokens.
     * @return The full list of permitted addresses
     */
    function getAddressesPermittedToMintUNIM()
        external
        view
        returns (address[] memory);

    /*
     * @notice Reports the lifetime number of UNIM that an address has minted and burned.
     * @param minter - Public address of the minter
     * @return minted - The grand total number of UNIM this address has minted
     * @return burned - The grand total number of UNIM this address has burned
     */
    function auditUNIMMintedByAddress(
        address minter
    ) external view returns (uint256 minted, uint256 burned);

    /*
     * @notice Create new UNIM tokens for a target wallet.
     * @dev Can only be called by an address allowed via allowAddressToMintUNIM
     * @param account - The address receiving the funds
     * @param amount - The number of UNIM tokens to create
     */
    function mintUNIM(address account, uint256 amount) external;

    /*
     * @notice Destroy UNIM tokens from a target wallet.
     * @dev Can only be called by an address allowed via allowAddressToMintUNIM
     * @dev This method uses the player's spend/burn allowance granted to GameBank,
     *     rather than allowance for msgSender, so this may have better permission.
     * @param account - The wallet to remove UNIM from
     * @param amount - The number of UNIM tokens to destroy
     */
    function burnUNIMFrom(address account, uint256 amount) external;
}


// Chain: POLYGON - File: IDarkMarksControllerFacet.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDarkMarksControllerFacet {
    /*
     * @notice Whitelist a user or contract to create new DarkMarks tokens.
     * @dev Can only be called by the Diamond owner of the DarkMarks contract.
     * @param minter - Public address of the user or contract allow
     */
    function allowAddressToMintDarkMarks(address minter) external;

    /*
     * @notice Revoke a user's or contract's permission to create new DarkMarks tokens.
     * @dev Can only be called by the Diamond owner of the DarkMarks contract.
     * @param minter - Public address of the user or contract to revoke
     */
    function denyAddressToMintDarkMarks(address minter) external;

    /*
     * @notice Print the list of wallets and contracts who can create DarkMarks tokens.
     * @return The full list of permitted addresses
     */
    function getAddressesPermittedToMintDarkMarks()
        external
        view
        returns (address[] memory);

    /*
     * @notice Reports the lifetime number of DarkMarks that an address has minted and burned.
     * @param minter - Public address of the minter
     * @return minted - The grand total number of DarkMarks this address has minted
     * @return burned - The grand total number of DarkMarks this address has burned
     */
    function auditDarkMarksMintedByAddress(
        address minter
    ) external view returns (uint256 minted, uint256 burned);

    /*
     * @notice Create new DarkMarks tokens for a target wallet.
     * @dev Can only be called by an address allowed via allowAddressToMintDarkMarks
     * @param account - The address receiving the funds
     * @param amount - The number of DarkMarks tokens to create
     */
    function mintDarkMarks(address account, uint256 amount) external;

    /*
     * @notice Destroy DarkMarks tokens from a target wallet.
     * @dev Can only be called by an address allowed via allowAddressToMintDarkMarks
     * @dev This method uses the player's spend/burn allowance granted to GameBank,
     *     rather than allowance for msgSender, so this may have better permission.
     * @param account - The wallet to remove DarkMarks from
     * @param amount - The number of DarkMarks tokens to destroy
     */
    function burnDarkMarksFrom(address account, uint256 amount) external;
}


// Chain: POLYGON - File: LibTwTUnicornAttack.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IERC721} from "IERC721.sol";
import {LibTwTShadowcornDefense} from "LibTwTShadowcornDefense.sol";
import {LibTwTUnicorn} from "LibTwTUnicorn.sol";
import {LibTwTModifier} from "LibTwTModifier.sol";
import {LibTwTSeason} from "LibTwTSeason.sol";
import {LibTwTRewards} from "LibTwTRewards.sol";
import {LibTwTAdmin} from "LibTwTAdmin.sol";
import {LibExternalAddress} from "LibExternalAddress.sol";
import {IUnicornStatCacheAdvanced, IUnicornStatCache} from "IUnicornStats.sol";
import {IUnicornERC721Facet } from "IUnicornERC721Facet.sol";
import {UnicornDNA} from "UnicornDNA.sol";
import {LibRNG} from "LibRNG.sol";
import {LibEvents} from "LibEvents.sol";
import {IMinionStats} from "IMinionStats.sol";
import {LibTwTWave} from "LibTwTWave.sol";
import {LibTwTMinions} from "LibTwTMinions.sol";
import {LibGasReturner} from "LibGasReturner.sol";
import {IShadowcornStatsFacet} from "IShadowcornStatsFacet.sol";

library LibTwTUnicornAttack {
    uint24 private constant BASE_COMBAT_RANGE = 75;
    uint24 private constant MAX_COMBAT_LUCK = 50;

    uint256 private constant UNICORN_GUIDE_KILL_SALT = 11;

    /// @notice Position to store the storage
    bytes32 private constant TWT_UNICORN_ATTACK_STORAGE_POSITION =
        keccak256("CryptoUnicorns.TwT.UnicornAttack.Storage");

    struct Match {
        // slot 1 (64+56+56+40+24+16)
        uint64 battleEndedTimestamp;
        uint56 matchId;
        uint56 dominationPointsUnicorns;
        uint40 shadowcornSquadId;
        uint24 unicornTeamStamina;
        uint16 seasonId;

        // slot 2
        uint56 dominationPointsShadowcorns;
        uint40 newSquadId;
        uint24 shadowcornTeamDamage;
        uint24 unicornTeamDamage;
        uint24 shadowcornTeamStamina;
        uint8 regionId;
        bool unicornTeamWon;
        bool leaderUnicornDied;
        address attackerAddress;

        // slot 3
        uint64[3] unicornIds;
        uint24[5] deadMinionPoolIds;
        uint24[5] deadMinionAmounts;

        // slot 4
        uint256 randomness;
    }

    struct LibTwTUnicornAttackStorage {
        uint40 lastSquadId;
        uint56 lastMatchId;
        mapping(uint40 => uint64[3]) squadById;
        mapping(uint256 => uint56) matchIdByVRFRequestId;
        mapping(uint56 => Match) matchById;
        mapping(uint64 => uint256) unicornLastBattleTimestampByTokenId;
        mapping(address => mapping(LibTwTRewards.FactionType => Match[])) matchesByPlayerAndSide;
        mapping(address => uint64[]) deadUnicornsByPlayer;
        mapping(address => mapping(uint24 => uint40)) deadMinionsByPlayerAndPoolId;
        mapping(uint16 => uint24) unicornNerfPercentageBySeason;
        mapping(uint16 seasonId => mapping(uint8 regionId => uint256 totalMatches)) totalMatchesBySeasonAndRegion;
    }

    function twtUnicornAttackStorage()
        private
        pure
        returns (LibTwTUnicornAttackStorage storage uas)
    {
        bytes32 position = TWT_UNICORN_ATTACK_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            uas.slot := position
        }
    }

    function twtGetMatchByVRFRequestId(uint256 vrfRequestId) internal returns(Match memory) {
        return twtUnicornAttackStorage().matchById[twtUnicornAttackStorage().matchIdByVRFRequestId[vrfRequestId]];
    }

    function enforceUnicornsAreValid(
        uint64[3] memory tokenIds,
        IUnicornStatCache.Stats[] memory unicornsInformation,
        address user
    ) private view {
        require(
            !unicornsInformation[0].gameLocked,
            "UA-011"
        );
        for (uint8 i = 0; i < 3; ++i) {
            if (tokenIds[i] > 0) {
                require(
                    unicornsInformation[i].lifecycleStage == uint8(UnicornDNA.LIFECYCLE_ADULT),
                    "UA-010"
                );
                require(
                    IUnicornERC721Facet(LibExternalAddress.getUnicornAddress()).ownerOf(tokenIds[i]) == user,
                    "UA-009"
                );
            }
        }
    }

    function enforceUnicornsAreNotCoolingDown(
        uint64[3] memory tokenIds
    ) internal view {
        for (uint8 i = 0; i < 3; ++i) {
            if (tokenIds[i] != 0) {
                require(
                    (twtUnicornAttackStorage().unicornLastBattleTimestampByTokenId[tokenIds[i]] +
                        LibTwTAdmin.twtGetUnicornAttackCooldown()) <
                        block.timestamp,
                    "UA-008"
                );
            }
        }
    }

    function setUnicornNerfPercentageForSeason(
        uint24 newPercentage,
        uint16 seasonId
    ) internal {
        require(
            newPercentage < 100,
            "UA-007"
        );
        twtUnicornAttackStorage().unicornNerfPercentageBySeason[
            seasonId
        ] = newPercentage;
    }

    function getUnicornNerfPercentageForSeason(
        uint16 seasonId
    ) internal view returns (uint24) {
        return
            twtUnicornAttackStorage().unicornNerfPercentageBySeason[seasonId];
    }

    function twtValidateUnicornAttack(
        uint16 seasonId,
        uint8 regionId,
        uint64[3] memory tokenIds
    ) internal view {
        require(
            LibTwTSeason.twtValidateSeasonState(
                seasonId,
                LibTwTSeason.TwTSeasonState.ACTIVE
            ),
            "UA-006"
        );

        require(
            tokenIds[0] != 0,
            "UA-005"
        );
        LibTwTRewards.enforceRegionIdIsValid(regionId);
        enforceUnicornsAreNotCoolingDown(tokenIds);
    }

    function twtUnicornAttackRegion(
        uint8 regionId,
        uint64[3] memory tokenIds,
        uint40 shadowcornSquadId
    ) internal {
        uint256 availableGas = gasleft();

        uint16 seasonId = LibTwTSeason.twtGetCurrentSeasonId();

        twtValidateUnicornAttack(seasonId, regionId, tokenIds);
        LibTwTUnicornAttackStorage storage uas = twtUnicornAttackStorage();
        address user = msg.sender;

        IUnicornStatCache.Stats[]
            memory unicornsInformation = twtGetUnicornsInfoMultipleAndValidate(
                tokenIds,
                regionId,
                user
            );

        LibTwTShadowcornDefense.ShadowcornSquad
            memory shadowcornSquad = LibTwTShadowcornDefense
                .twtGetShadowcornSquadById(shadowcornSquadId);

        twtValidateMinionSquadIsAttackable(
            seasonId,
            regionId,
            shadowcornSquadId,
            user
        );

        IERC721(LibExternalAddress.getUnicornAddress()).transferFrom(
            user,
            address(this),
            tokenIds[0]
        );

        ++uas.lastMatchId;
        Match memory matchData = twtUpdateMinionSquadStatusAndCreateMatch(
            seasonId,
            regionId,
            shadowcornSquadId,
            tokenIds,
            user
        );

        matchData = addDamageAndStaminaForBothTeamsToMatchAndEmitEvent(
            unicornsInformation,
            shadowcornSquad,
            regionId,
            matchData
        );

        uas.matchById[uas.lastMatchId] = matchData;

        // round simulation with max luck for shadowcorns and min luck for unicorns
        bool unicornsWin = simulateMatchWithMaxLuckForShadowcornTeam(matchData);
        if (unicornsWin) {
            matchData.unicornTeamDamage = ((matchData.unicornTeamDamage *
                (100 -
                    uas.unicornNerfPercentageBySeason[
                        LibTwTSeason.twtGetCurrentSeasonId()
                    ])) / 100);
        }

        twtFinalizeUnicornAttackRegion(
            tokenIds,
            regionId,
            seasonId,
            user,
            shadowcornSquadId
        );

        LibGasReturner.returnGasToUser(twtGetGasReturnerTransactionType(tokenIds), (availableGas - gasleft()), payable(user));
    }

    function twtGetGasReturnerTransactionType(uint64[3] memory tokenIds) private returns(LibGasReturner.GasReturnerTransactionType) {
        uint256[] memory castedTokenIds = new uint256[](tokenIds.length);

        for (uint8 i = 0; i < 3; ++i) {
            castedTokenIds[i] = uint256(tokenIds[i]);
        }

        (,bool[] memory cachedUnicorns) = IUnicornStatCache(LibExternalAddress.getUnicornAddress()).checkUnicornStatsCachedBatch(castedTokenIds);

        uint256 cachedUnicornsAmount = 0;

        for (uint256 j = 0 ; j < cachedUnicorns.length ; ++j) {
            if (cachedUnicorns[j]) {
                cachedUnicornsAmount++;
            }
        }

        if (cachedUnicornsAmount == 1) {
            return LibGasReturner.GasReturnerTransactionType.ATTACK_WITH_1_CACHED_UNICORN;
        }

        if (cachedUnicornsAmount == 2) {
            return LibGasReturner.GasReturnerTransactionType.ATTACK_WITH_2_CACHED_UNICORNS;
        }

        if (cachedUnicornsAmount == 3) {
            return LibGasReturner.GasReturnerTransactionType.ATTACK_WITH_3_CACHED_UNICORNS;
        }

        return LibGasReturner.GasReturnerTransactionType.ATTACK_WITH_NO_CACHED_UNICORNS;
    }

    function twtUpdateMinionSquadStatusAndCreateMatch(
        uint16 seasonId,
        uint8 regionId,
        uint40 shadowcornSquadId,
        uint64[3] memory tokenIds,
        address user
    ) internal view returns (Match memory matchData) {
        LibTwTUnicornAttackStorage storage uas = twtUnicornAttackStorage();
        matchData = Match({
            shadowcornSquadId: shadowcornSquadId,
            unicornIds: tokenIds,
            attackerAddress: user,
            regionId: regionId,
            seasonId: seasonId,
            shadowcornTeamDamage: 0,
            unicornTeamDamage: 0,
            shadowcornTeamStamina: 0,
            unicornTeamStamina: 0,
            battleEndedTimestamp: 0,
            unicornTeamWon: false,
            leaderUnicornDied: false,
            randomness: 0,
            dominationPointsUnicorns: 0,
            dominationPointsShadowcorns: 0,
            newSquadId: 0,
            deadMinionPoolIds: [
                uint24(0),
                uint24(0),
                uint24(0),
                uint24(0),
                uint24(0)
            ],
            deadMinionAmounts: [
                uint24(0),
                uint24(0),
                uint24(0),
                uint24(0),
                uint24(0)
            ],
            matchId: uas.lastMatchId
        });
    }

    function twtGetUnicornsInfoMultipleAndValidate(
        uint64[3] memory tokenIds,
        uint8 regionId,
        address user
    )
        private
        returns (IUnicornStatCache.Stats[] memory unicornsInformation)
    {
        // Create temp array for casting tokenIds to uint256
        uint256[] memory tempTokenIds = new uint256[](3);
        uint256 nonZeroUnicornTokenIds = 0;
        for (uint8 i = 0; i < 3; ++i) {
            if(tokenIds[i] == 0) {
                break;
            }
            nonZeroUnicornTokenIds++;
            tempTokenIds[i] = uint256(tokenIds[i]);
        }

        assembly {
            mstore(tempTokenIds, nonZeroUnicornTokenIds)
        }

        unicornsInformation = IUnicornStatCacheAdvanced(
            LibExternalAddress.getUnicornAddress()
        ).getAndCacheUnicornEnhancedStatsBatch(
                tempTokenIds
            );

        enforceUnicornsAreValid(tokenIds, unicornsInformation, user);
    }

    function twtValidateMinionSquadIsAttackable(
        uint16 seasonId,
        uint8 regionId,
        uint40 shadowcornSquadId,
        address user
    ) internal view {
        // require squad is deployed in the region
        require(
            LibTwTMinions.twtGetMinionSquadIdxInArray(
                seasonId,
                regionId,
                shadowcornSquadId
            ) != 0,
            "UA-004"
        );

        require(
            LibTwTUnicorn.twtCanCombatMinionSquad(
                regionId,
                shadowcornSquadId,
                user
            ),
            "UA-003"
        );
    }

    function twtFinalizeUnicornAttackRegion(
        uint64[3] memory tokenIds,
        uint8 regionId,
        uint16 seasonId,
        address user,
        uint40 shadowcornSquadId
    ) internal {
        LibTwTUnicornAttackStorage storage uas = twtUnicornAttackStorage();
        uint256 vrfReqId = LibRNG.requestRandomWordsFor(
            LibRNG.RNG_UNICORN_ATTACK_REGION
        );
        uas.matchIdByVRFRequestId[vrfReqId] = uas.lastMatchId;
        setUnicornsCooldown(tokenIds);
        uas.totalMatchesBySeasonAndRegion[seasonId][regionId]++;
        emit LibEvents.TwTBeginUnicornAttackRegion(
            uas.lastMatchId,
            vrfReqId,
            user,
            regionId,
            tokenIds,
            shadowcornSquadId
        );
    }

    function setUnicornsCooldown(uint64[3] memory tokenIds) internal {
        for (uint8 i = 0; i < 3; ++i) {
            if (tokenIds[i] != 0) {
                twtUnicornAttackStorage().unicornLastBattleTimestampByTokenId[
                    tokenIds[i]
                ] = block.timestamp;
            }
        }
    }

    function simulateMatchWithMaxLuckForShadowcornTeam(
        Match memory matchData
    ) private pure returns (bool unicornsWin) {
        unicornsWin = uint256(matchData.unicornTeamStamina / ((matchData.shadowcornTeamDamage * 125) / 100)) >
            uint256(matchData.shadowcornTeamStamina / ((matchData.unicornTeamDamage * 75) / 100));
    }

    struct DamageCalculationExtraInfo {
        uint24 basicShadowcornTeamDamage;
        uint24 shadowcornTeamRPSBonus;
        uint24 basicUnicornTeamDamage;
        uint24 unicornTeamRPSBonus;
        uint24 totalUnicornStats;
        uint24[] totalModifiersPerUnicorn;
        uint24[] totalStatsPerUnicorn;
    }

    function addDamageAndStaminaForBothTeamsToMatchAndEmitEvent(
        IUnicornStatCache.Stats[] memory unicornsInformation,
        LibTwTShadowcornDefense.ShadowcornSquad memory shadowcornSquad,
        uint8 regionId,
        Match memory matchData
    ) private returns (Match memory) {
        DamageCalculationExtraInfo memory extraInfo;
        (matchData, extraInfo) = addDamageAndStaminaForBothTeamsToMatch(
            unicornsInformation,
            shadowcornSquad,
            regionId,
            matchData
        );

        emit LibEvents.TwTDamageCalculationExtraInfo(extraInfo);
        return matchData;
    }

    function getTotalStatsForUnicorns(
        IUnicornStatCache.Stats[] memory unicornsInformation,
        uint256[] memory relevantUnicornStats
    ) internal pure returns (uint256 totalStats) {
        for (uint8 i = 0; i < unicornsInformation.length; ++i) {
            totalStats += getTotalStatsForUnicorn(unicornsInformation[i], relevantUnicornStats);
        }
    }

    function getTotalStatsForUnicorn(IUnicornStatCache.Stats memory unicornInformation, uint256[] memory relevantUnicornStats) private pure returns(uint256 totalStats) {
        for (uint8 i = 0 ; i < relevantUnicornStats.length ; ++i) {
            if (relevantUnicornStats[i] == UnicornDNA.STAT_ATTACK) {
                totalStats += unicornInformation.attack;
                continue;
            }
            if (relevantUnicornStats[i] == UnicornDNA.STAT_ACCURACY) {
                totalStats += unicornInformation.accuracy;
                continue;
            }
            if (relevantUnicornStats[i] == UnicornDNA.STAT_MOVE_SPEED) {
                totalStats += unicornInformation.moveSpeed;
                continue;
            }
            if (relevantUnicornStats[i] == UnicornDNA.STAT_ATTACK_SPEED) {
                totalStats += unicornInformation.attackSpeed;
                continue;
            }
            if (relevantUnicornStats[i] == UnicornDNA.STAT_DEFENSE) {
                totalStats += unicornInformation.defense;
                continue;
            }
            if (relevantUnicornStats[i] == UnicornDNA.STAT_VITALITY) {
                totalStats += unicornInformation.vitality;
                continue;
            }
            if (relevantUnicornStats[i] == UnicornDNA.STAT_RESISTANCE) {
                totalStats += unicornInformation.resistance;
                continue;
            }
            if (relevantUnicornStats[i] == UnicornDNA.STAT_MAGIC) {
                totalStats += unicornInformation.magic;
                continue;
            }
        }
    }

    function addDamageAndStaminaForBothTeamsToMatch(
        IUnicornStatCache.Stats[] memory unicornsInformation,
        LibTwTShadowcornDefense.ShadowcornSquad memory shadowcornSquad,
        uint8 regionId,
        Match memory matchData
    )
        private
        view
        returns (Match memory, DamageCalculationExtraInfo memory extraInfo)
    {
        (
            extraInfo.shadowcornTeamRPSBonus,
            extraInfo.unicornTeamRPSBonus
        ) = LibTwTModifier.getRPSModifier(unicornsInformation, shadowcornSquad);
        extraInfo.basicShadowcornTeamDamage = uint24(
            (
                uint256(shadowcornSquad.totalStats) *
                    uint256(
                        10000 +
                            extraInfo.shadowcornTeamRPSBonus +
                            shadowcornSquad.damageModifiers
                    )
            ) / 10000
        );

        matchData.shadowcornTeamStamina = uint24(
            (
                uint256(shadowcornSquad.totalStats) *
                    uint256(
                        10000 +
                            shadowcornSquad.staminaModifiers +
                            extraInfo.shadowcornTeamRPSBonus
                    )
            ) / 10000
        );

        // calc unicorn team damage and stamina
        extraInfo.basicUnicornTeamDamage = 0;
        extraInfo.totalModifiersPerUnicorn = new uint24[](
            unicornsInformation.length
        );
        extraInfo.totalStatsPerUnicorn = new uint24[](
            unicornsInformation.length
        );

        uint256[]
            memory relevantUnicornStats = getRelevantUnicornStatsForRegion(
                regionId
            );

        for (uint256 i = 0; i < unicornsInformation.length; ++i) {
            matchData.unicornTeamStamina += getStaminaForUnicorn(
                unicornsInformation[i].mythicCount
            );
            extraInfo.totalModifiersPerUnicorn[i] = LibTwTModifier
                .twtGetTotalModifiersAmountForUnicorn(
                    unicornsInformation[i],
                    regionId
                );
            extraInfo.totalStatsPerUnicorn[i] = uint24(getTotalStatsForUnicorn(unicornsInformation[i], relevantUnicornStats));
            extraInfo.basicUnicornTeamDamage += uint24(
                (
                    (uint256(extraInfo.totalStatsPerUnicorn[i]) *
                            uint256(10000 +
                                extraInfo.totalModifiersPerUnicorn[i] +
                                extraInfo.unicornTeamRPSBonus))
                / 10000)
            );
        }

        // shadowcornTeamDamage = Minion Damage * (1+((Minion Damage/Unicorn Damage)/10))
        // unicornTeamDamage = Unicorn Damage * (1+((Unicorn Damage/Minion Damage)/10))
        matchData.unicornTeamDamage = uint24(
            (
                uint256(extraInfo.basicUnicornTeamDamage) *
                    (1000 +
                        ((uint256(extraInfo.basicUnicornTeamDamage) * 1000) /
                        uint256(extraInfo.basicShadowcornTeamDamage)) /
                    10) / 1000
            )
        );

        matchData.shadowcornTeamDamage = uint24(
            (
                uint256(extraInfo.basicShadowcornTeamDamage) *
                    (1000 +
                        ((uint256(extraInfo.basicShadowcornTeamDamage) * 1000) /
                        uint256(extraInfo.basicUnicornTeamDamage)) /
                    10) / 1000
            )
        );

        return (matchData, extraInfo);
    }

    function getStaminaForUnicorn(
        uint8 amountOfMythicParts
    ) private pure returns (uint24) {
        // Nonmythic: 2000 Stamina
        // Single mythic: 2100 Stamina
        // Double mythic: 2300 Stamina
        // Triple Mythic: 2600 Stamina
        // Quad Mythic: 3000 Stamina
        // Epic Mythic: 3500 Stamina
        // Legendary Mythic: 4100 Stamina
        if (amountOfMythicParts == 0) {
            return 2000;
        }
        if (amountOfMythicParts == 1) {
            return 2100;
        }
        if (amountOfMythicParts == 2) {
            return 2300;
        }
        if (amountOfMythicParts == 3) {
            return 2600;
        }
        if (amountOfMythicParts == 4) {
            return 3000;
        }
        if (amountOfMythicParts == 5) {
            return 3500;
        }
        if (amountOfMythicParts == 6) {
            return 4100;
        }
        return 0;
    }

    function getRelevantUnicornStatsForRegion(
        uint8 regionId
    ) private pure returns (uint256[] memory unicornStatsRequired) {
        if (regionId == 1) {
            //fire region
            unicornStatsRequired = new uint256[](3);
            unicornStatsRequired[0] = UnicornDNA.STAT_MOVE_SPEED;
            unicornStatsRequired[1] = UnicornDNA.STAT_ATTACK_SPEED;
            unicornStatsRequired[2] = UnicornDNA.STAT_RESISTANCE;
        }
        if (regionId == 2) {
            //slime region
            unicornStatsRequired = new uint256[](3);
            unicornStatsRequired[0] = UnicornDNA.STAT_MAGIC;
            unicornStatsRequired[1] = UnicornDNA.STAT_RESISTANCE;
            unicornStatsRequired[2] = UnicornDNA.STAT_ATTACK;
        }
        if (regionId == 3) {
            // volt region
            unicornStatsRequired = new uint256[](3);
            unicornStatsRequired[0] = UnicornDNA.STAT_ATTACK;
            unicornStatsRequired[1] = UnicornDNA.STAT_ACCURACY;
            unicornStatsRequired[2] = UnicornDNA.STAT_ATTACK_SPEED;
        }
        if (regionId == 4) {
            // soul region
            unicornStatsRequired = new uint256[](3);
            unicornStatsRequired[0] = UnicornDNA.STAT_DEFENSE;
            unicornStatsRequired[1] = UnicornDNA.STAT_VITALITY;
            unicornStatsRequired[2] = UnicornDNA.STAT_MAGIC;
        }
        if (regionId == 5) {
            // nebula region
            unicornStatsRequired = new uint256[](4);
            unicornStatsRequired[0] = UnicornDNA.STAT_MOVE_SPEED;
            unicornStatsRequired[1] = UnicornDNA.STAT_DEFENSE;
            unicornStatsRequired[2] = UnicornDNA.STAT_VITALITY;
            unicornStatsRequired[3] = UnicornDNA.STAT_ACCURACY;
        }
    }

    function twtGetMatchHistory(
        address user,
        LibTwTRewards.FactionType side,
        uint32 _pageNumber
    )
        internal
        view
        returns (
            LibTwTUnicornAttack.Match[] memory matches,
            bool moreEntriesExist,
            uint256 totalEntries
        )
    {
        require(
            side != LibTwTRewards.FactionType.NONE,
            "UA-002"
        );

        Match[] memory playerSideMatches = twtUnicornAttackStorage()
            .matchesByPlayerAndSide[user][side];
        totalEntries = playerSideMatches.length;

        uint start = _pageNumber * 12;
        uint count = totalEntries - start;

        if (count > 12) {
            count = 12;
            moreEntriesExist = true;
        }

        matches = new Match[](count);

        for (uint i = 0; i < count; ++i) {
            uint256 index = start + i;

            matches[i] = playerSideMatches[index];
        }
    }

    function twtGetDeadUnicornsByUser(
        address user,
        uint32 _pageNumber
    )
        internal
        view
        returns (
            uint64[] memory unicornIds,
            bool moreEntriesExist,
            uint256 totalEntries
        )
    {
        uint64[] memory deadUnicornsByPlayer = twtUnicornAttackStorage()
            .deadUnicornsByPlayer[user];
        totalEntries = deadUnicornsByPlayer.length;
        uint256 start = _pageNumber * 12;
        uint256 count = totalEntries - start;

        if (count > 12) {
            count = 12;
            moreEntriesExist = true;
        }

        unicornIds = new uint64[](count);

        for (uint256 i = 0; i < count; ++i) {
            uint256 index = start + i;
            unicornIds[i] = deadUnicornsByPlayer[index];
        }
    }

    function twtGetDeadMinionsByUser(
        address user
    )
        internal
        view
        returns (
            uint24[] memory deadMinionPools,
            uint40[] memory deadMinionQuantities
        )
    {
        LibTwTUnicornAttackStorage storage uas = twtUnicornAttackStorage();
        deadMinionPools = LibTwTAdmin.twtGetMinionPoolIds();
        uint256 length = deadMinionPools.length;
        deadMinionQuantities = new uint40[](length);
        for (uint256 i = 0; i < length; i++) {
            deadMinionQuantities[i] = uas.deadMinionsByPlayerAndPoolId[user][
                deadMinionPools[i]
            ];
        }
    }

    function twtGetMatchById(
        uint56 matchId
    ) internal view returns (LibTwTUnicornAttack.Match memory) {
        return twtUnicornAttackStorage().matchById[matchId];
    }

    function popFromMemoryUint24Array(
        uint24[] memory array
    ) internal pure returns (uint24[] memory) {
        require(array.length > 0, "GA-002");
        assembly {
            mstore(array, sub(mload(array), 1))
        }
        return array;
        // Some important points to remember:

        // Make sure this assembly code never runs when backerList.length == 0 (don't allow the array length to underflow)

        // Don't try to use this to increase the size of an array (by replacing sub with add)

        // Only use it on variables with a type like ...[] memory (for example, don't use it on a address[10] memory or address)

        // Disclaimer: The use of inline assembly is usually not recommended. Use it with caution and at your own risk :)
        // source: https://ethereum.stackexchange.com/questions/51891/how-to-pop-from-decrease-the-length-of-a-memory-array-in-solidity
    }

    function popFromMemoryArray(
        uint256[] memory array
    ) internal pure returns (uint256[] memory) {
        require(array.length > 0, "GA-001");
        assembly {
            mstore(array, sub(mload(array), 1))
        }
        return array;
        // Some important points to remember:

        // Make sure this assembly code never runs when backerList.length == 0 (don't allow the array length to underflow)

        // Don't try to use this to increase the size of an array (by replacing sub with add)

        // Only use it on variables with a type like ...[] memory (for example, don't use it on a address[10] memory or address)

        // Disclaimer: The use of inline assembly is usually not recommended. Use it with caution and at your own risk :)
        // source: https://ethereum.stackexchange.com/questions/51891/how-to-pop-from-decrease-the-length-of-a-memory-array-in-solidity
    }

    // TODO: change to private
    function twtGetMatchAndUnicornSquadDetails(
        uint256 vrfReqId
    )
        internal
        view
        returns (
            Match memory matchDetail
        )
    {
        LibTwTUnicornAttackStorage storage uas = twtUnicornAttackStorage();

        uint56 matchId = uas.matchIdByVRFRequestId[vrfReqId];
        require(matchId != 0, "UA-001");

        matchDetail = uas.matchById[matchId];
    }

    function twtUnicornAttackRegionFulfillRandomness(
        uint256 vrfReqId,
        uint256 randomness
    ) internal {
        (
            Match memory matchDetail
        ) = twtGetMatchAndUnicornSquadDetails(vrfReqId);

        LibRNG.setPlayerSeed(matchDetail.attackerAddress, randomness);

        matchDetail.randomness = randomness;

        (
            bool unicornsWon,
            uint24 unicornsDamageDealt,
            uint24 shadowcornsDamageDealt
        ) = combatSquads(
                matchDetail.shadowcornTeamDamage,
                matchDetail.unicornTeamDamage,
                matchDetail.shadowcornTeamStamina,
                matchDetail.unicornTeamStamina,
                matchDetail.randomness
            );

        matchDetail.unicornTeamWon = unicornsWon;
        LibTwTShadowcornDefense.ShadowcornSquad
            memory squad = LibTwTShadowcornDefense.twtGetShadowcornSquadById(
                matchDetail.shadowcornSquadId
            );

        LibTwTShadowcornDefense.twtRemoveMinionSquadFromUserSquads(
            squad.sender,
            squad.squadId
        );

        if (unicornsWon) {
            (
                matchDetail
            ) = resolveUnicornTeamWinnerCase(
                unicornsDamageDealt,
                shadowcornsDamageDealt,
                matchDetail,
                squad.poolIds,
                squad.minionAmounts,
                squad.sender
            );
        } else {
            (
              matchDetail
            ) = resolveShadowcornTeamWinnerCase(
                unicornsDamageDealt,
                shadowcornsDamageDealt,
                squad,
                matchDetail
            );
        }

        // set minion squad chosen for combat to false
        LibTwTMinions.twtSetMinionSquadIsChosenForCombat(
            matchDetail.shadowcornSquadId,
            false
        );

        // add unicorn combat points
        LibTwTRewards.twtAddUnicornCombatPts(
            matchDetail.seasonId,
            matchDetail.regionId,
            matchDetail.dominationPointsUnicorns,
            matchDetail.attackerAddress
        );

        // add shadowcorn combat points
        LibTwTRewards.twtAddShadowcornCombatPts(
            matchDetail.seasonId,
            matchDetail.regionId,
            matchDetail.shadowcornSquadId,
            matchDetail.dominationPointsShadowcorns,
            squad.sender
        );

        twtUpdateFinishedMatch(
            squad.sender,
            matchDetail
        );

        emit LibEvents.TwTFinishUnicornAttackRegion(
            matchDetail.matchId,
            vrfReqId,
            matchDetail.attackerAddress,
            matchDetail,
            unicornsDamageDealt,
            shadowcornsDamageDealt
        );
    }

    function resolveShadowcornTeamWinnerCase(
        uint24 unicornsDamageDealt,
        uint24 shadowcornsDamageDealt,
        LibTwTShadowcornDefense.ShadowcornSquad memory squad,
        Match memory matchDetail
    ) internal returns (
        Match memory
    ) {
        (uint32 winnerMultiplier, uint32 loserMultiplier) = LibTwTAdmin
            .twtGetDominationPointsWinnerAndLoserMultiplierForCurrentSeason();
        matchDetail.dominationPointsUnicorns = uint56(
            (uint256(unicornsDamageDealt) * uint256(loserMultiplier) / 10000)
        );

        matchDetail.dominationPointsShadowcorns = uint56(
            (uint256(shadowcornsDamageDealt) * uint256(winnerMultiplier) / 10000)
        );

        (
            matchDetail
        ) = regroupNewSquad(
            squad,
            matchDetail,
            unicornsDamageDealt
        );

        //Roll to kill guide unicorn
        uint256 killChance = 0;
        for (uint256 i = 0; i < squad.poolIds.length; ++i) {
            if (squad.poolIds[i] > 0) {
                killChance += (LibTwTAdmin
                    .twtGetMinionPoolChanceToKillUnicornLeaderBySeason(
                        squad.poolIds[i],
                        matchDetail.seasonId
                    ) * squad.minionAmounts[i]);
            }
        }

        if (
            LibRNG.expand(100, matchDetail.randomness, UNICORN_GUIDE_KILL_SALT) <
            killChance
        ) {
            IERC721(LibExternalAddress.getUnicornAddress()).transferFrom(
                address(this),
                LibExternalAddress.getDeadWalletAddress(),
                matchDetail.unicornIds[0]
            );
            matchDetail.leaderUnicornDied = true;
            twtUnicornAttackStorage().deadUnicornsByPlayer[matchDetail.attackerAddress].push(
                matchDetail.unicornIds[0]
            );
        } else {
            returnLeaderToUser(
                matchDetail.attackerAddress,
                matchDetail.unicornIds[0]
            );
        }
        return matchDetail;
    }

    function resolveUnicornTeamWinnerCase(
        uint24 unicornsDamageDealt,
        uint24 shadowcornsDamageDealt,
        Match memory matchDetail,
        uint24[5] memory squadPoolids,
        uint24[5] memory squadMinionAmounts,
        address squadSender
    ) private returns(
        Match memory
    )   {
            (uint32 winnerMultiplier, uint32 loserMultiplier) = LibTwTAdmin
            .twtGetDominationPointsWinnerAndLoserMultiplierForCurrentSeason();
            matchDetail.dominationPointsUnicorns = uint56(
                (uint256(unicornsDamageDealt) * uint256(winnerMultiplier) / 10000)
            );
            matchDetail.dominationPointsShadowcorns = uint56(
                (uint256(shadowcornsDamageDealt) * uint256(loserMultiplier) / 10000)
            );
            // Shadowcorn squad is already removed from minionSquadIdsArray.
            returnLeaderToUser(
                matchDetail.attackerAddress,
                matchDetail.unicornIds[0]
            );

            for (uint256 i = 0; i < squadPoolids.length; ++i) {
                matchDetail.deadMinionPoolIds[i] = squadPoolids[i];
                matchDetail.deadMinionAmounts[i] = squadMinionAmounts[i];

                twtUnicornAttackStorage().deadMinionsByPlayerAndPoolId[squadSender][
                    squadPoolids[i]
                ] += squadMinionAmounts[i];
            }
        return matchDetail;
    }

    // TODO: change to private
    function twtUpdateFinishedMatch(
        address shadowcornUser,
        Match memory matchDetail
    ) internal {
        LibTwTUnicornAttackStorage storage uas = twtUnicornAttackStorage();

        matchDetail.battleEndedTimestamp = uint64(block.timestamp);
        uas
        .matchesByPlayerAndSide[matchDetail.attackerAddress][LibTwTRewards.FactionType.UNICORN]
            .push(matchDetail);
        uas
        .matchesByPlayerAndSide[shadowcornUser][
            LibTwTRewards.FactionType.SHADOWCORN
        ].push(matchDetail);
        uas.matchById[matchDetail.matchId] = matchDetail;
    }

    function getUpdatedMinionsToKill(
        uint24[5] memory squadPoolIds,
        uint24[5] memory squadMinionAmounts,
        uint24 unicornsDamageDealt,
        uint24 shadowcornTeamStamina
    ) internal view returns (NewSquadInformation memory newSquadInformation) {
        for (uint256 i = 0; i < squadPoolIds.length; ++i) {
            newSquadInformation.squadMinionQuantity += squadMinionAmounts[i];
            newSquadInformation.newSquadPoolIds[i] = squadPoolIds[i];
            newSquadInformation.newSquadMinionAmounts[i] = squadMinionAmounts[
                i
            ];
        }
       
        newSquadInformation.minionsToKill =
            unicornsDamageDealt /
            (shadowcornTeamStamina /
                newSquadInformation.squadMinionQuantity);

        // TODO: Check if this is correct. We should always have minionsToKill up to (squadMinionQuantity-1) but not more than that quantity.
        if (
            newSquadInformation.minionsToKill >=
            newSquadInformation.squadMinionQuantity
        ) {
            newSquadInformation.minionsToKill =
                newSquadInformation.squadMinionQuantity -
                1;
        }
    }

    struct NewSquadInformation {
        uint24 newSquadSize;
        uint24 squadMinionQuantity;
        uint24 minionsToKill;
        uint24[5] newSquadPoolIds;
        uint24[5] newSquadMinionAmounts;
    }

    struct NewSquadOverseerData {
        uint256 shadowcornOverseerClass;
        uint256 shadowcornOverseerRarity;
        IMinionStats.MinionStats[] minionStats;
        uint8[] minionClasses;
    } 

    struct NewSquadTotals {
        uint24 totalStats;
        uint24 damageModifiers;
        uint24 staminaModifiers;
    }

    function regroupNewSquad(
        LibTwTShadowcornDefense.ShadowcornSquad memory squad,
        Match memory matchDetail,
        uint24 unicornsDamageDealt
    )
        internal
        returns (
            Match memory
        )
    {
        NewSquadInformation
            memory newSquadInformation = getUpdatedMinionsToKill(
                squad.poolIds,
                squad.minionAmounts,
                unicornsDamageDealt,
                matchDetail.shadowcornTeamStamina
            );

        uint40[5] memory priorUserDeadMinions = getDeadMinionsByPools(squad.poolIds, squad.sender);

        (
            newSquadInformation
        ) = killMinionsAndUpdateNewSquadInformation(
            newSquadInformation,
            matchDetail
        );

        uint256 nonZeroMinionAmounts;
        uint40[5] memory postUserDeadMinions = getDeadMinionsByPools(squad.poolIds, squad.sender);
        (
            newSquadInformation,
            matchDetail,
            nonZeroMinionAmounts
        ) = updateNewSquadMinionAmounts(
            priorUserDeadMinions,
            postUserDeadMinions,
            newSquadInformation,
            matchDetail,
            squad.minionAmounts,
            squad.poolIds
        );
        
        
        NewSquadOverseerData memory newSquadOverseerData = getMinionStatsAndOverseerData(
            newSquadInformation,
            squad.shadowcornOverseerTokenId
        );

        NewSquadTotals memory newSquadTotals;
        for (uint256 i = 0; i < nonZeroMinionAmounts; ++i) {
            (
                newSquadTotals.totalStats,
                newSquadTotals.damageModifiers,
                newSquadTotals.staminaModifiers
            ) = LibTwTShadowcornDefense.twtUpdateMinionSquadStatsAndModifiers(
                LibTwTShadowcornDefense.ShadowcornSquadInformation({
                    totalStats: newSquadTotals.totalStats,
                    damageModifiers: newSquadTotals.damageModifiers,
                    staminaModifiers: newSquadTotals.staminaModifiers,
                    minionAmounts: newSquadInformation.newSquadMinionAmounts[i],
                    squadSize: newSquadInformation.newSquadSize,
                    minionStats: newSquadOverseerData.minionStats[i],
                    minionClass: newSquadOverseerData.minionClasses[i]
                }),
                matchDetail.regionId,
                newSquadOverseerData.shadowcornOverseerClass,
                newSquadOverseerData.shadowcornOverseerRarity
            );
        }

        LibTwTShadowcornDefense.LibTwTShadowcornDefenseStorage
            storage sds = LibTwTShadowcornDefense.twtShadowcornDefenseStorage();
        sds.lastSquadId++;

        // add new shadowcornSquad
        sds.squadById[sds.lastSquadId] = LibTwTShadowcornDefense.ShadowcornSquad({
                squadId: sds.lastSquadId,
                shadowcornOverseerTokenId: squad.shadowcornOverseerTokenId,
                poolIds: newSquadInformation.newSquadPoolIds,
                minionAmounts: newSquadInformation.newSquadMinionAmounts,
                minionClasses: newSquadOverseerData.minionClasses,
                sender: squad.sender,
                totalStats: newSquadTotals.totalStats,
                damageModifiers: newSquadTotals.damageModifiers,
                staminaModifiers: newSquadTotals.staminaModifiers,
                seasonId: matchDetail.seasonId,
                regionId: matchDetail.regionId
            });
        LibTwTMinions.twtAddMinionSquadToArray(
            matchDetail.seasonId,
            matchDetail.regionId,
            sds.lastSquadId
        );

        LibTwTShadowcornDefense.twtAddMinionSquadToUserSquads(
            squad.sender,
            sds.lastSquadId
        );
        LibTwTMinions.twtSetPartiallyKilledMinionSquadUnlockableWaveId(
            sds.lastSquadId,
            LibTwTMinions
            .twtGetMinionSquadUnlockableWaveId(squad.squadId)
        );

        matchDetail.newSquadId = sds.lastSquadId;
        return matchDetail;
    }

    function updateNewSquadMinionAmounts(
        uint40[5] memory priorUserDeadMinions,
        uint40[5] memory postUserDeadMinions,
        NewSquadInformation memory newSquadInformation,
        Match memory matchDetail,
        uint24[5] memory squadMinionAmounts,
        uint24[5] memory squadPoolIds
    ) internal returns (
        NewSquadInformation memory,
        Match memory,
        uint256 nonZeroMinionAmounts
    )  {
        uint24 newDeadMinionsDifference;
        uint24 newSquadSize;
        uint24 newSquadMinionAmount;
        nonZeroMinionAmounts = 1;
        for(uint256 i =0; i < priorUserDeadMinions.length; ++i) {
            newDeadMinionsDifference = uint24(postUserDeadMinions[i] - priorUserDeadMinions[i]);
            matchDetail.deadMinionAmounts[i] = newDeadMinionsDifference;
            newSquadMinionAmount = squadMinionAmounts[i] - newDeadMinionsDifference;
            if (newSquadMinionAmount > 0) {
                newSquadInformation.newSquadPoolIds[nonZeroMinionAmounts-1] = squadPoolIds[i];
                newSquadInformation.newSquadMinionAmounts[nonZeroMinionAmounts-1] = newSquadMinionAmount;
                nonZeroMinionAmounts++;
                newSquadSize += newSquadMinionAmount;    
            }
        }
        newSquadInformation.newSquadSize = newSquadSize;
        return (newSquadInformation, matchDetail, nonZeroMinionAmounts);
    }

    function getDeadMinionsByPools(uint24[5] memory poolIds, address player) internal view returns (uint40[5] memory deadMinions) {
        for(uint256 i = 0; i < poolIds.length; ++i) {
        LibTwTUnicornAttackStorage storage uas = twtUnicornAttackStorage();
            deadMinions[i] = uas.deadMinionsByPlayerAndPoolId[player][poolIds[i]];
        }
    }

    function killMinionsAndUpdateNewSquadInformation(
        NewSquadInformation memory newSquadInformation,
        Match memory matchDetail
    ) internal returns (
        NewSquadInformation memory
    ) {
        uint256 classToKill;
        uint256 i = 0;
        while (newSquadInformation.minionsToKill > 0) {
            classToKill = LibRNG.expand(
                5,
                matchDetail.randomness,
                i
            );
            if (newSquadInformation.newSquadMinionAmounts[classToKill] != 0) {
                newSquadInformation.newSquadMinionAmounts[classToKill] -= 1;
                twtUnicornAttackStorage().deadMinionsByPlayerAndPoolId[
                    matchDetail.attackerAddress
                ][newSquadInformation.newSquadPoolIds[classToKill]] += 1;
                newSquadInformation.minionsToKill--;
            }
            ++i;
        }
        return newSquadInformation;
    }

    function getMinionStatsAndOverseerData(
        NewSquadInformation memory newSquadInformation,
        uint256 shadowcornOverseerTokenId
    ) internal view returns (
        NewSquadOverseerData memory overseerData
    ) {
        // TODO: This code is repeated and could generate future bugs, we should abstract this piece in LibTwTShadowcornDefense.
        uint256[] memory castedNewSquadPoolIds = new uint256[](
            newSquadInformation.newSquadPoolIds.length
        );

        for (uint256 j = 0; j < castedNewSquadPoolIds.length; ++j) {
            castedNewSquadPoolIds[j] = uint256(
                newSquadInformation.newSquadPoolIds[j]
            );
        }

        (
            overseerData.minionStats,
            overseerData.minionClasses
        ) = IMinionStats(LibExternalAddress.getShadowcornItemsAddress())
                .getMinionPoolStatsAndClassesMultiple(castedNewSquadPoolIds);

        // TODO: Get this 2 things in one call.
        (
            overseerData.shadowcornOverseerClass,
            overseerData.shadowcornOverseerRarity,
        ) = IShadowcornStatsFacet(LibExternalAddress.getShadowcornAddress())
                .getClassRarityAndStat(shadowcornOverseerTokenId, 0);
    }

    function returnLeaderToUser(address user, uint256 tokenId) internal {
        IERC721(LibExternalAddress.getUnicornAddress()).transferFrom(
            address(this),
            user,
            tokenId
        );
    }

    function twtGetTodayShadowcornDominationPointsForAllRegions(
        uint16 seasonId
    ) internal view returns (uint56[5] memory unicornDominationPoints) {
        uint256 waveId = LibTwTWave.twtGetCurrentWaveId();
        for (uint8 i = 1; i < 6; ++i) {
            unicornDominationPoints[i - 1] = LibTwTRewards
                .twtGetUnicornDominationPointsBySeasonRegionAndWave(
                    seasonId,
                    i,
                    waveId
                );
        }
    }

    struct Combat {
        uint32 roundId;
        uint24 shadowcornTeamRoundDamage;
        uint24 unicornTeamRoundDamage;
        bool ended;
    }

    // TODO: change to private
    function combatSquads(
        uint24 shadowcornTeamDamage,
        uint24 unicornTeamDamage,
        uint24 staminaShadowcorns,
        uint24 staminaUnicorns,
        uint256 randomness
    )
        internal
        pure
        returns (
            bool unicornsWon,
            uint24 unicornsDamageDealt,
            uint24 shadowcornsDamageDealt
        )
    {
        Combat memory combat;
        while (!combat.ended) {
            // Multiply by 2 the salt for each side to ensure different values on each round
            combat.shadowcornTeamRoundDamage =
                uint24(
                    (
                        uint256(shadowcornTeamDamage) *
                        uint256(
                            (BASE_COMBAT_RANGE + LibRNG.expand(MAX_COMBAT_LUCK, randomness, 2 * combat.roundId))
                        )
                    ) / 100);

            combat.unicornTeamRoundDamage =
                uint24(
                    (
                        uint256(unicornTeamDamage) *
                        uint256(
                            (BASE_COMBAT_RANGE + LibRNG.expand(MAX_COMBAT_LUCK, randomness, (2 * combat.roundId) + 1))
                        )
                    ) / 100);

            unicornsDamageDealt += combat.unicornTeamRoundDamage;
            shadowcornsDamageDealt += combat.shadowcornTeamRoundDamage;

            //TODO: check if we can make this logic shorter
            if (
                combat.unicornTeamRoundDamage >= staminaShadowcorns ||
                combat.shadowcornTeamRoundDamage >= staminaUnicorns
            ) {
                combat.ended = true;
                if (combat.unicornTeamRoundDamage >= staminaShadowcorns) {
                    if (combat.shadowcornTeamRoundDamage >= staminaUnicorns) {
                        unicornsWon =
                            (combat.unicornTeamRoundDamage -
                                staminaShadowcorns) >
                            (combat.shadowcornTeamRoundDamage -
                                staminaUnicorns);
                    } else {
                        unicornsWon = true;
                    }
                } else {
                    unicornsWon = false;
                }
            } else {
                staminaShadowcorns -= combat.unicornTeamRoundDamage;
                staminaUnicorns -= combat.shadowcornTeamRoundDamage;
            }

            ++combat.roundId;
        }
    }

    struct BattlePreview {
        uint24 unicornTeamStamina;
        uint24 shadowcornTeamStamina;
        uint24 unicornTeamMinDamage;
        uint24 unicornTeamMaxDamage;
        uint24 shadowcornTeamMinDamage;
        uint24 shadowcornTeamMaxDamage;
        uint24 rpsUnicornTeamDamage;
        uint24 rpsShadowcornTeamDamage;
        uint24 shadowcornTeamDamage;
        uint24 unicornTeamDamage;
        DamageCalculationExtraInfo damageCalculationExtraInfo;
    }

    function twtGetBattlePreview(
        uint40 shadowcornSquadId,
        uint64[3] memory unicornTokenIds,
        uint8 regionId
    ) internal view returns (BattlePreview memory preview) {
        uint256[]
            memory relevantUnicornStats = getRelevantUnicornStatsForRegion(
                regionId
            );

        // using uint256 since this value is sent to an external contract that uses uint256
        uint256[] memory castedUnicornTokenIds = new uint256[](3);
        uint256 nonZeroUnicornids = 0;
        for (uint256 i = 0; i < castedUnicornTokenIds.length; ++i) {
            if(unicornTokenIds[i] == 0) {
                break;
            }
            castedUnicornTokenIds[i] = uint256(unicornTokenIds[i]);
            ++nonZeroUnicornids;
        }

        //Set unicorn length equal to unicorns that are not 0
        assembly {
            mstore(castedUnicornTokenIds, nonZeroUnicornids)
        }

        //We use address(0) here because user is used to see if unicorn belongs to user, which we don't care about in this context.
        IUnicornStatCache.Stats[]
            memory unicornsInformation = IUnicornStatCacheAdvanced(
                LibExternalAddress.getUnicornAddress()
            ).getUnicornEnhancedStatsBatch(
                    castedUnicornTokenIds
                );

        LibTwTShadowcornDefense.ShadowcornSquad
            memory shadowcornSquad = LibTwTShadowcornDefense
                .twtGetShadowcornSquadById(shadowcornSquadId);

        (
            uint24 shadowcornTeamRPSBonus,
            uint24 unicornTeamRPSBonus
        ) = LibTwTModifier.getRPSModifier(unicornsInformation, shadowcornSquad);

        uint64[3] memory optimizedUnicornTokenIds = [
            uint64(0),
            uint64(0),
            uint64(0)
        ];
        // Cast each value in unicornTokenIds inside optimizedUnicornTokenIds
        for (uint256 i = 0; i < unicornTokenIds.length; ++i) {
            optimizedUnicornTokenIds[i] = uint64(unicornTokenIds[i]);
        }

        // We build a mockMatch, we only care about shadowcornTeamStamina, shadowcornTeamDamage, unicornTeamStamina, unicornTeamDamage,
        Match memory mockMatch = Match({
            shadowcornSquadId: 0,
            unicornIds: optimizedUnicornTokenIds,
            attackerAddress: address(0),
            regionId: 0,
            seasonId: 0,
            shadowcornTeamDamage: 0,
            unicornTeamDamage: 0,
            shadowcornTeamStamina: 0,
            unicornTeamStamina: 0,
            battleEndedTimestamp: 0,
            unicornTeamWon: false,
            leaderUnicornDied: false,
            randomness: 0,
            dominationPointsUnicorns: 0,
            dominationPointsShadowcorns: 0,
            newSquadId: 0,
            deadMinionPoolIds: [
                uint24(0),
                uint24(0),
                uint24(0),
                uint24(0),
                uint24(0)
            ],
            deadMinionAmounts: [
                uint24(0),
                uint24(0),
                uint24(0),
                uint24(0),
                uint24(0)
            ],
            matchId: 0
        });

        DamageCalculationExtraInfo memory extraInfo;
        (mockMatch, extraInfo) = addDamageAndStaminaForBothTeamsToMatch(
            unicornsInformation,
            shadowcornSquad,
            regionId,
            mockMatch
        );
        preview.rpsShadowcornTeamDamage = (shadowcornSquad.totalStats *
            shadowcornTeamRPSBonus);
        uint24 totalUnicornsStats = uint24(getTotalStatsForUnicorns(unicornsInformation, relevantUnicornStats));
        preview.rpsUnicornTeamDamage = (totalUnicornsStats *
            unicornTeamRPSBonus);

        preview.unicornTeamDamage = mockMatch.unicornTeamDamage;
        preview.unicornTeamMinDamage =
            (mockMatch.unicornTeamDamage * BASE_COMBAT_RANGE) /
            100;
        preview.unicornTeamMaxDamage =
            (mockMatch.unicornTeamDamage *
                (BASE_COMBAT_RANGE + MAX_COMBAT_LUCK)) /
            100;

        preview.shadowcornTeamDamage = mockMatch.shadowcornTeamDamage;
        preview.shadowcornTeamMinDamage =
            (mockMatch.shadowcornTeamDamage * BASE_COMBAT_RANGE) /
            100;
        preview.shadowcornTeamMaxDamage =
            (mockMatch.shadowcornTeamDamage *
                (BASE_COMBAT_RANGE + MAX_COMBAT_LUCK)) /
            100;

        preview.unicornTeamStamina = mockMatch.unicornTeamStamina;
        preview.shadowcornTeamStamina = mockMatch.shadowcornTeamStamina;
        preview.damageCalculationExtraInfo = extraInfo;
    }

    function twtGetTotalBattlesBySeasonAndRegion(
        uint16 seasonId,
        uint8 regionId
    ) internal view returns (uint256 totalBattles) {
        return
            twtUnicornAttackStorage().totalMatchesBySeasonAndRegion[seasonId][
                regionId
            ];
    }

    function twtGetUnicornsAreCoolingDown(
        uint64[] memory unicornIds
    ) internal view returns (uint256[] memory unicornsCooldownTimes) {
        unicornsCooldownTimes = new uint256[](unicornIds.length);
        LibTwTUnicornAttackStorage storage uas = twtUnicornAttackStorage();
        for (uint256 i = 0; i < unicornIds.length; ++i) {
            unicornsCooldownTimes[i] =
                uas.unicornLastBattleTimestampByTokenId[unicornIds[i]] +
                LibTwTAdmin.twtGetUnicornAttackCooldown();
        }
    }

    function twtGetBattleResults(
        uint56 matchId
    )
        internal
        view
        returns (
            uint24 unicornsDamageDealt,
            uint24 shadowcornsDamageDealt,
            uint24 unicornTeamStamina,
            uint24 shadowcornTeamStamina,
            uint56 unicornDominationPoints,
            uint56 shadowcornDominationPoints,
            bool unicornsWon
        )
    {

        LibTwTUnicornAttack.Match memory matchDetail = twtGetMatchById(matchId);
        (
            unicornsWon,
            unicornsDamageDealt,
            shadowcornsDamageDealt
        ) = combatSquads(
            matchDetail.shadowcornTeamDamage,
            matchDetail.unicornTeamDamage,
            matchDetail.shadowcornTeamStamina,
            matchDetail.unicornTeamStamina,
            matchDetail.randomness
        );
        unicornTeamStamina = matchDetail.unicornTeamStamina;
        shadowcornTeamStamina = matchDetail.shadowcornTeamStamina;
        unicornDominationPoints = matchDetail.dominationPointsUnicorns;
        shadowcornDominationPoints = matchDetail.dominationPointsShadowcorns;
    }
}


// Chain: POLYGON - File: IERC721.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC165.sol";

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
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

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
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}


// Chain: POLYGON - File: LibTwTUnicorn.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LibRNG} from "LibRNG.sol";
import {LibEvents} from "LibEvents.sol";
import {LibTwTShadowcornDefense} from "LibTwTShadowcornDefense.sol";
import {LibTwTMinions} from "LibTwTMinions.sol";
import {LibTwTSeason} from "LibTwTSeason.sol";
import {LibTwTAdmin} from "LibTwTAdmin.sol";
import {IERC20} from "IERC20.sol";
import {LibExternalAddress} from "LibExternalAddress.sol";
import {LibTwTUnicornAttack} from "LibTwTUnicornAttack.sol";
import {IERC721} from "IERC721.sol";

library LibTwTUnicorn {
    /// @notice Position to store the storage
    bytes32 private constant TWT_UNICORN_STORAGE_POSITION =
        keccak256("CryptoUnicorns.TwT.Unicorn.Storage");

    struct LibTwTUnicornStorage {
        mapping(uint256 vrfRequestId => address player) playerIdByVRFRequestId;
        mapping(uint16 seasonId => uint256 RBWRerollCost) rerollCostBySeason;
    }

    function twtUnicornStorage()
        internal
        pure
        returns (LibTwTUnicornStorage storage us)
    {
        bytes32 position = TWT_UNICORN_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            us.slot := position
        }
    }

    /// @notice Get the reroll costs for a given season
    /// @return rbwCost The reroll costs
    function twtGetRerollCosts(uint16 seasonId) internal view returns (uint256 rbwCost) {
        return twtUnicornStorage().rerollCostBySeason[seasonId];
    }

    /// @notice Set the reroll costs for a given season
    /// @param seasonId The season id
    /// @param rbwCost The reroll costs
    function twtSetRerollCosts(uint16 seasonId, uint256 rbwCost) internal {
        twtUnicornStorage().rerollCostBySeason[seasonId] = rbwCost;
    }

    function twtRescueUnicorn(uint256[] memory vrfRequestIds) internal {
        for (uint256 i = 0; i < vrfRequestIds.length; ++i) {
            uint256 vrfRequestId = vrfRequestIds[i];

            if (vrfRequestId == 0) {
                continue;
            }

            LibTwTUnicornAttack.Match memory playedMatch = LibTwTUnicornAttack.twtGetMatchByVRFRequestId(vrfRequestId);

            require(playedMatch.attackerAddress != address(0), "U-005");
            require(playedMatch.randomness == 0, "U-004");
            require(playedMatch.unicornIds[0] != 0, "U-003");

            // Check if dark forest contract is owner of that tokenId. If not, continue the loop
            address currentOwner = IERC721(LibExternalAddress.getUnicornAddress()).ownerOf(playedMatch.unicornIds[0]);
            if (currentOwner != address(this)) {
                emit LibEvents.TwTUnicornReturnSkipped(
                    vrfRequestId,
                    playedMatch.matchId,
                    playedMatch.unicornIds[0],
                    currentOwner
                );
                continue;
            }

            IERC721(LibExternalAddress.getUnicornAddress()).transferFrom(
                address(this),
                playedMatch.attackerAddress,
                playedMatch.unicornIds[0]
            );

            emit LibEvents.TwTUnicornReturned(
                vrfRequestId,
                playedMatch.matchId,
                playedMatch.unicornIds[0],
                playedMatch.attackerAddress
            );
        }
    }

    function twtFindShadowcornOpponents(
        uint8 regionId,
        address player
    )
        internal
        view
        returns (LibTwTShadowcornDefense.ShadowcornSquad[3] memory squads)
    {
        uint16 seasonId = LibTwTSeason.twtGetCurrentSeasonId();
        uint256 playerSeed = LibRNG.getPlayerSeed(player);
        uint256 length = LibTwTMinions.twtGetMinionSquadIdsLength(
            seasonId,
            regionId
        );
        require(length > 2, "U-002");
        uint256 stableMinionSizeIncrements = LibTwTAdmin.twtGetStableMinionSquadSizeIncrements();
        if (length > stableMinionSizeIncrements) {
            length = (length/stableMinionSizeIncrements) * stableMinionSizeIncrements;
        }
        squads = twtGetAttackableSquads(length, seasonId, regionId, player, playerSeed);
    }

    function twtGetAttackableSquads(uint256 length, uint16 seasonId, uint8 regionId, address player, uint256 playerSeed) internal view returns (LibTwTShadowcornDefense.ShadowcornSquad[3] memory squads) {
        uint256 salt = 1;
        // Get index for first squad
        uint256[3] memory squadIndexes = [uint256(0), uint256(0), uint256(0)];
        uint256 squadIndex;
        uint40 squadId;
        LibTwTShadowcornDefense.LibTwTShadowcornDefenseStorage storage sds = LibTwTShadowcornDefense.twtShadowcornDefenseStorage();
        for(uint8 i = 0; i < 3; ++i) {
            while(squadIndexes[i] == 0) {
                squadIndex = LibRNG.expand(length, playerSeed, salt);
                if(squadIndexes[0] != squadIndex && squadIndexes[1] != squadIndex && squadIndexes[2] != squadIndex) {
                    squadId = LibTwTMinions.twtGetMinionSquadIdsArray(seasonId, regionId)[
                        squadIndex
                    ];
                    LibTwTShadowcornDefense.ShadowcornSquad memory squad = sds.squadById[squadId];
                    if(squad.sender != player) {
                        squads[i] = squad;
                        squadIndexes[i] = squadIndex;
                    }
                }
                ++salt;
            }
        }
    }
    function twtRerollShadowcornOpponents() internal {
        LibTwTUnicornStorage storage us = twtUnicornStorage();
        uint16 currentSeasonId = LibTwTSeason.twtGetCurrentSeasonId();
        uint256 rerollCost = twtGetRerollCosts(currentSeasonId);
        require(rerollCost > 0, "U-001");
        //Transfer RBW reroll cost to gamebank
        IERC20(LibExternalAddress.getRBWAddress()).transferFrom(
            msg.sender,
            LibExternalAddress.getGameBankAddress(),
            rerollCost
        );

        uint256 vrfRequestId = LibRNG.requestRandomWordsFor(
            LibRNG.RNG_REROLL_MINION_SQUADS
        );

        us.playerIdByVRFRequestId[vrfRequestId] = msg.sender;
    }

    function twtRerollShadowcornOpponentsFulfillRandomness(
        uint256 requestId,
        uint256 randomness
    ) internal {
        address player = twtUnicornStorage().playerIdByVRFRequestId[requestId];
        uint256 oldSeed = LibRNG.getPlayerSeed(player);
        LibRNG.setPlayerSeed(player, randomness);
        emit LibEvents.TwTRNGSeedChanged(player, oldSeed, randomness);
    }

    function twtCanCombatMinionSquad(
        uint8 regionId,
        uint40 shadowcornSquadId,
        address player
    ) internal view returns (bool) {
        uint16 seasonId = LibTwTSeason.twtGetCurrentSeasonId();
        uint256 playerSeed = LibRNG.getPlayerSeed(player);
        uint256 length = LibTwTMinions.twtGetMinionSquadIdsLength(
            seasonId,
            regionId
        );
        uint256 stableMinionSizeIncrements = LibTwTAdmin.twtGetStableMinionSquadSizeIncrements();
        if (length > stableMinionSizeIncrements) {
            length = (length/stableMinionSizeIncrements) * stableMinionSizeIncrements;
        }
        LibTwTShadowcornDefense.ShadowcornSquad[3] memory squads = twtGetAttackableSquads(length, seasonId, regionId, player, playerSeed);
        for (uint256 i = 0; i < squads.length; ++i) {
            if (squads[i].squadId == shadowcornSquadId) {
                return true;
            }
        }
        return false;
    }
}


// Chain: POLYGON - File: LibRNG.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {VRFCoordinatorV2Interface} from "VRFCoordinatorV2Interface.sol";

library LibRNG {
    uint256 internal constant RNG_REROLL_MINION_SQUADS = 1;
    uint256 internal constant RNG_UNICORN_ATTACK_REGION = 2;

    bytes32 private constant RNGVRF_STORAGE_POSITION = keccak256("diamond.DarkForest.LibRNGVRFV2.storage");

    struct LibRNGVRFV2Storage {
        // Your subscription ID.
        uint64 subscriptionId;

        // see https://docs.chain.link/docs/vrf-contracts/#configurations
        // mumbai = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed
        address vrfCoordinator;

        // The gas lane to use, which specifies the maximum gas price to bump to.
        // For a list of available gas lanes on each network,
        // see https://docs.chain.link/docs/vrf-contracts/#configurations
        //mumbai = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
        bytes32 keyHash;

        // Depends on the number of requested values that you want sent to the
        // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
        // so 100,000 is a safe default for this example contract. Test and adjust
        // this limit based on the network that you select, the size of the request,
        // and the processing of the callback request in the fulfillRandomWords()
        // function.
        mapping (uint256 => uint32) callbackGasLimitForMechanicId;

        // The default is 3, but you can set this higher.
        mapping (uint256 => uint16) confirmationsForMechanicId;

        // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
        uint32 numWords;

        // requestId (number provided by ChainLink) => mechanicId (ie RITUALS)
        // This map allows us to share RNG facet between mechanics.
        mapping(uint256 => uint256) rng_mechanicIdByVRFRequestId;
        // requestId => randomness provided by ChainLink
        mapping(uint256 => uint256) rng_randomness;

        uint256 rngNonce;

        mapping(address => uint256) playerSeedByWallet;
    }

    function vrfV2Storage() internal pure returns (LibRNGVRFV2Storage storage vrf) {
        bytes32 position = RNGVRF_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            vrf.slot := position
        }
    }

    function requestRandomWordsFor(uint256 mechanicId) internal returns(uint256) {
        LibRNGVRFV2Storage storage vrfs = vrfV2Storage();
        uint32 callbackGasLimit = vrfs.callbackGasLimitForMechanicId[mechanicId];
        uint16 requestConfirmations = vrfs.confirmationsForMechanicId[mechanicId];
        uint256 requestId = VRFCoordinatorV2Interface(vrfs.vrfCoordinator).requestRandomWords(
            vrfs.keyHash,
            vrfs.subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            vrfs.numWords
        );
        vrfs.rng_mechanicIdByVRFRequestId[requestId] = mechanicId;
        return requestId;
    }

    // function setVRFV2RequestConfirmationsByMechanicId(uint256 mechanicId, uint16 confirmations) internal {
    //     vrfV2Storage().confirmationsForMechanicId[mechanicId] = confirmations;
    // }

    // function setVRFV2NumWords(uint32 words) internal {
    //     vrfV2Storage().numWords = words;
    // }

    // function setVRFV2CallbackGasLimitByMechanicId(uint256 mechanicId, uint32 limit) internal {
    //     vrfV2Storage().callbackGasLimitForMechanicId[mechanicId] = limit;
    // }

    // function setVRFV2KeyHash(bytes32 keyHash) internal {
    //     vrfV2Storage().keyHash = keyHash;
    // }

    // function setVRFV2VrfCoordinatorAddress(address coordinator) internal {
    //     vrfV2Storage().vrfCoordinator = coordinator;
    // }

    // function setVRFV2SubscriptionId(uint64 subscriptionId) internal {
    //     vrfV2Storage().subscriptionId = subscriptionId;
    // }

    // function getVRFV2RequestConfirmationsByMechanicId(uint256 mechanicId) internal view returns(uint16) {
    //     return vrfV2Storage().confirmationsForMechanicId[mechanicId];
    // }

    // function getVRFV2NumWords() internal view returns(uint32) {
    //     return vrfV2Storage().numWords;
    // }

    // function getVRFV2CallbackGasLimitByMechanicId(uint256 mechanicId) internal view returns(uint32) {
    //     return vrfV2Storage().callbackGasLimitForMechanicId[mechanicId];
    // }

    // function getVRFV2KeyHash() internal view returns(bytes32) {
    //     return vrfV2Storage().keyHash;
    // }

    function getVRFV2VrfCoordinatorAddress() internal view returns(address) {
        return vrfV2Storage().vrfCoordinator;
    }

    // function getVRFV2SubscriptionId() internal view returns(uint64) {
    //     return vrfV2Storage().subscriptionId;
    // }

    // function makeRequestId(bytes32 _keyHash, uint256 _vRFInputSeed) internal pure returns (bytes32) {
    //     return keccak256(abi.encodePacked(_keyHash, _vRFInputSeed));
    // }
    // function makeVRFInputSeed(
    //     bytes32 _keyHash,
    //     uint256 _userSeed,
    //     address _requester,
    //     uint256 _nonce
    // ) internal pure returns (uint256) {
    //     return uint256(keccak256(abi.encode(_keyHash, _userSeed, _requester, _nonce)));
    // }

    function removeMechanicIdByVRFRequestId(uint256 requestId) internal {
        delete vrfV2Storage().rng_mechanicIdByVRFRequestId[requestId];
    }

    function getMechanicIdByVRFRequestId(uint256 requestId) internal view returns(uint256) {
        return vrfV2Storage().rng_mechanicIdByVRFRequestId[requestId];
    }

    function setRandomWord(uint256 requestId, uint256 randomWord) internal {
        vrfV2Storage().rng_randomness[requestId] = randomWord;
    }

    function expand(uint256 _modulus, uint256 _seed, uint256 _salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_seed, _salt))) % _modulus;
    }

    // function getRuntimeRNG() internal returns (uint256) {
    //     return getRuntimeRNG(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    // }

    // function getRuntimeRNG(uint _modulus) internal returns (uint256) {
    //     require(msg.sender != block.coinbase, "RNG-001");
    //     return uint256(keccak256(abi.encodePacked(block.coinbase, gasleft(), block.number, ++vrfV2Storage().rngNonce))) % _modulus;
    // }

    // function getViewRuntimeRNG(uint _modulus) internal view returns (uint256) {
    //     require(msg.sender != block.coinbase, "RNG-002");
    //     return uint256(keccak256(abi.encodePacked(block.coinbase, gasleft(), block.number, vrfV2Storage().rngNonce))) % _modulus;
    // }

    function getPlayerSeed(address player) internal view returns (uint256) {
        LibRNGVRFV2Storage storage vrfs = vrfV2Storage();
        uint256 playerSeed = vrfs.playerSeedByWallet[player];
        if (playerSeed == 0) {
            return uint256(keccak256(abi.encodePacked(player)));
        }
        return playerSeed;
    }

    function setPlayerSeed(address player, uint256 seed) internal {
        vrfV2Storage().playerSeedByWallet[player] = seed;
    }
}


// Chain: POLYGON - File: VRFCoordinatorV2Interface.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(uint64 subId)
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;

  /*
   * @notice Check to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId - ID of the subscription
   * @return true if there exists at least one unfulfilled request for the subscription, false
   * otherwise.
   */
  function pendingRequestExists(uint64 subId) external view returns (bool);
}


// Chain: POLYGON - File: LibTwTMinions.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibTwTWave} from "LibTwTWave.sol";

library LibTwTMinions {
    /// @notice Position to store the storage
    bytes32 private constant TWT_MINIONS_STORAGE_POSITION =
        keccak256("CryptoUnicorns.TwT.Minions.Storage");

    struct LibTwTMinionsStorage {
        // minion squad ids array for each season and region
        mapping(uint16 seasonId => mapping(uint8 regionId => uint40[] minionSquadIdsArray)) minionSquadIdsArray;
        // minion squad id to idx in array
        mapping(uint16 seasonId => mapping(uint8 regionId => mapping(uint40 minionSquadId => uint256 idx))) minionSquadIdToIdx;
        // minion squad id to lock status
        mapping(uint40 minionSquadId => uint256 unlockableWaveId) minionSquadIdToUnlockableWaveId;
        // minion squad id to is chosen for combat
        mapping(uint40 minionSquadId => bool isChosenForCombat) minionSquadIdIsChosenForCombat;
        // season id to unlockable waves
        mapping(uint16 seasonId => uint256 unlockableWaves) seasonIdToUnlockableWaves;
    }

    function twtMinionsStorage()
        internal
        pure
        returns (LibTwTMinionsStorage storage ltms)
    {
        bytes32 position = TWT_MINIONS_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ltms.slot := position
        }
    }

    function twtAddMinionSquadToArray(
        uint16 seasonId,
        uint8 regionId,
        uint40 minionSquadId
    ) internal {
        LibTwTMinionsStorage storage ltms = twtMinionsStorage();
        ltms.minionSquadIdsArray[seasonId][regionId].push(minionSquadId);
        ltms.minionSquadIdToIdx[seasonId][regionId][minionSquadId] = ltms
        .minionSquadIdsArray[seasonId][regionId].length;
    }

    function twtRemoveMinionSquadFromArray(
        uint16 seasonId,
        uint8 regionId,
        uint40 minionSquadId
    ) internal {
        LibTwTMinionsStorage storage ltms = twtMinionsStorage();
        // find idx of staked minion
        require(
            ltms.minionSquadIdToIdx[seasonId][regionId][minionSquadId] > 0,
            "MI-001"
        );
        uint256 idx = ltms.minionSquadIdToIdx[seasonId][regionId][
            minionSquadId
        ] - 1;

        require(
            ltms.minionSquadIdsArray[seasonId][regionId].length > 0,
            "MI-002"
        );
        // get last minion squad id
        uint40 lastMinionSquadId = ltms.minionSquadIdsArray[seasonId][
            regionId
        ][ltms.minionSquadIdsArray[seasonId][regionId].length - 1];

        // remove minion squad from array
        swapAndPopArrayUsingIdx(
            ltms.minionSquadIdsArray[seasonId][regionId],
            uint40(idx)
        );

        // update idx of last minion squad
        delete ltms.minionSquadIdToIdx[seasonId][regionId][minionSquadId];
        ltms.minionSquadIdToIdx[seasonId][regionId][uint40(lastMinionSquadId)] =
            uint40(idx) +
            1;
    }

    function twtGetMinionSquadIdsArray(
        uint16 seasonId,
        uint8 regionId
    ) internal view returns (uint40[] storage) {
        return twtMinionsStorage().minionSquadIdsArray[seasonId][regionId];
    }

    function twtGetMinionSquadIdsLength(
        uint16 seasonId,
        uint8 regionId
    ) internal view returns (uint256) {
        return
            twtMinionsStorage().minionSquadIdsArray[seasonId][regionId].length;
    }

    function twtGetMinionSquadIdxInArray(
        uint16 seasonId,
        uint8 regionId,
        uint40 minionSquadId
    ) internal view returns (uint256) {
        return
            twtMinionsStorage().minionSquadIdToIdx[seasonId][regionId][
                minionSquadId
            ];
    }

    function twtIsMinionSquadUnlockable(
        uint40 minionSquadId
    ) internal view returns (bool isLocked) {
        uint256 unlockableWaveId = twtMinionsStorage()
            .minionSquadIdToUnlockableWaveId[minionSquadId];

        // get current wave id
        uint256 waveId = LibTwTWave.twtGetCurrentWaveId();

        return
            unlockableWaveId >= waveId &&
            !twtMinionsStorage().minionSquadIdIsChosenForCombat[minionSquadId];
    }

    function twtSetMinionSquadUnlockableWaveId(
        uint16 seasonId,
        uint40 minionSquadId
    ) internal {
        // get current wave id
        uint256 waveId = LibTwTWave.twtGetCurrentWaveId();
        uint256 unlockableWaveId = waveId +
            twtGetUnlockableWaveForSeason(seasonId);
        twtMinionsStorage().minionSquadIdToUnlockableWaveId[
            minionSquadId
        ] = unlockableWaveId;
    }

    function twtSetUnlockableWaveForSeason(
        uint16 seasonId,
        uint256 waves
    ) internal {
        twtMinionsStorage().seasonIdToUnlockableWaves[seasonId] = waves;
    }

    function twtGetUnlockableWaveForSeason(
        uint16 seasonId
    ) internal view returns (uint256) {
        return twtMinionsStorage().seasonIdToUnlockableWaves[seasonId];
    }

    function twtSetPartiallyKilledMinionSquadUnlockableWaveId(
        uint40 minionSquadId,
        uint256 unlockableWaveId
    ) internal {
        twtMinionsStorage().minionSquadIdToUnlockableWaveId[
            minionSquadId
        ] = unlockableWaveId;
    }

    function twtGetMinionSquadUnlockableWaveId(
        uint40 minionSquadId
    ) internal view returns (uint256) {
        return
            twtMinionsStorage().minionSquadIdToUnlockableWaveId[minionSquadId];
    }

    function twtSetMinionSquadIsChosenForCombat(
        uint40 minionSquadId,
        bool isChosenForCombat
    ) internal {
        twtMinionsStorage().minionSquadIdIsChosenForCombat[
            minionSquadId
        ] = isChosenForCombat;
    }

    function twtGetMinionSquadIsChosenForCombat(
        uint40 minionSquadId
    ) internal view returns (bool) {
        return
            twtMinionsStorage().minionSquadIdIsChosenForCombat[minionSquadId];
    }

    // TODO: move this function to common repo.
    function swapAndPopArray(uint256[] storage array, uint256 item) internal {
        uint256 index = array.length - 1;
        for (uint256 i = 0; i < array.length; ++i) {
            if (array[i] == item) {
                index = i;
                break;
            }
        }
        if (index < array.length) {
            array[index] = array[array.length - 1];
            array.pop();
        }
    }

    // TODO: move this function to common repo.
    function swapAndPopArrayUsingIdx(
        uint40[] storage array,
        uint256 idx
    ) internal {
        require(idx < array.length, "MI-003");
        array[idx] = array[array.length - 1];
        array.pop();
    }
}


// Chain: POLYGON - File: LibTwTAdmin.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {LibDiamond} from "LibDiamond.sol";
import {LibEvents} from "LibEvents.sol";
import {LibTwTSeason} from "LibTwTSeason.sol";

library LibTwTAdmin {
    /// @notice Position to store the storage
    bytes32 private constant TWT_ADMIN_STORAGE_POSITION =
        keccak256("CryptoUnicorns.TwT.Admin.Storage");

    /// @notice DO NOT REORDER THIS STRUCT
    struct LibTwTAdminStorage {
        uint24 stableSquadSizeIncrements;
        uint16 unicornAttackCooldown;
        uint24[] minionPoolIds;
        address[] adminWallets;
        mapping(uint24 => bool) poolIdIsMinionPoolId;
        mapping(uint16 seasonId => mapping(uint24 minionPoolId => uint256 killChance)) minionPoolIdChanceToKillUnicornLeaderBySeason;
        mapping(uint24 poolId => uint56 stakingPoints) minionStakingPointsByPoolId;
        mapping(uint16 seasonId => uint24 overseerStatsBonus) overseerStatsBonusBySeason;
        // dominationPointsWinnerAndLoserMultiplier[0] = winner's multiplier, dominationPointsWinnerAndLoserMultiplier[1] = loser's multiplier.
        mapping(uint16 seasonId => uint32[2] dominationPointsWinnerAndLoserMultiplier) dominationPointsWinnerAndLoserMultiplierBySeason;
    }

    function twtSetDominationPointsWinnerAndLoserMultiplierBySeason(
        uint32 winnerMultiplier,
        uint32 loserMultiplier,
        uint16 seasonId
    ) internal {
        twtAdminStorage().dominationPointsWinnerAndLoserMultiplierBySeason[
            seasonId
        ][0] = winnerMultiplier;
        twtAdminStorage().dominationPointsWinnerAndLoserMultiplierBySeason[
            seasonId
        ][1] = loserMultiplier;
    }

    function twtGetDominationPointsWinnerAndLoserMultiplierBySeason(
        uint16 seasonId
    )
        internal
        view
        returns (uint32 winnerMultiplier, uint32 loserMultiplier)
    {
        winnerMultiplier = twtAdminStorage()
            .dominationPointsWinnerAndLoserMultiplierBySeason[seasonId][0];
        loserMultiplier = twtAdminStorage()
            .dominationPointsWinnerAndLoserMultiplierBySeason[seasonId][1];
    }

    function twtGetDominationPointsWinnerAndLoserMultiplierForCurrentSeason()
        internal
        view
        returns (uint32 winnerMultiplier, uint32 loserMultiplier)
    {
        return
            twtGetDominationPointsWinnerAndLoserMultiplierBySeason(
                LibTwTSeason.twtGetCurrentSeasonId()
            );
    }

    function twtSetOverseerStatsBonusBySeason(
        uint24 overseerStatsBonusPercentage,
        uint16 seasonId
    ) internal {
        twtAdminStorage().overseerStatsBonusBySeason[
            seasonId
        ] = overseerStatsBonusPercentage;
    }

    function twtGetOverseerStatsBonusBySeason(
        uint16 seasonId
    ) internal view returns (uint24) {
        return twtAdminStorage().overseerStatsBonusBySeason[seasonId];
    }

    function twtGetOverseerStatsBonusForCurrentSeason()
        internal
        view
        returns (uint24)
    {
        return
            twtAdminStorage().overseerStatsBonusBySeason[
                LibTwTSeason.twtGetCurrentSeasonId()
            ];
    }

    /// @notice Set wallet as admin
    /// @param wallet The wallet to set as admin
    function twtSetAdmin(address wallet) internal {
        LibTwTAdminStorage storage lts = twtAdminStorage();
        uint256 adminIndex = twtGetAdminIndex(wallet);
        require(
            adminIndex > lts.adminWallets.length,
            "ADM-001"
        );
        lts.adminWallets.push(wallet);

        emit LibEvents.TwTPermissionChanged(wallet, false, true);
    }

    /// @notice Unset wallet as admin
    /// @param wallet The wallet to unset as admin
    function twtUnsetAdmin(address wallet) internal {
        LibTwTAdminStorage storage lts = twtAdminStorage();
        require(
            lts.adminWallets.length > 0,
            "ADM-002"
        );
        uint256 adminIndex = twtGetAdminIndex(wallet);
        require(
            adminIndex < lts.adminWallets.length,
            "ADM-003"
        );
        lts.adminWallets[adminIndex] = lts.adminWallets[
            lts.adminWallets.length - 1
        ];
        lts.adminWallets.pop();

        emit LibEvents.TwTPermissionChanged(wallet, true, false);
    }

    /// @notice Get the index of a given wallet in the admin wallets array
    /// @param wallet The wallet to check
    function twtGetAdminIndex(address wallet) private view returns (uint256) {
        for (uint256 i = 0; i < twtAdminStorage().adminWallets.length; ++i) {
            if (twtAdminStorage().adminWallets[i] == wallet) {
                return i;
            }
        }
        return type(uint256).max;
    }

    /// @notice Get the index of a given minion pool in the minion pool ids array
    /// @param minionPoolId The minion pool id to check
    function twtGetMinionPoolIndex(
        uint24 minionPoolId
    ) private view returns (uint256) {
        LibTwTAdminStorage storage lts = twtAdminStorage();
        for (uint256 i = 0; i < lts.minionPoolIds.length; ++i) {
            if (lts.minionPoolIds[i] == minionPoolId) {
                return i;
            }
        }
        return type(uint256).max;
    }

    /// @notice Enforce wallet is admin (or owner)
    /// @dev This function will revert if the sender is not an admin. This method is not view because it's using msg.sender
    function twtEnforceIsAdmin() internal view {
        uint256 adminIndex = twtGetAdminIndex(msg.sender);
        require(
            adminIndex < twtAdminStorage().adminWallets.length ||
                msg.sender == LibDiamond.contractOwner(),
            "ADM-004"
        );
    }

    /// @notice Get the role of a given wallet
    /// @param wallet The wallet to check
    /// @return admin True if the wallet is admin
    function twtIsUserAdmin(address wallet) internal view returns (bool admin) {
        admin = twtGetAdminIndex(wallet) < type(uint256).max;
    }

    /// @notice This function is used to obtain the list of admins
    /// @return admins The list of admins
    function twtGetAdmins() internal view returns (address[] memory) {
        return twtAdminStorage().adminWallets;
    }

    /// @notice This function is used to set the list of minion pools
    /// @param minionPools The list of minion pools
    function twtSetMinionPoolIds(uint24[] memory minionPools) internal {
        LibTwTAdminStorage storage lts = twtAdminStorage();
        uint24[] memory oldPools = lts.minionPoolIds;
        lts.minionPoolIds = minionPools;

        for (uint256 i = 0; i < minionPools.length; ++i) {
            lts.poolIdIsMinionPoolId[minionPools[i]] = true;
        }
        emit LibEvents.TwTMinionPoolIdsChanged(oldPools, minionPools);
    }

    /// @notice This function is used to add a minion pool
    /// @param poolId The pool id to add
    function twtAddMinionPool(uint24 poolId) internal {
        uint256 minionPoolIndex = twtGetMinionPoolIndex(poolId);
        LibTwTAdminStorage storage lts = twtAdminStorage();
        uint24[] memory oldPools = lts.minionPoolIds;
        require(
            minionPoolIndex > oldPools.length,
            "ADM-005"
        );

        lts.minionPoolIds.push(poolId);
        lts.poolIdIsMinionPoolId[poolId] = true;

        uint24[] memory minionPools = lts.minionPoolIds;

        emit LibEvents.TwTMinionPoolIdsChanged(oldPools, minionPools);
    }

    /// @notice This function is used to clear minion pools
    function twtClearMinionPools() internal {
        LibTwTAdminStorage storage lts = twtAdminStorage();
        uint24[] memory oldPools = lts.minionPoolIds;
        for (uint256 i = 0; i < oldPools.length; ++i) {
            lts.poolIdIsMinionPoolId[oldPools[i]] = false;
        }
        lts.minionPoolIds = new uint24[](0);
    }

    /// @notice This function is used to get the list of minion pools
    function twtGetMinionPoolIds()
        internal
        view
        returns (uint24[] memory minionPools)
    {
        minionPools = twtAdminStorage().minionPoolIds;
    }

    function enforcePoolIdIsMinionPoolId(uint24 poolId) internal view {
        require(
            twtAdminStorage().poolIdIsMinionPoolId[poolId],
            "ADM-006"
        );
    }

    /// @notice This function is used to set the chance of a minion from a given pool to kill a unicorn leader
    /// @param minionPoolId The pool id
    /// @param seasonId The season id
    /// @param killChance The chance to kill a unicorn leader
    function twtSetMinionPoolChanceToKillUnicornLeader(
        uint24 minionPoolId,
        uint16 seasonId,
        uint256 killChance
    ) internal {
        enforcePoolIdIsMinionPoolId(minionPoolId);
        twtAdminStorage().minionPoolIdChanceToKillUnicornLeaderBySeason[
            seasonId
        ][minionPoolId] = killChance;
    }

    /// @notice This function is used to get the chance of a minion from a given pool to kill a unicorn leader
    /// @param minionPoolId The pool id
    /// @param seasonId The season id
    function twtGetMinionPoolChanceToKillUnicornLeaderBySeason(
        uint24 minionPoolId,
        uint16 seasonId
    ) internal view returns (uint256) {
        enforcePoolIdIsMinionPoolId(minionPoolId);
        return
            twtAdminStorage().minionPoolIdChanceToKillUnicornLeaderBySeason[
                seasonId
            ][minionPoolId];
    }

    /// @notice This function is used to set the points a minion of a given pool will earn when staking
    /// @param minionPoolId The pool id
    /// @param stakingPoints The points to earn
    function twtSetMinionPoolStakingPoints(
        uint24 minionPoolId,
        uint56 stakingPoints
    ) internal {
        twtAdminStorage().minionStakingPointsByPoolId[
            minionPoolId
        ] = stakingPoints;
    }

    /// @notice This function is used to get the points a minion of a given pool will earn when staking
    /// @param minionPoolId The pool id
    /// @return stakingPoints The points to earn
    function twtGetMinionPoolStakingPoints(
        uint24 minionPoolId
    ) internal view returns (uint56 stakingPoints) {
        stakingPoints = twtAdminStorage().minionStakingPointsByPoolId[
            minionPoolId
        ];
    }

    /// @notice This function is used to set the stable minion squad size increments
    /// @param stableMinionSquadSizeIncrements The stable minion squad size increments
    function twtSetStableMinionSquadSizeIncrements(
        uint24 stableMinionSquadSizeIncrements
    ) internal {
        twtAdminStorage()
            .stableSquadSizeIncrements = stableMinionSquadSizeIncrements;
    }

    /// @notice This function is used to get the stable minion squad size increments
    /// @return stableMinionSquadSizeIncrements The stable minion squad size increments
    function twtGetStableMinionSquadSizeIncrements()
        internal
        view
        returns (uint24 stableMinionSquadSizeIncrements)
    {
        stableMinionSquadSizeIncrements = twtAdminStorage()
            .stableSquadSizeIncrements;
    }

    function twtSetUnicornAttackCooldown(uint16 cooldown) internal {
        twtAdminStorage().unicornAttackCooldown = cooldown;
    }

    function twtGetUnicornAttackCooldown() internal view returns (uint16) {
        return twtAdminStorage().unicornAttackCooldown;
    }

    function twtAdminStorage()
        internal
        pure
        returns (LibTwTAdminStorage storage lss)
    {
        bytes32 position = TWT_ADMIN_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            lss.slot := position
        }
    }
}


// Chain: POLYGON - File: LibDiamond.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Adapted from the Diamond 3 reference implementation by Nick Mudge:
// https://github.com/mudgen/diamond-3-hardhat

import { IDiamondCut } from "IDiamondCut.sol";
import { LibEvents } from "LibEvents.sol";

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // owner of the contract
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit LibEvents.OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == diamondStorage().contractOwner, "LibDiamond: Must be contract owner");
    }


    // Internal function version of diamondCut
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; ++facetIndex) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert("LibDiamondCut: Incorrect FacetCutAction");
            }
        }
        emit LibEvents.DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) private {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; ++selectorIndex) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress == address(0), "LibDiamondCut: Can't add function that already exists");
            addFunction(ds, selector, selectorPosition, _facetAddress);
            ++selectorPosition;
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) private {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; ++selectorIndex) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress != _facetAddress, "LibDiamondCut: Can't replace function with same function");
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            ++selectorPosition;
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        // if function does not exist then do nothing and return
        require(_facetAddress == address(0), "LibDiamondCut: Remove facet address must be address(0)");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; ++selectorIndex) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    function addFacet(DiamondStorage storage ds, address _facetAddress) private {
        enforceHasContractCode(_facetAddress, "LibDiamondCut: New facet has no code");
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }


    function addFunction(DiamondStorage storage ds, bytes4 _selector, uint96 _selectorPosition, address _facetAddress) private {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(DiamondStorage storage ds, address _facetAddress, bytes4 _selector) internal {
        require(_facetAddress != address(0), "LibDiamondCut: Can't remove function that doesn't exist");
        // an immutable function is a function defined directly in a diamond
        require(_facetAddress != address(this), "LibDiamondCut: Can't remove immutable function");
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) private {
        if (_init == address(0)) {
            require(_calldata.length == 0, "LibDiamondCut: _init is address(0) but_calldata is not empty");
        } else {
            require(_calldata.length > 0, "LibDiamondCut: _calldata is empty but _init is not address(0)");
            if (_init != address(this)) {
                enforceHasContractCode(_init, "LibDiamondCut: _init address has no code");
            }
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                if (error.length > 0) {
                    // bubble up the error
                    revert(string(error));
                } else {
                    revert("LibDiamondCut: _init function reverted");
                }
            }
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) private view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}


// Chain: POLYGON - File: IUnicornStats.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title Basic Unicorn StatCache Interface
interface IUnicornStatCache {

    /// @notice Data object for a Unicorn's vital stats, either naturally,
    ///     or enhanced by Gems and other modifiers.
    /// @dev DO NOT CHANGE THIS STRUCT
    /// @dev properties are intended to pack into a single 256 bit storage slot
    struct Stats {
        uint40 dataTimestamp;
        uint16 attack;
        uint16 accuracy;
        uint16 moveSpeed;
        uint16 attackSpeed;
        uint16 defense;
        uint16 vitality;
        uint16 resistance;
        uint16 magic;
        uint16 firstName;
        uint16 lastName;
        uint8 class;
        uint8 lifecycleStage;
        uint8 breedingPoints;
        uint8 mythicCount;
        bool origin;
        bool gameLocked;
        bool limitedEdition;
        bool persistedToCache;
    }


    /// @notice Returns true if the StatCache has data for the target token
    /// @param tokenId The id of a Unicorn
    /// @return naturalStatsCached True if cached, otherwise false
    /// @return enhancedStatsCached True if cached, otherwise false
    function checkUnicornStatsCached(uint256 tokenId) external view returns (bool naturalStatsCached, bool enhancedStatsCached);


    /// @notice Returns indexed arrays matching the input argument, with true
    ///     if the corresponding token has cached data, otherwise false.
    /// @param tokenIds Array of Unicorn tokenId's to check
    /// @return naturalStatsCached True if natural stats are cached, for each index in tokenIds
    /// @return enhancedStatsCached True if enhanced stats are cached, for each index in tokenIds
    function checkUnicornStatsCachedBatch(uint256[] calldata tokenIds) external view returns (bool[] memory naturalStatsCached, bool[] memory enhancedStatsCached);


    /// @notice Returns a Unicorn's enhanced stats, from the cache if available,
    ///     otherwise by (expensive) direct lookup.
    /// @dev This is an alias of getUnicornEnhancedStats
    /// @param tokenId The id of a Unicorn
    /// @return enhancedStats The Stats of the unicorn
    function getUnicornStats(uint256 tokenId) external view returns (Stats memory enhancedStats);


    /// @notice Returns a group of Unicorns' enhanced stats
    /// @dev This is an alias of getEnhancedUnicornStatsBatch
    /// @param tokenIds, An array of Unicorn ids
    /// @return enhancedStats Corresponding stats for the unicorns specified in tokenIds
    function getUnicornStatsBatch(uint256[] calldata tokenIds) external view returns (Stats[] memory enhancedStats);


    /// @notice Returns a Unicorn's enhanced stats AND underlying natural stats,
    ///     from the cache if available, otherwise by (expensive) direct lookups.
    /// @dev This is an alias of getUnicornEnhancedStats
    /// @param tokenId The id of a Unicorn
    /// @return naturalStats The Stats of the unicorn without Gems or enhancements
    /// @return enhancedStats The Stats of the unicorn with Gems and enhancements
    function getUnicornFullStats(uint256 tokenId) external view returns (Stats memory naturalStats, Stats memory enhancedStats);
}


/// @title Extended Unicorn StatCache Interface
interface IUnicornStatCacheAdvanced is IUnicornStatCache{

    /// @notice Writes a Unicorn's data to the StatCache, overwriting any previous data.
    /// @param tokenId, The id of a Unicorn
    /// @return naturalStats The Stats struct in the cache (dataTimestamp will match the current block if freshly written)
    /// @custom:emits UnicornNaturalStatsChanged
    function cacheUnicornNaturalStats(uint256 tokenId) external returns (Stats memory naturalStats);


    /// @notice Writes a Unicorn's data to the StatCache, overwriting any previous data.
    /// @param tokenId, The id of a Unicorn
    /// @return enhancedStats The Stats struct in the cache (dataTimestamp will match the current block if freshly written)
    /// @custom:emits UnicornEnhancedStatsChanged
    function cacheUnicornEnhancedStats(uint256 tokenId) external returns (Stats memory enhancedStats);


    /// @notice Writes a collection of Unicorns' data to the StatCache, overwriting any previous data.
    /// @param tokenIds, An array of Unicorn ids
    /// @return naturalStats The Stats structs written to cache
    /// @custom:emits UnicornNaturalStatsChanged for each unicorn
    function cacheUnicornNaturalStatsBatch(uint256[] calldata tokenIds) external returns (Stats[] memory naturalStats);


    /// @notice Writes a collection of Unicorns' data to the StatCache, overwriting any previous data.
    /// @param tokenIds, An array of Unicorn ids
    /// @return enhancedStats The Stats structs written to cache
    /// @custom:emits UnicornEnhancedStatsChanged for each unicorn
    function cacheUnicornEnhancedStatsBatch(uint256[] calldata tokenIds) external returns (Stats[] memory enhancedStats);


    /// @notice Returns a Unicorn's natural stats, from the cache if available,
    ///     otherwise by (expensive) direct lookup.
    /// @param tokenId The id of a Unicorn
    /// @return naturalStats The Stats of the unicorn
    function getUnicornNaturalStats(uint256 tokenId) external view returns (Stats memory naturalStats);


    /// @notice Returns a Unicorn's enhanced stats, from the cache if available,
    ///     otherwise by (expensive) direct lookup.
    /// @param tokenId The id of a Unicorn
    /// @return enhancedStats The Stats of the unicorn
    function getUnicornEnhancedStats(uint256 tokenId) external view returns (Stats memory enhancedStats);


    /// @notice Returns a group of Unicorns' enhanced stats
    /// @dev This is an alias of getEnhancedUnicornStatsBatch
    /// @param tokenIds, An array of Unicorn ids
    /// @return naturalStats Corresponding stats for the unicorns specified in tokenIds
    function getUnicornNaturalStatsBatch(uint256[] calldata tokenIds) external view returns (Stats[] memory naturalStats);


    /// @notice Returns a group of Unicorns' enhanced stats
    /// @param tokenIds, An array of Unicorn ids
    /// @return enhancedStats Corresponding stats for the unicorns specified in tokenIds
    function getUnicornEnhancedStatsBatch(uint256[] calldata tokenIds) external view returns (Stats[] memory enhancedStats);


    /// @notice Returns a Unicorn's natural stats - from the cache if possible,
    ///     otherwise the cache will be updated.
    /// @dev May be expensive!
    /// @param tokenId The id of a Unicorn
    /// @return naturalStats The Stats of the unicorn
    function getAndCacheUnicornNaturalStats(uint256 tokenId) external returns (Stats memory naturalStats);


    /// @notice Returns a Unicorn's enhanced stats - from the cache if possible,
    ///     otherwise the cache will be updated.
    /// @dev This could hit BOTH caches - may be very expensive!
    /// @param tokenId The id of a Unicorn
    /// @return enhancedStats The Stats of the unicorn
    function getAndCacheUnicornEnhancedStats(uint256 tokenId) external returns (Stats memory enhancedStats);


    /// @notice Returns a collection of Unicorns' enhanced stats - from the cache if possible,
    ///     otherwise the cache will be updated
    /// @dev This could hit BOTH caches - may be VERY EXPENSIVE!
    /// @param tokenIds The id of a Unicorn
    /// @return enhancedStats The Stats of the unicorn
    function getAndCacheUnicornEnhancedStatsBatch(uint256[] calldata tokenIds) external returns (IUnicornStatCache.Stats[] memory enhancedStats);
}


// Chain: POLYGON - File: IUnicornERC721Facet.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IUnicornERC721Facet {
    function ownerOf(uint256 tokenId) external view returns (address);
}


// Chain: POLYGON - File: UnicornDNA.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library UnicornDNA {
    uint256 internal constant STAT_ATTACK = 1;
    uint256 internal constant STAT_ACCURACY = 2;
    uint256 internal constant STAT_MOVE_SPEED = 3;
    uint256 internal constant STAT_ATTACK_SPEED = 4;
    uint256 internal constant STAT_DEFENSE = 5;
    uint256 internal constant STAT_VITALITY = 6;
    uint256 internal constant STAT_RESISTANCE = 7;
    uint256 internal constant STAT_MAGIC = 8;

    uint8 internal constant LIFECYCLE_EGG = 0;
    uint8 internal constant LIFECYCLE_BABY = 1;
    uint8 internal constant LIFECYCLE_ADULT = 2;
}

// Chain: POLYGON - File: LibGasReturner.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LibEvents} from "LibEvents.sol";

library LibGasReturner {
    bytes32 private constant LIB_GAS_RETURNER_STORAGE_POSITION =
        keccak256("diamond.DarkForest.GasReturner.storage");

    enum GasReturnerTransactionType {
        NONE, // 0
        DEFEND, // 1
        ATTACK_WITH_1_CACHED_UNICORN, // 2
        ATTACK_WITH_2_CACHED_UNICORNS, // 3
        ATTACK_WITH_3_CACHED_UNICORNS, // 4
        ATTACK_WITH_NO_CACHED_UNICORNS //5
    }

    struct LibGasReturnerStorage {
        mapping(GasReturnerTransactionType transactionType => uint256 maxGasReturnedPerTransaction) maxGasReturnedPerTransactionType; // in wei, not gas units
    }

    function gasReturnerStorage()
        internal
        pure
        returns (LibGasReturnerStorage storage lgrs)
    {
        bytes32 position = LIB_GAS_RETURNER_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            lgrs.slot := position
        }
    }

    function returnGasToUser(
        GasReturnerTransactionType transactionType,
        uint256 gasSpent,
        address payable user
    ) internal {
        uint256 maxGasReturned = getMaxGasReturnedPerTransaction(
            transactionType
        );

        if (maxGasReturned == 0) {
            return;
        }

        uint256 totalToReturn = gasSpent * tx.gasprice;

        if (totalToReturn > maxGasReturned) {
            totalToReturn = maxGasReturned;
        }

        if (address(this).balance < totalToReturn) {
            emit LibEvents.GasReturnedToUser(
                0,
                tx.gasprice,
                gasSpent,
                user,
                false,
                transactionType
            );
            return;
        }

        (bool sent, ) = user.call{value: totalToReturn}("");

        emit LibEvents.GasReturnedToUser(
            totalToReturn,
            tx.gasprice,
            gasSpent,
            user,
            sent,
            transactionType
        );
    }

    function setMaxGasReturnedPerTransaction(
        GasReturnerTransactionType[] memory transactionType,
        uint256[] memory maxGasReturned
    ) internal {
        require(
            transactionType.length == maxGasReturned.length,
            "GR-001"
        );

        require(
            transactionType.length > 0,
            "GR-002"
        );

        for (uint256 i = 0; i < transactionType.length; ++i) {
            require(
                transactionType[i] != GasReturnerTransactionType.NONE,
                "GR-003"
            );

            emit LibEvents.GasReturnerMaxGasReturnedPerTransactionChanged(
                gasReturnerStorage().maxGasReturnedPerTransactionType[
                    transactionType[i]
                ],
                maxGasReturned[i],
                msg.sender
            );

            gasReturnerStorage().maxGasReturnedPerTransactionType[
                transactionType[i]
            ] = maxGasReturned[i];
        }
    }

    function getMaxGasReturnedPerTransaction(
        GasReturnerTransactionType transactionType
    ) internal view returns (uint256) {
        return
            gasReturnerStorage().maxGasReturnedPerTransactionType[
                transactionType
            ];
    }
}


// Chain: POLYGON - File: IShadowcornStatsFacet.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IShadowcornStatsFacet {

    // //  Classes
    // uint256 constant FIRE = 1;
    // uint256 constant SLIME = 2;
    // uint256 constant VOLT = 3;
    // uint256 constant SOUL = 4;
    // uint256 constant NEBULA = 5;

    // //  Stats
    // uint256 constant MIGHT = 1;
    // uint256 constant WICKEDNESS = 2;
    // uint256 constant TENACITY = 3;
    // uint256 constant CUNNING = 4;
    // uint256 constant ARCANA = 5;

    // //  Rarities
    // uint256 constant COMMON = 1;
    // uint256 constant RARE = 2;
    // uint256 constant MYTHIC = 3;

    function getClass(uint256 tokenId) external view returns (uint256 class);
    function getClassRarityAndStat(uint256 tokenId, uint256 statId) external view returns (uint256 class, uint256 rarity, uint256 stat);
    function getStats(uint256 tokenId) external view returns (uint256 might, uint256 wickedness, uint256 tenacity, uint256 cunning, uint256 arcana);
    function getMight(uint256 tokenId) external view returns (uint256 might);
    function getWickedness(uint256 tokenId) external view returns (uint256 wickedness);
    function getTenacity(uint256 tokenId) external view returns (uint256 tenacity);
    function getCunning(uint256 tokenId) external view returns (uint256 cunning);
    function getArcana(uint256 tokenId) external view returns (uint256 arcana);
    function getRarity(uint256 tokenId) external view returns (uint256 rarity);
}


// Chain: POLYGON - File: TerminusFacet.sol
// SPDX-License-Identifier: Apache-2.0

/**
 * Authors: Moonstream Engineering (engineering@moonstream.to)
 * GitHub: https://github.com/bugout-dev/dao
 *
 * This is an implementation of the Terminus decentralized authorization contract.
 *
 * Terminus users can create authorization pools. Each authorization pool has the following properties:
 * 1. Controller: The address that controls the pool. Initially set to be the address of the pool creator.
 * 2. Pool URI: Metadata URI for the authorization pool.
 * 3. Pool capacity: The total number of tokens that can be minted in that authorization pool.
 * 4. Pool supply: The number of tokens that have actually been minted in that authorization pool.
 * 5. Transferable: A boolean value which denotes whether or not tokens from that pool can be transfered
 *    between addresses. (Note: Implemented by TerminusStorage.poolNotTransferable since we expect most
 *    pools to be transferable. This negation is better for storage + gas since false is default value
 *    in map to bool.)
 * 6. Burnable: A boolean value which denotes whether or not tokens from that pool can be burned.
 */

pragma solidity ^0.8.0;

import "IERC20.sol";
import "ERC1155WithTerminusStorage.sol";
import "LibTerminus.sol";
import "LibDiamond.sol";

contract TerminusFacet is ERC1155WithTerminusStorage {
    constructor() {
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        ts.controller = msg.sender;
    }

    event PoolMintBatch(
        uint256 indexed id,
        address indexed operator,
        address from,
        address[] toAddresses,
        uint256[] amounts
    );

    function poolMintBatch(
        uint256 id,
        address[] memory toAddresses,
        uint256[] memory amounts
    ) public {
        address operator = _msgSender();
        LibTerminus.enforcePoolIsController(id, operator);
        require(
            toAddresses.length == amounts.length,
            "TerminusFacet: _poolMintBatch -- toAddresses and amounts length mismatch"
        );

        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();

        uint256 i = 0;
        uint256 totalAmount = 0;

        for (i = 0; i < toAddresses.length; i++) {
            address to = toAddresses[i];
            uint256 amount = amounts[i];
            require(
                to != address(0),
                "TerminusFacet: _poolMintBatch -- cannot mint to zero address"
            );
            totalAmount += amount;
            ts.poolBalances[id][to] += amount;
            emit TransferSingle(operator, address(0), to, id, amount);
        }

        require(
            ts.poolSupply[id] + totalAmount <= ts.poolCapacity[id],
            "TerminusFacet: _poolMintBatch -- Minted tokens would exceed pool capacity"
        );
        ts.poolSupply[id] += totalAmount;

        emit PoolMintBatch(id, operator, address(0), toAddresses, amounts);
    }

    function terminusController() external view returns (address) {
        return LibTerminus.terminusStorage().controller;
    }

    function paymentToken() external view returns (address) {
        return LibTerminus.terminusStorage().paymentToken;
    }

    function setPaymentToken(address newPaymentToken) external {
        LibTerminus.enforceIsController();
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        ts.paymentToken = newPaymentToken;
    }

    function poolBasePrice() external view returns (uint256) {
        return LibTerminus.terminusStorage().poolBasePrice;
    }

    function setPoolBasePrice(uint256 newBasePrice) external {
        LibTerminus.enforceIsController();
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        ts.poolBasePrice = newBasePrice;
    }

    function _paymentTokenContract() internal view returns (IERC20) {
        address paymentTokenAddress = LibTerminus
            .terminusStorage()
            .paymentToken;
        require(
            paymentTokenAddress != address(0),
            "TerminusFacet: Payment token has not been set"
        );
        return IERC20(paymentTokenAddress);
    }

    function withdrawPayments(address toAddress, uint256 amount) external {
        LibTerminus.enforceIsController();
        require(
            _msgSender() == toAddress,
            "TerminusFacet: withdrawPayments -- Controller can only withdraw to self"
        );
        IERC20 paymentTokenContract = _paymentTokenContract();
        paymentTokenContract.transfer(toAddress, amount);
    }

    function setURI(uint256 poolID, string memory poolURI) external {
        LibTerminus.enforcePoolIsController(poolID, _msgSender());
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        ts.poolURI[poolID] = poolURI;
    }

    function totalPools() external view returns (uint256) {
        return LibTerminus.terminusStorage().currentPoolID;
    }

    function setPoolController(uint256 poolID, address newController) external {
        LibTerminus.enforcePoolIsController(poolID, msg.sender);
        LibTerminus.setPoolController(poolID, newController);
    }

    function terminusPoolController(uint256 poolID)
        external
        view
        returns (address)
    {
        return LibTerminus.terminusStorage().poolController[poolID];
    }

    function terminusPoolCapacity(uint256 poolID)
        external
        view
        returns (uint256)
    {
        return LibTerminus.terminusStorage().poolCapacity[poolID];
    }

    function terminusPoolSupply(uint256 poolID)
        external
        view
        returns (uint256)
    {
        return LibTerminus.terminusStorage().poolSupply[poolID];
    }

    function createSimplePool(uint256 _capacity) external returns (uint256) {
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        uint256 requiredPayment = ts.poolBasePrice;
        IERC20 paymentTokenContract = _paymentTokenContract();
        require(
            paymentTokenContract.allowance(_msgSender(), address(this)) >=
                requiredPayment,
            "TerminusFacet: createSimplePool -- Insufficient allowance on payment token"
        );
        paymentTokenContract.transferFrom(
            msg.sender,
            address(this),
            requiredPayment
        );
        return LibTerminus.createSimplePool(_capacity);
    }

    function createPoolV1(
        uint256 _capacity,
        bool _transferable,
        bool _burnable
    ) external returns (uint256) {
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        // TODO(zomglings): Implement requiredPayment update based on pool features.
        uint256 requiredPayment = ts.poolBasePrice;
        IERC20 paymentTokenContract = _paymentTokenContract();
        require(
            paymentTokenContract.allowance(_msgSender(), address(this)) >=
                requiredPayment,
            "TerminusFacet: createPoolV1 -- Insufficient allowance on payment token"
        );
        paymentTokenContract.transferFrom(
            msg.sender,
            address(this),
            requiredPayment
        );
        uint256 poolID = LibTerminus.createSimplePool(_capacity);
        if (!_transferable) {
            ts.poolNotTransferable[poolID] = true;
        }
        if (_burnable) {
            ts.poolBurnable[poolID] = true;
        }
        return poolID;
    }

    function mint(
        address to,
        uint256 poolID,
        uint256 amount,
        bytes memory data
    ) external {
        LibTerminus.enforcePoolIsController(poolID, msg.sender);
        _mint(to, poolID, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory poolIDs,
        uint256[] memory amounts,
        bytes memory data
    ) external {
        for (uint256 i = 0; i < poolIDs.length; i++) {
            LibTerminus.enforcePoolIsController(poolIDs[i], _msgSender());
        }
        _mintBatch(to, poolIDs, amounts, data);
    }

    function burn(
        address from,
        uint256 poolID,
        uint256 amount
    ) external {
        address operator = _msgSender();
        require(
            operator == from || isApprovedForPool(poolID, operator),
            "TerminusFacet: burn -- caller is neither owner nor approved"
        );
        _burn(from, poolID, amount);
    }
}


// Chain: POLYGON - File: ERC1155WithTerminusStorage.sol
// SPDX-License-Identifier: Apache-2.0

/**
 * Authors: Moonstream Engineering (engineering@moonstream.to)
 * GitHub: https://github.com/bugout-dev/dao
 *
 * An ERC1155 implementation which uses the Moonstream DAO common storage structure for proxies.
 * EIP1155: https://eips.ethereum.org/EIPS/eip-1155
 *
 * The Moonstream contract is used to delegate calls from an EIP2535 Diamond proxy.
 *
 * This implementation is adapted from the OpenZeppelin ERC1155 implementation:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/tree/6bd6b76d1156e20e45d1016f355d154141c7e5b9/contracts/token/ERC1155
 */

pragma solidity ^0.8.9;

import "IERC1155.sol";
import "IERC1155Receiver.sol";
import "IERC1155MetadataURI.sol";
import "Address.sol";
import "Context.sol";
import "ERC165.sol";
import "LibTerminus.sol";

contract ERC1155WithTerminusStorage is
    Context,
    ERC165,
    IERC1155,
    IERC1155MetadataURI
{
    using Address for address;

    constructor() {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function uri(uint256 poolID)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return LibTerminus.terminusStorage().poolURI[poolID];
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            account != address(0),
            "ERC1155WithTerminusStorage: balance query for the zero address"
        );
        return LibTerminus.terminusStorage().poolBalances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(
            accounts.length == ids.length,
            "ERC1155WithTerminusStorage: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            LibTerminus.terminusStorage().globalOperatorApprovals[account][
                operator
            ];
    }

    function isApprovedForPool(uint256 poolID, address operator)
        public
        view
        returns (bool)
    {
        return LibTerminus._isApprovedForPool(poolID, operator);
    }

    function approveForPool(uint256 poolID, address operator) external {
        LibTerminus.enforcePoolIsController(poolID, _msgSender());
        LibTerminus._approveForPool(poolID, operator);
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
    ) public virtual override {
        require(
            from == _msgSender() ||
                isApprovedForAll(from, _msgSender()) ||
                isApprovedForPool(id, _msgSender()),
            "ERC1155WithTerminusStorage: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
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
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155WithTerminusStorage: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(
            to != address(0),
            "ERC1155WithTerminusStorage: transfer to the zero address"
        );
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        require(
            !ts.poolNotTransferable[id],
            "ERC1155WithTerminusStorage: _safeTransferFrom -- pool is not transferable"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            from,
            to,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        uint256 fromBalance = ts.poolBalances[id][from];
        require(
            fromBalance >= amount,
            "ERC1155WithTerminusStorage: insufficient balance for transfer"
        );
        unchecked {
            ts.poolBalances[id][from] = fromBalance - amount;
        }
        ts.poolBalances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
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
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(
            ids.length == amounts.length,
            "ERC1155WithTerminusStorage: ids and amounts length mismatch"
        );
        require(
            to != address(0),
            "ERC1155WithTerminusStorage: transfer to the zero address"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = ts.poolBalances[id][from];
            require(
                fromBalance >= amount,
                "ERC1155WithTerminusStorage: insufficient balance for transfer"
            );
            unchecked {
                ts.poolBalances[id][from] = fromBalance - amount;
            }
            ts.poolBalances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(
            operator,
            from,
            to,
            ids,
            amounts,
            data
        );
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(
            to != address(0),
            "ERC1155WithTerminusStorage: mint to the zero address"
        );
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        require(
            ts.poolSupply[id] + amount <= ts.poolCapacity[id],
            "ERC1155WithTerminusStorage: _mint -- Minted tokens would exceed pool capacity"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            address(0),
            to,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        ts.poolSupply[id] += amount;
        ts.poolBalances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _doSafeTransferAcceptanceCheck(
            operator,
            address(0),
            to,
            id,
            amount,
            data
        );
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
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(
            to != address(0),
            "ERC1155WithTerminusStorage: mint to the zero address"
        );
        require(
            ids.length == amounts.length,
            "ERC1155WithTerminusStorage: ids and amounts length mismatch"
        );

        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();

        for (uint256 i = 0; i < ids.length; i++) {
            require(
                ts.poolSupply[ids[i]] + amounts[i] <= ts.poolCapacity[ids[i]],
                "ERC1155WithTerminusStorage: _mintBatch -- Minted tokens would exceed pool capacity"
            );
        }

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            ts.poolSupply[ids[i]] += amounts[i];
            ts.poolBalances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(
            operator,
            address(0),
            to,
            ids,
            amounts,
            data
        );
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(
            from != address(0),
            "ERC1155WithTerminusStorage: burn from the zero address"
        );
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        require(
            ts.poolBurnable[id],
            "ERC1155WithTerminusStorage: _burn -- pool is not burnable"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            from,
            address(0),
            _asSingletonArray(id),
            _asSingletonArray(amount),
            ""
        );

        uint256 fromBalance = ts.poolBalances[id][from];
        require(
            fromBalance >= amount,
            "ERC1155WithTerminusStorage: burn amount exceeds balance"
        );
        unchecked {
            ts.poolBalances[id][from] = fromBalance - amount;
            ts.poolSupply[id] -= amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(
            from != address(0),
            "ERC1155WithTerminusStorage: burn from the zero address"
        );
        require(
            ids.length == amounts.length,
            "ERC1155WithTerminusStorage: ids and amounts length mismatch"
        );

        address operator = _msgSender();

        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        for (uint256 i = 0; i < ids.length; i++) {
            require(
                ts.poolBurnable[ids[i]],
                "ERC1155WithTerminusStorage: _burnBatch -- pool is not burnable"
            );
        }

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = ts.poolBalances[id][from];
            require(
                fromBalance >= amount,
                "ERC1155WithTerminusStorage: burn amount exceeds balance"
            );
            unchecked {
                ts.poolBalances[id][from] = fromBalance - amount;
                ts.poolSupply[id] -= amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(
            owner != operator,
            "ERC1155WithTerminusStorage: setting approval status for self"
        );
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        ts.globalOperatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
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
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert(
                        "ERC1155WithTerminusStorage: ERC1155Receiver rejected tokens"
                    );
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert(
                    "ERC1155WithTerminusStorage: transfer to non ERC1155Receiver implementer"
                );
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
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (
                    response != IERC1155Receiver.onERC1155BatchReceived.selector
                ) {
                    revert(
                        "ERC1155WithTerminusStorage: ERC1155Receiver rejected tokens"
                    );
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert(
                    "ERC1155WithTerminusStorage: transfer to non ERC1155Receiver implementer"
                );
            }
        }
    }

    function _asSingletonArray(uint256 element)
        private
        pure
        returns (uint256[] memory)
    {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}


// Chain: POLYGON - File: LibTerminus.sol
// SPDX-License-Identifier: Apache-2.0

/**
 * Authors: Moonstream Engineering (engineering@moonstream.to)
 * GitHub: https://github.com/bugout-dev/dao
 *
 * Common storage structure and internal methods for Moonstream DAO Terminus contracts.
 * As Terminus is an extension of ERC1155, this library can also be used to implement bare ERC1155 contracts
 * using the common storage pattern (e.g. for use in diamond proxies).
 */

// TODO(zomglings): Should we support EIP1761 in addition to ERC1155 or roll our own scopes and feature flags?
// https://eips.ethereum.org/EIPS/eip-1761

pragma solidity ^0.8.9;

library LibTerminus {
    bytes32 constant TERMINUS_STORAGE_POSITION =
        keccak256("moonstreamdao.eth.storage.terminus");

    struct TerminusStorage {
        // Terminus administration
        address controller;
        bool isTerminusActive;
        uint256 currentPoolID;
        address paymentToken;
        uint256 poolBasePrice;
        // Terminus pools
        mapping(uint256 => address) poolController;
        mapping(uint256 => string) poolURI;
        mapping(uint256 => uint256) poolCapacity;
        mapping(uint256 => uint256) poolSupply;
        mapping(uint256 => mapping(address => uint256)) poolBalances;
        mapping(uint256 => bool) poolNotTransferable;
        mapping(uint256 => bool) poolBurnable;
        mapping(address => mapping(address => bool)) globalOperatorApprovals;
        mapping(uint256 => mapping(address => bool)) globalPoolOperatorApprovals;
    }

    function terminusStorage()
        internal
        pure
        returns (TerminusStorage storage es)
    {
        bytes32 position = TERMINUS_STORAGE_POSITION;
        assembly {
            es.slot := position
        }
    }

    event ControlTransferred(
        address indexed previousController,
        address indexed newController
    );

    event PoolControlTransferred(
        uint256 indexed poolID,
        address indexed previousController,
        address indexed newController
    );

    function setController(address newController) internal {
        TerminusStorage storage ts = terminusStorage();
        address previousController = ts.controller;
        ts.controller = newController;
        emit ControlTransferred(previousController, newController);
    }

    function enforceIsController() internal view {
        TerminusStorage storage ts = terminusStorage();
        require(msg.sender == ts.controller, "LibTerminus: Must be controller");
    }

    function setTerminusActive(bool active) internal {
        TerminusStorage storage ts = terminusStorage();
        ts.isTerminusActive = active;
    }

    function setPoolController(uint256 poolID, address newController) internal {
        TerminusStorage storage ts = terminusStorage();
        address previousController = ts.poolController[poolID];
        ts.poolController[poolID] = newController;
        emit PoolControlTransferred(poolID, previousController, newController);
    }

    function createSimplePool(uint256 _capacity) internal returns (uint256) {
        TerminusStorage storage ts = terminusStorage();
        uint256 poolID = ts.currentPoolID + 1;
        setPoolController(poolID, msg.sender);
        ts.poolCapacity[poolID] = _capacity;
        ts.currentPoolID++;
        return poolID;
    }

    function enforcePoolIsController(uint256 poolID, address maybeController)
        internal
        view
    {
        TerminusStorage storage ts = terminusStorage();
        require(
            ts.poolController[poolID] == maybeController,
            "LibTerminus: Must be pool controller"
        );
    }

    function _isApprovedForPool(uint256 poolID, address operator)
        internal
        view
        returns (bool)
    {
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        if (operator == ts.poolController[poolID]) {
            return true;
        } else if (ts.globalPoolOperatorApprovals[poolID][operator]) {
            return true;
        }
        return false;
    }

    function _approveForPool(uint256 poolID, address operator) internal {
        LibTerminus.TerminusStorage storage ts = LibTerminus.terminusStorage();
        ts.globalPoolOperatorApprovals[poolID][operator] = true;
    }
}


// Chain: POLYGON - File: IStakingFacet.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
interface IStakingFacet {
    struct StakeData {
        address staker; //  Address of the staker
        bool staked; //  TRUE if the stake is active
        uint256 farmableItemId; //  Id of the FarmableItem being farmed
        uint256 stakeTimestamp; //  Timestamp of the stake
    }

    /// @notice Retrieves the staking information for a specific Shadowcorn token
    /// @param tokenId The ID of the Shadowcorn token for which to retrieve the staking information
    /// @return A LibStructs.StakeData struct containing the staking details for the specified token
    function getStakingInfoByShadowcornId(
        uint256 tokenId
    ) external view returns (StakeData memory);
}