// File: lib/solmate/src/auth/Owned.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}


// File: lib/solmate/src/tokens/ERC1155.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Minimalist and gas efficient standard ERC1155 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[to][ids[i]] += amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[from][ids[i]] -= amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[from][id] -= amount;

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}


// File: lib/solmate/src/utils/ReentrancyGuard.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    uint256 private locked = 1;

    modifier nonReentrant() virtual {
        require(locked == 1, "REENTRANCY");

        locked = 2;

        _;

        locked = 1;
    }
}


// File: src/SevenDeadlySins.sol
// SPDX-License-Identifier: UNLICENSED
/* 
 ______ ______ _____  ___ ______ _   __   __  _____ _____ _   _  _____ 
|___  / |  _  \  ___|/ _ \|  _  \ |  \ \ / / /  ___|_   _| \ | |/  ___|
   / /  | | | | |__ / /_\ \ | | | |   \ V /  \ `--.  | | |  \| |\ `--. 
  / /   | | | |  __||  _  | | | | |    \ /    `--. \ | | | . ` | `--. \
./ /    | |/ /| |___| | | | |/ /| |____| |   /\__/ /_| |_| |\  |/\__/ /
\_/     |___/ \____/\_| |_/___/ \_____/\_/   \____/ \___/\_| \_/\____/ 

*/   
pragma solidity ^0.8.17;

/// @title Seven Deadly Sins
/// @author @CM4YN3Z

import "solmate/tokens/ERC1155.sol";
import "solmate/auth/Owned.sol";
import "solmate/utils/ReentrancyGuard.sol";

contract SevenDeadlySins is ERC1155, Owned, ReentrancyGuard {

    string public name;
    string public symbol;
    uint public receiveTokenId;

    struct Token {
        string uri;
        uint price;
        uint incrementor;
        bool mintActive;
    }
    
    mapping(uint => Token) public tokens;

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    )Owned(_owner){
        name = _name;
        symbol = _symbol;
    }

    receive() external payable {
        mint(receiveTokenId);
    }

    /// @notice Mints a token and increases the token price by the value stored in the incrementor.
    /// @param tokenId uint ID of the token to be minted.
    function mint(uint tokenId) public payable nonReentrant {
        require(tokens[tokenId].mintActive, "SevenDeadlySins: Minting is not active");
        require(msg.value >= tokens[tokenId].price, "SevenDeadlySins: Incorrect payment amount");
        _mint(msg.sender, tokenId, 1, "");
        tokens[tokenId].price += tokens[tokenId].incrementor;
    }
    
    /// @notice Returns the URI for a given token ID.
    /// @param tokenId uint ID of the token to query
    /// @return URI of given token ID
    function uri(uint tokenId) public view override returns (string memory) {
        return tokens[tokenId].uri;
    }

    /// @notice Owner function to set the token URI for a given token ID.
    /// @param tokenId uint ID of the token to set the URI for.
    /// @param newURI string memory new URI value.
    function setTokenURI(uint tokenId, string memory newURI) external onlyOwner {
        tokens[tokenId].uri = newURI;
    }

    /// @notice Owner function to set the token price for a given token ID.
    /// @param tokenId uint ID of the token to set the price for.
    /// @param newTokenPrice uint new price value.
    function setTokenPrice(uint tokenId, uint newTokenPrice) external onlyOwner {
        tokens[tokenId].price = newTokenPrice;
    }

    /// @notice Owner function to set the incrementor that is added to the price after each mint.
    /// @param tokenId uint ID of the token to set the incrementor for.
    /// @param newTokenIncrementor uint new incrementor value in wei.
    /// @dev The value defaults to 0, so if no incrementor is set, the price of the token will be constant.
    function setTokenIncrementor(uint tokenId, uint newTokenIncrementor) external onlyOwner {
        tokens[tokenId].incrementor = newTokenIncrementor;
    }

    /// @notice Owner function to set the tokenID that is minted when ether is sent to the contract.
    /// @param tokenId uint ID of the token to set the receiveTokenId for.
    /// @dev This value defaults to 0, so if no receiveTokenId is set, the contract will always mint the token with ID 0.
    function setReceiveTokenId(uint tokenId) external onlyOwner {
        receiveTokenId = tokenId;
    }

    /// @notice Owner function to activate a token for minting.
    /// @param tokenId uint ID of the token to be activated.
    function flipMintActive(uint tokenId) external onlyOwner {
        tokens[tokenId].mintActive = !tokens[tokenId].mintActive;
    }

    /// @notice Owner function to withdraw ETH from the contract.
    function withdrawETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

}

