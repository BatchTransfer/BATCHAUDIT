//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ERC4907, IERC4907} from "../../utils/tokens/ERC721/extensions/ERC4907/ERC4907.sol";
import {IERC4906, IERC165} from "../../utils/tokens/IERC4906.sol";
import {Base721} from "../../utils/tokens/ERC721/Base721.sol";

import {ITPLRevealedParts} from "../TPLRevealedParts/ITPLRevealedParts.sol";

import {ITPLMechRentalManager} from "./TPLMechRental/ITPLMechRentalManager.sol";
import {ITPLMechOrigin} from "./TPLMechOrigin/ITPLMechOrigin.sol";

/// @title TPLMech
/// @author CyberBrokers
/// @author dev by @dievardump
/// @notice Registry containing the CyberBrokers Genesis Mechs
/// @dev Mechs can only be minted by accounts in the "minters" list.
///
///      To build a Mech, 7 parts are necessary: 2 arms, one head, one body, one pair of legs, one engine and one afterglow.
///
///      We keep a reference of all those 7 ids for each Mech, making sure we can get back all parts information used to build it
contract TPLMech is Base721, ERC4907, IERC4906 {
    error UnknownMech();
    error WrongParameter();
    error NotAuthorized();
    error OperatorNotAuthorized();

    error TransferDeniedByRentalManager();

    uint256 private _minted;
    uint256 private _burned;

    /// @notice Emitted when a Mech changed (either is minted, or its mechData has been updated)
    /// @param mechId the mech id
    event MechChanged(uint256 indexed mechId);

    address public tplOrigin;

    address public rentalManager;

    /// @dev contains extra data allowing to identify the Mechs origin (the parts etc...)
    mapping(uint256 => uint256) public mechOriginData;

    constructor(ERC721CommonConfig memory config, address tplOrigin_) Base721("Genesis Mechs", "GENESISMECHS", config) {
        tplOrigin = tplOrigin_;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(Base721, ERC4907, IERC165) returns (bool) {
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }

    function totalSupply() public view returns (uint256) {
        return _minted - _burned;
    }

    /// @notice returns all TPLRevealedParts IDs & TPLAfterglow ID used in crafting a Mech
    /// @param tokenId the Mech ID
    /// @return an array with the 6 TPLRevealedParts ids used
    /// @return the afterglow id
    function getMechPartsIds(uint256 tokenId) public view returns (uint256[] memory, uint256) {
        uint256 mechData = mechOriginData[tokenId];
        if (mechData == 0) {
            revert UnknownMech();
        }

        return ITPLMechOrigin(tplOrigin).getMechPartsIds(mechData);
    }

    /// @notice returns all TPL Revealed Parts IDs (& their TokenData) used in crafting a Mech
    /// @param tokenId the mech to get parts of
    /// @return an array with 7 MechOrigin containing each parts details
    function getMechOrigin(uint256 tokenId) public view returns (ITPLMechOrigin.MechOrigin memory) {
        uint256 mechData = mechOriginData[tokenId];
        if (mechData == 0) {
            revert UnknownMech();
        }

        return ITPLMechOrigin(tplOrigin).getMechOrigin(mechData);
    }

    /// @notice returns an array of getMechOrigin(tokenId) containing the origin for all ids in tokenIds
    /// @param tokenIds the mech ids we want the origin of
    /// @return an array of MechOrigin
    function getMechOriginBatch(uint256[] memory tokenIds) public view returns (ITPLMechOrigin.MechOrigin[] memory) {
        uint256 length = tokenIds.length;
        if (length == 0) revert WrongParameter();

        ITPLMechOrigin.MechOrigin[] memory origins = new ITPLMechOrigin.MechOrigin[](length);

        do {
            unchecked {
                length--;
            }
            origins[length] = getMechOrigin(tokenIds[length]);
        } while (length > 0);

        return origins;
    }

    function isApprovedForAll(address owner_, address operator) public view virtual override returns (bool) {
        // this allows to automatically approve some contracts like the MechCrafter contract
        // to do actions like disassembly of the mech
        return minters[msg.sender] || super.isApprovedForAll(owner_, operator);
    }

    /////////////////////////////////////////////////////////
    // Interactions                                        //
    /////////////////////////////////////////////////////////

    /// @notice disabled
    function mintTo(address, uint256) public override onlyMinter {
        revert NotAuthorized();
    }

    /// @notice Allows a minter to mint the next Mech to `to` with `mechData`
    /// @param to the token recipient
    /// @param mechData data allowing to find the mech origin
    /// @return the token id
    function mintNext(address to, uint256 mechData) external virtual onlyMinter returns (uint256) {
        uint256 tokenId = _mintTo(to, 1);
        mechOriginData[tokenId] = mechData;

        emit MechChanged(tokenId);

        return tokenId;
    }

    /// @notice Allows a minter to mint the given `tokenId` Mech to `to` with `mechData`
    /// @param tokenId the token id
    /// @param to the token recipient
    /// @param mechData data allowing to find the mech origin
    function mintToken(uint256 tokenId, address to, uint256 mechData) external virtual onlyMinter {
        _mint(to, tokenId);
        mechOriginData[tokenId] = mechData;

        emit MechChanged(tokenId);
    }

    /// @notice Allows to update a mech origin data
    /// @param tokenId the mech id
    /// @param mechData the new Data
    function updateMechData(uint256 tokenId, uint256 mechData) external onlyMinter {
        mechOriginData[tokenId] = mechData;

        emit MechChanged(tokenId);

        // if the mechData are updated, this could mean that the metadata changed
        emit MetadataUpdate(tokenId);
    }

    /////////////////////////////////////////////////////////
    // Gated Owner                                         //
    /////////////////////////////////////////////////////////

    /// @notice allows owner to set the collection base URI value & trigger a metadata update from indexers
    /// @param newBaseURI the new base URI
    /// @param triggerEIP4906 boolean to set to true if we want marketplaces/platforms to refetch metadata
    function setBaseURI(string calldata newBaseURI, bool triggerEIP4906) public onlyOwner {
        _setBaseURI(newBaseURI);

        if (triggerEIP4906) {
            emit BatchMetadataUpdate(1, _lastTokenId);
        }
    }

    /// @notice Allows owner to set the new rental manager, to support EIP-4907
    /// @param newRentalManager the new rental maanager
    function setRentalManager(address newRentalManager) external onlyOwner {
        rentalManager = newRentalManager;
    }

    /// @notice Allows owner to set the new tpl origin
    /// @param newTplMechOrigin the contract reading the origin of a mec
    function setTPLOrigin(address newTplMechOrigin) external onlyOwner {
        tplOrigin = newTplMechOrigin;
    }

    /////////////////////////////////////////////////////////
    // Internals                                           //
    /////////////////////////////////////////////////////////

    function _mint(address to, uint256 id) internal override {
        super._mint(to, id);
        _minted++;
    }

    function _burn(uint256 id) internal override {
        super._burn(id);
        delete mechOriginData[id];

        _burned++;
    }

    /// @dev only rentalManager can allow a rental
    function _checkCanRent(
        address operator,
        uint256 tokenId,
        address /*user*/,
        uint64 /*expires*/
    ) internal view override {
        if (!_exists(tokenId)) {
            revert UnknownMech();
        }

        // if it's not rentalManager calling, deny
        if (operator != rentalManager) {
            revert OperatorNotAuthorized();
        }

        // if we are here, it means the call comes from rentalManager, which must have already validated
        // everything there is before calling the setUser(tokenId, user) function
    }

    /// @dev only rentalManager can trigger the cancelation of a rental
    /// @param operator the current caller
    /// @param tokenId the token id to cancel the rental for
    function _checkCanCancelRental(address operator, uint256 tokenId) internal view virtual override {
        if (operator != rentalManager) {
            revert OperatorNotAuthorized();
        }

        // if we are here, it means the call comes from rentalManager, which must have already validated
        // everything there is before calling the cancelRenntal(tokenId) function
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        // if minting, there is definitely no rental ongoing, saves checks
        if (from != address(0)) {
            address user = userOf(firstTokenId);

            // if the item is currently in rental
            if (user != address(0)) {
                // we need rentalManager to allow or deny the transfer
                if (
                    !ITPLMechRentalManager(rentalManager).checkTransferPolicy(msg.sender, from, to, firstTokenId, user)
                ) {
                    revert TransferDeniedByRentalManager();
                }
            }
        }

        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/ERC721.sol)

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
        uint256, /* firstTokenId */
        uint256 batchSize
    ) internal virtual {
        if (batchSize > 1) {
            if (from != address(0)) {
                _balances[from] -= batchSize;
            }
            if (to != address(0)) {
                _balances[to] += batchSize;
            }
        }
    }

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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/extensions/ERC721Burnable.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "../../../utils/Context.sol";

/**
 * @title ERC721 Burnable Token
 * @dev ERC721 Token that can be burned (destroyed).
 */
abstract contract ERC721Burnable is Context, ERC721 {
    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _burn(tokenId);
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/common/ERC2981.sol)

pragma solidity ^0.8.0;

import "../../interfaces/IERC2981.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the NFT Royalty Standard, a standardized way to retrieve royalty payment information.
 *
 * Royalty information can be specified globally for all token ids via {_setDefaultRoyalty}, and/or individually for
 * specific token ids via {_setTokenRoyalty}. The latter takes precedence over the first.
 *
 * Royalty is specified as a fraction of sale price. {_feeDenominator} is overridable but defaults to 10000, meaning the
 * fee is specified in basis points by default.
 *
 * IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its payment. See
 * https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the EIP. Marketplaces are expected to
 * voluntarily pay royalties together with sales, but note that this standard is not yet widely supported.
 *
 * _Available since v4.5._
 */
abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view virtual override returns (address, uint256) {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    /**
     * @dev The denominator with which to interpret the fee set in {_setTokenRoyalty} and {_setDefaultRoyalty} as a
     * fraction of the sale price. Defaults to 10000 so fees are expressed in basis points, but may be customized by an
     * override.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Removes default royalty information.
     */
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Resets royalty information for the token id back to the global default.
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
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
}//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IBase721A} from "../../utils/tokens/ERC721/IBase721A.sol";

/// @title ITPLRevealedParts
/// @author CyberBrokers
/// @author dev by @dievardump
/// @notice Interface for the Revealed Parts contract.
interface ITPLRevealedParts is IBase721A {
    struct TokenData {
        uint256 generation;
        uint256 originalId;
        uint256 bodyPart;
        uint256 model;
        uint256[] stats;
    }

    /// @notice verifies that `account` owns all `tokenIds`
    /// @param account the account
    /// @param tokenIds the token ids to check
    /// @return if account owns all tokens
    function isOwnerOfBatch(address account, uint256[] calldata tokenIds) external view returns (bool);

    /// @notice returns a Mech Part data (body part and original id)
    /// @param tokenId the tokenId to check
    /// @return the Mech Part data (body part and original id)
    function partData(uint256 tokenId) external view returns (TokenData memory);

    /// @notice returns a list of Mech Part data (body part and original id)
    /// @param tokenIds the tokenIds to knoMechParts type of
    /// @return a list of Mech Part data (body part and original id)
    function partDataBatch(uint256[] calldata tokenIds) external view returns (TokenData[] memory);

    /// @notice Allows to burn tokens in batch
    /// @param tokenIds the tokens to burn
    function burnBatch(uint256[] calldata tokenIds) external;

    /// @notice Transfers the ownership of multiple NFTs from one address to another address
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenIds The NFTs to transfer
    function batchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _tokenIds
    ) external;
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IERC721, ERC721, ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Common, WithMeta, ERC2981} from "./ERC721Common.sol";

