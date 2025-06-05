// File: contracts/interfaces/IERC1155.sol
//SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

/**
    @title ERC-1155 Multi Token Standard
    @dev See https://eips.ethereum.org/EIPS/eip-1155
    Note: The ERC-165 identifier for this interface is 0xd9b67a26.
 */
/* is ERC165 */
interface IERC1155 {
    /**
        @dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).
        The `_operator` argument MUST be the address of an account/contract that is approved to make the transfer (SHOULD be msg.sender).
        The `_from` argument MUST be the address of the holder whose balance is decreased.
        The `_to` argument MUST be the address of the recipient whose balance is increased.
        The `_id` argument MUST be the token type being transferred.
        The `_value` argument MUST be the number of tokens the holder balance is decreased by and match what the recipient balance is increased by.
        When minting/creating tokens, the `_from` argument MUST be set to `0x0` (i.e. zero address).
        When burning/destroying tokens, the `_to` argument MUST be set to `0x0` (i.e. zero address).        
    */
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);

    /**
        @dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).      
        The `_operator` argument MUST be the address of an account/contract that is approved to make the transfer (SHOULD be msg.sender).
        The `_from` argument MUST be the address of the holder whose balance is decreased.
        The `_to` argument MUST be the address of the recipient whose balance is increased.
        The `_ids` argument MUST be the list of tokens being transferred.
        The `_values` argument MUST be the list of number of tokens (matching the list and order of tokens specified in _ids) the holder balance is decreased by and match what the recipient balance is increased by.
        When minting/creating tokens, the `_from` argument MUST be set to `0x0` (i.e. zero address).
        When burning/destroying tokens, the `_to` argument MUST be set to `0x0` (i.e. zero address).                
    */
    event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values);

    /**
        @dev MUST emit when approval for a second party/operator address to manage all tokens for an owner address is enabled or disabled (absence of an event assumes disabled).        
    */
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /**
        @dev MUST emit when the URI is updated for a token ID.
        URIs are defined in RFC 3986.
        The URI MUST point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
    */
    event URI(string _value, uint256 indexed _id);

    /**
        @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if balance of holder for token `_id` is lower than the `_value` sent.
        MUST revert on any other error.
        MUST emit the `TransferSingle` event to reflect the balance change (see "Safe Transfer Rules" section of the standard).
        After the above conditions are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call `onERC1155Received` on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).        
        @param _from    Source address
        @param _to      Target address
        @param _id      ID of the token type
        @param _value   Transfer amount
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
    */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external;

    /**
        @notice Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if length of `_ids` is not the same as length of `_values`.
        MUST revert if any of the balance(s) of the holder(s) for token(s) in `_ids` is lower than the respective amount(s) in `_values` sent to the recipient.
        MUST revert on any other error.        
        MUST emit `TransferSingle` or `TransferBatch` event(s) such that all the balance changes are reflected (see "Safe Transfer Rules" section of the standard).
        Balance changes and events MUST follow the ordering of the arrays (_ids[0]/_values[0] before _ids[1]/_values[1], etc).
        After the above conditions for the transfer(s) in the batch are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call the relevant `ERC1155TokenReceiver` hook(s) on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).                      
        @param _from    Source address
        @param _to      Target address
        @param _ids     IDs of each token type (order and length must match _values array)
        @param _values  Transfer amounts per token type (order and length must match _ids array)
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
    */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external;

    /**
        @notice Get the balance of an account's tokens.
        @param _owner  The address of the token holder
        @param _id     ID of the token
        @return        The _owner's balance of the token type requested
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);

    /**
        @notice Get the balance of multiple account/token pairs
        @param _owners The addresses of the token holders
        @param _ids    ID of the tokens
        @return        The _owner's balance of the token types requested (i.e. balance for each (owner, id) pair)
     */
    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory);

    /**
        @notice Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
        @dev MUST emit the ApprovalForAll event on success.
        @param _operator  Address to add to the set of authorized operators
        @param _approved  True if the operator is approved, false to revoke approval
    */
    function setApprovalForAll(address _operator, bool _approved) external;

    /**
        @notice Queries the approval status of an operator for a given owner.
        @param _owner     The owner of the tokens
        @param _operator  Address of authorized operator
        @return           True if the operator is approved, false if not
    */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}


