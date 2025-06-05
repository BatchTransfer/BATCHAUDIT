// Chain: POLYGON - File: @openzeppelin/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

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
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
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
}


// Chain: POLYGON - File: @openzeppelin/contracts/utils/Context.sol
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


// Chain: POLYGON - File: contracts/v2/GemSwapV2.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./utils/ReentrancyGuard.sol";
import "./markets/MarketRegistry.sol";
import "./SpecialTransferHelper.sol";
import "../../interfaces/markets/tokens/IERC20.sol";
import "../../interfaces/markets/tokens/IERC721.sol";
import "../../interfaces/markets/tokens/IERC1155.sol";

contract GemSwapV2 is SpecialTransferHelper, MarketRegistry, ReentrancyGuard {
    struct ERC20Details {
        address[] tokenAddrs;
        uint256[] amounts;
    }

    struct ERC1155Details {
        address tokenAddr;
        uint256[] ids;
        uint256[] amounts;
    }

    struct TradeDetails {
        uint256 marketId;
        uint256 value;
        bytes tradeData;
    }

    struct ConverstionDetails {
        bytes conversionData;
    }

    address public constant GOV = 0x073Ab1C0CAd3677cDe9BDb0cDEEDC2085c029579;
    address public guardian;
    address public converter;
    address public punkProxy;

    constructor(address _converter, address _guardian) {
        converter = _converter;
        guardian = _guardian;

        // Seaport
        markets.push(
            Market({
                proxy: 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC,
                isLib: false,
                isActive: true
            })
        );
    }
    
    // TODO: figure out one time approval with Parmesh

    // @audit This function is used to approve specific tokens to specific market contracts with high volume.
    // This is done in very rare cases for the gas optimization purposes.
    function setOneTimeApproval(
        IERC20 token,
        address operator,
        uint256 amount
    ) external onlyOwner {
        token.approve(operator, amount);
    }

    function setConverter(address _converter) external onlyOwner {
        converter = _converter;
    }

    function updateGuardian(address _guardian) external onlyOwner {
        guardian = _guardian;
    }

    function _transferEth(address _to, uint256 _amount) internal {
        bool callStatus;
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), _to, _amount, 0, 0, 0, 0)
        }
        require(callStatus, "_transferEth: Eth transfer failed");
    }

    function _checkCallResult(bool _success) internal pure {
        if (!_success) {
            // Copy revert reason from call
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function _transferFromHelper(
        ERC20Details memory erc20Details,
        SpecialTransferHelper.ERC721Details[] memory erc721Details,
        ERC1155Details[] memory erc1155Details
    ) internal {
        // transfer ERC20 tokens from the sender to this contract
        uint256 length = erc20Details.tokenAddrs.length;

        for (uint256 i; i < length; ) {
            erc20Details.tokenAddrs[i].call(
                abi.encodeWithSelector(
                    0x23b872dd,
                    msg.sender,
                    address(this),
                    erc20Details.amounts[i]
                )
            );

            unchecked {
                i++;
            }
        }

        // transfer ERC721 tokens from the sender to this contract
        length = erc721Details.length;

        for (uint256 i; i < length; ) {

            // default
            uint256 _length = erc721Details[i].ids.length;

            for (uint256 j; j < _length; ) {
                IERC721(erc721Details[i].tokenAddr).transferFrom(
                    _msgSender(),
                    address(this),
                    erc721Details[i].ids[j]
                );

                unchecked {
                    j++;
                }
            }

            unchecked {
                i++;
            }
        }

        // transfer ERC1155 tokens from the sender to this contract
        length = erc1155Details.length;

        for (uint256 i; i < length; ) {
            IERC1155(erc1155Details[i].tokenAddr).safeBatchTransferFrom(
                _msgSender(),
                address(this),
                erc1155Details[i].ids,
                erc1155Details[i].amounts,
                ""
            );

            unchecked {
                i++;
            }
        }
    }

// TODO: add logic in converter
    function _conversionHelper(ConverstionDetails[] memory _converstionDetails)
        internal
    {
        uint256 length = _converstionDetails.length;
        bool success;

        for (uint256 i; i < length; ) {
            // convert to desired asset
            (success, ) = converter.delegatecall(
                _converstionDetails[i].conversionData
            );
            // check if the call passed successfully
            _checkCallResult(success);

            unchecked {
                i++;
            }
        }
    }

    function _trade(TradeDetails[] memory _tradeDetails) internal {
        uint256 length = _tradeDetails.length;
        bool success;

        for (uint256 i; i < length; ) {
            // get market details
            Market memory market = _getMarket(_tradeDetails[i].marketId);

            // execute trade
            (success, ) = market.isLib
                ? market.proxy.delegatecall(_tradeDetails[i].tradeData)
                : market.proxy.call{value: _tradeDetails[i].value}(
                    _tradeDetails[i].tradeData
                );

            // check if the call passed successfully
            _checkCallResult(success);

            unchecked {
                i++;
            }
        }
    }

    function _tradeWithLimit(
        TradeDetails[] memory _tradeDetails,
        uint256 maxItemLimit
    ) internal {
        uint256 length = _tradeDetails.length;
        uint256 successCount;
        bool success;

        for (uint256 i; i < length; ) {
            // get market details
            Market memory market = _getMarket(_tradeDetails[i].marketId);

            // execute trade
            (success, ) = market.isLib
                ? market.proxy.delegatecall(_tradeDetails[i].tradeData)
                : market.proxy.call{value: _tradeDetails[i].value}(
                    _tradeDetails[i].tradeData
                );

            // check if the call passed successfully
            _checkCallResult(success);

            if (success) {
                unchecked {
                    successCount++;
                }

                if (successCount >= maxItemLimit) {
                    break;
                }
            }

            unchecked {
                i++;
            }
        }
    }

    /* function _tradeWithLimitV2(
        TradeDetails[] memory _tradeDetails,
        uint256 maxItemLimit
    ) internal {
        uint256 length = _tradeDetails.length;
        uint256 successCount;
        bool success;
        bytes memory successCountData;

        for (uint256 i; i < length; ) {
            // get market details
            Market memory market = markets[_tradeDetails[i].marketId];
            // market should be active
            require(market.isActive, "_trade: InActive Market");
            // execute trade
            (success, successCountData) = market.isLib
                ? market.proxy.delegatecall(
                    abi.encodeWithSelector(
                        SeaportMarketV1.buyAssetsForEthWithLimit.selector,
                        _tradeDetails[i].tradeData,
                        maxItemLimit
                    )
                )
                : market.proxy.call{value: _tradeDetails[i].value}(
                    _tradeDetails[i].tradeData
                );
            // check if the call passed successfully
            _checkCallResult(success);

            if (success) {
                uint256 _successCount;
                (_successCount) = abi.decode(successCountData, (uint256));

                unchecked {
                    successCount = successCount + _successCount;
                }

                if (successCount >= maxItemLimit) {
                    break;
                }
            }

            unchecked {
                i++;
            }
        }
    } */

    function _returnDust(address[] memory _tokens) internal {
        // return remaining ETH (if any)
        assembly {
            if gt(selfbalance(), 0) {
                let callStatus := call(
                    gas(),
                    caller(),
                    selfbalance(),
                    0,
                    0,
                    0,
                    0
                )
            }
        }

        // return remaining tokens (if any)
        uint256 length = _tokens.length;

        for (uint256 i; i < length; ) {
            if (IERC20(_tokens[i]).balanceOf(address(this)) > 0) {
                _tokens[i].call(
                    abi.encodeWithSelector(
                        0xa9059cbb,
                        msg.sender,
                        IERC20(_tokens[i]).balanceOf(address(this))
                    )
                );
            }

            unchecked {
                i++;
            }
        }
    }

    function batchSellERC721Assets(
        SpecialTransferHelper.ERC721Details[] memory erc721Details,
        TradeDetails[] memory tradeDetails
    ) external payable nonReentrant {
        // transfer assets to sell
        uint256 length = erc721Details.length;

        for (uint256 i; i < length; ) {
            uint256 _length = erc721Details[i].ids.length;

            for (uint256 j; j < _length; ) {
                IERC721(erc721Details[i].tokenAddr).transferFrom(
                    _msgSender(),
                    address(this),
                    erc721Details[i].ids[j]
                );

                unchecked {
                    j++;
                }
            }

            unchecked {
                i++;
            }
        }

        // execute trades
        _trade(tradeDetails);

        // return remaining ETH (if any)
        assembly {
            if gt(selfbalance(), 0) {
                let callStatus := call(
                    gas(),
                    caller(),
                    selfbalance(),
                    0,
                    0,
                    0,
                    0
                )
            }
        }
    }

    function batchSell(
        SpecialTransferHelper.ERC721Details[] memory erc721Details,
        ERC1155Details[] memory erc1155Details,
        TradeDetails[] memory tradeDetails
    ) external payable nonReentrant {
        // transfer ERC721 assets to sell
        uint256 length = erc721Details.length;

        for (uint256 i; i < length; ) {
            uint256 _length = erc721Details[i].ids.length;

            for (uint256 j; j < _length; ) {
                IERC721(erc721Details[i].tokenAddr).transferFrom(
                    _msgSender(),
                    address(this),
                    erc721Details[i].ids[j]
                );

                unchecked {
                    j++;
                }
            }
        }

        // transfer ERC1155 assets to sell
        length = erc1155Details.length;

        for (uint256 i; i < length; ) {
            IERC1155(erc1155Details[i].tokenAddr).safeBatchTransferFrom(
                _msgSender(),
                address(this),
                erc1155Details[i].ids,
                erc1155Details[i].amounts,
                ""
            );

            unchecked {
                i++;
            }
        }

        // execute trades
        _trade(tradeDetails);

        // return remaining ETH (if any)
        assembly {
            if gt(selfbalance(), 0) {
                let callStatus := call(
                    gas(),
                    caller(),
                    selfbalance(),
                    0,
                    0,
                    0,
                    0
                )
            }
        }
    }

    function batchBuyWithEth(TradeDetails[] memory tradeDetails)
        external
        payable
        nonReentrant
    {
        // execute trades
        _trade(tradeDetails);

        // return remaining ETH (if any)
        assembly {
            if gt(selfbalance(), 0) {
                let callStatus := call(
                    gas(),
                    caller(),
                    selfbalance(),
                    0,
                    0,
                    0,
                    0
                )
            }
        }
    }

    function batchBuyWithEthWithLimit(
        TradeDetails[] memory tradeDetails,
        uint256 maxItemLimit
    ) external payable nonReentrant {
        // execute trades
        _tradeWithLimit(tradeDetails, maxItemLimit);

        // return remaining ETH (if any)
        assembly {
            if gt(selfbalance(), 0) {
                let callStatus := call(
                    gas(),
                    caller(),
                    selfbalance(),
                    0,
                    0,
                    0,
                    0
                )
            }
        }
    }

    function batchBuyWithERC20sWithLimit(
        ERC20Details memory erc20Details,
        TradeDetails[] memory tradeDetails,
        ConverstionDetails[] memory converstionDetails,
        address[] memory dustTokens,
        uint256 maxItemLimit
    ) external payable nonReentrant {
        // transfer ERC20 tokens from the sender to this contract
        uint256 length = erc20Details.tokenAddrs.length;

        for (uint256 i; i < length; ) {
            erc20Details.tokenAddrs[i].call(
                abi.encodeWithSelector(
                    0x23b872dd,
                    msg.sender,
                    address(this),
                    erc20Details.amounts[i]
                )
            );

            unchecked {
                i++;
            }
        }

        // Convert any assets if needed
        _conversionHelper(converstionDetails);

        // execute trades
        _tradeWithLimit(tradeDetails, maxItemLimit);

        // return dust tokens (if any)
        _returnDust(dustTokens);
    }

    /* function batchBuyWithEthWithLimitV2(
        TradeDetails[] memory tradeDetails,
        uint256 maxItemLimit
    ) external payable nonReentrant {
        // execute trades
        _tradeWithLimitV2(tradeDetails, maxItemLimit);

        // return remaining ETH (if any)
        assembly {
            if gt(selfbalance(), 0) {
                let callStatus := call(
                    gas(),
                    caller(),
                    selfbalance(),
                    0,
                    0,
                    0,
                    0
                )
            }
        }
    } */

    function batchBuyWithERC20s(
        ERC20Details memory erc20Details,
        TradeDetails[] memory tradeDetails,
        ConverstionDetails[] memory converstionDetails,
        address[] memory dustTokens
    ) external payable nonReentrant {
        // transfer ERC20 tokens from the sender to this contract
        uint256 length = erc20Details.tokenAddrs.length;

        for (uint256 i; i < length; ) {
            erc20Details.tokenAddrs[i].call(
                abi.encodeWithSelector(
                    0x23b872dd,
                    msg.sender,
                    address(this),
                    erc20Details.amounts[i]
                )
            );

            unchecked {
                i++;
            }
        }

        // Convert any assets if needed
        _conversionHelper(converstionDetails);

        // execute trades
        _trade(tradeDetails);

        // return dust tokens (if any)
        _returnDust(dustTokens);
    }

    // swaps any combination of ERC-20/721/1155
    // User needs to approve assets before invoking swap
    // WARNING: DO NOT SEND TOKENS TO THIS FUNCTION DIRECTLY!!!
    function multiAssetSwap(
        ERC20Details memory erc20Details,
        SpecialTransferHelper.ERC721Details[] memory erc721Details,
        ERC1155Details[] memory erc1155Details,
        ConverstionDetails[] memory converstionDetails,
        TradeDetails[] memory tradeDetails,
        address[] memory dustTokens
    ) external payable nonReentrant {
        // transfer all tokens
        _transferFromHelper(erc20Details, erc721Details, erc1155Details);

        // Convert any assets if needed
        _conversionHelper(converstionDetails);

        // execute trades
        _trade(tradeDetails);

        // return dust tokens (if any)
        _returnDust(dustTokens);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return 0x150b7a02;
    }

    // Used by ERC721BasicToken.sol
    function onERC721Received(
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return 0xf0b9e5ba;
    }

    function supportsInterface(bytes4 interfaceId)
        external
        view
        virtual
        returns (bool)
    {
        return interfaceId == this.supportsInterface.selector;
    }

    receive() external payable {}

    // Emergency function: In case any ETH get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueETH(address recipient) external onlyOwner {
        _transferEth(recipient, address(this).balance);
    }

    // Emergency function: In case any ERC20 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC20(address asset, address recipient) external onlyOwner {
        asset.call(
            abi.encodeWithSelector(
                0xa9059cbb,
                recipient,
                IERC20(asset).balanceOf(address(this))
            )
        );
    }

    // Emergency function: In case any ERC721 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC721(
        address asset,
        uint256[] calldata ids,
        address recipient
    ) external onlyOwner {
        uint256 length = ids.length;

        for (uint256 i; i < length; ) {
            IERC721(asset).transferFrom(address(this), recipient, ids[i]);

            unchecked {
                i++;
            }
        }
    }

    // Emergency function: In case any ERC1155 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC1155(
        address asset,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        address recipient
    ) external onlyOwner {
        uint256 length = ids.length;

        for (uint256 i; i < length; ) {
            IERC1155(asset).safeTransferFrom(
                address(this),
                recipient,
                ids[i],
                amounts[i],
                ""
            );

            unchecked {
                i++;
            }
        }
    }
}


