// Chain: POLYGON - File: contracts/access/ownable/IOwnable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173 } from '../../interfaces/IERC173.sol';
import { IOwnableInternal } from './IOwnableInternal.sol';

interface IOwnable is IOwnableInternal, IERC173 {}


// Chain: POLYGON - File: contracts/access/ownable/IOwnableInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173Internal } from '../../interfaces/IERC173Internal.sol';

interface IOwnableInternal is IERC173Internal {
    error Ownable__NotOwner();
    error Ownable__NotTransitiveOwner();
}


// Chain: POLYGON - File: contracts/access/ownable/Ownable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173 } from '../../interfaces/IERC173.sol';
import { IOwnable } from './IOwnable.sol';
import { OwnableInternal } from './OwnableInternal.sol';

/**
 * @title Ownership access control based on ERC173
 */
abstract contract Ownable is IOwnable, OwnableInternal {
    /**
     * @inheritdoc IERC173
     */
    function owner() public view virtual returns (address) {
        return _owner();
    }

    /**
     * @inheritdoc IERC173
     */
    function transferOwnership(address account) public virtual onlyOwner {
        _transferOwnership(account);
    }
}


// Chain: POLYGON - File: contracts/access/ownable/OwnableInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173 } from '../../interfaces/IERC173.sol';
import { AddressUtils } from '../../utils/AddressUtils.sol';
import { IOwnableInternal } from './IOwnableInternal.sol';
import { OwnableStorage } from './OwnableStorage.sol';

abstract contract OwnableInternal is IOwnableInternal {
    using AddressUtils for address;

    modifier onlyOwner() {
        if (msg.sender != _owner()) revert Ownable__NotOwner();
        _;
    }

    modifier onlyTransitiveOwner() {
        if (msg.sender != _transitiveOwner())
            revert Ownable__NotTransitiveOwner();
        _;
    }

    function _owner() internal view virtual returns (address) {
        return OwnableStorage.layout().owner;
    }

    function _transitiveOwner() internal view virtual returns (address owner) {
        owner = _owner();

        while (owner.isContract()) {
            try IERC173(owner).owner() returns (address transitiveOwner) {
                owner = transitiveOwner;
            } catch {
                break;
            }
        }
    }

    function _transferOwnership(address account) internal virtual {
        _setOwner(account);
    }

    function _setOwner(address account) internal virtual {
        OwnableStorage.Layout storage l = OwnableStorage.layout();
        emit OwnershipTransferred(l.owner, account);
        l.owner = account;
    }
}


// Chain: POLYGON - File: contracts/access/ownable/OwnableStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

library OwnableStorage {
    struct Layout {
        address owner;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.Ownable');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: contracts/data/EnumerableSet.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Set implementation with enumeration functions
 * @dev derived from https://github.com/OpenZeppelin/openzeppelin-contracts (MIT license)
 */
library EnumerableSet {
    error EnumerableSet__IndexOutOfBounds();

    struct Set {
        bytes32[] _values;
        // 1-indexed to allow 0 to signify nonexistence
        mapping(bytes32 => uint256) _indexes;
    }

    struct Bytes32Set {
        Set _inner;
    }

    struct AddressSet {
        Set _inner;
    }

    struct UintSet {
        Set _inner;
    }

    function at(
        Bytes32Set storage set,
        uint256 index
    ) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    function at(
        AddressSet storage set,
        uint256 index
    ) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    function at(
        UintSet storage set,
        uint256 index
    ) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    function contains(
        Bytes32Set storage set,
        bytes32 value
    ) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    function contains(
        AddressSet storage set,
        address value
    ) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    function contains(
        UintSet storage set,
        uint256 value
    ) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    function indexOf(
        Bytes32Set storage set,
        bytes32 value
    ) internal view returns (uint256) {
        return _indexOf(set._inner, value);
    }

    function indexOf(
        AddressSet storage set,
        address value
    ) internal view returns (uint256) {
        return _indexOf(set._inner, bytes32(uint256(uint160(value))));
    }

    function indexOf(
        UintSet storage set,
        uint256 value
    ) internal view returns (uint256) {
        return _indexOf(set._inner, bytes32(value));
    }

    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    function add(
        Bytes32Set storage set,
        bytes32 value
    ) internal returns (bool) {
        return _add(set._inner, value);
    }

    function add(
        AddressSet storage set,
        address value
    ) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    function remove(
        Bytes32Set storage set,
        bytes32 value
    ) internal returns (bool) {
        return _remove(set._inner, value);
    }

    function remove(
        AddressSet storage set,
        address value
    ) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    function remove(
        UintSet storage set,
        uint256 value
    ) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    function toArray(
        Bytes32Set storage set
    ) internal view returns (bytes32[] memory) {
        return set._inner._values;
    }

    function toArray(
        AddressSet storage set
    ) internal view returns (address[] memory) {
        bytes32[] storage values = set._inner._values;
        address[] storage array;

        assembly {
            array.slot := values.slot
        }

        return array;
    }

    function toArray(
        UintSet storage set
    ) internal view returns (uint256[] memory) {
        bytes32[] storage values = set._inner._values;
        uint256[] storage array;

        assembly {
            array.slot := values.slot
        }

        return array;
    }

    function _at(
        Set storage set,
        uint256 index
    ) private view returns (bytes32) {
        if (index >= set._values.length)
            revert EnumerableSet__IndexOutOfBounds();
        return set._values[index];
    }

    function _contains(
        Set storage set,
        bytes32 value
    ) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    function _indexOf(
        Set storage set,
        bytes32 value
    ) private view returns (uint256) {
        unchecked {
            return set._indexes[value] - 1;
        }
    }

    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    function _add(
        Set storage set,
        bytes32 value
    ) private returns (bool status) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            status = true;
        }
    }

    function _remove(
        Set storage set,
        bytes32 value
    ) private returns (bool status) {
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            unchecked {
                bytes32 last = set._values[set._values.length - 1];

                // move last value to now-vacant index

                set._values[valueIndex - 1] = last;
                set._indexes[last] = valueIndex;
            }
            // clear last index

            set._values.pop();
            delete set._indexes[value];

            status = true;
        }
    }
}


// Chain: POLYGON - File: contracts/interfaces/IERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165 } from './IERC165.sol';
import { IERC1155Internal } from './IERC1155Internal.sol';

/**
 * @title ERC1155 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-1155
 */
