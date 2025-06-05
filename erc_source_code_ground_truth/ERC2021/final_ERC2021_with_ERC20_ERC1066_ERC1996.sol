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
interface IERC1996 /* is ERC-20 */ {
    enum HoldStatusCode {
        Nonexistent,
        Ordered,
        Executed,
        ReleasedByNotary,
        ReleasedByPayee,
        ReleasedOnExpiration
    }

    function hold(string calldata operationId, address to, address notary, uint256 value, uint256 timeToExpiration) external returns (bool); 
    function holdFrom(string calldata operationId, address from, address to, address notary, uint256 value, uint256 timeToExpiration) external returns (bool);
    function releaseHold(string calldata operationId) external returns (bool);
    function executeHold(string calldata operationId, uint256 value) external returns (bool);
    function renewHold(string calldata operationId, uint256 timeToExpiration) external returns (bool);
    function retrieveHoldData(string calldata operationId) external view returns (address from, address to, address notary, uint256 value, uint256 expiration, HoldStatusCode status);

    function balanceOnHold(address account) external view returns (uint256);
    function netBalanceOf(address account) external view returns (uint256);
    function totalSupplyOnHold() external view returns (uint256);

    function authorizeHoldOperator(address operator) external returns (bool);
    function revokeHoldOperator(address operator) external returns (bool);
    function isHoldOperatorFor(address operator, address from) external view returns (bool);

    event HoldCreated(address indexed holdIssuer, string  operationId, address from, address to, address indexed notary, uint256 value, uint256 expiration);
    event HoldExecuted(address indexed holdIssuer, string operationId, address indexed notary, uint256 heldValue, uint256 transferredValue);
    event HoldReleased(address indexed holdIssuer, string operationId, HoldStatusCode status);
    event HoldRenewed(address indexed holdIssuer, string operationId, uint256 oldExpiration, uint256 newExpiration);
    event AuthorizedHoldOperator(address indexed operator, address indexed account);
    event RevokedHoldOperator(address indexed operator, address indexed account);
}
interface IPayoutable /* is ERC-20 */ {
    enum PayoutStatusCode {
        Nonexistent,
        Ordered,
        InProcess,
        FundsInSuspense,
        Executed,
        Rejected,
        Cancelled
    }
    function authorizePayoutOperator(address orderer) external returns (bool);
    function revokePayoutOperator(address orderer) external returns (bool);
    function orderPayout(string calldata operationId, uint256 value, string calldata instructions) external returns (bool);
    function orderPayoutFrom(string calldata operationId, address walletToBePaidOut, uint256 value, string calldata instructions) external returns (bool);
    function cancelPayout(string calldata operationId) external returns (bool);
    function processPayout(string calldata operationId) external returns (bool);
    function putFundsInSuspenseInPayout(string calldata operationId) external returns (bool);
    function executePayout(string calldata operationId) external returns (bool);
    function rejectPayout(string calldata operationId, string calldata reason) external returns (bool);

    function isPayoutOperatorFor(address walletToDebit, address orderer) external view returns (bool);
    function retrievePayoutData(string calldata operationId) external view returns (address walletToDebit, uint256 value, string memory instructions, PayoutStatusCode status);

    event PayoutOrdered(address indexed orderer, string indexed operationId, address indexed walletToDebit, uint256 value, string instructions);
    event PayoutInProcess(address indexed orderer, string indexed operationId);
    event PayoutFundsInSuspense(address indexed orderer, string indexed operationId);
    event PayoutExecuted(address indexed orderer, string indexed operationId);
    event PayoutRejected(address indexed orderer, string indexed operationId, string reason);
    event PayoutCancelled(address indexed orderer, string indexed operationId);
    event PayoutOperatorAuthorized(address indexed walletToBePaidOut, address indexed orderer);
    event PayoutOperatorRevoked(address indexed walletToBePaidOut, address indexed orderer);
}