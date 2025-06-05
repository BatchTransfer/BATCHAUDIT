// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/MNOPToken.sol
pragma solidity 0.6.12;

import "./libs/BEP20Pausable.sol";
import "./libs/MinterRole.sol";




// MNOP Token with Governance.
contract MNOPToken is MinterRole,BEP20Pausable {
    /// @notice Creates `_amount` token to `_to`. Must only be called by the a minter.
    function mint(address _to, uint256 _amount) public onlyMinter {
        _mint(_to, _amount);
        _moveDelegates(address(0), _delegates[_to], _amount);
    }

     /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    
     function burn(address _account, uint256 _amount) public onlyMinter {
        _burn(_account, _amount);
        _moveDelegates( _delegates[_account],address(0), _amount);
    }


    /**
     * @dev pause the token for transfers other than addresses with the CanTransfer Role
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev unpause the token for anyone to transfer
     */
    function unpause() public onlyOwner {
        _unpause();
    }


    //Coppied and modified from EggToken Code
    // which is copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol


    mapping (address => address) internal _delegates;

    uint256 private _totalClaimed;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

      /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);


    /// returns the total claimed mnop
    // this is just purely used to display the total mnop claimed by users on the frontend
    function totalClaimed() public view returns (uint256) {
        return _totalClaimed;
    }

    // add mnop claimed
    function addClaimed(uint256 _amount) public onlyCanTransfer {
        _totalClaimed = _totalClaimed.add(_amount);
    }

    // set mnop claimed to a custom value, for if we wanna reset the counter anytime
    function setClaimed(uint256 _amount) public onlyCanTransfer {
        require(_amount >= 0, "nonono cant be negative");
        _totalClaimed = _amount;
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegator The address to get delegatee for
     */
    function delegates(address delegator)
        external
        view
        returns (address)
    {
        return _delegates[delegator];
    }

   /**
    * @notice Delegate votes from `msg.sender` to `delegatee`
    * @param delegatee The address to delegate votes to
    */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }


    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "MNOP::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "MNOP::delegateBySig: invalid nonce");
        require(now <= expiry, "MNOP::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account)
        external
        view
        returns (uint256)
    {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber)
        external
        view
        returns (uint256)
    {
        require(blockNumber < block.number, "MNOP::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee)
        internal
    {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying MNOP (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld.sub(amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld.add(amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
        internal
    {
        uint32 blockNumber = safe32(block.number, "MNOP::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}

// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/Memenopoly.sol
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

import "./MNOPToken.sol";
import "./MnopCard.sol";
import "./TheBroker.sol";


// This is the main game contrat, all logic for Memenopoly game mechanics can be found within.

contract Memenopoly is Ownable, ReentrancyGuard, VRFConsumerBase {
    // using SafeMath for uint256;
    using SafeMathChainlink for uint256;
    
    using SafeBEP20 for IBEP20;


    // Chainlink VRF
    bytes32 internal keyHash;
    uint256 internal linkFee;
    address internal vrfCoordinator;

    // The MNOP TOKEN!
    MNOPToken public mnop;

    // TheBroker Contract
    TheBroker public theBroker;

    // Dev address.
    address public devaddr;

    // The amount to seed the parking jackpot with
    uint256 public defaultParking;

    // The burn address
    address public burnAddress;   
    
    //Game active
    bool public gameActive;

    // Max level a play can achive
    uint256 public maxLevel;

    // The amount you collect landing on go/sppt 0
    uint256 public payDayReward;

    // The amount you collect landing on chest spots
    uint256 public chestReward;

    // time in second between rolls
    uint256 public rollTimeLimit;

    // time in second before a player is no longer considered active for payout
    uint256 public activeTimeLimit;

    uint256 nonce; //for chainlink seed
    uint256 totalSpaces; // Total board spots
    uint256 public parkingBalance; // current jackpot balance
    uint256 public totalRentPaid; // total rent ever paid
    uint256 public totalRentPaidOut; // total rewards paid out
    uint256 public totalPlayers; //players that rolled at least 1 time
    uint256 public totalRolls; //all time total rolls
    uint256 public jackpotWins; //Total times the jackpot was won
    uint256 public jailCount; //Total times someone was sent to jail


    //player data structure
    struct PlayerInfo {
      uint256 rewards; //rewards this player has gained during the game
      uint256 spotId;   // the index of the spot they are currently on.
      uint256 rentDue;      // the current rent due for this player.
      uint256 lastRoll; // the lsast number rolled
      uint256 lastRollTime; // timestamp of the last roll
      uint256 level; //the current level for this player
      bool inJail; //if this player is in jail
      uint256 totalClaimed; //lifetime mnop claimed from the game
      uint256 totalRentPaid; //lifetime rent and taxes paid
      uint256 totalRolls; //total rolls for this player
      uint256 jackpotWins; //Total times the jackpot was won
      uint256 jailCount; //Total times someone was sent to jail
      bool isRolling; //if this player is in jail

    }

    
    struct BoardInfo {
        uint256 spotType; //what type of space this is
        uint256 rent;      // the rent for this space.
        uint256 balance;  // the balance currently paid to this spot
        uint256 nftId; // Nft id's that relate to this spot
        uint256 totalPaid;  // total rent paid to this spot
        uint256 totalLanded;  // total times someone landed on this spot
    }

    mapping(address => PlayerInfo) public playerInfo;
    mapping(bytes32 => address) private rollQueue;
    mapping(uint256 => BoardInfo) public boardInfo;

    event Roll(address indexed user, uint256 rollNum, uint256 spodId, uint256 rent, bool isPropOwner, uint256 timeStart);
    event LandedParking(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event GotoJail(address indexed user, uint256 amountBurned);

    event SetGameActive(bool isActive);
    event SetDefaultParking(uint256 amount);
    event SetChestReward(uint256 amount);
    event SetPayDayReward(uint256 amount);
    event SpotUpdated(uint256 spotId, uint256 spotType, uint256 rent, uint256 nftId, bool clearBalance);

    event SetFeeAddress(address indexed user, address indexed newAddress);
    event SetDevAddress(address indexed user, address indexed newAddress);
    event UpdateBrokerAddress(address indexed user, TheBroker indexed theBroker);
    event UpdateRollTimeLimit(address indexed user, uint256 rollTimeLimit);
    event UpdateActiveTimeLimit(address indexed user, uint256 activeTimeLimit);
    event UpdateMaxLevel(address indexed user, uint256 level);
    event SpotPaid(uint256 spotId, uint256 totalBal, uint256 share, uint256 extraBurnt, uint256 toParking, uint256 toBurn, uint256 toDev, address[] stakers);
    event SetLinkFee(address indexed user, uint256 fee);

    //-----------------------------

    constructor(
        MNOPToken _mnop, //mnop token address
        TheBroker _theBroker, //the broker token address
        address _devaddr, //dev address
        uint256 _maxLevel, //the level cap for players
        uint256 _defaultParking, //the value of a fresh parking jackpot
        uint256 _payDayReward, //the value of landing on go, (payDayReward/10) for passing it
        uint256 _chestReward, //value to mint on a chest spot
        uint256 _rollTimeLimit, //seconds between rolls
        uint256 _activeTimeLimit, //seconds since last roll before a player is ineligible for payouts
        uint256[] memory _boardTypes, //an array of each board piece by type
        uint256[] memory _boardRent, //a corresponding array of each board piece by rent
        uint256[] memory _nftIds, //a corresponding array of each board piece by nftId
        address _vrfCoordinator,
        bytes32 _vrfKeyHash, 
        address _linkToken,
        uint256 _linkFee
    )  VRFConsumerBase (
        _vrfCoordinator, 
        _linkToken
    ) public {
        mnop = _mnop;
        theBroker = _theBroker;
        devaddr = _devaddr;
        maxLevel = _maxLevel;
        defaultParking = _defaultParking;
        payDayReward = _payDayReward;
        chestReward = _chestReward;
        rollTimeLimit = _rollTimeLimit;
        activeTimeLimit = _activeTimeLimit;

        burnAddress = 0x000000000000000000000000000000000000dEaD;
        //set the default board
        _setBoard(_boardTypes, _boardRent, _nftIds); 

        
        vrfCoordinator = _vrfCoordinator;
        keyHash = _vrfKeyHash;
        linkFee = _linkFee;

        // testnet settings
        // vrfCoordinator = 0xa555fC018435bef5A13C6c6870a9d4C11DEC329C;
        // linkToken = LinkTokenInterface(0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06);
        // keyHash = 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186;
        // linkFee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
    }



    /** 
     * @notice Modifier to only allow updates by the VRFCoordinator contract
     */
    modifier onlyVRFCoordinator {
        require(msg.sender == vrfCoordinator, 'Fulfillment only allowed by VRFCoordinator');
        _;
    }


    /**
    * @dev Roll and take a players turn
    * - must not owe rent
    * - must have waited long enough between rolls
    * - sends request to chainlink VRF
    */
    function roll() public returns (bytes32 requestId) {
        //roll and move

        PlayerInfo storage player = playerInfo[msg.sender];

        require(gameActive, "Memenopoly: Game not active");
        require(player.rentDue == 0, "Memenopoly: Rent is due pal!");
        require( block.timestamp >= player.lastRollTime.add(rollTimeLimit), "Memenopoly: Roll time not reached");
        require(LINK.balanceOf(address(this)) > linkFee, "Not enough LINK - fill contract with faucet");
       

        //Virgin player
        if( player.totalRolls < 1){
            totalPlayers = totalPlayers.add(1);
        }

        //inc some counters
        player.totalRolls = player.totalRolls.add(1);
        totalRolls = totalRolls.add(1);

        //check for players in jail
        if(player.inJail){
            //set them free
            player.inJail = false;
            //transport them to the jail spot 
            player.spotId = 10;
        }

        //check free parking to make sure there is always something to pay out
        //this shouldnt need to happen
        if(parkingBalance <= 0){
            seedParking();
        }

        //harvest any pending game rewards
        if(player.rewards > 0){
            _claimGameRewards();
        }

        //time lock the roll
        player.lastRollTime = block.timestamp;
        player.isRolling = true;
        bytes32 _requestId = requestRandomness(keyHash, linkFee, randomizeSeed());
        rollQueue[_requestId] = msg.sender;
        return _requestId;
    }

     /**
     * @notice Callback function used by VRF Coordinator
     * @dev Important! Add a modifier to only allow this function to be called by the VRFCoordinator
     * @dev The VRF Coordinator will only send this function verified responses.
     * @dev The VRF Coordinator will not pass randomness that could not be verified.
     * @dev Get a number between 2 and 12, and run the roll logic
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override onlyVRFCoordinator {
        uint256 _roll = randomness.mod(11).add(2);
        address _player = rollQueue[requestId];
        doRoll(_roll,_player);
    }


    /*
    types: [
        0: 'start',
        1: 'prop',
        2: 'rr',
        3: 'util',
        4: 'chest',
        5: 'chance',
        6: 'tax',
        7: 'jail',
        8: 'gojail',
        9: 'parking'
    ]
    */
    /**
     * @dev called by fulfillRandomness, process the roll and mvoe the player
     */
    function doRoll(uint256 _roll,address _player) internal onlyVRFCoordinator {

        bool isPropOwner =  false;
        bool doSeedParking = false;

        PlayerInfo storage player = playerInfo[_player];

        //move the player
        player.spotId = player.spotId.add(_roll);

        //log last roll
        player.lastRoll = _roll;

        //check if we passed go
        if(player.spotId >= totalSpaces){
          player.level = player.level.add(1);
          
          //make sure they are capped at the max level
          if(player.level > maxLevel){
            player.level = maxLevel;
          }

          player.spotId = player.spotId.sub(totalSpaces);
          
          //don't pay them twice
          if(player.spotId != 0){
            //multiply by the level
            totalRentPaidOut = totalRentPaidOut.add(payDayReward.mul(player.level));
            player.rewards = player.rewards.add(payDayReward.mul(player.level));
            mnop.mint(address(this), payDayReward.mul(player.level));
          }
        }

        BoardInfo storage bSpot = boardInfo[player.spotId];

        //some stats
        bSpot.totalLanded = bSpot.totalLanded.add(1);

        //set the rent
        uint256 rent = bSpot.rent;
        
        //check the spot type
        if(bSpot.spotType == 0){
            //landed on go mint 4x the pay day x the level
            totalRentPaidOut =  totalRentPaidOut.add(payDayReward.mul(4).mul(player.level));
            player.rewards = player.rewards.add(payDayReward.mul(4).mul(player.level));
            mnop.mint(address(this), payDayReward.mul(4).mul(player.level));
        }

        if(bSpot.spotType == 1 || bSpot.spotType == 2){
            //property and rocket
            //don't pay rent for our own property
            isPropOwner = _isStaked(_player, player.spotId);
            if(isPropOwner){
                rent = 0;
            }
        }


        if(bSpot.spotType == 3){
            /*
            @dev Utility
            rent is base rent X the roll so we can have varying util rents
            ie: 
            - first util spot rent is 4 so (4x the roll)
            - second util spot rent is 8 so (8x the roll)
            */

            rent = rent.mul(_roll);
        }

        if(bSpot.spotType == 4){
            //community chest
            totalRentPaidOut =  totalRentPaidOut.add(chestReward);
            player.rewards = player.rewards.add(chestReward);
            mnop.mint(address(this), chestReward);
        }

        if(bSpot.spotType == 5){
            //roll again
            //get a free roll, set the timesamp back 
            player.lastRollTime = block.timestamp.sub(rollTimeLimit);
        }

        if(bSpot.spotType == 8){
            //go to jail
            //take away a level
            if(player.level > 0){
                player.level = player.level.sub(1);
            }

            //flag player in jail
            player.inJail = true;
            player.jailCount = player.jailCount.add(1);
            jailCount = jailCount.add(1);

            //Clear the jackpot
            uint256 _pbal = parkingBalance;
            parkingBalance = 0;

            //lock them for 2 rolls time
            player.lastRollTime = block.timestamp.add(rollTimeLimit.mul(2));

            emit GotoJail(_player, _pbal);

           /*  )
              ) \  
             / ) (  
             \(_)/ */
            //Burn the jackpot!!! 
            safeMnopTransfer(address(burnAddress), _pbal);

            //re-seed the jackpot
            doSeedParking = true;

        }

        if(bSpot.spotType == 9){
            //Moon Jackpot
            //WINNER WINNER CHICKEN DINNER!!!
            if(parkingBalance > 0){
                //send the winner the prize
                uint256 _pbal = parkingBalance;
                emit LandedParking(_player, _pbal);
                parkingBalance = 0;
                player.rewards = player.rewards.add(_pbal);
                player.jackpotWins = player.jackpotWins.add(1);
                jackpotWins = jackpotWins.add(1);
                totalRentPaidOut =  totalRentPaidOut.add(_pbal);
                //reset the parking balance
                doSeedParking = true;
            }
        }

        if(doSeedParking){
            seedParking();
        }

        player.isRolling = false;
        player.rentDue = rent;

        emit Roll(_player, player.lastRoll, player.spotId , rent, isPropOwner, block.timestamp);
    }


    /**
    * @dev See if a player has a valid card staked and has recently rolled
    */
    function _isStaked(address _account, uint256 _spotId) private view returns(bool){

        //see if they have rolled lately 
        // do we need this since it is onlycalled on doRoll? 
        if(!_playerActive(_account)){
            return false;
        }

        BoardInfo storage bSpot = boardInfo[_spotId];

        if(bSpot.nftId == 0){
            return false;
        }

        uint256[] memory stakedCards = theBroker.getCardsStakedOfAddress(_account);
        uint256 len = stakedCards.length;
        
        
        if(len <= 0){
            return false;
        }

        

        for (uint i=0; i<len; i++) {
            if(stakedCards[i] > 0 && i == bSpot.nftId){
                //check if they have rolled/active
                return true;
            } 
        }

        return false;

    }

    /* @dev set the bord spots from the constructor */ 
    function _setBoard(uint256[] memory _boardTypes, uint256[] memory _boardRent, uint256[] memory _nftIds) private {
        totalSpaces = _boardTypes.length;
        for (uint i=0; i<totalSpaces; i++) {
            BoardInfo storage bSpot = boardInfo[i];
            bSpot.spotType = _boardTypes[i];
            bSpot.rent = _boardRent[i];
            bSpot.nftId = _nftIds[i];
            //bSpot.balance = 0;
        }

        //seedParking();
    }

    /**
     * @dev Claim/harvest the pending rewards won while playing, not related to yield farming
    */
    function claimGameRewards() public nonReentrant {
           _claimGameRewards();
    }

    function _claimGameRewards() internal {

         PlayerInfo storage player = playerInfo[msg.sender];
            uint256 pending = player.rewards;
            require(pending > 0, "Memenopoly: No rewards to claim");
            if(pending > 0){

                emit RewardsClaimed(msg.sender, pending);
                player.rewards = 0;
                player.totalClaimed = player.totalClaimed.add(pending);
                safeMnopTransfer(msg.sender, pending);

            }
    }

    /**
    * @dev Handle paying a players rent/tax 
    */
    function payRent() public nonReentrant {

            
        bool transferSuccess = false;
         // BoardInfo storage bSpot = boardInfo[_spotId];
        PlayerInfo storage player = playerInfo[msg.sender];

        uint256 _rentDue = player.rentDue;
        uint256 mnopBal = mnop.balanceOf(msg.sender);

        require(gameActive, "Memenopoly: Game not active");
        require(_rentDue > 0, "Memenopoly: No rent is due!");
        require(mnopBal > 0, "Memenopoly: Insufficient Balance");

         //if we don't have full rent take what we can get
        if(mnopBal < _rentDue){
            _rentDue = mnopBal;
        }

        //pay the rent internally 
        player.rentDue = player.rentDue.sub(_rentDue);

        if(boardInfo[player.spotId].spotType == 3){
            //utils are community add to the moon jackpot
            parkingBalance = parkingBalance.add(_rentDue);
        } else if(boardInfo[player.spotId].spotType == 6){

           /*  )
              ) \  
             / ) (  
             \(_)/ */
            //Burn all taxes 
            safeMnopTransfer(address(burnAddress), _rentDue);
        } else {
            //pay the spot and run payouts for all the stakers
            boardInfo[player.spotId].balance = boardInfo[player.spotId].balance.add(_rentDue);
            _payOutSpot(player.spotId);
            
        }

        //keep track of the total paid stats
        totalRentPaid = totalRentPaid.add(_rentDue);
        player.totalRentPaid = player.totalRentPaid.add(_rentDue);
        boardInfo[player.spotId].totalPaid = boardInfo[player.spotId].totalPaid.add(_rentDue);

        transferSuccess = mnop.transferFrom(address(msg.sender),address(this),_rentDue);
        require(transferSuccess, "Memenopoly: pay rent transfer failed");

            
    }


    /**
     * @dev Pays out all the stakers of this spot and resets its balance.
     *
     * Emits a {SpotPaid} 
     *
     * Payouts are distributed like so:
     * 10% - burned forever
     * 10% - sent to the parking jackpot
     * 5% - sent to dev address
     * 75% - split evenly between all stakers (active or not)
     * - To be eligible to receive the payout the player must have the card staked and rolled in the last day
     * - Any staked share that is not eligible will be burned
     * 
     *
     * Requirements
     *
     * - `_spotId` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
    */
    function _payOutSpot(uint256 _spotId) internal {
    //get all the addresses that have this card staked
    //total up the stakers
        require(_spotId.add(1) <= totalSpaces, "Memenopoly: Invalid Spot");
        require(boardInfo[_spotId].balance > 0, "Memenopoly: No balance to pay out");

        address[] memory stakers = theBroker.getStakersOfCard(boardInfo[_spotId].nftId);
        uint256 amtStaking = stakers.length;
        uint256 totalToDistribute = boardInfo[_spotId].balance;
        uint256 origBal = totalToDistribute;

        //10% to burn
        uint256 toBurn = totalToDistribute.mul(10).div(100);

        //10% to parking
        uint256 toParking = totalToDistribute.mul(10).div(100);

        //5% to dev
        uint256 toDev = totalToDistribute.mul(5).div(100);

        totalToDistribute = totalToDistribute.sub(toBurn).sub(toParking).sub(toDev);
        
        //clear the spot balance
        boardInfo[_spotId].balance = 0;
        uint256 share = totalToDistribute;

        if(amtStaking > 0){
            share = totalToDistribute.div(amtStaking);
            
            for (uint i=0; i<amtStaking; i++) {

               if(_playerActive(stakers[i])){
                   totalRentPaidOut = totalRentPaidOut.add(share);
                   playerInfo[stakers[i]].rewards = playerInfo[stakers[i]].rewards.add(share);
                   totalToDistribute = totalToDistribute.sub(share);
               }
            }
        }

        //if there is anything left over 
        if(totalToDistribute > 0){

           /*  )
              ) \  
             / ) (  
             \(_)/ */
            //burn m-fer... burn
            toBurn = toBurn.add(totalToDistribute);
            // safeMnopTransfer(address(burnAddress), totalToDistribute);
        }

        parkingBalance = parkingBalance.add(toParking);
       /*  )
          ) \  
         / ) (  
         \(_)/ */
        //burn it!
        safeMnopTransfer(address(burnAddress), toBurn);
        safeMnopTransfer(devaddr,toDev);

        emit SpotPaid(_spotId, origBal, share, totalToDistribute, toParking, toBurn, toDev, stakers);
    }
     
    /**
    * @dev reset the parking jackpot
    */
    function seedParking() private {
         //seed the parking
        parkingBalance = defaultParking;
        mnop.mint(address(this), defaultParking);
    }

    /**
    * @dev Add to the parking jackpot used for promos or for any generous soul to give back
    */
    function addParking(uint256 _amount) public nonReentrant {
             // manually add to the parking jackpot
            require(_amount > 0, "Memenopoly: Amount must not be Zero");

            bool transferSuccess = false;

            uint256 mnopBal = mnop.balanceOf(msg.sender);

            require(mnopBal >= _amount, "Memenopoly: Insufficient Balance");

            parkingBalance = parkingBalance.add(_amount);

            transferSuccess = mnop.transferFrom(address(msg.sender),address(this),_amount);
            require(transferSuccess, "Memenopoly: pay rent transfer failed");

    }

    /**
    * @dev Update the details on a space
    */
    function updateSpot(
        uint256 _spotId, 
        uint256 _spotType, 
        uint256 _rent,
        uint256 _nftId,
        bool _clearBalance) public onlyOwner {

            boardInfo[_spotId].spotType = _spotType;
            boardInfo[_spotId].rent = _rent;
            boardInfo[_spotId].nftId = _nftId;

            /* in case we need to reset the game */
            if(_clearBalance){
                boardInfo[_spotId].balance = 0;
            }
            emit SpotUpdated(_spotId, _spotType, _rent, _nftId, _clearBalance);
    }

    function randomizeSeed() private returns (uint) {
        uint randomnumber = uint(keccak256(abi.encodePacked(now, msg.sender, nonce))) % 11111;
        randomnumber = randomnumber + 2;
        nonce++;        
        return randomnumber;
    }

    function canRoll(address _account) external view returns(bool){

        if(!gameActive){
            return false;
        }
        
        //see if they are already rolling
        if(playerInfo[_account].isRolling ){
            return false;
        }

        //check if they have rent
        if(playerInfo[_account].rentDue > 0){
            return false;
        }

        //check the timer
        if(block.timestamp >= playerInfo[_account].lastRollTime.add(rollTimeLimit)){
            return true;
        }
        return false;
    }

    function playerActive(address _account) external view returns(bool){
        return _playerActive(_account);
    }

    function _playerActive(address _account) internal view returns(bool){
        if(block.timestamp <= playerInfo[_account].lastRollTime.add(activeTimeLimit)){
            return true;
        }
        return false;
    }

    // Safe mnop transfer function, just in case if rounding error causes pool to not have enough MNOPs.
    function safeMnopTransfer(address _to, uint256 _amount) internal {
        uint256 mnopBal = mnop.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > mnopBal) {
            transferSuccess = mnop.transfer(_to, mnopBal);
        } else {
            transferSuccess = mnop.transfer(_to, _amount);
        }
        require(transferSuccess, "safeMnopTransfer: transfer failed");
    }

    /**
    * @dev Set the game active 
    */
    function setGameActive(bool _isActive) public onlyOwner {
        gameActive = _isActive;
        emit SetGameActive(_isActive);
    }

     /**
    * @dev Update the amount to seed the parking jackpot
    */
    function setDefaultParking(uint256 _amount) public onlyOwner {
        defaultParking = _amount;
        emit SetDefaultParking(_amount);
    }

    /**
     * @dev Update the amount paid out on chest spots
     */
    function setChestReward(uint256 _amount) public onlyOwner {
      chestReward = _amount;
      emit SetChestReward(_amount);
    }

   /**
    * @dev Update the amount paid out when landing on go
    */
    function setPayDayReward(uint256 _amount) public onlyOwner {
      payDayReward = _amount;
      emit SetPayDayReward(_amount);
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
        emit SetDevAddress(msg.sender, _devaddr);
    }

     /**
     * @dev Update TheBroker address.
     */
    function updateTheBrokerAddress(TheBroker _theBrokerAddress) public onlyOwner{
        theBroker = _theBrokerAddress;
        emit UpdateBrokerAddress(msg.sender, _theBrokerAddress);
    }

     /**
     * @dev Set the roll timer (seconds between rolls)
     */
    function updateRollTimeLimit(uint256 _rollTimeLimit) public onlyOwner{
        rollTimeLimit = _rollTimeLimit;
        emit UpdateRollTimeLimit(msg.sender, _rollTimeLimit);
    }

     /**
     * @dev Set the time limit a player is no longer active (seconds since last roll)
     */
    function updateActiveTimeLimit(uint256 _activeTimeLimit) public onlyOwner{
        activeTimeLimit = _activeTimeLimit;
        emit UpdateActiveTimeLimit(msg.sender, _activeTimeLimit);
    }

    /**
     * @dev Set the max level
     */
    function updateMaxLevel(uint256 _maxLevel) public onlyOwner{
        maxLevel = _maxLevel;
        emit UpdateMaxLevel(msg.sender, _maxLevel);
    }

    /**
     * @dev transfer LINK out of the contract
     */
    function withdrawLink(uint256 _amount) public onlyOwner {
        require(LINK.transfer(msg.sender, _amount), "Unable to transfer");
    }

    /**
     * @dev update the link fee amount
     */
    function setLinkFee(uint256 _linkFee) public onlyOwner {
        linkFee = _linkFee;
        emit SetLinkFee(msg.sender, _linkFee);
    }

}


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/MnopCard.sol
pragma solidity >=0.5.0 <0.6.13;
//pragma solidity ^0.5.11;

import "./libs/ERC1155/ERC1155Tradable.sol";

/**
 * @title Memenopoly Card NFT 
 */
contract MnopCard is ERC1155Tradable {
    string private _contractURI;

    constructor(address _proxyRegistryAddress) public ERC1155Tradable("Memenopoly Cards", "MnopCard", _proxyRegistryAddress) {
        _setBaseMetadataURI("https://api.mnop.finance/cards/");
        _contractURI = "https://api.mnop.finance/contract/cards-erc1155";
    }

    function setBaseMetadataURI(string memory newURI) public override onlyWhitelistAdmin {
        _setBaseMetadataURI(newURI);
    }

    function setContractURI(string memory newURI) public onlyWhitelistAdmin {
        _contractURI = newURI;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    /**
         * @dev Ends minting of token
         * @param _id          Token ID for which minting will end
         */
    function endMinting(uint256 _id) external onlyWhitelistAdmin {
        tokenMaxSupply[_id] = tokenSupply[_id];
    }

    function burn(address _account, uint256 _id, uint256 _amount) public onlyMinter {
        require(balanceOf(_account, _id) >= _amount, "cannot burn more than address has");
        _burn(_account, _id, _amount);
    }

    /**
    * Mint NFT and send those to the list of given addresses
    */
    function airdrop(uint256 _id, address[] memory _addresses) public onlyMinter {
        require(tokenMaxSupply[_id] - tokenSupply[_id] >= _addresses.length, "cannot mint above max supply");
        for (uint256 i = 0; i < _addresses.length; i++) {
            mint(_addresses[i], _id, 1, "");
        }
    }
}

/*
Constructor Argument To Add During Deployment
OpenSea Registry Address
000000000000000000000000a5409ec958c83c3f309868babaca7c86dcb077c1

0xa5409ec958c83c3f309868babaca7c86dcb077c1
*/


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/TheBroker.sol
pragma solidity >=0.5.0 <0.6.13;
// pragma solidity  >=0.5.0 <0.6.0;

// import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
// import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MnopCard.sol";
import "./MNOPToken.sol";
import "./Memenopoly.sol";
// import "./MnopBooster.sol";

/**
 * @dev Contract for handling the NFT staking and set creation.
 */
contract TheBroker is Ownable {
    using SafeMath for uint256;

    struct CardSet {
        uint256[] cardIds;
        uint256 mnopPerDayPerCard;      //reward per day per card
        uint256 bonusMnopMultiplier;    // bonus for a full set 100% bonus = 1e5
        bool isRemoved;
    }

    ERC1155Tradable public mnopCard;
    MNOPToken public mnop;
    Memenopoly public memenopoly;

    //if true stake, unstake and harvest will require the address has rolled in the last 24 hours in the memenopoly contract
    bool public checkRoll;

    //dev address 
    address public treasuryAddr;

    uint256[] public cardSetList;

	//Highest CardId added to the museum
    uint256 public highestCardId;

	//SetId mapped to all card IDs in the set.
    mapping (uint256 => CardSet) public cardSets;

	//CardId to SetId mapping
    mapping (uint256 => uint256) public cardToSetMap;

    //toal staked for each cardId
    mapping (uint256 => uint256) public totalStaked;

	//user's cards staked mapped to the cardID with the value of the idx of stakedCards
    mapping (address => mapping(uint256 => uint256)) public userCards;

    //Status of cards staked mapped to the user addresses
    mapping (uint256 => mapping(uint256 => address)) public stakedCards;

	//Last update time for a user's MNOP rewards calculation
    mapping (address => uint256) public userLastUpdate;

    event Stake(address indexed user, uint256[] cardIds);
    event Unstake(address indexed user, uint256[] cardIds);
    event Harvest(address indexed user, uint256 amount);
//    event SetCardContract(address indexed user, ERC1155Tradable mnopCard);
//    event SetMnopTokenContract(address indexed user, MNOPToken mnopToken);


    constructor(ERC1155Tradable _mnopCardAddr, MNOPToken _mnopAddr, Memenopoly _memenopolyAddr, address _treasuryAddr) public { //, MnopBooster _mnopBoosterAddr
        mnopCard = _mnopCardAddr;
        mnop = _mnopAddr;
        treasuryAddr = _treasuryAddr;
        memenopoly = _memenopolyAddr;
        checkRoll = false;
    }

	/**
     * @dev Utility function to check if a value is inside an array
     */
    function _isInArray(uint256 _value, uint256[] memory _array) internal pure returns(bool) {
        uint256 length = _array.length;
        for (uint256 i = 0; i < length; ++i) {
            if (_array[i] == _value) {
                return true;
            }
        }
        return false;
    }

	/**
     * @dev Indexed boolean for whether a card is staked or not. Index represents the cardId.
     */
    function getCardsStakedOfAddress(address _user) public view returns(uint256[] memory) {
        uint256[] memory cardsStaked = new uint256[](highestCardId + 1);
        for (uint256 i = 0; i < highestCardId + 1; ++i) {			
            cardsStaked[i] = userCards[_user][i];
        }
        return cardsStaked;
    }
    
	/**
     * @dev Returns the list of cardIds which are part of a set
     */
    function getCardIdListOfSet(uint256 _setId) external view returns(uint256[] memory) {
        return cardSets[_setId].cardIds;
    }
    

    /**
     * @dev returns all the addresses that have a cardId staked
     */
    function getStakersOfCard(uint256 _cardId) external view returns(address[] memory) {
        address[] memory cardStakers = new address[](totalStaked[_cardId]);
        for (uint256 i = 0; i < totalStaked[_cardId]; ++i) {
            if(stakedCards[_cardId][i] != address(0)){
                cardStakers[i] = stakedCards[_cardId][i];
            }
        }
        return cardStakers;
    }
   
	
	/**
     * @dev Indexed  boolean of each setId for which a user has a full set or not.
     */
    function getFullSetsOfAddress(address _user) public view returns(bool[] memory) {
        uint256 length = cardSetList.length;
        bool[] memory isFullSet = new bool[](length);
        for (uint256 i = 0; i < length; ++i) {
            uint256 setId = cardSetList[i];
            if (cardSets[setId].isRemoved) {
                isFullSet[i] = false;
                continue;
            }
            bool _fullSet = true;
            uint256[] memory _cardIds = cardSets[setId].cardIds;
			
            for (uint256 j = 0; j < _cardIds.length; ++j) {
                if (userCards[_user][_cardIds[j]] == 0) {
                    _fullSet = false;
                    break;
                }
            }
            isFullSet[i] = _fullSet;
        }
        return isFullSet;
    }

	/**
     * @dev Returns the amount of NFTs staked by an address for a given set
     */
    function getNumOfNftsStakedForSet(address _user, uint256 _setId) public view returns(uint256) {
        uint256 nbStaked = 0;
        if (cardSets[_setId].isRemoved) return 0;
        uint256 length = cardSets[_setId].cardIds.length;
        for (uint256 j = 0; j < length; ++j) {
            uint256 cardId = cardSets[_setId].cardIds[j];
            if (userCards[_user][cardId] > 0) {
                nbStaked = nbStaked.add(1);
            }
        }
        return nbStaked;
    }

	/**
     * @dev Returns the total amount of NFTs staked by an address across all sets
     */
    function getNumOfNftsStakedByAddress(address _user) public view returns(uint256) {
        uint256 nbStaked = 0;
        for (uint256 i = 0; i < cardSetList.length; ++i) {
            nbStaked = nbStaked.add(getNumOfNftsStakedForSet(_user, cardSetList[i]));
        }
        return nbStaked;
    }
    
	/**
     * @dev Returns the total mnop pending for a given address. Can include the bonus from MnopBooster,
	 * if second param is set to true.
     */
    function totalPendingMnopOfAddress(address _user) public view returns (uint256) {
        uint256 totalMnopPerDay = 0;
        uint256 length = cardSetList.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 setId = cardSetList[i];
            CardSet storage set = cardSets[setId];
            if (set.isRemoved) continue;
            uint256 cardLength = set.cardIds.length;
            bool isFullSet = true;
            uint256 setMnopPerDay = 0;
            for (uint256 j = 0; j < cardLength; ++j) {
                if (userCards[_user][set.cardIds[j]] == 0) {
                    isFullSet = false;
                    continue;
                }
                setMnopPerDay = setMnopPerDay.add(set.mnopPerDayPerCard);
            }
            if (isFullSet) {
                setMnopPerDay = setMnopPerDay.mul(set.bonusMnopMultiplier).div(1e5);
            }
            totalMnopPerDay = totalMnopPerDay.add(setMnopPerDay);
        }

        uint256 lastUpdate = userLastUpdate[_user];
        uint256 blockTime = block.timestamp;
        return blockTime.sub(lastUpdate).mul(totalMnopPerDay.div(86400));
    }

	/**
     * @dev Manually sets the highestCardId, if it goes out of sync.
	 * Required calculate the range for iterating the list of staked cards for an address.
     */
    function setHighestCardId(uint256 _highestId) public onlyOwner {
        require(_highestId > 0, "Set if minimum 1 card is staked.");
        highestCardId = _highestId;
    }

	/**
     * @dev Adds a card set with the input param configs. Removes an existing set if the id exists.
     */
     // bool _isBooster,
     // uint256 _bonusFullSetBoost
     // uint256[] memory _poolBoosts, 
    function addCardSet(
        uint256 _setId, 
        uint256[] memory _cardIds, 
        uint256 _bonusMnopMultiplier, 
        uint256 _mnopPerDayPerCard
        
        ) public onlyOwner {
            removeCardSet(_setId);
            uint256 length = _cardIds.length;
            for (uint256 i = 0; i < length; ++i) {
                uint256 cardId = _cardIds[i];
                if (cardId > highestCardId) {
                    highestCardId = cardId;
                }
                // Check all cards to assign arent already part of another set
                require(cardToSetMap[cardId] == 0, "Card already assigned to a set");
                // Assign to set
                cardToSetMap[cardId] = _setId;
            }
            if (_isInArray(_setId, cardSetList) == false) {
                cardSetList.push(_setId);
            }
            cardSets[_setId] = CardSet({
                cardIds: _cardIds,
                bonusMnopMultiplier: _bonusMnopMultiplier,
                mnopPerDayPerCard: _mnopPerDayPerCard,
                isRemoved: false
            });
    }

	/**
     * @dev Updates the mnopPerDayPerCard for a card set.
     */
    function setMnopRateOfSets(uint256[] memory _setIds, uint256[] memory _mnopPerDayPerCard) public onlyOwner {
        require(_setIds.length == _mnopPerDayPerCard.length, "_setId and _mnopPerDayPerCard have different length");
        for (uint256 i = 0; i < _setIds.length; ++i) {
            require(cardSets[_setIds[i]].cardIds.length > 0, "Set is empty");
            cardSets[_setIds[i]].mnopPerDayPerCard = _mnopPerDayPerCard[i];
        }
    }

	/**
     * @dev Set the bonusMnopMultiplier value for a list of Card sets
     */
    function setBonusMnopMultiplierOfSets(uint256[] memory _setIds, uint256[] memory _bonusMnopMultiplier) public onlyOwner {
        require(_setIds.length == _bonusMnopMultiplier.length, "_setId and _mnopPerDayPerCard have different length");
        for (uint256 i = 0; i < _setIds.length; ++i) {
            require(cardSets[_setIds[i]].cardIds.length > 0, "Set is empty");
            cardSets[_setIds[i]].bonusMnopMultiplier = _bonusMnopMultiplier[i];
        }
    }

	/**
     * @dev Remove a cardSet that has been added.
     */
    function removeCardSet(uint256 _setId) public onlyOwner {
        uint256 length = cardSets[_setId].cardIds.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 cardId = cardSets[_setId].cardIds[i];
            cardToSetMap[cardId] = 0;
        }
        delete cardSets[_setId].cardIds;
        cardSets[_setId].isRemoved = true;
    }

	/**
     * @dev Harvests the accumulated MNOP in the contract, for the caller.
     */
    function harvest() public {
        require(!checkRoll || memenopoly.playerActive(msg.sender) ,"You must take a roll to harvest");
        uint256 pendingMnop = totalPendingMnopOfAddress(msg.sender);
        userLastUpdate[msg.sender] = block.timestamp;
        if (pendingMnop > 0) {
            mnop.mint(treasuryAddr, pendingMnop.div(40)); // 2.5% MNOP for the dev 
            mnop.mint(msg.sender, pendingMnop);
            mnop.addClaimed(pendingMnop);
        }
        emit Harvest(msg.sender, pendingMnop);
    }

	/**
     * @dev Stakes the cards on providing the card IDs. 
     */
    function stake(uint256[] memory _cardIds) public {
        require(_cardIds.length > 0, "you need to stake something");

        require(!checkRoll || memenopoly.playerActive(msg.sender) ,"You must take a roll to stake");
        // Check no card will end up above max stake and if it is needed to update the user NFT pool
        uint256 length = _cardIds.length;
        bool onlyBoosters = true;
        bool onlyNoBoosters = true;
        for (uint256 i = 0; i < length; ++i) {
            uint256 cardId = _cardIds[i];
            require(userCards[msg.sender][cardId] == 0, "item already staked");
            require(cardToSetMap[cardId] != 0, "you can't stake that");
            if (cardSets[cardToSetMap[cardId]].mnopPerDayPerCard > 0) onlyBoosters = false;
        }

        // Harvest NFT pool if the Mnop/day will be modified
        if (onlyBoosters == false) harvest();
        
        //Stake 1 unit of each cardId
        uint256[] memory amounts = new uint256[](_cardIds.length);
        for (uint256 i = 0; i < _cardIds.length; ++i) {
            amounts[i] = 1;
        }
        mnopCard.safeBatchTransferFrom(msg.sender, address(this), _cardIds, amounts, "");
		//Update the staked status for the card ID.
        for (uint256 i = 0; i < length; ++i) {
            uint256 cardId = _cardIds[i];
            userCards[msg.sender][cardId] = totalStaked[cardId].add(1); 
            stakedCards[cardId][totalStaked[cardId]] = msg.sender;
            totalStaked[cardId] = totalStaked[cardId].add(1);
        }
        emit Stake(msg.sender, _cardIds);
    }

	/**
     * @dev Unstakes the cards on providing the card IDs. 
     */
    function unstake(uint256[] memory _cardIds) public {
 
         require(_cardIds.length > 0, "input at least 1 card id");
         require(!checkRoll || memenopoly.playerActive(msg.sender) ,"You must take a roll to unstake");

        // Check if all cards are staked and if it is needed to update the user NFT pool
        uint256 length = _cardIds.length;
        bool onlyBoosters = true;
        bool onlyNoBoosters = true;
        for (uint256 i = 0; i < length; ++i) {
            uint256 cardId = _cardIds[i];
            require(userCards[msg.sender][cardId] > 0, "Card not staked");
            delete stakedCards[cardId][userCards[msg.sender][cardId]];
            userCards[msg.sender][cardId] = 0;
            
            totalStaked[cardId] = totalStaked[cardId].sub(1);
            if (cardSets[cardToSetMap[cardId]].mnopPerDayPerCard > 0) onlyBoosters = false;
        }
        
        if (onlyBoosters == false) harvest();


        //UnStake 1 unit of each cardId
        uint256[] memory amounts = new uint256[](_cardIds.length);
        for (uint256 i = 0; i < _cardIds.length; ++i) {
            amounts[i] = 1;
        }
        mnopCard.safeBatchTransferFrom(address(this), msg.sender, _cardIds, amounts, "");
        emit Unstake(msg.sender, _cardIds);
    }

	/**
     * @dev Emergency unstake the cards on providing the card IDs, forfeiting the MNOP rewards 
     */
    function emergencyUnstake(uint256[] memory _cardIds) public {
        userLastUpdate[msg.sender] = block.timestamp;
        uint256 length = _cardIds.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 cardId = _cardIds[i];
            require(userCards[msg.sender][cardId] > 0, "Card not staked");
            delete stakedCards[cardId][userCards[msg.sender][cardId]];
            userCards[msg.sender][cardId] = 0;
        }

        //UnStake 1 unit of each cardId
        uint256[] memory amounts = new uint256[](_cardIds.length);
        for (uint256 i = 0; i < _cardIds.length; ++i) {
            amounts[i] = 1;
        }
        mnopCard.safeBatchTransferFrom(address(this), msg.sender, _cardIds, amounts, "");
    }
    
	
    /**
     * @dev Update the Mnop token address only callable by the owner
     */
//	function setMnopTokenContract(MNOPToken _mnopAddr) public onlyOwner {
//        mnop = _mnopAddr;
//        emit SetMnopTokenContract(msg.sender, _mnopAddr);
//    }

    /**
     * @dev Update the card NFT contract address only callable by the owner
     */
//    function setCardContract(ERC1155Tradable _mnopCard) public onlyOwner {
//        mnopCard = _mnopCard;
//        emit SetCardContract(msg.sender, _mnopCard);
//    }

    /**
     * @dev Update the checkRoll flag, if true the address must have rolled in the last 24 hours
     */
    function setCheckRoll(bool _checkRoll) public onlyOwner{
        checkRoll = _checkRoll;
    }

    /**
     * @dev Update treasury address by the previous treasury.
     */
    function treasury(address _treasuryAddr) public {
        require(msg.sender == treasuryAddr, "Only current treasury address can update.");
        treasuryAddr = _treasuryAddr;
    }

    /**
     * @notice Handle the receipt of a single ERC1155 token type
     * @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeTransferFrom` after the balance has been updated
     * This function MAY throw to revert and reject the transfer
     * Return of other amount than the magic value MUST result in the transaction being reverted
     * Note: The token contract address is always the message sender
     * @param _operator  The address which called the `safeTransferFrom` function
     * @param _from      The address which previously owned the token
     * @param _id        The id of the token being transferred
     * @param _amount    The amount of tokens being transferred
     * @param _data      Additional data with no specified format
     * @return           `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     */
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _amount, bytes calldata _data) external returns(bytes4) {
        return 0xf23a6e61;
    }

    /**
     * @notice Handle the receipt of multiple ERC1155 token types
     * @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeBatchTransferFrom` after the balances have been updated
     * This function MAY throw to revert and reject the transfer
     * Return of other amount than the magic value WILL result in the transaction being reverted
     * Note: The token contract address is always the message sender
     * @param _operator  The address which called the `safeBatchTransferFrom` function
     * @param _from      The address which previously owned the token
     * @param _ids       An array containing ids of each token being transferred
     * @param _amounts   An array containing amounts of each token being transferred
     * @param _data      Additional data with no specified format
     * @return           `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data) external returns(bytes4) {
        return 0xbc197c81;
    }

    /**
     * @notice Indicates whether a contract implements the `ERC1155TokenReceiver` functions and so can accept ERC1155 token types.
     * @param  interfaceID The ERC-165 interface ID that is queried for support.s
     * @dev This function MUST return true if it implements the ERC1155TokenReceiver interface and ERC-165 interface.
     *      This function MUST NOT consume more than 5,000 gas.
     * @return Wheter ERC-165 or ERC1155TokenReceiver interfaces are supported.
     */
    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return  interfaceID == 0x01ffc9a7 ||    // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
        interfaceID == 0x4e2312e0;      // ERC-1155 `ERC1155TokenReceiver` support (i.e. `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")) ^ bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`).
    }
}


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/BEP20.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/GSN/Context.sol';
import './IBEP20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

/**
 * @dev Implementation of the {IBEP20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {BEP20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of BEP20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IBEP20-approve}.
 */
contract BEP20 is Context, IBEP20, Ownable {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external override view returns (address) {
        return owner();
    }


    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {BEP20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IBEP20-balanceOf} and {IBEP20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IBEP20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IBEP20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IBEP20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IBEP20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IBEP20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IBEP20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {BEP20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IBEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IBEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "BEP20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "BEP20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/BEP20Pausable.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./BEP20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./CanTransferRole.sol";
/**
 * @dev ERC20 token with pausable token transfers, minting and burning.
 *
 * Useful for scenarios such as preventing trades until the end of an evaluation
 * period, or having an emergency switch for freezing all token transfers in the
 * event of a large bug.
 */
abstract contract BEP20Pausable is BEP20('Memenopoly Money', 'MNOP'), CanTransferRole, Pausable {
    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused() || canTransfer(msg.sender), "ERC20Pausable: token transfer while paused");
    }
} 


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/CanTransferRole.sol
pragma solidity >=0.5.0 <0.6.13;

import "@openzeppelin/contracts/GSN/Context.sol";
import "./Roles.sol";

contract CanTransferRole is Context {
    using Roles for Roles.Role;

    event CanTransferAdded(address indexed account);
    event CanTransferRemoved(address indexed account);

    Roles.Role private _canTransfer;

    constructor () internal {
        _addCanTransfer(_msgSender());
    }

    modifier onlyCanTransfer() {
        require(canTransfer(_msgSender()), "cant: smol caller is not beeg");
        _;
    }

    function canTransfer(address account) public view returns (bool) {
        return _canTransfer.has(account);
    }

    function addCanTransfer(address account) public onlyCanTransfer {
        _addCanTransfer(account);
    }

    function renounceCanTransfer() public {
        _removeCanTransfer(_msgSender());
    }

    function _addCanTransfer(address account) internal {
        _canTransfer.add(account);
        emit CanTransferAdded(account);
    }

    function _removeCanTransfer(address account) internal {
        _canTransfer.remove(account);
        emit CanTransferRemoved(account);
    }
}

// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/ERC1155/ERC1155.sol
pragma solidity >=0.5.0 <0.6.13;

import "../interfaces/IERC165.sol";
import "../interfaces/IERC1155TokenReceiver.sol";
import "../interfaces/IERC1155.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";



/**
 * @dev Implementation of Multi-Token Standard contract
 */
contract ERC1155 is IERC165 {
  using SafeMath for uint256;
  using Address for address;


  /***********************************|
  |        Variables and Events       |
  |__________________________________*/

  // onReceive function signatures
  bytes4 constant internal ERC1155_RECEIVED_VALUE = 0xf23a6e61;
  bytes4 constant internal ERC1155_BATCH_RECEIVED_VALUE = 0xbc197c81;

  // Objects balances
  mapping (address => mapping(uint256 => uint256)) internal balances;

  // Operator Functions
  mapping (address => mapping(address => bool)) internal operators;

  // Events
  event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _amount);
  event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _amounts);
  event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
  event URI(string _uri, uint256 indexed _id);


  /***********************************|
  |     Public Transfer Functions     |
  |__________________________________*/


  function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount, bytes memory _data)
    public
  {
    require((msg.sender == _from) || isApprovedForAll(_from, msg.sender), "ERC1155#safeTransferFrom: INVALID_OPERATOR");
    require(_to != address(0),"ERC1155#safeTransferFrom: INVALID_RECIPIENT");
    // require(_amount >= balances[_from][_id]) is not necessary since checked with safemath operations

    _safeTransferFrom(_from, _to, _id, _amount);
    _callonERC1155Received(_from, _to, _id, _amount, _data);
  }


  function safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data)
    public
  {
    // Requirements
    require((msg.sender == _from) || isApprovedForAll(_from, msg.sender), "ERC1155#safeBatchTransferFrom: INVALID_OPERATOR");
    require(_to != address(0), "ERC1155#safeBatchTransferFrom: INVALID_RECIPIENT");

    _safeBatchTransferFrom(_from, _to, _ids, _amounts);
    _callonERC1155BatchReceived(_from, _to, _ids, _amounts, _data);
  }


  /***********************************|
  |    Internal Transfer Functions    |
  |__________________________________*/


  function _safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount)
    internal
  {
    // Update balances
    balances[_from][_id] = balances[_from][_id].sub(_amount); // Subtract amount
    balances[_to][_id] = balances[_to][_id].add(_amount);     // Add amount

    // Emit event
    emit TransferSingle(msg.sender, _from, _to, _id, _amount);
  }

  /**
   * @dev Verifies if receiver is contract and if so, calls (_to).onERC1155Received(...)
   */
  function _callonERC1155Received(address _from, address _to, uint256 _id, uint256 _amount, bytes memory _data)
    internal
  {
    // Check if recipient is contract
    if (_to.isContract()) {
      bytes4 retval = IERC1155TokenReceiver(_to).onERC1155Received(msg.sender, _from, _id, _amount, _data);
      require(retval == ERC1155_RECEIVED_VALUE, "ERC1155#_callonERC1155Received: INVALID_ON_RECEIVE_MESSAGE");
    }
  }

  /**
   * @dev Send multiple types of Tokens from the _from address to the _to address (with safety call)
   * @dev _from     Source addresses
   * @dev _to       Target addresses
   * @dev _ids      IDs of each token type
   * @dev _amounts  Transfer amounts per token type
   */
  function _safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts)
    internal
  {
    require(_ids.length == _amounts.length, "ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH");

    // Number of transfer to execute
    uint256 nTransfer = _ids.length;

    // Executing all transfers
    for (uint256 i = 0; i < nTransfer; i++) {
      // Update storage balance of previous bin
      balances[_from][_ids[i]] = balances[_from][_ids[i]].sub(_amounts[i]);
      balances[_to][_ids[i]] = balances[_to][_ids[i]].add(_amounts[i]);
    }

    // Emit event
    emit TransferBatch(msg.sender, _from, _to, _ids, _amounts);
  }

  /**
   * @dev Verifies if receiver is contract and if so, calls (_to).onERC1155BatchReceived(...)
   */
  function _callonERC1155BatchReceived(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data)
    internal
  {
    // Pass data if recipient is contract
    if (_to.isContract()) {
      bytes4 retval = IERC1155TokenReceiver(_to).onERC1155BatchReceived(msg.sender, _from, _ids, _amounts, _data);
      require(retval == ERC1155_BATCH_RECEIVED_VALUE, "ERC1155#_callonERC1155BatchReceived: INVALID_ON_RECEIVE_MESSAGE");
    }
  }


  /***********************************|
  |         Operator Functions        |
  |__________________________________*/

  function setApprovalForAll(address _operator, bool _approved)
    external
  {
    // Update operator status
    operators[msg.sender][_operator] = _approved;
    emit ApprovalForAll(msg.sender, _operator, _approved);
  }


  function isApprovedForAll(address _owner, address _operator)
    public virtual view returns (bool isOperator)
  {
    return operators[_owner][_operator];
  }


  /***********************************|
  |         Balance Functions         |
  |__________________________________*/


  function balanceOf(address _owner, uint256 _id)
    public view returns (uint256)
  {
    return balances[_owner][_id];
  }


  function balanceOfBatch(address[] memory _owners, uint256[] memory _ids)
    public view returns (uint256[] memory)
  {
    require(_owners.length == _ids.length, "ERC1155#balanceOfBatch: INVALID_ARRAY_LENGTH");

    // Variables
    uint256[] memory batchBalances = new uint256[](_owners.length);

    // Iterate over each owner and token ID
    for (uint256 i = 0; i < _owners.length; i++) {
      batchBalances[i] = balances[_owners[i]][_ids[i]];
    }

    return batchBalances;
  }


  /***********************************|
  |          ERC165 Functions         |
  |__________________________________*/

  /**
   * INTERFACE_SIGNATURE_ERC165 = bytes4(keccak256("supportsInterface(bytes4)"));
   */
  bytes4 constant private INTERFACE_SIGNATURE_ERC165 = 0x01ffc9a7;

  /**
   * INTERFACE_SIGNATURE_ERC1155 =
   * bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)")) ^
   * bytes4(keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)")) ^
   * bytes4(keccak256("balanceOf(address,uint256)")) ^
   * bytes4(keccak256("balanceOfBatch(address[],uint256[])")) ^
   * bytes4(keccak256("setApprovalForAll(address,bool)")) ^
   * bytes4(keccak256("isApprovedForAll(address,address)"));
   */
  bytes4 constant private INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;


  function supportsInterface(bytes4 _interfaceID) external override view returns (bool) {
    if (_interfaceID == INTERFACE_SIGNATURE_ERC165 ||
        _interfaceID == INTERFACE_SIGNATURE_ERC1155) {
      return true;
    }
    return false;
  }

}


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/ERC1155/ERC1155Metadata.sol
pragma solidity >=0.5.0 <0.6.13;
import "../interfaces/IERC1155.sol";