interface IERC1155 is IERC1155Internal, IERC165 {
    /**
     * @notice query the balance of given token held by given address
     * @param account address to query
     * @param id token to query
     * @return token balance
     */
    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);

    /**
     * @notice query the balances of given tokens held by given addresses
     * @param accounts addresss to query
     * @param ids tokens to query
     * @return token balances
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    /**
     * @notice query approval status of given operator with respect to given address
     * @param account address to query for approval granted
     * @param operator address to query for approval received
     * @return whether operator is approved to spend tokens held by account
     */
    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool);

    /**
     * @notice grant approval to or revoke approval from given operator to spend held tokens
     * @param operator address whose approval status to update
     * @param status whether operator should be considered approved
     */
    function setApprovalForAll(address operator, bool status) external;

    /**
     * @notice transfer tokens between given addresses, checking for ERC1155Receiver implementation if applicable
     * @param from sender of tokens
     * @param to receiver of tokens
     * @param id token ID
     * @param amount quantity of tokens to transfer
     * @param data data payload
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @notice transfer batch of tokens between given addresses, checking for ERC1155Receiver implementation if applicable
     * @param from sender of tokens
     * @param to receiver of tokens
     * @param ids list of token IDs
     * @param amounts list of quantities of tokens to transfer
     * @param data data payload
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// Chain: POLYGON - File: contracts/interfaces/IERC1155Internal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC1155 interface needed by internal functions
 */
interface IERC1155Internal {
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );
}


// Chain: POLYGON - File: contracts/interfaces/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165 } from './IERC165.sol';

/**
 * @title ERC1155 transfer receiver interface
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @notice validate receipt of ERC1155 transfer
     * @param operator executor of transfer
     * @param from sender of tokens
     * @param id token ID received
     * @param value quantity of tokens received
     * @param data data payload
     * @return function's own selector if transfer is accepted
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @notice validate receipt of ERC1155 batch transfer
     * @param operator executor of transfer
     * @param from sender of tokens
     * @param ids token IDs received
     * @param values quantities of tokens received
     * @param data data payload
     * @return function's own selector if transfer is accepted
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}


// Chain: POLYGON - File: contracts/interfaces/IERC165.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165Internal } from './IERC165Internal.sol';

/**
 * @title ERC165 interface registration interface
 * @dev see https://eips.ethereum.org/EIPS/eip-165
 */
interface IERC165 is IERC165Internal {
    /**
     * @notice query whether contract has registered support for given interface
     * @param interfaceId interface id
     * @return bool whether interface is supported
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// Chain: POLYGON - File: contracts/interfaces/IERC165Internal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title ERC165 interface registration interface
 */
interface IERC165Internal {

}


// Chain: POLYGON - File: contracts/interfaces/IERC173.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173Internal } from './IERC173Internal.sol';

/**
 * @title Contract ownership standard interface
 * @dev see https://eips.ethereum.org/EIPS/eip-173
 */
interface IERC173 is IERC173Internal {
    /**
     * @notice get the ERC173 contract owner
     * @return contract owner
     */
    function owner() external view returns (address);

