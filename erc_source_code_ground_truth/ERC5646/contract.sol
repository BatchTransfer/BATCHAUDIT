pragma solidity ^0.8.0;

/// @title Example of a mutable token implementing state fingerprint.
contract LPToken is ERC721, ERC5646 {

    /// @dev Stored token states (token id => state).
    mapping (uint256 => State) internal states;

    struct State {
        address asset1;
        address asset2;
        uint256 amount1;
        uint256 amount2;
        uint256 fee; // Immutable
        address operator; // Immutable
        uint256 expiration; // Parameter dependent on a block.timestamp
    }


    /// @dev State fingerprint getter.
    /// @param tokenId Id of a token state in question.
    /// @return Current token state fingerprint.
    function getStateFingerprint(uint256 tokenId) override public view returns (bytes32) {
        State storage state = states[tokenId];

        return keccak256(
            abi.encode(
                state.asset1,
                state.asset2,
                state.amount1,
                state.amount2,
                // state.fee don't need to be part of the fingerprint computation as it is immutable
                // state.operator don't need to be part of the fingerprint computation as it is immutable
                block.timestamp >= state.expiration
            )
        );
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId) ||
            interfaceId == type(ERC5646).interfaceId;
    }

}