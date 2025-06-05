// File: contracts/facets/Create1155SaleFacet.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { LibAppStorage, Modifiers, CustomErrors, Sale, Tier, Partner, PaymentTokenMaxSupply} from "../libraries/LibAppStorage.sol";
import { LibCreateSale } from "contracts/libraries/LibCreateSale.sol";

/** 
* @title Create1155SaleFacet
* @author Robert Gordon Palmer
* @dev This contract is used to create sales for ERC1155 tokens.
*/
contract Create1155SaleFacet is Modifiers, CustomErrors {

    /** 
    * @notice Creates a new sale for ERC1155 tokens.
    * @param collectionAddress The address of the collection.
    * @param tiersNumbers An array of tier numbers.
    * @param limitPerWalletPerTier An array of limits per wallet per tier.
    * @param starts An array of start times for each tier.
    * @param ends An array of end times for each tier.
    * @param merkleRoots An array of merkle roots for each tier.
    * @param isTierPublic An array of booleans indicating if each tier is public.
    * @param idsAvailable An array of arrays of available IDs for each tier.
    * @param paymentTokens An array of payment tokens.
    * @param paymentTokenMaxSupplies An array of max supplies for each payment token.
    */
    function create1155Sale(
        address collectionAddress,
        uint256[] memory tiersNumbers,
        uint256[] memory limitPerWalletPerTier,
        uint256[] memory starts,
        uint256[] memory ends,
        bytes32[] memory merkleRoots,
        bool[] memory isTierPublic,
        uint256[][] memory idsAvailable,
        address[] memory paymentTokens,
        uint256[] memory paymentTokenMaxSupplies
    ) public onlyAdminOrOwner(msg.sender){
        if(tiersNumbers.length != starts.length) revert ArrayLengthsDiffer();
        if(tiersNumbers.length != ends.length) revert ArrayLengthsDiffer();
        if(tiersNumbers.length != merkleRoots.length) revert ArrayLengthsDiffer();
        if(tiersNumbers.length != limitPerWalletPerTier.length) revert ArrayLengthsDiffer();
        if(tiersNumbers.length != isTierPublic.length) revert ArrayLengthsDiffer();
        if(tiersNumbers.length != idsAvailable.length) revert ArrayLengthsDiffer();

        s.totalSales++;
        uint256 _saleId = s.totalSales;
        uint256 _length = tiersNumbers.length;

        for (uint256 i = 0; i < _length; i++) {
            s.saleId[_saleId].tiers.push(Tier({
                tierNumber: tiersNumbers[i],
                start: starts[i],
                end: ends[i],
                merkleRoot: merkleRoots[i],
                limitPerWallet: limitPerWalletPerTier[i],
                availableIds: idsAvailable[i],
                isPublic: isTierPublic[i]
            }));
            s.saleId[_saleId].collectionERCType = 1155;
        }
        LibCreateSale._setPaymentTokensMaxSupplies(_saleId, paymentTokens, paymentTokenMaxSupplies);
        s.saleId[_saleId].collectionAddress = collectionAddress;
        s.collectionSaleId[collectionAddress] = _saleId;
    }


    /** 
    * @notice Creates a new ERC1155 collection contract and new sale for ERC1155 tokens.
    * @param _baseURI The base URI for the collection.
    * @param _name The name of the collection.
    * @param _symbol The symbol of the collection.
    * @param tiersNumbers An array of tier numbers.
    * @param limitPerWalletPerTier An array of limits per wallet per tier.
    * @param starts An array of start times for each tier.
    * @param ends An array of end times for each tier.
    * @param merkleRoots An array of merkle roots for each tier.
    * @param isTierPublic An array of booleans indicating if each tier is public.
    * @param idsAvailable An array of arrays of available IDs for each tier.
    * @param collectionIds An array of tokenIds that will be included in the sale.
    * @param collectionIdsMaxSupplies An array of max supply values for the associated tokenIds.
    * @param paymentTokens An array of payment tokens.
    * @param paymentTokenMaxSupplies An array of max supplies for each payment token.
    */
    function createSaleAndCollection1155(
        string memory _baseURI,
        string memory _name,
        string memory _symbol,
        uint256[] memory tiersNumbers,
        uint256[] memory limitPerWalletPerTier,
        uint256[] memory starts,
        uint256[] memory ends,
        bytes32[] memory merkleRoots,
        bool[] memory isTierPublic,
        uint256[][] memory idsAvailable,
        uint256[] memory collectionIds,
        uint256[] memory collectionIdsMaxSupplies,
        address[] memory paymentTokens,
        uint256[] memory paymentTokenMaxSupplies
    ) public onlyAdminOrOwner(msg.sender){
        if(tiersNumbers.length != starts.length) revert ArrayLengthsDiffer();
        if(tiersNumbers.length != ends.length) revert ArrayLengthsDiffer();
        if(tiersNumbers.length != merkleRoots.length) revert ArrayLengthsDiffer();
        if(tiersNumbers.length != limitPerWalletPerTier.length) revert ArrayLengthsDiffer();
        if(tiersNumbers.length != isTierPublic.length) revert ArrayLengthsDiffer();
        if(tiersNumbers.length != idsAvailable.length) revert ArrayLengthsDiffer();

        s.totalSales++;
        uint256 _saleId = s.totalSales;
        uint256 _length = tiersNumbers.length;

        for (uint256 i = 0; i < _length; i++) {
            s.saleId[_saleId].tiers.push(Tier({
                tierNumber: tiersNumbers[i],
                start: starts[i],
                end: ends[i],
                merkleRoot: merkleRoots[i],
                limitPerWallet: limitPerWalletPerTier[i],
                availableIds: idsAvailable[i],
                isPublic: isTierPublic[i]
            }));
            s.saleId[_saleId].collectionERCType = 1155;
        }

        LibCreateSale._setPaymentTokensMaxSupplies(_saleId, paymentTokens, paymentTokenMaxSupplies);

        address _collectionAddress = LibCreateSale._create1155Collection(
            _baseURI, 
            _name, 
            _symbol, 
            collectionIds, 
            collectionIdsMaxSupplies, 
            msg.sender
        );
        s.saleId[_saleId].collectionAddress = _collectionAddress;
        s.collectionSaleId[_collectionAddress] = _saleId;
    }

    /**
    * @notice Retrieves the token prices for a given sale and payment token.
    * @param _saleId The ID of the sale for which the token prices are retrieved.
    * @param _paymentToken The address of the payment token for which the prices are retrieved.
    */
    function getTokenPrices(
        uint256 _saleId, 
        address _paymentToken
    ) public view returns(uint256[] memory, uint256[] memory){
        return LibCreateSale._getTokenPrices(_saleId, _paymentToken);
    }

    /**
    * @notice Retireves the saleId associated with the given collection address.
    * @param _collectionAddress The address of the collection for which the saleId is retrieved.
    */
    function getCollectionSaleId(address _collectionAddress) public view returns (uint256 _saleId){
        return LibCreateSale._getSaleIdForCollection(_collectionAddress);
    }

    /**
    * @notice Assigns the prices per tokenId for a given sale and payment tokens.
    * @param _saleId The ID of the sale for which the prices are assigned.
    * @param _paymentTokens An array of addresses representing the payment tokens for which the prices are assigned.
    * @param _prices A nested array of uint256 values representing the prices per tokenId for each payment token.
    */
    function assignPricePerTokenId(
        uint256 _saleId,
        address[] memory _paymentTokens,
        uint256[][] memory _prices
    ) public onlyAdminOrOwner(msg.sender){
        LibCreateSale._assignPricePerTokenId(_saleId, _paymentTokens, _prices);
    }

    /**
    * @notice Retrieves the information of a specific sale.
    * @param _saleId The ID of the sale for which the information is retrieved.
    * @return A struct of type `Sale` containing the information of the specified sale.
    */
    function saleInfo(uint256 _saleId) external view returns (Sale memory){
        return LibCreateSale.getSaleInfo(_saleId);
    }

    /**
    * @notice Retrieves the information of a specific sale along with the token prices and IDs for a given payment token.
    * @param _saleId The ID of the sale for which the information is retrieved.
    * @param _paymentToken The address of the payment token for which prices and IDs are retrieved.
    * @return _saleInfo A struct of type `Sale` containing the information of the specified sale.
    * @return _prices An array of uint256 values representing the token prices for the specified sale and payment token.
    * @return _ids An array of uint256 values representing the token IDs available for the specified sale and payment token.
    */
    function saleInfoAndPrices(
        uint256 _saleId, 
        address _paymentToken
    ) external view returns (Sale memory _saleInfo, uint256[] memory _prices, uint256[] memory _ids){
        _saleInfo = LibCreateSale.getSaleInfo(_saleId);
        (_prices, _ids) = LibCreateSale._getTokenPrices(_saleId, _paymentToken);

        return (_saleInfo, _prices, _ids);
    }

    /**
    * @notice Retrieves the available token IDs for a specific sale and tier number.
    * @param _saleId The ID of the sale for which the available token IDs are retrieved.
    * @param _tierNumber The tier number for which the available token IDs are retrieved.
    * @return An array of uint256 values representing the available token IDs for the specified sale and tier number.
    */
    function availableIdsByTier(uint256 _saleId, uint256 _tierNumber) external view returns (uint256[] memory){
        return LibCreateSale.getAvailableIdsByTier(_saleId, _tierNumber);
    }

    /**
    * @notice Retrieves the available token IDs for a specific sale.
    * @param _saleId The ID of the sale for which the available token IDs are retrieved.
    * @return An array of uint256 values representing the available token IDs for the specified sale.
    */
    function availableIdsBySale(uint256 _saleId) external view returns (uint256[] memory){
        return LibCreateSale.getAvailableIdsBySale(_saleId);
    }

    /**
    * @notice Retrieves the information of a specific tier within a sale.
    * @param _saleId The ID of the sale for which the tier information is retrieved.
    * @param _tierNumber The tier number for which the information is retrieved.
    * @return A struct of type `Tier` containing the information of the specified tier within the sale.
    */
    function tierInfo(uint256 _saleId, uint256 _tierNumber) external view returns (Tier memory){
        return LibCreateSale.getTierInfo(_saleId, _tierNumber);
    }

    /**
    * @notice Assigns partner addresses and their corresponding percentages to a specified sale.
    * @param _partnerAddresses An array of addresses representing the partner addresses to be assigned.
    * @param _partnerPercentages An array of uint256 values representing the corresponding percentage allocations for each partner.
    * @param _saleId The ID of the sale to which the partners are being assigned.
    */
    function assignPartners(
        address[] memory _partnerAddresses, 
        uint256[] memory _partnerPercentages, 
        uint256 _saleId
    ) external onlyAdminOrOwner(msg.sender) {
        if(_partnerAddresses.length != _partnerPercentages.length) revert ArrayLengthsDiffer();
        uint256 length = _partnerAddresses.length;
        LibCreateSale._assignPartner(_partnerAddresses, _partnerPercentages, _saleId);
    }

    /**
    * @notice Removes all partner addresses and their corresponding percentages from a specified sale.
    * @param _saleId The ID of the sale from which partners are being removed.
    */
    function removePartners(uint256 _saleId) external onlyAdminOrOwner(msg.sender){
        LibCreateSale._removePartners(_saleId);
    }

    /**
    * @notice Retrieves the partner addresses and their corresponding percentages for a specified sale.
    * @param _saleId The ID of the sale for which the partner information is retrieved.
    * @return An array of structs of type `Partner` containing the partner addresses and their corresponding percentages for the specified sale.
    */
    function getSalePartners(uint256 _saleId) external view onlyAdminOrOwner(msg.sender) returns(Partner[] memory) {
        return LibCreateSale._getSalePartners(_saleId);
    }

    /**
    * @notice Retrieves the payment goal information for a specific sale and payment token.
    * @param _saleId The ID of the sale for which the payment goal information is retrieved.
    * @param _paymentTokenAddress The address of the payment token for which the information is retrieved.
    * @return A struct of type `PaymentTokenMaxSupply` containing the payment goal information for the specified sale and payment token.
    */
    function getPaymentGoalInfo(uint256 _saleId, address _paymentTokenAddress) external view returns(PaymentTokenMaxSupply memory){
        return LibCreateSale._getPaymentGoalInfo(_saleId, _paymentTokenAddress);
    }

    /**
    * @notice Sets the limit per wallet for a specific tier within a sale.
    * @param _saleId The ID of the sale for which the tier limit per wallet is being set.
    * @param _tierNumber The tier number for which the limit per wallet is being set.
    * @param _updatedLimit The updated limit per wallet to be set for the specified tier.
    */
    function setTierLimitPerWallet(uint256 _saleId, uint256 _tierNumber, uint256 _updatedLimit) external onlyAdminOrOwner(msg.sender){
        LibCreateSale._setTierLimitPerWallet(_saleId, _tierNumber, _updatedLimit);
    }
}


