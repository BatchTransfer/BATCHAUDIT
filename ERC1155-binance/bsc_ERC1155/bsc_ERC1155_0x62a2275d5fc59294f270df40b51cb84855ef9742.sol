// Chain: BSC - File: contracts/IDFG.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./helper/IOwnable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDFG is IERC20, IOwnable{
    function initSupply(address _teamAddr,
                address _marketingAddr,
                address _ecoFundAddr,
                address _partnersAddr,
                address _playToEarnAddr,
                address _nftPoolAddr,
                address _privateSaleAddr) external;
}


// Chain: BSC - File: contracts/IMBxOC.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./helper/INFTControl.sol";

interface IMBxOC is INFTControl{
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// Chain: BSC - File: Forge.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./contracts/supplementary/IMaterial.sol";
import "./contracts/IMBxOC.sol";
import "./contracts/IDFG.sol";
import "../../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./contracts/helper/PRNG.sol";

contract Forge is Ownable {
    using SafeMath for uint256;

    address private _recipient;
    uint256 private _balance;
    uint256 private _price;
    address private _materialAddress;
    address private _coinAddres;
    address private _nftAddress;

    mapping(uint256 => uint256) private _upgradeCount;
    mapping(string => uint256[]) private _costMaterial;
    uint16[14] private _upgradeProbability;

    event UpgradeTo(
        uint256 indexed tokenId,
        address indexed owner,
        uint256[] ids,
        uint256[] amounts,
        uint256[3] upLevels,
        bool result
    );

    constructor(
        address recipient,
        address material,
        address nft,
        address coin
    ) Ownable() {
        require(
            recipient != address(0),
            "Forge: The 'recipient' is a zero address"
        );
        require(
            material != address(0),
            "Forge: The 'material' is a zero address"
        );
        require(
            nft != address(0),
            "Forge: The 'nft' is a zero address"
        );
        require(
            coin != address(0),
            "Forge: The 'coin' is a zero address"
        );
        _recipient = recipient;
        _materialAddress = material;
        _coinAddres = coin;
        _nftAddress = nft;
        _initCostMaterial();
    }

    function balanceOf() public view returns (uint256) {
        return _balance;
    }

    function setPrice(uint256 price) public onlyOwner {
        _price = price;
    }

    function getPrice() public view returns (uint256) {
        return _price;
    }

    function upgradeCount(uint256 tokenId) public view returns (uint256) {
        return _upgradeCount[tokenId];
    }

    function up(
        uint256 tokenId,
        uint256[3] memory upLevels,
        uint256[] memory upIds,
        uint256[] memory amounts
    ) public {
        uint256[5] memory ids = _parseTokenId(tokenId);
        require(
            ids[0] > 0 && ids[1] > 0 && ids[2] > 0 && ids[3] > 0 && ids[4] > 0,
            "Forge: The tokenId is not legal"
        );
        require(
            IMBxOC(_nftAddress).ownerOf(tokenId) == _msgSender(),
            "Forge: caller is not owner of the MBxOC"
        );
        require(_upgradeCount[tokenId] < 13, "Forge: Upgrade limit exceeded");
        uint256 mbcBalance = IDFG(_coinAddres).balanceOf(_msgSender());
        require(mbcBalance >= _price, "Forge: DFG balance less than price");
        uint256 index = 0;
        uint256 cost = 0;
        uint256 sid;
        uint256 level;
        for (uint256 i = 0; i < 3; i++) {
            if (upLevels[i] > 0) {
                level = upLevels[i];
                cost = 0;
                if (i == 0 && level < 7) {
                    cost = _costMaterial["pet"][level];
                    sid = ids[1];
                } else if (i == 1 && level < 13) {
                    cost = _costMaterial["weapon"][level];
                    sid = ids[3];
                } else if (i == 2 && level < 7) {
                    cost = _costMaterial["wing"][level];
                    sid = ids[4];
                }
                require(
                    cost > 0 && upIds[index] == sid && amounts[index] == cost,
                    "Forge: materials mismatch"
                );
                index++;
            }
        }
        require(level > 0, "Forge: Param 'upLevels' is wrong");
        _upgradeCount[tokenId]++;
        IDFG(_coinAddres).transferFrom(_msgSender(), _recipient, _price);
        IMaterial(_materialAddress).safeBatchTransferFrom(
            _msgSender(),
            _recipient,
            upIds,
            amounts,
            ""
        );
        bool result = PRNG.probability(tokenId, _upgradeProbability[level]);
        if (result) {
            IMBxOC(_nftAddress).upgrade(tokenId, upLevels);
        }

        emit UpgradeTo(tokenId, _msgSender(), upIds, amounts, upLevels, result);
    }

    function _initCostMaterial() private {
        _costMaterial["pet"] = [0, 1, 2, 3, 4, 4, 5];
        _costMaterial["weapon"] = [
            0,
            10,
            15,
            20,
            25,
            30,
            35,
            40,
            45,
            50,
            55,
            60,
            65
        ];
        _costMaterial["wing"] = [0, 1, 2, 3, 4, 4, 5];
        _upgradeProbability = [
            0,
            9000,
            8500,
            8000,
            7500,
            7000,
            6500,
            6000,
            5500,
            5000,
            4500,
            4000,
            3500
        ];
    }

    function _parseTokenId(uint256 tokenId)
        private
        pure
        returns (uint256[5] memory)
    {
        uint256[5] memory ids;
        uint256 sid = tokenId.div(1000000000000000000000000);
        uint256 mod = tokenId.mod(1000000000000000000000000);
        if (sid != 404021 && sid != 404038 && sid != 404034 && sid != 404028) {
            return ids;
        }
        ids[0] = sid;
        sid = mod.div(1000000000000000000);
        mod = mod.mod(1000000000000000000);
        if (
            sid != 400035 &&
            sid != 400036 &&
            sid != 400045 &&
            sid != 400043 &&
            sid != 400048 &&
            sid != 400039 &&
            sid != 400041 &&
            sid != 400010
        ) {
            return ids;
        }
        ids[1] = sid;
        sid = mod.div(1000000000000);
        mod = mod.mod(1000000000000);

        if (
            sid != 111005 &&
            sid != 111006 &&
            sid != 111007 &&
            sid != 111008 &&
            sid != 111009 &&
            sid != 111012 &&
            sid != 111014 &&
            sid != 111015 &&
            sid != 111016 &&
            sid != 111019 &&
            sid != 111020 &&
            sid != 111021 &&
            sid != 111505 &&
            sid != 111506 &&
            sid != 111507 &&
            sid != 111508 &&
            sid != 111509 &&
            sid != 111583 &&
            sid != 111514 &&
            sid != 111515 &&
            sid != 111516 &&
            sid != 111519 &&
            sid != 111520 &&
            sid != 111521
        ) {
            return ids;
        }
        ids[2] = sid;
        sid = mod.div(1000000);
        mod = mod.mod(1000000);
        if (sid != 600021 && sid != 600008 && sid != 600006) {
            return ids;
        }
        ids[3] = sid;
        if (mod != 501014 && mod != 501012 && mod != 501013) {
            return ids;
        }
        ids[4] = mod;
        return ids;
    }
}


// Chain: BSC - File: contracts/helper/INFTControl.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./IRoleControl.sol";
interface INFTControl is IERC721Enumerable, IRoleControl{
    function powerOf(uint256 tokenId) external view returns (uint256);
    function mint(address to, uint256 tokenId)external;
    function upgrade(uint256 tokenId, uint256[3] memory upLevels) external; 
    function getLevel(uint256 tokenId) external view returns(uint256[5] memory);
}

// Chain: BSC - File: contracts/helper/IOwnable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IOwnable{
    function owner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner)external;
}

