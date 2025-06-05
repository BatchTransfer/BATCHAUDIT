// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Vault} from "../vault/Vault.sol";
import {EIP712} from "solady/utils/EIP712.sol";

/// @notice Staking vault that is managed by a vault manager.
contract StakingVault is Vault {
    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                         OVERRIDES                          */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    /// @dev For EIP-712.
    function _domainNameAndVersion()
        internal
        pure
        override(EIP712)
        returns (string memory, string memory)
    {
        return ("StakingVault", "1");
    }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC1271} from "solady/accounts/ERC1271.sol";
import {ERC6551} from "solady/accounts/ERC6551.sol";
import {LibERC6551} from "solady/accounts/LibERC6551.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/// @notice ERC6551 vault that is managed by a vault manager.
abstract contract Vault is ERC6551 {
    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                       CUSTOM ERRORS                        */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    /// @dev The function selector is not recognized.
    error FnSelectorNotRecognized();

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                           EVENTS                           */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    /// @dev Emitted when the ERC1271 adapter is set.
    event ERC1271AdapterSet(address indexed adapter);

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                          STORAGE                           */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    /// @dev So that users can provide their own adapter if needed.
    address public erc1271Adapter;

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                      PROXY OPERATIONS                      */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    /// @dev Returns the address stored in the ERC1967 implementation slot.
    /// If this returns zero, send 0 ETH to the proxy to initialize it.
    function erc1967Implementation() public view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := sload(_ERC1967_IMPLEMENTATION_SLOT)
        }
    }

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                       CONFIGURABLES                        */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    /// @dev Hook to override to check if the parameters to `execute` are approved.
    /// This can be used to check if the caller is the token contract (i.e. VaultManager),
    /// and allow calls to Asterix and AsterixMirror if they are blocked by default (e.g. for vesting).
    function _afterExecute(address target, uint256 value, bytes calldata data, uint8 operation)
        internal
        virtual
    {}

    /// @dev Hook to override to check if the parameters to `executeBatch` are approved.
    /// This can be used to check if the caller is the token contract (i.e. VaultManager),
    /// and allow calls to Asterix and AsterixMirror if they are blocked by default (e.g. for vesting).
    function _afterExecuteBatch(Call[] calldata calls, uint8 operation) internal virtual {}

    /// @dev Returns whether the proxy is upgradeable.
    /// Returns false by default.
    /// For extra safety, such that we can be double-sure that the proxy is non-upgradeable.
    function _isUpgradeable() internal view virtual returns (bool) {
        return false;
    }

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                      ERC1271 ADAPTER                       */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    /// @dev Allows a user to set a ERC1271 adapter.
    function setERC1271Adapter(address adapter) public virtual onlyValidSigner {
        erc1271Adapter = adapter;
        emit ERC1271AdapterSet(adapter);
        _updateState();
    }

    /// @dev Returns whether the `signature` is valid for the `hash.
    function _erc1271IsValidSignature(bytes32 hash, bytes calldata signature)
        internal
        view
        virtual
        override(ERC1271)
        returns (bool)
    {
        if (ERC1271._erc1271IsValidSignature(hash, signature)) return true;
        address adapter = erc1271Adapter;
        return adapter != address(0)
            && ERC1271(adapter).isValidSignature(hash, signature) == ERC1271.isValidSignature.selector;
    }

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                         OVERRIDES                          */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    /// @dev Override for `execute`, such that `_afterExecute` is called.
    function execute(address target, uint256 value, bytes calldata data, uint8 operation)
        public
        payable
        virtual
        override(ERC6551)
        returns (bytes memory results)
    {
        results = ERC6551.execute(target, value, data, operation);
        _afterExecute(target, value, data, operation);
    }

    /// @dev Override for `executeBatch`, such that `_afterExecuteBatch` is called.
    function executeBatch(Call[] calldata calls, uint8 operation)
        public
        payable
        virtual
        override(ERC6551)
        returns (bytes[] memory results)
    {
        results = ERC6551.executeBatch(calls, operation);
        _afterExecuteBatch(calls, operation);
    }

    /// @dev This is used in the `onlyValidSigner` modifier,
    /// which guards `execute` and `executeBatch`.
    function _isValidSigner(address signer)
        internal
        view
        virtual
        override(ERC6551)
        returns (bool)
    {
        // We also consider the token contract (i.e. the VaultManager) to also be a valid signer
        // such that it can withdraw Asterix ERC20s and AsterixMirror ERC721s from the vault.
        // This means we must be very careful to make sure that the VaultManager does NOT
        // let anyone control the vaults of others.
        return _signerIsTokenContract(signer) || ERC6551._isValidSigner(signer);
    }

    /// @dev Returns if `signer` is the vault manager.
    function _signerIsTokenContract(address signer) internal view virtual returns (bool) {
        // The token contract is immutably baked into the ERC6551 bytecode.
        return signer == LibERC6551.tokenContract(address(this));
    }

    /// @dev To ensure that only the vault manager can upgrade the vault.
    function _authorizeUpgrade(address) internal virtual override(ERC6551) {
        if (!_signerIsTokenContract(msg.sender)) revert Unauthorized();
        _updateState();
    }

    /// @dev Upgrades the proxy's implementation to `newImplementation`.
    /// Ensures that we must override `_isUpgradeable` to return true
    /// to enable upgradeability.
    function upgradeToAndCall(address newImplementation, bytes calldata data)
        public
        payable
        virtual
        override(UUPSUpgradeable)
    {
        if (_isUpgradeable()) {
            UUPSUpgradeable.upgradeToAndCall(newImplementation, data);
        } else {
            revert Unauthorized();
        }
    }

    /// @dev Handle token callbacks.
    fallback() external payable virtual override(ERC6551) receiverFallback {
        revert FnSelectorNotRecognized();
    }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Contract for EIP-712 typed structured data hashing and signing.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/EIP712.sol)