/**
 * @notice Contract that handles metadata related methods.
 * @dev Methods assume a deterministic generation of URI based on token IDs.
 *      Methods also assume that URI uses hex representation of token IDs.
 */
contract ERC1155Metadata {

  // URI's default URI prefix
  string internal baseMetadataURI;
  event URI(string _uri, uint256 indexed _id);


  /***********************************|
  |     Metadata Public Function s    |
  |__________________________________*/

  /**
   * @notice A distinct Uniform Resource Identifier (URI) for a given token.
   * @dev URIs are defined in RFC 3986.
   *      URIs are assumed to be deterministically generated based on token ID
   *      Token IDs are assumed to be represented in their hex format in URIs
   * @return URI string
   */
  function uri(uint256 _id) public virtual view returns (string memory) {
    return string(abi.encodePacked(baseMetadataURI, _uint2str(_id), ".json"));
  }


  /***********************************|
  |    Metadata Internal Functions    |
  |__________________________________*/

  /**
   * @notice Will emit default URI log event for corresponding token _id
   * @param _tokenIDs Array of IDs of tokens to log default URI
   */
  function _logURIs(uint256[] memory _tokenIDs) internal {
    string memory baseURL = baseMetadataURI;
    string memory tokenURI;

    for (uint256 i = 0; i < _tokenIDs.length; i++) {
      tokenURI = string(abi.encodePacked(baseURL, _uint2str(_tokenIDs[i]), ".json"));
      emit URI(tokenURI, _tokenIDs[i]);
    }
  }

  /**
   * @notice Will emit a specific URI log event for corresponding token
   * @param _tokenIDs IDs of the token corresponding to the _uris logged
   * @param _URIs    The URIs of the specified _tokenIDs
   */
  function _logURIs(uint256[] memory _tokenIDs, string[] memory _URIs) internal {
    require(_tokenIDs.length == _URIs.length, "ERC1155Metadata#_logURIs: INVALID_ARRAYS_LENGTH");
    for (uint256 i = 0; i < _tokenIDs.length; i++) {
      emit URI(_URIs[i], _tokenIDs[i]);
    }
  }

  /**
   * @notice Will update the base URL of token's URI
   * @param _newBaseMetadataURI New base URL of token's URI
   */
  function _setBaseMetadataURI(string memory _newBaseMetadataURI) internal {
    baseMetadataURI = _newBaseMetadataURI;
  }


  /***********************************|
  |    Utility Internal Functions     |
  |__________________________________*/

  /**
   * @notice Convert uint256 to string
   * @param _i Unsigned integer to convert to string
   */
  function _uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
    if (_i == 0) {
      return "0";
    }

    uint256 j = _i;
    uint256 ii = _i;
    uint256 len;

    // Get number of bytes
    while (j != 0) {
      len++;
      j /= 10;
    }

    bytes memory bstr = new bytes(len);
    uint256 k = len - 1;

    // Get each individual ASCII
    while (ii != 0) {
      bstr[k--] = byte(uint8(48 + ii % 10));
      ii /= 10;
    }

    // Convert to string
    return string(bstr);
  }

}

// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/ERC1155/ERC1155MintBurn.sol
pragma solidity >=0.5.0 <0.6.13;

import "./ERC1155.sol";


/**
 * @dev Multi-Fungible Tokens with minting and burning methods. These methods assume
 *      a parent contract to be executed as they are `internal` functions
 */
contract ERC1155MintBurn is ERC1155 {


  /****************************************|
  |            Minting Functions           |
  |_______________________________________*/


  function _mint(address _to, uint256 _id, uint256 _amount, bytes memory _data)
    internal
  {
    // Add _amount
    balances[_to][_id] = balances[_to][_id].add(_amount);

    // Emit event
    emit TransferSingle(msg.sender, address(0x0), _to, _id, _amount);

    // Calling onReceive method if recipient is contract
    _callonERC1155Received(address(0x0), _to, _id, _amount, _data);
  }


  function _batchMint(address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data)
    internal
  {
    require(_ids.length == _amounts.length, "ERC1155MintBurn#batchMint: INVALID_ARRAYS_LENGTH");

    // Number of mints to execute
    uint256 nMint = _ids.length;

     // Executing all minting
    for (uint256 i = 0; i < nMint; i++) {
      // Update storage balance
      balances[_to][_ids[i]] = balances[_to][_ids[i]].add(_amounts[i]);
    }

    // Emit batch mint event
    emit TransferBatch(msg.sender, address(0x0), _to, _ids, _amounts);

    // Calling onReceive method if recipient is contract
    _callonERC1155BatchReceived(address(0x0), _to, _ids, _amounts, _data);
  }


  /****************************************|
  |            Burning Functions           |
  |_______________________________________*/


  function _burn(address _from, uint256 _id, uint256 _amount)
    internal
  {
    //Substract _amount
    balances[_from][_id] = balances[_from][_id].sub(_amount);

    // Emit event
    emit TransferSingle(msg.sender, _from, address(0x0), _id, _amount);
  }


  function _batchBurn(address _from, uint256[] memory _ids, uint256[] memory _amounts)
    internal
  {
    require(_ids.length == _amounts.length, "ERC1155MintBurn#batchBurn: INVALID_ARRAYS_LENGTH");

    // Number of mints to execute
    uint256 nBurn = _ids.length;

     // Executing all minting
    for (uint256 i = 0; i < nBurn; i++) {
      // Update storage balance
      balances[_from][_ids[i]] = balances[_from][_ids[i]].sub(_amounts[i]);
    }

    // Emit batch mint event
    emit TransferBatch(msg.sender, _from, address(0x0), _ids, _amounts);
  }

}



// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/ERC1155/ERC1155Tradable.sol
pragma solidity >=0.5.0 <0.6.13; 
// pragma solidity >=0.5.0 <0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../Strings.sol";
import './ERC1155.sol';
import './ERC1155Metadata.sol';
import './ERC1155MintBurn.sol';
import "../MinterRole.sol";
import "../WhitelistAdminRole.sol";

import '../ProxyRegistry.sol';


/**
 * @title ERC1155Tradable
 * ERC1155Tradable - ERC1155 contract that whitelists an operator address,
 * has create and mint functionality, and supports useful standards from OpenZeppelin,
  like _exists(), name(), symbol(), and totalSupply()
 */
contract ERC1155Tradable is ERC1155, ERC1155MintBurn, ERC1155Metadata, Ownable, MinterRole, WhitelistAdminRole {
    using Strings for string;

    address proxyRegistryAddress;
    uint256 private _currentTokenID = 0;
    mapping(uint256 => address) public creators;
    mapping(uint256 => uint256) public tokenSupply;
    mapping(uint256 => uint256) public tokenMaxSupply;
    // Contract name
    string public name;
    // Contract symbol
    string public symbol;

    constructor(
        string memory _name,
        string memory _symbol,
        address _proxyRegistryAddress
    ) public {
        name = _name;
        symbol = _symbol;
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    function removeWhitelistAdmin(address account) public onlyOwner {
        _removeWhitelistAdmin(account);
    }

    function removeMinter(address account) public onlyOwner {
        _removeMinter(account);
    }

    function uri(uint256 _id) public override view returns (string memory) {
        require(_exists(_id), "erc721tradable#uri: NONEXISTENT_TOKEN");
        return Strings.strConcat(baseMetadataURI, Strings.uint2str(_id));
    }


    function totalSupply(uint256 _id) public view returns (uint256) {
        return tokenSupply[_id];
    }

    function maxSupply(uint256 _id) public view returns (uint256) {
        return tokenMaxSupply[_id];
    }


    function setBaseMetadataURI(string memory _newBaseMetadataURI) public virtual onlyWhitelistAdmin {
        _setBaseMetadataURI(_newBaseMetadataURI);
    }

    function create(
        uint256 _maxSupply,
        uint256 _initialSupply,
        string calldata _uri,
        bytes calldata _data
    ) external onlyWhitelistAdmin returns (uint256 tokenId) {
        require(_initialSupply <= _maxSupply, "initial supply cannot be more than max supply");
        uint256 _id = _getNextTokenID();
        _incrementTokenTypeId();
        creators[_id] = msg.sender;

        if (bytes(_uri).length > 0) {
            emit URI(_uri, _id);
        }

        if (_initialSupply != 0) _mint(msg.sender, _id, _initialSupply, _data);
        tokenSupply[_id] = _initialSupply;
        tokenMaxSupply[_id] = _maxSupply;
        return _id;
    }


    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public onlyMinter {
        uint256 tokenId = _id;
        uint256 newSupply = tokenSupply[tokenId].add(_quantity);
        require(newSupply <= tokenMaxSupply[tokenId], "max NFT supply reached");
        _mint(_to, _id, _quantity, _data);
        tokenSupply[_id] = tokenSupply[_id].add(_quantity);
    }

    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-free listings - The Beano of NFTs
     */
    function isApprovedForAll(address _owner, address _operator) public override view returns (bool isOperator) {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(_owner)) == _operator) {
            return true;
        }

        return ERC1155.isApprovedForAll(_owner, _operator);
    }

    function _exists(uint256 _id) internal view returns (bool) {
        return creators[_id] != address(0);
    }

    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID.add(1);
    }

    function _incrementTokenTypeId() private {
        _currentTokenID++;
    }
}

// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/IBEP20.sol
pragma solidity >=0.6.4;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender) external view returns (uint256);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}

// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/MinterRole.sol
pragma solidity >=0.5.0 <0.6.13;

import "@openzeppelin/contracts/GSN/Context.sol";
import "./Roles.sol";

contract MinterRole is Context {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor () internal {
        _addMinter(_msgSender());
    }

    modifier onlyMinter() {
        require(isMinter(_msgSender()), "MinterRole: caller does not have the Minter role");
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function addMinter(address account) public onlyMinter {
        _addMinter(account);
    }

    function renounceMinter() public {
        _removeMinter(_msgSender());
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/ProxyRegistry.sol
pragma solidity >=0.5.0 <0.6.13;

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/Roles.sol
pragma solidity >=0.5.0 <0.6.13;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/SafeBEP20.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IBEP20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SafeBEP20
 * @dev Wrappers around BEP20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeBEP20 for IBEP20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeBEP20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IBEP20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IBEP20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IBEP20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IBEP20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeBEP20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IBEP20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IBEP20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeBEP20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IBEP20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeBEP20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeBEP20: BEP20 operation did not succeed");
        }
    }
}


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/Strings.sol
pragma solidity >=0.6.4;

library Strings {
  // via https://github.com/oraclize/ethereum-api/blob/master/oraclizeAPI_0.5.sol
  function strConcat(string memory _a, string memory _b, string memory _c, string memory _d, string memory _e) internal pure returns (string memory) {
      bytes memory _ba = bytes(_a);
      bytes memory _bb = bytes(_b);
      bytes memory _bc = bytes(_c);
      bytes memory _bd = bytes(_d);
      bytes memory _be = bytes(_e);
      string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
      bytes memory babcde = bytes(abcde);
      uint k = 0;
      for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
      for (uint i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
      for (uint i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
      for (uint i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
      for (uint i = 0; i < _be.length; i++) babcde[k++] = _be[i];
      return string(babcde);
    }

    function strConcat(string memory _a, string memory _b, string memory _c, string memory _d) internal pure returns (string memory) {
        return strConcat(_a, _b, _c, _d, "");
    }

    function strConcat(string memory _a, string memory _b, string memory _c) internal pure returns (string memory) {
        return strConcat(_a, _b, _c, "", "");
    }

    function strConcat(string memory _a, string memory _b) internal pure returns (string memory) {
        return strConcat(_a, _b, "", "", "");
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }
}

// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/WhitelistAdminRole.sol
pragma solidity >=0.5.0 <0.6.13;

import "@openzeppelin/contracts/GSN/Context.sol";
import "./Roles.sol";

/**
 * @title WhitelistAdminRole
 * @dev WhitelistAdmins are responsible for assigning and removing Whitelisted accounts.
 */
contract WhitelistAdminRole is Context {
    using Roles for Roles.Role;

    event WhitelistAdminAdded(address indexed account);
    event WhitelistAdminRemoved(address indexed account);

    Roles.Role private _whitelistAdmins;

    constructor () internal {
        _addWhitelistAdmin(_msgSender());
    }

    modifier onlyWhitelistAdmin() {
        require(isWhitelistAdmin(_msgSender()), "WhitelistAdminRole: caller does not have the WhitelistAdmin role");
        _;
    }

    function isWhitelistAdmin(address account) public view returns (bool) {
        return _whitelistAdmins.has(account);
    }

    function addWhitelistAdmin(address account) public onlyWhitelistAdmin {
        _addWhitelistAdmin(account);
    }

    function renounceWhitelistAdmin() public {
        _removeWhitelistAdmin(_msgSender());
    }

    function _addWhitelistAdmin(address account) internal {
        _whitelistAdmins.add(account);
        emit WhitelistAdminAdded(account);
    }

    function _removeWhitelistAdmin(address account) internal {
        _whitelistAdmins.remove(account);
        emit WhitelistAdminRemoved(account);
    }
}


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/interfaces/IERC1155.sol
pragma solidity >=0.5.0 <0.6.13; 


interface IERC1155 {
  // Events

  /**
   * @dev Either TransferSingle or TransferBatch MUST emit when tokens are transferred, including zero amount transfers as well as minting or burning
   *   Operator MUST be msg.sender
   *   When minting/creating tokens, the `_from` field MUST be set to `0x0`
   *   When burning/destroying tokens, the `_to` field MUST be set to `0x0`
   *   The total amount transferred from address 0x0 minus the total amount transferred to 0x0 may be used by clients and exchanges to be added to the "circulating supply" for a given token ID
   *   To broadcast the existence of a token ID with no initial balance, the contract SHOULD emit the TransferSingle event from `0x0` to `0x0`, with the token creator as `_operator`, and a `_amount` of 0
   */
  event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _amount);

  /**
   * @dev Either TransferSingle or TransferBatch MUST emit when tokens are transferred, including zero amount transfers as well as minting or burning
   *   Operator MUST be msg.sender
   *   When minting/creating tokens, the `_from` field MUST be set to `0x0`
   *   When burning/destroying tokens, the `_to` field MUST be set to `0x0`
   *   The total amount transferred from address 0x0 minus the total amount transferred to 0x0 may be used by clients and exchanges to be added to the "circulating supply" for a given token ID
   *   To broadcast the existence of multiple token IDs with no initial balance, this SHOULD emit the TransferBatch event from `0x0` to `0x0`, with the token creator as `_operator`, and a `_amount` of 0
   */
  event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _amounts);

  /**
   * @dev MUST emit when an approval is updated
   */
  event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

  /**
   * @dev MUST emit when the URI is updated for a token ID
   *   URIs are defined in RFC 3986
   *   The URI MUST point a JSON file that conforms to the "ERC-1155 Metadata JSON Schema"
   */
  event URI(string _amount, uint256 indexed _id);


  function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount, bytes calldata _data) external;

  function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data) external;
  

  function balanceOf(address _owner, uint256 _id) external view returns (uint256);

  function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory);


  function setApprovalForAll(address _operator, bool _approved) external;


  function isApprovedForAll(address _owner, address _operator) external view returns (bool isOperator);

}


// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/interfaces/IERC1155TokenReceiver.sol
pragma solidity >=0.5.0 <0.6.13; 

/**
 * @dev ERC-1155 interface for accepting safe transfers.
 */
interface IERC1155TokenReceiver {


  function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _amount, bytes calldata _data) external returns(bytes4);

  function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data) external returns(bytes4);

  function supportsInterface(bytes4 interfaceID) external view returns (bool);

}

// Chain: BSC - File: /Users/famousbirthdays/Sites/memenopoly-contracts/contracts/libs/interfaces/IERC165.sol
pragma solidity >=0.5.0 <0.6.13; 

/**
 * @title ERC165
 * @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md
 */
interface IERC165 {


    function supportsInterface(bytes4 _interfaceId)
    external
    view
    returns (bool);
}

// Chain: BSC - File: @chainlink/contracts/src/v0.6/VRFConsumerBase.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./vendor/SafeMathChainlink.sol";

import "./interfaces/LinkTokenInterface.sol";

import "./VRFRequestIDBase.sol";

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constuctor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator, _link) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash), and have told you the minimum LINK
 * @dev price for VRF service. Make sure your contract has sufficient LINK, and
 * @dev call requestRandomness(keyHash, fee, seed), where seed is the input you
 * @dev want to generate randomness from.
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomness method.
 *
 * @dev The randomness argument to fulfillRandomness is the actual random value
 * @dev generated from your seed.
 *
 * @dev The requestId argument is generated from the keyHash and the seed by
 * @dev makeRequestId(keyHash, seed). If your contract could have concurrent
 * @dev requests open, you can use the requestId to track which seed is
 * @dev associated with which randomness. See VRFRequestIDBase.sol for more
 * @dev details. (See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.)
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ. (Which is critical to making unpredictable randomness! See the
 * @dev next section.)
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the ultimate input to the VRF is mixed with the block hash of the
 * @dev block in which the request is made, user-provided seeds have no impact
 * @dev on its economic security properties. They are only included for API
 * @dev compatability with previous versions of this contract.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request.
 */
