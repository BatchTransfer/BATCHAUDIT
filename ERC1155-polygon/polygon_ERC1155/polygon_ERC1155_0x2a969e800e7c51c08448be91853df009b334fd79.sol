// Chain: POLYGON - File: @openzeppelin/contracts/security/ReentrancyGuard.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
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
}


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

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


// Chain: POLYGON - File: @openzeppelin/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

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
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
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


// Chain: POLYGON - File: contracts/interfaces/staking/IWETH.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint amount) external;

    function approve(address spender, uint amount) external returns (bool);
}


// Chain: POLYGON - File: contracts/interfaces/zap/ISWManager.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

/// @author Solid World
/// @dev The minimal interface used to interact with SolidWorldManager
interface ISWManager {
    function collateralizeBatch(
        uint batchId,
        uint amountIn,
        uint amountOutMin
    ) external;

    function bulkDecollateralizeTokens(
        uint[] calldata batchIds,
        uint[] calldata amountsIn,
        uint[] calldata amountsOutMin
    ) external;

    function getBatchCategory(uint batchId) external view returns (uint);
}


// Chain: POLYGON - File: contracts/interfaces/zap/ISolidZapDecollateralize.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

/// @author Solid World
interface ISolidZapDecollateralize {
    event ZapDecollateralize(
        address indexed receiver,
        address indexed inputToken,
        uint indexed inputAmount,
        uint dust,
        address dustRecipient,
        uint categoryId
    );

    struct DecollateralizeParams {
        uint[] batchIds;
        uint[] amountsIn;
        uint[] amountsOutMin;
    }

    function router() external view returns (address);

    function weth() external view returns (address);

    function swManager() external view returns (address);

    function forwardContractBatch() external view returns (address);

    /// @notice Zap function that achieves the following:
    /// 1. Swaps `inputToken` to `crispToken` via encoded swap
    /// 2. Decollateralizes resulting tokens to forward credits via SolidWorldManager
    /// 3. Transfers resulting forward credits to `msg.sender`
    /// 4. Transfers remaining crisp token balance of SolidZapDecollateralize to the `dustRecipient`
    /// @notice The `msg.sender` must own `inputAmount` and approve this contract to spend `inputToken`
    /// @param inputToken The token used for redeeming forward credits
    /// @param inputAmount The amount of `inputToken` to use
    /// @param crispToken The intermediate token used for redeeming forward credits
    /// @param swap Encoded swap from `inputToken` to `crispToken`
    /// @param dustRecipient Address to receive any remaining crisp tokens dust
    /// @param decollateralizeParams Parameters for decollateralization
    ///  batchIds The batch ids of the forward credits to redeem
    ///  amountsIn The amounts of `crispToken` to used to redeem forward credits
    ///  amountsOutMin The minimum amounts of forward credits to receive
    function zapDecollateralize(
        address inputToken,
        uint inputAmount,
        address crispToken,
        bytes calldata swap,
        address dustRecipient,
        DecollateralizeParams calldata decollateralizeParams
    ) external;

    /// @notice Zap function that achieves the following:
    /// 1. Swaps `inputToken` to `crispToken` via encoded swap
    /// 2. Decollateralizes resulting tokens to forward credits via SolidWorldManager
    /// 3. Transfers resulting forward credits to `zapRecipient`
    /// 4. Transfers remaining crisp token balance of SolidZapDecollateralize to the `dustRecipient`
    /// @notice The msg.sender must own `inputAmount` and approve this contract to spend `inputToken`
    /// @param inputToken The token used for redeeming forward credits
    /// @param inputAmount The amount of `inputToken` to use
    /// @param crispToken The intermediate token used for redeeming forward credits
    /// @param swap Encoded swap from `inputToken` to `crispToken`
    /// @param dustRecipient Address to receive any remaining crisp tokens dust
    /// @param decollateralizeParams Parameters for decollateralization
    ///  batchIds The batch ids of the forward credits to redeem
    ///  amountsIn The amounts of `crispToken` to used to redeem forward credits
    ///  amountsOutMin The minimum amounts of forward credits to receive
    /// @param zapRecipient The address to receive forward credits
    function zapDecollateralize(
        address inputToken,
        uint inputAmount,
        address crispToken,
        bytes calldata swap,
        address dustRecipient,
        DecollateralizeParams calldata decollateralizeParams,
        address zapRecipient
    ) external;

