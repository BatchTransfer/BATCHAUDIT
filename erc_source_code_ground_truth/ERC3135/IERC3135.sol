interface IERC3135 {

        /// @return Image url of this token or descriptive resources
    function iconUrl() external view returns (string memory);

    /// @return Issuer of this token. Only issuer can execute claim function
    function issuer() external view returns (address);

    /**
    *  @notice   Remove consumption from payer's deposite
    *  @dev      Check if msg.sender == issuer
    *  @param    from          Payer's address
    *  @param    consumption   How many token is consumed in this epoch, specified
    *  @param    epoch         Epoch increased by 1 after claim or withdraw, at the beginning of each epoch, consumption goes back to 0
    *  @param    signature     Signature of payment message signed by payer
    */
    function claim(address from, uint256 consumption, uint256 epoch, bytes calldata signature) external;

    function transferIssuer(address newIssuer) external;

    /// @notice   Move amount from payer's token balance to deposite balance to ensure payment is sufficient
    function deposit(uint256 amount) external;

    /**
    *  @notice   Give remaining deposite balance back to "to" account, act as "refund" function
    *  @dev      In prepayment module, withdraw is executed from issuer account
    *            In lock-release module, withdraw is executed from user account
    *  @param    to            the account receiving remaining deposite
    *  @param    amount        how many token is returned
    */
    function withdraw(address to, uint256 amount) external;

    function depositBalanceOf(address user) external view returns(uint256 depositBalance, uint256 epoch);

    event Deposit(
        address indexed from,
        uint256 amount
    );

    event Withdraw(
        address indexed to,
        uint256 amount
    );
        
    event TransferIssuer(
        address indexed oldIssuer,
        address indexed newIssuer
    );

    event Claim(
        address indexed from,
        address indexed to,
        uint256 epoch,
        uint256 consumption
    );
}