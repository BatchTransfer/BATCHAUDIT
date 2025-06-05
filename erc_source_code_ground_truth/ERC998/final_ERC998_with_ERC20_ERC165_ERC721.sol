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




pragma solidity ^0.4.24;

/// @title `ERC998ERC721` Top-Down Composable Non-Fungible Token
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-998.md
///  Note: the ERC-165 identifier for this interface is 0xcde244d9
interface IERC998 {

  /// @dev This emits when a token receives a child token.
  /// @param _from The prior owner of the token.
  /// @param _toTokenId The token that receives the child token.
  event ReceivedChild(
    address indexed _from, 
    uint256 indexed _toTokenId, 
    address indexed _childContract, 
    uint256 _childTokenId
  );
  
  /// @dev This emits when a child token is transferred from a token to an address.
  /// @param _fromTokenId The parent token that the child token is being transferred from.
  /// @param _to The new owner address of the child token.
  event TransferChild(
    uint256 indexed _fromTokenId, 
    address indexed _to, 
    address indexed _childContract, 
    uint256 _childTokenId
  );

  /// @notice Get the root owner of tokenId.
  /// @param _tokenId The token to query for a root owner address
  /// @return rootOwner The root owner at the top of tree of tokens and ERC-998 magic value.
  function rootOwnerOf(uint256 _tokenId) public view returns (bytes32 rootOwner);
  
  /// @notice Get the root owner of a child token.
  /// @param _childContract The contract address of the child token.
  /// @param _childTokenId The tokenId of the child.
  /// @return rootOwner The root owner at the top of tree of tokens and ERC-998 magic value.
  function rootOwnerOfChild(
    address _childContract, 
    uint256 _childTokenId
  ) 
    public 
    view
    returns (bytes32 rootOwner);
  
  /// @notice Get the parent tokenId of a child token.
  /// @param _childContract The contract address of the child token.
  /// @param _childTokenId The tokenId of the child.
  /// @return parentTokenOwner The parent address of the parent token and ERC-998 magic value
  /// @return parentTokenId The parent tokenId of _tokenId
  function ownerOfChild(
    address _childContract, 
    uint256 _childTokenId
  ) 
    external 
    view 
    returns (
      bytes32 parentTokenOwner, 
      uint256 parentTokenId
    );
  
  /// @notice A token receives a child token
  /// @param _operator The address that caused the transfer.
  /// @param _from The owner of the child token.
  /// @param _childTokenId The token that is being transferred to the parent.
  /// @param _data Up to the first 32 bytes contains an integer which is the receiving parent tokenId.  
  function onERC721Received(
    address _operator, 
    address _from, 
    uint256 _childTokenId, 
    bytes _data
  ) 
    external 
    returns(bytes4);
    
  /// @notice Transfer child token from top-down composable to address.
  /// @param _fromTokenId The owning token to transfer from.
  /// @param _to The address that receives the child token
  /// @param _childContract The ERC-721 contract of the child token.
  /// @param _childTokenId The tokenId of the token that is being transferred.
  function transferChild(
    uint256 _fromTokenId,
    address _to, 
    address _childContract, 
    uint256 _childTokenId
  ) 
    external;
  
  /// @notice Transfer child token from top-down composable to address.
  /// @param _fromTokenId The owning token to transfer from.
  /// @param _to The address that receives the child token
  /// @param _childContract The ERC-721 contract of the child token.
  /// @param _childTokenId The tokenId of the token that is being transferred.
  function safeTransferChild(
    uint256 _fromTokenId,
    address _to, 
    address _childContract, 
    uint256 _childTokenId
  ) 
    external;
  
  /// @notice Transfer child token from top-down composable to address.
  /// @param _fromTokenId The owning token to transfer from.
  /// @param _to The address that receives the child token
  /// @param _childContract The ERC-721 contract of the child token.
  /// @param _childTokenId The tokenId of the token that is being transferred.
  /// @param _data Additional data with no specified format
  function safeTransferChild(
    uint256 _fromTokenId,
    address _to, 
    address _childContract, 
    uint256 _childTokenId, 
    bytes _data
  ) 
    external;
  
  /// @notice Transfer bottom-up composable child token from top-down composable to other ERC-721 token.
  /// @param _fromTokenId The owning token to transfer from.
  /// @param _toContract The ERC-721 contract of the receiving token
  /// @param _toTokenId The receiving token  
  /// @param _childContract The bottom-up composable contract of the child token.
  /// @param _childTokenId The token that is being transferred.
  /// @param _data Additional data with no specified format
  function transferChildToParent(
    uint256 _fromTokenId, 
    address _toContract, 
    uint256 _toTokenId, 
    address _childContract, 
    uint256 _childTokenId, 
    bytes _data
  ) 
    external;
  
  /// @notice Get a child token from an ERC-721 contract.
  /// @param _from The address that owns the child token.
  /// @param _tokenId The token that becomes the parent owner
  /// @param _childContract The ERC-721 contract of the child token
  /// @param _childTokenId The tokenId of the child token
  function getChild(
    address _from, 
    uint256 _tokenId, 
    address _childContract, 
    uint256 _childTokenId
  ) 
    external;
}
