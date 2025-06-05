// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.21;

import {IERC7401} from "@rmrk-team/evm-contracts/contracts/RMRK/nestable/IERC7401.sol";


interface IPassport is IERC7401{

    function getOwnerTokenId(address owner) external view returns(uint256 tokenId);
    
}
