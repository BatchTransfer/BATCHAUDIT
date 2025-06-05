// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
interface IERC1155 is IERC165 {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function approve(address spender, uint256 tokenId, uint256 amount) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function getApproved(address account, address spender, uint256 tokenId) external view returns (uint256);
    function isApprovedOrOwner(address account, address spender, uint256 tokenId, uint256 amount) external view returns (bool);
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
    function _exists(address account, uint256 tokenId) external view returns (bool);
}
struct LaunchpadNFTERC1155 {
    uint256 tokenId;
    string launchpad_id;
    uint256 percentage_of_shares;
    uint256 attr1;
    string attr2;
    uint256 attr3;
    string attr4;
    uint256 attr5;
    string attr6;
    uint256 attr7;
    string attr8;
}
interface LaunchpadNFTERC1155Core {
    function setNFTFactory(LaunchpadNFTERC1155 memory _launchpad, uint256 _tokenId) external;
    function safeMintNFT(address _addr, uint256 tokenId, uint256 amount) external;
    function safeBatchMintNFT(address _addr, uint256[] memory tokenId, uint256[] memory amount) external;
    function burnNFT(address _addr, uint256 tokenId, uint256 amount) external;
    function burnBatchNFT(address _addr, uint256[] memory ids, uint256[] memory amounts) external;
    function getAllNFT(uint256 _fromTokenId, uint256 _toTokenId) external view returns (LaunchpadNFTERC1155[] memory);
    function getLaunchpadFactory(uint256 _tokenId) external view returns (LaunchpadNFTERC1155 memory);
    function getLaunchpadToTokenId(string memory _launchpad_id) external view returns (uint256);
    function getNextNFTId() external view returns (uint256);
}
interface IERC1155Receiver is IERC165 {
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
abstract contract ERC165 is IERC165 {
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;
    mapping(bytes4 => bool) private _supportedInterfaces;
    constructor () {
        _registerInterface(_INTERFACE_ID_ERC165);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}
library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }
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
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
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
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _setOwner(_msgSender());
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }
    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
