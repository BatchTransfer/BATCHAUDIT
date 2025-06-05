// File: @solidstate/contracts/access/ownable/IOwnable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173 } from '../../interfaces/IERC173.sol';

interface IOwnable is IERC173 {}


// File: @solidstate/contracts/access/ownable/IOwnableInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC173Internal } from '../../interfaces/IERC173Internal.sol';

interface IOwnableInternal is IERC173Internal {
    error Ownable__NotOwner();
    error Ownable__NotTransitiveOwner();
}


// File: @solidstate/contracts/access/ownable/ISafeOwnable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IOwnable } from './IOwnable.sol';

interface ISafeOwnable is IOwnable {
    /**
     * @notice get the nominated owner who has permission to call acceptOwnership
     */
    function nomineeOwner() external view returns (address);

    /**
     * @notice accept transfer of contract ownership
     */
    function acceptOwnership() external;
}


// File: @solidstate/contracts/access/ownable/OwnableInternal.sol
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


// File: @solidstate/contracts/access/ownable/OwnableStorage.sol
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


// File: @solidstate/contracts/data/EnumerableSet.sol
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


// File: @solidstate/contracts/interfaces/IERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165 } from './IERC165.sol';
import { IERC1155Internal } from './IERC1155Internal.sol';

/**
 * @title ERC1155 interface
 * @dev see https://github.com/ethereum/EIPs/issues/1155
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


// File: @solidstate/contracts/interfaces/IERC1155Internal.sol
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


// File: @solidstate/contracts/interfaces/IERC1155Receiver.sol
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


// File: @solidstate/contracts/interfaces/IERC165.sol
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


// File: @solidstate/contracts/interfaces/IERC165Internal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165Internal } from './IERC165Internal.sol';

/**
 * @title ERC165 interface registration interface
 */
interface IERC165Internal {

}


// File: @solidstate/contracts/interfaces/IERC173.sol
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
     * @return conrtact owner
     */
    function owner() external view returns (address);

    /**
     * @notice transfer contract ownership to new account
     * @param account address of new owner
     */
    function transferOwnership(address account) external;
}


// File: @solidstate/contracts/interfaces/IERC173Internal.sol
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


// File: @solidstate/contracts/interfaces/IERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC20Internal } from './IERC20Internal.sol';

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 is IERC20Internal {
    /**
     * @notice query the total minted token supply
     * @return token supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice query the token balance of given account
     * @param account address to query
     * @return token balance
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice query the allowance granted from given holder to given spender
     * @param holder approver of allowance
     * @param spender recipient of allowance
     * @return token allowance
     */
    function allowance(
        address holder,
        address spender
    ) external view returns (uint256);

    /**
     * @notice grant approval to spender to spend tokens
     * @dev prefer ERC20Extended functions to avoid transaction-ordering vulnerability (see https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729)
     * @param spender recipient of allowance
     * @param amount quantity of tokens approved for spending
     * @return success status (always true; otherwise function should revert)
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @notice transfer tokens to given recipient
     * @param recipient beneficiary of token transfer
     * @param amount quantity of tokens to transfer
     * @return success status (always true; otherwise function should revert)
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice transfer tokens to given recipient on behalf of given holder
     * @param holder holder of tokens prior to transfer
     * @param recipient beneficiary of token transfer
     * @param amount quantity of tokens to transfer
     * @return success status (always true; otherwise function should revert)
     */
    function transferFrom(
        address holder,
        address recipient,
        uint256 amount
    ) external returns (bool);
}


// File: @solidstate/contracts/interfaces/IERC20Internal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC20 interface needed by internal functions
 */
interface IERC20Internal {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}


// File: @solidstate/contracts/interfaces/IERC721.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165 } from './IERC165.sol';
import { IERC721Internal } from './IERC721Internal.sol';

/**
 * @title ERC721 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721 is IERC721Internal, IERC165 {
    /**
     * @notice query the balance of given address
     * @return balance quantity of tokens held
     */
    function balanceOf(address account) external view returns (uint256 balance);

    /**
     * @notice query the owner of given token
     * @param tokenId token to query
     * @return owner token owner
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @notice transfer token between given addresses, checking for ERC721Receiver implementation if applicable
     * @param from sender of token
     * @param to receiver of token
     * @param tokenId token id
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable;

    /**
     * @notice transfer token between given addresses, checking for ERC721Receiver implementation if applicable
     * @param from sender of token
     * @param to receiver of token
     * @param tokenId token id
     * @param data data payload
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external payable;

    /**
     * @notice transfer token between given addresses, without checking for ERC721Receiver implementation if applicable
     * @param from sender of token
     * @param to receiver of token
     * @param tokenId token id
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable;

    /**
     * @notice grant approval to given account to spend token
     * @param operator address to be approved
     * @param tokenId token to approve
     */
    function approve(address operator, uint256 tokenId) external payable;

    /**
     * @notice get approval status for given token
     * @param tokenId token to query
     * @return operator address approved to spend token
     */
    function getApproved(
        uint256 tokenId
    ) external view returns (address operator);

    /**
     * @notice grant approval to or revoke approval from given account to spend all tokens held by sender
     * @param operator address to be approved
     * @param status approval status
     */
    function setApprovalForAll(address operator, bool status) external;

    /**
     * @notice query approval status of given operator with respect to given address
     * @param account address to query for approval granted
     * @param operator address to query for approval received
     * @return status whether operator is approved to spend tokens held by account
     */
    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool status);
}


// File: @solidstate/contracts/interfaces/IERC721Internal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC721 interface needed by internal functions
 */
interface IERC721Internal {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    event Approval(
        address indexed owner,
        address indexed operator,
        uint256 indexed tokenId
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
}


// File: @solidstate/contracts/interfaces/IERC721Receiver.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}


// File: @solidstate/contracts/introspection/ERC165/base/ERC165Base.sol
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


// File: @solidstate/contracts/introspection/ERC165/base/ERC165BaseInternal.sol
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
    ) internal view returns (bool) {
        return ERC165BaseStorage.layout().supportedInterfaces[interfaceId];
    }

    /**
     * @notice sets status of interface support
     * @param interfaceId id of interface to set status for
     * @param status boolean indicating whether interface will be set as supported
     */
    function _setSupportsInterface(bytes4 interfaceId, bool status) internal {
        if (interfaceId == 0xffffffff) revert ERC165Base__InvalidInterfaceId();
        ERC165BaseStorage.layout().supportedInterfaces[interfaceId] = status;
    }
}


// File: @solidstate/contracts/introspection/ERC165/base/ERC165BaseStorage.sol
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


// File: @solidstate/contracts/introspection/ERC165/base/IERC165Base.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC165 } from '../../../interfaces/IERC165.sol';
import { IERC165BaseInternal } from './IERC165BaseInternal.sol';

interface IERC165Base is IERC165, IERC165BaseInternal {}


// File: @solidstate/contracts/introspection/ERC165/base/IERC165BaseInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC165Internal } from '../../../interfaces/IERC165Internal.sol';

interface IERC165BaseInternal is IERC165Internal {
    error ERC165Base__InvalidInterfaceId();
}


// File: @solidstate/contracts/token/ERC1155/base/ERC1155Base.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155 } from '../../../interfaces/IERC1155.sol';
import { IERC1155Receiver } from '../../../interfaces/IERC1155Receiver.sol';
import { IERC1155Base } from './IERC1155Base.sol';
import { ERC1155BaseInternal, ERC1155BaseStorage } from './ERC1155BaseInternal.sol';

/**
 * @title Base ERC1155 contract
 * @dev derived from https://github.com/OpenZeppelin/openzeppelin-contracts/ (MIT license)
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


// File: @solidstate/contracts/token/ERC1155/base/ERC1155BaseInternal.sol
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


// File: @solidstate/contracts/token/ERC1155/base/ERC1155BaseStorage.sol
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


// File: @solidstate/contracts/token/ERC1155/base/IERC1155Base.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155 } from '../../../interfaces/IERC1155.sol';
import { IERC1155BaseInternal } from './IERC1155BaseInternal.sol';

/**
 * @title ERC1155 base interface
 */
interface IERC1155Base is IERC1155BaseInternal, IERC1155 {

}


// File: @solidstate/contracts/token/ERC1155/base/IERC1155BaseInternal.sol
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


// File: @solidstate/contracts/token/ERC1155/enumerable/ERC1155Enumerable.sol
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


// File: @solidstate/contracts/token/ERC1155/enumerable/ERC1155EnumerableInternal.sol
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


// File: @solidstate/contracts/token/ERC1155/enumerable/ERC1155EnumerableStorage.sol
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


// File: @solidstate/contracts/token/ERC1155/enumerable/IERC1155Enumerable.sol
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


// File: @solidstate/contracts/token/ERC1155/ISolidStateERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC1155Base } from './base/IERC1155Base.sol';
import { IERC1155Enumerable } from './enumerable/IERC1155Enumerable.sol';
import { IERC1155Metadata } from './metadata/IERC1155Metadata.sol';

interface ISolidStateERC1155 is
    IERC1155Base,
    IERC1155Enumerable,
    IERC1155Metadata
{}


// File: @solidstate/contracts/token/ERC1155/metadata/ERC1155Metadata.sol
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


// File: @solidstate/contracts/token/ERC1155/metadata/ERC1155MetadataInternal.sol
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


// File: @solidstate/contracts/token/ERC1155/metadata/ERC1155MetadataStorage.sol
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


// File: @solidstate/contracts/token/ERC1155/metadata/IERC1155Metadata.sol
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


// File: @solidstate/contracts/token/ERC1155/metadata/IERC1155MetadataInternal.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC1155Metadata interface needed by internal functions
 */
interface IERC1155MetadataInternal {
    event URI(string value, uint256 indexed tokenId);
}


// File: @solidstate/contracts/utils/AddressUtils.sol
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


// File: @solidstate/contracts/utils/UintUtils.sol
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


// File: contracts/adaptors/lending/JPEGDLendingAdaptor.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC721 } from '@solidstate/contracts/interfaces/IERC721.sol';
import { IERC20 } from '@solidstate/contracts/interfaces/IERC20.sol';

import { JPEGDStakingAdaptor as staking } from '../staking/JPEGDStakingAdaptor.sol';
import { JPEGDAdaptorStorage as s } from '../storage/JPEGDAdaptorStorage.sol';
import { IStableSwap } from '../../interfaces/curve/IStableSwap.sol';
import { ITriCrypto } from '../../interfaces/curve/ITriCrypto.sol';
import { INFTVault } from '../../interfaces/jpegd/INFTVault.sol';
import { ILPFarming } from '../../interfaces/jpegd/ILPFarming.sol';
import { INFTEscrow } from '../../interfaces/jpegd/INFTEscrow.sol';
import { IVault } from '../../interfaces/jpegd/IVault.sol';

