
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