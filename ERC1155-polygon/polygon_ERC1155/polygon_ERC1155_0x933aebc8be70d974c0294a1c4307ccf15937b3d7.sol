// Chain: POLYGON - File: contracts/flow/erc1155/FlowERC1155.sol
// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ReentrancyGuardUpgradeable as ReentrancyGuard} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC1155Upgradeable as ERC1155} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155ReceiverUpgradeable as ERC1155Receiver} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "rain.interpreter/lib/caller/LibEncodedDispatch.sol";
import "rain.factory/src/interface/ICloneableV2.sol";
import "sol.lib.memory/LibUint256Matrix.sol";
import "rain.flow/interface/IFlowERC1155V3.sol";

import "sol.lib.memory/LibStackPointer.sol";
import "../libraries/LibFlow.sol";
import "../FlowCommon.sol";

Sentinel constant RAIN_FLOW_ERC1155_SENTINEL = Sentinel.wrap(
    uint256(keccak256(bytes("RAIN_FLOW_ERC1155_SENTINEL")) | SENTINEL_HIGH_BITS)
);

bytes32 constant CALLER_META_HASH = bytes32(
    0x7ea70f837234357ec1bb5b777e04453ebaf3ca778a98805c4bb20a738d559a21
);

SourceIndex constant HANDLE_TRANSFER_ENTRYPOINT = SourceIndex.wrap(0);
uint256 constant HANDLE_TRANSFER_MIN_OUTPUTS = 0;
uint16 constant HANDLE_TRANSFER_MAX_OUTPUTS = 0;

uint256 constant FLOW_ERC1155_MIN_OUTPUTS = MIN_FLOW_SENTINELS + 2;

contract FlowERC1155 is
    ICloneableV2,
    IFlowERC1155V3,
    ReentrancyGuard,
    FlowCommon,
    ERC1155,
    OwnableUpgradeable
{
    using LibStackPointer for Pointer;
    using LibStackSentinel for Pointer;
    using LibStackPointer for uint256[];
    using LibUint256Array for uint256;
    using LibUint256Array for uint256[];
    using LibUint256Matrix for uint256[];

    bool private evalHandleTransfer;
    Evaluable internal evaluable;

    constructor(
        DeployerDiscoverableMetaV1ConstructionConfig memory config_
    ) FlowCommon(CALLER_META_HASH, config_) {}

    /// @inheritdoc ICloneableV2
    function initialize(
        bytes calldata data_
    ) external initializer returns (bytes32) {
        FlowERC1155Config memory config_ = abi.decode(
            data_,
            (FlowERC1155Config)
        );
        emit Initialize(msg.sender, config_);
        __ReentrancyGuard_init();
        __ERC1155_init(config_.uri);
        _transferOwnership(tx.origin);

        flowCommonInit(config_.flowConfig, FLOW_ERC1155_MIN_OUTPUTS);

        if (
            config_.evaluableConfig.sources.length > 0 &&
            config_
                .evaluableConfig
                .sources[SourceIndex.unwrap(HANDLE_TRANSFER_ENTRYPOINT)]
                .length >
            0
        ) {
            evalHandleTransfer = true;
            (
                IInterpreterV1 interpreter_,
                IInterpreterStoreV1 store_,
                address expression_
            ) = config_.evaluableConfig.deployer.deployExpression(
                    config_.evaluableConfig.sources,
                    config_.evaluableConfig.constants,
                    LibUint256Array.arrayFrom(HANDLE_TRANSFER_MIN_OUTPUTS)
                );
            evaluable = Evaluable(interpreter_, store_, expression_);
        }

        return ICLONEABLE_V2_SUCCESS;
    }

    function setUri(string calldata uri_) external virtual onlyOwner {
        _setURI(uri_);
    }

    function _dispatchHandleTransfer(
        address expression_
    ) internal pure returns (EncodedDispatch) {
        return
            LibEncodedDispatch.encode(
                expression_,
                HANDLE_TRANSFER_ENTRYPOINT,
                HANDLE_TRANSFER_MAX_OUTPUTS
            );
    }

    /// Needed here to fix Open Zeppelin implementing `supportsInterface` on
    /// multiple base contracts.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC1155Receiver) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @inheritdoc ERC1155
    function _afterTokenTransfer(
        address operator_,
        address from_,
        address to_,
        uint256[] memory ids_,
        uint256[] memory amounts_,
        bytes memory data_
    ) internal virtual override {
        unchecked {
            super._afterTokenTransfer(
                operator_,
                from_,
                to_,
                ids_,
                amounts_,
                data_
            );
            // Mint and burn access MUST be handled by flow.
            // HANDLE_TRANSFER will only restrict subsequent transfers.
            if (
                evalHandleTransfer &&
                !(from_ == address(0) || to_ == address(0))
            ) {
                Evaluable memory evaluable_ = evaluable;

                (, uint256[] memory kvs_) = evaluable_.interpreter.eval(
                    evaluable_.store,
                    DEFAULT_STATE_NAMESPACE,
                    _dispatchHandleTransfer(evaluable_.expression),
                    LibContext.build(
                        // Transfer params are caller context.
                        LibUint256Matrix.matrixFrom(
                            LibUint256Array.arrayFrom(
                                uint256(uint160(operator_)),
                                uint256(uint160(from_)),
                                uint256(uint160(to_))
                            ),
                            ids_,
                            amounts_
                        ),
                        new SignedContextV1[](0)
                    )
                );
                if (kvs_.length > 0) {
                    evaluable_.store.set(DEFAULT_STATE_NAMESPACE, kvs_);
                }
            }
        }
    }

    function _previewFlow(
        Evaluable memory evaluable_,
        uint256[][] memory context_
    ) internal view returns (FlowERC1155IOV1 memory, uint256[] memory) {
        ERC1155SupplyChange[] memory mints_;
        ERC1155SupplyChange[] memory burns_;
        Pointer tuplesPointer_;
        (
            Pointer stackBottom_,
            Pointer stackTop_,
            uint256[] memory kvs_
        ) = flowStack(evaluable_, context_);
        // mints
        (stackTop_, tuplesPointer_) = stackBottom_.consumeSentinelTuples(
            stackTop_,
            RAIN_FLOW_ERC1155_SENTINEL,
            3
        );
        assembly ("memory-safe") {
            mints_ := tuplesPointer_
        }
        // burns
        (stackTop_, tuplesPointer_) = stackBottom_.consumeSentinelTuples(
            stackTop_,
            RAIN_FLOW_ERC1155_SENTINEL,
            3
        );
        assembly ("memory-safe") {
            burns_ := tuplesPointer_
        }
        return (
            FlowERC1155IOV1(
                mints_,
                burns_,
                LibFlow.stackToFlow(stackBottom_, stackTop_)
            ),
            kvs_
        );
    }

    function _flow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContextV1[] memory signedContexts_
    ) internal virtual nonReentrant returns (FlowERC1155IOV1 memory) {
        unchecked {
            uint256[][] memory context_ = LibContext.build(
                callerContext_.matrixFrom(),
                signedContexts_
            );
            emit Context(msg.sender, context_);
            (
                FlowERC1155IOV1 memory flowIO_,
                uint256[] memory kvs_
            ) = _previewFlow(evaluable_, context_);
            for (uint256 i_ = 0; i_ < flowIO_.mints.length; i_++) {
                // @todo support data somehow.
                _mint(
                    flowIO_.mints[i_].account,
                    flowIO_.mints[i_].id,
                    flowIO_.mints[i_].amount,
                    ""
                );
            }
            for (uint256 i_ = 0; i_ < flowIO_.burns.length; i_++) {
                _burn(
                    flowIO_.burns[i_].account,
                    flowIO_.burns[i_].id,
                    flowIO_.burns[i_].amount
                );
            }
            LibFlow.flow(flowIO_.flow, evaluable_.store, kvs_);
            return flowIO_;
        }
    }

    function previewFlow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContextV1[] memory signedContexts_
    ) external view virtual returns (FlowERC1155IOV1 memory) {
        uint256[][] memory context_ = LibContext.build(
            callerContext_.matrixFrom(),
            signedContexts_
        );
        (FlowERC1155IOV1 memory flowERC1155IO_, ) = _previewFlow(
            evaluable_,
            context_
        );
        return flowERC1155IO_;
    }

    function flow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContextV1[] memory signedContexts_
    ) external virtual returns (FlowERC1155IOV1 memory) {
        return _flow(evaluable_, callerContext_, signedContexts_);
    }
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
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
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC1155/ERC1155.sol)

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
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
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
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
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
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
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
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
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
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
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


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/utils/ERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../IERC1155ReceiverUpgradeable.sol";
import "../../../utils/introspection/ERC165Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev _Available since v3.1._
 */