// File: contracts/libraries/LibAppStorage.sol
//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibMeta } from "contracts/libraries/LibMeta.sol";

/**
 * @title Tier
 * @dev This struct defines the data structure for a tier in a sale.
 */
struct Tier {
    uint256 tierNumber; // Tier number
    uint256 start; // Start timestamp of the tier
    uint256 end; // End timestamp of the tier
    bytes32 merkleRoot; // Merkle root for the tier
    uint256 limitPerWallet; // Limit the wallet can purcahse for the tier
    uint256[] availableIds; // Array of available IDs for the tier
    bool isPublic; // Flag indicating if the tier is public
}

/**
 * @title Partner
 * @dev This struct defines the data structure for a partner.
 */
struct Partner {
    address partnerAddress; // The partners address; Funds will be sent to this address.
    uint256 sharePercentage;// The partners share of each sale; Paid each time a user mints.
}

/**
 * @title Sale
 * @dev This struct defines the data structure for a sale.
 */
struct Sale {
    Tier[] tiers; // Array of tiers in the sale
    PaymentTokenMaxSupply[] paymentTokensMaxSupplies; // Array of payment tokens and their maximum accepted supplies
    address collectionAddress; // Address of the collection
    uint256 collectionERCType; // ERC type of the collection
    Partner[] partners; // Partners for the sale
}

/**
 * @title PaymentTokenMaxSupply
 * @dev This struct defines the data structure for a payment token and its maximum supply.
 */
struct PaymentTokenMaxSupply {
    address paymentToken;// Address of the payment token
    uint256 maxAcceptedAmount;// Maximum accepted amount for the payment token
    uint256 totalSpent;// Total spent amount for the payment token
}

/**
 * @title AppStorage
 * @dev This struct defines the data structure for storing the state of the application.
 * @dev Always add new members needed to the end of this struct when upgrading or adding a facet.
 */
struct AppStorage {

    bool initialized; // Flag indicating if the contract has been initialized

    address owner; // Address of the contract owner
    address multisig; // Address of the multisig wallet
    address treasuryWallet; // Address of the treasury wallet

