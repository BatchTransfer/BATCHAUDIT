// File: @thirdweb-dev/contracts/eip/ERC1155.sol
// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "./interface/IERC1155.sol";
import "./interface/IERC1155Metadata.sol";
import "./interface/IERC1155Receiver.sol";

contract ERC1155 is IERC1155, IERC1155Metadata {
    /*//////////////////////////////////////////////////////////////
                        State variables
    //////////////////////////////////////////////////////////////*/

    string public name;
    string public symbol;

    /*//////////////////////////////////////////////////////////////
                            Mappings
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    mapping(uint256 => string) internal _uri;

    /*//////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                            View functions
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        return _uri[tokenId];
    }

    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        require(accounts.length == ids.length, "LENGTH_MISMATCH");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf[accounts[i]][ids[i]];
        }

        return batchBalances;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC1155 logic
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual override {
        address owner = msg.sender;
        require(owner != operator, "APPROVING_SELF");
        isApprovedForAll[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(from == msg.sender || isApprovedForAll[from][msg.sender], "!OWNER_OR_APPROVED");
        _safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(from == msg.sender || isApprovedForAll[from][msg.sender], "!OWNER_OR_APPROVED");
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /*//////////////////////////////////////////////////////////////
                            Internal logic
    //////////////////////////////////////////////////////////////*/

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "TO_ZERO_ADDR");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

        uint256 fromBalance = balanceOf[from][id];
        require(fromBalance >= amount, "INSUFFICIENT_BAL");
        unchecked {
            balanceOf[from][id] = fromBalance - amount;
        }
        balanceOf[to][id] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");
        require(to != address(0), "TO_ZERO_ADDR");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = balanceOf[from][id];
            require(fromBalance >= amount, "INSUFFICIENT_BAL");
            unchecked {
                balanceOf[from][id] = fromBalance - amount;
            }
            balanceOf[to][id] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    function _setTokenURI(uint256 tokenId, string memory newuri) internal virtual {
        _uri[tokenId] = newuri;
    }

    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        require(to != address(0), "TO_ZERO_ADDR");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, address(0), to, _asSingletonArray(id), _asSingletonArray(amount), data);

        balanceOf[to][id] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "TO_ZERO_ADDR");
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            balanceOf[to][ids[i]] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "FROM_ZERO_ADDR");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, from, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

        uint256 fromBalance = balanceOf[from][id];
        require(fromBalance >= amount, "INSUFFICIENT_BAL");
        unchecked {
            balanceOf[from][id] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);
    }

    function _burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(from != address(0), "FROM_ZERO_ADDR");
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        address operator = msg.sender;

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = balanceOf[from][id];
            require(fromBalance >= amount, "INSUFFICIENT_BAL");
            unchecked {
                balanceOf[from][id] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);
    }

    function _beforeTokenTransfer(
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
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("TOKENS_REJECTED");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("!ERC1155RECEIVER");
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
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("TOKENS_REJECTED");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("!ERC1155RECEIVER");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}


// File: @thirdweb-dev/contracts/eip/ERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./interface/IERC165.sol";

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


// File: @thirdweb-dev/contracts/eip/ERC721A.sol
// SPDX-License-Identifier: MIT
// ERC721A Contracts v3.3.0
// Creator: Chiru Labs

pragma solidity ^0.8.4;

import "./interface/IERC721A.sol";
import "../external-deps/openzeppelin/token/ERC721/IERC721Receiver.sol";
import "../lib/Address.sol";
import "../external-deps/openzeppelin/utils/Context.sol";
import "../lib/Strings.sol";
import "./ERC165.sol";

/**
 * @dev Implementation of [ERC721](https://eips.ethereum.org/EIPS/eip-721) Non-Fungible Token Standard, including
 * the Metadata extension. Built to optimize for lower gas during batch mints.
 *
 * Assumes serials are sequentially minted starting at _startTokenId() (defaults to 0, e.g. 0, 1, 2, 3..).
 *
 * Assumes that an owner cannot have more than 2^64 - 1 (max value of uint64) of supply.
 *
 * Assumes that the maximum token id cannot exceed 2^256 - 1 (max value of uint256).
 */