/// @title Base721
/// @author dev by @dievardump
/// @notice ERC721 base with Burnable and common stuff for all 721 implementations
contract Base721 is ERC721Common, ERC721Burnable {
    error TooManyRequested();
    error InvalidZeroMint();

    uint256 internal _lastTokenId;

    constructor(
        string memory name_,
        string memory ticker_,
        ERC721CommonConfig memory config
    ) ERC721(name_, ticker_) ERC721Common(config) {}

    /////////////////////////////////////////////////////////
    // Getters                                             //
    /////////////////////////////////////////////////////////

    /// @inheritdoc ERC721
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }

    /// @inheritdoc ERC721
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        return _tokenURI(tokenId);
    }

    /////////////////////////////////////////////////////////
    // Interactions                                        //
    /////////////////////////////////////////////////////////

    /// @inheritdoc ERC721
    /// @dev overrode to add the FilterOperator
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /// @inheritdoc ERC721
    /// @dev overrode to add the FilterOperator
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /// @inheritdoc ERC721
    /// @dev overrode to add the FilterOperator
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /// @inheritdoc ERC721
    /// @dev overrode to add the FilterOperator
    function setApprovalForAll(address operator, bool _approved)
        public
        override
        onlyAllowedOperatorForApproval(operator, _approved)
    {
        super.setApprovalForAll(operator, _approved);
    }

    /// @notice Allows any "minter" to mint `amount` new tokens to `to`
    /// @param to to whom we need to mint
    /// @param amount how many to mint
    function mintTo(address to, uint256 amount) external virtual onlyMinter {
        _mintTo(to, amount);
    }

    /////////////////////////////////////////////////////////
    // Internals                                          //
    /////////////////////////////////////////////////////////

    function _baseURI() internal view virtual override(ERC721, WithMeta) returns (string memory) {
        return WithMeta._baseURI();
    }

    /// @dev mints `amount` tokens to `to`
    /// @param to to whom we need to mint
    /// @param amount how many to mint
    function _mintTo(address to, uint256 amount) internal virtual returns (uint256) {
        if (amount == 0) {
            revert InvalidZeroMint();
        }
        uint256 maxSupply = _maxSupply();
        uint256 lastTokenId = _lastTokenId;

        // check that there is enough supply
        if (maxSupply != 0 && lastTokenId + amount > maxSupply) {
            revert TooManyRequested();
        }

        do {
            unchecked {
                amount--;
                ++lastTokenId;
            }
            _mint(to, lastTokenId);
        } while (amount > 0);

        _lastTokenId = lastTokenId;
        return lastTokenId;
    }

    /// @dev internal config to return the max supply and stop the mint function to work after it's met
    /// @return the max supply, 0 means no max
    function _maxSupply() internal view virtual returns (uint256) {
        return 0;
    }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC2981, ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

