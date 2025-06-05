// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILibroBuddyParts} from "./ILibroBuddyParts.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC4883} from "./IERC4883.sol";
import {IERC6454} from "./IERC6454.sol";
import {LibroBuddyUtils} from "../lib/LibroBuddyUtils.sol";

interface ILibroBuddy is IERC721, IERC6454, IERC4883 {
    event LibroBuddyPartSet(uint256 indexed tokenId, LibroBuddyUtils.LibroBuddyPart part, uint256 partId);

    function width() external view returns (uint256);
    function height() external view returns (uint256);
    function partEquipped(uint256 tokenId)
        external
        view
        returns (ILibroBuddyParts[] memory parts, uint256[] memory partIds);
    function mintBuddy(address to) external;
    function createPart(LibroBuddyUtils.LibroBuddyPart partType, string memory data, bool isSvg) external;
    function mintParts(LibroBuddyUtils.LibroBuddyPart partType, address to, uint256 partId) external;
    function mintPartsToBatch(LibroBuddyUtils.LibroBuddyPart partType, address[] memory to, uint256 partId) external;
    function setPart(uint256 tokenId, LibroBuddyUtils.LibroBuddyPart part, uint256 partId) external;
    function setParts(uint256 tokenId, LibroBuddyUtils.LibroBuddyPart[] memory parts, uint256[] memory partIds)
        external;
}
