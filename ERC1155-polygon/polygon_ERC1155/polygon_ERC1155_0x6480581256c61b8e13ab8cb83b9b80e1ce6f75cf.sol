// Chain: POLYGON - File: tenderly/personal/contracts/atomicDirect/DirectTransactionAtomicWrapper.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./Access.sol";
import "./Utils.sol";
import "./TokenHandler.sol";

uint8 constant VERSION = 2;

contract DirectTransactionAtomicWrapper is TokenHandler, Utils {
    struct ExternalCall {
        address payable contractAddress;
        uint256 value;
        bytes data;
    }

    error MarketplaceCallFailed(string reason);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // constructor
    // This initializer will not be called again when the contract is upgraded
    function initialize(
        address[] memory whitelistedCallers
    ) external initializer {
        __Utils_init(whitelistedCallers);
        __TokenHandler_init();
    }

    // constructor for upgrades
    function reinitialize()
        external
        reinitializer(VERSION)
        onlyWhitelistedCaller
    {
        __TokenHandler_init();
    }

    receive() external payable {}

    /**
     * @notice Executes atomic transaction of any token when token ID is unknown i.e. primary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        uint256 quantity,
        bool isErc721
    ) external onlyWhitelistedCaller primarySale(buyer, quantity, isErc721) {
        _callMarketplace(marketplaceAddress, marketplaceData, value);
    }

    /**
     * @notice Approves ERC20 spending and executes atomic transaction of any token when token ID is unknown
     * i.e. primary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        uint256 quantity,
        bool isErc721,
        address erc20Address
    ) external onlyWhitelistedCaller primarySale(buyer, quantity, isErc721) {
        approveCurrencySpending(erc20Address, marketplaceAddress, value);
        _callMarketplace(marketplaceAddress, marketplaceData, 0);
    }

    /**
     * @notice Approves ERC20 spending by spender and executes atomic transaction of any token when token ID is unknown
     * i.e. primary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        uint256 quantity,
        bool isErc721,
        address erc20Address,
        address erc20Spender
    ) external onlyWhitelistedCaller primarySale(buyer, quantity, isErc721) {
        approveCurrencySpending(erc20Address, erc20Spender, value);
        _callMarketplace(marketplaceAddress, marketplaceData, 0);
    }

    /**
     * @notice Executes atomic transaction of ERC721 when token ID is known i.e. secondary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        address tokenAddress,
        uint256 tokenId
    ) external onlyWhitelistedCaller {
        _callMarketplace(marketplaceAddress, marketplaceData, value);
        _transferErc721Token(buyer, tokenAddress, tokenId);
    }

    /**
     * @notice Approves ERC20 spending and executes atomic transaction of ERC721 when token ID is known
     * i.e. secondary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        address tokenAddress,
        uint256 tokenId,
        address erc20Address
    ) external onlyWhitelistedCaller {
        approveCurrencySpending(erc20Address, marketplaceAddress, value);
        _callMarketplace(marketplaceAddress, marketplaceData, 0);
        _transferErc721Token(buyer, tokenAddress, tokenId);
    }

    /**
     * @notice Approves ERC20 spending by spender and executes atomic transaction of ERC721 when token ID is known
     * i.e. secondary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        address tokenAddress,
        uint256 tokenId,
        address erc20Address,
        address erc20Spender
    ) external onlyWhitelistedCaller {
        approveCurrencySpending(erc20Address, erc20Spender, value);
        _callMarketplace(marketplaceAddress, marketplaceData, 0);
        _transferErc721Token(buyer, tokenAddress, tokenId);
    }

    /**
     * @notice Executes atomic transaction of ERC1155 when token ID is known i.e. secondary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        address tokenAddress,
        uint256 tokenId,
        uint256 quantity
    ) external onlyWhitelistedCaller {
        _callMarketplace(marketplaceAddress, marketplaceData, value);
        _transferErc1155Token(buyer, tokenAddress, tokenId, quantity);
    }

    /**
     * @notice Approves ERC20 spending and executes atomic transaction of ERC1155 when token ID is known
     * i.e. secondary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        address tokenAddress,
        uint256 tokenId,
        uint256 quantity,
        address erc20Address
    ) external onlyWhitelistedCaller {
        approveCurrencySpending(erc20Address, marketplaceAddress, value);
        _callMarketplace(marketplaceAddress, marketplaceData, 0);
        _transferErc1155Token(buyer, tokenAddress, tokenId, quantity);
    }

    /**
     * @notice Approves ERC20 spending by spender and executes atomic transaction of ERC1155 when token ID is known
     * i.e. secondary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        address tokenAddress,
        uint256 tokenId,
        uint256 quantity,
        address erc20Address,
        address erc20Spender
    ) external onlyWhitelistedCaller {
        approveCurrencySpending(erc20Address, erc20Spender, value);
        _callMarketplace(marketplaceAddress, marketplaceData, 0);
        _transferErc1155Token(buyer, tokenAddress, tokenId, quantity);
    }

    /**
     * @notice Executes atomic transaction of batch ERC1155 when token ID is known i.e. secondary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        address tokenAddress,
        uint256[] calldata tokenIds,
        uint256[] calldata quantities
    ) external onlyWhitelistedCaller {
        _callMarketplace(marketplaceAddress, marketplaceData, value);
        _batchTransferErc1155Token(buyer, tokenAddress, tokenIds, quantities);
    }

    /**
     * @notice Approves ERC20 spending and executes atomic transaction of batch ERC1155 when token ID is known
     * i.e. secondary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        address tokenAddress,
        uint256[] calldata tokenIds,
        uint256[] calldata quantities,
        address erc20Address
    ) external onlyWhitelistedCaller {
        approveCurrencySpending(erc20Address, marketplaceAddress, value);
        _callMarketplace(marketplaceAddress, marketplaceData, 0);
        _batchTransferErc1155Token(buyer, tokenAddress, tokenIds, quantities);
    }

    /**
     * @notice Approves ERC20 spending by spender and executes atomic
     * transaction of batch ERC1155 when token ID is known i.e. secondary sale
     */
    function executeAtomic(
        address payable marketplaceAddress,
        bytes calldata marketplaceData,
        uint256 value,
        address buyer,
        address tokenAddress,
        uint256[] calldata tokenIds,
        uint256[] calldata quantities,
        address erc20Address,
        address erc20SpenderAddress
    ) external onlyWhitelistedCaller {
        approveCurrencySpending(erc20Address, erc20SpenderAddress, value);
        _callMarketplace(marketplaceAddress, marketplaceData, 0);
        _batchTransferErc1155Token(buyer, tokenAddress, tokenIds, quantities);
    }

    /**
     * @notice Executes custom atomic transactions that won't work with executeAtomic
     * @dev Uses onERC721Received / onERC1155Received / onERC1155BatchReceived to transfer tokens
     */
    function executeCustomAtomic(
        ExternalCall[] calldata calls,
        address buyer,
        uint256 quantity,
        bool isErc721
    ) external onlyWhitelistedCaller primarySale(buyer, quantity, isErc721) {
        executeCustomAtomic(calls);
    }

    /**
     * @notice Executes custom atomic transactions that won't work with executeAtomic
     */
    function executeCustomAtomic(
        ExternalCall[] calldata calls
    ) public onlyWhitelistedCaller {
        uint256 callsCount = calls.length;

        for (uint256 i; i < callsCount; ) {
            _callMarketplace(
                calls[i].contractAddress,
                calls[i].data,
                calls[i].value
            );

            unchecked {
                ++i;
            }
        }
    }

    function _callMarketplace(
        address payable contractAddress,
        bytes calldata data,
        uint256 value
    ) private {
        (bool success, bytes memory returnData) = contractAddress.call{
            value: value
        }(data);

        if (!success) {
            revert MarketplaceCallFailed(_getRevertMsg(returnData));
        }
    }
}


