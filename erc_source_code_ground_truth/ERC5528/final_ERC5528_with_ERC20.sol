interface IERC20 {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
pragma solidity ^0.4.20;

interface IERC5528 {

    function escrowFund(address _to, uint256 _value) public returns (bool);

    function escrowRefund(address _from, uint256 _value) public returns (bool);

    function escrowWithdraw() public returns (bool);

}