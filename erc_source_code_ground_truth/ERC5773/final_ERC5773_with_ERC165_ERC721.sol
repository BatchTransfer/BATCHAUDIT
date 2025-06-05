pragma solidity ^0.4.20;

interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}
pragma solidity ^0.4.20;

/// @title ERC-721 Non-Fungible Token Standard
/// @dev See https://eips.ethereum.org/EIPS/eip-721
///  Note: the ERC-165 identifier for this interface is 0x80ac58cd.
interface IERC721 /* is ERC165 */ {
    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view returns (uint256);

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) external payable;

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external payable;

    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external;

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address);

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}




/// @title ERC-5773 Context-Dependent Multi-Asset Tokens
/// @dev See https://eips.ethereum.org/EIPS/eip-5773
/// @dev Note: the ERC-165 identifier for this interface is 0x06b4329a.

pragma solidity ^0.8.16;

interface IERC5773 /* is ERC165 */ {
    /**
     * @notice Used to notify listeners that an asset object is initialised at `assetId`.
     * @param assetId ID of the asset that was initialised
     */
    event AssetSet(uint64 assetId);

    /**
     * @notice Used to notify listeners that an asset object at `assetId` is added to token's pending asset
     *  array.
     * @param tokenIds An array of IDs of the tokens that received a new pending asset
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
     * @notice Used to notify listeners that token's priority array is reordered.
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
     * @param operator Address of the account that has been granted the approval to manage the token's assets on all of the
     *  tokens
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
     * @param assetId Id of the asset expected to be in the index
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
     * @param assetId Id of the asset expected to be in the index
     */
    function rejectAsset(
        uint256 tokenId,
        uint256 index,
        uint64 assetId
    ) external;

    /**
     * @notice Rejects all assets from the pending array of a given token.
     * @dev Effectively deletes the pending array.
     * @dev Requirements:
     *
     *  - The caller must own the token or be approved to manage the token's assets
     *  - `tokenId` must exist.
     * @dev Emits a {AssetRejected} event with assetId = 0.
     * @param tokenId ID of the token of which to clear the pending array
     * @param maxRejections to prevent from rejecting assets which arrive just before this operation.
     */
    function rejectAllAssets(uint256 tokenId, uint256 maxRejections) external;

    /**
     * @notice Sets a new priority array for a given token.
     * @dev The priority array is a non-sequential list of `uint16`s, where the lowest value is considered highest
     *  priority.
     * @dev Value `0` of a priority is a special case equivalent to uninitialised.
     * @dev Requirements:
     *
     *  - The caller must own the token or be approved to manage the token's assets
     *  - `tokenId` must exist.
     *  - The length of `priorities` must be equal the length of the active assets array.
     * @dev Emits a {AssetPrioritySet} event.
     * @param tokenId ID of the token to set the priorities for
     * @param priorities An array of priorities of active assets. The succession of items in the priorities array
     *  matches that of the succession of items in the active array
     */
    function setPriority(uint256 tokenId, uint64[] calldata priorities)
        external;

    /**
     * @notice Used to retrieve IDs of the active assets of given token.
     * @dev Asset data is stored by reference, in order to access the data corresponding to the ID, call
     *  `getAssetMetadata(tokenId, assetId)`.
     * @dev You can safely get 10k
     * @param tokenId ID of the token to retrieve the IDs of the active assets
     * @return uint64[] An array of active asset IDs of the given token
     */
    function getActiveAssets(uint256 tokenId)
        external
        view
        returns (uint64[] memory);

    /**
     * @notice Used to retrieve IDs of the pending assets of given token.
     * @dev Asset data is stored by reference, in order to access the data corresponding to the ID, call
     *  `getAssetMetadata(tokenId, assetId)`.
     * @param tokenId ID of the token to retrieve the IDs of the pending assets
     * @return uint64[] An array of pending asset IDs of the given token
     */
    function getPendingAssets(uint256 tokenId)
        external
        view
        returns (uint64[] memory);

    /**
     * @notice Used to retrieve the priorities of the active assets of a given token.
     * @dev Asset priorities are a non-sequential array of uint16 values with an array size equal to active asset
     *  priorites.
     * @param tokenId ID of the token for which to retrieve the priorities of the active assets
     * @return uint16[] An array of priorities of the active assets of the given token
     */
    function getActiveAssetPriorities(uint256 tokenId)
        external
        view
        returns (uint64[] memory);

    /**
     * @notice Used to retrieve the asset that will be replaced if a given asset from the token's pending array
     *  is accepted.
     * @dev Asset data is stored by reference, in order to access the data corresponding to the ID, call
     *  `getAssetMetadata(tokenId, assetId)`.
     * @param tokenId ID of the token to check
     * @param newAssetId ID of the pending asset which will be accepted
     * @return uint64 ID of the asset which will be replaced
     */
    function getAssetReplacements(uint256 tokenId, uint64 newAssetId)
        external
        view
        returns (uint64);

    /**
     * @notice Used to fetch the asset metadata of the specified token's active asset with the given index.
     * @dev Can be overridden to implement enumerate, fallback or other custom logic.
     * @param tokenId ID of the token from which to retrieve the asset metadata
     * @param assetId Asset Id, must be in the active assets array
     * @return string The metadata of the asset belonging to the specified index in the token's active assets
     *  array
     */
    function getAssetMetadata(uint256 tokenId, uint64 assetId)
        external
        view
        returns (string memory);

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
     * @return address Address of the account that is approved to manage the specified token's assets
     */
    function getApprovedForAssets(uint256 tokenId)
        external
        view
        returns (address);

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
    function setApprovalForAllForAssets(address operator, bool approved)
        external;

    /**
     * @notice Used to check whether the address has been granted the operator role by a given address or not.
     * @dev See {setApprovalForAllForAssets}.
     * @param owner Address of the account that we are checking for whether it has granted the operator role
     * @param operator Address of the account that we are checking whether it has the operator role or not
     * @return bool The boolean value indicating whether the account we are checking has been granted the operator role
     */
    function isApprovedForAllForAssets(address owner, address operator)
        external
        view
        returns (bool);
}