// File: contracts/tokenvault/ERC1155Vault.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import "../libs/LibAddress.sol";
import "../common/LibStrings.sol";
import "./IBridgedERC1155.sol";
import "./BaseNFTVault.sol";

/// @title ERC1155Vault
/// @dev Labeled in AddressResolver as "erc1155_vault"
/// @notice This vault holds all ERC1155 tokens that users have deposited.
/// It also manages the mapping between canonical tokens and their bridged
/// tokens.
contract ERC1155Vault is BaseNFTVault, ERC1155ReceiverUpgradeable {
    using LibAddress for address;

    uint256[50] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
        __ERC1155Receiver_init();
    }
    /// @notice Transfers ERC1155 tokens to this vault and sends a message to
    /// the destination chain so the user can receive the same (bridged) tokens
    /// by invoking the message call.
    /// @param _op Option for sending the ERC1155 token.
    /// @return message_ The constructed message.

    function sendToken(BridgeTransferOp calldata _op)
        external
        payable
        whenNotPaused
        withValidOperation(_op)
        nonReentrant
        returns (IBridge.Message memory message_)
    {
        if (msg.value < _op.fee) revert VAULT_INSUFFICIENT_FEE();

        for (uint256 i; i < _op.amounts.length; ++i) {
            if (_op.amounts[i] == 0) revert VAULT_INVALID_AMOUNT();
        }
        // Check token interface support
        if (!_op.token.supportsInterface(type(IERC1155).interfaceId)) {
            revert VAULT_INTERFACE_NOT_SUPPORTED();
        }

        (bytes memory data, CanonicalNFT memory ctoken) = _handleMessage(_op);

        // Create a message to send to the destination chain
        IBridge.Message memory message = IBridge.Message({
            id: 0, // will receive a new value
            from: address(0), // will receive a new value
            srcChainId: 0, // will receive a new value
            destChainId: _op.destChainId,
            srcOwner: msg.sender,
            destOwner: _op.destOwner != address(0) ? _op.destOwner : msg.sender,
            to: resolve(_op.destChainId, name(), false),
            value: msg.value - _op.fee,
            fee: _op.fee,
            gasLimit: _op.gasLimit,
            data: data
        });

        // Send the message and obtain the message hash
        bytes32 msgHash;
        (msgHash, message_) =
            IBridge(resolve(LibStrings.B_BRIDGE, false)).sendMessage{ value: msg.value }(message);

        // Emit TokenSent event
        emit TokenSent({
            msgHash: msgHash,
            from: message_.srcOwner,
            to: _op.to,
            destChainId: message_.destChainId,
            ctoken: ctoken.addr,
            token: _op.token,
            tokenIds: _op.tokenIds,
            amounts: _op.amounts
        });
    }

    /// @inheritdoc IMessageInvocable
    function onMessageInvocation(bytes calldata data) external payable whenNotPaused nonReentrant {
        (
            CanonicalNFT memory ctoken,
            address from,
            address to,
            uint256[] memory tokenIds,
            uint256[] memory amounts
        ) = abi.decode(data, (CanonicalNFT, address, address, uint256[], uint256[]));

        // Check context validity
        // `onlyFromBridge` checked in checkProcessMessageContext
        IBridge.Context memory ctx = checkProcessMessageContext();

        // Don't allow sending to disallowed addresses.
        // Don't send the tokens back to `from` because `from` is on the source chain.
        checkToAddress(to);

        // Transfer the ETH and the tokens to the `to` address
        address token = _transferTokens(ctoken, to, tokenIds, amounts);
        to.sendEtherAndVerify(msg.value);

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            ctoken: ctoken.addr,
            token: token,
            tokenIds: tokenIds,
            amounts: amounts
        });
    }

    /// @inheritdoc IRecallableSender
    function onMessageRecalled(
        IBridge.Message calldata message,
        bytes32 msgHash
    )
        external
        payable
        override
        whenNotPaused
        nonReentrant
    {
        // `onlyFromBridge` checked in checkRecallMessageContext
        checkRecallMessageContext();

        (bytes memory data) = abi.decode(message.data[4:], (bytes));
        (CanonicalNFT memory ctoken,,, uint256[] memory tokenIds, uint256[] memory amounts) =
            abi.decode(data, (CanonicalNFT, address, address, uint256[], uint256[]));

        // Transfer the ETH and tokens back to the owner
        address token = _transferTokens(ctoken, message.srcOwner, tokenIds, amounts);
        message.srcOwner.sendEtherAndVerify(message.value);

        // Emit TokenReleased event
        emit TokenReleased({
            msgHash: msgHash,
            from: message.srcOwner,
            ctoken: ctoken.addr,
            token: token,
            tokenIds: tokenIds,
            amounts: amounts
        });
    }

    /// @notice See {ERC1155ReceiverUpgradeable-onERC1155BatchReceived}.
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        external
        pure
        returns (bytes4)
    {
        return IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector;
    }

    /// @notice See {ERC1155ReceiverUpgradeable-onERC1155Received}.
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    )
        external
        pure
        returns (bytes4)
    {
        return IERC1155ReceiverUpgradeable.onERC1155Received.selector;
    }

    /// @dev See {BaseVault-supportsInterface}.
    /// @param _interfaceId The interface identifier.
    /// @return true if supports, else otherwise.
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(BaseVault, ERC1155ReceiverUpgradeable)
        returns (bool)
    {
        // Here we cannot user `super.supportsInterface(_interfaceId)`
        return BaseVault.supportsInterface(_interfaceId)
            || ERC1155ReceiverUpgradeable.supportsInterface(_interfaceId);
    }

    /// @inheritdoc BaseVault
    function name() public pure override returns (bytes32) {
        return LibStrings.B_ERC1155_VAULT;
    }

    /// @dev Transfers ERC1155 tokens to the `to` address.
    /// @param ctoken CanonicalNFT data.
    /// @param to The address to transfer the tokens to.
    /// @param tokenIds The token IDs to transfer.
    /// @param amounts The amounts to transfer.
    /// @return token The address of the token.
    function _transferTokens(
        CanonicalNFT memory ctoken,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    )
        private
        returns (address token)
    {
        if (ctoken.chainId == block.chainid) {
            // Token lives on this chain
            token = ctoken.addr;
            IERC1155(token).safeBatchTransferFrom(address(this), to, tokenIds, amounts, "");
        } else {
            // Token does not live on this chain
            token = _getOrDeployBridgedToken(ctoken);
            IBridgedERC1155(token).mintBatch(to, tokenIds, amounts);
        }
    }

    /// @dev Handles the message on the source chain and returns the encoded
    /// call on the destination call.
    /// @param _op BridgeTransferOp data.
    /// @return msgData_ Encoded message data.
    /// @return ctoken_ The canonical token.
    function _handleMessage(BridgeTransferOp calldata _op)
        private
        returns (bytes memory msgData_, CanonicalNFT memory ctoken_)
    {
        unchecked {
            // is a btoken, meaning, it does not live on this chain
            CanonicalNFT storage _ctoken = bridgedToCanonical[_op.token];
            if (_ctoken.addr != address(0)) {
                ctoken_ = _ctoken;
                IERC1155(_op.token).safeBatchTransferFrom(
                    msg.sender, address(this), _op.tokenIds, _op.amounts, ""
                );
                for (uint256 i; i < _op.tokenIds.length; ++i) {
                    IBridgedERC1155(_op.token).burn(_op.tokenIds[i], _op.amounts[i]);
                }
            } else {
                // is a ctoken token, meaning, it lives on this chain
                ctoken_ = CanonicalNFT({
                    chainId: uint64(block.chainid),
                    addr: _op.token,
                    symbol: safeSymbol(_op.token),
                    name: safeName(_op.token)
                });

                IERC1155(_op.token).safeBatchTransferFrom(
                    msg.sender, address(this), _op.tokenIds, _op.amounts, ""
                );
            }
        }
        msgData_ = abi.encodeCall(
            this.onMessageInvocation,
            abi.encode(ctoken_, msg.sender, _op.to, _op.tokenIds, _op.amounts)
        );
    }

    /// @dev Retrieve or deploy a bridged ERC1155 token contract.
    /// @param _ctoken CanonicalNFT data.
    /// @return btoken_ Address of the bridged token contract.
    function _getOrDeployBridgedToken(CanonicalNFT memory _ctoken)
        private
        returns (address btoken_)
    {
        btoken_ = canonicalToBridged[_ctoken.chainId][_ctoken.addr];
        if (btoken_ == address(0)) {
            btoken_ = _deployBridgedToken(_ctoken);
        }
    }

    /// @dev Deploy a new BridgedNFT contract and initialize it.
    /// This must be called before the first time a bridged token is sent to
    /// this chain.
    /// @param _ctoken CanonicalNFT data.
    /// @return btoken_ Address of the deployed bridged token contract.
    function _deployBridgedToken(CanonicalNFT memory _ctoken) private returns (address btoken_) {
        bytes memory data = abi.encodeCall(
            IBridgedERC1155Initializable.init,
            (owner(), addressManager, _ctoken.addr, _ctoken.chainId, _ctoken.symbol, _ctoken.name)
        );

        btoken_ = address(new ERC1967Proxy(resolve(LibStrings.B_BRIDGED_ERC1155, false), data));

        bridgedToCanonical[btoken_] = _ctoken;
        canonicalToBridged[_ctoken.chainId][_ctoken.addr] = btoken_;

        emit BridgedTokenDeployed({
            chainId: _ctoken.chainId,
            ctoken: _ctoken.addr,
            btoken: btoken_,
            ctokenSymbol: _ctoken.symbol,
            ctokenName: _ctoken.name
        });
    }
}