// Chain: POLYGON - File: tenderly/personal/contracts/atomicDirect/TokenHandler.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./DeliveryHandler.sol";

contract TokenHandler is
    DeliveryHandler,
    ERC1155Receiver,
    IERC721Receiver,
    Initializable
{
    // deprecated
    struct PrimaryErc721 {
        address tokenAddress;
        uint256 tokenId;
    }

    struct PrimaryErc1155 {
        address tokenAddress;
        uint256 tokenId;
        uint256 quantity;
    }

    struct PrimaryErc1155Batch {
        address tokenAddress;
        uint256[] tokenIds;
        uint256[] quantities;
    }

    // non-zero uint256 are cheaper than booleans
    uint256 private constant _SALE_TYPE_PRIMARY = 1;

    uint256 private constant _SALE_TYPE_SECONDARY = 2;

    uint256 private constant _ERC_1155_SINGLE = 1;

    uint256 private constant _ERC_1155_BATCH = 2;

    uint256 private constant _PRIMARY_ERC721_IDS_INITIAL_SIZE = 100;

    // deprecated
    address private _unknownTokenRecipient;

    // deprecated
    PrimaryErc721[] private _primaryErc721s;

    PrimaryErc1155 private _primaryErc1155;

    PrimaryErc1155Batch private _primaryErc1155Batch;

    uint256 private _saleType;

    address private _primaryErc721Address;

    uint256[] private _primaryErc721Ids;

    uint256 private _primaryErc721RemainingQuantity;

    /// @custom:oz-renamed-from _isPrimaryBatch
    uint256 private _transferMode;

    uint256[36] private __gap_token_handler;

    // constructor
    function __TokenHandler_init() internal onlyInitializing {
        // initializing first 100 ERC721 token IDs with arbitrary values
        for (uint256 i; i < _PRIMARY_ERC721_IDS_INITIAL_SIZE; ) {
            _primaryErc721Ids.push(42);
            unchecked {
                ++i;
            }
        }
        // 1 is the default value for the remaining quantity, it's cheaper than 0
        _primaryErc721RemainingQuantity = 1;
        // secondary sale type has no side effects in onERC721Received / onERC1155Received / onERC1155BatchReceived
        _saleType = _SALE_TYPE_SECONDARY;
    }

    /**
     * @notice This modifier must be applied to every primary execute atomic function
     */
    modifier primarySale(
        address buyer,
        uint256 quantity,
        bool isErc721
    ) {
        // sets _saleType to _SALE_TYPE_PRIMARY
        // sets _primaryErc721RemainingQuantity to quantity
        _startReceivingPrimaryTokens(quantity, isErc721);
        _;
        _completePrimary(buyer, quantity, isErc721);
    }

    /**
     * @notice Handle the receipt of an NFT
     * @dev This function handles ERC721 token transfer during the primary flow when minted token ID is unknown.
     * The ERC721 smart contract calls this function on the recipient
     * after a `transfer`. This function MAY throw to revert and reject the
     * transfer. Return of other than the magic value MUST result in the
     * transaction being reverted.
     * Note: the contract address is always the message sender.
     * @param tokenId The NFT identifier which is being transferred
     * @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     */
    function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        if (_isPrimary()) {
            // this function calls _stopReceivingPrimaryTokens at the end
            // all subsequent calls will simply return the magic value
            _onERC721ReceivedPrimary(tokenId);
        }

        // secondary flow
        return this.onERC721Received.selector;
    }

    /**
     * @notice Handle the receipt of a single ERC1155 token type.
     * @dev This function handles ERC1155 token transfer during the primary flow when minted token ID is unknown.
     * An ERC1155-compliant smart contract MUST call this function on the token recipient contract,
     * at the end of a `safeTransferFrom` after the balance has been updated.
     * This function MUST return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61) if it accepts the transfer.
     * This function MUST revert if it rejects the transfer.
     * Return of any other value than the prescribed keccak256 generated value
     * MUST result in the transaction being reverted by the caller.
     * @param tokenId The ID of the token being transferred
     * @param quantity The amount of tokens being transferred
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     */
    function onERC1155Received(
        address,
        address,
        uint256 tokenId,
        uint256 quantity,
        bytes calldata
    ) external returns (bytes4) {
        if (_isPrimary()) {
            if (_transferMode != _ERC_1155_SINGLE) {
                _transferMode = _ERC_1155_SINGLE;
            }
            _primaryErc1155.tokenAddress = msg.sender;
            _primaryErc1155.tokenId = tokenId;
            _primaryErc1155.quantity = quantity;
            // all subsequent calls will simply return the magic value
            _stopReceivingPrimaryTokens();
        }

        // secondary flow
        return this.onERC1155Received.selector;
    }

    /**
     * @notice Handle the receipt of multiple ERC1155 token types.
     * @dev This function handles ERC1155 batch token transfer during the primary flow when minted token ID is unknown.
     * An ERC1155-compliant smart contract MUST call this function on the token recipient contract,
     * at the end of a `safeBatchTransferFrom` after the balances have been updated.
     * This function MUST return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81) if it accepts the transfer(s).
     * This function MUST revert if it rejects the transfer(s).
     * Return of any other value than the prescribed keccak256 generated value
     * MUST result in the transaction being reverted by the caller.
     * @param tokenIds An array containing ids of each token being transferred
     * (order and length must match _values array)
     * @param quantities An array containing amounts of each token being transferred
     * (order and length must match _ids array)
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata tokenIds,
        uint256[] calldata quantities,
        bytes calldata
    ) external returns (bytes4) {
        if (_isPrimary()) {
            if (_transferMode != _ERC_1155_BATCH) {
                _transferMode = _ERC_1155_BATCH;
            }
            _primaryErc1155Batch.tokenAddress = msg.sender;
            _primaryErc1155Batch.tokenIds = tokenIds;
            _primaryErc1155Batch.quantities = quantities;
            // all subsequent calls will simply return the magic value
            _stopReceivingPrimaryTokens();
        }

        // secondary flow
        return this.onERC1155BatchReceived.selector;
    }

    function _completePrimary(
        address buyer,
        uint256 expectedQuantity,
        bool isErc721
    ) private {
        if (isErc721) {
            return _completePrimaryErc721(buyer, expectedQuantity);
        }

        if (_transferMode == _ERC_1155_SINGLE) {
            return _completePrimaryErc1155(buyer, expectedQuantity);
        }

        return _completePrimaryErc1155Batch(buyer, expectedQuantity);
    }

    function _completePrimaryErc721(
        address buyer,
        uint256 expectedQuantity
    ) private {
        // _primaryErc721RemainingQuantity is always expected to be 1 at the end of the primary flow
        _validateTokensReceived(_primaryErc721RemainingQuantity, 1);
        // cache token address
        address tokenAddress = _primaryErc721Address;

        for (uint256 i; i < expectedQuantity; ) {
            _transferErc721Token(buyer, tokenAddress, _primaryErc721Ids[i]);

            unchecked {
                ++i;
            }
        }
    }

    function _completePrimaryErc1155(
        address buyer,
        uint256 expectedQuantity
    ) private {
        uint256 receivedQuantity = _primaryErc1155.quantity;
        _validateTokensReceived(receivedQuantity, expectedQuantity);
        _transferErc1155Token(
            buyer,
            _primaryErc1155.tokenAddress,
            _primaryErc1155.tokenId,
            receivedQuantity
        );
    }

    function _completePrimaryErc1155Batch(
        address buyer,
        uint256 expectedQuantity
    ) private {
        uint256[] memory tokenIds = _primaryErc1155Batch.tokenIds;
        uint256[] memory quantities = _primaryErc1155Batch.quantities;

        uint256 tokenCount = quantities.length;
        uint256 receivedQuantity;
        // calculate the total quantity received
        for (uint256 i; i < tokenCount; ) {
            unchecked {
                receivedQuantity += quantities[i];
                ++i;
            }
        }

        _validateTokensReceived(receivedQuantity, expectedQuantity);
        _batchTransferErc1155Token(
            buyer,
            _primaryErc1155Batch.tokenAddress,
            tokenIds,
            quantities
        );
    }

    function _startReceivingPrimaryTokens(
        uint256 quantity,
        bool isErc721
    ) private {
        _saleType = _SALE_TYPE_PRIMARY;
        // we need to keep track of the number of tokens received for multi ERC721 mints
        // _primaryErc721RemainingQuantity is already equal to 1 (default value)
        if (isErc721 && quantity > 1) {
            _primaryErc721RemainingQuantity = quantity;
        }
    }

    function _stopReceivingPrimaryTokens() private {
        _saleType = _SALE_TYPE_SECONDARY;
    }

    function _onERC721ReceivedPrimary(uint256 tokenId) private {
        // cache the value of _primaryErc721RemainingQuantity
        uint256 primaryErc721RemainingQuantity = _primaryErc721RemainingQuantity;
        // when primaryErc721RemainingQuantity is 1, it means that the last token is being received
        if (primaryErc721RemainingQuantity == 1) {
            _primaryErc721Address = msg.sender;
            // write the tokenId to the first index, it has to be initialised
            _primaryErc721Ids[0] = tokenId;
            return _stopReceivingPrimaryTokens();
        }

        uint256 index;
        unchecked {
            // when primaryErc721RemainingQuantity is 2, it means that the second last token is being received
            // i.e. it can be written to _primaryErc721TokenIds[1] so we need to decrement the value
            index = primaryErc721RemainingQuantity - 1;
            // decrement the remaining quantity
            --_primaryErc721RemainingQuantity;
        }

        // extend the array if required and fill it with the tokenId
        if (_PRIMARY_ERC721_IDS_INITIAL_SIZE < primaryErc721RemainingQuantity) {
            uint256 currentTokenIdsSize = _primaryErc721Ids.length;

            if (currentTokenIdsSize < primaryErc721RemainingQuantity) {
                return
                    _extendPrimaryErc721TokenIds(
                        currentTokenIdsSize,
                        primaryErc721RemainingQuantity,
                        tokenId
                    );
            }
        }

        // otherwise just write the tokenId to the primaryErc721RemainingQuantity index
        _primaryErc721Ids[index] = tokenId;
    }

    function _extendPrimaryErc721TokenIds(
        uint256 currentSize,
        uint256 requiredSize,
        uint256 tokenId
    ) private {
        uint256 delta;
        unchecked {
            delta = requiredSize - currentSize;
        }

        for (uint256 i; i < delta; ) {
            _primaryErc721Ids.push(tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function _isPrimary() private view returns (bool) {
        return _saleType == _SALE_TYPE_PRIMARY;
    }

    function _validateTokensReceived(
        uint256 receivedQuantity,
        uint256 expectedQuantity
    ) private view {
        // if it's still primary then none of onERC721Received / onERC1155Received / onERC1155BatchReceived was called
        // and _saleType was not reset properly i.e. it's not _SALE_TYPE_SECONDARY
        if (_isPrimary() || receivedQuantity != expectedQuantity) {
            revert TokenNotReceivedByBuyer(0);
        }
    }
}


// Chain: POLYGON - File: tenderly/personal/contracts/atomicDirect/Utils.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./Access.sol";

contract Utils is Access {
    uint256[48] private __gap_utils;

    error CallFailed(string reason);

    // constructor
    // This initializer will not be called again when the contract is upgraded
    function __Utils_init(
        address[] memory whitelistedCallers
    ) internal onlyInitializing {
        __Access_init(whitelistedCallers);
    }

    /**
     * @notice Allows to call any contract with any data
     * @param to The address of the contract to call
     * @param value The amount of ether to send
     * @param data The data to send
     */
    function callAny(
        address payable to,
        uint256 value,
        bytes calldata data
    ) external payable onlyWhitelistedCaller returns (bytes memory) {
        if (to == address(0)) {
            revert NullAddressCheckFailed();
        }

        (bool success, bytes memory result) = to.call{value: value}(data);

        if (!success) {
            revert CallFailed(_getRevertMsg(result));
        }

        return result;
    }

    function approveCurrencySpending(
        address erc20Address,
        address marketplaceAddress,
        uint256 amount
    ) public onlyWhitelistedCaller returns (bool) {
        IERC20 erc20Contract = IERC20(erc20Address);
        return erc20Contract.approve(marketplaceAddress, amount);
    }

    function withdrawErc20(
        address erc20Address,
        address to,
        uint256 amount
    ) external onlyWhitelistedCaller returns (bool) {
        IERC20 erc20Contract = IERC20(erc20Address);
        return erc20Contract.transfer(to, amount);
    }

    function _getRevertMsg(
        bytes memory _returnData
    ) internal pure returns (string memory) {
        // If the _returnData length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}


// Chain: POLYGON - File: tenderly/personal/contracts/atomicDirect/Access.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Access is Initializable {
    mapping(address => bool) private _whitelistedCallers;

    uint256[48] private __gap_access;

    event WhitelistedCallerAdded(address callerAddress);

    event WhitelistedCallerRemoved(address callerAddress);

    error CallerNotWhitelisted();

    error NullAddressCheckFailed();

    // constructor
    // This initializer will not be called again when the contract is upgraded
    function __Access_init(
        address[] memory callerAddresses
    ) internal onlyInitializing {
        uint256 callerCount = callerAddresses.length;

        for (uint256 i; i < callerCount; ) {
            if (callerAddresses[i] == address(0)) {
                revert NullAddressCheckFailed();
            }

            _whitelistedCallers[callerAddresses[i]] = true;
            emit WhitelistedCallerAdded(callerAddresses[i]);

            unchecked {
                ++i;
            }
        }
    }

    modifier onlyWhitelistedCaller() {
        if (!_whitelistedCallers[msg.sender]) {
            revert CallerNotWhitelisted();
        }

        _;
    }

    function whitelistCallerAddress(
        address callerAddress
    ) external onlyWhitelistedCaller {
        _whitelistedCallers[callerAddress] = true;
        emit WhitelistedCallerAdded(callerAddress);
    }

    function removeFromCallerWhitelist(
        address callerAddress
    ) external onlyWhitelistedCaller {
        delete _whitelistedCallers[callerAddress];
        emit WhitelistedCallerRemoved(callerAddress);
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/Address.sol";

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
            (isTopLevelCall && _initialized < 1) || (!Address.isContract(address(this)) && _initialized == 1),
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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC20/IERC20.sol
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


// Chain: POLYGON - File: tenderly/personal/contracts/atomicDirect/DeliveryHandler.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract DeliveryHandler {
    uint256[48] private __gap_delivery_handler;

    error TokenNotReceivedByBuyer(uint256 tokenId);

    function _transferErc721Token(
        address to,
        address tokenAddress,
        uint256 tokenId
    ) internal {
        IERC721 erc721Contract = IERC721(tokenAddress);

        erc721Contract.safeTransferFrom(address(this), to, tokenId);

        if (to != erc721Contract.ownerOf(tokenId)) {
            revert TokenNotReceivedByBuyer(tokenId);
        }
    }

    function _transferErc1155Token(
        address to,
        address tokenAddress,
        uint256 tokenId,
        uint256 quantity
    ) internal {
        IERC1155 erc1155Contract = IERC1155(tokenAddress);

        uint256 startingBalance = erc1155Contract.balanceOf(to, tokenId);

        erc1155Contract.safeTransferFrom(
            address(this),
            to,
            tokenId,
            quantity,
            ""
        );

        uint256 newBalance = erc1155Contract.balanceOf(to, tokenId);

        if (newBalance != startingBalance + quantity) {
            revert TokenNotReceivedByBuyer(tokenId);
        }
    }

    function _batchTransferErc1155Token(
        address to,
        address tokenAddress,
        uint256[] memory tokenIds,
        uint256[] memory quantities
    ) internal {
        IERC1155 erc1155Contract = IERC1155(tokenAddress);

        uint256 tokenCount = tokenIds.length;
        // We need this array cuz we need to pass array to balanceOfBatch method
        address[] memory recipients = new address[](tokenCount);

        for (uint256 i; i < tokenCount; ) {
            recipients[i] = to;
            unchecked {
                ++i;
            }
        }

        uint256[] memory startingBalances = erc1155Contract.balanceOfBatch(
            recipients,
            tokenIds
        );

        erc1155Contract.safeBatchTransferFrom(
            address(this),
            to,
            tokenIds,
            quantities,
            ""
        );

        uint256[] memory newBalances = erc1155Contract.balanceOfBatch(
            recipients,
            tokenIds
        );

        for (uint256 i; i < tokenCount; ) {
            if (newBalances[i] != startingBalances[i] + quantities[i]) {
                revert TokenNotReceivedByBuyer(tokenIds[i]);
            }

            unchecked {
                ++i;
            }
        }
    }
}


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol
// SPDX-License-Identifier: MIT
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
}


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/utils/Address.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC721/IERC721.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/utils/introspection/ERC165.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol
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


// Chain: POLYGON - File: @openzeppelin/contracts/utils/introspection/IERC165.sol
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