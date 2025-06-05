// File: contracts/_dummy/ArexaDiamondDummyImplementation.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

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
    

   function diamondCut(Tuple6871229[] memory _diamondCut, address  _init, bytes memory _calldata) external {}

   function facetAddress(bytes4  _functionSelector) external view returns (address  facetAddress_) {}

   function facetAddresses() external view returns (address[] memory facetAddresses_) {}

   function facetFunctionSelectors(address  _facet) external view returns (bytes4[] memory facetFunctionSelectors_) {}

   function facets() external view returns (Tuple1236461[] memory facets_) {}

   function supportsInterface(bytes4  _interfaceId) external view returns (bool ) {}

   function implementation() external view returns (address ) {}

   function setDummyImplementation(address  _implementation) external {}

   function owner() external view returns (address ) {}

   function transferOwnership(address  newOwner) external {}

   function PAUSABLE_AREXA_TOKEN() external view returns (bytes32 ) {}

   function PAUSABLE_FULL() external view returns (bytes32 ) {}

   function PAUSABLE_MAGIC_TOKEN() external view returns (bytes32 ) {}

   function PAUSABLE_SUBSCR1_TOKEN() external view returns (bytes32 ) {}

   function PAUSABLE_SUBSCR2_TOKEN() external view returns (bytes32 ) {}

   function PAUSABLE_TRADER_TOKEN() external view returns (bytes32 ) {}

   function pause(bytes32  target) external {}

   function pauseAllToken() external {}

   function pauseToken(uint256  tokenId) external {}

   function paused(bytes32  target) external view returns (bool ) {}

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

   function setPayingToken(address  token) external {}

   function MAGIC100_FIRST_BUYER() external view returns (bytes32 ) {}

   function getAccountBlackWhiteList(bytes32  target, address  account) external view returns (bool ) {}

   function getMagic100FirstBuyerWL(address  account) external view returns (bool ) {}

   function setAccountBlackWhiteList(bytes32  target, address  account, bool  lockValue) external {}

   function setBatchMagic100FirstBuyerWL(address[] memory addresses, bool  lockValue) external {}

   function setMagic100FirstBuyerWL(address  account, bool  lockValue) external {}

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

   function buyArexaTokenAdmin(address  toAccount, uint128  value, uint8  valueType, uint16  discountPercent) external {}

   function buyEdgeSubscriptionAdmin(address  toAccount, uint32  quantity, uint16  discountPercent) external {}

   function buyMagic100TokenAdmin(address  toAccount, uint16  discountPercent) external {}

   function buyOracleSubscriptionAdmin(address  toAccount, uint32  quantity, uint16  discountPercent) external {}

   function buySubscriptionAdmin(address  toAccount, uint256  tokenId, uint32  quantity, uint16  discountPercent) external {}

   function buyTraderTokenAdmin(address  toAccount, uint128  value, uint8  valueType, uint16  discountPercent) external {}

   function createSubscription(uint256  tokenType, uint16  year, uint8  month, uint256  quantity, uint256  min, uint256  max) external returns (uint256  tokenId) {}

   function getArexaTokenPool(uint8  tokenType) external view returns (uint256  total, uint256  sold) {}

   function payArexaTokenFromPool(uint8  poolType, address  account, uint32  quantity) external {}

   function calcDivident(address  account) external view returns (int256 ) {}

   function getArexaIncomeParameter(uint256  tokenId) external view returns (uint32  pool, uint32  arexa) {}

   function getInventory() external view returns (bool  isEnabled, int256  sumQuantity, int256  sumAmount, int256  sumPnl) {}

   function getInventoryItem(address  account) external view returns (int256  quantity, int256  deltaPnl, int256  payedPnl) {}

   function getPoolAndArexaIncomeBalances() external view returns (uint256  pool, uint256  poolPaidOut, uint256  arexa, uint256  arexaPaidOut) {}

   function payoutArexaDivident(address  toAccount, uint256  value) external {}

   function payoutArexaIncome(address  toAccount, uint256  value) external {}

   function payoutDivident(uint256  value) external {}

   function setArexaIncomeParameter(uint256  tokenId, uint32  pool, uint32  arexa) external {}

   function calcUnrestrictedAmount(address  account, uint256  tokenId, uint256  amount) external view returns (uint256 ) {}

   function checkRestriction(address  account, uint256  tokenId, uint256  amount) external view returns (bool ) {}

   function checkRestrictions(address  account, uint256[] memory tokenIds, uint256[] memory amounts) external view returns (bool ) {}

   function stakeArexaToken(uint256  quantity) external {}

   function withdrawArexaToken(address  fromAccount, address  toAccount, uint256  quantity) external {}

   function balanceOf(address  owner_, uint256  id) external view returns (uint256 ) {}

   function balanceOfBatch(address[] memory owners, uint256[] memory ids) external view returns (uint256[] memory) {}

   function isApprovedForAll(address  owner_, address  operator) external view returns (bool ) {}

   function name() external view returns (string memory) {}

   function safeBatchTransferFrom(address  from, address  to, uint256[] memory ids, uint256[] memory values, bytes memory data) external {}

   function safeTransferFrom(address  from, address  to, uint256  id, uint256  value, bytes memory data) external {}

   function setApprovalForAll(address  operator, bool  approved) external {}

   function symbol() external view returns (string memory) {}

   function allowance(address  owner_, address  operator, uint256  id) external view returns (uint256 ) {}

   function approve(address  operator, uint256  id, uint256  currentValue, uint256  newValue) external {}

   function isOperatorSpendingLimitEnabled(uint256  tokenId) external view returns (bool ) {}

   function setOperatorSpendingLimitEnabled(uint256  tokenId, bool  enabled) external {}

   function accountsByToken(uint256  id) external view returns (address[] memory) {}

   function tokensByAccount(address  account) external view returns (uint256[] memory) {}

   function totalHolders(uint256  id) external view returns (uint256 ) {}

   function totalSupply(uint256  id) external view returns (uint256 ) {}

   function getTokenBaseUri() external view returns (string memory) {}

   function getTokenUri(uint256  id) external view returns (string memory) {}

   function getUri() external view returns (string memory) {}

   function setTokenBaseURI(string memory newuri) external {}

   function setTokenURI(uint256  id, string memory newuri) external {}

   function setURI(string memory newuri) external {}

   function uri(uint256  id) external view returns (string memory) {}

   function onERC1155BatchReceived(address  operator, address  from, uint256[] memory ids, uint256[] memory values, bytes memory data) external returns (bytes4 ) {}

   function onERC1155Received(address  operator, address  from, uint256  id, uint256  value, bytes memory data) external returns (bytes4 ) {}
}


