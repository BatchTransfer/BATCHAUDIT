pragma solidity ^0.8.0;

interface ERC5646 is ERC165 {

    /// @notice Function to return current token state fingerprint.
    /// @param tokenId Id of a token state in question.
    /// @return Current token state fingerprint.
    function getStateFingerprint(uint256 tokenId) external view returns (bytes32);

}