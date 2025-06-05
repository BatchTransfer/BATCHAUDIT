pragma solidity ^0.4.20;

interface IERC5528 {

    function escrowFund(address _to, uint256 _value) public returns (bool);

    function escrowRefund(address _from, uint256 _value) public returns (bool);

    function escrowWithdraw() public returns (bool);

}

contract PayableContract is IERC5528, IERC20 {
    /*
      General ERC20 implementations
    */

    function _transfer(address from, address to, uint256 amount) internal {
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function escrowFund(address _to, uint256 _value) public returns (bool){
        bool res = IERC5528(to).escrowFund(msg.sender, amount);
        require(res, "Fund Failed");
        _transfer(msg.sender, to, amount);
        return true;
    }

    function escrowRefund(address _from, uint256 _value) public returns (bool){
        bool res = IERC5528(_from).escrowRefund(msg.sender, _value);
        require(res, "Refund Failed");
        _transfer(_from, msg.sender, _value);
        return true;
    }
}

contract EscrowContract is IERC5528 {

    enum State { Inited, Running, Success, Closed }
    struct BalanceData {
        address addr;
        uint256 amount;
    }

    address _addrSeller;
    address _addrBuyer;
    BalanceData _fundSeller;
    BalanceData _fundBuyer;
    EscrowStatus _status;

    constructor(address sellerContract, address buyerContract){
        _addrSeller = sellerContract;
        _addrBuyer = buyerContract;
        _status = State.Inited;
    }

    function escrowFund(address _to, uint256 _value) public returns (bool){
        if(msg.sender == _addrSeller){
            require(_status.state == State.Running, "must be running state");
            _fundSeller.addr = _to;
            _fundSeller.amount = _value;
            _status = State.Success;
        }else if(msg.sender == _addrBuyer){
            require(_status.state == State.Inited, "must be init state");
            _fundBuyer.addr = _to;
            _fundBuyer.amount = _value;
            _status = State.Running;
        }else{
            require(false, "Invalid to address");
        }
        return true;
    }

    function escrowRefund(address _from, uint256 amount) public returns (bool){
        require(_status.state == State.Running, "refund is only available on running state");
        require(msg.sender == _addrBuyer, "invalid caller for refund");
        require(_fundBuyer.addr == _from, "only buyer can refund");
        require(_fundBuyer.amount >= amount, "buyer fund is not enough to refund");
        _fundBuyer.amount = _fundBuyer.amount - amount;
        return true;
    }

    function escrowWithdraw() public returns (bool){
        require(_status.state == State.Success, "withdraw is only available on success state");
        uint256 common = MIN(_fundBuyer.amount, _fundSeller.amount);

        if(common > 0){
            _fundBuyer.amount = _fundBuyer.amount - common;
            _fundSeller.amount = _fundSeller.amount - common;

            // Exchange
            IERC5528(_addrSeller).transfer(_fundBuyer.addr, common);
            IERC5528(_addrBuyer).transfer(_fundSeller.addr, common);

            // send back the remaining balances
            if(_fundBuyer.amount > 0){
                IERC5528(_addrBuyer).transfer(_fundBuyer.addr, _fundBuyer.amount);
            }
            if(_fundSeller.amount > 0){
                IERC5528(_addrSeller).transfer(_fundSeller.addr, _fundSeller.amount);
            }
        }

        _status = State.Closed;
    }

}