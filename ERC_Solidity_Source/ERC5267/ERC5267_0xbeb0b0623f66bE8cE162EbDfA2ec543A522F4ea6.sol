// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "./base/JamValidation.sol";
import "./base/JamTransfer.sol";
import "./interfaces/IJamSettlement.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title JamSettlement
/// @notice The settlement contract executes the full lifecycle of a trade on chain.
/// Solvers figure out what "interactions" to pass to this contract such that the user order is fulfilled.
/// The contract ensures that only the user agreed price can be executed and otherwise will fail to execute.
/// As long as the trade is fulfilled, the solver is allowed to keep any potential excess.
contract JamSettlement is IJamSettlement, ReentrancyGuard, JamValidation, JamTransfer {

    address public immutable bebopBlend;
    using BlendAggregateOrderLib for BlendAggregateOrder;
    using BlendMultiOrderLib for BlendMultiOrder;

    constructor(address _permit2, address _bebopBlend, address _treasuryAddress) JamPartner(_treasuryAddress) JamValidation(_permit2) {
        bebopBlend = _bebopBlend;
    }

    receive() external payable {}


    /// @inheritdoc IJamSettlement
    function settle(
        JamOrder calldata order,
        bytes calldata signature,
        JamInteraction.Data[] calldata interactions,
        bytes memory hooksData,
        address balanceRecipient
    ) external payable nonReentrant {
        JamHooks.Def memory hooks = hooksData.length != 0 ?
            abi.decode(hooksData, (JamHooks.Def)) : JamHooks.Def(new JamInteraction.Data[](0), new JamInteraction.Data[](0));
        bytes32 hooksHash = hooksData.length != 0 ? JamHooks.hash(hooks) : JamHooks.EMPTY_HOOKS_HASH;
        validateOrder(order, signature, hooksHash);
        if (hooksHash != JamHooks.EMPTY_HOOKS_HASH){
            require(JamInteraction.runInteractionsM(hooks.beforeSettle, balanceManager), BeforeSettleHooksFailed());
        }
        if (order.usingPermit2) {
            balanceManager.transferTokensWithPermit2(order, signature, hooksHash, balanceRecipient);
        } else {
            balanceManager.transferTokens(order.sellTokens, order.sellAmounts, order.taker, balanceRecipient);
        }
        require(JamInteraction.runInteractions(interactions, balanceManager), InteractionsFailed());
        uint256[] memory buyAmounts = order.buyAmounts;
        transferTokensFromContract(order.buyTokens, order.buyAmounts, buyAmounts, order.receiver, order.partnerInfo, false);
        if (order.receiver == address(this)){
            require(!hasDuplicates(order.buyTokens), DuplicateTokens());
        }
        emit BebopJamOrderFilled(
            order.nonce, order.taker, order.sellTokens, order.buyTokens, order.sellAmounts, buyAmounts
        );
        if (hooksHash != JamHooks.EMPTY_HOOKS_HASH){
            require(JamInteraction.runInteractionsM(hooks.afterSettle, balanceManager), AfterSettleHooksFailed());
        }
    }


    /// @inheritdoc IJamSettlement
    function settleInternal(
        JamOrder calldata order,
        bytes calldata signature,
        uint256[] calldata filledAmounts,
        bytes memory hooksData
    ) external payable nonReentrant {
        JamHooks.Def memory hooks = hooksData.length != 0 ?
            abi.decode(hooksData, (JamHooks.Def)) : JamHooks.Def(new JamInteraction.Data[](0),new JamInteraction.Data[](0));
        bytes32 hooksHash = hooksData.length != 0 ? JamHooks.hash(hooks) : JamHooks.EMPTY_HOOKS_HASH;
        validateOrder(order, signature, hooksHash);
        if (hooksHash != JamHooks.EMPTY_HOOKS_HASH){
            require(JamInteraction.runInteractionsM(hooks.beforeSettle, balanceManager), BeforeSettleHooksFailed());
        }
        if (order.usingPermit2) {
            balanceManager.transferTokensWithPermit2(order, signature, hooksHash, msg.sender);
        } else {
            balanceManager.transferTokens(order.sellTokens, order.sellAmounts, order.taker, msg.sender);
        }
        if (order.partnerInfo == 0){
            uint256[] calldata buyAmounts = validateFilledAmounts(filledAmounts, order.buyAmounts);
            balanceManager.transferTokens(order.buyTokens, buyAmounts, msg.sender, order.receiver);
            emit BebopJamOrderFilled(order.nonce, order.taker, order.sellTokens, order.buyTokens, order.sellAmounts, buyAmounts);
        } else {
            (
                uint256[] memory buyAmounts, uint256[] memory protocolFees, uint256[] memory partnerFees, address partner
            ) = getUpdatedAmountsAndFees(filledAmounts, order.buyAmounts, order.partnerInfo);
            balanceManager.transferTokens(order.buyTokens, buyAmounts, msg.sender, order.receiver);
            if (protocolFees.length != 0){
                balanceManager.transferTokens(order.buyTokens, protocolFees, msg.sender, protocolFeeAddress);
            }
            if (partnerFees.length != 0){
                balanceManager.transferTokens(order.buyTokens, partnerFees, msg.sender, partner);
            }
            emit BebopJamOrderFilled(order.nonce, order.taker, order.sellTokens, order.buyTokens, order.sellAmounts, buyAmounts);
        }
        if (hooksHash != JamHooks.EMPTY_HOOKS_HASH){
            require(JamInteraction.runInteractionsM(hooks.afterSettle, balanceManager), AfterSettleHooksFailed());
        }
    }


    /// @inheritdoc IJamSettlement
    function settleBatch(
        JamOrder[] calldata orders,
        bytes[] calldata signatures,
        JamInteraction.Data[] calldata interactions,
        JamHooks.Def[] calldata hooks,
        address balanceRecipient
    ) external payable nonReentrant {
        validateBatchOrders(orders, hooks, signatures);
        bool executeHooks = hooks.length != 0;
        for (uint i; i < orders.length; ++i) {
            if (executeHooks){
                require(JamInteraction.runInteractions(hooks[i].beforeSettle, balanceManager), BeforeSettleHooksFailed());
            }
            if (orders[i].usingPermit2) {
                balanceManager.transferTokensWithPermit2(
                    orders[i], signatures[i], executeHooks ? JamHooks.hash(hooks[i]) : JamHooks.EMPTY_HOOKS_HASH, balanceRecipient
                );
            } else {
                balanceManager.transferTokens(orders[i].sellTokens, orders[i].sellAmounts, orders[i].taker, balanceRecipient);
            }
        }
        require(JamInteraction.runInteractions(interactions, balanceManager), InteractionsFailed());
        for (uint i; i < orders.length; ++i) {
            uint256[] memory buyAmounts = calculateNewAmounts(i, orders);
            transferTokensFromContract(
                orders[i].buyTokens, orders[i].buyAmounts, buyAmounts, orders[i].receiver, orders[i].partnerInfo, true
            );
            emit BebopJamOrderFilled(
                orders[i].nonce, orders[i].taker, orders[i].sellTokens, orders[i].buyTokens, orders[i].sellAmounts, buyAmounts
            );
            if (executeHooks){
                require(JamInteraction.runInteractions(hooks[i].afterSettle, balanceManager), AfterSettleHooksFailed());
            }
        }
    }


    /// @inheritdoc IJamSettlement
    function settleBebopBlend(
        address takerAddress,
        IBebopBlend.BlendOrderType orderType,
        bytes memory data,
        bytes memory hooksData
    ) external payable nonReentrant {
        JamHooks.Def memory hooks = hooksData.length != 0 ?
            abi.decode(hooksData, (JamHooks.Def)) : JamHooks.Def(new JamInteraction.Data[](0),new JamInteraction.Data[](0));
        bytes32 hooksHash = hooksData.length != 0 ? JamHooks.hash(hooks) : JamHooks.EMPTY_HOOKS_HASH;
        if (hooksHash != JamHooks.EMPTY_HOOKS_HASH){
            require(JamInteraction.runInteractionsM(hooks.beforeSettle, balanceManager), BeforeSettleHooksFailed());
        }
        if (orderType == IBebopBlend.BlendOrderType.Single){
            (
                BlendSingleOrder memory order,
                IBebopBlend.MakerSignature memory makerSignature,
                IBebopBlend.OldSingleQuote memory takerQuoteInfo,
                address makerAddress,
                uint256 newFlags,
                bytes memory takerSignature
            ) = abi.decode(data, (BlendSingleOrder, IBebopBlend.MakerSignature, IBebopBlend.OldSingleQuote, address, uint256, bytes));
            balanceManager.transferTokenForBlendSingleOrder(order, takerQuoteInfo, takerSignature, takerAddress, hooksHash);
            order.maker_address = makerAddress;
            if (newFlags != 0){
                require(uint64(order.flags >> 64) == uint64(newFlags >> 64), InvalidBlendPartnerId());
                order.flags = newFlags;
            }
            approveToken(IERC20(order.taker_token), order.taker_amount, bebopBlend);
            IBebopBlend(bebopBlend).settleSingle(order, makerSignature, 0, takerQuoteInfo, "0x");
            emit BebopBlendSingleOrderFilled(
                uint128(order.flags >> 128), order.receiver, order.taker_token,
                (order.packed_commands & 0x02) != 0 ? JamOrderLib.NATIVE_TOKEN : order.maker_token, order.taker_amount,
                takerQuoteInfo.useOldAmount ? takerQuoteInfo.makerAmount : order.maker_amount
            );
        } else if (orderType == IBebopBlend.BlendOrderType.Multi){
            (
                BlendMultiOrder memory order,
                IBebopBlend.MakerSignature memory makerSignature,
                IBebopBlend.OldMultiQuote memory takerQuoteInfo,
                address makerAddress,
                uint256 newFlags,
                bytes memory takerSignature
            ) = abi.decode(data, (BlendMultiOrder, IBebopBlend.MakerSignature, IBebopBlend.OldMultiQuote, address, uint256, bytes));
            balanceManager.transferTokensForMultiBebopOrder(order, takerQuoteInfo, takerSignature, takerAddress, hooksHash);
            order.maker_address = makerAddress;
            if (newFlags != 0){
                require(uint64(order.flags >> 64) == uint64(newFlags >> 64), InvalidBlendPartnerId());
                order.flags = newFlags;
            }
            for (uint i; i < order.taker_tokens.length; ++i) {
                approveToken(IERC20(order.taker_tokens[i]), order.taker_amounts[i], bebopBlend);
            }
            IBebopBlend(bebopBlend).settleMulti(order, makerSignature, 0, takerQuoteInfo, "0x");
            emit BebopBlendMultiOrderFilled(
                uint128(order.flags >> 128), order.receiver, order.taker_tokens, order.getMakerTokens(), order.taker_amounts,
                takerQuoteInfo.useOldAmount ? takerQuoteInfo.makerAmounts : order.maker_amounts
            );
        } else if (orderType == IBebopBlend.BlendOrderType.Aggregate){
            (
                BlendAggregateOrder memory order,
                IBebopBlend.MakerSignature[] memory makerSignatures,
                IBebopBlend.OldAggregateQuote memory takerQuoteInfo,
                uint256 newFlags,
                bytes memory takerSignature
            ) = abi.decode(data, (BlendAggregateOrder, IBebopBlend.MakerSignature[], IBebopBlend.OldAggregateQuote, uint256, bytes));
            balanceManager.transferTokensForAggregateBebopOrder(order, takerQuoteInfo, takerSignature, takerAddress, hooksHash);
            if (newFlags != 0){
                require(uint64(order.flags >> 64) == uint64(newFlags >> 64), InvalidBlendPartnerId());
                order.flags = newFlags;
            }
            (address[] memory tokens, uint256[] memory amounts) = order.unpackTokensAndAmounts(true, takerQuoteInfo);
            for (uint i; i < tokens.length; ++i) {
                approveToken(IERC20(tokens[i]), amounts[i], bebopBlend);
            }
            IBebopBlend(bebopBlend).settleAggregate(order, makerSignatures, 0, takerQuoteInfo, "0x");
            (address[] memory buyTokens, uint256[] memory buyAmounts) = order.unpackTokensAndAmounts(false, takerQuoteInfo);
            emit BebopBlendAggregateOrderFilled(
                uint128(order.flags >> 128), order.receiver, tokens, buyTokens, amounts, buyAmounts
            );
        } else {
            revert InvalidBlendOrderType();
        }
        if (hooksHash != JamHooks.EMPTY_HOOKS_HASH){
            require(JamInteraction.runInteractionsM(hooks.afterSettle, balanceManager), AfterSettleHooksFailed());
        }
    }

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC1271.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC5267.sol)