/// @author Modified from Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/utils/EIP712.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol)
///
/// @dev Note, this implementation:
/// - Uses `address(this)` for the `verifyingContract` field.
/// - Does NOT use the optional EIP-712 salt.
/// - Does NOT use any EIP-712 extensions.
/// This is for simplicity and to save gas.
/// If you need to customize, please fork / modify accordingly.
abstract contract EIP712 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONSTANTS AND IMMUTABLES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev `keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")`.
    bytes32 internal constant _DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    uint256 private immutable _cachedThis;
    uint256 private immutable _cachedChainId;
    bytes32 private immutable _cachedNameHash;
    bytes32 private immutable _cachedVersionHash;
    bytes32 private immutable _cachedDomainSeparator;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Cache the hashes for cheaper runtime gas costs.
    /// In the case of upgradeable contracts (i.e. proxies),
    /// or if the chain id changes due to a hard fork,
    /// the domain separator will be seamlessly calculated on-the-fly.
    constructor() {
        _cachedThis = uint256(uint160(address(this)));
        _cachedChainId = block.chainid;

        string memory name;
        string memory version;
        if (!_domainNameAndVersionMayChange()) (name, version) = _domainNameAndVersion();
        bytes32 nameHash = _domainNameAndVersionMayChange() ? bytes32(0) : keccak256(bytes(name));
        bytes32 versionHash =
            _domainNameAndVersionMayChange() ? bytes32(0) : keccak256(bytes(version));
        _cachedNameHash = nameHash;
        _cachedVersionHash = versionHash;

        bytes32 separator;
        if (!_domainNameAndVersionMayChange()) {
            /// @solidity memory-safe-assembly
            assembly {
                let m := mload(0x40) // Load the free memory pointer.
                mstore(m, _DOMAIN_TYPEHASH)
                mstore(add(m, 0x20), nameHash)
                mstore(add(m, 0x40), versionHash)
                mstore(add(m, 0x60), chainid())
                mstore(add(m, 0x80), address())
                separator := keccak256(m, 0xa0)
            }
        }
        _cachedDomainSeparator = separator;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   FUNCTIONS TO OVERRIDE                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Please override this function to return the domain name and version.
    /// ```
    ///     function _domainNameAndVersion()
    ///         internal
    ///         pure
    ///         virtual
    ///         returns (string memory name, string memory version)
    ///     {
    ///         name = "Solady";
    ///         version = "1";
    ///     }
    /// ```
    ///
    /// Note: If the returned result may change after the contract has been deployed,
    /// you must override `_domainNameAndVersionMayChange()` to return true.
    function _domainNameAndVersion()
        internal
        view
        virtual
        returns (string memory name, string memory version);

    /// @dev Returns if `_domainNameAndVersion()` may change
    /// after the contract has been deployed (i.e. after the constructor).
    /// Default: false.
    function _domainNameAndVersionMayChange() internal pure virtual returns (bool result) {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     HASHING OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the EIP-712 domain separator.
    function _domainSeparator() internal view virtual returns (bytes32 separator) {
        if (_domainNameAndVersionMayChange()) {
            separator = _buildDomainSeparator();
        } else {
            separator = _cachedDomainSeparator;
            if (_cachedDomainSeparatorInvalidated()) separator = _buildDomainSeparator();
        }
    }

    /// @dev Returns the hash of the fully encoded EIP-712 message for this domain,
    /// given `structHash`, as defined in
    /// https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
    ///
    /// The hash can be used together with {ECDSA-recover} to obtain the signer of a message:
    /// ```
    ///     bytes32 digest = _hashTypedData(keccak256(abi.encode(
    ///         keccak256("Mail(address to,string contents)"),
    ///         mailTo,
    ///         keccak256(bytes(mailContents))
    ///     )));
    ///     address signer = ECDSA.recover(digest, signature);
    /// ```
    function _hashTypedData(bytes32 structHash) internal view virtual returns (bytes32 digest) {
        // We will use `digest` to store the domain separator to save a bit of gas.
        if (_domainNameAndVersionMayChange()) {
            digest = _buildDomainSeparator();
        } else {
            digest = _cachedDomainSeparator;
            if (_cachedDomainSeparatorInvalidated()) digest = _buildDomainSeparator();
        }
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the digest.
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, digest) // Store the domain separator.
            mstore(0x3a, structHash) // Store the struct hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    EIP-5267 OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev See: https://eips.ethereum.org/EIPS/eip-5267
    function eip712Domain()
        public
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        fields = hex"0f"; // `0b01111`.
        (name, version) = _domainNameAndVersion();
        chainId = block.chainid;
        verifyingContract = address(this);
        salt = salt; // `bytes32(0)`.
        extensions = extensions; // `new uint256[](0)`.
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the EIP-712 domain separator.
    function _buildDomainSeparator() private view returns (bytes32 separator) {
        // We will use `separator` to store the name hash to save a bit of gas.
        bytes32 versionHash;
        if (_domainNameAndVersionMayChange()) {
            (string memory name, string memory version) = _domainNameAndVersion();
            separator = keccak256(bytes(name));
            versionHash = keccak256(bytes(version));
        } else {
            separator = _cachedNameHash;
            versionHash = _cachedVersionHash;
        }
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(m, _DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), separator) // Name hash.
            mstore(add(m, 0x40), versionHash)
            mstore(add(m, 0x60), chainid())
            mstore(add(m, 0x80), address())
            separator := keccak256(m, 0xa0)
        }
    }

    /// @dev Returns if the cached domain separator has been invalidated.
    function _cachedDomainSeparatorInvalidated() private view returns (bool result) {
        uint256 cachedChainId = _cachedChainId;
        uint256 cachedThis = _cachedThis;
        /// @solidity memory-safe-assembly
        assembly {
            result := iszero(and(eq(chainid(), cachedChainId), eq(address(), cachedThis)))
        }
    }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {EIP712} from "../utils/EIP712.sol";
