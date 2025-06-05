// File: @chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Client} from "../libraries/Client.sol";

/// @notice Application contracts that intend to receive messages from
/// the router should implement this interface.
interface IAny2EVMMessageReceiver {
  /// @notice Called by the Router to deliver a message.
  /// If this reverts, any token transfers also revert. The message
  /// will move to a FAILED state and become available for manual execution.
  /// @param message CCIP Message
  /// @dev Note ensure you check the msg.sender is the OffRampRouter
  function ccipReceive(Client.Any2EVMMessage calldata message) external;
}


// File: @chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Client} from "../libraries/Client.sol";

interface IRouterClient {
  error UnsupportedDestinationChain(uint64 destChainSelector);
  error InsufficientFeeTokenAmount();
  error InvalidMsgValue();

  /// @notice Checks if the given chain ID is supported for sending/receiving.
  /// @param chainSelector The chain to check.
  /// @return supported is true if it is supported, false if not.
  function isChainSupported(uint64 chainSelector) external view returns (bool supported);

  /// @notice Gets a list of all supported tokens which can be sent or received
  /// to/from a given chain id.
  /// @param chainSelector The chainSelector.
  /// @return tokens The addresses of all tokens that are supported.
  function getSupportedTokens(uint64 chainSelector) external view returns (address[] memory tokens);

  /// @param destinationChainSelector The destination chainSelector
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return fee returns guaranteed execution fee for the specified message
  /// delivery to destination chain
  /// @dev returns 0 fee on invalid message.
  function getFee(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage memory message
  ) external view returns (uint256 fee);

  /// @notice Request a message to be sent to the destination chain
  /// @param destinationChainSelector The destination chain ID
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return messageId The message ID
  /// @dev Note if msg.value is larger than the required fee (from getFee) we accept
  /// the overpayment with no refund.
  function ccipSend(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage calldata message
  ) external payable returns (bytes32);
}


// File: @chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// End consumer library.
library Client {
  struct EVMTokenAmount {
    address token; // token address on the local chain.
    uint256 amount; // Amount of tokens.
  }

  struct Any2EVMMessage {
    bytes32 messageId; // MessageId corresponding to ccipSend on source.
    uint64 sourceChainSelector; // Source chain selector.
    bytes sender; // abi.decode(sender) if coming from an EVM chain.
    bytes data; // payload sent in original message.
    EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
  }

  // If extraArgs is empty bytes, the default is 200k gas limit and strict = false.
  struct EVM2AnyMessage {
    bytes receiver; // abi.encode(receiver address) for dest EVM chains
    bytes data; // Data payload
    EVMTokenAmount[] tokenAmounts; // Token transfers
    address feeToken; // Address of feeToken. address(0) means you will send msg.value.
    bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV1)
  }

  // extraArgs will evolve to support new features
  // bytes4(keccak256("CCIP EVMExtraArgsV1"));
  bytes4 public constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;
  struct EVMExtraArgsV1 {
    uint256 gasLimit; // ATTENTION!!! MAX GAS LIMIT 4M FOR BETA TESTING
    bool strict; // See strict sequencing details below.
  }

  function _argsToBytes(EVMExtraArgsV1 memory extraArgs) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(EVM_EXTRA_ARGS_V1_TAG, extraArgs);
  }
}


// File: @chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);

  function transferFrom(address from, address to, uint256 value) external returns (bool success);
}


// File: contracts/CCIPReceiver.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

/// @title CCIPReceiver - Base contract for CCIP applications that can receive messages.
abstract contract CCIPReceiver is IAny2EVMMessageReceiver {
  address internal router;
  address internal immutable linkToken;

  error InvalidRouter(address router);

  constructor(address _router, address _link) {
    router = _router;
    linkToken = _link;
  }

  /// @inheritdoc IAny2EVMMessageReceiver
  function ccipReceive(Client.Any2EVMMessage calldata message) external virtual override onlyRouter {
    _ccipReceive(message);
  }

  /// @notice Override this function in your implementation.
  /// @param message Any2EVMMessage
  function _ccipReceive(Client.Any2EVMMessage memory message) internal virtual;

  /////////////////////////////////////////////////////////////////////
  // Plumbing
  /////////////////////////////////////////////////////////////////////

  /// @notice Return the current router
  /// @return router address
  function getRouter() public view returns (address) {
    return router;
  }

  function _setRouter(address newRouter) internal {
    router = newRouter;
  }

  /// @dev only calls from the set router are accepted.
  modifier onlyRouter() {
    if (msg.sender != router) revert InvalidRouter(msg.sender);
    _;
  }
}


