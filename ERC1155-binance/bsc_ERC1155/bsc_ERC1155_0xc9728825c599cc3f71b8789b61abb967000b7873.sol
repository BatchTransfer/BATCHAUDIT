// File: openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// File: multi-token-standard/contracts/interfaces/IERC1155Metadata.sol

pragma solidity 0.7.4;

interface IERC1155Metadata {
    event URI(string _uri, uint256 indexed _id);

    /****************************************|
  |                Functions               |
  |_______________________________________*/

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given token.
     * @dev URIs are defined in RFC 3986.
     *      URIs are assumed to be deterministically generated based on token ID
     *      Token IDs are assumed to be represented in their hex format in URIs
     * @return URI string
     */
    function uri(uint256 _id) external view returns (string memory);
}

// File: multi-token-standard/contracts/utils/ERC165.sol

pragma solidity 0.7.4;

abstract contract ERC165 {
    /**
     * @notice Query if a contract implements an interface
     * @param _interfaceID The interface identifier, as specified in ERC-165
     * @return `true` if the contract implements `_interfaceID`
     */
    function supportsInterface(bytes4 _interfaceID)
        public
        pure
        virtual
        returns (bool)
    {
        return _interfaceID == this.supportsInterface.selector;
    }
}

// File: multi-token-standard/contracts/tokens/ERC1155/ERC1155Metadata.sol

pragma solidity 0.7.4;

/**
 * @notice Contract that handles metadata related methods.
 * @dev Methods assume a deterministic generation of URI based on token IDs.
 *      Methods also assume that URI uses hex representation of token IDs.
 */
contract ERC1155Metadata is IERC1155Metadata, ERC165 {
    // URI's default URI prefix
    string internal baseMetadataURI;

    /***********************************|
  |     Metadata Public Function s    |
  |__________________________________*/

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given token.
     * @dev URIs are defined in RFC 3986.
     *      URIs are assumed to be deterministically generated based on token ID
     * @return URI string
     */
    function uri(uint256 _id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(abi.encodePacked(baseMetadataURI, _uint2str(_id), ".json"));
    }

    /***********************************|
  |    Metadata Internal Functions    |
  |__________________________________*/

    /**
     * @notice Will emit default URI log event for corresponding token _id
     * @param _tokenIDs Array of IDs of tokens to log default URI
     */
    function _logURIs(uint256[] memory _tokenIDs) internal {
        string memory baseURL = baseMetadataURI;
        string memory tokenURI;

        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            tokenURI = string(
                abi.encodePacked(baseURL, _uint2str(_tokenIDs[i]), ".json")
            );
            emit URI(tokenURI, _tokenIDs[i]);
        }
    }

    /**
     * @notice Will update the base URL of token's URI
     * @param _newBaseMetadataURI New base URL of token's URI
     */
    function _setBaseMetadataURI(string memory _newBaseMetadataURI) internal {
        baseMetadataURI = _newBaseMetadataURI;
    }

    /**
     * @notice Query if a contract implements an interface
     * @param _interfaceID  The interface identifier, as specified in ERC-165
     * @return `true` if the contract implements `_interfaceID` and
     */
    function supportsInterface(bytes4 _interfaceID)
        public
        pure
        virtual
        override
        returns (bool)
    {
        if (_interfaceID == type(IERC1155Metadata).interfaceId) {
            return true;
        }
        return super.supportsInterface(_interfaceID);
    }

    /***********************************|
  |    Utility Internal Functions     |
  |__________________________________*/

    /**
     * @notice Convert uint256 to string
     * @param _i Unsigned integer to convert to string
     */
    function _uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }

        uint256 j = _i;
        uint256 ii = _i;
        uint256 len;

        // Get number of bytes
        while (j != 0) {
            len++;
            j /= 10;
        }

        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;

        // Get each individual ASCII
        while (ii != 0) {
            bstr[k--] = bytes1(uint8(48 + (ii % 10)));
            ii /= 10;
        }

        // Convert to string
        return string(bstr);
    }
}

// File: multi-token-standard/contracts/utils/Ownable.sol

