// File: contracts/interfaces/IAnkrETH.sol
// SPDX-License-Identifier: GPL-3.0

/// @dev https://etherscan.io/token/0xE95A203B1a91a908F9B9CE46459d101078c2c3cb#code
interface IAnkrETH {
    /**
     * @notice Returns the current amount of ETH underlying the amount of ankrETH
     * @param amount The amount of ankrETH to convert to ETH
     * returns 1:1 if no reprice has occurred otherwise it returns the amount * rate.
     * @return The current ankrETH to ETH rate.
     */
    function sharesToBonds(uint256 amount) external view returns (uint256);

    function bondsToShares(uint256 amount) external view returns (uint256);
}


// File: contracts/interfaces/IOracle.sol
// SPDX-License-Identifier: GPL-3.0-or-later

interface IOracle {
    function priceDecimals() external view returns (uint256);

    function getData() external view returns (uint256, bool);
}


// File: contracts/oracles/AnkrETHOracle.sol
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.4;

import {IOracle} from "../interfaces/IOracle.sol";
import {IAnkrETH} from "../interfaces/IAnkrETH.sol";

/**
 * @title ankrETH Oracle
 *
 * @notice Provides an ankrETH:ETH rate for a button wrapper to use
 */
contract AnkrETHOracle is IOracle {
    /// @dev The output price has a 18 decimal point precision.
    uint256 public constant PRICE_DECIMALS = 18;
    // The address of the ankerETH contract
    IAnkrETH public immutable ankerETH;

    constructor(IAnkrETH ankerETH_) {
        ankerETH = ankerETH_;
    }

    /**
     * @notice Fetches the decimal precision used in the market price
     * @return priceDecimals_: Number of decimals in the price
     */
    function priceDecimals() external pure override returns (uint256) {
        return PRICE_DECIMALS;
    }

    /**
     * @notice Fetches the latest ankrETH:ETH exchange rate from ankrETH contract.
     * The returned value is specifically how much ETH is represented by 1e18 raw units of ankrETH.
     * @dev The returned value is considered to be always valid since it is derived directly from
     *   the source token.
     * @return Value: Latest market price as an `priceDecimals` decimal fixed point number.
     *         valid: Boolean indicating an value was fetched successfully.
     */
    function getData() external view override returns (uint256, bool) {
        return (ankerETH.sharesToBonds(1e18), true);
    }
}


