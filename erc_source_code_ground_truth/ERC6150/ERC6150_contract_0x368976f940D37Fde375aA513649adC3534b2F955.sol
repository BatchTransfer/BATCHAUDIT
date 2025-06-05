// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./interfaces/ICategory.sol";
import "./ERC6150/ERC6150Enumerable.sol";
import "./ERC6150/ERC6150Burnable.sol";
import "./ERC6150/ERC6150ParentTransferable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Category is
    ICategory,
    ERC6150Enumerable,
    ERC6150Burnable,
    ERC6150ParentTransferable,
    Ownable
{
    // tokenId => nodeName
    mapping(uint256 => string) public override getName;
    uint256 public override nodeCount;

    constructor() ERC6150("ELS Category", "ELS-CAT") {}

    function addRootNode(
        address to,
        string calldata name
    ) external override onlyOwner {
        _addChildNode(to, 0, name);
    }
    
    function batchAddRootNodes(
        address to,
        string[] calldata names
    ) external override onlyOwner {
        for (uint256 i = 0; i < names.length; i++) {
            _addChildNode(to, 0, names[i]);
        }
    }

    function addChildNode(
        address to,
        uint256 parent,
        string calldata name
    ) external override {
        require(
            msg.sender == owner() || msg.sender == ownerOf(parent),
            "forbidden"
        );
        _addChildNode(to, parent, name);
    }

    function batchAddChildrenNodes(
        address to,
        uint256 parent,
        string[] calldata names
    ) external override {
        require(
            msg.sender == owner() || msg.sender == ownerOf(parent),
            "forbidden"
        );
        for (uint256 i = 0; i < names.length; i++) {
            _addChildNode(to, parent, names[i]);
        }
    }

    function safeBurn(uint256 tokenId) public override {
        delete getName[tokenId];
        super.safeBurn(tokenId);
    }

    function safeBatchBurn(uint256[] memory tokenIds) public override {
        super.safeBatchBurn(tokenIds);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            delete getName[tokenIds[i]];
        }
    }

    function _addChildNode(
        address to,
        uint256 parent,
        string calldata name
    ) internal {
        // require(getPosting[parent] == address(0), "posting exists");
        nodeCount += 1;
        _safeMintWithParent(to, parent, nodeCount, bytes(name));
        emit NodeAdded(nodeCount, name);
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.2) (token/ERC721/ERC721.sol)

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
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
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
        _requireMinted(tokenId);

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
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");

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
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
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
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
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
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
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
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
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

        _beforeTokenTransfer(address(0), to, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to] += 1;
        }

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId, 1);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner = ERC721.ownerOf(tokenId);

        // Clear approvals
        delete _tokenApprovals[tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId, 1);
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

        _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
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
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
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
     * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual {}

    /**
     * @dev Hook that is called after any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens were transferred to `to`.
     * - When `from` is zero, the tokens were minted for `to`.
     * - When `to` is zero, ``from``'s tokens were burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual {}

    /**
     * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
     *
     * WARNING: Anyone calling this MUST ensure that the balances remain consistent with the ownership. The invariant
     * being that for any address `a` the value returned by `balanceOf(a)` must be equal to the number of tokens such
     * that `ownerOf(tokenId)` is `a`.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __unsafe_increaseBalance(address account, uint256 amount) internal {
        _balances[account] += amount;
    }
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

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
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./interfaces/IERC6150.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

abstract contract ERC6150 is ERC721, IERC6150 {
    mapping(uint256 => uint256) private _parentOf;
    mapping(uint256 => uint256[]) private _childrenOf;
    mapping(uint256 => uint256) private _indexInChildrenArray;

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC721) returns (bool) {
        return
            interfaceId == type(IERC6150).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function parentOf(
        uint256 tokenId
    ) public view virtual override returns (uint256 parentId) {
        _requireMinted(tokenId);
        parentId = _parentOf[tokenId];
    }

    function childrenOf(
        uint256 tokenId
    ) public view virtual override returns (uint256[] memory childrenIds) {
        if (tokenId > 0) {
            _requireMinted(tokenId);
        }
        childrenIds = _childrenOf[tokenId];
    }

    function isRoot(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        _requireMinted(tokenId);
        return _parentOf[tokenId] == 0;
    }

    function isLeaf(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        _requireMinted(tokenId);
        return _childrenOf[tokenId].length == 0;
    }

    function _getIndexInChildrenArray(
        uint256 tokenId
    ) internal view virtual returns (uint256) {
        return _indexInChildrenArray[tokenId];
    }

    function _safeBatchMintWithParent(
        address to,
        uint256 parentId,
        uint256[] memory tokenIds
    ) internal virtual {
        _safeBatchMintWithParent(
            to,
            parentId,
            tokenIds,
            new bytes[](tokenIds.length)
        );
    }

    function _safeBatchMintWithParent(
        address to,
        uint256 parentId,
        uint256[] memory tokenIds,
        bytes[] memory datas
    ) internal virtual {
        require(
            tokenIds.length == datas.length,
            "ERC6150: tokenIds.length != datas.length"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _safeMintWithParent(to, parentId, tokenIds[i], datas[i]);
        }
    }

    function _safeMintWithParent(
        address to,
        uint256 parentId,
        uint256 tokenId
    ) internal virtual {
        _safeMintWithParent(to, parentId, tokenId, "");
    }

    function _safeMintWithParent(
        address to,
        uint256 parentId,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        require(tokenId > 0, "ERC6150: tokenId is zero");
        if (parentId != 0)
            require(_exists(parentId), "ERC6150: parentId doesn't exist");

        _beforeMintWithParent(to, parentId, tokenId);

        _parentOf[tokenId] = parentId;
        _indexInChildrenArray[tokenId] = _childrenOf[parentId].length;
        _childrenOf[parentId].push(tokenId);

        _safeMint(to, tokenId, data);
        emit Minted(msg.sender, to, parentId, tokenId);

        _afterMintWithParent(to, parentId, tokenId);
    }

    function _safeBurn(uint256 tokenId) internal virtual {
        require(_exists(tokenId), "ERC6150: tokenId doesn't exist");
        require(isLeaf(tokenId), "ERC6150: tokenId is not a leaf");

        uint256 parent = _parentOf[tokenId];
        uint256 lastTokenIndex = _childrenOf[parent].length - 1;
        uint256 targetTokenIndex = _indexInChildrenArray[tokenId];
        uint256 lastIndexToken = _childrenOf[parent][lastTokenIndex];
        if (lastTokenIndex > targetTokenIndex) {
            _childrenOf[parent][targetTokenIndex] = lastIndexToken;
            _indexInChildrenArray[lastIndexToken] = targetTokenIndex;
        }

        delete _childrenOf[parent][lastIndexToken];
        delete _indexInChildrenArray[tokenId];
        delete _parentOf[tokenId];

        _burn(tokenId);
    }

    function _beforeMintWithParent(
        address to,
        uint256 parentId,
        uint256 tokenId
    ) internal virtual {}

    function _afterMintWithParent(
        address to,
        uint256 parentId,
        uint256 tokenId
    ) internal virtual {}
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./ERC6150.sol";
import "./interfaces/IERC6150Burnable.sol";

abstract contract ERC6150Burnable is ERC6150, IERC6150Burnable {
    function safeBurn(uint256 tokenId) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC6150Burnable: caller is neither token owner nor approved"
        );
        _safeBurn(tokenId);
    }

    function safeBatchBurn(uint256[] memory tokenIds) public virtual override {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            safeBurn(tokenIds[i]);
        }
    }
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./ERC6150.sol";
import "./interfaces/IERC6150Enumerable.sol";

abstract contract ERC6150Enumerable is ERC6150, IERC6150Enumerable {
    function childrenCountOf(
        uint256 parentId
    ) external view virtual override returns (uint256) {
        return childrenOf(parentId).length;
    }

    function childOfParentByIndex(
        uint256 parentId,
        uint256 index
    ) external view virtual override returns (uint256) {
        uint256[] memory children = childrenOf(parentId);
        return children[index];
    }

    function indexInChildrenEnumeration(
        uint256 parentId,
        uint256 tokenId
    ) external view virtual override returns (uint256) {
        require(parentOf(tokenId) == parentId, "wrong parent");
        return _getIndexInChildrenArray(tokenId);
    }
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./ERC6150.sol";
import "./interfaces/IERC6150ParentTransferable.sol";

abstract contract ERC6150ParentTransferable is
    ERC6150,
    IERC6150ParentTransferable
{
    function transferParent(
        uint256 newParentId,
        uint256 tokenId
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC6150ParentTransferable: caller is not token owner nor approved"
        );
        if (newParentId != 0) {
            require(
                _exists(newParentId),
                "ERC6150ParentTransferable: newParentId doesn't exists"
            );
        }

        address owner = ownerOf(tokenId);
        uint256 oldParentId = parentOf(tokenId);
        _safeBurn(tokenId);
        _safeMintWithParent(owner, newParentId, tokenId);
        emit ParentTransferred(tokenId, oldParentId, newParentId);
    }

    function batchTransferParent(
        uint256 newParentId,
        uint256[] memory tokenIds
    ) public virtual override {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            transferParent(tokenIds[i], newParentId);
        }
    }
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title ERC-6150 Hierarchical NFTs Token Standard
 * @dev See https://eips.ethereum.org/EIPS/eip-6150
 * Note: the ERC-165 identifier for this interface is 0x897e2c73.
 */