pragma solidity 0.7.4;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner_;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() {
        _owner_ = msg.sender;
        emit OwnershipTransferred(address(0), _owner_);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() virtual {
        require(
            msg.sender == _owner_,
            "Ownable#onlyOwner: SENDER_IS_NOT_OWNER"
        );
        _;
    }

    /**
     * @notice Transfers the ownership of the contract to new address
     * @param _newOwner Address of the new owner
     */
    function transferOwnership(address _newOwner) public onlyOwner {
        require(
            _newOwner != address(0),
            "Ownable#transferOwnership: INVALID_ADDRESS"
        );
        emit OwnershipTransferred(_owner_, _newOwner);
        _owner_ = _newOwner;
    }

    /**
     * @notice Returns the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner_;
    }
}

// File: multi-token-standard/contracts/utils/SafeMath.sol

pragma solidity 0.7.4;

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath#mul: OVERFLOW");

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath#div: DIVISION_BY_ZERO");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath#sub: UNDERFLOW");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath#add: OVERFLOW");

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath#mod: DIVISION_BY_ZERO");
        return a % b;
    }
}

// File: multi-token-standard/contracts/interfaces/IERC1155TokenReceiver.sol

pragma solidity 0.7.4;

/**
 * @dev ERC-1155 interface for accepting safe transfers.
 */
interface IERC1155TokenReceiver {
    /**
     * @notice Handle the receipt of a single ERC1155 token type
     * @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeTransferFrom` after the balance has been updated
     * This function MAY throw to revert and reject the transfer
     * Return of other amount than the magic value MUST result in the transaction being reverted
     * Note: The token contract address is always the message sender
     * @param _operator  The address which called the `safeTransferFrom` function
     * @param _from      The address which previously owned the token
     * @param _id        The id of the token being transferred
     * @param _amount    The amount of tokens being transferred
     * @param _data      Additional data with no specified format
     * @return           `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     */
    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) external returns (bytes4);

    /**
     * @notice Handle the receipt of multiple ERC1155 token types
     * @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeBatchTransferFrom` after the balances have been updated
     * This function MAY throw to revert and reject the transfer
     * Return of other amount than the magic value WILL result in the transaction being reverted
     * Note: The token contract address is always the message sender
     * @param _operator  The address which called the `safeBatchTransferFrom` function
     * @param _from      The address which previously owned the token
     * @param _ids       An array containing ids of each token being transferred
     * @param _amounts   An array containing amounts of each token being transferred
     * @param _data      Additional data with no specified format
     * @return           `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external returns (bytes4);
}

// File: multi-token-standard/contracts/interfaces/IERC1155.sol

pragma solidity 0.7.4;

interface IERC1155 {
    /****************************************|
  |                 Events                 |
  |_______________________________________*/

    /**
     * @dev Either TransferSingle or TransferBatch MUST emit when tokens are transferred, including zero amount transfers as well as minting or burning
     *   Operator MUST be msg.sender
     *   When minting/creating tokens, the `_from` field MUST be set to `0x0`
     *   When burning/destroying tokens, the `_to` field MUST be set to `0x0`
     *   The total amount transferred from address 0x0 minus the total amount transferred to 0x0 may be used by clients and exchanges to be added to the "circulating supply" for a given token ID
     *   To broadcast the existence of a token ID with no initial balance, the contract SHOULD emit the TransferSingle event from `0x0` to `0x0`, with the token creator as `_operator`, and a `_amount` of 0
     */
    event TransferSingle(
        address indexed _operator,
        address indexed _from,
        address indexed _to,
        uint256 _id,
        uint256 _amount
    );

    /**
     * @dev Either TransferSingle or TransferBatch MUST emit when tokens are transferred, including zero amount transfers as well as minting or burning
     *   Operator MUST be msg.sender
     *   When minting/creating tokens, the `_from` field MUST be set to `0x0`
     *   When burning/destroying tokens, the `_to` field MUST be set to `0x0`
     *   The total amount transferred from address 0x0 minus the total amount transferred to 0x0 may be used by clients and exchanges to be added to the "circulating supply" for a given token ID
     *   To broadcast the existence of multiple token IDs with no initial balance, this SHOULD emit the TransferBatch event from `0x0` to `0x0`, with the token creator as `_operator`, and a `_amount` of 0
     */
    event TransferBatch(
        address indexed _operator,
        address indexed _from,
        address indexed _to,
        uint256[] _ids,
        uint256[] _amounts
    );

    /**
     * @dev MUST emit when an approval is updated
     */
    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    /****************************************|
  |                Functions               |
  |_______________________________________*/

    /**
     * @notice Transfers amount of an _id from the _from address to the _to address specified
     * @dev MUST emit TransferSingle event on success
     * Caller must be approved to manage the _from account's tokens (see isApprovedForAll)
     * MUST throw if `_to` is the zero address
     * MUST throw if balance of sender for token `_id` is lower than the `_amount` sent
     * MUST throw on any other error
     * When transfer is complete, this function MUST check if `_to` is a smart contract (code size > 0). If so, it MUST call `onERC1155Received` on `_to` and revert if the return amount is not `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * @param _from    Source address
     * @param _to      Target address
     * @param _id      ID of the token type
     * @param _amount  Transfered amount
     * @param _data    Additional data with no specified format, sent in call to `_to`
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) external;

    /**
     * @notice Send multiple types of Tokens from the _from address to the _to address (with safety call)
     * @dev MUST emit TransferBatch event on success
     * Caller must be approved to manage the _from account's tokens (see isApprovedForAll)
     * MUST throw if `_to` is the zero address
     * MUST throw if length of `_ids` is not the same as length of `_amounts`
     * MUST throw if any of the balance of sender for token `_ids` is lower than the respective `_amounts` sent
     * MUST throw on any other error
     * When transfer is complete, this function MUST check if `_to` is a smart contract (code size > 0). If so, it MUST call `onERC1155BatchReceived` on `_to` and revert if the return amount is not `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * Transfers and events MUST occur in the array order they were submitted (_ids[0] before _ids[1], etc)
     * @param _from     Source addresses
     * @param _to       Target addresses
     * @param _ids      IDs of each token type
     * @param _amounts  Transfer amounts per token type
     * @param _data     Additional data with no specified format, sent in call to `_to`
     */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external;

    /**
     * @notice Get the balance of an account's Tokens
     * @param _owner  The address of the token holder
     * @param _id     ID of the Token
     * @return        The _owner's balance of the Token type requested
     */
    function balanceOf(address _owner, uint256 _id)
        external
        view
        returns (uint256);

    /**
     * @notice Get the balance of multiple account/token pairs
     * @param _owners The addresses of the token holders
     * @param _ids    ID of the Tokens
     * @return        The _owner's balance of the Token types requested (i.e. balance for each (owner, id) pair)
     */
    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @notice Enable or disable approval for a third party ("operator") to manage all of caller's tokens
     * @dev MUST emit the ApprovalForAll event on success
     * @param _operator  Address to add to the set of authorized operators
     * @param _approved  True if the operator is approved, false to revoke approval
     */
    function setApprovalForAll(address _operator, bool _approved) external;

    /**
     * @notice Queries the approval status of an operator for a given owner
     * @param _owner     The owner of the Tokens
     * @param _operator  Address of authorized operator
     * @return isOperator True if the operator is approved, false if not
     */
    function isApprovedForAll(address _owner, address _operator)
        external
        view
        returns (bool isOperator);
}