// File: contracts/ERC721.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../interfaces/IERC721A.sol";
import "../libraries/String.sol";
import "./Roles.sol";

bytes32 constant _TRANSFER_EVENT_SIGNATURE =
0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

interface ERC721A__IERC721Receiver {
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external returns (bytes4);
}

abstract contract ERC721 is IERC721A {
  using String for uint256;

  error NotOwner();
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  struct TokenApprovalRef {
    address value;
  }

  address public owner;

  mapping(address => uint256) private _balance;
  mapping(uint256 => address) internal _owner;
  mapping(uint256 => TokenApprovalRef) private _tokenApprovals;
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  string public constant name = 'KingdomTiles';
  string public constant symbol = 'KT';

  string internal _baseURI;

  modifier onlyOwner() {
    if (msg.sender != owner) {
      _revert(NotOwner.selector);
    }
    _;
  }

  constructor() {
    owner = msg.sender;
  }

  function tokenURI(uint256 tokenId) external view returns(string memory) {
    string memory extra = _owner[tokenId] == address(this) ? "_ccip" : "";
    return string(abi.encodePacked(_baseURI, tokenId.toString(), extra, ".json"));
  }

  function balanceOf(address tokenOwner) external view returns(uint256) {
    return _balance[tokenOwner];
  }

  function ownerOf(uint256 tokenId) external view returns(address) {
    return _owner[tokenId];
  }

  function getApproved(uint256 tokenId) public view returns (address) {
    if (!_exists(tokenId)) _revert(ApprovalQueryForNonexistentToken.selector);

    return _tokenApprovals[tokenId].value;
  }

  function isApprovedForAll(address tokenOwner, address operator) public view returns (bool) {
    return _operatorApprovals[tokenOwner][operator];
  }

  function approve(address to, uint256 tokenId) public payable {
    address tokenOwner = _owner[tokenId];

    if (msg.sender != tokenOwner)
      if (!isApprovedForAll(tokenOwner, msg.sender)) {
        _revert(ApprovalCallerNotOwnerNorApproved.selector);
      }

    _tokenApprovals[tokenId].value = to;
    emit Approval(tokenOwner, to, tokenId);
  }

  function setApprovalForAll(address operator, bool approved) public {
    _operatorApprovals[msg.sender][operator] = approved;
    emit ApprovalForAll(msg.sender, operator, approved);
  }

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public payable {
    address prevOwner = _owner[tokenId];

    if (prevOwner != from) _revert(TransferFromIncorrectOwner.selector);

    (uint256 approvedAddressSlot, address approvedAddress) = _getApprovedSlotAndAddress(tokenId);

    // The nested ifs save around 20+ gas over a compound boolean condition.
    if (msg.sender != from)
      if (msg.sender != approvedAddress)
        if (!_operatorApprovals[from][msg.sender]) _revert(TransferCallerNotOwnerNorApproved.selector);

    // Clear approvals from the previous owner.
    assembly {
      if approvedAddress {
      // This is equivalent to `delete _tokenApprovals[tokenId]`.
        sstore(approvedAddressSlot, 0)
      }
    }

    unchecked {
      --_balance[from]; // Updates: `balance -= 1`.
      ++_balance[to]; // Updates: `balance += 1`.

      _owner[tokenId] = to;
    }

    // Mask `to` to the lower 160 bits, in case the upper bits somehow aren't clean.
    assembly {
    // Emit the `Transfer` event.
      log4(
        0, // Start of data (0, since no data).
        0, // End of data (0, since no data).
        _TRANSFER_EVENT_SIGNATURE, // Signature.
        from, // `from`.
        to, // `to`.
        tokenId // `tokenId`.
      )
    }
    if (to == address(0)) _revert(TransferToZeroAddress.selector);
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public payable {
    safeTransferFrom(from, to, tokenId, '');
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) public payable {
    transferFrom(from, to, tokenId);
    if (to.code.length != 0)
      if (!_checkContractOnERC721Received(from, to, tokenId, _data)) {
        _revert(TransferToNonERC721ReceiverImplementer.selector);
      }
  }

  function transferOwnership(address newOwner) external onlyOwner {
    owner = newOwner;
    emit OwnershipTransferred(msg.sender, newOwner);
  }

  function _setBaseURI(string calldata uri) internal virtual {
    _baseURI = uri;
  }

  function _mint(address to, uint256 tokenId) internal virtual {
    _owner[tokenId] = to;
    unchecked {
      _balance[to] += 1;
    }
    if (to == address(0)) _revert(MintToZeroAddress.selector);

    assembly {
      log4(
        0,
        0,
        _TRANSFER_EVENT_SIGNATURE, // Signature.
        0,
        to,
        tokenId
      )
    }
  }

  function _safeMint(
    address to,
    uint256 tokenId,
    bytes memory _data
  ) internal virtual {
    _mint(to, tokenId);

    unchecked {
      if (to.code.length != 0) {
        if (!_checkContractOnERC721Received(address(0), to, tokenId, _data)) {
          _revert(TransferToNonERC721ReceiverImplementer.selector);
        }
      }
    }
  }

  /**
   * @dev Equivalent to `_safeMint(to, quantity, '')`.
     */
  function _safeMint(address to, uint256 tokenId) internal virtual {
    _safeMint(to, tokenId, '');
  }

  function _revert(bytes4 errorSelector) internal pure {
    assembly {
      mstore(0x00, errorSelector)
      revert(0x00, 0x04)
    }
  }

  function _checkContractOnERC721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) private returns (bool) {
    try ERC721A__IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (
      bytes4 retval
    ) {
      return retval == ERC721A__IERC721Receiver(to).onERC721Received.selector;
    } catch (bytes memory reason) {
      if (reason.length == 0) {
        _revert(TransferToNonERC721ReceiverImplementer.selector);
      }
      assembly {
        revert(add(32, reason), mload(reason))
      }
    }
  }

  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return _owner[tokenId] != address(0);
  }

  function _getApprovedSlotAndAddress(uint256 tokenId)
  private
  view
  returns (uint256 approvedAddressSlot, address approvedAddress)
  {
    TokenApprovalRef storage tokenApproval = _tokenApprovals[tokenId];
    // The following is equivalent to `approvedAddress = _tokenApprovals[tokenId].value`.
    assembly {
      approvedAddressSlot := tokenApproval.slot
      approvedAddress := sload(approvedAddressSlot)
    }
  }
}