abstract contract ERC1155ReceiverUpgradeable is Initializable, ERC165Upgradeable, IERC1155ReceiverUpgradeable {
    function __ERC1155Receiver_init() internal onlyInitializing {
    }

    function __ERC1155Receiver_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId == type(IERC1155ReceiverUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// Chain: POLYGON - File: lib/rain.interpreter/src/lib/caller/LibEncodedDispatch.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "../../interface/IInterpreterV1.sol";

/// @title LibEncodedDispatch
/// @notice Establishes and implements a convention for encoding an interpreter
/// dispatch. Handles encoding of several things required for efficient dispatch.
library LibEncodedDispatch {
    /// Builds an `EncodedDispatch` from its constituent parts.
    /// @param expression_ The onchain address of the expression to run.
    /// @param sourceIndex_ The index of the source to run within the expression
    /// as an entrypoint.
    /// @param maxOutputs_ The maximum outputs the caller can meaningfully use.
    /// If the interpreter returns a larger stack than this it is merely wasting
    /// gas across the external call boundary.
    /// @return The encoded dispatch.
    function encode(address expression_, SourceIndex sourceIndex_, uint16 maxOutputs_)
        internal
        pure
        returns (EncodedDispatch)
    {
        return EncodedDispatch.wrap(
            (uint256(uint160(expression_)) << 32) | (uint256(SourceIndex.unwrap(sourceIndex_)) << 16) | maxOutputs_
        );
    }

    /// Decodes an `EncodedDispatch` to its constituent parts.
    /// @param dispatch_ The `EncodedDispatch` to decode.
    /// @return The expression, source index, and max outputs as per `encode`.
    function decode(EncodedDispatch dispatch_) internal pure returns (address, SourceIndex, uint16) {
        return (
            address(uint160(EncodedDispatch.unwrap(dispatch_) >> 32)),
            SourceIndex.wrap(uint16(EncodedDispatch.unwrap(dispatch_) >> 16)),
            uint16(EncodedDispatch.unwrap(dispatch_))
        );
    }
}


// Chain: POLYGON - File: lib/rain.factory/src/interface/ICloneableV2.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

/// @dev This hash MUST be returned when an `ICloneableV2` is successfully
/// initialized.
bytes32 constant ICLONEABLE_V2_SUCCESS = keccak256("ICloneableV2.initialize");

/// @title ICloneableV2
/// @notice Interface for cloneable contracts that support initialization.
interface ICloneableV2 {
    /// Overloaded initialize function MUST revert with this error.
    error InitializeSignatureFn();

    /// Initialize is intended to work like constructors but for cloneable
    /// proxies. The `ICloneableV2` contract MUST ensure that initialize can NOT
    /// be called more than once. The `ICloneableV2` contract is designed to be
    /// deployed by an `ICloneableFactoryV2` but MUST NOT assume that it will be.
    /// It is possible for someone to directly deploy an `ICloneableV2` and fail
    /// to call initialize before other functions are called, and end users MAY
    /// NOT realise or know how to confirm a safe deployment state. The
    /// `ICloneableV2` MUST take appropriate measures to ensure that functions
    /// called before initialize are safe to do so, or revert.
    ///
    /// To be fully generic, `initilize` accepts `bytes` and so MUST ABI decode
    /// within the initialize function. This allows a single factory to service
    /// arbitrary cloneable proxies but also erases the type of the
    /// initialization config from the ABI. As tooling will inevitably require
    /// the ABI to be known, it is RECOMMENDED that the `ICloneableV2` contract
    /// implements a typed `initialize` function that overloads the generic
    /// `initialize(bytes)` function. This overloaded function MUST revert with
    /// `InitializeSignatureFn` always, so that it is NEVER accidentally called.
    /// This avoids complex and expensive delegate call style patterns where a
    /// typed overload has to call back to itself and preserve the sender,
    /// instead we force the caller to know the correct signature and call the
    /// correct function directly with encoded bytes.
    ///
    /// If initialization is successful the `ICloneableV2` MUST return the
    /// keccak256 hash of the string "ICloneableV2.initialize". This avoids false
    /// positives where a contract building a proxy, such as an
    /// `ICloneableFactoryV2`, may incorrectly believe that the clone has been
    /// initialized but the implementation doesn't support `ICloneableV2`.
    ///
    /// @dev The `ICloneableV2` interface is identical to `ICloneableV1` except
    /// that it returns a `bytes32` success hash.
    /// @param data The initialization data.
    /// @return success keccak256("ICloneableV2.initialize") if successful.
    function initialize(bytes calldata data) external returns (bytes32 success);
}


// Chain: POLYGON - File: lib/sol.lib.memory/src/LibUint256Matrix.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "./LibPointer.sol";

library LibUint256Matrix {
    /// Pointer to the start (length prefix) of a `uint256[][]`.
    /// @param matrix The matrix to get the start pointer of.
    /// @return pointer The pointer to the start of `matrix`.
    function startPointer(uint256[][] memory matrix) internal pure returns (Pointer pointer) {
        assembly ("memory-safe") {
            pointer := matrix
        }
    }

    /// Pointer to the data of a `uint256[][]` NOT the length prefix.
    /// Note that the data of a `uint256[][]` is _references_ to the `uint256[]`
    /// start pointers and does NOT include the arrays themselves.
    /// @param matrix The matrix to get the data pointer of.
    /// @return pointer The pointer to the data of `matrix`.
    function dataPointer(uint256[][] memory matrix) internal pure returns (Pointer pointer) {
        assembly ("memory-safe") {
            pointer := add(matrix, 0x20)
        }
    }

    /// Pointer to the end of the allocated memory of a matrix.
    /// Note that the data of a `uint256[][]` is _references_ to the `uint256[]`
    /// start pointers and does NOT include the arrays themselves.
    /// @param matrix The matrix to get the end pointer of.
    /// @return pointer The pointer to the end of `matrix`.
    function endPointer(uint256[][] memory matrix) internal pure returns (Pointer pointer) {
        assembly ("memory-safe") {
            pointer := add(matrix, add(0x20, mul(0x20, mload(matrix))))
        }
    }

    /// Cast a `Pointer` to `uint256[][]` without modification or safety checks.
    /// The caller MUST ensure the pointer is to a valid region of memory for
    /// some `uint256[][]`.
    /// @param pointer The pointer to cast to `uint256[][]`.
    /// @return matrix The cast `uint256[][]`.
    function unsafeAsUint256Matrix(Pointer pointer) internal pure returns (uint256[][] memory matrix) {
        assembly ("memory-safe") {
            matrix := pointer
        }
    }

    /// 2-dimensional analogue of `arrayFrom`. Takes a 1-dimensional array and
    /// coerces it to a 2-dimensional matrix where the first and only item in the
    /// matrix is the 1-dimensional array.
    /// @param a The 1-dimensional array to include in the matrix.
    /// @return matrix The 2-dimensional matrix containing `a`.
    function matrixFrom(uint256[] memory a) internal pure returns (uint256[][] memory matrix) {
        assembly ("memory-safe") {
            matrix := mload(0x40)
            mstore(matrix, 1)
            mstore(add(matrix, 0x20), a)
            mstore(0x40, add(matrix, 0x40))
        }
    }

    /// 2-dimensional analogue of `arrayFrom`. Takes 1-dimensional arrays and
    /// coerces them to a 2-dimensional matrix where items in the matrix are the
    /// 1-dimensional arrays.
    /// @param a The 1-dimensional array to include in the matrix.
    /// @param b Second 1-dimensional array to include in the matrix.
    /// @return matrix The 2-dimensional matrix containing `a` and `b`.
    function matrixFrom(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[][] memory matrix) {
        assembly ("memory-safe") {
            matrix := mload(0x40)
            mstore(matrix, 2)
            mstore(add(matrix, 0x20), a)
            mstore(add(matrix, 0x40), b)
            mstore(0x40, add(matrix, 0x60))
        }
    }

    /// 2-dimensional analogue of `arrayFrom`. Takes 1-dimensional arrays and
    /// coerces them to a 2-dimensional matrix where items in the matrix are the
    /// 1-dimensional arrays.
    /// @param a The 1-dimensional array to include in the matrix.
    /// @param b Second 1-dimensional array to include in the matrix.
    /// @param c Third 1-dimensional array to include in the matrix.
    /// @return matrix The 2-dimensional matrix containing `a`, `b` and `c`.
    function matrixFrom(uint256[] memory a, uint256[] memory b, uint256[] memory c)
        internal
        pure
        returns (uint256[][] memory matrix)
    {
        assembly ("memory-safe") {
            matrix := mload(0x40)
            mstore(matrix, 3)
            mstore(add(matrix, 0x20), a)
            mstore(add(matrix, 0x40), b)
            mstore(add(matrix, 0x60), c)
            mstore(0x40, add(matrix, 0x80))
        }
    }
}


// Chain: POLYGON - File: lib/rain.flow/src/interface/IFlowERC1155V3.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/lib/caller/LibEvaluable.sol";

import "./IFlowV3.sol";

struct FlowERC1155Config {
    string uri;
    EvaluableConfig evaluableConfig;
    EvaluableConfig[] flowConfig;
}

struct ERC1155SupplyChange {
    address account;
    uint256 id;
    uint256 amount;
}

struct FlowERC1155IOV1 {
    ERC1155SupplyChange[] mints;
    ERC1155SupplyChange[] burns;
    FlowTransferV1 flow;
}

/// @title IFlowERC1155V3
interface IFlowERC1155V3 {
    event Initialize(address sender, FlowERC1155Config config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowERC1155IOV1 calldata);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC1155IOV1 calldata);
}


// Chain: POLYGON - File: lib/sol.lib.memory/src/LibStackPointer.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "./LibUint256Array.sol";
import "./LibMemory.sol";
import "./LibMemCpy.sol";

/// @title LibStackPointer
/// @notice A stack `Pointer` is still just a pointer to some memory, but we are
/// going to treat it like it is pointing to a stack data structure. That means
/// it can move "up" and "down" (increment and decrement) by `uint256` (32 bytes)
/// increments. Structurally a stack is a `uint256[]` but we can save a lot of
/// gas vs. default Solidity handling of array indexes by using assembly to
/// bypass runtime bounds checks on every read and write. Of course, this means
/// the caller is responsible for ensuring the stack reads and write are not out
/// of bounds.
///
/// The pointer to the bottom of a stack points at the 0th item, NOT the length
/// of the implied `uint256[]` and the top of a stack points AFTER the last item.
/// e.g. consider a `uint256[]` in memory with values `3 A B C` and assume this
/// starts at position `0` in memory, i.e. `0` points to value `3` for the
/// array length. In this case the stack bottom would be `Pointer.wrap(0x20)`
/// (32 bytes above 0, past the length) and the stack top would be
/// `StackPointer.wrap(0x80)` (96 bytes above the stack bottom).
///
/// Most of the functions in this library are equivalent to each other via
/// composition, i.e. everything could be achieved with just `up`, `down`,
/// `pop`, `push`, `peek`. The reason there is so much overloaded/duplicated
/// logic is that the Solidity compiler seems to fail at inlining equivalent
/// logic quite a lot. Perhaps once the IR compilation of Solidity is better
/// supported by tooling etc. we could remove a lot of this duplication as the
/// compiler itself would handle the optimisations.
library LibStackPointer {
    using LibStackPointer for Pointer;
    using LibStackPointer for uint256[];
    using LibStackPointer for bytes;
    using LibUint256Array for uint256[];
    using LibMemory for uint256;

    /// Read the word immediately below the given stack pointer.
    ///
    /// Treats the given pointer as a pointer to the top of the stack, so `peek`
    /// reads the word below the pointer.
    ///
    /// https://en.wikipedia.org/wiki/Peek_(data_type_operation)
    ///
    /// The caller MUST ensure this read is not out of bounds, e.g. a `peek` to
    /// `0` will underflow (and exhaust gas attempting to read).
    ///
    /// @param pointer Pointer to the top of the stack to read below.
    /// @return word The word that was read.
    function unsafePeek(Pointer pointer) internal pure returns (uint256 word) {
        assembly ("memory-safe") {
            word := mload(sub(pointer, 0x20))
        }
    }

    /// Peeks 2 words from the top of the stack.
    ///
    /// Same as `unsafePeek` but returns 2 words instead of 1.
    ///
    /// @param pointer The stack top to peek below.
    /// @return lower The lower of the two words read.
    /// @return upper The upper of the two words read.
    function unsafePeek2(Pointer pointer) internal pure returns (uint256 lower, uint256 upper) {
        assembly ("memory-safe") {
            lower := mload(sub(pointer, 0x40))
            upper := mload(sub(pointer, 0x20))
        }
    }

    /// Pops the word from the top of the stack.
    ///
    /// Treats the given pointer as a pointer to the top of the stack, so `pop`
    /// reads the word below the pointer. The popped pointer is returned
    /// alongside the read word.
    ///
    /// https://en.wikipedia.org/wiki/Stack_(abstract_data_type)
    ///
    /// The caller MUST ensure the pop will not result in an out of bounds read.
    ///
    /// @param pointer Pointer to the top of the stack to read below.
    /// @return pointerAfter Pointer after the pop.
    /// @return word The word that was read.
    function unsafePop(Pointer pointer) internal pure returns (Pointer pointerAfter, uint256 word) {
        assembly ("memory-safe") {
            pointerAfter := sub(pointer, 0x20)
            word := mload(pointerAfter)
        }
    }

    /// Pushes a word to the top of the stack.
    ///
    /// Treats the given pointer as a pointer to the top of the stack, so `push`
    /// writes a word at the pointer. The pushed pointer is returned.
    ///
    /// https://en.wikipedia.org/wiki/Stack_(abstract_data_type)
    ///
    /// The caller MUST ensure the push will not result in an out of bounds
    /// write.
    ///
    /// @param pointer The stack pointer to write at.
    /// @param word The value to write.
    /// @return The stack pointer above where `word` was written to.
    function unsafePush(Pointer pointer, uint256 word) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            mstore(pointer, word)
            pointer := add(pointer, 0x20)
        }
        return pointer;
    }

    /// Returns `length` values from the stack as an array without allocating
    /// new memory. As arrays always start with their length, this requires
    /// writing the length value to the stack below the array values. The value
    /// that is overwritten in the process is also returned so that data is not
    /// lost. For example, imagine a stack `[ A B C D ]` and we list 2 values.
    /// This will write the stack to look like `[ A 2 C D ]` and return both `B`
    /// and a pointer to `2` represented as a `uint256[]`.
    /// The returned array is ONLY valid for as long as the stack DOES NOT move
    /// back into its memory. As soon as the stack moves up again and writes into
    /// the array it will be corrupt. The caller MUST ensure that it does not
    /// read from the returned array after it has been corrupted by subsequent
    /// stack writes.
    /// @param pointer The stack pointer to read the values below into an
    /// array.
    /// @param length The number of values to include in the returned array.
    /// @return head The value that was overwritten with the length.
    /// @return tail The array constructed from the stack memory.
    function unsafeList(Pointer pointer, uint256 length) internal pure returns (uint256 head, uint256[] memory tail) {
        assembly ("memory-safe") {
            tail := sub(pointer, add(0x20, mul(length, 0x20)))
            head := mload(tail)
            mstore(tail, length)
        }
    }

    /// Convert two stack pointer values to a single stack index. A stack index
    /// is the distance in 32 byte increments between two stack pointers. The
    /// calculations assumes the two stack pointers are aligned.
    ///
    /// The caller MUST ensure the alignment of both values. The calculation is
    /// unchecked and MAY underflow.
    ///
    /// The caller MUST ensure that the upper is greater or equal the lower.
    ///
    /// @param lower The lower of the two values.
    /// @param upper The higher of the two values.
    /// @return The stack index as 32 byte distance between the top and bottom.
    function unsafeToIndex(Pointer lower, Pointer upper) internal pure returns (uint256) {
        unchecked {
            return (Pointer.unwrap(upper) - Pointer.unwrap(lower)) / 0x20;
        }
    }
}


// Chain: POLYGON - File: contracts/flow/libraries/LibFlow.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.flow/interface/IFlowV3.sol";

import "sol.lib.memory/LibStackPointer.sol";
import "sol.lib.memory/LibStackSentinel.sol";
import "rain.interpreter/interface/IInterpreterStoreV1.sol";

import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable as SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC721Upgradeable as IERC721} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IERC1155Upgradeable as IERC1155} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import {SafeCastUpgradeable as SafeCast} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

/// @dev Thrown for unsupported native transfers.
error UnsupportedNativeFlow();

/// @dev Thrown for unsupported erc20 transfers.
error UnsupportedERC20Flow();

/// @dev Thrown for unsupported erc721 transfers.
error UnsupportedERC721Flow();

/// @dev Thrown for unsupported erc1155 transfers.
error UnsupportedERC1155Flow();

bytes32 constant SENTINEL_HIGH_BITS = bytes32(
    0xF000000000000000000000000000000000000000000000000000000000000000
);

/// @dev We want a sentinel with the following properties:
/// - Won't collide with token amounts (| with very large number)
/// - Won't collide with token addresses
/// - Won't collide with common values like `type(uint256).max` and
///   `type(uint256).min`
/// - Won't collide with other sentinels from unrelated contexts
Sentinel constant RAIN_FLOW_SENTINEL = Sentinel.wrap(
    uint256(keccak256(bytes("RAIN_FLOW_SENTINEL")) | SENTINEL_HIGH_BITS)
);

library LibFlow {
    using SafeERC20 for IERC20;
    using LibPointer for Pointer;
    using LibStackPointer for Pointer;
    using LibStackSentinel for Pointer;
    using SafeCast for uint256;
    using LibFlow for FlowTransferV1;
    using LibUint256Array for uint256[];

    function stackToFlow(
        Pointer stackBottom_,
        Pointer stackTop_
    ) internal pure returns (FlowTransferV1 memory) {
        unchecked {
            ERC20Transfer[] memory erc20_;
            ERC721Transfer[] memory erc721_;
            ERC1155Transfer[] memory erc1155_;
            Pointer tuplesPointer_;
            // erc20
            (stackTop_, tuplesPointer_) = stackBottom_.consumeSentinelTuples(
                stackTop_,
                RAIN_FLOW_SENTINEL,
                4
            );
            assembly ("memory-safe") {
                erc20_ := tuplesPointer_
            }
            // erc721
            (stackTop_, tuplesPointer_) = stackBottom_.consumeSentinelTuples(
                stackTop_,
                RAIN_FLOW_SENTINEL,
                4
            );
            assembly ("memory-safe") {
                erc721_ := tuplesPointer_
            }
            // erc1155
            (stackTop_, tuplesPointer_) = stackBottom_.consumeSentinelTuples(
                stackTop_,
                RAIN_FLOW_SENTINEL,
                5
            );
            assembly ("memory-safe") {
                erc1155_ := tuplesPointer_
            }
            return FlowTransferV1(erc20_, erc721_, erc1155_);
        }
    }

    function flowERC20(FlowTransferV1 memory flowTransfer_) internal {
        unchecked {
            ERC20Transfer memory transfer_;
            for (uint256 i_ = 0; i_ < flowTransfer_.erc20.length; i_++) {
                transfer_ = flowTransfer_.erc20[i_];
                if (transfer_.from == msg.sender) {
                    IERC20(transfer_.token).safeTransferFrom(
                        msg.sender,
                        transfer_.to,
                        transfer_.amount
                    );
                } else if (transfer_.from == address(this)) {
                    IERC20(transfer_.token).safeTransfer(
                        transfer_.to,
                        transfer_.amount
                    );
                } else {
                    // We don't support `from` as anyone other than `you` or `me`
                    // as this would allow for all kinds of issues re: approvals.
                    revert UnsupportedERC20Flow();
                }
            }
        }
    }

    function flowERC721(FlowTransferV1 memory flowTransfer_) internal {
        unchecked {
            ERC721Transfer memory transfer_;
            for (uint256 i_ = 0; i_ < flowTransfer_.erc721.length; i_++) {
                transfer_ = flowTransfer_.erc721[i_];
                if (
                    transfer_.from != msg.sender &&
                    transfer_.from != address(this)
                ) {
                    revert UnsupportedERC721Flow();
                }
                IERC721(transfer_.token).safeTransferFrom(
                    transfer_.from,
                    transfer_.to,
                    transfer_.id
                );
            }
        }
    }

    function flowERC1155(FlowTransferV1 memory flowTransfer_) internal {
        unchecked {
            ERC1155Transfer memory transfer_;
            for (uint256 i_ = 0; i_ < flowTransfer_.erc1155.length; i_++) {
                transfer_ = flowTransfer_.erc1155[i_];
                if (
                    transfer_.from != msg.sender &&
                    transfer_.from != address(this)
                ) {
                    revert UnsupportedERC1155Flow();
                }
                // @todo safeBatchTransferFrom support.
                // @todo data support.
                IERC1155(transfer_.token).safeTransferFrom(
                    transfer_.from,
                    transfer_.to,
                    transfer_.id,
                    transfer_.amount,
                    ""
                );
            }
        }
    }

    function flow(
        FlowTransferV1 memory flowTransfer_,
        IInterpreterStoreV1 interpreterStore_,
        uint256[] memory kvs_
    ) internal {
        if (kvs_.length > 0) {
            interpreterStore_.set(DEFAULT_STATE_NAMESPACE, kvs_);
        }
        flowTransfer_.flowERC20();
        flowTransfer_.flowERC721();
        flowTransfer_.flowERC1155();
    }
}


