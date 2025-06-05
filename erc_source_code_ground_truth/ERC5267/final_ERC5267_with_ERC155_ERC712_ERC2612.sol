
interface IERC2612{

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    function nonces(address owner) external view returns (uint);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

}

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