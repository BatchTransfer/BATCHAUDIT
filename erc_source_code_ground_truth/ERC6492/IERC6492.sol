// As per ERC-1271
interface IERC1271Wallet {
  function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);
}