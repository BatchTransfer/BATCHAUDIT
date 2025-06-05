// File: contracts/Dependencies/TellorCaller.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "../Interfaces/ITellorCaller.sol";
import "./ITellor.sol";
import "./SafeMath.sol";
/*
* This contract serves as an example of how to integrate the Tellor oracle into a Liquity-like system. It
* utilizes a best practice for using Tellor by implementing a time buffer. In addition, by caching the most 
* recent value and timestamp, it also seeks to limit dispute attacks.
* 
* This contract has a single external function that calls Tellor: getTellorCurrentValue(). 
*
* The function is called by the Liquity contract PriceFeed.sol. If any of its inner calls to Tellor revert, 
* this function will revert, and PriceFeed will catch the failure and handle it accordingly.
*
*/
contract TellorCaller is ITellorCaller {
    ITellor public tellor;

    mapping (bytes32 => uint256) public lastStoredTimestamps;
    mapping (bytes32 => uint256) public lastStoredPrices;

    constructor (address payable _tellorOracleAddress) public {
        tellor = ITellor(_tellorOracleAddress);
    }

    /*
    * getTellorCurrentValue(): retrieves most recent value with a 20 minute time buffer.
    * This buffer can be updated before deployment.
    *
    * @dev Allows the user to get the latest value with a time buffer for the queryId specified
    * @param _queryId is the queryId to look up the value for
    * @return ifRetrieve bool true if it is able to retrieve a value and the value's timestamp
    * @return value the value retrieved, converted from bytes to a uint256 value
    * @return _timestampRetrieved the value's timestamp
    */
    function getTellorCurrentValue(bytes32 _queryId)
        external
        override
        returns (
            bool ifRetrieve,
            uint256 value,
            uint256 _timestampRetrieved
        )
    {
        // retrieve most recent 20+ minute old value for a queryId. the time buffer allows time for a bad value to be disputed
        (, bytes memory data, uint256 timestamp) = tellor.getDataBefore(_queryId, block.timestamp - 20 minutes);
        uint256 _value = abi.decode(data, (uint256));
        if (timestamp == 0 || _value == 0) return (false, _value, timestamp);
        if (timestamp > lastStoredTimestamps[_queryId]) {
            lastStoredTimestamps[_queryId] = timestamp;
            lastStoredPrices[_queryId] = _value;
            return (true, _value, timestamp);
        } else {
            return (true, lastStoredPrices[_queryId], lastStoredTimestamps[_queryId]);
        }
    }
}

// File: contracts/Interfaces/ITellorCaller.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface ITellorCaller {
    function getTellorCurrentValue(bytes32 _requestId) external returns (bool, uint256, uint256);
}

// File: contracts/Dependencies/ITellor.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface ITellor {
    function getDataBefore(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (bool _ifRetrieve, bytes memory _value, uint256 _timestampRetrieved);
}

// File: contracts/Dependencies/SafeMath.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

/**
 * Based on OpenZeppelin's SafeMath:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol
 *
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


