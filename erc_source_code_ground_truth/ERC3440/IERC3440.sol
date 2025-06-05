// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @dev ERC721 token with editions extension.
 */
abstract contract ERC3440 is ERC721URIStorage {

    // eip-712
    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }
    
    // Contents of message to be signed
    struct Signature {
        address verificationAddress; // ensure the artists signs only address(this) for each piece
        string artist;
        address wallet;
        string contents;
    }

    // type hashes
    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 constant SIGNATURE_TYPEHASH = keccak256(
        "Signature(address verifyAddress,string artist,address wallet, string contents)"
    );

    bytes32 public DOMAIN_SEPARATOR;
    
    // Optional mapping for signatures
    mapping (uint256 => bytes) private _signatures;
    
    // A view to display the artist's address
    address public artist;

    // A view to display the total number of prints created
    uint public editionSupply = 0;
    
    // A view to display which ID is the original copy
    uint public originalId = 0;
    
    // A signed token event
    event Signed(address indexed from, uint256 indexed tokenId);

    /**
     * @dev Sets `artist` as the original artist.
     * @param `address _artist` the wallet of the signing artist (TODO consider multiple
     * signers and contract signers (non-EOA)
     */
    function _designateArtist(address _artist) internal virtual {
        require(artist == address(0), "ERC721Extensions: the artist has already been set");

        // If there is no special designation for the artist, set it.
        artist = _artist;
    }
    
    /**
     * @dev Sets `tokenId as the original print` as the tokenURI of `tokenId`.
     * @param `uint256 tokenId` the nft id of the original print
     */
    function _designateOriginal(uint256 _tokenId) internal virtual {
        require(msg.sender == artist, "ERC721Extensions: only the artist may designate originals");
        require(_exists(_tokenId), "ERC721Extensions: Original query for nonexistent token");
        require(originalId == 0, "ERC721Extensions: Original print has already been designated as a different Id");

        // If there is no special designation for the original, set it.
        originalId = _tokenId;
    }
    

    /**
     * @dev Sets total number printed editions of the original as the tokenURI of `tokenId`.
     * @param `uint256 _maxEditionSupply` max supply
     */
    function _setLimitedEditions(uint256 _maxEditionSupply) internal virtual {
        require(msg.sender == artist, "ERC721Extensions: only the artist may designate max supply");
        require(editionSupply == 0, "ERC721Extensions: Max number of prints has already been created");

        // If there is no max supply of prints, set it. Leaving supply at 0 indicates there are no prints of the original
        editionSupply = _maxEditionSupply;
    }

    /**
     * @dev Creates `tokenIds` representing the printed editions.
     * @param `string memory _tokenURI` the metadata attached to each nft
     */
    function _createEditions(string memory _tokenURI) internal virtual {
        require(msg.sender == artist, "ERC721Extensions: only the artist may create prints");
        require(editionSupply > 0, "ERC721Extensions: the edition supply is not set to more than 0");
        for(uint i=0; i < editionSupply; i++) {
            _mint(msg.sender, i);
            _setTokenURI(i, _tokenURI);
        }
    }

    /**
     * @dev internal hashing utility 
     * @param `Signature memory _message` the signature message struct to be signed
     * the address of this contract is enforced in the hashing
     */
    function _hash(Signature memory _message) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                SIGNATURE_TYPEHASH,
                address(this),
                _message.artist,
                _message.wallet,
                _message.contents
            ))
        ));
    }

    /**
     * @dev Signs a `tokenId` representing a print.
     * @param `uint256 _tokenId` id of the NFT being signed
     * @param `Signature memory _message` the signed message
     * @param `bytes memory _signature` signature bytes created off-chain
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Signed} event.
     */
    function _signEdition(uint256 _tokenId, Signature memory _message, bytes memory _signature) internal virtual {
        require(msg.sender == artist, "ERC721Extensions: only the artist may sign their work");
        require(_signatures[_tokenId].length == 0, "ERC721Extensions: this token is already signed");
        bytes32 digest = hash(_message);
        address recovered = ECDSA.recover(digest, _signature);
        require(recovered == artist, "ERC721Extensions: artist signature mismatch");
        _signatures[_tokenId] = _signature;
        emit Signed(artist, _tokenId);
    }

    
    /**
     * @dev displays a signature from the artist.
     * @param `uint256 _tokenId` NFT id to verify isSigned
     * @returns `bytes` gets the signature stored on the token
     */
    function getSignature(uint256 _tokenId) external view virtual returns (bytes memory) {
        require(_signatures[_tokenId].length != 0, "ERC721Extensions: no signature exists for this Id");
        return _signatures[_tokenId];
    }
    
    /**
     * @dev returns `true` if the message is signed by the artist.
     * @param `Signature memory _message` the message signed by an artist and published elsewhere
     * @param `bytes memory _signature` the signature on the message
     * @param `uint _tokenId` id of the token to be verified as being signed
     * @returns `bool` true if signed by artist
     * The artist may broadcast signature out of band that will verify on the nft
     */
    function isSigned(Signature memory _message, bytes memory _signature, uint _tokenId) external view virtual returns (bool) {
        bytes32 messageHash = hash(_message);
        address _artist = ECDSA.recover(messageHash, _signature);
        return (_artist == artist && _equals(_signatures[_tokenId], _signature));
    }

    /**
    * @dev Utility function that checks if two `bytes memory` variables are equal. This is done using hashing,
    * which is much more gas efficient then comparing each byte individually.
    * Equality means that:
    *  - 'self.length == other.length'
    *  - For 'n' in '[0, self.length)', 'self[n] == other[n]'
    */
    function _equals(bytes memory _self, bytes memory _other) internal pure returns (bool equal) {
        if (_self.length != _other.length) {
            return false;
        }
        uint addr;
        uint addr2;
        uint len = _self.length;
        assembly {
            addr := add(_self, /*BYTES_HEADER_SIZE*/32)
            addr2 := add(_other, /*BYTES_HEADER_SIZE*/32)
        }
        assembly {
            equal := eq(keccak256(addr, len), keccak256(addr2, len))
        }
    }
}