    bool paused; // Flag indicating if the contract is paused

    // SaleID => Sale struct containing all Tier strcut info
    mapping(uint256 => Sale) saleId;

    // Mapping of address to admin status
    mapping(address => bool) isAdmin;

    uint256[] emptyArr; // Empty array - used for assigning `availableIds` to a 721 tier

    uint256 totalSales; // Total number of sales

    // User Address => saleId => total minted amount
    mapping(address => mapping(uint256 => uint256)) userMintedAmount;

    // Payment token address => SaleId => price
    mapping(address => mapping(uint256 => uint256)) acceptedTokenPrice;

    mapping(uint256 saleId => mapping(address paymentToken => mapping(uint256 tokenId => uint256 price))) tokenIdPrice;

    // Mapping of address to collection sale ID
    mapping(address => uint256) collectionSaleId;

    // The address for Warm wallet delegation contract
    address warmWalletContractAddress;

    address permit2ContractAddress;
}

library LibAppStorage {

  function diamondStorage() 
    internal 
    pure 
    returns (AppStorage storage ds) 
  {    
    assembly {
      ds.slot := 0
    }
  }
}

/**
 * @title Modifiers
 * @dev This contract contains modifiers used in the facets.
 */
contract Modifiers {
    AppStorage internal s;

    /**
     * @dev Modifier to restrict access to only the admin or owner.
     * @param _address The address to check.
     * Requirements:
     * - The caller must be an admin or owner.
     */
    modifier onlyAdminOrOwner(address _address) {
        //AppStorage storage s = LibAppStorage.diamondStorage();
        require(
            s.isAdmin[_address] || _address == s.owner,
            "This address is not allowed"
        );
        _;
    }

    /**
     * @dev Modifier to restrict access to only the multisig wallet.
     * @param _address The address to check.
     * Requirements:
     * - The caller must be the multisig wallet.
     */
    modifier onlyMultiSig(address _address) {
        //AppStorage storage s = LibAppStorage.diamondStorage();
        require(_address == s.multisig, "Not Multisig wallet");
        _;
    }

    /**
     * @dev Modifier to restrict access when the contract is not paused.
     * Requirements:
     * - The contract must not be paused.
     */
    modifier onlyUnpaused() {
        //AppStorage storage s = LibAppStorage.diamondStorage();
        require(!s.paused, "Sale Stopped Currently");
        _;
    }
}

contract CustomErrors {
    error TotalSupplyGreaterThanMaxSupply();
    error TierNumberIncorrect();
    error ArrayLengthsDiffer();
    error TierLengthTooShort();
    error ClaimPeriodTooShort();
    error PartnerAlreadyExists();
    error PartnerNotFound();
    error InvalidPartnerWallet();
    error InvalidPartnerSharePct();
    error PartnerActive();
    error PartnerDeactivated();
    error InvalidProof();
    error TierPeriodHasntStarted();
    error TierPeriodHasEnded();
    error CurrentlyNotClaimPeriod();
    error MintLimitReached();
    error MaxSupplyReached();
    error AlreadyInitialized();
    error MsgSenderIsNotOwner();
    error IncorrectAddress();
    error BaseURINotSet();
    error TokenNotAcceptedAsPayment();
    error InsufficientBalance();
    error TokenIsSoulbound();
    error NoConfirmedIds();
    error ERCTypeIncorrect();
    error IncorrectHotWallet();
    error WarmLinkExpired();
    error DesiredIdNotAllowed();
    error PriceCannotBeZero();
}


// File: contracts/libraries/LibCreateSale.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { 
    LibAppStorage, 
    AppStorage, 
    CustomErrors, 
    Sale, 
    Tier, 
    PaymentTokenMaxSupply,
    Partner
} from "../libraries/LibAppStorage.sol";
import { Launchpad721 } from "contracts/Launchpad721.sol";
import { Launchpad1155 } from "contracts/Launchpad1155.sol";

