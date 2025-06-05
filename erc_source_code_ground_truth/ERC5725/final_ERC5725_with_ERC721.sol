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




// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Non-Fungible Vesting Token Standard.
 * @notice A non-fungible token standard used to vest ERC-20 tokens over a vesting release curve
 *  scheduled using timestamps.
 * @dev Because this standard relies on timestamps for the vesting schedule, it's important to keep track of the
 *  tokens claimed per Vesting NFT so that a user cannot withdraw more tokens than allotted for a specific Vesting NFT.
 * @custom:interface-id 0xbd3a202b
 */
interface IERC5725 is IERC721 {
    /**
     *  This event is emitted when the payout is claimed through the claim function.
     *  @param tokenId the NFT tokenId of the assets being claimed.
     *  @param recipient The address which is receiving the payout.
     *  @param claimAmount The amount of tokens being claimed.
     */
    event PayoutClaimed(uint256 indexed tokenId, address indexed recipient, uint256 claimAmount);

    /**
     *  This event is emitted when an `owner` sets an address to manage token claims for all tokens.
     *  @param owner The address setting a manager to manage all tokens.
     *  @param spender The address being permitted to manage all tokens.
     *  @param approved A boolean indicating whether the spender is approved to claim for all tokens.
     */
    event ClaimApprovalForAll(address indexed owner, address indexed spender, bool approved);

    /**
     *  This event is emitted when an `owner` sets an address to manage token claims for a `tokenId`.
     *  @param owner The `owner` of `tokenId`.
     *  @param spender The address being permitted to manage a tokenId.
     *  @param tokenId The unique identifier of the token being managed.
     *  @param approved A boolean indicating whether the spender is approved to claim for `tokenId`.
     */
    event ClaimApproval(address indexed owner, address indexed spender, uint256 indexed tokenId, bool approved);

    /**
     * @notice Claim the pending payout for the NFT.
     * @dev MUST grant the claimablePayout value at the time of claim being called to `msg.sender`.
     *  MUST revert if not called by the token owner or approved users.
     *  MUST emit PayoutClaimed.
     *  SHOULD revert if there is nothing to claim.
     * @param tokenId The NFT token id.
     */
    function claim(uint256 tokenId) external;

    /**
     * @notice Number of tokens for the NFT which have been claimed at the current timestamp.
     * @param tokenId The NFT token id.
     * @return payout The total amount of payout tokens claimed for this NFT.
     */
    function claimedPayout(uint256 tokenId) external view returns (uint256 payout);

    /**
     * @notice Number of tokens for the NFT which can be claimed at the current timestamp.
     * @dev It is RECOMMENDED that this is calculated as the `vestedPayout()` subtracted from `payoutClaimed()`.
     * @param tokenId The NFT token id.
     * @return payout The amount of unlocked payout tokens for the NFT which have not yet been claimed.
     */
    function claimablePayout(uint256 tokenId) external view returns (uint256 payout);

    /**
     * @notice Total amount of tokens which have been vested at the current timestamp.
     *  This number also includes vested tokens which have been claimed.
     * @dev It is RECOMMENDED that this function calls `vestedPayoutAtTime`
     *  with `block.timestamp` as the `timestamp` parameter.
     * @param tokenId The NFT token id.
     * @return payout Total amount of tokens which have been vested at the current timestamp.
     */
    function vestedPayout(uint256 tokenId) external view returns (uint256 payout);

    /**
     * @notice Total amount of vested tokens at the provided timestamp.
     *  This number also includes vested tokens which have been claimed.
     * @dev `timestamp` MAY be both in the future and in the past.
     *  Zero MUST be returned if the timestamp is before the token was minted.
     * @param tokenId The NFT token id.
     * @param timestamp The timestamp to check on, can be both in the past and the future.
     * @return payout Total amount of tokens which have been vested at the provided timestamp.
     */
    function vestedPayoutAtTime(uint256 tokenId, uint256 timestamp) external view returns (uint256 payout);

    /**
     * @notice Number of tokens for an NFT which are currently vesting.
     * @dev The sum of vestedPayout and vestingPayout SHOULD always be the total payout.
     * @param tokenId The NFT token id.
     * @return payout The number of tokens for the NFT which are vesting until a future date.
     */
    function vestingPayout(uint256 tokenId) external view returns (uint256 payout);

    /**
     * @notice The start and end timestamps for the vesting of the provided NFT.
     *  MUST return the timestamp where no further increase in vestedPayout occurs for `vestingEnd`.
     * @param tokenId The NFT token id.
     * @return vestingStart The beginning of the vesting as a unix timestamp.
     * @return vestingEnd The ending of the vesting as a unix timestamp.
     */
    function vestingPeriod(uint256 tokenId) external view returns (uint256 vestingStart, uint256 vestingEnd);

    /**
     * @notice Token which is used to pay out the vesting claims.
     * @param tokenId The NFT token id.
     * @return token The token which is used to pay out the vesting claims.
     */
    function payoutToken(uint256 tokenId) external view returns (address token);

    /**
     * @notice Sets a global `operator` with permission to manage all tokens owned by the current `msg.sender`.
     * @param operator The address to let manage all tokens.
     * @param approved A boolean indicating whether the spender is approved to claim for all tokens.
     */
    function setClaimApprovalForAll(address operator, bool approved) external;

    /**
     * @notice Sets a tokenId `operator` with permission to manage a single `tokenId` owned by the `msg.sender`.
     * @param operator The address to let manage a single `tokenId`.
     * @param tokenId the `tokenId` to be managed.
     * @param approved A boolean indicating whether the spender is approved to claim for all tokens.
     */
    function setClaimApproval(address operator, bool approved, uint256 tokenId) external;

    /**
     * @notice Returns true if `owner` has set `operator` to manage all `tokenId`s.
     * @param owner The owner allowing `operator` to manage all `tokenId`s.
     * @param operator The address who is given permission to spend tokens on behalf of the `owner`.
     */
    function isClaimApprovedForAll(address owner, address operator) external view returns (bool isClaimApproved);

    /**
     * @notice Returns the operating address for a `tokenId`.
     *  If `tokenId` is not managed, then returns the zero address.
     * @param tokenId The NFT `tokenId` to query for a `tokenId` manager.
     */
    function getClaimApproved(uint256 tokenId) external view returns (address operator);
}
