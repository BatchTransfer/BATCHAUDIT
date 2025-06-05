// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./IERC5192Minimal.sol";

abstract contract Sbt is IERC5192 {
  mapping(uint256 => bool) _tokenLocked;

    /**
   * @dev Modifier to restrict transfer
   */
  modifier isUnLocked(uint256 tokenId) {
    require(!locked(tokenId));
    _;
  }

   /**
     * @dev get token lock status
     * @return bool true if token is locked, or false
     */
  function locked(uint256 tokenId) public view override virtual returns (bool) {
    return _tokenLocked[tokenId];
  }

  /**
     * @dev internal lock function
     */
  function _lock(uint256 tokenId) internal virtual {
    _tokenLocked[tokenId] = true;
    emit Locked(tokenId);
  }

  /**
     * @dev internal unlock function
     */
  function _unlock(uint256 tokenId) internal virtual {
    _tokenLocked[tokenId] = false;
    emit Unlocked(tokenId);
  }
}
