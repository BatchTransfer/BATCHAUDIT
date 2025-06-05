//SPDX-License-Identifier: 	BUSL-1.1
pragma solidity ^0.8.9;



import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@solvprotocol/erc-3525/ERC3525.sol";
//import "./underlying/WUSDC.sol";
import "./ServiceMetadataDescriptor.sol";	
import "./Service.sol";
import "./Registry.sol";
//import "./message/Messenger.sol";






contract Pool is ERC3525, AccessControl {
    
    
	mapping(uint256 => address) private _contractOfToken;
    mapping(uint256 => uint256) private _tokenDiscount;
    mapping(uint256 => uint256) private _tokenValueRate;
	
	mapping(uint256 => uint256) private _queryFunds;
	mapping(uint256 => address) private _queryOwner;
	
	struct ContractData {
	    uint256[] tokens;
	}
	
	mapping(uint256 => mapping(address => ContractData)) private _pooledTokens;
	
	bytes32 public constant MKT_ARBITRATOR_ROLE = keccak256("MKT_ARBITRATOR_ROLE");
	
	struct PoolMsg {
	    string msgUri;
        uint256 slotId; 
    }
	
	//mapping(uint256 => PoolMsg) private _poolMsg;
	
	string private _baseuri; 
	string private _valueCurrency;
	
    Registry internal _registry;
    //Messenger internal _messenger;
    
    uint256 internal _discountDecimals = 18;
    uint256 private _decimals;
    
    mapping(address => mapping(uint256 => uint256)) private _underlying;
    
    event MetadataDescriptor(address  contractAddress);
    event NewSlot(uint256 slotId, string slotName);
    
    
    
    ERC20 internal USDC;
    //address internal _underlyingContractAddress = 0x14F137110c3Bb7c44CefCBcF2e96C46A6ADCfb8B;
	
	
	
   	address MERITIC_MKT_SERVICE_ADDRESS = 0xB9441B7BC507136A7Bf0f130e58C3f810d1Dc090;
    
    uint256 commissionNumerator = 50;
	uint256 commissionDenominator = 1000;


	
	
    constructor(address regContract_,
        		string memory valueCurrency_,
        		string memory name_, 
        		string memory symbol_, 
        		string memory baseuri_,
        		string memory contractDescription_,
        		string memory contractImage_,
        		uint8 decimals_) ERC3525(name_, symbol_, decimals_) {

  		_baseuri = baseuri_;
  		_registry = Registry(regContract_); 
  		//_messenger = Messenger(msgerContract_);
  		_valueCurrency = valueCurrency_;
  		USDC = ERC20(_registry.underlyingContractAddress());
  		//_msgIdGenerator = 1;
  
  		
        metadataDescriptor = new ServiceMetadataDescriptor(_baseuri, contractDescription_, contractImage_, address(this));
        emit MetadataDescriptor(address(metadataDescriptor));
        
    }
    
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC3525, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    
    
    function chargeCommision(uint256 amount_) internal virtual returns (uint256) {
        
        uint256 commission = amount_ * commissionNumerator / commissionDenominator; 
        require(amount_- commission > 0, "amount less commission should be > 0");
        USDC.transferFrom(msg.sender, MERITIC_MKT_SERVICE_ADDRESS, commission);
        
        return commission;
    }
    
    
	function lockUsdc(uint256 slotId_, uint256 amount_) public {

        require(amount_ > 0, "amount should be > 0");
        require(_registry.slot(slotId_).isValid, "Pool not valid");
        USDC.transferFrom(msg.sender, address(this), amount_);
        
        
        addUnderlying(msg.sender, slotId_, amount_);
    }
    
    
    
    /*function releaseUsdc(address from_, address to_, uint256 slotId_) public {

        require(_registry.slot(slotId_).isValid, "Pool not valid");
        
        
        _usdc.transferFrom(msg.sender, address(this), amount_);
        _pool.addUnderlying(msg.sender, slotId_, amount_);
    }*/
    
    
    
    function mintQuery(string memory dataUri_, uint256 slotId_, uint256 value_, string memory currency_) external virtual{
    
        
        uint256 commision = chargeCommision(value_);
        lockUsdc(slotId_, value_ - commision);
        
		//_messenger.sendPoolMessage(msg.sender, slotId_, dataUri_);
    }
    
    
    
    
    
    
    function pools() public view returns (Registry.Slot[] memory){
        
        return _registry.pools();
    }
    
    
    
    function mint(address owner_, 
        			uint256 slot_, 
        			uint256 value_
    ) external virtual returns (uint256) {
        //require(_registry.inSlotNetwork(slot_, msg.sender), "Sender not authorized to mint to slot");
        uint256 tokenId = ERC3525._mint(owner_, slot_, value_);
        _contractOfToken[tokenId] = msg.sender;
        return tokenId;
    }
    
    
    
    
    
    function poolToken(uint256 slotId_, uint256 tokenId_) external {
        ContractData storage data = _pooledTokens[slotId_][msg.sender];
        data.tokens.push(tokenId_);
    }
    
    function mintWithDiscount(address owner_, uint256 slot_, uint256 value_, uint256 adjDiscountBasisPts_) external returns (uint256) {
        //require(_registry.inSlotNetwork(slot_, msg.sender), "Sender not authorized to mint to slot");
        uint256 tokenId = ERC3525._mint(owner_, slot_, value_);
        _contractOfToken[tokenId] = msg.sender;

        _tokenDiscount[tokenId] = adjDiscountBasisPts_;
        
        return tokenId;
    }
    
    

    function mintWithValueRate(address owner_, uint256 slot_, uint256 value_, uint256 adjTVRate_) public returns (uint256) {
        
        uint256 tokenId = ERC3525._createOriginalTokenId();
        ERC3525._mint(owner_, tokenId, slot_, value_);
        _tokenValueRate[tokenId] = adjTVRate_;
        
        return tokenId;
    }
    

    
    function contractOf(uint256 networkTokenId_) external view returns (address){
        ERC3525._requireMinted(networkTokenId_);
        return _contractOfToken[networkTokenId_];
    }
    
    
    function approve(uint256 tokenId_, address to_, uint256 value_) public payable virtual override {
        ERC3525._requireMinted(tokenId_);
		ERC3525.approve(tokenId_, to_, value_);
    }
    
    
    
    function transferFrom(
        uint256 fromTokenId_,
        address to_,
        uint256 value_
    ) public payable virtual override returns (uint256) {
        ERC3525._requireMinted(fromTokenId_);
    	uint256 newTokenId =  ERC3525.transferFrom(fromTokenId_, to_, value_);
  
    	return newTokenId;
    }
    
    
    function _cashValueTransfer(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) internal {
        uint256 tenKBasisPts = 10000;
        uint256 toTokenValue = super.balanceOf(toTokenId_);
        
        uint256 discount;
        
        if(_tokenDiscount[fromTokenId_] != _tokenDiscount[toTokenId_]){
            discount = tenKBasisPts * (10 ** _discountDecimals) - ((tenKBasisPts *  (10 ** _discountDecimals) - _tokenDiscount[fromTokenId_]) * value_ + (tenKBasisPts * (10 ** _discountDecimals) - _tokenDiscount[toTokenId_]) * toTokenValue) / (value_ + toTokenValue);
        }else{
            discount = _tokenDiscount[toTokenId_];
        }
        
        _tokenDiscount[toTokenId_] = discount;
        
        super.transferFrom(fromTokenId_, toTokenId_, value_);
    }
    
    
    
    
    function _timeValueTransfer(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) internal {
        uint256 toTokenValue = ERC3525.balanceOf(toTokenId_);
  	    
  	    _tokenValueRate[toTokenId_] = (_tokenValueRate[fromTokenId_] * value_ + _tokenValueRate[toTokenId_] * toTokenValue) / (value_ + toTokenValue);
        
        super.transferFrom(fromTokenId_, toTokenId_, value_);
    }
    
    
    
    function transferFrom(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) public payable virtual override {
        ERC3525._requireMinted(fromTokenId_);
	    ERC3525._requireMinted(toTokenId_);
	    
	    uint256 slotId = ERC3525.slotOf(fromTokenId_);
	    uint256 toSlotId = ERC3525.slotOf(toTokenId_);
	    
	    require(slotId == toSlotId, 'Registry: transfer to token with different slot.');
	
	    Registry.CreditType creditType = _registry.contractType(msg.sender); 
	    Registry.CreditType toType = _registry.contractType(_contractOfToken[toTokenId_]);
	    
	    require(creditType == toType, 'Registry: Cannot transfer between tokens holding different types of credit.');
	    require(creditType != Registry.CreditType.time_, 'Registry: Network value transfer not allowed for priority tokens');
	    
	    
	    if(creditType == Registry.CreditType.cash_){
	        _cashValueTransfer(fromTokenId_, toTokenId_, value_);
	    }else if(creditType == Registry.CreditType.time_){
	        _timeValueTransfer(fromTokenId_, toTokenId_, value_);
	    }else if(creditType == Registry.CreditType.counts_){
	        ERC3525.transferFrom(fromTokenId_, toTokenId_, value_);
	    }
	    
    }
    
    function adminJoinSlot(uint256 slot_, address invitee_) external {
   		require(hasRole(MKT_ARBITRATOR_ROLE, msg.sender), 'Sender not authorized to join address to a slot');
       _registry.setIsAdmin(slot_, invitee_, true);
    
   }
    
    function isSlotAdmin(uint256 slotId_, address adminAdress_) public view returns(bool) {
        return   _registry.isSlotAdmin(slotId_, adminAdress_);  //_isSlotAdmin[slotId_][adminAdress_];
    }
    
    
    function isPoolMember(uint256 slotId_) public view returns(bool) {

        return  _registry.isPoolMember(slotId_, msg.sender); //_isPoolMember[slotId_][msg.sender];
    }
   

	function userIsPoolMember(uint256 slotId_, address user_) public view returns(bool) {
        
        return _registry.isPoolMember(slotId_, user_); 

    }
   
   	function totPoolMembership(uint256 slotId_) public view returns(uint256) {
   	    return _registry.poolMembers(slotId_).length;
   	}
   
   	function poolMembers(uint256 slotId_) public view returns(address[] memory) {
   	    return _registry.poolMembers(slotId_);
   	}
   	
   	
   	
    
    function isNetworkToken(uint256 tokenId_) external view returns (bool){
        return ERC3525._exists(tokenId_);
    }
    
    
    function tokenDiscount(uint256 toTokenId_) public view returns (uint256){
        ERC3525._requireMinted(toTokenId_);
        
	    return _tokenDiscount[toTokenId_];
	}
	
	function tokenValueRate(uint256 toTokenId_) public view returns (uint256){
	    return _tokenValueRate[toTokenId_];
	}
	
	
    
    function slotName(uint256 slotId_) external view returns (string memory) {
        require(exists(slotId_), "Slot is not registered");
        return _registry.slot(slotId_).name;
    }
    
    
    function slotDescription (uint256 slotId_) external view returns (string memory) {
        require(exists(slotId_), "Slot is not registered");
        return _registry.slot(slotId_).description;
    }
    
    function exists(uint256 slotId) public view returns (bool){
        return bytes(_registry.slot(slotId).name).length > 0;
    }
    
    
    function slotURI(uint256 slotId_) public view override returns (string memory) {
        require(exists(slotId_), "Slot is not registered");
        //return string(abi.encodePacked(baseURI, "slot/", slot_.toString())); 
        return _registry.slot(slotId_).slotURI;
    }
    
    function addUnderlying(address owner_, uint256 slotId_, uint256 amount_) public {
        _underlying[owner_][slotId_] = _underlying[owner_][slotId_] + amount_;
    }
    
	/*function _createMsgId() internal virtual returns (uint256) {
        return _msgIdGenerator++;
    }*/
    
    
}