pragma solidity ^0.8.20;

interface IERC5267 {
    /**
     * @dev MAY be emitted to signal that the domain could have changed.
     */
    event EIP712DomainChanged();

    /**
     * @dev returns the fields and values that describe the domain separator used by this contract for EIP-712
     * signature.
     */
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
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
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

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
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
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
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
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
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;


/// @notice Thrown when solver sends less than expected to settlement contract
error InvalidOutputBalance(address token, uint256 expected, uint256 actual);

/// @notice Thrown when sending ETH via call fails
error FailedToSendEth();

/// @notice Thrown when the passed in signature is not a valid length
error InvalidSignatureLength();

/// @notice Thrown when the recovered signer is equal to the zero address
error InvalidSignature();

/// @notice Thrown when the recovered signer does not equal the claimedSigner
error InvalidSigner();

/// @notice Thrown when the recovered contract signature is incorrect
error InvalidContractSignature();

/// @notice Thrown when msg.sender is not allowed to call a function
error InvalidExecutor();

/// @notice Thrown when length of sell tokens and sell amounts are not equal
error SellTokensInvalidLength();

/// @notice Thrown when length of buy tokens and buy amounts are not equal
error BuyTokensInvalidLength();

/// @notice Thrown when order is expired
error OrderExpired();

/// @notice Thrown when nonce is already invalidated
error InvalidNonce();

/// @notice Thrown when nonce is zero
error ZeroNonce();

/// @notice Thrown when length of filled amounts is not equal to tokens length
error InvalidFilledAmountsLength();

/// @notice Thrown when filled amounts is less than previous amount
error InvalidFilledAmounts(uint256 expected, uint256 actual);

/// @notice Thrown when length of signatures array is not equal to batch length
error InvalidBatchSignaturesLength();

/// @notice Thrown when length of hooks array is not equal to batch length
error InvalidBatchHooksLength();

/// @notice Thrown when one of the orders in batch has settlement contract as receiver
error InvalidReceiverInBatch();

/// @notice Thrown when different fees are passed in batch
error DifferentFeesInBatch();

/// @notice Thrown when invalid partner address is passed
error InvalidPartnerAddress();

/// @notice Thrown when caller is not settlement contract
error InvalidCaller();

/// @notice Thrown when interactions failed
error InteractionsFailed();

/// @notice Thrown when beforeSettle hooks failed
error BeforeSettleHooksFailed();

/// @notice Thrown when beforeSettle hooks failed
error AfterSettleHooksFailed();

/// @notice Thrown for unknown blend order type
error InvalidBlendOrderType();

/// @notice Thrown when invalid fee percentage is passed
error InvalidFeePercentage();

/// @notice Thrown when interactions contain call to balance manager
error CallToBalanceManagerNotAllowed();

/// @notice Thrown when there are duplicate buy tokens in the order
error DuplicateTokens();

/// @notice Thrown when new partner-id is different from the current one
error InvalidBlendPartnerId();

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../base/Errors.sol";
import "../libraries/JamOrder.sol";
import "../external-libs/SafeTransferLib.sol";

/// @title JamPartner
abstract contract JamPartner {

    uint16 internal constant HUNDRED_PERCENT = 10000;  // 100% in bps
    address internal immutable protocolFeeAddress;

    event NativeTransfer(address indexed receiver, uint256 amount);
    using SafeTransferLib for IERC20;

    constructor(address _protocolFeeAddress){
        protocolFeeAddress = _protocolFeeAddress;
    }

    /// @notice Distribute fees to the partner and protocol, fees are optional
    /// @param partnerInfo The partner info, packed with the partner address, partner fee and protocol fee
    /// @param token The token to distribute fees in
    /// @param amount Token amount in order to distribute fees from
    /// @return totalFeesSent The total amount of tokens sent as fees
    function distributeFees(uint256 partnerInfo, address token, uint256 amount) internal returns (uint256 totalFeesSent){
        (address partnerAddress, uint16 partnerFee, uint16 protocolFee) = unpackPartnerInfo(partnerInfo);
        if (partnerFee > 0) {
            totalFeesSent += sendPartnerFee(token, amount, partnerFee, partnerAddress);
        }
        if (protocolFee > 0) {
            totalFeesSent += sendPartnerFee(token, amount, protocolFee, protocolFeeAddress);
        }
        return totalFeesSent;
    }

    /// @notice Unpack the partner info
    /// @param partnerInfo Packed info: [ .... | address | uint16 | uint16 ]
    function unpackPartnerInfo(uint256 partnerInfo) private pure returns (address, uint16, uint16) {
        uint16 protocolFeeBps = uint16(partnerInfo & 0xFFFF);
        uint16 partnerFeeBps = uint16((partnerInfo >> 16) & 0xFFFF);
        address partnerAddress = address(uint160(partnerInfo >> 32));
        require(partnerFeeBps + protocolFeeBps < HUNDRED_PERCENT, InvalidFeePercentage());
        require(partnerFeeBps > 0 || (partnerFeeBps == 0 && partnerAddress == address(0)), InvalidPartnerAddress());
        return (partnerAddress, partnerFeeBps, protocolFeeBps);
    }

    /// @notice Send the partner fee
    /// @param token The token to send
    /// @param amount The amount to send
    /// @param fee The fee percentage
    /// @param receiver The receiver of the fee
    /// @return feeAmount The amount of fee sent
    function sendPartnerFee(address token, uint256 amount, uint16 fee, address receiver) private returns (uint256){
        uint256 feeAmount = amount * fee / HUNDRED_PERCENT;
        if (token == JamOrderLib.NATIVE_TOKEN) {
            (bool sent, ) = payable(receiver).call{value: feeAmount}("");
            require(sent, FailedToSendEth());
            emit NativeTransfer(receiver, feeAmount);
        } else {
            IERC20(token).safeTransfer(receiver, feeAmount);
        }
        return feeAmount;
    }

    /// @notice Get total fees in bps
    /// @param partnerInfo The partner info
    /// @return totalFeesBps The total fees in bps
    function getTotalFeesBps(uint256 partnerInfo) internal pure returns (uint16){
        uint16 protocolFeeBps = uint16(partnerInfo & 0xFFFF);
        uint16 partnerFeeBps = uint16((partnerInfo >> 16) & 0xFFFF);
        return protocolFeeBps + partnerFeeBps;
    }

    /// @notice Get arrays with fees amounts for each token
    /// @param amounts The amounts to calculate fees for
    /// @param minAmounts Minimum amounts that user signed for
    /// @param partnerInfo The partner info
    /// @return newAmounts The new amounts after fees
    /// @return protocolFees The protocol fees, if empty then no protocol fees
    /// @return partnerFees The partner fees, if empty then no partner fees
    /// @return partnerAddress The partner address, or zero address if no partner fees
    function getUpdatedAmountsAndFees(
        uint256[] calldata amounts, uint256[] calldata minAmounts, uint256 partnerInfo
    ) internal pure returns (uint256[] memory newAmounts, uint256[] memory protocolFees, uint256[] memory partnerFees, address) {
        (address partnerAddress, uint16 partnerFee, uint16 protocolFee) = unpackPartnerInfo(partnerInfo);
        uint tokensLength = amounts.length;
        require(minAmounts.length == tokensLength, InvalidFilledAmountsLength());
        newAmounts = new uint256[](tokensLength);
        if (protocolFee > 0) {
            protocolFees = new uint256[](tokensLength);
            for (uint256 i; i < tokensLength; ++i) {
                protocolFees[i] = amounts[i] * protocolFee / HUNDRED_PERCENT;
                newAmounts[i] = amounts[i] - protocolFees[i];
            }
        }
        if (partnerFee > 0) {
            partnerFees = new uint256[](tokensLength);
            for (uint256 i; i < tokensLength; ++i) {
                partnerFees[i] = amounts[i] * partnerFee / HUNDRED_PERCENT;
                newAmounts[i] = newAmounts[i] == 0 ? amounts[i] - partnerFees[i] : newAmounts[i] - partnerFees[i];
            }
        }
        for (uint256 i; i < tokensLength; ++i) {
            require(newAmounts[i] >= minAmounts[i], InvalidFilledAmounts(minAmounts[i], newAmounts[i]));
        }
        return (newAmounts, protocolFees, partnerFees, partnerAddress);
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "./JamPartner.sol";

/// @title JamTransfer
/// @notice Functions for transferring tokens from SettlementContract
abstract contract JamTransfer is JamPartner {

    using SafeTransferLib for IERC20;

    /// @dev Check if token is approved for spender, max approve if not
    /// max approval is fine for settlement contract, because we use BalanceManager for users approvals
    /// @param token token's address
    /// @param amount transfer amount
    /// @param spender spender's address, in our case it will BebopBlend contract
    function approveToken(IERC20 token, uint256 amount, address spender) internal {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance < amount) {
            token.safeApproveWithRetry(spender, type(uint256).max);
        }
    }

    /// @dev After solver settlement, transfer tokens from this contract to receiver
    /// @param tokens tokens' addresses
    /// @param minAmounts minimum amounts from order
    /// @param amounts tokens' filled amounts
    /// @param receiver address
    /// @param transferExactAmounts if true, transfer exact amounts, otherwise transfer full tokens balance
    function transferTokensFromContract(
        address[] calldata tokens,
        uint256[] calldata minAmounts,
        uint256[] memory amounts,
        address receiver,
        uint256 partnerInfo,
        bool transferExactAmounts
    ) internal {
        for (uint i; i < tokens.length; ++i) {
            if (!transferExactAmounts) {
                amounts[i] = tokens[i] == JamOrderLib.NATIVE_TOKEN ?
                    address(this).balance : IERC20(tokens[i]).balanceOf(address(this));
            }
            if (partnerInfo != 0){
                amounts[i] -= distributeFees(partnerInfo, tokens[i], amounts[i]);
            }
            require(amounts[i] >= minAmounts[i], InvalidOutputBalance(tokens[i], minAmounts[i], amounts[i]));
            if (tokens[i] == JamOrderLib.NATIVE_TOKEN) {
                (bool sent, ) = payable(receiver).call{value: amounts[i]}("");
                require(sent, FailedToSendEth());
                emit NativeTransfer(receiver, amounts[i]);
            } else {
                IERC20(tokens[i]).safeTransfer(receiver, amounts[i]);
            }
        }
    }

    /// @dev Transfer native tokens to receiver from this contract
    /// @param receiver address
    /// @param amount amount of native tokens
    function transferNativeFromContract(address receiver, uint256 amount) public {
        (bool sent, ) = payable(receiver).call{value: amount}("");
        require(sent, FailedToSendEth());
    }

    /// @dev Calculate new amounts of tokens if solver transferred excess to contract during settleBatch
    /// @param curInd index of current order
    /// @param orders array of orders
    /// @return array of new amounts
    function calculateNewAmounts(uint256 curInd, JamOrder[] calldata orders) internal view returns (uint256[] memory) {
        JamOrder calldata curOrder = orders[curInd];
        uint256[] memory newAmounts = new uint256[](curOrder.buyTokens.length);
        for (uint i; i < curOrder.buyTokens.length; ++i) {
            uint256 fullAmount;
            for (uint j = curInd; j < orders.length; ++j) {
                for (uint k; k < orders[j].buyTokens.length; ++k) {
                    if (orders[j].buyTokens[k] == curOrder.buyTokens[i]) {
                        fullAmount += orders[j].buyAmounts[k];
                        require(
                            getTotalFeesBps(curOrder.partnerInfo) == getTotalFeesBps(orders[j].partnerInfo),
                            DifferentFeesInBatch()
                        );
                    }
                }
            }
            uint256 tokenBalance = curOrder.buyTokens[i] == JamOrderLib.NATIVE_TOKEN ?
                address(this).balance : IERC20(curOrder.buyTokens[i]).balanceOf(address(this));
            // if at least two takers buy same token, we need to divide the whole tokenBalance among them.
            // for edge case with newAmounts[i] overflow, solver shouldn't submit txs in a batch
            newAmounts[i] = tokenBalance * curOrder.buyAmounts[i] / fullAmount;
            if (newAmounts[i] < curOrder.buyAmounts[i]) {
                newAmounts[i] = curOrder.buyAmounts[i];
            }
        }
        return newAmounts;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../base/Errors.sol";
import "../libraries/JamOrder.sol";
import "../libraries/JamHooks.sol";
import "../JamBalanceManager.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC5267.sol";

/// @title JamValidation
/// @notice Functions which handles the signing and validation of Jam orders
abstract contract JamValidation is IERC5267 {
    mapping(address => mapping(uint256 => uint256)) private standardNonces;
    mapping(address => mapping(uint256 => uint256)) private limitOrdersNonces;
    uint256 private constant INF_EXPIRY = 9999999999; // expiry for limit orders

    string public constant DOMAIN_NAME = "JamSettlement";
    string public constant DOMAIN_VERSION = "2";
    bytes32 private constant UPPER_BIT_MASK = (0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    bytes4 private constant EIP1271_MAGICVALUE = bytes4(keccak256("isValidSignature(bytes32,bytes)"));
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256(abi.encodePacked(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    ));

    IJamBalanceManager public immutable balanceManager;
    IPermit2 private immutable PERMIT2;
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;
    using JamOrderLib for JamOrder;

    constructor(address _permit2){
        balanceManager = new JamBalanceManager(address(this), _permit2);
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(DOMAIN_NAME)), keccak256(bytes(DOMAIN_VERSION)), block.chainid, address(this))
        );
        PERMIT2 = IPermit2(_permit2);
    }

    /// @notice The domain separator used in the order validation signature
    /// @return The domain separator used in encoding of order signature
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == _CACHED_CHAIN_ID
            ? _CACHED_DOMAIN_SEPARATOR
            : keccak256(
                abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(DOMAIN_NAME)), keccak256(bytes(DOMAIN_VERSION)), block.chainid, address(this))
            );
    }

    /// @notice ERC5267 implementation for requesting the EIP712 domain values
    function eip712Domain() public view returns (
        bytes1 fields, string memory name, string memory version, uint256 chainId,
        address verifyingContract, bytes32 salt, uint256[] memory extensions
    ){
        return (hex"0f", DOMAIN_NAME, DOMAIN_VERSION, block.chainid, address(this), bytes32(0), new uint256[](0));
    }

    /// @notice Validate the order signature
    /// @param validationAddress The address to validate the signature against
    /// @param hash The hash of the order
    /// @param signature The signature to validate
    function validateSignature(address validationAddress, bytes32 hash, bytes calldata signature) public view {
        bytes32 r;
        bytes32 s;
        uint8 v;
        if (validationAddress.code.length == 0) {
            if (signature.length == 65) {
                (r, s) = abi.decode(signature, (bytes32, bytes32));
                v = uint8(signature[64]);
            } else if (signature.length == 64) {
                // EIP-2098
                bytes32 vs;
                (r, vs) = abi.decode(signature, (bytes32, bytes32));
                s = vs & UPPER_BIT_MASK;
                v = uint8(uint256(vs >> 255)) + 27;
            } else {
                revert InvalidSignatureLength();
            }
            address signer = ecrecover(hash, v, r, s);
            if (signer == address(0)) revert InvalidSignature();
            if (signer != validationAddress) revert InvalidSigner();
        } else {
            bytes4 magicValue = IERC1271(validationAddress).isValidSignature(hash, signature);
            if (magicValue != EIP1271_MAGICVALUE) revert InvalidContractSignature();
        }
    }

    /// @notice Hash hooks and return the hash
    /// @param hooks The hooks to hash
    function hashHooks(JamHooks.Def calldata hooks) external pure returns (bytes32) {
        return JamHooks.hash(hooks);
    }

    /// @notice Hash Jam order and return the hash
    /// @param order The order to hash
    /// @param hooksHash The hash of the hooks to include in the order hash, 0x000..00 if no hooks
    function hashJamOrder(JamOrder calldata order, bytes32 hooksHash) external view returns (bytes32) {
        if (order.usingPermit2){
            return keccak256(abi.encodePacked(
                "\x19\x01", PERMIT2.DOMAIN_SEPARATOR(), order.permit2OrderHash(hooksHash, address(balanceManager))
            ));
        } else {
            return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), order.hash(hooksHash)));
        }
    }

    /// @notice Cancel limit order by invalidating nonce for the sender address
    /// @param nonce The nonce to invalidate
    function cancelLimitOrder(uint256 nonce) external {
        invalidateOrderNonce(msg.sender, nonce, true);
    }

    /// @notice Check if taker's limit order nonce is valid
    /// @param taker address
    /// @param nonce to check
    /// @return True if nonce is valid
    function isLimitOrderNonceValid(address taker, uint256 nonce) external view returns (bool) {
        uint256 invalidatorSlot = nonce >> 8;
        uint256 invalidatorBit = 1 << (nonce & 0xff);
        return (limitOrdersNonces[taker][invalidatorSlot] & invalidatorBit) == 0;
    }

    /// @notice Validate order data and in case of standard approvals validate the signature
    /// @param order The order to validate
    /// @param signature The signature to validate
    /// @param hooksHash The hash of the hooks to include in the order hash
    function validateOrder(JamOrder calldata order, bytes calldata signature, bytes32 hooksHash) internal {
        // Allow settle from user without sig; For permit2 case, we already validated witness during the transfer
        if (order.taker != msg.sender && !order.usingPermit2) {
            bytes32 orderHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), order.hash(hooksHash)));
            validateSignature(order.taker, orderHash, signature);
        }
        if (!order.usingPermit2 || order.expiry == INF_EXPIRY){
            invalidateOrderNonce(order.taker, order.nonce, order.expiry == INF_EXPIRY);
        }
        require(
            order.executor == msg.sender || order.executor == address(0) || block.timestamp > order.exclusivityDeadline,
            InvalidExecutor()
        );
        require(order.buyTokens.length == order.buyAmounts.length, BuyTokensInvalidLength());
        require(order.sellTokens.length == order.sellAmounts.length, SellTokensInvalidLength());
        require(block.timestamp < order.expiry, OrderExpired());
    }

    /// @notice Check if nonce is valid and invalidate it
    /// @param taker address
    /// @param nonce The nonce to invalidate
    /// @param isLimitOrder True if it is a limit order
    function invalidateOrderNonce(address taker, uint256 nonce, bool isLimitOrder) private {
        require(nonce != 0, ZeroNonce());
        uint256 invalidatorSlot = nonce >> 8;
        uint256 invalidatorBit = 1 << (nonce & 0xff);
        mapping(uint256 => uint256) storage invalidNonces = isLimitOrder ? limitOrdersNonces[taker] : standardNonces[taker];
        uint256 invalidator = invalidNonces[invalidatorSlot];
        require(invalidator & invalidatorBit != invalidatorBit, InvalidNonce());
        invalidNonces[invalidatorSlot] = invalidator | invalidatorBit;
    }

    /// @notice validate if filled amounts are more than initial amounts that user signed
    /// @param filledAmounts The increased amounts to validate (if empty, return initial amounts)
    /// @param initialAmounts The initial amounts to validate against
    /// @return The filled amounts if exist, otherwise the initial amounts
    function validateFilledAmounts(
        uint256[] calldata filledAmounts, uint256[] calldata initialAmounts
    ) internal pure returns (uint256[] calldata){
        if (filledAmounts.length == 0) {
            return initialAmounts;
        }
        require(filledAmounts.length == initialAmounts.length, InvalidFilledAmountsLength());
        for (uint256 i; i < filledAmounts.length; ++i) {
            require(filledAmounts[i] >= initialAmounts[i], InvalidFilledAmounts(initialAmounts[i], filledAmounts[i]));
        }
        return filledAmounts;
    }

    /// @notice Validate batch data and all orders in a batch
    /// @param orders The orders to validate
    /// @param hooks The array of hooks corresponding to each order, or empty array if no hooks
    /// @param signatures The signatures corresponding to each order
    function validateBatchOrders(
        JamOrder[] calldata orders, JamHooks.Def[] calldata hooks, bytes[] calldata signatures
    ) internal {
        bool noHooks = hooks.length == 0;
        require(orders.length == signatures.length, InvalidBatchSignaturesLength());
        require(orders.length == hooks.length || noHooks, InvalidBatchHooksLength());
        for (uint i; i < orders.length; ++i) {
            require(orders[i].receiver != address(this), InvalidReceiverInBatch());
            validateOrder(orders[i], signatures[i], noHooks ? JamHooks.EMPTY_HOOKS_HASH : JamHooks.hash(hooks[i]));
        }
    }

    /// @notice Check if there are any duplicates in the array of tokens
    /// @param tokens The array of tokens to validate
    /// @return True if there are duplicates
    function hasDuplicates(address[] calldata tokens) internal pure returns (bool) {
        for (uint i; i < tokens.length - 1; ++i) {
            for (uint j = i + 1; j < tokens.length; ++j) {
                if (tokens[i] == tokens[j]) {
                    return true;
                }
            }
        }
        return false;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../interfaces/IPermit2.sol";

// from PermitHash.sol in Permit2
// https://github.com/Uniswap/permit2/blob/main/src/libraries/PermitHash.sol
library PermitHash {

    bytes32 private constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    string private constant _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB = "PermitBatchWitnessTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline,";

    function hashWithWitness(
        IPermit2.PermitBatchTransferFrom memory permit,
        bytes32 witness,
        string memory witnessTypeString,
        address spender
    ) internal pure returns (bytes32) {
        bytes32 typeHash = keccak256(abi.encodePacked(_PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB, witnessTypeString));

        uint256 numPermitted = permit.permitted.length;
        bytes32[] memory tokenPermissionHashes = new bytes32[](numPermitted);

        for (uint256 i = 0; i < numPermitted; ++i) {
            tokenPermissionHashes[i] = _hashTokenPermissions(permit.permitted[i]);
        }

        return keccak256(
            abi.encode(
                typeHash,
                keccak256(abi.encodePacked(tokenPermissionHashes)),
                spender,
                permit.nonce,
                permit.deadline,
                witness
            )
        );
    }

    function _hashTokenPermissions(IPermit2.TokenPermissions memory permitted) private pure returns (bytes32){
        return keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permitted));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @notice Safe ERC20 transfer library that gracefully handles missing return values.
/// From: Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// https://github.com/Vectorized/solady/blob/main/src/utils/SafeTransferLib.sol

library SafeTransferLib {


    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "from" argument.
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
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

        require(success, "TRANSFER_FAILED");
    }


    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// If the initial attempt to approve fails, attempts to reset the approved amount to zero,
    /// then retries the approval again (some tokens, e.g. USDT, requires this).
    /// Reverts upon failure.
    function safeApproveWithRetry(IERC20 token, address to, uint256 amount) internal {
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
                pop(call(gas(), token, 0, 0x10, 0x44, codesize(), 0x00)) // Reset the approval.
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


}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../libraries/BlendSingleOrder.sol";
import "../libraries/BlendMultiOrder.sol";
import "../libraries/BlendAggregateOrder.sol";

/// @title IBebopBlend is interface for interacting with BebopBlend contract, which aggregates PMM liquidity.
/// Swaps through that contract have zero slippage.
/// Deployed on 0xbbbbbBB520d69a9775E85b458C58c648259FAD5F
interface IBebopBlend {

    enum BlendOrderType {
        Single, // 0
        Multi, // 1
        Aggregate // 2
    }

    struct OldSingleQuote {
        bool useOldAmount;
        uint256 makerAmount;
        uint256 makerNonce;
    }

    struct OldMultiQuote {
        bool useOldAmount;
        uint256[] makerAmounts;
        uint256 makerNonce;
    }

    struct OldAggregateQuote {
        bool useOldAmount;
        uint256[][] makerAmounts;
        uint256[] makerNonces;
    }

    struct MakerSignature {
        bytes signatureBytes;
        uint256 flags;
    }


    /// @notice Maker execution of one-to-one trade with one maker
    /// @param order Single order struct
    /// @param makerSignature Maker's signature for SingleOrder
    /// @param filledTakerAmount Partially filled taker amount, 0 for full fill
    /// @param takerQuoteInfo If maker_amount has improved then it contains old quote values that taker signed,
    ///                       otherwise it contains same values as in order
    /// @param takerSignature Taker's signature to approve executing order by maker,
    ///        if taker executes order himself then signature can be '0x' (recommended to use swapSingle for this case)
    function settleSingle(
        BlendSingleOrder calldata order,
        MakerSignature calldata makerSignature,
        uint256 filledTakerAmount,
        OldSingleQuote calldata takerQuoteInfo,
        bytes calldata takerSignature
    ) external payable;

    /// @notice Maker execution of one-to-many or many-to-one trade with one maker
    /// @param order Multi order struct
    /// @param makerSignature Maker's signature for MultiOrder
    /// @param filledTakerAmount Partially filled taker amount, 0 for full fill. Many-to-one doesnt support partial fill
    /// @param takerQuoteInfo If maker_amounts have improved then it contains old quote values that taker signed,
    ///                       otherwise it contains same values as in order
    /// @param takerSignature Taker's signature to approve executing order by maker,
    ///        if taker executes order himself then signature can be '0x' (recommended to use swapMulti for this case)
    function settleMulti(
        BlendMultiOrder calldata order,
        MakerSignature calldata makerSignature,
        uint256 filledTakerAmount,
        OldMultiQuote calldata takerQuoteInfo,
        bytes calldata takerSignature
    ) external payable;

    /// @notice Maker execution of any trade with multiple makers
    /// @param order Aggregate order struct
    /// @param makersSignatures Makers signatures for MultiOrder (can be contructed as part of current AggregateOrder)
    /// @param filledTakerAmount Partially filled taker amount, 0 for full fill. Many-to-one doesnt support partial fill
    /// @param takerQuoteInfo If maker_amounts have improved then it contains old quote values that taker signed,
    ///                       otherwise it contains same values as in order
    /// @param takerSignature Taker's signature to approve executing order by maker,
    ///      if taker executes order himself then signature can be '0x' (recommended to use swapAggregate for this case)
    function settleAggregate(
        BlendAggregateOrder calldata order,
        MakerSignature[] calldata makersSignatures,
        uint256 filledTakerAmount,
        OldAggregateQuote calldata takerQuoteInfo,
        bytes calldata takerSignature
    ) external payable;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../libraries/JamOrder.sol";
import "../libraries/BlendSingleOrder.sol";
import "../libraries/BlendMultiOrder.sol";
import "../libraries/BlendAggregateOrder.sol";
import "./IBebopBlend.sol";

/// @title IJamBalanceManager
/// @notice User approvals are made here. This handles the complexity of multiple allowance types. 
interface IJamBalanceManager {

    /// @dev Transfer user's tokens to receiver address for JamOrder
    /// @param order user signed order
    /// @param signature permit2 signature with order as witness
    /// @param hooksHash hash of hooks data
    /// @param receiver address to receive tokens, it can be operator address or solver address
    function transferTokensWithPermit2(
        JamOrder calldata order,
        bytes calldata signature,
        bytes32 hooksHash,
        address receiver
    ) external;

    /// @dev Transfer tokens to receiver address
    /// this function can be used not only for user's tokens, but also for maker's tokens in settleInternal
    /// @param tokens list of tokens to transfer
    /// @param amounts list of amounts to transfer
    /// @param sender address to transfer tokens from
    /// @param receiver address to transfer tokens to
    function transferTokens(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address sender,
        address receiver
    ) external;

    /// @dev Transfer user's tokens to operator address for BlendSingleOrder
    /// @param order user signed order
    /// @param oldSingleQuote in case of amounts improvement, old quote is used to get old amounts signed by user
    /// @param takerSignature permit2 signature with order as witness
    /// @param takerAddress user address
    /// @param hooksHash hash of hooks data
    function transferTokenForBlendSingleOrder(
        BlendSingleOrder memory order,
        IBebopBlend.OldSingleQuote memory oldSingleQuote,
        bytes memory takerSignature,
        address takerAddress,
        bytes32 hooksHash
    ) external;

    /// @dev Transfer user's tokens to operator address for BlendMultiOrder
    /// @param order user signed order
    /// @param oldMultiQuote in case of amounts improvement, old quote is used to get old amounts signed by user
    /// @param takerSignature permit2 signature with order as witness
    /// @param takerAddress user address
    /// @param hooksHash hash of hooks data
    function transferTokensForMultiBebopOrder(
        BlendMultiOrder memory order,
        IBebopBlend.OldMultiQuote memory oldMultiQuote,
        bytes memory takerSignature,
        address takerAddress,
        bytes32 hooksHash
    ) external;

    /// @dev Transfer user's tokens to operator address for BlendAggregateOrder
    /// @param order user signed order
    /// @param oldAggregateQuote in case of amounts improvement, old quote is used to get old amounts signed by user
    /// @param takerSignature permit2 signature with order as witness
    /// @param takerAddress user address
    /// @param hooksHash hash of hooks data
    function transferTokensForAggregateBebopOrder(
        BlendAggregateOrder memory order,
        IBebopBlend.OldAggregateQuote memory oldAggregateQuote,
        bytes memory takerSignature,
        address takerAddress,
        bytes32 hooksHash
    ) external;

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../libraries/JamInteraction.sol";
import "../libraries/JamOrder.sol";
import "../libraries/JamHooks.sol";

interface IJamSettlement {

    /// @dev Event emitted when a settlement of JamOrder is executed successfully
    event BebopJamOrderFilled(
        uint256 indexed nonce, address indexed user, address[] sellTokens, address[] buyTokens, uint256[] sellAmounts, uint256[] buyAmounts
    );

    /// @dev Event with same eventId as will be emitted by the BebopBlend contract for SingleOrder using Order.extractEventId()
    event BebopBlendSingleOrderFilled(
        uint128 indexed eventId, address indexed receiver, address sellToken, address buyToken, uint256 sellAmount, uint256 buyAmount
    );

    /// @dev Event with same eventId as will be emitted by the BebopBlend contract for MultiOrder using Order.extractEventId()
    event BebopBlendMultiOrderFilled(
        uint128 indexed eventId, address indexed receiver, address[] sellTokens, address[] buyTokens, uint256[] sellAmounts, uint256[] buyAmounts
    );

    /// @dev Event with same eventId as will be emitted by the BebopBlend contract for AggregateOrder using Order.extractEventId()
    event BebopBlendAggregateOrderFilled(
        uint128 indexed eventId, address indexed receiver, address[] sellTokens, address[] buyTokens, uint256[] sellAmounts, uint256[] buyAmounts
    );

    /// @dev Settle a jam order.
    /// Pulls sell tokens into the contract and ensures that after running interactions receiver has the minimum of buy
    /// @param order user signed order
    /// @param signature user signature
    /// @param interactions list of interactions to settle the order
    /// @param hooksData encoded hooks for pre and post interactions, empty if no hooks
    /// @param balanceRecipient solver specifies this address to receive the initial tokens from user
    function settle(
        JamOrder calldata order,
        bytes calldata signature,
        JamInteraction.Data[] calldata interactions,
        bytes memory hooksData,
        address balanceRecipient
    ) external payable;

    /// @dev Settle a jam order without interactions, just using balance of executor
    /// @param order user signed order
    /// @param signature user signature
    /// @param filledAmounts amounts that maker is transferring to taker
    /// @param hooksData encoded hooks for pre and post interactions, empty if no hooks
    function settleInternal(
        JamOrder calldata order,
        bytes calldata signature,
        uint256[] calldata filledAmounts,
        bytes memory hooksData
    ) external payable;

    /// @dev Settle a batch of orders.
    /// Pulls sell tokens into the contract and ensures that after running interactions receivers have the minimum of buy
    /// @param orders takers signed orders
    /// @param signatures takers signatures
    /// @param interactions list of interactions to settle the order
    /// @param hooks pre and post takers interactions, if empty then no interactions are run
    /// @param balanceRecipient solver specifies this address to receive the initial tokens from users
    function settleBatch(
        JamOrder[] calldata orders,
        bytes[] calldata signatures,
        JamInteraction.Data[] calldata interactions,
        JamHooks.Def[] calldata hooks,
        address balanceRecipient
    ) external payable;

    /// @dev Execute order on BebopBlend contract
    /// Using this contract as entry point for executing BebopBlend orders
    /// @param takerAddress address of the user
    /// @param orderType type of the order, Single, Multi or Aggregate
    /// @param data encoded order data, order has same structure as in BebopBlend contract
    /// @param hooksData encoded hooks for pre and post interactions, empty if no hooks
    function settleBebopBlend(
        address takerAddress,
        IBebopBlend.BlendOrderType orderType,
        bytes memory data,
        bytes memory hooksData
    ) external payable;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;


// Part of ISignatureTransfer(https://github.com/Uniswap/permit2/blob/main/src/interfaces/ISignatureTransfer.sol)
interface IPermit2 {

    /// @notice The token and amount details for a transfer signed in the permit transfer signature
    struct TokenPermissions {
        // ERC20 token address
        address token;
        // the maximum amount that can be spent
        uint256 amount;
    }

    /// @notice The signed permit message for a single token transfer
    struct PermitTransferFrom {
        TokenPermissions permitted;
        // a unique value for every token owner's signature to prevent signature replays
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
    }

    /// @notice Used to reconstruct the signed permit message for multiple token transfers
    /// @dev Do not need to pass in spender address as it is required that it is msg.sender
    /// @dev Note that a user still signs over a spender address
    struct PermitBatchTransferFrom {
        // the tokens and corresponding amounts permitted for a transfer
        TokenPermissions[] permitted;
        // a unique value for every token owner's signature to prevent signature replays
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
    }

    /// @notice Specifies the recipient address and amount for batched transfers.
    /// @dev Recipients and amounts correspond to the index of the signed token permissions array.
    /// @dev Reverts if the requested amount is greater than the permitted signed amount.
    struct SignatureTransferDetails {
        // recipient address
        address to;
        // spender requested amount
        uint256 requestedAmount;
    }

    /// @notice Transfers a token using a signed permit message
    /// @notice Includes extra data provided by the caller to verify signature over
    /// @dev The witness type string must follow EIP712 ordering of nested structs and must include the TokenPermissions type definition
    /// @dev Reverts if the requested amount is greater than the permitted signed amount
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails The spender's requested transfer details for the permitted token
    /// @param witness Extra data to include when checking the user signature
    /// @param witnessTypeString The EIP-712 type definition for remaining string stub of the typehash
    /// @param signature The signature to verify
    function permitWitnessTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external;


    /// @notice Transfers multiple tokens using a signed permit message
    /// @dev The witness type string must follow EIP712 ordering of nested structs and must include the TokenPermissions type definition
    /// @notice Includes extra data provided by the caller to verify signature over
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails Specifies the recipient and requested amount for the token transfer
    /// @param witness Extra data to include when checking the user signature
    /// @param witnessTypeString The EIP-712 type definition for remaining string stub of the typehash
    /// @param signature The signature to verify
    function permitWitnessTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "./base/JamTransfer.sol";
import "./interfaces/IJamBalanceManager.sol";
import "./interfaces/IPermit2.sol";

/// @title JamBalanceManager
/// @notice The reason a balance manager exists is to prevent interaction to the settlement contract draining user funds
/// By having another contract that allowances are made to, we can enforce that it is only used to draw in user balances to settlement and not sent out
contract JamBalanceManager is IJamBalanceManager {

    using SafeTransferLib for IERC20;
    using JamOrderLib for JamOrder;
    using BlendSingleOrderLib for BlendSingleOrder;
    using BlendMultiOrderLib for BlendMultiOrder;
    using BlendAggregateOrderLib for BlendAggregateOrder;

    address private immutable operator;
    IPermit2 private immutable PERMIT2;

    constructor(address _operator, address _permit2) {
        // Operator can be defined at creation time with `msg.sender`
        // Pass in the settlement - and that can be the only caller.
        operator = _operator;
        PERMIT2 = IPermit2(_permit2);
    }

    modifier onlyOperator(address account) {
        require(account == operator, InvalidCaller());
        _;
    }

    /// @inheritdoc IJamBalanceManager
    function transferTokensWithPermit2(
        JamOrder calldata order,
        bytes calldata signature,
        bytes32 hooksHash,
        address receiver
    ) onlyOperator(msg.sender) external {
        PERMIT2.permitWitnessTransferFrom(
            order.toBatchPermit2(),
            order.toSignatureTransferDetails(receiver),
            order.taker,
            order.hash(hooksHash),
            JamOrderLib.PERMIT2_ORDER_TYPE,
            signature
        );
    }

    /// @inheritdoc IJamBalanceManager
    function transferTokens(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address sender,
        address receiver
    ) onlyOperator(msg.sender) external {
        for (uint i; i < tokens.length; ++i){
            if (tokens[i] != JamOrderLib.NATIVE_TOKEN){
                IERC20(tokens[i]).safeTransferFrom(sender, receiver, amounts[i]);
            } else if (receiver != operator){
                JamTransfer(operator).transferNativeFromContract(receiver, amounts[i]);
            }
        }
    }

    /// @inheritdoc IJamBalanceManager
    function transferTokenForBlendSingleOrder(
        BlendSingleOrder memory order,
        IBebopBlend.OldSingleQuote memory oldSingleQuote,
        bytes memory takerSignature,
        address takerAddress,
        bytes32 hooksHash
    ) onlyOperator(msg.sender) external {
        PERMIT2.permitWitnessTransferFrom(
            IPermit2.PermitTransferFrom(
                IPermit2.TokenPermissions(order.taker_token, order.taker_amount), order.flags >> 128, order.expiry
            ),
            IPermit2.SignatureTransferDetails(operator, order.taker_amount),
            takerAddress,
            order.hash(oldSingleQuote.makerAmount, oldSingleQuote.makerNonce, hooksHash),
            BlendSingleOrderLib.PERMIT2_ORDER_TYPE,
            takerSignature
        );
    }

    /// @inheritdoc IJamBalanceManager
    function transferTokensForMultiBebopOrder(
        BlendMultiOrder memory order,
        IBebopBlend.OldMultiQuote memory oldMultiQuote,
        bytes memory takerSignature,
        address takerAddress,
        bytes32 hooksHash
    ) onlyOperator(msg.sender) external {
        PERMIT2.permitWitnessTransferFrom(
            order.toBatchPermit2(),
            order.toSignatureTransferDetails(operator),
            takerAddress,
            order.hash(oldMultiQuote.makerAmounts, oldMultiQuote.makerNonce, hooksHash),
            BlendMultiOrderLib.PERMIT2_ORDER_TYPE,
            takerSignature
        );
    }

    /// @inheritdoc IJamBalanceManager
    function transferTokensForAggregateBebopOrder(
        BlendAggregateOrder memory order,
        IBebopBlend.OldAggregateQuote memory oldAggregateQuote,
        bytes memory takerSignature,
        address takerAddress,
        bytes32 hooksHash
    ) onlyOperator(msg.sender) external {
        (address[] memory tokens, uint256[] memory amounts) = order.unpackTokensAndAmounts(true, oldAggregateQuote);
        PERMIT2.permitWitnessTransferFrom(
            order.toBatchPermit2(tokens, amounts),
            BlendAggregateOrderLib.toSignatureTransferDetails(amounts, operator),
            takerAddress,
            order.hash(oldAggregateQuote.makerAmounts, oldAggregateQuote.makerNonces, hooksHash),
            BlendAggregateOrderLib.PERMIT2_ORDER_TYPE,
            takerSignature
        );
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../interfaces/IPermit2.sol";
import "../interfaces/IBebopBlend.sol";

/// @notice Struct for any trade with multiple makers
struct BlendAggregateOrder {
    uint256 expiry;
    address taker_address;
    address[] maker_addresses;
    uint256[] maker_nonces;
    address[][] taker_tokens;
    address[][] maker_tokens;
    uint256[][] taker_amounts;
    uint256[][] maker_amounts;
    address receiver;
    bytes commands;
    uint256 flags;
}


library BlendAggregateOrderLib {

    bytes internal constant ORDER_TYPE = abi.encodePacked(
        "AggregateOrder(uint64 partner_id,uint256 expiry,address taker_address,address[] maker_addresses,uint256[] maker_nonces,address[][] taker_tokens,address[][] maker_tokens,uint256[][] taker_amounts,uint256[][] maker_amounts,address receiver,bytes commands,bytes32 hooksHash)"
    );
    bytes32 internal constant ORDER_TYPE_HASH = keccak256(ORDER_TYPE);
    string internal constant PERMIT2_ORDER_TYPE = string(
        abi.encodePacked("AggregateOrder witness)", ORDER_TYPE, "TokenPermissions(address token,uint256 amount)")
    );
    address internal constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice hash the given order using same schema as in BebopBlend contract
    /// @param order the order to hash
    /// @param updatedMakerAmounts amounts that taker signed
    /// @param updatedMakerNonces nonce that taker signed
    /// @return the eip-712 order hash
    function hash(
        BlendAggregateOrder memory order, uint256[][] memory updatedMakerAmounts, uint256[] memory updatedMakerNonces, bytes32 hooksHash
    ) internal pure returns (bytes32) {
        uint64 partnerId = uint64(order.flags >> 64);
        return keccak256(
            abi.encode(
                ORDER_TYPE_HASH, partnerId, order.expiry, order.taker_address,
                keccak256(abi.encodePacked(order.maker_addresses)), keccak256(abi.encodePacked(updatedMakerNonces)),
                keccak256(_encodeTightlyPackedNested(order.taker_tokens)), keccak256(_encodeTightlyPackedNested(order.maker_tokens)),
                keccak256(_encodeTightlyPackedNestedInt(order.taker_amounts)), keccak256(_encodeTightlyPackedNestedInt(updatedMakerAmounts)),
                order.receiver, keccak256(order.commands), hooksHash
            )
        );
    }

    function toBatchPermit2(
        BlendAggregateOrder memory order, address[] memory tokens, uint256[] memory amounts
    ) internal pure returns (IPermit2.PermitBatchTransferFrom memory) {
        IPermit2.TokenPermissions[] memory permitted = new IPermit2.TokenPermissions[](tokens.length);
        for (uint i; i < tokens.length; ++i) {
            permitted[i] = IPermit2.TokenPermissions(tokens[i], amounts[i]);
        }
        return IPermit2.PermitBatchTransferFrom(permitted, order.flags >> 128, order.expiry);
    }

    function toSignatureTransferDetails(
        uint256[] memory amounts, address receiver
    ) internal pure returns (IPermit2.SignatureTransferDetails[] memory) {
        IPermit2.SignatureTransferDetails[] memory details = new IPermit2.SignatureTransferDetails[](amounts.length);
        for (uint i; i < amounts.length; ++i) {
            details[i] = IPermit2.SignatureTransferDetails(receiver, amounts[i]);
        }
        return details;
    }

    /// @notice Unpack 2d arrays of tokens and amounts into 1d array without duplicates
    /// @param order the order to unpack
    /// @param unpackTakerAmounts if true, unpack taker amounts, otherwise unpack maker amounts
    function unpackTokensAndAmounts(
        BlendAggregateOrder memory order, bool unpackTakerAmounts, IBebopBlend.OldAggregateQuote memory oldAggregateQuote
    ) internal pure returns (address[] memory tokens, uint256[] memory amounts){
        uint maxLen;
        for (uint i; i < order.maker_addresses.length; ++i) {
            maxLen += unpackTakerAmounts ? order.taker_tokens[i].length : order.maker_tokens[i].length;
        }
        tokens = new address[](maxLen);
        amounts = new uint256[](maxLen);
        uint uniqueTokensCnt;
        uint commandsInd;
        for (uint256 i; i < order.maker_addresses.length; ++i) {
            if (unpackTakerAmounts) {
                commandsInd += order.maker_tokens[i].length;
            }
            uint curTokensLen = unpackTakerAmounts ? order.taker_tokens[i].length : order.maker_tokens[i].length;
            for (uint256 j; j < curTokensLen; ++j) {
                /// @dev  AggregateOrder contains multiple maker orders, 'commands' field indicates how to transfer tokens
                /// All commands packed into one variable with bytes type, for each token - command is 1 byte:
                /// '0x[maker1-order_maker-token1][maker1-order_taker-token1][maker2-order_maker-token1][maker2-order_taker-token1]...'
                /// ignoring TRANSFER_FROM_CONTRACT and TRANSFER_TO_CONTRACT commands, since they are transfers between makers
                if (
                    (unpackTakerAmounts && order.commands[commandsInd + j] != 0x08) ||  // Commands.TRANSFER_FROM_CONTRACT=0x08
                    (!unpackTakerAmounts && order.commands[commandsInd + j] != 0x07)    //Commands.TRANSFER_TO_CONTRACT=0x07
                ) {
                    bool isNew = true;
                    address token = unpackTakerAmounts ? order.taker_tokens[i][j] : order.maker_tokens[i][j];
                    if (order.commands[commandsInd + j] == 0x04) { // Commands.NATIVE_TRANSFER=0x04
                        token = NATIVE_TOKEN;
                    }
                    uint256 amount = unpackTakerAmounts ? order.taker_amounts[i][j] : (
                        oldAggregateQuote.useOldAmount ? oldAggregateQuote.makerAmounts[i][j] : order.maker_amounts[i][j]
                    );
                    for (uint256 k; k < uniqueTokensCnt; ++k) {
                        if (tokens[k] == token) {
                            amounts[k] += amount;
                            isNew = false;
                            break;
                        }
                    }
                    if (isNew) {
                        tokens[uniqueTokensCnt] = token;
                        amounts[uniqueTokensCnt++] = amount;
                    }
                }
            }
            if (unpackTakerAmounts) {
                commandsInd += order.taker_tokens[i].length;
            } else {
                commandsInd += order.maker_tokens[i].length + order.taker_tokens[i].length;
            }
        }
        assembly {
            mstore(tokens, uniqueTokensCnt)
            mstore(amounts, uniqueTokensCnt)
        }
    }

    /// @notice Pack 2D array of integers into tightly packed bytes for hashing
    function _encodeTightlyPackedNestedInt(uint256[][] memory nestedArray) private pure returns (bytes memory encoded) {
        uint nestedArrayLen = nestedArray.length;
        for (uint i; i < nestedArrayLen; ++i) {
            encoded = abi.encodePacked(encoded, keccak256(abi.encodePacked(nestedArray[i])));
        }
        return encoded;
    }

    /// @notice Pack 2D array of addresses into tightly packed bytes for hashing
    function _encodeTightlyPackedNested(address[][] memory nestedArray) private pure returns (bytes memory encoded) {
        uint nestedArrayLen = nestedArray.length;
        for (uint i; i < nestedArrayLen; ++i) {
            encoded = abi.encodePacked(encoded, keccak256(abi.encodePacked(nestedArray[i])));
        }
        return encoded;
    }

}


// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../interfaces/IPermit2.sol";


/// @notice Struct for many-to-one or one-to-many trade with one maker
struct BlendMultiOrder {
    uint256 expiry;
    address taker_address;
    address maker_address;
    uint256 maker_nonce;
    address[] taker_tokens;
    address[] maker_tokens;
    uint256[] taker_amounts;
    uint256[] maker_amounts;
    address receiver;
    bytes commands;
    uint256 flags;
}


library BlendMultiOrderLib {

    bytes internal constant ORDER_TYPE = abi.encodePacked(
        "MultiOrder(uint64 partner_id,uint256 expiry,address taker_address,address maker_address,uint256 maker_nonce,address[] taker_tokens,address[] maker_tokens,uint256[] taker_amounts,uint256[] maker_amounts,address receiver,bytes commands,bytes32 hooksHash)"
    );
    bytes32 internal constant ORDER_TYPE_HASH = keccak256(ORDER_TYPE);
    string internal constant PERMIT2_ORDER_TYPE = string(
        abi.encodePacked("MultiOrder witness)", ORDER_TYPE, "TokenPermissions(address token,uint256 amount)")
    );
    address internal constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice hash the given order using same schema as in BebopBlend contract
    /// @param order the order to hash
    /// @param updatedMakerAmounts amounts that taker signed
    /// @param updatedMakerNonce nonce that taker signed
    /// @return the eip-712 order hash
    function hash(
        BlendMultiOrder memory order, uint256[] memory updatedMakerAmounts, uint256 updatedMakerNonce, bytes32 hooksHash
    ) internal pure returns (bytes32) {
        uint64 partnerId = uint64(order.flags >> 64);
        return keccak256(
            abi.encode(
                ORDER_TYPE_HASH, partnerId, order.expiry, order.taker_address, order.maker_address, updatedMakerNonce,
                keccak256(abi.encodePacked(order.taker_tokens)), keccak256(abi.encodePacked(order.maker_tokens)),
                keccak256(abi.encodePacked(order.taker_amounts)), keccak256(abi.encodePacked(updatedMakerAmounts)),
                order.receiver, keccak256(order.commands), hooksHash
            )
        );
    }

    function toBatchPermit2(BlendMultiOrder memory order) internal pure returns (IPermit2.PermitBatchTransferFrom memory) {
        IPermit2.TokenPermissions[] memory permitted = new IPermit2.TokenPermissions[](order.taker_tokens.length);
        for (uint i; i < order.taker_tokens.length; ++i) {
            permitted[i] = IPermit2.TokenPermissions(order.taker_tokens[i], order.taker_amounts[i]);
        }
        return IPermit2.PermitBatchTransferFrom(permitted, order.flags >> 128, order.expiry);
    }

    function toSignatureTransferDetails(
        BlendMultiOrder memory order, address receiver
    ) internal pure returns (IPermit2.SignatureTransferDetails[] memory) {
        IPermit2.SignatureTransferDetails[] memory details = new IPermit2.SignatureTransferDetails[](order.taker_tokens.length);
        for (uint i; i < order.taker_tokens.length; ++i) {
            details[i] = IPermit2.SignatureTransferDetails(receiver, order.taker_amounts[i]);
        }
        return details;
    }

    /// @notice Get maker tokens from the order
    /// replace all tokens with command=0x04(Commands.NATIVE_TRANSFER) with native token address
    function getMakerTokens(BlendMultiOrder memory order) internal pure returns (address[] memory makerTokens) {
        makerTokens = new address[](order.maker_tokens.length);
        for (uint i; i < order.maker_tokens.length; ++i) {
            makerTokens[i] = order.commands[i] == 0x04 ? NATIVE_TOKEN : order.maker_tokens[i];
        }
    }

}


// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../interfaces/IPermit2.sol";


/// @notice BebopBlend struct for one-to-one trade with one maker
struct BlendSingleOrder {
    uint256 expiry;
    address taker_address;
    address maker_address;
    uint256 maker_nonce;
    address taker_token;
    address maker_token;
    uint256 taker_amount;
    uint256 maker_amount;
    address receiver;
    uint256 packed_commands;
    uint256 flags;
}


library BlendSingleOrderLib {

    bytes internal constant ORDER_TYPE = abi.encodePacked(
        "SingleOrder(uint64 partner_id,uint256 expiry,address taker_address,address maker_address,uint256 maker_nonce,address taker_token,address maker_token,uint256 taker_amount,uint256 maker_amount,address receiver,uint256 packed_commands,bytes32 hooksHash)"
    );
    bytes32 internal constant ORDER_TYPE_HASH = keccak256(ORDER_TYPE);
    string internal constant PERMIT2_ORDER_TYPE = string(
        abi.encodePacked("SingleOrder witness)", ORDER_TYPE, "TokenPermissions(address token,uint256 amount)")
    );

    /// @notice hash the given order using same schema as in BebopBlend contract
    /// @param order the order to hash
    /// @param updatedMakerAmount amount that taker signed
    /// @param updatedMakerNonce nonce that taker signed
    /// @return the eip-712 order hash
    function hash(
        BlendSingleOrder memory order, uint256 updatedMakerAmount, uint256 updatedMakerNonce, bytes32 hooksHash
    ) internal pure returns (bytes32) {
        uint64 partnerId = uint64(order.flags >> 64);
        return keccak256(
            abi.encode(
                ORDER_TYPE_HASH, partnerId, order.expiry, order.taker_address, order.maker_address,
                updatedMakerNonce, order.taker_token, order.maker_token, order.taker_amount,
                updatedMakerAmount, order.receiver, order.packed_commands, hooksHash
            )
        );
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../libraries/JamInteraction.sol";

/// @title JamHooks
/// @notice JamHooks is a library for managing pre and post interactions
library JamHooks {

    bytes32 internal constant EMPTY_HOOKS_HASH = bytes32(0);

    /// @dev Data structure for pre and post interactions
    struct Def {
        JamInteraction.Data[] beforeSettle;
        JamInteraction.Data[] afterSettle;
    }

    function hash(Def memory hooks) internal pure returns (bytes32) {
        if (hooks.afterSettle.length == 0 && hooks.beforeSettle.length == 0){
            return EMPTY_HOOKS_HASH;
        }
        return keccak256(abi.encode(hooks));
    }
}


// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../interfaces/IJamBalanceManager.sol";
import "../base/Errors.sol";

library JamInteraction {

    /// @dev Data representing an interaction on the chain
    struct Data {
        bool result; // If the interaction is required to succeed
        address to;
        uint256 value;
        bytes data;
    }

    function runInteractions(Data[] calldata interactions, IJamBalanceManager balanceManager) internal returns (bool) {
        for (uint i; i < interactions.length; ++i) {
            Data calldata interaction = interactions[i];
            require(interaction.to != address(balanceManager), CallToBalanceManagerNotAllowed());
            (bool execResult,) = payable(interaction.to).call{ value: interaction.value }(interaction.data);
            if (!execResult && interaction.result) return false;
        }
        return true;
    }

    function runInteractionsM(Data[] memory interactions, IJamBalanceManager balanceManager) internal returns (bool) {
        for (uint i; i < interactions.length; ++i) {
            Data memory interaction = interactions[i];
            require(interaction.to != address(balanceManager), CallToBalanceManagerNotAllowed());
            (bool execResult,) = payable(interaction.to).call{ value: interaction.value }(interaction.data);
            if (!execResult && interaction.result) return false;
        }
        return true;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../interfaces/IPermit2.sol";
import "./JamHooks.sol";
import "../external-libs/PermitHash.sol";

/// @dev Data representing a Jam Order.
struct JamOrder {
    address taker;
    address receiver;
    uint256 expiry;
    uint256 exclusivityDeadline; // if block.timestamp > exclusivityDeadline, then order can be executed by any executor
    uint256 nonce;
    address executor; // only msg.sender=executor is allowed to execute (if executor=address(0), then order can be executed by anyone)
    uint256 partnerInfo; // partnerInfo is a packed struct of [partnerAddress,partnerFee,protocolFee]
    address[] sellTokens;
    address[] buyTokens;
    uint256[] sellAmounts;
    uint256[] buyAmounts;
    bool usingPermit2; // this field is excluded from ORDER_TYPE, so taker doesnt need to sign it
}


/// @title JamOrderLib
library JamOrderLib {

    address internal constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes internal constant ORDER_TYPE = abi.encodePacked(
        "JamOrder(address taker,address receiver,uint256 expiry,uint256 exclusivityDeadline,uint256 nonce,address executor,uint256 partnerInfo,address[] sellTokens,address[] buyTokens,uint256[] sellAmounts,uint256[] buyAmounts,bytes32 hooksHash)"
    );
    bytes32 internal constant ORDER_TYPE_HASH = keccak256(ORDER_TYPE);
    string internal constant PERMIT2_ORDER_TYPE = string(
        abi.encodePacked("JamOrder witness)", ORDER_TYPE, "TokenPermissions(address token,uint256 amount)")
    );

    /// @notice hash the given order
    /// @param order the order to hash
    /// @return the eip-712 order hash
    function hash(JamOrder calldata order, bytes32 hooksHash) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ORDER_TYPE_HASH, order.taker, order.receiver, order.expiry, order.exclusivityDeadline, order.nonce,
                order.executor, order.partnerInfo, keccak256(abi.encodePacked(order.sellTokens)),
                keccak256(abi.encodePacked(order.buyTokens)), keccak256(abi.encodePacked(order.sellAmounts)),
                keccak256(abi.encodePacked(order.buyAmounts)), hooksHash
            )
        );
    }

    function toBatchPermit2(JamOrder calldata order) internal pure returns (IPermit2.PermitBatchTransferFrom memory) {
        IPermit2.TokenPermissions[] memory permitted = new IPermit2.TokenPermissions[](order.sellTokens.length);
        for (uint i; i < order.sellTokens.length; ++i) {
            permitted[i] = IPermit2.TokenPermissions(order.sellTokens[i], order.sellAmounts[i]);
        }
        return IPermit2.PermitBatchTransferFrom(permitted, order.nonce, order.expiry);
    }

    function toSignatureTransferDetails(
        JamOrder calldata order, address receiver
    ) internal pure returns (IPermit2.SignatureTransferDetails[] memory details) {
        details = new IPermit2.SignatureTransferDetails[](order.sellTokens.length);
        for (uint i; i < order.sellTokens.length; ++i) {
            details[i] = IPermit2.SignatureTransferDetails(receiver, order.sellAmounts[i]);
        }
    }

    function permit2OrderHash(JamOrder calldata order, bytes32 hooksHash, address spender) internal pure returns (bytes32) {
        return PermitHash.hashWithWitness(toBatchPermit2(order), hash(order, hooksHash), PERMIT2_ORDER_TYPE, spender);
    }


}