contract ERC721A is Context, ERC165, IERC721A {
    using Address for address;
    using Strings for uint256;

    // The tokenId of the next token to be minted.
    uint256 internal _currentIndex;

    // The number of tokens burned.
    uint256 internal _burnCounter;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to ownership details
    // An empty struct value does not necessarily mean the token is unowned. See _ownershipOf implementation for details.
    mapping(uint256 => TokenOwnership) internal _ownerships;

    // Mapping owner address to address data
    mapping(address => AddressData) private _addressData;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _currentIndex = _startTokenId();
    }

    /**
     * To change the starting tokenId, please override this function.
     */
    function _startTokenId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Burned tokens are calculated here, use _totalMinted() if you want to count just minted tokens.
     */
    function totalSupply() public view override returns (uint256) {
        // Counter underflow is impossible as _burnCounter cannot be incremented
        // more than _currentIndex - _startTokenId() times
        unchecked {
            return _currentIndex - _burnCounter - _startTokenId();
        }
    }

    /**
     * Returns the total amount of tokens minted in the contract.
     */
    function _totalMinted() internal view returns (uint256) {
        // Counter underflow is impossible as _currentIndex does not decrement,
        // and it is initialized to _startTokenId()
        unchecked {
            return _currentIndex - _startTokenId();
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        if (owner == address(0)) revert BalanceQueryForZeroAddress();
        return uint256(_addressData[owner].balance);
    }

    /**
     * Returns the number of tokens minted by `owner`.
     */
    function _numberMinted(address owner) internal view returns (uint256) {
        return uint256(_addressData[owner].numberMinted);
    }

    /**
     * Returns the number of tokens burned by or on behalf of `owner`.
     */
    function _numberBurned(address owner) internal view returns (uint256) {
        return uint256(_addressData[owner].numberBurned);
    }

    /**
     * Returns the auxillary data for `owner`. (e.g. number of whitelist mint slots used).
     */
    function _getAux(address owner) internal view returns (uint64) {
        return _addressData[owner].aux;
    }

    /**
     * Sets the auxillary data for `owner`. (e.g. number of whitelist mint slots used).
     * If there are multiple variables, please pack them into a uint64.
     */
    function _setAux(address owner, uint64 aux) internal {
        _addressData[owner].aux = aux;
    }

    /**
     * Gas spent here starts off proportional to the maximum mint batch size.
     * It gradually moves to O(1) as tokens get transferred around in the collection over time.
     */
    function _ownershipOf(uint256 tokenId) internal view returns (TokenOwnership memory) {
        uint256 curr = tokenId;

        unchecked {
            if (_startTokenId() <= curr)
                if (curr < _currentIndex) {
                    TokenOwnership memory ownership = _ownerships[curr];
                    if (!ownership.burned) {
                        if (ownership.addr != address(0)) {
                            return ownership;
                        }
                        // Invariant:
                        // There will always be an ownership that has an address and is not burned
                        // before an ownership that does not have an address and is not burned.
                        // Hence, curr will not underflow.
                        while (true) {
                            curr--;
                            ownership = _ownerships[curr];
                            if (ownership.addr != address(0)) {
                                return ownership;
                            }
                        }
                    }
                }
        }
        revert OwnerQueryForNonexistentToken();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _ownershipOf(tokenId).addr;
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
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public override {
        address owner = ERC721A.ownerOf(tokenId);
        if (to == owner) revert ApprovalToCurrentOwner();

        if (_msgSender() != owner)
            if (!isApprovedForAll(owner, _msgSender())) {
                revert ApprovalCallerNotOwnerNorApproved();
            }

        _approve(to, tokenId, owner);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override returns (address) {
        if (!_exists(tokenId)) revert ApprovalQueryForNonexistentToken();

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        if (operator == _msgSender()) revert ApproveToCaller();

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
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
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        _transfer(from, to, tokenId);
        if (to.isContract())
            if (!_checkContractOnERC721Received(from, to, tokenId, _data)) {
                revert TransferToNonERC721ReceiverImplementer();
            }
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _startTokenId() <= tokenId && tokenId < _currentIndex && !_ownerships[tokenId].burned;
    }

    /**
     * @dev Equivalent to `_safeMint(to, quantity, '')`.
     */
    function _safeMint(address to, uint256 quantity) internal {
        _safeMint(to, quantity, "");
    }

    /**
     * @dev Safely mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement
     *   {IERC721Receiver-onERC721Received}, which is called for each safe transfer.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 quantity, bytes memory _data) internal {
        uint256 startTokenId = _currentIndex;
        if (to == address(0)) revert MintToZeroAddress();
        if (quantity == 0) revert MintZeroQuantity();

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are incredibly unrealistic.
        // balance or numberMinted overflow if current value of either + quantity > 1.8e19 (2**64) - 1
        // updatedIndex overflows if _currentIndex + quantity > 1.2e77 (2**256) - 1
        unchecked {
            _addressData[to].balance += uint64(quantity);
            _addressData[to].numberMinted += uint64(quantity);

            _ownerships[startTokenId].addr = to;
            _ownerships[startTokenId].startTimestamp = uint64(block.timestamp);

            uint256 updatedIndex = startTokenId;
            uint256 end = updatedIndex + quantity;

            if (to.isContract()) {
                do {
                    emit Transfer(address(0), to, updatedIndex);
                    if (!_checkContractOnERC721Received(address(0), to, updatedIndex++, _data)) {
                        revert TransferToNonERC721ReceiverImplementer();
                    }
                } while (updatedIndex < end);
                // Reentrancy protection
                if (_currentIndex != startTokenId) revert();
            } else {
                do {
                    emit Transfer(address(0), to, updatedIndex++);
                } while (updatedIndex < end);
            }
            _currentIndex = updatedIndex;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 quantity) internal {
        uint256 startTokenId = _currentIndex;
        if (to == address(0)) revert MintToZeroAddress();
        if (quantity == 0) revert MintZeroQuantity();

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are incredibly unrealistic.
        // balance or numberMinted overflow if current value of either + quantity > 1.8e19 (2**64) - 1
        // updatedIndex overflows if _currentIndex + quantity > 1.2e77 (2**256) - 1
        unchecked {
            _addressData[to].balance += uint64(quantity);
            _addressData[to].numberMinted += uint64(quantity);

            _ownerships[startTokenId].addr = to;
            _ownerships[startTokenId].startTimestamp = uint64(block.timestamp);

            uint256 updatedIndex = startTokenId;
            uint256 end = updatedIndex + quantity;

            do {
                emit Transfer(address(0), to, updatedIndex++);
            } while (updatedIndex < end);

            _currentIndex = updatedIndex;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) private {
        TokenOwnership memory prevOwnership = _ownershipOf(tokenId);

        if (prevOwnership.addr != from) revert TransferFromIncorrectOwner();

        bool isApprovedOrOwner = (_msgSender() == from ||
            isApprovedForAll(from, _msgSender()) ||
            getApproved(tokenId) == _msgSender());

        if (!isApprovedOrOwner) revert TransferCallerNotOwnerNorApproved();
        if (to == address(0)) revert TransferToZeroAddress();

        _beforeTokenTransfers(from, to, tokenId, 1);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId, from);

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as tokenId would have to be 2**256.
        unchecked {
            _addressData[from].balance -= 1;
            _addressData[to].balance += 1;

            TokenOwnership storage currSlot = _ownerships[tokenId];
            currSlot.addr = to;
            currSlot.startTimestamp = uint64(block.timestamp);

            // If the ownership slot of tokenId+1 is not explicitly set, that means the transfer initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint256 nextTokenId = tokenId + 1;
            TokenOwnership storage nextSlot = _ownerships[nextTokenId];
            if (nextSlot.addr == address(0)) {
                // This will suffice for checking _exists(nextTokenId),
                // as a burned slot cannot contain the zero address.
                if (nextTokenId != _currentIndex) {
                    nextSlot.addr = from;
                    nextSlot.startTimestamp = prevOwnership.startTimestamp;
                }
            }
        }

        emit Transfer(from, to, tokenId);
        _afterTokenTransfers(from, to, tokenId, 1);
    }

    /**
     * @dev Equivalent to `_burn(tokenId, false)`.
     */
    function _burn(uint256 tokenId) internal virtual {
        _burn(tokenId, false);
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
    function _burn(uint256 tokenId, bool approvalCheck) internal virtual {
        TokenOwnership memory prevOwnership = _ownershipOf(tokenId);

        address from = prevOwnership.addr;

        if (approvalCheck) {
            bool isApprovedOrOwner = (_msgSender() == from ||
                isApprovedForAll(from, _msgSender()) ||
                getApproved(tokenId) == _msgSender());

            if (!isApprovedOrOwner) revert TransferCallerNotOwnerNorApproved();
        }

        _beforeTokenTransfers(from, address(0), tokenId, 1);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId, from);

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as tokenId would have to be 2**256.
        unchecked {
            AddressData storage addressData = _addressData[from];
            addressData.balance -= 1;
            addressData.numberBurned += 1;

            // Keep track of who burned the token, and the timestamp of burning.
            TokenOwnership storage currSlot = _ownerships[tokenId];
            currSlot.addr = from;
            currSlot.startTimestamp = uint64(block.timestamp);
            currSlot.burned = true;

            // If the ownership slot of tokenId+1 is not explicitly set, that means the burn initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint256 nextTokenId = tokenId + 1;
            TokenOwnership storage nextSlot = _ownerships[nextTokenId];
            if (nextSlot.addr == address(0)) {
                // This will suffice for checking _exists(nextTokenId),
                // as a burned slot cannot contain the zero address.
                if (nextTokenId != _currentIndex) {
                    nextSlot.addr = from;
                    nextSlot.startTimestamp = prevOwnership.startTimestamp;
                }
            }
        }

        emit Transfer(from, address(0), tokenId);
        _afterTokenTransfers(from, address(0), tokenId, 1);

        // Overflow not possible, as _burnCounter cannot be exceed _currentIndex times.
        unchecked {
            _burnCounter++;
        }
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId, address owner) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkContractOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
            return retval == IERC721Receiver(to).onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert TransferToNonERC721ReceiverImplementer();
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    /**
     * @dev Hook that is called before a set of serially-ordered token ids are about to be transferred. This includes minting.
     * And also called before burning one token.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity) internal virtual {}

    /**
     * @dev Hook that is called after a set of serially-ordered token ids have been transferred. This includes
     * minting.
     * And also called after one token has been burned.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` has been
     * transferred to `to`.
     * - When `from` is zero, `tokenId` has been minted for `to`.
     * - When `to` is zero, `tokenId` has been burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity) internal virtual {}
}


// File: @thirdweb-dev/contracts/eip/interface/IERC1155.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
    @title ERC-1155 Multi Token Standard
    @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1155.md
    Note: The ERC-165 identifier for this interface is 0xd9b67a26.
 */
interface IERC1155 {
    /**
        @dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).
        The `_operator` argument MUST be msg.sender.
        The `_from` argument MUST be the address of the holder whose balance is decreased.
        The `_to` argument MUST be the address of the recipient whose balance is increased.
        The `_id` argument MUST be the token type being transferred.
        The `_value` argument MUST be the number of tokens the holder balance is decreased by and match what the recipient balance is increased by.
        When minting/creating tokens, the `_from` argument MUST be set to `0x0` (i.e. zero address).
        When burning/destroying tokens, the `_to` argument MUST be set to `0x0` (i.e. zero address).
    */
    event TransferSingle(
        address indexed _operator,
        address indexed _from,
        address indexed _to,
        uint256 _id,
        uint256 _value
    );

    /**
        @dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).
        The `_operator` argument MUST be msg.sender.
        The `_from` argument MUST be the address of the holder whose balance is decreased.
        The `_to` argument MUST be the address of the recipient whose balance is increased.
        The `_ids` argument MUST be the list of tokens being transferred.
        The `_values` argument MUST be the list of number of tokens (matching the list and order of tokens specified in _ids) the holder balance is decreased by and match what the recipient balance is increased by.
        When minting/creating tokens, the `_from` argument MUST be set to `0x0` (i.e. zero address).
        When burning/destroying tokens, the `_to` argument MUST be set to `0x0` (i.e. zero address).
    */
    event TransferBatch(
        address indexed _operator,
        address indexed _from,
        address indexed _to,
        uint256[] _ids,
        uint256[] _values
    );

    /**
        @dev MUST emit when approval for a second party/operator address to manage all tokens for an owner address is enabled or disabled (absense of an event assumes disabled).
    */
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /**
        @dev MUST emit when the URI is updated for a token ID.
        URIs are defined in RFC 3986.
        The URI MUST point a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
    */
    event URI(string _value, uint256 indexed _id);

    /**
        @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if balance of holder for token `_id` is lower than the `_value` sent.
        MUST revert on any other error.
        MUST emit the `TransferSingle` event to reflect the balance change (see "Safe Transfer Rules" section of the standard).
        After the above conditions are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call `onERC1155Received` on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).
        @param _from    Source address
        @param _to      Target address
        @param _id      ID of the token type
        @param _value   Transfer amount
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
    */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;

    /**
        @notice Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if length of `_ids` is not the same as length of `_values`.
        MUST revert if any of the balance(s) of the holder(s) for token(s) in `_ids` is lower than the respective amount(s) in `_values` sent to the recipient.
        MUST revert on any other error.
        MUST emit `TransferSingle` or `TransferBatch` event(s) such that all the balance changes are reflected (see "Safe Transfer Rules" section of the standard).
        Balance changes and events MUST follow the ordering of the arrays (_ids[0]/_values[0] before _ids[1]/_values[1], etc).
        After the above conditions for the transfer(s) in the batch are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call the relevant `ERC1155TokenReceiver` hook(s) on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).
        @param _from    Source address
        @param _to      Target address
        @param _ids     IDs of each token type (order and length must match _values array)
        @param _values  Transfer amounts per token type (order and length must match _ids array)
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
    */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external;

    /**
        @notice Get the balance of an account's Tokens.
        @param _owner  The address of the token holder
        @param _id     ID of the Token
        @return        The _owner's balance of the Token type requested
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);

    /**
        @notice Get the balance of multiple account/token pairs
        @param _owners The addresses of the token holders
        @param _ids    ID of the Tokens
        @return        The _owner's balance of the Token types requested (i.e. balance for each (owner, id) pair)
     */
    function balanceOfBatch(
        address[] calldata _owners,
        uint256[] calldata _ids
    ) external view returns (uint256[] memory);

    /**
        @notice Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
        @dev MUST emit the ApprovalForAll event on success.
        @param _operator  Address to add to the set of authorized operators
        @param _approved  True if the operator is approved, false to revoke approval
    */
    function setApprovalForAll(address _operator, bool _approved) external;

    /**
        @notice Queries the approval status of an operator for a given owner.
        @param _owner     The owner of the Tokens
        @param _operator  Address of authorized operator
        @return           True if the operator is approved, false if not
    */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}


// File: @thirdweb-dev/contracts/eip/interface/IERC1155Metadata.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
    Note: The ERC-165 identifier for this interface is 0x0e89341c.
*/
interface IERC1155Metadata {
    /**
        @notice A distinct Uniform Resource Identifier (URI) for a given token.
        @dev URIs are defined in RFC 3986.
        The URI may point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
        @return URI string
    */
    function uri(uint256 _id) external view returns (string memory);
}


// File: @thirdweb-dev/contracts/eip/interface/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

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


// File: @thirdweb-dev/contracts/eip/interface/IERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * [EIP](https://eips.ethereum.org/EIPS/eip-165).
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
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File: @thirdweb-dev/contracts/eip/interface/IERC2981.sol
// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "./IERC165.sol";

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
     * exchange. The royalty amount is denominated and should be payed in that same unit of exchange.
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}


// File: @thirdweb-dev/contracts/eip/interface/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 {
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
    function balanceOf(address owner) external view returns (uint256);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address);

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
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address);

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}


