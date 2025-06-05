// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

 interface IERC1155Receiver {
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _amount, bytes calldata _data) external returns (bytes4);
    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data) external returns (bytes4);
}

interface IERC1155 {
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _amount);
    event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _amounts);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    event URI(string _value, uint256 indexed _id);
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory);
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount, bytes calldata _data) external;
    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data) external;
    function setApprovalForAll(address _operator, bool _approved) external;
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
    function uri(uint256 _id) external view returns (string memory);
}


contract Ownable {

    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract NOOX is IERC1155, Ownable {
    string private _name;
    string private _symbol;
    bool private _isInitialized;

    mapping(address => mapping(uint256 => uint256)) private balances;
    mapping(address => mapping(address => bool)) private operatorApprovals;
    mapping(uint256 => string) private tokenURIs;
    mapping(address => bool) private _whitelist;
    mapping(uint256 => uint256) public totalSupply;

    uint256 public  mintPrice = 0.01 ether;
    
    constructor() {
        _name = "Noox";
        _symbol = "NOOX";
       _whitelist[owner()] = true;
    }

    function initialize() external onlyOwner {
        require(!_isInitialized, "Already initialized");
        _isInitialized = true;
    }


    // Function to add an address to the whitelist
    function addToWhitelist(address addr) external onlyOwner {
        _whitelist[addr] = true;
    }

    // Function to remove an address from the whitelist
    function removeFromWhitelist(address addr) external onlyOwner {
        _whitelist[addr] = false;
    }


    function _mint(address _account, uint256 _id, uint256 _amount) internal 
    {
        require(_amount > 0, "Amount must be greater than zero");
        totalSupply[_id] += _amount;
        balances[_account][_id] += _amount;
        emit TransferSingle(_account, address(0), _account, _id, _amount);      
        _doSafeTransferAcceptanceCheck(_account, address(0), _account, _id, _amount, "");          
    }


    // Function to mint NFTs by the community
    function mint(uint256 _id, uint256 _amount) external payable 
    {
        require(_isInitialized || _whitelist[msg.sender], "Contract is not initialized for community minting");

        if(owner() != msg.sender)
        {
            require(msg.value >= _amount * mintPrice, "Insufficient provided Eth");
        }
        
        _mint(msg.sender, _id, _amount); 


        if(owner() != msg.sender)
        {        
            if (msg.value > _amount * mintPrice) 
            {
                uint256 refundAmount = msg.value - (_amount * mintPrice);
                payable(msg.sender).transfer(refundAmount);
            }
        }
    }


    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }


    function balanceOf(address _owner, uint256 _id) external view override returns (uint256) {
        return balances[_owner][_id];
    }


    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view override returns (uint256[] memory) {
        uint256[] memory batchBalances = new uint256[](_owners.length);
        for (uint256 i = 0; i < _owners.length; i++) {
            batchBalances[i] = balances[_owners[i]][_ids[i]];
        }
        return batchBalances;
    }


    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount, bytes calldata _data) external override {
        require(_to != address(0), "Invalid receiver address");
        require(_from == msg.sender || isApprovedForAll(_from, msg.sender), "Transfer not approved");
        balances[_from][_id] -= _amount;
        balances[_to][_id] += _amount;
        emit TransferSingle(msg.sender, _from, _to, _id, _amount);
        _doSafeTransferAcceptanceCheck(msg.sender, _from, _to, _id, _amount, _data);
    }


    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data) external override 
    {
        require(_to != address(0), "Invalid receiver address");
        require(_ids.length == _amounts.length, "Array length mismatch");
        require(_from == msg.sender || isApprovedForAll(_from, msg.sender), "Transfer not approved");

        for (uint256 i = 0; i < _ids.length; i++) 
        {
            uint256 id = _ids[i];
            uint256 amount = _amounts[i];

            balances[_from][id] -= amount;
            balances[_to][id] += amount;

        }

        emit TransferBatch(msg.sender, _from, _to, _ids, _amounts);
        _doSafeBatchTransferAcceptanceCheck(msg.sender, _from, _to, _ids, _amounts, _data);

    }


    function setApprovalForAll(address _operator, bool _approved) external override 
    {
        operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _owner, address _operator) public view override returns (bool) 
    {
        return operatorApprovals[_owner][_operator];
    }


    function uri(uint256 _id) external view override returns (string memory) 
    {
        return tokenURIs[_id];
    }

    function setURI(uint256 _id, string calldata _uri) external onlyOwner 
    {
        tokenURIs[_id] = _uri;
    }


    function isContract(address addr) internal view returns (bool) 
    {
        uint256 codeSize;
        assembly {
            // Retrieve the bytecode size at the address
            codeSize := extcodesize(addr)
        }
        return codeSize > 0;
    }

    function _doSafeTransferAcceptanceCheck(address _operator, address _from, address _to, uint256 _id, uint256 _amount, bytes memory _data) internal 
    {
            if(isContract(_to))
            {
                try IERC1155Receiver(_to).onERC1155Received(_operator, _from, _id, _amount, _data) returns (bytes4 response) {
                    if (response != IERC1155Receiver(_to).onERC1155Received.selector) {
                        revert("ERC1155: ERC1155Receiver rejected tokens");
                    }
                } catch Error(string memory reason) {
                    revert(reason);
                } catch {
                    revert("ERC1155: transfer to non ERC1155Receiver implementer");
                }
            }
    }



    function _doSafeBatchTransferAcceptanceCheck(address _operator, address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data) internal 
    {
        if(isContract(_to))
        {
            try IERC1155Receiver(_to).onERC1155BatchReceived(_operator, _from, _ids, _amounts, _data) returns (bytes4 response) {
                if (response != IERC1155Receiver(_to).onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }



    function airdropTokens(address[] calldata _recipients, uint256[] calldata _ids, uint256[] calldata _amounts) external {
        require(_recipients.length == _ids.length && _ids.length == _amounts.length, "Array length mismatch");
        for (uint256 i = 0; i < _recipients.length; i++) 
        {
            address recipient = _recipients[i];
            uint256 id = _ids[i];
            uint256 amount = _amounts[i];
            // Ensure the sender has enough balance to airdrop tokens
            require(balances[msg.sender][id] >= amount, "Not enough balance for airdrop");
            // Reduce the sender's balance
            balances[msg.sender][id] -= amount;
            // Increase the recipient's balance
            balances[recipient][id] += amount;
            // Emit the TransferSingle event for the airdrop
            emit TransferSingle(msg.sender, msg.sender, recipient, id, amount);
            // Perform the ERC-1155 receiver check for the recipient (if it's a contract)
            _doSafeTransferAcceptanceCheck(msg.sender, msg.sender, recipient, id, amount, "");
        }
    }



    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }


    function withdraw(uint256 _amount) public onlyOwner {
        uint256 balance = address(this).balance;
        require(_amount<balance, "Insufficient balance");
        payable(msg.sender).transfer(_amount);
    }


    function setPrice(uint256 _price) public onlyOwner
    {
         mintPrice = _price;
    }


}