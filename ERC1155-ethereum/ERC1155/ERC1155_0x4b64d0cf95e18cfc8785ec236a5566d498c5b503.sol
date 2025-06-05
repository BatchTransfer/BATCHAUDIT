// File: src/MgdERC1155PermitEscrowable.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ECDSA, ERC1155Allowance, ERC1155Permit} from "./abstract/ERC1155Permit.sol";
import {
  ERC1155Upgradeable,
  IERC1155Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {MgdL1MarketData} from "./voucher/VoucherDataTypes.sol";
import {MgdCompanyL2Sync, ICrossDomainMessenger} from "./MgdCompanyL2Sync.sol";
import {MintGoldDustMarketplace} from "mgd-v2-contracts/marketplace/MintGoldDustMarketplace.sol";
import {MintGoldDustERC1155} from "mgd-v2-contracts/marketplace/MintGoldDustERC1155.sol";

/**
 * @title MgdERC1155PermitEscrowable
 * @author Mint Gold Dust LLC
 * @notice This contracts extends the L1 {MintGoldDustERC1155} contract
 * with functionality that allows usage of permit and proper information
 * to move NFTs into escrow.
 * @dev This contract should upgrade existing {MintGoldDustERC1155}:
 * https://github.com/Mint-Gold-Dust/v2-contracts
 */
contract MgdERC1155PermitEscrowable is MintGoldDustERC1155, ERC1155Permit {
  using Counters for Counters.Counter;

  // Events
  /**
   * @dev Emit when `escrow` address is set.
   */
  event SetEscrow(address escrow_);

  /**
   * @dev Emit when `escrow` address is set.
   */
  event EscrowUpdateMarketData(uint256 indexed tokenId, MgdL1MarketData marketData);

  /// Custom Errors
  error MgdERC1155PermitEscrowable__onlyEscrow_notAllowed();

  address public escrow;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /// @dev Overriden to utilize the allowance in {ERC1155Allowance} set up in this contract.
  /// @dev CAUTION! If sending to `escrow`, ensure the `from` address is an accesible acount in L2.
  /// Requirements:
  /// - If using from != caller, and is not approved for all, call `_spendAllowance`
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  )
    public
    override
  {
    address operator = msg.sender;
    require(
      from == operator || allowance(from, operator, id) >= amount,
      "ERC1155: caller is not owner or approved or has allowance"
    );
    if (from != operator && !isApprovedForAll(from, operator)) {
      _spendAllowance(from, operator, id, amount);
    }
    if (escrow != address(0) && to == escrow) {
      data = _getTokenIdDataAndUpdateState(id, _safeCastToUint40(amount));
    }
    _safeTransferFrom(from, to, id, amount, data);
  }

  /// @inheritdoc ERC1155Allowance
  function allowance(
    address owner,
    address operator,
    uint256 tokenId
  )
    public
    view
    override
    returns (uint256)
  {
    if (isApprovedForAll(owner, operator)) {
      return type(uint256).max;
    } else {
      return _getAllowance(owner, operator, tokenId);
    }
  }

  /// @inheritdoc ERC1155Permit
  function permit(
    address owner,
    address operator,
    uint256 tokenId,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    public
    payable
    override
  {
    require(_blockTimestamp() <= deadline, "Permit expired");
    require(balanceOf(owner, tokenId) >= amount, "Invalid amount");
    require(operator != owner, "ERC1155Permit: approval to current owner");

    bytes32 digest = getPermitDigest(
      owner, operator, tokenId, amount, _getAndIncrementNonce(owner, tokenId), deadline
    );

    if (Address.isContract(owner)) {
      require(
        IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) == 0x1626ba7e,
        "Unauthorized"
      );
    } else {
      address recoveredAddress = ECDSA.recover(digest, v, r, s);
      require(recoveredAddress != address(0), "Invalid signature");
      require(recoveredAddress == owner, "Unauthorized");
    }

    _setAllowance(owner, operator, tokenId, amount);
  }

  /**
   * @notice Common entry external function for the `permit()` function.
   *
   * @param params abi.encoded inputs for this.permit() public
   */
  function permit(bytes calldata params) external payable {
    (
      address owner,
      address operator,
      uint256 tokenId,
      uint256 amount,
      uint256 deadline,
      uint8 v,
      bytes32 r,
      bytes32 s
    ) = abi.decode(params, (address, address, uint256, uint256, uint256, uint8, bytes32, bytes32));
    permit(owner, operator, tokenId, amount, deadline, v, r, s);
  }

  function mintFromL2Native(
    address receiver,
    uint256 amount,
    MgdL1MarketData calldata marketData,
    string calldata tokenURI,
    bytes calldata memoir
  )
    external
    returns (uint256 newTokenId)
  {
    if (msg.sender != escrow) {
      revert MgdERC1155PermitEscrowable__onlyEscrow_notAllowed();
    }
    _tokenIds.increment();
    newTokenId = _tokenIds.current();
    _mint(receiver, newTokenId, amount, "");
    _setURI(newTokenId, tokenURI);
    tokenIdRoyaltyPercent[newTokenId] = marketData.royaltyPercent;
    tokenIdMemoir[newTokenId] = memoir;
    tokenIdArtist[newTokenId] = marketData.artist;
    _tokenWasSold[newTokenId] = marketData.tokenWasSold;
    _primarySaleQuantityToSell[newTokenId] += marketData.primarySaleL2QuantityToSell;
    if (marketData.hasCollabs) {
      hasTokenCollaborators[newTokenId] = marketData.hasCollabs;
      tokenIdCollaboratorsQuantity[newTokenId] = marketData.collabsQuantity;
      tokenCollaborators[newTokenId] = marketData.collabs;
      tokenIdCollaboratorsPercentage[newTokenId] = marketData.collabsPercentage;
    }
    emit EscrowUpdateMarketData(newTokenId, marketData);
  }

  function mintFromL2NativeRecorded(
    address receiver,
    uint256 amount,
    uint256 recordedTokenId,
    MgdL1MarketData calldata marketData
  )
    external
  {
    if (msg.sender != escrow) {
      revert MgdERC1155PermitEscrowable__onlyEscrow_notAllowed();
    }
    _mint(receiver, recordedTokenId, amount, "");
    _primarySaleQuantityToSell[recordedTokenId] += marketData.primarySaleL2QuantityToSell;
    emit EscrowUpdateMarketData(recordedTokenId, marketData);
  }

  function updateMarketData(uint256 tokenId, MgdL1MarketData calldata marketData) external {
    if (msg.sender != escrow) {
      revert MgdERC1155PermitEscrowable__onlyEscrow_notAllowed();
    }
    _tokenWasSold[tokenId] = marketData.tokenWasSold;
    _primarySaleQuantityToSell[tokenId] += marketData.primarySaleL2QuantityToSell;
    emit EscrowUpdateMarketData(tokenId, marketData);
  }

  function setEscrow(address escrow_) external isZeroAddress(escrow_) isowner {
    escrow = escrow_;
    emit SetEscrow(escrow_);
  }

  /**
   * @notice Returns the data to escow for a given `tokenId` and `amountToEscrow`.
   * @param tokenId to get market data
   * @param amountToEscrow being sent
   */
  function getTokenIdData(
    uint256 tokenId,
    uint40 amountToEscrow
  )
    public
    view
    virtual
    returns (bytes memory data)
  {
    uint40 primarySaleToCarry = _getPrimarySaleToCarry(tokenId, amountToEscrow);

    data = abi.encode(
      MgdL1MarketData({
        artist: tokenIdArtist[tokenId],
        hasCollabs: hasTokenCollaborators[tokenId],
        tokenWasSold: _tokenWasSold[tokenId],
        collabsQuantity: _safeCastToUint40(tokenIdCollaboratorsQuantity[tokenId]),
        primarySaleL2QuantityToSell: primarySaleToCarry,
        royaltyPercent: _safeCastToUint128(tokenIdRoyaltyPercent[tokenId]),
        collabs: tokenCollaborators[tokenId],
        collabsPercentage: tokenIdCollaboratorsPercentage[tokenId]
      })
    );
  }

  function _getTokenIdDataAndUpdateState(
    uint256 tokenId,
    uint40 amountToEscrow
  )
    internal
    returns (bytes memory data)
  {
    data = getTokenIdData(tokenId, amountToEscrow);
    uint40 primarySaleToCarry = _getPrimarySaleToCarry(tokenId, amountToEscrow);
    _primarySaleQuantityToSell[tokenId] -= primarySaleToCarry;
  }

  function _getPrimarySaleToCarry(
    uint256 tokenId,
    uint40 amountToEscrow
  )
    internal
    view
    returns (uint40 primarySaleToCarry)
  {
    uint40 primarySaleRemaining = _safeCastToUint40(_primarySaleQuantityToSell[tokenId]);
    primarySaleToCarry =
      primarySaleRemaining >= amountToEscrow ? amountToEscrow : primarySaleRemaining;
  }

  function _safeCastToUint40(uint256 value) internal pure returns (uint40) {
    require(value <= type(uint40).max, "Value exceeds uint40");
    return uint40(value);
  }

  function _safeCastToUint128(uint256 value) internal pure returns (uint128) {
    require(value <= type(uint128).max, "Value exceeds uint128");
    return uint128(value);
  }
}


// File: lib/openzeppelin-contracts/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


// File: src/abstract/ERC1155Permit.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC1155Allowance} from "./ERC1155Allowance.sol";

