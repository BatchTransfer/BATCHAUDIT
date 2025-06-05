pragma solidity 0.8.0;

contract EIP712VerifyingContract {
  function eip712Domain() external view returns (
      bytes1 fields,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
  ) {
      return (
          hex"0d", // 01101
          "Example",
          "",
          block.chainid,
          address(this),
          bytes32(0),
          new uint256[](0)
      );
  }
}