abstract contract VRFConsumerBase is VRFRequestIDBase {

  using SafeMathChainlink for uint256;

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBase expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomness the VRF output
   */
  function fulfillRandomness(bytes32 requestId, uint256 randomness)
    internal virtual;

  /**
   * @notice requestRandomness initiates a request for VRF output given _seed
   *
   * @dev The fulfillRandomness method receives the output, once it's provided
   * @dev by the Oracle, and verified by the vrfCoordinator.
   *
   * @dev The _keyHash must already be registered with the VRFCoordinator, and
   * @dev the _fee must exceed the fee specified during registration of the
   * @dev _keyHash.
   *
   * @dev The _seed parameter is vestigial, and is kept only for API
   * @dev compatibility with older versions. It can't *hurt* to mix in some of
   * @dev your own randomness, here, but it's not necessary because the VRF
   * @dev oracle will mix the hash of the block containing your request into the
   * @dev VRF seed it ultimately uses.
   *
   * @param _keyHash ID of public key against which randomness is generated
   * @param _fee The amount of LINK to send with the request
   * @param _seed seed mixed into the input of the VRF.
   *
   * @return requestId unique ID for this request
   *
   * @dev The returned requestId can be used to distinguish responses to
   * @dev concurrent requests. It is passed as the first argument to
   * @dev fulfillRandomness.
   */
  function requestRandomness(bytes32 _keyHash, uint256 _fee, uint256 _seed)
    internal returns (bytes32 requestId)
  {
    LINK.transferAndCall(vrfCoordinator, _fee, abi.encode(_keyHash, _seed));
    // This is the seed passed to VRFCoordinator. The oracle will mix this with
    // the hash of the block containing this request to obtain the seed/input
    // which is finally passed to the VRF cryptographic machinery.
    uint256 vRFSeed  = makeVRFInputSeed(_keyHash, _seed, address(this), nonces[_keyHash]);
    // nonces[_keyHash] must stay in sync with
    // VRFCoordinator.nonces[_keyHash][this], which was incremented by the above
    // successful LINK.transferAndCall (in VRFCoordinator.randomnessRequest).
    // This provides protection against the user repeating their input seed,
    // which would result in a predictable/duplicate output, if multiple such
    // requests appeared in the same block.
    nonces[_keyHash] = nonces[_keyHash].add(1);
    return makeRequestId(_keyHash, vRFSeed);
  }

  LinkTokenInterface immutable internal LINK;
  address immutable private vrfCoordinator;

  // Nonces for each VRF key from which randomness has been requested.
  //
  // Must stay in sync with VRFCoordinator[_keyHash][this]
  mapping(bytes32 /* keyHash */ => uint256 /* nonce */) private nonces;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   * @param _link address of LINK token contract
   *
   * @dev https://docs.chain.link/docs/link-token-contracts
   */
  constructor(address _vrfCoordinator, address _link) public {
    vrfCoordinator = _vrfCoordinator;
    LINK = LinkTokenInterface(_link);
  }

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomness(bytes32 requestId, uint256 randomness) external {
    require(msg.sender == vrfCoordinator, "Only VRFCoordinator can fulfill");
    fulfillRandomness(requestId, randomness);
  }
}


