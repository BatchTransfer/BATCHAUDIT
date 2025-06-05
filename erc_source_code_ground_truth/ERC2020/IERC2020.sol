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