/// @title ERC1155Permit
/// @author Mint Gold Dust LLC
/// @notice This implements the permit function to transfer NFTs using a signature.
/// @dev This implementation is inspired by:
/// https://github.com/primitivefinance/rmm-manager/blob/main/contracts/base/ERC1155Permit.sol
abstract contract ERC1155Permit is ERC1155Allowance {
  // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  bytes32 private constant _TYPE_HASH =
    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

  // keccak256("Permit(address owner,address operator,uint256 tokenId,uint256 amount,uint256 nonce,uint256 deadline)")
  bytes32 private constant _PERMIT_TYPEHASH =
    0x3c6f69a4350f438202c90fe85edf1beb49dd32242963f890cef31487533bec80;

  // keccak("ERC1155Permit");
  bytes32 private constant _HASHED_NAME =
    0x1d4f415bd37d01f3848189b3fd5a293e7415256a90d661a7ca72d2cc50b05eea;

  // keccak("v0.0.1");
  bytes32 private constant _HASHED_VERSION =
    0x6bda7e3f385e48841048390444cced5cc795af87758af67622e5f4f0882c4a99;

  // keccak256(abi.encodePacked(owner,tokenId)) => current nonce
  mapping(bytes32 => uint256) internal _nonces;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /**
   *
   * @param owner of the `tokenId`
   * @param operator of given the allowance
   * @param tokenId to give allowance
   * @param amount of `tokenId` to give allowance
   * @param deadline  of the `signature`
   * @param v value of signature
   * @param r value of signature
   * @param s value of signature
   */
  function permit(
    address owner,
    address operator,
    uint256 tokenId,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    public
    payable
    virtual;

  function PERMIT_TYPEHASH() external pure returns (bytes32) {
    return _PERMIT_TYPEHASH;
  }

  /**
   * @notice The domain separator used in the permit signature
   */
  function DOMAIN_SEPARATOR() public view returns (bytes32) {
    return _domainSeparator();
  }

  function getPermitDigest(
    address owner,
    address operator,
    uint256 tokenId,
    uint256 amount,
    uint256 nonce,
    uint256 deadline
  )
    public
    view
    returns (bytes32 digest)
  {
    bytes32 structHash =
      keccak256(abi.encode(_PERMIT_TYPEHASH, owner, operator, tokenId, amount, nonce, deadline));
    digest = _hashTypedData(structHash);
  }

  function currentNonce(address owner, uint256 tokenId) public view returns (uint256 current) {
    current = _nonces[_hashedOwnerTokenID(owner, tokenId)];
  }

  function _getAndIncrementNonce(address owner, uint256 tokenId) internal returns (uint256 current) {
    bytes32 hashed = _hashedOwnerTokenID(owner, tokenId);
    current = _nonces[hashed];
    _nonces[hashed] += 1;
  }

  function _hashTypedData(bytes32 structHash) internal view returns (bytes32) {
    return ECDSA.toTypedDataHash(_domainSeparator(), structHash);
  }

  function _blockTimestamp() internal view returns (uint256) {
    return block.timestamp;
  }

  function _domainSeparator() private view returns (bytes32) {
    return
      keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
  }

  function _hashedOwnerTokenID(address owner, uint256 tokenId) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(owner, tokenId));
  }
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155Upgradeable.sol";
import "./IERC1155ReceiverUpgradeable.sol";
import "./extensions/IERC1155MetadataURIUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC1155Upgradeable, IERC1155MetadataURIUpgradeable {
    using AddressUpgradeable for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    function __ERC1155_init(string memory uri_) internal onlyInitializing {
        __ERC1155_init_unchained(uri_);
    }

    function __ERC1155_init_unchained(string memory uri_) internal onlyInitializing {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC1155Upgradeable).interfaceId ||
            interfaceId == type(IERC1155MetadataURIUpgradeable).interfaceId ||
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
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
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
    ) public view virtual override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
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
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
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
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `ids` and `amounts` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    /**
     * @dev Hook that is called after any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155ReceiverUpgradeable(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155ReceiverUpgradeable(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}


// File: lib/openzeppelin-contracts/contracts/interfaces/IERC1271.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC1271.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 *
 * _Available since v4.1._
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}


// File: lib/openzeppelin-contracts/contracts/utils/Counters.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}


// File: src/voucher/VoucherDataTypes.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

enum TypeNFT {
  ERC721,
  ERC1155
}

struct MgdL1MarketData {
  address artist;
  bool hasCollabs;
  bool tokenWasSold;
  uint40 collabsQuantity;
  uint40 primarySaleL2QuantityToSell;
  uint256 royaltyPercent;
  address[4] collabs;
  uint256[5] collabsPercentage;
}

struct L1VoucherData {
  address nft;
  uint256 tokenId;
  uint256 representedAmount;
}


// File: src/MgdCompanyL2Sync.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustCompany} from "mgd-v2-contracts/marketplace/MintGoldDustCompany.sol";
import {MgdEIP712L2Sync, CrossAction, ECDSAUpgradeable} from "./utils/MgdEIP712L2Sync.sol";
import {ICrossDomainMessenger} from "./interfaces/ICrossDomainMessenger.sol";

/// @title MgdCompanyL2Sync
/// @notice An extension to {MintGoldDustCompany} containing functions that
/// syncs access levels management changes with a L2.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract MgdCompanyL2Sync is MintGoldDustCompany, MgdEIP712L2Sync {
  /// @dev Emit when `setMessenger()` is called.
  event SetMessenger(address messenger);

  /**
   * @dev Emit for soft failing functions.
   * @param deadline of the signature
   */
  event ExpiredDeadline(uint256 deadline);

  /**
   * @dev Emit when `receiveL1Sync()` fails.
   * @param action intended
   * @param account address
   * @param state change
   */
  event FailedReceiveL1Sync(CrossAction action, address account, bool state);

  /// Custom errors
  error MgdCompanyL2Sync__performL2Call_noCrossDomainMGDCompany();
  error MGDCompanyL2Sync__onlyMainnet();
  error MGDCompanyL2Sync__notOnMainnet();

  ICrossDomainMessenger public messenger;

  modifier onlyCrossMessenger() {
    require(msg.sender == address(messenger));
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Similar to `setValidator()` with L2 synchronizaton.
   * @param account to set as validator
   * @param state to be set
   * @param deadline for the syncing to occur via this `signature`
   * @param mgdSignature generated from this `publicKey()`
   * @dev Requirements:
   * - `mgdSignature` should be generated by `MintGoldDustCompany.publicKey()`
   * - This method should only be called from the L1 network
   */
  function setValidatorWithL2Sync(
    address account,
    bool state,
    uint256 deadline,
    bytes calldata mgdSignature
  )
    external
    onlyOwner
    isZeroAddress(account)
  {
    _onlyMainnet();
    _checkDeadline(deadline, true);

    bytes32 structHash =
      keccak256(abi.encode(_SETVALIDATOR_TYPEHASH, account, state, _getCrossDomain(), deadline));

    require(_verifySignature(publicKey, structHash, mgdSignature), "Invalid signature");

    _performL2Call(CrossAction.SetValidator, account, state, deadline, mgdSignature);
    _setValidator(account, state);
  }

  /**
   * @notice Similar to `whitelist()` with L2 synchronizaton.
   * @param account to set as validator
   * @param state to be set
   * @param deadline for the syncing to occur via this `signature`
   * @param mgdSignature generated from this `publicKey()`
   * @dev Requirements:
   * - `mgdSignature` should be generated by the `MintGoldDustCompany.publicKey()`
   * - This method should only be called from the L1 network
   */
  function whitelistWithL2Sync(
    address account,
    bool state,
    uint256 deadline,
    bytes calldata mgdSignature
  )
    external
    isValidatorOrOwner
    isZeroAddress(account)
  {
    _onlyMainnet();
    _checkDeadline(deadline, true);

    bytes32 structHash =
      keccak256(abi.encode(_WHITELIST_TYPEHASH, account, state, _getCrossDomain(), deadline));

    require(_verifySignature(publicKey, structHash, mgdSignature), "Invalid signature");

    _performL2Call(CrossAction.SetWhitelist, account, state, deadline, mgdSignature);
    _whitelist(account, state);
  }

  /**
   * @notice Receives a message from the L1 network and performs the action.
   * @param data received from the L1 network
   * @dev Requirements:
   * - This method should only be called from the L2 network by the `messenger`
   * - Verifies the `signature` of the `data` was signed by the `publicKey`
   * - The public keys in both networks should be the same
   */
  function receiveL1Sync(bytes memory data) external onlyCrossMessenger {
    _notMainnet();
    (CrossAction action, address account, bool state, uint256 deadline, bytes memory mgdSignature) =
      abi.decode(data, (CrossAction, address, bool, uint256, bytes));

    bool success;

    if (action == CrossAction.SetValidator) {
      bytes32 structHash =
        keccak256(abi.encode(_SETVALIDATOR_TYPEHASH, account, state, _getCrossDomain(), deadline));
      if (_verifySignature(publicKey, structHash, mgdSignature)) {
        _setValidator(account, state);
        success = true;
      }
    } else if (action == CrossAction.SetWhitelist) {
      bytes32 structHash =
        keccak256(abi.encode(_WHITELIST_TYPEHASH, account, state, _getCrossDomain(), deadline));
      if (_verifySignature(publicKey, structHash, mgdSignature)) {
        _whitelist(account, state);
        success = true;
      }
    }

    if (!success) {
      emit FailedReceiveL1Sync(action, account, state);
    }
  }

  /**
   * @notice Sets the cross domain messenger address between L1<>L2 or L2<>L1
   * @param newMessenger canonical address communicating between L1 or L2
   */
  function setMessenger(address newMessenger) external onlyOwner isZeroAddress(newMessenger) {
    messenger = ICrossDomainMessenger(newMessenger);
    emit SetMessenger(newMessenger);
  }

  /**
   * @notice Sets the cross domain MGDCompany address
   * @param chainId of domain
   * @param mgdCompany address of the L2 or L1 MGDCompany opposite to this.domain
   */
  function setCrossDomainMGDCompany(
    uint256 chainId,
    address mgdCompany
  )
    external
    override
    onlyOwner
    isZeroAddress(mgdCompany)
  {
    _setCrossDomainMGDCompany(chainId, mgdCompany);
  }

  function _performL2Call(
    CrossAction action,
    address account,
    bool state,
    uint256 deadline,
    bytes calldata mgdSignature
  )
    private
  {
    bytes memory message = abi.encodeWithSelector(
      this.receiveL1Sync.selector, abi.encode(action, account, state, deadline, mgdSignature)
    );
    address crosscompany = crossDomainMGDCompany();
    if (crosscompany == address(0)) {
      revert MgdCompanyL2Sync__performL2Call_noCrossDomainMGDCompany();
    }
    messenger.sendMessage(crosscompany, message, 1000000);
  }

  function _checkDeadline(uint256 deadline, bool withRevert) private {
    if (withRevert) {
      require(block.timestamp <= deadline, "Expired deadline");
    } else if (block.timestamp > deadline) {
      emit ExpiredDeadline(deadline);
    }
  }

  function _onlyMainnet() private view {
    if (block.chainid != _MAINNET_CHAINID) {
      revert MGDCompanyL2Sync__onlyMainnet();
    }
  }

  function _notMainnet() private view {
    if (block.chainid == _MAINNET_CHAINID) {
      revert MGDCompanyL2Sync__notOnMainnet();
    }
  }

  function _setValidator(address account, bool state) private {
    isAddressValidator[account] = state;
    emit ValidatorAdded(account, state);
  }

  function _whitelist(address account, bool state) private {
    isArtistApproved[account] = state;
    emit ArtistWhitelisted(account, state);
  }
}


// File: lib/v2-contracts/contracts/marketplace/MintGoldDustMarketplace.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {AuctionProps, CollectorMintDTO, ListDTO, ManagePrimarySale, MarketItem, SaleDTO} from "../libraries/MgdMarketPlaceDataTypes.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {MintGoldDustCompany} from "./MintGoldDustCompany.sol";
import {MintGoldDustERC721} from "./MintGoldDustERC721.sol";
import {MintGoldDustNFT} from "./MintGoldDustNFT.sol";
import {MintGoldDustERC1155} from "./MintGoldDustERC1155.sol";

