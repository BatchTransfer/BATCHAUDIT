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





interface IERC4910{

    function royaltyPayOut (uint256 tokenId, address RAsubaccount, address payable payoutAccount, uint256 amount) public virtual nonReentrant returns (bool)

        /// @dev Function to fetch a Royalty Account for a given tokenId
    /// @param tokenId is the identifier of the NFT to which a Royalty Account is attached
    /// @param RoyaltyAccount is a data structure containing the royalty account information
    /// @param RASubAccount[] is an array of data structures containing the information of the royalty sub accounts associated with the royalty account

    function getRoyaltyAccount (uint256 tokenId) public view virtual returns (address,
                RoyaltyAccount memory,
                RASubAccount[] memory);

                /// @dev Function to update a Royalty Account and its Sub Accounts
    /// @param tokenId is the identifier of the NFT to which the Royalty Account to be updated is attached
    /// @param RoyaltyAccount is the Royalty Account and associated Royalty Sub Accounts with updated values  

    function updateRoyaltyAccount (uint256 _tokenId, `RoyaltyAccount memory _raAccount) public virtual returns (bool)

    /// @dev Function to delete a Royalty Account
    /// @param tokenId is the identifier of the NFT to which the Royalty Account to be updated is attached

    function deleteRoyaltyAccount (uint256 _tokenId) public virtual returns (bool)

    /// @dev Function creates one or more new NFTs with its relevant meta data necessary for royalties, and a Royalty Account with its associated met data for `to` address. The tokenId(s) will be automatically assigned (and available on the emitted {IERC-721-Transfer} event).
    /// @param to is the address to which the NFT(s) are minted
    /// @param nfttoken is an array of struct type NFTToken for the meta data of the minted NFT(s)
    /// @param tokenType is the type of allowed payment token for the NFT

    function mint(address to, NFTToken[] memory nfttoken, address tokenType) public virtual

    /// @dev Function to list one or more NFTs for direct sales
    /// @param tokenIds is the array of tokenIds to be included in the listing
    /// @param price is the price set by the owner for the listed NFT(s)
    /// @param tokenType is the payment token type allowed for the listing

    function listNFT (uint256[] calldata tokenIds, uint256 price, address tokenType) public virtual returns (bool)


    /// @dev Function to de-list one or more NFTs for direct sales
    /// @param listingId is the identifier of the NFT listing

    function removeNFTListing (uint256 listingId) public virtual returns (bool)

    /// @dev Function to make a NFT direct sales or exchange-mediate sales payment
    /// @param receiver is the address of the receiver of the payment
    /// @param seller is the address of the NFT seller 
    /// @param tokenIds are the tokenIds of the NFT to be bought
    /// @param payment is the amount of that payment to be made
    /// @param tokenType is the type of payment token
    /// @param trxnType is the type of payment transaction -- minimally direct sales or exchange-mediated

    function executePayment (address receiver, address seller, uint 256[] tokenIds, uint256 payment, string tokenType, int256 trxnType) public virtual nonReentrant returns (bool)


    /// @dev Definition of the function enabling the reversal of a payment before the sale is complete
    /// @param paymentId is the unique identifier for which a payment was made
    /// @param tokenType is the type of payment token used in the payment
    function reversePayment(uint256 paymentId, string memory tokenType) public virtual returns (bool)

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external virtual override


    /// @dev Function to distribute a payment as royalties to a chain of Royalty Accounts
    /// @param tokenId is a tokenId included in the sale and used to look up the associated Royalty Account
    /// @param payment is the payment (portion) to be distributed as royalties

    function distributePayment (uint256 tokenId, uint265 payment) internal virtual returns (bool)

    /// @dev Function to payout a royalty payment
    /// @param tokenId is the identifier of the NFT token
    /// @param RAsubaccount is the address of the Royalty Sub Account from which the payout should happen
    /// @param receiver is the address to receive the payout
    /// @param amount is the amount to be paid out

    function royaltyPayOut (uint256 tokenId, address RAsubaccount, address payable payoutAccount, uint256 amount) public virtual nonReentrant returns (bool)

    function _royaltyPayOut (uint256 tokenId, address RAsubaccount, address payable payoutAccount, uint256 amount) public virtual returns (bool)





}