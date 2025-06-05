
//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@solvprotocol/erc-3525/ERC3525.sol";
import "./ServiceMetadataDescriptor.sol";
import "./Registry.sol";
import "./Pool.sol";

import "./underlying/WUSDC.sol";
import "./extensions/Underlying.sol";







contract Service is ERC3525, AccessControl {
    
    using Strings for address;
    using Strings for uint256;
    
    address internal _adminAddress;
    address internal _meriticMktAdmin;
    uint256 internal _defaultSlot;
    Registry internal _registry;
    Pool internal _slotPool;
    
    uint256 private _offerIdGenerator;
    
    struct Offer {
        uint256 offerId;
        address owner;
        string side;
        uint256 price;
        uint256 tokenId;
        uint256 expiration;
    }
    
    
    address _valueContractAddress;
    Registry.CreditType internal _contractType;
    
    mapping(uint256 => uint256) internal networkTokenId;
 	mapping(uint256 => uint256) internal  _underlying;
 	
 	mapping(bytes32 => mapping(uint256 => Offer)) internal  _offer;
 	mapping(bytes32 => uint256[]) internal  _offerIds;
    bytes32 public constant MKT_ARBITRATOR_ROLE = keccak256("MKT_ARBITRATOR_ROLE");
    bytes32 public constant SERVICE_ADMIN_ROLE = keccak256("SERVICE_ADMIN_ROLE");
    
    
    event MintServiceToken(uint256  tokenId, uint256 slot, uint256 value);
    
    event MintServiceTokenToAddress(uint256  newTokenId, uint256 slot, uint256 value);
	event MetadataDescriptor(address  contractAddress);
	event ValueTransfer(uint256 fromTokenId,  uint256 toTokenId, uint256 value);

	event MintAssetToken(uint256  tokenId, uint256 slot, uint256 value);
	
	event ListOffer(uint256 offeringId, uint256 value);
	
    constructor(address adminAddress_,
        		address mktAdmin_,
        		address slotRegistry_,
        		address pool_,
        		address valueContractAddresss_,
        		uint256 defaultSlot_,
        		string memory name_, 
        		string memory symbol_,
        		string memory baseuri_,
        		string memory contractDescription_ ,
        		string memory contractImage_,
        		string memory contractType_,
        		uint8 decimals_) ERC3525(name_, symbol_, decimals_) {
      
	
        _meriticMktAdmin = mktAdmin_;
        _defaultSlot = defaultSlot_;
        _adminAddress = adminAddress_;
  		_registry = Registry(slotRegistry_);
  		_slotPool = Pool(pool_);
  		_valueContractAddress = valueContractAddresss_;
  		
  		_contractType = ( keccak256(abi.encodePacked(contractType_)) == keccak256(abi.encodePacked('time'))? Registry.CreditType.time_ : 
  							keccak256(abi.encodePacked(contractType_)) == keccak256(abi.encodePacked('cash')) ?  Registry.CreditType.cash_ : 
  								keccak256(abi.encodePacked(contractType_)) == keccak256(abi.encodePacked('counts')) ? Registry.CreditType.counts_ :
  									Registry.CreditType.priority_ );
  					
  		_registry.registerContract(adminAddress_, defaultSlot_, _contractType);
  		
        metadataDescriptor = new ServiceMetadataDescriptor(baseuri_, contractDescription_, contractImage_, slotRegistry_);
        
        _setupRole(MKT_ARBITRATOR_ROLE, _meriticMktAdmin);
		_setupRole(SERVICE_ADMIN_ROLE, adminAddress_);	
        
        emit MetadataDescriptor(address(metadataDescriptor));
    }
    
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC3525, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    function defaultSlot() public view returns (uint256) {
        return _defaultSlot;
    }
    
    
    
    
    function _baseURI() internal view virtual override returns (string memory) {
        return ServiceMetadataDescriptor(address(metadataDescriptor)).baseURI();
    }
   
    
	function contractURI() public view virtual override returns (string memory) {
        return ServiceMetadataDescriptor(address(metadataDescriptor)).constructContractURI();
    }
    
    
    function valueContractAddress() public view returns (address){
        return _valueContractAddress;
    }
    
    
    
    function tokenURI(uint256 tokenId_) public view virtual override returns (string memory) {
        ERC3525._requireMinted(tokenId_);
        return ServiceMetadataDescriptor(address(metadataDescriptor)).constructTokenURI(tokenId_);

    }
    
    
    
 	function _setBaseURI(string memory uri_) external virtual {
        ServiceMetadataDescriptor(address(metadataDescriptor)).setBaseURI(uri_);
    }
 
 	
	function contractAdmin() public view returns (address){
	    return _adminAddress;
	}
	
	
	
	
	
	
	
	function creditType() public view returns (string memory) {
	    string memory ctype;
	    ctype = (_contractType == Registry.CreditType.priority_ ? 'priority' :
	        		_contractType == Registry.CreditType.time_ ? 'time' :
	        			_contractType == Registry.CreditType.counts_ ? 'counts' : 'cash');
	        			
	    return ctype;
	}
	
    function mint(address owner_, 
        			uint256 slot_, 
        			uint256 value_,
        			string memory uuid_,
        			string memory tokenDescription_,
        			string memory tokenImage_,
        			string memory property_
    ) public virtual returns (uint256) {
        
        
        uint256 tokenId = ERC3525._mint(owner_, slot_, value_);
        
    	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenUUID(tokenId, uuid_);
    	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenDescription(tokenId, tokenDescription_);
    	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenImage(tokenId, tokenImage_);
    	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenProperty(tokenId, property_);
    	
        emit MintServiceToken(tokenId, slot_, value_);

	    return tokenId;
  	}
  	
  	
  	
  	
  	
  	
  	function networkMintWithDiscount(address owner_, uint256 slot_, uint256 value_, uint256 discountBasisPts_,
        			string memory uuid_, string memory tokenDescription_, string memory tokenImage_, string memory property_) public virtual returns (uint256) {
        			    
        //uint256 decimals = ERC3525.valueDecimals();
    	
    	uint256 tokenId = ERC3525._createOriginalTokenId();
           
           
    	uint256 regTokenId = _slotPool.mintWithDiscount(owner_, slot_, value_, discountBasisPts_);
        
        networkTokenId[tokenId] = regTokenId;
        
        ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenUUID(tokenId, uuid_);
    	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenDescription(tokenId, tokenDescription_);
    	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenImage(tokenId, tokenImage_);
    	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenProperty(tokenId, property_);
    	
    	
        return tokenId;
        			    
 	}
 	
 	
 	
 	function networkMintWithValueRate(address owner_, uint256 slot_, uint256 value_, uint256 valueRate_,
        			string memory uuid_, string memory tokenDescription_, string memory tokenImage_, string memory property_) public returns (uint256) {
        			    
        uint256 decimals = ERC3525.valueDecimals();
        
        
    	uint256 regTokenId = _slotPool.mintWithValueRate(owner_, slot_, value_, valueRate_ / (10  ** decimals));
        
        uint256 tokenId = ERC3525._createOriginalTokenId();
        
        networkTokenId[tokenId] = regTokenId;
         
        ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenUUID(tokenId, uuid_);
    	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenDescription(tokenId, tokenDescription_);
    	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenImage(tokenId, tokenImage_);
    	ServiceMetadataDescriptor(address(metadataDescriptor)).setTokenProperty(tokenId, property_);
    	
        return tokenId;
        			    
 	}
 	
 	
 	
 	
    
    function transferFrom(
        uint256 fromTokenId_,
        address to_,
        uint256 value_
    ) public payable virtual override returns (uint256) {
        
        if(networkTokenId[fromTokenId_] == 0){
        	uint256 newTokenId =  super.transferFrom(fromTokenId_, to_, value_);
        	emit MintServiceTokenToAddress(newTokenId, slotOf(fromTokenId_), value_);
        	return newTokenId;
        }else{
            uint256 newTokenId = _slotPool.transferFrom(fromTokenId_, to_, value_);
            emit MintServiceTokenToAddress(newTokenId, slotOf(fromTokenId_), value_);
        	return newTokenId;
        }
    }
    
    
    
    
    
    function contractValueTransfer(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) internal  {
        
        
        ERC3525.transferFrom(fromTokenId_, toTokenId_, value_);
        emit ValueTransfer(fromTokenId_,  toTokenId_, value_);	
    }
    
    
    
    

    function transferFrom(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) public payable virtual override {
        //require(isContractToken(toTokenId_) || _isNetworkToken(toTokenId_),
        require(isContractToken(toTokenId_) || _isNetworkToken(toTokenId_), 'Token ID of receiver not recognized by this contract or the registry');
        
        
        if(isContractToken(fromTokenId_) && isContractToken(toTokenId_)){
        	
        	ERC3525.transferFrom(fromTokenId_, toTokenId_, value_);
        	emit ValueTransfer(fromTokenId_,  toTokenId_, value_);
        	//_contractTokenDiscount[toTokenId] = calcContractTokenDiscount(fromTokenId_, toTokenId_, value_);
            //super.transferFrom(fromTokenId_, toTokenId_, value_);
        	
       	} else {
       	    _slotPool.transferFrom(fromTokenId_, toTokenId_, value_);
       	}    
    	
    }
    
    
    
    
    function isContractToken(uint256 tokenId_) internal view returns (bool){
        return (ERC3525._exists(tokenId_) && ERC3525.slotOf(tokenId_) == _defaultSlot);
    }
    
    
    
    function isInternalToken(uint256 tokenId_) internal view returns (bool) {
        
        return (networkTokenId[tokenId_] != 0);
    }
    
    function _isNetworkToken(uint256 tokenId_) internal view returns (bool) {
        
        return (networkTokenId[tokenId_] != 0 || _slotPool.isNetworkToken(tokenId_));
    }
    
    function isExternalToken(uint256 tokenId_) internal view returns (bool) {
        
        return ( (networkTokenId[tokenId_] == 0 && _slotPool.contractOf(tokenId_) != address(this))
        			|| (networkTokenId[tokenId_] != 0  && _slotPool.contractOf(networkTokenId[tokenId_]) != address(this)) );
    }
    
    

    function transferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) public payable virtual override {
        super.transferFrom( from_, to_, tokenId_);
    }
    
    
    
    function getTokenUUID(uint256 tokenId) view external returns(string memory){
        return ServiceMetadataDescriptor(address(metadataDescriptor)).getTokenUUID(tokenId);
    }
    
    function getTokenDescription(uint256 tokenId) view external returns(string memory){
        return ServiceMetadataDescriptor(address(metadataDescriptor)).getTokenDescription(tokenId);
    }
    
    function getTokenImage(uint256 tokenId) view external returns(string memory){
        return ServiceMetadataDescriptor(address(metadataDescriptor)).getTokenImage(tokenId);
    }
    
	
	
	
	
	function registerOnSlot(uint256 slotId_) public {
	    require(hasRole(SERVICE_ADMIN_ROLE, msg.sender), 'Sender not authorized to register contract to this slot');
	    _registry.registerContract(_adminAddress, slotId_, _contractType);
	}
	
	function _exists(uint256 tokenId_) internal view virtual override returns (bool) {
        return ERC3525._exists(tokenId_) || _isNetworkToken(tokenId_);
    }
    
    
	
	function _requireMinted(uint256 tokenId_) internal view virtual override {
        require(_exists(tokenId_) || _isNetworkToken(tokenId_), "ERC3525: invalid token ID");
    }
    
    
    function balanceOf(uint256 tokenId_) public view virtual override returns (uint256) {
        _requireMinted(tokenId_);
        
        if(isContractToken(tokenId_)){
            return super.balanceOf(tokenId_);
        }else{
            uint256 netTokenId = networkTokenId[tokenId_];
            return _slotPool.balanceOf(netTokenId);
        }
    }
    
    
    function ownerOf(uint256 tokenId_) public view virtual override returns (address owner_) {
        _requireMinted(tokenId_);
        
        if(isContractToken(tokenId_)){
            return super.ownerOf(tokenId_);
        }else{
            return _slotPool.ownerOf(networkTokenId[tokenId_]);
        }
    }
    
    
   
        
    
    function listOffer(uint256 expiration_, uint256 tokenId_, uint256 price_, string memory assetId_, string memory side_) external {
        
        uint256 offerId = _createOfferId();
        bytes32 assetIdBytes = keccak256(bytes(assetId_));
        
        _offer[assetIdBytes][offerId].owner = msg.sender;
	    _offer[assetIdBytes][offerId].offerId = offerId;
	    _offer[assetIdBytes][offerId].side = side_;
	    _offer[assetIdBytes][offerId].expiration = expiration_;
	    _offer[assetIdBytes][offerId].tokenId = tokenId_;
	    _offer[assetIdBytes][offerId].price = price_;
	   
	    _offerIds[assetIdBytes].push(offerId);
	    emit ListOffer(offerId, price_);
    }
    
    
    
    function mktListOffer(address owner_, uint256 expiration_, uint256 tokenId_, uint256 price_, string memory assetId_, string memory side_) public virtual {
        
        uint256 offerId = _createOfferId();
        bytes32 assetIdBytes = keccak256(bytes(assetId_));
        
        _offer[assetIdBytes][offerId].owner = owner_;
	    _offer[assetIdBytes][offerId].offerId = offerId;
	    _offer[assetIdBytes][offerId].side = side_;
	    _offer[assetIdBytes][offerId].expiration = expiration_;
	    _offer[assetIdBytes][offerId].tokenId = tokenId_;
	    _offer[assetIdBytes][offerId].price = price_;
	   
	    _offerIds[assetIdBytes].push(offerId);
	    emit ListOffer(offerId, price_);
	    
    }
    
    

    
    
    function validOffers(string memory assetId_, string memory side_) public view returns (Offer[] memory) {
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
    }
    
    
    
    
    
    function approve(uint256 tokenId_, address to_, uint256 value_) public payable virtual override {
        _requireMinted(tokenId_);
        
        if(isContractToken(tokenId_)){
            super.approve(tokenId_, to_, value_);
        }else{
            _slotPool.approve(networkTokenId[tokenId_], to_, value_);
        }
    }


    function allowance(uint256 tokenId_, address operator_) public view virtual override returns (uint256) {
        _requireMinted(tokenId_);
        
        if(isContractToken(tokenId_)){
            return super.allowance(tokenId_, operator_);
        }else{
            return _slotPool.allowance(networkTokenId[tokenId_], operator_);
        }
    }
    
    
    function _createOfferId() internal virtual returns (uint256) {
        return _offerIdGenerator++;
    }
    
    

}