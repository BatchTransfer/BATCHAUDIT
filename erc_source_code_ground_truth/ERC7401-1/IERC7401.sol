/// @title EIP-7401 Parent-Governed Nestable Non-Fungible Tokens
/// @dev See https://eips.ethereum.org/EIPS/eip-7401
/// @dev Note: the ERC-165 identifier for this interface is 0x42b0e56f.

pragma solidity ^0.8.16;

interface IERC7059 /* is ERC165 */ {
    /**
     * @notice The core struct of ownership.
     * @dev The `DirectOwner` struct is used to store information of the next immediate owner, be it the parent token,
     * an `ERC721Receiver` contract or an externally owned account.
     * @dev If the token is not owned by an NFT, the `tokenId` MUST equal `0`.
     * @param tokenId ID of the parent token
     * @param ownerAddress Address of the owner of the token. If the owner is another token, then the address MUST be
     *  the one of the parent token's collection smart contract. If the owner is externally owned account, the address
     *  MUST be the address of this account
     */
    struct DirectOwner {
        uint256 tokenId;
        address ownerAddress;
    }

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
     * @notice Used to notify listeners that the token is being transferred.
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     * @param from Address of the previous immediate owner, which is a smart contract if the token was nested.
     * @param to Address of the new immediate owner, which is a smart contract if the token is being nested.
     * @param fromTokenId ID of the previous parent token. If the token was not nested before, the value MUST be `0`
     * @param toTokenId ID of the new parent token. If the token is not being nested, the value MUST be `0`
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
     * @dev Emitted when a token removes all child tokens from its pending array.
     * @param tokenId ID of the token that rejected all of the pending children
     */
    event AllChildrenRejected(uint256 indexed tokenId);

    /**
     * @notice Used to notify listeners a child token has been transferred from parent token.
     * @dev Emitted when a token transfers a child from itself, transferring ownership.
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
     * @notice Used to retrieve the *root* owner of a given token.
     * @dev The *root* owner of the token is the top-level owner in the hierarchy which is not an NFT.
     * @dev If the token is owned by another NFT, it MUST recursively look up the parent's root owner.
     * @param tokenId ID of the token for which the *root* owner has been retrieved
     * @return owner The *root* owner of the token
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @notice Used to retrieve the immediate owner of the given token.
     * @dev If the immediate owner is another token, the address returned, MUST be the one of the parent token's
     *  collection smart contract.
     * @param tokenId ID of the token for which the direct owner is being retrieved
     * @return address Address of the given token's owner
     * @return uint256 The ID of the parent token. MUST be `0` if the owner is not an NFT
     * @return bool The boolean value signifying whether the owner is an NFT or not
     */
    function directOwnerOf(uint256 tokenId)
        external
        view
        returns (
            address,
            uint256,
            bool
        );

    /**
     * @notice Used to burn a given token.
     * @dev When a token is burned, all of its child tokens are recursively burned as well.
     * @dev When specifying the maximum recursive burns, the execution MUST be reverted if there are more children to be
     *  burned.
     * @dev Setting the `maxRecursiveBurn` value to 0 SHOULD only attempt to burn the specified token and MUST revert if
     *  there are any child tokens present.
     * @param tokenId ID of the token to burn
     * @param maxRecursiveBurns Maximum number of tokens to recursively burn
     * @return uint256 Number of recursively burned children
     */
    function burn(uint256 tokenId, uint256 maxRecursiveBurns)
        external
        returns (uint256);

    /**
     * @notice Used to add a child token to a given parent token.
     * @dev This adds the child token into the given parent token's pending child tokens array.
     * @dev The destination token MUST NOT be a child token of the token being transferred or one of its downstream
     *  child tokens.
     * @dev This method MUST NOT be called directly. It MUST only be called from an instance of `IERC7059` as part of a 
        `nestTransfer` or `transferChild` to an NFT.
     * @dev Requirements:
     *
     *  - `directOwnerOf` on the child contract MUST resolve to the called contract.
     *  - the pending array of the parent contract MUST not be full.
     * @param parentId ID of the parent token to receive the new child token
     * @param childId ID of the new proposed child token
     */
    function addChild(uint256 parentId, uint256 childId) external;

    /**
     * @notice Used to accept a pending child token for a given parent token.
     * @dev This moves the child token from parent token's pending child tokens array into the active child tokens
     *  array.
     * @param parentId ID of the parent token for which the child token is being accepted
     * @param childIndex Index of the child token to accept in the pending children array of a given token
     * @param childAddress Address of the collection smart contract of the child token expected to be at the specified
     *  index
     * @param childId ID of the child token expected to be located at the specified index
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
     * @dev The children's ownership structures are not updated.
     * @dev Requirements:
     *
     * - `parentId` MUST exist
     * @param parentId ID of the parent token for which to reject all of the pending tokens
     * @param maxRejections Maximum number of expected children to reject, used to prevent from
     *  rejecting children which arrive just before this operation.
     */
    function rejectAllChildren(uint256 parentId, uint256 maxRejections) external;

    /**
     * @notice Used to transfer a child token from a given parent token.
     * @dev MUST remove the child from the parent's active or pending children.
     * @dev When transferring a child token, the owner of the token MUST be set to `to`, or not updated in the event of `to`
     *  being the `0x0` address.
     * @param tokenId ID of the parent token from which the child token is being transferred
     * @param to Address to which to transfer the token to
     * @param destinationId ID of the token to receive this child token (MUST be 0 if the destination is not a token)
     * @param childIndex Index of a token we are transferring, in the array it belongs to (can be either active array or
     *  pending array)
     * @param childAddress Address of the child token's collection smart contract
     * @param childId ID of the child token in its own collection smart contract
     * @param isPending A boolean value indicating whether the child token being transferred is in the pending array of the
     *  parent token (`true`) or in the active array (`false`)
     * @param data Additional data with no specified format, sent in call to `to`
     */
    function transferChild(
        uint256 tokenId,
        address to,
        uint256 destinationId,
        uint256 childIndex,
        address childAddress,
        uint256 childId,
        bool isPending,
        bytes data
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
     * @return struct[] An array of Child structs containing the parent token's active child tokens
     */
    function childrenOf(uint256 parentId)
        external
        view
        returns (Child[] memory);

    /**
     * @notice Used to retrieve the pending child tokens of a given parent token.
     * @dev Returns array of pending Child structs existing for given parent.
     * @dev The Child struct consists of the following values:
     *  [
     *      tokenId,
     *      contractAddress
     *  ]
     * @param parentId ID of the parent token for which to retrieve the pending child tokens
     * @return struct[] An array of Child structs containing the parent token's pending child tokens
     */
    function pendingChildrenOf(uint256 parentId)
        external
        view
        returns (Child[] memory);

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
     * @return struct A Child struct containing data about the specified child
     */
    function childOf(uint256 parentId, uint256 index)
        external
        view
        returns (Child memory);

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
     * @return struct A Child struct containing data about the specified child
     */
    function pendingChildOf(uint256 parentId, uint256 index)
        external
        view
        returns (Child memory);

    /**
     * @notice Used to transfer the token into another token.
     * @dev The destination token MUST NOT be a child token of the token being transferred or one of its downstream
     *  child tokens.
     * @param from Address of the direct owner of the token to be transferred
     * @param to Address of the receiving token's collection smart contract
     * @param tokenId ID of the token being transferred
     * @param destinationId ID of the token to receive the token being transferred
     * @param data Additional data with no specified format
     */
    function nestTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 destinationId,
        bytes memory data
    ) external;
}