    /// @notice Zap function that achieves the following:
    /// 1. Wraps `msg.value` to WETH
    /// 2. Swaps `WETH` to `crispToken` via encoded swap
    /// 3. Decollateralizes resulting tokens to forward credits via SolidWorldManager
    /// 4. Transfers resulting forward credits to `msg.sender`
    /// 5. Transfers remaining crisp token balance of SolidZapDecollateralize to the `dustRecipient`
    /// @param crispToken The intermediate token used for redeeming forward credits
    /// @param swap Encoded swap from `inputToken` to `crispToken`
    /// @param dustRecipient Address to receive any remaining crisp tokens dust
    /// @param decollateralizeParams Parameters for decollateralization
    ///  batchIds The batch ids of the forward credits to redeem
    ///  amountsIn The amounts of `crispToken` to used to redeem forward credits
    ///  amountsOutMin The minimum amounts of forward credits to receive
    function zapDecollateralizeETH(
        address crispToken,
        bytes calldata swap,
        address dustRecipient,
        DecollateralizeParams calldata decollateralizeParams
    ) external payable;

    /// @notice Zap function that achieves the following:
    /// 1. Wraps `msg.value` to WETH
    /// 2. Swaps `WETH` to `crispToken` via encoded swap
    /// 3. Decollateralizes resulting tokens to forward credits via SolidWorldManager
    /// 4. Transfers resulting forward credits to `zapRecipient`
    /// 5. Transfers remaining crisp token balance of SolidZapDecollateralize to the `dustRecipient`
    /// @param crispToken The intermediate token used for redeeming forward credits
    /// @param swap Encoded swap from `inputToken` to `crispToken`
    /// @param dustRecipient Address to receive any remaining crisp tokens dust
    /// @param decollateralizeParams Parameters for decollateralization
    ///  batchIds The batch ids of the forward credits to redeem
    ///  amountsIn The amounts of `crispToken` to used to redeem forward credits
    ///  amountsOutMin The minimum amounts of forward credits to receive
    /// @param zapRecipient The address to receive forward credits
    function zapDecollateralizeETH(
        address crispToken,
        bytes calldata swap,
        address dustRecipient,
        DecollateralizeParams calldata decollateralizeParams,
        address zapRecipient
    ) external payable;
}


// Chain: POLYGON - File: contracts/interfaces/zap/ISolidZapStaker.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

/// @author Solid World
interface ISolidZapStaker {
    error AcquiredSharesLessThanMin(uint acquired, uint min);
    error InvalidSwap();

    event ZapStake(
        address indexed zapRecipient,
        address indexed inputToken,
        uint indexed inputAmount,
        uint shares
    );

    struct Fraction {
        uint numerator;
        uint denominator;
    }

    struct SwapResult {
        address _address;
        uint balance;
    }

    struct SwapResults {
        SwapResult token0;
        SwapResult token1;
    }

    function router() external view returns (address);

    function weth() external view returns (address);

    function solidStaking() external view returns (address);

    /// @notice Zap function that achieves the following:
    /// 1. Partially swaps `inputToken` to desired token via encoded swap1
    /// 2. Partially swaps `inputToken` to desired token via encoded swap2
    /// 3. Resulting tokens are deployed as liquidity via IUniProxy & `hypervisor`
    /// 4. Shares of the deployed liquidity are staked in `solidStaking`. `zapRecipient` is the beneficiary of the staked shares
    /// @notice The msg.sender must own `inputAmount` and approve this contract to spend `inputToken`
    /// @param inputToken The token used to provide liquidity
    /// @param inputAmount The amount of `inputToken` to use
    /// @param hypervisor The hypervisor used to deploy liquidity
    /// @param swap1 Encoded swap to partially swap `inputToken` to desired token
    /// @param swap2 Encoded swap to partially swap `inputToken` to desired token
    /// @param minShares The minimum amount of liquidity shares required for transaction to succeed
    /// @param zapRecipient The beneficiary of the staked shares
    /// @return shares The amount of shares staked in `solidStaking`
    function stakeDoubleSwap(
        address inputToken,
        uint inputAmount,
        address hypervisor,
        bytes calldata swap1,
        bytes calldata swap2,
        uint minShares,
        address zapRecipient
    ) external returns (uint shares);