// File: node_modules/@openzeppelin/contracts/token/ERC1155/IERC1155.sol
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


// File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/utils/ERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../IERC1155ReceiverUpgradeable.sol";
import "../../../utils/introspection/ERC165Upgradeable.sol";
import {Initializable} from "../../../proxy/utils/Initializable.sol";

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


// File: contracts/libs/LibAddress.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

/// @title LibAddress
/// @dev Provides utilities for address-related operations.
/// @custom:security-contact security@taiko.xyz
library LibAddress {
    error ETH_TRANSFER_FAILED();

    /// @dev Sends Ether to the specified address. This method will not revert even if sending ether
    /// fails.
    /// This function is inspired by
    /// https://github.com/nomad-xyz/ExcessivelySafeCall/blob/main/src/ExcessivelySafeCall.sol
    /// @param _to The recipient address.
    /// @param _amount The amount of Ether to send in wei.
    /// @param _gasLimit The max amount gas to pay for this transaction.
    /// @return success_ true if the call is successful, false otherwise.
    function sendEther(
        address _to,
        uint256 _amount,
        uint256 _gasLimit,
        bytes memory _calldata
    )
        internal
        returns (bool success_)
    {
        // Check for zero-address transactions
        if (_to == address(0)) revert ETH_TRANSFER_FAILED();
        // dispatch message to recipient
        // by assembly calling "handle" function
        // we call via assembly to avoid memcopying a very large returndata
        // returned by a malicious contract
        assembly {
            success_ :=
                call(
                    _gasLimit, // gas
                    _to, // recipient
                    _amount, // ether value
                    add(_calldata, 0x20), // inloc
                    mload(_calldata), // inlen
                    0, // outloc
                    0 // outlen
                )
        }
    }

    /// @dev Sends Ether to the specified address. This method will revert if sending ether fails.
    /// @param _to The recipient address.
    /// @param _amount The amount of Ether to send in wei.
    /// @param _gasLimit The max amount gas to pay for this transaction.
    function sendEtherAndVerify(address _to, uint256 _amount, uint256 _gasLimit) internal {
        if (_amount == 0) return;
        if (!sendEther(_to, _amount, _gasLimit, "")) {
            revert ETH_TRANSFER_FAILED();
        }
    }

    /// @dev Sends Ether to the specified address. This method will revert if sending ether fails.
    /// @param _to The recipient address.
    /// @param _amount The amount of Ether to send in wei.
    function sendEtherAndVerify(address _to, uint256 _amount) internal {
        sendEtherAndVerify(_to, _amount, gasleft());
    }

    function supportsInterface(
        address _addr,
        bytes4 _interfaceId
    )
        internal
        view
        returns (bool result_)
    {
        if (!Address.isContract(_addr)) return false;

        try IERC165(_addr).supportsInterface(_interfaceId) returns (bool _result) {
            result_ = _result;
        } catch { }
    }
}


