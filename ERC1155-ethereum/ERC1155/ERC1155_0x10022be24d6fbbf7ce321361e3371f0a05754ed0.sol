// File: src/core/OptionToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// external libraries
import {ERC1155} from "solmate/tokens/ERC1155.sol";

// interfaces
import {IOptionToken} from "../interfaces/IOptionToken.sol";
import {IPomace} from "../interfaces/IPomace.sol";
import {IOptionTokenDescriptor} from "../interfaces/IOptionTokenDescriptor.sol";

// constants and types
import "../config/enums.sol";
import "../config/constants.sol";
import "../config/errors.sol";

/**
 * @title   OptionToken
 * @author  antoncoding
 * @dev     each OptionToken represent the right to redeem cash value at expiry.
 *             The value of each OptionType should always be positive.
 */
contract OptionToken is ERC1155, IOptionToken {
    ///@dev pomace serve as the registry
    IPomace public immutable pomace;
    IOptionTokenDescriptor public immutable descriptor;

    constructor(address _pomace, address _descriptor) {
        // solhint-disable-next-line reason-string
        if (_pomace == address(0)) revert();
        pomace = IPomace(_pomace);

        descriptor = IOptionTokenDescriptor(_descriptor);
    }

    /**
     *  @dev return string as defined in token descriptor
     *
     */
    function uri(uint256 id) public view override returns (string memory) {
        return descriptor.tokenURI(id);
    }

    /**
     * @dev mint option token to an address. Can only be called by corresponding margin engine
     * @param _recipient    where to mint token to
     * @param _tokenId      tokenId to mint
     * @param _amount       amount to mint
     */
    function mint(address _recipient, uint256 _tokenId, uint256 _amount) external override {
        pomace.checkEngineAccessAndTokenId(_tokenId, msg.sender);

        _mint(_recipient, _tokenId, _amount, "");
    }

    /**
     * @dev burn option token from an address. Can only be called by corresponding margin engine
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     *
     */
    function burn(address _from, uint256 _tokenId, uint256 _amount) external override {
        pomace.checkEngineAccess(_tokenId, msg.sender);

        _burn(_from, _tokenId, _amount);
    }

    /**
     * @dev burn option token from an address. Can only be called by pomace, used for settlement
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     *
     */
    function burnPomaceOnly(address _from, uint256 _tokenId, uint256 _amount) external override {
        _checkIsPomace();
        _burn(_from, _tokenId, _amount);
    }

    /**
     * @dev burn batch of option token from an address. Can only be called by pomace, used for settlement
     * @param _from         account to burn from
     * @param _ids          tokenId to burn
     * @param _amounts      amount to burn
     *
     */
    function batchBurnPomaceOnly(address _from, uint256[] memory _ids, uint256[] memory _amounts) external override {
        _checkIsPomace();
        _batchBurn(_from, _ids, _amounts);
    }

    /**
     * @dev check if msg.sender is the marginAccount
     */
    function _checkIsPomace() internal view {
        if (msg.sender != address(pomace)) revert NoAccess();
    }
}


// File: lib/solmate/src/tokens/ERC1155.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Minimalist and gas efficient standard ERC1155 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[to][ids[i]] += amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[from][ids[i]] -= amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[from][id] -= amount;

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}


// File: src/interfaces/IOptionToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOptionToken {
    /**
     * @dev mint option token to an address. Can only be called by corresponding margin engine
     * @param _recipient    where to mint token to
     * @param _tokenId      tokenId to mint
     * @param _amount       amount to mint
     *
     */
    function mint(address _recipient, uint256 _tokenId, uint256 _amount) external;

    /**
     * @dev burn option token from an address. Can only be called by corresponding margin engine
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     *
     */
    function burn(address _from, uint256 _tokenId, uint256 _amount) external;

    /**
     * @dev burn option token from an address. Can only be called by pomace, used for settlement
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     *
     */
    function burnPomaceOnly(address _from, uint256 _tokenId, uint256 _amount) external;

    /**
     * @dev burn batch of option token from an address. Can only be called by pomace
     * @param _from         account to burn from
     * @param _ids          tokenId to burn
     * @param _amounts      amount to burn
     *
     */
    function batchBurnPomaceOnly(address _from, uint256[] memory _ids, uint256[] memory _amounts) external;
}


// File: src/interfaces/IPomace.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../config/types.sol";
import {IOracle} from "./IOracle.sol";

interface IPomace {
    function oracle() external view returns (IOracle oracle);

    function checkEngineAccess(uint256 _tokenId, address _engine) external view;

    function checkEngineAccessAndTokenId(uint256 _tokenId, address _engine) external view;

    function engineIds(address _engine) external view returns (uint8 id);

    function assetIds(address _asset) external view returns (uint8 id);

    function assets(uint8 _id) external view returns (address addr, uint8 decimals);

    function engines(uint8 _id) external view returns (address engine);

    function isCollateralizable(uint8 _asset0, uint8 _asset1) external view returns (bool);

    function isCollateralizable(address _asset0, address _asset1) external view returns (bool);

    function getDebtAndPayout(uint256 tokenId, uint64 amount)
        external
        view
        returns (address engine, uint8 debtId, uint256 debt, uint8 payoutId, uint256 payout);

    function batchGetDebtAndPayouts(uint256[] calldata tokenId, uint256[] calldata amount)
        external
        view
        returns (Balance[] memory debts, Balance[] memory payouts);

    function getProductId(address engine, address underlying, address strike, address collateral)
        external
        view
        returns (uint32 id);

    function getTokenId(TokenType tokenType, uint32 productId, uint256 expiry, uint256 strike, uint256 exerciseWindow)
        external
        view
        returns (uint256 id);