// File: contracts/KingdomTile.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "../interfaces/IERC721A.sol";
import "../interfaces/IERC2981.sol";
import "../libraries/ECDSA.sol";
import "../libraries/String.sol";
import "./Roles.sol";
import "./ERC721.sol";
import "./CCIPReceiver.sol";

contract KingdomTiles is Roles, ERC721, CCIPReceiver, IERC2981 {
  using Bits for bytes32;

  error BridgeToUnknownCollection();
  error NotEnoughLink();
  error UnauthorizedMint();
  error TokenIsNotLocked();
  error WithdrawFailed();

  event MessageSent(bytes32 messageId);
  event MetadataUpdate(uint256 _tokenId);
  event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
  event RoyaltiesUpdated(uint64 indexed feeBps, address indexed recipient);

  mapping(bytes32 => bool) private _sisterCollections;
  bytes32 private _royaltyConfig;

  constructor(address _router, address _link, string memory uri) CCIPReceiver(_router, _link) {
    _baseURI = uri;
    _setRole(msg.sender, 0, true);
    LinkTokenInterface(linkToken).approve(router, type(uint256).max);
    _royaltyConfig = _pack(500, address(this));
  }

  function unlockToken(uint256 tokenId, address to) external onlyRole(0) {
    if (_owner[tokenId] != address(this)) {
      revert TokenIsNotLocked();
    }
    IERC721A(address(this)).transferFrom(address(this), to, tokenId);
  }

  function setCCIPRouter(address newRouter) external onlyRole(0) {
    _setRouter(newRouter);
  }

  function setRoyaltiesConfig(uint64 feeBps, address recipient) external onlyRole(0) {
    _royaltyConfig = _pack(feeBps, recipient);
    emit RoyaltiesUpdated(feeBps, recipient);
  }

  function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
    return
      interfaceId == 0x01ffc9a7 || // ERC165.
      interfaceId == 0x80ac58cd || // ERC721.
      interfaceId == 0x5b5e139f || // ERC721Metadata
      interfaceId == 0x2a55205a || // ERC2981
      interfaceId == 0x85572ffb; // CCIPReceiver
  }

  function setBaseURI(string calldata uri) external onlyRole(0) {
    _setBaseURI(uri);
    emit BatchMetadataUpdate(0, type(uint256).max);
  }

  function setSister(uint64 chainSelector, address collection, bool status) external onlyRole(0) {
    bytes32 id = _pack(chainSelector, collection);
    _sisterCollections[id] = status;
  }

  function mint(address to, uint256 tokenId, bytes calldata signature) external payable {
    _verifySignature(tokenId, to, msg.value, signature);
    _safeMint(to, tokenId);
  }

  function bridge(uint256 tokenId, address toAddress, uint64 toChain, address toSister) external {
    if (!_isSister(toChain, toSister)) {
      revert BridgeToUnknownCollection();
    }
    transferFrom(msg.sender, address(this), tokenId);
    bytes32 data = _pack(uint64(tokenId), toAddress);
    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
      receiver: abi.encode(toSister),
      data: abi.encodePacked(data),
      tokenAmounts: new Client.EVMTokenAmount[](0),
      extraArgs: "",
      feeToken: linkToken
    });

    uint256 fee = IRouterClient(router).getFee(
      toChain,
      message
    );

    if (LinkTokenInterface(linkToken).balanceOf(address(this)) < fee) {
      revert NotEnoughLink();
    }

    bytes32 messageId;

    messageId = IRouterClient(router).ccipSend(
      toChain,
      message
    );

    emit MetadataUpdate(tokenId);
    emit MessageSent(messageId);
  }

  function _ccipReceive(
    Client.Any2EVMMessage memory message
  ) internal override {
    address sender = abi.decode(message.sender, (address));
    require(_isSister(message.sourceChainSelector, sender), "Untrusted bridge");
    (uint64 tokenId64, address bridger) = _unpack(message.data);
    uint256 tokenId = uint256(tokenId64);
    address tokenOwner = _owner[tokenId];
    if (tokenOwner == address(0)) {
      _safeMint(bridger, tokenId);
      return;
    }
    if (tokenOwner == address(this)) {
      IERC721A(address(this)).transferFrom(address(this), bridger, tokenId);
      emit MetadataUpdate(tokenId);
    }
  }

  function _isSister(uint64 chainSelector, address collection) internal view returns(bool) {
    bytes32 id = _pack(chainSelector, collection);
    return _sisterCollections[id];
  }

  function _pack(uint64 num, address addr) internal pure returns(bytes32 id) {
    assembly {
      id := or(addr, shl(160, num))
    }
  }

  function _unpack(bytes memory data) internal pure returns(uint64 num, address addr) {
    assembly {
      let b32 := mload(add(data, 32))
      addr := and(b32, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
      num := shr(160, b32)
    }
  }

  function _unpack32(bytes32 data) internal pure returns(uint64 num, address addr) {
    assembly {
      addr := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
      num := shr(160, data)
    }
  }

  function _verifySignature(uint256 tokenId, address minter, uint256 value, bytes calldata signature) internal view {
    bytes32 signedMessage = ECDSA.toEthSignedMessageHash(
      keccak256(
        abi.encodePacked(
          tokenId,
          minter,
          block.chainid,
          value
        )
      )
    );
    address signer = ECDSA.recover(signedMessage, signature);
    if (!_hasRole(signer, 1)) {
      revert UnauthorizedMint();
    }
  }

  function royaltyInfo(uint256, uint256 salePrice) external view returns (address, uint256) {
    (uint64 feeBps, address receiver) = _unpack32(_royaltyConfig);
    return (receiver, uint256(salePrice * feeBps) / 10000);
  }

  function withdrawToken(address token, address to) external onlyRole(0) {
    uint256 amount = LinkTokenInterface(token).balanceOf(address(this));
    LinkTokenInterface(linkToken).transfer(to, amount);
  }

  function withdraw() external onlyRole(0) {
    uint256 amount = address(this).balance;
    (bool success, ) = msg.sender.call{ value: amount }("");
    if (!success) {
      revert WithdrawFailed();
    }
  }
}