    /// @notice Zap function that achieves the following:
    /// 1. Partially swaps `inputToken` to desired token via encoded swap1
    /// 2. Partially swaps `inputToken` to desired token via encoded swap2
    /// 3. Resulting tokens are deployed as liquidity via IUniProxy & `hypervisor`
    /// 4. Shares of the deployed liquidity are staked in `solidStaking`. `msg.sender` is the beneficiary of the staked shares
    /// @notice The msg.sender must own `inputAmount` and approve this contract to spend `inputToken`
    /// @param inputToken The token used to provide liquidity
    /// @param inputAmount The amount of `inputToken` to use
    /// @param hypervisor The hypervisor used to deploy liquidity
    /// @param swap1 Encoded swap to partially swap `inputToken` to desired token
    /// @param swap2 Encoded swap to partially swap `inputToken` to desired token
    /// @param minShares The minimum amount of liquidity shares required for transaction to succeed
    /// @return shares The amount of shares staked in `solidStaking`
    function stakeDoubleSwap(
        address inputToken,
        uint inputAmount,
        address hypervisor,
        bytes calldata swap1,
        bytes calldata swap2,
        uint minShares
    ) external returns (uint shares);

    /// @notice Zap function that achieves the following:
    /// 1. Partially (close to 50%) swaps `inputToken` to desired token via encoded swap
    /// 3. Resulting tokens are deployed as liquidity via IUniProxy & `hypervisor`
    /// 4. Shares of the deployed liquidity are staked in `solidStaking`. `zapRecipient` is the beneficiary of the staked shares
    /// @notice The msg.sender must own `inputAmount` and approve this contract to spend `inputToken`
    /// @notice `inputToken` must be one of hypervisor's token0 or token1
    /// @param inputToken The token used to provide liquidity
    /// @param inputAmount The amount of `inputToken` to use
    /// @param hypervisor The hypervisor used to deploy liquidity
    /// @param swap Encoded swap to partially swap `inputToken` to desired token
    /// @param minShares The minimum amount of liquidity shares required for transaction to succeed
    /// @param zapRecipient The beneficiary of the staked shares
    /// @return shares The amount of shares staked in `solidStaking`
    function stakeSingleSwap(
        address inputToken,
        uint inputAmount,
        address hypervisor,
        bytes calldata swap,
        uint minShares,
        address zapRecipient
    ) external returns (uint shares);

    /// @notice Zap function that achieves the following:
    /// 1. Partially (close to 50%) swaps `inputToken` to desired token via encoded swap
    /// 3. Resulting tokens are deployed as liquidity via IUniProxy & `hypervisor`
    /// 4. Shares of the deployed liquidity are staked in `solidStaking`. `msg.sender` is the beneficiary of the staked shares
    /// @notice The msg.sender must own `inputAmount` and approve this contract to spend `inputToken`
    /// @notice `inputToken` must be one of hypervisor's token0 or token1
    /// @param inputToken The token used to provide liquidity
    /// @param inputAmount The amount of `inputToken` to use
    /// @param hypervisor The hypervisor used to deploy liquidity
    /// @param swap Encoded swap to partially swap `inputToken` to desired token
    /// @param minShares The minimum amount of liquidity shares required for transaction to succeed
    /// @return shares The amount of shares staked in `solidStaking`
    function stakeSingleSwap(
        address inputToken,
        uint inputAmount,
        address hypervisor,
        bytes calldata swap,
        uint minShares
    ) external returns (uint shares);

    /// @notice Zap function that achieves the following:
    /// 1. Wraps `msg.value` to WETH
    /// 2. Partially swaps `WETH` to desired token via encoded swap1
    /// 3. Partially swaps `WETH` to desired token via encoded swap2
    /// 4. Resulting tokens are deployed as liquidity via IUniProxy & `hypervisor`
    /// 5. Shares of the deployed liquidity are staked in `solidStaking`. `zapRecipient` is the beneficiary of the staked shares
    /// @param hypervisor The hypervisor used to deploy liquidity
    /// @param swap1 Encoded swap to partially swap `WETH` to desired token
    /// @param swap2 Encoded swap to partially swap `WETH` to desired token
    /// @param minShares The minimum amount of liquidity shares required for transaction to succeed
    /// @param zapRecipient The beneficiary of the staked shares
    /// @return shares The amount of shares staked in `solidStaking`
    function stakeETH(
        address hypervisor,
        bytes calldata swap1,
        bytes calldata swap2,
        uint minShares,
        address zapRecipient
    ) external payable returns (uint shares);