library JPEGDLendingAdaptor {
    /**
     * @notice thrown when attempting to borrow after target LTV amount is reached
     */
    error JPEGD__TargetLTVReached();

    /**
     * @notice thrown when insufficient amount of debt is repaid after repayLoan call
     */
    error JPEGD__RepaymentInsufficient();

    /**
     * @notice thrown when the transfer of an asset to JPEGD NFT Vault helper contract fails
     */
    error JPEGD__LowLevelTransferFailed();

    /**
     * @notice borrows JPEGD stablecoin in exchange for collaterlizing an ERC721 asset
     * @param collateralizationData encoded data needed to collateralize the ERC721 asset
     * @param ltvBufferBP loan-to-value buffer value in basis points
     * @param ltvDeviationBP loan-to-value deviation value in basis points
     * @return collection ERC721 collection address
     * @return tokenId id of ERC721 asset
     * @return amount amount of JPEGD stablecoin token received for the collateralized ERC721 asset
     */
    function collateralizeERC721Asset(
        bytes calldata collateralizationData,
        uint16 ltvBufferBP,
        uint16 ltvDeviationBP
    ) internal returns (address collection, uint256 tokenId, uint256 amount) {
        (
            address nftVault,
            uint256 id,
            uint256 borrowAmount,
            bool insure,
            bool hasHelper,
            bool isDirectTransfer,
            bytes memory transferData
        ) = abi.decode(
                collateralizationData,
                (address, uint256, uint256, bool, bool, bool, bytes)
            );

        address token = INFTVault(nftVault).stablecoin();
        address jpegdCollection = INFTVault(nftVault).nftContract();
        address transferTarget = hasHelper ? jpegdCollection : nftVault;
        collection = hasHelper
            ? INFTEscrow(jpegdCollection).nftContract()
            : jpegdCollection;
        tokenId = id;

        uint256 creditLimit = INFTVault(nftVault).getCreditLimit(
            address(this),
            tokenId
        );
        uint256 targetLTV = creditLimit -
            (creditLimit * (ltvBufferBP + ltvDeviationBP)) /
            s.BASIS_POINTS;

        if (INFTVault(nftVault).positionOwner(tokenId) != address(0)) {
            uint256 debt = totalDebt(nftVault, tokenId);

            if (borrowAmount + debt > targetLTV) {
                if (targetLTV < debt) {
                    revert JPEGD__TargetLTVReached();
                }
                borrowAmount = targetLTV - debt;
            }
        } else {
            if (borrowAmount > targetLTV) {
                borrowAmount = targetLTV;
            }

            if (isDirectTransfer) {
                IERC721(collection).approve(transferTarget, tokenId);
            } else {
                (bool success, ) = collection.call(transferData);

                if (!success) {
                    revert JPEGD__LowLevelTransferFailed();
                }
            }
        }

        uint256 oldBalance = IERC20(token).balanceOf(address(this));

        INFTVault(nftVault).borrow(tokenId, borrowAmount, insure);

        amount = IERC20(token).balanceOf(address(this)) - oldBalance;
    }

    /**
     * @notice liquidates all staked tokens in order to pay back loan, retrieves collateralized asset
     * @param closeData encoded data required to close JPEGD position
     * @return receivedETH amount of ETH received after exchanging surplus
     * @return collection address of underlying ERC721 contract
     * @param id tokenId relating to loan position
     */
    function closePosition(
        bytes calldata closeData
    ) internal returns (uint256 receivedETH, address collection, uint256 id) {
        (
            uint256 tokenId,
            uint256 minCoin,
            uint256 minETH,
            uint256 minUSDT,
            uint256 poolInfoIndex,
            address nftVault,
            bool isPETH,
            bool hasHelper
        ) = abi.decode(
                closeData,
                (
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    address,
                    bool,
                    bool
                )
            );

        address coin;
        address vault;
        address curvePool;
        int128 curveIndex;

        if (isPETH) {
            coin = s.PETH;
            vault = s.PETH_VAULT;
            curvePool = s.CURVE_PETH_POOL;
            curveIndex = s.STABLE_PETH_INDEX;
        } else {
            coin = s.PUSD;
            vault = s.PUSD_VAULT;
            curvePool = s.CURVE_PUSD_POOL;
            curveIndex = s.STABLE_PUSD_INDEX;
        }

        uint256 debt = totalDebt(nftVault, tokenId);
        uint256[2] memory amounts;
        amounts[uint256(uint128(curveIndex))] = debt;

        uint256 coinAmount = staking.unstake(
            abi.encode(
                queryVaultTokensForCoins(amounts, curvePool, vault),
                minCoin,
                poolInfoIndex,
                curveIndex,
                isPETH
            )
        );

        IERC20(coin).approve(nftVault, debt);
        INFTVault(nftVault).repay(tokenId, debt);
        INFTVault(nftVault).closePosition(tokenId);

        uint256 surplus = coinAmount - debt;

        receivedETH = swapCoin(coin, curvePool, surplus, minETH, minUSDT);
        id = tokenId;
        address jpegdCollection = INFTVault(nftVault).nftContract();
        collection = hasHelper
            ? INFTEscrow(jpegdCollection).nftContract()
            : jpegdCollection;
    }

    /**
     * @notice makes a debt payment for a collateralized NFT
     * @param repayData encoded data required for debt repayment
     * @return paidDebt amount of debt repaid
     */
    function repayLoan(
        bytes calldata repayData
    ) internal returns (uint256 paidDebt) {
        (
            uint256 amount,
            uint256 minCoinOut,
            uint256 poolInfoIndex,
            uint256 tokenId,
            address nftVault,
            bool isPETH
        ) = abi.decode(
                repayData,
                (uint256, uint256, uint256, uint256, address, bool)
            );

        address coin;
        address vault;
        address curvePool;
        int128 curveIndex;

        if (isPETH) {
            coin = s.PETH;
            vault = s.PETH_VAULT;
            curvePool = s.CURVE_PETH_POOL;
            curveIndex = s.STABLE_PETH_INDEX;
        } else {
            coin = s.PUSD;
            vault = s.PUSD_VAULT;
            curvePool = s.CURVE_PUSD_POOL;
            curveIndex = s.STABLE_PUSD_INDEX;
        }
        uint256[2] memory amounts;
        amounts[uint256(uint128(curveIndex))] = amount;

        paidDebt = staking.unstake(
            abi.encode(
                queryVaultTokensForCoins(amounts, curvePool, vault),
                minCoinOut,
                poolInfoIndex,
                curveIndex,
                isPETH
            )
        );

        if (amount > paidDebt) {
            revert JPEGD__RepaymentInsufficient();
        }

        IERC20(coin).approve(nftVault, paidDebt);
        INFTVault(nftVault).repay(tokenId, paidDebt);
    }

    /**
     * @notice makes loan repayment without unstaking
     * @param directRepayData encoded data required for direct loan repayment
     */
    function directRepayLoan(
        bytes calldata directRepayData
    ) internal returns (uint256 paidDebt) {
        (address nftVault, uint256 tokenId, uint256 amount, bool isPETH) = abi
            .decode(directRepayData, (address, uint256, uint256, bool));

        address coin = isPETH ? s.PETH : s.PUSD;

        IERC20(coin).approve(nftVault, amount);
        INFTVault(nftVault).repay(tokenId, amount);

        paidDebt = amount;
    }

    /**
     * @notice returns amount of JPEGD Vault LP shares needed to be burnt during unstaking
     * to result in a given amount of JPEGD stablecoins
     * @param amounts array of token amounts to receive upon curveLP token burn.
     * @param curvePool curve pool where JPEGD token - token are the underlying tokens
     * @param vault address of JPEGD Vault to withdraw from
     * @return vaultTokens required amount of JPEGD Vault
     */
    function queryVaultTokensForCoins(
        uint256[2] memory amounts,
        address curvePool,
        address vault
    ) internal view returns (uint256 vaultTokens) {
        //does not account for fees, not meant for precise calculations
        //leads to some inaccuracy in later conversion
        uint256 curveLP = IStableSwap(curvePool).calc_token_amount(
            amounts,
            false
        );

        //account for fees
        uint256 curveLPAccountingFee = (curveLP * s.CURVE_BASIS) /
            (s.CURVE_BASIS - s.CURVE_FEE);

        vaultTokens =
            (curveLPAccountingFee * 10 ** IVault(vault).decimals()) /
            IVault(vault).exchangeRate();
    }

    /**
     * @notice returns either total debt or debt interest depending on queryData for a given tokenId
     * on a given JPEGD NFT vault
     * @param queryData encoded data required to query the debt on JPEGD NFT vault
     * @return debt either total debt or debt interest for given tokenId
     */
    function queryDebt(
        bytes calldata queryData
    ) internal view returns (uint256 debt) {
        (address nftVault, uint256 tokenId, bool total) = abi.decode(
            queryData,
            (address, uint256, bool)
        );

        if (total) {
            debt = totalDebt(nftVault, tokenId);
        } else {
            debt = INFTVault(nftVault).getDebtInterest(tokenId);
        }
    }

    /**
     * @notice transfers JPEG tokens equal to yield of account to account
     * @param account address to transfer JPEG tokens to
     */
    function userClaim(address account) internal {
        s.Layout storage l = s.layout();

        uint256 yield = l.userJPEGYield[account];
        delete l.userJPEGYield[account];

        IERC20(s.JPEG).transfer(account, yield);
    }

    /**
     * @notice updates yield of an account without performing transfers
     * @param account account address to record for
     * @param yieldFeeBP discounted yield fee in basis points
     */
    function updateUserRewards(
        address account,
        uint256 shards,
        uint16 yieldFeeBP
    ) internal {
        s.Layout storage l = s.layout();

        uint256 yieldPerShard = l.cumulativeJPEGPerShard -
            l.jpegDeductionsPerShard[account];

        if (yieldPerShard > 0) {
            uint256 totalYield = yieldPerShard * shards;
            uint256 fee = (totalYield * yieldFeeBP) / s.BASIS_POINTS;

            l.jpegDeductionsPerShard[account] += yieldPerShard;
            l.accruedJPEGFees += fee;
            l.userJPEGYield[account] += totalYield - fee;
        }
    }

    /**
     * @notice withdraws JPEG protocol fees and sends to account
     * @param account address of account to send fees to
     * @return fees amount of JPEG fees
     */
    function withdrawFees(address account) internal returns (uint256 fees) {
        s.Layout storage l = s.layout();

        fees = l.accruedJPEGFees;
        delete l.accruedJPEGFees;

        IERC20(s.JPEG).transfer(account, fees);
    }

    /**
     * @notice returns the total JPEG an account may claim
     * @param account account address
     * @param shards shard balance of account
     * @param yieldFeeBP discounted yield fee in basis points
     * @return yield total JPEG claimable
     */
    function userRewards(
        address account,
        uint256 shards,
        uint16 yieldFeeBP
    ) internal view returns (uint256 yield) {
        s.Layout storage l = s.layout();
        uint256 yieldPerShard = l.cumulativeJPEGPerShard -
            l.jpegDeductionsPerShard[account];

        uint256 unclaimedYield = yieldPerShard * shards;
        uint256 yieldFee = (unclaimedYield * yieldFeeBP) / s.BASIS_POINTS;
        yield = l.userJPEGYield[account] + unclaimedYield - yieldFee;
    }

    /**
     * @notice returns the accrued JPEG protocol fees
     * @return fees total accrued JPEG protocol fees
     */
    function accruedJPEGFees() internal view returns (uint256 fees) {
        fees = s.layout().accruedJPEGFees;
    }

    /**
     * @notice returns the cumulative JPEG amount accrued per shard
     * @return amount cumulative JPEG amount accrued per shard
     */
    function cumulativeJPEGPerShard() internal view returns (uint256 amount) {
        amount = s.layout().cumulativeJPEGPerShard;
    }

    /**
     * @notice returns total debt owed to JPEGD NFT vault for a given token
     * @param nftVault address of JPEGD NFT vault
     * @param tokenId id of token position pertains to
     * @return debt total debt owed
     */
    function totalDebt(
        address nftVault,
        uint256 tokenId
    ) private view returns (uint256 debt) {
        debt =
            INFTVault(nftVault).getDebtInterest(tokenId) +
            INFTVault(nftVault).positions(tokenId).debtPrincipal;
    }

    /**
     * @notice swaps JPEGD stablecoin for ETH via curve pools
     * @param coin address of PETH/PUSD
     * @param coinAmount amoutn of PETH/PUSD
     * @param minETH minimum ETH to receive on final exchange
     * @param minUSDT minimum USDT to receive on intermediary exchange in PUSD => USDT => ETH
     */
    function swapCoin(
        address coin,
        address curvePool,
        uint256 coinAmount,
        uint256 minETH,
        uint256 minUSDT
    ) private returns (uint256 receivedETH) {
        if (coin == s.PETH) {
            IERC20(coin).approve(curvePool, coinAmount);
            receivedETH = IStableSwap(curvePool).exchange(
                int128(1), //PETH position in curve pool
                int128(0), //ETH position in cruve pool
                coinAmount,
                minETH
            );
        } else {
            IERC20(coin).approve(curvePool, coinAmount);

            uint256 receivedUSDT = IStableSwap(curvePool).exchange_underlying(
                int128(0), //PUSD position in curve pool
                int128(3), //USDT position in curve pool
                coinAmount,
                minUSDT
            );

            receivedETH = ITriCrypto(s.TRI_CRYPTO_POOL).exchange(
                int128(0), //USDT position in curve tricrypto pool
                int128(2), //WETH position in cruve tricrypto pool
                receivedUSDT,
                minETH,
                true
            );
        }
    }
}


// File: contracts/adaptors/staking/JPEGDStakingAdaptor.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC721 } from '@solidstate/contracts/interfaces/IERC721.sol';
import { IERC20 } from '@solidstate/contracts/interfaces/IERC20.sol';

import { JPEGDAdaptorStorage as s } from '../storage/JPEGDAdaptorStorage.sol';
import { IStableSwap } from '../../interfaces/curve/IStableSwap.sol';
import { ITriCrypto } from '../../interfaces/curve/ITriCrypto.sol';
import { INFTVault } from '../../interfaces/jpegd/INFTVault.sol';
import { ILPFarming } from '../../interfaces/jpegd/ILPFarming.sol';
import { IVault } from '../../interfaces/jpegd/IVault.sol';

library JPEGDStakingAdaptor {
    /**
     * @notice stakes an amount of coins into Curve_LP, then into JPEGD Vault and then into JPEGD LPFarming
     * @param stakeData encoded data required in order to perform staking
     * @return shares JPEGD Vault token amount deposited in LPFarming
     */
    function stake(bytes calldata stakeData) internal returns (uint256 shares) {
        (
            uint256 amount,
            uint256 minCurveLP,
            uint256 poolInfoIndex,
            uint256[2] memory amounts,
            bool isPETH
        ) = abi.decode(
                stakeData,
                (uint256, uint256, uint256, uint256[2], bool)
            );

        address coin;
        address curvePool;
        address vault;

        if (isPETH) {
            coin = s.PETH;
            curvePool = s.CURVE_PETH_POOL;
            vault = s.PETH_VAULT;
        } else {
            coin = s.PUSD;
            curvePool = s.CURVE_PUSD_POOL;
            vault = s.PUSD_VAULT;
        }

        IERC20(coin).approve(curvePool, amount);
        uint256 curveLP = IStableSwap(curvePool).add_liquidity(
            amounts,
            minCurveLP
        );

        IERC20(curvePool).approve(vault, curveLP);
        shares = IVault(vault).deposit(address(this), curveLP);

        IERC20(ILPFarming(s.LP_FARMING).poolInfo(poolInfoIndex).lpToken)
            .approve(s.LP_FARMING, shares);

        ILPFarming(s.LP_FARMING).deposit(poolInfoIndex, shares);
    }

    /**
     * @notice unstakes from JPEGD LPFarming, then from JPEGD vault, then from curve LP
     * @param unstakeData encoded data required for unstaking steps
     * @param coinAmount amount of JPEGD stablecoin received upon unstaking
     */
    function unstake(
        bytes memory unstakeData
    ) internal returns (uint256 coinAmount) {
        (
            uint256 vaultTokens,
            uint256 minCoinOut,
            uint256 poolInfoIndex,
            int128 curveIndex, //can't use constant directly - may want to unstake either token
            bool isPETH
        ) = abi.decode(unstakeData, (uint256, uint256, uint256, int128, bool));

        ILPFarming(s.LP_FARMING).withdraw(poolInfoIndex, vaultTokens);

        address vault;
        address curvePool;

        if (isPETH) {
            vault = s.PETH_VAULT;
            curvePool = s.CURVE_PETH_POOL;
        } else {
            vault = s.PUSD_VAULT;
            curvePool = s.CURVE_PUSD_POOL;
        }

        uint256 curveLP = IVault(vault).withdraw(
            address(this),
            IERC20(ILPFarming(s.LP_FARMING).poolInfo(poolInfoIndex).lpToken)
                .balanceOf(address(this))
        );

        coinAmount = IStableSwap(curvePool).remove_liquidity_one_coin(
            curveLP,
            curveIndex,
            minCoinOut
        );
    }

    /**
     * @notice unstakes from JPEGD LPFarming, then from JPEGD vault, then from curve LP and converts
     * to desired token of curveLP
     * @param unstakeData encoded data required for unstaking steps
     * @param totalSupply total supply of shards
     * @return receivedToken token amount received after unstaking
     * @return receivedJPEG amount JPEG token received after claiming
     */
    function provideYield(
        bytes memory unstakeData,
        uint256 totalSupply
    ) internal returns (uint256 receivedToken, uint256 receivedJPEG) {
        receivedToken = unstake(unstakeData);
        (, , uint256 poolInfoIndex, , ) = abi.decode(
            unstakeData,
            (uint256, uint256, uint256, int128, bool)
        );
        receivedJPEG = ILPFarming(s.LP_FARMING).pendingReward(
            poolInfoIndex,
            address(this)
        );

        ILPFarming(s.LP_FARMING).claim(poolInfoIndex);

        s.layout().cumulativeJPEGPerShard += receivedJPEG / totalSupply;
    }
}


// File: contracts/adaptors/storage/JPEGDAdaptorStorage.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

