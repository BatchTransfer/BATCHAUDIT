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




pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IERC_5521 is IERC165 {

    /// Logged when a node in the rNFT gets referred and changed.
    /// @notice Emitted when the `node` (i.e., an rNFT) is changed.
    event UpdateNode(uint256 indexed tokenId, 
                     address indexed owner, 
                     address[] _address_referringList,
                     uint256[][] _tokenIds_referringList,
                     address[] _address_referredList,
                     uint256[][] _tokenIds_referredList
    );

    /// @notice set the referred list of an rNFT associated with different contract addresses and update the referring list of each one in the referred list. Checking the duplication of `addresses` and `tokenIds` is **RECOMMENDED**.
    /// @param `tokenId` of rNFT being set. `addresses` of the contracts in which rNFTs with `tokenIds` being referred accordingly. 
    /// @requirement 
    /// - the size of `addresses` **MUST** be the same as that of `tokenIds`;
    /// - once the size of `tokenIds` is non-zero, the inner size **MUST** also be non-zero;
    /// - the `tokenId` **MUST** be unique within the same contract;
    /// - the `tokenId` **MUST NOT** be the same as `tokenIds[i][j]` if `addresses[i]` is essentially `address(this)`.
    function setNode(uint256 tokenId, address[] memory addresses, uint256[][] memory tokenIds) external;

    /// @notice get the referring list of an rNFT.
    /// @param `tokenId` of the rNFT being focused, `_address` of contract address associated with the focused rNFT.
    /// @return the referring mapping of the rNFT.
    function referringOf(address _address, uint256 tokenId) external view returns(address[] memory, uint256[][] memory);

    /// @notice get the referred list of an rNFT.
    /// @param `tokenId` of the rNFT being focused, `_address` of contract address associated with the focused rNFT.
    /// @return the referred mapping of the rNFT.
    function referredOf(address _address, uint256 tokenId) external view returns(address[] memory, uint256[][] memory);

    /// @notice get the timestamp of an rNFT when is being created.
    /// @param `tokenId` of the rNFT being focused, `_address` of contract address associated with the focused rNFT.
    /// @return the timestamp of the rNFT when is being created with uint256 format.
    function createdTimestampOf(address _address, uint256 tokenId) external view returns(uint256);
    
    /// @notice check supported interfaces, adhereing to ERC165.
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface TargetContract is IERC165 {
    /// @notice set the referred list of an rNFT associated with external contract addresses. 
    /// @param `_tokenIds` of rNFTs associated with the contract address `_address` being referred by the rNFT with `tokenId`.
    /// @requirement
    /// - `_address` **MUST NOT** be the same as `address(this)` where `this` is executed by an external contract where `TargetContract` interface is implemented.
    function setNodeReferredExternal(address _address, uint256 tokenId, uint256[] memory _tokenIds) external;

    function referringOf(address _address, uint256 tokenId) external view returns(address[] memory, uint256[][] memory);

    function referredOf(address _address, uint256 tokenId) external view returns(address[] memory, uint256[][] memory);

    function createdTimestampOf(address _address, uint256 tokenId) external view returns(uint256);
    
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
