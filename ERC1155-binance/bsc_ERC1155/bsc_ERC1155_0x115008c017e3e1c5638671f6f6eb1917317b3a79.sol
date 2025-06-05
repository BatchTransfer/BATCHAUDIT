// SPDX-License-Identifier: MIT
// https://cbomber.io
// CryptoBomberBasic
pragma solidity 0.8.8;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

}

library Address {
    
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

contract ERC165 is IERC165 {
    
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;
 
    mapping(bytes4 => bool) private _supportedInterfaces;
 
    constructor () {
        _registerInterface(_INTERFACE_ID_ERC165);
    }
 
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }
 
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}


interface IERC1155Receiver is IERC165 {
 
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    )
        external
        returns(bytes4);
 
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    )
        external
        returns(bytes4);
}

interface IERC1155 is IERC165 {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}


interface IERC1155MetadataURI is IERC1155 {
    function uri(uint256 id) external view returns (string memory);
}

contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using SafeMath for uint256;
    using Address for address;
    
    struct AddressSet {
        address[] _values;
        mapping (address => uint256) _indexes;
    }
    
    struct Uint256Set {
        uint256[] _values;
        mapping (uint256 => uint256) _indexes;
    }
    
    mapping (address => Uint256Set) private holderTokens;
    mapping (uint256 => AddressSet) private owners;
    mapping (uint256 => mapping(address => uint256)) private _balances;
    mapping (address => mapping(address => bool)) private _operatorApprovals;

    string private _uri;
    bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 private constant _INTERFACE_ID_ERC1155_METADATA_URI = 0x0e89341c;
 
    constructor (string memory _uris){
        _setURI(_uris);
        _registerInterface(_INTERFACE_ID_ERC1155);
        _registerInterface(_INTERFACE_ID_ERC1155_METADATA_URI);
    }
    
    function tokensOf(address owner) public view returns (uint256[] memory) {
        return holderTokens[owner]._values;
    }

    function toString(uint256 value) internal pure returns (string memory) {
         if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function strConcat(string memory _a, string memory _b) internal pure returns (string memory) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory ret = new string(_ba.length + _bb.length);
        bytes memory bret = bytes(ret);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++)bret[k++] = _ba[i];
        for (uint i = 0; i < _bb.length; i++)bret[k++] = _bb[i];
        return string(ret);
   } 
 
    function uri(uint256 _id) external view override returns (string memory) {
        return bytes(_uri).length > 0 ? strConcat(string(abi.encodePacked(_uri, toString(_id))), ".json"): "";
    }
    
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }
 
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    )
        public
        view
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            require(accounts[i] != address(0), "ERC1155: batch balance query for the zero address");
            batchBalances[i] = _balances[ids[i]][accounts[i]];
        }
        return batchBalances;
    }
    
    function ownerOf(uint256 _id) public view returns (address[] memory) {
        return owners[_id]._values;
    }
 
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(_msgSender() != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }
 
    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return _operatorApprovals[account][operator];
    }
 
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        public
        virtual
        override
    {
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        require(amount > 0 ,"Amount must be greater than 0");

        address operator = _msgSender();
        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);
        _balances[id][from] = _balances[id][from].sub(amount, "ERC1155: insufficient balance for transfer");
        _balances[id][to] = _balances[id][to].add(amount);

        emit TransferSingle(operator, from, to, id, amount);
        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
        if (balanceOf(from, id) == 0) {
            setRemove(from, id);
        }
        setAdd(to, id);
    }
 
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        public
        virtual
        override
    {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        address operator = _msgSender();
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            require(amount > 0 ,"Amount must be greater than 0");
            _balances[id][from] = _balances[id][from].sub(
                amount,
                "ERC1155: insufficient balance for transfer"
            );
            _balances[id][to] = _balances[id][to].add(amount);
        }
        emit TransferBatch(operator, from, to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            if (balanceOf(from, ids[i]) == 0) {
                setRemove(from, ids[i]);
            }
            setAdd(to, ids[i]);
        }
    }
 
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }
 
    function _mint(address account, uint256 id, uint256 amount, bytes memory data) internal virtual {
        require(account != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();
 
        _beforeTokenTransfer(operator, address(0), account, _asSingletonArray(id), _asSingletonArray(amount), data);
 
        _balances[id][account] = _balances[id][account].add(amount);
        emit TransferSingle(operator, address(0), account, id, amount);
 
        _doSafeTransferAcceptanceCheck(operator, address(0), account, id, amount, data);

        setAdd(account, id);
    }
 
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
 
        address operator = _msgSender();
 
        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);
 
        for (uint i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] = amounts[i].add(_balances[ids[i]][to]);
        }
 
        emit TransferBatch(operator, address(0), to, ids, amounts);
 
        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {

            setAdd(to, ids[i]);
        }
    }
    
    function _burn(address account, uint256 id, uint256 amount) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
 
        address operator = _msgSender();
 
        _beforeTokenTransfer(operator, account, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");
 
        _balances[id][account] = _balances[id][account].sub(
            amount,
            "ERC1155: burn amount exceeds balance"
        );
 
        emit TransferSingle(operator, account, address(0), id, amount);

        if (balanceOf(account, id) == 0) {
            setRemove(account, id);
        }
    }
 
    function _burnBatch(address account, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
 
        address operator = _msgSender();
 
        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");
 
        for (uint i = 0; i < ids.length; i++) {
            _balances[ids[i]][account] = _balances[ids[i]][account].sub(
                amounts[i],
                "ERC1155: burn amount exceeds balance"
            );
        }
 
        emit TransferBatch(operator, account, address(0), ids, amounts);
        for (uint i = 0; i < ids.length; i++) {
            if (balanceOf(account, ids[i]) == 0) {
                setRemove(account, ids[i]);
        }
        }
    }
 
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal virtual
    { }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        private
    {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver(to).onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
 
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        private
    {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
                if (response != IERC1155Receiver(to).onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
 
    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }
    
    function setAdd(address owner, uint256 value) internal returns (bool) {
        if (!setContains(owner, value)) {
            holderTokens[owner]._values.push(value);
            holderTokens[owner]._indexes[value] = holderTokens[owner]._values.length;
            owners[value]._values.push(owner);
            owners[value]._indexes[owner] = owners[value]._values.length;

            return true;
        } else {
            return false;
        }
    }

    function setRemove(address owner, uint256 value) internal returns (bool) {
        uint256 valueIndex = holderTokens[owner]._indexes[value];
        uint256 ownerIndex = owners[value]._indexes[owner];

        if (valueIndex != 0) {
            
            uint256 toDeleteValueIndex = valueIndex - 1;
            uint256 lastIndex = holderTokens[owner]._values.length - 1;
            uint256 lastValue = holderTokens[owner]._values[lastIndex];
            holderTokens[owner]._values[toDeleteValueIndex] = lastValue;
            holderTokens[owner]._indexes[lastValue] = toDeleteValueIndex + 1;
            holderTokens[owner]._values.pop();
            delete holderTokens[owner]._indexes[value];

            uint256 toDeleteOwnerIndex = ownerIndex - 1;
            lastIndex = owners[value]._values.length - 1;
            address lastAddress = owners[value]._values[lastIndex];
            owners[value]._values[toDeleteOwnerIndex] = lastAddress;
            owners[value]._indexes[lastAddress] = toDeleteOwnerIndex + 1;
            owners[value]._values.pop();
            delete owners[value]._indexes[owner];

            return true;
        } else {
            return false;
        }
    }

    function setContains(address owner, uint256 value) public view returns (bool) {
        return holderTokens[owner]._indexes[value] != 0;
    }

    
}

contract CryptoBomberBasic is ERC1155,Ownable{
    
    string public name;
   
    string public symbol;
   
    mapping (address => bool) private minterUser;
    
    modifier onlyMinter() {
        require(isMinter(_msgSender()) || owner() == _msgSender(), "MinterRole: caller does not have the Minter role or above");
        _;
    }
    
   constructor() ERC1155("https://cbomber.io/api/basic/") 
    {
        name = "CryptoBomber Basic NFT";
        symbol = "CBBN";
    }

    function isMinter(address account) public view returns (bool) {
        return minterUser[account];
    }

    function addMinter(address account) public onlyOwner{
        minterUser[account] = true;
    }

    function removeMinter(address account) public onlyOwner{
        minterUser[account] = false;
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyMinter
    {   
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyMinter
    {
        _mintBatch(to, ids, amounts, data);
    }

    function burn(address account, uint256 id, uint256 value) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _burn(account, id, value);
    }

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _burnBatch(account, ids, values);
    }
    
}