
//SPDX-License-Identifier: 	BUSL-1.1
pragma solidity ^0.8.9;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Offering.sol";
import "./Service.sol";
import "./Pool.sol";







contract CashCredit is Service {
    

	//Underlying private _valueContract;
	Pool internal _poolContract;
	
	uint256 _decimals;
	// address _revenueAcct;
	uint256 _totalBalance;
	uint256 internal _hundredPctMilliBasisPts = 10000 * 1000;
	mapping(uint256 => uint256) private _tokenDiscount;

	mapping(uint256 => mapping(address => uint256)) private _slotApprovedValues;
	
	
	event MintNetworkServiceToken(uint256  tokenId, uint256 slot, uint256 value);
	event MintCashToken(uint256  tokenId, uint256 slot, uint256 value);
	event RedeemForAsset(uint256  tokenId, address indexed redeemer, uint256 amount);
	event RedeemForAccess(address indexed redeemer, uint256 creditAmount, uint256 valueAmount );
	
	
	ERC20 internal _valueContract;
	


    constructor(address revenueAcct_,
        		address slotRegistryContract_,
        		address poolContract_,
        		address underlyingContract_,
        		address mktAdmin_,
        		uint256 defaultSlot_,
        		string memory name_, 
        		string memory symbol_, 
        		string memory baseuri_,
        		string memory contractDescription_,
        		string memory contractImage_,
        		string memory valueToken_,
        		uint8 decimals_) Service(revenueAcct_, mktAdmin_, slotRegistryContract_, poolContract_, underlyingContract_, defaultSlot_, name_, symbol_ , baseuri_, contractDescription_, contractImage_, 'cash', decimals_) {

        if( keccak256(bytes(valueToken_)) == keccak256(bytes("USDC")) ){
            _valueContract = ERC20(underlyingContract_); 
        }else{
            revert("CashCredit: Only USDC underlying accepted at this time");
        }
    	
        // _revenueAcct = revenueAcct_;
        _decimals = decimals_;
        _poolContract = Pool(poolContract_);
        
    }
    
    
    
    

 
 
 	
    function mintWithDiscount(address owner_, 
        			uint256 slot_, 
        			uint256 value_,
        			uint256 etherizedDiscountBasisPts_,
        			string memory uuid_,
        			string memory tokenDescription_,
        			string memory tokenImage_,
        			string memory property_
    ) public virtual returns (uint256) {
 
       
       uint256 tokenId;
       
       
       tokenId = Service.mint(owner_, slot_, value_, uuid_, tokenDescription_, tokenImage_, property_);
       
       _registry.registerTokenSlot(tokenId, slot_); 
       
       if(slot_ != _defaultSlot){
           _poolContract.poolToken(slot_, tokenId);
       }
       
       emit MintCashToken(tokenId, slot_, value_);
       
       _totalBalance += value_;
       
       _tokenDiscount[tokenId] = etherizedDiscountBasisPts_;  
       
  
       uint256 uValue = (_hundredPctMilliBasisPts - _tokenDiscount[tokenId] / (10 ** _decimals)) * value_ / _hundredPctMilliBasisPts;
       _slotApprovedValues[slot_][owner_] += uValue;
       
       _valueContract.transferFrom(_meriticMktAdmin, address(this), uValue);
       _underlying[tokenId] = _underlying[tokenId] + uValue;
       
       //_valueContract.mint(address(this), slot_, uValue);*/
       
       
    	
	   return tokenId;
  	}
  
  	
  	
  	/*function mintTransfer(address owner_, 
  	    			address receiver_, 
        			uint256 slot_, 
        			uint256 value_,
        			string memory uuid_,
        			string memory tokenDescription_,
        			string memory tokenImage_,
        			string memory property_
    ) public virtual returns (uint256) {
        
        uint256 tokenId = mint(receiver_, slot_, value_, uuid_, tokenDescription_, tokenImage_, property_);
        
        //transferFrom(owner_, receiver_, tokenId);
    }*/
    
    
    
    
  	function mint(address owner_, 
        			uint256 slot_, 
        			uint256 value_,
        			string memory uuid_,
        			string memory tokenDescription_,
        			string memory tokenImage_,
        			string memory property_
    ) public virtual override returns (uint256) {
        uint256 discountBasisPts_ = 0;

        uint256 tokenId = mintWithDiscount(owner_, slot_, value_, discountBasisPts_, uuid_, tokenDescription_, tokenImage_, property_);
        
        
  
        emit MintCashToken(tokenId, slot_, value_);
        return tokenId;
       
  	}
  	
  	
  	
  	
  	
  	
  	function tokenDiscount(uint256 tokenId_) external view returns (uint256) {
  	    if(isContractToken(tokenId_)){
  	    	return _tokenDiscount[tokenId_];	
  	    }else{
  	        return _poolContract.tokenDiscount(tokenId_);
  	    }
  	}
  	
  	
  	
  	
  	
	/*function redeem(uint256 tokenId_, uint256 slotId_, uint256 value_) external {
	    
	   require(ERC3525.ownerOf(tokenId_) == msg.sender || hasRole(MKT_ARBITRATOR_ROLE, msg.sender), "Sender is not authorized to redeem.");
	   uint256 uValue =  (10000 - _tokenDiscount[tokenId_] / (10 ** _decimals)) * value_ / 10000;

	   if(uValue <= _slotApprovedValues[slotId_][msg.sender]){
	       _valueContract.approve(_revenueAcct, uValue);
	       _valueContract.transfer(_revenueAcct, uValue);
	       _slotApprovedValues[slotId_][msg.sender] -= uValue;
        }
        emit Redeem(msg.sender, uValue);
       
	   _totalBalance -= value_;
	   super._burnValue(tokenId_, value_);
	}*/
	
	function redeemForAsset(address offeringContract_, 
	    					uint256 creditTokenId_, 
	    					uint256 slotId_, 
	    					uint256 value_,
	    					string memory assetId_) external returns (uint256) {
	   
	   Offering offering = Offering(offeringContract_);
	   
	   require(ERC3525.ownerOf(creditTokenId_) == msg.sender || _registry.hasAccess('MKT_ADMIN', msg.sender), "Sender is not authorized to redeem.");
	   require(ERC3525.balanceOf(creditTokenId_) >= value_, 'Value exceeds credit balance');
	   
	   if(!offering.isApproveCredit(address(this))){
	       offering.approveCredit(address(this));
	   }
	   
	   uint256 uValue =  (_hundredPctMilliBasisPts - _tokenDiscount[creditTokenId_] / (10 ** _decimals)) * value_ / _hundredPctMilliBasisPts;
	   require(uValue <= _slotApprovedValues[slotId_][msg.sender], "Insufficient allowance");
	   
	   try _valueContract.approve(offeringContract_, uValue) returns (bool isApproved) {
	       //_valueContract.approve(offeringContract_, uValue);
	       uint256 assetTokenId = offering.mintFromCredits( address(this), 
           												creditTokenId_, 
           												_tokenDiscount[creditTokenId_], 
           												msg.sender, 
           												slotId_, 
           												value_, 
           												assetId_);
           												
           
           _slotApprovedValues[slotId_][msg.sender] -= uValue;
	       emit RedeemForAsset(assetTokenId, msg.sender, uValue);
		   _totalBalance -= value_;
		   super._burnValue(creditTokenId_, value_);
		   return assetTokenId;
	   } catch {
            revert("Credits not approved for this offering");
       }
	   
	   return 0;
	}
	
	
	
	function redeemForAccess(address offeringContract_, 
	    					uint256 creditTokenId_, 
	    					uint256 slotId_, 
	    					uint256 value_,
	    					uint256 accesssEndTime_,
	    					string memory assetId_) external returns (bool) {
	    					    
	   Offering offering = Offering(offeringContract_);
	   
	   require(ERC3525.ownerOf(creditTokenId_) == msg.sender || _registry.hasAccess('MKT_ADMIN', msg.sender), "Sender is not authorized to redeem.");
	   require(ERC3525.balanceOf(creditTokenId_) >= value_, 'Value exceeds credit balance');
	   
	   if(!offering.isApproveCredit(address(this))){
	       offering.approveCredit(address(this));
	   }
	   uint256 uValue =  (_hundredPctMilliBasisPts - _tokenDiscount[creditTokenId_] / (10 ** _decimals)) * value_ / _hundredPctMilliBasisPts;
	   
	   require(uValue <= _slotApprovedValues[slotId_][msg.sender], "Insufficient allowance");
	   
	   _valueContract.approve(offeringContract_, uValue);
	   
	   bool accessGranted = offering.accessFromCredits(
			        					address(this), 
			        					creditTokenId_, 
			        					slotId_,
			        					_tokenDiscount[creditTokenId_], 
		        						assetId_,
		        						value_, accesssEndTime_);
        						
       _slotApprovedValues[slotId_][msg.sender] -= uValue;
       
       emit RedeemForAccess(msg.sender, value_, uValue);
       
	   _totalBalance -= value_;
	  
	   super._burnValue(creditTokenId_, value_);
	   
	   return true;
	}
    
    
    
    function transferFrom(
        uint256 fromTokenId_,
        address to_,
        uint256 value_
    ) public payable virtual override returns (uint256) {
        return super.transferFrom(fromTokenId_, to_, value_);
        //address fromOwnerAddress = _allTokens[_allTokensIndex[fromTokenId_]].owner;
    }


	function totalBalance() public view returns (uint256){
	    return _totalBalance;
	}

	

	


    function transferFrom(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) public payable virtual override {
        /* check both tokens are CashCredit token */
        transferFrom(address(this), fromTokenId_, address(this), toTokenId_, value_);
    }
    
    

	function addValue(uint256 fromTokenId_, uint256 toTokenId_, uint256 value_) public {
	    
	    uint256 discountBasisPts =  CashCredit(msg.sender).tokenDiscount(fromTokenId_);
		uint256 uValue =  (10000 - discountBasisPts / (10 ** _decimals)) * value_ / 10000;
			
		ERC3525._mintValue(toTokenId_, value_); 
	    _valueContract.transferFrom(msg.sender, address(this), uValue);
	    
	}
	
	
	
	function transferFrom(
	    address fromContract_,
        uint256 fromTokenId_,
        address toContract_,
        uint256 toTokenId_,
        uint256 value_
    ) public payable virtual {
        require(fromContract_ == address(this), 'Transferring from wrong contract');
        
        if(toContract_ == address(this)){
            uint256 tenKBasisPts = 10000;
	        uint256 toTokenValue = super.balanceOf(toTokenId_);
	        
	        if(_tokenDiscount[fromTokenId_] != _tokenDiscount[toTokenId_]){
	            _tokenDiscount[toTokenId_]  = tenKBasisPts * (10 ** _decimals) - ((tenKBasisPts  * (10 ** _decimals)  - _tokenDiscount[fromTokenId_]) * value_ + (tenKBasisPts  * (10 ** _decimals)  - _tokenDiscount[toTokenId_]) * toTokenValue) / (value_ + toTokenValue);
	        }else{
	            _tokenDiscount[toTokenId_]  = _tokenDiscount[toTokenId_];
	        }
        
            super.transferFrom(fromTokenId_, toTokenId_, value_);
        }else{
            CashCredit toContract = CashCredit(toContract_);
            uint256 discountBasisPts =  _tokenDiscount[fromTokenId_];
			uint256 uValue =  (10000 - discountBasisPts / (10 ** _decimals)) * value_ / 10000;
			
            _valueContract.approve(toContract_, uValue);
            toContract.addValue(fromTokenId_,  toTokenId_, value_);
        }
        
    }



    function transferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) public payable virtual override {
        super.transferFrom( from_, to_, tokenId_);
    }
    
}