// File: multi-token-standard/contracts/utils/Address.sol

pragma solidity 0.7.4;

/**
 * Utility library of inline functions on addresses
 */
library Address {
    // Default hash for EOA accounts returned by extcodehash
    bytes32 internal constant ACCOUNT_HASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    /**
     * Returns whether the target address is a contract
     * @dev This function will return false if invoked during the constructor of a contract.
     * @param _address address of the account to check
     * @return Whether the target address is a contract
     */
    function isContract(address _address) internal view returns (bool) {
        bytes32 codehash;

        // Currently there is no better way to check if there is a contract in an address
        // than to check the size of the code at that address or if it has a non-zero code hash or account hash
        assembly {
            codehash := extcodehash(_address)
        }
        return (codehash != 0x0 && codehash != ACCOUNT_HASH);
    }
}

// File: multi-token-standard/contracts/tokens/ERC1155/ERC1155.sol

pragma solidity 0.7.4;

/**
 * @dev Implementation of Multi-Token Standard contract
 */
contract ERC1155 is IERC1155, ERC165 {
    using SafeMath for uint256;
    using Address for address;

    /***********************************|
  |        Variables and Events       |
  |__________________________________*/

    // onReceive function signatures
    bytes4 internal constant ERC1155_RECEIVED_VALUE = 0xf23a6e61;
    bytes4 internal constant ERC1155_BATCH_RECEIVED_VALUE = 0xbc197c81;

    // Objects balances
    mapping(address => mapping(uint256 => uint256)) internal balances;

    // Operator Functions
    mapping(address => mapping(address => bool)) internal operators;

    /***********************************|
  |     Public Transfer Functions     |
  |__________________________________*/

    /**
     * @notice Transfers amount amount of an _id from the _from address to the _to address specified
     * @param _from    Source address
     * @param _to      Target address
     * @param _id      ID of the token type
     * @param _amount  Transfered amount
     * @param _data    Additional data with no specified format, sent in call to `_to`
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) public virtual override {
        require(
            (msg.sender == _from) || isApprovedForAll(_from, msg.sender),
            "ERC1155#safeTransferFrom: INVALID_OPERATOR"
        );
        require(
            _to != address(0),
            "ERC1155#safeTransferFrom: INVALID_RECIPIENT"
        );
        // require(_amount <= balances[_from][_id]) is not necessary since checked with safemath operations

        _safeTransferFrom(_from, _to, _id, _amount);
        _callonERC1155Received(_from, _to, _id, _amount, gasleft(), _data);
    }

    /**
     * @notice Send multiple types of Tokens from the _from address to the _to address (with safety call)
     * @param _from     Source addresses
     * @param _to       Target addresses
     * @param _ids      IDs of each token type
     * @param _amounts  Transfer amounts per token type
     * @param _data     Additional data with no specified format, sent in call to `_to`
     */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) public virtual override {
        // Requirements
        require(
            (msg.sender == _from) || isApprovedForAll(_from, msg.sender),
            "ERC1155#safeBatchTransferFrom: INVALID_OPERATOR"
        );
        require(
            _to != address(0),
            "ERC1155#safeBatchTransferFrom: INVALID_RECIPIENT"
        );

        _safeBatchTransferFrom(_from, _to, _ids, _amounts);
        _callonERC1155BatchReceived(
            _from,
            _to,
            _ids,
            _amounts,
            gasleft(),
            _data
        );
    }

    /***********************************|
  |    Internal Transfer Functions    |
  |__________________________________*/

    /**
     * @notice Transfers amount amount of an _id from the _from address to the _to address specified
     * @param _from    Source address
     * @param _to      Target address
     * @param _id      ID of the token type
     * @param _amount  Transfered amount
     */
    function _safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount
    ) internal {
        // Update balances
        balances[_from][_id] = balances[_from][_id].sub(_amount); // Subtract amount
        balances[_to][_id] = balances[_to][_id].add(_amount); // Add amount

        // Emit event
        emit TransferSingle(msg.sender, _from, _to, _id, _amount);
    }

    /**
     * @notice Verifies if receiver is contract and if so, calls (_to).onERC1155Received(...)
     */
    function _callonERC1155Received(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        uint256 _gasLimit,
        bytes memory _data
    ) internal {
        // Check if recipient is contract
        if (_to.isContract()) {
            bytes4 retval =
                IERC1155TokenReceiver(_to).onERC1155Received{gas: _gasLimit}(
                    msg.sender,
                    _from,
                    _id,
                    _amount,
                    _data
                );
            require(
                retval == ERC1155_RECEIVED_VALUE,
                "ERC1155#_callonERC1155Received: INVALID_ON_RECEIVE_MESSAGE"
            );
        }
    }

    /**
     * @notice Send multiple types of Tokens from the _from address to the _to address (with safety call)
     * @param _from     Source addresses
     * @param _to       Target addresses
     * @param _ids      IDs of each token type
     * @param _amounts  Transfer amounts per token type
     */
    function _safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) internal {
        require(
            _ids.length == _amounts.length,
            "ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"
        );

        // Number of transfer to execute
        uint256 nTransfer = _ids.length;

        // Executing all transfers
        for (uint256 i = 0; i < nTransfer; i++) {
            // Update storage balance of previous bin
            balances[_from][_ids[i]] = balances[_from][_ids[i]].sub(
                _amounts[i]
            );
            balances[_to][_ids[i]] = balances[_to][_ids[i]].add(_amounts[i]);
        }

        // Emit event
        emit TransferBatch(msg.sender, _from, _to, _ids, _amounts);
    }

    /**
     * @notice Verifies if receiver is contract and if so, calls (_to).onERC1155BatchReceived(...)
     */
    function _callonERC1155BatchReceived(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        uint256 _gasLimit,
        bytes memory _data
    ) internal {
        // Pass data if recipient is contract
        if (_to.isContract()) {
            bytes4 retval =
                IERC1155TokenReceiver(_to).onERC1155BatchReceived{
                    gas: _gasLimit
                }(msg.sender, _from, _ids, _amounts, _data);
            require(
                retval == ERC1155_BATCH_RECEIVED_VALUE,
                "ERC1155#_callonERC1155BatchReceived: INVALID_ON_RECEIVE_MESSAGE"
            );
        }
    }

    /***********************************|
  |         Operator Functions        |
  |__________________________________*/

    /**
     * @notice Enable or disable approval for a third party ("operator") to manage all of caller's tokens
     * @param _operator  Address to add to the set of authorized operators
     * @param _approved  True if the operator is approved, false to revoke approval
     */
    function setApprovalForAll(address _operator, bool _approved)
        external
        override
    {
        // Update operator status
        operators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
     * @notice Queries the approval status of an operator for a given owner
     * @param _owner     The owner of the Tokens
     * @param _operator  Address of authorized operator
     * @return isOperator True if the operator is approved, false if not
     */
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        virtual
        override
        returns (bool isOperator)
    {
        return operators[_owner][_operator];
    }

    /***********************************|
  |         Balance Functions         |
  |__________________________________*/

    /**
     * @notice Get the balance of an account's Tokens
     * @param _owner  The address of the token holder
     * @param _id     ID of the Token
     * @return The _owner's balance of the Token type requested
     */
    function balanceOf(address _owner, uint256 _id)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return balances[_owner][_id];
    }

    /**
     * @notice Get the balance of multiple account/token pairs
     * @param _owners The addresses of the token holders
     * @param _ids    ID of the Tokens
     * @return        The _owner's balance of the Token types requested (i.e. balance for each (owner, id) pair)
     */
    function balanceOfBatch(address[] memory _owners, uint256[] memory _ids)
        public
        view
        override
        returns (uint256[] memory)
    {
        require(
            _owners.length == _ids.length,
            "ERC1155#balanceOfBatch: INVALID_ARRAY_LENGTH"
        );

        // Variables
        uint256[] memory batchBalances = new uint256[](_owners.length);

        // Iterate over each owner and token ID
        for (uint256 i = 0; i < _owners.length; i++) {
            batchBalances[i] = balances[_owners[i]][_ids[i]];
        }

        return batchBalances;
    }

    /***********************************|
  |          ERC165 Functions         |
  |__________________________________*/

    /**
     * @notice Query if a contract implements an interface
     * @param _interfaceID  The interface identifier, as specified in ERC-165
     * @return `true` if the contract implements `_interfaceID` and
     */
    function supportsInterface(bytes4 _interfaceID)
        public
        pure
        virtual
        override
        returns (bool)
    {
        if (_interfaceID == type(IERC1155).interfaceId) {
            return true;
        }
        return super.supportsInterface(_interfaceID);
    }
}