// File: @thirdweb-dev/contracts/eip/interface/IERC721A.sol
// SPDX-License-Identifier: MIT
// ERC721A Contracts v3.3.0
// Creator: Chiru Labs

pragma solidity ^0.8.4;

import "./IERC721.sol";
import "./IERC721Metadata.sol";

/**
 * @dev Interface of an ERC721A compliant contract.
 */
interface IERC721A is IERC721, IERC721Metadata {
    /**
     * The caller must own the token or be an approved operator.
     */
    error ApprovalCallerNotOwnerNorApproved();

    /**
     * The token does not exist.
     */
    error ApprovalQueryForNonexistentToken();

    /**
     * The caller cannot approve to their own address.
     */
    error ApproveToCaller();

    /**
     * The caller cannot approve to the current owner.
     */
    error ApprovalToCurrentOwner();

    /**
     * Cannot query the balance for the zero address.
     */
    error BalanceQueryForZeroAddress();

    /**
     * Cannot mint to the zero address.
     */
    error MintToZeroAddress();

    /**
     * The quantity of tokens minted must be more than zero.
     */
    error MintZeroQuantity();

    /**
     * The token does not exist.
     */
    error OwnerQueryForNonexistentToken();

    /**
     * The caller must own the token or be an approved operator.
     */
    error TransferCallerNotOwnerNorApproved();

