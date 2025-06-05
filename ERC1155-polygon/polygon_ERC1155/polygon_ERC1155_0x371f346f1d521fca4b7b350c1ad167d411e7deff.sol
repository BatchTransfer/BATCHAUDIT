// Chain: POLYGON - File: contracts/fraktions/FraktionTokens.sol
// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { ERC1155Upgradeable } from "@oz-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { FraktionTransferCallback } from "./FraktionTransferCallback.sol";
import { ContentId } from "../libs/ContentId.sol";
import { FraktionId } from "../libs/FraktionId.sol";
import { ArrayLib } from "../libs/ArrayLib.sol";
import { FrakRoles } from "../roles/FrakRoles.sol";
import { FrakAccessControlUpgradeable } from "../roles/FrakAccessControlUpgradeable.sol";
import { InvalidArray, InvalidSigner } from "../utils/FrakErrors.sol";
import { EIP712Diamond } from "../utils/EIP712Diamond.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @author @KONFeature
/// @title FraktionTokens
/// @notice ERC1155 for the Frak Fraktions tokens, used as ownership proof for a content, or investisment proof
/// @custom:security-contact contact@frak.id
contract FraktionTokens is FrakAccessControlUpgradeable, ERC1155Upgradeable, EIP712Diamond {
    /* -------------------------------------------------------------------------- */
    /*                               Custom errors                                */
    /* -------------------------------------------------------------------------- */

    /// @dev Error throwned when we don't have enough supply to mint a new fNFT
    error InsuficiantSupply();

    /// @dev Error throwned when we try to update the supply of a non supply aware token
    error SupplyUpdateNotAllowed();

    /// @dev 'bytes4(keccak256("InsuficiantSupply()"))'
    uint256 private constant _INSUFICIENT_SUPPLY_SELECTOR = 0xa24b545a;

    /// @dev 'bytes4(keccak256("InvalidArray()"))'
    uint256 private constant _INVALID_ARRAY_SELECTOR = 0x1ec5aa51;

    /// @dev 'bytes4(keccak256("SupplyUpdateNotAllowed()"))'
    uint256 private constant _SUPPLY_UPDATE_NOT_ALLOWED_SELECTOR = 0x48385ebd;

    /// @dev 'bytes4(keccak256(bytes("PermitDelayExpired()")))'
    uint256 private constant _PERMIT_DELAYED_EXPIRED_SELECTOR = 0x95fc6e60;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when the supply of a fraktion is updated
    event SuplyUpdated(uint256 indexed id, uint256 supply);

    /// @dev Event emitted when the owner of a content changed
    event ContentOwnerUpdated(uint256 indexed id, address indexed owner);

    /// @dev 'keccak256(bytes("SuplyUpdated(uint256,uint256)"))'
    uint256 private constant _SUPPLY_UPDATED_EVENT_SELECTOR =
        0xb137aebbacc26855c231fff6d377b18aaa6397ab7c49bb7481d78a529017564d;

    /// @dev 'keccak256(bytes("ContentOwnerUpdated(uint256,address)"))'
    uint256 private constant _CONTENT_OWNER_UPDATED_EVENT_SELECTOR =
        0x4d30aa74825efbda2206e0f3ac5b20d3d5806e54280b6684b6f380afcbfc51d2;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The current content id
    uint256 private _currentContentId;

    /// @dev The current callback
    FraktionTransferCallback private transferCallback;

    /// @dev Id of content to owner of this content
    /// @notice This is unused now, since we rely on the balanceOf m
    mapping(uint256 id => address owner) private owners;

    /// @dev Available supply of each fraktion (classic, rare, epic and legendary only) by they id
    mapping(uint256 id => uint256 availableSupply) private _availableSupplies;

    /// @dev Tell us if that fraktion is supply aware or not
    /// @notice unused now since we rely on the fraktion type to know if it is supply aware or not
    mapping(uint256 => bool) private _unused1;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Versioning                                 */
    /* -------------------------------------------------------------------------- */

    function initialize(string calldata metadatalUrl) external initializer {
        __ERC1155_init(metadatalUrl);
        __FrakAccessControlUpgradeable_Minter_init();
        _initializeEIP712("Fraktions");
        // Set the initial content id
        _currentContentId = 1;
    }

    /// @dev Update to diamond Eip712
    function updateToDiamondEip712() external reinitializer(3) {
        _initializeEIP712("Fraktions");
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Mint a new content, return the id of the built content
    /// @param ownerAddress The address of the content owner
    /// @param suppliesToType The supplies to type array, each element of the array is a tuple on a byte [supply, type],
    /// type on 0xf, supply on all the remaining bytes
    function mintNewContent(
        address ownerAddress,
        uint256[] calldata suppliesToType
    )
        external
        payable
        onlyRole(FrakRoles.MINTER)
        returns (ContentId id)
    {
        uint256 creatorTokenId;
        assembly {
            // Get the next content id and increment the current content id
            id := add(sload(_currentContentId.slot), 1)
            sstore(_currentContentId.slot, id)

            // Get the shifted id, to ease the fraktion id creation
            let shiftedId := shl(0x04, id)

            // Iterate over each fraktion type, build their id, and set their supply
            // Get where our offset end
            let offsetEnd := shl(5, suppliesToType.length)
            // Current iterator offset
            let currentOffset := 0
            // Infinite loop
            for { } 1 { } {
                // Get the current id
                let currentItem := calldataload(add(suppliesToType.offset, currentOffset))
                let fraktionType := and(currentItem, 0xF)

                // Ensure the supply update of this fraktion type is allowed
                if or(lt(fraktionType, 3), gt(fraktionType, 6)) {
                    // If fraktion type lower than 3 -> free or owner
                    mstore(0x00, _SUPPLY_UPDATE_NOT_ALLOWED_SELECTOR)
                    revert(0x1c, 0x04)
                }

                // Build the fraktion id
                let fraktionId := or(shiftedId, fraktionType)

                // Get the supply
                let supply := shr(4, currentItem)

                // Get the supply slot and update it
                // Kecak (id, _availableSupplies.slot)
                mstore(0, fraktionId)
                mstore(0x20, _availableSupplies.slot)
                sstore(keccak256(0, 0x40), supply)
                // Emit the supply updated event
                mstore(0, supply)
                log2(0, 0x20, _SUPPLY_UPDATED_EVENT_SELECTOR, fraktionId)

                // Increase the iterator
                currentOffset := add(currentOffset, 0x20)
                // Exit if we reached the end
                if iszero(lt(currentOffset, offsetEnd)) { break }
            }

            // Update creator supply now
            creatorTokenId := or(shiftedId, 1)
            // Then store the available supply of 1 (since only one creator nft is possible)
            mstore(0, creatorTokenId)
            mstore(0x20, _availableSupplies.slot)
            sstore(keccak256(0, 0x40), 1)
        }

        // Mint the content nft into the content owner wallet directly
        _mint(ownerAddress, creatorTokenId, 1, "");

        // Return the content id
        return id;
    }

    /// @dev Set the supply for the given fraktion id
    function addSupply(FraktionId id, uint256 supply) external payable onlyRole(FrakRoles.MINTER) {
        assembly {
            // Ensure the supply update of this fraktion type is allowed
            let fraktionType := and(id, 0xF)
            if or(lt(fraktionType, 3), gt(fraktionType, 6)) {
                // If fraktion type lower than 3 -> free or owner, if greater than 6 -> not a content
                mstore(0x00, _SUPPLY_UPDATE_NOT_ALLOWED_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Kecak (id, _availableSupplies.slot)
            mstore(0, id)
            mstore(0x20, _availableSupplies.slot)
            let supplySlot := keccak256(0, 0x40)
            // Get the supply slot and update it
            sstore(supplySlot, add(sload(supplySlot), supply))
            // Emit the supply updated event
            mstore(0, supply)
            log2(0, 0x20, _SUPPLY_UPDATED_EVENT_SELECTOR, id)
        }
    }

    /// @dev Register a new transaction callback
    function registerNewCallback(address callbackAddr) external onlyRole(FrakRoles.ADMIN) {
        transferCallback = FraktionTransferCallback(callbackAddr);
    }

    /// @dev Mint a new fraktion of a nft
    function mint(address to, FraktionId id, uint256 amount) external payable onlyRole(FrakRoles.MINTER) {
        _mint(to, FraktionId.unwrap(id), amount, "");
    }

    /// @dev Burn a fraktion of a nft
    function burn(FraktionId id, uint256 amount) external payable {
        _burn(msg.sender, FraktionId.unwrap(id), amount);
    }

    /// @dev Transfer all the fraktions from the given user to a new one
    function transferAllFrom(address from, address to, uint256[] calldata ids) external payable {
        // Build the amounts matching the ids
        uint256 length = ids.length;
        uint256[] memory amounts = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            unchecked {
                amounts[i] = balanceOf(from, ids[i]);
                ++i;
            }
        }

        // Perform the batch transfer
        safeBatchTransferFrom(from, to, ids, amounts, "");
    }

    /* -------------------------------------------------------------------------- */
    /*                              Allowance methods                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Signature check to allow a user to transfer ERC-1155 on the behalf of the owner
    function permitAllTransfer(
        address owner,
        address spender,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        payable
    {
        // Ensure deadline is valid
        assembly {
            if gt(timestamp(), deadline) {
                mstore(0x00, _PERMIT_DELAYED_EXPIRED_SELECTOR)
                revert(0x1c, 0x04)
            }
        }

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ECDSA.recover(
                toTypedMessageHash(
                    keccak256(
                        abi.encode(
                            keccak256("PermitAllTransfer(address owner,address spender,uint256 nonce,uint256 deadline)"),
                            owner,
                            spender,
                            useNonce(owner),
                            deadline
                        )
                    )
                ),
                v,
                r,
                s
            );

            // Don't need to check for 0 address, or send event, since approve already do it for us
            if (recoveredAddress != owner) revert InvalidSigner();

            // Approve the token
            _setApprovalForAll(recoveredAddress, spender, true);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                        Internal callback functions                         */
    /* -------------------------------------------------------------------------- */

    /// @dev Handle the transfer token (so update the content investor, change the owner of some content etc)
    function _beforeTokenTransfer(
        address,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    )
        internal
        override
    {
        // Directly exit if we are not concerned by a mint or burn
        if (from != address(0) && to != address(0)) return;

        // Assembly block to check supply and decrease it if needed
        assembly {
            // Base offset to access array elements
            let currOffset := 0x20
            let offsetEnd := add(currOffset, shl(5, mload(ids)))

            // Infinite loop
            for { } 1 { } {
                // Get the id and amount
                let id := mload(add(ids, currOffset))
                let amount := mload(add(amounts, currOffset))

                // Supply aware code block
                // If fraktion type == 1 (creator) or fraktion type > 2 & < 7 (payed fraktion)
                let fraktionType := and(id, 0xF)
                if or(eq(fraktionType, 1), and(gt(fraktionType, 2), lt(fraktionType, 7))) {
                    // Get the supply slot
                    // Kecak (id, _availableSupplies.slot)
                    mstore(0, id)
                    mstore(0x20, _availableSupplies.slot)
                    let availableSupplySlot := keccak256(0, 0x40)
                    let availableSupply := sload(availableSupplySlot)
                    // Ensure we have enough supply
                    if and(iszero(from), gt(amount, availableSupply)) {
                        mstore(0x00, _INSUFICIENT_SUPPLY_SELECTOR)
                        revert(0x1c, 0x04)
                    }
                    // Update the supply
                    if iszero(from) { availableSupply := sub(availableSupply, amount) }
                    if iszero(to) { availableSupply := add(availableSupply, amount) }
                    sstore(availableSupplySlot, availableSupply)
                }

                // Increase our offset's
                currOffset := add(currOffset, 0x20)

                // Exit if we reached the end
                if iszero(lt(currOffset, offsetEnd)) { break }
            }
        }
    }

    /// @dev Handle the transfer token (so update the content investor, change the owner of some content etc)
    function _afterTokenTransfer(
        address,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    )
        internal
        override
    {
        assembly {
            // Base offset to access array elements
            let currOffset := 0x20
            let offsetEnd := add(currOffset, shl(5, mload(ids)))

            // Check if we got at least one fraktion needing callback (one that is higher than creator or free)
            let hasOneFraktionForCallback := false

            // Infinite loop
            for { } 1 { } {
                // Get the id and amount
                let id := mload(add(ids, currOffset))

                // Content owner migration code block
                if eq(and(id, 0xF), 1) {
                    let contentId := shr(0x04, id)
                    // Get the owner slot
                    // Kecak (contentId, owners.slot)
                    mstore(0, contentId)
                    mstore(0x20, owners.slot)
                    // Update the owner
                    sstore(keccak256(0, 0x40), to)
                    // Log the event
                    log3(0, 0, _CONTENT_OWNER_UPDATED_EVENT_SELECTOR, contentId, to)
                }

                // Check if we need to include this in our filtered ids array
                hasOneFraktionForCallback := or(hasOneFraktionForCallback, gt(and(id, 0xF), 2))

                // Increase our offset's
                currOffset := add(currOffset, 0x20)

                // Exit if we reached the end
                if iszero(lt(currOffset, offsetEnd)) { break }
            }

            // If no fraktion needing callback, exit directly
            if iszero(hasOneFraktionForCallback) { return(0, 0x20) }
            // If empty callback address, exit directly
            if iszero(sload(transferCallback.slot)) { return(0, 0x20) }
        }

        // Call our callback
        transferCallback.onFraktionsTransferred(from, to, ArrayLib.asFraktionIds(ids), amounts);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Public view functions                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Batch balance of for single address
    function balanceOfIdsBatch(
        address account,
        FraktionId[] calldata ids
    )
        public
        view
        virtual
        returns (uint256[] memory batchBalances)
    {
        assembly {
            // Get the free mem pointer for our batch balances
            batchBalances := mload(0x40)
            // Store the size of our array
            mstore(batchBalances, ids.length)
            // Get where our array ends
            let end := add(ids.offset, shl(5, ids.length))
            // Current iterator offset
            let i := ids.offset
            // Current balance array offset
            let balanceOffset := add(batchBalances, 0x20)
            // Infinite loop
            for { } 1 { } {
                // Get the slot for the current id
                mstore(0, calldataload(i))
                mstore(0x20, 0xcb) // `_balances.slot` on the OZ contract
                // Store it as destination for the account balance we will check
                mstore(0x20, keccak256(0, 0x40))
                // Slot for the balance of the given account
                mstore(0, account)
                // Set the balance at the right index
                mstore(balanceOffset, sload(keccak256(0, 0x40)))
                // Increase the iterator
                i := add(i, 0x20)
                balanceOffset := add(balanceOffset, 0x20)
                // Exit if we reached the end
                if iszero(lt(i, end)) { break }
            }
            // Set the new free mem pointer
            mstore(0x40, balanceOffset)
        }
    }

    /// @dev Find the owner of the given 'contentId'
    function ownerOf(ContentId contentId) external view returns (address) {
        return owners[ContentId.unwrap(contentId)];
    }

    /// @dev Find the current supply of the given 'tokenId'
    function supplyOf(FraktionId tokenId) external view returns (uint256) {
        return _availableSupplies[FraktionId.unwrap(tokenId)];
    }
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155Upgradeable.sol";
import "./IERC1155ReceiverUpgradeable.sol";
import "./extensions/IERC1155MetadataURIUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC1155Upgradeable, IERC1155MetadataURIUpgradeable {
    using AddressUpgradeable for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    function __ERC1155_init(string memory uri_) internal onlyInitializing {
        __ERC1155_init_unchained(uri_);
    }

    function __ERC1155_init_unchained(string memory uri_) internal onlyInitializing {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC1155Upgradeable).interfaceId ||
            interfaceId == type(IERC1155MetadataURIUpgradeable).interfaceId ||
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
            try IERC1155ReceiverUpgradeable(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155Received.selector) {
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
            try IERC1155ReceiverUpgradeable(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector) {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}


// Chain: POLYGON - File: contracts/fraktions/FraktionTransferCallback.sol
// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FraktionId } from "../libs/FraktionId.sol";

/// @author @KONFeature
/// @title FraktionTransferCallback
/// @notice Interface for contract who want to listen of the fraktion transfer (ERC1155 tokens transfer)
/// @custom:security-contact contact@frak.id
interface FraktionTransferCallback {
    /**
     * @dev Function called when a fraktion is transfered between two person
     */
    function onFraktionsTransferred(
        address from,
        address to,
        FraktionId[] memory ids,
        uint256[] memory amount
    )
        external
        payable;
}


// Chain: POLYGON - File: contracts/libs/ContentId.sol
// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FraktionId } from "./FraktionId.sol";

/// @dev Define the ContentId type
type ContentId is uint256;

/// @dev Tell to use the lib below for every ContentId instance
using ContentIdLib for ContentId global;

/// @author @KONFeature
/// @title ContentIdLib
/// @notice This contract is used to help us with the manipulation of the ContentId
/// @custom:security-contact contact@frak.id
library ContentIdLib {
    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The offset of the id we use to store the fraktion type
    uint256 internal constant ID_OFFSET = 4;
    /// @dev The mask we use to store the fraktion type in the fraktion id
    uint256 internal constant TYPE_MASK = 0xF;

    /// @dev NFT Token type mask
    uint256 internal constant FRAKTION_TYPE_CREATOR = 1;
    /// @dev Free Token type mask
    uint256 internal constant FRAKTION_TYPE_FREE = 2;
    /// @dev Common Token type mask
    uint256 internal constant FRAKTION_TYPE_COMMON = 3;
    /// @dev Premium Token type mask
    uint256 internal constant FRAKTION_TYPE_PREMIUM = 4;
    /// @dev Gold Token type mask
    uint256 internal constant FRAKTION_TYPE_GOLD = 5;
    /// @dev Diamond Token type mask
    uint256 internal constant FRAKTION_TYPE_DIAMOND = 6;

    /* -------------------------------------------------------------------------- */
    /*                               Helper functions                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Build a fraktion id from a content id
    function toFraktionId(ContentId self, uint256 fraktionType) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), fraktionType)
        }
    }

    /// @dev Build the id for a creator NFT id
    function creatorFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_CREATOR)
        }
    }

    /// @dev Build the id for a free NFT id
    function freeFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_FREE)
        }
    }

    /// @dev Build the id for a common NFT id
    function commonFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_COMMON)
        }
    }

    /// @dev Build the id for a premium NFT id
    function premiumFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_PREMIUM)
        }
    }

    /// @dev Build the id for a gold NFT id
    function goldFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_GOLD)
        }
    }

    /// @dev Build the id for a diamond NFT id
    function diamondFraktionId(ContentId self) internal pure returns (FraktionId id) {
        assembly {
            id := or(shl(ID_OFFSET, self), FRAKTION_TYPE_DIAMOND)
        }
    }

    /// @dev Build an array of all the payable fraktion types
    function payableFraktionIds(ContentId self) internal pure returns (FraktionId[] memory ids) {
        assembly {
            // Store each types
            ids := mload(0x40)
            mstore(ids, 4)
            mstore(add(ids, 0x20), or(shl(ID_OFFSET, self), FRAKTION_TYPE_COMMON))
            mstore(add(ids, 0x40), or(shl(ID_OFFSET, self), FRAKTION_TYPE_PREMIUM))
            mstore(add(ids, 0x60), or(shl(ID_OFFSET, self), FRAKTION_TYPE_GOLD))
            mstore(add(ids, 0x80), or(shl(ID_OFFSET, self), FRAKTION_TYPE_DIAMOND))
            // Update our free mem space
            mstore(0x40, add(ids, 0xA0))
        }
    }

    /// @dev Create a new array with the given element
    function asSingletonArray(ContentId self) internal pure returns (ContentId[] memory array) {
        assembly {
            // Get free memory space for our array, and update the free mem space index
            array := mload(0x40)
            mstore(0x40, add(array, 0x40))

            // Store our array (1st = length, 2nd = element)
            mstore(array, 0x01)
            mstore(add(array, 0x20), self)
        }
    }
}


// Chain: POLYGON - File: contracts/libs/FraktionId.sol
// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

/// @dev Define the FraktionId type
type FraktionId is uint256;

/// @dev Tell to use the lib below for every FraktionId instance
using FraktionIdLib for FraktionId global;

/// @author @KONFeature
/// @title FraktionIdLib
/// @notice This contract is used to help us with the manipulation of the FraktionId
/// @custom:security-contact contact@frak.id
library FraktionIdLib {
    /// @dev The offset of the id we use to store the fraktion type
    uint256 internal constant ID_OFFSET = 4;
    /// @dev The mask we use to store the fraktion type in the fraktion id
    uint256 internal constant TYPE_MASK = 0xF;

    /// @dev Get the `contentId` from the `self` fraktion id
    function isNotPayable(FraktionId self) internal pure returns (bool notPayable) {
        assembly {
            let fType := and(self, TYPE_MASK)
            notPayable := or(lt(fType, 3), gt(fType, 6))
        }
    }

    /// @dev Get the `contentId` from the `self` fraktion id
    function getContentId(FraktionId self) internal pure returns (uint256 contentId) {
        assembly {
            contentId := shr(ID_OFFSET, self)
        }
    }

    /// @dev Get the `fraktionType` from the `self` fraktion id
    function getFraktionType(FraktionId self) internal pure returns (uint256 fraktionType) {
        assembly {
            fraktionType := and(self, TYPE_MASK)
        }
    }

    /// @dev Get the `contentId` and `fraktionType` from the `self` fraktion id
    function extractAll(FraktionId self) internal pure returns (uint256 contentId, uint256 fraktionType) {
        assembly {
            contentId := shr(ID_OFFSET, self)
            fraktionType := and(self, TYPE_MASK)
        }
    }

    /// @dev Create a new array with the given element
    function asSingletonArray(FraktionId self) internal pure returns (FraktionId[] memory array) {
        assembly {
            // Get free memory space for our array, and update the free mem space index
            array := mload(0x40)
            mstore(0x40, add(array, 0x40))

            // Store our array (1st = length, 2nd = element)
            mstore(array, 0x01)
            mstore(add(array, 0x20), self)
        }
    }
}


// Chain: POLYGON - File: contracts/libs/ArrayLib.sol
// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FraktionId } from "./FraktionId.sol";

/// @author @KONFeature
/// @title ArrayLib
/// @notice Lib to help us manage array
/// @custom:security-contact contact@frak.id
library ArrayLib {
    /// @dev Wrap a uint256 to a FraktionId type
    function asFraktionIds(uint256[] memory self) internal pure returns (FraktionId[] memory fraktionIds) {
        assembly {
            fraktionIds := self
        }
    }

    /// @dev Create a singleton array of the given element
    function asSingletonArray(uint256 element) internal pure returns (uint256[] memory array) {
        assembly {
            // Get free memory space for our array, and update the free mem space index
            array := mload(0x40)
            mstore(0x40, add(array, 0x40))

            // Store our array (1st = length, 2nd = element)
            mstore(array, 0x01)
            mstore(add(array, 0x20), element)
        }
    }

    /// @dev Create a singleton array of the given element
    function asSingletonArray(address element) internal pure returns (address[] memory array) {
        assembly {
            // Get free memory space for our array, and update the free mem space index
            array := mload(0x40)
            mstore(0x40, add(array, 0x40))

            // Store our array (1st = length, 2nd = element)
            mstore(array, 0x01)
            mstore(add(array, 0x20), element)
        }
    }
}


// Chain: POLYGON - File: contracts/roles/FrakRoles.sol
// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

/// @author @KONFeature
/// @title FrakRoles
/// @notice All the roles of the frak ecosystem
/// @custom:security-contact contact@frak.id
library FrakRoles {
    /// @dev Administrator role of a contra
    bytes32 internal constant ADMIN = 0x00;

    /// @dev Role required to update a smart contract
    bytes32 internal constant UPGRADER = keccak256("UPGRADER_ROLE");

    /// @dev Role required to mint new token on in a contract
    bytes32 internal constant MINTER = keccak256("MINTER_ROLE");

    /// @dev Role required to update the badge in a contract
    bytes32 internal constant BADGE_UPDATER = keccak256("BADGE_UPDATER_ROLE");

    /// @dev Role required to reward user for their listen
    bytes32 internal constant REWARDER = keccak256("REWARDER_ROLE");

    /// @dev Role required to perform token specific actions on a contract
    bytes32 internal constant TOKEN_CONTRACT = keccak256("TOKEN_ROLE");

    /// @dev Role required to manage the vesting wallets
    bytes32 internal constant VESTING_MANAGER = keccak256("VESTING_MANAGER");

    /// @dev Role required to create new vesting
    bytes32 internal constant VESTING_CREATOR = keccak256("VESTING_CREATOR");
}


// Chain: POLYGON - File: contracts/roles/FrakAccessControlUpgradeable.sol
// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { Initializable } from "@oz-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ContextUpgradeable } from "@oz-upgradeable/utils/ContextUpgradeable.sol";
import { FrakRoles } from "./FrakRoles.sol";
import { NotAuthorized, RenounceForCallerOnly } from "../utils/FrakErrors.sol";

/**
 * @author @KONFeature
 * @title FrakAccessControlUpgradeable
 * @dev This contract provides an upgradeable access control framework, with roles and pausing functionality.
 *
 * Roles can be granted and revoked by a designated admin role, and certain functions can be restricted to certain roles
 * using the 'onlyRole' modifier. The contract can also be paused, disabling all non-admin functionality.
 *
 * This contract is upgradeable, meaning that it can be replaced with a new implementation, while preserving its state.
 *
 * @custom:security-contact contact@frak.id
 */
abstract contract FrakAccessControlUpgradeable is Initializable, ContextUpgradeable, UUPSUpgradeable {
    /* -------------------------------------------------------------------------- */
    /*                               Custom errors                                */
    /* -------------------------------------------------------------------------- */

    /// @dev 'bytes4(keccak256(bytes("NotAuthorized()")))'
    uint256 private constant _NOT_AUTHORIZED_SELECTOR = 0xea8e4eb5;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a role is granted
    event RoleGranted(address indexed account, bytes32 indexed role);
    /// @dev Event emitted when a role is revoked
    event RoleRevoked(address indexed account, bytes32 indexed role);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Is this contract currently paused ?
    /// @dev Unused now, since pausim mecanism isn't here anymore, can be reused
    bool private _paused;

    /// @dev Mapping of roles -> user -> hasTheRight
    mapping(bytes32 roles => mapping(address user => bool isAllowed)) private _roles;

    /// @dev Initialise the contract and also grant the role to the msg sender
    function __FrakAccessControlUpgradeable_init() internal onlyInitializing {
        __Context_init();
        __UUPSUpgradeable_init();

        _grantRole(FrakRoles.ADMIN, msg.sender);
        _grantRole(FrakRoles.UPGRADER, msg.sender);

        // Tell we are not paused at start
        _paused = false;
    }

    /// @dev Initialise the contract and also grant the role to the msg sender
    function __FrakAccessControlUpgradeable_Minter_init() internal onlyInitializing {
        __FrakAccessControlUpgradeable_init();

        _grantRole(FrakRoles.MINTER, msg.sender);
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Grant the `role` to the `account`
    function grantRole(bytes32 role, address account) external onlyRole(FrakRoles.ADMIN) {
        _grantRole(role, account);
    }

    /// @dev Revoke the `role` to the `account`
    function revokeRole(bytes32 role, address account) external onlyRole(FrakRoles.ADMIN) {
        _revokeRole(role, account);
    }

    /// @dev `Account` renounce to the `role`
    function renounceRole(bytes32 role, address account) external {
        if (account != msg.sender) revert RenounceForCallerOnly();

        _revokeRole(role, account);
    }

    /* -------------------------------------------------------------------------- */
    /*                          External view functions                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Check if the user has the given role
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal write functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Grant the `role` to the `account`
    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(account, role);
        }
    }

    /// @dev Revoke the given `role` to the `account`
    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(account, role);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal view functions                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Check that the calling user have the right `role`
    function _checkRole(bytes32 role) private view {
        address sender = msg.sender;
        assembly {
            // Kecak (role, _roles.slot)
            mstore(0, role)
            mstore(0x20, _roles.slot)
            let roleSlote := keccak256(0, 0x40)
            // Kecak (acount, roleSlot)
            mstore(0, sender)
            mstore(0x20, roleSlote)
            let slot := keccak256(0, 0x40)

            // Get var at the given slot
            let hasTheRole := sload(slot)

            // Ensre the user has the right roles
            if eq(hasTheRole, false) {
                mstore(0x00, _NOT_AUTHORIZED_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Modifiers                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Ensure the calling user have the right role
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @notice Authorize the upgrade of this contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(FrakRoles.UPGRADER) { }
}


// Chain: POLYGON - File: contracts/utils/FrakErrors.sol
// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

// Access control error (when accessing unauthorized method, or renouncing role that he havn't go)
error RenounceForCallerOnly();
error NotAuthorized();

// Generic error used for all the contract
error InvalidArray();
error InvalidAddress();
error NoReward();
error RewardTooLarge();
error BadgeTooLarge();
error InvalidFraktionType();

/// @dev error throwned when the signer is invalid
error InvalidSigner();
/// @dev error throwned when the permit delay is expired
error PermitDelayExpired();


// Chain: POLYGON - File: contracts/utils/EIP712Diamond.sol
// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { Initializable } from "@oz-upgradeable/proxy/utils/Initializable.sol";

/// @author @KONFeature
/// @title EIP712Diamond
/// @notice EIP712Diamond base contract with diamond storage
/// @custom:security-contact contact@frak.id
/// TODO: Use OZ5 -> Import another submodule based on OZ 5.0
contract EIP712Diamond {
    struct EIP712Domain {
        string name;
        string version;
        address verifyingContract;
        bytes32 salt;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The current version of the erc712, 2 since we switch between inline storage to diamond storage
    string internal constant ERC712_VERSION = "2";

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The storage struct for eip 712
    struct EIP712Storage {
        /// @dev The current domain seperator
        bytes32 _domainSeperator;
        /// @dev Nonces per account
        mapping(address account => uint256 nonce) _nonces;
    }

    /// @dev Access the storage struct of the contract
    function _getEIP712Storage() internal pure returns (EIP712Storage storage $) {
        assembly {
            // keccak256(abi.encode(uint256(keccak256("EIP712Diamond")) - 1)) & ~bytes32(uint256(0xff))
            $.slot := 0x8525956dfba681ee43bd6f7490f38cd4b2b234d15019aabbaf5a265041a3fb00
        }
    }

    /// @dev init function
    function _initializeEIP712(string memory name) internal {
        // Build and set the domain separator
        _getEIP712Storage()._domainSeperator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(ERC712_VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                             Public view methods                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Current domain seperator
    function getDomainSeperator() public view returns (bytes32) {
        return _getEIP712Storage()._domainSeperator;
    }

    /// @dev Get the current 'nonce' for the given 'user'
    function getNonce(address user) public view returns (uint256) {
        return _getEIP712Storage()._nonces[user];
    }

    /// @dev Use the current 'nonce' for the given 'user' (and increment it)
    function useNonce(address user) public returns (uint256) {
        return _getEIP712Storage()._nonces[user]++;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Internal functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * Accept message hash and returns hash message in EIP712 compatible form
     * So that it can be used to recover signer from signature signed using EIP712 formatted data
     * https://eips.ethereum.org/EIPS/eip-712
     * "\\x19" makes the encoding deterministic
     * "\\x01" is the version byte to make it compatible to EIP-191
     */
    function toTypedMessageHash(bytes32 messageHash) internal view returns (bytes32 digest) {
        bytes32 separator = _getEIP712Storage()._domainSeperator;
        assembly {
            // Compute the digest.
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, separator) // Store the domain separator.
            mstore(0x3a, messageHash) // Store the message hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }
    }
}


// Chain: POLYGON - File: lib/solady/src/utils/ECDSA.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Gas optimized ECDSA wrapper.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ECDSA.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ECDSA.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol)
///
/// WARNING! Do NOT use signatures as unique identifiers.
/// Please use EIP712 with a nonce included in the digest to prevent replay attacks.
/// This implementation does NOT check if a signature is non-malleable.
library ECDSA {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The signature is invalid.
    error InvalidSignature();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    RECOVERY OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Note: as of Solady version 0.0.68, these functions will
    // revert upon recovery failure for more safety by default.

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the `signature`.
    ///
    /// This function does NOT accept EIP-2098 short form signatures.
    /// Use `recover(bytes32 hash, bytes32 r, bytes32 vs)` for EIP-2098
    /// short form signatures instead.
    function recover(bytes32 hash, bytes memory signature) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            let signatureLength := mload(signature)
            mstore(0x00, hash)
            mstore(0x20, byte(0, mload(add(signature, 0x60)))) // `v`.
            mstore(0x40, mload(add(signature, 0x20))) // `r`.
            mstore(0x60, mload(add(signature, 0x40))) // `s`.
            result :=
                mload(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        eq(signatureLength, 65), // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x01, // Start of output.
                        0x20 // Size of output.
                    )
                )
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            if iszero(returndatasize()) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the `signature`.
    ///
    /// This function does NOT accept EIP-2098 short form signatures.
    /// Use `recover(bytes32 hash, bytes32 r, bytes32 vs)` for EIP-2098
    /// short form signatures instead.
    function recoverCalldata(bytes32 hash, bytes calldata signature)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, hash)
            mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40)))) // `v`.
            calldatacopy(0x40, signature.offset, 0x40) // Copy `r` and `s`.
            result :=
                mload(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        eq(signature.length, 65), // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x01, // Start of output.
                        0x20 // Size of output.
                    )
                )
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            if iszero(returndatasize()) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the EIP-2098 short form signature defined by `r` and `vs`.
    ///
    /// This function only accepts EIP-2098 short form signatures.
    /// See: https://eips.ethereum.org/EIPS/eip-2098
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, hash)
            mstore(0x20, add(shr(255, vs), 27)) // `v`.
            mstore(0x40, r)
            mstore(0x60, shr(1, shl(1, vs))) // `s`.
            result :=
                mload(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        1, // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x01, // Start of output.
                        0x20 // Size of output.
                    )
                )
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            if iszero(returndatasize()) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the signature defined by `v`, `r`, `s`.
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, hash)
            mstore(0x20, and(v, 0xff))
            mstore(0x40, r)
            mstore(0x60, s)
            result :=
                mload(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        1, // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x01, // Start of output.
                        0x20 // Size of output.
                    )
                )
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            if iszero(returndatasize()) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   TRY-RECOVER OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // WARNING!
    // These functions will NOT revert upon recovery failure.
    // Instead, they will return the zero address upon recovery failure.
    // It is critical that the returned address is NEVER compared against
    // a zero address (e.g. an uninitialized address variable).

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the `signature`.
    ///
    /// This function does NOT accept EIP-2098 short form signatures.
    /// Use `recover(bytes32 hash, bytes32 r, bytes32 vs)` for EIP-2098
    /// short form signatures instead.
    function tryRecover(bytes32 hash, bytes memory signature)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            let signatureLength := mload(signature)
            mstore(0x00, hash)
            mstore(0x20, byte(0, mload(add(signature, 0x60)))) // `v`.
            mstore(0x40, mload(add(signature, 0x20))) // `r`.
            mstore(0x60, mload(add(signature, 0x40))) // `s`.
            pop(
                staticcall(
                    gas(), // Amount of gas left for the transaction.
                    eq(signatureLength, 65), // Address of `ecrecover`.
                    0x00, // Start of input.
                    0x80, // Size of input.
                    0x40, // Start of output.
                    0x20 // Size of output.
                )
            )
            mstore(0x60, 0) // Restore the zero slot.
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            result := mload(xor(0x60, returndatasize()))
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the `signature`.
    ///
    /// This function does NOT accept EIP-2098 short form signatures.
    /// Use `recover(bytes32 hash, bytes32 r, bytes32 vs)` for EIP-2098
    /// short form signatures instead.
    function tryRecoverCalldata(bytes32 hash, bytes calldata signature)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, hash)
            mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40)))) // `v`.
            calldatacopy(0x40, signature.offset, 0x40) // Copy `r` and `s`.
            pop(
                staticcall(
                    gas(), // Amount of gas left for the transaction.
                    eq(signature.length, 65), // Address of `ecrecover`.
                    0x00, // Start of input.
                    0x80, // Size of input.
                    0x40, // Start of output.
                    0x20 // Size of output.
                )
            )
            mstore(0x60, 0) // Restore the zero slot.
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            result := mload(xor(0x60, returndatasize()))
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the EIP-2098 short form signature defined by `r` and `vs`.
    ///
    /// This function only accepts EIP-2098 short form signatures.
    /// See: https://eips.ethereum.org/EIPS/eip-2098
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, hash)
            mstore(0x20, add(shr(255, vs), 27)) // `v`.
            mstore(0x40, r)
            mstore(0x60, shr(1, shl(1, vs))) // `s`.
            pop(
                staticcall(
                    gas(), // Amount of gas left for the transaction.
                    1, // Address of `ecrecover`.
                    0x00, // Start of input.
                    0x80, // Size of input.
                    0x40, // Start of output.
                    0x20 // Size of output.
                )
            )
            mstore(0x60, 0) // Restore the zero slot.
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            result := mload(xor(0x60, returndatasize()))
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the signature defined by `v`, `r`, `s`.
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, hash)
            mstore(0x20, and(v, 0xff))
            mstore(0x40, r)
            mstore(0x60, s)
            pop(
                staticcall(
                    gas(), // Amount of gas left for the transaction.
                    1, // Address of `ecrecover`.
                    0x00, // Start of input.
                    0x80, // Size of input.
                    0x40, // Start of output.
                    0x20 // Size of output.
                )
            )
            mstore(0x60, 0) // Restore the zero slot.
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            result := mload(xor(0x60, returndatasize()))
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     HASHING OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns an Ethereum Signed Message, created from a `hash`.
    /// This produces a hash corresponding to the one signed with the
    /// [`eth_sign`](https://eth.wiki/json-rpc/API#eth_sign)
    /// JSON-RPC method as part of EIP-191.
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, hash) // Store into scratch space for keccak256.
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32") // 28 bytes.
            result := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.
        }
    }

    /// @dev Returns an Ethereum Signed Message, created from `s`.
    /// This produces a hash corresponding to the one signed with the
    /// [`eth_sign`](https://eth.wiki/json-rpc/API#eth_sign)
    /// JSON-RPC method as part of EIP-191.
    /// Note: Supports lengths of `s` up to 999999 bytes.
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let sLength := mload(s)
            let o := 0x20
            mstore(o, "\x19Ethereum Signed Message:\n") // 26 bytes, zero-right-padded.
            mstore(0x00, 0x00)
            // Convert the `s.length` to ASCII decimal representation: `base10(s.length)`.
            for { let temp := sLength } 1 {} {
                o := sub(o, 1)
                mstore8(o, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) { break }
            }
            let n := sub(0x3a, o) // Header length: `26 + 32 - o`.
            // Throw an out-of-offset error (consumes all gas) if the header exceeds 32 bytes.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0x20))
            mstore(s, or(mload(0x00), mload(n))) // Temporarily store the header.
            result := keccak256(add(s, sub(0x20, n)), add(n, sLength))
            mstore(s, sLength) // Restore the length.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   EMPTY CALLDATA HELPERS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns an empty calldata bytes.
    function emptySignature() internal pure returns (bytes calldata signature) {
        /// @solidity memory-safe-assembly
        assembly {
            signature.length := 0
        }
    }
}