/// @title An abstract contract responsible to define some general responsibilites related with
/// a marketplace for its childrens.
/// @notice Contain a general function for purchases in primary and secondary sales
/// and also a virtual function that each children should have a specif implementation.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
abstract contract MintGoldDustMarketplace is
    Initializable,
    PausableUpgradeable,
    IERC1155Receiver,
    IERC721Receiver,
    ReentrancyGuardUpgradeable
{
    using Counters for Counters.Counter;

    /**
     * @notice that this event show the info about primary sales.
     * @dev this event will be triggered if a primary sale is correctly completed.
     * @param saleId a uint value that indicates the sale number.
     * @param tokenId the sequence number for the item.
     * @param seller the address of the seller.
     * @param newOwner the address that is buying the item.
     * @param buyPrice the price that the buyer is paying for the item.
     * @param sellerAmount the final value that the seller should receive.
     * @param feeAmount the primary sale fee to be applied on top of the item price.
     * @param collectorFeeAmount the value paind by the collector to the marketplace.
     * @param tokenAmountSold the quantity of tokens bought.
     * @param hasCollaborators a parameter that indicate if the item has or not collaborators.
     * @param isERC721 a parameter that indicate if the item is an ERC721 or not.
     */
    event MintGoldDustNftPurchasedPrimaryMarket(
        uint256 indexed saleId,
        uint256 indexed tokenId,
        address seller,
        address newOwner,
        uint256 buyPrice,
        uint256 sellerAmount,
        uint256 feeAmount,
        uint256 collectorFeeAmount,
        uint256 tokenAmountSold,
        bool hasCollaborators,
        bool isERC721
    );

    /**
     * @notice that this event show the info about secondary sales.
     * @dev this event will be triggered if a secondary sale is correctly completed.
     * @param saleId a uint value that indicates the sale number.
     * @param tokenId the sequence number for the item.
     * @param seller the address of the seller.
     * @param newOwner the address that is buying the item.
     * @param sellerAmount the final value that the seller should receive.
     * @param royaltyPercent the royalty percent setted for this token.
     * @param royaltyAmount the value to be paid for the artist and the collaborators (when it has) for the royalties.
     * @param royaltyRecipient the main recipient for the royalty value (the artist).
     * @param feeAmount the fee final value that was paid to the marketplace.
     * @param tokenAmountSold the quantity of tokens bought.
     * @param hasCollaborators a parameter that indicate if the item has or not collaborators.
     * @param isERC721 a parameter that indicate if the item is an ERC721 or not.
     */
    event MintGoldDustNftPurchasedSecondaryMarket(
        uint256 indexed saleId,
        uint256 indexed tokenId,
        address seller,
        address newOwner,
        uint256 buyPrice,
        uint256 sellerAmount,
        uint256 royaltyPercent,
        uint256 royaltyAmount,
        address royaltyRecipient,
        uint256 feeAmount,
        uint256 tokenAmountSold,
        bool hasCollaborators,
        bool isERC721
    );

    /**
     * @notice that this event is used when a item has collaborators.
     * @dev this event shouldbe used if splitted market items. At the purchase moment it will
     *      be triggered for each one of the collaborators including the artist.
     * @param saleId a uint value that indicates the sale number.
     * @dev use this to vinculate this event with the MintGoldDustNftPurchasedSecondaryMarket that contains more
     *      general info about the sale.
     * @param collaborator the sequence number for the item.
     * @param amount the final value that the seller should receive.
     */
    event NftPurchasedCollaboratorAmount(
        uint256 indexed saleId,
        address collaborator,
        uint256 amount
    );

    error ItemIsNotListed(address nft);
    error ItemIsNotListedBySeller(
        uint256 tokenId,
        address market,
        address contractAddress,
        address seller,
        address msgSender
    );
    error ItemIsAlreadyListed(address nft);
    error AddressUnauthorized(string _reason);
    error MustBeERC721OrERC1155();
    error LessItemsListedThanTheRequiredAmount();
    error InvalidAmountForThisPurchase();
    error PurchaseOfERC1155InAuctionThatCoverAllListedItems();
    error InvalidAmount();

    Counters.Counter public itemsSold;
    MintGoldDustMarketplace internal mintGoldDustMarketplace;
    MintGoldDustCompany internal mintGoldDustCompany;
    address payable internal mintGoldDustERC721Address;
    address payable internal mintGoldDustERC1155Address;

    uint256[48] private __gap;

    /**
     * @notice that this mapping do the relationship between a contract address,
     *         the tokenId created in this contract (MintGoldDustERC721 or MintGoldDustERC1155)
     *         the owner address and the Market Item owned.
     * @dev this mapping is necessary mainly because of the ERC1155. I.e Some artist can mint the quantity
     *      of 10 for a tokenId. After it can list 8 items. So other address can buy 4 and another 4.
     *      Then this MarketItem can has 3 different owners for the same tokenId for the MintGoldDustERC1155 address.
     */
    mapping(address => mapping(uint256 => mapping(address => MarketItem)))
        public idMarketItemsByContractByOwner;

    modifier isowner() {
        if (msg.sender != mintGoldDustCompany.owner()) {
            revert AddressUnauthorized("Not Mint Gold Dust owner");
        }
        _;
    }

    /**
     *
     * @notice MintGoldDustMarketplace is composed by other two contracts.
     * @param _mintGoldDustCompany The contract responsible to Mint Gold Dust management features.
     * @param _mintGoldDustERC721Address The Mint Gold Dust ERC721 address.
     * @param _mintGoldDustERC1155Address The Mint Gold Dust ERC1155 address.
     */
    function initialize(
        address _mintGoldDustCompany,
        address payable _mintGoldDustERC721Address,
        address payable _mintGoldDustERC1155Address
    ) internal onlyInitializing {
        require(
            _mintGoldDustCompany != address(0) &&
                _mintGoldDustERC721Address != address(0) &&
                _mintGoldDustERC1155Address != address(0),
            "contract address cannot be zero"
        );
        __ReentrancyGuard_init();
        __Pausable_init();
        mintGoldDustCompany = MintGoldDustCompany(_mintGoldDustCompany);
        mintGoldDustERC721Address = _mintGoldDustERC721Address;
        mintGoldDustERC1155Address = _mintGoldDustERC1155Address;
    }

    /// @notice Helper function that returns the current primary sale market info for `tokenId`.
    /// @param nft of nft contract
    /// @param tokenId of token
    function getManagePrimarySale(
        address nft,
        uint256 tokenId
    ) external view returns (ManagePrimarySale memory) {
        return MintGoldDustNFT(nft).getManagePrimarySale(tokenId);
    }

    /// @notice that this function set an instance of the MintGoldDustMarketplace to the sibling contract.
    /// @param _mintGoldDustMarketplace the address of the MintGoldDustMarketplace.
    /// @dev we create this lazy dependence because of the circular dependence between the
    /// MintGoldDustMarketplace. So this way we can share the state of the _isSecondarySale mapping.
    function setMintGoldDustMarketplace(
        address _mintGoldDustMarketplace
    ) external {
        require(mintGoldDustCompany.owner() == msg.sender, "Unauthorized");
        mintGoldDustMarketplace = MintGoldDustMarketplace(
            _mintGoldDustMarketplace
        );
    }

    /// @notice Pause the contract
    function pauseContract() external isowner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpauseContract() external isowner {
        _unpause();
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     *
     * @notice that is a general function that must be implemented by the more specif makets.
     * @dev it is a internal function and should be implemented by the childrens
     * if these are not abstract also.
     * @param tokenId: The tokenId of the marketItem.
     * @param amount: The quantity of tokens to be listed for an MintGoldDustERC1155.
     *    @dev For MintGoldDustERC721 the amout must be always one.
     * @param nft: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
     * @param price: The price or reserve price for the item.
     */
    function list(
        uint256 tokenId,
        uint256 amount,
        MintGoldDustNFT nft,
        uint256 price
    ) external virtual;

    /**
     * @notice that is a more generic list function than the above. This function can be used by both kind of markets
     *         marketplace auction and set price.
     * @dev Here we're listing a MintGoldDustERC721 or a MintGoldDustERC1155 to the MintGoldDustMarketplace.
     *      If the item is being listed to _isAuction and the price is zero it means that
     *      the auction doesn't has a reserve price. In other case it has. If the NFT is being listed to
     *      the set price market the price must be greater than zero.
     *      Is important to know that after list an item to auction is not possible to cancel it like
     *      the delist function in the Set Price market.
     *      After the MarketItem struct creation the NFT is transferred from the seller to the respective
     *      markeplace address (marketplace auction or set price).
     * @param listDTO The ListDTO struct parameter to use.
     *                 It consists of the following fields:
     *                    - tokenid: The tokenId of the marketItem.
     *                    - amount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
     *                              MintGoldDustERC721 the amout must be always one.
     *                    - contractAddress: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
     *                    - seller: The seller of the marketItem.
     *                    - price: the price to list the item. For auction it corresponds to the reserve price.
     * @param auctionId the auctionId for the auction. If the item is being listed to the set price market it is *                   zero.
     * @param sender the address that is listing the item.
     *    @dev we need this parameter because in the collectorMint flow who calls this function is the buyer. How *    it function is internal we can have a good control on top of it.
     */
    function _list(
        ListDTO memory listDTO,
        uint256 auctionId,
        address sender
    ) internal {
        bool isERC721 = false;
        uint256 realAmount = 1;

        if (address(listDTO.nft) == mintGoldDustERC721Address) {
            _isNFTowner(listDTO.tokenId, sender);
            isERC721 = true;
        } else if (address(listDTO.nft) == mintGoldDustERC1155Address) {
            _checkBalanceForERC1155(listDTO.tokenId, listDTO.amount, sender);
            realAmount = listDTO.amount;
        } else {
            revert MustBeERC721OrERC1155();
        }

        ManagePrimarySale memory managePS = listDTO.nft.getManagePrimarySale(
            listDTO.tokenId
        );

        /// @dev why we need this? We need to check if there are some amount listed for the other market.
        /// I mean, if the item was listed for the set price market and the seller is trying to list it for auction.
        /// It needs to be added to the sommary of the quantity restant for primary sales.
        (, , , , uint256 returnedTokenAmount, ) = mintGoldDustMarketplace
            .idMarketItemsByContractByOwner(
                address(listDTO.nft),
                listDTO.tokenId,
                sender
            );

        if (!managePS.soldout && sender == managePS.owner) {
            require(
                listDTO.amount + returnedTokenAmount <= managePS.amount,
                "Invalid amount for primary sale"
            );
        }

        AuctionProps memory auctionProps = AuctionProps(
            auctionId,
            0,
            0,
            payable(address(0)),
            0,
            false
        );

        idMarketItemsByContractByOwner[address(listDTO.nft)][listDTO.tokenId][
            sender
        ] = MarketItem(
            listDTO.tokenId,
            sender,
            listDTO.price,
            isERC721,
            realAmount,
            auctionProps
        );

        listDTO.nft.transfer(
            sender,
            address(this),
            listDTO.tokenId,
            realAmount
        );
    }

    /**
     * @param saleDTO The SaleDTO struct parameter to use.
     *                 It consists of the following fields:
     *                    - tokenid: The tokenId of the marketItem.
     *                    - amount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
     *                              MintGoldDustERC721 the amout must be always one.
     *                    - contractAddress: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
     *                    - seller: The seller of the marketItem.
     * @return MarketItem struct.
     *                 It consists of the following fields:
     *                    - tokenId: The tokenId of the marketItem.
     *                    - seller: The seller of the marketItem.
     *                    - price: The price which the item should be sold.
     *                    - sold: It says if an item was or not sold.
     *                    - isAuction: true if the item was listed for marketplace auction and false if for set price market.
     *                    - isERC721: true is an MintGoldDustERC721 token.
     *                    - tokenAmount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
     *                              MintGoldDustERC721 the amout must be always one.
     *                    - auctionProps:
     *                        - endTime: the time that the auction must be finished. Is the start time plus 24 hours.
     *                        - highestBidder: the bidder that did bid the highest value.
     *                        - highestBid: the value of the high bid.
     *                        - ended: a boolean that indicates if the auction was already finished or not.
     */
    function _getMarketItem(
        SaleDTO memory saleDTO
    ) internal view returns (MarketItem memory) {
        return
            idMarketItemsByContractByOwner[address(saleDTO.nft)][
                saleDTO.tokenId
            ][saleDTO.seller];
    }

    /**
     * @notice function will fail if the token was not listed to the set price market.
     * @notice function will fail if the contract address is not a MintGoldDustERC721 neither a MintGoldDustERC1155.
     * @notice function will fail if the amount paid by the buyer does not cover the purshace amount required.
     * @param saleDTO The SaleDTO struct parameter to use.
     *                 It consists of the following fields:
     *                    - tokenid: The tokenId of the marketItem.
     *                    - amount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
     *                              MintGoldDustERC721 the amout must be always one.
     *                    - contractAddress: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
     *                    - seller: The seller of the marketItem.
     * @param sender The address that started this flow.
     * @param value The value to be paid for the purchase.
     */
    function _executePurchaseNftFlow(
        SaleDTO memory saleDTO,
        address sender,
        uint256 value
    ) internal {
        _isTokenListed(saleDTO.tokenId, address(saleDTO.nft), saleDTO.seller);
        _mustBeMintGoldDustERC721Or1155(address(saleDTO.nft));

        _hasEnoughAmountListed(
            saleDTO.tokenId,
            address(saleDTO.nft),
            address(this),
            saleDTO.amount,
            saleDTO.seller
        );

        MarketItem memory marketItem = _getMarketItem(saleDTO);

        /// @dev if the flow goes for ERC721 the amount of tokens MUST be ONE.
        uint256 realAmount = 1;

        if (!marketItem.isERC721) {
            realAmount = saleDTO.amount;
        }

        _checkIfIsPrimaryOrSecondarySaleAndCall(
            marketItem,
            saleDTO,
            value,
            sender,
            realAmount
        );
    }

    /**
     * @dev this function check if the item was already sold some time and *      direct the flow to
     *     a primary or a secondary sale flow.
     * @param marketItem The MarketItem struct parameter to use.
     * @param saleDTO The SaleDTO struct parameter to use.
     * @param value The value to be paid for the purchase.
     * @param sender The address that started this flow.
     *    @dev we need to receive the sender this way, because in the auction flow the purchase starts from
     *         the endAuction function in the MintGoldDustMarketplaceAuction contract. So from there the address
     *         that we get is the highest bidder that is stored in the marketItem struct. So we need to manage this way.
     */
    function _checkIfIsPrimaryOrSecondarySaleAndCall(
        MarketItem memory marketItem,
        SaleDTO memory saleDTO,
        uint256 value,
        address sender,
        uint256 realAmount
    ) internal {
        ManagePrimarySale memory managePS = saleDTO.nft.getManagePrimarySale(
            saleDTO.tokenId
        );

        if (
            (managePS.owner == saleDTO.seller && managePS.soldout) ||
            (managePS.owner != saleDTO.seller)
        ) {
            _isMsgValueEnough(
                marketItem.price,
                realAmount,
                value,
                marketItem.auctionProps.auctionId
            );
            _secondarySale(marketItem, saleDTO, value, sender);
        } else {
            _isMsgValueEnoughPrimarySale(
                marketItem.price,
                realAmount,
                value,
                marketItem.auctionProps.auctionId
            );
            _primarySale(marketItem, saleDTO, value, sender, realAmount);
        }
    }

    /**
     * @dev for the auction market, when an artist or collector decides to put a MintGoldDustERC1155 for auction
     *      is necessary to inform the quantity of tokens to be listed.
     *    @notice that in this case, at the moment of the purchase, the buyer needs to buy all the tokens
     *            listed for auction.
     *    @notice that this function check if the amount being purchased by the onwer is the same of the amount
     *            of listed MintGoldDustERC1155 tokenId.
     * @param saleDTO a parameter just like in doxygen (must be followed by parameter name)
     */
    function _isBuyingAllListedTokens(SaleDTO memory saleDTO) internal view {
        if (
            saleDTO.amount <
            idMarketItemsByContractByOwner[address(saleDTO.nft)][
                saleDTO.tokenId
            ][saleDTO.seller].tokenAmount
        ) {
            revert PurchaseOfERC1155InAuctionThatCoverAllListedItems();
        }
    }

    /**
     * @dev this function check if the an address represents a MintGoldDustNFT contract.
     *      It MUST be a MintGoldDustERC721 address or a MintGoldDustERC1155 address.
     * @notice that the function REVERTS with a MustBeERC721OrERC1155() error if the conditon is not met.
     * @param nft is a MintGoldDustNFT address.
     */
    function _mustBeMintGoldDustERC721Or1155(address nft) internal view {
        //   // Get the interfaces that the contract supports
        bool isERC721 = nft == mintGoldDustERC721Address;
        bool isERC1155 = nft == mintGoldDustERC1155Address;

        // Ensure that the contract is either an ERC721 or ERC1155
        if (!isERC1155 && !isERC721) {
            revert MustBeERC721OrERC1155();
        }
    }

    /**
     * @dev the main goal of this function is check if the address calling the function is the
     *      owner of the tokenId.
     * @notice that it REVERTS with a AddressUnauthorized error if the condition is not met.
     * @param tokenId is the id that represent the token.
     * @param sender is the address that started this flow.
     */
    function _isNFTowner(uint256 tokenId, address sender) internal view {
        if (
            (MintGoldDustERC721(mintGoldDustERC721Address)).ownerOf(tokenId) !=
            sender
        ) {
            revert AddressUnauthorized("Not owner!");
        }
    }

    /**
     * @dev the goal here is, depending of the contract address (MintGoldDustERC721 or MintGoldDustERC1155)
     *      verify if the tokenId is really listed.
     * @notice that if not it REVERTS with a Item_isNotListed() error.
     * @param tokenId is the id that represent the token.
     * @param nft is a MintGoldDustNFT address.
     * @param seller is the address of the seller of this tokenId.
     */
    function _isTokenListed(
        uint256 tokenId,
        address nft,
        address seller
    ) internal view {
        if (
            idMarketItemsByContractByOwner[nft][tokenId][seller].tokenAmount ==
            0
        ) {
            revert ItemIsNotListedBySeller(
                tokenId,
                address(this),
                nft,
                seller,
                msg.sender
            );
        }
        if (
            nft == mintGoldDustERC721Address &&
            (MintGoldDustERC721(mintGoldDustERC721Address)).ownerOf(tokenId) !=
            address(this)
        ) {
            revert ItemIsNotListed(nft);
        }

        if (
            nft == mintGoldDustERC1155Address &&
            (MintGoldDustERC1155(mintGoldDustERC1155Address)).balanceOf(
                address(this),
                tokenId
            ) ==
            0
        ) {
            revert ItemIsNotListed(nft);
        }
    }

    /**
     * @dev the goal here is verify if the MintGoldDustMarketplace contract has the quantity of
     *      MintGoldDustERC1155 tokens that the collector is trying to buy.
     * @notice that if not it REVERTS with a LessItemsListedThanTheRequiredAmount() error.
     * @param tokenId is the id that represent the token.
     * @param nft is a MintGoldDustNFT address.
     * @param marketPlaceAddress it can be a MintGoldDustMarketplaceAuction or a MintGoldDustSetPrice address.
     * @param tokenQuantity the quantity of tokens desired by the buyer.
     * @param seller is the address of the seller of this tokenId.
     */
    function _hasEnoughAmountListed(
        uint256 tokenId,
        address nft,
        address marketPlaceAddress,
        uint256 tokenQuantity,
        address seller
    ) internal view {
        if (
            nft == mintGoldDustERC1155Address &&
            (MintGoldDustERC1155(mintGoldDustERC1155Address)).balanceOf(
                marketPlaceAddress,
                tokenId
            ) <
            tokenQuantity
        ) {
            revert LessItemsListedThanTheRequiredAmount();
        }
        if (
            idMarketItemsByContractByOwner[nft][tokenId][seller].tokenAmount <
            tokenQuantity
        ) {
            revert LessItemsListedThanTheRequiredAmount();
        }
    }

    /**
     * @dev the goal here is verify if the address is the seller of the respective tokenId for a contract address.
     * @notice that if not it REVERTS with a AddressUnauthorized() error.
     * @param tokenId is the id that represent the token.
     * @param nft is a MintGoldDustNFT address.
     * @param seller is the address of the seller of this tokenId.
     */
    function _isSeller(
        uint256 tokenId,
        address nft,
        address seller
    ) internal view {
        if (
            msg.sender !=
            idMarketItemsByContractByOwner[nft][tokenId][seller].seller
        ) {
            revert AddressUnauthorized("Not seller!");
        }
    }

    function _isNotListed(
        uint256 tokenId,
        address nft,
        address _seller
    ) internal view {
        if (
            idMarketItemsByContractByOwner[nft][tokenId][_seller].tokenAmount >
            0
        ) {
            revert ItemIsAlreadyListed(nft);
        }
    }

    function _checkAmount(uint256 amount) internal pure {
        if (amount <= 0) {
            revert InvalidAmount();
        }
    }

    /**
     * @dev the main goal of this function is check if the address calling the function is the
     *      owner of the tokenId. For ERC1155 it means if the address has some balance for this token.
     * @notice that it REVERTS with a AddressUnauthorized error if the condition is not met.
     * @param tokenId is the id that represent the token.
     * @param _tokenAmount is the quantity of tokens desired by the buyer.
     * @param sender is the address that started this flow.
     */
    function _checkBalanceForERC1155(
        uint256 tokenId,
        uint256 _tokenAmount,
        address sender
    ) private view {
        if (
            (MintGoldDustERC1155(mintGoldDustERC1155Address)).balanceOf(
                sender,
                tokenId
            ) < _tokenAmount
        ) {
            revert AddressUnauthorized(
                "Not owner or not has enough token quantity!"
            );
        }
    }

    /**
     * @notice that this function is responsible to start the primary sale flow.
     * @dev here we apply the fees related with the primary market that are:
     *                 - the primarySaleFeePercent and the collectorFee.
     * @param marketItem The MarketItem struct parameter to use.
     *                 It consists of the following fields:
     *                    - tokenId: The tokenId of the marketItem.
     *                    - seller: The seller of the marketItem.
     *                    - price: The price which the item should be sold.
     *                    - isERC721: true is an MintGoldDustERC721 token.
     *                    - tokenAmount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
     *                              MintGoldDustERC721 the amout must be always one.
     *                    - auctionProps:
     *                        - auctionId: the auctionId for the auction.
     *                        - startTime: the time that the auction have started.
     *                        - endTime: the time that the auction must be finished. Is the start time plus 24 hours.
     *                        - highestBidder: the bidder that did bid the highest value.
     *                        - highestBid: the value of the high bid.
     *                        - ended: a boolean that indicates if the auction was already finished or not.
     * @param saleDTO The SaleDTO struct parameter to use.
     *                 It consists of the following fields:
     *                    - tokenid: The tokenId of the marketItem.
     *                    - amount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
     *                              MintGoldDustERC721 the amout must be always one.
     *                    - contractAddress: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
     *                    - seller: The seller of the marketItem.
     * @param value The value to be paid for the purchase.
     * @param sender The address that started this flow.
     *    @dev we need to receive the sender this way, because in the auction flow the purchase starts from
     *         the endAuction function in the MintGoldDustMarketplaceAuction contract. So from there the address
     *         that we get is the highst bidder that is stored in the marketItem struct. So we need to manage this way.
     */
    function _primarySale(
        MarketItem memory marketItem,
        SaleDTO memory saleDTO,
        uint256 value,
        address sender,
        uint256 realAmount
    ) private {
        // MintGoldDustNFT _mintGoldDustNFT = _getERC1155OrERC721(
        //     marketItem.isERC721
        // );

        ManagePrimarySale memory mPSale = saleDTO.nft.getManagePrimarySale(
            saleDTO.tokenId
        );

        saleDTO.nft.updatePrimarySaleQuantityToSell(
            saleDTO.tokenId,
            realAmount
        );

        if (mPSale.amount - realAmount == 0) {
            saleDTO.nft.setTokenWasSold(saleDTO.tokenId);
        }

        itemsSold.increment();

        uint256 fee;
        uint256 collFee;
        uint256 balance;

        /// @dev it removes the fee from the value that the buyer sent.
        uint256 netValue = (value * (100e18)) / (103e18);

        fee =
            (netValue * mintGoldDustCompany.primarySaleFeePercent()) /
            (100e18);
        collFee = (netValue * mintGoldDustCompany.collectorFee()) / (100e18);
        balance = netValue - fee;

        _checkIfIsSplitPaymentAndCall(
            saleDTO.nft,
            marketItem,
            saleDTO,
            balance,
            fee,
            collFee,
            true,
            netValue,
            sender
        );

        (bool successOwner, ) = payable(mintGoldDustCompany.owner()).call{
            value: collFee + fee
        }("");
        require(successOwner, "Transfer to owner failed.");
    }

    /**
     * @notice that this function will check if the item has or not the collaborator and call the correct
     *         flow (unique sale or split sale)
     * @dev Explain to a developer any extra details
     * @param nft MintGoldDustNFT is an instance of MintGoldDustERC721 or MintGoldDustERC1155.
     * @param marketItem the struct MarketItem - check it in the primarySale or secondary sale functions.
     * @param saleDTO the struct SaleDTO - check it in the primarySale or secondary sale functions.
     * @param balance uint256 that represents the total amount to be received by the seller after fee calculations.
     * @param fee uint256 the primary or the secondary fee to be paid by the buyer.
     * @param collFeeOrRoyalty uint256 that represent the collector fee or the royalty depending of the flow.
     * @param isPrimarySale bool that helps the code to go for the correct flow (Primary or Secondary sale).
     * @param value The value to be paid for the purchase.
     * @param sender The address that started this flow.
     *    @dev we need to receive the sender this way, because in the auction flow the purchase starts from
     *         the endAuction function in the MintGoldDustMarketplaceAuction contract. So from there the address
     *         that we get is the highst bidder that is stored in the marketItem struct. So we need to manage this way.
     */
    function _checkIfIsSplitPaymentAndCall(
        MintGoldDustNFT nft,
        MarketItem memory marketItem,
        SaleDTO memory saleDTO,
        uint256 balance,
        uint256 fee,
        uint256 collFeeOrRoyalty,
        bool isPrimarySale,
        uint256 value,
        address sender
    ) private {
        address artistOrSeller = nft.tokenIdArtist(saleDTO.tokenId);

        if (isPrimarySale) {
            artistOrSeller = saleDTO.seller;
        }

        if (nft.hasTokenCollaborators(saleDTO.tokenId)) {
            _handleSplitPaymentCall(
                nft,
                saleDTO,
                balance,
                fee,
                collFeeOrRoyalty,
                artistOrSeller,
                isPrimarySale,
                value,
                sender
            );
            return;
        }

        if (isPrimarySale) {
            _uniqueOwnerPrimarySale(
                nft,
                marketItem,
                saleDTO,
                fee,
                collFeeOrRoyalty,
                balance,
                value,
                sender
            );
            return;
        }

        _uniqueOwnerSecondarySale(
            marketItem,
            nft,
            saleDTO,
            artistOrSeller,
            fee,
            collFeeOrRoyalty,
            balance,
            value,
            sender
        );
    }

    /**
     * @dev this function is called when in the checkIfIsSplitPaymentAndCall function the flow goes for
     *      a sale for an item that does not has collaborators and is its first sale in the MintGoldDustMarketplace.
     * @param nft explained in checkIfIsSplitPaymentAndCall function.
     * @param marketItem explained in checkIfIsSplitPaymentAndCall function.
     * @param saleDTO explained in checkIfIsSplitPaymentAndCall function.
     * @param fee the primary fee to be paid for the MintGoldDustMarketplace.
     * @param _collFee represent the collector fee.
     * @param balance represents the total amount to be received by the seller after fee calculations.
     * @param value The value to be paid for the purchase.
     * @param sender The address that started this flow.
     *    @dev we need to receive the sender this way, because in the auction flow the purchase starts from
     *         the endAuction function in the MintGoldDustMarketplaceAuction contract. So from there the address
     *         that we get is the highst bidder that is stored in the marketItem struct. So we need to manage this way.
     */
    function _uniqueOwnerPrimarySale(
        MintGoldDustNFT nft,
        MarketItem memory marketItem,
        SaleDTO memory saleDTO,
        uint256 fee,
        uint256 _collFee,
        uint256 balance,
        uint256 value,
        address sender
    ) private {
        nft.transfer(address(this), sender, saleDTO.tokenId, saleDTO.amount);

        _updateIdMarketItemsByContractByOwnerMapping(saleDTO);
        emit MintGoldDustNftPurchasedPrimaryMarket(
            itemsSold.current(),
            saleDTO.tokenId,
            saleDTO.seller,
            sender,
            value,
            balance,
            fee,
            _collFee,
            saleDTO.amount,
            false,
            marketItem.isERC721
        );

        (bool successSeller, ) = payable(marketItem.seller).call{
            value: balance
        }("");
        require(successSeller, "Transfer to seller failed.");
    }

    function _updateIdMarketItemsByContractByOwnerMapping(
        SaleDTO memory saleDTO
    ) private {
        MarketItem storage item = idMarketItemsByContractByOwner[
            address(saleDTO.nft)
        ][saleDTO.tokenId][saleDTO.seller];

        item.tokenAmount = item.tokenAmount - saleDTO.amount;

        if (item.tokenAmount == 0) {
            delete idMarketItemsByContractByOwner[address(saleDTO.nft)][
                saleDTO.tokenId
            ][saleDTO.seller];
        }
    }

    /**
     * @dev this function is called when in the checkIfIsSplitPaymentAndCall function the flow goes for
     *      a sale for an item that does not has collaborators and was already sold the first time.
     * @param marketItem explained in checkIfIsSplitPaymentAndCall function.
     * @param nft explained in checkIfIsSplitPaymentAndCall function.
     * @param saleDTO explained in checkIfIsSplitPaymentAndCall function.
     * @param artist the creator of the artwork to receive the royalties.
     * @param fee the secondary fee to be paid for the MintGoldDustMarketplace.
     * @param _royalty represent the royalty to be paid for the artist.
     * @param balance represents the total amount to be received by the seller after fee calculations.
     * @param value The value to be paid for the purchase.
     * @param sender The address that started this flow.
     *    @dev we need to receive the sender this way, because in the auction flow the purchase starts from
     *         the endAuction function in the MintGoldDustMarketplaceAuction contract. So from there the address
     *         that we get is the highst bidder that is stored in the marketItem struct. So we need to manage this way.
     */
    function _uniqueOwnerSecondarySale(
        MarketItem memory marketItem,
        MintGoldDustNFT nft,
        SaleDTO memory saleDTO,
        address artist,
        uint256 fee,
        uint256 _royalty,
        uint256 balance,
        uint256 value,
        address sender
    ) private {
        nft.transfer(address(this), sender, saleDTO.tokenId, saleDTO.amount);

        _updateIdMarketItemsByContractByOwnerMapping(saleDTO);

        emit MintGoldDustNftPurchasedSecondaryMarket(
            itemsSold.current(),
            saleDTO.tokenId,
            saleDTO.seller,
            sender,
            value,
            balance,
            nft.tokenIdRoyaltyPercent(saleDTO.tokenId),
            _royalty,
            artist,
            fee,
            saleDTO.amount,
            false,
            marketItem.isERC721
        );

        (bool successArtist, ) = payable(artist).call{value: _royalty}("");
        require(successArtist, "Transfer to artist failed.");
    }

    /**
     * @notice that is the function responsible to manage the split sale flow.
     * @dev the _isPrimarySale is very important. It define if the value to be received is
     *      the balance for primary sale or the royalty for secondary sales.
     *    @notice that the emitEventForSplitPayment os called to trigger the correct event depending of the flow.
     * @param balance uint256 that represents the total amount to be received by the seller after fee calculations.
     * @param fee uint256 the primary or the secondary fee to be paid by the buyer.
     * @param collFeeOrRoyalty uint256 that represent the collector fee or the royalty depending of the flow.
     * @param artist the creator of the artwork to receive the royalties.
     * @param saleDTO The SaleDTO struct parameter to use.
     *                 It consists of the following fields:
     *                    - tokenid: The tokenId of the marketItem.
     *                    - amount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
     *                              MintGoldDustERC721 the amout must be always one.
     *                    - contractAddress: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
     *                    - seller: The seller of the marketItem.
     * @param _isPrimarySale bool that helps the code to go for the correct flow (Primary or Secondary sale).
     * @param value The value to be paid for the purchase.
     * @param sender The address that started this flow.
     *    @dev we need to receive the sender this way, because in the auction flow the purchase starts from
     *         the endAuction function in the MintGoldDustMarketplaceAuction contract. So from there the address
     *         that we get is the highst bidder that is stored in the marketItem struct. So we need to manage this way.
     */
    function _splittedSale(
        uint256 balance,
        uint256 fee,
        uint256 collFeeOrRoyalty,
        address artist,
        MintGoldDustNFT nft,
        SaleDTO memory saleDTO,
        bool _isPrimarySale,
        uint256 value,
        address sender
    ) private {
        MarketItem memory marketItem = _getMarketItem(saleDTO);

        uint256 balanceOrRoyalty = collFeeOrRoyalty;

        if (_isPrimarySale) {
            balanceOrRoyalty = balance;
        }

        uint256 tokenIdCollaboratorsQuantity = nft.tokenIdCollaboratorsQuantity(
            saleDTO.tokenId
        );

        uint256 balanceSplitPart = (balanceOrRoyalty *
            nft.tokenIdCollaboratorsPercentage(saleDTO.tokenId, 0)) / (100e18);

        (bool successArtist, ) = payable(artist).call{value: balanceSplitPart}(
            ""
        );
        require(successArtist, "Split tx to artist failed.");

        emit NftPurchasedCollaboratorAmount(
            itemsSold.current(),
            artist,
            balanceSplitPart
        );

        for (uint256 i = 1; i < tokenIdCollaboratorsQuantity; i++) {
            balanceSplitPart =
                (balanceOrRoyalty *
                    nft.tokenIdCollaboratorsPercentage(saleDTO.tokenId, i)) /
                (100e18);
            address collaborator = nft.tokenCollaborators(
                saleDTO.tokenId,
                i - 1
            );

            (bool successCollaborator, ) = payable(collaborator).call{
                value: balanceSplitPart
            }("");
            require(successCollaborator, "Split tx to collab failed.");

            emit NftPurchasedCollaboratorAmount(
                itemsSold.current(),
                collaborator,
                balanceSplitPart
            );
        }

        _updateIdMarketItemsByContractByOwnerMapping(saleDTO);
        _emitEventForSplitPayment(
            saleDTO,
            marketItem,
            nft,
            artist,
            balance,
            fee,
            collFeeOrRoyalty,
            _isPrimarySale,
            value,
            sender
        );
    }

    /**
     * @notice that is the function responsible to trigger the correct event for splitted sales.
     * @dev the _isPrimarySale defines if the primary sale or the secondary sale should be triggered.
     * @param nft MintGoldDustNFT is an instance of MintGoldDustERC721 or MintGoldDustERC1155.
     * @param marketItem explained in _splittedSale function.
     * @param artist the creator of the artwork to receive the royalties.
     * @param balance uint256 that represents the total amount to be received by the seller after fee calculations.
     * @param fee uint256 the primary or the secondary fee to be paid by the buyer.
     * @param collFeeOrRoyalty uint256 that represent the collector fee or the royalty depending of the flow.
     * @param isPrimarySale bool that helps the code to go for the correct flow (Primary or Secondary sale).
     * @param value The value to be paid for the purchase.
     * @param sender The address that started this flow.
     *    @dev we need to receive the sender this way, because in the auction flow the purchase starts from
     *         the endAuction function in the MintGoldDustMarketplaceAuction contract. So from there the address
     *         that we get is the highst bidder that is stored in the marketItem struct. So we need to manage this way.
     */
    function _emitEventForSplitPayment(
        SaleDTO memory saleDTO,
        MarketItem memory marketItem,
        MintGoldDustNFT nft,
        address artist,
        uint256 balance,
        uint256 fee,
        uint256 collFeeOrRoyalty,
        bool isPrimarySale,
        uint256 value,
        address sender
    ) private {
        if (isPrimarySale) {
            emit MintGoldDustNftPurchasedPrimaryMarket(
                itemsSold.current(),
                saleDTO.tokenId,
                saleDTO.seller,
                sender,
                value,
                balance,
                fee,
                collFeeOrRoyalty,
                saleDTO.amount,
                true,
                marketItem.isERC721
            );
            return;
        }

        emit MintGoldDustNftPurchasedSecondaryMarket(
            itemsSold.current(),
            saleDTO.tokenId,
            saleDTO.seller,
            sender,
            value,
            balance,
            nft.tokenIdRoyaltyPercent(saleDTO.tokenId),
            collFeeOrRoyalty,
            artist,
            fee,
            saleDTO.amount,
            true,
            marketItem.isERC721
        );
    }

    /**
     * @notice that this function do continuity to split payment flow.
     * @dev Explain to a developer any extra details
     * @param nft MintGoldDustNFT is an instance of MintGoldDustERC721 or MintGoldDustERC1155.
     * @param saleDTO The SaleDTO struct parameter to use.
     *                 It consists of the following fields:
     *                    - tokenid: The tokenId of the marketItem.
     *                    - amount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
     *                              MintGoldDustERC721 the amout must be always one.
     *                    - contractAddress: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
     *                    - seller: The seller of the marketItem.
     * @param balance uint256 that represents the total amount to be received by the seller after fee calculations.
     * @param fee uint256 the primary or the secondary fee to be paid by the buyer.
     * @param collFeeOrRoyalty uint256 that represent the collerctor fee or the royalty depending of the flow.
     * @param artistOrSeller address for the artist on secondary sales and for the seller on the primary sales.
     * @param isPrimarySale bool that helps the code to go for the correct flow (Primary or Secondary sale).
     * @param value The value to be paid for the purchase.
     * @param sender The address that started this flow.
     *    @dev we need to receive the sender this way, because in the auction flow the purchase starts from
     *         the endAuction function in the MintGoldDustMarketplaceAuction contract. So from there the address
     *         that we get is the highst bidder that is stored in the marketItem struct. So we need to manage this way.
     */
    function _handleSplitPaymentCall(
        MintGoldDustNFT nft,
        SaleDTO memory saleDTO,
        uint256 balance,
        uint256 fee,
        uint256 collFeeOrRoyalty,
        address artistOrSeller,
        bool isPrimarySale,
        uint256 value,
        address sender
    ) private {
        nft.transfer(address(this), sender, saleDTO.tokenId, saleDTO.amount);
        _splittedSale(
            balance,
            fee,
            collFeeOrRoyalty,
            artistOrSeller,
            nft,
            saleDTO,
            isPrimarySale,
            value,
            sender
        );
    }

    /**
     * @notice that this function is responsible to start the secondary sale flow.
     * @dev here we apply the fees related with the secondary market that are:
     *                 - the secondarySaleFeePercent and the tokenIdRoyaltyPercent.
     * @param marketItem The MarketItem struct parameter to use.
     *                 It consists of the following fields:
     *                    - tokenId: The tokenId of the marketItem.
     *                    - seller: The seller of the marketItem.
     *                    - price: The price which the item should be sold.
     *                    - sold: It says if an item was or not sold.
     *                    - isAuction: true if the item was listed for marketplace auction and false if for set price market.
     *                    - isERC721: true is an MintGoldDustERC721 token.
     *                    - tokenAmount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
     *                              MintGoldDustERC721 the amout must be always one.
     *                    - auctionProps:
     *                        - endTime: the time that the auction must be finished. Is the start time plus 24 hours.
     *                        - highestBidder: the bidder that did bid the highest value.
     *                        - highestBid: the value of the high bid.
     *                        - ended: a boolean that indicates if the auction was already finished or not.
     * @param saleDTO The SaleDTO struct parameter to use.
     *                 It consists of the following fields:
     *                    - tokenid: The tokenId of the marketItem.
     *                    - amount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
     *                              MintGoldDustERC721 the amout must be always one.
     *                    - contractAddress: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
     *                    - seller: The seller of the marketItem.
     * @param value The value to be paid for the purchase.
     * @param sender The address that started this flow.
     *    @dev we need to receive the sender this way, because in the auction flow the purchase starts from
     *         the endAuction function in the MintGoldDustMarketplaceAuction contract. So from there the address
     *         that we get is the highst bidder that is stored in the marketItem struct. So we need to manage this way.
     */
    function _secondarySale(
        MarketItem memory marketItem,
        SaleDTO memory saleDTO,
        uint256 value,
        address sender
    ) private {
        itemsSold.increment();

        uint256 fee;
        uint256 royalty;
        uint256 balance;

        fee =
            (value * mintGoldDustCompany.secondarySaleFeePercent()) /
            (100e18);
        royalty =
            (value * saleDTO.nft.tokenIdRoyaltyPercent(saleDTO.tokenId)) /
            (100e18);

        balance = value - (fee + royalty);

        _checkIfIsSplitPaymentAndCall(
            saleDTO.nft,
            marketItem,
            saleDTO,
            balance,
            fee,
            royalty,
            false,
            value,
            sender
        );

        (bool successOwner, ) = payable(mintGoldDustCompany.owner()).call{
            value: fee
        }("");
        require(successOwner, "Transaction to owner failed.");

        (bool successSeller, ) = payable(marketItem.seller).call{
            value: balance
        }("");
        require(successSeller, "Transaction to seller failed.");
    }

    /// @dev it is a private function to verify if the msg.value is enough to pay the product between the
    ///      price of the token and the quantity desired.
    /// @param price the price of one market item.
    /// @param amount the quantity desired for this purchase.
    /// @param value the value sent by the buyer.
    /// @notice that it REVERTS with a InvalidAmountForThisPurchase() error if the condition is not met.
    function _isMsgValueEnough(
        uint256 price,
        uint256 amount,
        uint256 value,
        uint256 _auctionId
    ) private pure {
        uint256 realAmount = amount;
        if (_auctionId != 0) {
            realAmount = 1;
        }

        if (value != price * realAmount) {
            revert InvalidAmountForThisPurchase();
        }
    }

    /**
     * @dev Checks if the provided value is enough to cover the total price of the product, including a 3% fee.
     * @param price The unit price of the item.
     * @param amount The quantity of items desired for purchase.
     * @param value The value sent with the transaction, expected to cover the totalPrice including the 3% fee.
     * @notice Reverts with the InvalidAmountForThisPurchase error if the provided value doesn't match the expected amount.
     */
    function _isMsgValueEnoughPrimarySale(
        uint256 price,
        uint256 amount,
        uint256 value,
        uint256 _auctionId
    ) private pure {
        uint256 realAmount = amount;
        if (_auctionId != 0) {
            realAmount = 1;
        }

        // Calculate total price for the amount
        uint256 totalPrice = price * realAmount;

        // Calculate the increase using higher precision
        uint256 increase = (totalPrice * 3) / 100;

        uint256 realPrice = totalPrice + increase;

        // Check if value is equal to totalPrice + realPrice
        if (value != realPrice && _auctionId == 0) {
            revert InvalidAmountForThisPurchase();
        }

        if (value < realPrice && _auctionId > 0) {
            revert InvalidAmountForThisPurchase();
        }
    }
}


// File: lib/v2-contracts/contracts/marketplace/MintGoldDustERC1155.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import {MintGoldDustCompany} from "./MintGoldDustCompany.sol";
import {MintGoldDustNFT} from "./MintGoldDustNFT.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

/// @title A contract responsible by all the operations related with Mint Gold Dust ERC1155 tokens.
/// @notice Contains functions to mint, transfer and burn Mint Gold Dust ERC1155 tokens.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io

contract MintGoldDustERC1155 is
    Initializable,
    ERC1155Upgradeable,
    ERC1155URIStorageUpgradeable,
    MintGoldDustNFT
{
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;

    /**
     *
     * @notice that the MintGoldDustERC1155 is composed by other contract.
     * @param _mintGoldDustCompany The contract responsible to Mint Gold Dust management features.
     */
    function initializeChild(
        address _mintGoldDustCompany,
        string calldata baseURI
    ) external initializer {
        __ERC1155_init(baseURI);
        __ERC1155URIStorage_init();
        MintGoldDustNFT.initialize(_mintGoldDustCompany);
    }

    /**
     * @dev The transfer function wraps the safeTransferFrom function of ERC1155.
     * @param from Sender of the token.
     * @param to Token destination.
     * @param tokenId ID of the token.
     * @param amount Amount of tokens to be transferred.
     */
    function transfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) public virtual override nonReentrant {
        safeTransferFrom(from, to, tokenId, amount, "");
    }

    /// @notice that this mapping will return the uri for the respective token id.
    /// @param tokenId is the id of the token.
    function uri(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC1155Upgradeable, ERC1155URIStorageUpgradeable)
        returns (string memory)
    {
        return super.uri(tokenId);
    }

    /**
     * @notice Mints additional copy(ies) of a collector mint edition
     * @param tokenId for extra edition(s)
     * @param amount to mint
     * @dev Requirements"
     * - Must only be called by {MintGoldDustSetPrice} contract
     */
    function collectorMintFromExisting(
        uint256 tokenId,
        uint256 amount
    ) external onlySetPrice {
        _mint(tokenIdArtist[tokenId], tokenId, amount, "");
        _primarySaleQuantityToSell[tokenId] += amount;
    }

    /**
     * Mints a new Mint Gold Dust token.
     * @notice Fails if artist is not whitelisted or if the royalty surpass the max royalty limit
     * setted on MintGoldDustCompany smart contract.
     * @dev tokenIdArtist keeps track of the work of each artist and tokenIdRoyaltyPercent the royalty
     * percent for each art work.
     * @param _tokenURI The uri of the token metadata.
     * @param _royaltyPercent The royalty percentage for this art work.
     * @param _amount The amount of tokens to be minted.
     */
    function _executeMintFlow(
        string calldata _tokenURI,
        uint256 _royaltyPercent,
        uint256 _amount,
        address _sender,
        uint256 _collectorMintId,
        bytes calldata _memoir
    ) internal override isZeroAddress(_sender) returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(_sender, newTokenId, _amount, "");
        _setURI(newTokenId, _tokenURI);
        tokenIdArtist[newTokenId] = _sender;
        tokenIdRoyaltyPercent[newTokenId] = _royaltyPercent;
        tokenIdMemoir[newTokenId] = _memoir;

        _primarySaleQuantityToSell[newTokenId] = _amount;

        emit MintGoldDustNFTMinted(
            newTokenId,
            _tokenURI,
            _sender,
            _royaltyPercent,
            _amount,
            false,
            _collectorMintId,
            _memoir
        );

        return newTokenId;
    }

    /**
     * @dev Allows specified roles to burn a specific amount of a specific token ID.
     *
     * @param tokenId The ID of the token to be burned.
     * @param amount The amount of tokens to be burned.
     *
     * Requirements:
     *
     * - Caller must be either the owner or have been approved to manage the owner's tokens, or be the Mint Gold Dust Owner.
     * - The balance of the `tokenOwner` for the specific `tokenId` should be greater than or equal to the `amount` to be burned.
     * - The token specified by `tokenId` must not have been sold yet.
     *
     * Emits a {TokenBurned} event.
     */
    function burnToken(uint256 tokenId, uint256 amount) external whenNotPaused {
        require(
            // Ensure the caller is either (approved or is the owner) or is the Mint Gold Dust Owner
            isApprovedForAll(tokenIdArtist[tokenId], msg.sender) ||
                tokenIdArtist[tokenId] == msg.sender ||
                msg.sender == mintGoldDustCompany.owner() ||
                mintGoldDustCompany.isAddressValidator(msg.sender),
            "Only creator or allowed"
        );

        address tokenOwner = msg.sender;
        if (msg.sender != tokenIdArtist[tokenId]) {
            tokenOwner = tokenIdArtist[tokenId];
        }

        require(
            // Ensure the owner has enough tokens to burn
            balanceOf(tokenOwner, tokenId) >= amount,
            "Insufficient balance to burn"
        );

        require(
            // Ensure the owner has enough tokens to burn
            _primarySaleQuantityToSell[tokenId] >= amount,
            "Items sold not possible to burn"
        );

        require(_tokenWasSold[tokenId] == false, "Token already sold");

        _burn(tokenOwner, tokenId, amount);
        emit TokenBurned(
            tokenId,
            true,
            tokenIdArtist[tokenId],
            msg.sender,
            amount
        );
    }

    /**
     * @dev Overrides the ERC1155's `_burn` internal function to extend its functionalities.
     *
     * @param account The address of the token owner.
     * @param id The ID of the token to be burned.
     * @param amount The amount of tokens to be burned.
     *
     * Note: This internal function is called by the `burn` function, which takes care of validations like owner checks and sufficient balance checks.
     */
    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal override {
        super._burn(account, id, amount);
    }
}


