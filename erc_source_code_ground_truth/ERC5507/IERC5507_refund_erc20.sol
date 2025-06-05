// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.17;

import "ERC20.sol";
import "ERC165.sol";

/// @notice Refundable ERC-20 tokens
/// @dev    The ERC-165 identifier of this interface is `0xf0ca2917`
interface ERC20Refund is ERC20, ERC165 {
    /// @notice           Emitted when a token is refunded
    /// @dev              Emitted by `refund`
    /// @param  _from     The account whose assets are refunded
    /// @param  _amount   The amount of token (in terms of the indivisible unit) that was refunded
    event Refund(
        address indexed _from,
        uint256 indexed _amount
    );

    /// @notice           Emitted when a token is refunded
    /// @dev              Emitted by `refundFrom`
    /// @param  _sender   The account that sent the refund
    /// @param  _from     The account whose assets are refunded
    /// @param  _amount   The amount of token (in terms of the indivisible unit) that was refunded
    event RefundFrom(
        address indexed _sender,
        address indexed _from,
        uint256 indexed _amount
    );

    /// @notice         As long as the refund is active, refunds the user
    /// @dev            Make sure to check that the user has the token, and be aware of potential re-entrancy vectors
    /// @param  amount  The `amount` to refund
    function refund(uint256 amount) external;

    /// @notice         As long as the refund is active and the sender has sufficient approval, refund the tokens and send the ether to the sender
    /// @dev            Make sure to check that the user has the token, and be aware of potential re-entrancy vectors
    ///                 The ether goes to msg.sender.
    /// @param  from    The user from which to refund the assets
    /// @param  amount  The `amount` to refund
    function refundFrom(address from, uint256 amount) external;

    /// @notice         Gets the refund price
    /// @return _wei    The amount of ether (in wei) that would be refunded for a single token unit (10**decimals indivisible units)
    function refundOf() external view returns (uint256 _wei);
 
    /// @notice         Gets the first block for which the refund is not active
    /// @return block   The first block where the token cannot be refunded
    function refundDeadlineOf() external view returns (uint256 block);
}

interface IERC20 {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);
}