// File: contracts/Roles.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../libraries/Bits.sol";

contract Roles {
    using Bits for bytes32;

    error MissingRole(address user, uint256 role);
    event RoleUpdated(address indexed user, uint256 indexed role, bool indexed status);

    /**
     * @dev There is a maximum of 256 roles: each bit says if the role is on or off
     */
    mapping(address => bytes32) private _addressRoles;

    modifier onlyRole(uint8 role) {
        _checkRole(msg.sender, role);
        _;
    }

    function _hasRole(address user, uint8 role) internal view returns(bool) {
        bytes32 roles = _addressRoles[user];
        return roles.getBool(role);
    }

    function _checkRole(address user, uint8 role) internal virtual view {
        bytes32 roles = _addressRoles[user];
        if (!roles.getBool(role)) {
            revert MissingRole(user, role);
        }
    }

    function _setRole(address user, uint8 role, bool status) internal virtual {
        _addressRoles[user] = _addressRoles[user].setBool(role, status);
        emit RoleUpdated(user, role, status);
    }

    function setRole(address user, uint8 role, bool status) external virtual onlyRole(0) {
        _setRole(user, role, status);
    }

    function getRoles(address user) external view returns(bytes32) {
        return _addressRoles[user];
    }
}


// File: interfaces/IERC2981.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC2981.sol)