    /**
     * The token must be owned by `from`.
     */
    error TransferFromIncorrectOwner();

    /**
     * Cannot safely transfer to a contract that does not implement the ERC721Receiver interface.
     */
    error TransferToNonERC721ReceiverImplementer();

    /**
     * Cannot transfer to the zero address.
     */
    error TransferToZeroAddress();

    /**
     * The token does not exist.
     */
    error URIQueryForNonexistentToken();

    // Compiler will pack this into a single 256bit word.
    struct TokenOwnership {
        // The address of the owner.
        address addr;
        // Keeps track of the start time of ownership with minimal overhead for tokenomics.
        uint64 startTimestamp;
        // Whether the token has been burned.
        bool burned;
    }

    // Compiler will pack this into a single 256bit word.
    struct AddressData {
        // Realistically, 2**64-1 is more than enough.
        uint64 balance;
        // Keeps track of mint count with minimal overhead for tokenomics.
        uint64 numberMinted;
        // Keeps track of burn count with minimal overhead for tokenomics.
        uint64 numberBurned;
        // For miscellaneous variable(s) pertaining to the address
        // (e.g. number of whitelist mint slots used).
        // If there are multiple variables, please pack them into a uint64.
        uint64 aux;
    }

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     *
     * Burned tokens are calculated here, use `_totalMinted()` if you want to count just minted tokens.
     */
    function totalSupply() external view returns (uint256);
}


