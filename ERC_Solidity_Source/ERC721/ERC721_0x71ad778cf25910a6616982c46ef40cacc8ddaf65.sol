// File: contracts/upgrade/AllocationUpgradeable.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IApNFT.sol";
import "../libraries/Types.sol";

contract AllocationUpgradeable is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {

    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    // BASE PERCENT
    uint public constant BASE_PERCENT = 100;
    // Inverse basis point
    uint public constant INVERSE_BASIS_POINT = 10000;

    // max refund limit
    uint public MAX_REFUND_LIMIT;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ASSET_ROLE = keccak256("ASSET_ROLE");
    bytes32 public constant ALLOCATION_ASSET_ROLE = keccak256("ALLOCATION_ASSET_ROLE");

    // true or false auto mint apNFT
    bool public autoMintApNFT;

    // Allocation max create limit
    uint8 public maxAlloctionLimit;
    // Allcotion roundIDs
    uint256[] public roundIDs;
    // groupId => uint256[]
    mapping (uint256 =>  uint256[])  public groupRoundIDs;

    // roundId => Recive payment address of the project
    mapping(uint256 => address) public recivedPay;
    // RoundID=> serialNo => times
    mapping(uint256 => mapping(uint256 => uint256)) public recivePayTimes;
    // RoundID=>SendFundraisingLog[]
    mapping(uint256 => Types.SendFundraisingLog[]) public sendFundraisings;
    // Project fee
    uint256 public fee;
    // Project fee recive address
    address public feeTo;
    
    // roundId => issueToken
    mapping(uint256 => address) public issueToken;


    // roundID => voteEndTime
    mapping(uint256 => uint256) private voteEndTime;
    // roundID => mintEndTime
    mapping(uint256 => uint256) private mintEndTime;

    // roundID => Project
    mapping(uint256 => Types.Project) private round;
    // roundID => UserInfo[]
    mapping(uint256 => Types.PreSaleLog[]) private preSaleLog;
    // roundID => total Quantity (total Quantity )
    mapping(uint256 => uint256) private totalQuantity;

    // roundID => Allow oversold
    // If the total number is greater than 0, oversold is allowed
    mapping(uint256 => bool) private allowOversold;

    // roundID => Lp paused
    mapping(uint256 => bool) private _paused;


    //////////////////// vote use///////////////////////////////
    // userVote roundID => (user => userVoteNum)
    mapping(uint256 => mapping(address=>uint256)) private userVoteNum;
    // userPreSaleNum roundID => (user => userPreSaleNum)
    mapping(uint256 => mapping(address=>uint256)) private userPreSaleNum;
    // roundID => Types.Vote
    mapping(uint256 => Types.Vote) private refundVote;

    /// Mint use
    // userPreSaleNum roundID => (user => mintNum)
    mapping(uint256 => mapping(address=>uint256)) private mintedNum;
    // user=> (presaleID => presaleNum)
    mapping(address => mapping(uint256 => uint256)) private preSaledNum;
    // roundID=> FundraisingStatus:(true/false)
    mapping(uint256 => Types.FundraisingStatus) private fundraisingStatus;

    
    // Refund roundID=> index
    mapping(uint256 => uint256) private refundIndex;

    // withdrawal
    // roundID => to => amount
    mapping(uint256=> mapping(address => uint256)) public withdrawalAllocationTo;
    // roundID => WithdrawalAllocationTotalAmount
    mapping(uint256=> uint256) public withdrawalAllocationTotalAmount;
    
    // roundID => lock:ture/false
    mapping(uint256=> bool) private presaleRefundLock;

    event WithdrawalAllocation(uint256 indexed _roundID, address indexed _to, uint256 indexed _amount);

    event Withdraw(address indexed _token, address indexed _to, uint256 indexed _amount);
        
    event PreSaleClaimed(uint256 indexed roundID, address indexed sender, uint256 indexed preSaleID, uint256 preSaleNum, uint256 timestamp);

    event ApNFTMint(uint256 indexed roundID, uint256 indexed apNftNo, address indexed apNft, address owner, uint256 mintNum, uint256 timestamp);

    event Refund(uint256 indexed roundID, uint256 indexed preSaleID, address indexed recipient, uint256 totalPayment, uint256 referrerFee, uint256 receiveAmount, uint256 timestamp);

    event SendFundraising(uint256 indexed roundID, uint256 indexed serialNo, address indexed recipient, uint256 referrerFee, uint256 receiveAmount, uint256 timestamp);

    event HardtopQuantity(uint256 indexed roundID, uint256 quantity);

    event Paused(uint256 indexed roundID);

    event Unpaused(uint256 indexed roundID);

    event RefundFundraisingVote(uint256 roundID, address voteUser, uint256 timestamp);

    event PresaleRefund(uint256 roundID);
    
    /**
     * @dev initialize the contract by setting a `admin_` and a `operator_` to the Alloction.
     */
    function initialize(address admin_, address operator_) external initializer{
        __ReentrancyGuard_init();
        _setupRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, operator_);
        maxAlloctionLimit = 2;
    }
    
    receive() external payable {}

    /**
     * @dev Modifier to make a function callable only when the lp is not paused.
     *
     * Requirements:
     *
     * - The lp must not be paused.
     */
    modifier whenNotPaused(uint256 _roundID) {
        _requireNotPaused(_roundID);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the lp is paused.
     *
     * Requirements:
     *
     * - The lp must be paused.
     */
    modifier whenPaused(uint256 _roundID) {
        _requirePaused(_roundID);
        _;
    }

    /**
     * @dev Initializes a new presale round by project.
     * This function sets up the details for a new launchpad project with a specified ID. 
     * It requires several parameters:
     * - The target address of the presale.
     * - The receipt address where funds will be sent.
     * - The address of the ERC20 token to be used for payments (if any).
     * - The price of each NFT in the presale.
     * - The start and end times for the presale round.
     * - Maximum number of create alloctoin by the project.
     *
     * Note: This function can only be called by an account with the `OPERATOR_ROLE`.
     *
     * @param _groupID The ID of the presale group to set up.
     * @param _roundID The ID of the presale round to set up.
     * @param _target The target address of the presale.
     * @param _receipt The receipt address where funds will be sent.
     * @param _payment The address of the ERC20 token to be used for payments (if any).
     * @param _nftPrice The price of each NFT in the presale.
     * @param _startTime The start time for the presale round.
     * @param _endTime The end time for the presale round.
     * @param _voteEndTime The vote end time for the presale round.
     * @param _mintEndTime The mint end time for the presale round.
     * @param _totalQuantity The total quantity for the presale round.
     */
    function allocation(uint256 _groupID, uint256 _roundID, address _target, address _receipt, address _payment, uint256 _nftPrice, uint256 _startTime, uint256 _endTime, uint256 _voteEndTime, uint256 _mintEndTime, uint256 _totalQuantity) public onlyRole(OPERATOR_ROLE) {

        require(_roundID > 0, "Invalid roundID");
        require(_endTime > _startTime, "Invalid start or end time");
        require(maxAlloctionLimit >= groupRoundIDs[_groupID].length, "Project limit of 2");
        require(_endTime > block.timestamp, "Invalid time");
        require(_target != address(0), "Invalid target");
        require(_receipt != address(0), "Invalid receipt");
        require(_nftPrice > 0, "nftPrice > 0");
        require(recivedPay[_roundID] == address(0), "Recive payment address already set");

        // create allocation
        Types.Project storage project = round[_roundID];
        require(project.target == address(0), "Already setting");

        project.target = _target;
        project.receipt = payable(this);
        project.payment = _payment;
        project.nftPrice = _nftPrice;
        project.startTime = _startTime;
        project.endTime = _endTime;

        groupRoundIDs[_groupID].push(_roundID);
        roundIDs.push(_roundID);
        // roundID => voteEndTime
        voteEndTime[_roundID] = _voteEndTime;
        // roundID => mintEndTime
        mintEndTime[_roundID] = _mintEndTime;
        totalQuantity[_roundID] = _totalQuantity;
        allowOversold[_roundID] = (_totalQuantity > 0);
        
        // roundId => Recive payment address of the project
        recivedPay[_roundID] = _receipt;
        
        fundraisingStatus[_roundID] = Types.FundraisingStatus.Success;
        emit HardtopQuantity(_roundID, _totalQuantity);
    }

    /**
     * @dev Initializes a new presale round by manager.
     * This function sets up the details for a new launchpad project with a specified ID. It requires several parameters:
     * - The target address of the presale.
     * - The receipt address where funds will be sent.
     * - The address of the ERC20 token to be used for payments (if any).
     * - The price of each NFT in the presale.
     * - The start and end times for the presale round.
     *
     * Note: This function can only be called by an account with the `OPERATOR_ROLE`.
     *
     * @param _roundID The ID of the presale round to set up.
     * @param _target The target address of the presale.
     * @param _receipt The receipt address where funds will be sent.
     * @param _payment The address of the ERC20 token to be used for payments (if any).
     * @param _nftPrice The price of each NFT in the presale.
     * @param _startTime The start time for the presale round.
     * @param _endTime The end time for the presale round.
     * @param _voteEndTime The end time for the presale round.
     * @param _mintEndTime The end time for the presale round.
     */
    function launchpad(uint256 _roundID, address _target, address payable _receipt, address _payment, uint256 _nftPrice, uint256 _startTime, uint256 _endTime, uint256 _voteEndTime, uint256 _mintEndTime) public onlyRole(OPERATOR_ROLE) {
        
        require(_roundID > 0, "Invalid roundID");
        require(_endTime > _startTime, "Invalid start or end time");
        require(_endTime > block.timestamp, "Invalid time");
        require(_target != address(0), "Invalid target");
        require(_receipt != address(0), "Invalid receipt");
        require(_nftPrice > 0, "nftPrice > 0");
        require(recivedPay[_roundID] == address(0), "Recive payment address already set");

        Types.Project storage project = round[_roundID];
        require(project.target == address(0), "Already setting");

        project.target = _target;        
        project.receipt = payable(this);
        project.payment = _payment;
        project.nftPrice = _nftPrice;
        project.startTime = _startTime;
        project.endTime = _endTime;
        
        roundIDs.push(_roundID);
        // roundID => voteEndTime
        voteEndTime[_roundID] = _voteEndTime;
        // roundID => mintEndTime
        mintEndTime[_roundID] = _mintEndTime;
        
        fundraisingStatus[_roundID] = Types.FundraisingStatus.Success;
        
        // roundId => Recive payment address of the project
        recivedPay[_roundID] = _receipt;
        

    }

    /**
     * @dev Executes a presale transaction.
     * This function allows a user to participate in a presale round by purchasing a specific amount of tokens.
      * The function performs several checks to validate the transaction:
     * - Checks that the current time is within the project's start and end times.
     * - Verifies that the `preSaleID` has not been used before by the sender.
     * - Checks that the `preSaleNum` is greater than 0.
     * - If the project's payment address is the zero address, it checks that the value sent with the transaction is
     *   greater or equal to the total cost of the tokens. Any excess value is refunded to the sender.
     * - If the project's payment address is not the zero address, it checks that no ether was sent with the transaction,
     *   and transfers the total cost of tokens from the sender to the project's receipt address using an ERC20 token transfer.
     *
     * After the checks and transfers, the function increments the project's total sales by `preSaleNum`,
     * and records the total payment for the `preSaleID` of the sender.
     *
     * Finally, it emits a `PreSaleClaimed` event.
     *
     * @param roundID The ID of the Project.
     * @param preSaleID The ID of the presale.
     * @param preSaleNum The number of tokens to purchase in the presale.
     * @param voteNum  Latest number of platform coins held by users, converted votes number.
     */
    function preSale(uint256 roundID, uint256 preSaleID, uint256 preSaleNum, uint256 voteNum) public payable whenNotPaused(roundID) nonReentrant {
        Types.Project storage project = round[roundID];

        // Verify time
        require(project.startTime <= block.timestamp, "The LaunchPad activity has not started");
        require(project.endTime >= block.timestamp, "The LaunchPad activity has ended");

        // If the total number is greater than 0, oversold is allowed
        if(allowOversold[roundID]){
            require(project.totalSales + preSaleNum <= totalQuantity[roundID], "The LaunchPad activity has sold out");
            if(project.totalSales + preSaleNum == totalQuantity[roundID]){
                project.endTime = block.timestamp;
            }
        }

        // Verify preSaleID and preSaleNum
        require(project.preSaleRecords[msg.sender][preSaleID] == 0, "Duplicate preSaleID");
        require(preSaleNum > 0, "preSaleNum>0");
        // Receipt token && Refund token
        uint256 total = project.nftPrice * preSaleNum;
        
        if (project.payment == address(0)) {
            require(msg.value >= total, "Insufficient token");
            uint256 _refund = msg.value - total;
            if (_refund > 0) {
                // Refund the excess token
                payable(msg.sender).transfer(_refund);
            }

            // Transfer the total payment to the project receipt address
            project.receipt.transfer(total);
        } else {
            require(msg.value == 0, "Needn't pay mainnet token");

            // Transfer the total payment from the sender to the project receipt address
            IERC20(project.payment).safeTransferFrom(msg.sender, project.receipt, total);
        }

        // Increment the total sales for the project
        unchecked{
            project.totalSales += preSaleNum;
        }

        // Record the total payment for the preSaleID of the sender
        project.preSaleRecords[msg.sender][preSaleID] = total;
        preSaledNum[msg.sender][preSaleID] = preSaleNum;


        // User secondary voting
        uint256 userPreSaleTotalNum = userPreSaleNum[roundID][msg.sender] + preSaleNum; 
        uint256 beforeVoteNum = userVoteNum[roundID][msg.sender];
        uint256 lastVoteNum;
        if(voteNum > userPreSaleTotalNum){
            lastVoteNum = userPreSaleTotalNum;
        }else{
            lastVoteNum = voteNum;
        }

        // total vote number
        refundVote[roundID].totalVote = refundVote[roundID].totalVote.add(lastVoteNum).sub(beforeVoteNum);
        // user latest vote number
        userVoteNum[roundID][msg.sender] = lastVoteNum;
        // user pre sale total number
        userPreSaleNum[roundID][msg.sender] = userPreSaleTotalNum;

        
        // roundID => PreSaleLog[](preSaleID,preSaleUser,paymentTime,preSaleNum)
        preSaleLog[roundID].push(Types.PreSaleLog(preSaleID,msg.sender,block.timestamp,preSaleNum));


        if(autoMintApNFT && project.target != address(0)){
            apNftMint(roundID, project.target, preSaleID);
        }

        emit PreSaleClaimed(roundID, msg.sender, preSaleID, preSaleNum, block.timestamp);
    }

    /**
     * @dev Fundraising refund voting. 
     * If successful, the funds will be disbursed; if unsuccessful, a refund will be issued.
     *
     *
     * @param roundID The ID of the presale round.
     * @param voteUser The voteuser of the presale user.
     */

    function refundFundraisingVote(uint256 roundID, address voteUser) public nonReentrant onlyRole(OPERATOR_ROLE){

        require(roundID > 0, "project is empty");
        Types.Project storage project = round[roundID];
        // Verify time
        require(project.startTime <= block.timestamp, "Activity has not started");
        require(project.endTime <= block.timestamp, "Fundraising Vote has not started");
        require(voteEndTime[roundID] > block.timestamp, "Fundraising Vote has ended");

        Types.Vote storage vote = refundVote[roundID];
        uint256 voteNum = userVoteNum[roundID][voteUser];
        require(voteNum > 0, "vote num is 0");
        // Number of dissenting votes
        vote.voteCount += voteNum;
        userVoteNum[roundID][voteUser] = 0;
        vote.voteRatio = SafeMath.div(SafeMath.mul(vote.voteCount, BASE_PERCENT), vote.totalVote);

        // If the number of dissenting votes is greater than 50%, the fundraising has failed.
        if(vote.voteRatio > 50){
            fundraisingStatus[roundID] = Types.FundraisingStatus.Fail;
        } else {
            //  If the number of dissenting votes is less than 50%, the fundraising is successful.
            fundraisingStatus[roundID] = Types.FundraisingStatus.Success;
        }

        // voteEvent
        emit RefundFundraisingVote(roundID, voteUser, block.timestamp);
    }

    function apNftMint(uint256 roundID, address target, uint256 preSaleID) internal virtual {
        address user = msg.sender;
        uint256 preSaleNum =  getPreSaleNum(user,preSaleID);
        require(preSaleNum > 0, "Pre sale quantity is 0");
        require(target != address(0), "The project does not exist");

        // function batchMint(address _to, uint256 _amount) external;
        IApNFT(target).batchMint(user, preSaleNum);
        
        mintedNum[roundID][user] = mintedNum[roundID][user] + preSaleNum;

        emit ApNFTMint(roundID, preSaleID, target, msg.sender, preSaleNum, block.timestamp);
        
    }

    /**
     * @dev Initiates refunds for a special project.
     * This function allows the project owner to refund amounts to multiple recipients.
     * It requires the round ID, the source address of the funds, an array of recipient addresses and an array of amounts.
     *
     * The function performs several checks to validate the parameters:
     * - Verifies that the length of the recipients array is equal to the length of the amounts array.
     *
     * After the checks, it retrieves the ERC20 token used for payments in the presale round,
     * and for each recipient in the array, it transfers the corresponding amount from the source address to the recipient.
     * It then emits a `Refund` event for each transfer.
     *
     * Note: This function can only be called by an account with appropriate permissions (typically the contract owner).
     *
     * @param roundID The ID of the presale round.
     * @param _Referrer An array of addresses to refund.
     * @param _ReferrerFee An array of _ReferrerFee to refund to each recipient.
     */
    function presaleRefund(uint256 roundID, address payable _Referrer, uint256 _ReferrerFee) public payable nonReentrant onlyRole(OPERATOR_ROLE){

        require(roundID > 0, "project is empty");
        // Verify time
        if(fundraisingStatus[roundID] != Types.FundraisingStatus.Fail){
            return;
        }
        
        if(presaleRefundLock[roundID]){
            return;
        }
        presaleRefundLock[roundID] = true;
        // Get the project associated with the given roundID
        Types.Project storage project = round[roundID];
        Types.PreSaleLog[] memory _logs = preSaleLog[roundID];

        uint256 limit = 1000;
        if(MAX_REFUND_LIMIT > 0 && MAX_REFUND_LIMIT < limit){
            limit = MAX_REFUND_LIMIT;
        }
        uint256 lastLogs = _logs.length - refundIndex[roundID];
        if(limit > lastLogs){
            limit = lastLogs;
        }
        
        if (refundIndex[roundID] >= _logs.length) {
            return;
        }

        uint256 total;
        if (project.payment == address(0)) {
            // Iterate over each recipient and transfer the corresponding amount of tokens
            uint256 i;
            for (; i < limit; i++) {
                Types.PreSaleLog memory _log = _logs[refundIndex[roundID]];
                // Record the total payment for the preSaleID of the sender
                uint256 totalPayment = project.preSaleRecords[_log.preSaleUser][_log.preSaleID];
                _refundEth(roundID, _log.preSaleID, _Referrer,_ReferrerFee,_log.preSaleUser,totalPayment);
                total += totalPayment;
                refundIndex[roundID]++;
            }
        } else {
            require(msg.value == 0, "Needn't pay mainnet token");
            // Iterate over each recipient and transfer the corresponding amount of tokens
            uint256 i;
            for (; i < limit; i++) {
                 Types.PreSaleLog memory _log = _logs[refundIndex[roundID]];
                // Record the total payment for the preSaleID of the sender
                uint256 totalPayment = project.preSaleRecords[_log.preSaleUser][_log.preSaleID];
                _refundTT(roundID, _log.preSaleID, _Referrer, _ReferrerFee, project.payment, _log.preSaleUser, totalPayment);
                total += totalPayment;
                refundIndex[roundID]++;
                
            }
        }

        withdrawalAllocationTotalAmount[roundID] += total;

        presaleRefundLock[roundID] = false;
        emit PresaleRefund(roundID);
    }

    function _refundEth(uint256 roundID, uint256 preSaleID, address payable _Referrer, uint256 _ReferrerFee, address receiver, uint256 totalPayment) internal virtual{
        
        require(address(this).balance >= totalPayment, "Insufficient amount token");
        /* Amount that will be received by user (for Ether). */
        uint256 receiveAmount = totalPayment;
        // Referrer Fee
        uint256 referrerFee;
        if (_Referrer!=address(0) && _ReferrerFee > 0) {
            referrerFee = SafeMath.div(SafeMath.mul(_ReferrerFee, totalPayment), INVERSE_BASIS_POINT);
            receiveAmount = SafeMath.sub(receiveAmount, referrerFee);
            TransferETH(payable(_Referrer), referrerFee);
        }

        TransferETH(payable(receiver), receiveAmount);
        
        emit Refund(roundID, preSaleID, receiver, totalPayment, referrerFee, receiveAmount, block.timestamp);
    }

    function _refundTT(uint256 roundID, uint256 preSaleID, address payable _Referrer, uint256 _ReferrerFee, address token, address receiver, uint256 totalPayment) internal virtual{
        require(IERC20(token).balanceOf(address(this)) >= totalPayment, "Insufficient amount token");
        /* Amount that will be received by user (for Token). */
        uint256 receiveAmount = totalPayment;
        // Referrer Fee
        uint256 referrerFee;
        if (_Referrer!=address(0) && _ReferrerFee > 0) {
            referrerFee = SafeMath.div(SafeMath.mul(_ReferrerFee, totalPayment), INVERSE_BASIS_POINT);
            receiveAmount = SafeMath.sub(receiveAmount, referrerFee);
            TT(token, payable(_Referrer), referrerFee);
        }

        TT(token, payable(receiver), receiveAmount);

        emit Refund(roundID, preSaleID, receiver, totalPayment, referrerFee, receiveAmount, block.timestamp);
    }

    /**
     * @dev The project party releases the fundraising funds
     *
     * @param roundID The ID of the alloction round.
     * @param _serialNo release serial no.
     * @param _amount release amount.
     */
    function sendFundraising(uint256 roundID, uint256 _serialNo, uint256 _amount) public payable nonReentrant onlyRole(OPERATOR_ROLE){

        require(roundID > 0, "project is empty");
        require(_serialNo > 0, "serialNo is empty");
        require(_amount > 0, "The amount must be greater than 0");
        require(recivedPay[roundID] != address(0), "project pay address is empty");
        // Verify time
        if(fundraisingStatus[roundID] != Types.FundraisingStatus.Success){
            return;
        }

        require(recivePayTimes[roundID][_serialNo] == 0, "Repeated sending of current amount");
        
        // Get the project associated with the given roundID
        Types.Project storage project = round[roundID];
                  
        uint256 totalAmount = project.nftPrice * project.totalSales;
        withdrawalAllocationTotalAmount[roundID] += _amount;
        require(totalAmount >= withdrawalAllocationTotalAmount[roundID], "Exceeding the maximum withdrawal amount");
        
        /* Amount that will be received by user (for Ether). */
        uint256 receiveAmount = _amount;
        uint256 referrerFee;
        if (project.payment == address(0)) {
            require(address(this).balance >= _amount, "Insufficient amount token");
            // Referrer Fee
            if (feeTo!=address(0) && fee > 0) {
                referrerFee = SafeMath.div(SafeMath.mul(fee, _amount), INVERSE_BASIS_POINT);
                receiveAmount = SafeMath.sub(receiveAmount, referrerFee);
                TransferETH(payable(feeTo), referrerFee);
            }
            TransferETH(payable(recivedPay[roundID]), receiveAmount);
        } else {
            require(msg.value == 0, "Needn't pay mainnet token");
            // Iterate over each recipient and transfer the corresponding amount of tokens
            IERC20 _token = IERC20(project.payment);
            require(_token.balanceOf(address(this)) >= _amount, "Insufficient amount token");
            // Referrer Fee
            if (feeTo!=address(0) && fee > 0) {
                referrerFee = SafeMath.div(SafeMath.mul(fee, _amount), INVERSE_BASIS_POINT);
                receiveAmount = SafeMath.sub(receiveAmount, referrerFee);
                TT(project.payment, payable(feeTo), referrerFee);
            }
            TT(project.payment, payable(recivedPay[roundID]), receiveAmount);
        }

        sendFundraisings[roundID].push(Types.SendFundraisingLog(block.timestamp, _amount, receiveAmount));
        recivePayTimes[roundID][_serialNo] = sendFundraisings[roundID].length;

        emit SendFundraising(roundID, _serialNo, recivedPay[roundID], referrerFee, receiveAmount,  block.timestamp);
    }

    function getFundraisingLength(uint256 roundID) public view returns (uint256){
        return sendFundraisings[roundID].length;
    }

    function getFundraisingByNo(uint256 roundID, uint256 serialNo) public view returns (uint256, uint256,uint256,uint256){
        uint256 index = recivePayTimes[roundID][serialNo];
        if(index > 0){
            index -= 1;
        }
        Types.SendFundraisingLog storage log = sendFundraisings[roundID][index];
        return (index, log.sendTime, log.amount, log.receiveAmount);
    }

    function getFundraisingByIndex(uint256 roundID, uint256 index) public view returns (uint256, uint256,uint256,uint256){
        Types.SendFundraisingLog storage log = sendFundraisings[roundID][index];
        return (index, log.sendTime, log.amount, log.receiveAmount);
    }

    // Returns project details by the roundID.
    function getProject(uint256 roundID) external view returns (address, address, address, uint256, uint256, uint256, uint256){
        Types.Project storage project = round[roundID];
        return (project.target, project.receipt, project.payment, project.nftPrice, project.totalSales, project.startTime, project.endTime);
    }

    // Returns project totalSales by the roundID.
    function getProjectTotalSales(uint256 roundID) external view returns (uint256){
        Types.Project storage project = round[roundID];
        return project.totalSales;
    }

    // Returns project preSaleRecords by the roundID.
    function getProjectPreSale(uint256 roundID, address user, uint256 preSaleID) external view returns (uint256){
        Types.Project storage project = round[roundID];
        return project.preSaleRecords[user][preSaleID];
    }

    // Returns project vote Records by the roundID.
    function getProjectVote(uint256 roundID) external view returns (uint256, uint256, uint256){
        Types.Vote storage vote = refundVote[roundID];
        
        // (Oppose votes, total votes, vote ratio)
        return (vote.voteCount, vote.totalVote, vote.voteRatio);
    }


    // Returns project details by the roundID.
    function getAlloctionInfo(uint256 _roundID) external view returns (Types.AlloctionInfo memory info){
        Types.Project storage project = round[_roundID];
    
        info = Types.AlloctionInfo(
            project.target, 
            project.receipt, 
            project.payment, 
            project.nftPrice, 
            project.totalSales, 
            project.startTime, 
            project.endTime,
            totalQuantity[_roundID],
            voteEndTime[_roundID],
            mintEndTime[_roundID],
            issueToken[_roundID],
            recivedPay[_roundID],
            Types.AllocStatus(
                uint8(fundraisingStatus[_roundID]),
                isAllowOversold(_roundID),
                isSoldOut(_roundID),
                _paused[_roundID]
            )
        );
        return info;
    }

    //  set project nft target by the roundID.
    function setApNFTTarget(uint256 roundID, address _nftTarget) public onlyRole(OPERATOR_ROLE){
        require(_nftTarget != address(0), "Invalid nft target");
        Types.Project storage project = round[roundID];
        project.target = _nftTarget;
    }

    //  Returns project target by the roundID.
    function getApNFTTarget(uint256 roundID) public view returns (address){
        Types.Project storage project = round[roundID];
        return project.target;
    }
    // Returns project preSale num by the preSaleID and user.
    function getPreSaleNum(address user, uint256 preSaleID) public view returns (uint256){
        return preSaledNum[user][preSaleID];
    }

    // Returns project preSale num by the user and ronudID.
    function getPreSaleNumByUser(address user, uint256 roundID) public view returns (uint256){
        return userPreSaleNum[roundID][user];
    }

    // Returns project preSale minted num by the user.
    function getMintNum(address user, uint256 roundID) public view returns (uint256){
        return mintedNum[roundID][user];
    }

    // Returns project preSale minted num by the user.
    function getMintInfo(address user, uint256 roundID) public view returns (uint256 preSaleNum, uint256 mintNum){
        return (userPreSaleNum[roundID][user], mintedNum[roundID][user]);
    }

    /**
     * @dev Executes a function call on another contract.
     * @param dest The address of the contract to call.
     * @param value The amount of ether/matic/mainnet token to send with the call.
     * @param func The function signature and parameters to call.
     */
    function execute(address dest, uint256 value, bytes calldata func) external onlyRole(OPERATOR_ROLE) {
        _call(dest, value, func);
    }

    /**
     * @dev Executes a batch of function calls on multiple contracts.
     * This function allows this contract to execute a batch of function calls on multiple contracts by specifying
     * an array of destination addresses, an array of values to send with each call, and an array of function signatures
     * and parameters for each call.
     * @param dest An array of addresses of the contracts to call.
     * @param value An array of amounts of ether/matic/mainnet token to send with each call.
     * @param func An array of function signatures and parameters to call for each destination.
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func) external onlyRole(OPERATOR_ROLE) {
        require(dest.length == func.length && (value.length == 0 || value.length == func.length), "Wrong array lengths");
        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], value[i], func[i]);
            }
        }
    }

    /**
     * @dev Executes a low-level call to another contract.
     * This internal function allows the contract to execute a low-level call to another contract,
     * by specifying the target address, the value to send with the call, and the data to send.
     *
     * It performs the call and checks if it was successful. If not, it reverts the transaction and returns
     * the error message from the failed call.
     *
     * Note: Use this function with caution as low-level calls can be dangerous.
     *
     * @param target The address of the contract to call.
     * @param value The amount of ether/mainnet token to send with the call.
     * @param data The data to send with the call.
     */
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @dev Set the total pre-sale quantity. 
     * If the total number is greater than 0, oversold is allowed
     * @param _roundID project Id
     * @param _totalQuantity total number
     */
    function setTotalQuantity(uint256 _roundID, uint256 _totalQuantity) public onlyRole(OPERATOR_ROLE) {
        Types.Project storage project = round[_roundID];
        require(project.target != address(0), "Project does not exist");
        require(project.totalSales <= _totalQuantity, "Project total quantity needs to be greater than the total pre-sale amount");
        totalQuantity[_roundID] = _totalQuantity;
        allowOversold[_roundID] = (_totalQuantity > 0);
        
        emit HardtopQuantity(_roundID, _totalQuantity);
    }

    // Returns project TotalQuantity by the roundID.
    function getTotalQuantity(uint256 _roundID) external view returns (uint256){
        return totalQuantity[_roundID];
    }

    // Returns project allowOversold by the roundID.
    function isAllowOversold(uint256 _roundID) public view returns (bool){
        return allowOversold[_roundID];
    }

    // Returns project SoldOut status by the roundID.
    function isSoldOut(uint256 _roundID) public view returns (bool){
        return totalQuantity[_roundID] > 0 && round[_roundID].totalSales == totalQuantity[_roundID];
    }

    // Returns project PreSaleLog[] by the roundID.
    function getPreSaleLog(uint256 _roundID) external view returns (Types.PreSaleLog[] memory){
        return preSaleLog[_roundID];
    }

    // Returns project status(totalSales,totalQuantity,allowOversold,SoldOut,paused) by the roundID.
    function getLpStatus(uint256 _roundID) external view returns (uint256, uint256, bool, bool, bool){
        bool soldOut = totalQuantity[_roundID] > 0 && round[_roundID].totalSales == totalQuantity[_roundID];
        return (round[_roundID].totalSales, totalQuantity[_roundID], allowOversold[_roundID], soldOut, _paused[_roundID]);
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The lp must not be paused.
     */
    function pause(uint256 _roundID) public whenNotPaused(_roundID) onlyRole(OPERATOR_ROLE)  {
        _paused[_roundID] = true;
        emit Paused(_roundID);
    }
    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The lp must be paused.
     */
    
    function unpause(uint256 _roundID) public whenPaused(_roundID) onlyRole(OPERATOR_ROLE)  {
        _paused[_roundID] = false;
        emit Unpaused(_roundID);
    }

    /**
     * @dev Returns true if the lp is paused, and false otherwise.
     */
    function paused(uint256 _roundID) public view virtual returns (bool) {
        return _paused[_roundID];
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused(uint256 _roundID) internal view virtual {
        require(!paused(_roundID), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused(uint256 _roundID) internal view virtual {
        require(paused(_roundID), "Pausable: not paused");
    }
    
    // Set the address for receiving transaction fees, and set this address to enable transaction fees
    function setFeeTo(address _feeTo) external onlyRole(OPERATOR_ROLE) {
        feeTo = _feeTo;
    }

    // Set project funding handling fees
    function setFee(uint256 _fee) external onlyRole(OPERATOR_ROLE) {
        fee = _fee;
    }

    // Set up automatic Mint NFT to the user's address after pre-sale of the project
    function setAutoMint(bool _autoMint) public onlyRole(OPERATOR_ROLE) {
        autoMintApNFT = _autoMint;
    }

    // Set project NFT mint quantity
    function setMintNum(uint256 _roundID,address user, uint256 preSaleNum) public onlyRole(OPERATOR_ROLE) {
        mintedNum[_roundID][user] = preSaleNum;
    }
    
    // Set Project - Payment Acceptance Address
    function setPaymentReceipt(uint256 _roundID, address _receipt) public onlyRole(OPERATOR_ROLE) { 
        Types.Project storage project = round[_roundID];
        require(project.target != address(0), "Project does not exist");
        require(_receipt != address(0), "Receipt address is empty");
        project.receipt = payable(_receipt);
    }

    // Set Project - Pre sale End Time
    function setEndTime(uint256 _roundID, uint256 _endTime) public onlyRole(OPERATOR_ROLE) { 
        Types.Project storage project = round[_roundID];
        require(project.target != address(0), "Project does not exist");
        project.endTime = _endTime;
    }

    // Set Project - Second Voting End Time
    function setVoteEndTime(uint256 _roundID, uint256 _voteEndTime) public onlyRole(OPERATOR_ROLE) {
        Types.Project storage project = round[_roundID];
        require(project.target != address(0), "Project does not exist");
        voteEndTime[_roundID] = _voteEndTime;
    }

    // Set project - mint end time
    function setMintEndTime(uint256 _roundID, uint256 _mintEndTime) public onlyRole(OPERATOR_ROLE) {
        Types.Project storage project = round[_roundID];
        require(project.target != address(0), "Project does not exist");
        mintEndTime[_roundID] = _mintEndTime;
    }

    // Set project - issue token
    function setIssueToken(uint256 _roundID, address _issueToken) public onlyRole(OPERATOR_ROLE) {
        Types.Project storage project = round[_roundID];
        require(project.target != address(0), "Project does not exist");
        issueToken[_roundID] = _issueToken;
    }

    // get project - issue token
    function getIssueToken(uint256 _roundID) public view returns (address) {
       return issueToken[_roundID];
    }

    // Returns project voteEndTime num by the _roundID.
    function getVoteEndTime(uint256 _roundID) public view returns (uint256){
        return voteEndTime[_roundID];
    }
    // Returns project mintEndTime num by the _roundID.
    function getMintEndTime(uint256 _roundID) public view returns (uint256){
        return mintEndTime[_roundID];
    }

    // Returns project fundraisingStatus num by the _roundID.
    function getFundraisingStatus(uint256 _roundID) public view returns (uint8){
        return uint8(fundraisingStatus[_roundID]);
    }

    // Set project - fundraising status
    function setFundraisingStatus(uint256 _roundID, uint8 _fundraisingStatus) public onlyRole(OPERATOR_ROLE) {
        fundraisingStatus[_roundID] = Types.FundraisingStatus(_fundraisingStatus);
    }

    // get project - vote num
    function getVoteNum(uint256 _roundID, address user) public view returns (uint256) {
        return userVoteNum[_roundID][user];
    }

    // Set project - recived pay address
    function setRecivedPay(uint256 _roundID, address _newRecivedPay) public onlyRole(OPERATOR_ROLE) {
        recivedPay[_roundID] = _newRecivedPay;
    }

    function TransferETH(address payable _receiver, uint256 _Amount) internal {
        // assert(payable(_receiver).send(_Amount));
        // This forwards all available gas. Be sure to check the return value!
        (bool success, ) = _receiver.call{value: _Amount}("");
        require(success, "Transfer failed.");

    }

    function TT(address _tokenAddress, address payable _receiver, uint256 _Amount) internal {
        IERC20(_tokenAddress).safeTransfer(_receiver, _Amount);
    }

    // withdraw eth
    function withdraw(address payable _to) public onlyRole(ASSET_ROLE) {
        uint256 balance = address(this).balance;
        // _to.transfer(balance);
        (bool success, ) = _to.call{value: balance}("");
        require(success, "Transfer failed.");
        emit Withdraw(address(0), _to, balance);
    }

    function thisBalance() public view returns (uint256){
        return address(this).balance;
    }

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getWithdrawableAmount(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    // withdraw token
    function withdrawToken(address _token, address _to) public onlyRole(ASSET_ROLE) {
        uint256 balance = getWithdrawableAmount(_token);
        IERC20(_token).safeTransfer(_to, balance);
        emit Withdraw(_token, _to, balance);
    }

    // withdraw allocation eth
    function withdrawalAllocation(uint256 _roundID, address payable _to, uint256 _amount) public onlyRole(ALLOCATION_ASSET_ROLE) {
        require(_roundID > 0, "Params roundID is empty");
        require(_to != address(0), "Params to is empty");
        require(_amount > 0, "Params amount is empty");
        Types.Project storage project = round[_roundID];
        
        // total pre-sale amount
        uint256 totalAmount = SafeMath.mul(project.nftPrice, project.totalSales);
        require(totalAmount > 0, "No total pre-sale amount");
        withdrawalAllocationTotalAmount[_roundID] += _amount;
        require(totalAmount >= withdrawalAllocationTotalAmount[_roundID], "Exceeding the maximum withdrawal amount");

        if(project.payment == address(0)){
            uint256 balance = address(this).balance;
            require(balance >= _amount, "The withdrawal amount for this allocation is insufficient");
            // _to.transfer(_amount);
            
            (bool success, ) = _to.call{value: _amount}("");
            require(success, "Transfer failed.");
        } else {
            uint256 balance = IERC20(project.payment).balanceOf(address(this));
            require(balance >= _amount, "The withdrawal token amount for this allocation is insufficient");
            IERC20(project.payment).safeTransfer(_to, _amount);
        }
        withdrawalAllocationTo[_roundID][_to] += _amount;
        emit WithdrawalAllocation(_roundID, _to, _amount);
    }

    /**
     * @dev Returns the allocation amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getAllocationWithdrawableAmount(uint256 _roundID) public view returns (uint256) {
        Types.Project storage project = round[_roundID];
        // total pre-sale amount
        uint256 totalAmount = SafeMath.mul(project.nftPrice, project.totalSales);
        return totalAmount.sub(withdrawalAllocationTotalAmount[_roundID]);
    }

    // Set the maximum number of projects created by the project team
    function setMaxAlloctionLimit(uint8 _limit) public onlyRole(OPERATOR_ROLE) {
        maxAlloctionLimit =_limit;
    }

    // Set the maximum number of refund 
    function setMaxRefundLimit(uint8 _limit) public onlyRole(OPERATOR_ROLE) {
        MAX_REFUND_LIMIT =_limit;
    }
}


// File: contracts/libraries/Types.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

/**
 * @title Types
 * @author CORESKY Protocol
 *
 * @notice A standard library of data types used throughout the CORESKY Protocol.
 */
library Types {
    /**
     * @notice A struct containing the necessary information to reconstruct an EIP-712 typed data signature.
     *
     * @param signer The address of the signer. Specially needed as a parameter to support EIP-1271.
     * @param v The signature's recovery parameter.
     * @param r The signature's r parameter.
     * @param s The signature's s parameter.
     * @param deadline The signature's deadline.
     */
    struct EIP712Signature {
        address signer;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
    }

    struct Proposal{
        //Voting number
        uint256 serialNo;
        //Project address
        address projectAddr;
        //Support quantity
        uint256 supportCount;
        //Oppose quantity
        uint256 opposeCount;
        //Voting ratio
        uint256 voteRatio;
        //Expiration date
        uint256 expireTime;
        //Total payment amount
        uint256 amount;
    }

    struct Vote{
        //Oppose quantity
        uint256 voteCount;
        //Total number of votes
        uint256 totalVote;
        //Voting ratio
        uint256 voteRatio;
    }

    /**
     * @notice An enum containing the different states the protocol can be in, limiting certain actions.
     *
     * @param Unpaused The fully unpaused state.
     * @param PublishingPaused The state where only publication creation functions are paused.
     * @param Paused The fully paused state.
     */
    enum ProtocolState {
        Unpaused,
        PublishingPaused,
        Paused
    }

    struct Project {
        address target;             // nft or deposit or any contract
        address payable receipt;    // receive payment
        address payment;            // ETH or ERC20
        uint256 nftPrice;           // nft nftPrice
        uint256 totalSales;         // nft totalSales
        uint256 startTime;          // start
        uint256 endTime;            // end
        // user=> presaleID => total
        mapping(address => mapping(uint256 => uint256)) preSaleRecords;  //preSale records
    }

    struct PreSaleLog {
        uint256 preSaleID;
        address preSaleUser;  
        uint256 paymentTime; 
        uint256 preSaleNum;
    }

    struct VestingLog {
        uint256 unlockIndex;
        uint256[] unlockTime; 
        uint256[] unlockNum;
    }

    struct SendFundraisingLog {
        uint256 sendTime; 
        uint256 amount;
        uint256 receiveAmount;
    }

    struct IssueToken {
        address issueToken;
        uint256 chainId;
        uint256 nftContainNum;
    }

    enum FundraisingStatus {
        None,
        Success,
        Fail
    }

    struct AllocStatus {
        uint8 fundraisingStatus;    // 0-none;1-success;2-fail
        bool isAllowOversold;       // AllowOversold: true/false
        bool isSoldOut;             // SoldOut:true/false
        bool paused;                // paused:true/false
    }

    struct AlloctionInfo {
        address target;             // nft or deposit or any contract
        address receipt;            // receive payment
        address payment;            // ETH or ERC20
        uint256 nftPrice;           // nft nftPrice
        uint256 totalSales;         // nft totalSales
        uint256 startTime;          // presale start
        uint256 endTime;            // presale end
        uint256 totalQuantity;      // total
        uint256 voteEndTime;        // vote end
        uint256 mintEndTime;        // mint end
        address issueToken;         // issue token address
        address recivedPay;         // Recive payment address of the project fundraising
        AllocStatus status;
    }

}


// File: contracts/interfaces/IApNFT.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IApNFT {

    function initialize(string memory name_,string memory symbol_,string memory baseUri_) external;

    function mint(address _to, uint256 _tokenId) external;

    function batchMint(address _to, uint256 _amount) external;

    function ownerBatchMint(address[] calldata _tos) external;
}


// File: @openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// File: @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}


// File: @openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(account),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


// File: @openzeppelin/contracts/utils/math/SafeMath.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}


// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}


// File: @openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


// File: @openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


// File: @openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// File: @openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/MathUpgradeable.sol";

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, MathUpgradeable.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}


// File: @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// File: @openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}


// File: @openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File: @openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // �� `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // �� `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}