pragma solidity 0.8.19;

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 */
interface IERC2981 {
  /**
   * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
   * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
   */
  function royaltyInfo(
    uint256 tokenId,
    uint256 salePrice
  ) external view returns (address receiver, uint256 royaltyAmount);
}


// File: interfaces/IERC721A.sol
// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.3
// Creator: Chiru Labs

pragma solidity ^0.8.4;

/**
 * @dev Interface of ERC721A.
 */
interface IERC721A {
  /**
   * The caller must own the token or be an approved operator.
   */
  error ApprovalCallerNotOwnerNorApproved();

  /**
   * The token does not exist.
   */
  error ApprovalQueryForNonexistentToken();

  /**
   * Cannot query the balance for the zero address.
   */
  error BalanceQueryForZeroAddress();

  /**
   * Cannot mint to the zero address.
   */
  error MintToZeroAddress();

  /**
   * The quantity of tokens minted must be more than zero.
   */
  error MintZeroQuantity();

  /**
   * The token does not exist.
   */
  error OwnerQueryForNonexistentToken();

  /**
   * The caller must own the token or be an approved operator.
   */
  error TransferCallerNotOwnerNorApproved();

  /**
   * The token must be owned by `from`.
   */
  error TransferFromIncorrectOwner();

  /**
   * Cannot safely transfer to a contract that does not implement the
   * ERC721Receiver interface.
   */
  error TransferToNonERC721ReceiverImplementer();

  /**
   * Cannot transfer to the zero address.
   */
  error TransferToZeroAddress();

  /**
   * The token does not exist.
   */
  error URIQueryForNonexistentToken();

  /**
   * The `quantity` minted with ERC2309 exceeds the safety limit.
   */
  error MintERC2309QuantityExceedsLimit();

  /**
   * The `extraData` cannot be set on an unintialized ownership slot.
   */
  error OwnershipNotInitializedForExtraData();

  // =============================================================
  //                            STRUCTS
  // =============================================================

  struct TokenOwnership {
    // The address of the owner.
    address addr;
    // Stores the start time of ownership with minimal overhead for tokenomics.
    uint64 startTimestamp;
    // Whether the token has been burned.
    bool burned;
    // Arbitrary data similar to `startTimestamp` that can be set via {_extraData}.
    uint24 extraData;
  }

  // =============================================================
  //                            IERC165
  // =============================================================

  /**
   * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30000 gas.
     */
  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  // =============================================================
  //                            IERC721
  // =============================================================

  /**
   * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

  /**
   * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
  event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

  /**
   * @dev Emitted when `owner` enables or disables
     * (`approved`) `operator` to manage all of its assets.
     */
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