// File: @thirdweb-dev/contracts/eip/interface/IERC721Metadata.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @title ERC-721 Non-Fungible Token Standard, optional metadata extension
/// @dev See https://eips.ethereum.org/EIPS/eip-721
///  Note: the ERC-165 identifier for this interface is 0x5b5e139f.
/* is ERC721 */
interface IERC721Metadata {
    /// @notice A descriptive name for a collection of NFTs in this contract
    function name() external view returns (string memory);

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external view returns (string memory);

    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
    ///  3986. The URI may point to a JSON file that conforms to the "ERC721
    ///  Metadata JSON Schema".
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}


// File: @thirdweb-dev/contracts/extension/interface/IRoyalty.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

import "../../eip/interface/IERC2981.sol";

/**
 *  Thirdweb's `Royalty` is a contract extension to be used with any base contract. It exposes functions for setting and reading
 *  the recipient of royalty fee and the royalty fee basis points, and lets the inheriting contract perform conditional logic
 *  that uses information about royalty fees, if desired.
 *
 *  The `Royalty` contract is ERC2981 compliant.
 */

interface IRoyalty is IERC2981 {
    struct RoyaltyInfo {
        address recipient;
        uint256 bps;
    }

    /// @dev Returns the royalty recipient and fee bps.
    function getDefaultRoyaltyInfo() external view returns (address, uint16);

    /// @dev Lets a module admin update the royalty bps and recipient.
    function setDefaultRoyaltyInfo(address _royaltyRecipient, uint256 _royaltyBps) external;

    /// @dev Lets a module admin set the royalty recipient for a particular token Id.
    function setRoyaltyInfoForToken(uint256 tokenId, address recipient, uint256 bps) external;

    /// @dev Returns the royalty recipient for a particular token Id.
    function getRoyaltyInfoForToken(uint256 tokenId) external view returns (address, uint16);

    /// @dev Emitted when royalty info is updated.
    event DefaultRoyalty(address indexed newRoyaltyRecipient, uint256 newRoyaltyBps);

    /// @dev Emitted when royalty recipient for tokenId is set
    event RoyaltyForToken(uint256 indexed tokenId, address indexed royaltyRecipient, uint256 royaltyBps);
}


// File: @thirdweb-dev/contracts/extension/Royalty.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

import "./interface/IRoyalty.sol";

/**
 *  @title   Royalty
 *  @notice  Thirdweb's `Royalty` is a contract extension to be used with any base contract. It exposes functions for setting and reading
 *           the recipient of royalty fee and the royalty fee basis points, and lets the inheriting contract perform conditional logic
 *           that uses information about royalty fees, if desired.
 *
 *  @dev     The `Royalty` contract is ERC2981 compliant.
 */