    /**
     * @notice transfer contract ownership to new account
     * @param account address of new owner
     */
    function transferOwnership(address account) external;
}


// Chain: POLYGON - File: contracts/interfaces/IERC173Internal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC173 interface needed by internal functions
 */
interface IERC173Internal {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}


// Chain: POLYGON - File: contracts/interfaces/IERC2981.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165 } from './IERC165.sol';
import { IERC2981Internal } from './IERC2981Internal.sol';

/**
 * @title ERC2981 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-2981
 */
interface IERC2981 is IERC2981Internal, IERC165 {
    /**
     * @notice called with the sale price to determine how much royalty is owed and to whom
     * @param tokenId the ERC721 or ERC1155 token id to query for royalty information
     * @param salePrice the sale price of the given asset
     * @return receiever rightful recipient of royalty
     * @return royaltyAmount amount of royalty owed
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiever, uint256 royaltyAmount);
}


// Chain: POLYGON - File: contracts/interfaces/IERC2981Internal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title ERC2981 interface
 */
interface IERC2981Internal {

}


// Chain: POLYGON - File: contracts/introspection/ERC165/base/ERC165Base.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165 } from '../../../interfaces/IERC165.sol';
import { IERC165Base } from './IERC165Base.sol';
import { ERC165BaseInternal } from './ERC165BaseInternal.sol';
import { ERC165BaseStorage } from './ERC165BaseStorage.sol';

/**
 * @title ERC165 implementation
 */
abstract contract ERC165Base is IERC165Base, ERC165BaseInternal {
    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return _supportsInterface(interfaceId);
    }
}


// Chain: POLYGON - File: contracts/introspection/ERC165/base/ERC165BaseInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165BaseInternal } from './IERC165BaseInternal.sol';
import { ERC165BaseStorage } from './ERC165BaseStorage.sol';

/**
 * @title ERC165 implementation
 */
abstract contract ERC165BaseInternal is IERC165BaseInternal {
    /**
     * @notice indicates whether an interface is already supported based on the interfaceId
     * @param interfaceId id of interface to check
     * @return bool indicating whether interface is supported
     */
    function _supportsInterface(
        bytes4 interfaceId
    ) internal view virtual returns (bool) {
        return ERC165BaseStorage.layout().supportedInterfaces[interfaceId];
    }

    /**
     * @notice sets status of interface support
     * @param interfaceId id of interface to set status for
     * @param status boolean indicating whether interface will be set as supported
     */
    function _setSupportsInterface(
        bytes4 interfaceId,
        bool status
    ) internal virtual {
        if (interfaceId == 0xffffffff) revert ERC165Base__InvalidInterfaceId();
        ERC165BaseStorage.layout().supportedInterfaces[interfaceId] = status;
    }
}


// Chain: POLYGON - File: contracts/introspection/ERC165/base/ERC165BaseStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

library ERC165BaseStorage {
    struct Layout {
        mapping(bytes4 => bool) supportedInterfaces;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.ERC165Base');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: contracts/introspection/ERC165/base/IERC165Base.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC165 } from '../../../interfaces/IERC165.sol';
import { IERC165BaseInternal } from './IERC165BaseInternal.sol';

interface IERC165Base is IERC165, IERC165BaseInternal {}


// Chain: POLYGON - File: contracts/introspection/ERC165/base/IERC165BaseInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC165Internal } from '../../../interfaces/IERC165Internal.sol';

interface IERC165BaseInternal is IERC165Internal {
    error ERC165Base__InvalidInterfaceId();
}


// Chain: POLYGON - File: contracts/security/pausable/IPausable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IPausableInternal } from './IPausableInternal.sol';

interface IPausable is IPausableInternal {
    /**
     * @notice query whether contract is paused
     * @return status whether contract is paused
     */
    function paused() external view returns (bool status);
}


// Chain: POLYGON - File: contracts/security/pausable/IPausableInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

interface IPausableInternal {
    error Pausable__Paused();
    error Pausable__NotPaused();

    event Paused(address account);
    event Unpaused(address account);
}


// Chain: POLYGON - File: contracts/security/pausable/Pausable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IPausable } from './IPausable.sol';
import { PausableInternal } from './PausableInternal.sol';

/**
 * @title Pausable security control module.
 */
abstract contract Pausable is IPausable, PausableInternal {
    /**
     * @inheritdoc IPausable
     */
    function paused() external view virtual returns (bool status) {
        status = _paused();
    }
}


// Chain: POLYGON - File: contracts/security/pausable/PausableInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IPausableInternal } from './IPausableInternal.sol';
import { PausableStorage } from './PausableStorage.sol';

/**
 * @title Internal functions for Pausable security control module.
 */
abstract contract PausableInternal is IPausableInternal {
    modifier whenNotPaused() {
        if (_paused()) revert Pausable__Paused();
        _;
    }

    modifier whenPaused() {
        if (!_paused()) revert Pausable__NotPaused();
        _;
    }

    /**
     * @notice query whether contract is paused
     * @return status whether contract is paused
     */
    function _paused() internal view virtual returns (bool status) {
        status = PausableStorage.layout().paused;
    }

    /**
     * @notice Triggers paused state, when contract is unpaused.
     */
    function _pause() internal virtual whenNotPaused {
        PausableStorage.layout().paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Triggers unpaused state, when contract is paused.
     */
    function _unpause() internal virtual whenPaused {
        delete PausableStorage.layout().paused;
        emit Unpaused(msg.sender);
    }
}


// Chain: POLYGON - File: contracts/security/pausable/PausableStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

library PausableStorage {
    struct Layout {
        bool paused;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.Pausable');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: contracts/token/common/ERC2981/ERC2981.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC2981 } from '../../../interfaces/IERC2981.sol';

import { ERC2981Storage } from './ERC2981Storage.sol';
import { ERC2981Internal } from './ERC2981Internal.sol';

/**
 * @title ERC2981 implementation
 */
abstract contract ERC2981 is IERC2981, ERC2981Internal {
    /**
     * @notice inheritdoc IERC2981
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address, uint256) {
        return _royaltyInfo(tokenId, salePrice);
    }
}


// Chain: POLYGON - File: contracts/token/common/ERC2981/ERC2981Internal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { ERC2981Storage } from './ERC2981Storage.sol';
import { IERC2981Internal } from '../../../interfaces/IERC2981Internal.sol';

/**
 * @title ERC2981 internal functions
 */
abstract contract ERC2981Internal is IERC2981Internal {
    /**
     * @notice calculate how much royalty is owed and to whom
     * @dev royalty must be paid in addition to, rather than deducted from, salePrice
     * @param tokenId the ERC721 or ERC1155 token id to query for royalty information
     * @param salePrice the sale price of the given asset
     * @return royaltyReceiver rightful recipient of royalty
     * @return royalty amount of royalty owed
     */
    function _royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) internal view virtual returns (address royaltyReceiver, uint256 royalty) {
        uint256 royaltyBPS = _getRoyaltyBPS(tokenId);

        // intermediate multiplication overflow is theoretically possible here, but
        // not an issue in practice because of practical constraints of salePrice
        return (_getRoyaltyReceiver(tokenId), (royaltyBPS * salePrice) / 10000);
    }

    /**
     * @notice query the royalty rate (denominated in basis points) for given token id
     * @dev implementation supports per-token-id values as well as a global default
     * @param tokenId token whose royalty rate to query
     * @return royaltyBPS royalty rate
     */
    function _getRoyaltyBPS(
        uint256 tokenId
    ) internal view virtual returns (uint16 royaltyBPS) {
        ERC2981Storage.Layout storage l = ERC2981Storage.layout();
        royaltyBPS = l.royaltiesBPS[tokenId];

        if (royaltyBPS == 0) {
            royaltyBPS = l.defaultRoyaltyBPS;
        }
    }

    /**
     * @notice query the royalty receiver for given token id
     * @dev implementation supports per-token-id values as well as a global default
     * @param tokenId token whose royalty receiver to query
     * @return royaltyReceiver royalty receiver
     */
    function _getRoyaltyReceiver(
        uint256 tokenId
    ) internal view virtual returns (address royaltyReceiver) {
        ERC2981Storage.Layout storage l = ERC2981Storage.layout();
        royaltyReceiver = l.royaltyReceivers[tokenId];

        if (royaltyReceiver == address(0)) {
            royaltyReceiver = l.defaultRoyaltyReceiver;
        }
    }
}


// Chain: POLYGON - File: contracts/token/common/ERC2981/ERC2981Storage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

library ERC2981Storage {
    struct Layout {
        // token id -> royalty (denominated in basis points)
        mapping(uint256 => uint16) royaltiesBPS;
        uint16 defaultRoyaltyBPS;
        // token id -> receiver address
        mapping(uint256 => address) royaltyReceivers;
        address defaultRoyaltyReceiver;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.ERC2981');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: contracts/token/ERC1155/base/ERC1155Base.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155 } from '../../../interfaces/IERC1155.sol';
import { IERC1155Receiver } from '../../../interfaces/IERC1155Receiver.sol';
import { IERC1155Base } from './IERC1155Base.sol';
import { ERC1155BaseInternal, ERC1155BaseStorage } from './ERC1155BaseInternal.sol';

/**
 * @title Base ERC1155 contract
 * @dev derived from https://github.com/OpenZeppelin/openzeppelin-contracts/ (MIT license)
 * @dev inheritor must either implement ERC165 supportsInterface or inherit ERC165Base
 */
abstract contract ERC1155Base is IERC1155Base, ERC1155BaseInternal {
    /**
     * @inheritdoc IERC1155
     */
    function balanceOf(
        address account,
        uint256 id
    ) public view virtual returns (uint256) {
        return _balanceOf(account, id);
    }

    /**
     * @inheritdoc IERC1155
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual returns (uint256[] memory) {
        if (accounts.length != ids.length)
            revert ERC1155Base__ArrayLengthMismatch();

        mapping(uint256 => mapping(address => uint256))
            storage balances = ERC1155BaseStorage.layout().balances;

        uint256[] memory batchBalances = new uint256[](accounts.length);

        unchecked {
            for (uint256 i; i < accounts.length; i++) {
                if (accounts[i] == address(0))
                    revert ERC1155Base__BalanceQueryZeroAddress();
                batchBalances[i] = balances[ids[i]][accounts[i]];
            }
        }

        return batchBalances;
    }

    /**
     * @inheritdoc IERC1155
     */
    function isApprovedForAll(
        address account,
        address operator
    ) public view virtual returns (bool) {
        return ERC1155BaseStorage.layout().operatorApprovals[account][operator];
    }

    /**
     * @inheritdoc IERC1155
     */
    function setApprovalForAll(address operator, bool status) public virtual {
        if (msg.sender == operator) revert ERC1155Base__SelfApproval();
        ERC1155BaseStorage.layout().operatorApprovals[msg.sender][
            operator
        ] = status;
        emit ApprovalForAll(msg.sender, operator, status);
    }

    /**
     * @inheritdoc IERC1155
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual {
        if (from != msg.sender && !isApprovedForAll(from, msg.sender))
            revert ERC1155Base__NotOwnerOrApproved();
        _safeTransfer(msg.sender, from, to, id, amount, data);
    }

    /**
     * @inheritdoc IERC1155
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual {
        if (from != msg.sender && !isApprovedForAll(from, msg.sender))
            revert ERC1155Base__NotOwnerOrApproved();
        _safeTransferBatch(msg.sender, from, to, ids, amounts, data);
    }
}


// Chain: POLYGON - File: contracts/token/ERC1155/base/ERC1155BaseInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155Receiver } from '../../../interfaces/IERC1155Receiver.sol';
import { AddressUtils } from '../../../utils/AddressUtils.sol';
import { IERC1155BaseInternal } from './IERC1155BaseInternal.sol';
import { ERC1155BaseStorage } from './ERC1155BaseStorage.sol';

/**
 * @title Base ERC1155 internal functions
 * @dev derived from https://github.com/OpenZeppelin/openzeppelin-contracts/ (MIT license)
 */
abstract contract ERC1155BaseInternal is IERC1155BaseInternal {
    using AddressUtils for address;

    /**
     * @notice query the balance of given token held by given address
     * @param account address to query
     * @param id token to query
     * @return token balance
     */
    function _balanceOf(
        address account,
        uint256 id
    ) internal view virtual returns (uint256) {
        if (account == address(0))
            revert ERC1155Base__BalanceQueryZeroAddress();
        return ERC1155BaseStorage.layout().balances[id][account];
    }

    /**
     * @notice mint given quantity of tokens for given address
     * @dev ERC1155Receiver implementation is not checked
     * @param account beneficiary of minting
     * @param id token ID
     * @param amount quantity of tokens to mint
     * @param data data payload
     */
    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        if (account == address(0)) revert ERC1155Base__MintToZeroAddress();

        _beforeTokenTransfer(
            msg.sender,
            address(0),
            account,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        ERC1155BaseStorage.layout().balances[id][account] += amount;

        emit TransferSingle(msg.sender, address(0), account, id, amount);
    }

    /**
     * @notice mint given quantity of tokens for given address
     * @param account beneficiary of minting
     * @param id token ID
     * @param amount quantity of tokens to mint
     * @param data data payload
     */
    function _safeMint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        _mint(account, id, amount, data);

        _doSafeTransferAcceptanceCheck(
            msg.sender,
            address(0),
            account,
            id,
            amount,
            data
        );
    }

    /**
     * @notice mint batch of tokens for given address
     * @dev ERC1155Receiver implementation is not checked
     * @param account beneficiary of minting
     * @param ids list of token IDs
     * @param amounts list of quantities of tokens to mint
     * @param data data payload
     */
    function _mintBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        if (account == address(0)) revert ERC1155Base__MintToZeroAddress();
        if (ids.length != amounts.length)
            revert ERC1155Base__ArrayLengthMismatch();

        _beforeTokenTransfer(
            msg.sender,
            address(0),
            account,
            ids,
            amounts,
            data
        );

        mapping(uint256 => mapping(address => uint256))
            storage balances = ERC1155BaseStorage.layout().balances;

        for (uint256 i; i < ids.length; ) {
            balances[ids[i]][account] += amounts[i];
            unchecked {
                i++;
            }
        }

        emit TransferBatch(msg.sender, address(0), account, ids, amounts);
    }

    /**
     * @notice mint batch of tokens for given address
     * @param account beneficiary of minting
     * @param ids list of token IDs
     * @param amounts list of quantities of tokens to mint
     * @param data data payload
     */
    function _safeMintBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        _mintBatch(account, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(
            msg.sender,
            address(0),
            account,
            ids,
            amounts,
            data
        );
    }

    /**
     * @notice burn given quantity of tokens held by given address
     * @param account holder of tokens to burn
     * @param id token ID
     * @param amount quantity of tokens to burn
     */
    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal virtual {
        if (account == address(0)) revert ERC1155Base__BurnFromZeroAddress();

        _beforeTokenTransfer(
            msg.sender,
            account,
            address(0),
            _asSingletonArray(id),
            _asSingletonArray(amount),
            ''
        );

        mapping(address => uint256) storage balances = ERC1155BaseStorage
            .layout()
            .balances[id];

        unchecked {
            if (amount > balances[account])
                revert ERC1155Base__BurnExceedsBalance();
            balances[account] -= amount;
        }

        emit TransferSingle(msg.sender, account, address(0), id, amount);
    }

    /**
     * @notice burn given batch of tokens held by given address
     * @param account holder of tokens to burn
     * @param ids token IDs
     * @param amounts quantities of tokens to burn
     */
    function _burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        if (account == address(0)) revert ERC1155Base__BurnFromZeroAddress();
        if (ids.length != amounts.length)
            revert ERC1155Base__ArrayLengthMismatch();

        _beforeTokenTransfer(msg.sender, account, address(0), ids, amounts, '');

        mapping(uint256 => mapping(address => uint256))
            storage balances = ERC1155BaseStorage.layout().balances;

        unchecked {
            for (uint256 i; i < ids.length; i++) {
                uint256 id = ids[i];
                if (amounts[i] > balances[id][account])
                    revert ERC1155Base__BurnExceedsBalance();
                balances[id][account] -= amounts[i];
            }
        }

        emit TransferBatch(msg.sender, account, address(0), ids, amounts);
    }

    /**
     * @notice transfer tokens between given addresses
     * @dev ERC1155Receiver implementation is not checked
     * @param operator executor of transfer
     * @param sender sender of tokens
     * @param recipient receiver of tokens
     * @param id token ID
     * @param amount quantity of tokens to transfer
     * @param data data payload
     */
    function _transfer(
        address operator,
        address sender,
        address recipient,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        if (recipient == address(0))
            revert ERC1155Base__TransferToZeroAddress();

        _beforeTokenTransfer(
            operator,
            sender,
            recipient,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        mapping(uint256 => mapping(address => uint256))
            storage balances = ERC1155BaseStorage.layout().balances;

        unchecked {
            uint256 senderBalance = balances[id][sender];
            if (amount > senderBalance)
                revert ERC1155Base__TransferExceedsBalance();
            balances[id][sender] = senderBalance - amount;
        }

        balances[id][recipient] += amount;

        emit TransferSingle(operator, sender, recipient, id, amount);
    }

    /**
     * @notice transfer tokens between given addresses
     * @param operator executor of transfer
     * @param sender sender of tokens
     * @param recipient receiver of tokens
     * @param id token ID
     * @param amount quantity of tokens to transfer
     * @param data data payload
     */
    function _safeTransfer(
        address operator,
        address sender,
        address recipient,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        _transfer(operator, sender, recipient, id, amount, data);

        _doSafeTransferAcceptanceCheck(
            operator,
            sender,
            recipient,
            id,
            amount,
            data
        );
    }

    /**
     * @notice transfer batch of tokens between given addresses
     * @dev ERC1155Receiver implementation is not checked
     * @param operator executor of transfer
     * @param sender sender of tokens
     * @param recipient receiver of tokens
     * @param ids token IDs
     * @param amounts quantities of tokens to transfer
     * @param data data payload
     */
    function _transferBatch(
        address operator,
        address sender,
        address recipient,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        if (recipient == address(0))
            revert ERC1155Base__TransferToZeroAddress();
        if (ids.length != amounts.length)
            revert ERC1155Base__ArrayLengthMismatch();

        _beforeTokenTransfer(operator, sender, recipient, ids, amounts, data);

        mapping(uint256 => mapping(address => uint256))
            storage balances = ERC1155BaseStorage.layout().balances;

        for (uint256 i; i < ids.length; ) {
            uint256 token = ids[i];
            uint256 amount = amounts[i];

            unchecked {
                uint256 senderBalance = balances[token][sender];

                if (amount > senderBalance)
                    revert ERC1155Base__TransferExceedsBalance();

                balances[token][sender] = senderBalance - amount;

                i++;
            }

            // balance increase cannot be unchecked because ERC1155Base neither tracks nor validates a totalSupply
            balances[token][recipient] += amount;
        }

        emit TransferBatch(operator, sender, recipient, ids, amounts);
    }

    /**
     * @notice transfer batch of tokens between given addresses
     * @param operator executor of transfer
     * @param sender sender of tokens
     * @param recipient receiver of tokens
     * @param ids token IDs
     * @param amounts quantities of tokens to transfer
     * @param data data payload
     */
    function _safeTransferBatch(
        address operator,
        address sender,
        address recipient,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        _transferBatch(operator, sender, recipient, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(
            operator,
            sender,
            recipient,
            ids,
            amounts,
            data
        );
    }

    /**
     * @notice wrap given element in array of length 1
     * @param element element to wrap
     * @return singleton array
     */
    function _asSingletonArray(
        uint256 element
    ) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }

    /**
     * @notice revert if applicable transfer recipient is not valid ERC1155Receiver
     * @param operator executor of transfer
     * @param from sender of tokens
     * @param to receiver of tokens
     * @param id token ID
     * @param amount quantity of tokens to transfer
     * @param data data payload
     */
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector)
                    revert ERC1155Base__ERC1155ReceiverRejected();
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert ERC1155Base__ERC1155ReceiverNotImplemented();
            }
        }
    }

    /**
     * @notice revert if applicable transfer recipient is not valid ERC1155Receiver
     * @param operator executor of transfer
     * @param from sender of tokens
     * @param to receiver of tokens
     * @param ids token IDs
     * @param amounts quantities of tokens to transfer
     * @param data data payload
     */
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (
                    response != IERC1155Receiver.onERC1155BatchReceived.selector
                ) revert ERC1155Base__ERC1155ReceiverRejected();
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert ERC1155Base__ERC1155ReceiverNotImplemented();
            }
        }
    }

