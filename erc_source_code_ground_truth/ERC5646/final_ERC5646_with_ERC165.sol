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
pragma solidity ^0.8.0;

interface ERC5646 is ERC165 {

    /// @notice Function to return current token state fingerprint.
    /// @param tokenId Id of a token state in question.
    /// @return Current token state fingerprint.
    function getStateFingerprint(uint256 tokenId) external view returns (bytes32);

}