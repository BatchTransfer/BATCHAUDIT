//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./interface/IERC4907.sol";

contract BinanceRemaster is
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721URIStorageUpgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    IERC4907
{
    using StringsUpgradeable for uint256;
    using Counters for Counters.Counter;
    address public OLDnft;
    string public baseURI;
    struct UserInfo {
        address user;
        uint256 expires;
    }
    mapping(uint256 => UserInfo) internal _users;
    event SwapedOldForNew(address user, uint256 oldTokenID, uint256 tokenIdNEW);

    function initialize(
        string calldata name_,
        string calldata symbol_,
        string memory _baseURII
    ) public initializer {
        __ERC721_init(name_, symbol_);
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __UUPSUpgradeable_init();
        __ERC721Enumerable_init();
        __Pausable_init();
        baseURI = _baseURII;
    }

    function userOf(uint256 tokenId) public view virtual returns (address) {
        if (uint256(_users[tokenId].expires) >= block.timestamp) {
            return _users[tokenId].user;
        } else {
            return address(0);
        }
    }

    function userExpires(uint256 tokenId)
        public
        view
        virtual
        returns (uint256)
    {
        return _users[tokenId].expires;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(currentBaseURI, tokenId.toString(), "")
                )
                : "";
    }

    function remasterNFT(uint256 tokenId, uint256 newTokenID) public {
        require(
            IERC721Upgradeable(OLDnft).balanceOf(_msgSender()) > 1,
            "old nft is missing"
        );
        require(tokenByIndex(newTokenID) == 0, "Already created");
        IERC721Upgradeable(OLDnft).safeTransferFrom(
            _msgSender(),
            address(0),
            tokenId
        );
        mint(_msgSender(), newTokenID);
        emit SwapedOldForNew(_msgSender(), tokenId, newTokenID);
    }

    function setNewRerunAddress(address oldNFT)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function setUser(
        uint256 tokenId,
        address user,
        uint64 expires
    ) public virtual {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC4907: transfer caller is not owner nor approved"
        );
        UserInfo storage info = _users[tokenId];
        info.user = user;
        info.expires = expires;
        emit UpdateUser(tokenId, user, expires);
    }

    function setBaseURI(string memory newBaseURI)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseURI = newBaseURI;
    }

    function mint(address to, uint256 id) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(to, id);
    }

    function setPause(bool _newPauseState)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _newPauseState ? _pause() : _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
        if (from != to && _users[tokenId].user != address(0)) {
            delete _users[tokenId];
            emit UpdateUser(tokenId, address(0), 0);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return
            interfaceId == type(IERC4907).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
