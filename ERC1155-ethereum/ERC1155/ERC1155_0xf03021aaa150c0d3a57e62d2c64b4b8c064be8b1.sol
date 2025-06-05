// File: @ensdomains/ens-contracts/contracts/ethregistrar/IBaseRegistrar.sol
import "../registry/ENS.sol";
import "./IBaseRegistrar.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IBaseRegistrar is IERC721 {
    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);
    event NameMigrated(
        uint256 indexed id,
        address indexed owner,
        uint256 expires
    );
    event NameRegistered(
        uint256 indexed id,
        address indexed owner,
        uint256 expires
    );
    event NameRenewed(uint256 indexed id, uint256 expires);

    // Authorises a controller, who can register and renew domains.
    function addController(address controller) external;

    // Revoke controller permission for an address.
    function removeController(address controller) external;

    // Set the resolver for the TLD this registrar manages.
    function setResolver(address resolver) external;

    // Returns the expiration timestamp of the specified label hash.
    function nameExpires(uint256 id) external view returns (uint256);

    // Returns true if the specified name is available for registration.
    function available(uint256 id) external view returns (bool);

    /**
     * @dev Register a name.
     */
    function register(
        uint256 id,
        address owner,
        uint256 duration
    ) external returns (uint256);

    function renew(uint256 id, uint256 duration) external returns (uint256);

    /**
     * @dev Reclaim ownership of a name in ENS, if you own it in the registrar.
     */
    function reclaim(uint256 id, address owner) external;
}


// File: @ensdomains/ens-contracts/contracts/registry/ENS.sol
pragma solidity >=0.8.4;

interface ENS {
    // Logged when the owner of a node assigns a new owner to a subnode.
    event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

    // Logged when the owner of a node transfers ownership to a new account.
    event Transfer(bytes32 indexed node, address owner);

    // Logged when the resolver for a node changes.
    event NewResolver(bytes32 indexed node, address resolver);

    // Logged when the TTL of a node changes
    event NewTTL(bytes32 indexed node, uint64 ttl);

    // Logged when an operator is added or removed.
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    ) external;

    function setSubnodeRecord(
        bytes32 node,
        bytes32 label,
        address owner,
        address resolver,
        uint64 ttl
    ) external;

    function setSubnodeOwner(
        bytes32 node,
        bytes32 label,
        address owner
    ) external returns (bytes32);

    function setResolver(bytes32 node, address resolver) external;

    function setOwner(bytes32 node, address owner) external;

    function setTTL(bytes32 node, uint64 ttl) external;

    function setApprovalForAll(address operator, bool approved) external;

    function owner(bytes32 node) external view returns (address);

    function resolver(bytes32 node) external view returns (address);

    function ttl(bytes32 node) external view returns (uint64);

    function recordExists(bytes32 node) external view returns (bool);

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/ResolverBase.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./profiles/IVersionableResolver.sol";

