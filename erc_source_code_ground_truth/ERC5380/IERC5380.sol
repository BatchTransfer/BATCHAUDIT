/// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

interface ERC5380Entitlement is ERC165 {
    /// @notice Emitted when the amount of entitlement a user has changes. If user is the zero address, then the user is the owner
    event EntitlementChanged(address indexed user, address indexed contract, uint256 indexed tokenId);

    /// @notice             Set the user associated with the given ERC-721 token as long as the owner is msg.sender.
    /// @dev                SHOULD NOT revert if the owner is not msg.sender.
    /// @param  user        The user to grant the entitlement to
    /// @param  contract    The property to grant
    /// @param  tokenId     The tokenId to grant the properties of
    function entitle(address user, address contract, uint256 tokenId) external;

    /// @notice             Get the maximum number of users that can receive this entitlement
    /// @param  contract    The contract to query
    /// @param  tokenId     The tokenId to query
    function maxEntitlements(address contract, uint256 tokenId) external view (uint256 max);

    /// @notice             Get the user associated with the given contract and tokenId.
    /// @dev                Defaults to maxEntitlements(contract, tokenId) assigned to contract.ownerOf(tokenId)
    /// @param  user        The user to query
    /// @param  contract    The contract to query
    /// @param  tokenId     The tokenId to query
    function entitlementOf(address user, address contract, uint256 tokenId) external view returns (uint256 amt);
}