// File: contracts/ERC1155Tradable.sol

pragma solidity >=0.6.0;

// Skeleton of Wyvern's Proxy
contract OwnableDelegateProxy {

}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

/**
 * @title ERC1155Tradable
 * ERC1155Tradable - ERC1155 contract that whitelists an operator address, has create and mint functionality, and supports useful standards from OpenZeppelin,
  like exists(), name(), symbol(), and totalSupply()
 */
contract ERC1155Tradable is ERC1155, Ownable {
    // Proxy registry address
    address public proxyRegistryAddress;
    // Contract name
    string public name;
    // Contract symbol
    string public symbol;

    using SafeMath for uint256;

    mapping(uint256 => uint256) private _supply;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /**
     * @dev Contract owner. Throws if called by any account other than the owner or their proxy
     */
    modifier onlyOwner() override {
        require(
            _isOwner(msg.sender),
            "ERC1155Tradable#onlyOwner: CALLER_IS_NOT_OWNER"
        );
        _;
    }

    /**
     * @dev Returns the total quantity for a token ID
     * @param _id uint256 ID of the token to query
     * @return amount of token in existence
     */
    function totalSupply(uint256 _id) public view returns (uint256) {
        return _supply[_id];
    }

    /**
     * Override isApprovedForAll to whitelist user's proxy accounts to enable gas-free listings.
     */
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool isOperator)
    {
        // Whitelist proxy contracts for easy trading.
        if (_isProxyForUser(_owner, _operator)) {
            return true;
        }

        return super.isApprovedForAll(_owner, _operator);
    }

    /**
     * @dev Mints some amount of tokens to an address
     * @param _to          Address of the future owner of the token
     * @param _id          Token ID to mint
     * @param _quantity    Amount of tokens to mint
     * @param _data        Data to pass if receiver is contract
     */
    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public virtual onlyOwner {
        _mint(_to, _id, _quantity, _data);
    }

    /**
     * @dev Mint tokens for each id in _ids
     * @param _to          The address to mint tokens to
     * @param _ids         Array of ids to mint
     * @param _quantities  Array of amounts of tokens to mint per id
     * @param _data        Data to pass if receiver is contract
     */
    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public virtual onlyOwner {
        _batchMint(_to, _ids, _quantities, _data);
    }

    /**
     * @dev Returns whether the specified token is minted
     * @param _id uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function exists(uint256 _id) public view returns (bool) {
        return _supply[_id] > 0;
    }

    function _isOwner(address _address) internal view returns (bool) {
        return owner() == _address || _isProxyForUser(owner(), _address);
    }

    // Overrides ERC1155MintBurn to allow changing birth events to creator transfers,
    // and to set _supply
    function _mint(
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) internal virtual {
        // Add _amount
        balances[_to][_id] = balances[_to][_id].add(_amount);
        _supply[_id] = _supply[_id].add(_amount);

        // Origin of token will be the _from parameter
        address origin = _origin(_id);

        // Emit event
        emit TransferSingle(msg.sender, origin, _to, _id, _amount);

        // Calling onReceive method if recipient is contract
        _callonERC1155Received(origin, _to, _id, _amount, gasleft(), _data);
    }

    // Overrides ERC1155MintBurn to change the batch birth events to creator transfers, and to set _supply
    function _batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal virtual {
        require(
            _ids.length == _amounts.length,
            "ERC1155Tradable#batchMint: INVALID_ARRAYS_LENGTH"
        );

        // Number of mints to execute
        uint256 nMint = _ids.length;

        // Origin of tokens will be the _from parameter
        address origin = _origin(_ids[0]);

        // Executing all minting
        for (uint256 i = 0; i < nMint; i++) {
            // Update storage balance
            uint256 id = _ids[i];
            require(
                _origin(id) == origin,
                "ERC1155Tradable#batchMint: MULTIPLE_ORIGINS_NOT_ALLOWED"
            );
            balances[_to][id] = balances[_to][id].add(_amounts[i]);
            _supply[id] = _supply[id].add(_amounts[i]);
        }

        // Emit batch mint event
        emit TransferBatch(msg.sender, origin, _to, _ids, _amounts);

        // Calling onReceive method if recipient is contract
        _callonERC1155BatchReceived(
            origin,
            _to,
            _ids,
            _amounts,
            gasleft(),
            _data
        );
    }

    // Override this to change birth events' _from address
    function _origin(
        uint256 /* _id */
    ) internal view virtual returns (address) {
        return address(0);
    }

    /**
     * @dev Allows owner to change the proxy registry
     */
    function setProxyRegistryAddress(address _address) public onlyOwner {
        proxyRegistryAddress = _address;
    }

    // PROXY HELPER METHODS

    function _isProxyForUser(address _user, address _address)
        internal
        view
        virtual
        returns (bool)
    {
        return _proxy(_user) == _address;
    }

    function _proxy(address _address) internal view returns (address) {
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        return address(proxyRegistry.proxies(_address));
    }
}