abstract contract Royalty is IRoyalty {
    /// @dev The sender is not authorized to perform the action
    error RoyaltyUnauthorized();

    /// @dev The recipient is invalid
    error RoyaltyInvalidRecipient(address recipient);

    /// @dev The fee bps exceeded the max value
    error RoyaltyExceededMaxFeeBps(uint256 max, uint256 actual);

    /// @dev The (default) address that receives all royalty value.
    address private royaltyRecipient;

    /// @dev The (default) % of a sale to take as royalty (in basis points).
    uint16 private royaltyBps;

    /// @dev Token ID => royalty recipient and bps for token
    mapping(uint256 => RoyaltyInfo) private royaltyInfoForToken;

    /**
     *  @notice   View royalty info for a given token and sale price.
     *  @dev      Returns royalty amount and recipient for `tokenId` and `salePrice`.
     *  @param tokenId          The tokenID of the NFT for which to query royalty info.
     *  @param salePrice        Sale price of the token.
     *
     *  @return receiver        Address of royalty recipient account.
     *  @return royaltyAmount   Royalty amount calculated at current royaltyBps value.
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view virtual override returns (address receiver, uint256 royaltyAmount) {
        (address recipient, uint256 bps) = getRoyaltyInfoForToken(tokenId);
        receiver = recipient;
        royaltyAmount = (salePrice * bps) / 10_000;
    }

    /**
     *  @notice          View royalty info for a given token.
     *  @dev             Returns royalty recipient and bps for `_tokenId`.
     *  @param _tokenId  The tokenID of the NFT for which to query royalty info.
     */
    function getRoyaltyInfoForToken(uint256 _tokenId) public view override returns (address, uint16) {
        RoyaltyInfo memory royaltyForToken = royaltyInfoForToken[_tokenId];

        return
            royaltyForToken.recipient == address(0)
                ? (royaltyRecipient, uint16(royaltyBps))
                : (royaltyForToken.recipient, uint16(royaltyForToken.bps));
    }

    /**
     *  @notice Returns the defualt royalty recipient and BPS for this contract's NFTs.
     */
    function getDefaultRoyaltyInfo() external view override returns (address, uint16) {
        return (royaltyRecipient, uint16(royaltyBps));
    }

    /**
     *  @notice         Updates default royalty recipient and bps.
     *  @dev            Caller should be authorized to set royalty info.
     *                  See {_canSetRoyaltyInfo}.
     *                  Emits {DefaultRoyalty Event}; See {_setupDefaultRoyaltyInfo}.
     *
     *  @param _royaltyRecipient   Address to be set as default royalty recipient.
     *  @param _royaltyBps         Updated royalty bps.
     */
    function setDefaultRoyaltyInfo(address _royaltyRecipient, uint256 _royaltyBps) external override {
        if (!_canSetRoyaltyInfo()) {
            revert RoyaltyUnauthorized();
        }

        _setupDefaultRoyaltyInfo(_royaltyRecipient, _royaltyBps);
    }

    /// @dev Lets a contract admin update the default royalty recipient and bps.
    function _setupDefaultRoyaltyInfo(address _royaltyRecipient, uint256 _royaltyBps) internal {
        if (_royaltyBps > 10_000) {
            revert RoyaltyExceededMaxFeeBps(10_000, _royaltyBps);
        }

        royaltyRecipient = _royaltyRecipient;
        royaltyBps = uint16(_royaltyBps);

        emit DefaultRoyalty(_royaltyRecipient, _royaltyBps);
    }

    /**
     *  @notice         Updates default royalty recipient and bps for a particular token.
     *  @dev            Sets royalty info for `_tokenId`. Caller should be authorized to set royalty info.
     *                  See {_canSetRoyaltyInfo}.
     *                  Emits {RoyaltyForToken Event}; See {_setupRoyaltyInfoForToken}.
     *
     *  @param _recipient   Address to be set as royalty recipient for given token Id.
     *  @param _bps         Updated royalty bps for the token Id.
     */
    function setRoyaltyInfoForToken(uint256 _tokenId, address _recipient, uint256 _bps) external override {
        if (!_canSetRoyaltyInfo()) {
            revert RoyaltyUnauthorized();
        }

        _setupRoyaltyInfoForToken(_tokenId, _recipient, _bps);
    }

    /// @dev Lets a contract admin set the royalty recipient and bps for a particular token Id.
    function _setupRoyaltyInfoForToken(uint256 _tokenId, address _recipient, uint256 _bps) internal {
        if (_bps > 10_000) {
            revert RoyaltyExceededMaxFeeBps(10_000, _bps);
        }

        royaltyInfoForToken[_tokenId] = RoyaltyInfo({ recipient: _recipient, bps: _bps });

        emit RoyaltyForToken(_tokenId, _recipient, _bps);
    }

    /// @dev Returns whether royalty info can be set in the given execution context.
    function _canSetRoyaltyInfo() internal view virtual returns (bool);
}


// File: @thirdweb-dev/contracts/external-deps/openzeppelin/token/ERC721/IERC721Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

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
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}


// File: @thirdweb-dev/contracts/external-deps/openzeppelin/utils/Context.sol
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


// File: @thirdweb-dev/contracts/lib/Address.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.1;

/// @author thirdweb, OpenZeppelin Contracts (v4.9.0)

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

        (bool success, ) = recipient.call{ value: amount }("");
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
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
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


// File: @thirdweb-dev/contracts/lib/Strings.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
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

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x", encoded using 2 hexadecimal digits per byte,
    /// and the alphabets are capitalized conditionally according to
    /// https://eips.ethereum.org/EIPS/eip-55
    function toHexStringChecksummed(address value) internal pure returns (string memory str) {
        str = toHexString(value);
        /// @solidity memory-safe-assembly
        assembly {
            let mask := shl(6, div(not(0), 255)) // `0b010000000100000000 ...`
            let o := add(str, 0x22)
            let hashed := and(keccak256(o, 40), mul(34, mask)) // `0b10001000 ... `
            let t := shl(240, 136) // `0b10001000 << 240`
            for {
                let i := 0
            } 1 {

            } {
                mstore(add(i, i), mul(t, byte(i, hashed)))
                i := add(i, 1)
                if eq(i, 20) {
                    break
                }
            }
            mstore(o, xor(mload(o), shr(1, and(mload(0x00), and(mload(o), mask)))))
            o := add(o, 0x20)
            mstore(o, xor(mload(o), shr(1, and(mload(0x20), and(mload(o), mask)))))
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.
    function toHexString(address value) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(str, 0x3078) // Write the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Write the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexStringNoPrefix(address value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            str := mload(0x40)

            // Allocate the memory.
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x28 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x28) is 0x80.
            mstore(0x40, add(str, 0x80))

            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            str := add(str, 2)
            mstore(str, 40)

            let o := add(str, 0x20)
            mstore(add(o, 40), 0)

            value := shl(96, value)

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for {
                let i := 0
            } 1 {

            } {
                let p := add(o, add(i, i))
                let temp := byte(i, value)
                mstore8(add(p, 1), mload(and(temp, 15)))
                mstore8(p, mload(shr(4, temp)))
                i := add(i, 1)
                if eq(i, 20) {
                    break
                }
            }
        }
    }

    /// @dev Returns the hex encoded string from the raw bytes.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexString(bytes memory raw) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(raw);
        /// @solidity memory-safe-assembly
        assembly {
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(str, 0x3078) // Write the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Write the length.
        }
    }

    /// @dev Returns the hex encoded string from the raw bytes.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexStringNoPrefix(bytes memory raw) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            let length := mload(raw)
            str := add(mload(0x40), 2) // Skip 2 bytes for the optional prefix.
            mstore(str, add(length, length)) // Store the length of the output.

            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let o := add(str, 0x20)
            let end := add(raw, length)

            for {

            } iszero(eq(raw, end)) {

            } {
                raw := add(raw, 1)
                mstore8(add(o, 1), mload(and(mload(raw), 15)))
                mstore8(o, mload(and(shr(4, mload(raw)), 15)))
                o := add(o, 2)
            }
            mstore(o, 0) // Zeroize the slot after the string.
            mstore(0x40, add(o, 0x20)) // Allocate the memory.
        }
    }
}


