// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {NewDREX} from "./ERC-3643/Token.sol";
import "@ERC3643/token/IToken.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";


contract VaultERC3643 is Ownable(msg.sender) {
    
    
    /// @dev ERC20 drex which can be deposited into this strategy. Do not use anything but ERC20s.
    address public drex;


    enum VaultState {Locked, Unlocked, Emergency}
    //State for user and security transactions

    /// @dev current state of the vault
    VaultState public state;

    /// @dev state of the vault before it was paused
    VaultState public stateBeforePause;

    /// @dev the timestamp at which the current Vault started
    uint256 public currentVaultStartTimestamp;

    mapping(address => bool) public authorizedAddresses;
    mapping(address => bool) public governor;

    /// @dev amount of drex that the authorized address can move from one address to another
    mapping(address => mapping(address => uint256)) approvedMove;//[from]][to] = amount

    /*=====================
    *       Events       *
    *====================*/

    event Deposit(address account, uint256 amountDeposited, address Vault);

    event Withdraw(address account, uint256 amountWithdrawn);

    event StateUpdated(VaultState state);
    event UpdatedAuthorization(address indexed target, bool authorized);
    event NewGovernor(address indexed governor, bool authorized);
    event Approved(address indexed _from, address indexed _to,uint256 _amount);
    event MoveDREX(address _from, address _to, uint256 _amount);


    /*=====================
   * External Functions *
   *====================*/

  constructor(address _drex){
    state = VaultState.Unlocked;
    drex = _drex;
    currentVaultStartTimestamp = block.timestamp;
  }



     function setAuthorized(address _target, bool _value) external {
        _onlyGovernor();
        authorizedAddresses[_target] = _value;
        emit UpdatedAuthorization(_target, _value);
    }

    function setGovernor(address _governance, bool _value) external onlyOwner{
        governor[_governance] = _value;
        emit NewGovernor(_governance, _value);
    }

    function setLimitTransfer(address _from, address _to, uint _amount) external onlyOwner{
        approvedMove[_from][_to] = _amount;
        emit Approved(_from, _to,_amount);
    }

//deposit in vault
  function deposit(uint256 _amount) external onlyUnlocked {
    //approve this address before transfer
    IToken(drex).transferFrom(msg.sender, address(this), _amount);
    emit Deposit(msg.sender, _amount, address(this));
  }

  function withdrawOwner(uint256 _amount) external onlyEmergency  {
    _onlyAuthorized();
    IToken(drex).transfer(msg.sender, _amount);
    emit Withdraw(msg.sender, _amount);
  }

///@dev drex movement related to the municipality and quantity approved by Bacen
  function moveDREX(address _to, uint256 _amount)external onlyUnlocked amountApprove(_to, _amount){
    _onlyGovernor();
    IToken(drex).transfer(msg.sender, _amount);
   emit MoveDREX(msg.sender,_to,_amount);
  }


  function emergency()external onlyOwner{
    stateBeforePause = state;
    state = VaultState.Emergency;
    emit StateUpdated(VaultState.Emergency);
  }

  function lock()external onlyOwner{
    stateBeforePause = state;
    state = VaultState.Locked;
    emit StateUpdated(VaultState.Locked);
  }


     function _onlyAuthorized() internal view {
        require(authorizedAddresses[msg.sender] == true || governor[msg.sender] == true, "!authorized");
    }

    function _onlyGovernor() internal view {
        require(governor[msg.sender] == true, "!governor");
    }



        /*=====================
    *     Modifiers      *
    *====================*/

    /**
     * @dev can only be executed in the unlocked state.
     */
    modifier onlyUnlocked {
        require(state == VaultState.Unlocked, "!Unlocked");
        _;
    }

    /**
     * @dev can only be executed in the locked state.
     */
    modifier onlyLocked {
        require(state == VaultState.Locked, "!Locked");
        _;
    }

    /**
     * @dev can only be executed in the locked state.
     */
    modifier onlyEmergency {
        require(state == VaultState.Emergency, "!Emergency");
        _;
    }


    /**
     * @dev can only be move amount approved
     */
    modifier amountApprove(address _to, uint256 _amount) {
        require(approvedMove[msg.sender][_to] <= _amount, "not approved move this amount");
        _;
    }

}