  /**
   * @dev Returns the number of tokens in `owner`'s account.
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
   * @dev Safely transfers `tokenId` token from `from` to `to`,
     * checking first that contract recipients are aware of the ERC721 protocol
     * to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move
     * this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes calldata data
  ) external payable;

  /**
   * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) external payable;

  /**
   * @dev Transfers `tokenId` from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom}
     * whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) external payable;

  /**
   * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
  function approve(address to, uint256 tokenId) external payable;

  /**
   * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
  function setApprovalForAll(address operator, bool _approved) external;

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
     * See {setApprovalForAll}.
     */
  function isApprovedForAll(address owner, address operator) external view returns (bool);

  // =============================================================
  //                        IERC721Metadata
  // =============================================================

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

  // =============================================================
  //                           IERC2309
  // =============================================================

  /**
   * @dev Emitted when tokens in `fromTokenId` to `toTokenId`
     * (inclusive) is transferred from `from` to `to`, as defined in the
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309) standard.
     *
     * See {_mintERC2309} for more details.
     */
  event ConsecutiveTransfer(uint256 indexed fromTokenId, uint256 toTokenId, address indexed from, address indexed to);
}


// File: libraries/Bits.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library Bits {
    /**
     * @dev unpack bit [offset] (bool)
     */
    function getBool(bytes32 p, uint8 offset) internal pure returns (bool r) {
        assembly {
            r := and(shr(offset, p), 1)
        }
    }

    /**
     * @dev unpack 8 bits [offset...offset+8] uint8
     */
    function getUint8(bytes32 p, uint8 offset) internal pure returns(uint8 r) {
        assembly {
            r := and(shr(offset, p), 0xFF)
        }
    }

    /**
     * @dev unpack 16 bits [offset...offset+16] uint16
     */
    function getUint16(bytes32 p, uint8 offset) internal pure returns(uint16 r) {
        assembly {
            r := and(shr(offset, p), 0xFFFF)
        }
    }

    /**
     * @dev unpack 32 bits [offset...offset+32] uint32
     */
    function getUint32(bytes32 p, uint8 offset) internal pure returns(uint32 r) {
        assembly {
            r := and(shr(offset, p), 0xFFFFFFFF)
        }
    }

    /**
     * @dev unpack 64 bits [offset...offset+64] uint64
     */
    function getUint64(bytes32 p, uint8 offset) internal pure returns(uint64 r) {
        assembly {
            r := and(shr(offset, p), 0xFFFFFFFFFFFFFFFF)
        }
    }

    /**
     * @dev unpack 128 bits [offset...offset+96] uint96
     */
    function getUint128(bytes32 p, uint8 offset) internal pure returns(uint128 r) {
        assembly {
            r := and(shr(offset, p), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
    }

    /**
     * @dev set bit [offset] to {value}
     */
    function setBool(
        bytes32 p,
        uint8 offset,
        bool value
    ) internal pure returns (bytes32 np) {
        assembly {
            np := or(
                and(
                    p,
                    xor(
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        shl(offset, 1)
                    )
                ),
                shl(offset, value)
            )
        }
    }

    /**
     * @dev set 8bits [offset..offset+8] to {value}
     */
    function setUint8(
        bytes8 p,
        uint8 offset,
        uint8 value
    ) internal pure returns (bytes8 np) {
        assembly {
            np := or(
                and(
                    p,
                    xor(
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        shl(offset, 0xFF)
                    )
                ),
                shl(offset, value)
            )
        }
    }


    /**
     * @dev set 16bits [offset..offset+16] to {value}
     */
    function setUint16(
        bytes32 p,
        uint8 offset,
        uint16 value
    ) internal pure returns (bytes16 np) {
        assembly {
            np := or(
                and(
                    p,
                    xor(
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        shl(offset, 0xFFFF)
                    )
                ),
                shl(offset, value)
            )
        }
    }


    /**
     * @dev set 32bits [offset..offset+32] to {value}
     */
    function setUint32(
        bytes32 p,
        uint8 offset,
        uint32 value
    ) internal pure returns (bytes32 np) {
        assembly {
            np := or(
                and(
                    p,
                    xor(
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        shl(offset, 0xFFFFFFFF)
                    )
                ),
                shl(offset, value)
            )
        }
    }

    /**
     * @dev set 64 bits [offset..offset+64] to {value}
     */
    function setUint64(
        bytes32 p,
        uint8 offset,
        uint64 value
    ) internal pure returns (bytes32 np) {
        assembly {
            np := or(
                and(
                    p,
                    xor(
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        shl(offset, 0xFFFFFFFFFFFFFFFF)
                    )
                ),
                shl(offset, value)
            )
        }
    }

    /**
     * @dev set 128 bits [offset..offset+128] to {value}
     */
    function setUint128(
        bytes32 p,
        uint8 offset,
        uint128 value
    ) internal pure returns (bytes32 np) {
        assembly {
            np := or(
                and(
                    p,
                    xor(
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        shl(offset, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                    )
                ),
                shl(offset, value)
            )
        }
    }
}


// File: libraries/ECDSA.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/cryptography/ECDSA.sol)
// Trimmed down to our specific use for Kingdom.so

pragma solidity ^0.8.0;

library ECDSA {
  error InvalidSignature();
  error InvalidSignatureLength();
  error InvalidSignatureS();
  error InvalidSignatureV();

  function _throwError(bytes4 error) private pure {
    if (uint32(error) == 0) return;
    assembly {
      mstore(0x00, error)
      revert(0x00, 0x04)
    }
  }

  function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, bytes4) {
    if (signature.length == 65) {
      bytes32 r;
      bytes32 s;
      uint8 v;
      assembly {
        r := mload(add(signature, 0x20))
        s := mload(add(signature, 0x40))
        v := byte(0, mload(add(signature, 0x60)))
      }
      return tryRecover(hash, v, r, s);
    } else if (signature.length == 64) {
      bytes32 r;
      bytes32 vs;
      assembly {
        r := mload(add(signature, 0x20))
        vs := mload(add(signature, 0x40))
      }
      return tryRecover(hash, r, vs);
    } else {
      return (address(0), InvalidSignatureLength.selector);
    }
  }

  function tryRecover(
    bytes32 hash,
    bytes32 r,
    bytes32 vs
  ) internal pure returns (address, bytes4) {
    bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    uint8 v = uint8((uint256(vs) >> 255) + 27);
    return tryRecover(hash, v, r, s);
  }

  function tryRecover(
    bytes32 hash,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) internal pure returns (address, bytes4) {
    if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
      return (address(0), InvalidSignatureS.selector);
    }
    if (v != 27 && v != 28) {
      return (address(0), InvalidSignatureV.selector);
    }

    address signer = ecrecover(hash, v, r, s);
    if (signer == address(0)) {
      return (address(0), InvalidSignature.selector);
    }

    return (signer, bytes4(uint32(0)));
  }

  function recover(bytes32 hash, bytes calldata signature) internal pure returns (address) {
    (address recovered, bytes4 error) = tryRecover(hash, signature);
    _throwError(error);
    return recovered;
  }

  function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
  }
}


