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
///  Note: the ERC-165 identifier for this interface is 0xded6338b
interface IERC5023 is IERC165 {

  /// @dev This emits when a token is shared, reminted and given to another wallet that isn't function caller
  event Share(address indexed from, address indexed to, uint256 indexed tokenId, uint256 derivedFromtokenId);

  /// @dev Shares, remints an existing token, gives a newly minted token a fresh token id, keeps original token at function callers possession and transfers newly minted token to receiver which should be another address than function caller. 
  function share(address to, uint256 tokenIdToBeShared) external returns(uint256 newTokenId);

} 