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
interface IKBT20 {
    event AccountSecured(address _account, uint256 _amount);
    event AccountResetBinding(address _account);
    event SafeFallbackActivated(address _account);
    event AccountEnabledTransfer(
        address _account,
        uint256 _amount,
        uint256 _time,
        address _to,
        bool _allFunds
    );
    event AccountEnabledApproval(
        address _account,
        uint256 _time,
        uint256 _numberOfTransfers
    );
    event Ingress(address _account, uint256 _amount);
    event Egress(address _account, uint256 _amount);

    struct AccountHolderBindings {
        address firstWallet;
        address secondWallet;
    }

    struct FirstAccountBindings {
        address accountHolderWallet;
        address secondWallet;
    }

    struct SecondAccountBindings {
        address accountHolderWallet;
        address firstWallet;
    }

    struct TransferConditions {
        uint256 amount;
        uint256 time;
        address to;
        bool allFunds;
    }

    struct ApprovalConditions {
        uint256 time;
        uint256 numberOfTransfers;
    }

    function addBindings(
        address _keyWallet1,
        address _keyWallet2
    ) external returns (bool);

    function getBindings(
        address _account
    ) external view returns (AccountHolderBindings memory);

    function resetBindings() external returns (bool);

    function safeFallback() external returns (bool);

    function allowTransfer(
        uint256 _amount,
        uint256 _time,
        address _to,
        bool _allFunds
    ) external returns (bool);

    function getTransferableFunds(
        address _account
    ) external view returns (TransferConditions memory);

    function allowApproval(
        uint256 _time,
        uint256 _numberOfTransfers
    ) external returns (bool);

    function getApprovalConditions(
        address account
    ) external view returns (ApprovalConditions memory);

    function getNumberOfTransfersAllowed(
        address _account,
        address _spender
    ) external view returns (uint256);

    function isSecureWallet(address _account) external view returns (bool);
}