    /**
     * @notice ERC1155 hook, called before all transfers including mint and burn
     * @dev function should be overridden and new implementation must call super
     * @dev called for both single and batch transfers
     * @param operator executor of transfer
     * @param from sender of tokens
     * @param to receiver of tokens
     * @param ids token IDs
     * @param amounts quantities of tokens to transfer
     * @param data data payload
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}
}


// Chain: POLYGON - File: contracts/token/ERC1155/base/ERC1155BaseStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

library ERC1155BaseStorage {
    struct Layout {
        mapping(uint256 => mapping(address => uint256)) balances;
        mapping(address => mapping(address => bool)) operatorApprovals;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.ERC1155Base');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: contracts/token/ERC1155/base/IERC1155Base.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155 } from '../../../interfaces/IERC1155.sol';
import { IERC1155BaseInternal } from './IERC1155BaseInternal.sol';

/**
 * @title ERC1155 base interface
 */
interface IERC1155Base is IERC1155BaseInternal, IERC1155 {

}


// Chain: POLYGON - File: contracts/token/ERC1155/base/IERC1155BaseInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155Internal } from '../../../interfaces/IERC1155Internal.sol';

/**
 * @title ERC1155 base interface
 */
interface IERC1155BaseInternal is IERC1155Internal {
    error ERC1155Base__ArrayLengthMismatch();
    error ERC1155Base__BalanceQueryZeroAddress();
    error ERC1155Base__NotOwnerOrApproved();
    error ERC1155Base__SelfApproval();
    error ERC1155Base__BurnExceedsBalance();
    error ERC1155Base__BurnFromZeroAddress();
    error ERC1155Base__ERC1155ReceiverRejected();
    error ERC1155Base__ERC1155ReceiverNotImplemented();
    error ERC1155Base__MintToZeroAddress();
    error ERC1155Base__TransferExceedsBalance();
    error ERC1155Base__TransferToZeroAddress();
}


// Chain: POLYGON - File: contracts/token/ERC1155/enumerable/ERC1155Enumerable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { EnumerableSet } from '../../../data/EnumerableSet.sol';
import { ERC1155BaseInternal } from '../base/ERC1155BaseInternal.sol';
import { IERC1155Enumerable } from './IERC1155Enumerable.sol';
import { ERC1155EnumerableInternal, ERC1155EnumerableStorage } from './ERC1155EnumerableInternal.sol';

/**
 * @title ERC1155 implementation including enumerable and aggregate functions
 */
abstract contract ERC1155Enumerable is
    IERC1155Enumerable,
    ERC1155EnumerableInternal
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    /**
     * @inheritdoc IERC1155Enumerable
     */
    function totalSupply(uint256 id) public view virtual returns (uint256) {
        return _totalSupply(id);
    }