library JPEGDAdaptorStorage {
    address internal constant JPEG =
        address(0xE80C0cd204D654CEbe8dd64A4857cAb6Be8345a3);
    address internal constant PETH =
        address(0x836A808d4828586A69364065A1e064609F5078c7);
    address internal constant CURVE_PETH_POOL =
        address(0x9848482da3Ee3076165ce6497eDA906E66bB85C5);
    address internal constant PETH_VAULT =
        address(0x56D1b6Ac326e152C9fAad749F1F4f9737a049d46);
    address internal constant PUSD =
        address(0x466a756E9A7401B5e2444a3fCB3c2C12FBEa0a54);
    address internal constant CURVE_PUSD_POOL =
        address(0x8EE017541375F6Bcd802ba119bdDC94dad6911A1);
    address internal constant PUSD_VAULT =
        address(0xF6Cbf5e56a8575797069c7A7FBED218aDF17e3b2);
    address internal constant TRI_CRYPTO_POOL =
        address(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    address internal constant LP_FARMING =
        address(0xb271d2C9e693dde033d97f8A3C9911781329E4CA);

    int128 internal constant STABLE_PETH_INDEX = 1;
    int128 internal constant STABLE_ETH_INDEX = 0;
    int128 internal constant STABLE_PUSD_INDEX = 1;
    int128 internal constant STABLE_USDT_INDEX = 3;
    int128 internal constant TRI_WETH_INDEX = 2;
    int128 internal constant TRI_USDT_INDEX = 0;

    uint256 internal constant CURVE_BASIS = 10000000000;
    uint256 internal constant CURVE_FEE = 4000000;
    uint16 constant BASIS_POINTS = 10000;

    struct Layout {
        uint256 cumulativeJPEGPerShard;
        uint256 accruedJPEGFees;
        mapping(address account => uint256 amount) userJPEGYield;
        mapping(address account => uint256 amount) jpegDeductionsPerShard;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('insrt.contracts.storage.adaptors.JPEGD');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// File: contracts/interfaces/cryptopunk/ICryptoPunkMarket.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Interface for CryptoPunkMarket
 */
interface ICryptoPunkMarket {
    /**
     * @notice offer made on a punk
     * @param isForSale indicates whether punk may be bought instantly
     * @param punkIndex the index of punk
     * @param minValue the minimum price of punk in WEI
     * @param onlySellTo if specified, is the only address a punk may be sold to
     */
    struct Offer {
        bool isForSale;
        uint256 punkIndex;
        address seller;
        uint256 minValue;
        address onlySellTo;
    }

    /**
     * @notice bid on a punk
     * @param hasBid deprecated  (used nowhere in CryptoPunkMarket contract)
     * @param punkIndex the index of the punk
     * @param bidder the address which made the bid
     * @param value the value of the bid in WEI
     */
    struct Bid {
        bool hasBid;
        uint256 punkIndex;
        address bidder;
        uint256 value;
    }

    /**
     * @notice returns  highest bid on a punk
     * @param punkIndex the index of the punk
     * @return highest bid on the punk
     */
    function punkBids(uint256 punkIndex) external view returns (Bid memory);

    /**
     * @notice public mapping(uint => Offer) punksOfferedForSale;
     * @param punkIndex the index of the punk
     * @return offer currently active on the punk
     */
    function punksOfferedForSale(
        uint256 punkIndex
    ) external view returns (Offer memory);

    /**
     * @notice public mapping(uint => address) punkIndexToAddress;
     * @param punkIndex index of the punk
     * @return address to which the punk belongs to (or is assigned to)
     */
    function punkIndexToAddress(
        uint256 punkIndex
    ) external view returns (address);

    /**
     * @notice mapping(address => uint256) pendingWithdrawals mapping
     * @param withdrawer address to which withdrawal is owed
     * @return uint amount pending in ETH
     */
    function pendingWithdrawals(
        address withdrawer
    ) external view returns (uint256);

    /**
     * @notice purchase a punk
     * @param punkIndex index of punk
     */
    function buyPunk(uint256 punkIndex) external payable;

    /**
     * @notice opens punk to instant purchase
     * @param punkIndex the index of the punk
     * @param minSalePriceInWei the minimum sale price of the punk in WEI
     */
    function offerPunkForSale(
        uint256 punkIndex,
        uint256 minSalePriceInWei
    ) external;

    /**
     * @notice closes punk to instance purchase
     * @param punkIndex index of punk
     */
    function punkNoLongerForSale(uint256 punkIndex) external;

    /**
     * @notice withdraws pending amount after punk sale
     */
    function withdraw() external;

    /**
     * @notice transfers a punk without a sale
     * @param to address to transfer punk to
     * @param punkIndex index of punk
     */
    function transferPunk(address to, uint256 punkIndex) external;

    /**
     * @notice accept a bid on a punk
     * @dev note that the minPrice parameter checks that the bid to be accepted must be larger than some
     * price defined by the caller of acceptBidForPunk to ensure the punk is not undersold.
     * @param punkIndex index of punk
     * @param minPrice minimum price of the bid in WEI
     */
    function acceptBidForPunk(uint256 punkIndex, uint256 minPrice) external;

    /**
     * @notice withdraw a bid on a punk
     * @param punkIndex punk index
     */
    function withdrawBidForPunk(uint256 punkIndex) external;

    /**
     * @notice enter a bid on a punk
     * @dev the bid amount is the msg.value attached to this call
     * @param punkIndex punk index
     */
    function enterBidForPunk(uint256 punkIndex) external payable;
}


// File: contracts/interfaces/curve/IStableSwap.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/**
 * @title Interface for Curve StableSwap pool
 */
interface IStableSwap {
    /**
     * @notice Perform an exchange between two underlying coins
     * @param i Index value for the underlying coin to send
     * @param j Index valie of the underlying coin to receive
     * @param _dx Amount of `i` being exchanged
     * @param _min_dy Minimum amount of `j` to receive
     * @return Actual amount of `j` received
     */
    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy
    ) external payable returns (uint256);

    /**
     * @notice Perform an exchange between two underlying coins
     * @param i Index value for the underlying coin to send
     * @param j Index valie of the underlying coin to receive
     * @param _dx Amount of `i` being exchanged
     * @param _min_dy Minimum amount of `j` to receive
     * @return Actual amount of `j` received
     */
    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy
    ) external payable returns (uint256);

    /**
     * @notice Deposit coins into the pool
     * @param _amounts List of amounts of coins to deposit
     * @param _min_mint_amount Minimum amount of LP tokens to mint from the deposit
     * @return amount of LP tokens received by depositing
     */
    function add_liquidity(
        uint256[2] memory _amounts,
        uint256 _min_mint_amount
    ) external returns (uint256);

    /**
     * @notice Withdraw a single coin from the pool
     * @param _burn_amount Amount of LP tokens to burn in the withdrawal
     * @param i Index value of the coin to withdraw
     * @param _min_received Minimum amount of coin to receive
     * @return Amount of coin received
     */
    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_received
    ) external payable returns (uint256);

    /**
     * @notice Calculate addition or reduction in token supply from a deposit or withdrawal
     * @dev This calculation accounts for slippage, but not fees.
     *      Needed to prevent front-running, not for precise calculations!
     * @param _amounts Amount of each underlying coin being deposited
     * @param _is_deposit set True for deposits, False for withdrawals
     * @return Expected amount of LP tokens received
     */
    function calc_token_amount(
        uint256[2] memory _amounts,
        bool _is_deposit
    ) external view returns (uint256);

    /**
     * @notice Calculate the amount received when withdrawing a single coin
     * @param _token_amount Amount of LP tokens to burn in the withdrawal
     * @param i Index value of the coin to withdraw
     * @return Amount of coin received
     */
    function calc_withdraw_one_coin(
        uint256 _token_amount,
        int128 i
    ) external view returns (uint256);

    /**
     * @notice The current virtual price of the pool LP token
     * @dev Useful for calculating profits
     * @return LP token virtual price normalized to 1e18
     */
    function get_virtual_price() external view returns (uint256);

    /**
     * @notice Get the amount received (“dy”) when swapping between two underlying assets within the pool.
     * @param i Index value of the token to send.
     * @param j Index value of the token to receive.
     * @param dx: The amount of i being exchanged.
     * @return amount of j received
     */
    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);
}


// File: contracts/interfaces/curve/ITriCrypto.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/**
 * @title interface for Curve TriCrypto (USDT, WBTC, WETH) pool
 */
interface ITriCrypto {
    /**
     * @notice Perform an exchange between two underlying coins
     * @param i Index value for the underlying coin to send
     * @param j Index valie of the underlying coin to receive
     * @param _dx Amount of `i` being exchanged
     * @param _min_dy Minimum amount of `j` to receive
     * @param use_eth boolean indicating whether ETH should be used in exchange
     * @return Actual amount of `j` received
     */
    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        bool use_eth
    ) external payable returns (uint256);
}


// File: contracts/interfaces/insrt/IDawnOfInsrt.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice Dawn of Insrt token collection interface
 */
interface IDawnOfInsrt {
    /**
     * @notice returns tier of given token
     * @param tokenId id of token to check
     * @return tier tier of tokenId
     */
    function tokenTier(uint256 tokenId) external view returns (uint8 tier);
}


// File: contracts/interfaces/jpegd/ILPFarming.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/**
 * @title Interface to jpeg'd LPFarming Contracts
 * @dev https://github.com/jpegd/core/blob/main/contracts/farming/LPFarming.sol
 * @dev Only whitelisted contracts may call these functions
 */
interface ILPFarming {
    /// @dev Data relative to an LP pool
    /// @param lpToken The LP token accepted by the pool
    /// @param allocPoint Allocation points assigned to the pool. Determines the share of `rewardPerBlock` allocated to this pool
    /// @param lastRewardBlock Last block number in which reward distribution occurred
    /// @param accRewardPerShare Accumulated rewards per share, times 1e36. The amount of rewards the pool has accumulated per unit of LP token deposited
    /// @param depositedAmount Total number of tokens deposited in the pool.
    struct PoolInfo {
        address lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
        uint256 depositedAmount;
    }

    /// @dev Data relative to a user's staking position
    /// @param amount The amount of LP tokens the user has provided
    /// @param lastAccRewardPerShare The `accRewardPerShare` pool value at the time of the user's last claim
    struct UserInfo {
        uint256 amount;
        uint256 lastAccRewardPerShare;
    }

    /**
     * @notice getter for poolInfo struct in  PoolInfo array of JPEGd LPFarming contract
     * @param index index of poolInfo in PoolInfo array
     * @return PoolInfo[] array of PoolInfo structs
     */
    function poolInfo(uint256 index) external view returns (PoolInfo memory);

    /**
     * @notice getter for the userInfo mapping in JPEGd LPFarming contract
     * @return UserInfo userInfo struct for user in JPEGd LPFarming pool with poolId
     */
    function userInfo(
        uint256 poolId,
        address user
    ) external view returns (UserInfo memory);

    /// @notice Frontend function used to calculate the amount of rewards `_user` can claim from the pool with id `_pid`
    /// @param _pid The pool id
    /// @param _user The address of the user
    /// @return The amount of rewards claimable from `_pid` by user `_user`
    function pendingReward(
        uint256 _pid,
        address _user
    ) external view returns (uint256);

    /// @notice Allows users to deposit `_amount` of LP tokens in the pool with id `_pid`. Non whitelisted contracts can't call this function
    /// @dev Emits a {Deposit} event
    /// @param _pid The id of the pool to deposit into
    /// @param _amount The amount of LP tokens to deposit
    function deposit(uint256 _pid, uint256 _amount) external;

    /// @notice Allows users to withdraw `_amount` of LP tokens from the pool with id `_pid`. Non whitelisted contracts can't call this function
    /// @dev Emits a {Withdraw} event
    /// @param _pid The id of the pool to withdraw from
    /// @param _amount The amount of LP tokens to withdraw
    function withdraw(uint256 _pid, uint256 _amount) external;

    /// @notice Allows users to claim rewards from the pool with id `_pid`. Non whitelisted contracts can't call this function
    /// @dev Emits a {Claim} event
    /// @param _pid The pool to claim rewards from
    function claim(uint256 _pid) external;

    /// @notice Allows users to claim rewards from all pools. Non whitelisted contracts can't call this function
    /// @dev Emits a {ClaimAll} event
    function claimAll() external;
}


// File: contracts/interfaces/jpegd/INFTEscrow.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/**
 * @title Interface to jpeg'd NFTEscrow Contracts
 * @dev https://github.com/jpegd/core/blob/main/contracts/escrow/NFTEscrow.sol
 */
interface INFTEscrow {
    /// @notice This function returns the address where user `_owner` should send the `_idx` NFT to
    /// @dev `precompute` computes the salt and the address relative to NFT at index `_idx` owned by `_owner`
    /// @param _owner The owner of the NFT at index `_idx`
    /// @param _idx The index of the NFT owner by `_owner`
    /// @return salt The salt that's going to be used to deploy the {FlashEscrow} instance
    /// @return predictedAddress The address where the {FlashEscrow} instance relative to `_owner` and `_idx` will be deployed to
    function precompute(
        address _owner,
        uint256 _idx
    ) external view returns (bytes32 salt, address predictedAddress);

    function nftContract() external view returns (address collection);
}


// File: contracts/interfaces/jpegd/INFTVault.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/**
 * @title Interface to jpeg'd NFTVault Contracts
 * @dev https://github.com/jpegd/core/blob/main/contracts/vaults/NFTVault.sol
 */
interface INFTVault {
    /// jpeg'd RATE struct
    struct Rate {
        uint128 numerator;
        uint128 denominator;
    }

    /// jpeg'd vault settings struct
    struct VaultSettings {
        Rate debtInterestApr;
        Rate creditLimitRate;
        Rate liquidationLimitRate;
        Rate cigStakedCreditLimitRate;
        Rate cigStakedLiquidationLimitRate;
        /// @custom:oz-renamed-from valueIncreaseLockRate
        Rate unused12;
        Rate organizationFeeRate;
        Rate insurancePurchaseRate;
        Rate insuranceLiquidationPenaltyRate;
        uint256 insuranceRepurchaseTimeLimit;
        uint256 borrowAmountCap;
    }

    /// jpeg'd vault BorrowType enum
    enum BorrowType {
        NOT_CONFIRMED,
        NON_INSURANCE,
        USE_INSURANCE
    }

    /// jpeg'd vault Position struct
    struct Position {
        BorrowType borrowType;
        uint256 debtPrincipal;
        uint256 debtPortion;
        uint256 debtAmountForRepurchase;
        uint256 liquidatedAt;
        address liquidator;
    }

    /// @notice Allows users to open positions and borrow using an NFT
    /// @dev emits a {Borrowed} event
    /// @param _nftIndex The index of the NFT to be used as collateral
    /// @param _amount The amount of PUSD to be borrowed. Note that the user will receive less than the amount requested,
    /// the borrow fee and insurance automatically get removed from the amount borrowed
    /// @param _useInsurance Whether to open an insured position. In case the position has already been opened previously,
    /// this parameter needs to match the previous insurance mode. To change insurance mode, a user needs to close and reopen the position
    function borrow(
        uint256 _nftIndex,
        uint256 _amount,
        bool _useInsurance
    ) external;

    /// @param _nftIndex The NFT to return the value of
    /// @return The value in USD of the NFT at index `_nftIndex`, with 18 decimals.
    function getNFTValueUSD(uint256 _nftIndex) external view returns (uint256);