// File: lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV // Deprecated in v4.8
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 message) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            message := keccak256(0x00, 0x3c)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 data) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "\x19\x01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            data := keccak256(ptr, 0x42)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Data with intended validator, created from a
     * `validator` and `data` according to the version 0 of EIP-191.
     *
     * See {recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x00", validator, data));
    }
}


// File: src/abstract/ERC1155Allowance.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {CommonCheckers} from "../utils/CommonCheckers.sol";

/// @title ERC1155Allowance
/// @author Mint Gold Dust LLC
/// @notice Extension for more granular allowance in ERC1155.
/// @dev This extension is required for the ERC1155Permit implementation in this repository.
abstract contract ERC1155Allowance {
  ///@dev Emit when `allowance` is set.
  event ApprovalByAmount(
    address indexed owner, address indexed operator, uint256 indexed id, uint256 amount
  );

  /// Custom Errors
  error ERC1155Allowance__spendAllowance_insufficient();
  error ERC1155Allowance__checkTokenId_notZero();

  // keccak256(abi.encodePacked(owner,operator,tokenId)) => amount
  mapping(bytes32 => uint256) internal _allowance;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /// @notice Returns the allowance given by `owner` to `operator` for `tokenId`
  /// @dev This call needs to read if `operator` is `ERC721.isApprovedForAll() == true` and return
  ///      type(uint256).max regardless of recorded state in `_allowance`.
  /// @param owner giving allowance
  /// @param operator to check allowance
  /// @param tokenId to check
  function allowance(
    address owner,
    address operator,
    uint256 tokenId
  )
    public
    view
    virtual
    returns (uint256);

  /// @notice Allow `msg.sender` for `operator` to `transfer` `tokenId` `amount`.
  /// @param operator of allowance
  /// @param tokenId to give allowance
  /// @param amount to give allowance
  function approve(address operator, uint256 tokenId, uint256 amount) public returns (bool) {
    address owner = msg.sender;
    _setAllowance(owner, operator, tokenId, amount);
    return true;
  }

  function _spendAllowance(
    address owner,
    address operator,
    uint256 tokenId,
    uint256 amount
  )
    internal
    virtual
  {
    uint256 currentAllowance = _getAllowance(owner, operator, tokenId);
    if (currentAllowance != type(uint256).max) {
      if (amount > currentAllowance) revert ERC1155Allowance__spendAllowance_insufficient();
      unchecked {
        _setAllowance(owner, operator, tokenId, currentAllowance - amount);
      }
    }
  }

  function _setAllowance(
    address owner,
    address operator,
    uint256 tokenId,
    uint256 amount
  )
    internal
    virtual
  {
    CommonCheckers.checkZeroAddress(owner);
    CommonCheckers.checkZeroAddress(operator);
    _checkTokenId(tokenId);
    _allowance[_hashedOwnerSpenderTokenID(owner, operator, tokenId)] = amount;
    emit ApprovalByAmount(owner, operator, tokenId, amount);
  }

  function _getAllowance(
    address owner,
    address operator,
    uint256 tokenId
  )
    internal
    view
    returns (uint256)
  {
    return _allowance[_hashedOwnerSpenderTokenID(owner, operator, tokenId)];
  }

  function _hashedOwnerSpenderTokenID(
    address owner,
    address operator,
    uint256 tokenId
  )
    internal
    pure
    returns (bytes32)
  {
    return keccak256(abi.encodePacked(owner, operator, tokenId));
  }

  /// @dev Revert if unsigned `input` is greater than zero
  function _checkTokenId(uint256 input) internal pure {
    if (input == 0) {
      revert ERC1155Allowance__checkTokenId_notZero();
    }
  }
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/IERC1155Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
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
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
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
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/IERC1155ReceiverUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155ReceiverUpgradeable is IERC165Upgradeable {
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155Upgradeable.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURIUpgradeable is IERC1155Upgradeable {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/ERC165Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

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
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}


// File: lib/v2-contracts/contracts/marketplace/MintGoldDustCompany.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title A contract responsible by Mint Gold Dust management.
/// @notice Contains functions for access levels management.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract MintGoldDustCompany is Initializable, IERC165, OwnableUpgradeable {
    /**
     * @dev all attributes are public to be accessible by the other contracts
     * that are composed by this one
     */
    uint256 public primarySaleFeePercent;
    uint256 public secondarySaleFeePercent;
    uint256 public collectorFee;
    uint256 public maxRoyalty;
    uint256 public auctionDuration;
    uint256 public auctionFinalMinutes;
    address public publicKey;
    bytes4 private constant ERC165_ID = 0x01ffc9a7; //ERC165
    mapping(address => bool) public isArtistApproved;
    mapping(address => bool) public isAddressValidator;

    event ArtistWhitelisted(address indexed artistAddress, bool state);

    event ValidatorAdded(address indexed validatorAddress, bool state);

    error Unauthorized();

    /// @notice that this modifier is used to check if the address is a validator or the owner
    modifier isValidatorOrOwner() {
        if (isAddressValidator[msg.sender] || msg.sender == owner()) {
            _;
        } else {
            revert Unauthorized();
        }
    }

    /// @notice that this modifier is used to check if the address is not zero address
    modifier isZeroAddress(address _address) {
        require(_address != address(0), "address is zero address");
        _;
    }

    /**
     *
     * @param _owner is the address that should be the owner of the contract.
     * @param _primarySaleFeePercent is the fee setted for primary sales (15%)
     * @param _secondarySaleFeePercent is the fee setted for secondary sales (5%)
     * @param _collectorFee is the fee paid by collectors setted for primary sales (3%)
     * @param _maxRoyalty is the maximum percetange that an artist can set to its artwork (20%)
     * @param _auctionDurationInMinutes is the duration of the auction in minutes (86400)
     * @param _auctionFinalMinutes is the duration of the final minutes of the auction (300)
     */
    function initialize(
        address _owner,
        uint256 _primarySaleFeePercent,
        uint256 _secondarySaleFeePercent,
        uint256 _collectorFee,
        uint256 _maxRoyalty,
        uint256 _auctionDurationInMinutes,
        uint256 _auctionFinalMinutes
    ) external initializer isZeroAddress(_owner) {
        __Ownable_init();
        _transferOwnership(_owner);
        primarySaleFeePercent = _primarySaleFeePercent;
        secondarySaleFeePercent = _secondarySaleFeePercent;
        collectorFee = _collectorFee;
        maxRoyalty = _maxRoyalty;
        auctionDuration = _auctionDurationInMinutes * 1 seconds;
        auctionFinalMinutes = _auctionFinalMinutes * 1 seconds;
    }

    /// @notice Set the public key to be used by the Mint Gold Dust Company
    /// @param _mintGoldDustPublicKey is the public key to be used by the Mint Gold Dust Company
    function setPublicKey(
        address _mintGoldDustPublicKey
    ) external onlyOwner isZeroAddress(_mintGoldDustPublicKey) {
        publicKey = _mintGoldDustPublicKey;
    }

    /// @notice Add new validators to Mint Gold Dust Company
    function setValidator(
        address _address,
        bool _state
    ) external onlyOwner isZeroAddress(_address) {
        isAddressValidator[_address] = _state;
        emit ValidatorAdded(_address, _state);
    }

    /// @notice Whitelist/Blacklist artist
    function whitelist(
        address _address,
        bool _state
    ) external isValidatorOrOwner isZeroAddress(_address) {
        isArtistApproved[_address] = _state;
        emit ArtistWhitelisted(_address, _state);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return interfaceId == ERC165_ID;
    }
}


// File: src/utils/MgdEIP712L2Sync.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ECDSAUpgradeable} from
  "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

enum CrossAction {
  SetValidator,
  SetWhitelist
}

/// @title MgdEIP712L2Sync
/// @notice EIP721 version for MGDCompanyL2Sync
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
abstract contract MgdEIP712L2Sync {
  /// Events
  /**
   * @dev Emit when `setCrossDomainMGDCompany()` is called.
   * @param chainId of cross domain
   * @param mgdCompany address in the indicated domain
   */
  event SetCrossDomainMGDCompany(uint256 chainId, address mgdCompany);

  /// Errors
  error MgdEIP712L2Sync_getDigestToSign_unknownCrossAction();

  /// Constants
  string public constant NAME = "MGDL2SyncEIP712";
  string public constant VERSION = "v0.0.1";

  bytes32 internal constant _TYPE_HASH =
    keccak256("MgdEIP712L2SyncDomain(string name,string version,address verifyingContract)");
  bytes32 internal constant _SETVALIDATOR_TYPEHASH =
    keccak256("SetValidator(address account,bool state,uint256 chainId,uint256 deadline)");
  bytes32 internal constant _WHITELIST_TYPEHASH =
    keccak256("Whitelist(address account,bool state,uint256 chainId,uint256 deadline)");
  uint256 internal constant _MAINNET_CHAINID = 0x1;

  /// Storage

  ///@dev keccak256(abi.encodePacked("MgdEIP712L2Sync_Storage"))
  bytes32 private constant MgdEIP712L2SyncStorageLocation =
    0x61aced8c5770c0c87dc43720e6727c6d7e783173d88587bda0edf1a603612573;

  struct MgdEIP712L2Sync_Storage {
    uint256 _crossChainId;
    address _crossDomainMGDCompany; // Add more storage after here
  }

  function _getMgdEIP712L2SyncStorage() internal pure returns (MgdEIP712L2Sync_Storage storage $) {
    assembly {
      $.slot := MgdEIP712L2SyncStorageLocation
    }
  }

  /// Methods
  function setCrossDomainMGDCompany(uint256 chainId, address mgdCompany) external virtual;

  /**
   * @notice Helper function to get the digest to sign
   * @dev Requirements:
   * - Should not be used within contract
   */
  function getDigestToSign(
    CrossAction action,
    address account,
    bool state,
    uint256 chainId,
    uint256 deadline
  )
    external
    view
    returns (bytes32 digest)
  {
    if (action == CrossAction.SetValidator) {
      bytes32 structHash =
        keccak256(abi.encode(_SETVALIDATOR_TYPEHASH, account, state, chainId, deadline));
      digest = _hashTypedDataV4(structHash);
    } else if (action == CrossAction.SetWhitelist) {
      bytes32 structHash =
        keccak256(abi.encode(_WHITELIST_TYPEHASH, account, state, chainId, deadline));
      digest = _hashTypedDataV4(structHash);
    } else {
      revert MgdEIP712L2Sync_getDigestToSign_unknownCrossAction();
    }
  }

  function crossDomainMGDCompany() public view returns (address) {
    MgdEIP712L2Sync_Storage storage $ = _getMgdEIP712L2SyncStorage();
    return $._crossDomainMGDCompany;
  }

  /**
   * @notice Sets the cross domain MGDCompany address
   * @param chainId of domain
   * @param mgdCompany address of the L2 or L1 MGDCompany opposite to this.domain
   */
  function _setCrossDomainMGDCompany(uint256 chainId, address mgdCompany) internal {
    MgdEIP712L2Sync_Storage storage $ = _getMgdEIP712L2SyncStorage();
    $._crossDomainMGDCompany = mgdCompany;
    $._crossChainId = chainId;
    emit SetCrossDomainMGDCompany(chainId, mgdCompany);
  }

  /**
   * @notice Verify a `signature` of a message was signed
   * by an `expectedSigner`.
   * @param expectedSigner is the signer address.
   * @param structHash is the _signature of the eip712 object generated off chain.
   * @param signature of the message
   */
  function _verifySignature(
    address expectedSigner,
    bytes32 structHash,
    bytes memory signature
  )
    internal
    view
    returns (bool)
  {
    bytes32 digest = _hashTypedDataV4(structHash);
    address signer = ECDSAUpgradeable.recover(digest, signature);
    return signer == expectedSigner;
  }

  function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
    return ECDSAUpgradeable.toTypedDataHash(_domainSeparator(), structHash);
  }

  function _getCrossDomain() internal view returns (uint256) {
    MgdEIP712L2Sync_Storage storage $ = _getMgdEIP712L2SyncStorage();
    return block.chainid == _MAINNET_CHAINID ? $._crossChainId : block.chainid;
  }

  function _EIP712NameHash() private pure returns (bytes32) {
    return keccak256(bytes(NAME));
  }

  function _EIP712VersionHash() private pure returns (bytes32) {
    return keccak256(bytes(VERSION));
  }

  function _domainSeparator() private view returns (bytes32) {
    return keccak256(
      abi.encode(_TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash(), _getAuthorizedAddress())
    );
  }

  function _getAuthorizedAddress() private view returns (address) {
    return block.chainid == _MAINNET_CHAINID ? crossDomainMGDCompany() : address(this);
  }
}


