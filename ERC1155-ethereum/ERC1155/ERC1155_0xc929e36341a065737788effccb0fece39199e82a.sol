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


// File: src/GRAZ.sol
//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//
//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//
//@@@@@@@@@@     @@@@@@@@           @@@@@@@@@@@@@@@   @@@@@@@@@@              @@@@//
//@@@@@@             @@@@               @@@@@@@@@@     @@@@@@@@@              @@@@//
//@@@@      @@@@@     @@@    @@@@@@@     @@@@@@@@       @@@@@@@@@@@@@@@@@     @@@@//
//@@@@     @@@@@@@@@@@@@@    @@@@@@@     @@@@@@@@        @@@@@@@@@@@@@@     @@@@@@//
//@@@@     @@@@        @@               @@@@@@@     @@    @@@@@@@@@@@     @@@@@@@@//
//@@@@     @@@@        @@            @@@@@@@@@     @@@@    @@@@@@@@#     @@@@@@@@@//
//@@@@     @@@@@@@     @@    @@@@     @@@@@@@               @@@@@@     @@@@@@@@@@@//
//@@@@@               @@@    @@@@@@     @@@@                 @@@               @@@//
//@@@@@@@           @@@@@    @@@@@@@     @@     @@@@@@@@@@    @@               @@@//
//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//
//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//

import { Owned } from "solmate/auth/Owned.sol";
import { ERC1155 } from "solmate/tokens/ERC1155.sol";
import { IGRAZ, Edition } from "./interfaces/IGRAZ.sol";