    /// @notice Zap function that achieves the following:
    /// 1. Wraps `msg.value` to WETH
    /// 2. Partially swaps `WETH` to desired token via encoded swap1
    /// 3. Partially swaps `WETH` to desired token via encoded swap2
    /// 4. Resulting tokens are deployed as liquidity via IUniProxy & `hypervisor`
    /// 5. Shares of the deployed liquidity are staked in `solidStaking`. `msg.sender` is the beneficiary of the staked shares
    /// @param hypervisor The hypervisor used to deploy liquidity
    /// @param swap1 Encoded swap to partially swap `WETH` to desired token
    /// @param swap2 Encoded swap to partially swap `WETH` to desired token
    /// @param minShares The minimum amount of liquidity shares required for transaction to succeed
    /// @return shares The amount of shares staked in `solidStaking`
    function stakeETH(
        address hypervisor,
        bytes calldata swap1,
        bytes calldata swap2,
        uint minShares
    ) external payable returns (uint shares);

    /// @notice Function is meant to be called off-chain with _staticCall_.
    /// @notice Zap function that achieves the following:
    /// 1. Partially swaps `inputToken` to desired token via encoded swap1
    /// 2. Partially swaps `inputToken` to desired token via encoded swap2
    /// 3. Resulting tokens are checked against Gamma Vault to determine if they qualify for a dustless liquidity deployment
    ///     * if dustless, the function deploys the liquidity to obtain the amounts of shares getting minted and returns
    ///     * if not dustless, the function computes the current gamma token ratio and returns
    /// @notice The msg.sender must own `inputAmount` and approve this contract to spend `inputToken`
    /// @param inputToken The token used to provide liquidity
    /// @param inputAmount The amount of `inputToken` to use
    /// @param hypervisor The hypervisor used to deploy liquidity
    /// @param swap1 Encoded swap to partially swap `inputToken` to desired token
    /// @param swap2 Encoded swap to partially swap `inputToken` to desired token
    /// @return isDustless Whether the resulting tokens qualify for a dustless liquidity deployment
    /// @return shares The amount of shares minted from the dustless liquidity deployment
    /// @return ratio The current gamma token ratio, or empty if dustless
    function simulateStakeDoubleSwap(
        address inputToken,
        uint inputAmount,
        address hypervisor,
        bytes calldata swap1,
        bytes calldata swap2
    )
        external
        returns (
            bool isDustless,
            uint shares,
            Fraction memory ratio
        );

    /// @notice Function is meant to be called off-chain with _staticCall_.
    /// @notice Zap function that achieves the following:
    /// 1. Wraps `msg.value` to WETH
    /// 2. Partially swaps `WETH` to desired token via encoded swap1
    /// 3. Partially swaps `WETH` to desired token via encoded swap2
    /// 4. Resulting tokens are checked against Gamma Vault to determine if they qualify for a dustless liquidity deployment
    ///     * if dustless, the function deploys the liquidity to obtain the amounts of shares getting minted and returns
    ///     * if not dustless, the function computes the current gamma token ratio and returns
    /// @param hypervisor The hypervisor used to deploy liquidity
    /// @param swap1 Encoded swap to partially swap `WETH` to desired token
    /// @param swap2 Encoded swap to partially swap `WETH` to desired token
    /// @return isDustless Whether the resulting tokens qualify for a dustless liquidity deployment
    /// @return shares The amount of shares minted from the dustless liquidity deployment
    /// @return ratio The current gamma token ratio, or empty if dustless
    function simulateStakeETH(
        address hypervisor,
        bytes calldata swap1,
        bytes calldata swap2
    )
        external
        payable
        returns (
            bool isDustless,
            uint shares,
            Fraction memory ratio
        );

