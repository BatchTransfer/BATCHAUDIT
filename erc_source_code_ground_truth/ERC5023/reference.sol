// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./IERC5023.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ShareableERC721 is ERC721URIStorage, Ownable, IERC5023 /* EIP165 */ {

  string baseURI;

  uint256 internal _currentIndex;
    
  constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

  function mint(
        address account,
        uint256 tokenId
    ) external onlyOwner {
        _mint(account, tokenId);
  }

  function setTokenURI(
        uint256 tokenId, 
        string memory tokenURI
    ) external {
        _setTokenURI(tokenId, tokenURI);
  }

  function setBaseURI(string memory baseURI_) external {
        baseURI = baseURI_;
  }
    
  function _baseURI() internal view override returns (string memory) {
        return baseURI;
  }

  function share(address to, uint256 tokenIdToBeShared) external returns(uint256 newTokenId) {
      require(to != address(0), "ERC721: mint to the zero address");
      require(_exists(tokenIdToBeShared), "ShareableERC721: token to be shared must exist");
      
      require(msg.sender == ownerOf(tokenIdToBeShared), "Method caller must be the owner of token");

      string memory _tokenURI = tokenURI(tokenIdToBeShared);
      _mint(to, _currentIndex);
      _setTokenURI(_currentIndex, _tokenURI);

      emit Share(msg.sender, to, _currentIndex, tokenIdToBeShared);

      return _currentIndex;
  }

  function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        revert('In this reference implementation tokens are not transferrable');
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        revert('In this reference implementation tokens are not transferrable');
    }
}