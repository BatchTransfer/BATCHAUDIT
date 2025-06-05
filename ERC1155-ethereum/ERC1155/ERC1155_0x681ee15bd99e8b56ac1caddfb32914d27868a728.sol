// File: contracts/_dummy/ArexaDiamondDummyImplementation.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * This is a generated dummy diamond implementation for compatibility with
 * etherscan. For full contract implementation, check out the diamond on https://louper.dev
 */

contract ArexaDiamondDummyImplementation {


    struct Tuple6871229 {
        address facetAddress;
        uint8 action;
        bytes4[] functionSelectors;
    }

    struct Tuple1236461 {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    struct Tuple4951158 {
        uint256 total;
        uint256 sold;
    }

    struct Tuple9951786 {
        int256 quantity;
        int256 deltaPnl;
        int256 payedPnl;
    }
    

   function diamondCut(Tuple6871229[] memory _diamondCut, address  _init, bytes memory _calldata) external {}

   function facetAddress(bytes4  _functionSelector) external view returns (address  facetAddress_) {}

   function facetAddresses() external view returns (address[] memory facetAddresses_) {}

   function facetFunctionSelectors(address  _facet) external view returns (bytes4[] memory facetFunctionSelectors_) {}

   function facets() external view returns (Tuple1236461[] memory facets_) {}

   function supportsInterface(bytes4  _interfaceId) external view returns (bool ) {}

   function implementation() external view returns (address ) {}

   function setDummyImplementation(address  _implementation) external {}

   function owner() external view returns (address ) {}

   function transferOwnership(address  _newOwner) external {}

   function PAUSABLE_AREXA_TOKEN() external view returns (bytes32 ) {}

   function PAUSABLE_FULL() external view returns (bytes32 ) {}

   function PAUSABLE_MAGIC_TOKEN() external view returns (bytes32 ) {}

   function PAUSABLE_SUBSCR1_TOKEN() external view returns (bytes32 ) {}

   function PAUSABLE_SUBSCR2_TOKEN() external view returns (bytes32 ) {}

   function PAUSABLE_TRADER_TOKEN() external view returns (bytes32 ) {}

   function pause(bytes32  target) external {}

   function pauseAllToken() external {}

   function pauseToken(uint256  tokenId) external {}

   function paused(bytes32  target) external view returns (bool  status_) {}

   function unpause(bytes32  target) external {}

   function unpauseAllToken() external {}

   function unpauseToken(uint256  tokenId) external {}

   function AREXA_ADMIN_ROLE() external view returns (bytes32 ) {}

   function getRoleAdmin(bytes32  role) external view returns (bytes32 ) {}

   function grantRole(bytes32  role, address  account) external {}

   function hasRole(bytes32  role, address  account) external view returns (bool ) {}

   function renounceRole(bytes32  role) external {}

   function revokeRole(bytes32  role, address  account) external {}

   function setRoleAdmin(bytes32  role, bytes32  adminRole) external {}

   function getArexaERC20Token() external view returns (address ) {}

   function getPayingToken() external view returns (address ) {}

   function setPayingToken(address  _token) external {}

   function MAGIC100_FIRST_BUYER() external view returns (bytes32 ) {}

   function getAccountBlackWhiteList(bytes32  _target, address  _account) external view returns (bool ) {}

   function getMagic100FirstBuyerWL(address  _account) external view returns (bool ) {}

   function setAccountBlackWhiteList(bytes32  _target, address  _account, bool  _lockValue) external {}

   function setBatchMagic100FirstBuyerWL(address[] memory _addresses, bool  _lockValue) external {}

   function setMagic100FirstBuyerWL(address  _account, bool  _lockValue) external {}

   function AMOUNT_VALUE_TYPE() external view returns (uint8 ) {}

   function AREXA_TOKEN_ID() external view returns (uint256 ) {}

   function AREXA_TOKEN_POOL_AREXAINC() external view returns (uint8 ) {}

   function AREXA_TOKEN_POOL_DEVELOPMENT() external view returns (uint8 ) {}

   function AREXA_TOKEN_POOL_INVESTOR() external view returns (uint8 ) {}

   function AREXA_TOKEN_POOL_MARKETING() external view returns (uint8 ) {}

   function AREXA_TOKEN_POOL_RESERVED() external view returns (uint8 ) {}

   function MAGIC_TOKEN_ID() external view returns (uint256 ) {}

   function QUANTITY_VALUE_TYPE() external view returns (uint8 ) {}

   function SUBSCR1_TOKEN_TYPE() external view returns (uint256 ) {}

   function SUBSCR2_TOKEN_TYPE() external view returns (uint256 ) {}

   function TRADER_TOKEN_ID() external view returns (uint256 ) {}

   function buyArexaToken(uint128  value, uint8  valueType) external {}

   function buyEdgeSubscription(uint32  quantity) external {}

   function buyMagic100Token() external {}

   function buyOracleSubscription(uint32  quantity) external {}

   function buySubscription(uint256  tokenId, uint32  quantity) external {}

   function buyTraderToken(uint128  value, uint8  valueType) external {}

   function calcSubscriptionPrice(uint256  tokenId, uint32  quantity) external view returns (uint256 ) {}

   function getCurrentSubscriptionTokenId(uint256  tokenType) external view returns (uint256 ) {}

   function buyMagic100TokenAdmin(address  toAccount) external {}

   function createSubscription(uint256  tokenType, uint16  year, uint8  month, uint256  quantity, uint256  min, uint256  max) external returns (uint256  tokenId) {}

   function getArexaTokenPool(uint8  _tokenType) external view returns (Tuple4951158 memory) {}

   function payArexaTokenFromPool(uint8  poolType, address  account, uint32  quantity) external {}

   function calcDivident(address  account) external view returns (int256 ) {}

   function getArexaIncomeParameter(uint256  tokenId) external view returns (uint32  pool_, uint32  arexa_) {}

   function getInventory() external view returns (bool  isEnabled, int256  sumQuantity, int256  sumAmount, int256  sumPnl) {}

   function getInventoryItem(address  account) external view returns (Tuple9951786 memory) {}

   function payoutArexaDivident(address  toAccount, uint256  value) external {}

   function payoutArexaIncome(address  toAccount, uint256  value) external {}

   function payoutDivident(uint256  value) external {}

   function setArexaIncomeParameter(uint256  tokenId, uint32  pool, uint32  arexa) external {}

   function calcUnrestrictedAmount(address  account, uint256  tokenId, uint256  amount) external view returns (uint256 ) {}

   function checkRestriction(address  account, uint256  tokenId, uint256  amount) external view {}

   function checkRestrictions(address  account, uint256[] memory tokenIds, uint256[] memory amounts) external view {}

   function stakeArexaToken(uint256  quantity) external {}

   function withdrawArexaToken(address  fromAccount, address  toAccount, uint256  _quantity) external {}

   function balanceOf(address  _owner, uint256  _id) external view returns (uint256 ) {}

   function balanceOfBatch(address[] memory _owners, uint256[] memory _ids) external view returns (uint256[] memory) {}

   function isApprovedForAll(address  _owner, address  _operator) external view returns (bool ) {}

   function name() external view returns (string memory) {}

   function safeBatchTransferFrom(address  _from, address  _to, uint256[] memory _ids, uint256[] memory _values, bytes memory _data) external {}

   function safeTransferFrom(address  _from, address  _to, uint256  _id, uint256  _value, bytes memory _data) external {}

   function setApprovalForAll(address  _operator, bool  _approved) external {}

   function symbol() external view returns (string memory) {}

   function allowance(address  _owner, address  _operator, uint256  _id) external view returns (uint256 ) {}

   function approve(address  _operator, uint256  _id, uint256  _currentValue, uint256  _newValue) external {}

   function isOperatorSpendingLimitEnabled(uint256  _tokenId) external view returns (bool ) {}

   function setOperatorSpendingLimitEnabled(uint256  _tokenId, bool  _enabled) external {}

   function accountsByToken(uint256  _id) external view returns (address[] memory) {}

   function tokensByAccount(address  _account) external view returns (uint256[] memory) {}

   function totalHolders(uint256  _id) external view returns (uint256 ) {}

   function totalSupply(uint256  _id) external view returns (uint256 ) {}

   function getTokenBaseUri() external view returns (string memory) {}

   function getTokenUri(uint256  _id) external view returns (string memory) {}

   function getUri() external view returns (string memory) {}

   function setTokenBaseURI(string memory newuri) external {}

   function setTokenURI(uint256  _id, string memory newuri) external {}

   function setURI(string memory newuri) external {}

   function uri(uint256  _id) external view returns (string memory) {}

   function onERC1155BatchReceived(address  _operator, address  _from, uint256[] memory _ids, uint256[] memory _values, bytes memory _data) external returns (bytes4 ) {}

   function onERC1155Received(address  _operator, address  _from, uint256  _id, uint256  _value, bytes memory _data) external returns (bytes4 ) {}
}


