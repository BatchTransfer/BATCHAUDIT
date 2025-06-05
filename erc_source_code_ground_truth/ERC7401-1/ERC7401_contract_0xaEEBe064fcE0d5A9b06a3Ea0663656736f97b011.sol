// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.21;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC6220} from "../equippable/IERC6220.sol";
import {IERC5773} from "../multiasset/IERC5773.sol";
import {IERC7401} from "../nestable/IERC7401.sol";
import {IERC6454} from "../extension/soulbound/IERC6454.sol";
import {IRMRKCollectionData} from "./IRMRKCollectionData.sol";

/**
 * @title RMRKCollectionUtils
 * @author RMRK team
 * @notice Smart contract of the RMRK Collection utils module.
 * @dev Extra utility functions for RMRK contracts.
 */
contract RMRKCollectionUtils {
    event CollectionTokensMetadataRefreshTriggered(address indexed collection);
    event TokenMetadataRefreshTriggered(
        address indexed collection,
        uint256 indexed tokenId
    );

    /**
     * notice Structure used to represent the collection data.
     * @return totalSupply The total supply of the collection
     * @return maxSupply The maximum supply of the collection
     * @return royaltyPercentage The royalty percentage of the collection
     * @return royaltyRecipient The address of the royalty recipient
     * @return owner The address of the owner of the collection
     * @return name The name of the collection
     * @return symbol The symbol of the collection
     * @return collectionMetadata The metadata of the collection
     */
    struct CollectionData {
        uint256 totalSupply;
        uint256 maxSupply;
        uint256 royaltyPercentage;
        address royaltyRecipient;
        address owner;
        string name;
        string symbol;
        string collectionMetadata;
    }

    /**
     * @notice Used to get the collection data of a specified collection.
     * @dev The full `CollectionData` struct looks like this:
     *  [
     *      totalSupply,
     *      maxSupply,
     *      royaltyPercentage,
     *      royaltyRecipient,
     *      owner,
     *      symbol,
     *      name,
     *      collectionMetadata
     *  ]
     * @param collection Address of the collection to get the data from
     * @return data Collection data struct containing the collection data
     */
    function getCollectionData(
        address collection
    ) public view returns (CollectionData memory data) {
        IRMRKCollectionData target = IRMRKCollectionData(collection);

        try target.totalSupply() returns (uint256 totalSupply) {
            data.totalSupply = totalSupply;
        } catch {}
        try target.maxSupply() returns (uint256 maxSupply) {
            data.maxSupply = maxSupply;
        } catch {}
        try target.getRoyaltyPercentage() returns (uint256 royaltyPercentage) {
            data.royaltyPercentage = royaltyPercentage;
        } catch {}
        try target.getRoyaltyRecipient() returns (address royaltyRecipient) {
            data.royaltyRecipient = royaltyRecipient;
        } catch {}
        try target.owner() returns (address owner) {
            data.owner = owner;
        } catch {}
        try target.name() returns (string memory name) {
            data.name = name;
        } catch {}
        try target.symbol() returns (string memory symbol) {
            data.symbol = symbol;
        } catch {}
        try target.collectionMetadata() returns (
            string memory collectionMetadata
        ) {
            data.collectionMetadata = collectionMetadata;
        } catch {
            try target.contractURI() returns (
                string memory collectionMetadata
            ) {
                data.collectionMetadata = collectionMetadata;
            } catch {}
        }
    }

    /**
     * @notice Used to get the interface support of a specified collection.
     * @param collection Address of the collection to get the interface support from
     * @return supports721 Boolean value signifying whether the collection supports ERC721 interface
     * @return supportsMultiAsset Boolean value signifying whether the collection supports MultiAsset interface (ERC5773)
     * @return supportsNesting Boolean value signifying whether the collection supports Nestable interface (ERC7401)
     * @return supportsEquippable Boolean value signifying whether the collection supports Equippable interface (ERC6220)
     * @return supportsSoulbound Boolean value signifying whether the collection supports Soulbound interface (ERC6454)
     * @return supportsRoyalties Boolean value signifying whether the collection supports Royaltiesy interface (ERC2981)
     */
    function getInterfaceSupport(
        address collection
    )
        public
        view
        returns (
            bool supports721,
            bool supportsMultiAsset,
            bool supportsNesting,
            bool supportsEquippable,
            bool supportsSoulbound,
            bool supportsRoyalties
        )
    {
        IERC165 target = IERC165(collection);
        supports721 = target.supportsInterface(type(IERC721).interfaceId);
        supportsMultiAsset = target.supportsInterface(
            type(IERC5773).interfaceId
        );
        supportsNesting = target.supportsInterface(type(IERC7401).interfaceId);
        supportsEquippable = target.supportsInterface(
            type(IERC6220).interfaceId
        );
        supportsSoulbound = target.supportsInterface(
            type(IERC6454).interfaceId
        );
        supportsRoyalties = target.supportsInterface(
            type(IERC2981).interfaceId
        );
    }

    /**
     * @notice Used to get a list of existing token IDs in the range between `pageStart` and `pageSize`.
     * @dev It is not optimized to avoid checking IDs out of max supply nor total supply, since this is not meant to be
     *  used during transaction execution; it is only meant to be used as a getter.
     * @dev The resulting array might be smaller than the given `pageSize` since no-existent IDs are not included.
     * @param targetEquippable Address of the collection smart contract of the given token
     * @param pageStart The first ID to check
     * @param pageSize The number of IDs to check
     * @return page An array of IDs of the existing tokens
     */
    function getPaginatedMintedIds(
        address targetEquippable,
        uint256 pageStart,
        uint256 pageSize
    ) public view returns (uint256[] memory page) {
        uint256[] memory tmpIds = new uint[](pageSize);
        uint256 found;
        for (uint256 i = 0; i < pageSize; ) {
            try IERC721(targetEquippable).ownerOf(pageStart + i) returns (
                address
            ) {
                tmpIds[i] = pageStart + i;
                unchecked {
                    found += 1;
                }
            } catch {
                // do nothing
            }
            unchecked {
                ++i;
            }
        }
        page = new uint256[](found);
        uint256 actualIndex;
        for (uint256 i = 0; i < pageSize; ) {
            if (tmpIds[i] != 0) {
                page[actualIndex] = tmpIds[i];
                unchecked {
                    ++actualIndex;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Triggers an event to refresh the collection metadata.
     * @dev It will do nothing if the given collection address is not a contract.
     * @param collectionAddress Address of the collection to refresh the metadata from
     */
    function refreshCollectionTokensMetadata(address collectionAddress) public {
        // To avoid some spam
        if (collectionAddress.code.length == 0) {
            return;
        }
        emit CollectionTokensMetadataRefreshTriggered(collectionAddress);
    }

    /**
     * @notice Triggers an event to refresh the token metadata.
     * @dev It will do nothing if the given collection address is not a contract.
     * @param collectionAddress Address of the collection to refresh the metadata from
     * @param tokenId ID of the token to refresh the metadata from
     */
    function refreshTokenMetadata(
        address collectionAddress,
        uint256 tokenId
    ) public {
        // To avoid some spam
        if (collectionAddress.code.length == 0) {
            return;
        }
        emit TokenMetadataRefreshTriggered(collectionAddress, tokenId);
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../utils/introspection/IERC165.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.20;

import {IERC721} from "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

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
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
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
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
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
     * - The `operator` cannot be the address zero.
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
}// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.21;

import {IERC5773} from "../multiasset/IERC5773.sol";

/**
 * @title IERC6220
 * @author RMRK team
 * @notice Interface smart contract of the RMRK equippable module.
 */
interface IERC6220 is IERC5773 {
    /**
     * @notice Used to store the core structure of the `Equippable` RMRK lego.
     * @return assetId The ID of the asset equipping a child
     * @return childAssetId The ID of the asset used as equipment
     * @return childId The ID of token that is equipped
     * @return childEquippableAddress Address of the collection to which the child asset belongs to
     */
    struct Equipment {
        uint64 assetId;
        uint64 childAssetId;
        uint256 childId;
        address childEquippableAddress;
    }

    /**
     * @notice Used to provide a struct for inputing equip data.
     * @dev Only used for input and not storage of data.
     * @return tokenId ID of the token we are managing
     * @return childIndex Index of a child in the list of token's active children
     * @return assetId ID of the asset that we are equipping into
     * @return slotPartId ID of the slot part that we are using to equip
     * @return childAssetId ID of the asset that we are equipping
     */
    struct IntakeEquip {
        uint256 tokenId;
        uint256 childIndex;
        uint64 assetId;
        uint64 slotPartId;
        uint64 childAssetId;
    }

    /**
     * @notice Used to notify listeners that a child's asset has been equipped into one of its parent assets.
     * @param tokenId ID of the token that had an asset equipped
     * @param assetId ID of the asset associated with the token we are equipping into
     * @param slotPartId ID of the slot we are using to equip
     * @param childId ID of the child token we are equipping into the slot
     * @param childAddress Address of the child token's collection
     * @param childAssetId ID of the asset associated with the token we are equipping
     */
    event ChildAssetEquipped(
        uint256 indexed tokenId,
        uint64 indexed assetId,
        uint64 indexed slotPartId,
        uint256 childId,
        address childAddress,
        uint64 childAssetId
    );

    /**
     * @notice Used to notify listeners that a child's asset has been unequipped from one of its parent assets.
     * @param tokenId ID of the token that had an asset unequipped
     * @param assetId ID of the asset associated with the token we are unequipping out of
     * @param slotPartId ID of the slot we are unequipping from
     * @param childId ID of the token being unequipped
     * @param childAddress Address of the collection that a token that is being unequipped belongs to
     * @param childAssetId ID of the asset associated with the token we are unequipping
     */
    event ChildAssetUnequipped(
        uint256 indexed tokenId,
        uint64 indexed assetId,
        uint64 indexed slotPartId,
        uint256 childId,
        address childAddress,
        uint64 childAssetId
    );

    /**
     * @notice Used to notify listeners that the assets belonging to a `equippableGroupId` have been marked as
     *  equippable into a given slot and parent
     * @param equippableGroupId ID of the equippable group being marked as equippable into the slot associated with
     *  `slotPartId` of the `parentAddress` collection
     * @param slotPartId ID of the slot part of the catalog into which the parts belonging to the equippable group
     *  associated with `equippableGroupId` can be equipped
     * @param parentAddress Address of the collection into which the parts belonging to `equippableGroupId` can be
     *  equipped
     */
    event ValidParentEquippableGroupIdSet(
        uint64 indexed equippableGroupId,
        uint64 indexed slotPartId,
        address parentAddress
    );

    /**
     * @notice Used to equip a child into a token.
     * @dev The `IntakeEquip` stuct contains the following data:
     *  [
     *      tokenId,
     *      childIndex,
     *      assetId,
     *      slotPartId,
     *      childAssetId
     *  ]
     * @param data An `IntakeEquip` struct specifying the equip data
     */
    function equip(IntakeEquip memory data) external;

    /**
     * @notice Used to unequip child from parent token.
     * @dev This can only be called by the owner of the token or by an account that has been granted permission to
     *  manage the given token by the current owner.
     * @param tokenId ID of the parent from which the child is being unequipped
     * @param assetId ID of the parent's asset that contains the `Slot` into which the child is equipped
     * @param slotPartId ID of the `Slot` from which to unequip the child
     */
    function unequip(
        uint256 tokenId,
        uint64 assetId,
        uint64 slotPartId
    ) external;

    /**
     * @notice Used to check whether the token has a given child equipped.
     * @dev This is used to prevent from transferring a child that is equipped.
     * @param tokenId ID of the parent token for which we are querying for
     * @param childAddress Address of the child token's smart contract
     * @param childId ID of the child token
     * @return A boolean value indicating whether the child token is equipped into the given token or not
     */
    function isChildEquipped(
        uint256 tokenId,
        address childAddress,
        uint256 childId
    ) external view returns (bool);

    /**
     * @notice Used to verify whether a token can be equipped into a given parent's slot.
     * @param parent Address of the parent token's smart contract
     * @param tokenId ID of the token we want to equip
     * @param assetId ID of the asset associated with the token we want to equip
     * @param slotId ID of the slot that we want to equip the token into
     * @return A boolean indicating whether the token with the given asset can be equipped into the desired slot
     */
    function canTokenBeEquippedWithAssetIntoSlot(
        address parent,
        uint256 tokenId,
        uint64 assetId,
        uint64 slotId
    ) external view returns (bool);

    /**
     * @notice Used to get the Equipment object equipped into the specified slot of the desired token.
     * @dev The `Equipment` struct consists of the following data:
     *  [
     *      assetId,
     *      childAssetId,
     *      childId,
     *      childEquippableAddress
     *  ]
     * @param tokenId ID of the token for which we are retrieving the equipped object
     * @param targetCatalogAddress Address of the `Catalog` associated with the `Slot` part of the token
     * @param slotPartId ID of the `Slot` part that we are checking for equipped objects
     * @return The `Equipment` struct containing data about the equipped object
     */
    function getEquipment(
        uint256 tokenId,
        address targetCatalogAddress,
        uint64 slotPartId
    ) external view returns (Equipment memory);

    /**
     * @notice Used to get the asset and equippable data associated with given `assetId`.
     * @param tokenId ID of the token for which to retrieve the asset
     * @param assetId ID of the asset of which we are retrieving
     * @return metadataURI The metadata URI of the asset
     * @return equippableGroupId ID of the equippable group this asset belongs to
     * @return catalogAddress The address of the catalog the part belongs to
     * @return partIds An array of IDs of parts included in the asset
     */
    function getAssetAndEquippableData(
        uint256 tokenId,
        uint64 assetId
    )
        external
        view
        returns (
            string memory metadataURI,
            uint64 equippableGroupId,
            address catalogAddress,
            uint64[] memory partIds
        );
}// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.21;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC6454
 * @author RMRK team
 * @notice A minimal extension to identify the transferability of Non-Fungible Tokens.
 */
interface IERC6454 is IERC165 {
    /**
     * @notice Used to check whether the given token is transferable or not.
     * @dev If this function returns `false`, the transfer of the token MUST revert execution.
     * @dev If the tokenId does not exist, this method MUST revert execution, unless the token is being checked for
     *  minting.
     * @param tokenId ID of the token being checked
     * @param from Address from which the token is being transferred
     * @param to Address to which the token is being transferred
     * @return Boolean value indicating whether the given token is transferable
     */
    function isTransferable(
        uint256 tokenId,
        address from,
        address to
    ) external view returns (bool);
}// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.21;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC5773
 * @author RMRK team
 * @notice Interface smart contract of the RMRK multi asset module.
 */
interface IERC5773 is IERC165 {
    /**
     * @notice Used to notify listeners that an asset object is initialized at `assetId`.
     * @param assetId ID of the asset that was initialized
     */
    event AssetSet(uint64 indexed assetId);

    /**
     * @notice Used to notify listeners that an asset object at `assetId` is added to token's pending asset
     *  array.
     * @param tokenIds An array of token IDs that received a new pending asset
     * @param assetId ID of the asset that has been added to the token's pending assets array
     * @param replacesId ID of the asset that would be replaced
     */
    event AssetAddedToTokens(
        uint256[] tokenIds,
        uint64 indexed assetId,
        uint64 indexed replacesId
    );

    /**
     * @notice Used to notify listeners that an asset object at `assetId` is accepted by the token and migrated
     *  from token's pending assets array to active assets array of the token.
     * @param tokenId ID of the token that had a new asset accepted
     * @param assetId ID of the asset that was accepted
     * @param replacesId ID of the asset that was replaced
     */
    event AssetAccepted(
        uint256 indexed tokenId,
        uint64 indexed assetId,
        uint64 indexed replacesId
    );

    /**
     * @notice Used to notify listeners that an asset object at `assetId` is rejected from token and is dropped
     *  from the pending assets array of the token.
     * @param tokenId ID of the token that had an asset rejected
     * @param assetId ID of the asset that was rejected
     */
    event AssetRejected(uint256 indexed tokenId, uint64 indexed assetId);

    /**
     * @notice Used to notify listeners that token's prioritiy array is reordered.
     * @param tokenId ID of the token that had the asset priority array updated
     */
    event AssetPrioritySet(uint256 indexed tokenId);

    /**
     * @notice Used to notify listeners that owner has granted an approval to the user to manage the assets of a
     *  given token.
     * @dev Approvals must be cleared on transfer
     * @param owner Address of the account that has granted the approval for all token's assets
     * @param approved Address of the account that has been granted approval to manage the token's assets
     * @param tokenId ID of the token on which the approval was granted
     */
    event ApprovalForAssets(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @notice Used to notify listeners that owner has granted approval to the user to manage assets of all of their
     *  tokens.
     * @param owner Address of the account that has granted the approval for all assets on all of their tokens
     * @param operator Address of the account that has been granted the approval to manage the token's assets on all of
     *  the tokens
     * @param approved Boolean value signifying whether the permission has been granted (`true`) or revoked (`false`)
     */
    event ApprovalForAllForAssets(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /**
     * @notice Accepts an asset at from the pending array of given token.
     * @dev Migrates the asset from the token's pending asset array to the token's active asset array.
     * @dev Active assets cannot be removed by anyone, but can be replaced by a new asset.
     * @dev Requirements:
     *
     *  - The caller must own the token or be approved to manage the token's assets
     *  - `tokenId` must exist.
     *  - `index` must be in range of the length of the pending asset array.
     * @dev Emits an {AssetAccepted} event.
     * @param tokenId ID of the token for which to accept the pending asset
     * @param index Index of the asset in the pending array to accept
     * @param assetId ID of the asset expected to be in the index
     */
    function acceptAsset(
        uint256 tokenId,
        uint256 index,
        uint64 assetId
    ) external;

    /**
     * @notice Rejects an asset from the pending array of given token.
     * @dev Removes the asset from the token's pending asset array.
     * @dev Requirements:
     *
     *  - The caller must own the token or be approved to manage the token's assets
     *  - `tokenId` must exist.
     *  - `index` must be in range of the length of the pending asset array.
     * @dev Emits a {AssetRejected} event.
     * @param tokenId ID of the token that the asset is being rejected from
     * @param index Index of the asset in the pending array to be rejected
     * @param assetId ID of the asset expected to be in the index
     */
    function rejectAsset(
        uint256 tokenId,
        uint256 index,
        uint64 assetId
    ) external;

    /**
     * @notice Rejects all assets from the pending array of a given token.
     * @dev Effecitvely deletes the pending array.
     * @dev Requirements:
     *
     *  - The caller must own the token or be approved to manage the token's assets
     *  - `tokenId` must exist.
     * @dev Emits a {AssetRejected} event with assetId = 0.
     * @param tokenId ID of the token of which to clear the pending array.
     * @param maxRejections Maximum number of expected assets to reject, used to prevent from rejecting assets which
     *  arrive just before this operation.
     */
    function rejectAllAssets(uint256 tokenId, uint256 maxRejections) external;

    /**
     * @notice Sets a new priority array for a given token.
     * @dev The priority array is a non-sequential list of `uint64`s, where the lowest value is considered highest
     *  priority.
     * @dev Value `0` of a priority is a special case equivalent to unitialized.
     * @dev Requirements:
     *
     *  - The caller must own the token or be approved to manage the token's assets
     *  - `tokenId` must exist.
     *  - The length of `priorities` must be equal the length of the active assets array.
     * @dev Emits a {AssetPrioritySet} event.
     * @param tokenId ID of the token to set the priorities for
     * @param priorities An array of priorities of active assets. The succesion of items in the priorities array
     *  matches that of the succesion of items in the active array
     */
    function setPriority(
        uint256 tokenId,
        uint64[] calldata priorities
    ) external;

    /**
     * @notice Used to retrieve IDs of the active assets of given token.
     * @dev Asset data is stored by reference, in order to access the data corresponding to the ID, call
     *  `getAssetMetadata(tokenId, assetId)`.
     * @dev You can safely get 10k
     * @param tokenId ID of the token to retrieve the IDs of the active assets
     * @return An array of active asset IDs of the given token
     */
    function getActiveAssets(
        uint256 tokenId
    ) external view returns (uint64[] memory);

    /**
     * @notice Used to retrieve IDs of the pending assets of given token.
     * @dev Asset data is stored by reference, in order to access the data corresponding to the ID, call
     *  `getAssetMetadata(tokenId, assetId)`.
     * @param tokenId ID of the token to retrieve the IDs of the pending assets
     * @return An array of pending asset IDs of the given token
     */
    function getPendingAssets(
        uint256 tokenId
    ) external view returns (uint64[] memory);

    /**
     * @notice Used to retrieve the priorities of the active resoources of a given token.
     * @dev Asset priorities are a non-sequential array of uint64 values with an array size equal to active asset
     *  priorites.
     * @param tokenId ID of the token for which to retrieve the priorities of the active assets
     * @return An array of priorities of the active assets of the given token
     */
    function getActiveAssetPriorities(
        uint256 tokenId
    ) external view returns (uint64[] memory);

    /**
     * @notice Used to retrieve the asset that will be replaced if a given asset from the token's pending array
     *  is accepted.
     * @dev Asset data is stored by reference, in order to access the data corresponding to the ID, call
     *  `getAssetMetadata(tokenId, assetId)`.
     * @param tokenId ID of the token to check
     * @param newAssetId ID of the pending asset which will be accepted
     * @return ID of the asset which will be replaced
     */
    function getAssetReplacements(
        uint256 tokenId,
        uint64 newAssetId
    ) external view returns (uint64);

    /**
     * @notice Used to fetch the asset metadata of the specified token's active asset with the given index.
     * @dev Assets are stored by reference mapping `_assets[assetId]`.
     * @dev Can be overriden to implement enumerate, fallback or other custom logic.
     * @param tokenId ID of the token from which to retrieve the asset metadata
     * @param assetId Asset Id, must be in the active assets array
     * @return The metadata of the asset belonging to the specified index in the token's active assets
     *  array
     */
    function getAssetMetadata(
        uint256 tokenId,
        uint64 assetId
    ) external view returns (string memory);

    // Approvals

    /**
     * @notice Used to grant permission to the user to manage token's assets.
     * @dev This differs from transfer approvals, as approvals are not cleared when the approved party accepts or
     *  rejects an asset, or sets asset priorities. This approval is cleared on token transfer.
     * @dev Only a single account can be approved at a time, so approving the `0x0` address clears previous approvals.
     * @dev Requirements:
     *
     *  - The caller must own the token or be an approved operator.
     *  - `tokenId` must exist.
     * @dev Emits an {ApprovalForAssets} event.
     * @param to Address of the account to grant the approval to
     * @param tokenId ID of the token for which the approval to manage the assets is granted
     */
    function approveForAssets(address to, uint256 tokenId) external;

    /**
     * @notice Used to retrieve the address of the account approved to manage assets of a given token.
     * @dev Requirements:
     *
     *  - `tokenId` must exist.
     * @param tokenId ID of the token for which to retrieve the approved address
     * @return Address of the account that is approved to manage the specified token's assets
     */
    function getApprovedForAssets(
        uint256 tokenId
    ) external view returns (address);

    /**
     * @notice Used to add or remove an operator of assets for the caller.
     * @dev Operators can call {acceptAsset}, {rejectAsset}, {rejectAllAssets} or {setPriority} for any token
     *  owned by the caller.
     * @dev Requirements:
     *
     *  - The `operator` cannot be the caller.
     * @dev Emits an {ApprovalForAllForAssets} event.
     * @param operator Address of the account to which the operator role is granted or revoked from
     * @param approved The boolean value indicating whether the operator role is being granted (`true`) or revoked
     *  (`false`)
     */
    function setApprovalForAllForAssets(
        address operator,
        bool approved
    ) external;

    /**
     * @notice Used to check whether the address has been granted the operator role by a given address or not.
     * @dev See {setApprovalForAllForAssets}.
     * @param owner Address of the account that we are checking for whether it has granted the operator role
     * @param operator Address of the account that we are checking whether it has the operator role or not
     * @return A boolean value indicating wehter the account we are checking has been granted the operator role
     */
    function isApprovedForAllForAssets(
        address owner,
        address operator
    ) external view returns (bool);
}// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.21;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC7401
 * @author RMRK team
 * @notice Interface smart contract of the RMRK nestable module.
 */
interface IERC7401 is IERC165 {
    /**
     * @notice The core struct of RMRK ownership.
     * @dev The `DirectOwner` struct is used to store information of the next immediate owner, be it the parent token or
     *  the externally owned account.
     * @dev If the token is owned by the externally owned account, the `tokenId` should equal `0`.
     * @param tokenId ID of the parent token
     * @param ownerAddress Address of the owner of the token. If the owner is another token, then the address should be
     *  the one of the parent token's collection smart contract. If the owner is externally owned account, the address
     *  should be the address of this account
     * @param isNft A boolean value signifying whether the token is owned by another token (`true`) or by an externally
     *  owned account (`false`)
     */
    struct DirectOwner {
        uint256 tokenId;
        address ownerAddress;
    }

    /**
     * @notice Used to notify listeners that the token is being transferred.
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     * @param from Address of the previous immediate owner, which is a smart contract if the token was nested.
     * @param to Address of the new immediate owner, which is a smart contract if the token is being nested.
     * @param fromTokenId ID of the previous parent token. If the token was not nested before, the value should be `0`
     * @param toTokenId ID of the new parent token. If the token is not being nested, the value should be `0`
     * @param tokenId ID of the token being transferred
     */
    event NestTransfer(
        address indexed from,
        address indexed to,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 indexed tokenId
    );

    /**
     * @notice Used to notify listeners that a new token has been added to a given token's pending children array.
     * @dev Emitted when a child NFT is added to a token's pending array.
     * @param tokenId ID of the token that received a new pending child token
     * @param childIndex Index of the proposed child token in the parent token's pending children array
     * @param childAddress Address of the proposed child token's collection smart contract
     * @param childId ID of the child token in the child token's collection smart contract
     */
    event ChildProposed(
        uint256 indexed tokenId,
        uint256 childIndex,
        address indexed childAddress,
        uint256 indexed childId
    );

    /**
     * @notice Used to notify listeners that a new child token was accepted by the parent token.
     * @dev Emitted when a parent token accepts a token from its pending array, migrating it to the active array.
     * @param tokenId ID of the token that accepted a new child token
     * @param childIndex Index of the newly accepted child token in the parent token's active children array
     * @param childAddress Address of the child token's collection smart contract
     * @param childId ID of the child token in the child token's collection smart contract
     */
    event ChildAccepted(
        uint256 indexed tokenId,
        uint256 childIndex,
        address indexed childAddress,
        uint256 indexed childId
    );

    /**
     * @notice Used to notify listeners that all pending child tokens of a given token have been rejected.
     * @dev Emitted when a token removes all a child tokens from its pending array.
     * @param tokenId ID of the token that rejected all of the pending children
     */
    event AllChildrenRejected(uint256 indexed tokenId);

    /**
     * @notice Used to notify listeners a child token has been transferred from parent token.
     * @dev Emitted when a token transfers a child from itself, transferring ownership to the root owner.
     * @param tokenId ID of the token that transferred a child token
     * @param childIndex Index of a child in the array from which it is being transferred
     * @param childAddress Address of the child token's collection smart contract
     * @param childId ID of the child token in the child token's collection smart contract
     * @param fromPending A boolean value signifying whether the token was in the pending child tokens array (`true`) or
     *  in the active child tokens array (`false`)
     * @param toZero A boolean value signifying whether the token is being transferred to the `0x0` address (`true`) or
     *  not (`false`)
     */
    event ChildTransferred(
        uint256 indexed tokenId,
        uint256 childIndex,
        address indexed childAddress,
        uint256 indexed childId,
        bool fromPending,
        bool toZero
    );

    /**
     * @notice The core child token struct, holding the information about the child tokens.
     * @return tokenId ID of the child token in the child token's collection smart contract
     * @return contractAddress Address of the child token's smart contract
     */
    struct Child {
        uint256 tokenId;
        address contractAddress;
    }

    /**
     * @notice Used to retrieve the *root* owner of a given token.
     * @dev The *root* owner of the token is an externally owned account (EOA). If the given token is child of another
     *  NFT, this will return an EOA address. Otherwise, if the token is owned by an EOA, this EOA wil be returned.
     * @param tokenId ID of the token for which the *root* owner has been retrieved
     * @return owner The *root* owner of the token
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @notice Used to retrieve the immediate owner of the given token.
     * @dev If the immediate owner is another token, the address returned, should be the one of the parent token's
     *  collection smart contract.
     * @param tokenId ID of the token for which the RMRK owner is being retrieved
     * @return Address of the given token's owner
     * @return The ID of the parent token. Should be `0` if the owner is an externally owned account
     * @return The boolean value signifying whether the owner is an NFT or not
     */
    function directOwnerOf(
        uint256 tokenId
    ) external view returns (address, uint256, bool);

    /**
     * @notice Used to burn a given token.
     * @dev When a token is burned, all of its child tokens are recursively burned as well.
     * @dev When specifying the maximum recursive burns, the execution will be reverted if there are more children to be
     *  burned.
     * @dev Setting the `maxRecursiveBurn` value to 0 will only attempt to burn the specified token and revert if there
     *  are any child tokens present.
     * @dev The approvals are cleared when the token is burned.
     * @dev Requirements:
     *
     *  - `tokenId` must exist.
     * @dev Emits a {Transfer} event.
     * @param tokenId ID of the token to burn
     * @param maxRecursiveBurns Maximum number of tokens to recursively burn
     * @return Number of recursively burned children
     */
    function burn(
        uint256 tokenId,
        uint256 maxRecursiveBurns
    ) external returns (uint256);

    /**
     * @notice Used to add a child token to a given parent token.
     * @dev This adds the child token into the given parent token's pending child tokens array.
     * @dev Requirements:
     *
     *  - `directOwnerOf` on the child contract must resolve to the called contract.
     *  - the pending array of the parent contract must not be full.
     * @param parentId ID of the parent token to receive the new child token
     * @param childId ID of the new proposed child token
     * @param data Additional data with no specified format
     */
    function addChild(
        uint256 parentId,
        uint256 childId,
        bytes memory data
    ) external;

    /**
     * @notice Used to accept a pending child token for a given parent token.
     * @dev This moves the child token from parent token's pending child tokens array into the active child tokens
     *  array.
     * @param parentId ID of the parent token for which the child token is being accepted
     * @param childIndex Index of a child tokem in the given parent's pending children array
     * @param childAddress Address of the collection smart contract of the child token expected to be located at the
     *  specified index of the given parent token's pending children array
     * @param childId ID of the child token expected to be located at the specified index of the given parent token's
     *  pending children array
     */
    function acceptChild(
        uint256 parentId,
        uint256 childIndex,
        address childAddress,
        uint256 childId
    ) external;

    /**
     * @notice Used to reject all pending children of a given parent token.
     * @dev Removes the children from the pending array mapping.
     * @dev This does not update the ownership storage data on children. If necessary, ownership can be reclaimed by the
     *  rootOwner of the previous parent.
     * @dev Requirements:
     *
     * Requirements:
     *
     * - `parentId` must exist
     * @param parentId ID of the parent token for which to reject all of the pending tokens.
     * @param maxRejections Maximum number of expected children to reject, used to prevent from rejecting children which
     *  arrive just before this operation.
     */
    function rejectAllChildren(
        uint256 parentId,
        uint256 maxRejections
    ) external;

    /**
     * @notice Used to transfer a child token from a given parent token.
     * @dev When transferring a child token, the owner of the token is set to `to`, or is not updated in the event of
     *  `to` being the `0x0` address.
     * @param tokenId ID of the parent token from which the child token is being transferred
     * @param to Address to which to transfer the token to
     * @param destinationId ID of the token to receive this child token (MUST be 0 if the destination is not a token)
     * @param childIndex Index of a token we are transferring, in the array it belongs to (can be either active array or
     *  pending array)
     * @param childAddress Address of the child token's collection smart contract.
     * @param childId ID of the child token in its own collection smart contract.
     * @param isPending A boolean value indicating whether the child token being transferred is in the pending array of
     *  the parent token (`true`) or in the active array (`false`)
     * @param data Additional data with no specified format, sent in call to `_to`
     */
    function transferChild(
        uint256 tokenId,
        address to,
        uint256 destinationId,
        uint256 childIndex,
        address childAddress,
        uint256 childId,
        bool isPending,
        bytes memory data
    ) external;

    /**
     * @notice Used to retrieve the active child tokens of a given parent token.
     * @dev Returns array of Child structs existing for parent token.
     * @dev The Child struct consists of the following values:
     *  [
     *      tokenId,
     *      contractAddress
     *  ]
     * @param parentId ID of the parent token for which to retrieve the active child tokens
     * @return An array of Child structs containing the parent token's active child tokens
     */
    function childrenOf(
        uint256 parentId
    ) external view returns (Child[] memory);

    /**
     * @notice Used to retrieve the pending child tokens of a given parent token.
     * @dev Returns array of pending Child structs existing for given parent.
     * @dev The Child struct consists of the following values:
     *  [
     *      tokenId,
     *      contractAddress
     *  ]
     * @param parentId ID of the parent token for which to retrieve the pending child tokens
     * @return An array of Child structs containing the parent token's pending child tokens
     */
    function pendingChildrenOf(
        uint256 parentId
    ) external view returns (Child[] memory);

    /**
     * @notice Used to retrieve a specific active child token for a given parent token.
     * @dev Returns a single Child struct locating at `index` of parent token's active child tokens array.
     * @dev The Child struct consists of the following values:
     *  [
     *      tokenId,
     *      contractAddress
     *  ]
     * @param parentId ID of the parent token for which the child is being retrieved
     * @param index Index of the child token in the parent token's active child tokens array
     * @return A Child struct containing data about the specified child
     */
    function childOf(
        uint256 parentId,
        uint256 index
    ) external view returns (Child memory);

    /**
     * @notice Used to retrieve a specific pending child token from a given parent token.
     * @dev Returns a single Child struct locating at `index` of parent token's active child tokens array.
     * @dev The Child struct consists of the following values:
     *  [
     *      tokenId,
     *      contractAddress
     *  ]
     * @param parentId ID of the parent token for which the pending child token is being retrieved
     * @param index Index of the child token in the parent token's pending child tokens array
     * @return A Child struct containting data about the specified child
     */
    function pendingChildOf(
        uint256 parentId,
        uint256 index
    ) external view returns (Child memory);

    /**
     * @notice Used to transfer the token into another token.
     * @param from Address of the direct owner of the token to be transferred
     * @param to Address of the receiving token's collection smart contract
     * @param tokenId ID of the token being transferred
     * @param destinationId ID of the token to receive the token being transferred
     * @param data Additional data with no specified format, sent in the addChild call
     */
    function nestTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 destinationId,
        bytes memory data
    ) external;
}//SPDX-License-Identifier: Apache 2.0

pragma solidity ^0.8.21;

interface IRMRKCollectionData {
    function totalSupply() external view returns (uint256);

    function maxSupply() external view returns (uint256);

    function getRoyaltyPercentage() external view returns (uint256);

    function getRoyaltyRecipient() external view returns (address);

    function owner() external view returns (address);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function collectionMetadata() external view returns (string memory);

    function contractURI() external view returns (string memory);
}