// File: contracts/TesseractXMultipleNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@thirdweb-dev/contracts/eip/ERC1155.sol";
import "@thirdweb-dev/contracts/extension/Royalty.sol";

/**
 * @title TesseractXMultipleNFT
 * @dev This contract represents a collection of multiple NFTs using the ERC1155 standard with royalty functionality.
 */
contract TesseractXMultipleNFT is ERC1155, Royalty {
    struct Item {
        uint256 id;
        string uri;
        uint256 supply;
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public owner;
    uint256 public currentID;
    string private collection_uri;
    mapping(uint256 => Item) public Items;

    event MultiItemCreated(
        uint256 id,
        string uri,
        uint256 supply,
        address creator
    );
    event CollectionUriUpdated(string collection_uri);
    event CollectionNameUpdated(string collection_name);
    event TokenUriUpdated(uint256 id, string uri);
    event OwnerUpdated(address newowner);

    /**
     * @dev Constructor to initialize the contract.
     * @param _name The name of the collection.
     * @param _uri The URI for the collection metadata.
     * @param _owner The owner of the collection.
     * @param _royaltyBps The royalty percentage in basis points (1/10,000).
     */
    constructor(
        string memory _name,
        string memory _uri,
        address _owner,
        uint128 _royaltyBps
    ) ERC1155(_name, "TXMN") {
        collection_uri = _uri;
        owner = _owner;

        _setupDefaultRoyaltyInfo(_owner, _royaltyBps);
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "caller is not the owner");
        _;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the URI for a specific token ID.
     * @param tokenId The ID of the token.
     * @return The token URI.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC1155Tradable#uri: NONEXISTENT_TOKEN");
        return Items[tokenId].uri;
    }

    /**
     * @dev Sets the collection URI.
     * @param newURI The new collection URI.
     */
    function setCollectionURI(string memory newURI) public onlyOwner {
        collection_uri = newURI;
        emit CollectionUriUpdated(newURI);
    }

    /**
     * @dev Returns the contract's collection URI.
     * @return The collection URI.
     */
    function contractURI() public view returns (string memory) {
        return collection_uri;
    }

    /**
     * @dev Transfers ownership of the contract to a new address.
     * @param _newOwner The address of the new owner.
     */
    function transferOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
        emit OwnerUpdated(_newOwner);
    }

    /**
     * @dev Sets the name of the collection.
     * @param newname The new name for the collection.
     */
    function setName(string memory newname) public onlyOwner {
        name = newname;
        emit CollectionNameUpdated(newname);
    }

    /**
     * @dev Sets a custom URI for a specific token.
     * @param _tokenId The ID of the token.
     * @param _newURI The new URI for the token.
     */
    function setCustomURI(
        uint256 _tokenId,
        string memory _newURI
    ) public onlyOwner {
        require(_exists(_tokenId), "ERC1155Tradable#uri: NONEXISTENT_TOKEN");
        Items[_tokenId].uri = _newURI;
        emit TokenUriUpdated(_tokenId, _newURI);
    }

    /**
     * @dev Returns the total supply of a specific token ID.
     * @param _id The ID of the token.
     * @return The total supply.
     */
    function totalSupply(uint256 _id) public view returns (uint256) {
        require(_exists(_id), "ERC1155Tradable#supply: NONEXISTENT_TOKEN");
        return Items[_id].supply;
    }

    /**
     * @dev Adds a new item to the collection.
     * @param supply The supply of the item.
     * @param _uri The URI for the item.
     * @return The ID of the newly created item.
     */
    function addItem(
        uint256 supply,
        string memory _uri
    ) public onlyOwner returns (uint256) {
        require(supply > 0, "supply can not be 0");

        if (supply > 0) {
            _mint(msg.sender, currentID, supply, "Mint");
        }
        Items[currentID] = Item(currentID, _uri, supply);
        emit MultiItemCreated(currentID, _uri, supply, msg.sender);
        currentID = currentID + 1;

        return currentID - 1;
    }

    /**
     * @dev Burns a specific amount of a token owned by the caller.
     * @param id The ID of the token.
     * @param amount The amount to burn.
     * @return A boolean indicating whether the burn was successful.
     */
    function burn(uint256 id, uint256 amount) public returns (bool) {
        uint256 nft_token_balance = balanceOf[msg.sender][id];
        require(nft_token_balance > 0, "Only owner can burn");
        require(
            nft_token_balance >= amount,
            "invalid amount : amount have to be smaller than the balance"
        );
        _burn(msg.sender, id, amount);
        Items[id].supply = Items[id].supply - amount;
        return true;
    }

    /**
     * @dev Checks if the sender can set royalty info, restricted to the owner.
     * @return A boolean indicating whether the sender can set royalty info.
     */
    function _canSetRoyaltyInfo()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return msg.sender == owner;
    }

    /**
     * @dev Checks if a token with a given ID exists.
     * @param _id The ID of the token.
     * @return A boolean indicating whether the token exists.
     */
    function _exists(uint256 _id) internal view returns (bool) {
        return _id < currentID;
    }
}


// File: contracts/TesseractXNFTFactory.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./TesseractXMultipleNFT.sol";
import "./TesseractXSingleNFT.sol";

/**
 * @title TesseractXNFTFactory
 * @dev This contract allows users to create and manage NFT collections, both single and multiple, using TesseractXSingleNFT and TesseractXMultipleNFT contracts.
 */
