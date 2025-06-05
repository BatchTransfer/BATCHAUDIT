// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

/**
 * @title NFT minting
 * @author 0xSumo <@PBADAO>
 */


library Math {
    enum Rounding {
        Down, 
        Up, 
        Zero 
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function average(uint256 a, uint256 b) internal pure returns (uint256) {

        return (a & b) + (a ^ b) / 2;
    }

    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {

        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {

            uint256 prod0; 
            uint256 prod1; 
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                return prod0 / denominator;
            }

            require(denominator > prod1);

            uint256 remainder;
            assembly {

                remainder := mulmod(x, y, denominator)

                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = denominator & (~denominator + 1);
            assembly {

                denominator := div(denominator, twos)

                prod0 := div(prod0, twos)

                twos := add(div(sub(0, twos), twos), 1)
            }

            prod0 |= prod1 * twos;

            uint256 inverse = (3 * denominator) ^ 2;

            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 

            result = prod0 * inverse;
            return result;
        }
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 result = 1 << (log2(a) >> 1);

        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

library Counters {
    struct Counter {

        uint256 _value; 
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;

            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;

                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV 
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; 
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;

            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {

        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

    struct UserOperation {

        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

library UserOperationLib {

    function getSender(UserOperation calldata userOp) internal pure returns (address) {
        address data;

        assembly {data := calldataload(userOp)}
        return address(uint160(data));
    }

    function gasPrice(UserOperation calldata userOp) internal view returns (uint256) {
    unchecked {
        uint256 maxFeePerGas = userOp.maxFeePerGas;
        uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        if (maxFeePerGas == maxPriorityFeePerGas) {

            return maxFeePerGas;
        }
        return min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);
    }
    }

    function pack(UserOperation calldata userOp) internal pure returns (bytes memory ret) {

        bytes calldata sig = userOp.signature;

        assembly {
            let ofs := userOp
            let len := sub(sub(sig.offset, ofs), 32)
            ret := mload(0x40)
            mstore(0x40, add(ret, add(len, 32)))
            mstore(ret, len)
            calldatacopy(add(ret, 32), ofs, len)
        }
    }

    function hash(UserOperation calldata userOp) internal pure returns (bytes32) {
        return keccak256(pack(userOp));
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

    struct ValidationData {
        address aggregator;
        uint48 validAfter;
        uint48 validUntil;
    }

    function _parseValidationData(uint validationData) pure returns (ValidationData memory data) {
        address aggregator = address(uint160(validationData));
        uint48 validUntil = uint48(validationData >> 160);
        if (validUntil == 0) {
            validUntil = type(uint48).max;
        }
        uint48 validAfter = uint48(validationData >> (48 + 160));
        return ValidationData(aggregator, validAfter, validUntil);
    }

    function _intersectTimeRange(uint256 validationData, uint256 paymasterValidationData) pure returns (ValidationData memory) {
        ValidationData memory accountValidationData = _parseValidationData(validationData);
        ValidationData memory pmValidationData = _parseValidationData(paymasterValidationData);
        address aggregator = accountValidationData.aggregator;
        if (aggregator == address(0)) {
            aggregator = pmValidationData.aggregator;
        }
        uint48 validAfter = accountValidationData.validAfter;
        uint48 validUntil = accountValidationData.validUntil;
        uint48 pmValidAfter = pmValidationData.validAfter;
        uint48 pmValidUntil = pmValidationData.validUntil;

        if (validAfter < pmValidAfter) validAfter = pmValidAfter;
        if (validUntil > pmValidUntil) validUntil = pmValidUntil;
        return ValidationData(aggregator, validAfter, validUntil);
    }

    function _packValidationData(ValidationData memory data) pure returns (uint256) {
        return uint160(data.aggregator) | (uint256(data.validUntil) << 160) | (uint256(data.validAfter) << (160 + 48));
    }

    function _packValidationData(bool sigFailed, uint48 validUntil, uint48 validAfter) pure returns (uint256) {
        return (sigFailed ? 1 : 0) | (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
    }

interface IStakeManager {

    event Deposited(
        address indexed account,
        uint256 totalDeposit
    );

    event Withdrawn(
        address indexed account,
        address withdrawAddress,
        uint256 amount
    );

    event StakeLocked(
        address indexed account,
        uint256 totalStaked,
        uint256 unstakeDelaySec
    );

    event StakeUnlocked(
        address indexed account,
        uint256 withdrawTime
    );

    event StakeWithdrawn(
        address indexed account,
        address withdrawAddress,
        uint256 amount
    );

    struct DepositInfo {
        uint112 deposit;
        bool staked;
        uint112 stake;
        uint32 unstakeDelaySec;
        uint48 withdrawTime;
    }

    struct StakeInfo {
        uint256 stake;
        uint256 unstakeDelaySec;
    }

    function getDepositInfo(address account) external view returns (DepositInfo memory info);

    function balanceOf(address account) external view returns (uint256);

    function depositTo(address account) external payable;

    function addStake(uint32 _unstakeDelaySec) external payable;

    function unlockStake() external;

    function withdrawStake(address payable withdrawAddress) external;

    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external;
}

interface IAggregator {

    function validateSignatures(UserOperation[] calldata userOps, bytes calldata signature) external view;

    function validateUserOpSignature(UserOperation calldata userOp)
    external view returns (bytes memory sigForUserOp);

    function aggregateSignatures(UserOperation[] calldata userOps) external view returns (bytes memory aggregatedSignature);
}

interface IAccount {

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
    external returns (uint256 validationData);
}

interface IEntryPoint is IStakeManager {

    event UserOperationEvent(bytes32 indexed userOpHash, address indexed sender, address indexed paymaster, uint256 nonce, bool success, uint256 actualGasCost, uint256 actualGasUsed);

    event AccountDeployed(bytes32 indexed userOpHash, address indexed sender, address factory, address paymaster);

    event UserOperationRevertReason(bytes32 indexed userOpHash, address indexed sender, uint256 nonce, bytes revertReason);

    event SignatureAggregatorChanged(address indexed aggregator);

    error FailedOp(uint256 opIndex, string reason);

    error SignatureValidationFailed(address aggregator);

    error ValidationResult(ReturnInfo returnInfo,
        StakeInfo senderInfo, StakeInfo factoryInfo, StakeInfo paymasterInfo);

    error ValidationResultWithAggregation(ReturnInfo returnInfo,
        StakeInfo senderInfo, StakeInfo factoryInfo, StakeInfo paymasterInfo,
        AggregatorStakeInfo aggregatorInfo);

    error SenderAddressResult(address sender);

    error ExecutionResult(uint256 preOpGas, uint256 paid, uint48 validAfter, uint48 validUntil, bool targetSuccess, bytes targetResult);

    struct UserOpsPerAggregator {
        UserOperation[] userOps;

        IAggregator aggregator;

        bytes signature;
    }

    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external;

    function handleAggregatedOps(
        UserOpsPerAggregator[] calldata opsPerAggregator,
        address payable beneficiary
    ) external;

    function getUserOpHash(UserOperation calldata userOp) external view returns (bytes32);

    function simulateValidation(UserOperation calldata userOp) external;

    struct ReturnInfo {
        uint256 preOpGas;
        uint256 prefund;
        bool sigFailed;
        uint48 validAfter;
        uint48 validUntil;
        bytes paymasterContext;
    }

    struct AggregatorStakeInfo {
        address aggregator;
        StakeInfo stakeInfo;
    }

    function getSenderAddress(bytes memory initCode) external;

    function simulateHandleOp(UserOperation calldata op, address target, bytes calldata targetCallData) external;
}

abstract contract BaseAccount is IAccount {
    using UserOperationLib for UserOperation;

    uint256 constant internal SIG_VALIDATION_FAILED = 1;

    function nonce() public view virtual returns (uint256);

    function entryPoint() public view virtual returns (IEntryPoint);

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
    external override virtual returns (uint256 validationData) {
        _requireFromEntryPoint();
        validationData = _validateSignature(userOp, userOpHash);
        if (userOp.initCode.length == 0) {
            _validateAndUpdateNonce(userOp);
        }
        _payPrefund(missingAccountFunds);
    }

    function _requireFromEntryPoint() internal virtual view {
        require(msg.sender == address(entryPoint()), "account: not from EntryPoint");
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
    internal virtual returns (uint256 validationData);

    function _validateAndUpdateNonce(UserOperation calldata userOp) internal virtual;

    function _payPrefund(uint256 missingAccountFunds) internal virtual {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value : missingAccountFunds, gas : type(uint256).max}("");
            (success);

        }
    }
}

interface ERC1155TokenReceiver {
    function onERC1155Received(address operator_, address from_, uint256 id_, uint256 amount_, bytes calldata data_) external returns (bytes4);
    function onERC1155BatchReceived(address operator_, address from_, uint256[] calldata ids_, uint256[] calldata amounts_, bytes calldata data_) external returns (bytes4);
}

abstract contract ERC1155Enumerable {

    string public name;
    string public symbol;

    constructor(string memory name_, string memory symbol_) {
        name = name_; 
        symbol = symbol_; 
    }

    event TransferSingle(address indexed operator_, address indexed from_,  address indexed to_, uint256 id_, uint256 amount_);
    event TransferBatch(address indexed operator_, address indexed from_, address indexed to_, uint256[] ids_, uint256[] amounts_);
    event ApprovalForAll(address indexed owner_, address indexed operator_, bool approved_);
    event URI(string value_, uint256 indexed id_);

    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    mapping(uint256 => address[]) public tokenToOwners;
    mapping(uint256 => mapping(address => uint256)) public tokenToOwnersToIndex;

    struct TokenBalances {
        address owner;
        uint256 balance;
    }

    function _addEnumerableData(address address_, uint256 id_) internal {
        if (balanceOf[address_][id_] == 0) {
            uint256 _nextIndex = tokenToOwners[id_].length;
            tokenToOwners[id_].push(address_);
            tokenToOwnersToIndex[id_][address_] = _nextIndex;
        }
    }

    function _removeEnumerableData(address address_, uint256 id_) internal {
        if (balanceOf[address_][id_] == 0) {
            uint256 _userIndex = tokenToOwnersToIndex[id_][address_];
            uint256 _lastIndex = tokenToOwners[id_].length - 1;
            if (_userIndex != _lastIndex) {
                address _userAtLastIndex = tokenToOwners[id_][_lastIndex];
                tokenToOwners[id_][_userIndex] = _userAtLastIndex;
                tokenToOwnersToIndex[id_][_userAtLastIndex] = _userIndex;
            }

            tokenToOwners[id_].pop();
            delete tokenToOwnersToIndex[id_][address_];
        }
    }

    function getOwnersOfTokenId(uint256 id_) public view returns (address[] memory) {
        return tokenToOwners[id_];
    }

    function getOwnersOfTokenIdAndBalance(uint256 id_) public view returns (TokenBalances[] memory) {
        address[] memory _owners = getOwnersOfTokenId(id_);
        uint256 _ownersLength = _owners.length;
        TokenBalances[] memory _TokenBalancesAll = new TokenBalances[] (_ownersLength);

        for (uint256 i = 0; i < _ownersLength; i++) {
            address _currentOwner = _owners[i];
            _TokenBalancesAll[i] = TokenBalances(
                _currentOwner,
                balanceOf[_currentOwner][id_]
            );
        }
        return _TokenBalancesAll;
    }

    function getTotalSupplyOfIds(uint256[] calldata ids_) public view returns (uint256) {
        uint256 _tokens;
        for (uint256 i = 0; i < ids_.length; i++) {
            _tokens += getOwnersOfTokenId(ids_[i]).length;
        }
        return _tokens;
    }

    function uri(uint256 id) public view virtual returns (string memory);

    function _isSameLength(uint256 a, uint256 b) internal pure returns (bool) {
        return a == b;
    }

    function _isApprovedOrOwner(address from_) internal view returns (bool) {
        return msg.sender == from_ || isApprovedForAll[from_][msg.sender];
    }

    function _ERC1155Supported(address from_, address to_, uint256 id_, uint256 amount_, bytes memory data_) internal {
        require(to_.code.length == 0 ? to_ != address(0) :
            ERC1155TokenReceiver(to_).onERC1155Received(
                msg.sender, from_, id_, amount_, data_) ==
            ERC1155TokenReceiver.onERC1155Received.selector,
                "_ERC1155Supported(): Unsupported Recipient!"
        );
    }

    function _ERC1155BatchSupported(address from_, address to_, uint256[] memory ids_, uint256[] memory amounts_, bytes memory data_) internal {
        require(to_.code.length == 0 ? to_ != address(0) :
            ERC1155TokenReceiver(to_).onERC1155BatchReceived(
                msg.sender, from_, ids_, amounts_, data_) ==
            ERC1155TokenReceiver.onERC1155BatchReceived.selector,
                "_ERC1155BatchSupported(): Unsupported Recipient!"
        );
    }

    function setApprovalForAll(address operator_, bool approved_) public virtual {
        isApprovedForAll[msg.sender][operator_] = approved_;
        emit ApprovalForAll(msg.sender, operator_, approved_);
    }

    function _transfer(address from_, address to_, uint256 id_, uint256 amount_) internal {
        _addEnumerableData(to_, id_);
        balanceOf[to_][id_] += amount_;
        balanceOf[from_][id_] -= amount_;
        _removeEnumerableData(from_, id_);
    }

    function safeTransferFrom(address from_, address to_, uint256 id_, uint256 amount_, bytes memory data_) public virtual {
        require(_isApprovedOrOwner(from_));
        _transfer(from_, to_, id_, amount_);
        emit TransferSingle(msg.sender, from_, to_, id_, amount_);
        _ERC1155Supported(from_, to_, id_, amount_, data_);
    }

    function safeBatchTransferFrom(address from_, address to_, uint256[] memory ids_, uint256[] memory amounts_, bytes memory data_) public virtual {
        require(_isSameLength(ids_.length, amounts_.length));
        require(_isApprovedOrOwner(from_));

        for (uint256 i = 0; i < ids_.length; i++) {
            _transfer(from_, to_, ids_[i], amounts_[i]);
        }

        emit TransferBatch(msg.sender, from_, to_, ids_, amounts_);

        _ERC1155BatchSupported(from_, to_, ids_, amounts_, data_);
    }

    function _mintInternal(address to_, uint256 id_, uint256 amount_) internal {
        _addEnumerableData(to_, id_);
        balanceOf[to_][id_] += amount_;
    }

    function _mint(address to_, uint256 id_, uint256 amount_, bytes memory data_) internal {
        _mintInternal(to_, id_, amount_);

        emit TransferSingle(msg.sender, address(0), to_, id_, amount_);

        _ERC1155Supported(address(0), to_, id_, amount_, data_);
    }

    function _batchMint(address to_, uint256[] memory ids_, uint256[] memory amounts_, bytes memory data_) internal {
        require(_isSameLength(ids_.length, amounts_.length));

        for (uint256 i = 0; i < ids_.length; i++) {
            _mintInternal(to_, ids_[i], amounts_[i]);
        }

        emit TransferBatch(msg.sender, address(0), to_, ids_, amounts_);

        _ERC1155BatchSupported(address(0), to_, ids_, amounts_, data_);
    }

    function _burnInternal(address from_, uint256 id_, uint256 amount_) internal {
        balanceOf[from_][id_] -= amount_;
        _removeEnumerableData(from_, id_);
    }

    function _burn(address from_, uint256 id_, uint256 amount_) internal {
        _burnInternal(from_, id_, amount_);
        emit TransferSingle(msg.sender, from_, address(0), id_, amount_);
    }

    function _batchBurn(address from_, uint256[] memory ids_, uint256[] memory amounts_) internal {
        require(_isSameLength(ids_.length, amounts_.length));

        for (uint256 i = 0; i < ids_.length; i++) {
            _burnInternal(from_, ids_[i], amounts_[i]);
        }

        emit TransferBatch(msg.sender, from_, address(0), ids_, amounts_);
    }

    function supportsInterface(bytes4 interfaceId_) public pure virtual returns (bool) {
        return interfaceId_ == 0x01ffc9a7 || interfaceId_ == 0xd9b67a26 || interfaceId_ == 0x0e89341c;
    }

    function balanceOfBatch(address[] memory owners_, uint256[] memory ids_) public view virtual returns (uint256[] memory) {
        require(_isSameLength(owners_.length, ids_.length));

        uint256[] memory _balances = new uint256[](owners_.length);

        for (uint256 i = 0; i < owners_.length; i++) {
            _balances[i] = balanceOf[owners_[i]][ids_[i]];
        }
        return _balances;
    }
}

abstract contract ERC721URIPerToken {
    mapping(uint256 => string) public tokenToURI;
    function _setTokenToURI(uint256 tokenId_, string memory uri_) internal virtual {
        tokenToURI[tokenId_] = uri_;
    }
}

contract ERC1155 is BaseAccount, ERC1155Enumerable, ERC721URIPerToken {

    using Counters for Counters.Counter;

    using ECDSA for bytes32;
    
    IEntryPoint private immutable _entryPoint;

    uint96 private _nonce;

    address public owner;

    address public admin;

    uint256 public _offset = 132;

    event mintDone(address wallet);

    event burnDone(address wallet, bytes data_);

    constructor(IEntryPoint anEntryPoint) ERC1155Enumerable("ERC1155TORMO", "1155") {
        _entryPoint = anEntryPoint;
        owner = msg.sender;
    }

    function nonce() public view virtual override returns (uint256) {
        return _nonce;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    function _validateAndUpdateNonce(UserOperation calldata userOp) internal override {
        require(_nonce++ == userOp.nonce, "account: invalid nonce");
    }

    function extractAddressFromBytecode(bytes memory bytecode, uint256 offset) public pure returns (address extractedAddress) {
        require(bytecode.length >= offset + 20, "Bytecode too short for specified offset.");
        assembly {
            extractedAddress := mload(add(bytecode, add(offset, 0x20)))
        }
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash) internal virtual override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (extractAddressFromBytecode(userOp.callData, _offset) != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    function _requireOnlyFromEntryPoint() internal view {
        require(msg.sender == address(entryPoint()), "only entryPoint");
    }

    receive() external payable {}

    fallback() external payable {}

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function mint(address address_, uint256 id_, uint256 amount_, bytes memory data_, address wallet_) external {
        _requireOnlyFromEntryPoint();
        _mint(address_, id_, amount_, data_);
        emit mintDone(wallet_);
    }

    function burn(address address_, uint256 id_, uint256 amount_, bytes memory data_, address wallet_) external {
        _requireOnlyFromEntryPoint();
        _burn(address_, id_, amount_);
        emit burnDone(wallet_, data_);
    }

    function setAdmin(address address_) external {
        require(msg.sender == owner, "owner only");
        admin = address_;
    }

    function setTokenToURI(uint256 tokenId_, string calldata uri_) external {
        require(msg.sender == owner, "owner only");
        _setTokenToURI(tokenId_, uri_);
    }

    function uri(uint256 id) public view override  returns (string memory) {
        return tokenToURI[id];
    }

    function setOffset(uint256 offset_) external {
        require(msg.sender == owner, "owner only");
        _offset = offset_;
    }

    function withdraw() external {
        require(msg.sender == owner, "owner only");
        uint256 balance = address(this).balance;
        (bool transferTx, ) = msg.sender.call{value: balance}("");
        require(transferTx, "Transfer failed.");
    }
}