// Chain: POLYGON - File: contracts/flow/FlowCommon.sol
// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "./libraries/LibFlow.sol";
import "rain.interpreter/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/interface/IExpressionDeployerV1.sol";
import "rain.interpreter/interface/IInterpreterV1.sol";
import "rain.interpreter/lib/caller/LibEncodedDispatch.sol";
import "rain.interpreter/lib/caller/LibContext.sol";
import "rain.interpreter/lib/state/LibInterpreterState.sol";
import "rain.interpreter/abstract/DeployerDiscoverableMetaV1.sol";
import "rain.interpreter/lib/caller/LibEvaluable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {MulticallUpgradeable as Multicall} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {ERC721HolderUpgradeable as ERC721Holder} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {ERC1155HolderUpgradeable as ERC1155Holder} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

/// Thrown when the flow being evaluated is unregistered.
/// @param unregisteredHash Hash of the unregistered flow.
error UnregisteredFlow(bytes32 unregisteredHash);

/// Thrown when the min outputs for a flow is fewer than the sentinels.
error BadMinStackLength(uint256 flowMinOutputs_);

uint256 constant FLAG_COLUMN_FLOW_ID = 0;
uint256 constant FLAG_ROW_FLOW_ID = 0;
uint256 constant FLAG_COLUMN_FLOW_TIME = 0;
uint256 constant FLAG_ROW_FLOW_TIME = 2;

uint256 constant MIN_FLOW_SENTINELS = 3;

SourceIndex constant FLOW_ENTRYPOINT = SourceIndex.wrap(0);
uint16 constant FLOW_MAX_OUTPUTS = type(uint16).max;

contract FlowCommon is
    ERC721Holder,
    ERC1155Holder,
    Multicall,
    IInterpreterCallerV2,
    DeployerDiscoverableMetaV1
{
    using LibStackPointer for Pointer;
    using LibStackPointer for uint256[];
    using LibUint256Array for uint256;
    using LibUint256Array for uint256[];
    using LibEvaluable for Evaluable;

    /// Evaluable hash => is registered
    mapping(bytes32 => uint256) internal registeredFlows;

    event FlowInitialized(address sender, Evaluable evaluable);

    constructor(
        bytes32 metaHash_,
        DeployerDiscoverableMetaV1ConstructionConfig memory config_
    ) DeployerDiscoverableMetaV1(metaHash_, config_) {
        _disableInitializers();
    }

    function flowCommonInit(
        EvaluableConfig[] memory evaluableConfigs_,
        uint256 flowMinOutputs_
    ) internal onlyInitializing {
        __ERC721Holder_init();
        __ERC1155Holder_init();
        __Multicall_init();
        if (flowMinOutputs_ < MIN_FLOW_SENTINELS) {
            revert BadMinStackLength(flowMinOutputs_);
        }
        EvaluableConfig memory config_;
        Evaluable memory evaluable_;
        for (uint256 i_ = 0; i_ < evaluableConfigs_.length; i_++) {
            config_ = evaluableConfigs_[i_];
            (
                IInterpreterV1 interpreter_,
                IInterpreterStoreV1 store_,
                address expression_
            ) = config_.deployer.deployExpression(
                    config_.sources,
                    config_.constants,
                    LibUint256Array.arrayFrom(flowMinOutputs_)
                );
            evaluable_ = Evaluable(interpreter_, store_, expression_);
            registeredFlows[evaluable_.hash()] = 1;
            emit FlowInitialized(msg.sender, evaluable_);
        }
    }

    function _flowDispatch(
        address expression_
    ) internal pure returns (EncodedDispatch) {
        return
            LibEncodedDispatch.encode(
                expression_,
                FLOW_ENTRYPOINT,
                FLOW_MAX_OUTPUTS
            );
    }

    modifier onlyRegisteredEvaluable(Evaluable memory evaluable_) {
        bytes32 hash_ = evaluable_.hash();
        if (registeredFlows[hash_] == 0) {
            revert UnregisteredFlow(hash_);
        }
        _;
    }

    function flowStack(
        Evaluable memory evaluable_,
        uint256[][] memory context_
    )
        internal
        view
        onlyRegisteredEvaluable(evaluable_)
        returns (Pointer, Pointer, uint256[] memory)
    {
        (uint256[] memory stack_, uint256[] memory kvs_) = evaluable_
            .interpreter
            .eval(
                evaluable_.store,
                DEFAULT_STATE_NAMESPACE,
                _flowDispatch(evaluable_.expression),
                context_
            );
        return (stack_.dataPointer(), stack_.endPointer(), kvs_);
    }
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

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
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
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
        if (_initialized < type(uint8).max) {
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


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

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
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
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


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol
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


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol
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


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
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


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol
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


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol
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


// Chain: POLYGON - File: lib/rain.interpreter/src/interface/IInterpreterV1.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "./IInterpreterStoreV1.sol";

/// @dev The index of a source within a deployed expression that can be evaluated
/// by an `IInterpreterV1`. MAY be an entrypoint or the index of a source called
/// internally such as by the `call` opcode.
type SourceIndex is uint16;

/// @dev Encoded information about a specific evaluation including the expression
/// address onchain, entrypoint and expected return values.
type EncodedDispatch is uint256;

/// @dev The namespace for state changes as requested by the calling contract.
/// The interpreter MUST apply this namespace IN ADDITION to namespacing by
/// caller etc.
type StateNamespace is uint256;

/// @dev Additional bytes that can be used to configure a single opcode dispatch.
/// Commonly used to specify the number of inputs to a variadic function such
/// as addition or multiplication.
type Operand is uint256;

/// @dev The default state namespace MUST be used when a calling contract has no
/// particular opinion on or need for dynamic namespaces.
StateNamespace constant DEFAULT_STATE_NAMESPACE = StateNamespace.wrap(0);

/// @title IInterpreterV1
/// Interface into a standard interpreter that supports:
///
/// - evaluating `view` logic deployed onchain by an `IExpressionDeployerV1`
/// - receiving arbitrary `uint256[][]` supporting context to be made available
///   to the evaluated logic
/// - handling subsequent state changes in bulk in response to evaluated logic
/// - namespacing state changes according to the caller's preferences to avoid
///   unwanted key collisions
/// - exposing its internal function pointers to support external precompilation
///   of logic for more gas efficient runtime evaluation by the interpreter
///
/// The interface is designed to be stable across many versions and
/// implementations of an interpreter, balancing minimalism with features
/// required for a general purpose onchain interpreted compute environment.
///
/// The security model of an interpreter is that it MUST be resilient to
/// malicious expressions even if they dispatch arbitrary internal function
/// pointers during an eval. The interpreter MAY return garbage or exhibit
/// undefined behaviour or error during an eval, _provided that no state changes
/// are persisted_ e.g. in storage, such that only the caller that specifies the
/// malicious expression can be negatively impacted by the result. In turn, the
/// caller must guard itself against arbitrarily corrupt/malicious reverts and
/// return values from any interpreter that it requests an expression from. And
/// so on and so forth up to the externally owned account (EOA) who signs the
/// transaction and agrees to a specific combination of contracts, expressions
/// and interpreters, who can presumably make an informed decision about which
/// ones to trust to get the job done.
///
/// The state changes for an interpreter are expected to be produces by an `eval`
/// and passed to the `IInterpreterStoreV1` returned by the eval, as-is by the
/// caller, after the caller has had an opportunity to apply their own
/// intermediate logic such as reentrancy defenses against malicious
/// interpreters. The interpreter is free to structure the state changes however
/// it wants but MUST guard against the calling contract corrupting the changes
/// between `eval` and `set`. For example a store could sandbox storage writes
/// per-caller so that a malicious caller can only damage their own state
/// changes, while honest callers respect, benefit from and are protected by the
/// interpreter store's state change handling.
///
/// The two step eval-state model allows eval to be read-only which provides
/// security guarantees for the caller such as no stateful reentrancy, either
/// from the interpreter or some contract interface used by some word, while
/// still allowing for storage writes. As the storage writes happen on the
/// interpreter rather than the caller (c.f. delegate call) the caller DOES NOT
/// need to trust the interpreter, which allows for permissionless selection of
/// interpreters by end users. Delegate call always implies an admin key on the
/// caller because the delegatee contract can write arbitrarily to the state of
/// the delegator, which severely limits the generality of contract composition.
interface IInterpreterV1 {
    /// Exposes the function pointers as `uint16` values packed into a single
    /// `bytes` in the same order as they would be indexed into by opcodes. For
    /// example, if opcode `2` should dispatch function at position `0x1234` then
    /// the start of the returned bytes would be `0xXXXXXXXX1234` where `X` is
    /// a placeholder for the function pointers of opcodes `0` and `1`.
    ///
    /// `IExpressionDeployerV1` contracts use these function pointers to
    /// "compile" the expression into something that an interpreter can dispatch
    /// directly without paying gas to lookup the same at runtime. As the
    /// validity of any integrity check and subsequent dispatch is highly
    /// sensitive to both the function pointers and overall bytecode of the
    /// interpreter, `IExpressionDeployerV1` contracts SHOULD implement guards
    /// against accidentally being deployed onchain paired against an unknown
    /// interpreter. It is very easy for an apparent compatible pairing to be
    /// subtly and critically incompatible due to addition/removal/reordering of
    /// opcodes and compiler optimisations on the interpreter bytecode.
    ///
    /// This MAY return different values during construction vs. all other times
    /// after the interpreter has been successfully deployed onchain. DO NOT rely
    /// on function pointers reported during contract construction.
    function functionPointers() external view returns (bytes memory);

    /// The raison d'etre for an interpreter. Given some expression and per-call
    /// additional contextual data, produce a stack of results and a set of state
    /// changes that the caller MAY OPTIONALLY pass back to be persisted by a
    /// call to `IInterpreterStoreV1.set`.
    /// @param store The storage contract that the returned key/value pairs
    /// MUST be passed to IF the calling contract is in a non-static calling
    /// context. Static calling contexts MUST pass `address(0)`.
    /// @param namespace The state namespace that will be fully qualified by the
    /// interpreter at runtime in order to perform gets on the underlying store.
    /// MUST be the same namespace passed to the store by the calling contract
    /// when sending the resulting key/value items to storage.
    /// @param dispatch All the information required for the interpreter to load
    /// an expression, select an entrypoint and return the values expected by the
    /// caller. The interpreter MAY encode dispatches differently to
    /// `LibEncodedDispatch` but this WILL negatively impact compatibility for
    /// calling contracts that hardcode the encoding logic.
    /// @param context A 2-dimensional array of data that can be indexed into at
    /// runtime by the interpreter. The calling contract is responsible for
    /// ensuring the authenticity and completeness of context data. The
    /// interpreter MUST revert at runtime if an expression attempts to index
    /// into some context value that is not provided by the caller. This implies
    /// that context reads cannot be checked for out of bounds reads at deploy
    /// time, as the runtime context MAY be provided in a different shape to what
    /// the expression is expecting.
    /// Same as `eval` but allowing the caller to specify a namespace under which
    /// the state changes will be applied. The interpeter MUST ensure that keys
    /// will never collide across namespaces, even if, for example:
    ///
    /// - The calling contract is malicious and attempts to craft a collision
    ///   with state changes from another contract
    /// - The expression is malicious and attempts to craft a collision with
    ///   other expressions evaluated by the same calling contract
    ///
    /// A malicious entity MAY have access to significant offchain resources to
    /// attempt to precompute key collisions through brute force. The collision
    /// resistance of namespaces should be comparable or equivalent to the
    /// collision resistance of the hashing algorithms employed by the blockchain
    /// itself, such as the design of `mapping` in Solidity that hashes each
    /// nested key to produce a collision resistant compound key.
    /// @return stack The list of values produced by evaluating the expression.
    /// MUST NOT be longer than the maximum length specified by `dispatch`, if
    /// applicable.
    /// @return kvs A list of pairwise key/value items to be saved in the store.
    function eval(
        IInterpreterStoreV1 store,
        StateNamespace namespace,
        EncodedDispatch dispatch,
        uint256[][] calldata context
    ) external view returns (uint256[] memory stack, uint256[] memory kvs);
}


// Chain: POLYGON - File: lib/sol.lib.memory/src/LibPointer.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

/// A pointer to a location in memory. This is a `uint256` to save gas on low
/// level operations on the evm stack. These same low level operations typically
/// WILL NOT check for overflow or underflow, so all pointer logic MUST ensure
/// that reads, writes and movements are not out of bounds.
type Pointer is uint256;

/// @title LibPointer
/// Ergonomic wrappers around common pointer movements, reading and writing. As
/// wrappers on such low level operations often introduce too much jump gas
/// overhead, these functions MAY find themselves used in reference
/// implementations that more optimised code can be fuzzed against. MAY also be
/// situationally useful on cooler performance paths.
library LibPointer {
    /// Cast a `Pointer` to `bytes` without modification or any safety checks.
    /// The caller MUST ensure the pointer is to a valid region of memory for
    /// some `bytes`.
    /// @param pointer The pointer to cast to `bytes`.
    /// @return data The cast `bytes`.
    function unsafeAsBytes(Pointer pointer) internal pure returns (bytes memory data) {
        assembly ("memory-safe") {
            data := pointer
        }
    }

    /// Increase some pointer by a number of bytes.
    ///
    /// This is UNSAFE because it can silently overflow or point beyond some
    /// data structure. The caller MUST ensure that this is a safe operation.
    ///
    /// Note that moving a pointer by some bytes offset is likely to unalign it
    /// with the 32 byte increments of the Solidity allocator.
    ///
    /// @param pointer The pointer to increase by `length`.
    /// @param length The number of bytes to increase the pointer by.
    /// @return The increased pointer.
    function unsafeAddBytes(Pointer pointer, uint256 length) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            pointer := add(pointer, length)
        }
        return pointer;
    }

    /// Increase some pointer by a single 32 byte word.
    ///
    /// This is UNSAFE because it can silently overflow or point beyond some
    /// data structure. The caller MUST ensure that this is a safe operation.
    ///
    /// If the original pointer is aligned to the Solidity allocator it will be
    /// aligned after the movement.
    ///
    /// @param pointer The pointer to increase by a single word.
    /// @return The increased pointer.
    function unsafeAddWord(Pointer pointer) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            pointer := add(pointer, 0x20)
        }
        return pointer;
    }

    /// Increase some pointer by multiple 32 byte words.
    ///
    /// This is UNSAFE because it can silently overflow or point beyond some
    /// data structure. The caller MUST ensure that this is a safe operation.
    ///
    /// If the original pointer is aligned to the Solidity allocator it will be
    /// aligned after the movement.
    ///
    /// @param pointer The pointer to increase.
    /// @param words The number of words to increase the pointer by.
    /// @return The increased pointer.
    function unsafeAddWords(Pointer pointer, uint256 words) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            pointer := add(pointer, mul(0x20, words))
        }
        return pointer;
    }

    /// Decrease some pointer by a single 32 byte word.
    ///
    /// This is UNSAFE because it can silently underflow or point below some
    /// data structure. The caller MUST ensure that this is a safe operation.
    ///
    /// If the original pointer is aligned to the Solidity allocator it will be
    /// aligned after the movement.
    ///
    /// @param pointer The pointer to decrease by a single word.
    /// @return The decreased pointer.
    function unsafeSubWord(Pointer pointer) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            pointer := sub(pointer, 0x20)
        }
        return pointer;
    }

    /// Decrease some pointer by multiple 32 byte words.
    ///
    /// This is UNSAFE because it can silently underflow or point below some
    /// data structure. The caller MUST ensure that this is a safe operation.
    ///
    /// If the original pointer is aligned to the Solidity allocator it will be
    /// aligned after the movement.
    ///
    /// @param pointer The pointer to decrease.
    /// @param words The number of words to decrease the pointer by.
    /// @return The decreased pointer.
    function unsafeSubWords(Pointer pointer, uint256 words) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            pointer := sub(pointer, mul(0x20, words))
        }
        return pointer;
    }

    /// Read the word at the pointer.
    ///
    /// This is UNSAFE because it can read outside any particular data stucture
    /// or even beyond allocated memory. The caller MUST ensure that this is a
    /// safe operation.
    ///
    /// @param pointer Pointer to read the word at.
    /// @return word The word read from the pointer.
    function unsafeReadWord(Pointer pointer) internal pure returns (uint256 word) {
        assembly ("memory-safe") {
            word := mload(pointer)
        }
    }

    /// Write a word at the pointer.
    ///
    /// This is UNSAFE because it can write outside any particular data stucture
    /// or even beyond allocated memory. The caller MUST ensure that this is a
    /// safe operation.
    ///
    /// @param pointer Pointer to write the word at.
    /// @param word The word to write.
    function unsafeWriteWord(Pointer pointer, uint256 word) internal pure {
        assembly ("memory-safe") {
            mstore(pointer, word)
        }
    }

    /// Get the pointer to the end of all allocated memory.
    /// As per Solidity docs, there is no guarantee that the region of memory
    /// beyond this pointer is zeroed out, as assembly MAY write beyond allocated
    /// memory for temporary use if the scratch space is insufficient.
    /// @return pointer The pointer to the end of all allocated memory.
    function allocatedMemoryPointer() internal pure returns (Pointer pointer) {
        assembly ("memory-safe") {
            pointer := mload(0x40)
        }
    }
}


