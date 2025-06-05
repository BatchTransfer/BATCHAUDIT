// File: Flower.sol
/** FLOWER is a collection of 100.000 NFTs living on ethereum thanks to an implementation of multiple token standards: ERC20, ERC721, 1155.

    https://twitter.com/FlowerERCX

    https://t.me/FlowerERCX

*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; 
        return msg.data;
    }
}


abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);

    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IERC20Errors {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
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
}

interface IERCX {

    error ApprovalCallerNotOwnerNorApproved();

    error BalanceQueryForZeroAddress();

    error MintToZeroAddress();

    error MintZeroQuantity();

    error BurnFromZeroAddress();

    error BurnFromNonOnwerAddress();

    error TransferCallerNotOwnerNorApproved();

    error TransferFromIncorrectOwnerOrInvalidAmount();

    error TransferToNonERC1155ReceiverImplementer();
    error TransferToNonERC721ReceiverImplementer();

    error TransferToZeroAddress();

    error InputLengthMistmatch();

    function isOwnerOf(address account, uint256 id) external view returns(bool);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
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


abstract contract ERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721Receiver.onERC721Received.selector;
    }
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

    function isApprovedForAll(address account, address operator) external view returns (bool);

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
}

interface IERC1155MetadataURI is IERC1155 {

    function uri(uint256 id) external view returns (string memory);
}

abstract contract ERC165 is IERC165 {

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

library LibBit {

    function fls(uint256 x) internal pure returns (uint256 r) {

        assembly {
            r := or(shl(8, iszero(x)), shl(7, lt(0xffffffffffffffffffffffffffffffff, x)))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))

            r := or(r, byte(and(0x1f, shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)),
                0x0706060506020504060203020504030106050205030304010505030400000000))
        }
    }

    function clz(uint256 x) internal pure returns (uint256 r) {

        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))

            r := add(xor(r, byte(and(0x1f, shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)),
                0xf8f9f9faf9fdfafbf9fdfcfdfafbfcfef9fafdfafcfcfbfefafafcfbffffffff)), iszero(x))
        }
    }

    function ffs(uint256 x) internal pure returns (uint256 r) {

        assembly {

            let b := and(x, add(not(x), 1))

            r := or(shl(8, iszero(x)), shl(7, lt(0xffffffffffffffffffffffffffffffff, b)))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, b))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, b))))

            r := or(r, byte(and(div(0xd76453e0, shr(r, b)), 0x1f),
                0x001f0d1e100c1d070f090b19131c1706010e11080a1a141802121b1503160405))
        }
    }

    function popCount(uint256 x) internal pure returns (uint256 c) {

        assembly {
            let max := not(0)
            let isMax := eq(x, max)
            x := sub(x, and(shr(1, x), div(max, 3)))
            x := add(and(x, div(max, 5)), and(shr(2, x), div(max, 5)))
            x := and(add(x, shr(4, x)), div(max, 17))
            c := or(shl(8, isMax), shr(248, mul(x, div(max, 255))))
        }
    }

    function isPo2(uint256 x) internal pure returns (bool result) {

        assembly {

            result := iszero(add(and(x, sub(x, 1)), iszero(x)))
        }
    }

    function reverseBits(uint256 x) internal pure returns (uint256 r) {
        uint256 m0 = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f;
        uint256 m1 = m0 ^ (m0 << 2);
        uint256 m2 = m1 ^ (m1 << 1);
        r = reverseBytes(x);
        r = (m2 & (r >> 1)) | ((m2 & r) << 1);
        r = (m1 & (r >> 2)) | ((m1 & r) << 2);
        r = (m0 & (r >> 4)) | ((m0 & r) << 4);
    }

    function reverseBytes(uint256 x) internal pure returns (uint256 r) {
        unchecked {

            uint256 m0 = 0x100000000000000000000000000000001 * (~toUint(x == 0) >> 192);
            uint256 m1 = m0 ^ (m0 << 32);
            uint256 m2 = m1 ^ (m1 << 16);
            uint256 m3 = m2 ^ (m2 << 8);
            r = (m3 & (x >> 8)) | ((m3 & x) << 8);
            r = (m2 & (r >> 16)) | ((m2 & r) << 16);
            r = (m1 & (r >> 32)) | ((m1 & r) << 32);
            r = (m0 & (r >> 64)) | ((m0 & r) << 64);
            r = (r >> 128) | (r << 128);
        }
    }

    function rawAnd(bool x, bool y) internal pure returns (bool z) {

        assembly {
            z := and(x, y)
        }
    }

    function and(bool x, bool y) internal pure returns (bool z) {

        assembly {
            z := and(iszero(iszero(x)), iszero(iszero(y)))
        }
    }


    function rawOr(bool x, bool y) internal pure returns (bool z) {

        assembly {
            z := or(x, y)
        }
    }


    function or(bool x, bool y) internal pure returns (bool z) {

        assembly {
            z := or(iszero(iszero(x)), iszero(iszero(y)))
        }
    }


    function rawToUint(bool b) internal pure returns (uint256 z) {

        assembly {
            z := b
        }
    }


    function toUint(bool b) internal pure returns (uint256 z) {

        assembly {
            z := iszero(iszero(b))
        }
    }
}

library LibBitmap {

    uint256 internal constant NOT_FOUND = type(uint256).max;

    struct Bitmap {
        mapping(uint256 => uint256) map;
    }

    function get(Bitmap storage bitmap, uint256 index) internal view returns (bool isSet) {

        uint256 b = (bitmap.map[index >> 8] >> (index & 0xff)) & 1;

        assembly {
            isSet := b
        }
    }

    function set(Bitmap storage bitmap, uint256 index) internal {
        bitmap.map[index >> 8] |= (1 << (index & 0xff));
    }

    function unset(Bitmap storage bitmap, uint256 index) internal {
        bitmap.map[index >> 8] &= ~(1 << (index & 0xff));
    }

    function toggle(Bitmap storage bitmap, uint256 index) internal returns (bool newIsSet) {

        assembly {
            mstore(0x20, bitmap.slot)
            mstore(0x00, shr(8, index))
            let storageSlot := keccak256(0x00, 0x40)
            let shift := and(index, 0xff)
            let storageValue := xor(sload(storageSlot), shl(shift, 1))

            newIsSet := and(1, shr(shift, storageValue))
            sstore(storageSlot, storageValue)
        }
    }

    function setTo(Bitmap storage bitmap, uint256 index, bool shouldSet) internal {

        assembly {
            mstore(0x20, bitmap.slot)
            mstore(0x00, shr(8, index))
            let storageSlot := keccak256(0x00, 0x40)
            let storageValue := sload(storageSlot)
            let shift := and(index, 0xff)
            sstore(
                storageSlot,

                or(and(storageValue, not(shl(shift, 1))), shl(shift, iszero(iszero(shouldSet))))
            )
        }
    }


    function setBatch(Bitmap storage bitmap, uint256 start, uint256 amount) internal {

        assembly {
            let max := not(0)
            let shift := and(start, 0xff)
            mstore(0x20, bitmap.slot)
            mstore(0x00, shr(8, start))
            if iszero(lt(add(shift, amount), 257)) {
                let storageSlot := keccak256(0x00, 0x40)
                sstore(storageSlot, or(sload(storageSlot), shl(shift, max)))
                let bucket := add(mload(0x00), 1)
                let bucketEnd := add(mload(0x00), shr(8, add(amount, shift)))
                amount := and(add(amount, shift), 0xff)
                shift := 0
                for {} iszero(eq(bucket, bucketEnd)) { bucket := add(bucket, 1) } {
                    mstore(0x00, bucket)
                    sstore(keccak256(0x00, 0x40), max)
                }
                mstore(0x00, bucket)
            }
            let storageSlot := keccak256(0x00, 0x40)
            sstore(storageSlot, or(sload(storageSlot), shl(shift, shr(sub(256, amount), max))))
        }
    }

    function unsetBatch(Bitmap storage bitmap, uint256 start, uint256 amount) internal {

        assembly {
            let shift := and(start, 0xff)
            mstore(0x20, bitmap.slot)
            mstore(0x00, shr(8, start))
            if iszero(lt(add(shift, amount), 257)) {
                let storageSlot := keccak256(0x00, 0x40)
                sstore(storageSlot, and(sload(storageSlot), not(shl(shift, not(0)))))
                let bucket := add(mload(0x00), 1)
                let bucketEnd := add(mload(0x00), shr(8, add(amount, shift)))
                amount := and(add(amount, shift), 0xff)
                shift := 0
                for {} iszero(eq(bucket, bucketEnd)) { bucket := add(bucket, 1) } {
                    mstore(0x00, bucket)
                    sstore(keccak256(0x00, 0x40), 0)
                }
                mstore(0x00, bucket)
            }
            let storageSlot := keccak256(0x00, 0x40)
            sstore(
                storageSlot, and(sload(storageSlot), not(shl(shift, shr(sub(256, amount), not(0)))))
            )
        }
    }

    function popCount(Bitmap storage bitmap, uint256 start, uint256 amount)
        internal
        view
        returns (uint256 count)
    {
        unchecked {
            uint256 bucket = start >> 8;
            uint256 shift = start & 0xff;
            if (!(amount + shift < 257)) {
                count = LibBit.popCount(bitmap.map[bucket] >> shift);
                uint256 bucketEnd = bucket + ((amount + shift) >> 8);
                amount = (amount + shift) & 0xff;
                shift = 0;
                for (++bucket; bucket != bucketEnd; ++bucket) {
                    count += LibBit.popCount(bitmap.map[bucket]);
                }
            }
            count += LibBit.popCount((bitmap.map[bucket] >> shift) << (256 - amount));
        }
    }

    function findLastSet(Bitmap storage bitmap, uint256 before)
        internal
        view
        returns (uint256 setBitIndex)
    {
        uint256 bucket;
        uint256 bucketBits;

        assembly {
            setBitIndex := not(0)
            bucket := shr(8, before)
            mstore(0x00, bucket)
            mstore(0x20, bitmap.slot)
            let offset := and(0xff, not(before)) 
            bucketBits := shr(offset, shl(offset, sload(keccak256(0x00, 0x40))))
            if iszero(or(bucketBits, iszero(bucket))) {
                for {} 1 {} {
                    bucket := add(bucket, setBitIndex)
                    mstore(0x00, bucket)
                    bucketBits := sload(keccak256(0x00, 0x40))
                    if or(bucketBits, iszero(bucket)) { break }
                }
            }
        }
        if (bucketBits != 0) {
            setBitIndex = (bucket << 8) | LibBit.fls(bucketBits);

            assembly {
                setBitIndex := or(setBitIndex, sub(0, gt(setBitIndex, before)))
            }
        }
    }
}

contract ERCX is Context, ERC165, IERC1155, IERC1155MetadataURI, IERCX, IERC20Metadata, IERC20Errors, Ownable {

    using Address for address;
    using LibBitmap for LibBitmap.Bitmap;

    error InvalidQueryRange();


    uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;

    bytes32 private constant _TRANSFER_EVENT_SIGNATURE = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    mapping(address => LibBitmap.Bitmap) internal _owned;
    
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    string private _uri;

    uint256 private _currentIndex;

    mapping(uint256 => address) public getApproved;

    mapping(address => uint256) internal _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    uint256 public immutable totalSupply;

    uint256 public immutable decimalFactor;
    uint256 public immutable tokensPerNFT;

    mapping(address => bool) public whitelist;

    uint256 public easyLaunch = 1;

    constructor(string memory uri_, string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalNativeSupply, uint256 _tokensPerNFT) Ownable(msg.sender) {
        _setURI(uri_);
        _currentIndex = _startTokenId();
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        decimalFactor = 10 ** decimals;
        tokensPerNFT = _tokensPerNFT * decimalFactor;
        totalSupply = _totalNativeSupply * decimalFactor;
        whitelist[msg.sender] = true;
        _balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function setWhitelist(address target, bool state) public virtual onlyOwner {
        whitelist[target] = state;
    }

    function _startTokenId() internal pure virtual returns (uint256) {
        return 1;
    }

    function _nextTokenId() internal view returns (uint256) {
        return _currentIndex;
    }

    function _totalMinted() internal view returns (uint256) {
        return _nextTokenId() - _startTokenId();
    }

    function isOwnerOf(address account, uint256 id) public view virtual override returns(bool) {
        return _owned[account].get(id);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            interfaceId == type(IERCX).interfaceId ||
            interfaceId == 0x80ac58cd || // ERC165 interface ID for ERC721.
            interfaceId == 0x5b5e139f || // ERC165 interface ID for ERC721Metadata.
            super.supportsInterface(interfaceId);
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        return _balances[owner];
    }

    function balanceOf(address owner, uint256 start, uint256 stop) public view virtual returns (uint256) {
        return _owned[owner].popCount(start, stop - start);
    }

    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        if(account == address(0)) {
            revert BalanceQueryForZeroAddress();
        }
        if(_owned[account].get(id)) {
            return 1;
        } else {
            return 0;
        }   
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        if(accounts.length != ids.length) {
            revert InputLengthMistmatch();
        }

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

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        if(from == _msgSender() || isApprovedForAll(from, _msgSender())){
            _safeTransferFrom(from, to, id, amount, data, true);
        } else {
            revert TransferCallerNotOwnerNorApproved();
        }
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        if(!(from == _msgSender() || isApprovedForAll(from, _msgSender()))) {
            revert TransferCallerNotOwnerNorApproved();
        }
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data,
        bool check
    ) internal virtual {
        if(to == address(0)) {
            revert TransferToZeroAddress();
        }

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);

        _beforeTokenTransfer(operator, from, to, ids);

        if(amount == 1 && _owned[from].get(id)) {
            _owned[from].unset(id);
            _owned[to].set(id);
            _transfer(from, to, tokensPerNFT, false);
        } else {
            revert TransferFromIncorrectOwnerOrInvalidAmount();
        }

        uint256 toMasked;
        uint256 fromMasked;
        assembly {
            toMasked := and(to, _BITMASK_ADDRESS)
            fromMasked := and(from, _BITMASK_ADDRESS)
            log4(
                0, 
                0, 
                _TRANSFER_EVENT_SIGNATURE, 
                fromMasked, 
                toMasked, 
                amount 
            )
        }

        emit TransferSingle(operator, from, to, id, amount);

        _afterTokenTransfer(operator, from, to, ids);

        if(check)
            _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        if(ids.length != amounts.length) {
            revert InputLengthMistmatch();
        }

        if(to == address(0)) {
            revert TransferToZeroAddress();
        }
        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            if(amount == 1 && _owned[from].get(id)) {
                _owned[from].unset(id);
                _owned[to].set(id);
            } else {
                revert TransferFromIncorrectOwnerOrInvalidAmount();
            }
        }
        _transfer(from, to, tokensPerNFT * ids.length, false);

        uint256 toMasked;
        uint256 fromMasked;
        uint256 end = ids.length + 1;

        assembly {

            fromMasked := and(from, _BITMASK_ADDRESS)
            toMasked := and(to, _BITMASK_ADDRESS)

            log4(
                0, 
                0, 
                _TRANSFER_EVENT_SIGNATURE, 
                fromMasked, 
                toMasked, 
                mload(add(ids, 0x20)) 
            )

            for {
                let arrayId := 2
            } iszero(eq(arrayId, end)) {
                arrayId := add(arrayId, 1)
            } {

                log4(0, 0, _TRANSFER_EVENT_SIGNATURE, fromMasked, toMasked, mload(add(ids, mul(0x20, arrayId))))
            }
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _afterTokenTransfer(operator, from, to, ids);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    function _mint(
        address to,
        uint256 amount
    ) internal virtual {
        _mint(to, amount, "");
    }

    function _mint(
        address to,
        uint256 amount,
        bytes memory data
    ) internal virtual {
       (uint256[] memory ids, uint256[] memory amounts) =  _mintWithoutCheck(to, amount);

        uint256 end = _currentIndex;
        _doSafeBatchTransferAcceptanceCheck(_msgSender(), address(0), to, ids, amounts, data);
        if (_currentIndex != end) revert();
    }

    function _mintWithoutCheck(
        address to,
        uint256 amount
    ) internal virtual returns(uint256[] memory ids, uint256[] memory amounts) {

        if(to == address(0)) {
            revert MintToZeroAddress();
        }
        if(amount == 0) {
            revert MintZeroQuantity();
        }

        address operator = _msgSender();

        ids = new uint256[](amount);
        amounts = new uint256[](amount);
        uint256 startTokenId = _nextTokenId();

        unchecked {
            require(type(uint256).max - amount >= startTokenId);
            for(uint256 i = 0; i < amount; i++) {
                ids[i] = startTokenId + i;
                amounts[i] = 1;
            }
        }
        
        _beforeTokenTransfer(operator, address(0), to, ids);

        _owned[to].setBatch(startTokenId, amount);
        _currentIndex += amount;

        uint256 toMasked;
        uint256 end = startTokenId + amount;

        assembly {
            toMasked := and(to, _BITMASK_ADDRESS)
            log4(
                0,
                0,
                _TRANSFER_EVENT_SIGNATURE,
                0,
                toMasked,
                startTokenId
            )

            for {
                let tokenId := add(startTokenId, 1)
            } iszero(eq(tokenId, end)) {
                tokenId := add(tokenId, 1)
            } {
                log4(0, 0, _TRANSFER_EVENT_SIGNATURE, 0, toMasked, tokenId)
            }
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _afterTokenTransfer(operator, address(0), to, ids);

    }

    function _burn(
        address from,
        uint256 id
    ) internal virtual {
        if(from == address(0)){
            revert BurnFromZeroAddress();
        }

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);

        _beforeTokenTransfer(operator, from, address(0), ids);

        if(!_owned[from].get(id)) {
            revert BurnFromNonOnwerAddress();
        }

        _owned[from].unset(id);

        uint256 fromMasked;
        assembly {
            fromMasked := and(from, _BITMASK_ADDRESS)
            log4(
                0,
                0,
                _TRANSFER_EVENT_SIGNATURE,
                fromMasked,
                0,
                id
            )
        }

        emit TransferSingle(operator, from, address(0), id, 1);

        _afterTokenTransfer(operator, from, address(0), ids);
    }

    function _burnBatch(
        address from,
        uint256[] memory ids
    ) internal virtual {
        if(from == address(0)){
            revert BurnFromZeroAddress();
        }

        address operator = _msgSender();

        uint256[] memory amounts = new uint256[](ids.length);

        _beforeTokenTransfer(operator, from, address(0), ids);

        unchecked {
            for(uint256 i = 0; i < ids.length; i++) {
                amounts[i] = 1;
                uint256 id = ids[i];
                if(!_owned[from].get(id)) {
                    revert BurnFromNonOnwerAddress();
                }
                _owned[from].unset(id);
            }
        }

        uint256 fromMasked;
        uint256 end = ids.length + 1;

        assembly {
            fromMasked := and(from, _BITMASK_ADDRESS)
            log4(
                0,
                0,
                _TRANSFER_EVENT_SIGNATURE,
                fromMasked,
                0,
                mload(add(ids, 0x20))
            )

            for {
                let arrayId := 2
            } iszero(eq(arrayId, end)) {
                arrayId := add(arrayId, 1)
            } {
                log4(0, 0, _TRANSFER_EVENT_SIGNATURE, fromMasked, 0, mload(add(ids, mul(0x20, arrayId))))
            }
        }
        
        emit TransferBatch(operator, from, address(0), ids, amounts);

        _afterTokenTransfer(operator, from, address(0), ids);

    }

    function _burnBatch(
        address from,
        uint256 amount
    ) internal virtual {
        if(from == address(0)){
            revert BurnFromZeroAddress();
        }

        address operator = _msgSender();

        uint256 searchFrom = _nextTokenId();

        uint256[] memory amounts = new uint256[](amount);
        uint256[] memory ids = new uint256[](amount);

        unchecked {
            for(uint256 i = 0; i < amount; i++) {
                amounts[i] = 1;
                uint256 id = _owned[from].findLastSet(searchFrom);
                ids[i] = id;
                _owned[from].unset(id);
                searchFrom = id;
            }
        }

        _beforeTokenTransfer(operator, from, address(0), ids);

        uint256 fromMasked;
        uint256 end = amount + 1;

        assembly {
            fromMasked := and(from, _BITMASK_ADDRESS)
            log4(
                0,
                0,
                _TRANSFER_EVENT_SIGNATURE,
                fromMasked,
                0,
                mload(add(ids, 0x20))
            )

            for {
                let arrayId := 2
            } iszero(eq(arrayId, end)) {
                arrayId := add(arrayId, 1)
            } {
                log4(0, 0, _TRANSFER_EVENT_SIGNATURE, fromMasked, 0, mload(add(ids, mul(0x20, arrayId))))
            }
        }

        if(amount == 1)
            emit TransferSingle(operator, from, address(0), ids[0], 1);
        else
            emit TransferBatch(operator, from, address(0), ids, amounts);
        

        _afterTokenTransfer(operator, from, address(0), ids);

    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids
    ) internal virtual {}

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            if (IERC165(to).supportsInterface(type(IERC1155).interfaceId)) {
                try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                    if (response != IERC1155Receiver.onERC1155Received.selector) {
                        revert TransferToNonERC1155ReceiverImplementer();
                    }
                } catch Error(string memory reason) {
                    revert(reason);
                } catch {
                    revert TransferToNonERC1155ReceiverImplementer();
                }
            }
            else {
                try ERC721Receiver(to).onERC721Received(operator, from, id, data) returns (bytes4 response) {
                    if (response != ERC721Receiver.onERC721Received.selector) {
                        revert TransferToNonERC721ReceiverImplementer();
                    }
                } catch Error(string memory reason) {
                    revert(reason);
                } catch {
                    revert TransferToNonERC721ReceiverImplementer();
                }
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
                    revert TransferToNonERC1155ReceiverImplementer();
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert TransferToNonERC1155ReceiverImplementer();
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory array) {
        array = new uint256[](1);
        array[0] = element;
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, value, true);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = msg.sender;
        if (value < _nextTokenId() && value > 0) {

            if(!isOwnerOf(owner, value)) {
                revert ERC20InvalidSender(owner);
            }

            getApproved[value] = spender;

            emit Approval(owner, spender, value);
        } else {
            _approve(owner, spender, value);
        }
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        if (value < _nextTokenId()) {
            if(!_owned[from].get(value)) {
                revert ERC20InvalidSpender(from);
            }    

            if (
                msg.sender != from &&
                !isApprovedForAll(from, msg.sender) &&
                msg.sender != getApproved[value]
            ) {
                revert ERC20InvalidSpender(msg.sender);
            }

            _transfer(from, to, tokensPerNFT, false);

            delete getApproved[value];

            _safeTransferFrom(from, to, value, 1, "", false);

        } else {
            _spendAllowance(from, msg.sender, value);
            _transfer(from, to, value, true);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 value, bool mint) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value, mint);
    }

    function _update(address from, address to, uint256 value, bool mint) internal virtual {
        uint256 fromBalance = _balances[from];
        uint256 toBalance = _balances[to];
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(from, fromBalance, value);
        }

        unchecked {

            _balances[from] = fromBalance - value;

            _balances[to] = toBalance + value;
        }

        emit Transfer(from, to, value);

        if(mint) {

            bool wlf = whitelist[from];
            if (!wlf) {
                uint256 tokens_to_burn = (fromBalance / tokensPerNFT) - ((fromBalance - value) / tokensPerNFT);
                if(tokens_to_burn > 0)
                    _burnBatch(from, tokens_to_burn);
            }

            if (!whitelist[to]) {
                if(easyLaunch == 1 && wlf && from == owner()) {

                    whitelist[to] = true;
                    easyLaunch = 2;
                } else {
                    uint256 tokens_to_mint = ((toBalance + value) / tokensPerNFT) - (toBalance / tokensPerNFT);
                    if(tokens_to_mint > 0)
                        _mintWithoutCheck(to, tokens_to_mint);
                }
            }
        }
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }

    function tokensOfOwnerIn(
        address owner,
        uint256 start,
        uint256 stop
    ) public view virtual returns (uint256[] memory) {
        unchecked {
            if (start >= stop) revert InvalidQueryRange();

            if (start < _startTokenId()) {
                start = _startTokenId();
            }

            uint256 stopLimit = _nextTokenId();
            if (stop > stopLimit) {
                stop = stopLimit;
            }

            uint256 tokenIdsLength;
            if(start < stop) {
                tokenIdsLength = balanceOf(owner, start, stop);
            } else {
                tokenIdsLength = 0;
            }
            
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);

            LibBitmap.Bitmap storage bmap = _owned[owner];
            
            for ((uint256 i, uint256 tokenIdsIdx) = (start, 0); tokenIdsIdx != tokenIdsLength; ++i) {
                if(bmap.get(i) ) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            return tokenIds;
        }
    }

    function tokensOfOwner(address owner) public view virtual returns (uint256[] memory) {
        if(_totalMinted() == 0) {
            return new uint256[](0);
        }
        return tokensOfOwnerIn(owner, _startTokenId(), _nextTokenId());
    }
}

contract Flower is ERCX {
    using Strings for uint256;
    string public dataURI;
    string public baseTokenURI;
    
    uint8 private constant _decimals = 18;
    uint256 private constant _totalTokens = 100000;
    uint256 private constant _tokensPerNFT = 1;
    string private constant _name = "FLOWER";
    string private constant _ticker = "FLOWER";

    uint256 public maxWallet;
    bool public transferDelay = false;
    mapping (address => uint256) private delayTimer;

    constructor() ERCX("", _name, _ticker, _decimals, _totalTokens, _tokensPerNFT) {
        dataURI = "https://i.ibb.co/";
        maxWallet = (_totalTokens * 10 ** _decimals) * 2 / 100;
    }

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids
    ) internal override {
        if(!whitelist[to]) {
            require(_balances[to] <= maxWallet, "Transfer exceeds maximum wallet");
            if (transferDelay) {
                require(delayTimer[tx.origin] < block.number,"Only one transfer per block allowed.");
                delayTimer[tx.origin] = block.number;

                require(address(to).code.length == 0 && address(tx.origin).code.length == 0, "Contract trading restricted at launch");
            }
        }
        
        
        super._afterTokenTransfer(operator, from, to, ids);
    }

    function toggleDelay() external onlyOwner {
        transferDelay = !transferDelay;
    }

    function setMaxWallet(uint256 percent) external onlyOwner {
        maxWallet = totalSupply * percent / 100;
    }

    function setDataURI(string memory _dataURI) public onlyOwner {
        dataURI = _dataURI;
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function tokenURI(uint256 id) public view returns (string memory) {
        if(id >= _nextTokenId()) revert InputLengthMistmatch();

        if (bytes(super.uri(id)).length > 0)
            return super.uri(id);
        if (bytes(baseTokenURI).length > 0)
            return string(abi.encodePacked(baseTokenURI, id.toString()));
        else {
            uint8 seed = uint8(bytes1(keccak256(abi.encodePacked(id))));

            string memory image;
            string memory color;
            string memory description;

            if (seed <= 63) {
                image = "pxMZ1jF/Nexopetal.gif";
                color = "Nexopetal";
                description = "Nexopetal NFTs by Flowers 404 Collection. FLOWER is a collection of 100.000 NFTs living on ethereum thanks to an implementation of multiple token standards: ERC20, ERC721, 1155.";
            } else if (seed <= 127) {
                image = "hD4JH0T/Astraliris.gif";
                color = "Astraliris";
                description = "Astraliris NFTs by Flowers 404 Collection. FLOWER is a collection of 100.000 NFTs living on ethereum thanks to an implementation of multiple token standards: ERC20, ERC721, 1155.";
            } else if (seed <= 191) {
                image = "VSXR8n4/Nebulium.gif";
                color = "Nebulium";
                description = "Nebulium NFTs by Flowers 404 Collection. FLOWER is a collection of 100.000 NFTs living on ethereum thanks to an implementation of multiple token standards: ERC20, ERC721, 1155.";
            } else if (seed <= 255) {
                image = "CHhp2CC/Luminaflora.gif";
                color = "Luminaflora";
                description = "Luminaflora NFTs by Flowers 404 Collection. FLOWER is a collection of 100.000 NFTs living on ethereum thanks to an implementation of multiple token standards: ERC20, ERC721, 1155.";
            }

            string memory jsonPreImage = string(abi.encodePacked('{"name": "FLOWER #', id.toString(), '","description":"', description, '","external_url":"https://t.me/FlowerERCX","image":"', dataURI, image));
            return string(abi.encodePacked("data:application/json;utf8,", jsonPreImage, '","attributes":[{"trait_type":"Color","value":"', color, '"}]}'));
        }
    }

    function uri(uint256 id) public view override returns (string memory) {
        return tokenURI(id);
    }
}