    /**
     * @inheritdoc IERC1155Enumerable
     */
    function totalHolders(uint256 id) public view virtual returns (uint256) {
        return _totalHolders(id);
    }

    /**
     * @inheritdoc IERC1155Enumerable
     */
    function accountsByToken(
        uint256 id
    ) public view virtual returns (address[] memory) {
        return _accountsByToken(id);
    }

    /**
     * @inheritdoc IERC1155Enumerable
     */
    function tokensByAccount(
        address account
    ) public view virtual returns (uint256[] memory) {
        return _tokensByAccount(account);
    }
}


// Chain: POLYGON - File: contracts/token/ERC1155/enumerable/ERC1155EnumerableInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { EnumerableSet } from '../../../data/EnumerableSet.sol';
import { ERC1155BaseInternal, ERC1155BaseStorage } from '../base/ERC1155BaseInternal.sol';
import { ERC1155EnumerableStorage } from './ERC1155EnumerableStorage.sol';

/**
 * @title ERC1155Enumerable internal functions
 */
abstract contract ERC1155EnumerableInternal is ERC1155BaseInternal {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    /**
     * @notice query total minted supply of given token
     * @param id token id to query
     * @return token supply
     */
    function _totalSupply(uint256 id) internal view virtual returns (uint256) {
        return ERC1155EnumerableStorage.layout().totalSupply[id];
    }

    /**
     * @notice query total number of holders for given token
     * @param id token id to query
     * @return quantity of holders
     */
    function _totalHolders(uint256 id) internal view virtual returns (uint256) {
        return ERC1155EnumerableStorage.layout().accountsByToken[id].length();
    }

    /**
     * @notice query holders of given token
     * @param id token id to query
     * @return list of holder addresses
     */
    function _accountsByToken(
        uint256 id
    ) internal view virtual returns (address[] memory) {
        EnumerableSet.AddressSet storage accounts = ERC1155EnumerableStorage
            .layout()
            .accountsByToken[id];

        address[] memory addresses = new address[](accounts.length());

        unchecked {
            for (uint256 i; i < accounts.length(); i++) {
                addresses[i] = accounts.at(i);
            }
        }

        return addresses;
    }

    /**
     * @notice query tokens held by given address
     * @param account address to query
     * @return list of token ids
     */
    function _tokensByAccount(
        address account
    ) internal view virtual returns (uint256[] memory) {
        EnumerableSet.UintSet storage tokens = ERC1155EnumerableStorage
            .layout()
            .tokensByAccount[account];

        uint256[] memory ids = new uint256[](tokens.length());

        unchecked {
            for (uint256 i; i < tokens.length(); i++) {
                ids[i] = tokens.at(i);
            }
        }

        return ids;
    }

    /**
     * @notice ERC1155 hook: update aggregate values
     * @inheritdoc ERC1155BaseInternal
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != to) {
            ERC1155EnumerableStorage.Layout storage l = ERC1155EnumerableStorage
                .layout();
            mapping(uint256 => EnumerableSet.AddressSet)
                storage tokenAccounts = l.accountsByToken;
            EnumerableSet.UintSet storage fromTokens = l.tokensByAccount[from];
            EnumerableSet.UintSet storage toTokens = l.tokensByAccount[to];

            for (uint256 i; i < ids.length; ) {
                uint256 amount = amounts[i];

                if (amount > 0) {
                    uint256 id = ids[i];

                    if (from == address(0)) {
                        l.totalSupply[id] += amount;
                    } else if (_balanceOf(from, id) == amount) {
                        tokenAccounts[id].remove(from);
                        fromTokens.remove(id);
                    }

                    if (to == address(0)) {
                        l.totalSupply[id] -= amount;
                    } else if (_balanceOf(to, id) == 0) {
                        tokenAccounts[id].add(to);
                        toTokens.add(id);
                    }
                }

                unchecked {
                    i++;
                }
            }
        }
    }
}


// Chain: POLYGON - File: contracts/token/ERC1155/enumerable/ERC1155EnumerableStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { EnumerableSet } from '../../../data/EnumerableSet.sol';

library ERC1155EnumerableStorage {
    struct Layout {
        mapping(uint256 => uint256) totalSupply;
        mapping(uint256 => EnumerableSet.AddressSet) accountsByToken;
        mapping(address => EnumerableSet.UintSet) tokensByAccount;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.ERC1155Enumerable');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: contracts/token/ERC1155/enumerable/ERC1155NFTCollectionStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

library ERC1155NFTCollectionStorage {
    struct Layout {
        // Collection  name
        string name;
        // Coin to burn for Collection
        mapping(address => uint256) token;
        // Collection Symbol
        string symbol;
        //Token Supply
        mapping(uint256 => uint256) tokensupply;
        //Mint Price
        mapping(uint256 => uint256) price;
        // Project Specific address that can burn a token
        mapping(address => bool) buyerCollections;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('tamocross.contracts.storage.ERC1155NFTCollection');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: contracts/token/ERC1155/enumerable/IERC1155Enumerable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155BaseInternal } from '../base/IERC1155BaseInternal.sol';

/**
 * @title ERC1155 enumerable and aggregate function interface
 */
interface IERC1155Enumerable is IERC1155BaseInternal {
    /**
     * @notice query total minted supply of given token
     * @param id token id to query
     * @return token supply
     */
    function totalSupply(uint256 id) external view returns (uint256);

    /**
     * @notice query total number of holders for given token
     * @param id token id to query
     * @return quantity of holders
     */
    function totalHolders(uint256 id) external view returns (uint256);

    /**
     * @notice query holders of given token
     * @param id token id to query
     * @return list of holder addresses
     */
    function accountsByToken(
        uint256 id
    ) external view returns (address[] memory);

    /**
     * @notice query tokens held by given address
     * @param account address to query
     * @return list of token ids
     */
    function tokensByAccount(
        address account
    ) external view returns (uint256[] memory);
}


// Chain: POLYGON - File: contracts/token/ERC1155/enumerable/SPC.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165 } from '../../../interfaces/IERC165.sol';
import { IERC1155 } from '../../../interfaces/IERC1155.sol';
import { ERC165Base } from '../../../introspection/ERC165/base/ERC165Base.sol';
import { ERC1155Base } from '../base/ERC1155Base.sol';
import { ERC1155BaseInternal } from '../base/ERC1155BaseInternal.sol';
import { ERC1155Enumerable } from './ERC1155Enumerable.sol';
import { ERC1155EnumerableInternal } from './ERC1155EnumerableInternal.sol';
import { Ownable } from '../../../access/ownable/Ownable.sol';
import { Pausable } from '../../../security/pausable/Pausable.sol';
import { ERC1155NFTCollectionStorage } from './ERC1155NFTCollectionStorage.sol';
import { AddressUtils } from '../../../utils/AddressUtils.sol';
import { ERC1155Metadata, ERC1155MetadataStorage } from '../metadata/ERC1155Metadata.sol';
// Need to set supportsInterface on Proxy using "2a55205a" to signal support for ERC2981
import { ERC2981, IERC2981 } from '../../common/ERC2981/ERC2981.sol';
import { ERC2981Storage } from '../../common/ERC2981/ERC2981Storage.sol';

contract SPC is
    ERC1155Enumerable,
    ERC1155Base,
    ERC1155Metadata,
    ERC165Base,
    ERC2981,
    Ownable,
    Pausable
{
    receive() external payable {}

    function withdraw1155(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, 'Not enough balance');
        (bool success, ) = msg.sender.call{ value: amount }('');
        require(success, 'Transfer failed.');
    }

    function name() external view returns (string memory) {
        return ERC1155NFTCollectionStorage.layout().name;
    }

    function maxSupply(
        uint256 tokenId
    ) external view returns (uint256 maxSupply_) {
        maxSupply_ = ERC1155NFTCollectionStorage.layout().tokensupply[tokenId];
    }

    // Mint token based on price
    function claim(
        address _to,
        uint256 tokenId,
        uint256 amount
    ) external payable {
        require(amount > 0, 'Invalid amount');
        require(
            ERC1155NFTCollectionStorage.layout().price[tokenId] * amount <=
                msg.value,
            'Not enough funds'
        );
        require(
            totalSupply(tokenId) + amount <=
                ERC1155NFTCollectionStorage.layout().tokensupply[tokenId],
            'Exceeded max supply'
        );
        _mint(_to, tokenId, amount, '');
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, '');
    }

    function setPrice(uint256 _price, uint256 token) external onlyOwner {
        ERC1155NFTCollectionStorage.layout().price[token] = _price;
    }

    function mintPrice(
        uint256 tokenId
    ) external view returns (uint256 mintprice) {
        mintprice = ERC1155NFTCollectionStorage.layout().price[tokenId];
    }

    // Send minted token
    function sendToken(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external onlyOwner {
        _safeTransfer(owner(), from, to, tokenId, amount, '');
    }

    // External can burn if burning contract is in the buyerscollection mapping
    // External Contract can burn token that is in the token mapping
    function tokenburn(address account, uint256 amount) external whenNotPaused {
        require(
            ERC1155NFTCollectionStorage.layout().buyerCollections[msg.sender],
            'Contract unknown'
        );
        _burn(
            account,
            ERC1155NFTCollectionStorage.layout().token[msg.sender],
            amount
        );
    }

    function setOwner(address owner) external onlyOwner {
        _setOwner(owner);
    }

    // ERC2981 Set default royalty
    function setdefaultRoyalty(uint16 defaultRoyaltyBPS) external onlyOwner {
        ERC2981Storage.layout().defaultRoyaltyBPS = defaultRoyaltyBPS;
    }

    // ERC2981 Set individual royalties for each token
    function setRoyalties(uint16[] calldata royaltiesBPS) external onlyOwner {
        for (uint8 i = 0; i < royaltiesBPS.length; i++) {
            ERC2981Storage.layout().royaltiesBPS[i] = royaltiesBPS[i];
        }
    }

    //  ERC2981 Change the default receiver
    function setRoyaltyReceiver(address _receiver) external onlyOwner {
        ERC2981Storage.layout().defaultRoyaltyReceiver = _receiver;
    }

    // Functions from Solidstate Start

    function burn(
        address account,
        uint256 id,
        uint256 amount
    ) external whenNotPaused onlyOwner {
        _burn(account, id, amount);
    }

    function setBaseURI(
        string memory baseURI
    ) external whenNotPaused onlyOwner {
        _setBaseURI(baseURI);
    }

    function setTokenURI(
        uint256 tokenId,
        string memory tokenURI
    ) external whenNotPaused onlyOwner {
        _setTokenURI(tokenId, tokenURI);
    }

    /**
     * @notice ERC1155 hook: update aggregate values
     * @inheritdoc ERC1155EnumerableInternal
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        virtual
        override(ERC1155BaseInternal, ERC1155EnumerableInternal)
        whenNotPaused
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
    // Functions from Solidstate END
}


// Chain: POLYGON - File: contracts/token/ERC1155/metadata/ERC1155Metadata.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { UintUtils } from '../../../utils/UintUtils.sol';
import { IERC1155Metadata } from './IERC1155Metadata.sol';
import { ERC1155MetadataInternal } from './ERC1155MetadataInternal.sol';
import { ERC1155MetadataStorage } from './ERC1155MetadataStorage.sol';

/**
 * @title ERC1155 metadata extensions
 */
abstract contract ERC1155Metadata is IERC1155Metadata, ERC1155MetadataInternal {
    using UintUtils for uint256;

    /**
     * @notice inheritdoc IERC1155Metadata
     */
    function uri(uint256 tokenId) public view virtual returns (string memory) {
        ERC1155MetadataStorage.Layout storage l = ERC1155MetadataStorage
            .layout();

        string memory tokenIdURI = l.tokenURIs[tokenId];
        string memory baseURI = l.baseURI;

        if (bytes(baseURI).length == 0) {
            return tokenIdURI;
        } else if (bytes(tokenIdURI).length > 0) {
            return string(abi.encodePacked(baseURI, tokenIdURI));
        } else {
            return string(abi.encodePacked(baseURI, tokenId.toString()));
        }
    }
}


// Chain: POLYGON - File: contracts/token/ERC1155/metadata/ERC1155MetadataInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155MetadataInternal } from './IERC1155MetadataInternal.sol';
import { ERC1155MetadataStorage } from './ERC1155MetadataStorage.sol';

/**
 * @title ERC1155Metadata internal functions
 */
abstract contract ERC1155MetadataInternal is IERC1155MetadataInternal {
    /**
     * @notice set base metadata URI
     * @dev base URI is a non-standard feature adapted from the ERC721 specification
     * @param baseURI base URI
     */
    function _setBaseURI(string memory baseURI) internal {
        ERC1155MetadataStorage.layout().baseURI = baseURI;
    }

    /**
     * @notice set per-token metadata URI
     * @param tokenId token whose metadata URI to set
     * @param tokenURI per-token URI
     */
    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal {
        ERC1155MetadataStorage.layout().tokenURIs[tokenId] = tokenURI;
        emit URI(tokenURI, tokenId);
    }
}


// Chain: POLYGON - File: contracts/token/ERC1155/metadata/ERC1155MetadataStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title ERC1155 metadata extensions
 */
library ERC1155MetadataStorage {
    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.ERC1155Metadata');

    struct Layout {
        string baseURI;
        mapping(uint256 => string) tokenURIs;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: contracts/token/ERC1155/metadata/IERC1155Metadata.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155MetadataInternal } from './IERC1155MetadataInternal.sol';

/**
 * @title ERC1155Metadata interface
 */
interface IERC1155Metadata is IERC1155MetadataInternal {
    /**
     * @notice get generated URI for given token
     * @return token URI
     */
    function uri(uint256 tokenId) external view returns (string memory);
}


// Chain: POLYGON - File: contracts/token/ERC1155/metadata/IERC1155MetadataInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC1155Metadata interface needed by internal functions
 */
interface IERC1155MetadataInternal {
    event URI(string value, uint256 indexed tokenId);
}


// Chain: POLYGON - File: contracts/utils/AddressUtils.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { UintUtils } from './UintUtils.sol';

library AddressUtils {
    using UintUtils for uint256;

    error AddressUtils__InsufficientBalance();
    error AddressUtils__NotContract();
    error AddressUtils__SendValueFailed();

    function toString(address account) internal pure returns (string memory) {
        return uint256(uint160(account)).toHexString(20);
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable account, uint256 amount) internal {
        (bool success, ) = account.call{ value: amount }('');
        if (!success) revert AddressUtils__SendValueFailed();
    }

    function functionCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return
            functionCall(target, data, 'AddressUtils: failed low-level call');
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory error
    ) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, error);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                value,
                'AddressUtils: failed low-level call with value'
            );
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory error
    ) internal returns (bytes memory) {
        if (value > address(this).balance)
            revert AddressUtils__InsufficientBalance();
        return _functionCallWithValue(target, data, value, error);
    }

    /**
     * @notice execute arbitrary external call with limited gas usage and amount of copied return data
     * @dev derived from https://github.com/nomad-xyz/ExcessivelySafeCall (MIT License)
     * @param target recipient of call
     * @param gasAmount gas allowance for call
     * @param value native token value to include in call
     * @param maxCopy maximum number of bytes to copy from return data
     * @param data encoded call data
     * @return success whether call is successful
     * @return returnData copied return data
     */
    function excessivelySafeCall(
        address target,
        uint256 gasAmount,
        uint256 value,
        uint16 maxCopy,
        bytes memory data
    ) internal returns (bool success, bytes memory returnData) {
        returnData = new bytes(maxCopy);

        assembly {
            // execute external call via assembly to avoid automatic copying of return data
            success := call(
                gasAmount,
                target,
                value,
                add(data, 0x20),
                mload(data),
                0,
                0
            )

            // determine whether to limit amount of data to copy
            let toCopy := returndatasize()

            if gt(toCopy, maxCopy) {
                toCopy := maxCopy
            }

            // store the length of the copied bytes
            mstore(returnData, toCopy)

            // copy the bytes from returndata[0:toCopy]
            returndatacopy(add(returnData, 0x20), 0, toCopy)
        }
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory error
    ) private returns (bytes memory) {
        if (!isContract(target)) revert AddressUtils__NotContract();

        (bool success, bytes memory returnData) = target.call{ value: value }(
            data
        );

        if (success) {
            return returnData;
        } else if (returnData.length > 0) {
            assembly {
                let returnData_size := mload(returnData)
                revert(add(32, returnData), returnData_size)
            }
        } else {
            revert(error);
        }
    }
}


// Chain: POLYGON - File: contracts/utils/UintUtils.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title utility functions for uint256 operations
 * @dev derived from https://github.com/OpenZeppelin/openzeppelin-contracts/ (MIT license)
 */
library UintUtils {
    error UintUtils__InsufficientHexLength();

    bytes16 private constant HEX_SYMBOLS = '0123456789abcdef';

    function add(uint256 a, int256 b) internal pure returns (uint256) {
        return b < 0 ? sub(a, -b) : a + uint256(b);
    }

    function sub(uint256 a, int256 b) internal pure returns (uint256) {
        return b < 0 ? add(a, -b) : a - uint256(b);
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return '0';
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return '0x00';
        }

        uint256 length = 0;

        for (uint256 temp = value; temp != 0; temp >>= 8) {
            unchecked {
                length++;
            }
        }

        return toHexString(value, length);
    }

    function toHexString(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = '0';
        buffer[1] = 'x';

        unchecked {
            for (uint256 i = 2 * length + 1; i > 1; --i) {
                buffer[i] = HEX_SYMBOLS[value & 0xf];
                value >>= 4;
            }
        }

        if (value != 0) revert UintUtils__InsufficientHexLength();

        return string(buffer);
    }
}