// File: contracts/BaseMusicBlock.sol

pragma solidity >=0.6.0;

/**
 * @title BaseMusicBlock
 */
contract BaseMusicBlock is ERC1155Tradable, ERC1155Metadata {
    uint256 constant TOKEN_SUPPLY_CAP = 1;

    using SafeMath for uint256;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURI;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _templateURI
    ) ERC1155Tradable(_name, _symbol) {
        if (bytes(_templateURI).length > 0) {
            _setBaseMetadataURI(_templateURI);
        }
    }

    /**
     * Compat for factory interfaces
     * Indicates that this contract can return balances for
     * tokens that haven't been minted yet
     */
    function supportsFactoryInterface() public pure returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 _interfaceID)
        public
        pure
        override(ERC1155, ERC1155Metadata)
        returns (bool)
    {
        return super.supportsInterface(_interfaceID);
    }

    function setBaseMetadataURI(string memory _uri) public onlyOwner {
        _setBaseMetadataURI(_uri);
    }

    function setURI(uint256 _id, string memory _uri) public virtual onlyOwner {
        _setURI(_id, _uri);
    }

    function uri(uint256 _id) public view override returns (string memory) {
        string memory tokenUri = _tokenURI[_id];
        if (bytes(tokenUri).length != 0) {
            return tokenUri;
        }
        return string(abi.encodePacked(baseMetadataURI, _uint2str(_id)));
    }

    function balanceOf(address _owner, uint256 _id)
        public
        view
        override
        returns (uint256)
    {
        uint256 balance = super.balanceOf(_owner, _id);
        return
            _isCreatorOrProxy(_id, _owner)
                ? balance.add(_remainingSupply(_id))
                : balance;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) public override {
        uint256 mintedBalance = super.balanceOf(_from, _id);
        if (mintedBalance < _amount) {
            // Only mint what _from doesn't already have
            mint(_to, _id, _amount.sub(mintedBalance), _data);
            if (mintedBalance > 0) {
                super.safeTransferFrom(_from, _to, _id, mintedBalance, _data);
            }
        } else {
            super.safeTransferFrom(_from, _to, _id, _amount, _data);
        }
    }

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) public override {
        require(
            _ids.length == _amounts.length,
            "BaseMusicBlock#safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"
        );
        for (uint256 i = 0; i < _ids.length; i++) {
            safeTransferFrom(_from, _to, _ids[i], _amounts[i], _data);
        }
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public virtual override onlyOwner {
        require(
            _quantity <= _remainingSupply(_id),
            "BaseMusicBlock#mint: QUANTITY_EXCEEDS_TOKEN_SUPPLY_CAP"
        );
        _mint(_to, _id, _quantity, _data);
    }

    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public virtual override onlyOwner {
        for (uint256 i = 0; i < _ids.length; i++) {
            require(
                _quantities[i] <= _remainingSupply(_ids[i]),
                "BaseMusicBlock#batchMint: QUANTITY_EXCEEDS_TOKEN_SUPPLY_CAP"
            );
        }
        _batchMint(_to, _ids, _quantities, _data);
    }

    function _mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) internal override {
        super._mint(_to, _id, _quantity, _data);
        if (_data.length > 1) {
            _setURI(_id, string(_data));
        }
    }

    function _isCreatorOrProxy(uint256, address _address)
        internal
        view
        virtual
        returns (bool)
    {
        return _isOwner(_address);
    }

    function _remainingSupply(uint256 _id)
        internal
        view
        virtual
        returns (uint256)
    {
        return TOKEN_SUPPLY_CAP.sub(totalSupply(_id));
    }

    // Override ERC1155Tradable for birth events
    function _origin(
        uint256 /* _id */
    ) internal view virtual override returns (address) {
        return owner();
    }

    function _batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) internal override {
        super._batchMint(_to, _ids, _quantities, _data);
        if (_data.length > 1) {
            for (uint256 i = 0; i < _ids.length; i++) {
                _setURI(_ids[i], string(_data));
            }
        }
    }

    function _setURI(uint256 _id, string memory _uri) internal {
        _tokenURI[_id] = _uri;
        emit URI(_uri, _id);
    }
}