// File: contracts/common/LibStrings.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LibStrings
/// @custom:security-contact security@taiko.xyz
library LibStrings {
    bytes32 internal constant B_AUTOMATA_DCAP_ATTESTATION = bytes32("automata_dcap_attestation");
    bytes32 internal constant B_BRIDGE = bytes32("bridge");
    bytes32 internal constant B_BRIDGE_WATCHDOG = bytes32("bridge_watchdog");
    bytes32 internal constant B_BRIDGED_ERC1155 = bytes32("bridged_erc1155");
    bytes32 internal constant B_BRIDGED_ERC20 = bytes32("bridged_erc20");
    bytes32 internal constant B_BRIDGED_ERC721 = bytes32("bridged_erc721");
    bytes32 internal constant B_CHAIN_WATCHDOG = bytes32("chain_watchdog");
    bytes32 internal constant B_ERC1155_VAULT = bytes32("erc1155_vault");
    bytes32 internal constant B_ERC20_VAULT = bytes32("erc20_vault");
    bytes32 internal constant B_ERC721_VAULT = bytes32("erc721_vault");
    bytes32 internal constant B_PROVER_ASSIGNMENT = bytes32("PROVER_ASSIGNMENT");
    bytes32 internal constant B_PROVER_SET = bytes32("prover_set");
    bytes32 internal constant B_QUOTA_MANAGER = bytes32("quota_manager");
    bytes32 internal constant B_SGX_WATCHDOG = bytes32("sgx_watchdog");
    bytes32 internal constant B_SIGNAL_SERVICE = bytes32("signal_service");
    bytes32 internal constant B_TAIKO = bytes32("taiko");
    bytes32 internal constant B_TAIKO_TOKEN = bytes32("taiko_token");
    bytes32 internal constant B_TIER_GUARDIAN = bytes32("tier_guardian");
    bytes32 internal constant B_TIER_GUARDIAN_MINORITY = bytes32("tier_guardian_minority");
    bytes32 internal constant B_TIER_ROUTER = bytes32("tier_router");
    bytes32 internal constant B_TIER_SGX = bytes32("tier_sgx");
    bytes32 internal constant B_TIER_SGX_ZKVM = bytes32("tier_sgx_zkvm");
    bytes32 internal constant B_WITHDRAWER = bytes32("withdrawer");
    bytes32 internal constant H_RETURN_LIVENESS_BOND = keccak256("RETURN_LIVENESS_BOND");
    bytes32 internal constant H_SIGNAL_ROOT = keccak256("SIGNAL_ROOT");
    bytes32 internal constant H_STATE_ROOT = keccak256("STATE_ROOT");
}


// File: contracts/tokenvault/IBridgedERC1155.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IBridgedERC1155
/// @notice Contract for bridging ERC1155 tokens across different chains.
/// @custom:security-contact security@taiko.xyz
interface IBridgedERC1155 {
    /// @dev Mints tokens.
    /// @param _to Address to receive the minted tokens.
    /// @param _tokenIds ID of the token to mint.
    /// @param _amounts Amount of tokens to mint.
    function mintBatch(
        address _to,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    )
        external;

    /// @dev Burns tokens.
    /// @param _id ID of the token to burn.
    /// @param _amount Amount of token to burn respectively.
    function burn(uint256 _id, uint256 _amount) external;

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address.
    /// @return The canonical token's chain ID.
    function canonical() external view returns (address, uint256);
}

/// @title IBridgedERC1155Initializable
/// @custom:security-contact security@taiko.xyz
interface IBridgedERC1155Initializable {
    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _srcToken Address of the source token.
    /// @param _srcChainId Source chain ID.
    /// @param _symbol Symbol of the bridged token.
    /// @param _name Name of the bridged token.
    function init(
        address _owner,
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        string calldata _symbol,
        string calldata _name
    )
        external;
}


// File: contracts/tokenvault/BaseNFTVault.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./BaseVault.sol";

