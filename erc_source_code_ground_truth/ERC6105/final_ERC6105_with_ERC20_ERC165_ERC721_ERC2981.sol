interface IERC20 {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
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




pragma solidity ^0.6.0;

interface IERC2981 {
    /// ERC165 bytes to add to interface array - set in parent contract
    /// implementing this standard
    ///
    /// bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
    /// bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    /// _registerInterface(_INTERFACE_ID_ERC2981);

    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _salePrice - the sale price of the NFT asset specified by _tokenId
    /// @return receiver - address of who should be sent the royalty payment
    /// @return royaltyAmount - the royalty payment amount for _salePrice
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (
        address receiver,
        uint256 royaltyAmount
    );
}

interface IERC6105 {

  /// @notice Emitted when a token is listed for sale or delisted
  /// @dev The zero `salePrice` indicates that the token is not for sale
  ///      The zero `expires` indicates that the token is not for sale
  /// @param tokenId - identifier of the token being listed
  /// @param from - address of who is selling the token
  /// @param salePrice - the price the token is being sold for
  /// @param expires - UNIX timestamp, the buyer could buy the token before expires
  /// @param supportedToken - contract addresses of supported token or zero address
  ///                         The zero address indicates that the supported token is ETH
  ///                         Buyer needs to purchase item with supported token
  /// @param benchmarkPrice - Additional price parameter, may be used when calculating royalties
  event UpdateListing(
    uint256 indexed tokenId,
    address indexed from,
    uint256 salePrice,
    uint64 expires,
    address supportedToken,
    uint256 benchmarkPrice
    );

  /// @notice Emitted when a token is being purchased
  /// @param tokenId - identifier of the token being purchased
  /// @param from - address of who is selling the token
  /// @param to - address of who is buying the token 
  /// @param salePrice - the price the token is being sold for
  /// @param supportedToken - contract addresses of supported token or zero address
  ///                         The zero address indicates that the supported token is ETH
  ///                         Buyer needs to purchase item with supported token
  /// @param royalties - The amount of royalties paid on this purchase
  event Purchased(
    uint256 indexed tokenId,
    address indexed from,
    address indexed to,
    uint256 salePrice,
    address supportedToken,
    uint256 royalties
    );

  /// @notice Create or update a listing for `tokenId`
  /// @dev `salePrice` MUST NOT be set to zero
  /// @param tokenId - identifier of the token being listed
  /// @param salePrice - the price the token is being sold for
  /// @param expires - UNIX timestamp, the buyer could buy the token before expires
  /// @param supportedToken - contract addresses of supported token or zero address
  ///                         The zero address indicates that the supported token is ETH
  ///                         Buyer needs to purchase item with supported token
  /// Requirements:
  /// - `tokenId` must exist
  /// - Caller must be owner, authorised operators or approved address of the token
  /// - `salePrice` must not be zero
  /// - `expires` must be valid
  /// - Must emit an {UpdateListing} event.
  function listItem(
    uint256 tokenId,
    uint256 salePrice,
    uint64 expires,
    address supportedToken
    ) external;

  /// @notice Create or update a listing for `tokenId` with `benchmarkPrice`
  /// @dev `salePrice` MUST NOT be set to zero
  /// @param tokenId - identifier of the token being listed
  /// @param salePrice - the price the token is being sold for
  /// @param expires - UNIX timestamp, the buyer could buy the token before expires
  /// @param supportedToken - contract addresses of supported token or zero address
  ///                         The zero address indicates that the supported token is ETH
  ///                         Buyer needs to purchase item with supported token
  /// @param benchmarkPrice - Additional price parameter, may be used when calculating royalties
  /// Requirements:
  /// - `tokenId` must exist
  /// - Caller must be owner, authorised operators or approved address of the token
  /// - `salePrice` must not be zero
  /// - `expires` must be valid
  /// - Must emit an {UpdateListing} event.
  function listItem(
    uint256 tokenId,
    uint256 salePrice,
    uint64 expires,
    address supportedToken,
    uint256 benchmarkPrice
    ) external;
 
  /// @notice Remove the listing for `tokenId`
  /// @param tokenId - identifier of the token being delisted
  /// Requirements:
  /// - `tokenId` must exist and be listed for sale
  /// - Caller must be owner, authorised operators or approved address of the token
  /// - Must emit an {UpdateListing} event
  function delistItem(uint256 tokenId) external;
 
  /// @notice Buy a token and transfer it to the caller
  /// @dev `salePrice` and `supportedToken` must match the expected purchase price and token to prevent front-running attacks
  /// @param tokenId - identifier of the token being purchased
  /// @param salePrice - the price the token is being sold for
  /// @param supportedToken - contract addresses of supported token or zero address
  /// Requirements:
  /// - `tokenId` must exist and be listed for sale
  /// - `salePrice` must matches the expected purchase price to prevent front-running attacks
  /// - `supportedToken` must matches the expected purchase token to prevent front-running attacks
  /// - Caller must be able to pay the listed price for `tokenId`
  /// - Must emit a {Purchased} event
  function buyItem(uint256 tokenId, uint256 salePrice, address supportedToken) external payable;

  /// @notice Return the listing for `tokenId`
  /// @dev The zero sale price indicates that the token is not for sale
  ///      The zero expires indicates that the token is not for sale
  ///      The zero supported token address indicates that the supported token is ETH
  /// @param tokenId identifier of the token being queried
  /// @return the specified listing (sale price, expires, supported token, benchmark price)
  function getListing(uint256 tokenId) external view returns (uint256, uint64, address, uint256);
}