contract GRAZ is Owned, ERC1155, IGRAZ {
    /*//////////////////////////////////////////////////////////////
                                 Errors
    //////////////////////////////////////////////////////////////*/

    error InvalidOwnerAddress();
    error InvalidWithdrawReceiverAddress();
    error InvalidFactoryAddress();
    error SupplyLimit();
    error MintNotStarted();
    error PayTheFee();
    error ReachedLimit();
    error InvalidMintQuantity();
    error CallerIsNotEOA();
    error CallerIsNotOwnerOrFactory();

    /*//////////////////////////////////////////////////////////////
                                 State vars
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Flag which determines if minting is allowed or not
     */
    bool public mintStarted;

    /**
     * @notice Address of a factory contract
     * @dev external contract to be used in the future for other interactions
     */
    address public grazFactory;

    /**
     * @notice The name of the contract
     */
    string public name;

    /**
     * @notice The symbol of the contract
     */
    string public symbol;

    /**
     * @notice Mapping containing the minted tokens for each edition
     */
    mapping(uint256 => uint256) public editionSupply;

    /**
     * @notice Array containing all editions
     */
    Edition[] public editions;

    /*//////////////////////////////////////////////////////////////
                                 Modifiers
    //////////////////////////////////////////////////////////////*/

    modifier onlyEOA() {
        if (tx.origin != msg.sender) revert CallerIsNotEOA();
        _;
    }

    modifier onlyOwnerOrFactory() {
        if (msg.sender != grazFactory && msg.sender != owner) revert CallerIsNotOwnerOrFactory();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 Constructor
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol, address owner) Owned(owner) {
        if (owner == address(0)) revert InvalidOwnerAddress();
        name = _name;
        symbol = _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                                 Functions start
    //////////////////////////////////////////////////////////////*/

    /// MINTING FUNCTIONS

    function ownerMint(address reciever, uint256 tokenId, uint256 quantity) external onlyOwner {
        if (quantity == 0) revert InvalidMintQuantity();
        Edition storage edition = editions[tokenId];
        if (editionSupply[tokenId] + quantity > edition.maxSupply) {
            revert SupplyLimit();
        }
        editionSupply[tokenId] += quantity;
        _mint(reciever, tokenId, quantity, "");
    }

    function mintToken(uint256 tokenId, uint256 quantity) external payable onlyEOA {
        if (quantity == 0) revert InvalidMintQuantity();

        if (mintStarted == false) {
            revert MintNotStarted();
        }

        Edition storage edition = editions[tokenId];

        if (msg.value < (quantity * edition.editionPrice)) {
            revert PayTheFee();
        }
        if (balanceOf[msg.sender][tokenId] + quantity > edition.mintCap) {
            revert ReachedLimit();
        }

        if (editionSupply[tokenId] + quantity > edition.maxSupply) {
            revert SupplyLimit();
        }

        editionSupply[tokenId] += quantity;
        _mint(msg.sender, tokenId, quantity, "");
    }

    /// BURNING FUNCTIONS

    function burnToken(address from, uint256 id, uint256 amount) external onlyOwnerOrFactory {
        _burn(from, id, amount);
    }

    function batchBurnTokens(address from, uint256[] memory ids, uint256[] memory amounts) external onlyOwnerOrFactory {
        _batchBurn(from, ids, amounts);
    }

    /// MANAGEMENT FUNCTIONS

    function toggleMint() external onlyOwner {
        mintStarted = !mintStarted;
    }

    function setFactoryAddress(address factory) external onlyOwner {
        if (factory.code.length == 0) revert InvalidFactoryAddress();
        grazFactory = factory;
    }

    function createEdition(uint256 _supply, uint256 _price, string memory _uri, uint256 _mintCap) external onlyOwner {
        editions.push(Edition(_supply, _price, _uri, _mintCap));
    }

    function editEdition(uint256 _tokenId, uint256 _supply, uint256 _price, string memory _uri, uint256 _mintCap) external onlyOwner {
        Edition storage edition = editions[_tokenId];
        edition.maxSupply = _supply;
        edition.editionPrice = _price;
        edition.editionURI = _uri;
        edition.mintCap = _mintCap;
    }

    function withdrawFunds(address receiver) external onlyOwner {
        if (receiver == address(0)) revert InvalidWithdrawReceiverAddress();
        uint256 balance = address(this).balance;
        payable(receiver).transfer(balance);
    }

    /// VIEW FUNCTIONS

    function uri(uint256 tokenId) public view override returns (string memory) {
        Edition storage edition = editions[tokenId];
        return edition.editionURI;
    }
}


// File: src/interfaces/IGRAZ.sol
//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//
//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//
//@@@@@@@@@@     @@@@@@@@           @@@@@@@@@@@@@@@   @@@@@@@@@@              @@@@//
//@@@@@@             @@@@               @@@@@@@@@@     @@@@@@@@@              @@@@//
//@@@@      @@@@@     @@@    @@@@@@@     @@@@@@@@       @@@@@@@@@@@@@@@@@     @@@@//
//@@@@     @@@@@@@@@@@@@@    @@@@@@@     @@@@@@@@        @@@@@@@@@@@@@@     @@@@@@//
//@@@@     @@@@        @@               @@@@@@@     @@    @@@@@@@@@@@     @@@@@@@@//
//@@@@     @@@@        @@            @@@@@@@@@     @@@@    @@@@@@@@#     @@@@@@@@@//
//@@@@     @@@@@@@     @@    @@@@     @@@@@@@               @@@@@@     @@@@@@@@@@@//
//@@@@@               @@@    @@@@@@     @@@@                 @@@               @@@//
//@@@@@@@           @@@@@    @@@@@@@     @@     @@@@@@@@@@    @@               @@@//
//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//
//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//

import { Owned } from "solmate/auth/Owned.sol";
import { ERC1155 } from "solmate/tokens/ERC1155.sol";

struct Edition {
    uint256 maxSupply;
    uint256 editionPrice;
    string editionURI;
    uint256 mintCap;
}

interface IGRAZ {
    /*//////////////////////////////////////////////////////////////
                                 Functions start
    //////////////////////////////////////////////////////////////*/

    /// MINTING FUNCTIONS

    function ownerMint(address reciever, uint256 tokenId, uint256 quantity) external;

    function mintToken(uint256 tokenId, uint256 quantity) external payable;

    /// BURNING FUNCTIONS

    function burnToken(address from, uint256 id, uint256 amount) external;

    function batchBurnTokens(address from, uint256[] memory ids, uint256[] memory amounts) external;

    /// MANAGEMENT FUNCTIONS

    function toggleMint() external;

    function setFactoryAddress(address factory) external;

    function createEdition(uint256 _supply, uint256 _price, string memory _uri, uint256 _mintCap) external;

    function editEdition(uint256 _tokenId, uint256 _supply, uint256 _price, string memory _uri, uint256 _mintCap) external;

    function withdrawFunds(address receiver) external;

    /// VIEW FUNCTIONS

    function mintStarted() external view returns (bool);

    function grazFactory() external view returns (address);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function editionSupply(uint256) external view returns (uint256);

    function editions(uint256) external view returns (uint256, uint256, string memory, uint256);
}


