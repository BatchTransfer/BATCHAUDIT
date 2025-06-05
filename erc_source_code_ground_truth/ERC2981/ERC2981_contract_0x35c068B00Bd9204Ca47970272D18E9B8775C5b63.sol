// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {MultiOwnable} from "./MultiOwnable.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC2981} from "openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {DefaultOperatorFilterer} from "operator-filter-registry/DefaultOperatorFilterer.sol";

import {IAzurian} from "./AzurRoot.sol";

contract Azurian is IAzurian, DefaultOperatorFilterer, ERC721, ERC2981, MultiOwnable {
    /// @notice The Azur Root contract
    address public immutable ROOT;

    /// @notice Total number of tokens which have minted
    uint256 public totalSupply = 0;

    /// @notice The prefix to attach to the tokenId to get the metadata uri
    string public baseTokenURI;

    /// @notice Whether the minting is open
    bool public mintOpen;

    /// @notice Thrown when the mint is not yet open
    error MintNotOpen();

    /// @notice Thrown when metadata is queried for a nonexistent token
    error TokenDoesNotExist();

    constructor(address _root) ERC721("Azurian", "AZUR") {
        ROOT = _root;
    }

    function burnRootAndMint(uint256[] calldata rootIds) external {
        if (msg.sender != ROOT) revert AccessControl();
        if (!mintOpen) revert MintNotOpen();
        unchecked {
            for (uint256 i = 0; i < rootIds.length; ++i) {
                _mint(tx.origin, rootIds[i]);
            }
        }
        totalSupply += rootIds.length;
    }

    /////////////////////////
    // ADMIN FUNCTIONALITY //
    /////////////////////////

    /// @notice Set metadata
    function setBaseTokenURI(string memory _baseTokenURI) external {
        if (msg.sender != metadataOwner) {
            revert AccessControl();
        }
        baseTokenURI = _baseTokenURI;
    }

    /// @notice Set mint open
    function setMintOpen(bool _mintOpen) external {
        if (msg.sender != mintingOwner) {
            revert AccessControl();
        }
        mintOpen = _mintOpen;
    }

    // ROYALTY FUNCTIONALITY

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public pure override(ERC721, ERC2981) returns (bool) {
        return interfaceId == 0x2a55205a // ERC165 Interface ID for ERC2981
            || interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /// @dev See {ERC2981-_setDefaultRoyalty}.
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /// @dev See {ERC2981-_deleteDefaultRoyalty}.
    function deleteDefaultRoyalty() external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _deleteDefaultRoyalty();
    }

    /// @dev See {ERC2981-_setTokenRoyalty}.
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /// @dev See {ERC2981-_resetTokenRoyalty}.
    function resetTokenRoyalty(uint256 tokenId) external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _resetTokenRoyalty(tokenId);
    }

    // METADATA FUNCTIONALITY

    /// @notice Returns the metadata URI for a given token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }

    // OPERATOR FILTER

    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) internal _ownerOf;

    mapping(address => uint256) internal _balanceOf;

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        require((owner = _ownerOf[id]) != address(0), "NOT_MINTED");
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        return _balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {
        address owner = _ownerOf[id];

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        require(from == _ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");

        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = _ownerOf[id];

        require(owner != address(0), "NOT_MINTED");

        // Ownership check above ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        delete _ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/common/ERC2981.sol)

pragma solidity ^0.8.0;

import "../../interfaces/IERC2981.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the NFT Royalty Standard, a standardized way to retrieve royalty payment information.
 *
 * Royalty information can be specified globally for all token ids via {_setDefaultRoyalty}, and/or individually for
 * specific token ids via {_setTokenRoyalty}. The latter takes precedence over the first.
 *
 * Royalty is specified as a fraction of sale price. {_feeDenominator} is overridable but defaults to 10000, meaning the
 * fee is specified in basis points by default.
 *
 * IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its payment. See
 * https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the EIP. Marketplaces are expected to
 * voluntarily pay royalties together with sales, but note that this standard is not yet widely supported.
 *
 * _Available since v4.5._
 */
abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view virtual override returns (address, uint256) {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    /**
     * @dev The denominator with which to interpret the fee set in {_setTokenRoyalty} and {_setDefaultRoyalty} as a
     * fraction of the sale price. Defaults to 10000 so fees are expressed in basis points, but may be customized by an
     * override.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Removes default royalty information.
     */
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Resets royalty information for the token id back to the global default.
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
}// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {MultiOwnable} from "./MultiOwnable.sol";
import {IDelegationRegistry} from "./IDelegationRegistry.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC2981} from "openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {DefaultOperatorFilterer} from "operator-filter-registry/DefaultOperatorFilterer.sol";

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 id) external;
}

interface IAzurian {
    function burnRootAndMint(uint256[] calldata rootIds) external;
}

