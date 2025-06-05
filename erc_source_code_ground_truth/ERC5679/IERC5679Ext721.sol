// The EIP-165 identifier of this interface is 0xcce39764
interface IERC5679Ext721 {
   function safeMint(address _to, uint256 _id, bytes calldata _data) external;
   function burn(address _from, uint256 _id, bytes calldata _data) external;
}