/**
@title LibCreateSale
@author Robert Gordon Palmer
@dev Library for creating and managing sales. 
*/ 
library LibCreateSale {

    /**
    * @dev Retrieves the sale information for a given sale ID.
    * @param _saleId The ID of the sale.
    * @return sale_ The Sale struct containing the sale information.
    */
    function getSaleInfo(uint256 _saleId) internal view returns (Sale memory sale_) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        sale_ = s.saleId[_saleId];
    }

    /**
    * @dev Retrieves the sale ID associated with a collection address.
    * @param _collectionAddress The address of the collection.
    * @return _saleId The ID of the sale associated with the collection.
    */
    function _getSaleIdForCollection(address _collectionAddress) internal view returns (uint256 _saleId){
        AppStorage storage s = LibAppStorage.diamondStorage();

        _saleId = s.collectionSaleId[_collectionAddress];
    }

    /**
    * @dev Sets the maximum accepted amounts for payment tokens in a sale.
    * @param _saleId The ID of the sale.
    * @param _paymentTokens The array of payment token addresses.
    * @param _maxAcceptedAmounts The array of maximum accepted amounts for each payment token.
    */
    function _setPaymentTokensMaxSupplies(
        uint256 _saleId,
        address[] memory _paymentTokens, 
        uint256[] memory _maxAcceptedAmounts
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if(_paymentTokens.length != _maxAcceptedAmounts.length) revert CustomErrors.ArrayLengthsDiffer();

        uint256 _length = _paymentTokens.length;

        for(uint256 i = 0; i < _length; i++){
            s.saleId[_saleId].paymentTokensMaxSupplies.push(PaymentTokenMaxSupply({
                paymentToken: _paymentTokens[i],
                maxAcceptedAmount: _maxAcceptedAmounts[i],
                totalSpent: 0
            }));
        }
    }

    /**
    * @dev Retrieves the prices for tokens in a sale for a specific payment token.
    * @param _saleId The ID of the sale.
    * @param _paymentToken The address of the payment token.
    * @return prices The array of token prices.
    * @return availableIds The array of available token IDs.
    */
    function _getTokenPrices(
        uint256 _saleId, 
        address _paymentToken
    ) internal view returns(uint256[] memory, uint256[] memory){
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256[] memory _ids = getAvailableIdsBySale(_saleId);
        uint256 length = _ids.length;
        uint256[] memory prices = new uint256[](length);

        for(uint256 i = 0; i < length; i++){
            prices[i] = s.tokenIdPrice[_saleId][_paymentToken][_ids[i]];
        }

        return (prices, getAvailableIdsBySale(_saleId));
    }

    function _get721Prices(
        uint256 _saleId,
        address _paymentToken
    ) internal view returns(uint256[] memory){
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256[] memory price = new uint256[](1);
        price[0] = s.acceptedTokenPrice[_paymentToken][_saleId];

        return price;
    }

    /**
    * @dev Retrieves the tier information for a given sale ID and tier number.
    * @param _saleId The ID of the sale.
    * @param _tierNumber The number of the tier.
    * @return tier_ The Tier struct containing the tier information.
    */
    function getTierInfo(uint256 _saleId, uint256 _tierNumber) internal view returns (Tier memory){
        AppStorage storage s = LibAppStorage.diamondStorage();

        return s.saleId[_saleId].tiers[_tierNumber - 1];
    }

    function getAvailableIdsByTier(uint256 _saleId, uint256 _tierNumber) internal view returns (uint256[] memory){
        AppStorage storage s = LibAppStorage.diamondStorage();

        if(s.saleId[_saleId].collectionERCType == 721) revert CustomErrors.ERCTypeIncorrect();

        // This is _tierNumber - 1 because when pushing the Tier struct, tier 1 goes into slot 0
        return s.saleId[_saleId].tiers[_tierNumber - 1].availableIds;
    }

    /**
    * @dev Retrieves the total number of elements (token IDs) in a sale.
    * @param _saleId The ID of the sale.
    * @return totalElements The total number of elements in the sale.
    */
    function getTotalElements(uint256 _saleId) internal view returns (uint256 totalElements){
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 _length = s.saleId[_saleId].tiers.length;
        for(uint256 i = 0; i < _length; i++){
            totalElements += s.saleId[_saleId].tiers[i].availableIds.length;
        }

        return totalElements;
    }

    /**
     * @dev Removes duplicate elements from an array.
     * @param array The array to remove duplicates from.
     * @return resultArray The array with duplicate elements removed.
     */
    function _removeDuplicates(uint[] memory array) internal pure returns (uint[] memory) {
        uint[] memory uniqueArray = new uint[](array.length);
        uint uniqueCount = 0;

        for (uint i = 0; i < array.length; i++) {
            bool isDuplicate = false;
            for (uint j = 0; j < uniqueCount; j++) {
                if (array[i] == uniqueArray[j]) {
                    isDuplicate = true;
                    break;
                }
            }
            if (!isDuplicate) {
                uniqueArray[uniqueCount] = array[i];
                uniqueCount++;
            }
        }

        uint[] memory resultArray = new uint[](uniqueCount);
        for (uint i = 0; i < uniqueCount; i++) {
            resultArray[i] = uniqueArray[i];
        }

        return resultArray;
    }

    /**
     * @dev Retrieves the available token IDs for a given sale ID.
     * @param _saleId The ID of the sale.
     * @return _ids The array of available token IDs.
     */
    function getAvailableIdsBySale(uint256 _saleId) internal view returns (uint256[] memory _ids){
        AppStorage storage s = LibAppStorage.diamondStorage();
        if(s.saleId[_saleId].collectionERCType == 721) revert CustomErrors.ERCTypeIncorrect();

        uint256 _length = s.saleId[_saleId].tiers.length;
        uint256 totalElements = getTotalElements(_saleId);

        _ids = new uint256[](totalElements);
        uint256 index = 0;
        for(uint256 i = 0; i < _length; i++){
            for(uint256 j = 0; j < s.saleId[_saleId].tiers[i].availableIds.length; j++){
                if(_ids[index] != s.saleId[_saleId].tiers[i].availableIds[j]){
                    _ids[index] = s.saleId[_saleId].tiers[i].availableIds[j];
                }
                index += 1;
            }
        }
        _ids = _removeDuplicates(_ids);
        return _ids;
    }

    /**
     * @dev Assigns the price per token ID for a given sale ID and payment tokens.
     * @param _saleId The ID of the sale.
     * @param _paymentTokens The array of payment token addresses.
     * @param _prices The array of arrays of prices per token ID.
     */
    function _assignPricePerTokenId(
        uint256 _saleId,
        address[] memory _paymentTokens,
        uint256[][] memory _prices
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256[] memory _ids = getAvailableIdsBySale(_saleId);

        
        if(_prices.length != _paymentTokens.length) revert CustomErrors.ArrayLengthsDiffer();

        uint256 _iLength = _paymentTokens.length;
        uint256 _jLength = _ids.length;

        for(uint256 i = 0; i < _iLength; i++){
            if(_prices[i].length != _ids.length) revert CustomErrors.ArrayLengthsDiffer();
            for(uint256 j = 0; j < _jLength; j++){
                if(_prices[i][j] == 0) revert CustomErrors.PriceCannotBeZero();
                s.tokenIdPrice[_saleId][_paymentTokens[i]][_ids[j]] = _prices[i][j];
            }
        }
    }

    /**
     * @dev Assigns the price per token for a given sale ID and payment tokens (721).
     * @param _saleId The ID of the sale.
     * @param _paymentTokens The array of payment token addresses.
     * @param _prices The array of prices per token ID.
     */
    function _assignPricePerToken721(
        uint256 _saleId,
        address[] memory _paymentTokens,
        uint256[] memory _prices
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if(_prices.length != _paymentTokens.length) revert CustomErrors.ArrayLengthsDiffer();

        uint256 _length = _prices.length;
        for(uint256 i = 0; i < _length; i++){
            if(_prices[i] == 0) revert CustomErrors.PriceCannotBeZero();
            s.acceptedTokenPrice[_paymentTokens[i]][_saleId] = _prices[i];
        }
    }

    /**
     * @dev Creates a new ERC1155 collection.
     * @param _baseURI The base URI for the collection.
     * @param _name The name of the collection.
     * @param _symbol The symbol of the collection.
     * @param _tokenIds The array of token IDs.
     * @param _maxSupplys The array of maximum supplies for each token ID.
     * @param _owner The address of the owner.
     * @return The address of the newly created collection.
     */
    function _create1155Collection(
        string memory _baseURI,
        string memory _name,
        string memory _symbol,
        uint256[] memory _tokenIds,
        uint256[] memory _maxSupplys,
        address _owner
    ) internal returns (address) {
        Launchpad1155 collection = new Launchpad1155();
        collection._erc1155Initializer(_baseURI, _name, _symbol);
        collection.setTokenIdMaxSupply(_tokenIds, _maxSupplys);
        collection.transferOwnership(_owner);
        return address(collection);
    }

    /**
     * @dev Creates a new ERC721 collection.
     * @param _baseURI The base URI for the collection.
     * @param _name The name of the collection.
     * @param _symbol The symbol of the collection.
     * @param _maxSupply The maximum supply for the collection.
     * @param _owner The address of the owner.
     * @return The address of the newly created collection.
     */
    function _create721Collection(
        string memory _baseURI,
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        address _owner
    ) internal returns (address) {
        Launchpad721 collection = new Launchpad721();
        collection._erc721Initializer(_baseURI, _name, _symbol, _maxSupply);
        collection.transferOwnership(_owner);
        return address(collection);
    }

    /**
    * @notice Internal function to assign partners for a specific sale.
    * @param _partnerAddresses An array of partner addresses.
    * @param _partnerPercentages An array of partner share percentages.
    * @param _saleId The ID of the sale.
    */
    function _assignPartner(
        address[] memory _partnerAddresses, 
        uint256[] memory _partnerPercentages, 
        uint256 _saleId
    ) internal {
        if(_partnerAddresses.length != _partnerPercentages.length) revert CustomErrors.ArrayLengthsDiffer();

        uint256 length = _partnerAddresses.length;

        AppStorage storage s = LibAppStorage.diamondStorage();

        for(uint256 i = 0; i < length; i++){
            s.saleId[_saleId].partners.push(Partner({
                partnerAddress: _partnerAddresses[i],
                sharePercentage: _partnerPercentages[i]
            }));
        }
    }

    /**
    * @notice Internal function to remove partners from a specific sale.
    * @param _saleId The ID of the sale.
    */
    function _removePartners(uint256 _saleId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 length = s.saleId[_saleId].partners.length;

        for (uint256 i = 0; i < length; i++){
            delete s.saleId[_saleId].partners[i];
        }
    }

    /**
    * @notice Internal function to retrieve the partners associated with a specific sale.
    * @param _saleId The ID of the sale.
    * @return An array of Partner structures representing the partners associated with the sale.
    */
    function _getSalePartners(uint256 _saleId) internal view returns(Partner[] memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.saleId[_saleId].partners;
    }

    /**
    * @notice Internal function to retrieve the payment goal information for a specific payment token in a sale.
    * @param _saleId The ID of the sale.
    * @param _paymentTokenAddress The address of the payment token.
    * @return A PaymentTokenMaxSupply structure representing the payment goal information for the specified payment token.
    */
    function _getPaymentGoalInfo(uint256 _saleId, address _paymentTokenAddress) internal view returns(PaymentTokenMaxSupply memory){
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 _paymentTokenIndex;

        for(uint256 i = 0; i < s.saleId[_saleId].paymentTokensMaxSupplies.length; i++){
            if(s.saleId[_saleId].paymentTokensMaxSupplies[i].paymentToken == _paymentTokenAddress){
                _paymentTokenIndex = i;
                break;
            }
        }

        return s.saleId[_saleId].paymentTokensMaxSupplies[_paymentTokenIndex];
    }

    /**
    * @notice Internal function to set the limit per wallet for a specific tier in a sale.
    * @param _saleId The ID of the sale.
    * @param _tierNumber The tier number.
    * @param _updatedLimit The updated limit per wallet.
    */
    function _setTierLimitPerWallet(uint256 _saleId, uint256 _tierNumber, uint256 _updatedLimit) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        s.saleId[_saleId].tiers[_tierNumber - 1].limitPerWallet = _updatedLimit;
    }
}


