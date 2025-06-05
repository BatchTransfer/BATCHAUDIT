/**
* @dev Interface of the Multiverse NFT standard as defined in the EIP.
*/
interface IMultiverseNFT {

   /**
    * @dev struct to store delegate token details
    *
    */
   struct DelegateData {
       address contractAddress;
       uint256 tokenId;
       uint256 quantity;
   }

   /**
    * @dev Emitted when one or more new delegate NFTs are added to a Multiverse NFT
    */
   event Bundled(uint256 multiverseTokenID, DelegateData[] delegateData, address ownerAddress);


   /**
    * @dev Emitted when one or more delegate NFTs are removed from a Multiverse NFT
    */
   event Unbundled(uint256 multiverseTokenID, DelegateData[] delegateData);

   /**
    * @dev Accepts the tokenId of the Multiverse NFT and returns an array of delegate token data
    */
   function delegateTokens(uint256 multiverseTokenID) external view returns (DelegateData[] memory);

   /**
    * @dev Removes one or more delegate NFTs from a Multiverse NFT
    * This function accepts the delegate NFT details and transfers those NFTs out of the Multiverse NFT contract to the owner's wallet
    */
   function unbundle(DelegateData[] memory delegateData, uint256 multiverseTokenID) external;

   /**
    * @dev Adds one or more delegate NFTs to a Multiverse NFT
    * This function accepts the delegate NFT details and transfers those NFTs to the Multiverse NFT contract
    * Need to ensure that approval is given to this Multiverse NFT contract for the delegate NFTs so that they can be transferred programmatically
    */
   function bundle(DelegateData[] memory delegateData, uint256 multiverseTokenID) external;

   /**
    * @dev Initialises a new bundle, mints a Multiverse NFT and assigns it to msg.sender
    * Returns the token ID of a new Multiverse NFT
    * Note - When a new Multiverse NFT is initialised, it is empty; it does not contain any delegate NFTs
    */
   function initBundle(DelegateData[] memory delegateData) external;
}