    /// @notice Function is meant to be called off-chain with _staticCall_.
    /// @notice Zap function that achieves the following:
    /// 1. Partially (close to 50%) swaps `inputToken` to desired token via encoded swap
    /// 2. Resulting tokens are checked against Gamma Vault to determine if they qualify for a dustless liquidity deployment
    ///     * if dustless, the function deploys the liquidity to obtain the amounts of shares getting minted and returns
    ///     * if not dustless, the function computes the current gamma token ratio and returns
    /// @notice The msg.sender must own `inputAmount` and approve this contract to spend `inputToken`
    /// @notice `inputToken` must be one of hypervisor's token0 or token1
    /// @param inputToken The token used to provide liquidity
    /// @param inputAmount The amount of `inputToken` to use
    /// @param hypervisor The hypervisor used to deploy liquidity
    /// @param swap Encoded swap to partially (close to 50%) swap `inputToken` to desired token
    /// @return isDustless Whether the resulting tokens qualify for a dustless liquidity deployment
    /// @return shares The amount of shares minted from the dustless liquidity deployment
    /// @return ratio The current gamma token ratio, or empty if dustless
    function simulateStakeSingleSwap(
        address inputToken,
        uint inputAmount,
        address hypervisor,
        bytes calldata swap
    )
        external
        returns (
            bool isDustless,
            uint shares,
            Fraction memory ratio
        );
}


// Chain: POLYGON - File: contracts/libraries/GPv2SafeERC20_0_8_18.sol
// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Gnosis Protocol v2 Safe ERC20 Transfer Library
/// @author Gnosis Developers
/// @dev Gas-efficient version of Openzeppelin's SafeERC20 contract.
library GPv2SafeERC20 {
    /// @dev Wrapper around a call to the ERC20 function `transfer` that reverts
    /// also when the token returns `false`.
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        bytes4 selector_ = token.transfer.selector;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, selector_)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), value)

            if iszero(call(gas(), token, 0, freeMemoryPointer, 68, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        require(getLastTransferResult(token), "GPv2: failed transfer");
    }

    /// @dev Wrapper around a call to the ERC20 function `transferFrom` that
    /// reverts also when the token returns `false`.
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        bytes4 selector_ = token.transferFrom.selector;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, selector_)
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 68), value)

            if iszero(call(gas(), token, 0, freeMemoryPointer, 100, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        require(getLastTransferResult(token), "GPv2: failed transferFrom");
    }

    /// @dev Verifies that the last return was a successful `transfer*` call.
    /// This is done by checking that the return data is either empty, or
    /// is a valid ABI encoded boolean.
    function getLastTransferResult(IERC20 token) private view returns (bool success) {
        // NOTE: Inspecting previous return data requires assembly. Note that
        // we write the return data to memory 0 in the case where the return
        // data size is 32, this is OK since the first 64 bytes of memory are
        // reserved by Solidy as a scratch space that can be used within
        // assembly blocks.
        // <https://docs.soliditylang.org/en/v0.7.6/internals/layout_in_memory.html>
        // solhint-disable-next-line no-inline-assembly
        assembly {
            /// @dev Revert with an ABI encoded Solidity error with a message
            /// that fits into 32-bytes.
            ///
            /// An ABI encoded Solidity error has the following memory layout:
            ///
            /// ------------+----------------------------------
            ///  byte range | value
            /// ------------+----------------------------------
            ///  0x00..0x04 |        selector("Error(string)")
            ///  0x04..0x24 |      string offset (always 0x20)
            ///  0x24..0x44 |                    string length
            ///  0x44..0x64 | string value, padded to 32-bytes
            function revertWithMessage(length, message) {
                mstore(0x00, "\x08\xc3\x79\xa0")
                mstore(0x04, 0x20)
                mstore(0x24, length)
                mstore(0x44, message)
                revert(0x00, 0x64)
            }

            switch returndatasize()
            // Non-standard ERC20 transfer without return.
            case 0 {
                // NOTE: When the return data size is 0, verify that there
                // is code at the address. This is done in order to maintain
                // compatibility with Solidity calling conventions.
                // <https://docs.soliditylang.org/en/v0.7.6/control-structures.html#external-function-calls>
                if iszero(extcodesize(token)) {
                    revertWithMessage(20, "GPv2: not a contract")
                }

                success := 1
            }
            // Standard ERC20 transfer returning boolean success value.
            case 32 {
                returndatacopy(0, 0, returndatasize())

                // NOTE: For ABI encoding v1, any non-zero value is accepted
                // as `true` for a boolean. In order to stay compatible with
                // OpenZeppelin's `SafeERC20` library which is known to work
                // with the existing ERC20 implementation we care about,
                // make sure we return success for any non-zero return value
                // from the `transfer*` call.
                success := iszero(iszero(mload(0)))
            }
            default {
                revertWithMessage(31, "GPv2: malformed transfer result")
            }
        }
    }
}


