interface IERC5267{
    
    function eip712Domain() external view returns (
    bytes1 fields,
    string name,
    string version,
    uint256 chainId,
    address verifyingContract,
    bytes32 salt,
    uint256[] extensions
);
}