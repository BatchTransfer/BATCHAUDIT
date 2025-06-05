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
interface IERC1820{



    function interfaceHash(string _interfaceName) public pure returns(bytes32);

    function updateERC165Cache(address _contract, bytes4 _interfaceId) external;
 
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;


    function setManager(address _addr, address _newManager) external;

    function getManager(address _addr) public view returns(address);


}