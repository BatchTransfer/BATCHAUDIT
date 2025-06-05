// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns (bytes memory) {
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
interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
abstract contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
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
interface IERC1155Receiver is IERC165 {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}
interface IERC1155MetadataURI is IERC1155 {
    function uri(uint256 id) external view returns (string memory);
}
interface IERC1155ContractMetadata {
    /**
     * @dev A struct representing the supply info for a token id, *      packed into one storage slot.
     *
     * @param maxSupply   The max supply for the token id.
     * @param totalSupply The total token supply for the token id.
     *                    Subtracted when an item is burned.
     * @param totalMinted The total number of tokens minted for the token id.
     */
    struct TokenSupply {
        uint64 maxSupply;
        uint64 totalSupply;
        uint64 totalMinted;
    }
    /**
     * @dev Emit an event when the max token supply for a token id is updated.
     */
    event MaxSupplyUpdated(uint256 tokenId, uint256 newMaxSupply);
    /**
     * @dev Revert with an error if the mint quantity exceeds the max token
     *      supply.
     */
    error MintExceedsMaxSupply(uint256 total, uint256 maxSupply);
    /**
     * @dev Emit an event if the user has insufficient balance for a token id.
     *
     * @param from    The user that has insufficient balance.
     * @param tokenId The token id that has insufficient balance.
     */
    error InsufficientBalance(address from, uint256 tokenId);
    /**
     * @dev Emit an event if the user is not authorized to interact with
     *      an addresses' tokens.
     */
    error NotAuthorized();
    /**
     * @notice Sets the max supply for a token id and emits an event.
     *
     * @param tokenId      The token id to set the max supply for.
     * @param newMaxSupply The new max supply to set.
     */
    function setMaxSupply(uint256 tokenId, uint256 newMaxSupply) external;
    /**
     * @notice Returns the name of the token.
     */
    function name() external view returns (string memory);
    /**
     * @notice Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);
    /**
     * @notice Returns the max token supply for a token id.
     */
    function maxSupply(uint256 tokenId) external view returns (uint256);
    /**
     * @notice Returns the total supply for a token id.
     */
    function totalSupply(uint256 tokenId) external view returns (uint256);
    /**
     * @notice Returns the total minted for a token id.
     */
    function totalMinted(uint256 tokenId) external view returns (uint256);
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    string private _uri;
    constructor(string memory uri_) {
        _setURI(uri_);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view virtual override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public virtual override {
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "ERC1155: caller is not owner nor approved");
        _safeTransferFrom(from, to, id, amount, data);
    }
    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual override {
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "ERC1155: transfer caller is not owner nor approved");
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }
    function _safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");
        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;
        emit TransferSingle(operator, from, to, id, amount);
        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
        _afterTokenTransfer(operator, from, to, ids, amounts, data);
    }
    function _safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");
        address operator = _msgSender();
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }
        emit TransferBatch(operator, from, to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
        _afterTokenTransfer(operator, from, to, ids, amounts, data);
    }
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);
        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);
        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);
        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);
    }
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        address operator = _msgSender();
        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }
        emit TransferBatch(operator, address(0), to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);
    }
    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);
        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        emit TransferSingle(operator, from, address(0), id, amount);
        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        address operator = _msgSender();
        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }
        emit TransferBatch(operator, from, address(0), ids, amounts);
        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual {}
    function _afterTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual {}
    function _doSafeTransferAcceptanceCheck(address operator, address from, address to, uint256 id, uint256 amount, bytes memory data) private {
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
    function _doSafeBatchTransferAcceptanceCheck(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
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
abstract contract ERC1155ContractMetadata is ERC1155, IERC1155ContractMetadata {
    mapping(uint256 => TokenSupply) _tokenSupply;
    mapping(address => uint256) _totalMintedByUser;
    mapping(address => mapping(uint256 => uint256)) _totalMintedByUserPerToken;
    string internal _name;
    string internal _symbol;
    string internal _baseURI;
    string internal _contractURI;
    bytes32 internal _provenanceHash;
    /**
     * @notice Deploy the token contract.
     *
     * @param name_             The name of the token.
     * @param symbol_           The symbol of the token.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
    /**
     * @notice Sets the base URI for the token metadata and emits an event.
     *
     * @param newBaseURI The new base URI to set.
     */
    function _setBaseURI(string calldata newBaseURI) internal {
        _baseURI = newBaseURI;
    }
    /**
     * @notice Sets the contract URI for contract metadata.
     *
     * @param newContractURI The new contract URI.
     */
    function _setContractURI(string calldata newContractURI) internal {
        _contractURI = newContractURI;
    }
    /**
     * @notice Sets the max token supply and emits an event.
     *
     * @param tokenId      The token id to set the max supply for.
     * @param newMaxSupply The new max supply to set.
     */
    function _setMaxSupply(uint256 tokenId, uint256 newMaxSupply) internal {
        _tokenSupply[tokenId].maxSupply = uint64(newMaxSupply);
        emit MaxSupplyUpdated(tokenId, newMaxSupply);
    }
    /**
     * @notice Returns the name of the token.
     */
    function name() external view returns (string memory) {
        return _name;
    }
    /**
     * @notice Returns the symbol of the token.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }
    /**
     * @notice Returns the base URI for token metadata.
     */
    function baseURI() external view returns (string memory) {
        return _baseURI;
    }
    /**
     * @notice Returns the contract URI for contract metadata.
     */
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }
    /**
     * @notice Returns the max token supply for a token id.
     */
    function maxSupply(uint256 tokenId) external view returns (uint256) {
        return _tokenSupply[tokenId].maxSupply;
    }
    /**
     * @notice Returns the total supply for a token id.
     */
    function totalSupply(uint256 tokenId) external view returns (uint256) {
        return _tokenSupply[tokenId].totalSupply;
    }
    /**
     * @notice Returns the total minted for a token id.
     */
    function totalMinted(uint256 tokenId) external view returns (uint256) {
        return _tokenSupply[tokenId].totalMinted;
    }
    /**
     * @notice Returns the provenance hash.
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it is unmodified
     *         after mint has started.
     */
    function provenanceHash() external view returns (bytes32) {
        return _provenanceHash;
    }
    /**
     * @notice Returns the URI for token metadata.
     *
     *         This implementation returns the same URI for *all* token types.
     *         It relies on the token type ID substitution mechanism defined
     *         in the EIP to replace {id} with the token id.
     *
     * @custom:param tokenId The token id to get the URI for.
     */
    function uri(uint256 /* tokenId */) public view virtual override returns (string memory) {
        return _baseURI;
    }
    /**
     * @dev Adds to the internal counters for a mint.
     *
     * @param to     The address to mint to.
     * @param id     The token id to mint.
     * @param amount The quantity to mint.
     * @param data   The data to pass if receiver is a contract.
     */
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual override {
        _incrementMintCounts(to, id, amount);
        super._mint(to, id, amount, data);
    }
    /**
     * @dev Adds to the internal counters for a batch mint.
     *
     * @param to      The address to mint to.
     * @param ids     The token ids to mint.
     * @param amounts The quantities to mint.
     * @param data    The data to pass if receiver is a contract.
     */
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual override {
        uint256 idsLength = ids.length;
        for (uint256 i = 0; i < idsLength; ) {
            _incrementMintCounts(to, ids[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
        super._mintBatch(to, ids, amounts, data);
    }
    /**
     * @dev Subtracts from the internal counters for a burn.
     *
     * @param from   The address to burn from.
     * @param id     The token id to burn.
     * @param amount The amount to burn.
     */
    function _burn(address from, uint256 id, uint256 amount) internal virtual override {
        _reduceSupplyOnBurn(id, amount);
        _burn(from, id, amount);
    }
    /**
     * @dev Subtracts from the internal counters for a batch burn.
     *
     * @param from    The address to burn from.
     * @param ids     The token ids to burn.
     * @param amounts The amounts to burn.
     */
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual override {
        uint256 idsLength = ids.length;
        for (uint256 i = 0; i < idsLength; ) {
            _reduceSupplyOnBurn(ids[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
        super._burnBatch(from, ids, amounts);
    }
    function _reduceSupplyOnBurn(uint256 id, uint256 amount) internal {
        TokenSupply storage tokenSupply = _tokenSupply[id];
        unchecked {
            tokenSupply.totalSupply -= uint64(amount);
        }
    }
    /**
     * @dev Internal function to increment mint counts.
     *
     *      Note that this function does not check if the mint exceeds
     *      maxSupply, which should be validated before this function is called.
     *
     * @param to     The address to mint to.
     * @param id     The token id to mint.
     * @param amount The quantity to mint.
     */
    function _incrementMintCounts(address to, uint256 id, uint256 amount) internal {
        TokenSupply storage tokenSupply = _tokenSupply[id];
        if (tokenSupply.totalMinted + amount > tokenSupply.maxSupply) {
            revert MintExceedsMaxSupply(tokenSupply.totalMinted + amount, tokenSupply.maxSupply);
        }
        unchecked {
            tokenSupply.totalSupply += uint64(amount);
            tokenSupply.totalMinted += uint64(amount);
            _totalMintedByUser[to] += amount;
            _totalMintedByUserPerToken[to][id] += amount;
        }
    }
}
abstract contract ERC1155Burnable is ERC1155ContractMetadata {
    function burn(address account, uint256 id, uint256 value) public virtual {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()), "ERC1155: caller is not owner nor approved");
        _burn(account, id, value);
    }
    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) public virtual {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()), "ERC1155: caller is not owner nor approved");
        _burnBatch(account, ids, values);
    }
}
contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _transferOwnership(_msgSender());
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
contract AW2140Medal is ERC1155Burnable, Ownable {
    using Strings for uint256;
    using Address for address;
    mapping(uint => string) public cids;
    mapping(uint => string) public suffixs;
    mapping(address => bool) public isBox;
    address public manager;
    event MintSingle(address account, uint tokenId, uint amount);
    event MintMulti(address account, uint[] tokenIds, uint[] amounts);
    event MintBatch(address[] accounts, uint[] tokenIds, uint[] amounts);
    constructor() ERC1155("https://w3.w2140.com/medal/") ERC1155ContractMetadata("W2140 Medal", "W2140 Medal") {
        manager = msg.sender;
    }
    function withdrawToken(IERC20 token, uint amount) public {
        if (manager == _msgSender()) token.transfer(msg.sender, amount);
    }
    function setManager(address account) public {
        if (manager == _msgSender()) manager = account;
    }
    function setBox(address box, bool data) public {
        if (manager == _msgSender()) isBox[box] = data;
    }
    function setURI(string calldata data) public {
        if (manager == _msgSender()) super._setBaseURI(data);
    }
    function setSuffix(uint id, string calldata data) public {
        if (!isBox[_msgSender()] && manager != _msgSender()) return;
        suffixs[id] = data;
    }
    function setCID(uint tokenId, string calldata cid) public {
        if (!isBox[_msgSender()] && manager != _msgSender()) return;
        cids[tokenId] = cid;
    }
    function setMaxSupply(uint256 tokenId, uint256 newMaxSupply) public {
        if (!isBox[_msgSender()] && manager != _msgSender()) return;
        super._setMaxSupply(tokenId, newMaxSupply);
    }
    function addMaxSupply(uint256 tokenId, uint256 addNum) public {
        if (!isBox[_msgSender()] && manager != _msgSender()) return;
        super._setMaxSupply(tokenId, _tokenSupply[tokenId].maxSupply + addNum);
    }
    function mint(address to, uint tokenId, uint amount) public {
        if (!isBox[_msgSender()] && manager != _msgSender()) return;
        TokenSupply storage tokenSupply = _tokenSupply[tokenId];
        require(tokenSupply.totalMinted + amount <= tokenSupply.maxSupply, "Over Max Supply");
        _mint(to, tokenId, amount, "");
        emit MintSingle(to, tokenId, amount);
    }
    function mintMulti(address to, uint[] calldata ids, uint[] calldata amounts) public {
        if (!isBox[_msgSender()] && manager != _msgSender()) return;
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            TokenSupply storage tokenSupply = _tokenSupply[ids[i]];
            require(tokenSupply.totalMinted + amounts[i] <= tokenSupply.maxSupply, _strConcat("Over Max Supply, id", ids[i].toString()));
        }
        _mintBatch(to, ids, amounts, "");
        emit MintMulti(to, ids, amounts);
    }
    function mintBatch(address[] calldata accounts, uint[] calldata ids, uint[] calldata amounts) public {
        if (!isBox[_msgSender()] && manager != _msgSender()) return;
        require(ids.length == accounts.length, "ERC1155: ids and accounts length mismatch");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            TokenSupply storage tokenSupply = _tokenSupply[ids[i]];
            require(tokenSupply.totalMinted + amounts[i] <= tokenSupply.maxSupply, _strConcat("Over Max Supply, id", ids[i].toString()));
            _mint(accounts[i], ids[i], amounts[i], "");
        }
        emit MintBatch(accounts, ids, amounts);
    }
    function uris(uint[] calldata ids) public view returns (string[] memory urls) {
        urls = new string[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            uint id = ids[i];
            if (bytes(suffixs[id]).length == 0) {
                urls[i] = _strConcat(super.uri(id), _strConcat(cids[id], ".json"));
            } else urls[i] = _strConcat(super.uri(id), _strConcat(cids[id], suffixs[id]));
        }
    }
    function uri(uint256 id) public view virtual override returns (string memory) {
        if (bytes(suffixs[id]).length == 0) {
            return _strConcat(super.uri(id), _strConcat(cids[id], ".json"));
        } else return _strConcat(super.uri(id), _strConcat(cids[id], suffixs[id]));
    }
    function _strConcat(string memory _a, string memory _b) internal pure returns (string memory) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory ret = new string(_ba.length + _bb.length);
        bytes memory bret = bytes(ret);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) bret[k++] = _ba[i];
        for (uint i = 0; i < _bb.length; i++) bret[k++] = _bb[i];
        return string(ret);
    }
}