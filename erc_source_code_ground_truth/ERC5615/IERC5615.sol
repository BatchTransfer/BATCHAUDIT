interface ERC1155Supply is ERC1155 {
  // @notice      This function MUST return whether the given token id exists, previously existed, or may exist
  // @param   id  The token id of which to check the existence
  // @return      Whether the given token id exists, previously existed, or may exist
  function exists(uint256 id) external view returns (bool);

  // @notice      This function MUST return the number of tokens with a given id. If the token id does not exist, it MUST return 0.
  // @param   id  The token id of which fetch the total supply
  // @return      The total supply of the given token id
  function totalSupply(uint256 id) external view returns (uint256);
}