// Chain: POLYGON - File: contracts/libraries/SafeTransferLib.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Simply use address for `token` parameter
library SafeTransferLib {
    function safeApprove(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "APPROVE_FAILED");
    }
}


// Chain: POLYGON - File: contracts/zap/BaseZap.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/staking/IWETH.sol";
import "../interfaces/zap/ISolidZapStaker.sol";
import "../interfaces/zap/ISWManager.sol";
import "../libraries/GPv2SafeERC20_0_8_18.sol";
import "../libraries/SafeTransferLib.sol";

/// @author Solid World
abstract contract BaseZap {
    using GPv2SafeERC20 for IERC20;
    using SafeTransferLib for address;

    error GenericSwapError();
    error InvalidInput();
    error SweepAmountZero();

    function _swapViaRouter(address router, bytes calldata encodedSwap) internal {
        (bool success, bytes memory retData) = router.call(encodedSwap);

        if (!success) {
            _propagateError(retData);
        }
    }

    function _propagateError(bytes memory revertReason) internal pure {
        if (revertReason.length == 0) {
            revert GenericSwapError();
        }

        assembly {
            revert(add(32, revertReason), mload(revertReason))
        }
    }

    function _wrap(address weth, uint amount) internal {
        IWETH(weth).deposit{ value: amount }();
    }

    function _approveTokenSpendingIfNeeded(address token, address spender) internal {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            token.safeApprove(spender, type(uint).max);
        }
    }

    function _prepareToSwap(
        address inputToken,
        uint inputAmount,
        address _router
    ) internal {
        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), inputAmount);
        _approveTokenSpendingIfNeeded(inputToken, _router);
    }

    function _sweepTokensTo(address token, address zapRecipient) internal returns (uint sweptAmount) {
        sweptAmount = _sweepTokensTo(token, zapRecipient, false);
    }

    function _sweepTokensTo(
        address token,
        address zapRecipient,
        bool revertOnSweepAmountZero
    ) internal returns (uint sweptAmount) {
        sweptAmount = IERC20(token).balanceOf(address(this));
        if (sweptAmount == 0 && revertOnSweepAmountZero) {
            revert SweepAmountZero();
        }

        if (sweptAmount > 0) {
            IERC20(token).safeTransfer(zapRecipient, sweptAmount);
        }
    }
}


// Chain: POLYGON - File: contracts/zap/decollateralize/BaseSolidZapDecollateralize.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../../interfaces/zap/ISolidZapDecollateralize.sol";
import "../../interfaces/staking/IWETH.sol";
import "../BaseZap.sol";

