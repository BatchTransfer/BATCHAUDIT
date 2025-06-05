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




interface IERC5585 {

    struct UserRecord {
        address user;
        string[] rights;
        uint256 expires;
    }

    /// @notice Get all available rights of this NFT project
    /// @return All the rights that can be authorized to the user
    function getRights() external view returns(string[]);

    /// @notice NFT holder authorizes all the rights of the NFT to a user for a specified period of time
    /// @dev The zero address indicates there is no user
    /// @param tokenId The NFT which is authorized
    /// @param user The user to whom the NFT is authorized
    /// @param duration The period of time the authorization lasts
    function authorizeUser(uint256 tokenId, address user, uint duration) external;

    /// @notice NFT holder authorizes specific rights to a user for a specified period of time
    /// @dev The zero address indicates there is no user. It will throw exception when the rights are not defined by this NFT project
    /// @param tokenId The NFT which is authorized
    /// @param user The user to whom the NFT is authorized
    /// @param rights Rights authorized to the user, such as renting, distribution or display etc
    /// @param duration The period of time the authorization lasts
    function authorizeUser(uint256 tokenId, address user, string[] rights, uint duration) external;
    
    /// @notice The user of the NFT transfers his rights to the new user
    /// @dev The zero address indicates there is no user
    /// @param tokenId The rights of this NFT is transferred to the new user
    /// @param newUser The new user
    function transferUserRights(uint256 tokenId, address newUser) external;

    /// @notice NFT holder extends the duration of authorization
    /// @dev The zero address indicates there is no user. It will throw exception when the rights are not defined by this NFT project
    /// @param tokenId The NFT which has been authorized
    /// @param user The user to whom the NFT has been authorized
    /// @param duration The new duration of the authorization
    function extendDuration(uint256 tokenId, address user, uint duration) external;

    /// @notice NFT holder updates the rights of authorization
    /// @dev The zero address indicates there is no user
    /// @param tokenId The NFT which has been authorized
    /// @param user The user to whom the NFT has been authorized
    /// @param rights New rights authorized to the user
    function updateUserRights(uint256 tokenId, address user, string[] rights) external;

    /// @notice Get the authorization expired time of the specified NFT and user
    /// @dev The zero address indicates there is no user
    /// @param tokenId The NFT to get the user expires for
    /// @param user The user who has been authorized
    /// @return The authorization expired time
    function getExpires(uint256 tokenId, address user) external view returns(uint);

    /// @notice Get the rights of the specified NFT and user
    /// @dev The zero address indicates there is no user
    /// @param tokenId The NFT to get the rights
    /// @param user The user who has been authorized
    /// @return The rights has been authorized
    function getUserRights(uint256 tokenId, address user) external view returns(string[]);

    /// @notice The contract owner can update the number of users that can be authorized per NFT
    /// @param userLimit The number of users set by operators only
    function updateUserLimit(uint256 userLimit) external onlyOwner;

    /// @notice resetAllowed flag can be updated by contract owner to control whether the authorization can be revoked or not 
    /// @param resetAllowed It is the boolean flag
    function updateResetAllowed(bool resetAllowed) external onlyOwner;

    /// @notice Check if the token is available for authorization
    /// @dev Throws if tokenId is not a valid NFT
    /// @param tokenId The NFT to be checked the availability
    /// @return true or false whether the NFT is available for authorization or not
    function checkAuthorizationAvailability(uint256 tokenId) public view returns(bool);

    /// @notice Clear authorization of a specified user
    /// @dev The zero address indicates there is no user. The function  works when resetAllowed is true and it will throw exception when false  
    /// @param tokenId The NFT on which the authorization based
    /// @param user The user whose authorization will be cleared
    function resetUser(uint256 tokenId, address user) external;


    /// @notice Emitted when the user of a NFT is changed or the authorization expires time is updated
    /// param tokenId The NFT on which the authorization based
    /// param indexed user The user to whom the NFT authorized
    /// @param rights Rights authorized to the user
    /// @param expires The expires time of the authorization
    event authorizeUser(uint256 indexed tokenId, address indexed user, string[] rights, uint expires);

    /// @notice Emitted when the number of users that can be authorized per NFT is updated
    /// @param userLimit The number of users set by operators only
    event updateUserLimit(uint256 userLimit);
}