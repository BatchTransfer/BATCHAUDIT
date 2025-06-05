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
interface IERC2018 /* is ERC-1996 */ {
    enum ClearableTransferStatusCode { Nonexistent, Ordered, InProcess, Executed, Rejected, Cancelled }

    function orderTransfer(string calldata operationId, address to, uint256 value) external returns (bool);
    function orderTransferFrom(string calldata operationId, address from, address to, uint256 value) external returns (bool);
    function cancelTransfer(string calldata operationId) external returns (bool);
    function processClearableTransfer(string calldata operationId) external returns (bool);
    function executeClearableTransfer(string calldata operationId) external returns (bool);
    function rejectClearableTransfer(string calldata operationId, string calldata reason) external returns (bool);
    function retrieveClearableTransferData(string calldata operationId) external view returns (address from, address to, uint256 value, ClearableTransferStatusCode status);

    function authorizeClearableTransferOperator(address operator) external returns (bool);
    function revokeClearableTransferOperator(address operator) external returns (bool);
    function isClearableTransferOperatorFor(address operator, address from) external view returns (bool);

    event ClearableTransferOrdered(address indexed orderer, string operationId, address indexed from, address indexed to, uint256 value);
    event ClearableTransferInProcess(address indexed orderer, string operationId);
    event ClearableTransferExecuted(address indexed orderer, string operationId);
    event ClearableTransferRejected(address indexed orderer, string operationId, string reason);
    event ClearableTransferCancelled(address indexed orderer, string operationId);
    event AuthorizedClearableTransferOperator(address indexed operator, address indexed account);
    event RevokedClearableTransferOperator(address indexed operator, address indexed account);
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
interface IERC2020 /* is ERC-1996, ERC-2018, ERC-2019, ERC-2021 */ {
    function currency() external view returns (string memory);
    function version() external pure returns (string memory);
    
    function availableFunds(address account) external view returns (uint256);
    
    function checkTransferAllowed(address from, address to, uint256 value) external view returns (byte status);
    function checkApproveAllowed(address from, address spender, uint256 value) external view returns (byte status);
    
    function checkHoldAllowed(address from, address to, address notary, uint256 value) external view returns (byte status);
    function checkAuthorizeHoldOperatorAllowed(address operator, address from) external view returns (byte status);    

    function checkOrderTransferAllowed(address from, address to, uint256 value) external view returns (byte status);
    function checkAuthorizeClearableTransferOperatorAllowed(address operator, address from) external view returns (byte status);
    
    function checkOrderFundAllowed(address to, address operator, uint256 value) external view returns (byte status);
    function checkAuthorizeFundOperatorAllowed(address operator, address to) external view returns (byte status);
    
    function checkOrderPayoutAllowed(address from, address operator, uint256 value) external view returns (byte status);
    function checkAuthorizePayoutOperatorAllowed(address operator, address from) external view returns (byte status);
}