interface IERC6150 is IERC721 {
    /**
     * @notice Emitted when `tokenId` token under `parentId` is minted.
     * @param minter The address of minter
     * @param to The address received token
     * @param parentId The id of parent token, if it's zero, it means minted `tokenId` is a root token.
     * @param tokenId The id of minted token, required to be greater than zero
     */
    event Minted(
        address indexed minter,
        address indexed to,
        uint256 parentId,
        uint256 tokenId
    );

    /**
     * @notice Get the parent token of `tokenId` token.
     * @param tokenId The child token
     * @return parentId The Parent token found
     */
    function parentOf(uint256 tokenId) external view returns (uint256 parentId);

    /**
     * @notice Get the children tokens of `tokenId` token.
     * @param tokenId The parent token
     * @return childrenIds The array of children tokens
     */
    function childrenOf(
        uint256 tokenId
    ) external view returns (uint256[] memory childrenIds);

    /**
     * @notice Check the `tokenId` token if it is a root token.
     * @param tokenId The token want to be checked
     * @return Return `true` if it is a root token; if not, return `false`
     */
    function isRoot(uint256 tokenId) external view returns (bool);

    /**
     * @notice Check the `tokenId` token if it is a leaf token.
     * @param tokenId The token want to be checked
     * @return Return `true` if it is a leaf token; if not, return `false`
     */
    function isLeaf(uint256 tokenId) external view returns (bool);
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./IERC6150.sol";

/**
 * @title ERC-6150 Hierarchical NFTs Token Standard, optional extension for burnable
 * @dev See https://eips.ethereum.org/EIPS/eip-6150
 * Note: the ERC-165 identifier for this interface is 0x4ac0aa46.
 */
interface IERC6150Burnable is IERC6150 {
    /**
     * @notice Burn the `tokenId` token.
     * @dev Throws if `tokenId` is not a leaf token.
     * Throws if `tokenId` is not a valid NFT.
     * Throws if `owner` is not the owner of `tokenId` token.
     * Throws unless `msg.sender` is the current owner, an authorized operator, or the approved address for this token.
     * @param tokenId The token to be burnt
     */
    function safeBurn(uint256 tokenId) external;