// Chain: POLYGON - File: lib/rain.interpreter/src/interface/IInterpreterCallerV2.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

/// Typed embodiment of some context data with associated signer and signature.
/// The signature MUST be over the packed encoded bytes of the context array,
/// i.e. the context array concatenated as bytes without the length prefix, then
/// hashed, then handled as per EIP-191 to produce a final hash to be signed.
///
/// The calling contract (likely with the help of `LibContext`) is responsible
/// for ensuring the authenticity of the signature, but not authorizing _who_ can
/// sign. IN ADDITION to authorisation of the signer to known-good entities the
/// expression is also responsible for:
///
/// - Enforcing the context is the expected data (e.g. with a domain separator)
/// - Tracking and enforcing nonces if signed contexts are only usable one time
/// - Tracking and enforcing uniqueness of signed data if relevant
/// - Checking and enforcing expiry times if present and relevant in the context
/// - Many other potential constraints that expressions may want to enforce
///
/// EIP-1271 smart contract signatures are supported in addition to EOA
/// signatures via. the Open Zeppelin `SignatureChecker` library, which is
/// wrapped by `LibContext.build`. As smart contract signatures are checked
/// onchain they CAN BE REVOKED AT ANY MOMENT as the smart contract can simply
/// return `false` when it previously returned `true`.
///
/// @param signer The account that produced the signature for `context`. The
/// calling contract MUST authenticate that the signer produced the signature.
/// @param context The signed data in a format that can be merged into a
/// 2-dimensional context matrix as-is.
/// @param signature The cryptographic signature for `context`. The calling
/// contract MUST authenticate that the signature is valid for the `signer` and
/// `context`.
struct SignedContextV1 {
    // The ordering of these fields is important and used in assembly offset
    // calculations and hashing.
    address signer;
    uint256[] context;
    bytes signature;
}

uint256 constant SIGNED_CONTEXT_SIGNER_OFFSET = 0;
uint256 constant SIGNED_CONTEXT_CONTEXT_OFFSET = 0x20;
uint256 constant SIGNED_CONTEXT_SIGNATURE_OFFSET = 0x40;

/// @title IInterpreterCallerV2
/// @notice A contract that calls an `IInterpreterV1` via. `eval`. There are near
/// zero requirements on a caller other than:
///
/// - Emit some meta about itself upon construction so humans know what the
///   contract does
/// - Provide the context, which can be built in a standard way by `LibContext`
/// - Handle the stack array returned from `eval`
/// - OPTIONALLY emit the `Context` event
/// - OPTIONALLY set state on the `IInterpreterStoreV1` returned from eval.
interface IInterpreterCallerV2 {
    /// Calling contracts SHOULD emit `Context` before calling `eval` if they
    /// are able. Notably `eval` MAY be called within a static call which means
    /// that events cannot be emitted, in which case this does not apply. It MAY
    /// NOT be useful to emit this multiple times for several eval calls if they
    /// all share a common context, in which case a single emit is sufficient.
    /// @param sender `msg.sender` building the context.
    /// @param context The context that was built.
    event Context(address sender, uint256[][] context);
}


// Chain: POLYGON - File: lib/rain.interpreter/src/lib/caller/LibEvaluable.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "../../interface/IExpressionDeployerV1.sol";
import "../../interface/IInterpreterStoreV1.sol";
import "../../interface/IInterpreterV1.sol";

/// Standard struct that can be embedded in ABIs in a consistent format for
/// tooling to read/write. MAY be useful to bundle up the data required to call
/// `IExpressionDeployerV1` but is NOT mandatory.
/// @param deployer Will deploy the expression from sources and constants.
/// @param sources Will be deployed to an expression address for use in
/// `Evaluable`.
/// @param constants Will be available to the expression at runtime.
struct EvaluableConfig {
    IExpressionDeployerV1 deployer;
    bytes[] sources;
    uint256[] constants;
}

/// Struct over the return of `IExpressionDeployerV1.deployExpression`
/// which MAY be more convenient to work with than raw addresses.
/// @param interpreter Will evaluate the expression.
/// @param store Will store state changes due to evaluation of the expression.
/// @param expression Will be evaluated by the interpreter.
struct Evaluable {
    IInterpreterV1 interpreter;
    IInterpreterStoreV1 store;
    address expression;
}

/// @title LibEvaluable
/// @notice Common logic to provide consistent implementations of common tasks
/// that could be arbitrarily/ambiguously implemented, but work much better if
/// consistently implemented.
library LibEvaluable {
    /// Hashes an `Evaluable`, ostensibly so that only the hash need be stored,
    /// thus only storing a single `uint256` instead of 3x `uint160`.
    /// @param evaluable_ The evaluable to hash.
    /// @return hash_ Standard hash of the evaluable.
    function hash(Evaluable memory evaluable_) internal pure returns (bytes32 hash_) {
        // `Evaluable` does NOT contain any dynamic types so it is safe to encode
        // packed for hashing, and is preferable due to the smaller/simpler
        // in-memory structure. It also makes it easier to replicate the logic
        // offchain as a simple concatenation of bytes.
        assembly ("memory-safe") {
            hash_ := keccak256(evaluable_, 0x60)
        }
    }
}


// Chain: POLYGON - File: lib/rain.flow/src/interface/IFlowV3.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/lib/caller/LibEvaluable.sol";

struct FlowConfig {
    // https://github.com/ethereum/solidity/issues/13597
    EvaluableConfig dummyConfig;
    EvaluableConfig[] config;
}

struct ERC20Transfer {
    address token;
    address from;
    address to;
    uint256 amount;
}

struct ERC721Transfer {
    address token;
    address from;
    address to;
    uint256 id;
}

struct ERC1155Transfer {
    address token;
    address from;
    address to;
    uint256 id;
    uint256 amount;
}

struct FlowTransferV1 {
    ERC20Transfer[] erc20;
    ERC721Transfer[] erc721;
    ERC1155Transfer[] erc1155;
}

interface IFlowV3 {
    event Initialize(address sender, FlowConfig config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowTransferV1 calldata flowTransfer);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowTransferV1 calldata flowTransfer);
}


// Chain: POLYGON - File: lib/sol.lib.memory/src/LibUint256Array.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "./LibMemCpy.sol";

/// Thrown if a truncated length is longer than the array being truncated. It is
/// not possible to truncate something and increase its length as the memory
/// region after the array MAY be allocated for something else already.
error OutOfBoundsTruncate(uint256 arrayLength, uint256 truncatedLength);