// Chain: POLYGON - File: contracts/v2/markets/MarketRegistry.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketRegistry is Ownable {
    struct Market {
        address proxy;
        bool isLib;
        bool isActive;
    }

    Market[] public markets;

    function _getMarket(uint256 marketId)
        internal
        view
        returns (Market memory)
    {
        Market memory market = markets[marketId];

        // market should be active
        // NOTE: We can just skip this check by setting the proxy address of the exploited markets.
        require(market.isActive, "_trade: InActive Market");

        return market;
    }

    function addMarket(address proxy, bool isLib) external onlyOwner {
        markets.push(Market(proxy, isLib, true));
    }

    function setMarketStatus(uint256 marketId, bool newStatus)
        external
        onlyOwner
    {
        Market storage market = markets[marketId];
        market.isActive = newStatus;
    }

    function setMarketProxy(
        uint256 marketId,
        address newProxy,
        bool isLib
    ) external onlyOwner {
        Market storage market = markets[marketId];
        market.proxy = newProxy;
        market.isLib = isLib;
    }
}


// Chain: POLYGON - File: contracts/v2/SpecialTransferHelper.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Context.sol";
import "../../interfaces/punks/ICryptoPunks.sol";
import "../../interfaces/punks/IWrappedPunk.sol";
import "../../interfaces/mooncats/IMoonCatsRescue.sol";

