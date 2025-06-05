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




/**
    @title Multi-Fractional Non-Fungible Token Standard
    @dev Note : The ERC-165 identifier for this interface is 0x83f5d35f.
*/
interface IERC4675 {
    /**
        @dev This emits when ownership of any token changes by any mechanism.
        The `_from` argument MUST be the address of an account/contract sending the token.
        The `_to` argument MUST be the address of an account/contract receiving the token.
        The `_id` argument MUST be the token type being transferred. (represents NFT)
        The `_value` argument MUST be the number of tokens the holder balance is decrease by and match the recipient balance is increased by.
    */
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _id, uint256 _value);

    /**
        @dev This emits when the approved address for token is changed or reaffirmed.
        The `_owner` argument MUST be the address of account/contract approving to withdraw.
        The `_spender` argument MUST be the address of account/contract approved to withdraw from the `_owner` balance.
        The `_id` argument MUST be the token type being transferred. (represents NFT)
        The `_value` argument MUST be the number of tokens the `_approved` is able to withdraw from `_owner` balance.
    */
    event Approval(address indexed _owner, address indexed _spender, uint256 indexed _id, uint256 _value);

    /**
        @dev This emits when new token type is added which represents the share of the Non-Fungible Token.
        The `_parentToken` argument MUST be the address of the Non-Fungible Token contract.
        The `_parentTokenId` argument MUST be the token ID of the Non-Fungible Token.
        The `_id` argument MUST be the token type being added. (represents NFT)
        The `_totalSupply` argument MUST be the number of total token supply of the token type.
    */
    event TokenAddition(address indexed _parentToken, uint256 indexed _parentTokenId, uint256 _id, uint256 _totalSupply);

    /**
        @notice Transfers `_value` amount of an `_id` from the msg.sender address to the `_to` address specified
        @dev msg.sender must have sufficient balance to handle the tokens being transferred out of the account.
        MUST revert if `_to` is the zero address.
        MUST revert if balance of msg.sender for token `_id` is lower than the `_value` being transferred.
        MUST revert on any other error.
        MUST emit the `Transfer` event to reflect the balance change.
        @param _to      Source address
        @param _id      ID of the token type
        @param _value   Transfer amount
        @return         True if transfer was successful, false if not
    */
    function transfer(address _to, uint256 _id, uint256 _value) external returns (bool);

    /**
        @notice Approves `_value` amount of an `_id` from the msg.sender to the `_spender` address specified.
        @dev msg.sender must have sufficient balance to handle the tokens when the `_spender` wants to transfer the token on behalf.
        MUST revert if `_spender` is the zero address.
        MUST revert on any other error.
        MUST emit the `Approval` event.
        @param _spender Spender address(account/contract which can withdraw token on behalf of msg.sender)
        @param _id      ID of the token type
        @param _value   Approval amount
        @return         True if approval was successful, false if not
    */
    function approve(address _spender, uint256 _id, uint256 _value) external returns (bool);

    /**
        @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified.
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account.
        MUST revert if `_to` is the zero address.
        MUST revert if balance of holder for token `_id` is lower than the `_value` sent.
        MUST revert on any other error.
        MUST emit `Transfer` event to reflect the balance change.
        @param _from    Source address
        @param _to      Target Address
        @param _id      ID of the token type
        @param _value   Transfer amount
        @return         True if transfer was successful, false if not

    */
    function transferFrom(address _from, address _to, uint256 _id, uint256 _value) external returns (bool);

    /**
        @notice Sets the NFT as a new type token
        @dev The contract itself should verify if the ownership of NFT is belongs to this contract itself with the `_parentNFTContractAddress` & `_parentNFTTokenId` before adding the token.
        MUST revert if the same NFT is already registered.
        MUST revert if `_parentNFTContractAddress` is address zero.
        MUST revert if `_parentNFTContractAddress` is not ERC-721 compatible.
        MUST revert if this contract itself is not the owner of the NFT.
        MUST revert on any other error.
        MUST emit `TokenAddition` event to reflect the token type addition.
        @param _parentNFTContractAddress    NFT contract address
        @param _parentNFTTokenId            NFT tokenID
        @param _totalSupply                 Total token supply
    */
    function setParentNFT(address _parentNFTContractAddress, uint256 _parentNFTTokenId, uint256 _totalSupply) external;

    /**
        @notice Get the token ID's total token supply.
        @param _id      ID of the token
        @return         The total token supply of the specified token type
    */
    function totalSupply(uint256 _id) external view returns (uint256);

    /**
        @notice Get the balance of an account's tokens.
        @param _owner  The address of the token holder
        @param _id     ID of the token
        @return        The _owner's balance of the token type requested
    */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);

    /**
        @notice Get the amount which `_spender` is still allowed to withdraw from `_owner`
        @param _owner   The address of the token holder
        @param _spender The address approved to withdraw token on behalf of `_owner`
        @param _id      ID of the token
        @return         The amount which `_spender` is still allowed to withdraw from `_owner`
    */
    function allowance(address _owner, address _spender, uint256 _id) external view returns (uint256);

    /**
        @notice Get the bool value which represents whether the NFT is already registered and fractionalized by this contract.
        @param _parentNFTContractAddress    NFT contract address
        @param _parentNFTTokenId            NFT tokenID
        @return                             The bool value representing the whether the NFT is already registered.
    */
    function isRegistered(address _parentNFTContractAddress, uint256 _parentNFTTokenId) external view returns (bool);
}