// File: src/interfaces/ICrossDomainMessenger.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface ICrossDomainMessenger {
  /// https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts-bedrock/src/L1/L1CrossDomainMessenger.sol
  function sendMessage(address _target, bytes memory _message, uint32 _gasLimit) external;
  function xDomainMessageSender() external returns (address);
}


// File: lib/v2-contracts/contracts/libraries/MgdMarketPlaceDataTypes.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustNFT} from "../marketplace/MintGoldDustNFT.sol";

/**
 * This struct consists of the following fields:
 *    - endTime: the time that the auction must be finished. Is the start time plus 24 hours.
 *    - highestBidder: the bidder that did bid the highest value.
 *    - highestBid: the value of the high bid.
 *    - ended: a boolean that indicates if the auction was already finished or not.
 */
struct AuctionProps {
    uint256 auctionId;
    uint256 startTime;
    uint256 endTime;
    address highestBidder;
    uint256 highestBid;
    bool ended;
}

/**
 * @notice that is a Data Transfer Object to be transferred betwwen the functions in the auction flow.
 *              It consists of the following fields:
 *                    - tokenId: The tokenId of the marketItem.
 *                    - nft: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
 *                    - seller: The seller of the marketItem.
 */
struct BidDTO {
    uint256 tokenId;
    MintGoldDustNFT nft;
    address seller;
}

