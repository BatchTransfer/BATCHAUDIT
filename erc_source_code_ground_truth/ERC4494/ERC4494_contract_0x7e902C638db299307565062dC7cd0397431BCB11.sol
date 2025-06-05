// SPDX-License-Identifier: WTFPL
pragma solidity 0.8.16;

import "solidity-kit/solc_0.8/ERC721/interfaces/IERC721Metadata.sol";
import "solidity-kit/solc_0.8/ERC173/interfaces/IERC173.sol";
import "solidity-kit/solc_0.8/ERC721/TokenURI/interfaces/IContractURI.sol";

import "solidity-kit/solc_0.8/ERC721/ERC4494/implementations/UsingERC4494PermitWithDynamicChainID.sol";
import "solidity-kit/solc_0.8/ERC173/implementations/Owned.sol";

import "./ERC721OwnedByAll.sol";

/// @notice What if Blockies were NFTs. That is what this collection is all about.
/// Check your wallet as every ethereum address already owns its own Blocky NFT. No minting needed.
/// You can even use Permit (EIP-4494) to approve transfers from smart contracts, via signatures.
/// Note that unless you transfer or call `emitSelfTransferEvent` / `emitMultipleSelfTransferEvents` first, indexers would not know of your token.
/// So if you want your Blocky to shows up, you can call `emitSelfTransferEvent(<your address>)` for ~ 26000 gas.
/// If you are interested in multiple blockies, you can also call `emitMultipleSelfTransferEvents` for ~ 21000 + ~ 5000 gas per blocky.
/// @title On-chain Blockies
contract Blockies is ERC721OwnedByAll, UsingERC4494PermitWithDynamicChainID, IERC721Metadata, IContractURI, Owned {
	/// @notice You attempted to claim a Blocky from an EIP-173 contract (using owner()) while the Blocky has already been claimed or transfered.
	error AlreadyClaimed();

	// ------------------------------------------------------------------------------------------------------------------
	// METADATA TEMPLATE
	// ------------------------------------------------------------------------------------------------------------------
	bytes internal constant TOKEN_URI_TEMPLATE =
		'data:application/json,{"name":"0x0000000000000000000000000000000000000000","description":"Blocky%200x0000000000000000000000000000000000000000%20Generated%20On-Chain","image":"';

	// 31 start position for name
	// 41 = length of address - 1
	uint256 internal constant ADDRESS_NAME_POS = 31 + 41; // 72

	// 90 = start position for descripton
	// 9 = Blocky%20
	// 41 = length of address - 1
	uint256 internal constant ADDRESS_NAME_2_POS = 90 + 9 + 41; // 140

	bytes internal constant SVG_TEMPLATE =
		"data:image/svg+xml,<svg%20xmlns='http://www.w3.org/2000/svg'%20shape-rendering='crispEdges'%20width='512'%20height='512'><g%20transform='scale(64)'><path%20fill='hsl(000,000%,000%)'%20d='M0,0h8v8h-8z'/><path%20fill='hsl(000,000%,000%)'%20d='M0,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1z'/><path%20fill='hsl(000,000%,000%)'%20d='M0,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm-8,1m1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1zm1,0h1v0h-1z'/></g></svg>";

	uint256 internal constant COLOR_BG_POS = 168;

	uint256 internal constant COLOR_1_POS = 222;
	uint256 internal constant PATH_1_POS = COLOR_1_POS + 18;

	uint256 internal constant COLOR_2_POS = 1067;
	uint256 internal constant PATH_2_POS = COLOR_2_POS + 18;

	// ------------------------------------------------------------------------------------------------------------------
	// DATA AND TYPES
	// ------------------------------------------------------------------------------------------------------------------
	bytes internal constant hexAlphabet = "0123456789abcdef";

	struct Seed {
		int32 s0;
		int32 s1;
		int32 s2;
		int32 s3;
	}

	// ------------------------------------------------------------------------------------------------------------------
	// CONSTRUCTOR
	// ------------------------------------------------------------------------------------------------------------------

	constructor(address contractOwner)
		UsingERC712WithDynamicChainID(address(0))
		ERC721OwnedByAll(contractOwner)
		Owned(contractOwner, 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e) // ENS Registry
	{}

	// ------------------------------------------------------------------------------------------------------------------
	// EXTERNAL INTERFACE
	// ------------------------------------------------------------------------------------------------------------------

	/// @inheritdoc IERC721Metadata
	function name() public pure override(IERC721Metadata, Named) returns (string memory) {
		return "Blockies";
	}

	/// @inheritdoc IERC721Metadata
	function symbol() external pure returns (string memory) {
		return "BLOCKY";
	}

	/// @inheritdoc IERC721Metadata
	function tokenURI(uint256 tokenID) external pure override returns (string memory str) {
		bytes memory metadata = TOKEN_URI_TEMPLATE;
		_writeUintAsHex(metadata, ADDRESS_NAME_POS, tokenID);
		_writeUintAsHex(metadata, ADDRESS_NAME_2_POS, tokenID);

		return string(bytes.concat(metadata, _renderSVG(tokenID), '"}'));
	}

	/// @inheritdoc IContractURI
	function contractURI() external view returns (string memory) {
		return
			string(
				bytes.concat(
					'data:application/json,{"name":"On-chain%20Blockies","description":"The%20ubiquitous%20Blockies,%20but%20fully%20generated%20on-chain.%20Each%20Ethereum%20address%20owns%20its%20own%20unique%20Blocky%20NFT.","image":"',
					_renderSVG(uint160(address(this))),
					'"}'
				)
			);
	}

	/// @inheritdoc IERC165
	function supportsInterface(bytes4 interfaceID)
		public
		view
		override(BasicERC721, UsingERC4494Permit, IERC165)
		returns (bool)
	{
		return BasicERC721.supportsInterface(interfaceID) || UsingERC4494Permit.supportsInterface(interfaceID);
	}

	/// @notice emit a Transfer event where from == to so that indexers can scan the token.
	///   This can be called by anyone at any time and does not change state.
	///   As such it keeps the token's approval state and will re-emit an Approval event to indicate that if needed.
	/// @param tokenID token to emit the event for.
	function emitSelfTransferEvent(uint256 tokenID) public {
		(address currentowner, bool operatorEnabled) = _ownerAndOperatorEnabledOf(tokenID);
		if (currentowner == address(0)) {
			revert NonExistentToken(tokenID);
		}

		emit Transfer(currentowner, currentowner, tokenID);

		if (operatorEnabled) {
			// we reemit the Approval as Transfer event indicate a reset, as per ERC721 spec
			emit Approval(currentowner, _operators[tokenID], tokenID);
		}
	}

	/// @notice emit a Transfer event where from == to for each tokenID provided so that indexers can scan them.
	///   This can be called by anyone at any time and does not change state.
	///   As such it keeps each token's approval state and will re-emit an Approval event to indicate that if needed.
	/// @param tokenIDs list of token to emit the event for.
	function emitMultipleSelfTransferEvents(uint256[] calldata tokenIDs) external {
		for (uint256 i = 0; i < tokenIDs.length; i++) {
			emitSelfTransferEvent(tokenIDs[i]);
		}
	}

	/// @notice claim ownership of the blocky owned by a contract.
	///   Will only work  if you are the owner of that contract (EIP-173).
	/// @param tokenID blocky address to claim
	function claimOwnership(uint256 tokenID) external {
		(address currentowner, uint256 nonce) = _ownerAndNonceOf(tokenID);
		if (currentowner == address(0)) {
			revert NonExistentToken(tokenID);
		}

		bool registered = (nonce >> 24) != 0;
		if (registered) {
			revert AlreadyClaimed();
		}

		if (currentowner.code.length == 0 || IERC173(currentowner).owner() != msg.sender) {
			revert NotAuthorized();
		}

		_transferFrom(currentowner, msg.sender, tokenID, false);
	}

	// ------------------------------------------------------------------------------------------------------------------
	// INTERNALS
	// ------------------------------------------------------------------------------------------------------------------

	function _writeUint(
		bytes memory data,
		uint256 endPos,
		uint256 num
	) internal pure {
		while (num != 0) {
			data[endPos--] = bytes1(uint8(48 + (num % 10)));
			num /= 10;
		}
	}

	function _seedrand(bytes memory seed) internal pure returns (Seed memory randseed) {
		unchecked {
			for (uint256 i = 0; i < seed.length; i++) {
				uint8 j = uint8(i % 4);
				if (j == 0) {
					randseed.s0 = (randseed.s0 << 5) - randseed.s0 + int32(uint32(uint8(seed[i])));
				} else if (j == 1) {
					randseed.s1 = (randseed.s1 << 5) - randseed.s1 + int32(uint32(uint8(seed[i])));
				} else if (j == 2) {
					randseed.s2 = (randseed.s2 << 5) - randseed.s2 + int32(uint32(uint8(seed[i])));
				} else if (j == 3) {
					randseed.s3 = (randseed.s3 << 5) - randseed.s3 + int32(uint32(uint8(seed[i])));
				}
			}
		}
	}

	function _rand(Seed memory randseed) internal pure returns (uint256 rnd) {
		unchecked {
			int32 t = randseed.s0 ^ int32(randseed.s0 << 11);
			randseed.s0 = randseed.s1;
			randseed.s1 = randseed.s2;
			randseed.s2 = randseed.s3;
			randseed.s3 = randseed.s3 ^ (randseed.s3 >> 19) ^ t ^ (t >> 8);
			rnd = uint32(randseed.s3);
		}
	}

	function _randhsl(Seed memory randseed)
		internal
		pure
		returns (
			uint16 hue,
			uint8 saturation,
			uint8 lightness
		)
	{
		unchecked {
			// saturation is the whole color spectrum
			hue = uint16(((_rand(randseed) * 360) / 2147483648));
			// saturation goes from 40 to 100, it avoids greyish colors
			saturation = uint8((_rand(randseed) * 60) / 2147483648 + 40);
			// lightness can be anything from 0 to 100, but probabilities are a bell curve around 50%
			lightness = uint8(
				((_rand(randseed) + _rand(randseed) + _rand(randseed) + _rand(randseed)) * 25) / 2147483648
			);
		}
	}

	function _setColor(
		bytes memory metadata,
		Seed memory randseed,
		uint8 i
	) internal pure {
		(uint16 hue, uint8 saturation, uint8 lightness) = _randhsl(randseed);
		uint256 pos = COLOR_BG_POS;
		if (i == 1) {
			pos = COLOR_1_POS;
		} else if (i == 2) {
			pos = COLOR_2_POS;
		}
		_writeUint(metadata, pos + 0, hue);
		_writeUint(metadata, pos + 4, saturation);
		_writeUint(metadata, pos + 9, lightness);
	}

	function _writeUintAsHex(
		bytes memory data,
		uint256 endPos,
		uint256 num
	) internal pure {
		while (num != 0) {
			data[endPos--] = bytes1(hexAlphabet[num % 16]);
			num /= 16;
		}
	}

	function _addressToString(address who) internal pure returns (string memory) {
		bytes memory addr = "0x0000000000000000000000000000000000000000";
		_writeUintAsHex(addr, 41, uint160(who));
		return string(addr);
	}

	function _setPixel(
		bytes memory metadata,
		uint256 x,
		uint256 y,
		uint8 color
	) internal pure {
		uint256 pathPos = 0;
		if (color == 0) {
			return;
		}
		if (color == 1) {
			pathPos = PATH_1_POS;
		} else if (color == 2) {
			pathPos = PATH_2_POS;
		}
		uint256 pos = pathPos + y * 5 + (y * 8 + x) * 12 + 8;
		metadata[pos] = "1";
	}

	function _renderSVG(uint256 tokenID) internal pure returns (bytes memory) {
		bytes memory svg = SVG_TEMPLATE;

		Seed memory randseed = _seedrand(bytes(_addressToString(address(uint160(tokenID)))));

		_setColor(svg, randseed, 1);
		_setColor(svg, randseed, 0);
		_setColor(svg, randseed, 2);

		for (uint256 y = 0; y < 8; y++) {
			uint8 p0 = uint8((_rand(randseed) * 23) / 2147483648 / 10);
			uint8 p1 = uint8((_rand(randseed) * 23) / 2147483648 / 10);
			uint8 p2 = uint8((_rand(randseed) * 23) / 2147483648 / 10);
			uint8 p3 = uint8((_rand(randseed) * 23) / 2147483648 / 10);

			_setPixel(svg, 0, y, p0);
			_setPixel(svg, 1, y, p1);
			_setPixel(svg, 2, y, p2);
			_setPixel(svg, 3, y, p3);
			_setPixel(svg, 4, y, p3);
			_setPixel(svg, 5, y, p2);
			_setPixel(svg, 6, y, p1);
			_setPixel(svg, 7, y, p0);
		}

		return svg;
	}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC165.sol";

abstract contract UsingERC165Internal is IERC165 {
	/// @inheritdoc IERC165
	function supportsInterface(bytes4) public view virtual returns (bool) {
		return false;
	}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC165 {
	/// @notice Query if a contract implements an interface
	/// @param interfaceID The interface identifier, as specified in ERC-165
	/// @dev Interface identification is specified in ERC-165. This function
	///  uses less than 30,000 gas.
	/// @return `true` if the contract implements `interfaceID` and
	///  `interfaceID` is not 0xffffffff, `false` otherwise
	function supportsInterface(bytes4 interfaceID) external view returns (bool);
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../utils/GenericErrors.sol";

interface IERC173 {
	/// @notice This emits when ownership of the contract changes.
	/// @param previousOwner the previous owner
	/// @param newOwner the new owner
	event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

	/// @notice Get the address of the owner
	/// @return The address of the owner.
	function owner() external view returns (address);

	/// @notice Set the address of the new owner of the contract
	/// @dev Set newOwner to address(0) to renounce any ownership.
	/// @param newOwner The address of the new owner of the contract
	function transferOwnership(address newOwner) external;
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
	/// @notice trigger when tokens are transferred, including zero value transfers.
	/// @param from the account the tokens are sent from
	/// @param to the account the tokens are sent to
	/// @param value number of tokens sent
	event Transfer(address indexed from, address indexed to, uint256 value);

	/// @notice trigger on approval amount being set.
	///   Note that Transfer events need to be considered to compute the current allowance.
	/// @param owner the account approving the `spender`
	/// @param spender the account allowed to spend
	/// @param value the amount granted
	event Approval(address indexed owner, address indexed spender, uint256 value);

	/// @notice The msg value do not match the expected value
	/// @param provided msg.value amount provided
	/// @param expected value expected
	error InvalidMsgValue(uint256 provided, uint256 expected);
	/// @notice The total amount provided do not match the expected value
	/// @param provided msg.value amount provided
	/// @param expected value expected
	error InvalidTotalAmount(uint256 provided, uint256 expected);
	/// @notice An invalid address is specified (for example: zero address)
	/// @param addr invalid address
	error InvalidAddress(address addr);
	/// @notice the amount requested exceed the allowance
	/// @param currentAllowance the current allowance
	/// @param expected amount expected
	error NotAuthorizedAllowance(uint256 currentAllowance, uint256 expected);
	/// @notice the amount requested exceed the balance
	/// @param currentBalance the current balance
	/// @param expected amount expected
	error NotEnoughTokens(uint256 currentBalance, uint256 expected);

	/// @notice Returns the total token supply.
	function totalSupply() external view returns (uint256);

	/// @notice Returns the number of decimals the token uses.
	function decimals() external view returns (uint8);

	/// @notice Returns the symbol of the token.
	function symbol() external view returns (string memory);

	/// @notice Returns the name of the token.
	function name() external view returns (string memory);

	/// @notice Returns the account balance of another account with address `owner`.
	function balanceOf(address owner) external view returns (uint256);

	/// @notice Transfers `amount` of tokens to address `to`.
	function transfer(address to, uint256 amount) external returns (bool);

	/// @notice Returns the amount which `spender` is still allowed to withdraw from `owner`.
	function allowance(address owner, address spender) external view returns (uint256);

	/// @notice Allows `spender` to withdraw from your account multiple times, up to `amount`.
	function approve(address spender, uint256 amount) external returns (bool);

	/// @notice Transfers `amount` tokens from address `from` to address `to`.
	function transferFrom(
		address from,
		address to,
		uint256 amount
	) external returns (bool);
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC5267.sol";

abstract contract UsingERC712 is IERC5267 {}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingERC712.sol";
import "./Named.sol";

abstract contract UsingERC712WithDynamicChainID is UsingERC712, Named {
	uint256 private immutable _deploymentChainID;
	bytes32 private immutable _deploymentDomainSeparator;

	constructor(address verifyingContract) {
		uint256 chainID;
		assembly {
			chainID := chainid()
		}

		_deploymentChainID = chainID;
		_deploymentDomainSeparator = _calculateDomainSeparator(
			chainID,
			verifyingContract == address(0) ? address(this) : verifyingContract
		);
	}

	/// @inheritdoc IERC5267
	function eip712Domain()
		external
		view
		virtual
		override
		returns (
			bytes1 fields,
			string memory name,
			string memory version,
			uint256 chainID,
			address verifyingContract,
			bytes32 salt,
			uint256[] memory extensions
		)
	{
		fields = 0x0D;
		name = _name();
		version = "";
		assembly {
			chainID := chainid()
		}
		verifyingContract = address(this);
		salt = 0;
		extensions = new uint256[](0);
	}

	// ------------------------------------------------------------------------------------------------------------------
	// INTERNALS
	// ------------------------------------------------------------------------------------------------------------------

	// need to ensure we can use return value "name" in `eip712Domain`
	function _name() internal view returns (string memory) {
		return name();
	}

	function _currentDomainSeparator() internal view returns (bytes32) {
		uint256 chainID;
		assembly {
			chainID := chainid()
		}

		// in case a fork happen, to support the chain that had to change its chainID, we compute the domain operator
		return
			chainID == _deploymentChainID
				? _deploymentDomainSeparator
				: _calculateDomainSeparator(chainID, address(this));
	}

	/// @dev Calculate the Domain Separator used to compute ERC712 hash
	function _calculateDomainSeparator(uint256 chainID, address verifyingContract) private view returns (bytes32) {
		return
			keccak256(
				abi.encode(
					keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
					keccak256(bytes(name())),
					chainID,
					verifyingContract
				)
			);
	}
}// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC5267 {
	/// @notice The return values of this function MUST describe the domain separator that is used for verification of EIP-712 signatures in the contract. They describe both the form of the EIP712Domain struct (i.e., which of the optional fields and extensions are present) and the value of each field, as follows.
	/// @return fields A bit map where bit i is set to 1 if and only if domain field i is present (0 ≤ i ≤ 4). Bits are read from least significant to most significant, and fields are indexed in the order that is specified by EIP-712, identical to the order in which they are listed in the function type.
	/// @return name EIP-712 name
	/// @return version EIP-712 version
	/// @return chainID EIP-712 chainID
	/// @return verifyingContract EIP-712 name verifyingContract
	/// @return salt EIP-712 salt
	/// @return extensions A list of EIP numbers that specify additional fields in the domain. The method to obtain the value for each of these additional fields and any conditions for inclusion are expected to be specified in the respective EIP. The value of fields does not affect their inclusion.
	function eip712Domain()
		external
		view
		returns (
			bytes1 fields,
			string memory name,
			string memory version,
			uint256 chainID,
			address verifyingContract,
			bytes32 salt,
			uint256[] memory extensions
		);
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../implementations/ImplementingERC721Internal.sol";
import "../../../ERC165/implementations/UsingERC165Internal.sol";
import "../interfaces/IERC4494.sol";
import "../../../ERC712/implementations/UsingERC712.sol";
import "../../../ERC712/implementations/ImplementingExternalDomainSeparator.sol";
import "../../../ERC721/interfaces/IERC721.sol";

import "../../..//openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "../../../openzeppelin/contracts/utils/Address.sol";

abstract contract UsingERC4494Permit is
	IERC4494,
	IERC4494PermitForAll,
	IERC4494Alternative,
	ImplementingERC721Internal,
	UsingERC165Internal,
	ImplementingExternalDomainSeparator,
	UsingERC712
{
	bytes32 internal constant PERMIT_TYPEHASH =
		keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
	bytes32 internal constant PERMIT_FOR_ALL_TYPEHASH =
		keccak256("PermitForAll(address owner,address spender,uint256 nonce,uint256 deadline)");

	mapping(address => uint256) internal _userNonces;

	/// @inheritdoc IERC4494PermitForAll
	function nonces(address account) external view virtual returns (uint256 nonce) {
		return _userNonces[account];
	}

	/// @inheritdoc IERC4494
	function nonces(uint256 tokenID) public view virtual returns (uint256 nonce) {
		(address owner, uint256 currentNonce) = _ownerAndNonceOf(tokenID);
		if (owner == address(0)) {
			revert IERC721.NonExistentToken(tokenID);
		}
		return currentNonce;
	}

	/// @inheritdoc IERC4494Alternative
	function tokenNonces(uint256 tokenID) external view returns (uint256 nonce) {
		return nonces(tokenID);
	}

	/// @inheritdoc IERC4494
	function permit(
		address spender,
		uint256 tokenID,
		uint256 deadline,
		bytes memory sig
	) external override(IERC4494, IERC4494Alternative) {
		if (block.timestamp > deadline) {
			revert DeadlineOver(block.timestamp, deadline);
		}

		(address owner, uint256 nonce) = _ownerAndNonceOf(tokenID);
		if (owner == address(0)) {
			revert IERC721.NonExistentToken(tokenID);
		}

		_requireValidPermit(owner, spender, tokenID, deadline, nonce, sig);

		_approveFor(owner, nonce, spender, tokenID);
	}

	/// @inheritdoc IERC4494PermitForAll
	function permitForAll(
		address owner,
		address spender,
		uint256 deadline,
		bytes memory sig
	) external {
		if (block.timestamp > deadline) {
			revert DeadlineOver(block.timestamp, deadline);
		}

		_requireValidPermitForAll(owner, spender, deadline, _userNonces[owner]++, sig);

		_setApprovalForAll(owner, spender, true);
	}

	/// @inheritdoc IERC165
	function supportsInterface(bytes4 interfaceID)
		public
		view
		virtual
		override(IERC165, UsingERC165Internal)
		returns (bool)
	{
		return
			super.supportsInterface(interfaceID) ||
			interfaceID == type(IERC4494).interfaceId ||
			interfaceID == type(IERC4494Alternative).interfaceId;
	}

	/// @inheritdoc ImplementingExternalDomainSeparator
	function DOMAIN_SEPARATOR()
		public
		view
		virtual
		override(IERC4494, IERC4494PermitForAll, IERC4494Alternative, ImplementingExternalDomainSeparator)
		returns (bytes32);

	// ------------------------------------------------------------------------------------------------------------------
	// INTERNALS
	// ------------------------------------------------------------------------------------------------------------------

	function _requireValidPermit(
		address signer,
		address spender,
		uint256 tokenID,
		uint256 deadline,
		uint256 nonce,
		bytes memory sig
	) internal view {
		bytes32 digest = keccak256(
			abi.encodePacked(
				"\x19\x01",
				DOMAIN_SEPARATOR(),
				keccak256(abi.encode(PERMIT_TYPEHASH, spender, tokenID, nonce, deadline))
			)
		);
		if (!Openzeppelin_SignatureChecker.isValidSignatureNow(signer, digest, sig)) {
			revert InvalidSignature();
		}
	}

	function _requireValidPermitForAll(
		address owner,
		address spender,
		uint256 deadline,
		uint256 nonce,
		bytes memory sig
	) internal view {
		bytes32 digest = keccak256(
			abi.encodePacked(
				"\x19\x01",
				DOMAIN_SEPARATOR(),
				keccak256(abi.encode(PERMIT_FOR_ALL_TYPEHASH, owner, spender, nonce, deadline))
			)
		);
		if (!Openzeppelin_SignatureChecker.isValidSignatureNow(owner, digest, sig)) {
			revert InvalidSignature();
		}
	}
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingERC4494Permit.sol";
import "../../../ERC712/implementations/UsingERC712WithDynamicChainID.sol";

abstract contract UsingERC4494PermitWithDynamicChainID is UsingERC4494Permit, UsingERC712WithDynamicChainID {
	/// @inheritdoc ImplementingExternalDomainSeparator
	function DOMAIN_SEPARATOR() public view virtual override returns (bytes32) {
		return _currentDomainSeparator();
	}
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../ERC165/interfaces/IERC165.sol";

interface IERC4494 is IERC165 {
	/// @notice The permit has expired
	/// @param currentTime time at which the error happen
	/// @param deadline the deadline
	error DeadlineOver(uint256 currentTime, uint256 deadline);
	/// @notice The signature do not match the expected signer
	error InvalidSignature();

	/// @notice EIP-712 Domain separator hash
	function DOMAIN_SEPARATOR() external view returns (bytes32);

	/// @notice Allows to retrieve current nonce for token
	/// @param tokenID token id
	/// @return nonce token nonce
	function nonces(uint256 tokenID) external view returns (uint256 nonce);

	/// @notice function to be called by anyone to approve `spender` using a Permit signature
	/// @dev Anyone can call this to approve `spender`, even a third-party
	/// @param spender the actor to approve
	/// @param tokenID the token id
	/// @param deadline the deadline for the permit to be used
	/// @param signature permit
	function permit(
		address spender,
		uint256 tokenID,
		uint256 deadline,
		bytes memory signature
	) external;
}

interface IERC4494PermitForAll {
	/// @notice EIP-712 Domain separator hash
	function DOMAIN_SEPARATOR() external view returns (bytes32);

	/// @notice Allows to retrieve current nonce for the account
	/// @param account account to query
	/// @return nonce account's nonce
	function nonces(address account) external view returns (uint256 nonce);

	/// @notice function to be called by anyone to approve `spender` using a Permit signature
	/// @dev Anyone can call this to approve `spender`, even a third-party
	/// @param signer the one giving permission
	/// @param spender the actor to approve
	/// @param deadline the deadline for the permit to be used
	/// @param signature permit
	function permitForAll(
		address signer,
		address spender,
		uint256 deadline,
		bytes memory signature
	) external;
}

interface IERC4494Alternative is IERC165 {
	/// @notice EIP-712 Domain separator hash
	function DOMAIN_SEPARATOR() external view returns (bytes32);

	/// @notice Allows to retrieve current nonce for token
	/// @param tokenID token id
	/// @return nonce token nonce
	function tokenNonces(uint256 tokenID) external view returns (uint256 nonce);

	/// @notice function to be called by anyone to approve `spender` using a Permit signature
	/// @dev Anyone can call this to approve `spender`, even a third-party
	/// @param spender the actor to approve
	/// @param tokenID the token id
	/// @param deadline the deadline for the permit to be used
	/// @param signature permit
	function permit(
		address spender,
		uint256 tokenID,
		uint256 deadline,
		bytes memory signature
	) external;
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC721Receiver.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC721WithBlocknumber.sol";
import "./ImplementingERC721Internal.sol";

import "../../openzeppelin/contracts/utils/Address.sol";

abstract contract BasicERC721 is IERC721, IERC721WithBlocknumber, ImplementingERC721Internal {
	using Openzeppelin_Address for address;

	bytes4 internal constant ERC721_RECEIVED = 0x150b7a02;

	uint256 internal constant OPERATOR_FLAG = 0x8000000000000000000000000000000000000000000000000000000000000000;

	mapping(uint256 => uint256) internal _owners;
	mapping(address => uint256) internal _balances;
	mapping(address => mapping(address => bool)) internal _operatorsForAll;
	mapping(uint256 => address) internal _operators;

	/// @inheritdoc IERC721
	function approve(address operator, uint256 tokenID) external override {
		(address owner, uint256 nonce) = _ownerAndNonceOf(tokenID);
		if (owner == address(0)) {
			revert NonExistentToken(tokenID);
		}
		if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
			revert NotAuthorized();
		}
		_approveFor(owner, nonce, operator, tokenID);
	}

	/// @inheritdoc IERC721
	function transferFrom(
		address from,
		address to,
		uint256 tokenID
	) external override {
		(address owner, uint256 nonce, bool operatorEnabled) = _ownerNonceAndOperatorEnabledOf(tokenID);
		if (owner == address(0)) {
			revert NonExistentToken(tokenID);
		}
		if (from != owner) {
			revert NotOwner(from, owner);
		}
		if (to == address(0) || to == address(this)) {
			revert InvalidAddress(to);
		}
		if (msg.sender != from) {
			if (!(operatorEnabled && _operators[tokenID] == msg.sender) && !isApprovedForAll(from, msg.sender)) {
				revert NotAuthorized();
			}
		}
		_transferFrom(from, to, tokenID, (nonce >> 24) != 0);
	}

	/// @inheritdoc IERC721
	function safeTransferFrom(
		address from,
		address to,
		uint256 tokenID
	) external override {
		safeTransferFrom(from, to, tokenID, "");
	}

	/// @inheritdoc IERC721
	function setApprovalForAll(address operator, bool approved) external override {
		_setApprovalForAll(msg.sender, operator, approved);
	}

	/// @inheritdoc IERC721
	function balanceOf(address owner) public view virtual override returns (uint256 balance) {
		if (owner == address(0)) {
			revert InvalidAddress(owner);
		}
		balance = _balances[owner];
	}

	/// @inheritdoc IERC721
	function ownerOf(uint256 tokenID) external view override returns (address owner) {
		owner = _ownerOf(tokenID);
		if (owner == address(0)) {
			revert NonExistentToken(tokenID);
		}
	}

	/// @inheritdoc IERC721
	function getApproved(uint256 tokenID) external view override returns (address operator) {
		(address owner, bool operatorEnabled) = _ownerAndOperatorEnabledOf(tokenID);
		if (owner == address(0)) {
			revert NonExistentToken(tokenID);
		}
		if (operatorEnabled) {
			return _operators[tokenID];
		} else {
			return address(0);
		}
	}

	/// @inheritdoc IERC721
	function isApprovedForAll(address owner, address operator) public view virtual override returns (bool isOperator) {
		return _operatorsForAll[owner][operator];
	}

	/// @inheritdoc IERC721
	function safeTransferFrom(
		address from,
		address to,
		uint256 tokenID,
		bytes memory data
	) public override {
		(address owner, uint256 nonce, bool operatorEnabled) = _ownerNonceAndOperatorEnabledOf(tokenID);
		if (owner == address(0)) {
			revert NonExistentToken(tokenID);
		}
		if (owner != from) {
			revert NotOwner(from, owner);
		}

		if (to == address(0) || to == address(this)) {
			revert InvalidAddress(to);
		}

		if (msg.sender != from) {
			if (!(operatorEnabled && _operators[tokenID] == msg.sender) && !isApprovedForAll(from, msg.sender)) {
				revert NotAuthorized();
			}
		}
		_safeTransferFrom(from, to, tokenID, (nonce >> 24) != 0, data);
	}

	/// @inheritdoc IERC165
	function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
		/// 0x01ffc9a7 is ERC165.
		/// 0x80ac58cd is ERC721
		/// 0x5b5e139f is for ERC721 metadata
		return interfaceID == 0x01ffc9a7 || interfaceID == 0x80ac58cd || interfaceID == 0x5b5e139f;
	}

	/// @inheritdoc IERC721WithBlocknumber
	function ownerAndLastTransferBlockNumberOf(uint256 tokenID)
		external
		view
		override
		returns (address owner, uint256 blockNumber)
	{
		(address currentOwner, uint256 nonce) = _ownerAndNonceOf(tokenID);
		owner = currentOwner;
		blockNumber = (nonce >> 24);
	}

	/// @inheritdoc IERC721WithBlocknumber
	function ownerAndLastTransferBlockNumberList(uint256[] calldata tokenIDs)
		external
		view
		virtual
		returns (OwnerData[] memory ownersData)
	{
		ownersData = new OwnerData[](tokenIDs.length);
		for (uint256 i = 0; i < tokenIDs.length; i++) {
			uint256 data = _owners[tokenIDs[i]];
			ownersData[i].owner = address(uint160(data));
			ownersData[i].lastTransferBlockNumber = (data >> 184) & 0xFFFFFFFFFFFFFFFF;
		}
	}

	// ------------------------------------------------------------------------------------------------------------------
	// INTERNALS
	// ------------------------------------------------------------------------------------------------------------------

	function _safeMint(address to, uint256 tokenID) internal {
		_safeTransferFrom(address(0), to, tokenID, false, "");
	}

	function _safeTransferFrom(
		address from,
		address to,
		uint256 tokenID,
		bool registered,
		bytes memory data
	) internal {
		_transferFrom(from, to, tokenID, registered);
		if (to.isContract()) {
			if (!_checkOnERC721Received(msg.sender, from, to, tokenID, data)) {
				revert TransferRejected();
			}
		}
	}

	function _transferFrom(
		address from,
		address to,
		uint256 tokenID,
		bool registered
	) internal virtual {
		unchecked {
			_balances[to]++;
			if (registered) {
				_balances[from]--;
			}
		}

		// We encode the blockNumber in the token nonce. We can then use it for count voting.
		_owners[tokenID] = (block.number << 184) | uint256(uint160(to));
		emit Transfer(from, to, tokenID);
	}

	/// @dev See approve.
	function _approveFor(
		address owner,
		uint256 nonce,
		address operator,
		uint256 tokenID
	) internal override {
		uint256 blockNumber = nonce >> 24;
		uint256 newNonce = nonce + 1;
		if (newNonce >> 24 != blockNumber) {
			revert NonceOverflow();
		}
		if (operator == address(0)) {
			_owners[tokenID] = (newNonce << 160) | uint256(uint160(owner));
		} else {
			_owners[tokenID] = OPERATOR_FLAG | ((newNonce << 160) | uint256(uint160(owner)));
			_operators[tokenID] = operator;
		}
		emit Approval(owner, operator, tokenID);
	}

	/// @dev See setApprovalForAll.
	function _setApprovalForAll(
		address sender,
		address operator,
		bool approved
	) internal override {
		_operatorsForAll[sender][operator] = approved;

		emit ApprovalForAll(sender, operator, approved);
	}

	/// @dev Check if receiving contract accepts erc721 transfers.
	/// @param operator The address of the operator.
	/// @param from The from address, may be different from msg.sender.
	/// @param to The adddress we want to transfer to.
	/// @param tokenID The id of the token we would like to transfer.
	/// @param data Any additional data to send with the transfer.
	/// @return Whether the expected value of 0x150b7a02 is returned.
	function _checkOnERC721Received(
		address operator,
		address from,
		address to,
		uint256 tokenID,
		bytes memory data
	) internal returns (bool) {
		bytes4 retval = IERC721Receiver(to).onERC721Received(operator, from, tokenID, data);
		return (retval == ERC721_RECEIVED);
	}

	/// @dev Get the owner of a token.
	/// @param tokenID The token to query.
	function _ownerOf(uint256 tokenID) internal view virtual returns (address owner) {
		return address(uint160(_owners[tokenID]));
	}

	/// @dev Get the owner and operatorEnabled status of a token.
	/// @param tokenID The token to query.
	/// @return owner The owner of the token.
	/// @return operatorEnabled Whether or not operators are enabled for this token.
	function _ownerAndOperatorEnabledOf(uint256 tokenID)
		internal
		view
		virtual
		returns (address owner, bool operatorEnabled)
	{
		uint256 data = _owners[tokenID];
		owner = address(uint160(data));
		operatorEnabled = (data & OPERATOR_FLAG) == OPERATOR_FLAG;
	}

	/// @dev Get the owner and the permit nonce of a token.
	/// @param tokenID The token to query.
	/// @return owner The owner of the token.
	/// @return nonce the nonce for permit (also incluse the blocknumer in the 64 higer bits (88 bits in total))
	function _ownerAndNonceOf(uint256 tokenID) internal view virtual override returns (address owner, uint256 nonce) {
		uint256 data = _owners[tokenID];
		owner = address(uint160(data));
		nonce = (data >> 160) & 0xFFFFFFFFFFFFFFFFFFFFFF;
	}

	// @dev Get the owner, the permit nonce of a token and operatorEnabled status of a token.
	/// @param tokenID The token to query.
	/// @return owner The owner of the token.
	/// @return nonce the nonce for permit (also incluse the blocknumer in the 64 higer bits (88 bits in total))
	/// @return operatorEnabled Whether or not operators are enabled for this token.
	function _ownerNonceAndOperatorEnabledOf(uint256 tokenID)
		internal
		view
		virtual
		returns (
			address owner,
			uint256 nonce,
			bool operatorEnabled
		)
	{
		uint256 data = _owners[tokenID];
		owner = address(uint160(data));
		operatorEnabled = (data & OPERATOR_FLAG) == OPERATOR_FLAG;
		nonce = (data >> 160) & 0xFFFFFFFFFFFFFFFFFFFFFF;
	}
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../ERC165/interfaces/IERC165.sol";
import "../../utils/GenericErrors.sol";

interface IERC721Supply {
	function totalSupply() external view returns (uint256);
}

interface IERC721 is IERC165 {
	/// @notice Triggered when a token is transferred
	/// @param from the account the token is sent from
	/// @param to the account the token is sent to
	/// @param tokenID id of the token being sent
	event Transfer(address indexed from, address indexed to, uint256 indexed tokenID);

	/// @notice Triggered when a token is approved to be sent by another account
	///  Note tat the approval get reset when a Transfer event for that same token is emitted.
	/// @param owner current owner of the token
	/// @param approved account who can know transfer on the owner's behalf
	/// @param tokenID id of the token being approved
	event Approval(address indexed owner, address indexed approved, uint256 indexed tokenID);

	/// @notice Triggered when an account approve or disaprove another to transfer on its behalf
	/// @param owner the account granting rights over all of its token
	/// @param operator account who can know transfer on the owner's behalf
	/// @param approved whether it is approved or not
	event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

	/// @notice The token does not exist
	/// @param tokenID id of the expected token
	error NonExistentToken(uint256 tokenID);
	/// @notice The address from which the token is sent is not the current owner
	/// @param provided the address expected to be the current owner
	/// @param currentOwner the current owner
	error NotOwner(address provided, address currentOwner);
	/// @notice An invalid address is specified (for example: zero address)
	/// @param addr invalid address
	error InvalidAddress(address addr);
	/// @notice The Transfer was rejected by the destination
	error TransferRejected();
	/// @notice The Nonce overflowed, make a transfer to self to allow new nonces.
	error NonceOverflow();

	/// @notice Get the number of tokens owned by an address.
	/// @param owner The address to look for.
	/// @return balance The number of tokens owned by the address.
	function balanceOf(address owner) external view returns (uint256 balance);

	/// @notice Get the owner of a token.
	/// @param tokenID The id of the token.
	/// @return owner The address of the token owner.
	function ownerOf(uint256 tokenID) external view returns (address owner);

	/// @notice Transfer a token between 2 addresses letting the receiver knows of the transfer.
	/// @param from The sender of the token.
	/// @param to The recipient of the token.
	/// @param tokenID The id of the token.
	/// @param data Additional data.
	function safeTransferFrom(
		address from,
		address to,
		uint256 tokenID,
		bytes calldata data
	) external;

	/// @notice Transfer a token between 2 addresses letting the receiver know of the transfer.
	/// @param from The send of the token.
	/// @param to The recipient of the token.
	/// @param tokenID The id of the token.
	function safeTransferFrom(
		address from,
		address to,
		uint256 tokenID
	) external;

	/// @notice Transfer a token between 2 addresses.
	/// @param from The sender of the token.
	/// @param to The recipient of the token.
	/// @param tokenID The id of the token.
	function transferFrom(
		address from,
		address to,
		uint256 tokenID
	) external;

	/// @notice Approve an operator to transfer a specific token on the senders behalf.
	/// @param operator The address receiving the approval.
	/// @param tokenID The id of the token.
	function approve(address operator, uint256 tokenID) external;

	/// @notice Set the approval for an operator to manage all the tokens of the sender.
	/// @param operator The address receiving the approval.
	/// @param approved The determination of the approval.
	function setApprovalForAll(address operator, bool approved) external;

	/// @notice Get the approved operator for a specific token.
	/// @param tokenID The id of the token.
	/// @return operator The address of the operator.
	function getApproved(uint256 tokenID) external view returns (address operator);

	/// @notice Check if the sender approved the operator to transfer any of its tokens.
	/// @param owner The address of the owner.
	/// @param operator The address of the operator.
	/// @return isOperator The status of the approval.
	function isApprovedForAll(address owner, address operator) external view returns (bool);
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ImplementingERC721Internal {
	function _ownerAndNonceOf(uint256 tokenID) internal view virtual returns (address owner, uint256 nonce);

	function _approveFor(
		address owner,
		uint256 nonce,
		address operator,
		uint256 tokenID
	) internal virtual;

	function _setApprovalForAll(
		address sender,
		address operator,
		bool approved
	) internal virtual;
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC721.sol";

interface IERC721Metadata is IERC721 {
	/// @notice A descriptive name for a collection of NFTs in this contract
	function name() external view returns (string memory name);

	/// @notice An abbreviated name for NFTs in this contract
	function symbol() external view returns (string memory symbol);

	/// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
	/// @dev Throws if `tokenID` is not a valid NFT. URIs are defined in RFC
	///  3986. The URI may point to a JSON file that conforms to the "ERC721
	///  Metadata JSON Schema".
	/// @param tokenID id of the token being queried.
	function tokenURI(uint256 tokenID) external view returns (string memory);
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721Receiver {
	/// @notice Handle the receipt of an NFT
	/// @dev The ERC721 smart contract calls this function on the recipient
	///  after a `transfer`. This function MAY throw to revert and reject the
	///  transfer. Return of other than the magic value MUST result in the
	///  transaction being reverted.
	///  Note: the contract address is always the message sender.
	/// @param operator The address which called `safeTransferFrom` function
	/// @param from The address which previously owned the token
	/// @param tokenID The NFT identifier which is being transferred
	/// @param data Additional data with no specified format
	/// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
	///  unless throwing
	function onERC721Received(
		address operator,
		address from,
		uint256 tokenID,
		bytes calldata data
	) external returns (bytes4);
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721WithBlocknumber {
	/// @notice Get the owner of a token and the blockNumber of the last transfer, useful to voting mechanism.
	/// @param tokenID The id of the token.
	/// @return owner The address of the token owner.
	/// @return blockNumber The blocknumber at which the last transfer of that id happened.
	function ownerAndLastTransferBlockNumberOf(uint256 tokenID)
		external
		view
		returns (address owner, uint256 blockNumber);

	struct OwnerData {
		address owner;
		uint256 lastTransferBlockNumber;
	}

	/// @notice Get the list of owner of a token and the blockNumber of its last transfer, useful to voting mechanism.
	/// @param tokenIDs The list of token ids to check.
	/// @return ownersData The list of (owner, lastTransferBlockNumber) for each ids given as input.
	function ownerAndLastTransferBlockNumberList(uint256[] calldata tokenIDs)
		external
		view
		returns (OwnerData[] memory ownersData);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC1271.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 *
 * _Available since v4.1._
 */
interface Openzeppelin_IERC1271 {
	/**
	 * @dev Should return whether the signature provided is valid for the provided data
	 * @param hash      Hash of the data to be signed
	 * @param signature Signature byte array associated with _data
	 */
	function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.0;

import "solidity-kit/solc_0.8/ERC721/implementations/BasicERC721.sol";

abstract contract ERC721OwnedByAll is BasicERC721, IERC721Supply {
	constructor(address initialOwnerOfTokenIdZero) {
		if (initialOwnerOfTokenIdZero == address(0)) {
			// This ensures address zero do not own any token.
			initialOwnerOfTokenIdZero = address(this);
		}
		_transferFrom(address(0), initialOwnerOfTokenIdZero, 0, false);
	}

	/// @inheritdoc IERC721
	function balanceOf(address owner) public view override returns (uint256 balance) {
		balance = super.balanceOf(owner);

		(, uint256 nonce) = _ownerAndNonceOf(uint256(uint160(owner)));
		if (nonce >> 24 == 0) {
			// self token was never registered
			unchecked {
				balance++;
			}
		}
	}

	/// @inheritdoc IERC721WithBlocknumber
	function ownerAndLastTransferBlockNumberList(uint256[] calldata ids)
		external
		view
		override
		returns (OwnerData[] memory ownersData)
	{
		ownersData = new OwnerData[](ids.length);
		for (uint256 i = 0; i < ids.length; i++) {
			uint256 id = ids[i];
			uint256 data = _owners[id];
			address owner = address(uint160(data));
			if (owner == address(0) && id < 2**160) {
				owner = address(uint160(id));
			}
			ownersData[i].owner = owner;
			ownersData[i].lastTransferBlockNumber = (data >> 184) & 0xFFFFFFFFFFFFFFFF;
		}
	}

	/// @inheritdoc IERC721Supply
	function totalSupply() external pure returns (uint256) {
		return 2**160;
	}

	// ------------------------------------------------------------------------------------------------------------------
	// INTERNALS
	// ------------------------------------------------------------------------------------------------------------------

	function _ownerOf(uint256 id) internal view override returns (address owner) {
		owner = super._ownerOf(id);
		if (owner == address(0) && id < 2**160) {
			owner = address(uint160(id));
		}
	}

	function _ownerAndOperatorEnabledOf(uint256 id)
		internal
		view
		override
		returns (address owner, bool operatorEnabled)
	{
		(owner, operatorEnabled) = super._ownerAndOperatorEnabledOf(id);
		if (owner == address(0) && id < 2**160) {
			owner = address(uint160(id));
		}
	}

	function _ownerAndNonceOf(uint256 id) internal view override returns (address owner, uint256 nonce) {
		(owner, nonce) = super._ownerAndNonceOf(id);
		if (owner == address(0) && id < 2**160) {
			owner = address(uint160(id));
		}
	}

	function _ownerNonceAndOperatorEnabledOf(uint256 id)
		internal
		view
		override
		returns (
			address owner,
			uint256 nonce,
			bool operatorEnabled
		)
	{
		(owner, nonce, operatorEnabled) = super._ownerNonceAndOperatorEnabledOf(id);
		if (owner == address(0) && id < 2**160) {
			owner = address(uint160(id));
		}
	}
}