import {WithMeta} from "../WithMeta.sol";
import {WithMinters} from "../WithMinters.sol";
import {WithOperatorFilter} from "../WithOperatorFilter/WithOperatorFilter.sol";

import {IERC721Common} from "./IERC721Common.sol";

/// @title ERC721Common
/// @author dev by @dievardump
/// @notice contains all the goodies that can be added to any implementation of ERC721 (OZ, ERC721A, ...)
///         without needing any implementation specific tweaks
contract ERC721Common is IERC721Common, Ownable, ERC2981, WithMeta, WithMinters, WithOperatorFilter {
    constructor(ERC721CommonConfig memory config) {
        if (config.minters.length > 0) {
            _addMinters(config.minters);
        }

        if (bytes(config.baseURI).length > 0) {
            _setBaseURI(config.baseURI);
        }

        if (bytes(config.contractURI).length > 0) {
            contractURI = config.contractURI;
        }

        if (config.metadataManager != address(0)) {
            metadataManager = config.metadataManager;
        }

        if (config.royaltyReceiver != address(0)) {
            _setDefaultRoyalty(config.royaltyReceiver, config.royaltyFeeNumerator);
        }
    }

    /////////////////////////////////////////////////////////
    // Gated Owner                                         //
    /////////////////////////////////////////////////////////

    //// @notice Allows to add minters to this contract
    /// @param newMinters the new minters to add
    function addMinters(address[] calldata newMinters) external onlyOwner {
        _addMinters(newMinters);
    }

    //// @notice Allows to remove minters from this contract
    /// @param oldMinters the old minters to remove
    function removeMinters(address[] calldata oldMinters) external onlyOwner {
        _removeMinters(oldMinters);
    }

    /// @notice Allows owner to update metadataManager
    /// @param newMetadataManager the new address of the third eye
    function setMetadataManager(address newMetadataManager) external onlyOwner {
        metadataManager = newMetadataManager;
    }

    /// @notice Allows owner to update contractURI
    /// @param newContractURI the new contract URI
    function setContractURI(string calldata newContractURI) external onlyOwner {
        contractURI = newContractURI;
    }

    /// @notice allows owner to change the royalties receiver and fees
    /// @param receiver the royalties receiver
    /// @param feeNumerator the fees to ask for; fees are expressed in basis points so 1 == 0.01%, 500 = 5%, 10000 = 100%
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public virtual onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /// @notice allows owner to set the collection base URI value
    /// @param newBaseURI the new base URI
    function setBaseURI(string calldata newBaseURI) public onlyOwner {
        _setBaseURI(newBaseURI);
    }

    /// @notice Allows owner to switch on/off the OperatorFilter
    /// @param newIsEnabled the new state
    function setIsOperatorFilterEnabled(bool newIsEnabled) public onlyOwner {
        isOperatorFilterEnabled = newIsEnabled;
    }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IBase721A {
    /// @notice Allows a `minter` to mint `amount` tokens to `to` with `extraData_`
    /// @param to to whom we need to mint
    /// @param amount how many to mint
    /// @param extraData extraData for these items
    function mintTo(
        address to,
        uint256 amount,
        uint24 extraData
    ) external;
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IERC721Common {
    struct ERC721CommonConfig {
        string contractURI;
        string baseURI;
        address[] minters;
        address metadataManager;
        address royaltyReceiver;
        uint96 royaltyFeeNumerator;
    }
}//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC4907} from "./IERC4907.sol";

/// @title ERC4907 - ERC721 Rental
/// @author dev by @dievardump
/// @notice Generic contract for rentals of ERC721 allowing custom rules for allowing rentals and cancelations
/// @dev dev MUST implement _checkCanRent in their own contract to check for Rental allowance
///      dev CAN override _checkCanCancelRental in their own contract to allow or not a cancelation
abstract contract ERC4907 is IERC4907, ERC165 {
    error NotCurrentRenter();

    uint256 private constant _BITPOS_EXPIRES = 160;

    mapping(uint256 => uint256) internal _rentals;

    /////////////////////////////////////////////////////////
    // Getters                                             //
    /////////////////////////////////////////////////////////
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4907).interfaceId || super.supportsInterface(interfaceId);
    }

    function userOf(uint256 tokenId) public view returns (address) {
        (address renter, uint256 expires) = _rentalData(tokenId);

        // rental has expired, so there is no user
        if (expires < block.timestamp) {
            return address(0);
        }

        return renter;
    }

    function userExpires(uint256 tokenId) public view returns (uint256) {
        (address renter, uint256 expires) = _rentalData(tokenId);

        if (renter == address(0)) {
            expires = 0;
        }

        return expires;
    }

    /////////////////////////////////////////////////////////
    // Actions                                             //
    /////////////////////////////////////////////////////////

    function setUser(
        uint256 tokenId,
        address user,
        uint64 expires
    ) public {
        _checkCanRent(msg.sender, tokenId, user, expires);

        _rentals[tokenId] = (uint256(expires) << _BITPOS_EXPIRES) | uint256(uint160(user));
        emit UpdateUser(tokenId, user, expires);
    }

    /// @notice allows current caller to cancel the rental for tokenId
    /// @param tokenId the token id
    function cancelRental(uint256 tokenId) public {
        _checkCanCancelRental(msg.sender, tokenId);

        _rentals[tokenId] = 0;
        emit UpdateUser(tokenId, address(0), 0);
    }

    /////////////////////////////////////////////////////////
    // Internals                                           //
    /////////////////////////////////////////////////////////

    function _rentalData(uint256 tokenId) internal view returns (address, uint256) {
        uint256 rental = _rentals[tokenId];
        return (address(uint160(rental)), rental >> _BITPOS_EXPIRES);
    }

    /// @dev by default, only the current renter can cancel a rental
    /// @param operator the current caller
    /// @param tokenId the token id to cancel the rental for
    function _checkCanCancelRental(address operator, uint256 tokenId) internal view virtual {
        if (operator != userOf(tokenId)) {
            revert NotCurrentRenter();
        }
    }

    /// @notice Function used to check if `operator` can rent `tokenId` to `user` until `expires`
    ///         this function MUST REVERT if the rental is invalid
    /// @dev MUST be defined in consumer contract
    /// @param operator the operator trying to do the rent
    /// @param tokenId the token id to rent
    /// @param user the possible renter
    /// @param expires the rent expiration
    function _checkCanRent(
        address operator,
        uint256 tokenId,
        address user,
        uint64 expires
    ) internal view virtual;
}//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IERC4907 {
    // Logged when the user of an NFT is changed or expires is changed
    /// @notice Emitted when the `user` of an NFT or the `expires` of the `user` is changed
    /// The zero address for user indicates that there is no user address
    event UpdateUser(uint256 indexed tokenId, address indexed user, uint64 expires);

    /// @notice set the user and expires of an NFT
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    function setUser(
        uint256 tokenId,
        address user,
        uint64 expires
    ) external;

    /// @notice Get the user address of an NFT
    /// @dev The zero address indicates that there is no user or the user is expired
    /// @param tokenId The NFT to get the user address for
    /// @return The user address for this NFT
    function userOf(uint256 tokenId) external view returns (address);

    /// @notice Get the user expires of an NFT
    /// @dev The zero value indicates that there is no user
    /// @param tokenId The NFT to get the user expires for
    /// @return The user expires for this NFT
    function userExpires(uint256 tokenId) external view returns (uint256);
}//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title EIP-721 Metadata Update Extension
interface IERC4906 is IERC165 {
    /// @dev This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
}