/**
 * @notice that is a Data Transfer Object to be transferred between functions in the Collector (lazy) mint flow.
 *              It consists of the following fields:
 *                    - nft: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
 *                    - tokenURI the URI that contains the metadata for the NFT.
 *                    - royalty the royalty percentage to be applied for this NFT secondary sales.
 *                    - collaborators an array of address that can be a number of maximum 4 collaborators.
 *                    - ownersPercentage an array of uint256 that are the percetages for the artist and for each one of the collaborators.
 *                    - amount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
 *                              MintGoldDustERC721 the amout must be always one.
 *                    - artistSigner: the address of the artist creator.
 *                    - price: the price to be paid for the item in the set price market.
 *                    - collectorMintId: the id of the collector mint generated off chain.
 */
struct CollectorMintDTO {
    MintGoldDustNFT nft;
    string tokenURI;
    uint256 royalty;
    bytes memoir;
    address[] collaborators;
    uint256[] ownersPercentage;
    uint256 amount;
    address artistSigner;
    uint256 price;
    uint256 collectorMintId;
}

struct DelistDTO {
    uint256 tokenId;
    uint256 amount;
    MintGoldDustNFT nft;
}

/**
 * @notice that is a Data Transfer Object to be transferred between functions for the listing flow.
 *              It consists of the following fields:
 *                    - tokenid: The tokenId of the marketItem.
 *                    - amount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
 *                              MintGoldDustERC721 the amout must be always one.
 *                    - nft: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
 *                    - price: the price to be paid for the item in the set price market and it correponds
 *                             to the reserve price for the marketplace auction.
 */
