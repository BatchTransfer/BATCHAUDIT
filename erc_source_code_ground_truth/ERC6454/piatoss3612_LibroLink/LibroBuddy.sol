// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILibroBuddy, IERC6454, IERC4883} from "./interfaces/ILibroBuddy.sol";
import {ILibroBuddyParts} from "./interfaces/ILibroBuddyParts.sol";
import {LibroBuddyParts} from "./LibroBuddyParts.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {LibroBuddyUtils} from "./lib/LibroBuddyUtils.sol";

/**
 * @title LibroNFT
 * @author piatoss3612
 * @dev Basic ERC721 token.
 */
contract LibroBuddy is ILibroBuddy, ERC721, AccessControl {
    error LibroBuddy__Soulbound();
    error LibroBuddy__OnlyOwnerOfToken(uint256 tokenId);
    error LibroBuddy__InvalidPart();
    error LibroBuddy__NotOwnedPart(ILibroBuddyParts part, uint256 partId);

    bytes32 public constant BUDDY_MINER_ROLE = keccak256("BUDDY_MINER_ROLE");
    bytes32 public constant PART_MINER_ROLE = keccak256("PART_MINER_ROLE");

    uint256 private _tokenId;
    uint256 private _width;
    uint256 private _height;

    ILibroBuddyParts[] private _parts;
    mapping(uint256 => mapping(ILibroBuddyParts => uint256)) private _partEquipped;

    constructor() ERC721("LibroBuddy", "LB") {
        _setRoleAdmin(BUDDY_MINER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PART_MINER_ROLE, DEFAULT_ADMIN_ROLE);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        ILibroBuddyParts background = new LibroBuddyParts(
            LibroBuddyUtils.LibroBuddyPartInitParams({
                partId: 1,
                data: LibroBuddyUtils.LibroBuddyPartData({x: 0, y: 0, width: 400, height: 400}),
                defaultUri: "",
                gateway: "https://green-main-hoverfly-930.mypinata.cloud"
            })
        );
        ILibroBuddyParts buddy = new LibroBuddyParts(
            LibroBuddyUtils.LibroBuddyPartInitParams({
                partId: 0,
                data: LibroBuddyUtils.LibroBuddyPartData({x: 0, y: 0, width: 400, height: 400}),
                defaultUri: "",
                gateway: "https://green-main-hoverfly-930.mypinata.cloud"
            })
        );
        ILibroBuddyParts leftOrnament = new LibroBuddyParts(
            LibroBuddyUtils.LibroBuddyPartInitParams({
                partId: 2,
                data: LibroBuddyUtils.LibroBuddyPartData({x: 0, y: 200, width: 160, height: 160}),
                defaultUri: "",
                gateway: "https://green-main-hoverfly-930.mypinata.cloud"
            })
        );
        ILibroBuddyParts rightOrnament = new LibroBuddyParts(
            LibroBuddyUtils.LibroBuddyPartInitParams({
                partId: 3,
                data: LibroBuddyUtils.LibroBuddyPartData({x: 240, y: 200, width: 160, height: 160}),
                defaultUri: "",
                gateway: "https://green-main-hoverfly-930.mypinata.cloud"
            })
        );

        // background -> buddy -> leftOrnament -> rightOrnament order (z-index)
        _parts = [background, buddy, leftOrnament, rightOrnament];
    }

    function width() public view override returns (uint256) {
        return _width;
    }

    function height() public view override returns (uint256) {
        return _height;
    }

    function partEquipped(uint256 tokenId)
        public
        view
        override
        returns (ILibroBuddyParts[] memory parts, uint256[] memory partIds)
    {
        _requireOwned(tokenId);

        parts = _parts;
        partIds = new uint256[](parts.length);

        for (uint256 i = 0; i < parts.length; i++) {
            partIds[i] = _partEquipped[tokenId][parts[i]];
        }
    }

    /**
     * @dev Mints a new token to the given address.
     * @param to address to mint the token to.
     */
    function mintBuddy(address to) external onlyRole(BUDDY_MINER_ROLE) {
        uint256 tokenId = _tokenId++;
        _safeMint(to, tokenId);
    }

    function createPart(LibroBuddyUtils.LibroBuddyPart partType, string memory data, bool isSvg)
        external
        onlyRole(PART_MINER_ROLE)
    {
        ILibroBuddyParts part = _requirePartExists(partType);
        part.create(data, isSvg);
    }

    function mintParts(LibroBuddyUtils.LibroBuddyPart partType, address to, uint256 partId)
        external
        onlyRole(PART_MINER_ROLE)
    {
        ILibroBuddyParts part = _requirePartExists(partType);
        part.mint(to, partId);
    }

    function mintPartsToBatch(LibroBuddyUtils.LibroBuddyPart partType, address[] memory to, uint256 partId)
        external
        onlyRole(PART_MINER_ROLE)
    {
        ILibroBuddyParts part = _requirePartExists(partType);
        part.mintToBatch(to, partId);
    }

    function _requirePartExists(LibroBuddyUtils.LibroBuddyPart partType)
        internal
        view
        returns (ILibroBuddyParts part)
    {
        for (uint256 i = 0; i < _parts.length; i++) {
            if (_parts[i].part() == partType) {
                part = _parts[i];
            }
        }

        if (address(part) == address(0x0)) {
            revert LibroBuddy__InvalidPart();
        }
    }

    function setPart(uint256 tokenId, LibroBuddyUtils.LibroBuddyPart part, uint256 partId) external override {
        address owner = _requireOwned(tokenId);
        if (owner != _msgSender()) {
            revert LibroBuddy__OnlyOwnerOfToken(tokenId);
        }

        ILibroBuddyParts partContract = _requirePartExists(part);

        if (partContract.balanceOf(owner, partId) == 0) {
            revert LibroBuddy__NotOwnedPart(partContract, partId);
        }

        _partEquipped[tokenId][partContract] = partId;

        emit LibroBuddyPartSet(tokenId, part, partId);
    }

    function setParts(uint256 tokenId, LibroBuddyUtils.LibroBuddyPart[] memory parts, uint256[] memory partIds)
        external
        override
    {
        address owner = _requireOwned(tokenId);
        if (owner != _msgSender()) {
            revert LibroBuddy__OnlyOwnerOfToken(tokenId);
        }

        if (parts.length != partIds.length) {
            revert LibroBuddy__InvalidPart();
        }

        for (uint256 i = 0; i < parts.length; i++) {
            ILibroBuddyParts part = _parts[i];

            if (part.balanceOf(owner, partIds[i]) == 0) {
                revert LibroBuddy__NotOwnedPart(part, partIds[i]);
            }

            _partEquipped[tokenId][part] = partIds[i];

            emit LibroBuddyPartSet(tokenId, parts[i], partIds[i]);
        }
    }

    /**
     * @dev Burns the token.
     */
    function burn(uint256 tokenId) external {
        _requireOwned(tokenId);
        _burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        string memory name = string(abi.encodePacked("LibroBuddy #", Strings.toString(tokenId)));
        string memory description = "LibroBuddy is a collection of LibroLink NFTs. Let's build a book club together!";
        string memory image = Base64.encode(bytes(_generateSVG(tokenId)));

        uri = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name,
                            '","description":"',
                            description,
                            '","image":"data:image/svg+xml;base64,',
                            image,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    function _generateSVG(uint256 tokenId) internal view returns (string memory svg) {
        string memory render = renderTokenById(tokenId);
        svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ',
                Strings.toString(_width),
                " ",
                Strings.toString(_height),
                '">',
                render,
                "</svg>"
            )
        );
    }

    function renderTokenById(uint256 id) public view returns (string memory render) {
        address owner = _requireOwned(id);

        ILibroBuddyParts[] memory parts = _parts;

        render = '<g id="libro-buddy">';

        for (uint256 i = 0; i < parts.length;) {
            ILibroBuddyParts part = parts[i];
            uint256 equipped = _partEquipped[id][part];

            if (part.balanceOf(owner, equipped) > 0) {
                render = string(abi.encodePacked(render, part.renderTokenById(equipped)));
            }
        }

        render = string(abi.encodePacked(render, "</g>"));
    }

    /**
     * @notice Used to check whether the given token is transferable or not.
     * @dev IERC-6454 implementation.
     * @param tokenId token id to check
     * @param from address from which the token is being transferred
     * @param to address to which the token is being transferred
     * @return Boolean value indicating whether the given token is transferable
     */
    function isTransferable(uint256 tokenId, address from, address to) public view returns (bool) {
        /*
            Only allow:
            - Minting tokens to Non-Zero address
            - Burning tokens by sending to Zero address
         */

        if (from == address(0x0) && to == address(0x0)) {
            return false;
        }

        if (from == address(0x0) || to == address(0x0)) {
            return true;
        }

        _requireOwned(tokenId);

        // Disallow transfer of tokens.
        return false;
    }

    /**
     * @dev Overriding ERC721 _update function to add transfer restrictions.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);

        // Only allow minting and burning of tokens.
        if (isTransferable(tokenId, from, to)) {
            return super._update(to, tokenId, auth);
        }

        // Revert by default.
        revert LibroBuddy__Soulbound();
    }

    /**
     * @dev Overriding IERC-165 supportsInterface function to add support for ILibroBuddy and IERC6454 interfaces.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl, IERC165)
        returns (bool)
    {
        return interfaceId == type(ILibroBuddy).interfaceId || interfaceId == type(IERC6454).interfaceId
            || interfaceId == type(IERC4883).interfaceId || super.supportsInterface(interfaceId);
    }
}