/// @title BaseNFTVault
/// @notice Abstract contract for bridging NFTs across different chains.
/// @custom:security-contact security@taiko.xyz
abstract contract BaseNFTVault is BaseVault {
    // Struct representing the canonical NFT on another chain.
    struct CanonicalNFT {
        // Chain ID of the NFT.
        uint64 chainId;
        // Address of the NFT contract.
        address addr;
        // Symbol of the NFT.
        string symbol;
        // Name of the NFT.
        string name;
    }

    /// @devStruct representing the details of a bridged token transfer operation.
    /// 5 slots
    struct BridgeTransferOp {
        // Destination chain ID.
        uint64 destChainId;
        // The owner of the bridge message on the destination chain.
        address destOwner;
        // Recipient address.
        address to;
        // Processing fee for the relayer.
        uint64 fee;
        // Address of the token.
        address token;
        // Gas limit for the operation.
        uint32 gasLimit;
        // Token Id array
        uint256[] tokenIds;
        // Respective amounts per given token Ids.
        uint256[] amounts;
    }

    /// @notice Mapping to store bridged NFTs and their canonical counterparts.
    mapping(address btoken => CanonicalNFT canonical) public bridgedToCanonical;

    /// @notice Mapping to store canonical NFTs and their bridged counterparts.
    mapping(uint256 chainId => mapping(address ctoken => address btoken)) public canonicalToBridged;

    uint256[48] private __gap;

    /// @notice Emitted when a new bridged token is deployed.
    /// @param chainId The chain ID of the bridged token.
    /// @param ctoken The address of the canonical token.
    /// @param btoken The address of the bridged token.
    /// @param ctokenSymbol The symbol of the canonical token.
    /// @param ctokenName The name of the canonical token.
    event BridgedTokenDeployed(
        uint64 indexed chainId,
        address indexed ctoken,
        address indexed btoken,
        string ctokenSymbol,
        string ctokenName
    );

    /// @notice Emitted when a token is sent to another chain.
    /// @param msgHash The hash of the message.
    /// @param from The sender of the message.
    /// @param to The recipient of the message.
    /// @param destChainId The destination chain ID.
    /// @param ctoken The address of the canonical token.
    /// @param token The address of the bridged token.
    /// @param tokenIds The IDs of the tokens.
    /// @param amounts The amounts of the tokens.
    event TokenSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint64 destChainId,
        address ctoken,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    /// @notice Emitted when a token is released on the current chain.
    /// @param msgHash The hash of the message.
    /// @param from The sender of the message.
    /// @param ctoken The address of the canonical token.
    /// @param token The address of the bridged token.
    /// @param tokenIds The IDs of the tokens.
    /// @param amounts The amounts of the tokens.
    event TokenReleased(
        bytes32 indexed msgHash,
        address indexed from,
        address ctoken,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    /// @notice Emitted when a token is received from another chain.
    /// @param msgHash The hash of the message.
    /// @param from The sender of the message.
    /// @param to The recipient of the message.
    /// @param srcChainId The source chain ID.
    /// @param ctoken The address of the canonical token.
    /// @param token The address of the bridged token.
    /// @param tokenIds The IDs of the tokens.
    /// @param amounts The amounts of the tokens.
    event TokenReceived(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint64 srcChainId,
        address ctoken,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    error VAULT_INVALID_TOKEN();
    error VAULT_INVALID_AMOUNT();
    error VAULT_INTERFACE_NOT_SUPPORTED();
    error VAULT_TOKEN_ARRAY_MISMATCH();

    modifier withValidOperation(BridgeTransferOp memory _op) {
        if (_op.tokenIds.length != _op.amounts.length) {
            revert VAULT_TOKEN_ARRAY_MISMATCH();
        }

        if (_op.token == address(0)) revert VAULT_INVALID_TOKEN();
        _;
    }
}


// File: node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol
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


// File: node_modules/@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol
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


// File: node_modules/@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

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


// File: node_modules/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol
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


// File: node_modules/@openzeppelin/contracts/utils/Address.sol
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


// File: node_modules/@openzeppelin/contracts/interfaces/IERC1271.sol
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


// File: contracts/tokenvault/BaseVault.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../bridge/IBridge.sol";
import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../libs/LibBytes.sol";

/// @title INameSymbol
/// @notice Interface for contracts that provide name() and symbol()
/// functions. These functions may not be part of the official interface but are
/// used by some contracts.
/// @custom:security-contact security@taiko.xyz
interface INameSymbol {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

/// @title BaseVault
/// @notice This abstract contract provides a base implementation for vaults.
/// @custom:security-contact security@taiko.xyz
abstract contract BaseVault is
    EssentialContract,
    IRecallableSender,
    IMessageInvocable,
    IERC165Upgradeable
{
    using LibBytes for bytes;

    uint256[50] private __gap;

    error VAULT_INSUFFICIENT_FEE();
    error VAULT_INVALID_TO_ADDR();
    error VAULT_PERMISSION_DENIED();

    /// @notice Checks if the contract supports the given interface.
    /// @param _interfaceId The interface identifier.
    /// @return true if the contract supports the interface, false otherwise.
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IRecallableSender).interfaceId
            || _interfaceId == type(IMessageInvocable).interfaceId
            || _interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /// @notice Returns the name of the vault.
    /// @return The name of the vault.
    function name() public pure virtual returns (bytes32);

    function checkProcessMessageContext()
        internal
        view
        onlyFromNamed(LibStrings.B_BRIDGE)
        returns (IBridge.Context memory ctx_)
    {
        ctx_ = IBridge(msg.sender).context();
        address selfOnSourceChain = resolve(ctx_.srcChainId, name(), false);
        if (ctx_.from != selfOnSourceChain) revert VAULT_PERMISSION_DENIED();
    }

    function checkRecallMessageContext()
        internal
        view
        onlyFromNamed(LibStrings.B_BRIDGE)
        returns (IBridge.Context memory ctx_)
    {
        ctx_ = IBridge(msg.sender).context();
        if (ctx_.from != msg.sender) revert VAULT_PERMISSION_DENIED();
    }

    function checkToAddress(address _to) internal view {
        if (_to == address(0) || _to == address(this)) revert VAULT_INVALID_TO_ADDR();
    }

    function safeSymbol(address _token) internal view returns (string memory symbol_) {
        (bool success, bytes memory data) =
            address(_token).staticcall(abi.encodeCall(INameSymbol.symbol, ()));
        return success ? data.toString() : "";
    }

    function safeName(address _token) internal view returns (string memory) {
        (bool success, bytes memory data) =
            address(_token).staticcall(abi.encodeCall(INameSymbol.name, ()));
        return success ? data.toString() : "";
    }
}


// File: node_modules/@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol
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


// File: node_modules/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol
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


// File: node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/ERC1967/ERC1967Proxy.sol)

pragma solidity ^0.8.0;

import "../Proxy.sol";
import "./ERC1967Upgrade.sol";

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 */
contract ERC1967Proxy is Proxy, ERC1967Upgrade {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializing the storage of the proxy like a Solidity constructor.
     */
    constructor(address _logic, bytes memory _data) payable {
        _upgradeToAndCall(_logic, _data, false);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view virtual override returns (address impl) {
        return ERC1967Upgrade._getImplementation();
    }
}


// File: contracts/bridge/IBridge.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IBridge
/// @notice The bridge used in conjunction with the {ISignalService}.
/// @dev Ether is held by Bridges on L1 and L2s.
/// @custom:security-contact security@taiko.xyz
interface IBridge {
    enum Status {
        NEW,
        RETRIABLE,
        DONE,
        FAILED,
        RECALLED
    }

    enum StatusReason {
        INVOCATION_OK,
        INVOCATION_PROHIBITED,
        INVOCATION_FAILED,
        OUT_OF_ETH_QUOTA
    }

    struct Message {
        // Message ID whose value is automatically assigned.
        uint64 id;
        // The max processing fee for the relayer. This fee has 3 parts:
        // - the fee for message calldata.
        // - the minimal fee reserve for general processing, excluding function call.
        // - the invocation fee for the function call.
        // Any unpaid fee will be refunded to the destOwner on the destination chain.
        // Note that fee must be 0 if gasLimit is 0, or large enough to make the invocation fee
        // non-zero.
        uint64 fee;
        // gasLimit that the processMessage call must have.
        uint32 gasLimit;
        // The address, EOA or contract, that interacts with this bridge.
        // The value is automatically assigned.
        address from;
        // Source chain ID whose value is automatically assigned.
        uint64 srcChainId;
        // The owner of the message on the source chain.
        address srcOwner;
        // Destination chain ID where the `to` address lives.
        uint64 destChainId;
        // The owner of the message on the destination chain.
        address destOwner;
        // The destination address on the destination chain.
        address to;
        // value to invoke on the destination chain.
        uint256 value;
        // callData to invoke on the destination chain.
        bytes data;
    }

    // Struct representing the context of a bridge operation.
    // 2 slots
    struct Context {
        bytes32 msgHash; // Message hash.
        address from; // Sender's address.
        uint64 srcChainId; // Source chain ID.
    }

    /// @notice Emitted when a message is sent.
    /// @param msgHash The hash of the message.
    /// @param message The message.
    event MessageSent(bytes32 indexed msgHash, Message message);

    /// @notice Emitted when the status of a message changes.
    /// @param msgHash The hash of the message.
    /// @param status The new status of the message.
    event MessageStatusChanged(bytes32 indexed msgHash, Status status);

    /// @notice Sends a message to the destination chain and takes custody
    /// of Ether required in this contract.
    /// @param _message The message to be sent.
    /// @return msgHash_ The hash of the sent message.
    /// @return message_ The updated message sent.
    function sendMessage(Message calldata _message)
        external
        payable
        returns (bytes32 msgHash_, Message memory message_);

    /// @notice Recalls a failed message on its source chain, releasing
    /// associated assets.
    /// @dev This function checks if the message failed on the source chain and
    /// releases associated Ether or tokens.
    /// @param _message The message whose associated Ether should be released.
    /// @param _proof The merkle inclusion proof.
    function recallMessage(Message calldata _message, bytes calldata _proof) external;

    /// @notice Processes a bridge message on the destination chain. This
    /// function is callable by any address, including the `message.destOwner`.
    /// @dev The process begins by hashing the message and checking the message
    /// status in the bridge  If the status is "NEW", the message is invoked. The
    /// status is updated accordingly, and processing fees are refunded as
    /// needed.
    /// @param _message The message to be processed.
    /// @param _proof The merkle inclusion proof.
    /// @return The message's status after processing and the reason for the change.
    function processMessage(
        Message calldata _message,
        bytes calldata _proof
    )
        external
        returns (Status, StatusReason);

    /// @notice Retries to invoke the messageCall after releasing associated
    /// Ether and tokens.
    /// @dev This function can be called by any address, including the
    /// `message.destOwner`.
    /// It attempts to invoke the messageCall and updates the message status
    /// accordingly.
    /// @param _message The message to retry.
    /// @param _isLastAttempt Specifies if this is the last attempt to retry the
    /// message.
    function retryMessage(Message calldata _message, bool _isLastAttempt) external;

    /// @notice Mark a message as failed if the message is currently retriable.
    /// @dev This function can only be called by `message.destOwner`.
    /// @param _message The message to fail.
    /// message.
    function failMessage(Message calldata _message) external;

    /// @notice Returns the bridge state context.
    /// @return ctx_ The context of the current bridge operation.
    function context() external view returns (Context memory ctx_);

    /// @notice Checks if the message was sent.
    /// @param _message The message.
    /// @return true if the message was sent.
    function isMessageSent(Message calldata _message) external view returns (bool);

    /// @notice Hash the message
    /// @param _message The message struct variable to be hashed.
    /// @return The message's hash.
    function hashMessage(Message memory _message) external pure returns (bytes32);
}

/// @title IRecallableSender
/// @notice An interface that all recallable message senders shall implement.
interface IRecallableSender {
    /// @notice Called when a message is recalled.
    /// @param _message The recalled message.
    /// @param _msgHash The hash of the recalled message.
    function onMessageRecalled(
        IBridge.Message calldata _message,
        bytes32 _msgHash
    )
        external
        payable;
}

/// @title IMessageInvocable
/// @notice An interface that all bridge message receiver shall implement
interface IMessageInvocable {
    /// @notice Called when this contract is the bridge target.
    /// @param _data The data for this contract to interpret.
    /// @dev This method should be guarded with `onlyFromNamed("bridge")`.
    function onMessageInvocation(bytes calldata _data) external payable;
}


// File: contracts/common/EssentialContract.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "./AddressResolver.sol";
import "../libs/LibNetwork.sol";

/// @title EssentialContract
/// @custom:security-contact security@taiko.xyz
abstract contract EssentialContract is UUPSUpgradeable, Ownable2StepUpgradeable, AddressResolver {
    uint8 private constant _FALSE = 1;

    uint8 private constant _TRUE = 2;

    /// @dev The slot in transient storage of the reentry lock.
    /// This is the result of keccak256("ownerUUPS.reentry_slot") plus 1. The addition aims to
    /// prevent hash collisions with slots defined in EIP-1967, where slots are derived by
    /// keccak256("something") - 1, and with slots in SignalService, calculated directly with
    /// keccak256("something").
    bytes32 private constant _REENTRY_SLOT =
        0xa5054f728453d3dbe953bdc43e4d0cb97e662ea32d7958190f3dc2da31d9721b;

    /// @dev Slot 1.
    uint8 private __reentry;
    uint8 private __paused;
    uint64 public lastUnpausedAt;

    uint256[49] private __gap;

    /// @notice Emitted when the contract is paused.
    /// @param account The account that paused the contract.
    event Paused(address account);

    /// @notice Emitted when the contract is unpaused.
    /// @param account The account that unpaused the contract.
    event Unpaused(address account);

    error INVALID_PAUSE_STATUS();
    error FUNC_NOT_IMPLEMENTED();
    error REENTRANT_CALL();
    error ZERO_ADDRESS();
    error ZERO_VALUE();

    /// @dev Modifier that ensures the caller is the owner or resolved address of a given name.
    /// @param _name The name to check against.
    modifier onlyFromOwnerOrNamed(bytes32 _name) {
        if (msg.sender != owner() && msg.sender != resolve(_name, true)) revert RESOLVER_DENIED();
        _;
    }

    modifier notImplemented() {
        revert FUNC_NOT_IMPLEMENTED();
        _;
    }

    modifier nonReentrant() {
        if (_loadReentryLock() == _TRUE) revert REENTRANT_CALL();
        _storeReentryLock(_TRUE);
        _;
        _storeReentryLock(_FALSE);
    }

    modifier whenPaused() {
        if (!paused()) revert INVALID_PAUSE_STATUS();
        _;
    }

    modifier whenNotPaused() {
        if (paused()) revert INVALID_PAUSE_STATUS();
        _;
    }

    modifier nonZeroAddr(address _addr) {
        if (_addr == address(0)) revert ZERO_ADDRESS();
        _;
    }

    modifier nonZeroValue(bytes32 _value) {
        if (_value == 0) revert ZERO_VALUE();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Pauses the contract.
    function pause() public virtual {
        _pause();
        // We call the authorize function here to avoid:
        // Warning (5740): Unreachable code.
        _authorizePause(msg.sender, true);
    }

    /// @notice Unpauses the contract.
    function unpause() public virtual {
        _unpause();
        // We call the authorize function here to avoid:
        // Warning (5740): Unreachable code.
        _authorizePause(msg.sender, false);
    }

    function impl() public view returns (address) {
        return _getImplementation();
    }

    /// @notice Returns true if the contract is paused, and false otherwise.
    /// @return true if paused, false otherwise.
    function paused() public view returns (bool) {
        return __paused == _TRUE;
    }

    function inNonReentrant() public view returns (bool) {
        return _loadReentryLock() == _TRUE;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function __Essential_init(
        address _owner,
        address _addressManager
    )
        internal
        nonZeroAddr(_addressManager)
    {
        __Essential_init(_owner);
        __AddressResolver_init(_addressManager);
    }

    function __Essential_init(address _owner) internal virtual onlyInitializing {
        __Context_init();
        _transferOwnership(_owner == address(0) ? msg.sender : _owner);
        __paused = _FALSE;
    }

    function _pause() internal whenNotPaused {
        __paused = _TRUE;
        emit Paused(msg.sender);
    }

    function _unpause() internal whenPaused {
        __paused = _FALSE;
        lastUnpausedAt = uint64(block.timestamp);
        emit Unpaused(msg.sender);
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner { }

    function _authorizePause(address, bool) internal virtual onlyOwner { }

    // Stores the reentry lock
    function _storeReentryLock(uint8 _reentry) internal virtual {
        if (LibNetwork.isDencunSupported(block.chainid)) {
            assembly {
                tstore(_REENTRY_SLOT, _reentry)
            }
        } else {
            __reentry = _reentry;
        }
    }

    // Loads the reentry lock
    function _loadReentryLock() internal view virtual returns (uint8 reentry_) {
        if (LibNetwork.isDencunSupported(block.chainid)) {
            assembly {
                reentry_ := tload(_REENTRY_SLOT)
            }
        } else {
            reentry_ = __reentry;
        }
    }
}


// File: contracts/libs/LibBytes.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library LibBytes {
    error INNER_ERROR(bytes innerError);

    // Function body taken from:
    // https://github.com/clober-dex/core/blob/main/contracts/utils/BoringERC20.sol#L17-L33
    /// @notice Function to convert returned data to string
    /// returns '' as fallback value.
    function toString(bytes memory _data) internal pure returns (string memory) {
        if (_data.length >= 64) {
            return abi.decode(_data, (string));
        } else if (_data.length == 32) {
            uint8 i = 0;
            while (i < 32 && _data[i] != 0) {
                i++;
            }
            bytes memory bytesArray = new bytes(i);
            for (i = 0; i < 32 && _data[i] != 0; i++) {
                bytesArray[i] = _data[i];
            }
            return string(bytesArray);
        } else {
            return "";
        }
    }

    // Taken from:
    // https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/BoringBatchable.sol
    /// @dev Helper function to extract a useful revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this call can fail
    /// itself.
    function revertWithExtractedError(bytes memory _returnData) internal pure {
        // If the _res length is less than 68, then
        // the transaction failed with custom error or silently (without a revert message)
        if (_returnData.length < 68) revert INNER_ERROR(_returnData);

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        revert(abi.decode(_returnData, (string))); // All that remains is the revert string
    }
}


// File: node_modules/@openzeppelin/contracts/proxy/Proxy.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

pragma solidity ^0.8.0;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overridden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}


// File: node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeacon.sol";
import "../../interfaces/IERC1967.sol";
import "../../interfaces/draft-IERC1822.sol";
import "../../utils/Address.sol";
import "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 */
abstract contract ERC1967Upgrade is IERC1967 {
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
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
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
            Address.functionDelegateCall(newImplementation, data);
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
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
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
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
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
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
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
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}


// File: node_modules/@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822.sol";
import "../ERC1967/ERC1967Upgrade.sol";

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
abstract contract UUPSUpgradeable is IERC1822Proxiable, ERC1967Upgrade {
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
}


// File: node_modules/@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.0;

import "./OwnableUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2StepUpgradeable is Initializable, OwnableUpgradeable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    function __Ownable2Step_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable2Step_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// File: contracts/common/AddressResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IAddressManager.sol";
import "./IAddressResolver.sol";

/// @title AddressResolver
/// @notice See the documentation in {IAddressResolver}.
/// @custom:security-contact security@taiko.xyz
abstract contract AddressResolver is IAddressResolver, Initializable {
    /// @notice Address of the AddressManager.
    address public addressManager;
    uint256[49] private __gap;

    error RESOLVER_DENIED();
    error RESOLVER_INVALID_MANAGER();
    error RESOLVER_UNEXPECTED_CHAINID();
    error RESOLVER_ZERO_ADDR(uint64 chainId, bytes32 name);

    /// @dev Modifier that ensures the caller is the resolved address of a given
    /// name.
    /// @param _name The name to check against.
    modifier onlyFromNamed(bytes32 _name) {
        if (msg.sender != resolve(_name, true)) revert RESOLVER_DENIED();
        _;
    }

    /// @dev Modifier that ensures the caller is a resolved address to either _name1 or _name2
    /// name.
    /// @param _name1 The first name to check against.
    /// @param _name2 The second name to check against.
    modifier onlyFromNamedEither(bytes32 _name1, bytes32 _name2) {
        if (msg.sender != resolve(_name1, true) && msg.sender != resolve(_name2, true)) {
            revert RESOLVER_DENIED();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IAddressResolver
    function resolve(
        bytes32 _name,
        bool _allowZeroAddress
    )
        public
        view
        virtual
        returns (address payable)
    {
        return _resolve(uint64(block.chainid), _name, _allowZeroAddress);
    }

    /// @inheritdoc IAddressResolver
    function resolve(
        uint64 _chainId,
        bytes32 _name,
        bool _allowZeroAddress
    )
        public
        view
        virtual
        returns (address payable)
    {
        return _resolve(_chainId, _name, _allowZeroAddress);
    }

    /// @dev Initialization method for setting up AddressManager reference.
    /// @param _addressManager Address of the AddressManager.
    function __AddressResolver_init(address _addressManager) internal virtual onlyInitializing {
        if (block.chainid > type(uint64).max) {
            revert RESOLVER_UNEXPECTED_CHAINID();
        }
        addressManager = _addressManager;
    }

    /// @dev Helper method to resolve name-to-address.
    /// @param _chainId The chainId of interest.
    /// @param _name Name whose address is to be resolved.
    /// @param _allowZeroAddress If set to true, does not throw if the resolved
    /// address is `address(0)`.
    /// @return addr_ Address associated with the given name on the specified
    /// chain.
    function _resolve(
        uint64 _chainId,
        bytes32 _name,
        bool _allowZeroAddress
    )
        private
        view
        returns (address payable addr_)
    {
        address _addressManager = addressManager;
        if (_addressManager == address(0)) revert RESOLVER_INVALID_MANAGER();

        addr_ = payable(IAddressManager(_addressManager).getAddress(_chainId, _name));

        if (!_allowZeroAddress && addr_ == address(0)) {
            revert RESOLVER_ZERO_ADDR(_chainId, _name);
        }
    }
}


// File: contracts/libs/LibNetwork.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LibNetwork
library LibNetwork {
    uint256 internal constant MAINNET = 1;
    uint256 internal constant ROPSTEN = 2;
    uint256 internal constant RINKEBY = 4;
    uint256 internal constant GOERLI = 5;
    uint256 internal constant KOVAN = 42;
    uint256 internal constant HOLESKY = 17_000;
    uint256 internal constant SEPOLIA = 11_155_111;

    uint64 internal constant TAIKO = 167_000;

    /// @dev Checks if the chain ID represents an Ethereum testnet.
    /// @param _chainId The chain ID.
    /// @return true if the chain ID represents an Ethereum testnet, false otherwise.
    function isEthereumTestnet(uint256 _chainId) internal pure returns (bool) {
        return _chainId == LibNetwork.ROPSTEN || _chainId == LibNetwork.RINKEBY
            || _chainId == LibNetwork.GOERLI || _chainId == LibNetwork.KOVAN
            || _chainId == LibNetwork.HOLESKY || _chainId == LibNetwork.SEPOLIA;
    }

    /// @dev Checks if the chain ID represents an Ethereum testnet or the Etheruem mainnet.
    /// @param _chainId The chain ID.
    /// @return true if the chain ID represents an Ethereum testnet or the Etheruem mainnet, false
    /// otherwise.
    function isEthereumMainnetOrTestnet(uint256 _chainId) internal pure returns (bool) {
        return _chainId == LibNetwork.MAINNET || isEthereumTestnet(_chainId);
    }

    /// @dev Checks if the chain ID represents the Taiko L2 mainnet.
    /// @param _chainId The chain ID.
    /// @return true if the chain ID represents the Taiko L2 mainnet.
    function isTaikoMainnet(uint256 _chainId) internal pure returns (bool) {
        return _chainId == TAIKO;
    }

    /// @dev Checks if the chain ID represents an internal Taiko devnet's base layer.
    /// @param _chainId The chain ID.
    /// @return true if the chain ID represents an internal Taiko devnet's base layer, false
    /// otherwise.
    function isTaikoDevnet(uint256 _chainId) internal pure returns (bool) {
        return _chainId >= 32_300 && _chainId <= 32_400;
    }

    /// @dev Checks if the chain supports Dencun hardfork. Note that this check doesn't need to be
    /// exhaustive.
    /// @param _chainId The chain ID.
    /// @return true if the chain supports Dencun hardfork, false otherwise.
    function isDencunSupported(uint256 _chainId) internal pure returns (bool) {
        return _chainId == LibNetwork.MAINNET || _chainId == LibNetwork.HOLESKY
            || _chainId == LibNetwork.SEPOLIA || isTaikoDevnet(_chainId);
    }
}


// File: node_modules/@openzeppelin/contracts/proxy/beacon/IBeacon.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}


// File: node_modules/@openzeppelin/contracts/interfaces/IERC1967.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC1967.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 *
 * _Available since v4.8.3._
 */
interface IERC1967 {
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


// File: node_modules/@openzeppelin/contracts/interfaces/draft-IERC1822.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
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


// File: node_modules/@openzeppelin/contracts/utils/StorageSlot.sol
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
library StorageSlot {
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


// File: node_modules/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

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
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
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


// File: contracts/common/IAddressManager.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IAddressManager
/// @notice Manages a mapping of (chainId, name) pairs to Ethereum addresses.
/// @custom:security-contact security@taiko.xyz
interface IAddressManager {
    /// @notice Gets the address mapped to a specific chainId-name pair.
    /// @dev Note that in production, this method shall be a pure function
    /// without any storage access.
    /// @param _chainId The chainId for which the address needs to be fetched.
    /// @param _name The name for which the address needs to be fetched.
    /// @return Address associated with the chainId-name pair.
    function getAddress(uint64 _chainId, bytes32 _name) external view returns (address);
}


// File: contracts/common/IAddressResolver.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IAddressResolver
/// @notice This contract acts as a bridge for name-to-address resolution.
/// It delegates the resolution to the AddressManager. By separating the logic,
/// we can maintain flexibility in address management without affecting the
/// resolving process.
/// @dev Note that the address manager should be changed using upgradability, there
/// is no setAddressManager() function to guarantee atomicity across all
/// contracts that are resolvers.
/// @custom:security-contact security@taiko.xyz
interface IAddressResolver {
    /// @notice Resolves a name to its address deployed on this chain.
    /// @param _name Name whose address is to be resolved.
    /// @param _allowZeroAddress If set to true, does not throw if the resolved
    /// address is `address(0)`.
    /// @return Address associated with the given name.
    function resolve(
        bytes32 _name,
        bool _allowZeroAddress
    )
        external
        view
        returns (address payable);

    /// @notice Resolves a name to its address deployed on a specified chain.
    /// @param _chainId The chainId of interest.
    /// @param _name Name whose address is to be resolved.
    /// @param _allowZeroAddress If set to true, does not throw if the resolved
    /// address is `address(0)`.
    /// @return Address associated with the given name on the specified
    /// chain.
    function resolve(
        uint64 _chainId,
        bytes32 _name,
        bool _allowZeroAddress
    )
        external
        view
        returns (address payable);
}


// File: node_modules/@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;
import {Initializable} from "../proxy/utils/Initializable.sol";

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

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


