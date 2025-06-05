interface IERC875 /* is ERC165 */
{
  event Transfer(address indexed _from, address indexed _to, uint256[] tokenIndices);

  function name() constant public returns (string name);
  function symbol() constant public returns (string symbol);
  function balanceOf(address _owner) public view returns (uint256[] _balances);
  function transfer(address _to, uint256[] _tokens) public;
  function transferFrom(address _from, address _to, uint256[] _tokens) public;
}