/// @title Uint256Array
/// @notice Things we want to do carefully and efficiently with uint256 arrays
/// that Solidity doesn't give us native tools for.
library LibUint256Array {
    using LibUint256Array for uint256[];

    /// Pointer to the start (length prefix) of a `uint256[]`.
    /// @param array The array to get the start pointer of.
    /// @return pointer The pointer to the start of `array`.
    function startPointer(uint256[] memory array) internal pure returns (Pointer pointer) {
        assembly ("memory-safe") {
            pointer := array
        }
    }

    /// Pointer to the data of a `uint256[]` NOT the length prefix.
    /// @param array The array to get the data pointer of.
    /// @return pointer The pointer to the data of `array`.
    function dataPointer(uint256[] memory array) internal pure returns (Pointer pointer) {
        assembly ("memory-safe") {
            pointer := add(array, 0x20)
        }
    }

    /// Pointer to the end of the allocated memory of an array.
    /// @param array The array to get the end pointer of.
    /// @return pointer The pointer to the end of `array`.
    function endPointer(uint256[] memory array) internal pure returns (Pointer pointer) {
        assembly ("memory-safe") {
            pointer := add(array, add(0x20, mul(0x20, mload(array))))
        }
    }

    /// Cast a `Pointer` to `uint256[]` without modification or safety checks.
    /// The caller MUST ensure the pointer is to a valid region of memory for
    /// some `uint256[]`.
    /// @param pointer The pointer to cast to `uint256[]`.
    /// @return array The cast `uint256[]`.
    function unsafeAsUint256Array(Pointer pointer) internal pure returns (uint256[] memory array) {
        assembly ("memory-safe") {
            array := pointer
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a A single integer to build an array around.
    /// @return array The newly allocated array including `a` as a single item.
    function arrayFrom(uint256 a) internal pure returns (uint256[] memory array) {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 1)
            mstore(add(array, 0x20), a)
            mstore(0x40, add(array, 0x40))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @return array The newly allocated array including `a` and `b` as the only
    /// items.
    function arrayFrom(uint256 a, uint256 b) internal pure returns (uint256[] memory array) {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 2)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(0x40, add(array, 0x60))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @param c The third integer to build an array around.
    /// @return array The newly allocated array including `a`, `b` and `c` as the
    /// only items.
    function arrayFrom(uint256 a, uint256 b, uint256 c) internal pure returns (uint256[] memory array) {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 3)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(add(array, 0x60), c)
            mstore(0x40, add(array, 0x80))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @param c The third integer to build an array around.
    /// @param d The fourth integer to build an array around.
    /// @return array The newly allocated array including `a`, `b`, `c` and `d` as the
    /// only items.
    function arrayFrom(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256[] memory array) {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 4)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(add(array, 0x60), c)
            mstore(add(array, 0x80), d)
            mstore(0x40, add(array, 0xA0))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @param c The third integer to build an array around.
    /// @param d The fourth integer to build an array around.
    /// @param e The fifth integer to build an array around.
    /// @return array The newly allocated array including `a`, `b`, `c`, `d` and
    /// `e` as the only items.
    function arrayFrom(uint256 a, uint256 b, uint256 c, uint256 d, uint256 e)
        internal
        pure
        returns (uint256[] memory array)
    {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 5)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(add(array, 0x60), c)
            mstore(add(array, 0x80), d)
            mstore(add(array, 0xA0), e)
            mstore(0x40, add(array, 0xC0))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @param c The third integer to build an array around.
    /// @param d The fourth integer to build an array around.
    /// @param e The fifth integer to build an array around.
    /// @param f The sixth integer to build an array around.
    /// @return array The newly allocated array including `a`, `b`, `c`, `d`, `e`
    /// and `f` as the only items.
    function arrayFrom(uint256 a, uint256 b, uint256 c, uint256 d, uint256 e, uint256 f)
        internal
        pure
        returns (uint256[] memory array)
    {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 6)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(add(array, 0x60), c)
            mstore(add(array, 0x80), d)
            mstore(add(array, 0xA0), e)
            mstore(add(array, 0xC0), f)
            mstore(0x40, add(array, 0xE0))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The head of the new array.
    /// @param tail The tail of the new array.
    /// @return array The new array.
    function arrayFrom(uint256 a, uint256[] memory tail) internal pure returns (uint256[] memory array) {
        assembly ("memory-safe") {
            let length := add(mload(tail), 1)
            let outputCursor := mload(0x40)
            array := outputCursor
            let outputEnd := add(outputCursor, add(0x20, mul(length, 0x20)))
            mstore(0x40, outputEnd)

            mstore(outputCursor, length)
            mstore(add(outputCursor, 0x20), a)

            for {
                outputCursor := add(outputCursor, 0x40)
                let inputCursor := add(tail, 0x20)
            } lt(outputCursor, outputEnd) {
                outputCursor := add(outputCursor, 0x20)
                inputCursor := add(inputCursor, 0x20)
            } { mstore(outputCursor, mload(inputCursor)) }
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first item of the new array.
    /// @param b The second item of the new array.
    /// @param tail The tail of the new array.
    /// @return array The new array.
    function arrayFrom(uint256 a, uint256 b, uint256[] memory tail) internal pure returns (uint256[] memory array) {
        assembly ("memory-safe") {
            let length := add(mload(tail), 2)
            let outputCursor := mload(0x40)
            array := outputCursor
            let outputEnd := add(outputCursor, add(0x20, mul(length, 0x20)))
            mstore(0x40, outputEnd)

            mstore(outputCursor, length)
            mstore(add(outputCursor, 0x20), a)
            mstore(add(outputCursor, 0x40), b)

            for {
                outputCursor := add(outputCursor, 0x60)
                let inputCursor := add(tail, 0x20)
            } lt(outputCursor, outputEnd) {
                outputCursor := add(outputCursor, 0x20)
                inputCursor := add(inputCursor, 0x20)
            } { mstore(outputCursor, mload(inputCursor)) }
        }
    }

    /// Solidity provides no way to change the length of in-memory arrays but
    /// it also does not deallocate memory ever. It is always safe to shrink an
    /// array that has already been allocated, with the caveat that the
    /// truncated items will effectively become inaccessible regions of memory.
    /// That is to say, we deliberately "leak" the truncated items, but that is
    /// no worse than Solidity's native behaviour of leaking everything always.
    /// The array is MUTATED in place so there is no return value and there is
    /// no new allocation or copying of data either.
    /// @param array The array to truncate.
    /// @param newLength The new length of the array after truncation.
    function truncate(uint256[] memory array, uint256 newLength) internal pure {
        if (newLength > array.length) {
            revert OutOfBoundsTruncate(array.length, newLength);
        }
        assembly ("memory-safe") {
            mstore(array, newLength)
        }
    }

    /// Extends `base_` with `extend_` by allocating only an additional
    /// `extend_.length` words onto `base_` and copying only `extend_` if
    /// possible. If `base_` is large this MAY be significantly more efficient
    /// than allocating `base_.length + extend_.length` for an entirely new array
    /// and copying both `base_` and `extend_` into the new array one item at a
    /// time in Solidity.
    ///
    /// The efficient version of extension is only possible if the free memory
    /// pointer sits at the end of the base array at the moment of extension. If
    /// there is allocated memory after the end of base then extension will
    /// require copying both the base and extend arays to a new region of memory.
    /// The caller is responsible for optimising code paths to avoid additional
    /// allocations.
    ///
    /// This function is UNSAFE because the base array IS MUTATED DIRECTLY by
    /// some code paths AND THE FINAL RETURN ARRAY MAY POINT TO THE SAME REGION
    /// OF MEMORY. It is NOT POSSIBLE to reliably see this behaviour from the
    /// caller in all cases as the Solidity compiler optimisations may switch the
    /// caller between the allocating and non-allocating logic due to subtle
    /// optimisation reasons. To use this function safely THE CALLER MUST NOT USE
    /// THE BASE ARRAY AND MUST USE THE RETURNED ARRAY ONLY. It is safe to use
    /// the extend array after calling this function as it is never mutated, it
    /// is only copied from.
    ///
    /// @param b The base integer array that will be extended by `e`.
    /// @param e The extend integer array that extends `b`.
    /// @return extended The extended array of `b` extended by `e`.
    function unsafeExtend(uint256[] memory b, uint256[] memory e) internal pure returns (uint256[] memory extended) {
        assembly ("memory-safe") {
            // Slither doesn't recognise assembly function names as mixed case
            // even if they are.
            // https://github.com/crytic/slither/issues/1815
            //slither-disable-next-line naming-convention
            function extendInline(base, extend) -> baseAfter {
                let outputCursor := mload(0x40)
                let baseLength := mload(base)
                let baseEnd := add(base, add(0x20, mul(baseLength, 0x20)))

                // If base is NOT the last thing in allocated memory, allocate,
                // copy and recurse.
                switch eq(outputCursor, baseEnd)
                case 0 {
                    let newBase := outputCursor
                    let newBaseEnd := add(newBase, sub(baseEnd, base))
                    mstore(0x40, newBaseEnd)
                    for { let inputCursor := base } lt(outputCursor, newBaseEnd) {
                        inputCursor := add(inputCursor, 0x20)
                        outputCursor := add(outputCursor, 0x20)
                    } { mstore(outputCursor, mload(inputCursor)) }

                    baseAfter := extendInline(newBase, extend)
                }
                case 1 {
                    let totalLength_ := add(baseLength, mload(extend))
                    let outputEnd_ := add(base, add(0x20, mul(totalLength_, 0x20)))
                    mstore(base, totalLength_)
                    mstore(0x40, outputEnd_)
                    for { let inputCursor := add(extend, 0x20) } lt(outputCursor, outputEnd_) {
                        inputCursor := add(inputCursor, 0x20)
                        outputCursor := add(outputCursor, 0x20)
                    } { mstore(outputCursor, mload(inputCursor)) }

                    baseAfter := base
                }
            }

            extended := extendInline(b, e)
        }
    }
}


// Chain: POLYGON - File: lib/sol.lib.memory/src/LibMemory.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

library LibMemory {
    /// Returns true if the free memory pointer is pointing at a multiple of 32
    /// bytes, false otherwise. If all memory allocations are handled by Solidity
    /// then this will always be true, but assembly blocks can violate this, so
    /// this is a useful tool to test compliance of a custom assembly block with
    /// the solidity allocator.
    /// @return isAligned true if the memory is currently aligned to 32 bytes.
    function memoryIsAligned() internal pure returns (bool isAligned) {
        assembly ("memory-safe") {
            isAligned := iszero(mod(mload(0x40), 0x20))
        }
    }
}


// Chain: POLYGON - File: lib/sol.lib.memory/src/LibMemCpy.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "./LibPointer.sol";

library LibMemCpy {
    /// Copy an arbitrary number of bytes from one location in memory to another.
    /// As we can only read/write bytes in 32 byte chunks we first have to loop
    /// over 32 byte values to copy then handle any unaligned remaining data. The
    /// remaining data will be appropriately masked with the existing data in the
    /// final chunk so as to not write past the desired length. Note that the
    /// final unaligned write will be more gas intensive than the prior aligned
    /// writes. The writes are completely unsafe, the caller MUST ensure that
    /// sufficient memory is allocated and reading/writing the requested number
    /// of bytes from/to the requested locations WILL NOT corrupt memory in the
    /// opinion of solidity or other subsequent read/write operations.
    /// @param sourceCursor The starting pointer to read from.
    /// @param targetCursor The starting pointer to write to.
    /// @param length The number of bytes to read/write.
    function unsafeCopyBytesTo(Pointer sourceCursor, Pointer targetCursor, uint256 length) internal pure {
        assembly ("memory-safe") {
            // Precalculating the end here, rather than tracking the remaining
            // length each iteration uses relatively more gas for less data, but
            // scales better for more data. Copying 1-2 words is ~30 gas more
            // expensive but copying 3+ words favours a precalculated end point
            // increasingly for more data.
            let m := mod(length, 0x20)
            let end := add(sourceCursor, sub(length, m))
            for {} lt(sourceCursor, end) {
                sourceCursor := add(sourceCursor, 0x20)
                targetCursor := add(targetCursor, 0x20)
            } { mstore(targetCursor, mload(sourceCursor)) }

            if iszero(iszero(m)) {
                //slither-disable-next-line incorrect-shift
                let mask_ := shr(mul(m, 8), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                // preserve existing bytes
                mstore(
                    targetCursor,
                    or(
                        // input
                        and(mload(sourceCursor), not(mask_)),
                        and(mload(targetCursor), mask_)
                    )
                )
            }
        }
    }

    /// Copies `length` `uint256` values starting from `source` to `target`
    /// with NO attempt to check that this is safe to do so. The caller MUST
    /// ensure that there exists allocated memory at `target` in which it is
    /// safe and appropriate to copy `length * 32` bytes to. Anything that was
    /// already written to memory at `[target:target+(length * 32 bytes)]`
    /// will be overwritten.
    /// There is no return value as memory is modified directly.
    /// @param source The starting position in memory that data will be copied
    /// from.
    /// @param target The starting position in memory that data will be copied
    /// to.
    /// @param length The number of 32 byte (i.e. `uint256`) words that will
    /// be copied.
    function unsafeCopyWordsTo(Pointer source, Pointer target, uint256 length) internal pure {
        assembly ("memory-safe") {
            for { let end_ := add(source, mul(0x20, length)) } lt(source, end_) {
                source := add(source, 0x20)
                target := add(target, 0x20)
            } { mstore(target, mload(source)) }
        }
    }
}


// Chain: POLYGON - File: lib/sol.lib.memory/src/LibStackSentinel.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "./LibPointer.sol";

/// Thrown when the sentinel cannot be found. This can be because the sentinel
/// was not in stack, but also if the upper pointer is below the lower, or the
/// sentinel is in the stack but not aligned with the tuples size.
/// @param sentinel The sentinel that was not found.
error MissingSentinel(Sentinel sentinel);

/// > In computer programming, a sentinel value (also referred to as a flag
/// > value, trip value, rogue value, signal value, or dummy data)[1] is a
/// > special value in the context of an algorithm which uses its presence as a
/// > condition of termination, typically in a loop or recursive algorithm.
/// >
/// > The sentinel value is a form of in-band data that makes it possible to
/// > detect the end of the data when no out-of-band data (such as an explicit
/// > size indication) is provided. The value should be selected in such a way
/// > that it is guaranteed to be distinct from all legal data values since
/// > otherwise, the presence of such values would prematurely signal the end of
/// > the data (the semipredicate problem).
/// >
/// > - [Wikipedia](https://en.wikipedia.org/wiki/Sentinel_value)
type Sentinel is uint256;

/// Rainlang has no dynamic list data type as every stack item MUST be explicit
/// in the structure of the code itself. While it would be possible for users to
/// manually code length prefixes into the stack, this would be error prone and
/// generally hostile to the overall DX. Instead we can allow sentinels as an
/// option that is merely awkward rather than downright pathological.
///
/// Rainlang authors can use a single sentinel value that is constant across all
/// their expressions rather than a calculated length prefix. This value can even
/// be aliased in onchain metadata and referenced by name for ease of use. The
/// calling contract defines and consumes sentinels, so the expression author
/// does not need to be aware of or have control over any subtleties in choice of
/// sentinel.
///
/// The main tradeoffs for sentinel terminated lists on a stack are similar to
/// null-terminated strings,
/// as per [Wikipedia](https://en.wikipedia.org/wiki/Null-terminated_string)
///
/// > While simple to implement, this representation has been prone to errors and
/// > performance problems.
///
/// This library attempts to mitigate potential implementation errors with a
/// standard implementation that has been fuzzed and optimized for building lists
/// of tuples (and therefore lists of structs via. a direct type cast). The main
/// implementation issues in null-terminated strings are avoided:
///
/// - Using any sentinel value other than `0`, such as the hash of some well
///   known string, will avoid misinterpreting unallocated memory as a sentinel.
/// - Any underflows manifest as either a "missing sentinel" or infinite loop,
///   which will revert either way due to an explicit check or gas limits.
/// - Given that a sentinel is `uint256` it is possible to construct a value that
///   is very unlikely to collide with real values in the implementation domain.
/// - Well behaved integrity checks will ensure the memory for the sentinel is
///   allocated as any other stack item.
///
/// Sadly there is no way to avoid the O(n) performance overhead of searching for
/// a sentinel vs. O(1) of reading a length prefix directly. This is somewhat
/// mitigated by the nature of a hand-written stack being small in
/// computing terms, and that each item being iterated over is an entire struct
/// rather than individual stack values. Assembly is used to keep the looping
/// overhead to a minimum.
library LibStackSentinel {
    using LibStackSentinel for Pointer;

    /// Given two stack pointers that bound a stack build an array of `n` item
    /// tuples above the given sentinel value. The sentinel will be skipped and
    /// a pointer below it returned alongside the tuples list.
    ///
    /// The tuples can be cast (via assembly) to structs.
    ///
    /// The caller MUST consider the region of memory consumed for the structs as
    /// mutated/truncated/deallocated and reallocated insitu to the tuples.
    ///
    /// The sentinel MUST be chosen to have a negligible chance of colliding with
    /// a real value in the array, otherwise an intended array item will be
    /// interpreted as a sentinel.
    ///
    /// If the sentinel is absent in the stack this WILL REVERT. The intent is
    /// to represent dynamic length arrays without forcing expression authors to
    /// calculate lengths on the stack. If the expression author wants to model
    /// an empty/optional/absent value they MAY provided a sentinel for a zero
    /// length array and the calling contract SHOULD handle this.
    ///
    /// If `lower` is smaller than `n` it is possible that this will underflow
    /// which will result in the evm immediately running out of gas as it
    /// attempts to loop from infinity. There is no explicit underflow check but
    /// there is no way to underflow without reverting due to gas.
    ///
    /// @param upper Pointer to the top of the stack range.
    /// @param lower Pointer to the bottom of the stack range.
    /// @param sentinel The value to expect as the sentinel. MUST be present in
    /// the stack or `consumeSentinel` will revert. MUST NOT collide with valid
    /// stack items (or be cryptographically improbable to do so).
    /// @param n The number of items per tuple.
    /// @return sentinelPointer Pointer to the sentinel that was found. A missing
    /// sentinel WILL REVERT.
    /// @return tuplesPointer Pointer to the n-item tuples array that was built.
    function consumeSentinelTuples(Pointer lower, Pointer upper, Sentinel sentinel, uint256 n)
        internal
        pure
        returns (Pointer sentinelPointer, Pointer tuplesPointer)
    {
        // Each tuple takes this much space in memory.
        uint256 size;

        // First pass to find the sentinel.
        assembly ("memory-safe") {
            size := mul(n, 0x20)
            // An underflow here always results in a revert due to gas.
            for { let cursor := upper } gt(cursor, lower) { cursor := sub(cursor, size) } {
                let potentialSentinelPointer := sub(cursor, 0x20)
                if eq(mload(potentialSentinelPointer), sentinel) {
                    sentinelPointer := potentialSentinelPointer
                    break
                }
            }
        }

        // We revert if the sentinel was not found.
        if (Pointer.unwrap(sentinelPointer) == 0) {
            revert MissingSentinel(sentinel);
        }

        // Second pass to build references _in order_ from the sentinel back up
        // to upper.
        assembly ("memory-safe") {
            tuplesPointer := mload(0x40)
            let tuplesCursor := add(tuplesPointer, 0x20)
            for { let cursor := add(sentinelPointer, 0x20) } lt(cursor, upper) {
                tuplesCursor := add(tuplesCursor, 0x20)
                cursor := add(cursor, size)
            } {
                // Write the reference to the tuple.
                mstore(tuplesCursor, cursor)
            }
            // Update allocated memory pointer past the tuples.
            mstore(0x40, tuplesCursor)
            // Store tuples length.
            mstore(tuplesPointer, sub(div(sub(tuplesCursor, tuplesPointer), 0x20), 1))
        }
    }
}


// Chain: POLYGON - File: lib/rain.interpreter/src/interface/IInterpreterStoreV1.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "./IInterpreterV1.sol";

/// A fully qualified namespace includes the interpreter's own namespacing logic
/// IN ADDITION to the calling contract's requested `StateNamespace`. Typically
/// this involves hashing the `msg.sender` into the `StateNamespace` so that each
/// caller operates within its own disjoint state universe. Intepreters MUST NOT
/// allow either the caller nor any expression/word to modify this directly on
/// pain of potential key collisions on writes to the interpreter's own storage.
type FullyQualifiedNamespace is uint256;

IInterpreterStoreV1 constant NO_STORE = IInterpreterStoreV1(address(0));

/// @title IInterpreterStoreV1
/// @notice Tracks state changes on behalf of an interpreter. A single store can
/// handle state changes for many calling contracts, many interpreters and many
/// expressions. The store is responsible for ensuring that applying these state
/// changes is safe from key collisions with calls to `set` from different
/// `msg.sender` callers. I.e. it MUST NOT be possible for a caller to modify the
/// state changes associated with some other caller.
///
/// The store defines the shape of its own state changes, which is opaque to the
/// calling contract. For example, some store may treat the list of state changes
/// as a pairwise key/value set, and some other store may treat it as a literal
/// list to be stored as-is.
///
/// Each interpreter decides for itself which store to use based on the
/// compatibility of its own opcodes.
///
/// The store MUST assume the state changes have been corrupted by the calling
/// contract due to bugs or malicious intent, and enforce state isolation between
/// callers despite arbitrarily invalid state changes. The store MUST revert if
/// it can detect invalid state changes, such as a key/value list having an odd
/// number of items, but this MAY NOT be possible if the corruption is
/// undetectable.
interface IInterpreterStoreV1 {
    /// Mutates the interpreter store in bulk. The bulk values are provided in
    /// the form of a `uint256[]` which can be treated e.g. as pairwise keys and
    /// values to be stored in a Solidity mapping. The `IInterpreterStoreV1`
    /// defines the meaning of the `uint256[]` for its own storage logic.
    ///
    /// @param namespace The unqualified namespace for the set that MUST be
    /// fully qualified by the `IInterpreterStoreV1` to prevent key collisions
    /// between callers. The fully qualified namespace forms a compound key with
    /// the keys for each value to set.
    /// @param kvs The list of changes to apply to the store's internal state.
    function set(StateNamespace namespace, uint256[] calldata kvs) external;

    /// Given a fully qualified namespace and key, return the associated value.
    /// Ostensibly the interpreter can use this to implement opcodes that read
    /// previously set values. The interpreter MUST apply the same qualification
    /// logic as the store that it uses to guarantee consistent round tripping of
    /// data and prevent malicious behaviours. Technically also allows onchain
    /// reads of any set value from any contract, not just interpreters, but in
    /// this case readers MUST be aware and handle inconsistencies between get
    /// and set while the state changes are still in memory in the calling
    /// context and haven't yet been persisted to the store.
    ///
    /// `IInterpreterStoreV1` uses the same fallback behaviour for unset keys as
    /// Solidity. Specifically, any UNSET VALUES SILENTLY FALLBACK TO `0`.
    /// @param namespace The fully qualified namespace to get a single value for.
    /// @param key The key to get the value for within the namespace.
    /// @return The value OR ZERO IF NOT SET.
    function get(FullyQualifiedNamespace namespace, uint256 key) external view returns (uint256);
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/draft-IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
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
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCastUpgradeable {
    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        require(value <= type(uint248).max, "SafeCast: value doesn't fit in 248 bits");
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        require(value <= type(uint240).max, "SafeCast: value doesn't fit in 240 bits");
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        require(value <= type(uint232).max, "SafeCast: value doesn't fit in 232 bits");
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.2._
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        require(value <= type(uint216).max, "SafeCast: value doesn't fit in 216 bits");
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        require(value <= type(uint208).max, "SafeCast: value doesn't fit in 208 bits");
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        require(value <= type(uint200).max, "SafeCast: value doesn't fit in 200 bits");
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        require(value <= type(uint192).max, "SafeCast: value doesn't fit in 192 bits");
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "SafeCast: value doesn't fit in 184 bits");
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        require(value <= type(uint176).max, "SafeCast: value doesn't fit in 176 bits");
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        require(value <= type(uint168).max, "SafeCast: value doesn't fit in 168 bits");
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "SafeCast: value doesn't fit in 160 bits");
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        require(value <= type(uint152).max, "SafeCast: value doesn't fit in 152 bits");
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        require(value <= type(uint144).max, "SafeCast: value doesn't fit in 144 bits");
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        require(value <= type(uint136).max, "SafeCast: value doesn't fit in 136 bits");
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v2.5._
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        require(value <= type(uint120).max, "SafeCast: value doesn't fit in 120 bits");
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        require(value <= type(uint112).max, "SafeCast: value doesn't fit in 112 bits");
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        require(value <= type(uint104).max, "SafeCast: value doesn't fit in 104 bits");
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.2._
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        require(value <= type(uint80).max, "SafeCast: value doesn't fit in 80 bits");
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        require(value <= type(uint72).max, "SafeCast: value doesn't fit in 72 bits");
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v2.5._
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        require(value <= type(uint56).max, "SafeCast: value doesn't fit in 56 bits");
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "SafeCast: value doesn't fit in 48 bits");
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value <= type(uint40).max, "SafeCast: value doesn't fit in 40 bits");
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v2.5._
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        require(value <= type(uint24).max, "SafeCast: value doesn't fit in 24 bits");
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v2.5._
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v2.5._
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     *
     * _Available since v3.0._
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 248 bits");
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 240 bits");
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 232 bits");
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.7._
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 224 bits");
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 216 bits");
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 208 bits");
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 200 bits");
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 192 bits");
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 184 bits");
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 176 bits");
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 168 bits");
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 160 bits");
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 152 bits");
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 144 bits");
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 136 bits");
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 128 bits");
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 120 bits");
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 112 bits");
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 104 bits");
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.7._
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 96 bits");
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 88 bits");
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 80 bits");
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 72 bits");
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 64 bits");
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 56 bits");
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 48 bits");
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 40 bits");
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 32 bits");
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 24 bits");
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 16 bits");
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 8 bits");
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     *
     * _Available since v3.0._
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}


// Chain: POLYGON - File: lib/rain.interpreter/src/interface/IExpressionDeployerV1.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "./IInterpreterV1.sol";

/// @title IExpressionDeployerV1
/// @notice Companion to `IInterpreterV1` responsible for onchain static code
/// analysis and deploying expressions. Each `IExpressionDeployerV1` is tightly
/// coupled at the bytecode level to some interpreter that it knows how to
/// analyse and deploy expressions for. The expression deployer can perform an
/// integrity check "dry run" of candidate source code for the intepreter. The
/// critical analysis/transformation includes:
///
/// - Enforcement of no out of bounds memory reads/writes
/// - Calculation of memory required to eval the stack with a single allocation
/// - Replacing index based opcodes with absolute interpreter function pointers
/// - Enforcement that all opcodes and operands used exist and are valid
///
/// This analysis is highly sensitive to the specific implementation and position
/// of all opcodes and function pointers as compiled into the interpreter. This
/// is what makes the coupling between an interpreter and expression deployer
/// so tight. Ideally all responsibilities would be handled by a single contract
/// but this introduces code size issues quickly by roughly doubling the compiled
/// logic of each opcode (half for the integrity check and half for evaluation).
///
/// Interpreters MUST assume that expression deployers are malicious and fail
/// gracefully if the integrity check is corrupt/bypassed and/or function
/// pointers are incorrect, etc. i.e. the interpreter MUST always return a stack
/// from `eval` in a read only way or error. I.e. it is the expression deployer's
/// responsibility to do everything it can to prevent undefined behaviour in the
/// interpreter, and the interpreter's responsibility to handle the expression
/// deployer completely failing to do so.
interface IExpressionDeployerV1 {
    /// This is the literal InterpreterOpMeta bytes to be used offchain to make
    /// sense of the opcodes in this interpreter deployment, as a human. For
    /// formats like json that make heavy use of boilerplate, repetition and
    /// whitespace, some kind of compression is recommended.
    /// @param sender The `msg.sender` providing the op meta.
    /// @param opMeta The raw binary data of the op meta. Maybe compressed data
    /// etc. and is intended for offchain consumption.
    event DISpair(address sender, address deployer, address interpreter, address store, bytes opMeta);

    /// Expressions are expected to be deployed onchain as immutable contract
    /// code with a first class address like any other contract or account.
    /// Technically this is optional in the sense that all the tools required to
    /// eval some expression and define all its opcodes are available as
    /// libraries.
    ///
    /// In practise there are enough advantages to deploying the sources directly
    /// onchain as contract data and loading them from the interpreter at eval:
    ///
    /// - Loading and storing binary data is gas efficient as immutable contract
    ///   data
    /// - Expressions need to be immutable between their deploy time integrity
    ///   check and runtime evaluation
    /// - Passing the address of an expression through calldata to an interpreter
    ///   is cheaper than passing an entire expression through calldata
    /// - Conceptually a very simple approach, even if implementations like
    ///   SSTORE2 are subtle under the hood
    ///
    /// The expression deployer MUST perform an integrity check of the source
    /// code before it puts the expression onchain at a known address. The
    /// integrity check MUST at a minimum (it is free to do additional static
    /// analysis) calculate the memory required to be allocated for the stack in
    /// total, and that no out of bounds memory reads/writes occur within this
    /// stack. A simple example of an invalid source would be one that pushes one
    /// value to the stack then attempts to pops two values, clearly we cannot
    /// remove more values than we added. The `IExpressionDeployerV1` MUST revert
    /// in the case of any integrity failure, all integrity checks MUST pass in
    /// order for the deployment to complete.
    ///
    /// Once the integrity check is complete the `IExpressionDeployerV1` MUST do
    /// any additional processing required by its paired interpreter.
    /// For example, the `IExpressionDeployerV1` MAY NEED to replace the indexed
    /// opcodes in the `ExpressionConfig` sources with real function pointers
    /// from the corresponding interpreter.
    ///
    /// @param sources Sources verbatim. These sources MUST be provided in their
    /// sequential/index opcode form as the deployment process will need to index
    /// into BOTH the integrity check and the final runtime function pointers.
    /// This will be emitted in an event for offchain processing to use the
    /// indexed opcode sources. The first N sources are considered entrypoints
    /// and will be integrity checked by the expression deployer against a
    /// starting stack height of 0. Non-entrypoint sources MAY be provided for
    /// internal use such as the `call` opcode but will NOT be integrity checked
    /// UNLESS entered by an opcode in an entrypoint.
    /// @param constants Constants verbatim. Constants are provided alongside
    /// sources rather than inline as it allows us to avoid variable length
    /// opcodes and can be more memory efficient if the same constant is
    /// referenced several times from the sources.
    /// @param minOutputs The first N sources on the state config are entrypoints
    /// to the expression where N is the length of the `minOutputs` array. Each
    /// item in the `minOutputs` array specifies the number of outputs that MUST
    /// be present on the final stack for an evaluation of each entrypoint. The
    /// minimum output for some entrypoint MAY be zero if the expectation is that
    /// the expression only applies checks and error logic. Non-entrypoint
    /// sources MUST NOT have a minimum outputs length specified.
    /// @return interpreter The interpreter the deployer believes it is qualified
    /// to perform integrity checks on behalf of.
    /// @return store The interpreter store the deployer believes is compatible
    /// with the interpreter.
    /// @return expression The address of the deployed onchain expression. MUST
    /// be valid according to all integrity checks the deployer is aware of.
    function deployExpression(bytes[] memory sources, uint256[] memory constants, uint256[] memory minOutputs)
        external
        returns (IInterpreterV1 interpreter, IInterpreterStoreV1 store, address expression);
}


// Chain: POLYGON - File: lib/rain.interpreter/src/lib/caller/LibContext.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "sol.lib.memory/LibUint256Array.sol";
import "rain.lib.hash/LibHashNoAlloc.sol";

import {SignatureChecker} from "openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import "../../interface/IInterpreterCallerV2.sol";

/// Thrown when the ith signature from a list of signed contexts is invalid.
error InvalidSignature(uint256 i);

/// @title LibContext
/// @notice Conventions for working with context as a calling contract. All of
/// this functionality is OPTIONAL but probably useful for the majority of use
/// cases. By building and authenticating onchain, caller provided and signed
/// contexts all in a standard way the overall usability of context is greatly
/// improved for expression authors and readers. Any calling contract that can
/// match the context expectations of an existing expression is one large step
/// closer to compatibility and portability, inheriting network effects of what
/// has already been authored elsewhere.
library LibContext {
    using LibUint256Array for uint256[];

    /// The base context is the `msg.sender` and address of the calling contract.
    /// As the interpreter itself is called via an external interface and may be
    /// statically calling itself, it MAY NOT have any ability to inspect either
    /// of these values. Even if this were not the case the calling contract
    /// cannot assume the existence of some opcode(s) in the interpreter that
    /// inspect the caller, so providing these two values as context is
    /// sufficient to decouple the calling contract from the interpreter. It is
    /// STRONGLY RECOMMENDED that even if the calling contract has "no context"
    /// that it still provides this base to every `eval`.
    ///
    /// Calling contracts DO NOT need to call this directly. It is built and
    /// merged automatically into the standard context built by `build`.
    ///
    /// @return The `msg.sender` and address of the calling contract using this
    /// library, as a context-compatible array.
    function base() internal view returns (uint256[] memory) {
        return LibUint256Array.arrayFrom(uint256(uint160(msg.sender)), uint256(uint160(address(this))));
    }

    /// Standard hashing process over a single `SignedContextV1`. Notably used
    /// to hash a list as `SignedContextV1[]` but could also be used to hash a
    /// single `SignedContextV1` in isolation. Avoids allocating memory by
    /// hashing each struct field in sequence within the memory scratch space.
    /// @param signedContext The signed context to hash.
    /// @param hashed The hashed signed context.
    function hash(SignedContextV1 memory signedContext) internal pure returns (bytes32 hashed) {
        uint256 signerOffset = SIGNED_CONTEXT_SIGNER_OFFSET;
        uint256 contextOffset = SIGNED_CONTEXT_CONTEXT_OFFSET;
        uint256 signatureOffset = SIGNED_CONTEXT_SIGNATURE_OFFSET;

        assembly ("memory-safe") {
            mstore(0, keccak256(add(signedContext, signerOffset), 0x20))

            let context_ := mload(add(signedContext, contextOffset))
            mstore(0x20, keccak256(add(context_, 0x20), mul(mload(context_), 0x20)))

            mstore(0, keccak256(0, 0x40))

            let signature_ := mload(add(signedContext, signatureOffset))
            mstore(0x20, keccak256(add(signature_, 0x20), mload(signature_)))

            hashed := keccak256(0, 0x40)
        }
    }

    /// Standard hashing process over a list of signed contexts. Situationally
    /// useful if the calling contract wants to record that it has seen a set of
    /// signed data then later compare it against some input (e.g. to ensure that
    /// many calls of some function all share the same input values). Note that
    /// unlike the internals of `build`, this hashes over the signer and the
    /// signature, to ensure that some data cannot be re-signed and used under
    /// a different provenance later.
    /// @param signedContexts The list of signed contexts to hash over.
    /// @return hashed The hash of the signed contexts.
    function hash(SignedContextV1[] memory signedContexts) internal pure returns (bytes32 hashed) {
        uint256 cursor;
        uint256 end;
        bytes32 hashNil = HASH_NIL;
        assembly ("memory-safe") {
            cursor := add(signedContexts, 0x20)
            end := add(cursor, mul(mload(signedContexts), 0x20))
            mstore(0, hashNil)
        }

        SignedContextV1 memory signedContext;
        bytes32 mem0;
        while (cursor < end) {
            assembly ("memory-safe") {
                signedContext := mload(cursor)
                // Subhash will write to 0 for its own hashing so keep a copy
                // before it gets overwritten.
                mem0 := mload(0)
            }
            bytes32 subHash = hash(signedContext);
            assembly ("memory-safe") {
                mstore(0, mem0)
                mstore(0x20, subHash)
                mstore(0, keccak256(0, 0x40))
                cursor := add(cursor, 0x20)
            }
        }
        assembly ("memory-safe") {
            hashed := mload(0)
        }
    }

    /// Builds a standard 2-dimensional context array from base, calling and
    /// signed contexts. Note that "columns" of a context array refer to each
    /// `uint256[]` and each item within a `uint256[]` is a "row".
    ///
    /// @param baseContext Anything the calling contract can provide which MAY
    /// include input from the `msg.sender` of the calling contract. The default
    /// base context from `LibContext.base()` DOES NOT need to be provided by the
    /// caller, this matrix MAY be empty and will be simply merged into the final
    /// context. The base context matrix MUST contain a consistent number of
    /// columns from the calling contract so that the expression can always
    /// predict how many unsigned columns there will be when it runs.
    /// @param signedContexts Signed contexts are provided by the `msg.sender`
    /// but signed by a third party. The expression (author) defines _who_ may
    /// sign and the calling contract authenticates the signature over the
    /// signed data. Technically `build` handles all the authentication inline
    /// for the calling contract so if some context builds it can be treated as
    /// authentic. The builder WILL REVERT if any of the signatures are invalid.
    /// Note two things about the structure of the final built context re: signed
    /// contexts:
    /// - The first column is a list of the signers in order of what they signed
    /// - The `msg.sender` can provide an arbitrary number of signed contexts so
    ///   expressions DO NOT know exactly how many columns there are.
    /// The expression is responsible for defining e.g. a domain separator in a
    /// position that would force signed context to be provided in the "correct"
    /// order, rather than relying on the `msg.sender` to honestly present data
    /// in any particular structure/order.
    function build(uint256[][] memory baseContext, SignedContextV1[] memory signedContexts)
        internal
        view
        returns (uint256[][] memory)
    {
        unchecked {
            uint256[] memory signers = new uint256[](signedContexts.length);

            // - LibContext.base() + whatever we are provided.
            // - signed contexts + signers if they exist else nothing.
            uint256 contextLength = 1 + baseContext.length + (signedContexts.length > 0 ? signedContexts.length + 1 : 0);

            uint256[][] memory context = new uint256[][](contextLength);
            uint256 offset = 0;
            context[offset] = LibContext.base();

            for (uint256 i = 0; i < baseContext.length; i++) {
                offset++;
                context[offset] = baseContext[i];
            }

            if (signedContexts.length > 0) {
                offset++;
                context[offset] = signers;

                for (uint256 i = 0; i < signedContexts.length; i++) {
                    if (
                        // Unlike `LibContext.hash` we can only hash over
                        // the context as it's impossible for a signature
                        // to sign itself.
                        // Note the use of encodePacked here over a
                        // single array, not including the length. This
                        // would be a security issue if multiple dynamic
                        // length values were hashed over together as
                        // then many possible inputs could collide with
                        // a single encoded output.
                        !SignatureChecker.isValidSignatureNow(
                            signedContexts[i].signer,
                            ECDSA.toEthSignedMessageHash(LibHashNoAlloc.hashWords(signedContexts[i].context)),
                            signedContexts[i].signature
                        )
                    ) {
                        revert InvalidSignature(i);
                    }

                    signers[i] = uint256(uint160(signedContexts[i].signer));
                    offset++;
                    context[offset] = signedContexts[i].context;
                }
            }

            return context;
        }
    }
}


// Chain: POLYGON - File: lib/rain.interpreter/src/lib/state/LibInterpreterState.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "sol.lib.memory/LibPointer.sol";
import "rain.lib.memkv/LibMemoryKV.sol";

import "../../interface/IInterpreterV1.sol";

/// The standard in-memory representation of an interpreter that facilitates
/// decoupled coordination between opcodes. Opcodes MAY:
///
/// - push and pop values to the shared stack
/// - read per-expression constants
/// - write to the final state changes set within the fully qualified namespace
/// - read per-eval context values
/// - recursively evaluate any compiled source associated with the expression
///
/// As the interpreter defines the opcodes it is its responsibility to ensure the
/// opcodes are incapable of doing anything to undermine security or correctness.
/// For example, a hypothetical opcode could modify the current namespace from
/// the stack, but this would be a very bad idea as it would allow expressions
/// to hijack storage values associated with other callers, fundamentally
/// breaking the state sandbox model.
///
/// The iterpreter MAY skip any runtime integrity checks that can be reasonably
/// assumed to have been performed by a competent expression deployer, such as
/// guarding against stack underflow. A competent expression deployer MAY NOT
/// have deployed the currently evaluating expression, so the interpreter MUST
/// avoid state changes during evaluation, but MAY return garbage data if the
/// calling contract fails to leverage an appropriate expression deployer.
///
/// @param stackBottom Opcodes write to the stack starting at the stack bottom,
/// ideally using `LibStackPointer` to normalise push and pop behaviours. A
/// competent expression deployer will calculate a memory preallocation that
/// pushes and pops above the stack bottom effectively allocate and deallocate
/// memory within.
/// @param constantsBottom Opcodes read constants starting at the pointer to
/// the bottom of the constants array. As the name implies the interpreter MUST
/// NOT write to the constants, it is read only.
/// @param stateKV The in memory key/value store that tracks reads/writes over
/// the underlying interpreter storage for the duration of a single expression
/// evaluation.
/// @param namespace The fully qualified namespace that all state reads and
/// writes MUST be performed under.
/// @param store The store to reference ostensibly for gets but perhaps other
/// things.
/// @param context A 2-dimensional array of per-eval data provided by the calling
/// contract. Opaque to the interpreter but presumably meaningful to the
/// expression.
/// @param compiledSources A list of sources that can be directly evaluated by
/// the interpreter, either as a top level entrypoint or nested e.g. under a
/// dispatch by `call`.
struct InterpreterState {
    Pointer stackBottom;
    Pointer constantsBottom;
    MemoryKV stateKV;
    FullyQualifiedNamespace namespace;
    IInterpreterStoreV1 store;
    uint256[][] context;
    bytes[] compiledSources;
}


// Chain: POLYGON - File: lib/rain.interpreter/src/abstract/DeployerDiscoverableMetaV1.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.metadata/IMetaV1.sol";
import "rain.metadata/LibMeta.sol";
import "../lib/caller/LibDeployerDiscoverable.sol";

/// Construction config for `DeployerDiscoverableMetaV1`.
/// @param deployer Deployer the calling contract will be discoverable under.
/// @param meta MetaV1 data to emit before touching the deployer.
struct DeployerDiscoverableMetaV1ConstructionConfig {
    address deployer;
    bytes meta;
}

/// @title DeployerDiscoverableMetaV1
/// @notice Upon construction, checks metadata against a known hash, emits it
/// then touches the deployer (deploy an empty expression). This allows indexers
/// to discover the metadata of the `DeployerDiscoverableMetaV1` contract by
/// indexing the deployer. In this way the deployer acts as a pseudo-registry by
/// virtue of it being a natural hub for interactions with calling contracts.
abstract contract DeployerDiscoverableMetaV1 is IMetaV1 {
    constructor(bytes32 metaHash, DeployerDiscoverableMetaV1ConstructionConfig memory config) {
        LibMeta.checkMetaHashed(metaHash, config.meta);
        emit MetaV1(msg.sender, uint256(uint160(address(this))), config.meta);
        LibDeployerDiscoverable.touchDeployer(config.deployer);
    }
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Multicall.sol)

pragma solidity ^0.8.0;

import "./AddressUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Provides a function to batch together multiple calls in a single external call.
 *
 * _Available since v4.1._
 */
abstract contract MulticallUpgradeable is Initializable {
    function __Multicall_init() internal onlyInitializing {
    }

    function __Multicall_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Receives and executes a batch of function calls on this contract.
     */
    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = _functionDelegateCall(address(this), data[i]);
        }
        return results;
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.0;

import "../IERC721ReceiverUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721HolderUpgradeable is Initializable, IERC721ReceiverUpgradeable {
    function __ERC721Holder_init() internal onlyInitializing {
    }

    function __ERC721Holder_init_unchained() internal onlyInitializing {
    }
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/utils/ERC1155Holder.sol)

pragma solidity ^0.8.0;

import "./ERC1155ReceiverUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * Simple implementation of `ERC1155Receiver` that will allow a contract to hold ERC1155 tokens.
 *
 * IMPORTANT: When inheriting this contract, you must include a way to use the received tokens, otherwise they will be
 * stuck.
 *
 * @dev _Available since v3.1._
 */
contract ERC1155HolderUpgradeable is Initializable, ERC1155ReceiverUpgradeable {
    function __ERC1155Holder_init() internal onlyInitializing {
    }

    function __ERC1155Holder_init_unchained() internal onlyInitializing {
    }
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol
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


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


// Chain: POLYGON - File: lib/rain.interface.interpreter/lib/rain.lib.hash/src/LibHashNoAlloc.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

bytes32 constant HASH_NIL = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

/// @title LibHashNoAlloc
/// @notice When producing hashes of just about anything that isn't already bytes
/// the common suggestions look something like `keccak256(abi.encode(...))` or
/// `keccak256(abi.encodePacked(...))` with the main differentiation being
/// whether dynamic data types are being hashed. If they are then there is a hash
/// collision risk in the packed case as `"abc" + "def"` and `"ab" + "cdef"` will
/// pack and therefore hash to the same values, the suggested fix commonly being
/// to use abi.encode, which includes the lengths disambiguating dynamic data.
/// Something like `3"abc" + 3"def"` with the length prefixes won't collide with
/// `2"ab" + 4"cdef"` but note that ABI provides neither a strong guarantee to
/// be collision resitant on inputs (as far as I know, it's a coincidence that
/// this works), nor an efficient solution.
///
/// - Abi encoding is a complex algorithm that is easily 1k+ gas for simple
///   structs with just one or two dynamic typed fields.
/// - Abi encoding requires allocating and copying all the data plus a header to
///   a new region of memory, which gives it non-linearly increasing costs due to
///   memory expansion.
/// - Abi encoding can't easily be reproduced offchain without specialised tools,
///   it's not simply a matter of length prefixing some byte string and hashing
///   with keccak256, the heads and tails all need to be produced recursively
///   https://docs.soliditylang.org/en/develop/abi-spec.html#formal-specification-of-the-encoding
///
/// Consider that `hash(hash("abc") + hash("def"))` won't collide with
/// `hash(hash("ab") + hash("cdef"))`. It should be easier to convince ourselves
/// this is true for all possible pairs of byte strings than it is to convince
/// ourselves that the ABI serialization is never ambigious. Inductively we can
/// scale this to all possible data structures that are ordered compositions of
/// byte strings. Even better, the native behaviour of `keccak256` in the EVM
/// requires no additional allocation of memory. Worst case scenario is that we
/// want to hash several hashes together like `hash(hash0, hash1, ...)`, in which
/// case we can write the words after the free memory pointer, hash them, but
/// leave the pointer. This way we pay for memory expansion but can re-use that
/// region of memory for subsequent logic, which may effectively make the
/// expansion free as we would have needed to pay for it anyway. Given that hash
/// checks often occur early in real world logic due to
/// checks-effects-interactions, this is not an unreasonable assumption to call
/// this kind of expansion "no alloc".
///
/// One problem is that the gas saving for trivial abi encoding,
/// e.g. ~1-3 uint256 values, can be lost by the overhead of jumps and stack
/// manipulation due to function calls.
///
/// ```
/// struct Foo {
///   uint256 a;
///   address b;
///   uint32 c;
/// }
/// ```
/// The simplest way to hash `Foo` is to just hash it (crazy, i know!).
///
/// ```
/// assembly ("memory-safe") {
///   hash_ := keccak256(foo_, 0x60)
/// }
/// ```
/// Every struct field is 0x20 bytes in memory so 3 fields = 0x60 bytes to hash
/// always, with the exception of dynamic types. This costs about 70 gas vs.
/// about 350 gas for an abi encoding based approach.
library LibHashNoAlloc {
    function hashBytes(bytes memory data_) internal pure returns (bytes32 hash_) {
        assembly ("memory-safe") {
            hash_ := keccak256(add(data_, 0x20), mload(data_))
        }
    }

    function hashWords(bytes32[] memory words_) internal pure returns (bytes32 hash_) {
        assembly ("memory-safe") {
            hash_ := keccak256(add(words_, 0x20), mul(mload(words_), 0x20))
        }
    }

    function hashWords(uint256[] memory words_) internal pure returns (bytes32 hash_) {
        assembly ("memory-safe") {
            hash_ := keccak256(add(words_, 0x20), mul(mload(words_), 0x20))
        }
    }

    function combineHashes(bytes32 a_, bytes32 b_) internal pure returns (bytes32 hash_) {
        assembly ("memory-safe") {
            mstore(0, a_)
            mstore(0x20, b_)
            hash_ := keccak256(0, 0x40)
        }
    }
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/SignatureChecker.sol)

pragma solidity ^0.8.0;

import "./ECDSA.sol";
import "../Address.sol";
import "../../interfaces/IERC1271.sol";

/**
 * @dev Signature verification helper that can be used instead of `ECDSA.recover` to seamlessly support both ECDSA
 * signatures from externally owned accounts (EOAs) as well as ERC1271 signatures from smart contract wallets like
 * Argent and Gnosis Safe.
 *
 * _Available since v4.1._
 */
library SignatureChecker {
    /**
     * @dev Checks if a signature is valid for a given signer and data hash. If the signer is a smart contract, the
     * signature is validated against that smart contract using ERC1271, otherwise it's validated using `ECDSA.recover`.
     *
     * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
     * change through time. It could return true at block N and false at block N+1 (or the opposite).
     */
    function isValidSignatureNow(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signature);
        if (error == ECDSA.RecoverError.NoError && recovered == signer) {
            return true;
        }

        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(IERC1271.isValidSignature.selector, hash, signature)
        );
        return (success &&
            result.length == 32 &&
            abi.decode(result, (bytes32)) == bytes32(IERC1271.isValidSignature.selector));
    }
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV // Deprecated in v4.8
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}