    function getDetailFromProductId(uint32 _productId)
        external
        view
        returns (
            address engine,
            address underlying,
            uint8 underlyingDecimals,
            address strike,
            uint8 strikeDecimals,
            address collateral,
            uint8 collateralDecimals
        );

    /**
     * @notice burn option token and get out cash value at expiry
     * @param _account who to settle for
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     * @return debt amount collected
     * @return payout amount paid out
     */
    function settleOption(address _account, uint256 _tokenId, uint256 _amount)
        external
        returns (Balance memory debt, Balance memory payout);

    /**
     * @notice burn array of option tokens and get out cash value at expiry
     * @param _account who to settle for
     * @param _tokenIds array of tokenIds to burn
     * @param _amounts   array of amounts to burn
     */
    function batchSettleOptions(address _account, uint256[] memory _tokenIds, uint256[] memory _amounts) external;
}


// File: src/interfaces/IOptionTokenDescriptor.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Describes Option NFT
interface IOptionTokenDescriptor {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}


// File: src/config/enums.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum TokenType {
    PUT,
    CALL
}

/**
 * @dev common action types on margin engines
 */
enum ActionType {
    AddCollateral,
    RemoveCollateral,
    MintShort,
    BurnShort,
    AddLong,
    RemoveLong,
    ExerciseToken,
    SettleAccount,
    // actions that influence more than one subAccounts:
    // These actions are defined in "OptionTransferable"
    MintShortIntoAccount, // increase short (debt) position in one subAccount, increase long token directly to another subAccount
    TransferCollateral, // transfer collateral directly to another subAccount
    TransferLong, // transfer long directly to another subAccount
    TransferShort // transfer short directly to another subAccount
}


// File: src/config/constants.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

///@dev unit used for option amount and strike prices
uint8 constant UNIT_DECIMALS = 6;

///@dev unit scaled used to convert amounts.
uint256 constant UNIT = 10 ** 6;

///@dev int scaled used to convert amounts.
int256 constant sUNIT = int256(10 ** 6);

///@dev maximum dispute period for oracle
uint256 constant MAX_DISPUTE_PERIOD = 6 hours;


// File: src/config/errors.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* ------------------------ *
 *      Shared Errors       *
 * -----------------------  */

error NoAccess();

/* ------------------------ *
 *      Pomace Errors       *
 * -----------------------  */

/// @dev asset already registered
error PM_AssetAlreadyRegistered();

/// @dev margin engine already registered
error PM_EngineAlreadyRegistered();

/// @dev amounts length specified to batch settle doesn't match with tokenIds
error PM_WrongArgumentLength();

/// @dev cannot settle an unexpired option
error PM_NotExpired();

/// @dev settlement price is not finalized yet
error PM_PriceNotFinalized();

/// @dev cannot mint token after expiry
error PM_InvalidExpiry();

/// @dev cannot mint token with zero settlement window
error PM_InvalidExerciseWindow();

/// @dev cannot mint token with zero settlement window
error PM_InvalidCollateral();

/// @dev burn or mint can only be called by corresponding engine.
error PM_Not_Authorized_Engine();

/* ---------------------------- *
 *   Common BaseEngine Errors   *
 * ---------------------------  */

/// @dev account is not healthy / account is underwater
error BM_AccountUnderwater();

/// @dev msg.sender is not authorized to ask margin account to pull token from {from} address
error BM_InvalidFromAddress();


// File: src/config/types.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./enums.sol";

/**
 * @dev struct representing the current balance for a given collateral
 * @param collateralId pomace asset id
 * @param amount amount the asset
 */
struct Balance {
    uint8 collateralId;
    uint80 amount;
}

/**
 * @dev struct containing assets detail for an product
 * @param underlying    underlying address
 * @param strike        strike address
 * @param collateral    collateral address
 * @param collateralDecimals collateral asset decimals
 */
struct ProductDetails {
    address engine;
    uint8 engineId;
    address underlying;
    uint8 underlyingId;
    uint8 underlyingDecimals;
    address strike;
    uint8 strikeId;
    uint8 strikeDecimals;
    address collateral;
    uint8 collateralId;
    uint8 collateralDecimals;
}

// todo: update doc
struct ActionArgs {
    ActionType action;
    bytes data;
}

struct BatchExecute {
    address subAccount;
    ActionArgs[] actions;
}

/**
 * @dev asset detail stored per asset id
 * @param addr address of the asset
 * @param decimals token decimals
 */
struct AssetDetail {
    address addr;
    uint8 decimals;
}


// File: src/interfaces/IOracle.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOracle {
    /**
     * @notice  get spot price of _base, denominated in _quote.
     * @param _base base asset. for ETH/USD price, ETH is the base asset
     * @param _quote quote asset. for ETH/USD price, USD is the quote asset
     * @return price with 6 decimals
     */
    function getSpotPrice(address _base, address _quote) external view returns (uint256);

    /**
     * @dev get expiry price of underlying, denominated in strike asset.
     * @param _base base asset. for ETH/USD price, ETH is the base asset
     * @param _quote quote asset. for ETH/USD price, USD is the quote asset
     * @param _expiry expiry timestamp
     *
     * @return price with 6 decimals
     */
    function getPriceAtExpiry(address _base, address _quote, uint256 _expiry)
        external
        view
        returns (uint256 price, bool isFinalized);

    /**
     * @dev return the maximum dispute period for the oracle
     * @dev this will only be checked during oracle registration, as a soft constraint on integrating oracles.
     */
    function maxDisputePeriod() external view returns (uint256 disputePeriod);
}