struct ListDTO {
    uint256 tokenId;
    uint256 amount;
    MintGoldDustNFT nft;
    uint256 price;
}

/// @notice that this struct has the necessary fields to manage the secondary sales.
struct ManagePrimarySale {
    address owner;
    bool soldout;
    uint256 amount;
}

/**
 * This struct consists of the following fields:
 *    - tokenId: The tokenId of the marketItem.
 *    - seller: The seller of the marketItem.
 *    - price: The price which the item should be sold.
 *    - sold: It says if an item was or not sold.
 *    - isAuction: true if the item was listed for marketplace auction and false if for set price market.
 *    - isERC721: true is an MintGoldDustERC721 token.
 *    - tokenAmount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
 *              MintGoldDustERC721 the amout must be always one.
 *    - AuctionProps: The AuctionProps structure (See below).
 */
struct MarketItem {
    uint256 tokenId;
    address seller;
    uint256 price;
    bool isERC721;
    uint256 tokenAmount;
    AuctionProps auctionProps;
}

/**
 * @notice that is a Data Transfer Object to be transferred between functions for the sale flow.
 *              It consists of the following fields:
 *                  - tokenid: The tokenId of the marketItem.
 *                  - amount: The quantity of tokens to be listed for an MintGoldDustERC1155. For
 *                            MintGoldDustERC721 the amout must be always one.
 *                  - nft: The MintGoldDustERC1155 or the MintGoldDustERC721 address.
 *                  - seller: The seller of the marketItem.
 */
struct SaleDTO {
    uint256 tokenId;
    uint256 amount;
    MintGoldDustNFT nft;
    address seller;
}


// File: lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

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
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
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


// File: lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev _Available since v3.1._
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// File: lib/v2-contracts/contracts/marketplace/MintGoldDustERC721.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {MintGoldDustCompany} from "./MintGoldDustCompany.sol";
import {MintGoldDustNFT} from "./MintGoldDustNFT.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

/// @title A contract responsible by all the operations related with Mint Gold Dust ERC721 tokens.
/// @notice Contains functions to mint, transfer and burn Mint Gold Dust ERC721 tokens.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io

contract MintGoldDustERC721 is
    Initializable,
    ERC721URIStorageUpgradeable,
    MintGoldDustNFT
{
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;

    /**
     *
     * @notice that the MintGoldDustERC721 is composed by other contract.
     * @param _mintGoldDustCompany The contract responsible to Mint Gold Dust management features.
     */
    function initializeChild(
        address _mintGoldDustCompany
    ) external initializer {
        __ERC721_init("Mint Gold Dust NFT", "MGDNFT");
        __ERC721URIStorage_init();
        MintGoldDustNFT.initialize(_mintGoldDustCompany);
    }

    /**
     * @dev the safeTransferFrom function is a function of ERC721. And because of the
     * necessity of call this function from other contract by composition we did need to
     * create this public function.
     * @param _from sender of the token.
     * @param _to token destionation.
     * @param _tokenId id of the token.
     */
    function transfer(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256
    ) public virtual override nonReentrant {
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Internal function to handle the complete flow for minting a new token.
     *
     * @param _tokenURI The URI of the minted token, storing metadata off-chain.
     * @param _royaltyPercent The royalty percentage for the artist.
     * @param _sender The address of the user who initiates the minting process.
     * @param _collectorMintId The ID associated with the collector mint.
     * @param _memoir Extra data associated with the token.
     *
     * @return newTokenId Returns the newly minted token's ID.
     *
     * Requirements:
     *
     * - `_sender` must not be the zero address.
     *
     * Emits a {MintGoldDustNFTMinted} event.
     */
    function _executeMintFlow(
        string calldata _tokenURI,
        uint256 _royaltyPercent,
        uint256,
        address _sender,
        uint256 _collectorMintId,
        bytes calldata _memoir
    ) internal override isZeroAddress(_sender) returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(_sender, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        tokenIdArtist[newTokenId] = _sender;
        tokenIdRoyaltyPercent[newTokenId] = _royaltyPercent;
        tokenIdMemoir[newTokenId] = _memoir;

        _primarySaleQuantityToSell[newTokenId] = 1;

        emit MintGoldDustNFTMinted(
            newTokenId,
            _tokenURI,
            _sender,
            _royaltyPercent,
            1,
            true,
            _collectorMintId,
            _memoir
        );
        return newTokenId;
    }

    /// @dev Allows an approved address or token owner to burn a token.
    /// The function also checks if the token has been previously sold before allowing it to be burned.
    /// Emits a `TokenBurned` event upon successful burn.
    ///
    /// @param tokenId The unique identifier for the token.
    ///
    /// Requirements:
    ///
    /// - `tokenId` must exist.
    /// - The caller must be the owner of `tokenId`, or an approved address for `tokenId`,
    ///   or the owner of the contract, or a validated MintGoldDust address.
    /// - The token specified by `tokenId` must not have been sold previously.
    ///
    /// Events:
    ///
    /// - Emits a `TokenBurned` event containing the tokenId, burn status, sender, and amount.
    function burnToken(uint256 tokenId) external whenNotPaused {
        require(
            _isApprovedOrOwner(msg.sender, tokenId) ||
                msg.sender == mintGoldDustCompany.owner() ||
                mintGoldDustCompany.isAddressValidator(msg.sender),
            "Only creator or allowed"
        );

        require(_tokenWasSold[tokenId] == false, "Token already sold");

        _burn(tokenId);
        emit TokenBurned(tokenId, true, tokenIdArtist[tokenId], msg.sender, 1);
    }

    /// @dev Overrides the `_burn` function from `ERC721URIStorageUpgradeable` to perform custom logic, if any.
    /// This is an internal function that is only accessible from within this contract or derived contracts.
    ///
    /// @param tokenId The unique identifier for the token.
    ///
    /// Requirements:
    ///
    /// - `tokenId` must exist.
    ///
    /// Note:
    ///
    /// - As this is an internal function, additional requirements may be imposed by public/external functions
    ///   that call this function. Refer to those for more details.
    function _burn(
        uint256 tokenId
    ) internal override(ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }
}


// File: lib/v2-contracts/contracts/marketplace/MintGoldDustNFT.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {MintGoldDustCompany} from "./MintGoldDustCompany.sol";
import {ManagePrimarySale} from "../libraries/MgdMarketPlaceDataTypes.sol";

error RoyaltyInvalidPercentage();
error UnauthorizedOnNFT(string message);
error NumberOfCollaboratorsAndPercentagesNotMatch();
error TheTotalPercentageCantBeGreaterOrLessThan100();

abstract contract MintGoldDustNFT is
    Initializable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /**
     * @notice that this is an event that contains the info for a mint.
     * @dev it will be triggered after a successfully traditional minting or split minting.
     * @param tokenId the uint256 generated for this token.
     * @param tokenURI the URI that contains the metadata for the NFT.
     * @param owner the address of the artist creator.
     * @param royalty the royalty percetage choosen by the artist for this token.
     * @param amount the quantity to be minted for this token.
     *    @dev for MingGoldDustERC721 this amount is always one.
     * @param isERC721 a boolean that indicates if this token is ERC721 or ERC1155.
     * @param collectorMintId a unique identifier for the collector mint.
     * @param memoir the memoir for this token.
     */
    event MintGoldDustNFTMinted(
        uint256 indexed tokenId,
        string tokenURI,
        address owner,
        uint256 royalty,
        uint256 amount,
        bool isERC721,
        uint256 collectorMintId,
        bytes memoir
    );

    /**
     * @notice that this is an event that contains the info for a split mint.
     * @dev it will be triggered after a successfully split minting.
     * @param tokenId the uint256 generated for this token.
     * @param collaborators an array of address that can be a number of maximum 4 collaborators.
     * @param ownersPercentage an array of uint256 that are the percetages for the artist and for each one of the collaborators.
     * @param contractAddress the address of the contract that minted this token.
     */
    event MintGoldDustNftMintedAndSplitted(
        uint256 indexed tokenId,
        address[] collaborators,
        uint256[] ownersPercentage,
        address contractAddress
    );

    event TokenBurned(
        uint256 indexed tokenId,
        bool isERC721,
        address owner,
        address burner,
        uint256 amount
    );

    MintGoldDustCompany internal mintGoldDustCompany;
    address internal mintGoldDustSetPriceAddress;
    address internal mintGoldDustMarketplaceAuctionAddress;

    mapping(uint256 => address) public tokenIdArtist;
    mapping(uint256 => uint256) public tokenIdRoyaltyPercent;

    mapping(uint256 => bytes) public tokenIdMemoir;

    mapping(uint256 => address[4]) public tokenCollaborators;
    mapping(uint256 => uint256[5]) public tokenIdCollaboratorsPercentage;

    mapping(uint256 => bool) public hasTokenCollaborators;
    mapping(uint256 => uint256) public tokenIdCollaboratorsQuantity;

    mapping(uint256 => bool) internal _tokenWasSold;

    mapping(uint256 => uint256) internal _primarySaleQuantityToSell;

    uint256[48] private __gap;

    /// @notice that this modifier is used to check if the address is not zero address
    modifier isZeroAddress(address _address) {
        require(_address != address(0), "address is zero address");
        _;
    }

    /// @notice Checks if the array lengths are valid
    /// @dev the _ownersPercentage array length MUST be equals the _newOwners array length plus one
    modifier checkArraySize(
        address[] calldata _newOwners,
        uint256[] calldata _ownersPercentage
    ) {
        if (_ownersPercentage.length != _newOwners.length + 1) {
            revert NumberOfCollaboratorsAndPercentagesNotMatch();
        }
        _;
    }

    /// @notice that this modifier is used to check if the address is the owner
    modifier isowner() {
        if (msg.sender != mintGoldDustCompany.owner()) {
            revert UnauthorizedOnNFT("OWNER");
        }
        _;
    }

    /// @notice that this modifier is used to check if the percentage is not greater than the max royalty percentage
    modifier validPercentage(uint256 percentage) {
        if (percentage > mintGoldDustCompany.maxRoyalty()) {
            revert RoyaltyInvalidPercentage();
        }
        _;
    }

    /// @notice that this modifier is used to check if the address is whitelisted
    modifier isArtistWhitelisted(address _artistAddress) {
        if (!mintGoldDustCompany.isArtistApproved(_artistAddress)) {
            revert UnauthorizedOnNFT("ARTIST");
        }
        _;
    }

    /// @notice that this modifier do a group of verifications for the collector mint flow
    modifier checkParameters(
        address _sender,
        address _artistAddress,
        uint256 percentage
    ) {
        if (
            !mintGoldDustCompany.isArtistApproved(_artistAddress) ||
            _artistAddress == address(0)
        ) {
            revert UnauthorizedOnNFT("ARTIST");
        }
        if (msg.sender == address(0)) {
            revert UnauthorizedOnNFT("CONTRACT");
        }
        if (percentage > mintGoldDustCompany.maxRoyalty()) {
            revert RoyaltyInvalidPercentage();
        }
        _;
    }

    /// @notice that this modifier is used to check if the address is the Mint Gold Dust set price contract address
    /// @dev it is used by the collectorMint flows
    modifier onlySetPrice() {
        if (msg.sender != mintGoldDustSetPriceAddress) {
            revert UnauthorizedOnNFT("SET_PRICE");
        }
        _;
    }

    /**
     * @notice that the MintGoldDustERC721 is composed by other contract.
     * @param _mintGoldDustCompany The contract responsible to MGD management features.
     */
    function initialize(
        address _mintGoldDustCompany
    ) internal onlyInitializing isZeroAddress(_mintGoldDustCompany) {
        __ReentrancyGuard_init();
        __Pausable_init();
        mintGoldDustCompany = MintGoldDustCompany(
            payable(_mintGoldDustCompany)
        );
    }

    /// @dev this function will be removed after upgrade the contracts to the new version.
    function setOverridePrimarySaleQuantityToSell(
        uint256[] calldata _tokenId
    ) external {
        require(
            msg.sender == mintGoldDustCompany.owner() &&
                address(this) == 0x4B0Dc0900dDe9d4f15115Bee56554857AE0Becb0,
            "Unauthorized"
        );
        uint256 len = _tokenId.length;

        for (uint i = 0; i < len; i++) {
            _primarySaleQuantityToSell[_tokenId[i]] = 1;
        }
    }

    function getManagePrimarySale(
        uint256 _tokenId
    ) public view returns (ManagePrimarySale memory) {
        uint256 remaining = _primarySaleQuantityToSell[_tokenId];
        return
            ManagePrimarySale({
                owner: tokenIdArtist[_tokenId],
                soldout: remaining == 0,
                amount: remaining
            });
    }

    /**
     * @notice that is the function responsible by the mint a new MintGoldDustNFT token.
     * @dev that is a virtual function that MUST be implemented by the NFT contracts childrens.
     * @param _tokenURI the URI that contains the metadata for the NFT.
     * @param _royaltyPercent the royalty percentage to be applied for this NFT secondary sales.
     * @param _amount the quantity to be minted for this token.
     */
    function mintNft(
        string calldata _tokenURI,
        uint256 _royaltyPercent,
        uint256 _amount,
        bytes calldata _memoir
    )
        public
        payable
        isArtistWhitelisted(msg.sender)
        validPercentage(_royaltyPercent)
        whenNotPaused
        returns (uint256)
    {
        uint256 newTokenId = _executeMintFlow(
            _tokenURI,
            _royaltyPercent,
            _amount,
            msg.sender,
            0,
            _memoir
        );

        return newTokenId;
    }

    /**
     * @notice that is the function responsible by the mint and split a new MintGoldDustNFT token.
     * @dev that it receives two arrays one with the _newOwners that are the collaborators for this NFT
     *      and the _ownersPercentage that is the percentage of participation for each collaborators.
     *      @notice that the _newOwners array MUST always have the length equals the _ownersPercentage length minus one.
     *              it is because the fist collaborators we already have that is the creator of the NFT and is saved in
     *              the tokenIdArtist mapping.
     * @param _tokenURI the URI that contains the metadata for the NFT.
     * @param _royalty the royalty percentage to be applied for this NFT secondary sales.
     * @param _newOwners an array of address that can be a number of maximum 4 collaborators.
     * @param _ownersPercentage an array of uint256 that are the percetages for the artist and for each one of the collaborators.
     *    @dev @notice that the percetages will be applied in order that the f position 0 is the percetage for the artist and
     *                 the others will match with the _newOwners array order.
     * @param _amount the quantity to be minted for this token.
     */
    function splitMint(
        string calldata _tokenURI,
        uint256 _royalty,
        address[] calldata _newOwners,
        uint256[] calldata _ownersPercentage,
        uint256 _amount,
        bytes calldata _memoir
    )
        external
        whenNotPaused
        checkArraySize(_newOwners, _ownersPercentage)
        returns (uint256)
    {
        uint256 _tokenId = mintNft(_tokenURI, _royalty, _amount, _memoir);
        _executeSplitMintFlow(_tokenId, _newOwners, _ownersPercentage);
        return _tokenId;
    }

    function collectorMint(
        string calldata _tokenURI,
        uint256 _royaltyPercent,
        uint256 _amountToMint,
        address _artistAddress,
        bytes calldata _memoir,
        uint256 _collectorMintId,
        address _sender
    )
        external
        onlySetPrice
        checkParameters(_sender, _artistAddress, _royaltyPercent)
        whenNotPaused
        returns (uint256)
    {
        uint256 newTokenId = _executeMintFlow(
            _tokenURI,
            _royaltyPercent,
            _amountToMint,
            _artistAddress,
            _collectorMintId,
            _memoir
        );

        return newTokenId;
    }

    function collectorSplitMint(
        string calldata _tokenURI,
        uint256 _royalty,
        address[] calldata _newOwners,
        uint256[] calldata _ownersPercentage,
        uint256 _amountToMint,
        address _artistAddress,
        bytes calldata _memoir,
        uint256 _collectorMintId,
        address _sender
    )
        external
        onlySetPrice
        checkParameters(_sender, _artistAddress, _royalty)
        whenNotPaused
        checkArraySize(_newOwners, _ownersPercentage)
        returns (uint256)
    {
        uint256 _tokenId = _executeMintFlow(
            _tokenURI,
            _royalty,
            _amountToMint,
            _artistAddress,
            _collectorMintId,
            _memoir
        );

        _executeSplitMintFlow(_tokenId, _newOwners, _ownersPercentage);
        return _tokenId;
    }

    /// @notice Reduces the quantity of remaining items available for primary sale for a specific token.
    ///         Only executes the update if there is a non-zero quantity of the token remaining for primary sale.
    /// @dev This function should only be called by authorized addresses.
    /// @param _tokenId The ID of the token whose primary sale quantity needs to be updated.
    /// @param _amountSold The amount sold that needs to be subtracted from the remaining quantity.
    function updatePrimarySaleQuantityToSell(
        uint256 _tokenId,
        uint256 _amountSold
    ) external virtual {
        require(
            msg.sender == mintGoldDustMarketplaceAuctionAddress ||
                msg.sender == mintGoldDustSetPriceAddress,
            "Unauthorized on NFT"
        );
        if (_primarySaleQuantityToSell[_tokenId] > 0) {
            _primarySaleQuantityToSell[_tokenId] =
                _primarySaleQuantityToSell[_tokenId] -
                _amountSold;
        }
    }

    function setTokenWasSold(uint256 _tokenId) public {
        require(
            msg.sender == mintGoldDustMarketplaceAuctionAddress ||
                msg.sender == mintGoldDustSetPriceAddress,
            "Unauthorized on NFT"
        );
        if (!_tokenWasSold[_tokenId]) {
            _tokenWasSold[_tokenId] = true;
        }
    }

    /// @notice that this function is used for the Mint Gold Dust owner
    /// create the dependence of the Mint Gold Dust set price contract address.
    /// @param _mintGoldDustSetPriceAddress the address to be setted.
    function setMintGoldDustSetPriceAddress(
        address _mintGoldDustSetPriceAddress
    ) external {
        require(msg.sender == mintGoldDustCompany.owner(), "Unauthorized");
        require(
            address(mintGoldDustSetPriceAddress) == address(0),
            "Already setted!"
        );
        mintGoldDustSetPriceAddress = _mintGoldDustSetPriceAddress;
    }

    /// @notice that this function is used for the Mint Gold Dust owner
    /// create the dependence of the Mint Gold Dust Marketplace Auction address.
    /// @param _mintGoldDustMarketplaceAuctionAddress the address to be setted.
    function setMintGoldDustMarketplaceAuctionAddress(
        address _mintGoldDustMarketplaceAuctionAddress
    ) external {
        require(msg.sender == mintGoldDustCompany.owner(), "Unauthorized");
        require(
            address(mintGoldDustMarketplaceAuctionAddress) == address(0),
            "Already setted!"
        );
        mintGoldDustMarketplaceAuctionAddress = _mintGoldDustMarketplaceAuctionAddress;
    }

    function transfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external virtual;

    function _executeMintFlow(
        string calldata _tokenURI,
        uint256 _royaltyPercent,
        uint256 _amount,
        address _artistAddress,
        uint256 _collectorMintId,
        bytes calldata _memoir
    ) internal virtual returns (uint256);

    function _executeSplitMintFlow(
        uint256 _tokenId,
        address[] calldata _newOwners,
        uint256[] calldata _ownersPercentage
    ) private {
        uint256 ownersCount = 0;
        /// @dev it is a new variable to keep track of the total percentage assigned to collaborators.
        uint256 totalPercentage = 0;

        for (uint256 i = 0; i < _newOwners.length; i++) {
            require(
                _newOwners[i] != address(0),
                "Owner address cannot be null!"
            );
            require(_ownersPercentage[i] > 0, "Percentage must be > zero!");

            ownersCount++;
            totalPercentage += _ownersPercentage[i]; /// @dev Accumulate the percentage for each valid collaborator
            tokenCollaborators[_tokenId][i] = _newOwners[i];
            tokenIdCollaboratorsPercentage[_tokenId][i] = _ownersPercentage[i];
        }

        require(
            _ownersPercentage[ownersCount] > 0,
            "Percentage must be > zero!"
        );

        require(ownersCount >= 1, "Add more than 1 owner!");

        require(ownersCount < 5, "Add max 4!");

        /// @dev the array of percentages is always one number greater than the collaborators length.
        /// So is necessary do one more addition here.
        totalPercentage += _ownersPercentage[ownersCount];

        if (totalPercentage != 100e18) {
            revert TheTotalPercentageCantBeGreaterOrLessThan100();
        }

        tokenIdCollaboratorsQuantity[_tokenId] = ownersCount + 1;
        tokenIdCollaboratorsPercentage[_tokenId][
            ownersCount
        ] = _ownersPercentage[ownersCount];

        hasTokenCollaborators[_tokenId] = true;
        emit MintGoldDustNftMintedAndSplitted(
            _tokenId,
            _newOwners,
            _ownersPercentage,
            address(this)
        );
    }

    /// @notice Pause the contract
    function pauseContract() external isowner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpauseContract() external isowner {
        _unpause();
    }
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC1155/extensions/ERC1155URIStorage.sol)

