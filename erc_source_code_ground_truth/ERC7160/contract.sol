// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IERC7160} from "./IERC7160.sol";

contract MultiMetadata is ERC721, Ownable, IERC7160, IERC4906 {
  mapping(uint256 => string[]) private _tokenURIs;
  mapping(uint256 => uint256) private _pinnedURIIndices;
  mapping(uint256 => bool) private _hasPinnedTokenURI;

  constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) Ownable() {
    _mint(msg.sender, 1);
  }

  // @notice Returns the pinned URI index or the last token URI index (length - 1).
  function _getTokenURIIndex(uint256 tokenId) internal view returns (uint256) {
    return _hasPinnedTokenURI[tokenId] ? _pinnedURIIndices[tokenId] : _tokenURIs[tokenId].length - 1;
  }

  // @notice Implementation of ERC721.tokenURI for backwards compatibility.
  // @inheritdoc ERC721.tokenURI
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    _requireMinted(tokenId);

    uint256 index = _getTokenURIIndex(tokenId);
    string[] memory uris = _tokenURIs[tokenId];
    string memory uri = uris[index];

    // Revert if no URI is found for the token.
    require(bytes(uri).length > 0, "ERC721: not URI found");
    return uri;
  }

  /// @inheritdoc IERC721MultiMetadata.tokenURIs
  function tokenURIs(uint256 tokenId) external view returns (uint256 index, string[] memory uris, bool pinned) {
    _requireMinted(tokenId);
    return (_getTokenURIIndex(tokenId), _tokenURIs[tokenId], _hasPinnedTokenURI[tokenId]);
  }

  /// @inheritdoc IERC721MultiMetadata.pinTokenURI
  function pinTokenURI(uint256 tokenId, uint256 index) external {
    require(msg.sender == ownerOf(tokenId), "Unauthorized");
    _pinnedURIIndices[tokenId] = index;
    _hasPinnedTokenURI[tokenId] = true;
    emit TokenUriPinned(tokenId, index);
  }

  /// @inheritdoc IERC721MultiMetadata.unpinTokenURI
  function unpinTokenURI(uint256 tokenId) external {
    require(msg.sender == ownerOf(tokenId), "Unauthorized");
    _pinnedURIIndices[tokenId] = 0;
    _hasPinnedTokenURI[tokenId] = false;
    emit TokenUriUnpinned(tokenId);
  }

  /// @inheritdoc IERC721MultiMetadata.hasPinnedTokenURI
  function hasPinnedTokenURI(uint256 tokenId) external view returns (bool pinned) {
    return _hasPinnedTokenURI[tokenId];
  }

  /// @notice Sets a specific metadata URI for a token at the given index.
  function setUri(uint256 tokenId, uint256 index, string calldata uri) external onlyOwner {
    if (_tokenURIs[tokenId].length > index) {
      _tokenURIs[tokenId][index] = uri;
    } else {
      _tokenURIs[tokenId].push(uri);
    }

    emit MetadataUpdate(tokenId);
  }

  // Overrides supportsInterface to include IERC721MultiMetadata interface support.
  function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
    return (
      interfaceId == type(IERC7160).interfaceId ||
      super.supportsInterface(interfaceId)
    );
  }
}