abstract contract ResolverBase is ERC165, IVersionableResolver {
    mapping(bytes32 => uint64) public recordVersions;

    function isAuthorised(bytes32 node) internal view virtual returns (bool);

    modifier authorised(bytes32 node) {
        require(isAuthorised(node));
        _;
    }

    /**
     * Increments the record version associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     */
    function clearRecords(bytes32 node) public virtual authorised(node) {
        recordVersions[node]++;
        emit VersionChanged(node, recordVersions[node]);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(IVersionableResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/IABIResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IABIResolver {
    event ABIChanged(bytes32 indexed node, uint256 indexed contentType);

    /**
     * Returns the ABI associated with an ENS node.
     * Defined in EIP205.
     * @param node The ENS node to query
     * @param contentTypes A bitwise OR of the ABI formats accepted by the caller.
     * @return contentType The content type of the return value
     * @return data The ABI data
     */
    function ABI(
        bytes32 node,
        uint256 contentTypes
    ) external view returns (uint256, bytes memory);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/IAddrResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/**
 * Interface for the legacy (ETH-only) addr function.
 */
interface IAddrResolver {
    event AddrChanged(bytes32 indexed node, address a);

    /**
     * Returns the address associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated address.
     */
    function addr(bytes32 node) external view returns (address payable);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/IAddressResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/**
 * Interface for the new (multicoin) addr function.
 */
interface IAddressResolver {
    event AddressChanged(
        bytes32 indexed node,
        uint256 coinType,
        bytes newAddress
    );

    function addr(
        bytes32 node,
        uint256 coinType
    ) external view returns (bytes memory);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/IContentHashResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IContentHashResolver {
    event ContenthashChanged(bytes32 indexed node, bytes hash);

    /**
     * Returns the contenthash associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated contenthash.
     */
    function contenthash(bytes32 node) external view returns (bytes memory);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/IDNSRecordResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IDNSRecordResolver {
    // DNSRecordChanged is emitted whenever a given node/name/resource's RRSET is updated.
    event DNSRecordChanged(
        bytes32 indexed node,
        bytes name,
        uint16 resource,
        bytes record
    );
    // DNSRecordDeleted is emitted whenever a given node/name/resource's RRSET is deleted.
    event DNSRecordDeleted(bytes32 indexed node, bytes name, uint16 resource);

    /**
     * Obtain a DNS record.
     * @param node the namehash of the node for which to fetch the record
     * @param name the keccak-256 hash of the fully-qualified name for which to fetch the record
     * @param resource the ID of the resource as per https://en.wikipedia.org/wiki/List_of_DNS_record_types
     * @return the DNS record in wire format if present, otherwise empty
     */
    function dnsRecord(
        bytes32 node,
        bytes32 name,
        uint16 resource
    ) external view returns (bytes memory);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/IDNSZoneResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IDNSZoneResolver {
    // DNSZonehashChanged is emitted whenever a given node's zone hash is updated.
    event DNSZonehashChanged(
        bytes32 indexed node,
        bytes lastzonehash,
        bytes zonehash
    );

    /**
     * zonehash obtains the hash for the zone.
     * @param node The ENS node to query.
     * @return The associated contenthash.
     */
    function zonehash(bytes32 node) external view returns (bytes memory);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IExtendedResolver {
    function resolve(
        bytes memory name,
        bytes memory data
    ) external view returns (bytes memory);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/IInterfaceResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IInterfaceResolver {
    event InterfaceChanged(
        bytes32 indexed node,
        bytes4 indexed interfaceID,
        address implementer
    );

    /**
     * Returns the address of a contract that implements the specified interface for this name.
     * If an implementer has not been set for this interfaceID and name, the resolver will query
     * the contract at `addr()`. If `addr()` is set, a contract exists at that address, and that
     * contract implements EIP165 and returns `true` for the specified interfaceID, its address
     * will be returned.
     * @param node The ENS node to query.
     * @param interfaceID The EIP 165 interface ID to check for.
     * @return The address that implements this interface, or 0 if the interface is unsupported.
     */
    function interfaceImplementer(
        bytes32 node,
        bytes4 interfaceID
    ) external view returns (address);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/INameResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface INameResolver {
    event NameChanged(bytes32 indexed node, string name);

    /**
     * Returns the name associated with an ENS node, for reverse records.
     * Defined in EIP181.
     * @param node The ENS node to query.
     * @return The associated name.
     */
    function name(bytes32 node) external view returns (string memory);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/IPubkeyResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IPubkeyResolver {
    event PubkeyChanged(bytes32 indexed node, bytes32 x, bytes32 y);

    /**
     * Returns the SECP256k1 public key associated with an ENS node.
     * Defined in EIP 619.
     * @param node The ENS node to query
     * @return x The X coordinate of the curve point for the public key.
     * @return y The Y coordinate of the curve point for the public key.
     */
    function pubkey(bytes32 node) external view returns (bytes32 x, bytes32 y);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface ITextResolver {
    event TextChanged(
        bytes32 indexed node,
        string indexed indexedKey,
        string key,
        string value
    );

    /**
     * Returns the text data associated with an ENS node and key.
     * @param node The ENS node to query.
     * @param key The text data key to query.
     * @return The associated text data.
     */
    function text(
        bytes32 node,
        string calldata key
    ) external view returns (string memory);
}


// File: @ensdomains/ens-contracts/contracts/resolvers/profiles/IVersionableResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IVersionableResolver {
    event VersionChanged(bytes32 indexed node, uint64 newVersion);

    function recordVersions(bytes32 node) external view returns (uint64);
}


// File: @ensdomains/ens-contracts/contracts/reverseRegistrar/IReverseRegistrar.sol
pragma solidity >=0.8.4;

interface IReverseRegistrar {
    function setDefaultResolver(address resolver) external;

    function claim(address owner) external returns (bytes32);

    function claimForAddr(
        address addr,
        address owner,
        address resolver
    ) external returns (bytes32);

    function claimWithResolver(
        address owner,
        address resolver
    ) external returns (bytes32);

    function setName(string memory name) external returns (bytes32);

    function setNameForAddr(
        address addr,
        address owner,
        address resolver,
        string memory name
    ) external returns (bytes32);

    function node(address addr) external pure returns (bytes32);
}


// File: @ensdomains/ens-contracts/contracts/reverseRegistrar/ReverseClaimer.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {ENS} from "../registry/ENS.sol";
import {IReverseRegistrar} from "../reverseRegistrar/IReverseRegistrar.sol";

contract ReverseClaimer {
    bytes32 constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    constructor(ENS ens, address claimant) {
        IReverseRegistrar reverseRegistrar = IReverseRegistrar(
            ens.owner(ADDR_REVERSE_NODE)
        );
        reverseRegistrar.claim(claimant);
    }
}


// File: @ensdomains/ens-contracts/contracts/utils/NameEncoder.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BytesUtils} from "../wrapper/BytesUtils.sol";

library NameEncoder {
    using BytesUtils for bytes;

    function dnsEncodeName(
        string memory name
    ) internal pure returns (bytes memory dnsName, bytes32 node) {
        uint8 labelLength = 0;
        bytes memory bytesName = bytes(name);
        uint256 length = bytesName.length;
        dnsName = new bytes(length + 2);
        node = 0;
        if (length == 0) {
            dnsName[0] = 0;
            return (dnsName, node);
        }

        // use unchecked to save gas since we check for an underflow
        // and we check for the length before the loop
        unchecked {
            for (uint256 i = length - 1; i >= 0; i--) {
                if (bytesName[i] == ".") {
                    dnsName[i + 1] = bytes1(labelLength);
                    node = keccak256(
                        abi.encodePacked(
                            node,
                            bytesName.keccak(i + 1, labelLength)
                        )
                    );
                    labelLength = 0;
                } else {
                    labelLength += 1;
                    dnsName[i + 1] = bytesName[i];
                }
                if (i == 0) {
                    break;
                }
            }
        }

        node = keccak256(
            abi.encodePacked(node, bytesName.keccak(0, labelLength))
        );

        dnsName[0] = bytes1(labelLength);
        return (dnsName, node);
    }
}


// File: @ensdomains/ens-contracts/contracts/wrapper/BytesUtils.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

library BytesUtils {
    /*
     * @dev Returns the keccak-256 hash of a byte range.
     * @param self The byte string to hash.
     * @param offset The position to start hashing at.
     * @param len The number of bytes to hash.
     * @return The hash of the byte range.
     */
    function keccak(
        bytes memory self,
        uint256 offset,
        uint256 len
    ) internal pure returns (bytes32 ret) {
        require(offset + len <= self.length);
        assembly {
            ret := keccak256(add(add(self, 32), offset), len)
        }
    }

    /**
     * @dev Returns the ENS namehash of a DNS-encoded name.
     * @param self The DNS-encoded name to hash.
     * @param offset The offset at which to start hashing.
     * @return The namehash of the name.
     */
    function namehash(
        bytes memory self,
        uint256 offset
    ) internal pure returns (bytes32) {
        (bytes32 labelhash, uint256 newOffset) = readLabel(self, offset);
        if (labelhash == bytes32(0)) {
            require(offset == self.length - 1, "namehash: Junk at end of name");
            return bytes32(0);
        }
        return
            keccak256(abi.encodePacked(namehash(self, newOffset), labelhash));
    }

    /**
     * @dev Returns the keccak-256 hash of a DNS-encoded label, and the offset to the start of the next label.
     * @param self The byte string to read a label from.
     * @param idx The index to read a label at.
     * @return labelhash The hash of the label at the specified index, or 0 if it is the last label.
     * @return newIdx The index of the start of the next label.
     */
    function readLabel(
        bytes memory self,
        uint256 idx
    ) internal pure returns (bytes32 labelhash, uint256 newIdx) {
        require(idx < self.length, "readLabel: Index out of bounds");
        uint256 len = uint256(uint8(self[idx]));
        if (len > 0) {
            labelhash = keccak(self, idx + 1, len);
        } else {
            labelhash = bytes32(0);
        }
        newIdx = idx + len + 1;
    }
}


// File: @ensdomains/ens-contracts/contracts/wrapper/IMetadataService.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

interface IMetadataService {
    function uri(uint256) external view returns (string memory);
}


// File: @ensdomains/ens-contracts/contracts/wrapper/INameWrapper.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "../registry/ENS.sol";
import "../ethregistrar/IBaseRegistrar.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./IMetadataService.sol";
import "./INameWrapperUpgrade.sol";

uint32 constant CANNOT_UNWRAP = 1;
uint32 constant CANNOT_BURN_FUSES = 2;
uint32 constant CANNOT_TRANSFER = 4;
uint32 constant CANNOT_SET_RESOLVER = 8;
uint32 constant CANNOT_SET_TTL = 16;
uint32 constant CANNOT_CREATE_SUBDOMAIN = 32;
uint32 constant CANNOT_APPROVE = 64;
//uint16 reserved for parent controlled fuses from bit 17 to bit 32
uint32 constant PARENT_CANNOT_CONTROL = 1 << 16;
uint32 constant IS_DOT_ETH = 1 << 17;
uint32 constant CAN_EXTEND_EXPIRY = 1 << 18;
uint32 constant CAN_DO_EVERYTHING = 0;
uint32 constant PARENT_CONTROLLED_FUSES = 0xFFFF0000;
// all fuses apart from IS_DOT_ETH
uint32 constant USER_SETTABLE_FUSES = 0xFFFDFFFF;

interface INameWrapper is IERC1155 {
    event NameWrapped(
        bytes32 indexed node,
        bytes name,
        address owner,
        uint32 fuses,
        uint64 expiry
    );

    event NameUnwrapped(bytes32 indexed node, address owner);

    event FusesSet(bytes32 indexed node, uint32 fuses);
    event ExpiryExtended(bytes32 indexed node, uint64 expiry);

    function ens() external view returns (ENS);

    function registrar() external view returns (IBaseRegistrar);

    function metadataService() external view returns (IMetadataService);

    function names(bytes32) external view returns (bytes memory);

    function name() external view returns (string memory);

    function upgradeContract() external view returns (INameWrapperUpgrade);

    function supportsInterface(bytes4 interfaceID) external view returns (bool);

    function wrap(
        bytes calldata name,
        address wrappedOwner,
        address resolver
    ) external;

    function wrapETH2LD(
        string calldata label,
        address wrappedOwner,
        uint16 ownerControlledFuses,
        address resolver
    ) external returns (uint64 expires);

    function registerAndWrapETH2LD(
        string calldata label,
        address wrappedOwner,
        uint256 duration,
        address resolver,
        uint16 ownerControlledFuses
    ) external returns (uint256 registrarExpiry);

    function renew(
        uint256 labelHash,
        uint256 duration
    ) external returns (uint256 expires);

    function unwrap(bytes32 node, bytes32 label, address owner) external;

    function unwrapETH2LD(
        bytes32 label,
        address newRegistrant,
        address newController
    ) external;

    function upgrade(bytes calldata name, bytes calldata extraData) external;

    function setFuses(
        bytes32 node,
        uint16 ownerControlledFuses
    ) external returns (uint32 newFuses);

    function setChildFuses(
        bytes32 parentNode,
        bytes32 labelhash,
        uint32 fuses,
        uint64 expiry
    ) external;

    function setSubnodeRecord(
        bytes32 node,
        string calldata label,
        address owner,
        address resolver,
        uint64 ttl,
        uint32 fuses,
        uint64 expiry
    ) external returns (bytes32);

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    ) external;

    function setSubnodeOwner(
        bytes32 node,
        string calldata label,
        address newOwner,
        uint32 fuses,
        uint64 expiry
    ) external returns (bytes32);

    function extendExpiry(
        bytes32 node,
        bytes32 labelhash,
        uint64 expiry
    ) external returns (uint64);

    function canModifyName(
        bytes32 node,
        address addr
    ) external view returns (bool);

    function setResolver(bytes32 node, address resolver) external;

    function setTTL(bytes32 node, uint64 ttl) external;

    function ownerOf(uint256 id) external view returns (address owner);

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function getData(
        uint256 id
    ) external view returns (address, uint32, uint64);

    function setMetadataService(IMetadataService _metadataService) external;

    function uri(uint256 tokenId) external view returns (string memory);

    function setUpgradeContract(INameWrapperUpgrade _upgradeAddress) external;

    function allFusesBurned(
        bytes32 node,
        uint32 fuseMask
    ) external view returns (bool);

    function isWrapped(bytes32) external view returns (bool);

    function isWrapped(bytes32, bytes32) external view returns (bool);
}


// File: @ensdomains/ens-contracts/contracts/wrapper/INameWrapperUpgrade.sol
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

interface INameWrapperUpgrade {
    function wrapFromUpgrade(
        bytes calldata name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry,
        address approved,
        bytes calldata extraData
    ) external;
}


// File: @openzeppelin/contracts/interfaces/IERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";


// File: @openzeppelin/contracts/security/ReentrancyGuard.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}


// File: @openzeppelin/contracts/token/ERC1155/ERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155.sol";
import "./IERC1155Receiver.sol";
import "./extensions/IERC1155MetadataURI.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `ids` and `amounts` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    /**
     * @dev Hook that is called after any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}


// File: @openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}


// File: @openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/utils/ERC1155Holder.sol)

pragma solidity ^0.8.0;

import "./ERC1155Receiver.sol";

/**
 * Simple implementation of `ERC1155Receiver` that will allow a contract to hold ERC1155 tokens.
 *
 * IMPORTANT: When inheriting this contract, you must include a way to use the received tokens, otherwise they will be
 * stuck.
 *
 * @dev _Available since v3.1._
 */
contract ERC1155Holder is ERC1155Receiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}


// File: @openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/utils/ERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../IERC1155Receiver.sol";
import "../../../utils/introspection/ERC165.sol";

/**
 * @dev _Available since v3.1._
 */
abstract contract ERC1155Receiver is ERC165, IERC1155Receiver {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


// File: @openzeppelin/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/IERC721.sol)

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
    function setApprovalForAll(address operator, bool approved) external;

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


// File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


// File: @openzeppelin/contracts/utils/Context.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


// File: @openzeppelin/contracts/utils/introspection/ERC165.sol
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


// File: @openzeppelin/contracts/utils/introspection/ERC165Checker.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/introspection/ERC165Checker.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library ERC165Checker {
    // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;

    /**
     * @dev Returns true if `account` supports the {IERC165} interface.
     */
    function supportsERC165(address account) internal view returns (bool) {
        // Any contract that implements ERC165 must explicitly indicate support of
        // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
        return
            supportsERC165InterfaceUnchecked(account, type(IERC165).interfaceId) &&
            !supportsERC165InterfaceUnchecked(account, _INTERFACE_ID_INVALID);
    }

    /**
     * @dev Returns true if `account` supports the interface defined by
     * `interfaceId`. Support for {IERC165} itself is queried automatically.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        // query support of both ERC165 as per the spec and support of _interfaceId
        return supportsERC165(account) && supportsERC165InterfaceUnchecked(account, interfaceId);
    }

    /**
     * @dev Returns a boolean array where each value corresponds to the
     * interfaces passed in and whether they're supported or not. This allows
     * you to batch check interfaces for a contract where your expectation
     * is that some interfaces may not be supported.
     *
     * See {IERC165-supportsInterface}.
     *
     * _Available since v3.4._
     */
    function getSupportedInterfaces(
        address account,
        bytes4[] memory interfaceIds
    ) internal view returns (bool[] memory) {
        // an array of booleans corresponding to interfaceIds and whether they're supported or not
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);

        // query support of ERC165 itself
        if (supportsERC165(account)) {
            // query support of each interface in interfaceIds
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = supportsERC165InterfaceUnchecked(account, interfaceIds[i]);
            }
        }

        return interfaceIdsSupported;
    }

    /**
     * @dev Returns true if `account` supports all the interfaces defined in
     * `interfaceIds`. Support for {IERC165} itself is queried automatically.
     *
     * Batch-querying can lead to gas savings by skipping repeated checks for
     * {IERC165} support.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        // query support of ERC165 itself
        if (!supportsERC165(account)) {
            return false;
        }

        // query support of each interface in interfaceIds
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!supportsERC165InterfaceUnchecked(account, interfaceIds[i])) {
                return false;
            }
        }

        // all interfaces supported
        return true;
    }

    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     *
     * Some precompiled contracts will falsely indicate support for a given interface, so caution
     * should be exercised when using this function.
     *
     * Interface identification is specified in ERC-165.
     */
    function supportsERC165InterfaceUnchecked(address account, bytes4 interfaceId) internal view returns (bool) {
        // prepare call
        bytes memory encodedParams = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);

        // perform static call
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly {
            success := staticcall(30000, account, add(encodedParams, 0x20), mload(encodedParams), 0x00, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0x00)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }
}


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol
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


// File: contracts/ensGuilds/ENSGuilds.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ENS } from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import { ReverseClaimer } from "@ensdomains/ens-contracts/contracts/reverseRegistrar/ReverseClaimer.sol";
import { INameWrapper } from "@ensdomains/ens-contracts/contracts/wrapper/INameWrapper.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { IFeePolicy } from "../feePolicies/IFeePolicy.sol";
import { ITagsAuthPolicy } from "../tagsAuthPolicies/ITagsAuthPolicy.sol";
import { ENSNamehash } from "../libraries/ENSNamehash.sol";
import { IENSGuilds } from "./interfaces/IENSGuilds.sol";
import { GuildTagTokens } from "./mixins/GuildTagTokens.sol";
import { ENSGuildsHumanized } from "./mixins/ENSGuildsHumanized.sol";
import { GuildsResolver } from "./GuildsResolver.sol";

contract ENSGuilds is IENSGuilds, ENSGuildsHumanized, GuildTagTokens, ERC1155Holder, ReentrancyGuard, ReverseClaimer {
    struct GuildInfo {
        address admin;
        IFeePolicy feePolicy;
        ITagsAuthPolicy tagsAuthPolicy;
        address originalResolver;
        bool active;
        bool deregistered;
        bool usesNameWrapper;
    }

    using ERC165Checker for address;
    using ENSNamehash for bytes;

    /** State */
    ENS private immutable _ensRegistry;
    INameWrapper private immutable _nameWrapper;
    GuildsResolver private immutable _guildsResolver;
    mapping(bytes32 => GuildInfo) public guilds;

    /** Errors */
    error AlreadyRegistered();
    error ENSGuildsIsNotRegisteredOperator();
    error NotDomainOwner();
    error InvalidPolicy(address);
    error GuildNotActive();
    error ClaimUnauthorized();
    error RevokeUnauthorized();
    error TransferUnauthorized();
    error GuildAdminOnly();
    error TagAlreadyClaimed();
    error FeeError();

    modifier onlyGuildAdmin(bytes32 guildHash) {
        if (guilds[guildHash].admin != _msgSender()) {
            revert GuildAdminOnly();
        }
        _;
    }

    modifier requireGuildRegistered(bytes32 guildEnsNode) {
        if (guilds[guildEnsNode].deregistered) {
            revert GuildNotActive();
        }
        _;
    }

    modifier requireGuildActive(bytes32 guildEnsNode) {
        if (!guilds[guildEnsNode].active || guilds[guildEnsNode].deregistered) {
            revert GuildNotActive();
        }
        _;
    }

    constructor(
        string memory defaultTokenMetadataUri,
        ENS ensRegistry,
        INameWrapper nameWrapper,
        GuildsResolver guildsResolver,
        address reverseRecordOwner
    ) ERC1155(defaultTokenMetadataUri) ReverseClaimer(ensRegistry, reverseRecordOwner) {
        _ensRegistry = ensRegistry;
        _nameWrapper = nameWrapper;
        _guildsResolver = guildsResolver;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(GuildTagTokens, ERC1155Receiver, IERC165) returns (bool) {
        return
            interfaceId == type(IENSGuilds).interfaceId ||
            GuildTagTokens.supportsInterface(interfaceId) ||
            ERC1155Receiver.supportsInterface(interfaceId) ||
            ERC165.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function registerGuild(
        string calldata guildName,
        address admin,
        address feePolicy,
        address tagsAuthPolicy
    ) public override(IENSGuilds) {
        bytes32 ensNode = bytes(guildName).namehash();

        // Determine whether this name is using the ENS NameWrapper
        address nodeOwner = _ensRegistry.owner(ensNode);
        bool usesNameWrapper = false;
        if (nodeOwner == address(_nameWrapper)) {
            nodeOwner = _nameWrapper.ownerOf(uint256(ensNode));
            usesNameWrapper = true;
        }

        // Check caller is owner of domain
        if (nodeOwner != _msgSender()) {
            revert NotDomainOwner();
        }

        // Check guild not yet registered
        if (address(guilds[ensNode].feePolicy) != address(0)) {
            revert AlreadyRegistered();
        }

        // Check ENSGuilds contract has been approved to edit the ENS registry on behalf of the caller
        if (usesNameWrapper && !_nameWrapper.isApprovedForAll(_msgSender(), address(this))) {
            revert ENSGuildsIsNotRegisteredOperator();
        }
        if (!usesNameWrapper && !_ensRegistry.isApprovedForAll(_msgSender(), address(this))) {
            revert ENSGuildsIsNotRegisteredOperator();
        }

        // Check for valid fee/tagsAuth policies
        if (!feePolicy.supportsInterface(type(IFeePolicy).interfaceId)) {
            revert InvalidPolicy(feePolicy);
        }
        if (!tagsAuthPolicy.supportsInterface(type(ITagsAuthPolicy).interfaceId)) {
            revert InvalidPolicy(tagsAuthPolicy);
        }

        // Store the config for this Guild
        address originalResolver = _ensRegistry.resolver(ensNode);
        guilds[ensNode] = GuildInfo({
            admin: admin,
            feePolicy: IFeePolicy(feePolicy),
            tagsAuthPolicy: ITagsAuthPolicy(tagsAuthPolicy),
            originalResolver: originalResolver,
            active: true,
            deregistered: false,
            usesNameWrapper: usesNameWrapper
        });

        // Set GuildsResolver as the resolver for the Guild's ENS name
        _guildsResolver.setPassthroughTarget(ensNode, originalResolver);
        _setResolverForGuild(ensNode, address(_guildsResolver));
        _guildsResolver.onGuildRegistered(guildName);

        // Done
        emit Registered(ensNode);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function deregisterGuild(
        bytes32 ensNode
    ) public override(ENSGuildsHumanized, IENSGuilds) onlyGuildAdmin(ensNode) requireGuildRegistered(ensNode) {
        // wipe all the ENS records so that this guild may be re-registered later with a clean state
        _guildsResolver.clearEnsRecordsForGuild(ensNode);

        // un-set ENSGuilds as the resolver for the guild's ENS name
        address originalResolver = guilds[ensNode].originalResolver;
        _setResolverForGuild(ensNode, address(originalResolver));

        // clear out internal state
        guilds[ensNode] = GuildInfo({
            deregistered: true,
            admin: address(0),
            feePolicy: IFeePolicy(address(0)),
            tagsAuthPolicy: ITagsAuthPolicy(address(0)),
            originalResolver: address(0),
            active: false,
            usesNameWrapper: false
        });
        emit Deregistered(ensNode);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function claimGuildTag(
        bytes32 guildEnsNode,
        string calldata tag,
        address recipient,
        bytes calldata extraClaimArgs
    ) public payable override(ENSGuildsHumanized, IENSGuilds) nonReentrant requireGuildActive(guildEnsNode) {
        bytes32 tagHash = keccak256(bytes(tag));

        // check tag not already registered
        bytes32 tagEnsNode = keccak256(abi.encodePacked(guildEnsNode, tagHash));
        if (_ensRegistry.owner(tagEnsNode) != address(0)) {
            // this is a pre-existing sub-name already registered outside of the Guilds context
            revert TagAlreadyClaimed();
        }
        if (tagOwner(guildEnsNode, tagHash) != address(0)) {
            // already registered as a Guild tag
            revert TagAlreadyClaimed();
        }

        // check caller is authorized to claim tag
        ITagsAuthPolicy auth = guilds[guildEnsNode].tagsAuthPolicy;
        if (!auth.canClaimTag(guildEnsNode, tag, _msgSender(), recipient, extraClaimArgs)) {
            revert ClaimUnauthorized();
        }

        // fees
        _handleClaimFee(guildEnsNode, tag, extraClaimArgs);

        // NFT mint
        _mintNewGuildToken(guildEnsNode, recipient);

        // inform auth contract that tag was claimed, then revoke an existing tag if instructed
        string memory tagToRevoke = auth.onTagClaimed(guildEnsNode, tag, _msgSender(), recipient, extraClaimArgs);
        if (bytes(tagToRevoke).length != 0) {
            _revokeTag(guildEnsNode, tagToRevoke);
        }

        // Set forward record in ENS resolver
        _guildsResolver.setEnsForwardRecord(guildEnsNode, tag, recipient);

        emit TagClaimed(guildEnsNode, tagHash, recipient);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function claimGuildTagsBatch(
        bytes32 guildEnsNode,
        string[] calldata tags,
        address[] calldata recipients,
        bytes[] calldata extraClaimArgs
    ) external payable override {
        for (uint256 i = 0; i < tags.length; i++) {
            claimGuildTag(guildEnsNode, tags[i], recipients[i], extraClaimArgs[i]);
        }
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function transferGuildTag(
        bytes32 guildEnsNode,
        string calldata tag,
        address recipient,
        bytes calldata extraTransferArgs
    ) public override(ENSGuildsHumanized, IENSGuilds) nonReentrant requireGuildActive(guildEnsNode) {
        bytes32 tagHash = keccak256(bytes(tag));
        address currentOwner = tagOwner(guildEnsNode, tagHash);

        // check that tag exists
        if (currentOwner == address(0)) {
            revert TransferUnauthorized();
        }

        // transfer authorized?
        ITagsAuthPolicy auth = guilds[guildEnsNode].tagsAuthPolicy;
        if (!auth.canTransferTag(guildEnsNode, tag, _msgSender(), currentOwner, recipient, extraTransferArgs)) {
            revert TransferUnauthorized();
        }

        // NFT transfer
        _transferGuildToken(guildEnsNode, currentOwner, recipient);

        // Update forward record in ENS resolver
        _guildsResolver.setEnsForwardRecord(guildEnsNode, tag, recipient);

        // Inform auth contract that tag was transferred
        auth.onTagTransferred(guildEnsNode, tag, _msgSender(), currentOwner, recipient);

        emit TagTransferred(guildEnsNode, tagHash, currentOwner, recipient);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function guildAdmin(bytes32 guildHash) public view override(ENSGuildsHumanized, IENSGuilds) returns (address) {
        return guilds[guildHash].admin;
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function revokeGuildTag(
        bytes32 guildEnsNode,
        string calldata tag,
        bytes calldata extraData
    ) public override(ENSGuildsHumanized, IENSGuilds) nonReentrant requireGuildRegistered(guildEnsNode) {
        GuildInfo storage guild = guilds[guildEnsNode];

        // revoke authorized?
        ITagsAuthPolicy auth = guild.tagsAuthPolicy;
        if (!auth.canRevokeTag(_msgSender(), guildEnsNode, tag, extraData)) {
            revert RevokeUnauthorized();
        }

        _revokeTag(guildEnsNode, tag);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function revokeGuildTagsBatch(
        bytes32 guildHash,
        string[] calldata tags,
        bytes[] calldata extraData
    ) external override {
        for (uint256 i = 0; i < tags.length; i++) {
            revokeGuildTag(guildHash, tags[i], extraData[i]);
        }
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function updateGuildFeePolicy(
        bytes32 guildEnsNode,
        address feePolicy
    )
        public
        override(ENSGuildsHumanized, IENSGuilds)
        onlyGuildAdmin(guildEnsNode)
        requireGuildRegistered(guildEnsNode)
    {
        if (!feePolicy.supportsInterface(type(IFeePolicy).interfaceId)) {
            revert InvalidPolicy(feePolicy);
        }
        guilds[guildEnsNode].feePolicy = IFeePolicy(feePolicy);
        emit FeePolicyUpdated(guildEnsNode, feePolicy);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function updateGuildTagsAuthPolicy(
        bytes32 guildEnsNode,
        address tagsAuthPolicy
    )
        public
        override(ENSGuildsHumanized, IENSGuilds)
        onlyGuildAdmin(guildEnsNode)
        requireGuildRegistered(guildEnsNode)
    {
        if (!tagsAuthPolicy.supportsInterface(type(ITagsAuthPolicy).interfaceId)) {
            revert InvalidPolicy(tagsAuthPolicy);
        }
        guilds[guildEnsNode].tagsAuthPolicy = ITagsAuthPolicy(tagsAuthPolicy);
        emit TagsAuthPolicyUpdated(guildEnsNode, tagsAuthPolicy);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function transferGuildAdmin(
        bytes32 guildEnsNode,
        address newAdmin
    )
        public
        override(ENSGuildsHumanized, IENSGuilds)
        onlyGuildAdmin(guildEnsNode)
        requireGuildRegistered(guildEnsNode)
    {
        guilds[guildEnsNode].admin = newAdmin;
        emit AdminTransferred(guildEnsNode, newAdmin);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function setGuildTokenUri(
        bytes32 guildEnsNode,
        string calldata uri
    )
        public
        override(ENSGuildsHumanized, IENSGuilds)
        onlyGuildAdmin(guildEnsNode)
        requireGuildRegistered(guildEnsNode)
    {
        _setGuildTokenURI(guildEnsNode, uri);
        emit TokenUriSet(guildEnsNode, uri);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function setGuildActive(
        bytes32 guildEnsNode,
        bool active
    )
        public
        override(ENSGuildsHumanized, IENSGuilds)
        onlyGuildAdmin(guildEnsNode)
        requireGuildRegistered(guildEnsNode)
    {
        guilds[guildEnsNode].active = active;
        emit SetActive(guildEnsNode, active);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function tagOwner(
        bytes32 guildEnsNode,
        bytes32 tagHash
    ) public view override(ENSGuildsHumanized, IENSGuilds) returns (address) {
        return _guildsResolver.getTagOwner(guildEnsNode, tagHash);
    }

    /**
     * @inheritdoc IENSGuilds
     */
    function setFallbackResolver(
        bytes32 guildEnsNode,
        address fallbackResolver
    )
        public
        override(ENSGuildsHumanized, IENSGuilds)
        onlyGuildAdmin(guildEnsNode)
        requireGuildRegistered(guildEnsNode)
    {
        _guildsResolver.setPassthroughTarget(guildEnsNode, fallbackResolver);
    }

    function _revokeTag(bytes32 guildEnsNode, string memory tag) private {
        bytes32 tagHash = keccak256(bytes(tag));
        address _tagOwner = tagOwner(guildEnsNode, tagHash);

        // check that tag exists
        if (_tagOwner == address(0)) {
            revert RevokeUnauthorized();
        }

        // clear the ENS record for the tag
        _guildsResolver.setEnsForwardRecord(guildEnsNode, tag, address(0));

        // clear the token ownership for the tag
        _burnGuildToken(guildEnsNode, _tagOwner);

        // inform the auth policy of the revocation
        ITagsAuthPolicy auth = guilds[guildEnsNode].tagsAuthPolicy;
        if (address(auth) != address(0)) {
            auth.onTagRevoked(_msgSender(), _tagOwner, guildEnsNode, tag);
        }

        emit TagRevoked(guildEnsNode, tagHash);
    }

    function _handleClaimFee(bytes32 guildEnsNode, string calldata tag, bytes calldata extraClaimArgs) internal {
        (address feeToken, uint256 fee, address feePaidTo) = guilds[guildEnsNode].feePolicy.tagClaimFee(
            guildEnsNode,
            tag,
            _msgSender(),
            extraClaimArgs
        );
        if (fee != 0) {
            if (feeToken == address(0)) {
                if (msg.value != fee) {
                    revert FeeError();
                }
                // solhint-disable-next-line avoid-low-level-calls
                (bool sent, ) = feePaidTo.call{ value: msg.value }("");
                if (!sent) revert FeeError();
            } else {
                try IERC20(feeToken).transferFrom(_msgSender(), feePaidTo, fee) returns (bool sent) {
                    if (!sent) revert FeeError();
                } catch {
                    revert FeeError();
                }
            }
        }
    }

    function _setResolverForGuild(bytes32 guildEnsNode, address resolver) internal {
        if (guilds[guildEnsNode].usesNameWrapper) {
            _nameWrapper.setResolver(guildEnsNode, resolver);
        } else {
            _ensRegistry.setResolver(guildEnsNode, resolver);
        }
    }
}


// File: contracts/ensGuilds/GuildsResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { NameEncoder } from "@ensdomains/ens-contracts/contracts/utils/NameEncoder.sol";
import { ReverseClaimer } from "@ensdomains/ens-contracts/contracts/reverseRegistrar/ReverseClaimer.sol";
import { ENS } from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import { INameWrapper } from "@ensdomains/ens-contracts/contracts/wrapper/INameWrapper.sol";

import { WildcardResolverBase } from "../ensWildcardResolvers/WildcardResolverBase.sol";
import { IENSGuilds } from "./interfaces/IENSGuilds.sol";

contract GuildsResolver is WildcardResolverBase, ReverseClaimer {
    using NameEncoder for string;

    IENSGuilds public ensGuilds;

    // guildEnsNode => recordVersion => keccak256(tag) => tagOwner
    mapping(bytes32 => mapping(uint256 => mapping(bytes32 => address))) private _guildRecords;

    // used to clear all of a Guild's ENS records
    mapping(bytes32 => uint256) private _guildRecordVersions;

    modifier onlyEnsGuildsContract() {
        // solhint-disable-next-line reason-string, custom-errors
        require(_msgSender() == address(ensGuilds));
        _;
    }

    constructor(
        ENS _ensRegistry,
        INameWrapper _ensNameWrapper,
        address reverseRecordOwner
    ) WildcardResolverBase(_ensRegistry, _ensNameWrapper) ReverseClaimer(_ensRegistry, reverseRecordOwner) {
        return;
    }

    function initialize(IENSGuilds _ensGuilds) external {
        // solhint-disable reason-string, custom-errors
        require(address(ensGuilds) == address(0));
        require(_ensGuilds.supportsInterface(type(IENSGuilds).interfaceId));
        // solhint-enable reason-string, custom-errors

        ensGuilds = _ensGuilds;
    }

    function onGuildRegistered(string calldata guildName) external onlyEnsGuildsContract {
        // need to keep track of the mapping from the DNS-encoded version
        // of the guild name to its namehash-encoded version
        (bytes memory dnsEncodedName, bytes32 ensNode) = guildName.dnsEncodeName();
        parentEnsNodes[dnsEncodedName] = ensNode;
    }

    /**
     * Sets the address associated with a guild tag.
     * May only be called by descendants of this contract
     */
    function setEnsForwardRecord(
        bytes32 guildEnsNode,
        string memory tag,
        address _addr
    ) external onlyEnsGuildsContract {
        uint256 version = _guildRecordVersions[guildEnsNode];
        bytes32 tagHash = keccak256(bytes(tag));
        _guildRecords[guildEnsNode][version][tagHash] = _addr;
    }

    function clearEnsRecordsForGuild(bytes32 guildEnsNode) external onlyEnsGuildsContract {
        _guildRecordVersions[guildEnsNode]++;
    }

    function setPassthroughTarget(bytes32 guildEnsNode, address resolver) external onlyEnsGuildsContract {
        _setPassthroughTarget(guildEnsNode, resolver);
    }

    function getTagOwner(bytes32 guildEnsNode, bytes32 tagHash) public view returns (address) {
        uint256 version = _guildRecordVersions[guildEnsNode];
        return _guildRecords[guildEnsNode][version][tagHash];
    }

    function _resolveWildcardEthAddr(
        bytes calldata childUtf8Encoded,
        bytes calldata parentDnsEncoded
    ) internal view override returns (address) {
        bytes32 guildEnsNode = parentEnsNodes[parentDnsEncoded];
        bytes32 tagHash = keccak256(childUtf8Encoded);
        return getTagOwner(guildEnsNode, tagHash);
    }

    function _resolveWildcardTextRecord(
        bytes calldata,
        bytes calldata,
        string calldata
    ) internal pure override returns (string memory) {
        // ENSGuilds doesn't set text records for Guild tags
        return "";
    }

    function isAuthorised(bytes32 node) internal view override returns (bool) {
        return _msgSender() == _nodeOwner(node);
    }
}


// File: contracts/ensGuilds/interfaces/IENSGuilds.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IERC1155MetadataURI } from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

interface IENSGuilds is IERC1155MetadataURI {
    /** Events */
    event Registered(bytes32 indexed guildEnsNode);
    event Deregistered(bytes32 indexed guildEnsNode);
    event TagClaimed(bytes32 indexed guildEnsNode, bytes32 indexed tagHash, address recipient);
    event TagTransferred(bytes32 indexed guildEnsNode, bytes32 indexed tagHash, address from, address to);
    event TagRevoked(bytes32 indexed guildEnsNode, bytes32 indexed tagHash);
    event FeePolicyUpdated(bytes32 indexed guildEnsNode, address feePolicy);
    event TagsAuthPolicyUpdated(bytes32 indexed guildEnsNode, address tagsAuthPolicy);
    event AdminTransferred(bytes32 indexed guildEnsNode, address newAdmin);
    event SetActive(bytes32 indexed guildEnsNode, bool active);
    event TokenUriSet(bytes32 indexed guildEnsNode, string uri);

    /* Functions */

    /**
     * @notice Registers a new guild from an existing ENS domain.
     * Caller must be the ENS node's owner and ENSGuilds must have been designated an "operator" for the caller.
     * @param ensName The guild's full ENS name (e.g. 'my-guild.eth')
     * @param guildAdmin The address that will administrate this guild
     * @param feePolicy The address of an implementation of FeePolicy to use for minting new tags within this guild
     * @param tagsAuthPolicy The address of an implementation of TagsAuthPolicy to use for minting new tags
     * within this guild
     */
    function registerGuild(
        string calldata ensName,
        address guildAdmin,
        address feePolicy,
        address tagsAuthPolicy
    ) external;

    /**
     * @notice De-registers a registered guild.
     * Designates guild as inactive and marks all tags previously minted for that guild as eligible for revocation.
     * @param guildEnsNode The ENS namehash of the guild's domain
     */
    function deregisterGuild(bytes32 guildEnsNode) external;

    /**
     * @notice Claims a guild tag
     * @param guildEnsNode The namehash of the guild for which the tag should be claimed (e.g. namehash('my-guild.eth'))
     * @param tag The tag name to claim (e.g. 'foo' for foo.my-guild.eth). Assumes `tag` is already normalized per
     * ENS Name Processing rules
     * @param recipient The address that will receive this guild tag (usually same as the caller)
     * @param extraClaimArgs [Optional] Any additional arguments necessary for guild-specific logic,
     *  such as authorization
     */
    function claimGuildTag(
        bytes32 guildEnsNode,
        string calldata tag,
        address recipient,
        bytes calldata extraClaimArgs
    ) external payable;

    /**
     * @notice Transfers an existing guild tag
     * @param guildEnsNode The namehash of the guild for which the tag should be transferred
     * (e.g. namehash('my-guild.eth'))
     * @param tag The tag name to transfer (e.g. 'foo' for foo.my-guild.eth). Assumes `tag` is already normalized per
     * ENS Name Processing rules
     * @param recipient The address that will receive this guild tag
     * @param extraTransferArgs [Optional] Any additional arguments necessary for guild-specific logic,
     *  such as authorization
     */
    function transferGuildTag(
        bytes32 guildEnsNode,
        string calldata tag,
        address recipient,
        bytes calldata extraTransferArgs
    ) external;

    /**
     * @notice Claims multiple tags for a guild at once
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tags Tags to be claimed
     * @param recipients Recipients of each tag to be claimed
     * @param extraClaimArgs Per-tag extra arguments required for guild-specific logic, such as authorization.
     * Must have same length as array of tagHashes, even if each array element is itself empty bytes
     */
    function claimGuildTagsBatch(
        bytes32 guildEnsNode,
        string[] calldata tags,
        address[] calldata recipients,
        bytes[] calldata extraClaimArgs
    ) external payable;

    /**
     * @notice Returns the current owner of the given guild tag.
     * Returns address(0) if no such guild or tag exists, or if the guild has been deregistered.
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tagHash The ENS namehash of the tag (e.g. keccak256('foo') for foo.my-guild.eth)
     */
    function tagOwner(bytes32 guildEnsNode, bytes32 tagHash) external view returns (address);

    /**
     * @notice Attempts to revoke an existing guild tag, if authorized by the guild's AuthPolicy.
     * Deregistered guilds will bypass auth checks for revocation of all tags.
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tag The tag to revoke
     * @param extraData [Optional] Any additional arguments necessary for assessing whether a tag may be revoked
     */
    function revokeGuildTag(bytes32 guildEnsNode, string calldata tag, bytes calldata extraData) external;

    /**
     * @notice Attempts to revoke multiple guild tags
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tags tags to revoke
     * @param extraData Additional arguments necessary for assessing whether a tag may be revoked
     */
    function revokeGuildTagsBatch(bytes32 guildEnsNode, string[] calldata tags, bytes[] calldata extraData) external;

    /**
     * @notice Updates the FeePolicy for an existing guild. May only be called by the guild's registered admin.
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param feePolicy The address of an implementation of FeePolicy to use for minting new tags within this guild
     */
    function updateGuildFeePolicy(bytes32 guildEnsNode, address feePolicy) external;

    /**
     * @notice Updates the TagsAuthPolicy for an existing guild. May only be called by the guild's registered admin.
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tagsAuthPolicy The address of an implementation of TagsAuthPolicy to use for
     * minting new tags within this guild
     */
    function updateGuildTagsAuthPolicy(bytes32 guildEnsNode, address tagsAuthPolicy) external;

    /**
     * @notice Sets the metadata URI string for fetching metadata for a guild's tag NFTs.
     * May only be called by the guild's registered admin.
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param uri The ERC1155 metadata URL template
     */
    function setGuildTokenUri(bytes32 guildEnsNode, string calldata uri) external;

    /**
     * @notice Sets a guild as active or inactive. May only be called by the guild's registered admin.
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param active The new status
     */
    function setGuildActive(bytes32 guildEnsNode, bool active) external;

    /**
     * @notice Returns the current admin registered for the given guild.
     * @param guildEnsNode The ENS namehash of the guild's domain
     */
    function guildAdmin(bytes32 guildEnsNode) external view returns (address);

    /**
     * @notice Transfers the role of guild admin to the given address.
     * May only be called by the guild's registered admin.
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param newAdmin The new admin
     */
    function transferGuildAdmin(bytes32 guildEnsNode, address newAdmin) external;

    /**
     * @notice Registers a resolver for the guild's root ENS name that will
     * answer queries about the parent name itself, or any child names that are
     * not Guild tags
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param fallbackResolver The fallback resolver
     */
    function setFallbackResolver(bytes32 guildEnsNode, address fallbackResolver) external;
}


// File: contracts/ensGuilds/interfaces/IENSGuildsHumanized.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IENSGuildsHumanized {
    function claimGuildTag(
        string calldata guildEnsName,
        string calldata tag,
        address recipient,
        bytes calldata extraClaimArgs
    ) external payable;

    function transferGuildTag(
        string calldata guildEnsName,
        string calldata tag,
        address recipient,
        bytes calldata extraTransferArgs
    ) external;

    function setFallbackResolver(string calldata guildEnsName, address fallbackResolver) external;

    function tagOwner(string memory guildEnsName, string memory tag) external view returns (address);

    function revokeGuildTag(string calldata guildEnsName, string calldata tag, bytes calldata extraData) external;

    function updateGuildFeePolicy(string calldata guildEnsName, address feePolicy) external;

    function updateGuildTagsAuthPolicy(string calldata guildEnsName, address tagsAuthPolicy) external;

    function setGuildTokenUri(string calldata guildEnsName, string calldata uri) external;

    function setGuildActive(string calldata guildEnsName, bool active) external;

    function guildAdmin(string memory guildEnsName) external view returns (address);

    function transferGuildAdmin(string calldata guildEnsName, address newAdmin) external;

    function deregisterGuild(string calldata guildEnsName) external;
}


// File: contracts/ensGuilds/mixins/ENSGuildsHumanized.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IENSGuildsHumanized } from "../interfaces/IENSGuildsHumanized.sol";
import { ENSNamehash } from "../../libraries/ENSNamehash.sol";

abstract contract ENSGuildsHumanized is IENSGuildsHumanized {
    using ENSNamehash for bytes;

    // Humanized versions

    /**
     * @notice De-registers a registered guild.
     * Designates guild as inactive and marks all tags previously minted for that guild as eligible for revocation.
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     */
    function deregisterGuild(string calldata guildEnsName) external override {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        deregisterGuild(guildEnsNode);
    }

    /**
     * @notice Claims a guild tag
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     * @param tag The tag to claim (e.g. 'foobar')
     * @param recipient The address that will receive this guild tag (usually same as the caller)
     * @param extraClaimArgs [Optional] Any additional arguments necessary for guild-specific logic,
     *  such as authorization
     */
    function claimGuildTag(
        string calldata guildEnsName,
        string calldata tag,
        address recipient,
        bytes calldata extraClaimArgs
    ) external payable override {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        claimGuildTag(guildEnsNode, tag, recipient, extraClaimArgs);
    }

    function transferGuildTag(
        string calldata guildEnsName,
        string calldata tag,
        address recipient,
        bytes calldata extraTransferArgs
    ) external override {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        transferGuildTag(guildEnsNode, tag, recipient, extraTransferArgs);
    }

    /**
     * @notice Attempts to revoke an existing guild tag, if authorized by the guild's AuthPolicy.
     * Deregistered guilds will bypass auth checks for revocation of all tags.
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     * @param tag The tag to revoke (e.g. 'foobar')
     * @param extraData [Optional] Any additional arguments necessary for assessing whether a tag may be revoked
     */
    function revokeGuildTag(
        string calldata guildEnsName,
        string calldata tag,
        bytes calldata extraData
    ) external override {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        revokeGuildTag(guildEnsNode, tag, extraData);
    }

    /**
     * @notice Returns the current owner of the given guild tag.
     * Returns address(0) if no such guild or tag exists, or if the guild has been deregistered.
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     * @param tag The tag (e.g. 'foobar')
     */
    function tagOwner(string memory guildEnsName, string memory tag) external view override returns (address) {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        bytes32 tagHash = keccak256(bytes(tag));
        return tagOwner(guildEnsNode, tagHash);
    }

    /**
     * @notice Updates the FeePolicy for an existing guild. May only be called by the guild's registered admin.
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     * @param feePolicy The address of an implementation of FeePolicy to use for minting new tags within this guild
     */
    function updateGuildFeePolicy(string calldata guildEnsName, address feePolicy) external override {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        updateGuildFeePolicy(guildEnsNode, feePolicy);
    }

    /**
     * @notice Updates the TagsAuthPolicy for an existing guild. May only be called by the guild's registered admin.
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     * @param tagsAuthPolicy The address of an implementation of TagsAuthPolicy to use for
     * minting new tags within this guild
     */
    function updateGuildTagsAuthPolicy(string calldata guildEnsName, address tagsAuthPolicy) external override {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        updateGuildTagsAuthPolicy(guildEnsNode, tagsAuthPolicy);
    }

    /**
     * @notice Sets the metadata URI template string for fetching metadata for a guild's tag NFTs.
     * May only be called by the guild's registered admin.
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     * @param uri The ERC1155 metadata URL template
     */
    function setGuildTokenUri(string calldata guildEnsName, string calldata uri) external override {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        setGuildTokenUri(guildEnsNode, uri);
    }

    /**
     * @notice Sets a guild as active or inactive. May only be called by the guild's registered admin.
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     * @param active The new status
     */
    function setGuildActive(string calldata guildEnsName, bool active) external override {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        setGuildActive(guildEnsNode, active);
    }

    /**
     * @notice Returns the current admin registered for the given guild.
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     */
    function guildAdmin(string memory guildEnsName) external view override returns (address) {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        return guildAdmin(guildEnsNode);
    }

    /**
     * @notice Transfers the role of guild admin to the given address.
     * May only be called by the guild's registered admin.
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     * @param newAdmin The new admin
     */
    function transferGuildAdmin(string calldata guildEnsName, address newAdmin) external override {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        transferGuildAdmin(guildEnsNode, newAdmin);
    }

    /**
     * @notice Registers a resolver for the guild's root ENS name that will
     * answer queries about the parent name itself, or any child names that are
     * not Guild tags
     * @param guildEnsName The guild's full domain name (e.g. 'my-guild.eth')
     * @param fallbackResolver The fallback resolver
     */
    function setFallbackResolver(string calldata guildEnsName, address fallbackResolver) external override {
        bytes32 guildEnsNode = bytes(guildEnsName).namehash();
        setFallbackResolver(guildEnsNode, fallbackResolver);
    }

    // Original versions

    function deregisterGuild(bytes32) public virtual;

    function claimGuildTag(bytes32, string calldata, address, bytes calldata) public payable virtual;

    function transferGuildTag(bytes32, string calldata, address, bytes calldata) public virtual;

    function revokeGuildTag(bytes32, string calldata, bytes calldata) public virtual;

    function tagOwner(bytes32, bytes32) public view virtual returns (address);

    function updateGuildFeePolicy(bytes32, address) public virtual;

    function updateGuildTagsAuthPolicy(bytes32, address) public virtual;

    function setGuildTokenUri(bytes32, string calldata) public virtual;

    function setGuildActive(bytes32, bool) public virtual;

    function guildAdmin(bytes32) public view virtual returns (address);

    function transferGuildAdmin(bytes32, address) public virtual;

    function setFallbackResolver(bytes32 guildEnsNode, address fallbackResolver) public virtual;
}


// File: contracts/ensGuilds/mixins/GuildTagTokens.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

abstract contract GuildTagTokens is ERC1155 {
    error GuildsTokenTransferNotAllowed();

    struct GuildTokenInfo {
        string metadataUri;
    }

    // maps each guild's GuildID (ensNode) to its metadataURI
    mapping(bytes32 => GuildTokenInfo) private guilds;

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155) returns (bool) {
        return ERC1155.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     * @param tokenId The token whose URI is returned
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        // return guild-specific URI if exists
        string storage guildMetadataURI = guilds[bytes32(tokenId)].metadataUri;
        if (bytes(guildMetadataURI).length != 0) {
            return guildMetadataURI;
        }

        // return default URI shared by all guilds
        return ERC1155.uri(tokenId);
    }

    function _mintNewGuildToken(bytes32 guildHash, address to) internal {
        _mint(to, uint256(guildHash), 1, "");
    }

    function _burnGuildToken(bytes32 guildHash, address tagOwner) internal {
        _burn(tagOwner, uint256(guildHash), 1);
    }

    function _transferGuildToken(bytes32 guildHash, address from, address to) internal {
        _safeTransferFrom(from, to, uint256(guildHash), 1, "");
    }

    function _setGuildTokenURI(bytes32 guildHash, string calldata metadataURI) internal {
        guilds[guildHash].metadataUri = metadataURI;
    }

    /**
     * @dev ENSGuilds NFTs are non-transferrable and may only be directly minted and burned
     * with their corresponding guild tags.
     */
    function safeTransferFrom(address, address, uint256, uint256, bytes memory) public virtual override {
        revert GuildsTokenTransferNotAllowed();
    }
}


// File: contracts/ensWildcardResolvers/IPublicResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IABIResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IABIResolver.sol";
import { IAddrResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddrResolver.sol";
import { IAddressResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddressResolver.sol";
import { IContentHashResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IContentHashResolver.sol";
import { IDNSRecordResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IDNSRecordResolver.sol";
import { IDNSZoneResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IDNSZoneResolver.sol";
import { IInterfaceResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IInterfaceResolver.sol";
import { INameResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/INameResolver.sol";
import { IPubkeyResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IPubkeyResolver.sol";
import { ITextResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";

interface IPublicResolver is
    IABIResolver,
    IAddrResolver,
    IAddressResolver,
    IContentHashResolver,
    IDNSRecordResolver,
    IDNSZoneResolver,
    IInterfaceResolver,
    INameResolver,
    IPubkeyResolver,
    ITextResolver
{
    function setABI(bytes32 node, uint256 contentType, bytes calldata data) external;

    function setAddr(bytes32 node, address a) external;

    function setAddr(bytes32 node, uint256 coinType, bytes memory a) external;

    function setContenthash(bytes32 node, bytes calldata hash) external;

    function setDNSRecords(bytes32 node, bytes calldata data) external;

    function setZonehash(bytes32 node, bytes calldata hash) external;

    function setInterface(bytes32 node, bytes4 interfaceID, address implementer) external;

    function setName(bytes32 node, string calldata newName) external;

    function setPubkey(bytes32 node, bytes32 x, bytes32 y) external;

    function setText(bytes32 node, string calldata key, string calldata value) external;
}


// File: contracts/ensWildcardResolvers/PassthroughResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ResolverBase } from "@ensdomains/ens-contracts/contracts/resolvers/ResolverBase.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {
    IPublicResolver,
    IABIResolver,
    IAddrResolver,
    IAddressResolver,
    IContentHashResolver,
    IDNSRecordResolver,
    IDNSZoneResolver,
    IInterfaceResolver,
    INameResolver,
    IPubkeyResolver,
    ITextResolver
} from "./IPublicResolver.sol";

/**
 * @dev PassthroughResolver is an ENS Resolver that forwards all calls to a
 * fallback Resolver. A custom resolver may inherit this contract
 * to selectively implement specific record types, deferring all others to the
 * fallback Resolver (usually whatever public Resolver the ENS app set on behalf
 * of the user when a name was registered).
 *
 * The owner of the ENS name must first configure their PublicResolver to approve
 * this contract as an authorized manager on the owner's behalf for the setter
 * methods of PassthroughResolver to work. Note that this delegation is separate
 * from approvals set with the ENS Registry. ENS's public Registry and its public
 * Resolvers each have their own, independent concepts of approved managers.
 */
abstract contract PassthroughResolver is IPublicResolver, ResolverBase {
    using ERC165Checker for address;

    mapping(bytes32 => address) private _passthroughTargets;

    function isAuthorised(bytes32) internal view virtual override returns (bool);

    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return
            interfaceID == type(IABIResolver).interfaceId ||
            interfaceID == type(IAddrResolver).interfaceId ||
            interfaceID == type(IAddressResolver).interfaceId ||
            interfaceID == type(IContentHashResolver).interfaceId ||
            interfaceID == type(IDNSRecordResolver).interfaceId ||
            interfaceID == type(IDNSZoneResolver).interfaceId ||
            interfaceID == type(IInterfaceResolver).interfaceId ||
            interfaceID == type(INameResolver).interfaceId ||
            interfaceID == type(IPubkeyResolver).interfaceId ||
            interfaceID == type(ITextResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }

    function getPassthroughTarget(bytes32 node) public view virtual returns (address resolver) {
        return _passthroughTargets[node];
    }

    function _setPassthroughTarget(bytes32 node, address target) internal {
        _passthroughTargets[node] = target;
    }

    function setABI(bytes32 node, uint256 contentType, bytes calldata data) external virtual authorised(node) {
        IPublicResolver(getPassthroughTarget(node)).setABI(node, contentType, data);
    }

    // solhint-disable-next-line func-name-mixedcase
    function ABI(
        bytes32 node,
        uint256 contentTypes
    ) external view virtual override returns (uint256 a, bytes memory b) {
        address target = getPassthroughTarget(node);
        if (target.supportsInterface(type(IABIResolver).interfaceId)) {
            return IABIResolver(target).ABI(node, contentTypes);
        }
    }

    function setAddr(bytes32 node, address a) external virtual authorised(node) {
        IPublicResolver(getPassthroughTarget(node)).setAddr(node, a);
    }

    function addr(bytes32 node) public view virtual override returns (address payable result) {
        address target = getPassthroughTarget(node);
        if (target.supportsInterface(type(IAddrResolver).interfaceId)) {
            return IAddrResolver(target).addr(node);
        }
    }

    function setAddr(bytes32 node, uint256 coinType, bytes memory a) public virtual authorised(node) {
        IPublicResolver(getPassthroughTarget(node)).setAddr(node, coinType, a);
    }

    function addr(bytes32 node, uint256 coinType) public view virtual override returns (bytes memory result) {
        address target = getPassthroughTarget(node);
        if (target.supportsInterface(type(IAddressResolver).interfaceId)) {
            return IAddressResolver(target).addr(node, coinType);
        }
    }

    function setContenthash(bytes32 node, bytes calldata hash) external virtual authorised(node) {
        IPublicResolver(getPassthroughTarget(node)).setContenthash(node, hash);
    }

    function contenthash(bytes32 node) external view virtual override returns (bytes memory result) {
        address target = getPassthroughTarget(node);
        if (target.supportsInterface(type(IContentHashResolver).interfaceId)) {
            return IContentHashResolver(target).contenthash(node);
        }
    }

    function setDNSRecords(bytes32 node, bytes calldata data) external virtual authorised(node) {
        IPublicResolver(getPassthroughTarget(node)).setDNSRecords(node, data);
    }

    function dnsRecord(
        bytes32 node,
        bytes32 name, // solhint-disable-line
        uint16 resource
    ) public view virtual override returns (bytes memory result) {
        address target = getPassthroughTarget(node);
        if (target.supportsInterface(type(IDNSRecordResolver).interfaceId)) {
            return IDNSRecordResolver(target).dnsRecord(node, name, resource);
        }
    }

    function setZonehash(bytes32 node, bytes calldata hash) external virtual authorised(node) {
        IPublicResolver(getPassthroughTarget(node)).setZonehash(node, hash);
    }

    function zonehash(bytes32 node) external view virtual override returns (bytes memory result) {
        address target = getPassthroughTarget(node);
        if (target.supportsInterface(type(IDNSZoneResolver).interfaceId)) {
            return IDNSZoneResolver(target).zonehash(node);
        }
    }

    function setInterface(bytes32 node, bytes4 interfaceID, address implementer) external virtual authorised(node) {
        IPublicResolver(getPassthroughTarget(node)).setInterface(node, interfaceID, implementer);
    }

    function interfaceImplementer(
        bytes32 node,
        bytes4 interfaceID
    ) external view virtual override returns (address result) {
        address target = getPassthroughTarget(node);
        if (target.supportsInterface(type(IInterfaceResolver).interfaceId)) {
            return IInterfaceResolver(target).interfaceImplementer(node, interfaceID);
        }
    }

    function setName(bytes32 node, string calldata newName) external virtual authorised(node) {
        IPublicResolver(getPassthroughTarget(node)).setName(node, newName);
    }

    function name(bytes32 node) external view virtual override returns (string memory result) {
        address target = getPassthroughTarget(node);
        if (target.supportsInterface(type(INameResolver).interfaceId)) {
            return INameResolver(target).name(node);
        }
    }

    function setPubkey(bytes32 node, bytes32 x, bytes32 y) external virtual authorised(node) {
        IPublicResolver(getPassthroughTarget(node)).setPubkey(node, x, y);
    }

    function pubkey(bytes32 node) external view virtual override returns (bytes32 x, bytes32 y) {
        address target = getPassthroughTarget(node);
        if (target.supportsInterface(type(IPubkeyResolver).interfaceId)) {
            return IPubkeyResolver(target).pubkey(node);
        }
    }

    function setText(bytes32 node, string calldata key, string calldata value) external virtual authorised(node) {
        IPublicResolver(getPassthroughTarget(node)).setText(node, key, value);
    }

    function text(bytes32 node, string calldata key) public view virtual override returns (string memory result) {
        address target = getPassthroughTarget(node);
        if (target.supportsInterface(type(ITextResolver).interfaceId)) {
            return ITextResolver(target).text(node, key);
        }
    }
}


// File: contracts/ensWildcardResolvers/WildcardResolverBase.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ENS } from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import { INameWrapper } from "@ensdomains/ens-contracts/contracts/wrapper/INameWrapper.sol";
import { IExtendedResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

import { ENSParentName } from "../libraries/ENSParentName.sol";
import { ENSByteUtils } from "../libraries/ENSByteUtils.sol";
import { BytesLib } from "../libraries/BytesLib.sol";

import { PassthroughResolver } from "./PassthroughResolver.sol";

abstract contract WildcardResolverBase is IExtendedResolver, Context, PassthroughResolver {
    using ENSByteUtils for address;
    using ENSByteUtils for bytes;
    using ENSParentName for bytes;
    using ERC165Checker for address;

    error RecordTypeNotSupported();
    error InvalidOperation();
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    bytes4 public constant RESOLVER_SIGNATURE__ADDR = bytes4(keccak256(bytes("addr(bytes32)")));
    bytes4 public constant RESOLVER_SIGNATURE__ADDR_WITH_COINTYPE = bytes4(keccak256(bytes("addr(bytes32,uint256)")));
    bytes4 public constant RESOLVER_SIGNATURE__TEXT = bytes4(keccak256(bytes("text(bytes32,string)")));
    uint256 private constant COIN_TYPE_ETH = 60;

    ENS public immutable ensRegistry;
    INameWrapper public immutable ensNameWrapper;

    // dnsEncode(parentName) -> namehash(parentName)
    // ex: "test.eth" would be mapped as
    // 0x04746573740365746800 -> 0xeb4f647bea6caa36333c816d7b46fdcb05f9466ecacc140ea8c66faf15b3d9f1
    mapping(bytes => bytes32) internal parentEnsNodes;

    constructor(ENS _ensRegistry, INameWrapper _ensNameWrapper) {
        ensRegistry = _ensRegistry;
        ensNameWrapper = _ensNameWrapper;
    }

    function resolve(
        bytes calldata dnsEncodedName,
        bytes calldata resolverCalldata
    ) public view virtual override returns (bytes memory) {
        bytes4 resolverSignature = bytes4(resolverCalldata[:4]);

        if (resolverSignature == RESOLVER_SIGNATURE__ADDR) {
            address ethAddr = _resolveEthAddr(dnsEncodedName, resolverCalldata);
            return abi.encode(ethAddr);
        } else if (resolverSignature == RESOLVER_SIGNATURE__ADDR_WITH_COINTYPE) {
            (, uint256 coinType) = abi.decode(resolverCalldata[4:], (bytes32, uint256));
            if (coinType == COIN_TYPE_ETH) {
                address ethAddr = _resolveEthAddr(dnsEncodedName, resolverCalldata);
                return abi.encode(ethAddr.toBytes());
            } else {
                // Unsupported COIN_TYPE
                bytes memory emptyBytes;
                return abi.encode(emptyBytes);
            }
        } else if (resolverSignature == RESOLVER_SIGNATURE__TEXT) {
            string calldata key = _parseKeyFromCalldata(resolverCalldata);
            string memory result = _resolveTextRecord(dnsEncodedName, key, resolverCalldata);
            return abi.encode(result);
        }

        revert RecordTypeNotSupported();
    }

    function supportsInterface(bytes4 interfaceID) public view virtual override(PassthroughResolver) returns (bool) {
        return interfaceID == type(IExtendedResolver).interfaceId || PassthroughResolver.supportsInterface(interfaceID);
    }

    function _resolveWildcardEthAddr(
        bytes calldata childUtf8Encoded,
        bytes calldata parentDnsEncoded
    ) internal view virtual returns (address);

    function _resolveWildcardTextRecord(
        bytes calldata childUtf8Encoded,
        bytes calldata parentDnsEncoded,
        string calldata key
    ) internal view virtual returns (string memory);

    function _resolveEthAddr(
        bytes calldata dnsEncodedName,
        bytes calldata resolverCalldata
    ) private view returns (address result) {
        // Check if the caller is asking for a record on the parent name itself (non-wildcard query)
        (bool isParentName, bytes32 ensNode) = _isParentName(dnsEncodedName);

        if (isParentName) {
            // Try to resolve the parent name using the two `addr()` resolver variants
            result = addr(ensNode);
            if (result == address(0)) {
                bytes memory addrBytes = addr(ensNode, COIN_TYPE_ETH);
                if (addrBytes.length != 0) {
                    result = addrBytes.toAddress();
                }
            }
        } else {
            // Caller has issued a wildcard query. Defer to the concrete implementation of this contract
            (bytes calldata childUtf8Encoded, bytes calldata parentDnsEncoded) = dnsEncodedName.splitParentChildNames();
            ensNode = parentEnsNodes[parentDnsEncoded];
            result = _resolveWildcardEthAddr(childUtf8Encoded, parentDnsEncoded);
        }

        // No luck. If our fallback resolver also happens to implement the `resolve()` wildcard standard then we can try
        // that as a final option
        address passthrough = getPassthroughTarget(ensNode);
        if (result == address(0) && passthrough.supportsInterface(type(IExtendedResolver).interfaceId)) {
            try IExtendedResolver(passthrough).resolve(dnsEncodedName, resolverCalldata) returns (
                bytes memory encodedResult
            ) {
                (result) = abi.decode(encodedResult, (address));
                // Catch OffchainLookup and override sender param
            } catch (bytes memory err) {
                // The first 4 bytes of the ABI encoded error represent the error's signature
                // Slice those 4 bytes and get the data from the OffchainLookup error
                (
                    address sender,
                    string[] memory urls,
                    bytes memory callData,
                    bytes4 callbackFunction,
                    bytes memory extraData
                ) = abi.decode(BytesLib.slice(err, 4, err.length - 4), (address, string[], bytes, bytes4, bytes));
                revert OffchainLookup(
                    address(this),
                    urls,
                    callData,
                    this.resolveCallback.selector,
                    abi.encode(sender, callbackFunction, extraData)
                );
            }
        }
    }

    // Callback to contract that initially reverted OffchainLookup
    function resolveCallback(bytes calldata response, bytes calldata extraData) public returns (bytes memory) {
        (address inner, bytes4 innerCallbackFunction, bytes memory innerExtraData) = abi.decode(
            extraData,
            (address, bytes4, bytes)
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = inner.call(
            abi.encodeWithSelector(innerCallbackFunction, response, innerExtraData)
        );
        if (success) {
            return abi.decode(data, (bytes));
        }
        revert InvalidOperation();
    }

    function _resolveTextRecord(
        bytes calldata dnsEncodedName,
        string calldata key,
        bytes calldata resolverCalldata
    ) private view returns (string memory result) {
        // Check if the caller is asking for a record on the parent name itself (non-wildcard query)
        (bool isParentName, bytes32 ensNode) = _isParentName(dnsEncodedName);
        if (isParentName) {
            result = text(ensNode, key);
        } else {
            // Caller has issued a wildcard query. Defer to the concrete implementation of this contract
            (bytes calldata childUtf8Encoded, bytes calldata parentDnsEncoded) = dnsEncodedName.splitParentChildNames();
            ensNode = parentEnsNodes[parentDnsEncoded];
            result = _resolveWildcardTextRecord(childUtf8Encoded, parentDnsEncoded, key);
        }

        // No luck. If our fallback resolver also happens to implement the `resolve()` wildcard standard then we can try
        // that as a final option
        address passthrough = getPassthroughTarget(ensNode);
        if (bytes(result).length == 0 && passthrough.supportsInterface(type(IExtendedResolver).interfaceId)) {
            try IExtendedResolver(passthrough).resolve(dnsEncodedName, resolverCalldata) returns (
                bytes memory encodedResult
            ) {
                (result) = abi.decode(encodedResult, (string));
                // Catch OffchainLookup and override sender param
            } catch (bytes memory err) {
                // The first 4 bytes of the ABI encoded error represent the error's signature
                // Slice those 4 bytes and get the data from the OffchainLookup error
                (
                    address sender,
                    string[] memory urls,
                    bytes memory callData,
                    bytes4 callbackFunction,
                    bytes memory extraData
                ) = abi.decode(BytesLib.slice(err, 4, err.length - 4), (address, string[], bytes, bytes4, bytes));
                revert OffchainLookup(
                    address(this),
                    urls,
                    callData,
                    this.resolveCallback.selector,
                    abi.encode(sender, callbackFunction, extraData)
                );
            }
        }
    }

    function _parseKeyFromCalldata(bytes calldata resolverCalldata) private pure returns (string calldata key) {
        // ENS resolvers expect that the `key` for text queries is passed in via calldata.
        //
        // Until this is implemented in Solidity, we have to hand-pick the string out
        // of the calldata ourself: https://github.com/ethereum/solidity/issues/13518
        //
        // Here's the cleaner version once the above is implemented:
        //    (, string calldata key) = abi.decode(resolverCalldata[4:], (bytes32, string calldata));
        //
        // Reminder: the text resolver signature is `text(bytes32 ensNode, string [calldata] key)`
        //
        // Offset math:
        //    - 4 bytes for the function selector for `text(bytes32,string)`
        //    - 32 bytes for the `ensNode` as bytes32
        //    - 32 bytes to encode the offset to start of data part of the dynamic string parameter
        //         (see https://docs.soliditylang.org/en/v0.8.20/abi-spec.html#use-of-dynamic-types)
        //    - 32 bytes for the string's length: uint256(len(bytes(key_as_utf8_string)))
        //    - Remainder is the UTF8 encoding of the key, right-padded to a multiple of 32 bytes
        uint256 keyLengthOffset = 4 + 32 + 32;
        uint256 keyOffset = keyLengthOffset + 32;

        uint256 keyLength = abi.decode(resolverCalldata[keyLengthOffset:], (uint256));

        key = string(resolverCalldata[keyOffset:keyOffset + keyLength]);
    }

    function _isParentName(bytes calldata dnsEncodedName) internal view returns (bool, bytes32 ensNode) {
        ensNode = parentEnsNodes[dnsEncodedName];
        return (ensNode != bytes32(0), ensNode);
    }

    function _nodeOwner(bytes32 node) internal view returns (address) {
        address owner = ensRegistry.owner(node);
        if (owner == address(ensNameWrapper)) {
            owner = ensNameWrapper.ownerOf(uint256(node));
        }
        return owner;
    }
}


// File: contracts/feePolicies/IFeePolicy.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IFeePolicy
 * @notice An interface for Guilds to implement that will specify how fees must be paid for guild tag mints
 */
interface IFeePolicy is IERC165 {
    /**
     * @notice Returns the fee required to mint the given guild tag by the given minter
     * @param guildHash The ENS namehash of the guild's domain
     * @param tag The tag being claimed (e.g. 'foo' for foo.my-guild.eth)
     * @param claimant The address attempting to claim the tag (not necessarily the address that will receive it)
     * @param extraClaimArgs Any additional arguments that would be passed by the minter to the claimGuildTag() function
     * @return tokenContract The token contract the fee must be paid in (if any). Address(0) designates native Ether.
     * @return fee The amount (in base unit) that must be paid
     * @return feePaidTo The address that should receive payment of the fee
     */
    function tagClaimFee(
        bytes32 guildHash,
        string calldata tag,
        address claimant,
        bytes calldata extraClaimArgs
    ) external view returns (address tokenContract, uint256 fee, address feePaidTo);
}


// File: contracts/libraries/BytesLib.sol
// SPDX-License-Identifier: MIT
// https://gist.github.com/rmeissner/76d6345796909ee41fb9f36fdaa4d15f

pragma solidity ^0.8.4;

library BytesLib {
    function slice(bytes memory _bytes, uint256 _start, uint256 _length) internal pure returns (bytes memory) {
        require(_length + 31 >= _length, "slice_overflow"); // solhint-disable-line custom-errors
        require(_bytes.length >= _start + _length, "slice_outOfBounds"); // solhint-disable-line custom-errors

        bytes memory tempBytes;

        // Check length is 0. `iszero` return 1 for `true` and 0 for `false`.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // Calculate length mod 32 to handle slices that are not a multiple of 32 in size.
                let lengthmod := and(_length, 31)

                // tempBytes will have the following format in memory: <length><data>
                // When copying data we will offset the start forward to avoid allocating additional memory
                // Therefore part of the length area will be written, but this will be overwritten later anyways.
                // In case no offset is require, the start is set to the data region (0x20 from the tempBytes)
                // mc will be used to keep track where to copy the data to.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // Same logic as for mc is applied & additionally the start offset specified for the method is added
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    // increase `mc` and `cc` to read the next word from memory
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    // Copy the data from source (cc location) to the slice data (mc location)
                    mstore(mc, mload(cc))
                }

                // Store the length of the slice. This will overwrite any partial data that
                // was copied when having slices that are not a multiple of 32.
                mstore(tempBytes, _length)

                // update free-memory pointer
                // allocating the array padded to 32 bytes like the compiler does now
                // To set the used memory as a multiple of 32, add 31 to the actual memory usage (mc)
                // and remove the modulo 32 (the `and` with `not(31)`)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            // if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                // zero out the 32 bytes slice we are about to return
                // we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                // update free-memory pointer
                // tempBytes uses 32 bytes in memory (even when empty) for the length.
                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }
}


// File: contracts/libraries/ENSByteUtils.sol
// SPDX-License-Identifier: MIT

// solhint-disable-next-line max-line-length
// Source: https://github.com/ensdomains/ens-contracts/blob/340a6d05cd00d078ae40edbc58c139eb7048189a/contracts/resolvers/profiles/AddrResolver.sol

pragma solidity ^0.8.4;

/*
 * @dev Converts addresses to and from their byte-string representations
 */
library ENSByteUtils {
    // solhint-disable
    function toAddress(bytes memory b) internal pure returns (address payable a) {
        require(b.length == 20);
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12)) // cspell:disable-line
        }
    }

    function toBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12))) // cspell:disable-line
        }
    }
    // solhint-enable
}


// File: contracts/libraries/ENSNamehash.sol
// SPDX-License-Identifier: MIT
// Source: https://github.com/JonahGroendal/ens-namehash/blob/master/contracts/ENSNamehash.sol

pragma solidity ^0.8.4;

/*
 * @dev Solidity implementation of the ENS namehash algorithm.
 *
 * Warning! Does not normalize or validate names before hashing.
 */
library ENSNamehash {
    function namehash(bytes memory domain) internal pure returns (bytes32) {
        return namehash(domain, 0);
    }

    function namehash(bytes memory domain, uint i) internal pure returns (bytes32) {
        if (domain.length <= i) return 0x0000000000000000000000000000000000000000000000000000000000000000;

        uint len = LabelLength(domain, i);

        return keccak256(abi.encodePacked(namehash(domain, i + len + 1), keccak(domain, i, len)));
    }

    function LabelLength(bytes memory domain, uint i) private pure returns (uint) {
        uint len;
        while (i + len != domain.length && domain[i + len] != 0x2e) {
            len++;
        }
        return len;
    }

    function keccak(bytes memory data, uint offset, uint len) private pure returns (bytes32 ret) {
        require(offset + len <= data.length);
        assembly {
            ret := keccak256(add(add(data, 32), offset), len)
        }
    }
}


// File: contracts/libraries/ENSParentName.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

library ENSParentName {
    /**
     * @dev Finds the parent name of a given ENS name, or the empty string if there is no parent.
     *      Assumes the given name is already a well-formed ENS name, and does not check for invalid input.
     * @param name A DNS-encoded name, e.g. 0x03666f6f03626172047465737400 for the name `foo.bar.test`
     * @return child The UTF8-encoded child label, e.g. 0x666f6f for `foo`
     * @return parent The DNS-encoded parent, e.g. 03626172047465737400 for `bar.test`
     */
    function splitParentChildNames(
        bytes calldata name
    ) internal pure returns (bytes calldata child, bytes calldata parent) {
        uint8 labelLength = uint8(name[0]);
        return (name[1:labelLength + 1], name[labelLength + 1:]);
    }
}


// File: contracts/tagsAuthPolicies/ITagsAuthPolicy.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title TagsAuthPolicy
 * @notice An interface for Guilds to implement that will control authorization for minting tags within that guild
 */
interface ITagsAuthPolicy is IERC165 {
    /**
     * @notice Checks whether a certain address (claimant) may claim a given guild tag that has been revoked or
     * has never been claimed
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tag The tag being claimed (e.g. 'foo' for foo.my-guild.eth)
     * @param claimant The address attempting to claim the tag (not necessarily the address that will receive it)
     * @param recipient The address that would receive the tag
     * @param extraClaimArgs [Optional] Any guild-specific additional arguments required
     */
    function canClaimTag(
        bytes32 guildEnsNode,
        string calldata tag,
        address claimant,
        address recipient,
        bytes calldata extraClaimArgs
    ) external view returns (bool);

    /**
     * @dev Called by ENSGuilds once a tag has been claimed.
     * Provided for auth policies to update local state, such as erasing an address from an allowlist after that
     * address has successfully minted a tag.
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tag The tag being claimed (e.g. 'foo' for foo.my-guild.eth)
     * @param claimant The address that claimed the tag (not necessarily the address that received it)
     * @param recipient The address that received receive the tag
     * @param extraClaimArgs [Optional] Any guild-specific additional arguments required
     * @return tagToRevoke Any tag that should be revoked as a consequence of the given tag
     * being claimed. Returns empty string if no tag should be revoked.
     */
    function onTagClaimed(
        bytes32 guildEnsNode,
        string calldata tag,
        address claimant,
        address recipient,
        bytes calldata extraClaimArgs
    ) external returns (string memory tagToRevoke);

    /**
     * @notice Checks whether a given guild tag is eligible to be revoked
     * @param revokedBy The address that would attempt to revoke it
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tag The tag being revoked (e.g. 'foo' for foo.my-guild.eth)
     * @param extraRevokeArgs Any additional arguments necessary for assessing whether a tag may be revoked
     */
    function canRevokeTag(
        address revokedBy,
        bytes32 guildEnsNode,
        string calldata tag,
        bytes calldata extraRevokeArgs
    ) external view returns (bool);

    /**
     * @notice Called by ENSGuilds once a tag has been revoked.
     * @param revokedBy The address that revoked it
     * @param revokedFrom The address who owned it when it was revoked
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tag The tag being revoked (e.g. 'foo' for foo.my-guild.eth)
     */
    function onTagRevoked(address revokedBy, address revokedFrom, bytes32 guildEnsNode, string memory tag) external;

    /**
     * @notice Checks whether a tag can be transferred. Implementations may trust that `currentOwner` is the
     * owner of the given tag.
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tag The tag being revoked (e.g. 'foo' for foo.my-guild.eth)
     * @param transferredBy The address initiating the transfer. May be different than the currentOwner, such
     * as an admin or a marketplace contract
     * @param currentOwner The address currently owning the given tag
     * @param newOwner The address that would receive the tag
     * @param extraTransferArgs Any additional arguments necessary for assessing whether a tag may be transferred
     */
    function canTransferTag(
        bytes32 guildEnsNode,
        string calldata tag,
        address transferredBy,
        address currentOwner,
        address newOwner,
        bytes calldata extraTransferArgs
    ) external view returns (bool);

    /**
     * @notice Called by ENSGuilds once a tag has been transferred
     * @param guildEnsNode The ENS namehash of the guild's domain
     * @param tag The tag that was transferred
     * @param transferredBy The address initiating the transfer
     * @param prevOwner The address that previously owned the tag
     * @param newOwner The address that received the tag
     */
    function onTagTransferred(
        bytes32 guildEnsNode,
        string calldata tag,
        address transferredBy,
        address prevOwner,
        address newOwner
    ) external;
}