// File: contracts/libraries/LibDiamond.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // owner of the contract
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == diamondStorage().contractOwner, "LibDiamond: Must be contract owner");
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    // Internal function version of diamondCut
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert("LibDiamondCut: Incorrect FacetCutAction");
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();        
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);            
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress == address(0), "LibDiamondCut: Can't add function that already exists");
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress != _facetAddress, "LibDiamondCut: Can't replace function with same function");
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        // if function does not exist then do nothing and return
        require(_facetAddress == address(0), "LibDiamondCut: Remove facet address must be address(0)");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress, "LibDiamondCut: New facet has no code");
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }    


    function addFunction(DiamondStorage storage ds, bytes4 _selector, uint96 _selectorPosition, address _facetAddress) internal {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(DiamondStorage storage ds, address _facetAddress, bytes4 _selector) internal {        
        require(_facetAddress != address(0), "LibDiamondCut: Can't remove function that doesn't exist");
        // an immutable function is a function defined directly in a diamond
        require(_facetAddress != address(this), "LibDiamondCut: Can't remove immutable function");
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init, "LibDiamondCut: _init address has no code");        
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}


// File: contracts/libraries/LibMeta.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library LibMeta {
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(bytes("EIP712Domain(string name,string version,uint256 salt,address verifyingContract)"));

    function domainSeparator(string memory name, string memory version) internal view returns (bytes32 domainSeparator_) {
        domainSeparator_ = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes(version)), getChainID(), address(this))
        );
    }

    function getChainID() internal view returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    function msgSender() internal view returns (address sender_) {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender_ := and(mload(add(array, index)), 0xffffffffffffffffffffffffffffffffffffffff)
            }
        } else {
            sender_ = msg.sender;
        }
    }
}

// File: contracts/interfaces/IDiamondCut.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

interface IDiamondCut {
    enum FacetCutAction {Add, Replace, Remove}
    // Add=0, Replace=1, Remove=2

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}


// File: contracts/Launchpad721.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ForjCustomErrors} from "contracts/ForjCustomErrors.sol";

/**
 * @title Launchpad721
 * @author Robert Gordon Palmer
 * @dev A contract for managing an ERC721 token collection for a launchpad.
 */
contract Launchpad721 is ERC721, Ownable, ForjCustomErrors{

    using Strings for uint256;

    bool public erc721Initialized;
    uint256 public totalSupply;
    uint256 public totalMinted;
    string public baseURI;
    string public _name;
    string public _symbol;

    string public provenanceHash;
    string public HIDDEN_URI; 
    bool public revealed;

    mapping(address => bool) public isAdmin;

    /**
     * @dev Modifier to allow only the admin or the owner to perform certain actions.
     * @param _address The address to check.
     */
    modifier onlyAdminOrOwner(address _address) {
        require(
            isAdmin[_address] || _address == owner(),
            "This address is not allowed"
        );
        _;
    }

    constructor() ERC721("", "") Ownable(msg.sender){}

    /**
     * @dev Initialize the ERC721 contract.
     * @param _hiddenURI The base URI for token metadata.
     * @param _name_ The name of the token.
     * @param _symbol_ The symbol of the token.
     * @param _totalSupply The total supply of tokens.
     */
    function _erc721Initializer(
        string memory _hiddenURI,
        string memory _name_,
        string memory _symbol_,
        uint256 _totalSupply
    ) public onlyAdminOrOwner(msg.sender) {
        if(erc721Initialized) revert AlreadyInitialized();
        if(_totalSupply == 0) revert SupplyCannotBeZero();

        HIDDEN_URI = _hiddenURI;
        _name = _name_;
        _symbol = _symbol_;
        totalSupply = _totalSupply;

        erc721Initialized = true;
    }

    /**
     * @dev Set the admin status of an address.
     * @param _admin The address to set as admin.
     * @param _isAdmin The admin status to set.
     */
    function setAdmin(address _admin, bool _isAdmin) public onlyAdminOrOwner(msg.sender) {
        isAdmin[_admin] = _isAdmin;
    }

    /**
     * @dev Mint a new token.
     * @param to The address to mint the token for.
     */
    function mint(address to) public onlyAdminOrOwner(msg.sender){
        if(totalMinted + 1 > totalSupply) revert MaxSupplyReached();
        totalMinted += 1;
        _safeMint(to, totalMinted);
    }

    /**
     * @dev Set the base URI for token metadata.
     * @param _baseURI The new base URI.
     */
    function setBaseURI(string memory _baseURI) public onlyAdminOrOwner(msg.sender) {
        baseURI = _baseURI;
    }

    /**
     * @dev Get the token URI for a given token ID.
     * @param tokenId The ID of the token.
     * @return The token URI.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        if(revealed) {
            return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
        } else {
            return HIDDEN_URI;
        }
    }

    /**
     * @dev Commit the provenance hash.
     * @param _provanceHash The provenance hash to commit.
     */
    function commit(string memory _provanceHash) external onlyAdminOrOwner(msg.sender) {
        if(revealed) revert AlreadyRevealed();
        provenanceHash = _provanceHash;
    }

    /**
     * @dev Reveal the collection by setting the base URI.
     * @param _newBaseURI The new base URI to reveal the collection.
     */
    function reveal(string memory _newBaseURI)
        external
        onlyAdminOrOwner(msg.sender)
    {
        if(revealed) revert AlreadyRevealed();
        baseURI = _newBaseURI;
        revealed = true;
    }
}


// File: contracts/Launchpad1155.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ForjCustomErrors} from "contracts/ForjCustomErrors.sol";

/**
 * @title Launchpad1155
 * @author Robert Gordon Palmer
 * @dev A contract that implements ERC1155 token functionality with additional features for a launchpad.
 */
