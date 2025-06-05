///  Note: the ERC-165 identifier for this interface is 0xded6338b
interface IERC5023 is IERC165 {

  /// @dev This emits when a token is shared, reminted and given to another wallet that isn't function caller
  event Share(address indexed from, address indexed to, uint256 indexed tokenId, uint256 derivedFromtokenId);

  /// @dev Shares, remints an existing token, gives a newly minted token a fresh token id, keeps original token at function callers possession and transfers newly minted token to receiver which should be another address than function caller. 
  function share(address to, uint256 tokenIdToBeShared) external returns(uint256 newTokenId);

} 