    /// @param _nftIndex The NFT to return the credit limit of
    /// @return The PETH/PUSD credit limit of the NFT at index `_nftIndex`.
    function getCreditLimit(
        address _owner,
        uint256 _nftIndex
    ) external view returns (uint256);

    /**
     * @notice getter for jpegdVault settings
     * @return VaultSettings settings of jpegdVault
     */
    function settings() external view returns (VaultSettings memory);

    /**
     * @notice getter for owned of position opened in jpegdVault
     * @param tokenId NFT id mapping to position owner
     * @return address position owner address
     */
    function positionOwner(uint256 tokenId) external view returns (address);

    /// @param _nftIndex The NFT to check
    /// @return The PUSD debt interest accumulated by the NFT at index `_nftIndex`.
    function getDebtInterest(uint256 _nftIndex) external view returns (uint256);

    /// @return The floor value for the collection, in ETH.
    function getFloorETH() external view returns (uint256);

    /// @notice Allows users to repay a portion/all of their debt. Note that since interest increases every second,
    /// a user wanting to repay all of their debt should repay for an amount greater than their current debt to account for the
    /// additional interest while the repay transaction is pending, the contract will only take what's necessary to repay all the debt
    /// @dev Emits a {Repaid} event
    /// @param _nftIndex The NFT used as collateral for the position
    /// @param _amount The amount of debt to repay. If greater than the position's outstanding debt, only the amount necessary to repay all the debt will be taken
    function repay(uint256 _nftIndex, uint256 _amount) external;

    /// @notice Allows a user to close a position and get their collateral back, if the position's outstanding debt is 0
    /// @dev Emits a {PositionClosed} event
    /// @param _nftIndex The index of the NFT used as collateral
    function closePosition(uint256 _nftIndex) external;

    /**
     * @notice getter for position corresponding to tokenId
     * @param tokenId NFT id mapping to position
     * @return position corresponding to tokenId
     */
    function positions(uint256 tokenId) external view returns (Position memory);

    /**
     * @notice getter for total globabl debt in jpeg'd vault
     * @return uin256 total global debt
     */
    function totalDebtAmount() external view returns (uint256);

    /**
     * @notice getter for the JPEG'd NFT Value provider contract address
     * @return address of NFT Value provider
     */
    function nftValueProvider() external view returns (address);

    /// @param _nftIndex The NFT to return the liquidation limit of
    /// @return The PETH liquidation limit of the NFT at index `_nftIndex`.
    function getLiquidationLimit(
        address _owner,
        uint256 _nftIndex
    ) external view returns (uint256);

    /**
     * @notice returns underlying stablecoin (PETH/PUSD) of NFT Vault
     * @return coin address of PETH/PUSD
     */
    function stablecoin() external view returns (address coin);

    /**
     * @notice returns underlying ERC721 collection of NFT Vault
     * @return collection ERC721 collection address
     */
    function nftContract() external view returns (address collection);
}


// File: contracts/interfaces/jpegd/IVault.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/**
 * @title Interface to jpeg'd Vault Contracts
 * @dev https://github.com/jpegd/core/blob/main/contracts/vaults/erc20/Vault.sol
 * @dev Only whitelisted contracts may call these functions
 */
interface IVault {
    struct Rate {
        uint128 numerator;
        uint128 denominator;
    }

    /// @notice Allows users to deposit `token`. Contracts can't call this function
    /// @param _to The address to send the tokens to
    /// @param _amount The amount to deposit
    function deposit(
        address _to,
        uint256 _amount
    ) external returns (uint256 shares);

    /// @notice Allows users to withdraw tokens. Contracts can't call this function
    /// @param _to The address to send the tokens to
    /// @param _shares The amount of shares to burn
    function withdraw(
        address _to,
        uint256 _shares
    ) external returns (uint256 backingTokens);

    /// @return The underlying tokens per share
    function exchangeRate() external view returns (uint256);

    /// @return assets The total amount of tokens managed by this vault and the underlying strategy
    function totalAssets() external view returns (uint256 assets);

    /**
     * @notice custom getter for decimals of jpeg'd Vault underlying token
     * @return uint8 decimals of jpeg'd Vault underlying token
     */
    function decimals() external view returns (uint8);

    /**
     * @notice custom getter for depositFeeRate in jpeg'd citadel
     * @return Rate deposit fee rate
     */
    function depositFeeRate() external view returns (Rate memory);
}


// File: contracts/simple/ERC1155MetadataExtension.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { ERC1155MetadataExtensionInternal } from './ERC1155MetadataExtensionInternal.sol';
import { IERC1155MetadataExtension } from './IERC1155MetadataExtension.sol';

abstract contract ERC1155MetadataExtension is
    ERC1155MetadataExtensionInternal,
    IERC1155MetadataExtension
{
    /**
     * @notice inheritdoc IERC1155MetadataExtension
     */
    function name() external view virtual returns (string memory) {
        return _name();
    }

    /**
     * @notice inheritdoc IERC1155MetadataExtension
     */
    function symbol() external view virtual returns (string memory) {
        return _symbol();
    }
}


// File: contracts/simple/ERC1155MetadataExtensionInternal.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { ERC1155MetadataExtensionStorage } from './ERC1155MetadataExtensionStorage.sol';

abstract contract ERC1155MetadataExtensionInternal {
    /**
     * @notice sets a new name for ECR1155 collection
     * @param name name to set
     */
    function _setName(string memory name) internal {
        ERC1155MetadataExtensionStorage.layout().name = name;
    }

    /**
     * @notice sets a new symbol for ECR1155 collection
     * @param symbol symbol to set
     */
    function _setSymbol(string memory symbol) internal {
        ERC1155MetadataExtensionStorage.layout().symbol = symbol;
    }

    /**
     * @notice reads ERC1155 collcetion name
     * @return name ERC1155 collection name
     */
    function _name() internal view returns (string memory name) {
        name = ERC1155MetadataExtensionStorage.layout().name;
    }

    /**
     * @notice reads ERC1155 collcetion symbol
     * @return symbol ERC1155 collection symbol
     */
    function _symbol() internal view returns (string memory symbol) {
        symbol = ERC1155MetadataExtensionStorage.layout().symbol;
    }
}


// File: contracts/simple/ERC1155MetadataExtensionStorage.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