// Chain: POLYGON - File: lib/rain.lib.interpreter/lib/rain.lib.memkv/src/LibMemoryKV.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

/// Entrypoint into the key/value store. Is a mutable pointer to the head of the
/// linked list. Initially points to `0` for an empty list. The total word count
/// of all inserts is also encoded alongside the pointer to allow efficient O(1)
/// memory allocation for a `uint256[]` in the case of a final snapshot/export.
type MemoryKV is uint256;

/// The key associated with the value for each item in the store.
type MemoryKVKey is uint256;

/// The value associated with the key for each item in the store.
type MemoryKVVal is uint256;

/// @title LibMemoryKV
library LibMemoryKV {
    /// Gets the value associated with a given key.
    /// The value returned will be `0` if the key exists and was set to zero OR
    /// the key DOES NOT exist, i.e. was never set.
    ///
    /// The caller MUST check the `exists` flag to disambiguate between zero
    /// values and unset keys.
    ///
    /// @param kv The entrypoint to the key/value store.
    /// @param key The key to lookup a `value` for.
    /// @return exists `0` if the key was not found. The `value` MUST NOT be
    /// used if the `key` does not exist.
    /// @return value The value for the `key`, if it exists, else `0`. MAY BE `0`
    /// even if the `key` exists. It is possible to set any key to a `0` value.
    function get(MemoryKV kv, MemoryKVKey key) internal pure returns (uint256 exists, MemoryKVVal value) {
        assembly ("memory-safe") {
            // Hash to find the internal linked list to walk.
            // Hash logic MUST match set.
            mstore(0, key)
            let bitOffset := mul(mod(keccak256(0, 0x20), 15), 0x10)

            // Loop until k found or give up if pointer is zero.
            for { let pointer := and(shr(bitOffset, kv), 0xFFFF) } iszero(iszero(pointer)) {
                pointer := mload(add(pointer, 0x40))
            } {
                if eq(key, mload(pointer)) {
                    exists := 1
                    value := mload(add(pointer, 0x20))
                    break
                }
            }
        }
    }

    /// Upserts a value in the set by its key. I.e. if the key exists then the
    /// associated value will be mutated in place, else a new key/value pair will
    /// be inserted. The key/value store pointer will be mutated and returned as
    /// it MAY point to a new list item in memory.
    /// @param kv The key/value store pointer to modify.
    /// @param key The key to upsert against.
    /// @param value The value to associate with the upserted key.
    /// @return The final value of `kv` as it MAY be modified if the upsert
    /// resulted in an insert operation.
    function set(MemoryKV kv, MemoryKVKey key, MemoryKVVal value) internal pure returns (MemoryKV) {
        assembly ("memory-safe") {
            // Hash to spread inserts across internal lists.
            // This MUST remain in sync with `get` logic.
            mstore(0, key)
            let bitOffset := mul(mod(keccak256(0, 0x20), 15), 0x10)

            // Set aside the starting pointer as we'll need to include it in any
            // newly inserted linked list items.
            let startPointer := and(shr(bitOffset, kv), 0xFFFF)

            // Find a key match then break so that we populate a nonzero pointer.
            let pointer := startPointer
            for {} iszero(iszero(pointer)) { pointer := mload(add(pointer, 0x40)) } {
                if eq(key, mload(pointer)) { break }
            }

            // If the pointer is nonzero we have to update the associated value
            // directly, otherwise this is an insert operation.
            switch iszero(pointer)
            // Update.
            case 0 { mstore(add(pointer, 0x20), value) }
            // Insert.
            default {
                // Allocate 3 words of memory.
                pointer := mload(0x40)
                mstore(0x40, add(pointer, 0x60))

                // Write key/value/pointer.
                mstore(pointer, key)
                mstore(add(pointer, 0x20), value)
                mstore(add(pointer, 0x40), startPointer)

                // Update total stored word count.
                let length := add(shr(0xf0, kv), 2)

                //slither-disable-next-line incorrect-shift
                kv := or(shl(0xf0, length), and(kv, not(shl(0xf0, 0xFFFF))))

                // kv must point to new insertion.
                //slither-disable-next-line incorrect-shift
                kv :=
                    or(
                        shl(bitOffset, pointer),
                        // Mask out the old pointer
                        and(kv, not(shl(bitOffset, 0xFFFF)))
                    )
            }
        }
        return kv;
    }

    /// Export/snapshot the underlying linked list of the key/value store into
    /// a standard `uint256[]`. Reads the total length to preallocate the
    /// `uint256[]` then bisects the bits of the `kv` to find non-zero pointers
    /// to linked lists, walking each found list to the end to extract all
    /// values. As a single `kv` has 15 slots for pointers to linked lists it is
    /// likely for smallish structures that many slots can simply be skipped, so
    /// the bisect approach can save ~1-1.5k gas vs. a naive linear loop over
    /// all 15 slots for every export.
    ///
    /// Note this is a one time export, if the key/value store is subsequently
    /// mutated the built array will not reflect these mutations.
    ///
    /// @param kv The entrypoint into the key/value store.
    /// @return array All the keys and values copied pairwise into a `uint256[]`.
    /// Slither is not wrong about the cyclomatic complexity but I don't know
    /// another way to implement the bisect and keep the gas savings.
    //slither-disable-next-line cyclomatic-complexity
    function toUint256Array(MemoryKV kv) internal pure returns (uint256[] memory array) {
        uint256 mask16 = type(uint16).max;
        uint256 mask32 = type(uint32).max;
        uint256 mask64 = type(uint64).max;
        uint256 mask128 = type(uint128).max;
        assembly ("memory-safe") {
            // Manually create an `uint256[]`.
            // No need to zero out memory as we're about to write to it.
            array := mload(0x40)
            let length := shr(0xf0, kv)
            mstore(0x40, add(array, add(0x20, mul(length, 0x20))))
            mstore(array, length)

            // Known false positives in slither
            // https://github.com/crytic/slither/issues/1815
            //slither-disable-next-line naming-convention
            function copyFromPtr(cursor, pointer) -> end {
                for {} iszero(iszero(pointer)) {
                    pointer := mload(add(pointer, 0x40))
                    cursor := add(cursor, 0x40)
                } {
                    mstore(cursor, mload(pointer))
                    mstore(add(cursor, 0x20), mload(add(pointer, 0x20)))
                }
                end := cursor
            }

            // Bisect.
            // This crazy tree saves ~1-1.5k gas vs. a simple loop with larger
            // relative savings for small-medium sized structures.
            // The internal scoping blocks are to provide some safety against
            // typos causing the incorrect symbol to be referenced by enforcing
            // each symbol is as tightly scoped as it can be.
            let cursor := add(array, 0x20)
            {
                // Remove the length from kv before iffing to save ~100 gas.
                let p0 := shr(0x90, shl(0x10, kv))
                if iszero(iszero(p0)) {
                    {
                        let p00 := shr(0x40, p0)
                        if iszero(iszero(p00)) {
                            {
                                // This branch is a special case because we
                                // already zeroed out the high bits which are
                                // used by the length and are NOT a pointer.
                                // We can skip processing where the pointer would
                                // have been if it were not the length, and do
                                // not need to scrub the high bits to move from
                                // `p00` to `p0001`.
                                let p0001 := shr(0x20, p00)
                                if iszero(iszero(p0001)) { cursor := copyFromPtr(cursor, p0001) }
                            }
                            let p001 := and(mask32, p00)
                            if iszero(iszero(p001)) {
                                {
                                    let p0010 := shr(0x10, p001)
                                    if iszero(iszero(p0010)) { cursor := copyFromPtr(cursor, p0010) }
                                }
                                let p0011 := and(mask16, p001)
                                if iszero(iszero(p0011)) { cursor := copyFromPtr(cursor, p0011) }
                            }
                        }
                    }
                    let p01 := and(mask64, p0)
                    if iszero(iszero(p01)) {
                        {
                            let p010 := shr(0x20, p01)
                            if iszero(iszero(p010)) {
                                {
                                    let p0100 := shr(0x10, p010)
                                    if iszero(iszero(p0100)) { cursor := copyFromPtr(cursor, p0100) }
                                }
                                let p0101 := and(mask16, p010)
                                if iszero(iszero(p0101)) { cursor := copyFromPtr(cursor, p0101) }
                            }
                        }

                        let p011 := and(mask32, p01)
                        if iszero(iszero(p011)) {
                            {
                                let p0110 := shr(0x10, p011)
                                if iszero(iszero(p0110)) { cursor := copyFromPtr(cursor, p0110) }
                            }

                            let p0111 := and(mask16, p011)
                            if iszero(iszero(p0111)) { cursor := copyFromPtr(cursor, p0111) }
                        }
                    }
                }
            }

            {
                let p1 := and(mask128, kv)
                if iszero(iszero(p1)) {
                    {
                        let p10 := shr(0x40, p1)
                        if iszero(iszero(p10)) {
                            {
                                let p100 := shr(0x20, p10)
                                if iszero(iszero(p100)) {
                                    {
                                        let p1000 := shr(0x10, p100)
                                        if iszero(iszero(p1000)) { cursor := copyFromPtr(cursor, p1000) }
                                    }
                                    let p1001 := and(mask16, p100)
                                    if iszero(iszero(p1001)) { cursor := copyFromPtr(cursor, p1001) }
                                }
                            }
                            let p101 := and(mask32, p10)
                            if iszero(iszero(p101)) {
                                {
                                    let p1010 := shr(0x10, p101)
                                    if iszero(iszero(p1010)) { cursor := copyFromPtr(cursor, p1010) }
                                }
                                let p1011 := and(mask16, p101)
                                if iszero(iszero(p1011)) { cursor := copyFromPtr(cursor, p1011) }
                            }
                        }
                    }
                    let p11 := and(mask64, p1)
                    if iszero(iszero(p11)) {
                        {
                            let p110 := shr(0x20, p11)
                            if iszero(iszero(p110)) {
                                {
                                    let p1100 := shr(0x10, p110)
                                    if iszero(iszero(p1100)) { cursor := copyFromPtr(cursor, p1100) }
                                }
                                let p1101 := and(mask16, p110)
                                if iszero(iszero(p1101)) { cursor := copyFromPtr(cursor, p1101) }
                            }
                        }

                        let p111 := and(mask32, p11)
                        if iszero(iszero(p111)) {
                            {
                                let p1110 := shr(0x10, p111)
                                if iszero(iszero(p1110)) { cursor := copyFromPtr(cursor, p1110) }
                            }

                            let p1111 := and(mask16, p111)
                            if iszero(iszero(p1111)) { cursor := copyFromPtr(cursor, p1111) }
                        }
                    }
                }
            }
        }
    }
}