contract SpecialTransferHelper is Context {
    struct ERC721Details {
        address tokenAddr;
        address[] to;
        uint256[] ids;
    }

    function _uintToBytes5(uint256 id)
        internal
        pure
        returns (bytes5 slicedDataBytes5)
    {
        bytes memory _bytes = new bytes(32);
        assembly {
            mstore(add(_bytes, 32), id)
        }

        bytes memory tempBytes;

        assembly {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
            tempBytes := mload(0x40)

            // The first word of the slice result is potentially a partial
            // word read from the original array. To read it, we calculate
            // the length of that partial word and start copying that many
            // bytes into the array. The first word we copy will start with
            // data we don't care about, but the last `lengthmod` bytes will
            // land at the beginning of the contents of the new array. When
            // we're done copying, we overwrite the full first word with
            // the actual length of the slice.
            let lengthmod := and(5, 31)

            // The multiplication in the next line is necessary
            // because when slicing multiples of 32 bytes (lengthmod == 0)
            // the following copy loop was copying the origin's length
            // and then ending prematurely not copying everything it should.
            let mc := add(
                add(tempBytes, lengthmod),
                mul(0x20, iszero(lengthmod))
            )
            let end := add(mc, 5)

            for {
                // The multiplication in the next line has the same exact purpose
                // as the one above.
                let cc := add(
                    add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))),
                    27
                )
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            mstore(tempBytes, 5)

            //update free-memory pointer
            //allocating the array padded to 32 bytes like the compiler does now
            mstore(0x40, and(add(mc, 31), not(31)))
        }

        assembly {
            slicedDataBytes5 := mload(add(tempBytes, 32))
        }
    }

    function _acceptMoonCat(ERC721Details memory erc721Details) internal {
        for (uint256 i = 0; i < erc721Details.ids.length; i++) {
            bytes5 catId = _uintToBytes5(erc721Details.ids[i]);
            address owner = IMoonCatsRescue(erc721Details.tokenAddr).catOwners(
                catId
            );
            require(
                owner == _msgSender(),
                "_acceptMoonCat: invalid mooncat owner"
            );
            IMoonCatsRescue(erc721Details.tokenAddr).acceptAdoptionOffer(catId);
        }
    }

    function _transferMoonCat(ERC721Details memory erc721Details) internal {
        for (uint256 i = 0; i < erc721Details.ids.length; i++) {
            IMoonCatsRescue(erc721Details.tokenAddr).giveCat(
                _uintToBytes5(erc721Details.ids[i]),
                erc721Details.to[i]
            );
        }
    }

    function _acceptCryptoPunk(ERC721Details memory erc721Details) internal {
        for (uint256 i = 0; i < erc721Details.ids.length; i++) {
            address owner = ICryptoPunks(erc721Details.tokenAddr)
                .punkIndexToAddress(erc721Details.ids[i]);
            require(
                owner == _msgSender(),
                "_acceptCryptoPunk: invalid punk owner"
            );
            ICryptoPunks(erc721Details.tokenAddr).buyPunk(erc721Details.ids[i]);
        }
    }

    function _transferCryptoPunk(ERC721Details memory erc721Details) internal {
        for (uint256 i = 0; i < erc721Details.ids.length; i++) {
            ICryptoPunks(erc721Details.tokenAddr).transferPunk(
                erc721Details.to[i],
                erc721Details.ids[i]
            );
        }
    }
}