// Chain: BSC - File: @chainlink/contracts/src/v0.6/VRFRequestIDBase.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract VRFRequestIDBase {

  /**
   * @notice returns the seed which is actually input to the VRF coordinator
   *
   * @dev To prevent repetition of VRF output due to repetition of the
   * @dev user-supplied seed, that seed is combined in a hash with the
   * @dev user-specific nonce, and the address of the consuming contract. The
   * @dev risk of repetition is mostly mitigated by inclusion of a blockhash in
   * @dev the final seed, but the nonce does protect against repetition in
   * @dev requests which are included in a single block.
   *
   * @param _userSeed VRF seed input provided by user
   * @param _requester Address of the requesting contract
   * @param _nonce User-specific nonce at the time of the request
   */
  function makeVRFInputSeed(bytes32 _keyHash, uint256 _userSeed,
    address _requester, uint256 _nonce)
    internal pure returns (uint256)
  {
    return  uint256(keccak256(abi.encode(_keyHash, _userSeed, _requester, _nonce)));
  }

  /**
   * @notice Returns the id for this request
   * @param _keyHash The serviceAgreement ID to be used for this request
   * @param _vRFInputSeed The seed to be passed directly to the VRF
   * @return The id for this request
   *
   * @dev Note that _vRFInputSeed is not the seed passed by the consuming
   * @dev contract, but the one generated by makeVRFInputSeed
   */
  function makeRequestId(
    bytes32 _keyHash, uint256 _vRFInputSeed) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_keyHash, _vRFInputSeed));
  }
}


// Chain: BSC - File: @chainlink/contracts/src/v0.6/interfaces/LinkTokenInterface.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);
  function approve(address spender, uint256 value) external returns (bool success);
  function balanceOf(address owner) external view returns (uint256 balance);
  function decimals() external view returns (uint8 decimalPlaces);
  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);
  function increaseApproval(address spender, uint256 subtractedValue) external;
  function name() external view returns (string memory tokenName);
  function symbol() external view returns (string memory tokenSymbol);
  function totalSupply() external view returns (uint256 totalTokensIssued);
  function transfer(address to, uint256 value) external returns (bool success);
  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);
  function transferFrom(address from, address to, uint256 value) external returns (bool success);
}


// Chain: BSC - File: @chainlink/contracts/src/v0.6/vendor/SafeMathChainlink.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMathChainlink {
  /**
    * @dev Returns the addition of two unsigned integers, reverting on
    * overflow.
    *
    * Counterpart to Solidity's `+` operator.
    *
    * Requirements:
    * - Addition cannot overflow.
    */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "SafeMath: addition overflow");

    return c;
  }

  /**
    * @dev Returns the subtraction of two unsigned integers, reverting on
    * overflow (when the result is negative).
    *
    * Counterpart to Solidity's `-` operator.
    *
    * Requirements:
    * - Subtraction cannot overflow.
    */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "SafeMath: subtraction overflow");
    uint256 c = a - b;

    return c;
  }

  /**
    * @dev Returns the multiplication of two unsigned integers, reverting on
    * overflow.
    *
    * Counterpart to Solidity's `*` operator.
    *
    * Requirements:
    * - Multiplication cannot overflow.
    */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "SafeMath: multiplication overflow");

    return c;
  }

  /**
    * @dev Returns the integer division of two unsigned integers. Reverts on
    * division by zero. The result is rounded towards zero.
    *
    * Counterpart to Solidity's `/` operator. Note: this function uses a
    * `revert` opcode (which leaves remaining gas untouched) while Solidity
    * uses an invalid opcode to revert (consuming all remaining gas).
    *
    * Requirements:
    * - The divisor cannot be zero.
    */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // Solidity only automatically asserts when dividing by 0
    require(b > 0, "SafeMath: division by zero");
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
    * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
    * Reverts when dividing by zero.
    *
    * Counterpart to Solidity's `%` operator. This function uses a `revert`
    * opcode (which leaves remaining gas untouched) while Solidity uses an
    * invalid opcode to revert (consuming all remaining gas).
    *
    * Requirements:
    * - The divisor cannot be zero.
    */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "SafeMath: modulo by zero");
    return a % b;
  }
}


// Chain: BSC - File: @openzeppelin/contracts/GSN/Context.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../utils/Context.sol";


// Chain: BSC - File: @openzeppelin/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../utils/Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


// Chain: BSC - File: @openzeppelin/contracts/math/SafeMath.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}


// Chain: BSC - File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


// Chain: BSC - File: @openzeppelin/contracts/utils/Context.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


// Chain: BSC - File: @openzeppelin/contracts/utils/Pausable.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor () internal {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


// Chain: BSC - File: @openzeppelin/contracts/utils/ReentrancyGuard.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}