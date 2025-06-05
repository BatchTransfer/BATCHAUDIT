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

