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