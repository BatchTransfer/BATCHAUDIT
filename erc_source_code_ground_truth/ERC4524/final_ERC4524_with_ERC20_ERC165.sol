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

interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}
// the EIP-165 interfaceId for this interface is 0x534f5876

interface IERC4524 {
  function safeTransfer(address to, uint256 amount) external returns(bool);
  function safeTransfer(address to, uint256 amount, bytes memory data) external returns(bool);
  function safeTransferFrom(address from, address to, uint256 amount) external returns(bool);
  function safeTransferFrom(address from, address to, uint256 amount, bytes memory data) external returns(bool);
}