// File: contracts/TokenIdentifier.sol

pragma solidity >=0.6.0;

library TokenIdentifier {
    using SafeMath for uint256;

    uint8 constant ADDRESS_BITS = 160;
    uint8 constant INDEX_BITS = 56;
    uint8 constant SUPPLY_BITS = 40;
    uint8 constant FACTORY_OPTION_BITS = 8; // TokenIndex  = option (8bits) + index (48bits)

    uint256 constant SUPPLY_MASK = (uint256(1) << SUPPLY_BITS) - 1;
    uint256 constant INDEX_MASK = (uint256(1) << INDEX_BITS) - 1;

    function tokenMaxSupply(uint256 _id) internal pure returns (uint256) {
        return _id & SUPPLY_MASK;
    }

    function tokenIndex(uint256 _id) internal pure returns (uint256) {
        return (_id >> SUPPLY_BITS) & INDEX_MASK;
    }

    function tokenCreator(uint256 _id) internal pure returns (address) {
        return address(_id >> (INDEX_BITS + SUPPLY_BITS));
    }

    function factoryOption(uint256 _id) internal pure returns (uint256) {
        return tokenIndex(_id) >> (INDEX_BITS - FACTORY_OPTION_BITS);
    }
}

// File: contracts/MusicBlock.sol

