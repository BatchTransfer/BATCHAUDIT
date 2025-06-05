interface IERC1820{



    function interfaceHash(string _interfaceName) public pure returns(bytes32);

    function updateERC165Cache(address _contract, bytes4 _interfaceId) external;
 
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;


    function setManager(address _addr, address _newManager) external;

    function getManager(address _addr) public view returns(address);


}