import {SignatureCheckerLib} from "../utils/SignatureCheckerLib.sol";

/// @notice ERC1271 mixin with nested EIP-712 approach.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/accounts/ERC1271.sol)
abstract contract ERC1271 is EIP712 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ERC1271 OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the ERC1271 signer.
    /// Override to return the signer `isValidSignature` checks against.
    function _erc1271Signer() internal view virtual returns (address);

    /// @dev Returns whether the `msg.sender` is considered safe, such
    /// that we don't need to use the nested EIP-712 workflow.
    /// Override to return true for more callers.
    /// See: https://mirror.xyz/curiousapple.eth/pFqAdW2LiJ-6S4sg_u1z08k4vK6BCJ33LcyXpnNb8yU
    function _erc1271CallerIsSafe() internal view virtual returns (bool) {
        // The canonical `MulticallerWithSender` at 0x000000000000D9ECebf3C23529de49815Dac1c4c
        // is known to include the account in the hash to be signed.
        return msg.sender == 0x000000000000D9ECebf3C23529de49815Dac1c4c;
    }

    /// @dev Validates the signature with ERC1271 return,
    /// so that this account can also be used as a signer.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        returns (bytes4 result)
    {
        bool success = _erc1271IsValidSignature(hash, signature);
        /// @solidity memory-safe-assembly
        assembly {
            // `success ? bytes4(keccak256("isValidSignature(bytes32,bytes)")) : 0xffffffff`.
            // We use `0xffffffff` for invalid, in convention with the reference implementation.
            result := shl(224, or(0x1626ba7e, sub(0, iszero(success))))
        }
    }

    /// @dev Returns whether the `signature` is valid for the `hash.
    function _erc1271IsValidSignature(bytes32 hash, bytes calldata signature)
        internal
        view
        virtual
        returns (bool)
    {
        return _erc1271IsValidSignatureViaSafeCaller(hash, signature)
            || _erc1271IsValidSignatureViaNestedEIP712(hash, signature)
            || _erc1271IsValidSignatureViaRPC(hash, signature);
    }

    /// @dev Performs the signature validation without nested EIP-712 if the caller is
    /// a safe caller. A safe caller must include the address of this account in the hash.
    function _erc1271IsValidSignatureViaSafeCaller(bytes32 hash, bytes calldata signature)
        internal
        view
        virtual
        returns (bool result)
    {
        if (_erc1271CallerIsSafe()) {
            result =
                SignatureCheckerLib.isValidSignatureNowCalldata(_erc1271Signer(), hash, signature);
        }
    }

    /// @dev ERC1271 signature validation (Nested EIP-712 workflow).
    ///
    /// This implementation uses ECDSA recovery. It also uses a nested EIP-712 approach to
    /// prevent signature replays when a single EOA owns multiple smart contract accounts,
    /// while still enabling wallet UIs (e.g. Metamask) to show the EIP-712 values.
    ///
    /// The `hash` parameter to this method is the `childHash`.
    /// __________________________________________________________________________________________
    ///
    /// Glossary:
    ///
    /// - `DOMAIN_SEP_B`: The domain separator of the `childHash`.
    ///   Provided by the front end. Intended to be the domain separator of the contract
    ///   that will call `isValidSignature` on this account.
    ///
    /// - `DOMAIN_SEP_A`: The domain separator of this account.
    ///   See: `EIP712._domainSeparator()`.
    ///
    /// - `Parent`: The parent struct type.
    ///   To be defined by the front end, such that `child` can be visible via EIP-712.
    /// __________________________________________________________________________________________
    ///
    /// For the default nested EIP-712 workflow, the final hash will be:
    /// ```
    ///     keccak256(\x19\x01 || DOMAIN_SEP_A ||
    ///         hashStruct(Parent({
    ///             childHash: keccak256(\x19\x01 || DOMAIN_SEP_B || hashStruct(originalStruct)),
    ///             child: hashStruct(originalStruct)
    ///         }))
    ///     )
    /// ```
    /// where `||` denotes the concatenation operator for bytes.
    /// The order of Parent's fields is important: `childHash` comes before `child`.
    ///
    /// The signature will be `r || s || v || PARENT_TYPEHASH || DOMAIN_SEP_B || child`,
    /// where `child` is the bytes32 struct hash of the original struct.
    ///
    /// The `DOMAIN_SEP_B` and `child` will be used to verify if `childHash` is indeed correct.
    /// __________________________________________________________________________________________
    ///
    /// For the `personalSign` workflow, the final hash will be:
    /// ```
    ///     keccak256(\x19\x01 || DOMAIN_SEP_A ||
    ///         hashStruct(Parent({
    ///             childHash: keccak256(\x19Ethereum Signed Message:\n ||
    ///                 base10(bytes(someString).length) || someString)
    ///         }))
    ///     )
    /// ```
    /// where `||` denotes the concatenation operator for bytes.
    /// The signature will be `r || s || v || PARENT_TYPEHASH`.
    /// __________________________________________________________________________________________
    ///
    /// For demo and typescript code, see:
    /// - https://github.com/junomonster/nested-eip-712
    /// - https://github.com/frangio/eip712-wrapper-for-eip1271
    ///
    /// Their nomenclature may differ from ours, although the high-level idea is similar.
    ///
    /// Of course, if you are a wallet app maker and can update your app's UI at will,
    /// you can choose a more minimalistic signature scheme like
    /// `keccak256(abi.encode(address(this), hash))` instead of all these acrobatics.
    /// All these are just for widespead out-of-the-box compatibility with other wallet apps.
    function _erc1271IsValidSignatureViaNestedEIP712(bytes32 hash, bytes calldata signature)
        internal
        view
        virtual
        returns (bool)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            let o := add(signature.offset, sub(signature.length, 0x60))
            calldatacopy(0x00, o, 0x60) // Copy the `DOMAIN_SEP_B` and child's structHash.
            mstore(0x00, 0x1901) // Store the "\x19\x01" prefix, overwriting 0x00.
            for {} 1 {} {
                // Use the nested EIP-712 workflow if the reconstructed `childHash` matches,
                // and the signature is at least 96 bytes long.
                if iszero(or(xor(keccak256(0x1e, 0x42), hash), lt(signature.length, 0x60))) {
                    // Truncate the `signature.length` by 3 words (96 bytes).
                    signature.length := sub(signature.length, 0x60)
                    mstore(0x00, calldataload(o)) // Store the `PARENT_TYPEHASH`.
                    mstore(0x20, hash) // Store the `childHash`.
                    // The `child` struct hash is already at 0x40.
                    hash := keccak256(0x00, 0x60) // Compute the `parent` struct hash.
                    break
                }
                // Else, use the `personalSign` workflow.
                // If `signature.length` > 1 word (32 bytes), reduce by 1 word, else set to 0.
                signature.length := mul(gt(signature.length, 0x20), sub(signature.length, 0x20))
                // The `PARENT_TYPEHASH` is already at 0x40.
                mstore(0x60, hash) // Store the `childHash`.
                hash := keccak256(0x40, 0x40) // Compute the `parent` struct hash.
                mstore(0x60, 0) // Restore the zero pointer.
                break
            }
            mstore(0x40, m) // Restore the free memory pointer.
        }
        return SignatureCheckerLib.isValidSignatureNowCalldata(
            _erc1271Signer(), _hashTypedData(hash), signature
        );
    }

    /// @dev Performs the signature validation without nested EIP-712 to allow for easy sign ins.
    /// This function must always return false or revert if called on-chain.
    function _erc1271IsValidSignatureViaRPC(bytes32 hash, bytes calldata signature)
        internal
        view
        virtual
        returns (bool result)
    {
        // Non-zero gasprice is a heuristic to check if a call is on-chain,
        // but we can't fully depend on it because it can be manipulated.
        // See: https://x.com/NoahCitron/status/1580359718341484544
        if (tx.gasprice == 0) {
            /// @solidity memory-safe-assembly
            assembly {
                let gasBurnHash := 0x31d8f1c26729207294 // uint72(bytes9(keccak256("gasBurnHash"))).
                if eq(hash, gasBurnHash) { invalid() } // Burns gas computationally efficiently.
                let m := mload(0x40) // Cache the free memory pointer.
                mstore(0x00, 0x1626ba7e) // `isValidSignature(bytes32,bytes)`.
                mstore(0x20, gasBurnHash)
                mstore(0x40, 0x40)
                // Make a call to this with `gasBurnHash`, efficiently burning the gas provided.
                // No valid transaction can consume more than the gaslimit.
                // See: https://ethereum.github.io/yellowpaper/paper.pdf
                // Most RPCs perform calls with a gas budget greater than the gaslimit.
                pop(staticcall(add(100000, gaslimit()), address(), 0x1c, 0x64, 0x00, 0x00))
                mstore(0x40, m) // Restore the free memory pointer.
            }
            result =
                SignatureCheckerLib.isValidSignatureNowCalldata(_erc1271Signer(), hash, signature);
        }
    }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Receiver} from "./Receiver.sol";