// File: libraries/String.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

library String {
  /**
   * @dev Converts a uint256 to its ASCII string decimal representation.
   */
  function toString(uint256 value) internal pure returns (string memory str) {
    assembly {
    // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
    // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
    // We will need 1 word for the trailing zeros padding, 1 word for the length,
    // and 3 words for a maximum of 78 digits. Total: 5 * 0x20 = 0xa0.
      let m := add(mload(0x40), 0xa0)
    // Update the free memory pointer to allocate.
      mstore(0x40, m)
    // Assign the `str` to the end.
      str := sub(m, 0x20)
    // Zeroize the slot after the string.
      mstore(str, 0)

    // Cache the end of the memory to calculate the length later.
      let end := str

    // We write the string from rightmost digit to leftmost digit.
    // The following is essentially a do-while loop that also handles the zero case.
    // prettier-ignore
      for { let temp := value } 1 {} {
        str := sub(str, 1)
      // Write the character to the pointer.
      // The ASCII index of the '0' character is 48.
        mstore8(str, add(48, mod(temp, 10)))
      // Keep dividing `temp` until zero.
        temp := div(temp, 10)
      // prettier-ignore
        if iszero(temp) { break }
      }

      let length := sub(end, str)
    // Move the pointer 32 bytes leftwards to make room for the length.
      str := sub(str, 0x20)
    // Store the length.
      mstore(str, length)
    }
  }
}


