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




pragma solidity ^0.8.0;
 /// @title EIP-4519 NFT: Extension of EIP-721 Non-Fungible Token Standard. 
///  Note: the EIP-165 identifier for this interface is 0x8a68abe3
 interface IERC4519{
    /// @dev This emits when the NFT is assigned as utility of a new user.
    ///  This event emits when the user of the token changes.
    ///  (`_addressUser` == 0) when no user is assigned.
    event UserAssigned(uint256 indexed tokenId, address indexed _addressUser);
    
    /// @dev This emits when user and asset finish mutual authentication process successfully.
    ///  This event emits when both the user and the asset prove they share a secure communication channel.
    event UserEngaged(uint256 indexed tokenId);
    
    /// @dev This emits when owner and asset finish mutual authentication process successfully.
    ///  This event emits when both the owner and the asset prove they share a secure communication channel.
    event OwnerEngaged(uint256 indexed tokenId);
    
    /// @dev This emits when it is checked that the timeout has expired.
    ///  This event emits when the timestamp of the EIP-4519 NFT is not updated in timeout.
    event TimeoutAlarm(uint256 indexed tokenId);
    /// @notice This function defines how the NFT is assigned as utility of a new user (if "addressUser" is defined).
    /// @dev Only the owner of the EIP-4519 NFT can assign a user. If "addressAsset" is defined, then the state of the token must be
    /// "engagedWithOwner","waitingForUser" or "engagedWithUser" and this function changes the state of the token defined by "_tokenId" to
    /// "waitingForUser". If "addressAsset" is not defined, the state is set to "userAssigned". In both cases, this function sets the parameter 
    /// "addressUser" to "_addressUser". 
    /// @param _tokenId is the tokenId of the EIP-4519 NFT tied to the asset.
    /// @param _addressUser is the address of the new user.
    function setUser(uint256 _tokenId, address _addressUser) external payable; 
    /// @notice This function defines the initialization of the mutual authentication process between the owner and the asset.
    /// @dev Only the owner of the token can start this authentication process if "addressAsset" is defined and the state of the token is "waitingForOwner".
    /// The function does not change the state of the token and saves "_dataEngagement" 
    /// and "_hashK_OA" in the parameters of the token.
    /// @param _tokenId is the tokenId of the EIP-4519 NFT tied to the asset.
    /// @param _dataEngagement is the public data proposed by the owner for the agreement of the shared key.
    /// @param _hashK_OA is the hash of the secret proposed by the owner to share with the asset.
    function startOwnerEngagement(uint256 _tokenId, uint256 _dataEngagement, uint256 _hashK_OA) external payable;
 
    /// @notice This function completes the mutual authentication process between the owner and the asset.
    /// @dev Only the asset tied to the token can finish this authentication process provided that the state of the token is
    /// "waitingForOwner" and dataEngagement is different from 0. This function compares hashK_OA saved in
    /// the token with hashK_A. If they are equal then the state of the token changes to "engagedWithOwner", dataEngagement is set to 0,
    /// and the event "OwnerEngaged" is emitted.
    /// @param _hashK_A is the hash of the secret generated by the asset to share with the owner.
    function ownerEngagement(uint256 _hashK_A) external payable; 
 
    /// @notice This function defines the initialization of the mutual authentication process between the user and the asset.
    /// @dev Only the user of the token can start this authentication process if "addressAsset" and "addressUser" are defined and
    /// the state of the token is "waitingForUser". The function does not change the state of the token and saves "_dataEngagement" 
    /// and "_hashK_UA" in the parameters of the token.
    /// @param _tokenId is the tokenId of the EIP-4519 NFT tied to the asset.
    /// @param _dataEngagement is the public data proposed by the user for the agreement of the shared key.
    /// @param _hashK_UA is the hash of the secret proposed by the user to share with the asset.
    function startUserEngagement(uint256 _tokenId, uint256 _dataEngagement, uint256 _hashK_UA) external payable;
    
    /// @notice This function completes the mutual authentication process between the user and the asset.
    /// @dev Only the asset tied to the token can finish this authentication process provided that the state of the token is
    /// "waitingForUser" and dataEngagement is different from 0. This function compares hashK_UA saved in
    /// the token with hashK_A. If they are equal then the state of the token changes to "engagedWithUser", dataEngagement is set to 0,
    /// and the event "UserEngaged" is emitted.
    /// @param _hashK_A is the hash of the secret generated by the asset to share with the user.
    function userEngagement(uint256 _hashK_A) external payable; 
 
    /// @notice This function checks if the timeout has expired.
    /// @dev Everybody can call this function to check if the timeout has expired. The event "TimeoutAlarm" is emitted
    /// if the timeout has expired.
    /// @param _tokenId is the tokenId of the EIP-4519 NFT tied to the asset.
    /// @return true if timeout has expired and false in other case.
    function checkTimeout(uint256 _tokenId) external returns (bool);
    
    /// @notice This function sets the value of timeout.
    /// @dev Only the owner of the token can set this value provided that the state of the token is "engagedWithOwner",
    /// "waitingForUser" or "engagedWithUser".
    /// @param _tokenId is the tokenId of the EIP-4519 NFT tied to the asset.
    /// @param _timeout is the value to assign to timeout.
    function setTimeout(uint256 _tokenId, uint256 _timeout) external; 
    
    /// @notice This function updates the timestamp, thus avoiding the timeout alarm.
    /// @dev Only the asset tied to the token can update its own timestamp.
    function updateTimestamp() external; 
    
    /// @notice This function lets obtain the tokenId from an address. 
    /// @dev Everybody can call this function. The code executed only reads from Ethereum.
    /// @param _addressAsset is the address to obtain the tokenId from it.
    /// @return tokenId of the token tied to the asset that generates _addressAsset.
    function tokenFromBCA(address _addressAsset) external view returns (uint256);
    
    /// @notice This function lets know the owner of the token from the address of the asset tied to the token.
    /// @dev Everybody can call this function. The code executed only reads from Ethereum.
    /// @param _addressAsset is the address to obtain the owner from it.
    /// @return owner of the token bound to the asset that generates _addressAsset.
    function ownerOfFromBCA(address _addressAsset) external view returns (address);
    
    /// @notice This function lets know the user of the token from its tokenId.
    /// @dev Everybody can call this function. The code executed only reads from Ethereum.
    /// @param _tokenId is the tokenId of the EIP-4519 NFT tied to the asset.
    /// @return user of the token from its _tokenId.
    function userOf(uint256 _tokenId) external view returns (address);
    
    /// @notice This function lets know the user of the token from the address of the asset tied to the token.
    /// @dev Everybody can call this function. The code executed only reads from Ethereum.
    /// @param _addressAsset is the address to obtain the user from it.
    /// @return user of the token tied to the asset that generates _addressAsset.
    function userOfFromBCA(address _addressAsset) external view returns (address);
    
    /// @notice This function lets know how many tokens are assigned to a user.
    /// @dev Everybody can call this function. The code executed only reads from Ethereum.
    /// @param _addressUser is the address of the user.
    /// @return number of tokens assigned to a user.
    function userBalanceOf(address _addressUser) external view returns (uint256);
    
    /// @notice This function lets know how many tokens of a particular owner are assigned to a user.
    /// @dev Everybody can call this function. The code executed only reads from Ethereum.
    /// @param _addressUser is the address of the user.
    /// @param _addressOwner is the address of the owner.
    /// @return number of tokens assigned to a user from an owner.
    function userBalanceOfAnOwner(address _addressUser, address _addressOwner) external view returns (uint256);
}