contract AzurRoot is DefaultOperatorFilterer, ERC721, ERC2981, MultiOwnable {
    /// @notice The Bored and Dangerous contract
    address public immutable BOOK;

    /// @notice Total number of tokens which have minted
    uint256 public totalSupply = 0;

    /// @notice The prefix to attach to the tokenId to get the metadata uri
    string public baseTokenURI;

    /// @notice Whether the burning is open
    bool public burnOpen;

    /// @notice The delegation registry for burning root authentication
    IDelegationRegistry public constant delegationRegistry =
        IDelegationRegistry(0x00000000000076A84feF008CDAbe6409d2FE638B);

    /// @notice Emitted when a token is minted
    event Mint(address indexed owner, uint256 indexed tokenId);

    /// @notice Raised when the mint has not reached the required timestamp
    error MintNotOpen();
    /// @notice Raised when two calldata arrays do not have the same length
    error MismatchedArrays();
    /// @notice Raised when `sender` does not pass the proper ether amount to `recipient`
    error FailedToSendEther(address sender, address recipient);
    /// @notice Raised when `msg.sender` does not own the roots they're attempting to burn
    error BurnAuthentication();

    constructor(address _book) ERC721("Azur Root", "ROOT") {
        BOOK = _book;
    }

    /// @notice Admin mint a batch of tokens
    function ownerMint(address[] calldata recipients) external {
        if (msg.sender != mintingOwner) {
            revert AccessControl();
        }

        unchecked {
            uint256 _totalSupply = totalSupply;
            for (uint256 i = 0; i < recipients.length; ++i) {
                _mint(recipients[i], _totalSupply + i);
            }
            totalSupply += recipients.length;
        }
    }

    /// @notice Burn a token
    function burn(uint256 id) external {
        address from = _ownerOf[id];
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id], "NOT_AUTHORIZED"
        );
        _burn(id);
    }

    //////////////////
    // BOOK BURNING //
    //////////////////

    /// @notice Burn a book to receive an azur root
    function burnBooks(uint256[] calldata tokenIds) external {
        if (!burnOpen) {
            revert MintNotOpen();
        }

        // Cache the totalSupply to minimize storage reads
        uint256 _totalSupply = totalSupply;
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            // Attempt to transfer token from the msg sender, revert if not owned or approved
            IERC721(BOOK).transferFrom(msg.sender, address(this), tokenIds[i]);
            _mint(msg.sender, _totalSupply + i);
        }
        totalSupply += tokenIds.length;
    }

    /// @notice Burn a root to receive an azurian
    function burnRoots(address azurians, uint256[] calldata rootIds) external {
        for (uint256 i = 0; i < rootIds.length; ++i) {
            address rootOwner = ownerOf(rootIds[i]);
            if (
                !(
                    msg.sender == rootOwner
                        || delegationRegistry.checkDelegateForToken(msg.sender, rootOwner, address(this), rootIds[i])
                )
            ) {
                revert BurnAuthentication();
            }
            _burn(rootIds[i]);
        }
        IAzurian(azurians).burnRootAndMint(rootIds);
    }

    /////////////////////////
    // ADMIN FUNCTIONALITY //
    /////////////////////////

    /// @notice Set metadata
    function setBaseTokenURI(string memory _baseTokenURI) external {
        if (msg.sender != metadataOwner) {
            revert AccessControl();
        }
        baseTokenURI = _baseTokenURI;
    }

    /// @notice Set burn open
    function setBurnOpen(bool _burnOpen) external {
        if (msg.sender != mintingOwner) {
            revert AccessControl();
        }
        burnOpen = _burnOpen;
    }

    /// @notice Claim funds
    function claimFunds(address payable recipient) external {
        if (!(msg.sender == mintingOwner || msg.sender == metadataOwner || msg.sender == royaltyOwner)) {
            revert AccessControl();
        }

        (bool sent,) = recipient.call{value: address(this).balance}("");
        if (!sent) {
            revert FailedToSendEther(address(this), recipient);
        }
    }

    // ROYALTY FUNCTIONALITY

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public pure override(ERC721, ERC2981) returns (bool) {
        return interfaceId == 0x2a55205a // ERC165 Interface ID for ERC2981
            || interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /// @dev See {ERC2981-_setDefaultRoyalty}.
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /// @dev See {ERC2981-_deleteDefaultRoyalty}.
    function deleteDefaultRoyalty() external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _deleteDefaultRoyalty();
    }

    /// @dev See {ERC2981-_setTokenRoyalty}.
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /// @dev See {ERC2981-_resetTokenRoyalty}.
    function resetTokenRoyalty(uint256 tokenId) external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _resetTokenRoyalty(tokenId);
    }

    // METADATA FUNCTIONALITY

    /// @notice Returns the metadata URI for a given token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }

    // OPERATOR FILTER

    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}