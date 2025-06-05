
//SPDX-License-Identifier: 	BUSL-1.1
pragma solidity ^0.8.9;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@solvprotocol/erc-3525/ERC3525.sol";
import "@solvprotocol/erc-3525/periphery/ERC3525MetadataDescriptor.sol";

import "./ServiceMetadataDescriptor.sol";
import "./Registry.sol";
import "./Pool.sol";



contract Offering is ERC3525, AccessControl {
    
    Registry internal _registry;
    Pool internal _pool;
    uint256 internal _totalBalance;
    
    address internal _valueContractAddress;
    address internal _revenueAcct;
    address internal _mktAdmin;
    
    int256 internal _hundredPctMilliBasisPts = 10000 * 1000;
    uint256 internal _decimals;

    
    mapping(uint256 => uint256) internal  _underlying;
	
	event ListOffering(uint256 offeringId, uint256 slot, uint256 value);
	event MintOffering(uint256 tokenId, uint256 slot, uint256 value);
	
    event CreditValue(uint256 tokenId, uint256 slot, uint256 value);
    event MetadataDescriptor(address  contractAddress);
    
    
    //enum ActionType {commented_, liked_, disliked_, consumed_, tipped_}
    enum ActionType {simmsg_, comment_, like_,  dislike_, tip_, consumed_, refund_, request_, offer_}
    enum AssetType {data_, content_, event_, app_, merchandise_, credits_, other_}
    
    struct UserAction {
        ActionType actionType;
        uint256 actionTime;
        uint256 messageId;
    }
    struct Asset {
        string assetId;
        string assetUri;
        AssetType assetType;
        uint256[] interaction;
    }

    struct SvcOffering {
        address creator;
        uint256 offeringId;
        bytes32[] assets;
        uint256[] tokens;
        int256 value;
        uint256 slotId;
        string side;
        string description;
        string image;
        string properties;
        bool canShareOwn;
        bool isMultiAccess;
    }
    
    struct Access {
	    uint256 startTime;
	    uint256 endTime;
	}

	mapping(uint256 => UserAction) internal _interactions;
	mapping(bytes32 => Asset) internal _assets;
    mapping(uint256 => SvcOffering) internal _offerings;
    
    mapping(uint256 => uint256[]) internal _tokenOfferings; 
    mapping(uint256 => mapping(uint256 => bool)) internal _tokenOffering;
    mapping(uint256 => mapping(uint256 => int256)) internal _offeringShare;
    
    mapping(uint256 => mapping(address => uint256)) private _approvedValues;
    
	mapping(address => bool) internal _approvedCredit;
	
    mapping(uint256 => mapping(address => mapping(uint256 => Access))) internal _accessLedger;

    ERC20 internal _valueContract;
    uint256 private _offerIdGenerator;
	uint256 private _assetInteractionIdGenerator;

    constructor(address revenueAcct_,
        		address registry_,
        		address poolContract_,
        		address underlyingContract_,
        		string memory name_, 
        		string memory symbol_, 
        		string memory baseuri_,
        		string memory contractDescription_,
        		string memory contractImage_,
        		string memory valueToken_,
        		uint8 decimals_) ERC3525(name_, symbol_, decimals_) {
        		    
        
        _revenueAcct = revenueAcct_;
        _registry = Registry(registry_);
        _pool = Pool(poolContract_);
        _valueContract = ERC20(underlyingContract_); 
        _valueContractAddress = underlyingContract_;
        _decimals = decimals_;
        _mktAdmin = msg.sender;
        _createOfferingId();
        _createAssetInteractionId();
        
		metadataDescriptor = new ServiceMetadataDescriptor(baseuri_, contractDescription_, contractImage_, registry_);
        emit MetadataDescriptor(address(metadataDescriptor));    
 	}
        		
        		
      
   	function supportsInterface(bytes4 interfaceId) public view virtual override(ERC3525, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
 
    
    
    
    /*function offerings(string memory assetId_, string memory side_) public view returns (Offer[] memory) {
        bytes32 assetIdBytes = keccak256(bytes(assetId_));
        uint256[] memory offerIds = _offerIds[assetIdBytes];
     
        uint256 offerCount = 0;
        for (uint256 i=0; i < offerIds.length; i++) {
            Offer memory o = _offer[assetIdBytes][offerIds[i]];
            if(keccak256(bytes(o.side))  == keccak256(bytes(side_)) && o.expiration > block.timestamp){
                offerCount++;
            }
        }
        
        
        Offer[] memory voffers = new Offer[](offerCount);
        uint256 j=0;
        
        for (uint256 i=0; i < offerIds.length; i++) {
            Offer memory o = _offer[assetIdBytes][offerIds[i]];
            if(keccak256(bytes(o.side))  == keccak256(bytes(side_)) && o.expiration > block.timestamp){
                voffers[j++] = o;
            }
        }
        
        return voffers;
    }*/
    
    
    
    function mktListOffering(	address owner_, 
        						string[] memory asset_,
			        			string[] memory assetUri_,
			        			string[] memory assetType_,
        						uint256 value_, 
        						uint256 slotId_,
        						string memory offeringAssetId_, 
        						string memory side_,
        						string memory description_,
			        			string memory image_,
			      				string memory properties_,
			        			bool canShareOwn_,
			      				bool isMultiAccess_) public virtual {
        
        uint256 offeringId = _createOfferingId();
        
        
        bytes32[] memory offeringAssets = new bytes32[](asset_.length);
        
        
        for(uint8 i=0; i < asset_.length; ++i){
            bytes32 assetIdBytes = keccak256(bytes(asset_[i]));
            
            if(_registry.assetOffering(assetIdBytes) != 0){
                revert(string(abi.encodePacked('Asset can only be in one offering')));
            }
            
            _registry.setAssetOffering(assetIdBytes, offeringId);
            
            AssetType atype;
            
            if(keccak256(abi.encodePacked(assetType_[i])) == keccak256(abi.encodePacked('data'))){
                atype = AssetType.data_;
            }else if(keccak256(abi.encodePacked(assetType_[i])) == keccak256(abi.encodePacked('content'))){
                atype = AssetType.content_;
            }else if(keccak256(abi.encodePacked(assetType_[i])) == keccak256(abi.encodePacked('event'))){
                atype = AssetType.event_;
            }else if(keccak256(abi.encodePacked(assetType_[i])) == keccak256(abi.encodePacked('app'))){
                atype = AssetType.app_;
            }else if(keccak256(abi.encodePacked(assetType_[i])) == keccak256(abi.encodePacked('merchandise'))){
                atype = AssetType.merchandise_;
	        }else if(keccak256(abi.encodePacked(assetType_[i])) == keccak256(abi.encodePacked('credits'))){
	            atype = AssetType.credits_;
	        }else if(keccak256(abi.encodePacked(assetType_[i])) == keccak256(abi.encodePacked('other'))){
	            atype = AssetType.other_;
	        }
	        _assets[assetIdBytes].assetId = asset_[i];
	        _assets[assetIdBytes].assetUri = assetUri_[i];
	        _assets[assetIdBytes].assetType = atype;
	        
	        offeringAssets[i] = assetIdBytes; //Asset({assetId: asset_[i], assetUri: assetUri_[i], assetType: atype});
        }
        
        _offerings[offeringId].creator = owner_;
       	_offerings[offeringId].assets = offeringAssets;
	    _offerings[offeringId].offeringId = offeringId;
	    _offerings[offeringId].side = side_;
	  	_offerings[offeringId].description = description_;
	  	_offerings[offeringId].image = image_;
	  	_offerings[offeringId].properties = properties_;
	  	_offerings[offeringId].slotId = slotId_;
	  	_offerings[offeringId].canShareOwn = canShareOwn_;
	  	_offerings[offeringId].isMultiAccess = isMultiAccess_;
	  	_offerings[offeringId].value = int256(value_);
	  	
	  	bytes32 offeringAssetIdBytes = keccak256(bytes(offeringAssetId_));
	   _registry.setAssetOffering(offeringAssetIdBytes, offeringId);
	   
	    emit ListOffering(offeringId, slotId_, value_);
	   			
    }
    
    
    function grantAccess(address user_, uint256 offeringId_) public view returns (bool) {
        require(_offerings[offeringId_].creator != address(0), 'Offering not found');
        return (_offerings[offeringId_].creator == user_);
    }
    
    
    
    
    function mintFromCredits(address creditContract_, 
        			uint256 creditTokenId_,
        			uint256 discountMilliBasisPts_,
        			address owner_, 
        			uint256 slotId_,
        			uint256 value_,
        			string memory offeringAssetId_) public virtual returns (uint256) {
      	
      	uint256 creditSlotId_ = _registry.slotOf(creditContract_, creditTokenId_);
      	require(_approvedCredit[creditContract_], 'Credit contract not approved');
      	require(creditSlotId_ == slotId_, 'credits not approved for this offering');
      	
      	
      	
       	uint256 uValue = uint256((_hundredPctMilliBasisPts - int256(discountMilliBasisPts_) / int256(10 ** _decimals)) * int256(value_) / _hundredPctMilliBasisPts);
       
      	
      	uint256 tokenId = mint(	owner_, slotId_,  uValue,  offeringAssetId_);
				      	    	
		emit CreditValue(tokenId, slotId_, uValue);
		
		//_valueContract.transferFrom(_meriticMktAdmin, address(this), uValue);
		
		bytes32 assetIdBytes = keccak256(bytes(offeringAssetId_));
		uint256 offeringId = _registry.assetOffering(assetIdBytes);

		
      	_accessLedger[offeringId][creditContract_][creditTokenId_] = Access({startTime: block.timestamp, endTime: 0});
      	
      	return tokenId;
    }
      	
      	
      	
    function assetOffering(string memory offeringAssetId_) public view returns (uint256) {
        bytes32 assetIdBytes = keccak256(bytes(offeringAssetId_));
        return _registry.assetOffering(assetIdBytes);
    }
    

    function offering(uint256 offeringId_) public view returns (SvcOffering memory) {
        return _offerings[offeringId_];
    }
    
    
	
	function mint(address owner_, 
        			uint256 slotId_, 
        			uint256 value_,
        			string memory offeringAssetId_) public virtual returns (uint256) {
        			    
       bytes32 assetIdBytes = keccak256(bytes(offeringAssetId_));
       uint256 offeringId = _registry.assetOffering(assetIdBytes); 
       
	   require(_registry.hasAccess('MKT_ADMIN', msg.sender) 
	       		|| _approvedCredit[msg.sender] 
	       		|| _offerings[offeringId].creator == msg.sender, 'Sender not authorized to mint');

       uint256 tokenId = ERC3525._mint(owner_, slotId_, value_);
  
       
       
	   int256 share = _hundredPctMilliBasisPts;
   	   _offerings[offeringId].tokens.push(tokenId); //FracShare({tokenId: tokenId, fracShare: share}));
    
       _tokenOfferings[tokenId].push(offeringId);
       _tokenOffering[tokenId][offeringId] = true;
       _offeringShare[tokenId][offeringId] = share;
       
       updateTokenMetadataDescriptor(	tokenId, 
           								offeringAssetId_, 
   										_offerings[offeringId].description, 
   										_offerings[offeringId].image, 
   										_offerings[offeringId].properties);

       _pool.poolToken(slotId_, tokenId);
       _totalBalance += value_;
       _approvedValues[slotId_][owner_] += value_;
       
       
       emit MintOffering(tokenId, slotId_, value_);
       return tokenId;
  	}
  	
  	
  	
  	function accessFromCredits(	address creditContract_, 
        						uint256 creditTokenId_, uint256 creditSlotId_, uint256 discountMilliBasisPts_, 
        						string memory offeringAssetId_, uint256 value_, uint256 endTime_) public returns (bool) {
        
        require(_approvedCredit[creditContract_], 'Credit contract not approved');
      	
        
        bytes32 assetIdBytes = keccak256(bytes(offeringAssetId_));	    
    	uint256 offeringId = _registry.assetOffering(assetIdBytes);
    	
    	require(creditSlotId_ == _offerings[offeringId].slotId, 'credits not approved for this offering');
    	_accessLedger[offeringId][creditContract_][creditTokenId_] = Access({startTime: block.timestamp, endTime: endTime_});
    }
    
    
    
  	
  	function access(uint256 offeringId_, address tokenContract_, uint256 tokenId_) public  virtual returns (bool) {
  	    Access memory obj = _accessLedger[offeringId_][tokenContract_][tokenId_];
  	    return (obj.startTime >= block.timestamp && (obj.endTime == 0 || obj.endTime < block.timestamp));
  	}
  	
  	
  	function updateTokenMetadataDescriptor( uint256 tokenId_, string memory offeringAssetId_, 
  	    									string memory tokenDescription_, string memory tokenImage_, string memory properties_) internal {
  		
  		ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenUUID(tokenId_, offeringAssetId_);
       	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenDescription(tokenId_, tokenDescription_);
       	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenImage(tokenId_, tokenImage_);
       	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenProperty(tokenId_, properties_);
  	}
  	
  	
  	
  	
  	function approveCredit(address creditContract_) public {
  	    //require(_registry.hasAccess('MKT_ADMIN', msg.sender), 'Sender not authorized to approve credit');
  	    Service svc = Service(creditContract_);
  	    require(svc.valueContractAddress() == _valueContractAddress, 'Value contract mismatch');
  	    require(svc.valueDecimals() == ERC3525.valueDecimals(), 'Decimals mismatch');
		_approvedCredit[creditContract_] = true;
  	}
  	
  	
  	
  	function isApproveCredit(address creditContract_) public view returns (bool) {
  	    return _approvedCredit[creditContract_];
  	}
  	
  	
  	
  	
  	function transferFrom(
        uint256 fromTokenId_,
        address to_,
        uint256 value_
    ) public payable virtual override returns (uint256) {
  		require(_tokenOfferings[fromTokenId_].length > 0, 'Token has no offering');
        require(value_ > 0 && (value_ / _tokenOfferings[fromTokenId_].length > 0), string(abi.encodePacked('Value less than minimum')));
    
        /* Need to set metdataDesxriptor for new offeringId */
        uint256 slotId_ = ERC3525.slotOf(fromTokenId_);
        
        _approvedValues[slotId_][msg.sender] -= value_;
        _approvedValues[slotId_][to_] += value_;
        
        uint256 newTokenId =  ERC3525.transferFrom(fromTokenId_, to_, value_);
        
        //updateTokenMetadataDescriptor(newTokenId, uint256 offeringAssetId_, 
  	    //									string memory tokenDescription_, string memory tokenImage_, string memory properties_)
        _pool.poolToken(slotId_, newTokenId);
        
        
        
        // int256 deltaVal = int256(value_ / _tokenOfferings[fromTokenId_].length);
        int256 totValue = 0;
        for(uint8 i=0; i < _tokenOfferings[fromTokenId_].length; ++i){
            uint256 offeringId = _tokenOfferings[fromTokenId_][i];
            totValue += _offerings[offeringId].value;
        }
        
        
        for(uint8 i=0; i < _tokenOfferings[fromTokenId_].length; ++i){
            uint256 offeringId = _tokenOfferings[fromTokenId_][i];
            int256 deltaV = (int256(value_) * _offerings[offeringId].value * int256(10 ** _decimals) / totValue ) / int256(10 ** _decimals);
            int256 newShare = deltaV * _hundredPctMilliBasisPts / _offerings[offeringId].value;
            int256 fromTokenShare = _offeringShare[fromTokenId_][offeringId];
            _offeringShare[newTokenId][offeringId] = newShare;
            _offeringShare[fromTokenId_][offeringId] = fromTokenShare - newShare;
            
            _tokenOfferings[newTokenId].push(offeringId);
        	_tokenOffering[newTokenId][offeringId] = true;
        	_offerings[offeringId].tokens.push(newTokenId); 
        }
        
        
        return newTokenId;
    }
    
    
    
    function numOwners(uint256 offeringId_) public view returns (uint256) {
        return _offerings[offeringId_].tokens.length;
    }
    
    function ownershipMilliBasisPts(string memory offeringAssetId_, uint256 tokenId_) public view returns (int256) {
        bytes32 assetIdBytes = keccak256(bytes(offeringAssetId_));
        uint256 offeringId = _registry.assetOffering(assetIdBytes);
        return _offeringShare[tokenId_][offeringId];
    }
    
    
    function updateFracOwnership(uint256 offeringId_, int256 value_) internal {
        
        int256 oldOfferingVal = _offerings[offeringId_].value;
        _offerings[offeringId_].value += value_;
        
        for(uint8 i=0; i < _offerings[offeringId_].tokens.length; ++i){
            uint256 tokenId  = _offerings[offeringId_].tokens[i];
            //FracShare memory token = _offerings[offeringId_].tokens[i];
            int256 oldShare = _offeringShare[tokenId][offeringId_];
            int256 newShare = (oldShare * oldOfferingVal) / _offerings[offeringId_].value;
            _tokenOffering[tokenId][offeringId_] = true;
            _offeringShare[tokenId][offeringId_] = newShare;
            //_offerings[offeringId_].tokens[i].fracShare = newShare;
        } 
    }
    
    
    
    function transferFrom(
        uint256 fromTokenId_,
        uint256 toTokengId_,
        uint256 value_) public payable virtual override {
        
        uint256 slotId_ = ERC3525.slotOf(fromTokenId_);
        
        ERC3525.transferFrom(fromTokenId_, toTokengId_, value_);
        
        address fromAddr_ = ERC3525.ownerOf(fromTokenId_);
        address toAddr_ = ERC3525.ownerOf(toTokengId_);
        
        _approvedValues[slotId_][fromAddr_] -= value_;
        _approvedValues[slotId_][toAddr_] += value_;
        
        
        int256 deltaVal = int256(value_) / int256(_tokenOfferings[fromTokenId_].length);
  		
  		int256 totValue = 0;
  		
        for(uint8 i=0; i < _tokenOfferings[fromTokenId_].length; ++i){
            uint256 offeringId = _tokenOfferings[fromTokenId_][i];
            totValue += _offerings[offeringId].value;
        }
        
        for(uint8 i=0; i < _tokenOfferings[fromTokenId_].length; ++i){
            
            uint256 offeringId = _tokenOfferings[fromTokenId_][i];
            int256 deltaV = (int256(value_) * _offerings[offeringId].value * int256(10 ** _decimals) / totValue ) / int256(10 ** _decimals);
            
			int256 deltaShare = deltaV * _hundredPctMilliBasisPts / _offerings[offeringId].value;
            int256 fromTokenShare = _offeringShare[fromTokenId_][offeringId];
     
            _offeringShare[fromTokenId_][offeringId] = fromTokenShare - deltaShare;
            
            if(!_tokenOffering[toTokengId_][offeringId]){
                _tokenOfferings[toTokengId_].push(offeringId);
                _tokenOffering[toTokengId_][offeringId] = true;
                
                _offerings[offeringId].tokens.push(toTokengId_); 
            }
            _offeringShare[toTokengId_][offeringId] += deltaShare;
        }
    }
    
    
  	
  	
  	
  	
  	function transferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) public payable virtual override {
        
        ERC3525.transferFrom( from_, to_, tokenId_);
        uint256 slotId_ = ERC3525.slotOf(tokenId_);
        
        uint256 value_ = ERC3525.balanceOf(tokenId_);
        
        _approvedValues[slotId_][from_] -= value_;
        _approvedValues[slotId_][to_] += value_;
    }
    
    
    
    
    
    
  	function redeem(uint256 tokenId_, uint256 slotId_, uint256 value_) external {
	    
	   require(ERC3525.ownerOf(tokenId_) == msg.sender, "Sender is not authorized.");
	   require(value_ <= _approvedValues[slotId_][msg.sender], "Insufficient approval to redeem amount");
	  
       _valueContract.approve(_revenueAcct, value_);
       _valueContract.transfer(_revenueAcct, value_);
       
       _approvedValues[slotId_][msg.sender] -= value_;
       
       int256 deltaVal = int256(value_ / _tokenOfferings[tokenId_].length);
       
       for(uint8 i=0; i < _tokenOfferings[tokenId_].length; ++i){
           uint256 offeringId = _tokenOfferings[tokenId_][i];
           updateFracOwnership(offeringId, -deltaVal);
       }
       
	   _totalBalance -= value_;
	   super._burnValue(tokenId_, value_);

	}
  	
  	
  	
  	
  	function addUserAction(string memory assetId_, uint256 msgId_, ActionType actionType_) external {
  	    bytes32 assetIdBytes = keccak256(bytes(assetId_));
  	    uint256 interactionId = _createAssetInteractionId();
  	    _interactions[interactionId] = UserAction({ actionType: actionType_, actionTime: block.timestamp, messageId: msgId_});
		_assets[assetIdBytes].interaction.push(interactionId);
  	}
  	
  	function getAssetUserActions(string memory assetId_) public view returns (UserAction[] memory) {
  	    bytes32 assetIdBytes = keccak256(bytes(assetId_));
  	    Asset memory ast = _assets[assetIdBytes];
  	    
  	    UserAction[] memory interact = new UserAction[](ast.interaction.length);
  	    
  	    for(uint8 i = 0; i < ast.interaction.length; ++i){
  	        uint256 iid = ast.interaction[i];
  	       	interact[i] = _interactions[iid];
  	    }
  	    
  	    return interact;
  	}
  	
  	function _setBaseURI(string memory uri_) external virtual {
        ServiceMetadataDescriptor(address(metadataDescriptor)).setBaseURI(uri_);
    }
    
  	function _createOfferingId() internal virtual returns (uint256) {
        return _offerIdGenerator++;
    }
  	
  	function _createAssetInteractionId() internal virtual returns (uint256) {
        return _assetInteractionIdGenerator++;
    }
}



