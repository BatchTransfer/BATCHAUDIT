// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IERC998.sol";
import "./KumaleonGenArt.sol";

// LICENSE
// Kumaleon.sol is a modified version of MoonCatAcclimator.sol:
// https://github.com/cryptocopycats/contracts/blob/master/mooncats-acclimated/MoonCatAcclimator.sol
//
// MoonCatAcclimator.sol source code licensed under the GPL-3.0-only license.
// Additional conditions of GPL-3.0-only can be found here: https://spdx.org/licenses/GPL-3.0-only.html
//
// MODIFICATIONS
// Kumaleon.sol modifies MoonCatAcclimator to use IERC2981 and original mint().
// And it controls the child tokens so that only authorized tokens are reflected in the NFT visual.

contract Kumaleon is
    ERC721,
    ERC721Holder,
    Ownable,
    IERC998ERC721TopDown,
    IERC998ERC721TopDownEnumerable,
    IERC2981,
    ReentrancyGuard
{
    // ERC998
    bytes32 private constant ERC998_MAGIC_VALUE =
        0x00000000000000000000000000000000000000000000000000000000cd740db5;
    bytes4 private constant _INTERFACE_ID_ERC998ERC721TopDown = 0xcde244d9;
    bytes4 private constant _INTERFACE_ID_ERC998ERC721TopDownEnumerable = 0xa344afe4;

    // kumaleon
    struct AllowlistEntry {
        uint256 minTokenId;
        uint256 maxTokenId;
        address beneficiary;
    }

    uint256 public constant MAX_SUPPLY = 3_000;
    uint256 public totalSupply;
    uint256 public royaltyPercentage = 10;
    uint256 public parentLockAge = 25;
    uint256 private constant FEE_DENOMINATOR = 100;
    address public minter;
    address public moltingHelper;
    address public genArt;
    address private defaultBeneficiary;
    address public constant OKAZZ = 0x783dFB5811B0540875f451c48C13aF6Dd8D42DF5;
    string private baseURI;
    mapping(uint256 => bytes32) public tokenIdToHash;
    mapping(uint256 => bool) public isMolted;
    mapping(uint256 => uint256) public lastTransferChildBlockNumbers;
    mapping(address => AllowlistEntry[]) public childTokenAllowlist;
    bool public isMetadataFrozen;
    bool public isGenArtFrozen;
    bool public isRevealStarted;
    bool public isChildTokenAcceptable;

    event KumaleonTransfer(uint256 tokenId, address childToken, uint256 childTokenId);
    event StartReveal();
    event BaseURIUpdated(string baseURI);
    event SetChildTokenAllowlist(address _address, uint256 minTokenId, uint256 maxTokenId);
    event DeleteChildTokenAllowlist(address _address, uint256 _index);
    event SetGenArt(address _address);

    constructor(address _defaultBeneficiary) ERC721("KUMALEON", "KUMA") {
        setDefaultBeneficiary(_defaultBeneficiary);
    }

    function mint(address _to, uint256 _quantity) external nonReentrant {
        require(totalSupply + _quantity <= MAX_SUPPLY, "Kumaleon: invalid quantity");
        require(msg.sender == minter, "Kumaleon: call from only minter");

        for (uint256 i = 0; i < _quantity; i++) {
            uint256 tokenId = totalSupply;
            totalSupply++;
            tokenIdToHash[tokenId] = keccak256(
                abi.encodePacked(tokenId, block.number, blockhash(block.number - 1), _to)
            );
            _safeMint(OKAZZ, tokenId);
            _safeTransfer(OKAZZ, _to, tokenId, "");
        }
    }

    function molt(
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _childTokenIds
    ) external nonReentrant {
        require(msg.sender == moltingHelper, "Kumaleon: call from only molting helper");
        require(_tokenIds.length == _childTokenIds.length, "Kumaleon: invalid length");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            address rootOwner = address(uint160(uint256(rootOwnerOf(_tokenIds[i]))));
            require(rootOwner == _to, "Kumaleon: Token not owned");

            isMolted[_tokenIds[i]] = true;
            lastTransferChildBlockNumbers[_tokenIds[i]] = block.number;
            KumaleonGenArt(genArt).mintWithHash(
                address(this),
                _to,
                _childTokenIds[i],
                tokenIdToHash[_tokenIds[i]]
            );
            IERC721(genArt).safeTransferFrom(address(this), _to, _childTokenIds[i]);
            emit TransferChild(_tokenIds[i], _to, genArt, _childTokenIds[i]);
        }
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        require(!isMetadataFrozen, "Kumaleon: Already frozen");
        baseURI = _newBaseURI;
        emit BaseURIUpdated(_newBaseURI);
    }

    function freezeMetadata() external onlyOwner {
        require(!isMetadataFrozen, "Kumaleon: Already frozen");
        isMetadataFrozen = true;
    }

    function startReveal() external onlyOwner {
        require(!isRevealStarted, "Kumaleon: Already revealed");
        isRevealStarted = true;
        emit StartReveal();
    }

    function setIsChildTokenAcceptable(bool _bool) external onlyOwner {
        isChildTokenAcceptable = _bool;
    }

    function setMinterAddress(address _minterAddress) external onlyOwner {
        minter = _minterAddress;
    }

    function setMoltingHelperAddress(address _helperAddress) external onlyOwner {
        moltingHelper = _helperAddress;
        isChildTokenAcceptable = true;
    }

    function setChildTokenAllowlist(
        address _address,
        uint256 _minTokenId,
        uint256 _maxTokenId,
        address _beneficiary
    ) external onlyOwner {
        childTokenAllowlist[_address].push(AllowlistEntry(_minTokenId, _maxTokenId, _beneficiary));
        emit SetChildTokenAllowlist(_address, _minTokenId, _maxTokenId);
    }

    function updateChildTokenAllowlistBeneficiary(
        address _childContract,
        uint256 _index,
        address _beneficiary
    ) public onlyOwner {
        childTokenAllowlist[_childContract][_index].beneficiary = _beneficiary;
    }

    function updateChildTokenAllowlistsBeneficiary(
        address[] memory _childContracts,
        uint256[] memory _indices,
        address[] memory _beneficiaries
    ) external onlyOwner {
        require(
            _childContracts.length == _indices.length && _indices.length == _beneficiaries.length,
            "Kumaleon: invalid length"
        );

        for (uint256 i = 0; i < _childContracts.length; i++) {
            updateChildTokenAllowlistBeneficiary(
                _childContracts[i],
                _indices[i],
                _beneficiaries[i]
            );
        }
    }

    // This function could break the original order of array to save gas fees.
    function deleteChildTokenAllowlist(address _address, uint256 _index) external onlyOwner {
        require(_index < childTokenAllowlist[_address].length, "Kumaleon: allowlist not found");

        childTokenAllowlist[_address][_index] = childTokenAllowlist[_address][
            childTokenAllowlist[_address].length - 1
        ];
        childTokenAllowlist[_address].pop();
        if (childTokenAllowlist[_address].length == 0) {
            delete childTokenAllowlist[_address];
        }
        emit DeleteChildTokenAllowlist(_address, _index);
    }

    function childTokenAllowlistByAddress(address _childContract)
        external
        view
        returns (AllowlistEntry[] memory)
    {
        return childTokenAllowlist[_childContract];
    }

    function setGenArt(address _address) external onlyOwner {
        require(!isGenArtFrozen, "Kumaleon: Already frozen");
        genArt = _address;
        emit SetGenArt(_address);
    }

    function freezeGenArt() external onlyOwner {
        require(!isGenArtFrozen, "Kumaleon: Already frozen");
        isGenArtFrozen = true;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _childTokenId,
        bytes memory _data
    ) public override(ERC721Holder, IERC998ERC721TopDown) returns (bytes4) {
        require(
            _data.length > 0,
            "Kumaleon: _data must contain the uint256 tokenId to transfer the child token to."
        );
        // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
        uint256 tokenId;
        assembly {
            tokenId := calldataload(164)
        }
        if (_data.length < 32) {
            tokenId = tokenId >> (256 - _data.length * 8);
        }
        require(
            IERC721(msg.sender).ownerOf(_childTokenId) == address(this),
            "Kumaleon: Child token not owned."
        );
        _receiveChild(_from, tokenId, msg.sender, _childTokenId);
        return ERC721Holder.onERC721Received(_operator, _from, _childTokenId, _data);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require(isParentTransferable(tokenId), "Kumaleon: transfer is not allowed");
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        address childContract = childContracts[tokenId].length() > 0
            ? childContractByIndex(tokenId, 0)
            : address(0);
        emit KumaleonTransfer(
            tokenId,
            childContract,
            childContract != address(0) ? childTokenByIndex(tokenId, childContract, 0) : 0
        );
    }

    ///// ERC998 /////
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev mapping of local token IDs, and which addresses they own children at.
    /// tokenId => child contract
    mapping(uint256 => EnumerableSet.AddressSet) private childContracts;

    /// @dev mapping of local token IDs, addresses they own children at, and IDs of the specific child tokens
    /// tokenId => (child address => array of child tokens)
    mapping(uint256 => mapping(address => EnumerableSet.UintSet)) private childTokens;

    /// @dev mapping of addresses of child tokens, the specific child token IDs, and which local token owns them
    /// child address => childId => tokenId
    mapping(address => mapping(uint256 => uint256)) internal childTokenOwner;

    /**
     * @dev a token has been transferred to this contract mark which local token is to now own it
     * Emits a {ReceivedChild} event.
     *
     * @param _from the address who sent the token to this contract
     * @param _tokenId the local token ID that is to be the parent
     * @param _childContract the address of the child token's contract
     * @param _childTokenId the ID value of teh incoming child token
     */
    function _receiveChild(
        address _from,
        uint256 _tokenId,
        address _childContract,
        uint256 _childTokenId
    ) private {
        // kumaleon <--
        require(isChildTokenAcceptable, "Kumaleon: Child received while paused");
        require(isMolted[_tokenId], "Kumaleon: Child received before molt");
        require(
            _msgSender() == _childContract || _msgSender() == _from,
            "Kumaleon: invalid msgSender"
        );
        address rootOwner = address(uint160(uint256(rootOwnerOf(_tokenId))));
        require(_from == rootOwner, "Kumaleon: only owner can transfer child tokens");
        require(_isTokenAllowed(_childContract, _childTokenId), "Kumaleon: Token not allowed");

        if (childContracts[_tokenId].length() != 0) {
            address oldChildContract = childContractByIndex(_tokenId, 0);
            uint256 oldChildTokenId = childTokenByIndex(_tokenId, oldChildContract, 0);

            _removeChild(_tokenId, oldChildContract, oldChildTokenId);
            ERC721(oldChildContract).safeTransferFrom(address(this), rootOwner, oldChildTokenId);
            emit TransferChild(_tokenId, rootOwner, oldChildContract, oldChildTokenId);
        }
        require(
            childContracts[_tokenId].length() == 0,
            "Kumaleon: Cannot receive child token because it has already had"
        );
        // kumaleon -->
        childContracts[_tokenId].add(_childContract);
        childTokens[_tokenId][_childContract].add(_childTokenId);
        childTokenOwner[_childContract][_childTokenId] = _tokenId;
        emit ReceivedChild(_from, _tokenId, _childContract, _childTokenId);
    }

    function _isTokenAllowed(address _childContract, uint256 _childTokenId)
        private
        view
        returns (bool)
    {
        bool allowed;
        for (uint256 i = 0; i < childTokenAllowlist[_childContract].length; i++) {
            if (
                childTokenAllowlist[_childContract][i].minTokenId <= _childTokenId &&
                _childTokenId <= childTokenAllowlist[_childContract][i].maxTokenId
            ) {
                allowed = true;
                break;
            }
        }
        return allowed;
    }

    /**
     * @dev See {IERC998ERC721TopDown-getChild}.
     */
    function getChild(
        address _from,
        uint256 _tokenId,
        address _childContract,
        uint256 _childTokenId
    ) external override {
        _receiveChild(_from, _tokenId, _childContract, _childTokenId);
        IERC721(_childContract).transferFrom(_from, address(this), _childTokenId);
    }

    /**
     * @dev Given a child address/ID that is owned by some token in this contract, return that owning token's owner
     * @param _childContract the address of the child asset being queried
     * @param _childTokenId the specific ID of the child asset being queried
     * @return parentTokenOwner the address of the owner of that child's parent asset
     * @return parentTokenId the local token ID that is the parent of that child asset
     */
    function _ownerOfChild(address _childContract, uint256 _childTokenId)
        internal
        view
        returns (address parentTokenOwner, uint256 parentTokenId)
    {
        parentTokenId = childTokenOwner[_childContract][_childTokenId];
        require(
            childTokens[parentTokenId][_childContract].contains(_childTokenId),
            "Kumaleon: That child is not owned by a token in this contract"
        );
        return (ownerOf(parentTokenId), parentTokenId);
    }

    /**
     * @dev See {IERC998ERC721TopDown-ownerOfChild}.
     */
    function ownerOfChild(address _childContract, uint256 _childTokenId)
        external
        view
        override
        returns (bytes32 parentTokenOwner, uint256 parentTokenId)
    {
        parentTokenId = childTokenOwner[_childContract][_childTokenId];
        require(
            childTokens[parentTokenId][_childContract].contains(_childTokenId),
            "Kumaleon: That child is not owned by a token in this contract"
        );
        return (
            (ERC998_MAGIC_VALUE << 224) | bytes32(uint256(uint160(ownerOf(parentTokenId)))),
            parentTokenId
        );
    }

    /**
     * @dev See {IERC998ERC721TopDown-rootOwnerOf}.
     */
    function rootOwnerOf(uint256 _tokenId) public view override returns (bytes32 rootOwner) {
        return rootOwnerOfChild(address(0), _tokenId);
    }

    /**
     * @dev See {IERC998ERC721TopDown-rootOwnerOfChild}.
     */
    function rootOwnerOfChild(address _childContract, uint256 _childTokenId)
        public
        view
        override
        returns (bytes32 rootOwner)
    {
        address rootOwnerAddress;
        if (_childContract != address(0)) {
            (rootOwnerAddress, _childTokenId) = _ownerOfChild(_childContract, _childTokenId);
        } else {
            rootOwnerAddress = ownerOf(_childTokenId);
        }
        // Case 1: Token owner is this contract and token.
        while (rootOwnerAddress == address(this)) {
            (rootOwnerAddress, _childTokenId) = _ownerOfChild(rootOwnerAddress, _childTokenId);
        }

        (bool callSuccess, bytes memory data) = rootOwnerAddress.staticcall(
            abi.encodeWithSelector(0xed81cdda, address(this), _childTokenId)
        );
        if (data.length != 0) {
            rootOwner = abi.decode(data, (bytes32));
        }

        if (callSuccess == true && rootOwner >> 224 == ERC998_MAGIC_VALUE) {
            // Case 2: Token owner is other top-down composable
            return rootOwner;
        } else {
            // Case 3: Token owner is other contract
            // Or
            // Case 4: Token owner is user
            return (ERC998_MAGIC_VALUE << 224) | bytes32(uint256(uint160(rootOwnerAddress)));
        }
    }

    /**
     * @dev remove internal records linking a given child to a given parent
     * @param _tokenId the local token ID that is the parent of the child asset
     * @param _childContract the address of the child asset to remove
     * @param _childTokenId the specific ID representing the child asset to be removed
     */
    function _removeChild(
        uint256 _tokenId,
        address _childContract,
        uint256 _childTokenId
    ) private {
        require(
            childTokens[_tokenId][_childContract].contains(_childTokenId),
            "Kumaleon: Child token not owned by token"
        );

        // remove child token
        childTokens[_tokenId][_childContract].remove(_childTokenId);
        delete childTokenOwner[_childContract][_childTokenId];

        // kumaleon
        lastTransferChildBlockNumbers[_tokenId] = block.number;

        // remove contract
        if (childTokens[_tokenId][_childContract].length() == 0) {
            childContracts[_tokenId].remove(_childContract);
        }
    }

    /**
     * @dev check permissions are correct for a transfer of a child asset
     * @param _fromTokenId the local ID of the token that is the parent
     * @param _to the address this child token is being transferred to
     * @param _childContract the address of the child asset's contract
     * @param _childTokenId the specific ID for the child asset being transferred
     */
    function _checkTransferChild(
        uint256 _fromTokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId
    ) private view {
        uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
        require(
            childTokens[tokenId][_childContract].contains(_childTokenId),
            "Kumaleon: Child asset is not owned by a token in this contract"
        );
        require(tokenId == _fromTokenId, "Kumaleon: Parent does not own that asset");
        address rootOwner = address(uint160(uint256(rootOwnerOf(_fromTokenId))));
        require(
            _msgSender() == rootOwner ||
                getApproved(_fromTokenId) == _msgSender() ||
                isApprovedForAll(rootOwner, _msgSender()),
            "Kumaleon: Not allowed to transfer child assets of parent"
        );
    }

    /**
     * @dev See {IERC998ERC721TopDown-safeTransferChild}.
     */
    function safeTransferChild(
        uint256 _fromTokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId
    ) public override {
        _checkTransferChild(_fromTokenId, _to, _childContract, _childTokenId);
        _removeChild(_fromTokenId, _childContract, _childTokenId);
        ERC721(_childContract).safeTransferFrom(address(this), _to, _childTokenId);
        emit TransferChild(_fromTokenId, _to, _childContract, _childTokenId);
    }

    /**
     * @dev See {IERC998ERC721TopDown-safeTransferChild}.
     */
    function safeTransferChild(
        uint256 _fromTokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId,
        bytes calldata _data
    ) public override {
        _checkTransferChild(_fromTokenId, _to, _childContract, _childTokenId);
        _removeChild(_fromTokenId, _childContract, _childTokenId);
        ERC721(_childContract).safeTransferFrom(address(this), _to, _childTokenId, _data);
        emit TransferChild(_fromTokenId, _to, _childContract, _childTokenId);
    }

    /**
     * @dev See {IERC998ERC721TopDown-transferChild}.
     */
    function transferChild(
        uint256 _fromTokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId
    ) public override {
        _checkTransferChild(_fromTokenId, _to, _childContract, _childTokenId);
        _removeChild(_fromTokenId, _childContract, _childTokenId);
        //this is here to be compatible with cryptokitties and other old contracts that require being owner and approved
        // before transferring.
        //does not work with current standard which does not allow approving self, so we must let it fail in that case.
        //0x095ea7b3 == "approve(address,uint256)"
        (bool success, bytes memory data) = _childContract.call(
            abi.encodeWithSelector(0x095ea7b3, this, _childTokenId)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Kumaleon: Failed to Approve"
        );
        ERC721(_childContract).transferFrom(address(this), _to, _childTokenId);
        emit TransferChild(_fromTokenId, _to, _childContract, _childTokenId);
    }

    /**
     * @dev See {IERC998ERC721TopDown-transferChildToParent}.
     */
    function transferChildToParent(
        uint256 _fromTokenId,
        address _toContract,
        uint256 _toTokenId,
        address _childContract,
        uint256 _childTokenId,
        bytes calldata _data
    ) public override {
        _checkTransferChild(_fromTokenId, _toContract, _childContract, _childTokenId);
        _removeChild(_fromTokenId, _childContract, _childTokenId);
        IERC998ERC721BottomUp(_childContract).transferToParent(
            address(this),
            _toContract,
            _toTokenId,
            _childTokenId,
            _data
        );
        emit TransferChild(_fromTokenId, _toContract, _childContract, _childTokenId);
    }

    ///// ERC998 Enumerable

    /**
     * @dev See {IERC998ERC721TopDownEnumerable-totalChildContracts}.
     */
    function totalChildContracts(uint256 _tokenId) public view override returns (uint256) {
        return childContracts[_tokenId].length();
    }

    /**
     * @dev See {IERC998ERC721TopDownEnumerable-childContractByIndex}.
     */
    function childContractByIndex(uint256 _tokenId, uint256 _index)
        public
        view
        override
        returns (address childContract)
    {
        return childContracts[_tokenId].at(_index);
    }

    /**
     * @dev See {IERC998ERC721TopDownEnumerable-totalChildTokens}.
     */
    function totalChildTokens(uint256 _tokenId, address _childContract)
        external
        view
        override
        returns (uint256)
    {
        return childTokens[_tokenId][_childContract].length();
    }

    /**
     * @dev See {IERC998ERC721TopDownEnumerable-childTokenByIndex}.
     */
    function childTokenByIndex(
        uint256 _tokenId,
        address _childContract,
        uint256 _index
    ) public view override returns (uint256 childTokenId) {
        return childTokens[_tokenId][_childContract].at(_index);
    }

    // kumaleon ERC998

    function isParentTransferable(uint256 _tokenId) public view returns (bool) {
        return
            lastTransferChildBlockNumbers[_tokenId] + parentLockAge < block.number;
    }

    function updateParentLockAge(uint256 _age) external onlyOwner {
        parentLockAge = _age;
    }

    function childTokenDetail(uint256 _tokenId)
        external
        view
        returns (address _childContract, uint256 _childTokenId)
    {
        require(super._exists(_tokenId), "Kumaleon: _tokenId does not exist");

        _childContract = childContracts[_tokenId].length() > 0
            ? childContractByIndex(_tokenId, 0)
            : address(0);
        _childTokenId = _childContract != address(0)
            ? childTokenByIndex(_tokenId, _childContract, 0)
            : 0;
    }

    // interface

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC721)
        returns (bool)
    {
        return
            interfaceId == _INTERFACE_ID_ERC998ERC721TopDown ||
            interfaceId == _INTERFACE_ID_ERC998ERC721TopDownEnumerable ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // royalty

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        public
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        bool isTokenHasChild = totalChildContracts(_tokenId) != 0;
        uint256 defaultRoyaltyAmount = (_salePrice * royaltyPercentage) / FEE_DENOMINATOR;
        if (!isTokenHasChild) {
            return (defaultBeneficiary, defaultRoyaltyAmount);
        }

        address childContract = Kumaleon(address(this)).childContractByIndex(_tokenId, 0);
        uint256 childTokenId = Kumaleon(address(this)).childTokenByIndex(
            _tokenId,
            childContract,
            0
        );

        for (uint256 i = 0; i < childTokenAllowlist[childContract].length; i++) {
            if (
                childTokenAllowlist[childContract][i].minTokenId <= childTokenId &&
                childTokenId <= childTokenAllowlist[childContract][i].maxTokenId
            ) {
                receiver = childTokenAllowlist[childContract][i].beneficiary;
                royaltyAmount = (_salePrice * royaltyPercentage) / FEE_DENOMINATOR;
                return (receiver, royaltyAmount);
            }
        }

        return (defaultBeneficiary, defaultRoyaltyAmount);
    }

    function setDefaultBeneficiary(address _receiver) public onlyOwner {
        require(_receiver != address(0), "Kumaleon: invalid receiver");

        defaultBeneficiary = _receiver;
    }

    function setRoyaltyPercentage(uint256 _feeNumerator) external onlyOwner {
        require(_feeNumerator <= FEE_DENOMINATOR, "Kumaleon: royalty fee will exceed salePrice");

        royaltyPercentage = _feeNumerator;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./Kumaleon.sol";

contract KumaleonMinter is Ownable, ReentrancyGuard {
    uint256 private constant OWNER_ALLOTMENT = 450;
    uint256 private _totalOwnerMinted;
    bytes32 public merkleRoot;
    bool public isAllowlistMintActive;
    bool public isPublicMintActive;
    mapping(bytes32 => bool) public isMinted;
    Kumaleon public kumaleon;

    function allowlistMint(
        uint8[] memory _grades,
        uint256[] memory _quantities,
        bytes32[][] calldata proofs
    ) external nonReentrant {
        require(isAllowlistMintActive, "KumaleonMinter: mint is not opened");
        require(_grades.length != 0, "KumaleonMinter: no mint is available");
        require(
            _grades.length == _quantities.length && _quantities.length == proofs.length,
            "KumaleonMinter: invalid length"
        );

        uint256 quantity;
        for (uint256 i = 0; i < _grades.length; i++) {
            bytes32 leaf = keccak256(abi.encode(msg.sender, _grades[i], _quantities[i]));
            require(
                MerkleProof.verify(proofs[i], merkleRoot, leaf),
                "KumaleonMinter: Invalid proof"
            );
            require(!isMinted[leaf], "KumaleonMinter: already minted");

            isMinted[leaf] = true;
            quantity += _quantities[i];
        }
        kumaleon.mint(msg.sender, quantity);
    }

    function publicMint() external nonReentrant {
        require(isPublicMintActive, "KumaleonMinter: mint is not opened");
        kumaleon.mint(msg.sender, 1);
    }

    function ownerMint(address _to, uint256 _quantity) external onlyOwner {
        require(
            _totalOwnerMinted + _quantity <= OWNER_ALLOTMENT,
            "KumaleonMinter: invalid quantity"
        );
        _totalOwnerMinted += _quantity;
        kumaleon.mint(_to, _quantity);
    }

    function setIsAllowlistMintActive(bool _isAllowlistMintActive) external onlyOwner {
        require(merkleRoot != 0, "KumaleonMinter: merkleRoot is not set");
        isAllowlistMintActive = _isAllowlistMintActive;
    }

    function setIsPublicMintActive(bool _isPublicMintActive) external onlyOwner {
        isPublicMintActive = _isPublicMintActive;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setKumaleonAddress(address _kumaleonAddress) external onlyOwner {
        kumaleon = Kumaleon(_kumaleonAddress);
    }
}

// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.9;

import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IKumaleonGenArt.sol";

// LICENSE
// KumaleonGenArt.sol is a modified version of ArtBlocks' GenArt721CoreV2_PBAB.sol:
// https://github.com/ArtBlocks/artblocks-contracts/blob/main/contracts/PBAB%2BCollabs/GenArt721CoreV2_PBAB.sol
//
// GenArt721CoreV2_PBAB.sol source code licensed under the LGPL-3.0-only license.
// Additional conditions of LGPL-3.0-only can be found here: https://spdx.org/licenses/LGPL-3.0-only.html
//
// MODIFICATIONS
// KumaleonGenArt.sol modifies GenArt721CoreV2_PBAB to use IERC2981 and original mintWithHash().

contract KumaleonGenArt is ERC721, IKumaleonGenArt, IERC2981, ReentrancyGuard {
    struct Project {
        string name;
        string artist;
        string description;
        string website;
        string license;
        string projectBaseURI;
        uint256 invocations;
        uint256 maxInvocations;
        string scriptJSON;
        mapping(uint256 => string) scripts;
        uint256 scriptCount;
        string ipfsHash;
        bool active;
        bool locked;
        bool paused;
    }

    uint256 constant ONE_MILLION = 1_000_000;
    mapping(uint256 => Project) projects;

    //All financial functions are stripped from struct for visibility
    mapping(uint256 => address payable) public override(IKumaleonGenArt) projectIdToArtistAddress;
    mapping(uint256 => string) public override(IKumaleonGenArt) projectIdToCurrencySymbol;
    mapping(uint256 => address) public override(IKumaleonGenArt) projectIdToCurrencyAddress;
    mapping(uint256 => uint256) public override(IKumaleonGenArt) projectIdToPricePerTokenInWei;
    mapping(uint256 => address payable) public override(IKumaleonGenArt) projectIdToAdditionalPayee;
    mapping(uint256 => uint256)
        public
        override(IKumaleonGenArt) projectIdToAdditionalPayeePercentage;
    mapping(uint256 => uint256) public projectIdToSecondaryMarketRoyaltyPercentage;

    address payable public override(IKumaleonGenArt) renderProviderAddress;
    /// Percentage of mint revenue allocated to render provider
    uint256 public override(IKumaleonGenArt) renderProviderPercentage = 10;

    mapping(uint256 => uint256) public override(IKumaleonGenArt) tokenIdToProjectId;
    mapping(uint256 => bytes32) public tokenIdToHash;
    mapping(bytes32 => uint256) public hashToTokenId;

    /// admin for contract
    address public override(IKumaleonGenArt) admin;
    /// true if address is whitelisted
    mapping(address => bool) public override(IKumaleonGenArt) isWhitelisted;
    /// true if minter is whitelisted
    mapping(address => bool) public isMintWhitelisted;

    /// next project ID to be created
    uint256 public override(IKumaleonGenArt) nextProjectId = 0;

    // kumaleon
    address public kumaleon;
    bool public isKumaleonFrozen;

    modifier onlyValidTokenId(uint256 _tokenId) {
        require(_exists(_tokenId), "Token ID does not exist");
        _;
    }

    modifier onlyUnlocked(uint256 _projectId) {
        require(!projects[_projectId].locked, "Only if unlocked");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyWhitelisted() {
        require(isWhitelisted[msg.sender], "Only whitelisted");
        _;
    }

    /**
     * @notice Initializes contract.
     * @param _tokenName Name of token.
     * @param _tokenSymbol Token symbol.
     */
    constructor(string memory _tokenName, string memory _tokenSymbol)
        ERC721(_tokenName, _tokenSymbol)
    {
        admin = msg.sender;
        isWhitelisted[msg.sender] = true;
        renderProviderAddress = payable(msg.sender);
    }

    /**
     * @notice Mints a token from project `_projectId` and sets the
     * token's owner to `_to`.
     * @param _to Address to be the minted token's owner.
     * @param _projectId Project ID to mint a token on.
     * @param _by Purchaser of minted token.
     * @dev sender must be a whitelisted minter
     */
    function mint(
        address _to,
        uint256 _projectId,
        address _by
    ) external override(IKumaleonGenArt) returns (uint256 _tokenId) {
        revert("disabled");
    }

    /**
     * @notice Mints a token from hash `_hash` and sets the
     * token's owner to `_to`.
     * @param _to Address to be the minted token's owner.
     * @param _by Purchaser of minted token.
     * @param _tokenId TokenId of minted token.
     * @param _hash hash of minted token.
     * @dev sender must be a whitelisted minter
     */
    function mintWithHash(
        address _to,
        address _by,
        uint256 _tokenId,
        bytes32 _hash
    ) external nonReentrant returns (uint256 _mintedTokenId) {
        require(kumaleon == msg.sender, "Must mint from kumaleon contract.");
        uint256 _projectId = _tokenId / ONE_MILLION;
        require(
            _tokenId % ONE_MILLION < projects[_projectId].maxInvocations,
            "Must not exceed max invocations"
        );
        require(
            projects[_projectId].active || _by == projectIdToArtistAddress[_projectId],
            "Project must exist and be active"
        );
        require(
            !projects[_projectId].paused || _by == projectIdToArtistAddress[_projectId],
            "Purchases are paused."
        );

        uint256 mintedTokenId = _mintToken(_to, _projectId, _tokenId, _hash);

        return mintedTokenId;
    }

    function _mintToken(
        address _to,
        uint256 _projectId,
        uint256 _tokenId,
        bytes32 _hash
    ) internal returns (uint256 _mintedTokenId) {
        projects[_projectId].invocations = projects[_projectId].invocations + 1;

        tokenIdToHash[_tokenId] = _hash;
        hashToTokenId[_hash] = _tokenId;

        _mint(_to, _tokenId);

        tokenIdToProjectId[_tokenId] = _projectId;

        emit Mint(_to, _tokenId, _projectId);

        return _tokenId;
    }

    /**
     * @notice Updates contract admin to `_adminAddress`.
     */
    function updateAdmin(address _adminAddress) public onlyAdmin {
        admin = _adminAddress;
    }

    /**
     * @notice Updates render provider address to `_renderProviderAddress`.
     */
    function updateRenderProviderAddress(address payable _renderProviderAddress) public onlyAdmin {
        renderProviderAddress = _renderProviderAddress;
    }

    /**
     * @notice Updates render provider mint revenue percentage to
     * `_renderProviderPercentage`.
     */
    function updateRenderProviderPercentage(uint256 _renderProviderPercentage) public onlyAdmin {
        require(_renderProviderPercentage <= 25, "Max of 25%");
        renderProviderPercentage = _renderProviderPercentage;
    }

    /**
     * @notice Whitelists `_address`.
     */
    function addWhitelisted(address _address) public onlyAdmin {
        isWhitelisted[_address] = true;
    }

    /**
     * @notice Revokes whitelisting of `_address`.
     */
    function removeWhitelisted(address _address) public onlyAdmin {
        isWhitelisted[_address] = false;
    }

    /**
     * @notice Whitelists minter `_address`.
     */
    function addMintWhitelisted(address _address) public onlyAdmin {
        isMintWhitelisted[_address] = true;
    }

    /**
     * @notice Revokes whitelisting of minter `_address`.
     */
    function removeMintWhitelisted(address _address) public onlyAdmin {
        isMintWhitelisted[_address] = false;
    }

    /**
     * @notice Locks project `_projectId`.
     */
    function toggleProjectIsLocked(uint256 _projectId)
        public
        onlyWhitelisted
        onlyUnlocked(_projectId)
    {
        projects[_projectId].locked = true;
    }

    /**
     * @notice Toggles project `_projectId` as active/inactive.
     */
    function toggleProjectIsActive(uint256 _projectId) public onlyWhitelisted {
        projects[_projectId].active = !projects[_projectId].active;
    }

    /**
     * @notice Updates artist of project `_projectId` to `_artistAddress`.
     */
    function updateProjectArtistAddress(uint256 _projectId, address payable _artistAddress)
        public
        onlyWhitelisted
    {
        projectIdToArtistAddress[_projectId] = _artistAddress;
    }

    /**
     * @notice Toggles paused state of project `_projectId`.
     */
    function toggleProjectIsPaused(uint256 _projectId) public onlyWhitelisted {
        projects[_projectId].paused = !projects[_projectId].paused;
    }

    /**
     * @notice Adds new project `_projectName` by `_artistAddress`.
     * @param _projectName Project name.
     * @param _artistAddress Artist's address.
     * @param _pricePerTokenInWei Price to mint a token, in Wei.
     */
    function addProject(
        string memory _projectName,
        address payable _artistAddress,
        uint256 _pricePerTokenInWei
    ) public onlyWhitelisted {
        uint256 projectId = nextProjectId;
        projectIdToArtistAddress[projectId] = _artistAddress;
        projects[projectId].name = _projectName;
        projectIdToCurrencySymbol[projectId] = "ETH";
        projectIdToPricePerTokenInWei[projectId] = _pricePerTokenInWei;
        projects[projectId].paused = true;
        projects[projectId].maxInvocations = ONE_MILLION;
        nextProjectId = nextProjectId + 1;
    }

    /**
     * @notice Updates payment currency of project `_projectId` to be
     * `_currencySymbol`.
     * @param _projectId Project ID to update.
     * @param _currencySymbol Currency symbol.
     * @param _currencyAddress Currency address.
     */
    function updateProjectCurrencyInfo(
        uint256 _projectId,
        string memory _currencySymbol,
        address _currencyAddress
    ) public onlyWhitelisted {
        projectIdToCurrencySymbol[_projectId] = _currencySymbol;
        projectIdToCurrencyAddress[_projectId] = _currencyAddress;
    }

    /**
     * @notice Updates price per token of project `_projectId` to be
     * '_pricePerTokenInWei`, in Wei.
     */
    function updateProjectPricePerTokenInWei(uint256 _projectId, uint256 _pricePerTokenInWei)
        public
        onlyWhitelisted
    {
        projectIdToPricePerTokenInWei[_projectId] = _pricePerTokenInWei;
    }

    /**
     * @notice Updates name of project `_projectId` to be `_projectName`.
     */
    function updateProjectName(uint256 _projectId, string memory _projectName)
        public
        onlyUnlocked(_projectId)
        onlyWhitelisted
    {
        projects[_projectId].name = _projectName;
    }

    /**
     * @notice Updates artist name for project `_projectId` to be
     * `_projectArtistName`.
     */
    function updateProjectArtistName(uint256 _projectId, string memory _projectArtistName)
        public
        onlyUnlocked(_projectId)
        onlyWhitelisted
    {
        projects[_projectId].artist = _projectArtistName;
    }

    /**
     * @notice Updates additional payee for project `_projectId` to be
     * `_additionalPayee`, receiving `_additionalPayeePercentage` percent
     * of artist mint and royalty revenues.
     */
    function updateProjectAdditionalPayeeInfo(
        uint256 _projectId,
        address payable _additionalPayee,
        uint256 _additionalPayeePercentage
    ) public onlyWhitelisted {
        require(_additionalPayeePercentage <= 100, "Max of 100%");
        projectIdToAdditionalPayee[_projectId] = _additionalPayee;
        projectIdToAdditionalPayeePercentage[_projectId] = _additionalPayeePercentage;
    }

    /**
     * @notice Updates artist secondary market royalties for project
     * `_projectId` to be `_secondMarketRoyalty` percent.
     */
    function updateProjectSecondaryMarketRoyaltyPercentage(
        uint256 _projectId,
        uint256 _secondMarketRoyalty
    ) public onlyWhitelisted {
        require(_secondMarketRoyalty <= 100, "Max of 100%");
        projectIdToSecondaryMarketRoyaltyPercentage[_projectId] = _secondMarketRoyalty;
    }

    /**
     * @notice Updates description of project `_projectId`.
     */
    function updateProjectDescription(uint256 _projectId, string memory _projectDescription)
        public
        onlyWhitelisted
    {
        projects[_projectId].description = _projectDescription;
    }

    /**
     * @notice Updates website of project `_projectId` to be `_projectWebsite`.
     */
    function updateProjectWebsite(uint256 _projectId, string memory _projectWebsite)
        public
        onlyWhitelisted
    {
        projects[_projectId].website = _projectWebsite;
    }

    /**
     * @notice Updates license for project `_projectId`.
     */
    function updateProjectLicense(uint256 _projectId, string memory _projectLicense)
        public
        onlyUnlocked(_projectId)
        onlyWhitelisted
    {
        projects[_projectId].license = _projectLicense;
    }

    /**
     * @notice Updates maximum invocations for project `_projectId` to
     * `_maxInvocations`.
     */
    function updateProjectMaxInvocations(uint256 _projectId, uint256 _maxInvocations)
        public
        onlyWhitelisted
    {
        require(
            (!projects[_projectId].locked || _maxInvocations < projects[_projectId].maxInvocations),
            "Only if unlocked"
        );
        require(
            _maxInvocations > projects[_projectId].invocations,
            "You must set max invocations greater than current invocations"
        );
        require(_maxInvocations <= ONE_MILLION, "Cannot exceed 1000000");
        projects[_projectId].maxInvocations = _maxInvocations;
    }

    /**
     * @notice Adds a script to project `_projectId`.
     * @param _projectId Project to be updated.
     * @param _script Script to be added.
     */
    function addProjectScript(uint256 _projectId, string memory _script)
        public
        onlyUnlocked(_projectId)
        onlyWhitelisted
    {
        projects[_projectId].scripts[projects[_projectId].scriptCount] = _script;
        projects[_projectId].scriptCount = projects[_projectId].scriptCount + 1;
    }

    /**
     * @notice Updates script for project `_projectId` at script ID `_scriptId`.
     * @param _projectId Project to be updated.
     * @param _scriptId Script ID to be updated.
     * @param _script Script to be added.
     */
    function updateProjectScript(
        uint256 _projectId,
        uint256 _scriptId,
        string memory _script
    ) public onlyUnlocked(_projectId) onlyWhitelisted {
        require(_scriptId < projects[_projectId].scriptCount, "scriptId out of range");
        projects[_projectId].scripts[_scriptId] = _script;
    }

    /**
     * @notice Removes last script from project `_projectId`.
     */
    function removeProjectLastScript(uint256 _projectId)
        public
        onlyUnlocked(_projectId)
        onlyWhitelisted
    {
        require(projects[_projectId].scriptCount > 0, "there are no scripts to remove");
        delete projects[_projectId].scripts[projects[_projectId].scriptCount - 1];
        projects[_projectId].scriptCount = projects[_projectId].scriptCount - 1;
    }

    /**
     * @notice Updates script json for project `_projectId`.
     */
    function updateProjectScriptJSON(uint256 _projectId, string memory _projectScriptJSON)
        public
        onlyUnlocked(_projectId)
        onlyWhitelisted
    {
        projects[_projectId].scriptJSON = _projectScriptJSON;
    }

    /**
     * @notice Updates ipfs hash for project `_projectId`.
     */
    function updateProjectIpfsHash(uint256 _projectId, string memory _ipfsHash)
        public
        onlyUnlocked(_projectId)
        onlyWhitelisted
    {
        projects[_projectId].ipfsHash = _ipfsHash;
    }

    /**
     * @notice Updates base URI for project `_projectId` to `_newBaseURI`.
     */
    function updateProjectBaseURI(uint256 _projectId, string memory _newBaseURI)
        public
        onlyWhitelisted
    {
        projects[_projectId].projectBaseURI = _newBaseURI;
    }

    /**
     * @notice Returns project details for project `_projectId`.
     * @param _projectId Project to be queried.
     * @return projectName Name of project
     * @return artist Artist of project
     * @return description Project description
     * @return website Project website
     * @return license Project license
     */
    function projectDetails(uint256 _projectId)
        public
        view
        returns (
            string memory projectName,
            string memory artist,
            string memory description,
            string memory website,
            string memory license
        )
    {
        projectName = projects[_projectId].name;
        artist = projects[_projectId].artist;
        description = projects[_projectId].description;
        website = projects[_projectId].website;
        license = projects[_projectId].license;
    }

    /**
     * @notice Returns project token information for project `_projectId`.
     * @param _projectId Project to be queried.
     * @return artistAddress Project Artist's address
     * @return pricePerTokenInWei Price to mint a token, in Wei
     * @return invocations Current number of invocations
     * @return maxInvocations Maximum allowed invocations
     * @return active Boolean representing if project is currently active
     * @return additionalPayee Additional payee address
     * @return additionalPayeePercentage Percentage of artist revenue
     * to be sent to the additional payee's address
     * @return currency Symbol of project's currency
     * @return currencyAddress Address of project's currency
     */
    function projectTokenInfo(uint256 _projectId)
        public
        view
        override(IKumaleonGenArt)
        returns (
            address artistAddress,
            uint256 pricePerTokenInWei,
            uint256 invocations,
            uint256 maxInvocations,
            bool active,
            address additionalPayee,
            uint256 additionalPayeePercentage,
            string memory currency,
            address currencyAddress
        )
    {
        artistAddress = projectIdToArtistAddress[_projectId];
        pricePerTokenInWei = projectIdToPricePerTokenInWei[_projectId];
        invocations = projects[_projectId].invocations;
        maxInvocations = projects[_projectId].maxInvocations;
        active = projects[_projectId].active;
        additionalPayee = projectIdToAdditionalPayee[_projectId];
        additionalPayeePercentage = projectIdToAdditionalPayeePercentage[_projectId];
        currency = projectIdToCurrencySymbol[_projectId];
        currencyAddress = projectIdToCurrencyAddress[_projectId];
    }

    /**
     * @notice Returns script information for project `_projectId`.
     * @param _projectId Project to be queried.
     * @return scriptJSON Project's script json
     * @return scriptCount Count of scripts for project
     * @return ipfsHash IPFS hash for project
     * @return locked Boolean representing if project is locked
     * @return paused Boolean representing if project is paused
     */
    function projectScriptInfo(uint256 _projectId)
        public
        view
        returns (
            string memory scriptJSON,
            uint256 scriptCount,
            string memory ipfsHash,
            bool locked,
            bool paused
        )
    {
        scriptJSON = projects[_projectId].scriptJSON;
        scriptCount = projects[_projectId].scriptCount;
        ipfsHash = projects[_projectId].ipfsHash;
        locked = projects[_projectId].locked;
        paused = projects[_projectId].paused;
    }

    /**
     * @notice Returns script for project `_projectId` at script index `_index`.
     */
    function projectScriptByIndex(uint256 _projectId, uint256 _index)
        public
        view
        returns (string memory)
    {
        return projects[_projectId].scripts[_index];
    }

    /**
     * @notice Returns base URI for project `_projectId`.
     */
    function projectURIInfo(uint256 _projectId) public view returns (string memory projectBaseURI) {
        projectBaseURI = projects[_projectId].projectBaseURI;
    }

    /**
     * @notice Gets royalty data for token ID `_tokenId`.
     * @param _tokenId Token ID to be queried.
     * @return artistAddress Artist's payment address
     * @return additionalPayee Additional payee's payment address
     * @return additionalPayeePercentage Percentage of artist revenue
     * to be sent to the additional payee's address
     * @return royaltyFeeByID Total royalty percentage to be sent to
     * combination of artist and additional payee
     */
    function getRoyaltyData(uint256 _tokenId)
        public
        view
        override(IKumaleonGenArt)
        returns (
            address artistAddress,
            address additionalPayee,
            uint256 additionalPayeePercentage,
            uint256 royaltyFeeByID
        )
    {
        artistAddress = projectIdToArtistAddress[tokenIdToProjectId[_tokenId]];
        additionalPayee = projectIdToAdditionalPayee[tokenIdToProjectId[_tokenId]];
        additionalPayeePercentage = projectIdToAdditionalPayeePercentage[
            tokenIdToProjectId[_tokenId]
        ];
        royaltyFeeByID = projectIdToSecondaryMarketRoyaltyPercentage[tokenIdToProjectId[_tokenId]];
    }

    /**
     * @notice Gets token URI for token ID `_tokenId`.
     */
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        onlyValidTokenId(_tokenId)
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    projects[tokenIdToProjectId[_tokenId]].projectBaseURI,
                    Strings.toString(_tokenId)
                )
            );
    }

    /* royalty */

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        uint256 projectId = tokenIdToProjectId[_tokenId];
        uint256 royaltyPercentage = projectIdToSecondaryMarketRoyaltyPercentage[projectId];
        royaltyAmount = (_salePrice * royaltyPercentage) / 100;
        receiver = projectIdToAdditionalPayee[projectId];

        return (receiver, royaltyAmount);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    // kumaleon

    function setKumaleon(address _address) external onlyAdmin {
        require(!isKumaleonFrozen, "KumaleonGenArt: Already frozen");
        kumaleon = _address;
    }

    function freezeKumaleon() external onlyAdmin {
        require(!isKumaleonFrozen, "KumaleonGenArt: Already frozen");
        isKumaleonFrozen = true;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

/**
 * @title ERC998ERC721 Top-Down Composable Non-Fungible Token
 * @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-998.md
 * Note: the ERC-165 identifier for this interface is 0x1efdf36a
 */
interface IERC998ERC721TopDown {
    /**
     * @dev This emits when a token receives a child token.
     * @param _from The prior owner of the token.
     * @param _toTokenId The token that receives the child token.
     */
    event ReceivedChild(
        address indexed _from,
        uint256 indexed _toTokenId,
        address indexed _childContract,
        uint256 _childTokenId
    );

    /**
     * @dev This emits when a child token is transferred from a token to an address.
     * @param _fromTokenId The parent token that the child token is being transferred from.
     * @param _to The new owner address of the child token.
     */
    event TransferChild(
        uint256 indexed _fromTokenId,
        address indexed _to,
        address indexed _childContract,
        uint256 _childTokenId
    );

    /**
     * @notice Get the root owner of tokenId.
     * @param _tokenId The token to query for a root owner address
     * @return rootOwner The root owner at the top of tree of tokens and ERC998 magic value.
     */
    function rootOwnerOf(uint256 _tokenId) external view returns (bytes32 rootOwner);

    /**
     * @notice Get the root owner of a child token.
     * @param _childContract The contract address of the child token.
     * @param _childTokenId The tokenId of the child.
     * @return rootOwner The root owner at the top of tree of tokens and ERC998 magic value.
     */
    function rootOwnerOfChild(address _childContract, uint256 _childTokenId)
        external
        view
        returns (bytes32 rootOwner);

    /**
     * @notice Get the parent tokenId of a child token.
     * @param _childContract The contract address of the child token.
     * @param _childTokenId The tokenId of the child.
     * @return parentTokenOwner The parent address of the parent token and ERC998 magic value
     * @return parentTokenId The parent tokenId of _tokenId
     */
    function ownerOfChild(address _childContract, uint256 _childTokenId)
        external
        view
        returns (bytes32 parentTokenOwner, uint256 parentTokenId);

    /**
     * @notice A token receives a child token
     * @param _operator The address that caused the transfer.
     * @param _from The owner of the child token.
     * @param _childTokenId The token that is being transferred to the parent.
     * @param _data Up to the first 32 bytes contains an integer which is the receiving parent tokenId.
     */
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _childTokenId,
        bytes calldata _data
    ) external returns (bytes4);

    /**
     * @notice Transfer child token from top-down composable to address.
     * @param _fromTokenId The owning token to transfer from.
     * @param _to The address that receives the child token
     * @param _childContract The ERC721 contract of the child token.
     * @param _childTokenId The tokenId of the token that is being transferred.
     */
    function transferChild(
        uint256 _fromTokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId
    ) external;

    /**
     * @notice Transfer child token from top-down composable to address.
     * @param _fromTokenId The owning token to transfer from.
     * @param _to The address that receives the child token
     * @param _childContract The ERC721 contract of the child token.
     * @param _childTokenId The tokenId of the token that is being transferred.
     */
    function safeTransferChild(
        uint256 _fromTokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId
    ) external;

    /**
     * @notice Transfer child token from top-down composable to address.
     * @param _fromTokenId The owning token to transfer from.
     * @param _to The address that receives the child token
     * @param _childContract The ERC721 contract of the child token.
     * @param _childTokenId The tokenId of the token that is being transferred.
     * @param _data Additional data with no specified format
     */
    function safeTransferChild(
        uint256 _fromTokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId,
        bytes calldata _data
    ) external;

    /**
     * @notice Transfer bottom-up composable child token from top-down composable to other ERC721 token.
     * @param _fromTokenId The owning token to transfer from.
     * @param _toContract The ERC721 contract of the receiving token
     * @param _toTokenId The receiving token
     * @param _childContract The bottom-up composable contract of the child token.
     * @param _childTokenId The token that is being transferred.
     * @param _data Additional data with no specified format
     */
    function transferChildToParent(
        uint256 _fromTokenId,
        address _toContract,
        uint256 _toTokenId,
        address _childContract,
        uint256 _childTokenId,
        bytes calldata _data
    ) external;

    /**
     * @notice Get a child token from an ERC721 contract.
     * @param _from The address that owns the child token.
     * @param _tokenId The token that becomes the parent owner
     * @param _childContract The ERC721 contract of the child token
     * @param _childTokenId The tokenId of the child token
     */
    function getChild(
        address _from,
        uint256 _tokenId,
        address _childContract,
        uint256 _childTokenId
    ) external;
}

/**
 * @dev The ERC-165 identifier for this interface is 0xa344afe4
 */
interface IERC998ERC721TopDownEnumerable {
    /**
     * @notice Get the total number of child contracts with tokens that are owned by tokenId.
     * @param _tokenId The parent token of child tokens in child contracts
     * @return uint256 The total number of child contracts with tokens owned by tokenId.
     */
    function totalChildContracts(uint256 _tokenId) external view returns (uint256);

    /**
     * @notice Get child contract by tokenId and index
     * @param _tokenId The parent token of child tokens in child contract
     * @param _index The index position of the child contract
     * @return childContract The contract found at the tokenId and index.
     */
    function childContractByIndex(uint256 _tokenId, uint256 _index)
        external
        view
        returns (address childContract);

    /**
     * @notice Get the total number of child tokens owned by tokenId that exist in a child contract.
     * @param _tokenId The parent token of child tokens
     * @param _childContract The child contract containing the child tokens
     * @return uint256 The total number of child tokens found in child contract that are owned by tokenId.
     */
    function totalChildTokens(uint256 _tokenId, address _childContract)
        external
        view
        returns (uint256);

    /**
     * @notice Get child token owned by tokenId, in child contract, at index position
     * @param _tokenId The parent token of the child token
     * @param _childContract The child contract of the child token
     * @param _index The index position of the child token.
     * @return childTokenId The child tokenId for the parent token, child token and index
     */
    function childTokenByIndex(
        uint256 _tokenId,
        address _childContract,
        uint256 _index
    ) external view returns (uint256 childTokenId);
}

interface IERC998ERC721BottomUp {
    /**
     * @notice Transfer token from owner address to a token
     * @param _from The owner address
     * @param _toContract The ERC721 contract of the receiving token
     * @param _toTokenId The receiving token
     * @param _data Additional data with no specified format
     */
    function transferToParent(
        address _from,
        address _toContract,
        uint256 _toTokenId,
        uint256 _tokenId,
        bytes calldata _data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.0;

import "../IERC721Receiver.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
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