library ERC1155MetadataExtensionStorage {
    struct Layout {
        string name;
        string symbol;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('insrt.contracts.storage.ERC1155MetadataExtensionStorage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// File: contracts/simple/IERC1155MetadataExtension.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

interface IERC1155MetadataExtension {
    /**
     * @notice read ERC1155 collcetion name
     * @return ERC1155 collection  name
     */
    function name() external view returns (string memory);

    /**
     * @notice read ERC1155 collcetion symbol
     * @return ERC1155 collection  symbol
     */
    function symbol() external view returns (string memory);
}


// File: contracts/simple/ISimpleVaultBase.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC1155MetadataExtension } from './IERC1155MetadataExtension.sol';
import { ISolidStateERC1155 } from '@solidstate/contracts/token/ERC1155/ISolidStateERC1155.sol';

interface ISimpleVaultBase is ISolidStateERC1155, IERC1155MetadataExtension {}


// File: contracts/simple/ISimpleVaultInternal.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IOwnableInternal } from '@solidstate/contracts/access/ownable/IOwnableInternal.sol';

interface ISimpleVaultInternal is IOwnableInternal {
    /**
     * @notice indicates which lending adaptor is to be interacted with
     */
    enum LendingAdaptor {
        DEFAULT, //allows for passing an 'empty' adaptor argument in functions
        JPEGD
    }

    /**
     * @notice indicates which staking adaptor is to be interacted with
     */
    enum StakingAdaptor {
        DEFAULT, //allows for passing an 'empty' adaptor argument in functions
        JPEGD
    }

    /**
     * @notice encapsulates an amount of fees of a particular token
     */
    struct TokenFee {
        address token;
        uint256 fees;
    }

    /**
     * @notice encapsulates an amount of yield of a particular token
     */
    struct TokenYield {
        address token;
        uint256 yield;
    }

    /**
     * @notice encapsulates the cumulative amount of yield accrued of a paritcular token per shard
     */
    struct TokensPerShard {
        address token;
        uint256 cumulativeAmount;
    }

    /**
     * @notice thrown when function called by non-protocol owner
     */
    error SimpleVault__NotProtocolOwner();

    /**
     * @notice thrown when function called by account which is  non-authorized and non-protocol owner
     */
    error SimpleVault__NotAuthorized();

    /**
     * @notice thrown when the deposit amount is not a multiple of shardSize
     */
    error SimpleVault__InvalidDepositAmount();

    /**
     * @notice thrown when the maximum capital has been reached or vault has invested
     */
    error SimpleVault__DepositForbidden();

    /**
     * @notice thrown when attempting to call a disabled function
     */
    error SimpleVault__NotEnabled();

    /**
     * @notice thrown when user is attempting to deposit after owning (minting) max shards
     */
    error SimpleVault__MaxMintBalance();

    /**
     * @notice thrown when attempting to act without being whitelisted
     */
    error SimpleVault__NotWhitelisted();

    /**
     * @notice thrown when the maximum capital has been reached or vault has invested
     */
    error SimpleVault__WithdrawalForbidden();

    /**
     * @notice thrown when setting a basis point fee value larger than 10000
     */
    error SimpleVault__BasisExceeded();

    /**
     * @notice thrown when attempting to claim yield before yield claiming is initialized
     */
    error SimpleVault__YieldClaimingForbidden();

    /**
     * @notice thrown when attempting to set a reserved supply larger than max supply
     */
    error SimpleVault__ExceededMaxSupply();

    /**
     * @notice thrown when setting a max supply which is smaller than total supply
     */
    error SimpleVault__MaxSupplyTooSmall();

    /**
     * @notice thrown when the vault does not have enough ETH to account for an ETH transfer + respective fee
     */
    error SimpleVault__InsufficientETH();

    /**
     * @notice thrown when attempting to interact on a collection which is not part of the vault collections
     */
    error SimpleVault__NotCollectionOfVault();

    /**
     * @notice thrown when marking a token for sale which is not in ownedTokenIds
     */
    error SimpleVault__NotOwnedToken();

    /**
     * @notice thrown when attempting to sell an ERC721 token not marked for sale
     */
    error SimpleVault__TokenNotForSale();

    /**
     * @notice thrown when attempting to sell ERC1155 tokens not marked for sale
     */
    error SimpleVault__TokensNotForSale();

    /**
     * @notice thrown when an incorrect ETH amount is received during token sale
     */
    error SimpleVault__IncorrectETHReceived();

    /**
     * @notice thrown when attempted to mark a token for sale whilst it is collateralized
     */
    error SimpleVault__TokenCollateralized();

    /**
     * @notice thrown when attempting to discount yield fee with a DAWN_OF_INSRT token not
     * belonging to account yield fee is being discounted for
     */
    error SimpleVault__NotDawnOfInsrtTokenOwner();

    /**
     * @notice thrown when attempting to add a token to collectionOwnedTokens without vault being the token owner
     */
    error SimpleVault__NotTokenOwner();

    /**
     * @notice thrown when attempting to remove a token from collectionOwnedTokens with vault being the token owner
     */
    error SimpleVault__TokenStillOwned();

    /**
     * @notice emitted when an ERC721 is transferred from the treasury to the vault in exchange for ETH
     * @param tokenId id of ERC721 asset
     */
    event ERC721AssetTransferred(uint256 tokenId);

    /**
     * @notice emitted when ERC1155 assets are transferred from the treasury to the vault in exchange for ETH
     * @param tokenId id of ERC1155 assets
     * @param amount amount of ECR1155 assets
     */
    event ERC1155AssetsTransferred(uint256 tokenId, uint256 amount);

    /**
     * @notice emitted when protocol fees are withdrawn
     * @param tokenFees array of TokenFee structs indicating address of fee token and amount
     */
    event FeesWithdrawn(TokenFee[3] tokenFees);

    /**
     * @notice emitted when an ERC721 token is marked for sale
     * @param collection address of collection of token
     * @param tokenId id of token
     * @param price price in ETH of token
     */
    event TokenMarkedForSale(
        address collection,
        uint256 tokenId,
        uint256 price
    );

    /**
     * @notice emitted when ERC1155 tokens are marked for sale
     * @param collection address of collection of token
     * @param tokenId id of token
     * @param amount amount of token
     * @param price price in ETH of token
     */
    event TokensMarkedForSale(
        address collection,
        uint256 tokenId,
        uint256 amount,
        uint256 price
    );

    /**
     * @notice emitted when ERC1155 tokens are removed from sale
     * @param collection address of collection of token
     * @param tokenId id of token
     * @param amount amount of token
     * @param price price in ETH of token
     */
    event TokensRemovedFromSale(
        address collection,
        uint256 tokenId,
        uint256 amount,
        uint256 price
    );

    /**
     * @notice emitted when a token is sold (ERC721)
     * @param collection address of token collection
     * @param tokenId id of token
     */
    event TokenSold(address collection, uint256 tokenId);

    /**
     * @notice emitted when a token is sold (ERC1155)
     * @param collection address of token collection
     * @param tokenId id of token
     * @param amount amounts of token
     */
    event TokensSold(address collection, uint256 tokenId, uint256 amount);

    /**
     * @notice emitted when whitelistEndsAt is set
     * @param whitelistEndsAt the new whitelistEndsAt timestamp
     */
    event WhitelistEndsAtSet(uint48 whitelistEndsAt);

    /**
     * @notice emitted when reservedSupply is set
     * @param reservedSupply the new reservedSupply
     */
    event ReservedSupplySet(uint64 reservedSupply);

    /**
     * @notice emitted when isEnabled is set
     * @param isEnabled the new isEnabled value
     */
    event IsEnabledSet(bool isEnabled);

    /**
     * @notice emitted when maxMintBalance is set
     * @param maxMintBalance the new maxMintBalance
     */
    event MaxMintBalanceSet(uint64 maxMintBalance);

    /**
     * @notice emitted when maxSupply is set
     * @param maxSupply the new maxSupply
     */
    event MaxSupplySet(uint64 maxSupply);

    /**
     * @notice emitted when sale fee is set
     * @param feeBP the new sale fee basis points
     */
    event SaleFeeSet(uint16 feeBP);

    /**
     * @notice emitted when acquisition fee is set
     * @param feeBP the new acquisition fee basis points
     */
    event AcquisitionFeeSet(uint16 feeBP);

    /**
     * @notice emitted when yield fee is set
     * @param feeBP the new yield fee basis points
     */
    event YieldFeeSet(uint16 feeBP);

    /**
     * @notice emitted when ltvBufferBP is set
     * @param bufferBP new ltvBufferBP value
     */
    event LTVBufferSet(uint16 bufferBP);

    /**
     * @notice emitted when ltvDeviationBP is set
     * @param deviationBP new ltvDeviationBP value
     */
    event LTVDeviationSet(uint16 deviationBP);

    /**
     * @notice emitted when a collection is removed from vault collections
     * @param collection address of removed collection
     */
    event CollectionRemoved(address collection);

    /**
     * @notice emitted when a collection is added to vault collections
     * @param collection address of added collection
     */
    event CollectionAdded(address collection);

    /**
     * @notice emitted when an owned token is added to a collection manually
     * @param collection collection address
     * @param tokenId tokenId
     */
    event OwnedTokenAddedToCollection(address collection, uint256 tokenId);

    /**
     * @notice emitted when an owned token is removed from a collection manually
     * @param collection collection address
     * @param tokenId tokenId
     */
    event OwnedTokenRemovedFromCollection(address collection, uint256 tokenId);

    /**
     * @notice emmitted when the 'authorized' state is granted to or revoked from an account
     * @param account address of account to grant/revoke 'authorized'
     * @param isAuthorized value of 'authorized' state
     */
    event AuthorizedSet(address account, bool isAuthorized);

    /**
     * @notice emitted when an ERC721 asset is collateralized in a lending vendor
     * @param adaptor enum indicating which lending vendor adaptor was used
     * @param collection address of ERC721 collection
     * @param tokenId id of token
     */
    event ERC721AssetCollateralized(
        LendingAdaptor adaptor,
        address collection,
        uint256 tokenId
    );

    /**
     * @notice emitted when lending vendor tokens received for collateralizing and asset
     *  are staked in a lending vendor
     * @param adaptor enum indicating which lending vendor adaptor was used
     * @param shares lending vendor shares received after staking, if any
     */
    event Staked(StakingAdaptor adaptor, uint256 shares);

    /**
     * @notice emitted when a position in a lending vendor is unstaked and converted back
     * to the tokens which were initially staked
     * @param adaptor enum indicating which lending vendor adaptor was used
     * @param tokenAmount amount of tokens received for unstaking
     */
    event Unstaked(StakingAdaptor adaptor, uint256 tokenAmount);

    /**
     * @notice emitted when a certain amount of the staked position in a lending vendor is
     * unstaked and converted to tokens to be provided as yield
     * @param adaptor enum indicating which lending vendor adaptor was used
     * @param tokenYields array of token addresses and corresponding yields provided
     */
    event YieldProvided(StakingAdaptor adaptor, TokenYield[] tokenYields);

    /**
     * @notice emitted when a loan repayment is made for a collateralized position
     * @param adaptor enum indicating which lending vendor adaptor was used
     * @param paidDebt amount of debt repaid
     */
    event LoanPaymentMade(LendingAdaptor adaptor, uint256 paidDebt);

    /**
     * @notice emitted when a loan is repaid in full and the position is closed
     * @param adaptor enum indicating which lending vendor adaptor was used
     * @param receivedETH amount of ETH received after closing position
     */
    event PositionClosed(LendingAdaptor adaptor, uint256 receivedETH);

    /**
     * @notice emitted when a punk is purchasd from the CryptoPunkMarket
     * @param punkId id of punk purchased
     */
    event PunkPurchased(uint256 punkId);

    /**
     * @notice emitted when a punk is listed for sale on the CryptoPunkMarket
     * @param punkId id of punk listed
     * @param minValue minimum ETH value accepted for instantaneous purchase
     */
    event PunkListed(uint256 punkId, uint256 minValue);

    /**
     * @notice emitted when a punk is delisted from sale from the CryptoPunkMarket
     * @param punkId id of punk delisted
     */
    event PunkDelisted(uint256 punkId);

    /**
     * @notice emitted when a bid is accepted on a listed punk and it is sold on the CryptoPunkMarket
     * @param punkId id of punk sold
     */
    event PunkSold(uint256 punkId);

    /**
     * @notice emitted when proceeds from punk sales on the CryptoPunkMarket are received
     * @param proceeds amount of proceeds received
     */
    event PunkProceedsReceived(uint256 proceeds);
}


// File: contracts/simple/SimpleVaultBase.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import 'operator-filter-registry/src/DefaultOperatorFilterer.sol';
import { ERC1155BaseInternal } from '@solidstate/contracts/token/ERC1155/base/ERC1155BaseInternal.sol';
import { ERC1155EnumerableInternal } from '@solidstate/contracts/token/ERC1155/enumerable/ERC1155EnumerableInternal.sol';
import { ERC1155Base } from '@solidstate/contracts/token/ERC1155/base/ERC1155Base.sol';
import { ERC1155Enumerable } from '@solidstate/contracts/token/ERC1155/enumerable/ERC1155Enumerable.sol';
import { ERC1155Metadata } from '@solidstate/contracts/token/ERC1155/metadata/ERC1155Metadata.sol';
import { ERC165Base } from '@solidstate/contracts/introspection/ERC165/base/ERC165Base.sol';
import { IERC721Receiver } from '@solidstate/contracts/interfaces/IERC721Receiver.sol';
import { IERC1155Receiver } from '@solidstate/contracts/interfaces/IERC1155Receiver.sol';
import { IERC1155 } from '@solidstate/contracts/interfaces/IERC1155.sol';

import { ERC1155MetadataExtension } from './ERC1155MetadataExtension.sol';
import { ISimpleVaultBase } from './ISimpleVaultBase.sol';
import { SimpleVaultInternal } from './SimpleVaultInternal.sol';

contract SimpleVaultBase is
    DefaultOperatorFilterer,
    SimpleVaultInternal,
    ISimpleVaultBase,
    IERC721Receiver,
    IERC1155Receiver,
    ERC1155Base,
    ERC1155Enumerable,
    ERC1155Metadata,
    ERC1155MetadataExtension,
    ERC165Base
{
    constructor(
        address feeRecipient,
        address dawnOfInsrt
    ) SimpleVaultInternal(feeRecipient, dawnOfInsrt) {}

    /**
     * @inheritdoc ERC1155BaseInternal
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
        override(
            ERC1155BaseInternal,
            ERC1155EnumerableInternal,
            SimpleVaultInternal
        )
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /**
     * @inheritdoc ERC1155Base
     * @notice adds OpenSea DefaultFilterer modifier
     */
    function setApprovalForAll(
        address operator,
        bool approved
    )
        public
        virtual
        override(ERC1155Base, IERC1155)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @inheritdoc ERC1155Base
     * @notice adds OpenSea DefaultFilterer modifier
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) public virtual override(ERC1155Base, IERC1155) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    /**
     * @inheritdoc ERC1155Base
     * @notice adds OpenSea DefaultFilterer modifier
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override(ERC1155Base, IERC1155) onlyAllowedOperator(from) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}


// File: contracts/simple/SimpleVaultInternal.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { AddressUtils } from '@solidstate/contracts/utils/AddressUtils.sol';
import { EnumerableSet } from '@solidstate/contracts/data/EnumerableSet.sol';
import { ERC1155BaseInternal } from '@solidstate/contracts/token/ERC1155/base/ERC1155BaseInternal.sol';
import { ERC1155EnumerableInternal } from '@solidstate/contracts/token/ERC1155/enumerable/ERC1155EnumerableInternal.sol';
import { ERC1155MetadataInternal } from '@solidstate/contracts/token/ERC1155/metadata/ERC1155MetadataInternal.sol';
import { IERC173 } from '@solidstate/contracts/interfaces/IERC173.sol';
import { IERC20 } from '@solidstate/contracts/interfaces/IERC20.sol';
import { IERC721 } from '@solidstate/contracts/interfaces/IERC721.sol';
import { IERC1155 } from '@solidstate/contracts/interfaces/IERC1155.sol';
import { OwnableInternal } from '@solidstate/contracts/access/ownable/OwnableInternal.sol';

import { SimpleVaultStorage as s } from './SimpleVaultStorage.sol';
import { ISimpleVaultInternal } from './ISimpleVaultInternal.sol';
import { JPEGDLendingAdaptor as JPEGDLending } from '../adaptors/lending/JPEGDLendingAdaptor.sol';
import { JPEGDStakingAdaptor as JPEGDStaking } from '../adaptors/staking/JPEGDStakingAdaptor.sol';
import { JPEGDAdaptorStorage } from '../adaptors/storage/JPEGDAdaptorStorage.sol';
import { ICryptoPunkMarket } from '../interfaces/cryptopunk/ICryptoPunkMarket.sol';
import { IDawnOfInsrt } from '../interfaces/insrt/IDawnOfInsrt.sol';
import { IWhitelist } from '../whitelist/IWhitelist.sol';

/**
 * @title SimpleVault internal functions
 * @dev inherited by all SimpleVault implementation contracts
 */
abstract contract SimpleVaultInternal is
    ISimpleVaultInternal,
    OwnableInternal,
    ERC1155BaseInternal,
    ERC1155EnumerableInternal,
    ERC1155MetadataInternal
{
    using AddressUtils for address payable;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal immutable TREASURY;
    address internal immutable DAWN_OF_INSRT;
    uint256 internal constant MINT_TOKEN_ID = 1;
    uint256 internal constant BASIS_POINTS = 10000;
    uint256 internal constant DAWN_OF_INSRT_ZERO_BALANCE = type(uint256).max;
    uint256 internal constant TIER0_FEE_COEFFICIENT = 9000;
    uint256 internal constant TIER1_FEE_COEFFICIENT = 7500;
    uint256 internal constant TIER2_FEE_COEFFICIENT = 6000;
    uint256 internal constant TIER3_FEE_COEFFICIENT = 4000;
    uint256 internal constant TIER4_FEE_COEFFICIENT = 2000;

    constructor(address feeRecipient, address dawnOfInsrt) {
        TREASURY = feeRecipient;
        DAWN_OF_INSRT = dawnOfInsrt;
    }

    modifier onlyProtocolOwner() {
        _onlyProtocolOwner(msg.sender);
        _;
    }

    modifier onlyAuthorized() {
        _onlyAuthorized(msg.sender);
        _;
    }

    /**
     * @notice returns the protocol owner
     * @return address of the protocol owner
     */
    function _protocolOwner() internal view returns (address) {
        return IERC173(_owner()).owner();
    }

    function _onlyProtocolOwner(address account) internal view {
        if (account != _protocolOwner()) {
            revert SimpleVault__NotProtocolOwner();
        }
    }

    function _onlyAuthorized(address account) internal view {
        if (
            account != _protocolOwner() &&
            s.layout().isAuthorized[account] == false
        ) {
            revert SimpleVault__NotAuthorized();
        }
    }

    /**
     * @notice transfers an ETH amount to the vault in exchange for ERC1155 shards of MINT_TOKEN_ID
     * @param data any encoded data required to perform whitelist check
     */
    function _deposit(bytes calldata data) internal {
        s.Layout storage l = s.layout();

        if (!l.isEnabled) {
            revert SimpleVault__NotEnabled();
        }

        uint64 maxSupply = l.maxSupply;
        uint64 maxMintBalance = l.maxMintBalance;
        uint256 balance = _balanceOf(msg.sender, MINT_TOKEN_ID);

        if (balance >= maxMintBalance) {
            revert SimpleVault__MaxMintBalance();
        }

        if (block.timestamp < l.whitelistEndsAt) {
            _enforceWhitelist(l.whitelist, msg.sender, data);
            maxSupply = l.reservedSupply;
        }

        uint256 amount = msg.value;
        uint256 shardValue = l.shardValue;
        uint256 totalSupply = _totalSupply(MINT_TOKEN_ID); //supply of token ID == 1

        if (amount % shardValue != 0 || amount == 0) {
            revert SimpleVault__InvalidDepositAmount();
        }
        if (totalSupply == maxSupply) {
            revert SimpleVault__DepositForbidden();
        }

        uint256 shards = amount / shardValue;
        uint256 excessShards;

        if (balance + shards > maxMintBalance) {
            excessShards = shards + balance - maxMintBalance;
            shards -= excessShards;
        }

        if (shards + totalSupply > maxSupply) {
            excessShards += shards + totalSupply - maxSupply;
            shards = maxSupply - totalSupply;
        }

        _mint(msg.sender, MINT_TOKEN_ID, shards, '0x');

        if (excessShards > 0) {
            payable(msg.sender).sendValue(excessShards * shardValue);
        }
    }

    /**
     * @notice burn held shards before NFT acquisition and withdraw corresponding ETH
     * @param amount amount of shards to burn
     */
    function _withdraw(uint256 amount) internal {
        s.Layout storage l = s.layout();

        if (_totalSupply(MINT_TOKEN_ID) == l.maxSupply) {
            revert SimpleVault__WithdrawalForbidden();
        }

        _burn(msg.sender, MINT_TOKEN_ID, amount);
        payable(msg.sender).sendValue(amount * l.shardValue);
    }

    /**
     * @notice claims ETH and vendor token rewards for msg.sender
     * @param tokenId DAWN_OF_INSRT tokenId to claim with for discounting yield fee
     */
    function _claim(uint256 tokenId) internal {
        s.Layout storage l = s.layout();

        _updateUserRewards(msg.sender, tokenId);

        uint256 yield = l.userETHYield[msg.sender];
        delete l.userETHYield[msg.sender];

        if (l.activatedLendingAdaptors[LendingAdaptor.JPEGD]) {
            JPEGDLending.userClaim(msg.sender);
        }

        payable(msg.sender).sendValue(yield);
    }

    /**
     * @notice collateralizes an ERC721 asset on a lending vendor in exchange for lending
     * lending vendor tokens
     * @param adaptor enum indicating which lending vendor to interact with via the respective adaptor
     * @param collateralizationData encoded data needed to collateralize the ERC721 asset
     * @return amount amount of lending vendor token borrowed
     */
    function _collateralizeERC721Asset(
        LendingAdaptor adaptor,
        bytes calldata collateralizationData
    ) internal returns (uint256 amount) {
        s.Layout storage l = s.layout();
        uint16 ltvBufferBP = l.ltvBufferBP;
        uint16 ltvDeviationBP = l.ltvDeviationBP;
        address collection;
        uint256 tokenId;

        if (adaptor == LendingAdaptor.JPEGD) {
            (collection, tokenId, amount) = JPEGDLending
                .collateralizeERC721Asset(
                    collateralizationData,
                    ltvBufferBP,
                    ltvDeviationBP
                );
        }

        l.collateralizedTokens[collection].add(tokenId);

        if (!l.activatedLendingAdaptors[adaptor]) {
            l.activatedLendingAdaptors[adaptor] = true;
        }

        emit ERC721AssetCollateralized(adaptor, collection, tokenId);
    }

    /**
     * @notice performs a staking sequence on a given adaptor
     * @param adaptor enum indicating which adaptor will perform staking
     * @param stakeData encoded data required in order to perform staking
     * @return shares amount of staking shares received, if any
     */
    function _stake(
        StakingAdaptor adaptor,
        bytes calldata stakeData
    ) internal returns (uint256 shares) {
        s.Layout storage l = s.layout();

        if (adaptor == StakingAdaptor.JPEGD) {
            shares = JPEGDStaking.stake(stakeData);
        }

        if (l.activatedStakingAdaptors[adaptor]) {
            l.activatedStakingAdaptors[adaptor] = true;
        }

        emit Staked(adaptor, shares);
    }

    /**
     * @notice unstakes part or all of position from the protocol relating to the adaptor
     * @param adaptor adaptor to use in order to unstake
     * @param unstakeData encoded data required to perform unstaking steps
     * @return tokenAmount amount of tokens returns for unstaking
     */
    function _unstake(
        StakingAdaptor adaptor,
        bytes calldata unstakeData
    ) internal returns (uint256 tokenAmount) {
        if (adaptor == StakingAdaptor.JPEGD) {
            tokenAmount = JPEGDStaking.unstake(unstakeData);
        }

        emit Unstaked(adaptor, tokenAmount);
    }

    /**
     * @notice repays part of the loan owed to a lending vendor for a collateralized position
     * @param adaptor adaptor to use in order to repay loan
     * @param repayData encoded data required to pay back loan portion
     * @return paidDebt amount of debt repaid
     */
    function _repayLoan(
        LendingAdaptor adaptor,
        bytes calldata repayData
    ) internal returns (uint256 paidDebt) {
        if (adaptor == LendingAdaptor.JPEGD) {
            paidDebt = JPEGDLending.repayLoan(repayData);
        }

        emit LoanPaymentMade(adaptor, paidDebt);
    }

    /**
     * @notice liquidates entire position in a lending vendor in order to pay back debt
     * and converts any surplus ETH and reward tokens into yield
     * @param adaptor adaptor to use in order to close position
     * @param closeData encoded data required to close lending vendor position
     * @return eth amount of ETH received after closing position
     */
    function _closePosition(
        LendingAdaptor adaptor,
        bytes calldata closeData
    ) internal returns (uint256 eth) {
        s.Layout storage l = s.layout();

        address collection;
        uint256 tokenId;

        if (adaptor == LendingAdaptor.JPEGD) {
            (eth, collection, tokenId) = JPEGDLending.closePosition(closeData);
        }

        l.collateralizedTokens[collection].remove(tokenId);
        l.cumulativeETHPerShard += eth / _totalSupply(MINT_TOKEN_ID);

        emit PositionClosed(adaptor, eth);
    }

    /**
     * @notice makes loan repayment for a collateralized ERC721 asset using vault funds
     * @param adaptor adaptor to use in order to make loan repayment
     * @param directRepayData encoded data needed to directly repay loan
     */
    function _directRepayLoan(
        LendingAdaptor adaptor,
        bytes calldata directRepayData
    ) internal returns (uint256 paidDebt) {
        if (adaptor == LendingAdaptor.JPEGD) {
            paidDebt = JPEGDLending.directRepayLoan(directRepayData);
        }

        emit LoanPaymentMade(adaptor, paidDebt);
    }

    /**
     * @notice converts part of position and/or claims rewards to provide as yield to users
     * @param adaptor adaptor to use in order liquidate convert part of position and/or claim rewards
     * @param unstakeData encoded data required in order to perform unstaking of position and reward claiming
     */
    function _provideYield(
        StakingAdaptor adaptor,
        bytes memory unstakeData
    ) internal {
        s.Layout storage l = s.layout();

        TokenYield[] memory tokenYields = new TokenYield[](5);
        uint256 totalSupply = _totalSupply(MINT_TOKEN_ID);
        uint256 receivedETH;

        if (adaptor == StakingAdaptor.JPEGD) {
            uint256 receivedJPEG;
            (receivedETH, receivedJPEG) = JPEGDStaking.provideYield(
                unstakeData,
                totalSupply
            );

            tokenYields[0] = TokenYield({
                token: address(0),
                yield: receivedETH
            });
            tokenYields[1] = TokenYield({
                token: JPEGDAdaptorStorage.JPEG,
                yield: receivedJPEG
            });
        }

        l.cumulativeETHPerShard += receivedETH / totalSupply;

        if (!l.isYieldClaiming) {
            l.isYieldClaiming = true;
        }

        emit YieldProvided(adaptor, tokenYields);
    }

    /**
     * @notice transfers an ERC721 asset from the TREASURY in an "over-the-counter" (OTC) fashion
     * @param collection address of ERC721 collection
     * @param tokenId id of ERC721 asset to transfer
     * @param price amount of ETH to send to TREASURY in exchange for ERC721 asset
     */
    function _transferERC721AssetOTC(
        address collection,
        uint256 tokenId,
        uint256 price
    ) internal {
        s.Layout storage l = s.layout();

        if (!l.vaultCollections.contains(collection)) {
            revert SimpleVault__NotCollectionOfVault();
        }

        IERC721(collection).safeTransferFrom(TREASURY, address(this), tokenId);

        uint256 fee = (price * l.acquisitionFeeBP) / BASIS_POINTS;
        if (fee + price > address(this).balance) {
            revert SimpleVault__InsufficientETH();
        }

        if (_ownedTokenAmount() == 0) {
            l.maxSupply = uint64(_totalSupply(MINT_TOKEN_ID));
        }
        l.accruedFees += fee;
        l.collectionOwnedTokenIds[collection].add(tokenId);
        ++l.ownedTokenAmount;

        payable(TREASURY).sendValue(price);

        emit ERC721AssetTransferred(tokenId);
    }

    /**
     * @notice transfers an amount of ERC1155 assets from the TREASURY in an "over-the-counter" (OTC) fashion
     * @param collection address of ERC1155 collection
     * @param tokenId id of ERC155 asset to transfer
     * @param amount amount of ERC1155 assets to transfer
     * @param price amount of ETH to send to TREASURY in exchange for ERC1155 assets
     */
    function _transferERC1155AssetOTC(
        address collection,
        uint256 tokenId,
        uint256 amount,
        uint256 price
    ) internal {
        s.Layout storage l = s.layout();

        if (!l.vaultCollections.contains(collection)) {
            revert SimpleVault__NotCollectionOfVault();
        }

        IERC1155(collection).safeTransferFrom(
            TREASURY,
            address(this),
            tokenId,
            amount,
            '0x'
        );

        uint256 fee = (price * l.acquisitionFeeBP) / BASIS_POINTS;
        if (fee + price > address(this).balance) {
            revert SimpleVault__InsufficientETH();
        }

        if (_ownedTokenAmount() == 0) {
            l.maxSupply = uint64(_totalSupply(MINT_TOKEN_ID));
        }

        l.accruedFees += fee;
        l.collectionOwnedTokenIds[collection].add(tokenId);
        l.collectionOwnedTokenAmounts[collection][tokenId] += amount;
        ++l.ownedTokenAmount;

        payable(TREASURY).sendValue(price);

        emit ERC1155AssetsTransferred(tokenId, amount);
    }

    /**
     * @notice purchases a punk from the CryptoPunkMarket
     * @param punkMarket address of CryptoPunkMarket contract
     * @param punkId id of punk to purchase
     */
    function _purchasePunk(address punkMarket, uint256 punkId) internal {
        s.Layout storage l = s.layout();

        uint256 price = ICryptoPunkMarket(punkMarket)
            .punksOfferedForSale(punkId)
            .minValue;

        ICryptoPunkMarket(punkMarket).buyPunk{ value: price }(punkId);

        l.accruedFees += (price * l.acquisitionFeeBP) / BASIS_POINTS;
        l.collectionOwnedTokenIds[punkMarket].add(punkId);

        emit PunkPurchased(punkId);
    }

    /**
     * @notice lists a punk for sale on the CryptoPunkMarket
     * @param punkMarket CryptoPunkMarket contract address
     * @param punkId id of punk to list for sale
     * @param minValue minimum amount of ETH to accept for an instant sale
     */
    function _listPunk(
        address punkMarket,
        uint256 punkId,
        uint256 minValue
    ) internal {
        ICryptoPunkMarket(punkMarket).offerPunkForSale(punkId, minValue);

        emit PunkListed(punkId, minValue);
    }

    /**
     * @notice delists a punk listed for sale on CryptoPunkMarket
     * @param punkMarket CryptoPunkMarket contract address
     * @param punkId id of punk to delist
     */
    function _delistPunk(address punkMarket, uint256 punkId) internal {
        ICryptoPunkMarket(punkMarket).punkNoLongerForSale(punkId);

        emit PunkDelisted(punkId);
    }

    /**
     * @notice sells a punk  on the CryptoPunkMarket assuming there is an active bid on it
     * @param punkMarket CryptoPunkMarket contract address
     * @param punkId id of punk to list for sale
     * @param minValue minimum amount of ETH to accept for an instant sale
     */
    function _sellPunk(
        address punkMarket,
        uint256 punkId,
        uint256 minValue
    ) internal {
        s.Layout storage l = s.layout();

        uint256 oldBalance = address(this).balance;

        ICryptoPunkMarket(punkMarket).acceptBidForPunk(punkId, minValue);
        ICryptoPunkMarket(punkMarket).withdraw();

        uint256 proceeds = address(this).balance - oldBalance;

        l.accruedFees += (proceeds * l.saleFeeBP) / BASIS_POINTS;
        l.collectionOwnedTokenIds[punkMarket].remove(punkId);

        emit PunkSold(punkId);
        emit PunkProceedsReceived(proceeds);
    }

    /**
     * @notice receives all proceeds from punk sales on CryptoPunkMarket which were not initiated
     * by vault
     * @param punkMarket address of CryptoPunkMarket contract
     * @param punkIds array of punkIds which were sol
     */
    function _receivePunkProceeds(
        address punkMarket,
        uint256[] memory punkIds
    ) internal {
        s.Layout storage l = s.layout();

        uint256 oldBalance = address(this).balance;

        ICryptoPunkMarket(punkMarket).withdraw();

        uint256 proceeds = address(this).balance - oldBalance;

        for (uint256 i; i < punkIds.length; ++i) {
            l.collectionOwnedTokenIds[punkMarket].remove(punkIds[i]);
        }

        l.accruedFees += (proceeds * l.saleFeeBP) / BASIS_POINTS;

        emit PunkProceedsReceived(proceeds);
    }

    /**
     * @notice mark a vault owned ERC721 asset (token) as available for purchase
     * @param collection address of token collection
     * @param tokenId id of token
     * @param price sale price of token
     */
    function _markERC721AssetForSale(
        address collection,
        uint256 tokenId,
        uint256 price
    ) internal {
        s.Layout storage l = s.layout();

        if (!l.collectionOwnedTokenIds[collection].contains(tokenId)) {
            revert SimpleVault__NotOwnedToken();
        }
        if (l.collateralizedTokens[collection].contains(tokenId)) {
            revert SimpleVault__TokenCollateralized();
        }

        l.priceOfSale[collection][tokenId] = price;

        emit TokenMarkedForSale(collection, tokenId, price);
    }

    /**
     * @notice mark vault owned ERC1155 assets (token) as available for purchase
     * @param collection address of token collection
     * @param tokenId id of tokens
     * @param amount amount of tokens
     * @param price sale price of tokens
     */
    function _markERC1155AssetsForSale(
        address collection,
        uint256 tokenId,
        uint256 amount,
        uint256 price
    ) internal {
        s.Layout storage l = s.layout();

        if (!l.collectionOwnedTokenIds[collection].contains(tokenId)) {
            revert SimpleVault__NotOwnedToken();
        }
        if (l.collateralizedTokens[collection].contains(tokenId)) {
            revert SimpleVault__TokenCollateralized();
        }

        l.priceOfSales[collection][tokenId][amount].add(price);

        emit TokensMarkedForSale(collection, tokenId, amount, price);
    }

    /**
     * @notice remove the price of sales from ERC1155 assets marked for sale
     * @param collection address of ERC1155 collection
     * @param tokenId id of ERC1155 assets
     * @param amount amount of ERC1155 assets
     * @param price price to remove
     */
    function _removeERC1155AssetsFromSale(
        address collection,
        uint256 tokenId,
        uint256 amount,
        uint256 price
    ) internal {
        s.Layout storage l = s.layout();

        if (!l.priceOfSales[collection][tokenId][amount].contains(price)) {
            revert SimpleVault__TokensNotForSale();
        }

        l.priceOfSales[collection][tokenId][amount].remove(price);

        emit TokensRemovedFromSale(collection, tokenId, amount, price);
    }

    /**
     * @notice sells an ERC721 asset (token) to msg.sender
     * @param collection collection address of token
     * @param tokenId id of token to sell
     */
    function _buyERC721Asset(address collection, uint256 tokenId) internal {
        s.Layout storage l = s.layout();
        uint256 price = l.priceOfSale[collection][tokenId];

        if (price == 0) {
            revert SimpleVault__TokenNotForSale();
        }
        if (msg.value != price) {
            revert SimpleVault__IncorrectETHReceived();
        }

        uint256 fees = (price * l.saleFeeBP) / BASIS_POINTS;
        l.accruedFees += fees;
        l.cumulativeETHPerShard += (price - fees) / _totalSupply(MINT_TOKEN_ID);
        l.collectionOwnedTokenIds[collection].remove(tokenId);
        --l.ownedTokenAmount;
        delete l.priceOfSale[collection][tokenId];

        if (_ownedTokenAmount() == 0) {
            l.isYieldClaiming = true;
        }

        IERC721(collection).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );

        emit TokenSold(collection, tokenId);
    }

    /**
     * @notice sells an amount of ERC1155  assets (token) to msg.sender
     * @param collection collection address of token
     * @param tokenId id of token to sell
     * @param amount amount of tokens to sell
     * @param price price of sales of ECR1155 assets
     */
    function _buyERC1155Assets(
        address collection,
        uint256 tokenId,
        uint256 amount,
        uint256 price
    ) internal {
        s.Layout storage l = s.layout();

        if (!l.priceOfSales[collection][tokenId][amount].contains(price)) {
            revert SimpleVault__TokensNotForSale();
        }
        if (msg.value != price) {
            revert SimpleVault__IncorrectETHReceived();
        }

        uint256 fees = (price * l.saleFeeBP) / BASIS_POINTS;
        l.accruedFees += fees;
        l.cumulativeETHPerShard += (price - fees) / _totalSupply(MINT_TOKEN_ID);
        l.collectionOwnedTokenAmounts[collection][tokenId] -= amount;

        if (l.collectionOwnedTokenAmounts[collection][tokenId] == 0) {
            --l.ownedTokenAmount;
        }

        if (_ownedTokenAmount() == 0) {
            l.isYieldClaiming = true;
        }

        l.priceOfSales[collection][tokenId][amount].remove(price);

        IERC1155(collection).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            amount,
            '0x'
        );

        emit TokensSold(collection, tokenId, amount);
    }

    /**
     * @notice withdraw accrued protocol fees, and send to TREASURY address
     * @param adaptor enum indicating which adaptor to withdraw fees from
     * @return tokenFees an array of all the different fees withdrawn from the adaptor - currently supports up to 3 different tokens
     */
    function _withdrawFees(
        LendingAdaptor adaptor
    ) internal returns (TokenFee[3] memory tokenFees) {
        if (adaptor == LendingAdaptor.JPEGD) {
            tokenFees[0] = TokenFee({
                token: JPEGDAdaptorStorage.JPEG,
                fees: JPEGDLending.withdrawFees(TREASURY)
            });
        }

        if (adaptor == LendingAdaptor.DEFAULT) {
            s.Layout storage l = s.layout();

            uint256 fees = l.accruedFees;
            delete l.accruedFees;

            tokenFees[0] = TokenFee({ token: address(0), fees: fees });

            payable(TREASURY).sendValue(fees);
        }

        emit FeesWithdrawn(tokenFees);
    }

    /**
     * @notice sets the tokenURI for the MINT_TOKEN
     * @param tokenURI URI string
     */
    function _setMintTokenURI(string memory tokenURI) internal {
        _setTokenURI(MINT_TOKEN_ID, tokenURI);
    }

    /**
     * @notice sets the isEnabled flag
     * @param isEnabled boolean value
     */
    function _setIsEnabled(bool isEnabled) internal {
        s.layout().isEnabled = isEnabled;
        emit IsEnabledSet(isEnabled);
    }

    /**
     * @notice sets the maxSupply of shards
     * @param maxSupply the maxSupply of shards
     */
    function _setMaxSupply(uint64 maxSupply) internal {
        if (maxSupply < _totalSupply(MINT_TOKEN_ID)) {
            revert SimpleVault__MaxSupplyTooSmall();
        }
        s.layout().maxSupply = maxSupply;

        emit MaxSupplySet(maxSupply);
    }

    /**
     * @notice return the maximum shards a user is allowed to mint; theoretically a user may acquire more than this amount via transfers,
     * but once this amount is exceeded said user may not deposit more
     * @param maxMintBalance new maxMintBalance value
     */
    function _setMaxMintBalance(uint64 maxMintBalance) internal {
        s.layout().maxMintBalance = maxMintBalance;
        emit MaxMintBalanceSet(maxMintBalance);
    }

    /**
     * @notice sets the whitelistEndsAt timestamp
     * @param whitelistEndsAt timestamp of whitelist end
     */
    function _setWhitelistEndsAt(uint48 whitelistEndsAt) internal {
        s.layout().whitelistEndsAt = whitelistEndsAt;
        emit WhitelistEndsAtSet(whitelistEndsAt);
    }

    /**
     * @notice sets the maximum amount of shard to be minted during whitelist
     * @param reservedSupply whitelist shard amount
     */
    function _setReservedSupply(uint64 reservedSupply) internal {
        s.Layout storage l = s.layout();

        if (l.maxSupply < reservedSupply) {
            revert SimpleVault__ExceededMaxSupply();
        }

        l.reservedSupply = reservedSupply;
        emit ReservedSupplySet(reservedSupply);
    }

    /**
     * @notice sets the sale fee BP
     * @param feeBP basis points value of fee
     */
    function _setSaleFee(uint16 feeBP) internal {
        _enforceBasis(feeBP);
        s.layout().saleFeeBP = feeBP;
        emit SaleFeeSet(feeBP);
    }

    /**
     * @notice sets the acquisition fee BP
     * @param feeBP basis points value of fee
     */
    function _setAcquisitionFee(uint16 feeBP) internal {
        _enforceBasis(feeBP);
        s.layout().acquisitionFeeBP = feeBP;
        emit AcquisitionFeeSet(feeBP);
    }

    /**
     * @notice sets the yield fee BP
     * @param feeBP basis poitns value of fee
     */
    function _setYieldFee(uint16 feeBP) internal {
        _enforceBasis(feeBP);
        s.layout().yieldFeeBP = feeBP;
        emit YieldFeeSet(feeBP);
    }

    /**
     * @notice sets the ltvBufferBP value
     * @param bufferBP new ltvBufferBP value
     */
    function _setLTVBufferBP(uint16 bufferBP) internal {
        _enforceBasis(bufferBP);
        s.layout().ltvBufferBP = bufferBP;
        emit LTVBufferSet(bufferBP);
    }

    /**
     * @notice sets the ltvDeviationBP value
     * @param deviationBP new ltvDeviationBP value
     */
    function _setLTVDeviationBP(uint16 deviationBP) internal {
        _enforceBasis(deviationBP);
        s.layout().ltvDeviationBP = deviationBP;
        emit LTVDeviationSet(deviationBP);
    }

    /**
     * @notice grants or revokes the 'authorized' state to an account
     * @param account address of account to grant/revoke 'authorized'
     * @param isAuthorized value of 'authorized' state
     */
    function _setAuthorized(address account, bool isAuthorized) internal {
        s.layout().isAuthorized[account] = isAuthorized;
        emit AuthorizedSet(account, isAuthorized);
    }

    /**
     * @notice adds a collection to vault collections
     * @param collection address of collection to add
     */
    function _addCollection(address collection) internal {
        s.layout().vaultCollections.add(collection);
        emit CollectionAdded(collection);
    }

    /**
     * @notice removes a collection from vault collections
     * @param collection address of collection to remove
     */
    function _removeCollection(address collection) internal {
        s.layout().vaultCollections.remove(collection);
        emit CollectionRemoved(collection);
    }

    /**
     * @notice adds a tokenId to owned token Ids of a collection manually
     * @dev only needed for previously vaults to update storage
     * @param collection collection address
     * @param tokenId tokenId
     */
    function _addOwnedTokenToCollection(
        address collection,
        uint256 tokenId
    ) internal {
        s.Layout storage l = s.layout();

        if (!l.vaultCollections.contains(collection)) {
            revert SimpleVault__NotCollectionOfVault();
        }
        if (IERC721(collection).ownerOf(tokenId) != address(this)) {
            revert SimpleVault__NotTokenOwner();
        }

        l.collectionOwnedTokenIds[collection].add(tokenId);
        ++l.ownedTokenAmount;

        emit OwnedTokenAddedToCollection(collection, tokenId);
    }

    /**
     * @notice removes a tokenId to owned token Ids of a collection manually
     * @dev only needed for previously vaults to update storage
     * @param collection collection address
     * @param tokenId tokenId
     */
    function _removeOwnedTokenFromCollection(
        address collection,
        uint256 tokenId
    ) internal {
        s.Layout storage l = s.layout();

        if (IERC721(collection).ownerOf(tokenId) == address(this)) {
            revert SimpleVault__TokenStillOwned();
        }

        l.collectionOwnedTokenIds[collection].remove(tokenId);
        --l.ownedTokenAmount;

        emit OwnedTokenRemovedFromCollection(collection, tokenId);
    }

    /**
     * @inheritdoc ERC1155BaseInternal
     * @notice claims rewards of both from/to accounts to ensure correct reward accounting
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
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        if (from != address(0)) {
            _updateUserRewards(from, DAWN_OF_INSRT_ZERO_BALANCE);
        }

        if (to != address(0)) {
            _updateUserRewards(to, DAWN_OF_INSRT_ZERO_BALANCE);
        }
    }

    /**
     * @notice check to ensure account is whitelisted (holding a DAWN_OF_INSRT token or added to optinal mintWhitelist)
     * @param whitelist address of whitelist contract
     * @param account address to check
     * @param data any encoded data required to perform whitelist check
     */
    function _enforceWhitelist(
        address whitelist,
        address account,
        bytes calldata data
    ) internal view {
        if (
            IERC721(DAWN_OF_INSRT).balanceOf(account) == 0 &&
            !IWhitelist(whitelist).isWhitelisted(address(this), account, data)
        ) {
            revert SimpleVault__NotWhitelisted();
        }
    }

    /**
     * @notice check to ensure yield claiming is initialized
     */
    function _enforceYieldClaiming() internal view {
        if (!s.layout().isYieldClaiming) {
            revert SimpleVault__YieldClaimingForbidden();
        }
    }

    /**
     * @notice returns total fees accrued for given adaptor
     * @notice if adaptor is the default (no adaptor), then the sum of ETH fees accrued from sale, yield and acquisition is returned
     * @notice supports up to 5 different tokens and fees for each adaptor
     * @param adaptor enum indicating adaptor to check for token fees
     * @return tokenFees total token fees accrued for given adaptor
     */
    function _accruedFees(
        LendingAdaptor adaptor
    ) internal view returns (TokenFee[5] memory tokenFees) {
        if (adaptor == LendingAdaptor.DEFAULT) {
            tokenFees[0] = TokenFee({
                token: address(0),
                fees: s.layout().accruedFees
            });
        }

        if (adaptor == LendingAdaptor.JPEGD) {
            tokenFees[0] = TokenFee({
                token: JPEGDAdaptorStorage.JPEG,
                fees: JPEGDLending.accruedJPEGFees()
            });
        }
    }

    /**
     * @notice returns acquisition fee BP
     * @return feeBP basis points of acquisition fee
     */
    function _acquisitionFeeBP() internal view returns (uint16 feeBP) {
        feeBP = s.layout().acquisitionFeeBP;
    }

    /**
     * @notice returns sale fee BP
     * @return feeBP basis points of sale fee
     */
    function _saleFeeBP() internal view returns (uint16 feeBP) {
        feeBP = s.layout().saleFeeBP;
    }

    /**
     * @notice returns yield fee BP
     * @return feeBP basis points of yield fee
     */
    function _yieldFeeBP() internal view returns (uint16 feeBP) {
        feeBP = s.layout().yieldFeeBP;
    }

    /**
     * @notice return the maximum shards a user is allowed to mint; theoretically a user may acquire more than this amount via transfers,
     * but once this amount is exceeded said user may not deposit more
     * @return maxMint maxMintBalance value
     */
    function _maxMintBalance() internal view returns (uint64 maxMint) {
        maxMint = s.layout().maxMintBalance;
    }

    /**
     * @notice returns underlying collection address
     * @return collections addresses of underlying collection
     */
    function _vaultCollections()
        internal
        view
        returns (address[] memory collections)
    {
        collections = s.layout().vaultCollections.toArray();
    }

    /**
     * @notice return array with owned token IDs of a vault collection
     * @param collection address of collection to query ownedTokenIds for
     * @return tokenIds  array of owned token IDs in collecion
     */
    function _collectionOwnedTokenIds(
        address collection
    ) internal view returns (uint256[] memory tokenIds) {
        tokenIds = s.layout().collectionOwnedTokenIds[collection].toArray();
    }

    /**
     * @notice return amount of tokens of a particular ERC1155 collection owned by vault
     * @param collection address of ERC1155 collection
     * @param tokenId tokenId to check
     * @return amount amount of tokens owned by vault
     */
    function _collectionOwnedTokenAmounts(
        address collection,
        uint256 tokenId
    ) internal view returns (uint256 amount) {
        amount = s.layout().collectionOwnedTokenAmounts[collection][tokenId];
    }

    /**
     * @notice returns total number of NFTs owned across collections
     * @return amount total number of NFTs owned across collections
     */
    function _ownedTokenAmount() internal view returns (uint32 amount) {
        amount = s.layout().ownedTokenAmount;
    }

    /**
     * @notice return price of sale for a vault ERC721 token
     * @param collection collection address of token
     * @param tokenId id of token marked for sale
     * @return price price of token marked for sale
     */
    function _priceOfSale(
        address collection,
        uint256 tokenId
    ) internal view returns (uint256 price) {
        price = s.layout().priceOfSale[collection][tokenId];
    }

    /**
     * @notice return prices of sales for an amount of vault owned ECR1155 tokens
     * @param collection collection address of token
     * @param tokenId id of token
     * @param amount amount of tokens marked for sale
     * @return prices prices of tokens marked for sale
     */
    function _priceOfSales(
        address collection,
        uint256 tokenId,
        uint256 amount
    ) internal view returns (uint256[] memory prices) {
        prices = s.layout().priceOfSales[collection][tokenId][amount].toArray();
    }

    /**
     * @notice returns isEnabled status of vault deposits
     * @return status status of isEnabled
     */
    function _isEnabled() internal view returns (bool status) {
        status = s.layout().isEnabled;
    }

    /**
     * @notice returns the yield claiming status of the vault
     * @return status the yield claiming status of the vault
     */
    function _isYieldClaiming() internal view returns (bool status) {
        status = s.layout().isYieldClaiming;
    }

    /**
     * @notice returns timestamp of whitelist end
     * @return endTimestamp timestamp of whitelist end
     */
    function _whitelistEndsAt() internal view returns (uint48 endTimestamp) {
        endTimestamp = s.layout().whitelistEndsAt;
    }

    /**
     * @notice returns treasury address
     * @return feeRecipient address of treasury
     */
    function _treasury() internal view returns (address feeRecipient) {
        feeRecipient = TREASURY;
    }

    /**
     * @notice returns ETH value of a shard
     * @return shardETHValue ETH value of a shard
     */
    function _shardValue() internal view returns (uint256 shardETHValue) {
        shardETHValue = s.layout().shardValue;
    }

    /**
     * @notice return isInvested flag state indicating whether an asset has been purchased
     * @return status isInvested flag
     */
    function _isInvested() internal view returns (bool status) {
        if (_ownedTokenAmount() != 0) {
            status = true;
        }
    }

    /**
     * @notice returns maximum possible minted shards
     * @return supply maximum possible minted shards
     */
    function _maxSupply() internal view returns (uint64 supply) {
        supply = s.layout().maxSupply;
    }

    /**
     * @notice return amount of shards reserved for whitelist
     * @return supply amount of shards reserved for whitelist
     */
    function _reservedSupply() internal view returns (uint64 supply) {
        supply = s.layout().reservedSupply;
    }

    /**
     * @notice returns the address of the whitelist proxy
     * @return proxy whitelist proxy address
     */
    function _whitelist() internal view returns (address proxy) {
        proxy = s.layout().whitelist;
    }

    /**
     * @notice returns the cumulative ETH and tokens accrued per shard attained by the vault
     * @notice sum of all yield provided / totalSupply(MINT_TOKEN_ID)
     * @return ethPerShard cumulative ETH per shard attained by the vault
     * @return tokensPerShard array of amount of tokens yielded from vendors per shard
     */
    function _cumulativeTokensPerShard()
        internal
        view
        returns (uint256 ethPerShard, TokensPerShard[10] memory tokensPerShard)
    {
        s.Layout storage l = s.layout();

        ethPerShard = l.cumulativeETHPerShard;

        if (l.activatedLendingAdaptors[LendingAdaptor.JPEGD]) {
            tokensPerShard[0].token = JPEGDAdaptorStorage.JPEG;
            tokensPerShard[0].cumulativeAmount = JPEGDLending
                .cumulativeJPEGPerShard();
        }
    }

    /**
     * @notice returns the tokenIds of collateralized tokens for a collection
     * @param collection ERC721 collection address
     * @return tokens array of collateralized tokenIds
     */
    function _collateralizedTokens(
        address collection
    ) internal view returns (uint256[] memory tokens) {
        tokens = s.layout().collateralizedTokens[collection].toArray();
    }

    /**
     * @notice returns the total ETH and token yields from vendors an account may claim
     * @notice supports a total of 10 different tokens and their yields accross all adaptors
     * @param account account address
     * @param tokenId DOI tokenId used for yield fee discounting
     * @return yield total ETH yield claimable
     * @return tokenYields array of token yields available to user to claim
     */
    function _userRewards(
        address account,
        uint256 tokenId
    ) internal view returns (uint256 yield, TokenYield[10] memory tokenYields) {
        s.Layout storage l = s.layout();

        uint16 yieldFeeBP = _discountYieldFeeBP(account, tokenId, l.yieldFeeBP);
        uint256 shards = _balanceOf(account, MINT_TOKEN_ID);
        uint256 yieldPerShard = l.cumulativeETHPerShard -
            l.ethDeductionsPerShard[account];

        uint256 unclaimedYield = yieldPerShard * shards;
        uint256 yieldFee = (unclaimedYield * yieldFeeBP) / BASIS_POINTS;

        yield = l.userETHYield[account] + unclaimedYield - yieldFee;

        if (l.activatedLendingAdaptors[LendingAdaptor.JPEGD]) {
            tokenYields[0].token = JPEGDAdaptorStorage.JPEG;
            tokenYields[0].yield = JPEGDLending.userRewards(
                account,
                shards,
                yieldFeeBP
            );
        }
    }

    /**
     * @notice returns either interest debt or total debt on a given protocol
     * @param adaptor adaptor to query debt on
     * @param queryData encoded data required to query the debt
     * @return debt either total debt or debt interest
     */
    function _queryDebt(
        LendingAdaptor adaptor,
        bytes calldata queryData
    ) internal view returns (uint256 debt) {
        if (adaptor == LendingAdaptor.JPEGD) {
            debt = JPEGDLending.queryDebt(queryData);
        }
    }

    /**
     * @notice returns the activity status of an adaptor
     * @return status bool indicating whether an adaptor is active
     */
    function _isLendingAdaptorActive(
        LendingAdaptor adaptor
    ) internal view returns (bool status) {
        status = adaptor == LendingAdaptor.DEFAULT
            ? true
            : s.layout().activatedLendingAdaptors[adaptor];
    }

    /**
     * @notice returns the activity status of an adaptor
     * @return status bool indicating whether an adaptor is active
     */
    function _isStakingAdaptorActive(
        StakingAdaptor adaptor
    ) internal view returns (bool status) {
        status = adaptor == StakingAdaptor.DEFAULT
            ? true
            : s.layout().activatedStakingAdaptors[adaptor];
    }

    /**
     * @notice returns isAuthorized status of a given account
     * @param account address of account to check
     * @return status boolean indicating whether account is authorized
     */
    function _isAuthorized(
        address account
    ) internal view returns (bool status) {
        status = s.layout().isAuthorized[account];
    }

    /**
     * @notice returns the loan-to-value buffer in basis points
     * @return bufferBP loan-to-value buffer in basis points
     */
    function _ltvBufferBP() internal view returns (uint16 bufferBP) {
        bufferBP = s.layout().ltvBufferBP;
    }

    /**
     * @notice returns the loan-to-value deviation in basis points
     * @return deviationBP loan-to-value deviation in basis points
     */
    function _ltvDeviationBP() internal view returns (uint16 deviationBP) {
        deviationBP = s.layout().ltvDeviationBP;
    }

    /**
     * @notice returns the tokenId assigned to MINT_TOKEN
     * @return tokenId tokenId assigned to MINT_TOKEN
     */
    function _mintTokenId() internal pure returns (uint256 tokenId) {
        tokenId = MINT_TOKEN_ID;
    }

    /**
     * @notice enforces that a value cannot exceed BASIS_POINTS
     * @param value the value to check
     */
    function _enforceBasis(uint16 value) internal pure {
        if (value > BASIS_POINTS) revert SimpleVault__BasisExceeded();
    }

    /**
     * @notice records yield of an account without performing ETH/token transfers
     * @dev type(unit256).max is used to indicate no DAWN_OF_INSRT token is being used for fee deductions
     * @param account account address to record for
     * @param tokenId DAWN_OF_INSRT tokenId
     */
    function _updateUserRewards(address account, uint256 tokenId) private {
        s.Layout storage l = s.layout();

        uint256 yieldPerShard = l.cumulativeETHPerShard -
            l.ethDeductionsPerShard[account];

        uint256 shards = _balanceOf(account, MINT_TOKEN_ID);
        uint16 yieldFeeBP = _discountYieldFeeBP(account, tokenId, l.yieldFeeBP);

        if (yieldPerShard > 0) {
            uint256 totalYield = yieldPerShard * shards;
            uint256 fee = (totalYield * yieldFeeBP) / BASIS_POINTS;

            l.ethDeductionsPerShard[account] += yieldPerShard;
            l.accruedFees += fee;
            l.userETHYield[account] += totalYield - fee;
        }

        if (l.activatedLendingAdaptors[LendingAdaptor.JPEGD]) {
            JPEGDLending.updateUserRewards(account, shards, yieldFeeBP);
        }
    }

    /**
     * @notice applies a discount on yield fee
     * @param account address to check for discount
     * @param tokenId Dawn of Insrt token Id
     * @param rawYieldFeeBP the undiscounted yield fee in basis points
     */
    function _discountYieldFeeBP(
        address account,
        uint256 tokenId,
        uint16 rawYieldFeeBP
    ) private view returns (uint16 yieldFeeBP) {
        if (tokenId == DAWN_OF_INSRT_ZERO_BALANCE) {
            yieldFeeBP = rawYieldFeeBP;
        } else {
            if (account != IERC721(DAWN_OF_INSRT).ownerOf(tokenId)) {
                revert SimpleVault__NotDawnOfInsrtTokenOwner();
            }
            uint8 tier = IDawnOfInsrt(DAWN_OF_INSRT).tokenTier(tokenId);

            uint256 discount;
            if (tier == 0) {
                discount = TIER0_FEE_COEFFICIENT;
            } else if (tier == 1) {
                discount = TIER1_FEE_COEFFICIENT;
            } else if (tier == 2) {
                discount = TIER2_FEE_COEFFICIENT;
            } else if (tier == 3) {
                discount = TIER3_FEE_COEFFICIENT;
            } else {
                discount = TIER4_FEE_COEFFICIENT;
            }

            yieldFeeBP = uint16((rawYieldFeeBP * discount) / BASIS_POINTS);
        }
    }
}


// File: contracts/simple/SimpleVaultStorage.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { ISimpleVaultInternal } from './ISimpleVaultInternal.sol';
import { EnumerableSet } from '@solidstate/contracts/data/EnumerableSet.sol';

library SimpleVaultStorage {
    struct Layout {
        uint256 shardValue;
        uint256 accruedFees;
        //maximum tokens of MINT_TOKEN_ID which may be minted from deposits.
        //will be set to current totalSupply of MINT_TOKEN_ID if ERC721 asset
        //is purchased by vault prior to maxSupply of shards being minted
        uint64 maxSupply;
        uint16 saleFeeBP;
        uint16 acquisitionFeeBP;
        address whitelist;
        uint64 maxMintBalance;
        uint64 reservedSupply;
        uint48 whitelistEndsAt;
        bool isEnabled;
        bool isYieldClaiming;
        EnumerableSet.AddressSet vaultCollections;
        //registered all ids of ERC721 tokens acquired by vault - was replaced with collectionOwnedTokenIds
        //in order to allow for same id from different collections to be owned
        EnumerableSet.UintSet _deprecated_ownedtokenIds;
        mapping(address collection => mapping(uint256 tokenId => uint256 price)) priceOfSale;
        mapping(address collection => EnumerableSet.UintSet ownedTokenIds) collectionOwnedTokenIds;
        uint32 ownedTokenAmount;
        uint256 cumulativeETHPerShard;
        uint16 yieldFeeBP;
        uint16 ltvBufferBP;
        uint16 ltvDeviationBP;
        mapping(address collection => EnumerableSet.UintSet tokenIds) collateralizedTokens;
        mapping(address account => uint256 amount) ethDeductionsPerShard; //total amount of ETH deducted per shard, used to account for user rewards
        mapping(address account => uint256 amount) userETHYield;
        mapping(address account => bool isAuthorized) isAuthorized;
        mapping(ISimpleVaultInternal.StakingAdaptor adaptor => bool isActivated) activatedStakingAdaptors;
        mapping(ISimpleVaultInternal.LendingAdaptor adaptor => bool isActivated) activatedLendingAdaptors;
        mapping(address collection => mapping(uint256 tokenId => uint256 amount)) collectionOwnedTokenAmounts;
        mapping(address collection => mapping(uint256 tokenId => uint256 amount)) collateralizedTokenAmounts;
        mapping(address collection => mapping(uint256 tokenId => mapping(uint256 amount => EnumerableSet.UintSet))) priceOfSales;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('insrt.contracts.storage.SimpleVault');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// File: contracts/whitelist/IWhitelist.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import { ISafeOwnable } from '@solidstate/contracts/access/ownable/ISafeOwnable.sol';

/**
 * @title General whitelist interface for Insrt product instances
 */
interface IWhitelist is ISafeOwnable {
    /**
     * @notice returns whitelisted state of a given account for an Insrt product instance (eg ShardVault)
     * @param instance address of Insrt product instance
     * @param account account to check whitelisted state for
     * @param data any encoded data required to perform whitelist check
     * @return isWhitelisted whitelist state of account for given Insrt product instance
     */
    function isWhitelisted(
        address instance,
        address account,
        bytes calldata data
    ) external view returns (bool isWhitelisted);
}


// File: operator-filter-registry/src/DefaultOperatorFilterer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OperatorFilterer} from "./OperatorFilterer.sol";

/**
 * @title  DefaultOperatorFilterer
 * @notice Inherits from OperatorFilterer and automatically subscribes to the default OpenSea subscription.
 */
abstract contract DefaultOperatorFilterer is OperatorFilterer {
    address constant DEFAULT_SUBSCRIPTION = address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6);

    constructor() OperatorFilterer(DEFAULT_SUBSCRIPTION, true) {}
}


// File: operator-filter-registry/src/IOperatorFilterRegistry.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IOperatorFilterRegistry {
    function isOperatorAllowed(address registrant, address operator) external view returns (bool);
    function register(address registrant) external;
    function registerAndSubscribe(address registrant, address subscription) external;
    function registerAndCopyEntries(address registrant, address registrantToCopy) external;
    function unregister(address addr) external;
    function updateOperator(address registrant, address operator, bool filtered) external;
    function updateOperators(address registrant, address[] calldata operators, bool filtered) external;
    function updateCodeHash(address registrant, bytes32 codehash, bool filtered) external;
    function updateCodeHashes(address registrant, bytes32[] calldata codeHashes, bool filtered) external;
    function subscribe(address registrant, address registrantToSubscribe) external;
    function unsubscribe(address registrant, bool copyExistingEntries) external;
    function subscriptionOf(address addr) external returns (address registrant);
    function subscribers(address registrant) external returns (address[] memory);
    function subscriberAt(address registrant, uint256 index) external returns (address);
    function copyEntriesOf(address registrant, address registrantToCopy) external;
    function isOperatorFiltered(address registrant, address operator) external returns (bool);
    function isCodeHashOfFiltered(address registrant, address operatorWithCode) external returns (bool);
    function isCodeHashFiltered(address registrant, bytes32 codeHash) external returns (bool);
    function filteredOperators(address addr) external returns (address[] memory);
    function filteredCodeHashes(address addr) external returns (bytes32[] memory);
    function filteredOperatorAt(address registrant, uint256 index) external returns (address);
    function filteredCodeHashAt(address registrant, uint256 index) external returns (bytes32);
    function isRegistered(address addr) external returns (bool);
    function codeHashOf(address addr) external returns (bytes32);
}


// File: operator-filter-registry/src/OperatorFilterer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IOperatorFilterRegistry} from "./IOperatorFilterRegistry.sol";

/**
 * @title  OperatorFilterer
 * @notice Abstract contract whose constructor automatically registers and optionally subscribes to or copies another
 *         registrant's entries in the OperatorFilterRegistry.
 * @dev    This smart contract is meant to be inherited by token contracts so they can use the following:
 *         - `onlyAllowedOperator` modifier for `transferFrom` and `safeTransferFrom` methods.
 *         - `onlyAllowedOperatorApproval` modifier for `approve` and `setApprovalForAll` methods.
 */
abstract contract OperatorFilterer {
    error OperatorNotAllowed(address operator);

    IOperatorFilterRegistry public constant OPERATOR_FILTER_REGISTRY =
        IOperatorFilterRegistry(0x000000000000AAeB6D7670E522A718067333cd4E);

    constructor(address subscriptionOrRegistrantToCopy, bool subscribe) {
        // If an inheriting token contract is deployed to a network without the registry deployed, the modifier
        // will not revert, but the contract will need to be registered with the registry once it is deployed in
        // order for the modifier to filter addresses.
        if (address(OPERATOR_FILTER_REGISTRY).code.length > 0) {
            if (subscribe) {
                OPERATOR_FILTER_REGISTRY.registerAndSubscribe(address(this), subscriptionOrRegistrantToCopy);
            } else {
                if (subscriptionOrRegistrantToCopy != address(0)) {
                    OPERATOR_FILTER_REGISTRY.registerAndCopyEntries(address(this), subscriptionOrRegistrantToCopy);
                } else {
                    OPERATOR_FILTER_REGISTRY.register(address(this));
                }
            }
        }
    }

    modifier onlyAllowedOperator(address from) virtual {
        // Allow spending tokens from addresses with balance
        // Note that this still allows listings and marketplaces with escrow to transfer tokens if transferred
        // from an EOA.
        if (from != msg.sender) {
            _checkFilterOperator(msg.sender);
        }
        _;
    }

    modifier onlyAllowedOperatorApproval(address operator) virtual {
        _checkFilterOperator(operator);
        _;
    }

    function _checkFilterOperator(address operator) internal view virtual {
        // Check registry code length to facilitate testing in environments without a deployed registry.
        if (address(OPERATOR_FILTER_REGISTRY).code.length > 0) {
            if (!OPERATOR_FILTER_REGISTRY.isOperatorAllowed(address(this), operator)) {
                revert OperatorNotAllowed(operator);
            }
        }
    }
}