pragma solidity >=0.6.0;

/**
 * @title MusicBlock
 */
contract MusicBlock is BaseMusicBlock, ReentrancyGuard {
    mapping(address => bool) public sharedProxyAddresses;
    using SafeMath for uint256;
    using TokenIdentifier for uint256;

    event CreatorChanged(uint256 indexed _id, address indexed _creator);

    mapping(uint256 => address) internal _creatorOverride;

    /**
     * @dev Require msg.sender to be the creator of the token id
     */
    modifier creatorOnly(uint256 _id) {
        require(
            _isCreatorOrProxy(_id, msg.sender),
            "MusicBlock#creatorOnly: ONLY_CREATOR_ALLOWED"
        );
        _;
    }

    constructor()
        BaseMusicBlock(
            "MELOS Music Token",
            "MELOSNFT",
            "https://meta.melos.finance/melosnft/"
        )
    {}

    /**
     * @dev Allows owner to add a shared proxy address
     */
    function addSharedProxyAddress(address _address) public onlyOwner {
        sharedProxyAddresses[_address] = true;
    }

    /**
     * @dev Allows owner to remove a shared proxy address
     */
    function removeSharedProxyAddress(address _address) public onlyOwner {
        delete sharedProxyAddresses[_address];
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public override nonReentrant() {
        _requireMintable(msg.sender, _id, _quantity);
        _mint(_to, _id, _quantity, _data);
    }

    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public override nonReentrant() {
        for (uint256 i = 0; i < _ids.length; i++) {
            _requireMintable(msg.sender, _ids[i], _quantities[i]);
        }
        _batchMint(_to, _ids, _quantities, _data);
    }

    /////////////////////////////////
    // CONVENIENCE CREATOR METHODS //
    /////////////////////////////////

    /**
     * @dev Will update the URI for the token
     * @param _id The token ID to update. msg.sender must be its creator.
     * @param _uri New URI for the token.
     */
    function setURI(uint256 _id, string memory _uri)
        public
        override
        creatorOnly(_id)
    {
        _setURI(_id, _uri);
    }

    /**
     * @dev Change the creator address for given token
     * @param _to   Address of the new creator
     * @param _id  Token IDs to change creator of
     */
    function setCreator(uint256 _id, address _to) public creatorOnly(_id) {
        require(_to != address(0), "MusicBlock#setCreator: INVALID_ADDRESS.");
        _creatorOverride[_id] = _to;
        emit CreatorChanged(_id, _to);
    }

    /**
     * @dev Get the creator for a token
     * @param _id   The token id to look up
     */
    function creator(uint256 _id) public view returns (address) {
        if (_creatorOverride[_id] != address(0)) {
            return _creatorOverride[_id];
        } else {
            return _id.tokenCreator();
        }
    }

    /**
     * @dev Get the maximum supply for a token
     * @param _id   The token id to look up
     */
    function maxSupply(uint256 _id) public pure returns (uint256) {
        return _id.tokenMaxSupply();
    }

    // Override ERC1155Tradable for birth events
    function _origin(uint256 _id) internal pure override returns (address) {
        return _id.tokenCreator();
    }

    function _requireMintable(
        address _address,
        uint256 _id,
        uint256 _amount
    ) internal view {
        require(
            _isCreatorOrProxy(_id, _address),
            "MusicBlock#_requireMintable: ONLY_CREATOR_ALLOWED"
        );
        require(
            _remainingSupply(_id) >= _amount,
            "MusicBlock#_requireMintable: SUPPLY_EXCEEDED"
        );
    }

    function _remainingSupply(uint256 _id)
        internal
        view
        override
        returns (uint256)
    {
        return maxSupply(_id).sub(totalSupply(_id));
    }

    function _isCreatorOrProxy(uint256 _id, address _address)
        internal
        view
        override
        returns (bool)
    {
        address creator_ = creator(_id);
        return creator_ == _address || _isProxyForUser(creator_, _address);
    }

    // Overrides ERC1155Tradable to allow a shared proxy address
    function _isProxyForUser(address _user, address _address)
        internal
        view
        override
        returns (bool)
    {
        if (sharedProxyAddresses[_address]) {
            return true;
        }
        return super._isProxyForUser(_user, _address);
    }
}