library EnumerableSet {
    struct Set {
        bytes32[] _values;
        mapping(bytes32 => uint256) _indexes;
    }
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;
            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];
                set._values[toDeleteIndex] = lastvalue;
                set._indexes[lastvalue] = valueIndex;
            }
            set._values.pop();
            delete set._indexes[value];
            return true;
        } else {
            return false;
        }
    }
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }
    struct Bytes32Set {
        Set _inner;
    }
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }
    struct AddressSet {
        Set _inner;
    }
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;
        assembly {
            result := store
        }
        return result;
    }
    struct UintSet {
        Set _inner;
    }
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;
        assembly {
            result := store
        }
        return result;
    }
}
interface ManagerInterface {
    function safeNFT(address _address) external view returns (bool);
    function safeTransferNFT(address _address) external view returns (bool);
}
contract ERC1155 is Context, ERC165, IERC1155, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => mapping(uint256 => uint256))) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    string private _uri;
    mapping(address => EnumerableSet.UintSet) private _holderTokens;
    ManagerInterface public manager;
    bool requireContractTransfer = true;
    mapping(address => bool) public blackList;
    uint256 totalNFT = 0;
    string private _name;
    string private _symbol;
    struct ListNFT {
        uint256 tokenId;
        uint256 qty;
    }
    bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 private constant _INTERFACE_ID_ERC1155_METADATA = 0x5b5e139f;
    bytes4 private constant ERC1155_ERC165_TOKENRECEIVER = 0x4e2312e0;
    bytes4 private constant ERC1155_ACCEPTED = 0xf23a6e61;
    bytes4 private constant ERC1155_BATCH_ACCEPTED = 0xbc197c81;
    constructor(string memory uri_, address _manager, string memory name_, string memory symbol_) {
        _setURI(uri_);
        manager = ManagerInterface(_manager);
        _name = name_;
        _symbol = symbol_;
        _registerInterface(_INTERFACE_ID_ERC1155);
        _registerInterface(_INTERFACE_ID_ERC1155_METADATA);
        _registerInterface(ERC1155_ERC165_TOKENRECEIVER);
        _registerInterface(ERC1155_ACCEPTED);
        _registerInterface(ERC1155_BATCH_ACCEPTED);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId || super.supportsInterface(interfaceId);
    }
    function setManager(address _addr) external onlyOwner {
        manager = ManagerInterface(_addr);
    }
    function setRequireContractTransfer(bool _block) external onlyOwner {
        requireContractTransfer = _block;
    }
    function setBlackList(address _user, bool _block) onlyOwner public {
        blackList[_user] = _block;
    }
    function totalSupply() public view virtual returns (uint256) {
        return totalNFT;
    }
    function _exists(address account, uint256 tokenId) public view virtual override returns (bool) {
        return balanceOf(account,tokenId) > 0;
    }
    function totalNFTOwner(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ERC1155: balance query for the zero address");
        return _holderTokens[owner].length();
    }
    function tokenOfOwner(address owner) public view virtual returns (ListNFT[] memory) {
        require(owner != address(0), "ERC1155: query for the zero address");
        ListNFT[] memory array = new ListNFT[](_holderTokens[owner].length());
        for (uint256 i = 0; i < _holderTokens[owner].length(); ++i) {
            uint256 _tokenId = _holderTokens[owner].at(i);
            array[i] = ListNFT({tokenId: _tokenId, qty: _balances[_tokenId][owner]});
        }
        return array;
    }
    function name() public view virtual returns (string memory) {
        return _name;
    }
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    function tokenURI(uint256 _tokenId) public view virtual returns (string memory) {
        require(_tokenId <= totalNFT, "token id not found");
        return string(abi.encodePacked(_uri, _tokenId.toString(), ".json"));
    }
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }
    function approve(address spender, uint256 tokenId, uint256 amount) public virtual override {
        require(_msgSender() != spender, "ERC1155: setting approval status for self");
        _tokenApprovals[_msgSender()][spender][tokenId] = amount;
    }
    function getApproved(address account, address spender, uint256 tokenId) public view virtual override returns (uint256) {
        return _tokenApprovals[account][spender][tokenId];
    }
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(_msgSender() != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }
    function clearApprovalForAll(address from, address to, uint256 tokenId, uint256 amount) internal virtual {
        _operatorApprovals[from][to] = false;
        if(from != to && tokenId > 0) {
            _tokenApprovals[from][to][tokenId] -= amount;
        }
    }
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }
    function isApprovedOrOwner(address account, address spender, uint256 tokenId, uint256 amount) public view virtual override returns (bool) {
        return (isApprovedForAll(account, spender) || getApproved(account, spender, tokenId) >= amount);
    }
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedOrOwner(from, _msgSender(), id, amount),
            "ERC1155: caller is not owner nor approved"
        );
        require(
            ERC1155._exists(from, id) == true,
            "ERC1155: operator query for nonexistent token"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(blackList[from] == false && blackList[to] == false, "owner has been blacklist");
        if (requireContractTransfer == true) {
            require(manager.safeTransferNFT(_msgSender()) == true, "ERC1155: Block transfer to the address");
        }
        require(to != address(0), "ERC1155: transfer to the zero address");
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;
        _holderTokens[to].add(id);
        if(_balances[id][from] == 0) {
            _holderTokens[from].remove(id);
        }
        clearApprovalForAll(from, _msgSender(), id, amount);
        emit TransferSingle(_msgSender(), from, to, id, amount);
        _doSafeTransferAcceptanceCheck(_msgSender(), from, to, id, amount, data);
    }


    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(blackList[from] == false && blackList[to] == false, "owner has been locked");
        if (requireContractTransfer == true) {
            require(manager.safeTransferNFT(_msgSender()) == true, "ERC1155: Block transfer to the address");
        }
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            require(ERC1155._exists(from, id) == true, "ERC1155: operator query for nonexistent token");
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
            _holderTokens[to].add(id);

            if(_balances[id][from] == 0) {
                _holderTokens[from].remove(id);
            }
        }
        clearApprovalForAll(from, _msgSender(), 0, 0);
        emit TransferBatch(_msgSender(), from, to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(_msgSender(), from, to, ids, amounts, data);
    }
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }
    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(account != address(0), "ERC1155: mint to the zero address");
        require(blackList[account] == false, "owner has been locked");
        _balances[id][account] += amount;
        _holderTokens[account].add(id);
        if (id > totalNFT) {
            totalNFT += 1;
        }
        emit TransferSingle(_msgSender(), address(0), account, id, amount);
        _doSafeTransferAcceptanceCheck(_msgSender(), address(0), account, id, amount, data);
    }
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(blackList[to] == false, "owner has been locked");
        uint tid = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
            _holderTokens[to].add(ids[i]);
            if (ids[i] > totalNFT) {
                tid += 1;
            }
        }
        if(tid > 0) {
            totalNFT += tid;
        }
        emit TransferBatch(_msgSender(), address(0), to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(_msgSender(), address(0), to, ids, amounts, data);
    }
    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ERC1155._exists(account, id) == true, "ERC1155: operator query for nonexistent token");
        uint256 accountBalance = _balances[id][account];
        require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][account] = accountBalance - amount;
        }
        if(_balances[id][account] == 0) {
            _holderTokens[account].remove(id);
        }
        emit TransferSingle(_msgSender(), account, address(0), id, amount);
    }
    function _burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            require(ERC1155._exists(account, id) == true, "ERC1155: operator query for nonexistent token");
            uint256 accountBalance = _balances[id][account];
            require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][account] = accountBalance - amount;
            }
            if(_balances[id][account] == 0) {
                _holderTokens[account].remove(id);
            }
        }
        emit TransferBatch(_msgSender(), account, address(0), ids, amounts);
    }
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
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
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
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
}
contract LaunchpadNFTERC1155Contract is LaunchpadNFTERC1155Core, ERC1155 {
    using SafeMath for uint256;
    using Strings for uint256;
    using Address for address;
    event AddLaunchpadFactory(uint256 indexed tokenId);
    mapping(uint256 => LaunchpadNFTERC1155) private LaunchpadFactory;
    mapping(string => uint256) private LaunchpadToTokenId;
    modifier onlySafeNFT() {
        require(manager.safeNFT(msg.sender) == true, "require Safe Address.");
        _;
    }
    modifier onlySafeTransferNFT() {
        require(manager.safeTransferNFT(msg.sender) == true, "require Safe Transfer Address.");
        _;
    }
    constructor(
        string memory baseURI,
        address _manager
    ) ERC1155(baseURI, _manager, "Heralding Platform", "HeraldingNFT") {}
    function SwapExactToken(address coinAddress, uint256 value, address payable to) public onlyOwner {
        if (coinAddress == address(0)) {
            return to.transfer(value);
        }
        IERC20(coinAddress).transfer(to, value);
    }
    function safeMintNFT(address _addr, uint256 tokenId, uint256 amount) external override onlySafeNFT {
        _mint(_addr, tokenId, amount, "0x0");
    }
    function safeBatchMintNFT(address _addr, uint256[] memory tokenId, uint256[] memory amount) external override onlySafeNFT {
        _mintBatch(_addr, tokenId, amount, "0x0");
    }
    function burnNFT(address _addr, uint256 tokenId, uint256 amount) external override onlySafeTransferNFT {
        _burn(_addr, tokenId, amount);
    }
    function burnBatchNFT(address _addr, uint256[] memory ids, uint256[] memory amounts) external override onlySafeTransferNFT {
        _burnBatch(_addr, ids, amounts);
    }
    function changeBaseURI(string memory baseURI) public onlyOwner {
        _setURI(baseURI);
    }
    function setNFTFactory(LaunchpadNFTERC1155 memory _launchpad, uint256 _tokenId) external override onlySafeNFT {
        if (LaunchpadFactory[_tokenId].tokenId > 0 && bytes(LaunchpadFactory[_tokenId].launchpad_id).length != bytes(_launchpad.launchpad_id).length) {
            delete LaunchpadToTokenId[LaunchpadFactory[_tokenId].launchpad_id];
        }
        LaunchpadFactory[_tokenId] = _launchpad;
        LaunchpadToTokenId[_launchpad.launchpad_id] = _tokenId;
        emit AddLaunchpadFactory(_tokenId);
    }
    function getAllNFT(uint256 _fromTokenId, uint256 _toTokenId) external view override returns (LaunchpadNFTERC1155[] memory) {
        uint256 total = _toTokenId - _fromTokenId;
        require(total >= 0, "_toTokenId must be greater than _fromTokenId");
        LaunchpadNFTERC1155[] memory allLaunchpad = new LaunchpadNFTERC1155[](total);
        uint256 count = 0;
        for (uint256 index = _fromTokenId; index <= _toTokenId; index++) {
            allLaunchpad[count] = LaunchpadFactory[index];
            ++count;
        }
        return allLaunchpad;
    }
    function getLaunchpadFactory(uint256 _tokenId) external view override returns (LaunchpadNFTERC1155 memory){
        return LaunchpadFactory[_tokenId];
    }
    function getLaunchpadToTokenId(string memory _launchpad_id) external view override returns (uint256){
        return LaunchpadToTokenId[_launchpad_id];
    }
    function getNextNFTId() external view override returns (uint256){
        return totalSupply().add(1);
    }
}