contract TesseractXNFTFactory {
    address[] public collections;

    event MultiCollectionCreated(
        address collection_address,
        address owner,
        string name,
        string uri,
        uint128 royaltyBps
    );
    event SingleCollectionCreated(
        address collection_address,
        address owner,
        string name,
        string uri,
        uint128 royaltyBps
    );

    constructor() {}

    /**
     * @dev Retrieves the list of created NFT collections.
     * @return An array of collection addresses.
     */
    function getCollections() public view returns (address[] memory) {
        return collections;
    }

    /**
     * @dev Creates a new multiple NFT collection.
     * @param _name The name of the collection.
     * @param _uri The URI for the collection metadata.
     * @param _royaltyBps The royalty percentage in basis points (1/10,000).
     * @return The address of the newly created collection contract.
     */
    function createMultipleCollection(
        string memory _name,
        string memory _uri,
        uint128 _royaltyBps
    ) public returns (address) {
        address collection = address(
            new TesseractXMultipleNFT(_name, _uri, msg.sender, _royaltyBps)
        );

        collections.push(collection);

        emit MultiCollectionCreated(
            collection,
            msg.sender,
            _name,
            _uri,
            _royaltyBps
        );
        return collection;
    }

    /**
     * @dev Creates a new single NFT collection.
     * @param _name The name of the collection.
     * @param _uri The URI for the collection metadata.
     * @param _royaltyBps The royalty percentage in basis points (1/10,000).
     * @return The address of the newly created collection contract.
     */
    function createSingleCollection(
        string memory _name,
        string memory _uri,
        uint128 _royaltyBps
    ) public returns (address) {
        address collection = address(
            new TesseractXSingleNFT(_name, _uri, msg.sender, _royaltyBps)
        );

        collections.push(collection);

        emit SingleCollectionCreated(
            collection,
            msg.sender,
            _name,
            _uri,
            _royaltyBps
        );
        return collection;
    }
}


// File: contracts/TesseractXSingleNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@thirdweb-dev/contracts/eip/ERC721A.sol";
import "@thirdweb-dev/contracts/extension/Royalty.sol";

/**
 * @title TesseractXSingleNFT
 * @dev This contract represents a single NFT collection with royalty functionality.
 */
contract TesseractXSingleNFT is ERC721A, Royalty {
    string public collection_name;
    string private collection_uri;
    address public owner;

    mapping(uint256 => string) public Items;

    event CollectionUriUpdated(string collection_uri);
    event CollectionNameUpdated(string collection_name);
    event TokenUriUpdated(uint256 id, string uri);
    event ItemCreated(uint256 id, address creator, string uri);
    event Burned(address owner, uint nftID);
    event OwnerUpdated(address newowner);

    /**
     * @dev Constructor to initialize the contract.
     * @param _name The name of the collection.
     * @param _uri The URI for the collection metadata.
     * @param _owner The owner of the collection.
     * @param _royaltyBps The royalty percentage in basis points (1/10,000).
     */
    constructor(
        string memory _name,
        string memory _uri,
        address _owner,
        uint128 _royaltyBps
    ) ERC721A(_name, "TXSN") {
        collection_uri = _uri;
        collection_name = _name;
        owner = _owner;
        _setupDefaultRoyaltyInfo(_owner, _royaltyBps);
    }

    modifier onlyOwner() {
        require(owner == _msgSender(), "caller is not the owner");
        _;
    }

    /**
     * @dev Sets the collection URI.
     * @param newURI The new collection URI.
     */
    function setCollectionURI(string memory newURI) public onlyOwner {
        collection_uri = newURI;
        emit CollectionUriUpdated(newURI);
    }

    /**
     * @dev Returns the contract's collection URI.
     * @return The collection URI.
     */
    function contractURI() public view returns (string memory) {
        return collection_uri;
    }

    /**
     * @dev Adds a new item to the collection.
     * @param _tokenURI The URI for the item.
     * @return The ID of the newly created item.
     */
    function addItem(
        string memory _tokenURI
    ) public onlyOwner returns (uint256) {
        _safeMint(msg.sender, 1);
        uint256 currentID = _currentIndex - 1;
        Items[currentID] = _tokenURI;
        emit ItemCreated(currentID, msg.sender, _tokenURI);
        return currentID;
    }

    /**
     * @dev Burns a specific NFT.
     * @param _tokenId The ID of the NFT to be burned.
     * @return A boolean indicating whether the burn was successful.
     */
    function burn(uint _tokenId) public returns (bool) {
        require(_exists(_tokenId), "Token ID is invalid");
        require(ERC721A.ownerOf(_tokenId) == msg.sender, "only owner can burn");
        _burn(_tokenId);
        emit Burned(msg.sender, _tokenId);
        return true;
    }

    /**
     * @dev Sets the token URI for a specific NFT.
     * @param _tokenId The ID of the NFT.
     * @param _newURI The new URI for the NFT.
     */
    function setTokenURI(
        uint256 _tokenId,
        string memory _newURI
    ) public onlyOwner {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        Items[_tokenId] = _newURI;
        emit TokenUriUpdated(_tokenId, _newURI);
    }

    /**
     * @dev Retrieves the token URI for a specific NFT.
     * @param tokenId The ID of the NFT.
     * @return The token URI.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return Items[tokenId];
    }

    /**
     * @dev Transfers ownership of the contract to a new address.
     * @param _newOwner The address of the new owner.
     */
    function transferOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
        emit OwnerUpdated(_newOwner);
    }

    /**
     * @dev Checks if the sender can set royalty info, restricted to the owner.
     * @return A boolean indicating whether the sender can set royalty info.
     */
    function _canSetRoyaltyInfo()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return msg.sender == owner;
    }
}


