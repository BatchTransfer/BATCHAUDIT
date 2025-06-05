interface IERC20 {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
interface IERC2019 /* is ERC-20 */ {
    enum FundStatusCode {
        Nonexistent,
        Ordered,
        InProcess,
        Executed,
        Rejected,
        Cancelled
    }
    function authorizeFundOperator(address orderer) external returns (bool);
    function revokeFundOperator(address orderer) external returns (bool) ;
    function orderFund(string calldata operationId, uint256 value, string calldata instructions) external returns (bool);
    function orderFundFrom(string calldata operationId, address walletToFund, uint256 value, string calldata instructions) external returns (bool);
    function cancelFund(string calldata operationId) external returns (bool);
    function processFund(string calldata operationId) external returns (bool);
    function executeFund(string calldata operationId) external returns (bool);
    function rejectFund(string calldata operationId, string calldata reason) external returns (bool);

    function isFundOperatorFor(address walletToFund, address orderer) external view returns (bool);
    function retrieveFundData(address orderer, string calldata operationId) external view returns (address walletToFund,       uint256 value, string memory instructions, FundStatusCode status);

    event FundOrdered(address indexed orderer, string indexed operationId, address indexed , uint256 value,         string instructions);
    event FundInProcess(address indexed orderer, string indexed operationId);
    event FundExecuted(address indexed orderer, string indexed operationId);
    event FundRejected(address indexed orderer, string indexed operationId, string reason);
    event FundCancelled(address indexed orderer, string indexed operationId);
    event FundOperatorAuthorized(address indexed walletToFund, address indexed orderer);
    event FundOperatorRevoked(address indexed walletToFund, address indexed orderer);
}