    /**
     * @notice Batch burn tokens.
     * @dev Throws if one of `tokenIds` is not a leaf token.
     * Throws if one of `tokenIds` is not a valid NFT.
     * Throws if `owner` is not the owner of all `tokenIds` tokens.
     * Throws unless `msg.sender` is the current owner, an authorized operator, or the approved address for all `tokenIds`.
     * @param tokenIds The tokens to be burnt
     */
    function safeBatchBurn(uint256[] memory tokenIds) external;
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

/**
 * @title ERC-6150 Hierarchical NFTs Token Standard, optional extension for enumerable
 * @dev See https://eips.ethereum.org/EIPS/eip-6150
 * Note: the ERC-165 identifier for this interface is 0xba541a2e.
 */
interface IERC6150Enumerable {
    /**
     * @notice Get total amount of children tokens under `parentId` token.
     * @dev If `parentId` is zero, it means get total amount of root tokens.
     * @return The total amount of children tokens under `parentId` token.
     */
    function childrenCountOf(uint256 parentId) external view returns (uint256);

    /**
     * @notice Get the token at the specified index of all children tokens under `parentId` token.
     * @dev If `parentId` is zero, it means get root token.
     * @return The token ID at `index` of all chlidren tokens under `parentId` token.
     */
    function childOfParentByIndex(
        uint256 parentId,
        uint256 index
    ) external view returns (uint256);

    /**
     * @notice Get the index position of specified token in the children enumeration under specified parent token.
     * @dev Throws if the `tokenId` is not found in the children enumeration.
     * If `parentId` is zero, means get root token index.
     * @param parentId The parent token
     * @param tokenId The specified token to be found
     * @return The index position of `tokenId` found in the children enumeration
     */
    function indexInChildrenEnumeration(
        uint256 parentId,
        uint256 tokenId
    ) external view returns (uint256);
}// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./IERC6150.sol";

/**
 * @title ERC-6150 Hierarchical NFTs Token Standard, optional extension for parent transferable
 * @dev See https://eips.ethereum.org/EIPS/eip-6150
 * Note: the ERC-165 identifier for this interface is 0xfa574808.
 */
interface IERC6150ParentTransferable is IERC6150 {
    /**
     * @notice Emitted when the parent of `tokenId` token changed.
     * @param tokenId The token changed
     * @param oldParentId Previous parent token
     * @param newParentId New parent token
     */
    event ParentTransferred(
        uint256 tokenId,
        uint256 oldParentId,
        uint256 newParentId
    );

    /**
     * @notice Transfer parentship of `tokenId` token to a new parent token
     * @param newParentId New parent token id
     * @param tokenId The token to be changed
     */
    function transferParent(uint256 newParentId, uint256 tokenId) external;

    /**
     * @notice Batch transfer parentship of `tokenIds` to a new parent token
     * @param newParentId New parent token id
     * @param tokenIds Array of token ids to be changed
     */
    function batchTransferParent(
        uint256 newParentId,
        uint256[] memory tokenIds
    ) external;
}