contract Launchpad1155 is ERC1155, Ownable, ForjCustomErrors {

    using Strings for uint256;

    string public name;
    string public symbol;
    string public baseURI;
    bool public erc1155Initialized;

    event TokenBurnBatch(uint256[] indexed _tokenIds, uint256[] indexed _amounts, address indexed _user);
    event TokenBurn(uint256 indexed _tokenId, uint256 indexed _amount, address indexed _user);
    event BatchMint(address indexed user, uint256[] indexed _ids, uint256[] indexed _amounts);

    mapping(uint256 => Supply) public supplyPerId;
    mapping(address => bool) public isAdmin;

    /**
     * @dev Modifier to restrict access to only administrators or the contract owner.
     * @param _address The address to check.
     */
    modifier onlyAdminOrOwner(address _address) {
        require(
            isAdmin[_address] || _address == owner(),
            "This address is not allowed"
        );
        _;
    }

    struct Supply {
        uint256 max;
        uint256 total;
    }

    constructor() ERC1155("") Ownable(msg.sender){}

    /**
     * @dev Initializes the ERC1155 contract with the specified base URI, name, and symbol.
     * @param _baseURI The base URI for token metadata.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     */
    function _erc1155Initializer(
        string memory _baseURI,
        string memory _name,
        string memory _symbol
    ) public onlyAdminOrOwner(msg.sender) {
        if(erc1155Initialized) revert AlreadyInitialized();

        baseURI = _baseURI;
        name = _name;
        symbol = _symbol;

        erc1155Initialized = true;
    }

    /**
     * @dev Sets the administrator status for the specified address.
     * @param _admin The address to set as an administrator.
     * @param _isAdmin The administrator status to set.
     */
    function setAdmin(address _admin, bool _isAdmin) public onlyAdminOrOwner(msg.sender) {
        isAdmin[_admin] = _isAdmin;
    }

    /**
     * @dev Retrieves the maximum and total supply for the specified token ID.
     * @param _id The ID of the token.
     * @return The maximum supply and the total supply.
     */
    function getSupplyPerId(uint256 _id) public view returns(uint256, uint256){
        return (supplyPerId[_id].max, supplyPerId[_id].total);
    }

    /**
     * @dev Sets the name of the token.
     * @param _name The new name of the token.
     */
    function setName(string memory _name) public onlyAdminOrOwner(msg.sender){
        name = _name;
    }

    /**
     * @dev Sets the symbol of the token.
     * @param _symbol The new symbol of the token.
     */
    function setSymbol(string memory _symbol) public onlyAdminOrOwner(msg.sender){
        symbol = _symbol;
    }

    /**
     * @dev Sets the maximum supply for multiple token IDs.
     * @param _tokenIds The IDs of the tokens.
     * @param _maxSupplys The maximum supplies for the tokens.
     */
    function setTokenIdMaxSupply(
        uint256[] calldata _tokenIds, 
        uint256[] calldata _maxSupplys
    ) public onlyAdminOrOwner(msg.sender) {

        if(_tokenIds.length != _maxSupplys.length) revert ArrayLengthsDiffer();

        uint256 length = _tokenIds.length;

        for(uint256 i = 0; i < length; i++){
            if (supplyPerId[_tokenIds[i]].total > _maxSupplys[i]) revert TotalSupplyGreaterThanMaxSupply();
            supplyPerId[_tokenIds[i]].max = _maxSupplys[i];
        }
    }

    /**
     * @dev Sets the base URI for token URIs
     * @param _baseURI The base URI to set
     */
    function setBaseURI(string memory _baseURI) public onlyAdminOrOwner(msg.sender) {
        baseURI = _baseURI;
    }

    /**
     * @dev Burns a batch of tokens
     * @param from The address from which tokens are burned
     * @param ids The array of token IDs to burn
     * @param amounts The array of token amounts to burn
     */
    function burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public {
        if(from != msg.sender) revert MsgSenderIsNotOwner();

        _burnBatch(from, ids, amounts);

        emit TokenBurnBatch(ids, amounts, from);
    }

    /**
     * @dev Burns a single token
     * @param from The address from which the token is burned
     * @param id The ID of the token to burn
     * @param amount The amount of the token to burn
     */
    function burn(address from, uint256 id, uint256 amount) public {
        if(from != msg.sender) revert MsgSenderIsNotOwner();

        _burn(from, id, amount);

        emit TokenBurn(id, amount, from);
    }

    /**
     * @dev Mints a batch of tokens
     * @param to The address to which tokens are minted
     * @param ids The array of token IDs to mint
     * @param amounts The array of token amounts to mint
     * @param data Additional data to pass to the receiving contract
     */
    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyAdminOrOwner(msg.sender) {

        if(ids.length != amounts.length) revert ArrayLengthsDiffer();

        uint256 length = ids.length;
        
        for(uint256 i; i < length; i++){
            if(
                supplyPerId[ids[i]].total + amounts[i] > supplyPerId[ids[i]].max
            ) revert TotalSupplyGreaterThanMaxSupply();
            supplyPerId[ids[i]].total += amounts[i];
        }
        super._mintBatch(to, ids, amounts, data);

        emit BatchMint(to, ids, amounts);
    }

    /**
     * @dev Mints a single token
     * @param to The address to which the token is minted
     * @param id The ID of the token to mint
     * @param amount The amount of the token to mint
     * @param data Additional data to pass to the receiving contract
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyAdminOrOwner(msg.sender) {
        if(supplyPerId[id].total + amount > supplyPerId[id].max) revert TotalSupplyGreaterThanMaxSupply();
        supplyPerId[id].total += amount;
        super._mint(to, id, amount, data);
    }

    /**
     * @dev Sets the approval status for an operator
     * @param operator The address of the operator
     * @param approved The approval status to set
     */
    function setApprovalForAll(
        address operator, 
        bool approved
    ) public override virtual {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev Safely transfers a batch of tokens from one address to another
     * @param from The address from which tokens are transferred
     * @param to The address to which tokens are transferred
     * @param tokenIds The array of token IDs to transfer
     * @param amounts The array of token amounts to transfer
     * @param data Additional data to pass to the receiving contract
     */
    function safeBatchTransferFrom(
        address from, 
        address to, 
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data
    ) public override virtual {
        super.safeBatchTransferFrom(from, to, tokenIds, amounts, data);
    }

    /**
     * @dev Safely transfers a single token fromaddress from, 
     * @param to The address to which the token is transferred
     * @param tokenId The ID of the token to transfer
     * @param amount The amount of the token to transfer
     * @param data Additional data to pass to the receiving contract
     */
    function safeTransferFrom(
        address from, 
        address to, 
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) public override virtual {
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    /**
     * @dev Retrieves the URI for a given token ID
     * @param tokenId The ID of the token
     * @return The URI string for the token ID
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }
}


// File: @openzeppelin/contracts/token/ERC721/ERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.20;

import {IERC721} from "./IERC721.sol";
import {IERC721Receiver} from "./IERC721Receiver.sol";
import {IERC721Metadata} from "./extensions/IERC721Metadata.sol";
import {Context} from "../../utils/Context.sol";
import {Strings} from "../../utils/Strings.sol";
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";
import {IERC721Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
abstract contract ERC721 is Context, ERC165, IERC721, IERC721Metadata, IERC721Errors {
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    mapping(uint256 tokenId => address) private _owners;

    mapping(address owner => uint256) private _balances;

    mapping(uint256 tokenId => address) private _tokenApprovals;

    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender());
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);

        return _getApproved(tokenId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        // Setting an "auth" arguments enables the `_isAuthorized` check which verifies that the token exists
        // (from != 0). Therefore, it is not needed to verify that the return value is not 0 here.
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     *
     * IMPORTANT: Any overrides to this function that add ownership of tokens not tracked by the
     * core ERC721 logic MUST be matched with the use of {_increaseBalance} to keep balances
     * consistent with ownership. The invariant to preserve is that for any address `a` the value returned by
     * `balanceOf(a)` must be equal to the number of tokens such that `_ownerOf(tokenId)` is `a`.
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev Returns the approved address for `tokenId`. Returns 0 if `tokenId` is not minted.
     */
    function _getApproved(uint256 tokenId) internal view virtual returns (address) {
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `owner`'s tokens, or `tokenId` in
     * particular (ignoring whether it is owned by `owner`).
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _isAuthorized(address owner, address spender, uint256 tokenId) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender || isApprovedForAll(owner, spender) || _getApproved(tokenId) == spender);
    }

    /**
     * @dev Checks if `spender` can operate on `tokenId`, assuming the provided `owner` is the actual owner.
     * Reverts if `spender` does not have approval from the provided `owner` for the given token or for all its assets
     * the `spender` for the specific `tokenId`.
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal view virtual {
        if (!_isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            } else {
                revert ERC721InsufficientApproval(spender, tokenId);
            }
        }
    }

    /**
     * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
     *
     * NOTE: the value is limited to type(uint128).max. This protect against _balance overflow. It is unrealistic that
     * a uint256 would ever overflow from increments when these increments are bounded to uint128 values.
     *
     * WARNING: Increasing an account's balance using this function tends to be paired with an override of the
     * {_ownerOf} function to resolve the ownership of the corresponding tokens so that balances and ownership
     * remain consistent with one another.
     */
    function _increaseBalance(address account, uint128 value) internal virtual {
        unchecked {
            _balances[account] += value;
        }
    }

    /**
     * @dev Transfers `tokenId` from its current owner to `to`, or alternatively mints (or burns) if the current owner
     * (or `to`) is the zero address. Returns the owner of the `tokenId` before the update.
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that
     * `auth` is either the owner of the token, or approved to operate on the token (by the owner).
     *
     * Emits a {Transfer} event.
     *
     * NOTE: If overriding this function in a way that tracks balances, see also {_increaseBalance}.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        address from = _ownerOf(tokenId);

        // Perform (optional) operator check
        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }

        // Execute the update
        if (from != address(0)) {
            // Clear approval. No need to re-authorize or emit the Approval event
            _approve(address(0), tokenId, address(0), false);

            unchecked {
                _balances[from] -= 1;
            }
        }

        if (to != address(0)) {
            unchecked {
                _balances[to] += 1;
            }
        }

        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        return from;
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
    }

    /**
     * @dev Mints `tokenId`, transfers it to `to` and checks for `to` acceptance.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        _checkOnERC721Received(address(0), to, tokenId, data);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal {
        address previousOwner = _update(address(0), tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        } else if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking that contract recipients
     * are aware of the ERC721 standard to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is like {safeTransferFrom} in the sense that it invokes
     * {IERC721Receiver-onERC721Received} on the receiver, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `tokenId` token must exist and be owned by `from`.
     * - `to` cannot be the zero address.
     * - `from` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeTransfer-address-address-uint256-}[`_safeTransfer`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that `auth` is
     * either the owner of the token, or approved to operate on all tokens held by this owner.
     *
     * Emits an {Approval} event.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address to, uint256 tokenId, address auth) internal {
        _approve(to, tokenId, auth, true);
    }

    /**
     * @dev Variant of `_approve` with an optional flag to enable or disable the {Approval} event. The event is not
     * emitted in the context of transfers.
     */
    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal virtual {
        // Avoid reading the owner unless necessary
        if (emitEvent || auth != address(0)) {
            address owner = _requireOwned(tokenId);

            // We do not use _isAuthorized because single-token approvals should not be able to call approve
            if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
                revert ERC721InvalidApprover(auth);
            }

            if (emitEvent) {
                emit Approval(owner, to, tokenId);
            }
        }

        _tokenApprovals[tokenId] = to;
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Requirements:
     * - operator can't be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` doesn't have a current owner (it hasn't been minted, or it has been burned).
     * Returns the owner.
     *
     * Overrides to ownership logic should be done to {_ownerOf}.
     */
    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target address. This will revert if the
     * recipient doesn't accept the token transfer. The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }
}


// File: @openzeppelin/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File: @openzeppelin/contracts/utils/Strings.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Strings.sol)

pragma solidity ^0.8.20;

import {Math} from "./math/Math.sol";
import {SignedMath} from "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}


// File: contracts/ForjCustomErrors.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract ForjCustomErrors {
    error TotalSupplyGreaterThanMaxSupply();
    error TierNumberIncorrect();
    error ArrayLengthsDiffer();
    error TierLengthTooShort();
    error ClaimPeriodTooShort();
    error PartnerAlreadyExists();
    error PartnerNotFound();
    error InvalidPartnerWallet();
    error InvalidPartnerSharePct();
    error PartnerActive();
    error PartnerDeactivated();
    error InvalidProof();
    error TierPeriodHasntStarted();
    error TierPeriodHasEnded();
    error CurrentlyNotClaimPeriod();
    error MintLimitReached();
    error MaxSupplyReached();
    error AlreadyInitialized();
    error MsgSenderIsNotOwner();
    error IncorrectAddress();
    error BaseURINotSet();
    error TokenNotAcceptedAsPayment();
    error InsufficientBalance();
    error TokenIsSoulbound();
    error NoConfirmedIds();
    error AlreadyRevealed();
    error SupplyCannotBeZero();
}

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}


// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.20;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}


// File: @openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.20;

import {IERC721} from "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}


// File: @openzeppelin/contracts/utils/Context.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// File: @openzeppelin/contracts/utils/introspection/ERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


// File: @openzeppelin/contracts/interfaces/draft-IERC6093.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File: @openzeppelin/contracts/utils/math/Math.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}


// File: @openzeppelin/contracts/utils/math/SignedMath.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}


// File: @openzeppelin/contracts/token/ERC1155/ERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.20;

import {IERC1155} from "./IERC1155.sol";
import {IERC1155Receiver} from "./IERC1155Receiver.sol";
import {IERC1155MetadataURI} from "./extensions/IERC1155MetadataURI.sol";
import {Context} from "../../utils/Context.sol";
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";
import {Arrays} from "../../utils/Arrays.sol";
import {IERC1155Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 */
abstract contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI, IERC1155Errors {
    using Arrays for uint256[];
    using Arrays for address[];

    mapping(uint256 id => mapping(address account => uint256)) private _balances;

    mapping(address account => mapping(address operator => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256 /* id */) public view virtual returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     */
    function balanceOf(address account, uint256 id) public view virtual returns (uint256) {
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual returns (uint256[] memory) {
        if (accounts.length != ids.length) {
            revert ERC1155InvalidArrayLength(ids.length, accounts.length);
        }

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts.unsafeMemoryAccess(i), ids.unsafeMemoryAccess(i));
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public virtual {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert ERC1155MissingApprovalForAll(sender, from);
        }
        _safeTransferFrom(from, to, id, value, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert ERC1155MissingApprovalForAll(sender, from);
        }
        _safeBatchTransferFrom(from, to, ids, values, data);
    }

    /**
     * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`. Will mint (or burn) if `from`
     * (or `to`) is the zero address.
     *
     * Emits a {TransferSingle} event if the arrays contain one element, and {TransferBatch} otherwise.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement either {IERC1155Receiver-onERC1155Received}
     *   or {IERC1155Receiver-onERC1155BatchReceived} and return the acceptance magic value.
     * - `ids` and `values` must have the same length.
     *
     * NOTE: The ERC-1155 acceptance check is not performed in this function. See {_updateWithAcceptanceCheck} instead.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual {
        if (ids.length != values.length) {
            revert ERC1155InvalidArrayLength(ids.length, values.length);
        }

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids.unsafeMemoryAccess(i);
            uint256 value = values.unsafeMemoryAccess(i);

            if (from != address(0)) {
                uint256 fromBalance = _balances[id][from];
                if (fromBalance < value) {
                    revert ERC1155InsufficientBalance(from, fromBalance, value, id);
                }
                unchecked {
                    // Overflow not possible: value <= fromBalance
                    _balances[id][from] = fromBalance - value;
                }
            }

            if (to != address(0)) {
                _balances[id][to] += value;
            }
        }

        if (ids.length == 1) {
            uint256 id = ids.unsafeMemoryAccess(0);
            uint256 value = values.unsafeMemoryAccess(0);
            emit TransferSingle(operator, from, to, id, value);
        } else {
            emit TransferBatch(operator, from, to, ids, values);
        }
    }

    /**
     * @dev Version of {_update} that performs the token acceptance check by calling
     * {IERC1155Receiver-onERC1155Received} or {IERC1155Receiver-onERC1155BatchReceived} on the receiver address if it
     * contains code (eg. is a smart contract at the moment of execution).
     *
     * IMPORTANT: Overriding this function is discouraged because it poses a reentrancy risk from the receiver. So any
     * update to the contract state after this function would break the check-effect-interaction pattern. Consider
     * overriding {_update} instead.
     */
    function _updateWithAcceptanceCheck(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal virtual {
        _update(from, to, ids, values);
        if (to != address(0)) {
            address operator = _msgSender();
            if (ids.length == 1) {
                uint256 id = ids.unsafeMemoryAccess(0);
                uint256 value = values.unsafeMemoryAccess(0);
                _doSafeTransferAcceptanceCheck(operator, from, to, id, value, data);
            } else {
                _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, values, data);
            }
        }
    }

    /**
     * @dev Transfers a `value` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `value` amount.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(from, to, ids, values, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     * - `ids` and `values` must have the same length.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        _updateWithAcceptanceCheck(from, to, ids, values, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the values in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Creates a `value` amount of tokens of type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(address to, uint256 id, uint256 value, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(address(0), to, ids, values, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `values` must have the same length.
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        _updateWithAcceptanceCheck(address(0), to, ids, values, data);
    }

    /**
     * @dev Destroys a `value` amount of tokens of type `id` from `from`
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `value` amount of tokens of type `id`.
     */
    function _burn(address from, uint256 id, uint256 value) internal {
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(from, address(0), ids, values, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `value` amount of tokens of type `id`.
     * - `ids` and `values` must have the same length.
     */
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory values) internal {
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        _updateWithAcceptanceCheck(from, address(0), ids, values, "");
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the zero address.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (operator == address(0)) {
            revert ERC1155InvalidOperator(address(0));
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Performs an acceptance check by calling {IERC1155-onERC1155Received} on the `to` address
     * if it contains code at the moment of execution.
     */
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, value, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    // Tokens rejected
                    revert ERC1155InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert ERC1155InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev Performs a batch acceptance check by calling {IERC1155-onERC1155BatchReceived} on the `to` address
     * if it contains code at the moment of execution.
     */
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, values, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    // Tokens rejected
                    revert ERC1155InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert ERC1155InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev Creates an array in memory with only one value for each of the elements provided.
     */
    function _asSingletonArrays(
        uint256 element1,
        uint256 element2
    ) private pure returns (uint256[] memory array1, uint256[] memory array2) {
        /// @solidity memory-safe-assembly
        assembly {
            // Load the free memory pointer
            array1 := mload(0x40)
            // Set array length to 1
            mstore(array1, 1)
            // Store the single element at the next word after the length (where content starts)
            mstore(add(array1, 0x20), element1)

            // Repeat for next array locating it right after the first array
            array2 := add(array1, 0x40)
            mstore(array2, 1)
            mstore(add(array2, 0x20), element2)

            // Update the free memory pointer by pointing after the second array
            mstore(0x40, add(array2, 0x40))
        }
    }
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` amount of tokens of type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the value of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`.
     *
     * WARNING: This function can potentially allow a reentrancy attack when transferring tokens
     * to an untrusted contract, when invoking {onERC1155Received} on the receiver.
     * Ensure to follow the checks-effects-interactions pattern and consider employing
     * reentrancy guards when interacting with untrusted contracts.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `value` amount.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * WARNING: This function can potentially allow a reentrancy attack when transferring tokens
     * to an untrusted contract, when invoking {onERC1155BatchReceived} on the receiver.
     * Ensure to follow the checks-effects-interactions pattern and consider employing
     * reentrancy guards when interacting with untrusted contracts.
     *
     * Emits either a {TransferSingle} or a {TransferBatch} event, depending on the length of the array arguments.
     *
     * Requirements:
     *
     * - `ids` and `values` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external;
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev Interface that must be implemented by smart contracts in order to receive
 * ERC-1155 token transfers.
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}


// File: @openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.20;

import {IERC1155} from "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}


// File: @openzeppelin/contracts/utils/Arrays.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Arrays.sol)

pragma solidity ^0.8.20;

import {StorageSlot} from "./StorageSlot.sol";
import {Math} from "./math/Math.sol";

/**
 * @dev Collection of functions related to array types.
 */
library Arrays {
    using StorageSlot for bytes32;

    /**
     * @dev Searches a sorted `array` and returns the first index that contains
     * a value greater or equal to `element`. If no such index exists (i.e. all
     * values in the array are strictly less than `element`), the array length is
     * returned. Time complexity O(log n).
     *
     * `array` is expected to be sorted in ascending order, and to contain no
     * repeated elements.
     */
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;

        if (high == 0) {
            return 0;
        }

        while (low < high) {
            uint256 mid = Math.average(low, high);

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds towards zero (it does integer division with truncation).
            if (unsafeAccess(array, mid).value > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && unsafeAccess(array, low - 1).value == element) {
            return low - 1;
        } else {
            return low;
        }
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeAccess(address[] storage arr, uint256 pos) internal pure returns (StorageSlot.AddressSlot storage) {
        bytes32 slot;
        // We use assembly to calculate the storage slot of the element at index `pos` of the dynamic array `arr`
        // following https://docs.soliditylang.org/en/v0.8.20/internals/layout_in_storage.html#mappings-and-dynamic-arrays.

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getAddressSlot();
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeAccess(bytes32[] storage arr, uint256 pos) internal pure returns (StorageSlot.Bytes32Slot storage) {
        bytes32 slot;
        // We use assembly to calculate the storage slot of the element at index `pos` of the dynamic array `arr`
        // following https://docs.soliditylang.org/en/v0.8.20/internals/layout_in_storage.html#mappings-and-dynamic-arrays.

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getBytes32Slot();
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeAccess(uint256[] storage arr, uint256 pos) internal pure returns (StorageSlot.Uint256Slot storage) {
        bytes32 slot;
        // We use assembly to calculate the storage slot of the element at index `pos` of the dynamic array `arr`
        // following https://docs.soliditylang.org/en/v0.8.20/internals/layout_in_storage.html#mappings-and-dynamic-arrays.

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getUint256Slot();
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeMemoryAccess(uint256[] memory arr, uint256 pos) internal pure returns (uint256 res) {
        assembly {
            res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
        }
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeMemoryAccess(address[] memory arr, uint256 pos) internal pure returns (address res) {
        assembly {
            res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
        }
    }
}


// File: @openzeppelin/contracts/utils/StorageSlot.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}