import {ERC1271} from "./ERC1271.sol";
import {LibZip} from "../utils/LibZip.sol";
import {UUPSUpgradeable} from "../utils/UUPSUpgradeable.sol";

/// @notice Simple ERC6551 account implementation.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/accounts/ERC6551.sol)
/// @author ERC6551 team (https://github.com/erc6551/reference/blob/main/src/examples/upgradeable/ERC6551AccountUpgradeable.sol)
///
/// @dev Recommended usage (regular):
/// 1. Deploy the ERC6551 as an implementation contract, and verify it on Etherscan.
/// 2. Use the canonical ERC6551Registry to deploy a clone to the ERC6551 implementation.
///    The UUPSUpgradeable functions will simply become no-ops.
///
/// Recommended usage (upgradeable):
/// 1. Deploy the ERC6551 as an implementation contract, and verify it on Etherscan.
/// 2. Deploy the ERC6551Proxy pointing to the implementation.
///    This relay proxy is required, but Etherscan verification of it is optional.
/// 3. Use the canonical ERC6551Registry to deploy a clone to the ERC6551Proxy.
///    If you want to reveal the "Read as Proxy" and "Write as Proxy" tabs on Etherscan,
///    send 0 ETH to the clone to initialize its ERC1967 implementation slot,
///    the click on "Is this a proxy?" on the clone's page on Etherscan.
///
/// Note:
/// - This implementation does NOT include ERC4337 functionality.
///   This is intentional, because the canonical ERC4337 entry point may still change and we
///   don't want to encourage upgradeability by default for ERC6551 accounts just to handle this.
///   We may include ERC4337 functionality once ERC4337 has been finalized.
///   Recent updates to the account abstraction validation scope rules
///   [ERC7562](https://eips.ethereum.org/EIPS/eip-7562) has made ERC6551 compatible with ERC4337.
///   For an opinionated implementation, see https://github.com/tokenbound/contracts.
///   If you want to add it yourself, you'll just need to add in the
///   user operation validation functionality (and use ERC6551's execution functionality).
/// - Please refer to the official [ERC6551](https://github.com/erc6551/reference) reference
///   for latest updates on the ERC6551 standard, as well as canonical registry information.
abstract contract ERC6551 is UUPSUpgradeable, Receiver, ERC1271 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Call struct for the `executeBatch` function.
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev The operation is not supported.
    error OperationNotSupported();

    /// @dev Self ownership detected.
    error SelfOwnDetected();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONSTANTS AND IMMUTABLES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ERC6551 state slot is given by:
    /// `bytes32(~uint256(uint32(bytes4(keccak256("_ERC6551_STATE_SLOT_NOT")))))`.
    /// It is intentionally chosen to be a high value
    /// to avoid collision with lower slots.
    /// The choice of manual storage layout is to enable compatibility
    /// with both regular and upgradeable contracts.
    uint256 internal constant _ERC6551_STATE_SLOT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffb919c7a5;

    /// @dev Caches the chain ID in the deployed bytecode,
    /// so that in the rare case of a hard fork, `owner` will still work.
    uint256 private immutable _cachedChainId = block.chainid;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              TOKEN-BOUND OWNERSHIP OPERATIONS              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the token-bound information.
    function token()
        public
        view
        virtual
        returns (uint256 chainId, address tokenContract, uint256 tokenId)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            extcodecopy(address(), 0x00, 0x4d, 0x60)
            chainId := mload(0x00)
            tokenContract := mload(0x20) // Upper 96 bits will be clean.
            tokenId := mload(0x40)
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Returns the owner of the contract.
    function owner() public view virtual returns (address result) {
        uint256 cachedChainId = _cachedChainId;
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            extcodecopy(address(), 0x00, 0x4d, 0x60)
            if eq(mload(0x00), cachedChainId) {
                let tokenContract := mload(0x20)
                // `tokenId` is already at 0x40.
                mstore(0x20, 0x6352211e) // `ownerOf(uint256)`.
                result :=
                    mul( // Returns `address(0)` on failure or if contract does not exist.
                        mload(0x20),
                        and(
                            gt(returndatasize(), 0x1f),
                            staticcall(gas(), tokenContract, 0x3c, 0x24, 0x20, 0x20)
                        )
                    )
            }
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Returns if `signer` is an authorized signer.
    function _isValidSigner(address signer) internal view virtual returns (bool) {
        return signer == owner();
    }

    /// @dev Returns if `signer` is an authorized signer, with an optional `context`.
    /// MUST return the bytes4 magic value `0x523e3260` if the given signer is valid.
    /// By default, the holder of the non-fungible token the account is bound to
    /// MUST be considered a valid signer.
    function isValidSigner(address signer, bytes calldata context)
        public
        view
        virtual
        returns (bytes4 result)
    {
        context = context; // Silence unused variable warning.
        bool isValid = _isValidSigner(signer);
        /// @solidity memory-safe-assembly
        assembly {
            // `isValid ? bytes4(keccak256("isValidSigner(address,bytes)")) : 0x00000000`.
            // We use `0x00000000` for invalid, in convention with the reference implementation.
            result := shl(224, mul(0x523e3260, iszero(iszero(isValid))))
        }
    }

    /// @dev Requires that the caller is a valid signer (i.e. the owner).
    modifier onlyValidSigner() virtual {
        if (!_isValidSigner(msg.sender)) revert Unauthorized();
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      STATE OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the current value of the state.
    function state() public view virtual returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := sload(_ERC6551_STATE_SLOT)
        }
    }

    /// @dev Mutates the state. This function is required to be called in every
    /// public / external function that may modify storage or emit events.
    function _updateState() internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            let s := _ERC6551_STATE_SLOT
            let m := mload(0x40)
            mstore(m, sload(s))
            mstore(add(0x20, m), 0x40)
            mstore(add(0x40, m), calldatasize())
            calldatacopy(add(0x60, m), 0x00, add(0x20, calldatasize()))
            sstore(s, keccak256(m, and(add(0x7f, calldatasize()), not(0x1f))))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    EXECUTION OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Execute a call from this account.
    /// Reverts and bubbles up error if operation fails.
    /// Returns the result of the operation.
    ///
    /// Accounts MUST accept the following operation parameter values:
    /// - 0 = CALL
    /// - 1 = DELEGATECALL
    /// - 2 = CREATE
    /// - 3 = CREATE2
    ///
    /// Accounts MAY support additional operations or restrict a signer's
    /// ability to execute certain operations.
    function execute(address target, uint256 value, bytes calldata data, uint8 operation)
        public
        payable
        virtual
        onlyValidSigner
        returns (bytes memory result)
    {
        if (operation != 0) revert OperationNotSupported();
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            calldatacopy(result, data.offset, data.length)
            if iszero(call(gas(), target, value, result, data.length, codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
        _updateState();
    }

    /// @dev Execute a sequence of calls from this account.
    /// Reverts and bubbles up error if an operation fails.
    /// Returns the results of the operations.
    ///
    /// This is a batch variant of `execute` and is not required for `IERC6551Executable`.
    function executeBatch(Call[] calldata calls, uint8 operation)
        public
        payable
        virtual
        onlyValidSigner
        returns (bytes[] memory results)
    {
        if (operation != 0) revert OperationNotSupported();
        /// @solidity memory-safe-assembly
        assembly {
            results := mload(0x40)
            mstore(results, calls.length)
            let r := add(0x20, results)
            let m := add(r, shl(5, calls.length))
            calldatacopy(r, calls.offset, shl(5, calls.length))
            for { let end := m } iszero(eq(r, end)) { r := add(r, 0x20) } {
                let e := add(calls.offset, mload(r))
                let o := add(e, calldataload(add(e, 0x40)))
                calldatacopy(m, add(o, 0x20), calldataload(o))
                // forgefmt: disable-next-item
                if iszero(call(gas(), calldataload(e), calldataload(add(e, 0x20)),
                    m, calldataload(o), codesize(), 0x00)) {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(m, 0x00, returndatasize())
                    revert(m, returndatasize())
                }
                mstore(r, m) // Append `m` into `results`.
                mstore(m, returndatasize()) // Store the length,
                let p := add(m, 0x20)
                returndatacopy(p, 0x00, returndatasize()) // and copy the returndata.
                m := add(p, returndatasize()) // Advance `m`.
            }
            mstore(0x40, m) // Allocate the memory.
        }
        _updateState();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERC165                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns true if this contract implements the interface defined by `interfaceId`.
    /// See: https://eips.ethereum.org/EIPS/eip-165
    /// This function call must use less than 30000 gas.
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let s := shr(224, interfaceId)
            // ERC165: 0x01ffc9a7, ERC6551: 0x6faff5f1, ERC6551Executable: 0x51945447.
            result := or(or(eq(s, 0x01ffc9a7), eq(s, 0x6faff5f1)), eq(s, 0x51945447))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         OVERRIDES                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev To ensure that only the owner or the account itself can upgrade the implementation.
    function _authorizeUpgrade(address)
        internal
        virtual
        override(UUPSUpgradeable)
        onlyValidSigner
    {
        _updateState();
    }

    /// @dev Uses the `owner` as the ERC1271 signer.
    function _erc1271Signer() internal view virtual override(ERC1271) returns (address) {
        return owner();
    }

    /// @dev For handling token callbacks.
    /// Safe-transferred ERC721 tokens will trigger a ownership cycle check.
    modifier receiverFallback() override(Receiver) {
        uint256 cachedChainId = _cachedChainId;
        /// @solidity memory-safe-assembly
        assembly {
            let s := shr(224, calldataload(0x00))
            // 0x150b7a02: `onERC721Received(address,address,uint256,bytes)`.
            if eq(s, 0x150b7a02) {
                extcodecopy(address(), 0x00, 0x4d, 0x60) // `chainId`, `tokenContract`, `tokenId`.
                mstore(0x60, 0xfc0c546a) // `token()`.
                for {} 1 {} {
                    let tokenContract := mload(0x20)
                    // `tokenId` is already at 0x40.
                    mstore(0x20, 0x6352211e) // `ownerOf(uint256)`.
                    let chainsEq := eq(mload(0x00), cachedChainId)
                    let currentOwner :=
                        mul(
                            mload(0x20),
                            and(
                                and(gt(returndatasize(), 0x1f), chainsEq),
                                staticcall(gas(), tokenContract, 0x3c, 0x24, 0x20, 0x20)
                            )
                        )
                    if iszero(
                        or(
                            eq(currentOwner, address()),
                            and(
                                and(chainsEq, eq(tokenContract, caller())),
                                eq(mload(0x40), calldataload(0x44))
                            )
                        )
                    ) {
                        if iszero(
                            and(
                                gt(returndatasize(), 0x5f),
                                staticcall(gas(), currentOwner, 0x7c, 0x04, 0x00, 0x60)
                            )
                        ) {
                            mstore(0x40, s) // Store `msg.sig`.
                            return(0x5c, 0x20) // Return `msg.sig`.
                        }
                        continue
                    }
                    mstore(0x00, 0xaed146d3) // `SelfOwnDetected()`.
                    revert(0x1c, 0x04)
                }
            }
            // 0xf23a6e61: `onERC1155Received(address,address,uint256,uint256,bytes)`.
            // 0xbc197c81: `onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)`.
            if or(eq(s, 0xf23a6e61), eq(s, 0xbc197c81)) {
                mstore(0x20, s) // Store `msg.sig`.
                return(0x3c, 0x20) // Return `msg.sig`.
            }
        }
        _;
    }

    /// @dev Handle token callbacks. If no token callback is triggered,
    /// use `LibZip.cdFallback` for generalized calldata decompression.
    /// If you don't need either, re-override this function.
    fallback() external payable virtual override(Receiver) receiverFallback {
        LibZip.cdFallback();
    }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for interacting with ERC6551 accounts.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/accounts/LibERC6551.sol)
/// @author ERC6551 team (https://github.com/erc6551/reference/blob/main/src/lib/ERC6551AccountLib.sol)
library LibERC6551 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Failed to create a ERC6551 account via the registry.
    error AccountCreationFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The canonical ERC6551 registry address for EVM chains.
    address internal constant REGISTRY = 0x000000006551c19487814612e58FE06813775758;

    /// @dev The canonical ERC6551 registry bytecode for EVM chains.
    /// Useful for forge tests:
    /// `vm.etch(REGISTRY, REGISTRY_BYTECODE)`.
    bytes internal constant REGISTRY_BYTECODE =
        hex"608060405234801561001057600080fd5b50600436106100365760003560e01c8063246a00211461003b5780638a54c52f1461006a575b600080fd5b61004e6100493660046101b7565b61007d565b6040516001600160a01b03909116815260200160405180910390f35b61004e6100783660046101b7565b6100e1565b600060806024608c376e5af43d82803e903d91602b57fd5bf3606c5285605d52733d60ad80600a3d3981f3363d3d373d3d3d363d7360495260ff60005360b76055206035523060601b60015284601552605560002060601b60601c60005260206000f35b600060806024608c376e5af43d82803e903d91602b57fd5bf3606c5285605d52733d60ad80600a3d3981f3363d3d373d3d3d363d7360495260ff60005360b76055206035523060601b600152846015526055600020803b61018b578560b760556000f580610157576320188a596000526004601cfd5b80606c52508284887f79f19b3655ee38b1ce526556b7731a20c8f218fbda4a3990b6cc4172fdf887226060606ca46020606cf35b8060601b60601c60005260206000f35b80356001600160a01b03811681146101b257600080fd5b919050565b600080600080600060a086880312156101cf57600080fd5b6101d88661019b565b945060208601359350604086013592506101f46060870161019b565b94979396509194608001359291505056fea2646970667358221220ea2fe53af507453c64dd7c1db05549fa47a298dfb825d6d11e1689856135f16764736f6c63430008110033";

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                ACCOUNT BYTECODE OPERATIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the initialization code of the ERC6551 account.
    function initCode(
        address implementation_,
        bytes32 salt_,
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40) // Grab the free memory pointer..
            // Layout the variables and bytecode backwards.
            mstore(add(result, 0xb7), tokenId_)
            mstore(add(result, 0x97), shr(96, shl(96, tokenContract_)))
            mstore(add(result, 0x77), chainId_)
            mstore(add(result, 0x57), salt_)
            mstore(add(result, 0x37), 0x5af43d82803e903d91602b57fd5bf3)
            mstore(add(result, 0x28), implementation_)
            mstore(add(result, 0x14), 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73)
            mstore(result, 0xb7) // Store the length.
            mstore(0x40, add(result, 0xd7)) // Allocate the memory.
        }
    }

    /// @dev Returns the initialization code hash of the ERC6551 account.
    function initCodeHash(
        address implementation_,
        bytes32 salt_,
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40) // Grab the free memory pointer.
            // Layout the variables and bytecode backwards.
            mstore(add(result, 0xa3), tokenId_)
            mstore(add(result, 0x83), shr(96, shl(96, tokenContract_)))
            mstore(add(result, 0x63), chainId_)
            mstore(add(result, 0x43), salt_)
            mstore(add(result, 0x23), 0x5af43d82803e903d91602b57fd5bf3)
            mstore(add(result, 0x14), implementation_)
            mstore(result, 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73)
            result := keccak256(add(result, 0x0c), 0xb7)
        }
    }

    /// @dev Creates an account via the ERC6551 registry.
    function createAccount(
        address implementation_,
        bytes32 salt_,
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) internal returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(add(m, 0x14), implementation_)
            mstore(add(m, 0x34), salt_)
            mstore(add(m, 0x54), chainId_)
            mstore(add(m, 0x74), shr(96, shl(96, tokenContract_)))
            mstore(add(m, 0x94), tokenId_)
            // `createAccount(address,bytes32,uint256,address,uint256)`.
            mstore(m, 0x8a54c52f000000000000000000000000)
            if iszero(
                and(
                    gt(returndatasize(), 0x1f),
                    call(gas(), REGISTRY, 0, add(m, 0x10), 0xa4, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x20188a59) // `AccountCreationFailed()`.
                revert(0x1c, 0x04)
            }
            result := mload(0x00)
        }
    }

    /// @dev Returns the address of the ERC6551 account.
    function account(
        address implementation_,
        bytes32 salt_,
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) internal pure returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40) // Grab the free memory pointer.
            // Layout the variables and bytecode backwards.
            mstore(add(result, 0xa3), tokenId_)
            mstore(add(result, 0x83), shr(96, shl(96, tokenContract_)))
            mstore(add(result, 0x63), chainId_)
            mstore(add(result, 0x43), salt_)
            mstore(add(result, 0x23), 0x5af43d82803e903d91602b57fd5bf3)
            mstore(add(result, 0x14), implementation_)
            mstore(result, 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73)
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, keccak256(add(result, 0x0c), 0xb7))
            mstore(0x01, shl(96, REGISTRY))
            mstore(0x15, salt_)
            result := keccak256(0x00, 0x55)
            mstore(0x35, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns if `a` is an ERC6551 account with `expectedImplementation`.
    function isERC6551Account(address a, address expectedImplementation)
        internal
        view
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Grab the free memory pointer..
            extcodecopy(a, add(m, 0x20), 0x0a, 0xa3)
            let implementation_ := shr(96, mload(add(m, 0x20)))
            if mul(
                extcodesize(implementation_),
                gt(eq(extcodesize(a), 0xad), shl(96, xor(expectedImplementation, implementation_)))
            ) {
                // Layout the variables and bytecode backwards.
                mstore(add(m, 0x23), 0x5af43d82803e903d91602b57fd5bf3)
                mstore(add(m, 0x14), implementation_)
                mstore(m, 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73)
                // Compute and store the bytecode hash.
                mstore8(0x00, 0xff) // Write the prefix.
                mstore(0x35, keccak256(add(m, 0x0c), 0xb7))
                mstore(0x01, shl(96, REGISTRY))
                mstore(0x15, mload(add(m, 0x43)))
                result := iszero(shl(96, xor(a, keccak256(0x00, 0x55))))
                mstore(0x35, 0) // Restore the overwritten part of the free memory pointer.
            }
        }
    }

    /// @dev Returns the implementation of the ERC6551 account `a`.
    function implementation(address a) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            extcodecopy(a, 0x00, 0x0a, 0x14)
            result := shr(96, mload(0x00))
        }
    }

    /// @dev Returns the static variables of the ERC6551 account `a`.
    function context(address a)
        internal
        view
        returns (bytes32 salt_, uint256 chainId_, address tokenContract_, uint256 tokenId_)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            extcodecopy(a, 0x00, 0x2d, 0x80)
            salt_ := mload(0x00)
            chainId_ := mload(0x20)
            tokenContract_ := mload(0x40)
            tokenId_ := mload(0x60)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero pointer.
        }
    }

    /// @dev Returns the salt of the ERC6551 account `a`.
    function salt(address a) internal view returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            extcodecopy(a, 0x00, 0x2d, 0x20)
            result := mload(0x00)
        }
    }

    /// @dev Returns the chain ID of the ERC6551 account `a`.
    function chainId(address a) internal view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            extcodecopy(a, 0x00, 0x4d, 0x20)
            result := mload(0x00)
        }
    }

    /// @dev Returns the token contract of the ERC6551 account `a`.
    function tokenContract(address a) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            extcodecopy(a, 0x00, 0x6d, 0x20)
            result := mload(0x00)
        }
    }

    /// @dev Returns the token ID of the ERC6551 account `a`.
    function tokenId(address a) internal view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            extcodecopy(a, 0x00, 0x8d, 0x20)
            result := mload(0x00)
        }
    }
}