// Chain: POLYGON - File: lib/rain.metadata/src/IMetaV1.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

/// Thrown when hashed metadata does NOT match the expected hash.
/// @param expectedHash The hash expected by the `IMetaV1` contract.
/// @param actualHash The hash of the metadata seen by the `IMetaV1` contract.
error UnexpectedMetaHash(bytes32 expectedHash, bytes32 actualHash);

/// Thrown when some bytes are expected to be rain meta and are not.
/// @param unmeta the bytes that are not meta.
error NotRainMetaV1(bytes unmeta);

/// @dev Randomly generated magic number with first bytes oned out.
/// https://github.com/rainprotocol/specs/blob/main/metadata-v1.md
uint64 constant META_MAGIC_NUMBER_V1 = 0xff0a89c674ee7874;

/// @title IMetaV1
interface IMetaV1 {
    /// An onchain wrapper to carry arbitrary Rain metadata. Assigns the sender
    /// to the metadata so that tooling can easily drop/ignore data from unknown
    /// sources. As metadata is about something, the subject MUST be provided.
    /// @param sender The msg.sender.
    /// @param subject The entity that the metadata is about. MAY be the address
    /// of the emitting contract (as `uint256`) OR anything else. The
    /// interpretation of the subject is context specific, so will often be a
    /// hash of some data/thing that this metadata is about.
    /// @param meta Rain metadata V1 compliant metadata bytes.
    /// https://github.com/rainprotocol/specs/blob/main/metadata-v1.md
    event MetaV1(address sender, uint256 subject, bytes meta);
}