// File: contracts/VouchersContract.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./interfaces/IERC1155.sol";
import "./interfaces/IERC1155TokenReceiver.sol";
import "./interfaces/IERC1155Metadata_URI.sol";
import "./libraries/LibStrings.sol";
import "./interfaces/IERC173.sol";
import "./interfaces/IERC165.sol";

struct Vouchers {
    // user address => balance
    mapping(address => uint256) accountBalances;
    uint256 totalSupply;
}

struct AppStorage {
    mapping(bytes4 => bool) supportedInterfaces;
    mapping(address => mapping(address => bool)) approved;
    Vouchers[] vouchers;
    string vouchersBaseUri;
    address contractOwner;
}

contract VouchersContract is IERC1155, IERC173, IERC165 {
    AppStorage internal s;
    bytes4 internal constant ERC1155_ACCEPTED = 0xf23a6e61; // Return value from `onERC1155Received` call if a contract accepts receipt (i.e `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`).
    bytes4 internal constant ERC1155_BATCH_ACCEPTED = 0xbc197c81; // Return value from `onERC1155BatchReceived` call if a contract accepts receipt (i.e `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`).

    constructor(address _contractOwner) {
        s.contractOwner = _contractOwner;
        s.vouchersBaseUri = "https://aavegotchi.com/metadata/vouchers/";

        // adding ERC165 data
        s.supportedInterfaces[type(IERC165).interfaceId] = true;
        s.supportedInterfaces[type(IERC173).interfaceId] = true;

        // ERC1155
        // ERC165 identifier for the main token standard.
        s.supportedInterfaces[type(IERC1155).interfaceId] = true;

        // ERC1155
        // ERC1155Metadata_URI
        s.supportedInterfaces[type(IERC1155Metadata_URI).interfaceId] = true;
    }

    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        return s.supportedInterfaces[_interfaceId];
    }

    function owner() external view override returns (address) {
        return s.contractOwner;
    }

    function transferOwnership(address _newContractOwner) external override {
        address previousOwner = s.contractOwner;
        require(msg.sender == previousOwner, "Vouchers: Must be contract owner");
        s.contractOwner = _newContractOwner;
        emit OwnershipTransferred(previousOwner, _newContractOwner);
    }

    /**
        @notice Creates new voucher types and mints vouchers
        @dev Can only be called by contract owner
        @param _to      Who gets the vouchers that are minted
        @param _values  How many vouchers to mint for each new voucher type
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155BatchReceived` on `_to`
    */
    function createVoucherTypes(
        address _to,
        uint256[] calldata _values,
        bytes calldata _data
    ) external {
        require(_to != address(0), "Vouchers: Can't mint to 0 address");
        require(msg.sender == s.contractOwner, "Vouchers: Must be contract owner");
        uint256 vouchersIndex = s.vouchers.length;
        uint256[] memory ids = new uint256[](_values.length);
        for (uint256 i; i < _values.length; i++) {
            ids[i] = vouchersIndex;
            uint256 value = _values[i];
            s.vouchers.push();
            s.vouchers[vouchersIndex].totalSupply = value;
            s.vouchers[vouchersIndex].accountBalances[_to] = value;
            vouchersIndex++;
        }
        emit TransferBatch(msg.sender, address(0), _to, ids, _values);
        uint256 size;
        assembly {
            size := extcodesize(_to)
        }
        if (size > 0) {
            require(
                ERC1155_BATCH_ACCEPTED == IERC1155TokenReceiver(_to).onERC1155BatchReceived(msg.sender, address(0), ids, _values, _data),
                "Vouchers: createVoucherTypes rejected/failed"
            );
        }
    }

    /**
        @notice Mints new vouchers
        @dev Can only be called by contract owner
        @param _to      Who gets the vouchers that are minted
        @param _ids     Which voucher types to mint
        @param _values  How many vouchers to mint for each voucher type
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155BatchReceived` on `_to`
    */
    function mintVouchers(
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external {
        require(_to != address(0), "Vouchers: Can't mint to 0 address");
        require(msg.sender == s.contractOwner, "Vouchers: Must be contract owner");
        require(_ids.length == _values.length, "Vouchers: _ids must be same length as _values");
        uint256 vouchersLength = s.vouchers.length;
        for (uint256 i; i < _values.length; i++) {
            uint256 id = _ids[i];
            require(id < vouchersLength, "Vouchers: id does not exist");
            uint256 value = _values[i];
            s.vouchers[id].totalSupply += value;
            s.vouchers[id].accountBalances[_to] += value;
        }
        emit TransferBatch(msg.sender, address(0), _to, _ids, _values);
        uint256 size;
        assembly {
            size := extcodesize(_to)
        }
        if (size > 0) {
            require(
                ERC1155_BATCH_ACCEPTED == IERC1155TokenReceiver(_to).onERC1155BatchReceived(msg.sender, address(0), _ids, _values, _data),
                "Vouchers: Mint rejected/failed"
            );
        }
    }

    /**
        @notice Set the base url for all voucher types
        @param _value The new base url        
    */
    function setBaseURI(string memory _value) external {
        require(msg.sender == s.contractOwner, "Vouchers: Must be contract owner");
        s.vouchersBaseUri = _value;
        for (uint256 i; i < s.vouchers.length; i++) {
            emit URI(string(abi.encodePacked(_value, LibStrings.uintStr(i))), i);
        }
    }

    /**
        @notice Get the URI for a voucher type
        @return URI for token type
    */
    function uri(uint256 _id) external view returns (string memory) {
        require(_id < s.vouchers.length, "_id not found for  ticket");
        return string(abi.encodePacked(s.vouchersBaseUri, LibStrings.uintStr(_id)));
    }

    /**
        @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if balance of holder for token `_id` is lower than the `_value` sent.
        MUST revert on any other error.
        MUST emit the `TransferSingle` event to reflect the balance change (see "Safe Transfer Rules" section of the standard).
        After the above conditions are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call `onERC1155Received` on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).        
        @param _from    Source address
        @param _to      Target address
        @param _id      ID of the token type
        @param _value   Transfer amount
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
    */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external override {
        require(_to != address(0), "Vouchers: Can't transfer to 0 address");
        require(_id < s.vouchers.length, "Vouchers: _id not found");
        require(_from == msg.sender || s.approved[_from][msg.sender], "Vouchers: Not approved to transfer");
        uint256 bal = s.vouchers[_id].accountBalances[_from];
        require(bal >= _value, "Vouchers: _value greater than balance");
        s.vouchers[_id].accountBalances[_from] = bal - _value;
        s.vouchers[_id].accountBalances[_to] += _value;
        emit TransferSingle(msg.sender, _from, _to, _id, _value);
        uint256 size;
        assembly {
            size := extcodesize(_to)
        }
        if (size > 0) {
            require(
                ERC1155_ACCEPTED == IERC1155TokenReceiver(_to).onERC1155Received(msg.sender, _from, _id, _value, _data),
                "Vouchers: Transfer rejected/failed by _to"
            );
        }
    }

    /**
        @notice Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if length of `_ids` is not the same as length of `_values`.
        MUST revert if any of the balance(s) of the holder(s) for token(s) in `_ids` is lower than the respective amount(s) in `_values` sent to the recipient.
        MUST revert on any other error.        
        MUST emit `TransferSingle` or `TransferBatch` event(s) such that all the balance changes are reflected (see "Safe Transfer Rules" section of the standard).
        Balance changes and events MUST follow the ordering of the arrays (_ids[0]/_values[0] before _ids[1]/_values[1], etc).
        After the above conditions for the transfer(s) in the batch are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call the relevant `ERC1155TokenReceiver` hook(s) on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).                      
        @param _from    Source address
        @param _to      Target address
        @param _ids     IDs of each token type (order and length must match _values array)
        @param _values  Transfer amounts per token type (order and length must match _ids array)
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
    */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external override {
        require(_to != address(0), "Vouchers: Can't transfer to 0 address");
        require(_ids.length == _values.length, "Vouchers: _ids not the same length as _values");
        require(_from == msg.sender || s.approved[_from][msg.sender], "Vouchers: Not approved to transfer");
        uint256 vouchersLength = s.vouchers.length;
        for (uint256 i; i < _ids.length; i++) {
            uint256 id = _ids[i];
            require(id < vouchersLength, "Vouchers: id not found");
            uint256 value = _values[i];
            uint256 bal = s.vouchers[id].accountBalances[_from];
            require(bal >= value, "Vouchers: _value greater than balance");
            s.vouchers[id].accountBalances[_from] = bal - value;
            s.vouchers[id].accountBalances[_to] += value;
        }
        emit TransferBatch(msg.sender, _from, _to, _ids, _values);
        uint256 size;
        assembly {
            size := extcodesize(_to)
        }
        if (size > 0) {
            require(
                ERC1155_BATCH_ACCEPTED == IERC1155TokenReceiver(_to).onERC1155BatchReceived(msg.sender, _from, _ids, _values, _data),
                "Vouchers: Batch transfer rejected/failed by _to"
            );
        }
    }

    /**
        @notice Get total supply of each voucher type        
        @return totalSupplies_ The totalSupply of each voucher type
    */
    function totalSupplies() external view returns (uint256[] memory totalSupplies_) {
        uint256 vouchersLength = s.vouchers.length;
        totalSupplies_ = new uint256[](vouchersLength);
        for (uint256 i; i < vouchersLength; i++) {
            totalSupplies_[i] = s.vouchers[i].totalSupply;
        }
    }

    /**
        @notice Get total supply of voucher type
        @param _id           The voucher type id
        @return totalSupply_ The totalSupply of a voucher type
    */
    function totalSupply(uint256 _id) external view returns (uint256 totalSupply_) {
        require(_id < s.vouchers.length, "Vourchers:  Voucher not found");
        totalSupply_ = s.vouchers[_id].totalSupply;
    }

    /**
        @notice Get balance of an account's vouchers for each voucher type.
        @param _owner    The address of the token holder        
        @return balances_ The _owner's balances of the token types
    */
    function balanceOfAll(address _owner) external view returns (uint256[] memory balances_) {
        uint256 vouchersLength = s.vouchers.length;
        balances_ = new uint256[](vouchersLength);
        for (uint256 i; i < vouchersLength; i++) {
            balances_[i] = s.vouchers[i].accountBalances[_owner];
        }
    }

    /**
        @notice Get the balance of an account's tokens.
        @param _owner    The address of the token holder
        @param _id       ID of the token
        @return balance_ The _owner's balance of the token type requested
    */
    function balanceOf(address _owner, uint256 _id) external view override returns (uint256 balance_) {
        require(_id < s.vouchers.length, "Vouchers: _id not found");
        balance_ = s.vouchers[_id].accountBalances[_owner];
    }

    /**
        @notice Get the balance of multiple account/token pairs
        @param _owners    The addresses of the token holders
        @param _ids       ID of the tokens
        @return balances_ The _owner's balance of the token types requested (i.e. balance for each (owner, id) pair)
     */
    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view override returns (uint256[] memory balances_) {
        require(_owners.length == _ids.length, "Vouchers: _owners not same length as _ids");
        uint256 vouchersLength = s.vouchers.length;
        balances_ = new uint256[](_owners.length);
        for (uint256 i; i < _owners.length; i++) {
            uint256 id = _ids[i];
            require(id < vouchersLength, "Vouchers: id not found");
            balances_[i] = s.vouchers[id].accountBalances[_owners[i]];
        }
    }

    /**
        @notice Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
        @dev MUST emit the ApprovalForAll event on success.
        @param _operator  Address to add to the set of authorized operators
        @param _approved  True if the operator is approved, false to revoke approval
    */
    function setApprovalForAll(address _operator, bool _approved) external override {
        s.approved[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
        @notice Queries the approval status of an operator for a given owner.
        @param _owner     The owner of the tokens
        @param _operator  Address of authorized operator
        @return           True if the operator is approved, false if not
    */
    function isApprovedForAll(address _owner, address _operator) external view override returns (bool) {
        return s.approved[_owner][_operator];
    }
}


// File: contracts/interfaces/IERC1155TokenReceiver.sol
//SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

/**
    Note: The ERC-165 identifier for this interface is 0x4e2312e0.
*/
interface IERC1155TokenReceiver {
    /**
        @notice Handle the receipt of a single ERC1155 token type.
        @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeTransferFrom` after the balance has been updated.        
        This function MUST return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` (i.e. 0xf23a6e61) if it accepts the transfer.
        This function MUST revert if it rejects the transfer.
        Return of any other value than the prescribed keccak256 generated value MUST result in the transaction being reverted by the caller.
        @param _operator  The address which initiated the transfer (i.e. msg.sender)
        @param _from      The address which previously owned the token
        @param _id        The ID of the token being transferred
        @param _value     The amount of tokens being transferred
        @param _data      Additional data with no specified format
        @return           `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
    */
    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes4);

    /**
        @notice Handle the receipt of multiple ERC1155 token types.
        @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeBatchTransferFrom` after the balances have been updated.        
        This function MUST return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` (i.e. 0xbc197c81) if it accepts the transfer(s).
        This function MUST revert if it rejects the transfer(s).
        Return of any other value than the prescribed keccak256 generated value MUST result in the transaction being reverted by the caller.
        @param _operator  The address which initiated the batch transfer (i.e. msg.sender)
        @param _from      The address which previously owned the token
        @param _ids       An array containing ids of each token being transferred (order and length must match _values array)
        @param _values    An array containing amounts of each token being transferred (order and length must match _ids array)
        @param _data      Additional data with no specified format
        @return           `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
    */
    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external returns (bytes4);
}


// File: contracts/interfaces/IERC1155Metadata_URI.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

/**
    Note: The ERC-165 identifier for this interface is 0x0e89341c.
*/
interface IERC1155Metadata_URI {
    /**
        @notice A distinct Uniform Resource Identifier (URI) for a given token.
        @dev URIs are defined in RFC 3986.
        The URI MUST point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".        
        @return URI string
    */
    function uri(uint256 _id) external view returns (string memory);
}


// File: contracts/libraries/LibStrings.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

// From Open Zeppelin contracts: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol

/**
 * @dev String operations.
 */
library LibStrings {
    /**
     * @dev Converts a `uint256` to its ASCII `string` representation.
     */
    function uintStr(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

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
        uint256 index = digits - 1;
        temp = value;
        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + (temp % 10)));
            temp /= 10;
        }
        return string(buffer);
    }
}


// File: contracts/interfaces/IERC173.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

/// @title ERC-173 Contract Ownership Standard
///  Note: the ERC-165 identifier for this interface is 0x7f5828d0
/* is ERC165 */
interface IERC173 {
    /// @dev This emits when ownership of a contract changes.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Get the address of the owner
    /// @return owner_ The address of the owner.
    function owner() external view returns (address owner_);

    /// @notice Set the address of the new owner of the contract
    /// @dev Set _newOwner to address(0) to renounce any ownership.
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) external;
}


// File: contracts/interfaces/IERC165.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceId The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


