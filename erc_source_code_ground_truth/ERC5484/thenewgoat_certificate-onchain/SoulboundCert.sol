// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IERC5484.sol";

contract SoulboundCert is ERC721, AccessControl, IERC5484 {
    /// Define a role identifier for the minter role.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// The designated issuer (constant for this organization).
    address public issuer;

    /**
     * @notice A contract-level description, e.g., describing
     *         the organization or purpose of this soulbound certificate contract.
     */
    string public contractDescription;

    /// Counter for token IDs.
    uint256 private _currentTokenId;

    /// Mapping from tokenId to burn authorization.
    mapping(uint256 => BurnAuth) private _burnAuth;

    /// Base URI for all token metadata (e.g. "ipfs://QmXYZ123/").
    /// tokenURI(tokenId) will append tokenId + ".json".
    string private _baseURIextended;

    /**
     * @dev Constructor sets up the contract-level description,
     *      the constant issuer, and grants the MINTER_ROLE to `minter_`.
     * @param baseURI_ The base IPFS or HTTP URI (must end with a slash, e.g. "ipfs://QmXYZ123/").
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory contractDescription_,
        address issuer_,
        address minter_,
        string memory baseURI_
    ) ERC721(name_, symbol_) {
        contractDescription = contractDescription_;
        issuer = issuer_;

        // The issuer becomes the default admin (can grant/revoke roles).
        _setupRole(DEFAULT_ADMIN_ROLE, issuer_);
        // Grant the minter role to the designated minting wallet.
        _setupRole(MINTER_ROLE, minter_);

        _baseURIextended = baseURI_;
    }

    /**
     * @notice Issues a new soulbound certificate with a predetermined burn authorization.
     * @dev Can only be called by an account with MINTER_ROLE.
     */
    function issueCertificate(
        address to,
        BurnAuth burnAuthType
    ) external {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not designated minter");

        uint256 tokenId = _currentTokenId;
        _mint(to, tokenId);

        // Set burn authorization.
        _burnAuth[tokenId] = burnAuthType;

        emit Issued(issuer, to, tokenId, burnAuthType);
        _currentTokenId++;
    }

    /**
     * @notice Returns the burn authorization for a given token.
     */
    function burnAuth(uint256 tokenId) external view override returns (BurnAuth) {
        require(_exists(tokenId), "Query for nonexistent token");
        return _burnAuth[tokenId];
    }

    /**
     * @notice Allows burning of a token according to its predetermined burn authorization.
     */
    function burn(uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        BurnAuth auth = _burnAuth[tokenId];

        if (auth == BurnAuth.IssuerOnly) {
            require(msg.sender == issuer, "Only issuer can burn");
        } else if (auth == BurnAuth.OwnerOnly) {
            require(msg.sender == tokenOwner, "Only token owner can burn");
        } else if (auth == BurnAuth.Both) {
            require(
                msg.sender == issuer || msg.sender == tokenOwner,
                "Not authorized to burn"
            );
        } else {
            revert("Token is non-burnable");
        }

        _burn(tokenId);
    }

    /**
     * @dev Override _transfer to prevent transfers (making tokens soulbound).
     */
    function _transfer(address from, address to, uint256 tokenId) internal override {
        revert("Token is soulbound and non-transferable");
    }

    /**
     * @notice Resolves multiple inheritance conflict between ERC721 and AccessControl.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Override ERC721's baseURI function.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    /**
     * @notice The standard ERC-721 tokenURI function.
     *         It returns baseURI + tokenId + ".json"
     *         For example: "ipfs://QmXYZ123/0.json"
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Nonexistent token");

        string memory base = _baseURI();
        return bytes(base).length > 0
            ? string(abi.encodePacked(base, Strings.toString(tokenId), ".json"))
            : "";
    }
}