/// @author Solid World
abstract contract BaseSolidZapDecollateralize is
    BaseZap,
    ISolidZapDecollateralize,
    IERC1155Receiver,
    ReentrancyGuard
{
    address public immutable router;
    address public immutable weth;
    address public immutable swManager;
    address public immutable forwardContractBatch;

    constructor(
        address _router,
        address _weth,
        address _swManager,
        address _forwardContractBatch
    ) {
        router = _router;
        weth = _weth;
        swManager = _swManager;
        forwardContractBatch = _forwardContractBatch;

        IWETH(weth).approve(_router, type(uint).max);
    }

    /// @dev accept transfers from swManager contract only
    function onERC1155Received(
        address operator,
        address,
        uint,
        uint,
        bytes memory
    ) public virtual returns (bytes4) {
        if (operator != swManager) {
            return bytes4(0);
        }

        return this.onERC1155Received.selector;
    }

    /// @dev accept transfers from swManager contract only
    function onERC1155BatchReceived(
        address operator,
        address,
        uint[] memory,
        uint[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        if (operator != swManager) {
            return bytes4(0);
        }

        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        // ERC165 && ERC1155TokenReceiver support
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x4e2312e0;
    }
}


// Chain: POLYGON - File: contracts/zap/decollateralize/SolidZapDecollateralize.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "./BaseSolidZapDecollateralize.sol";

/// @author Solid World
contract SolidZapDecollateralize is BaseSolidZapDecollateralize {
    using GPv2SafeERC20 for IERC20;

    constructor(
        address _router,
        address _weth,
        address _swManager,
        address _forwardContractBatch
    ) BaseSolidZapDecollateralize(_router, _weth, _swManager, _forwardContractBatch) {}

    /// @inheritdoc ISolidZapDecollateralize
    function zapDecollateralize(
        address inputToken,
        uint inputAmount,
        address crispToken,
        bytes calldata swap,
        address dustRecipient,
        DecollateralizeParams calldata decollateralizeParams
    ) external nonReentrant {
        _prepareToSwap(inputToken, inputAmount, router);
        _zapDecollateralize(
            inputToken,
            inputAmount,
            crispToken,
            swap,
            dustRecipient,
            decollateralizeParams,
            msg.sender
        );
    }

    /// @inheritdoc ISolidZapDecollateralize
    function zapDecollateralize(
        address inputToken,
        uint inputAmount,
        address crispToken,
        bytes calldata swap,
        address dustRecipient,
        DecollateralizeParams calldata decollateralizeParams,
        address zapRecipient
    ) external nonReentrant {
        _prepareToSwap(inputToken, inputAmount, router);
        _zapDecollateralize(
            inputToken,
            inputAmount,
            crispToken,
            swap,
            dustRecipient,
            decollateralizeParams,
            zapRecipient
        );
    }

    /// @inheritdoc ISolidZapDecollateralize
    function zapDecollateralizeETH(
        address crispToken,
        bytes calldata swap,
        address dustRecipient,
        DecollateralizeParams calldata decollateralizeParams
    ) external payable nonReentrant {
        _wrap(weth, msg.value);
        _zapDecollateralize(
            weth,
            msg.value,
            crispToken,
            swap,
            dustRecipient,
            decollateralizeParams,
            msg.sender
        );
    }

    /// @inheritdoc ISolidZapDecollateralize
    function zapDecollateralizeETH(
        address crispToken,
        bytes calldata swap,
        address dustRecipient,
        DecollateralizeParams calldata decollateralizeParams,
        address zapRecipient
    ) external payable nonReentrant {
        _wrap(weth, msg.value);
        _zapDecollateralize(
            weth,
            msg.value,
            crispToken,
            swap,
            dustRecipient,
            decollateralizeParams,
            zapRecipient
        );
    }

    function _zapDecollateralize(
        address inputToken,
        uint inputAmount,
        address crispToken,
        bytes calldata swap,
        address dustRecipient,
        DecollateralizeParams calldata decollateralizeParams,
        address zapRecipient
    ) private {
        _swapViaRouter(router, swap);
        _approveTokenSpendingIfNeeded(crispToken, swManager);
        ISWManager(swManager).bulkDecollateralizeTokens(
            decollateralizeParams.batchIds,
            decollateralizeParams.amountsIn,
            decollateralizeParams.amountsOutMin
        );
        IERC1155(forwardContractBatch).safeBatchTransferFrom(
            address(this),
            zapRecipient,
            decollateralizeParams.batchIds,
            _getDecollateralizedForwardCreditAmounts(decollateralizeParams.batchIds),
            ""
        );
        uint dustAmount = _sweepTokensTo(crispToken, dustRecipient);
        uint categoryId = ISWManager(swManager).getBatchCategory(decollateralizeParams.batchIds[0]);

        emit ZapDecollateralize(zapRecipient, inputToken, inputAmount, dustAmount, dustRecipient, categoryId);
    }

    function _getDecollateralizedForwardCreditAmounts(uint[] calldata batchIds)
        private
        view
        returns (uint[] memory decollateralizedForwardCreditAmounts)
    {
        address[] memory addresses = new address[](1);
        addresses[0] = address(this);
        decollateralizedForwardCreditAmounts = IERC1155(forwardContractBatch).balanceOfBatch(
            addresses,
            batchIds
        );
    }
}