// Chain: POLYGON - File: contracts/v2/utils/ReentrancyGuard.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    uint256 private reentrancyStatus = 1;

    modifier nonReentrant() {
        require(reentrancyStatus == 1, "REENTRANCY");

        reentrancyStatus = 2;

        _;

        reentrancyStatus = 1;
    }
}


// Chain: POLYGON - File: interfaces/markets/tokens/IERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IERC1155 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function balanceOf(address _owner, uint256 _id)
        external
        view
        returns (uint256);

    function isApprovedForAll(address account, address operator)
        external
        view
        returns (bool);

    function setApprovalForAll(address operator, bool approved) external;
}


// Chain: POLYGON - File: interfaces/markets/tokens/IERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IERC20 {
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
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

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
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
}


// Chain: POLYGON - File: interfaces/markets/tokens/IERC721.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IERC721 {
    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) external;

    function setApprovalForAll(address operator, bool approved) external;

    function approve(address to, uint256 tokenId) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    function balanceOf(address _owner) external view returns (uint256);

    function ownerOf(uint256 _tokenId) external view returns (address);
}


// Chain: POLYGON - File: interfaces/mooncats/IMoonCatsRescue.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IMoonCatsRescue {
    function acceptAdoptionOffer(bytes5 catId) external payable;

    function makeAdoptionOfferToAddress(
        bytes5 catId,
        uint256 price,
        address to
    ) external;

    function giveCat(bytes5 catId, address to) external;

    function catOwners(bytes5 catId) external view returns (address);

    function rescueOrder(uint256 rescueIndex)
        external
        view
        returns (bytes5 catId);
}


// Chain: POLYGON - File: interfaces/punks/ICryptoPunks.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface ICryptoPunks {
    function punkIndexToAddress(uint256 index)
        external
        view
        returns (address owner);

    function offerPunkForSaleToAddress(
        uint256 punkIndex,
        uint256 minSalePriceInWei,
        address toAddress
    ) external;

    function buyPunk(uint256 punkIndex) external payable;

    function transferPunk(address to, uint256 punkIndex) external;
}


// Chain: POLYGON - File: interfaces/punks/IWrappedPunk.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IWrappedPunk {
    /**
     * @dev Mints a wrapped punk
     */
    function mint(uint256 punkIndex) external;

    /**
     * @dev Burns a specific wrapped punk
     */
    function burn(uint256 punkIndex) external;

    /**
     * @dev Registers proxy
     */
    function registerProxy() external;

    /**
     * @dev Gets proxy address
     */
    function proxyInfo(address user) external view returns (address);
}