// Chain: BSC - File: contracts/helper/IRoleControl.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOwnable.sol";

interface IRoleControl is IOwnable {
    function roleApprove(
        string memory role,
        address to,
        bool _allow
    ) external;

    function getRoleApproved(string memory role, address to)
        external
        view
        returns (bool);
}


// Chain: BSC - File: contracts/helper/PRNG.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library PRNG {
    function random(uint256 seed) internal view returns (uint16) {
        uint16 randomNumber = uint16(
            uint256(keccak256(abi.encodePacked(block.timestamp, seed))) % 10000
        );
        return randomNumber;
    }

    function probability(uint256 seed, uint16 expectation)
        internal
        view
        returns (bool)
    {
        uint16 rd = random(seed);
        if (rd <= expectation) {
            return true;
        }
        return false;
    }
}


// Chain: BSC - File: contracts/supplementary/IMaterial.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../helper/IRoleControl.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IMaterial is IERC1155, IRoleControl{

    function mint(
        address account,
        uint256 id,
        uint256 amount
    )external;

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    )external;
}


// Chain: BSC - File: node_modules/@openzeppelin/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * 'onlyOwner', which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * 'onlyOwner' functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account ('newOwner').
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// Chain: BSC - File: node_modules/@openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT

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
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

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
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

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


// Chain: BSC - File: node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}


// Chain: BSC - File: node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT

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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

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
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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
}


// Chain: BSC - File: node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}


// Chain: BSC - File: node_modules/@openzeppelin/contracts/utils/Context.sol
// SPDX-License-Identifier: MIT

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


// Chain: BSC - File: node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol
// SPDX-License-Identifier: MIT

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


// Chain: BSC - File: node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}