pragma solidity ^0.8.0;

import "../../../utils/StringsUpgradeable.sol";
import "../ERC1155Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev ERC1155 token with storage based token URI management.
 * Inspired by the ERC721URIStorage extension
 *
 * _Available since v4.6._
 */
abstract contract ERC1155URIStorageUpgradeable is Initializable, ERC1155Upgradeable {
    function __ERC1155URIStorage_init() internal onlyInitializing {
        __ERC1155URIStorage_init_unchained();
    }

    function __ERC1155URIStorage_init_unchained() internal onlyInitializing {
        _baseURI = "";
    }
    using StringsUpgradeable for uint256;

    // Optional base URI
    string private _baseURI;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the concatenation of the `_baseURI`
     * and the token-specific uri if the latter is set
     *
     * This enables the following behaviors:
     *
     * - if `_tokenURIs[tokenId]` is set, then the result is the concatenation
     *   of `_baseURI` and `_tokenURIs[tokenId]` (keep in mind that `_baseURI`
     *   is empty per default);
     *
     * - if `_tokenURIs[tokenId]` is NOT set then we fallback to `super.uri()`
     *   which in most cases will contain `ERC1155._uri`;
     *
     * - if `_tokenURIs[tokenId]` is NOT set, and if the parents do not have a
     *   uri value set, then the result is empty.
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];

        // If token URI is set, concatenate base URI and tokenURI (via abi.encodePacked).
        return bytes(tokenURI).length > 0 ? string(abi.encodePacked(_baseURI, tokenURI)) : super.uri(tokenId);
    }

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */
    function _setURI(uint256 tokenId, string memory tokenURI) internal virtual {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    /**
     * @dev Sets `baseURI` as the `_baseURI` for all tokens
     */
    function _setBaseURI(string memory baseURI) internal virtual {
        _baseURI = baseURI;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}


// File: lib/openzeppelin-contracts/contracts/utils/Strings.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";
import "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
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
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMath.abs(value))));
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
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}


// File: src/utils/CommonCheckers.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

library CommonCheckers {
  /// Custom Errors
  error CommonCheckers__checkZeroAddress_notAllowed();
  error CommonCheckers__checkGtZero_notZero();

  /// @dev Revert if `addr` is zero
  function checkZeroAddress(address addr) internal pure {
    if (addr == address(0)) {
      revert CommonCheckers__checkZeroAddress_notAllowed();
    }
  }

  /// @notice Checks that unsigned `input` is greater than zero
  function checkGtZero(uint256 input) internal pure {
    if (input == 0) {
      revert CommonCheckers__checkGtZero_notZero();
    }
  }
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/IERC165Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
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
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
        require(newOwner != address(0), "Ownable: new owner is the zero address");
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// File: lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

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


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/ECDSAUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../StringsUpgradeable.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSAUpgradeable {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV // Deprecated in v4.8
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 message) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            message := keccak256(0x00, 0x3c)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", StringsUpgradeable.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 data) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "\x19\x01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            data := keccak256(ptr, 0x42)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Data with intended validator, created from a
     * `validator` and `data` according to the version 0 of EIP-191.
     *
     * See {recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x00", validator, data));
    }
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/extensions/ERC721URIStorage.sol)

pragma solidity ^0.8.0;

import "../ERC721Upgradeable.sol";
import "../../../interfaces/IERC4906Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev ERC721 token with storage based token URI management.
 */
abstract contract ERC721URIStorageUpgradeable is Initializable, IERC4906Upgradeable, ERC721Upgradeable {
    function __ERC721URIStorage_init() internal onlyInitializing {
    }

    function __ERC721URIStorage_init_unchained() internal onlyInitializing {
    }
    using StringsUpgradeable for uint256;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Emits {MetadataUpdate}.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;

        emit MetadataUpdate(tokenId);
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally checks to see if a
     * token-specific URI was set for the token, and if so, it deletes the token URI from
     * the storage mapping.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/StringsUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/MathUpgradeable.sol";
import "./math/SignedMathUpgradeable.sol";

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
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
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
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
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMathUpgradeable.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, MathUpgradeable.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}


// File: lib/openzeppelin-contracts/contracts/utils/math/Math.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
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
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
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
            require(denominator > prod1, "Math: mulDiv overflow");

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

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
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

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
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
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
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
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
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
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
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
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
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
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}


// File: lib/openzeppelin-contracts/contracts/utils/math/SignedMath.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

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


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721Upgradeable.sol";
import "./IERC721ReceiverUpgradeable.sol";
import "./extensions/IERC721MetadataUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/StringsUpgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC721Upgradeable, IERC721MetadataUpgradeable {
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __ERC721_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
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
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
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
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to] += 1;
        }

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId, 1);
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
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721Upgradeable.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner = ERC721Upgradeable.ownerOf(tokenId);

        // Clear approvals
        delete _tokenApprovals[tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId, 1);
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
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721ReceiverUpgradeable(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721ReceiverUpgradeable.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual {}

    /**
     * @dev Hook that is called after any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens were transferred to `to`.
     * - When `from` is zero, the tokens were minted for `to`.
     * - When `to` is zero, ``from``'s tokens were burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual {}

    /**
     * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
     *
     * WARNING: Anyone calling this MUST ensure that the balances remain consistent with the ownership. The invariant
     * being that for any address `a` the value returned by `balanceOf(a)` must be equal to the number of tokens such
     * that `ownerOf(tokenId)` is `a`.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __unsafe_increaseBalance(address account, uint256 amount) internal {
        _balances[account] += amount;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[44] private __gap;
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4906Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC4906.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "./IERC721Upgradeable.sol";

/// @title EIP-721 Metadata Update Extension
interface IERC4906Upgradeable is IERC165Upgradeable, IERC721Upgradeable {
    /// @dev This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
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
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
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
            require(denominator > prod1, "Math: mulDiv overflow");

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

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
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

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
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
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
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
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
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
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
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
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
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
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}


// File: lib/openzeppelin-contracts-upgradeable/contracts/utils/math/SignedMathUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMathUpgradeable {
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/IERC721Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
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
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
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
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
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
     * - The `operator` cannot be the caller.
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/IERC721ReceiverUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721MetadataUpgradeable is IERC721Upgradeable {
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


// File: lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC165Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC165.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165Upgradeable.sol";


// File: lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC721Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC721.sol)

pragma solidity ^0.8.0;

import "../token/ERC721/IERC721Upgradeable.sol";


