//SPDX-License-Identifier: 	BUSL-1.1
pragma solidity ^0.8.9;

//import "@openzeppelin/contracts/access/Ownable.sol";
import "./Service.sol";
import "./underlying/WUSDC.sol";
import "./Registry.sol";
import "./Pool.sol";





contract TimeCredit is Service {
	
	struct ValidPeriod{
	    uint256 start;
	    uint256 expiration;
	}
	//uint256 private _defaultSlot;
	mapping(uint256 => ValidPeriod) internal tokenPeriod;
	mapping(uint256 => uint256) private _timeValueRate;
	mapping(uint256 => bool) private _transferAllowed;
	mapping(uint256 => uint256) private _minAllowedValueTransferSecs;
	
	Pool internal _poolContract;
	
	address private _revenueAcct;
	Underlying private _valueContract;
	
	// bool _transferAllowed;
	// uint256 _minAllowedValueTransferSecs;
	uint8 _decimals;
	string private _dispTimeUnit;
	
	
	event MintTimeToken(uint256 tokenId, uint256 valueSeconds, uint256 valueUnit);
	
	
	
	constructor(address revenueAcct_,
        		address serviceAdmin_,
        		address slotRegistry_,
        		address poolContract_,
        		address underlyingContract_,
        		address mktAdmin_,
        		uint256 defaultSlot_,
        		string memory name_, 
        		string memory symbol_,
        		string memory baseUri_,
        		string memory contractDescription_,
        		string memory contractImage_,
        		string memory dispTimeUnit_, 
        		string memory valueToken_, 
        		uint8 decimals_) 
        		Service(serviceAdmin_, mktAdmin_, slotRegistry_, poolContract_, underlyingContract_, defaultSlot_, name_, symbol_, baseUri_, string(abi.encodePacked(contractDescription_, "\n Time units: " , dispTimeUnit_)), contractImage_, 'time',  decimals_) {
				
        		_defaultSlot = defaultSlot_;
        		
				if( keccak256(bytes(valueToken_)) == keccak256(bytes("USDC")) ){
		            _valueContract = WUSDC(underlyingContract_); 
		        }else{
		            revert("SpendCredit: Only USDC underlying accepted at this time");
		        }
					        
       _revenueAcct = revenueAcct_;
       _dispTimeUnit = dispTimeUnit_;
       _decimals = decimals_;
       
       _poolContract = Pool(poolContract_);
	}
	
	
	
	
	function mintTime(address owner_, 
        			uint256 slotId_, 
        			uint256 timeValue_,
        			uint256 paidValue_,
        			uint256 validStart_,
        			uint256 validExpiration_,
        			string memory uuid_,
        			string memory tokenDescription_,
        			string memory tokenImage_,
        			string memory property_,
        			bool transfersAllowed_,
        			uint256 minAllowedValueTransfer_
    ) public virtual returns (uint256) {
        
        			
        uint256 timeValueSeconds;
        
       	uint256 tokenId;
		
		timeValueSeconds = toSeconds(timeValue_);
		
	
 		require(validStart_ <= validExpiration_, "TimeCredit: valid start time must be less than expiration time");
 		require(block.timestamp <= validExpiration_, "TimeCredit: cannot mint an expired token");
 		require(
 		    (block.timestamp <= validStart_) && (timeValueSeconds <= (validExpiration_ - validStart_))
 		    		|| (block.timestamp > validStart_ && block.timestamp < validExpiration_) && (timeValueSeconds <= (validExpiration_ - block.timestamp)), 
 		    			"TimeCredit: time value cannot exceed valid period"
 		);
 		
 		
		_valueContract.mint(address(this), slotId_, paidValue_);
		
		uint256 tVRate = (paidValue_ * (10 ** _decimals) / timeValueSeconds);
		
		if(slotId_ == _defaultSlot){
		    tokenId = super.mint(owner_, slotId_, timeValueSeconds, uuid_, tokenDescription_, tokenImage_, property_);
		}else{
		    tokenId = Service.networkMintWithValueRate(owner_, slotId_, timeValueSeconds, tVRate, uuid_, tokenDescription_, tokenImage_, property_);

		}
		
 		emit MintTimeToken(tokenId, timeValueSeconds, timeValue_);
 		
        _transferAllowed[tokenId] = transfersAllowed_;
        _minAllowedValueTransferSecs[tokenId] = toSeconds(minAllowedValueTransfer_);
       
        _timeValueRate[tokenId] = tVRate;

        
        ValidPeriod memory period = ValidPeriod({
            start: validStart_,
			expiration: validExpiration_
        });
  
  		tokenPeriod[tokenId] = period;
 	
	    return tokenId;
  	}
  	
  	

    
  	
  	function toSeconds(uint256 timeValue_) private view returns (uint256){
  	    uint256 timeValueSeconds;
        
        
        if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('seconds'))){
            timeValueSeconds = timeValue_ / (10 ** _decimals);
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('minutes'))){
            timeValueSeconds = timeValue_ * 60 / (10 ** _decimals);
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('hours'))){
            timeValueSeconds = timeValue_ / (10 ** _decimals) * 60 * 60 ;
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('days'))){
            timeValueSeconds = timeValue_ * 24 * 60 * 60 / (10 ** _decimals);
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('weeks'))){
            timeValueSeconds = timeValue_ * 7 * 24 * 60 * 60 / (10 ** _decimals);
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('months'))){
            timeValueSeconds = timeValue_ * 60 * 60 * 24 * 30 / (10 ** _decimals);
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('years'))){
			timeValueSeconds = timeValue_ * (60 * 60 * 24 * 30 * 12) / (10 ** _decimals);
		}
		
		return timeValueSeconds;
  	}
  	
  	
  	function isValid(uint256 tokenId_) public view virtual returns (bool) {
  	    
		return (block.timestamp >= tokenPeriod[tokenId_].start) && (block.timestamp < tokenPeriod[tokenId_].expiration);    
  	}
  	
  	
  	
  	
  	
  	function calcToTokenTimeValueRate(uint256 fromTokenId_, uint256 toTokenId_, uint256 amountTransferred_) private view returns (uint256){
  	    require(isInternalToken(fromTokenId_) && isInternalToken(toTokenId_), "TimeCredit: calc contract time-value rate requires contract tokens");
  	    uint256 toTokenValue = ERC3525.balanceOf(toTokenId_);
  	    
  	    return (_timeValueRate[fromTokenId_] * amountTransferred_ + _timeValueRate[toTokenId_] * toTokenValue) / (amountTransferred_ + toTokenValue);

  	}
  	
  	
  	
  	
  	
  	
  	function transferFrom(
        uint256 fromTokenId_,
        address to_,
        uint256 value_
    ) public payable virtual override returns (uint256) {
        uint256 value = toSeconds(value_);
        require(_transferAllowed[fromTokenId_], "TimeCredit: transfers are not allowed");
        require(value >= _minAllowedValueTransferSecs[fromTokenId_], "TimeCredit: amount being transfered is less than minimum transferable value");
        require(block.timestamp < tokenPeriod[fromTokenId_].expiration, "TimeCredit: cannot transfer from an expired token");
        
        return super.transferFrom(fromTokenId_, to_, value);
    }
    
    
    
    
    
    
    
    function transferFrom(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) public payable virtual override {
		uint256 valueSeconds = toSeconds(value_);
		
		require(_transferAllowed[fromTokenId_], "TimeCredit: transfers are not allowed");
		require(valueSeconds >= _minAllowedValueTransferSecs[fromTokenId_], "TimeCredit: amount being transfered is less than minimum transferable value");

        require(block.timestamp < tokenPeriod[fromTokenId_].expiration, "TimeCredit: cannot transfer time from an expired token");
        require(block.timestamp <  tokenPeriod[toTokenId_].expiration, "TimeCredit: cannot transfer time into an expired token");
        require(block.timestamp + ERC3525.balanceOf(toTokenId_) <= tokenPeriod[toTokenId_].expiration, "TimeCredit: time value of token receiving transfer exceeds time till expiration");
		
		if(isContractToken(fromTokenId_) && isContractToken(toTokenId_)){
		    
	        if(_timeValueRate[fromTokenId_] != _timeValueRate[toTokenId_]){
	            _timeValueRate[toTokenId_] = calcToTokenTimeValueRate(fromTokenId_, toTokenId_, valueSeconds);
	        }
	        super.transferFrom(fromTokenId_, toTokenId_, valueSeconds);
		}else if(!isContractToken(fromTokenId_) && !isContractToken(toTokenId_)){
		    
		    super.transferFrom(fromTokenId_, toTokenId_, valueSeconds);
		    
		    address toContractAddress = _poolContract.contractOf(toTokenId_);
		    uint256 networkTokenId = networkTokenId[fromTokenId_];
		    
		    uint256 tVRate = (networkTokenId != 0) ? _poolContract.tokenValueRate(networkTokenId) : _poolContract.tokenValueRate(fromTokenId_);
		    
		    
		    
		    uint256 uValue =  tVRate * valueSeconds / (10 ** _decimals);
		    _valueContract.transfer(toContractAddress, uValue);
		  
		}else{
		    revert("TimeCredit: transfer to token with different slot");
		}
		
    }
    
    
    
    function transferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) public payable virtual override {
        require(_transferAllowed[tokenId_], "TimeCredit: transfers are not allowed");
		require(balanceOf(tokenId_) >= _minAllowedValueTransferSecs[tokenId_], "TimeCredit: token value is less than minimum transferable value");
		
        super.transferFrom(from_, to_, tokenId_);
    }
    
    
    
  	
  	
  	function redeem(uint256 tokenId_, uint256 slotId_, uint256 valueSeconds_) external {
	    
	   require(ERC3525.ownerOf(tokenId_) == msg.sender || hasRole(MKT_ARBITRATOR_ROLE, msg.sender), "Sender is not authorized to redeem.");
	   uint256 uValue;
	   
	   if(isContractToken(tokenId_)){
	       uValue =  _timeValueRate[tokenId_] * valueSeconds_ / (10 ** _decimals);
	   }else if(isInternalToken(tokenId_)){
	       uint256 netTokenId = networkTokenId[tokenId_];
	       if(netTokenId != 0){
	           uValue = _poolContract.tokenValueRate(netTokenId) * valueSeconds_ / (10 ** _decimals); 
	       }else{
	           uValue = _poolContract.tokenValueRate(tokenId_) * valueSeconds_ / (10 ** _decimals); 
	       }
	   }
	   
	   _valueContract.redeem(_revenueAcct, slotId_, uValue);
	   super._burnValue(tokenId_, valueSeconds_);
	}
	
	
	
	
	
	function addTime(uint256 tokenId_, uint256 valueSeconds_) external {

	    require(block.timestamp < tokenPeriod[tokenId_].expiration, "TimeCredit: cannot add time to an expired token");
	    if(block.timestamp + balanceOf(tokenId_) + valueSeconds_ > tokenPeriod[tokenId_].expiration){
	        tokenPeriod[tokenId_].expiration = block.timestamp + balanceOf(tokenId_) + valueSeconds_;
	    }
	    super._mintValue(tokenId_, valueSeconds_);
	}
	
	
	
	
	
	function balanceOf(uint256 tokenId_) public view virtual override returns (uint256) {
        _requireMinted(tokenId_);
		
		uint256 balance = super.balanceOf(tokenId_);
		
       if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('seconds'))){
            return balance * (10 ** _decimals);
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('minutes'))){
            return (balance * (10 ** _decimals)) / 60;
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('hours'))){
            return (balance  * (10 ** _decimals)) / (60 * 60);
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('days'))){
            return (balance * (10 ** _decimals)) / (60 * 60 * 24);
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('months'))){
            return (balance * (10 ** _decimals)) / (60 * 60 * 24 * 30);
        }else if(keccak256(bytes(_dispTimeUnit)) == keccak256(bytes('years'))){
			return (balance * (10 ** _decimals)) / (60 * 60 * 24 * 30 * 12);
		}else{
		    return balance * (10 ** _decimals);
		}
    }
    
    
    
    
    
    
}