// Chain: POLYGON - File: lib/solady/src/utils/SafeTransferLib.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeTransferLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
///
/// @dev Note:
/// - For ETH transfers, please use `forceSafeTransferETH` for gas griefing protection.
/// - For ERC20s, this implementation won't check that a token has code,
///   responsibility is delegated to the caller.
library SafeTransferLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ETH transfer has failed.
    error ETHTransferFailed();

    /// @dev The ERC20 `transferFrom` has failed.
    error TransferFromFailed();

    /// @dev The ERC20 `transfer` has failed.
    error TransferFailed();

    /// @dev The ERC20 `approve` has failed.
    error ApproveFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Suggested gas stipend for contract receiving ETH that disallows any storage writes.
    uint256 internal constant GAS_STIPEND_NO_STORAGE_WRITES = 2300;

    /// @dev Suggested gas stipend for contract receiving ETH to perform a few
    /// storage reads and writes, but low enough to prevent griefing.
    uint256 internal constant GAS_STIPEND_NO_GRIEF = 100000;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ETH OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // If gas griefing protection is needed, please use the force variants.
    //
    // The regular variants:
    // - Forwards all remaining gas to the target.
    // - Reverts if the target reverts.
    // - Reverts if the current contract has insufficient balance.
    //
    // The force variants:
    // - Forwards with an optional gas stipend
    //   (defaults to `GAS_STIPEND_NO_GRIEF`, which is sufficient for most cases).
    // - If the target reverts, or if the gas stipend is exhausted,
    //   creates a temporary contract to force send the ETH via `SELFDESTRUCT`.
    //   Future compatible with `SENDALL`: https://eips.ethereum.org/EIPS/eip-4758.
    // - Reverts if the current contract has insufficient balance.
    //
    // The try variants:
    // - Forwards with a mandatory gas stipend.
    // - Instead of reverting, returns whether the transfer succeeded.

    /// @dev Sends `amount` (in wei) ETH to `to`.
    function safeTransferETH(address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(call(gas(), to, amount, gas(), 0x00, gas(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Sends all the ETH in the current contract to `to`.
    function safeTransferAllETH(address to) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer all the ETH and check if it succeeded or not.
            if iszero(call(gas(), to, selfbalance(), gas(), 0x00, gas(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    function forceSafeTransferETH(address to, uint256 amount, uint256 gasStipend) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if lt(selfbalance(), amount) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
            if iszero(call(gasStipend, to, amount, gas(), 0x00, gas(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(amount, 0x0b, 0x16)) {
                    returndatacopy(gas(), returndatasize(), shr(20, gas())) // For gas estimation.
                }
            }
        }
    }

    /// @dev Force sends all the ETH in the current contract to `to`, with a `gasStipend`.
    function forceSafeTransferAllETH(address to, uint256 gasStipend) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(call(gasStipend, to, selfbalance(), gas(), 0x00, gas(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(selfbalance(), 0x0b, 0x16)) {
                    returndatacopy(gas(), returndatasize(), shr(20, gas())) // For gas estimation.
                }
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with `GAS_STIPEND_NO_GRIEF`.
    function forceSafeTransferETH(address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if lt(selfbalance(), amount) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
            if iszero(call(GAS_STIPEND_NO_GRIEF, to, amount, gas(), 0x00, gas(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(amount, 0x0b, 0x16)) {
                    returndatacopy(gas(), returndatasize(), shr(20, gas())) // For gas estimation.
                }
            }
        }
    }

    /// @dev Force sends all the ETH in the current contract to `to`, with `GAS_STIPEND_NO_GRIEF`.
    function forceSafeTransferAllETH(address to) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(call(GAS_STIPEND_NO_GRIEF, to, selfbalance(), gas(), 0x00, gas(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(selfbalance(), 0x0b, 0x16)) {
                    returndatacopy(gas(), returndatasize(), shr(20, gas())) // For gas estimation.
                }
            }
        }
    }

    /// @dev Sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    function trySafeTransferETH(address to, uint256 amount, uint256 gasStipend)
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            success := call(gasStipend, to, amount, gas(), 0x00, gas(), 0x00)
        }
    }

    /// @dev Sends all the ETH in the current contract to `to`, with a `gasStipend`.
    function trySafeTransferAllETH(address to, uint256 gasStipend)
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            success := call(gasStipend, to, selfbalance(), gas(), 0x00, gas(), 0x00)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC20 OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have at least `amount` approved for
    /// the current contract to manage.
    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, amount) // Store the `amount` argument.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x23b872dd000000000000000000000000) // `transferFrom(address,address,uint256)`.
            // Perform the transfer, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends all of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have their entire balance approved for
    /// the current contract to manage.
    function safeTransferAllFrom(address token, address from, address to)
        internal
        returns (uint256 amount)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            // Read the balance, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x1c, 0x24, 0x60, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x00, 0x23b872dd) // `transferFrom(address,address,uint256)`.
            amount := mload(0x60) // The `amount` is already at 0x60. We'll need to return it.
            // Perform the transfer, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransfer(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            // Perform the transfer, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sends all of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransferAll(address token, address to) internal returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x70a08231) // Store the function selector of `balanceOf(address)`.
            mstore(0x20, address()) // Store the address of the current contract.
            // Read the balance, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x1c, 0x24, 0x34, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x14, to) // Store the `to` argument.
            amount := mload(0x34) // The `amount` is already at 0x34. We'll need to return it.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            // Perform the transfer, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// Reverts upon failure.
    function safeApprove(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
            // Perform the approval, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// If the initial attempt to approve fails, attempts to reset the approved amount to zero,
    /// then retries the approval again (some tokens, e.g. USDT, requires this).
    /// Reverts upon failure.
    function safeApproveWithRetry(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
            // Perform the approval, retrying upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x34, 0) // Store 0 for the `amount`.
                mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
                pop(call(gas(), token, 0, 0x10, 0x44, 0x00, 0x00)) // Reset the approval.
                mstore(0x34, amount) // Store back the original `amount`.
                // Retry the approval, reverting upon failure.
                if iszero(
                    and(
                        or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                        call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                    )
                ) {
                    mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Returns the amount of ERC20 `token` owned by `account`.
    /// Returns zero if the `token` does not exist.
    function balanceOf(address token, address account) internal view returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, account) // Store the `account` argument.
            mstore(0x00, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            amount :=
                mul(
                    mload(0x20),
                    and( // The arguments of `and` are evaluated from right to left.
                        gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                        staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20)
                    )
                )
        }
    }
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/IERC1155Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155Upgradeable is IERC165Upgradeable {
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


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/IERC1155ReceiverUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155ReceiverUpgradeable is IERC165Upgradeable {
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


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155Upgradeable.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURIUpgradeable is IERC1155Upgradeable {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/ERC165Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

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
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
import "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeTo(address newImplementation) public virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/IERC165Upgradeable.sol
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
interface IERC165Upgradeable {
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


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/interfaces/draft-IERC1822Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/proxy/ERC1967/ERC1967UpgradeUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/IERC1967Upgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable, IERC1967Upgradeable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            AddressUpgradeable.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data, bool forceCall) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(address newBeacon, bytes memory data, bool forceCall) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            AddressUpgradeable.functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/proxy/beacon/IBeaconUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC1967Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC1967.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 *
 * _Available since v4.8.3._
 */
interface IERC1967Upgradeable {
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);
}


// Chain: POLYGON - File: lib/openzeppelin-contracts-upgradeable/contracts/utils/StorageSlotUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, `uint256`._
 * _Available since v4.9 for `string`, `bytes`._
 */
library StorageSlotUpgradeable {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}