// Chain: POLYGON - File: lib/rain.metadata/src/LibMeta.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "./IMetaV1.sol";

/// @title LibMeta
/// @notice Need a place to put data that can be handled offchain like ABIs that
/// IS NOT etherscan.
library LibMeta {
    /// Returns true if the metadata bytes are prefixed by the Rain meta magic
    /// number. DOES NOT attempt to validate the body of the metadata as offchain
    /// tooling will be required for this.
    /// @param meta_ The data that may be rain metadata.
    /// @return True if `meta_` is metadata, false otherwise.
    function isRainMetaV1(bytes memory meta_) internal pure returns (bool) {
        if (meta_.length < 8) return false;
        uint256 mask_ = type(uint64).max;
        uint256 magicNumber_ = META_MAGIC_NUMBER_V1;
        assembly ("memory-safe") {
            magicNumber_ := and(mload(add(meta_, 8)), mask_)
        }
        return magicNumber_ == META_MAGIC_NUMBER_V1;
    }

    /// Reverts if the provided `meta_` is NOT metadata according to
    /// `isRainMetaV1`.
    /// @param meta_ The metadata bytes to check.
    function checkMetaUnhashed(bytes memory meta_) internal pure {
        if (!isRainMetaV1(meta_)) {
            revert NotRainMetaV1(meta_);
        }
    }

    /// Reverts if the provided `meta_` is NOT metadata according to
    /// `isRainMetaV1` OR it does not match the expected hash of its data.
    /// @param meta_ The metadata to check.
    function checkMetaHashed(bytes32 expectedHash_, bytes memory meta_) internal pure {
        bytes32 actualHash_ = keccak256(meta_);
        if (expectedHash_ != actualHash_) {
            revert UnexpectedMetaHash(expectedHash_, actualHash_);
        }
        checkMetaUnhashed(meta_);
    }
}


// Chain: POLYGON - File: lib/rain.interpreter/src/lib/caller/LibDeployerDiscoverable.sol
// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "../../interface/IExpressionDeployerV1.sol";

library LibDeployerDiscoverable {
    /// Hack so that some deployer will emit an event with the sender as the
    /// caller of `touchDeployer`. This MAY be needed by indexers such as
    /// subgraph that can only index events from the first moment they are aware
    /// of some contract. The deployer MUST be registered in ERC1820 registry
    /// before it is touched, THEN the caller meta MUST be emitted after the
    /// deployer is touched. This allows indexers such as subgraph to index the
    /// deployer, then see the caller, then see the caller's meta emitted in the
    /// same transaction.
    /// This is NOT required if ANY other expression is deployed in the same
    /// transaction as the caller meta, there only needs to be one expression on
    /// ANY deployer known to ERC1820.
    function touchDeployer(address deployer) internal {
        (IInterpreterV1 interpreter, IInterpreterStoreV1 store, address expression) =
            IExpressionDeployerV1(deployer).deployExpression(new bytes[](0), new uint256[](0), new uint256[](0));
        (interpreter);
        (store);
        (expression);
    }
}


// Chain: POLYGON - File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
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


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
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


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/interfaces/IERC1271.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC1271.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 *
 * _Available since v4.1._
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/utils/Strings.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/utils/math/Math.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}