


interface IERC223 {

event Transfer(address indexed _from, address indexed _to, uint _value, bytes _data);

function totalSupply() view returns (uint256);

function balanceOf(address _owner) view returns (uint256);

function transfer(address _to, uint _value) returns (bool);

function transfer(address _to, uint _value, bytes calldata _data) returns (bool);

}