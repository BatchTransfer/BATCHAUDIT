// the EIP-165 interfaceId for this interface is 0x534f5876

interface IERC4524 {
  function safeTransfer(address to, uint256 amount) external returns(bool);
  function safeTransfer(address to, uint256 amount, bytes memory data) external returns(bool);
  function safeTransferFrom(address from, address to, uint256 amount) external returns(bool);
  function safeTransferFrom(address from, address to, uint256 amount, bytes memory data) external returns(bool);
}