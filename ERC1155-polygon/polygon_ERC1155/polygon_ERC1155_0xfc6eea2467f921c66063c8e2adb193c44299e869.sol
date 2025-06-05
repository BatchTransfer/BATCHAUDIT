// Chain: POLYGON - File: src/cores/ERC1155/ERC1155Mage.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Address} from "openzeppelin-contracts/utils/Address.sol";

import {Mage} from "../../Mage.sol";
import {Ownable, OwnableInternal} from "../../access/ownable/Ownable.sol";
import {Access} from "../../access/Access.sol";
import {ERC1155} from "./ERC1155.sol";
import {TokenMetadata} from "../TokenMetadata/TokenMetadata.sol";
import {TokenMetadataInternal} from "../TokenMetadata/TokenMetadataInternal.sol";
import {
    ITokenURIExtension, IContractURIExtension
} from "../../extension/examples/metadataRouter/IMetadataExtensions.sol";
import {Operations} from "../../lib/Operations.sol";
import {PermissionsStorage} from "../../access/permissions/PermissionsStorage.sol";
import {IERC1155Mage} from "./interface/IERC1155Mage.sol";
import {Initializable} from "../../lib/initializable/Initializable.sol";

/// @notice apply Mage pattern to ERC1155 NFTs
contract ERC1155Mage is Mage, Ownable, Initializable, TokenMetadata, ERC1155, IERC1155Mage {

    constructor() Initializable() {}
    
    // owner stored explicitly
    function owner() public view override(Access, OwnableInternal) returns (address) {
        return OwnableInternal.owner();
    }

    /// @dev cannot call initialize within a proxy constructor, only post-deployment in a factory
    function initialize(address owner_, string calldata name_, string calldata symbol_, bytes calldata initData)
        external
        initializer
    {
        _setName(name_);
        _setSymbol(symbol_);
        if (initData.length > 0) {
            /// @dev if called within a constructor, self-delegatecall will not work because this address does not yet have
            /// bytecode implementing the init functions -> revert here with nicer error message
            if (address(this).code.length == 0) {
                revert CannotInitializeWhileConstructing();
            }
            // make msg.sender the owner to ensure they have all permissions for further initialization
            _transferOwnership(msg.sender);
            Address.functionDelegateCall(address(this), initData);
            // if sender and owner arg are different, transfer ownership to desired address
            if (msg.sender != owner_) {
                _transferOwnership(owner_);
            }
        } else {
            _transferOwnership(owner_);
        }
    }

    /*==============
        METADATA
    ==============*/

    function name() public view override(ERC1155, TokenMetadataInternal) returns (string memory) {
        return TokenMetadataInternal.name();
    }

    function symbol() public view override(ERC1155, TokenMetadataInternal) returns (string memory) {
        return TokenMetadataInternal.symbol();
    }

    function supportsInterface(bytes4 interfaceId) public view override(Mage, ERC1155) returns (bool) {
        return Mage.supportsInterface(interfaceId) || ERC1155.supportsInterface(interfaceId);
    }

    // must override ERC1155 implementation
    function uri(uint256 tokenId) public view override returns (string memory) {
        // to avoid clashing selectors, use standardized `ext_` prefix
        return ITokenURIExtension(address(this)).ext_tokenURI(tokenId);
    }

    // include contractURI as modern standard for NFTs
    function contractURI() public view override returns (string memory) {
        // to avoid clashing selectors, use standardized `ext_` prefix
        return IContractURIExtension(address(this)).ext_contractURI();
    }

    /*=============
        SETTERS
    =============*/

    function mintTo(address recipient, uint256 tokenId, uint256 value) external onlyPermission(Operations.MINT) {
        _mint(recipient, tokenId, value, "");
    }

    function burnFrom(address from, uint256 tokenId, uint256 value) external {
        if (!hasPermission(Operations.BURN, msg.sender)) {
            _checkCanTransfer(from);
        }
        _burn(from, tokenId, value);
    }

    /*===========
        GUARD
    ===========*/

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    )
        internal
        view
        override
        returns (address guard, bytes memory beforeCheckData)
    {
        bytes8 operation;
        if (from == address(0)) {
            operation = Operations.MINT;
        } else if (to == address(0)) {
            operation = Operations.BURN;
        } else {
            operation = Operations.TRANSFER;
        }
        bytes memory data = abi.encode(msg.sender, from, to, ids, values);

        return checkGuardBefore(operation, data);
    }

    function _afterTokenTransfers(address guard, bytes memory checkBeforeData) internal view override {
        checkGuardAfter(guard, checkBeforeData, ""); // no execution data
    }

    /*===================
        AUTHORIZATION
    ===================*/

    function _checkCanUpdatePermissions() internal view override {
        _checkPermission(Operations.PERMISSIONS, msg.sender);
    }

    function _checkCanUpdateGuards() internal view override {
        _checkPermission(Operations.GUARDS, msg.sender);
    }

    function _checkCanExecute() internal view override {
        _checkPermission(Operations.EXECUTE, msg.sender);
    }

    function _checkCanUpdateInterfaces() internal view override {
        _checkPermission(Operations.INTERFACE, msg.sender);
    }

    function _checkCanUpdateTokenMetadata() internal view override {
        _checkPermission(Operations.METADATA, msg.sender);
    }

    // changes to core functionality must be restricted to owners to protect admins overthrowing
    function _checkCanUpdateExtensions() internal view override {
        _checkOwner();
    }

    function _authorizeUpgrade(address) internal view override {
        _checkOwner();
    }
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/utils/Address.sol
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


// Chain: POLYGON - File: src/Mage.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import {Multicall} from "openzeppelin-contracts/utils/Multicall.sol";

import {Access} from "./access/Access.sol";
import {Guards} from "./guard/Guards.sol";
import {Extensions} from "./extension/Extensions.sol";
import {SupportsInterface} from "./lib/ERC165/SupportsInterface.sol";
import {Execute} from "./lib/Execute.sol";
import {Operations} from "./lib/Operations.sol";

/**
 * A Solidity framework for creating complex and evolving onchain structures.
 * Mage is an acronym for the architecture pattern's four layers: Module, Access, Guard, and Extension.
 * All Mage-inherited contracts receive a batteries-included contract development kit.
 */
abstract contract Mage is Access, Guards, Extensions, SupportsInterface, Execute, Multicall, UUPSUpgradeable {
    function contractURI() public view virtual returns (string memory uri) {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(Access, Guards, Extensions, SupportsInterface)
        returns (bool)
    {
        return Access.supportsInterface(interfaceId) || Guards.supportsInterface(interfaceId)
            || Extensions.supportsInterface(interfaceId) || SupportsInterface.supportsInterface(interfaceId);
    }

    function _beforeExecute(address to, uint256 value, bytes calldata data) internal view override returns (address guard, bytes memory checkBeforeData) {
        return checkGuardBefore(Operations.EXECUTE, abi.encode(to, value, data));
    }

    function _afterExecute(address guard, bytes memory checkBeforeData, bytes memory executeData) internal view override {
        checkGuardAfter(guard, checkBeforeData, executeData);
    }
}


// Chain: POLYGON - File: src/access/ownable/Ownable.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OwnableInternal} from "./OwnableInternal.sol";
import {IOwnableExternal} from "./interface/IOwnable.sol";

abstract contract Ownable is OwnableInternal, IOwnableExternal {
    /*=============
        SETTERS
    =============*/

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        _startOwnershipTransfer(newOwner);
    }

    function acceptOwnership() public virtual {
        _acceptOwnership();
    }
}


// Chain: POLYGON - File: src/access/Access.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Permissions} from "./permissions/Permissions.sol";
import {PermissionsStorage} from "./permissions/PermissionsStorage.sol";
import {Operations} from "../lib/Operations.sol";

abstract contract Access is Permissions {
    // support multiple owner implementations, e.g. explicit storage vs NFT-owner (ERC-6551)
    function owner() public view virtual returns (address);

    function hasPermission(bytes8 operation, address account) public view override returns (bool) {
        // 3 tiers: has operation permission, has admin permission, or is owner
        if (super.hasPermission(operation, account)) {
            return true;
        }
        if (operation != Operations.ADMIN && super.hasPermission(Operations.ADMIN, account)) {
            return true;
        }
        return account == owner();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}


// Chain: POLYGON - File: src/cores/ERC1155/ERC1155.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC1155Receiver} from "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "./interface/IERC1155.sol";
import {ERC1155Storage} from "./ERC1155Storage.sol";

abstract contract ERC1155 is IERC1155 {

    /*==============
        METADATA
    ==============*/

    /// @dev require override
    function name() public view virtual returns (string memory);

    /// @dev require override
    function symbol() public view virtual returns (string memory);

    /// @dev require override
    function uri(uint256 tokenId) public view virtual returns (string memory);

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        // The interface IDs are constants representing the first 4 bytes
        // of the XOR of all function selectors in the interface.
        // See: [ERC165](https://eips.ethereum.org/EIPS/eip-165)
        // (e.g. `bytes4(i.functionA.selector ^ i.functionB.selector ^ ...)`)
        return interfaceId == 0x01ffc9a7 // ERC165 interface ID for ERC165.
            || interfaceId == 0xd9b67a26 // ERC165 Interface ID for ERC1155
            || interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*===========
        VIEWS
    ===========*/

    function balanceOf(address account, uint256 id) public view virtual returns (uint256) {
        return ERC1155Storage.layout().balances[id][account];
    }

    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual returns (uint256[] memory) {
        if (accounts.length != ids.length) {
            revert ERC1155InvalidArrayLength(ids.length, accounts.length);
        }

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    function isApprovedForAll(address account, address operator) public view virtual returns (bool) {
        return ERC1155Storage.layout().operatorApprovals[account][operator];
    }

    /*======================
        EXTERNAL SETTERS
    ======================*/

    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public virtual {
        _checkCanTransfer(from);
        _safeTransferFrom(from, to, id, value, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual {
        _checkCanTransfer(from);
        _safeBatchTransferFrom(from, to, ids, values, data);
    }

    /*======================
        INTERNAL SETTERS
    ======================*/

    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (operator == address(0)) {
            revert ERC1155InvalidOperator(address(0));
        }
        ERC1155Storage.layout().operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) internal {
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _safeBatchTransferFrom(from, to, ids, values, data);
    }

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

    function _mint(address to, uint256 id, uint256 value, bytes memory data) internal {
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _mintBatch(to, ids, values, data);
    }

    function _mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        _updateWithAcceptanceCheck(address(0), to, ids, values, data);
    }

    function _burn(address from, uint256 id, uint256 value) internal {
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _burnBatch(from, ids, values);
    }

    function _burnBatch(address from, uint256[] memory ids, uint256[] memory values) internal {
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        _updateWithAcceptanceCheck(from, address(0), ids, values, "");
    }

    function _updateWithAcceptanceCheck(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal virtual {
        _update(from, to, ids, values);
        if (to != address(0)) {
            address operator = msg.sender;
            if (ids.length == 1) {
                uint256 id = ids[0];
                uint256 value = values[0];
                _doSafeTransferAcceptanceCheck(operator, from, to, id, value, data);
            } else {
                _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, values, data);
            }
        }
    }

    /// @dev overriden from OZ by adding totalSupply math
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual {
        if (ids.length != values.length) {
            revert ERC1155InvalidArrayLength(ids.length, values.length);
        }
        ERC1155Storage.Layout storage layout = ERC1155Storage.layout();

        // check before
        (address guard, bytes memory beforeCheckData) = _beforeTokenTransfers(from, to, ids, values);

        address operator = msg.sender;

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 value = values[i];

            if (from != address(0)) {
                uint256 fromBalance = layout.balances[id][from];
                if (fromBalance < value) {
                    revert ERC1155InsufficientBalance(from, fromBalance, value, id);
                }
                layout.balances[id][from] = fromBalance - value;
            } else {
                // increase total supply if minting
                layout.totalSupply[id] += value;
            }

            if (to != address(0)) {
                layout.balances[id][to] += value;
            } else {
                // decrease total supply if burning
                layout.totalSupply[id] -= value;
            }
        }

        if (ids.length == 1) {
            uint256 id = ids[0];
            uint256 value = values[0];
            emit TransferSingle(operator, from, to, id, value);
        } else {
            emit TransferBatch(operator, from, to, ids, values);
        }

        // check after
        _afterTokenTransfers(guard, beforeCheckData);
    }

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

    /*====================
        AUTHORIZATION
    ====================*/

    function _checkCanTransfer(address from) internal virtual {
        if (from != msg.sender && !isApprovedForAll(from, msg.sender)) {
            revert ERC1155MissingApprovalForAll(msg.sender, from);
        }
    }
    
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

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual returns (address guard, bytes memory beforeCheckData);

    function _afterTokenTransfers(address guard, bytes memory checkBeforeData) internal virtual;
}


// Chain: POLYGON - File: src/cores/TokenMetadata/TokenMetadata.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ITokenMetadataExternal} from "./ITokenMetadata.sol";
import {TokenMetadataInternal} from "./TokenMetadataInternal.sol";
import {TokenMetadataStorage} from "./TokenMetadataStorage.sol";

abstract contract TokenMetadata is TokenMetadataInternal, ITokenMetadataExternal {
    /*===========
        VIEWS
    ===========*/

    /*=============
        SETTERS
    =============*/
    
    function setName(string calldata name_) external canUpdateTokenMetadata {
        _setName(name_);
    }
    
    function setSymbol(string calldata symbol_) external canUpdateTokenMetadata {
        _setSymbol(symbol_);
    }

    /*====================
        AUTHORIZATION
    ====================*/

    modifier canUpdateTokenMetadata() {
        _checkCanUpdateTokenMetadata();
        _;
    }

    function _checkCanUpdateTokenMetadata() internal view virtual;
}


// Chain: POLYGON - File: src/cores/TokenMetadata/TokenMetadataInternal.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ITokenMetadataInternal} from "./ITokenMetadata.sol";
import {TokenMetadataStorage} from "./TokenMetadataStorage.sol";

abstract contract TokenMetadataInternal is ITokenMetadataInternal {
    /*===========
        VIEWS
    ===========*/
    
    function name() public view virtual returns (string memory) {
        TokenMetadataStorage.Layout storage layout = TokenMetadataStorage.layout();
        return layout.name;
    }
    
    function symbol() public view virtual returns (string memory) {
        TokenMetadataStorage.Layout storage layout = TokenMetadataStorage.layout();
        return layout.symbol;
    }

    /*=============
        SETTERS
    =============*/
    
    function _setName(string calldata name_) internal {
        TokenMetadataStorage.layout().name = name_;
        emit NameUpdated(name_);
    }
    
    function _setSymbol(string calldata symbol_) internal {
        TokenMetadataStorage.layout().symbol = symbol_;
        emit SymbolUpdated(symbol_);
    }

    /*====================
        AUTHORIZATION
    ====================*/
}


// Chain: POLYGON - File: src/extension/examples/metadataRouter/IMetadataExtensions.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ITokenURIExtension {
    function ext_tokenURI(uint256 tokenId) external view returns (string memory);
}

interface IContractURIExtension {
    function ext_contractURI() external view returns (string memory);
}

interface IMetadataRouter {
    function tokenURI(address contractAddress, uint256 tokenId) external view returns (string memory);
    function contractURI(address contractAddress) external view returns (string memory);
}


// Chain: POLYGON - File: src/lib/Operations.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Operations {
    bytes8 constant ADMIN = 0xfd45ddde6135ec42; // hashOperation("ADMIN");
    bytes8 constant MINT = 0x38381131ea27ecba; // hashOperation("MINT");
    bytes8 constant BURN = 0xf951edb3fd4a16a3; // hashOperation("BURN");
    bytes8 constant TRANSFER = 0x5cc15eb80ba37777; // hashOperation("TRANSFER");
    bytes8 constant METADATA = 0x0e5de49ee56c0bd3; // hashOperation("METADATA");
    bytes8 constant PERMISSIONS = 0x96bbcfa480f6f1a8; // hashOperation("PERMISSIONS");
    bytes8 constant GUARDS = 0x53cbed5bdabf52cc; // hashOperation("GUARDS");
    bytes8 constant EXECUTE = 0xf01aff3887dcbbc6; // hashOperation("EXECUTE");
    bytes8 constant INTERFACE = 0x4a9bf2931aa5eae4; // hashOperation("INTERFACE");

    // TODO: deprecate and find another way versus anti-pattern
    // permits are enabling the permission, but only through set up modules/extension logic
    // e.g. someone can approve new members to mint, but cannot circumvent the module for taking payment
    bytes8 constant MINT_PERMIT = 0x0b6c53f325d325d3; // hashOperation("MINT_PERMIT");
    bytes8 constant BURN_PERMIT = 0x6801400fea7cd7c7; // hashOperation("BURN_PERMIT");
    bytes8 constant TRANSFER_PERMIT = 0xa994951607abf93b; // hashOperation("TRANSFER_PERMIT");
    bytes8 constant EXECUTE_PERMIT = 0x6c9e9b56de5e9f1c; // hashOperation("EXECUTE_PERMIT");

    function nameOperation(bytes8 operation) public pure returns (string memory name) {
        if (operation == ADMIN) {
            return "ADMIN";
        } else if (operation == MINT) {
            return "MINT";
        } else if (operation == BURN) {
            return "BURN";
        } else if (operation == TRANSFER) {
            return "TRANSFER";
        } else if (operation == METADATA) {
            return "METADATA";
        } else if (operation == PERMISSIONS) {
            return "PERMISSIONS";
        } else if (operation == GUARDS) {
            return "GUARDS";
        } else if (operation == EXECUTE) {
            return "EXECUTE";
        } else if (operation == INTERFACE) {
            return "INTERFACE";
        } else if (operation == MINT_PERMIT) {
            return "MINT_PERMIT";
        } else if (operation == BURN_PERMIT) {
            return "BURN_PERMIT";
        } else if (operation == TRANSFER_PERMIT) {
            return "TRANSFER_PERMIT";
        } else if (operation == EXECUTE_PERMIT) {
            return "EXECUTE_PERMIT";
        }
    }
}


// Chain: POLYGON - File: src/access/permissions/PermissionsStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

library PermissionsStorage {
    bytes32 internal constant SLOT = keccak256(abi.encode(uint256(keccak256("mage.Permissions")) - 1));

    struct Layout {
        uint256[] _permissionKeys;
        mapping(uint256 => PermissionData) _permissions;
    }

    struct PermissionData {
        uint24 index; //              [0..23]
        uint40 updatedAt; //          [24..63]
        bool exists; //              [64-71]
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }

    function _packKey(bytes8 operation, address account) internal pure returns (uint256) {
        // `operation` cast to uint64 to keep it on the small Endian side, packed with account to its left; leftmost 4 bytes remain empty
        return (uint256(uint64(operation)) | uint256(uint160(account)) << 64);
    }

    function _unpackKey(uint256 key) internal pure returns (bytes8 operation, address account) {
        operation = bytes8(uint64(key));
        account = address(uint160(key >> 64));
        return (operation, account);
    }

    function _hashOperation(string memory name) internal pure returns (bytes8) {
        return bytes8(keccak256(abi.encodePacked(name)));
    }
}


// Chain: POLYGON - File: src/cores/ERC1155/interface/IERC1155Mage.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC1155Mage {
    function mintTo(address recipient, uint256 tokenId, uint256 value) external;
    function burnFrom(address from, uint256 tokenId, uint256 value) external;
    function initialize(address owner, string calldata name, string calldata symbol, bytes calldata initData)
        external;
}


// Chain: POLYGON - File: src/lib/initializable/Initializable.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IInitializableInternal} from "./IInitializable.sol";
import {InitializableStorage} from "./InitializableStorage.sol";

abstract contract Initializable is IInitializableInternal {

    /*===========
        LOCK
    ===========*/
    
    /// @dev Logic implementation contract disables `initialize()` from being called 
    /// to prevent privilege escalation and 'exploding kitten' attacks  
    constructor() {
        _disableInitializers();
    }

    function _disableInitializers() internal virtual {
        InitializableStorage.Layout storage layout = InitializableStorage.layout();

        if (layout._initializing) {
            revert AlreadyInitialized();
        }
        if (layout._initialized == false) {
            layout._initialized = true;
            emit Initialized();
        }
    }
    
    /*===============
        MODIFIERS
    ===============*/

    modifier initializer() {
        InitializableStorage.Layout storage layout = InitializableStorage.layout();
        if (layout._initialized) {
            revert AlreadyInitialized();
        }
        layout._initializing = true;

        _;

        layout._initializing = false;
        layout._initialized = true;
        emit Initialized();
    }

    modifier onlyInitializing() {
        InitializableStorage.Layout storage layout = InitializableStorage.layout();
        if (!layout._initializing) {
            revert NotInitializing();
        }

        _;
    }

    /*===========
        VIEWS
    ===========*/

    function initialized() public view returns (bool) {
        InitializableStorage.Layout storage layout = InitializableStorage.layout();
        return layout._initialized;
    }
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822.sol";
import "../ERC1967/ERC1967Upgrade.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is IERC1822Proxiable, ERC1967Upgrade {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeTo(address newImplementation) public virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/utils/Multicall.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Multicall.sol)

pragma solidity ^0.8.0;

import "./Address.sol";

/**
 * @dev Provides a function to batch together multiple calls in a single external call.
 *
 * _Available since v4.1._
 */
abstract contract Multicall {
    /**
     * @dev Receives and executes a batch of function calls on this contract.
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), data[i]);
        }
        return results;
    }
}


// Chain: POLYGON - File: src/guard/Guards.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IGuards} from "./interface/IGuards.sol";
import {GuardsInternal} from "./GuardsInternal.sol";

abstract contract Guards is GuardsInternal {
    /*===========
        VIEWS
    ===========*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IGuards).interfaceId;
    }

    /*=============
        SETTERS
    =============*/

    /// @notice Due to EXTCODESIZE check within `_requireContract()`, this function will revert if called
    /// during the constructor of the contract at `implementation`. Deploy `implementation` contract first.
    function setGuard(bytes8 operation, address implementation) public virtual canUpdateGuards {
        _setGuard(operation, implementation);
    }

    function removeGuard(bytes8 operation) public virtual canUpdateGuards {
        _removeGuard(operation);
    }

    /*===================
        AUTHORIZATION
    ===================*/

    modifier canUpdateGuards() {
        _checkCanUpdateGuards();
        _;
    }

    function _checkCanUpdateGuards() internal virtual;
}


// Chain: POLYGON - File: src/extension/Extensions.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IExtensions} from "./interface/IExtensions.sol";
import {ExtensionsInternal} from "./ExtensionsInternal.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

abstract contract Extensions is ExtensionsInternal {
    /*==================
        CALL ROUTING
    ==================*/

    fallback(bytes calldata) external payable virtual returns (bytes memory) {
        address implementation = extensionOf(msg.sig);
        return Address.functionDelegateCall(implementation, msg.data); // library checks for target contract existence
    }

    receive() external payable virtual {}

    /*===========
        VIEWS
    ===========*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IExtensions).interfaceId;
    }

    /*=============
        SETTERS
    =============*/

    function setExtension(bytes4 selector, address implementation) public virtual canUpdateExtensions {
        _setExtension(selector, implementation);
    }

    function removeExtension(bytes4 selector) public virtual canUpdateExtensions {
        _removeExtension(selector);
    }

    /*===================
        AUTHORIZATION
    ===================*/

    modifier canUpdateExtensions() {
        _checkCanUpdateExtensions();
        _;
    }

    function _checkCanUpdateExtensions() internal virtual;
}


// Chain: POLYGON - File: src/lib/ERC165/SupportsInterface.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ISupportsInterfaceExternal} from "./ISupportsInterface.sol";
import {SupportsInterfaceInternal} from "./SupportsInterfaceInternal.sol";
import {SupportsInterfaceStorage} from "./SupportsInterfaceStorage.sol";

abstract contract SupportsInterface is SupportsInterfaceInternal, ISupportsInterfaceExternal {
    /*===========
        VIEWS
    ===========*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return _supportsInterface(interfaceId);
    }

    /*=============
        SETTERS
    =============*/
    
    function addInterface(bytes4 interfaceId) external virtual canUpdateInterfaces {
        _addInterface(interfaceId);
    }

    function removeInterface(bytes4 interfaceId) external virtual canUpdateInterfaces {
        _removeInterface(interfaceId);
    }

    /*====================
        AUTHORIZATION
    ====================*/

    modifier canUpdateInterfaces() {
        _checkCanUpdateInterfaces();
        _;
    }

    function _checkCanUpdateInterfaces() internal virtual;
}


// Chain: POLYGON - File: src/lib/Execute.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Address} from "openzeppelin-contracts/utils/Address.sol";

abstract contract Execute {
    event Executed(address indexed executor, address indexed to, uint256 value, bytes data);

    function execute(address to, uint256 value, bytes calldata data) public returns (bytes memory executeData) {
        _checkCanExecute();
        (address guard, bytes memory checkBeforeData) = _beforeExecute(to, value, data);
        executeData = Address.functionCallWithValue(to, data, value); // library checks for contract existence
        _afterExecute(guard, checkBeforeData, executeData);
        emit Executed(msg.sender, to, value, data);
        return executeData;
    }

    function _checkCanExecute() internal view virtual;

    function _beforeExecute(address to, uint256 value, bytes calldata data) internal virtual returns (address guard, bytes memory checkBeforeData);

    function _afterExecute(address guard, bytes memory checkBeforeData, bytes memory executeData) internal virtual;
}


// Chain: POLYGON - File: src/access/ownable/OwnableInternal.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IOwnableInternal} from "./interface/IOwnable.sol";
import {OwnableStorage} from "./OwnableStorage.sol";

abstract contract OwnableInternal is IOwnableInternal {
    /*===========
        VIEWS
    ===========*/

    function owner() public view virtual returns (address) {
        return OwnableStorage.layout().owner;
    }

    function pendingOwner() public view virtual returns (address) {
        return OwnableStorage.layout().pendingOwner;
    }

    /*=============
        SETTERS
    =============*/

    function _transferOwnership(address newOwner) internal virtual {
        OwnableStorage.Layout storage layout = OwnableStorage.layout();
        emit OwnershipTransferred(layout.owner, newOwner);
        layout.owner = newOwner;
        delete layout.pendingOwner;
    }

    function _startOwnershipTransfer(address newOwner) internal virtual {
        if (newOwner == address(0)) {
            revert OwnerInvalidOwner(address(0));
        }
        OwnableStorage.Layout storage layout = OwnableStorage.layout();
        layout.pendingOwner = newOwner;
        emit OwnershipTransferStarted(layout.owner, newOwner);
    }

    function _acceptOwnership() internal virtual {
        OwnableStorage.Layout storage layout = OwnableStorage.layout();
        address newOwner = layout.pendingOwner;
        if (newOwner != msg.sender) {
            revert OwnerUnauthorizedAccount(msg.sender);
        }
        _transferOwnership(newOwner);
    }

    /*===================
        AUTHORIZATION
    ===================*/

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnerUnauthorizedAccount(msg.sender);
        }
    }
}


// Chain: POLYGON - File: src/access/ownable/interface/IOwnable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

interface IOwnableInternal {
    // events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    // errors
    error OwnerUnauthorizedAccount(address account);
    error OwnerInvalidOwner(address owner);

    // views
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
}

interface IOwnableExternal {
    // setters
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
    function acceptOwnership() external;
}

interface IOwnable is IOwnableInternal, IOwnableExternal {}


// Chain: POLYGON - File: src/access/permissions/Permissions.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPermissions} from "./interface/IPermissions.sol";
import {PermissionsInternal} from "./PermissionsInternal.sol";
import {PermissionsStorage as Storage} from "./PermissionsStorage.sol";

abstract contract Permissions is PermissionsInternal {
    /*===========
        VIEWS
    ===========*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IPermissions).interfaceId;
    }

    /*=============
        SETTERS
    =============*/

    function addPermission(bytes8 operation, address account) public virtual {
        _checkCanUpdatePermissions();
        _addPermission(operation, account);
    }

    function removePermission(bytes8 operation, address account) public virtual {
        if (account != msg.sender) {
            _checkCanUpdatePermissions();
        }
        _removePermission(operation, account);
    }

    /*===================
        AUTHORIZATION
    ===================*/

    function _checkCanUpdatePermissions() internal virtual;
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol
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


// Chain: POLYGON - File: src/cores/ERC1155/interface/IERC1155.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC1155 {
    // events
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    // errors, EIP6903 compliant
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);
    error ERC1155InvalidSender(address sender);
    error ERC1155InvalidReceiver(address receiver);
    error ERC1155MissingApprovalForAll(address operator, address owner);
    error ERC1155InvalidApprover(address approver);
    error ERC1155InvalidOperator(address operator);
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);

    // metadata
    function uri(uint256 id) external view returns (string memory);

    // views
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);
    function isApprovedForAll(address account, address operator) external view returns (bool);

    // setters
    function setApprovalForAll(address operator, bool approved) external;
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// Chain: POLYGON - File: src/cores/ERC1155/ERC1155Storage.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library ERC1155Storage {
    bytes32 internal constant SLOT = keccak256(abi.encode(uint256(keccak256("mage.ERC1155")) - 1));

    struct Layout {
        // id => account => balance
        mapping(uint256 => mapping(address => uint256)) balances;
        // account => operator => t/f
        mapping(address => mapping(address => bool)) operatorApprovals;
        // id => supply
        mapping(uint256 => uint256) totalSupply;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: src/cores/TokenMetadata/ITokenMetadata.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ITokenMetadataInternal {
    // events
    event NameUpdated(string name);
    event SymbolUpdated(string symbol);

    // errors

    // views
    function name() external view returns (string calldata);
    function symbol() external view returns (string calldata);
}

interface ITokenMetadataExternal {
    // setters
    function setName(string calldata name) external;
    function setSymbol(string calldata symbol) external;
}

interface ITokenMetadata is ITokenMetadataInternal, ITokenMetadataExternal {}


// Chain: POLYGON - File: src/cores/TokenMetadata/TokenMetadataStorage.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library TokenMetadataStorage {
    bytes32 internal constant SLOT = keccak256(abi.encode(uint256(keccak256("mage.TokenMetadata")) - 1));

    struct Layout {
        string name;
        string symbol;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: src/lib/initializable/IInitializable.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IInitializableInternal {
    // events
    event Initialized();

    // errors
    error AlreadyInitialized();
    error NotInitializing();
    error CannotInitializeWhileConstructing();

    // views
    function initialized() external view returns (bool);
}

interface IInitializable is IInitializableInternal {}


// Chain: POLYGON - File: src/lib/initializable/InitializableStorage.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library InitializableStorage {
    bytes32 internal constant SLOT = keccak256(abi.encode(uint256(keccak256("mage.Initializable")) - 1));

    struct Layout {
        bool _initialized;
        bool _initializing;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/interfaces/draft-IERC1822.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeacon.sol";
import "../../interfaces/IERC1967.sol";
import "../../interfaces/draft-IERC1822.sol";
import "../../utils/Address.sol";
import "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 */
abstract contract ERC1967Upgrade is IERC1967 {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data, bool forceCall) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(address newBeacon, bytes memory data, bool forceCall) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}


// Chain: POLYGON - File: src/guard/interface/IGuards.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IGuardsInternal {
    struct Guard {
        bytes8 operation;
        address implementation;
        uint40 updatedAt;
    }

    // events
    event GuardUpdated(bytes8 indexed operation, address indexed oldGuard, address indexed newGuard);

    // errors
    error GuardDoesNotExist(bytes8 operation);
    error GuardUnchanged(bytes8 operation, address oldImplementation, address newImplementation);
    error GuardRejected(bytes8 operation, address guard);
}

/// @notice Since the Solidity compiler ignores inherited functions, function declarations are made
/// at the top level so their selectors are properly XORed into a nonzero `interfaceId`
interface IGuards is IGuardsInternal {
    // IGuardsInternal views
    function checkGuardBefore(bytes8 operation, bytes calldata data) external view returns (address guard, bytes memory checkBeforeData);
    function checkGuardAfter(address guard, bytes calldata checkBeforeData, bytes calldata executionData) external view;
    function guardOf(bytes8 operation) external view returns (address implementation);
    function getAllGuards() external view returns (Guard[] memory Guards);
    // external setters
    function setGuard(bytes8 operation, address implementation) external;
    function removeGuard(bytes8 operation) external;
}


// Chain: POLYGON - File: src/guard/GuardsInternal.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IGuards} from "./interface/IGuards.sol";
import {IGuard} from "./interface/IGuard.sol";
import {GuardsStorage} from "./GuardsStorage.sol";
import {Contract} from "../lib/Contract.sol";

abstract contract GuardsInternal is IGuards {
    using GuardsStorage for address;
    /*===========
        HOOKS
    ===========*/

    function checkGuardBefore(bytes8 operation, bytes memory data) public view returns (address guard, bytes memory checkBeforeData) {
        guard = guardOf(operation); 
        if (guard.autoReject()) {
            revert GuardRejected(operation, guard);
        } else if (guard.autoApprove()) {
            return (guard, "");
        }

        checkBeforeData = IGuard(guard).checkBefore(msg.sender, data); // revert will cascade

        return (guard, checkBeforeData);
    }

    function checkGuardAfter(address guard, bytes memory checkBeforeData, bytes memory executionData) public view {
        // only check guard if not autoApprove, autoReject will have already reverted
        if (!guard.autoApprove()) {
            IGuard(guard).checkAfter(checkBeforeData, executionData); // revert will cascade
        }
    }

    /*===========
        VIEWS
    ===========*/

    function guardOf(bytes8 operation) public view returns (address implementation) {
        GuardsStorage.Layout storage layout = GuardsStorage.layout();
        return layout._guards[operation].implementation;
    }

    function getAllGuards() public view virtual returns (Guard[] memory guards) {
        GuardsStorage.Layout storage layout = GuardsStorage.layout();
        uint256 len = layout._operations.length;
        guards = new Guard[](len);
        for (uint256 i; i < len; i++) {
            bytes8 operation = layout._operations[i];
            GuardsStorage.GuardData memory guard = layout._guards[operation];
            guards[i] = Guard(operation, guard.implementation, guard.updatedAt);
        }
        return guards;
    }

    /*=============
        SETTERS
    =============*/

    function _setGuard(bytes8 operation, address implementation) internal {
        GuardsStorage.Layout storage layout = GuardsStorage.layout();
        // require implementation is contract unless it is MAX_ADDRESS
        if (implementation != GuardsStorage.MAX_ADDRESS) {
            Contract._requireContract(implementation); // fails on adding address(0) here
        }

        GuardsStorage.GuardData memory oldGuard = layout._guards[operation];
        if (oldGuard.implementation != address(0)) {
            // update

            if (implementation == oldGuard.implementation) {
                revert GuardUnchanged(operation, oldGuard.implementation, implementation);
            }
            GuardsStorage.GuardData memory newGuard =
                GuardsStorage.GuardData(uint24(oldGuard.index), uint40(block.timestamp), implementation);
            layout._guards[operation] = newGuard;
        } else {
            // add

            // new length will be `len + 1`, so this guard has index `len`
            GuardsStorage.GuardData memory guard =
                GuardsStorage.GuardData(uint24(layout._operations.length), uint40(block.timestamp), implementation);
            layout._guards[operation] = guard;
            layout._operations.push(operation); // set new operation at index and increment length
        }

        emit GuardUpdated(operation, oldGuard.implementation, implementation);
    }

    function _removeGuard(bytes8 operation) internal {
        GuardsStorage.Layout storage layout = GuardsStorage.layout();
        GuardsStorage.GuardData memory oldGuard = layout._guards[operation];
        if (oldGuard.implementation == address(0)) revert GuardDoesNotExist(operation);

        uint256 lastIndex = layout._operations.length - 1;
        // if removing extension not at the end of the array, swap extension with last in array
        if (oldGuard.index < lastIndex) {
            bytes8 lastOperation = layout._operations[lastIndex];
            GuardsStorage.GuardData memory lastGuard = layout._guards[lastOperation];
            lastGuard.index = oldGuard.index;
            layout._operations[oldGuard.index] = lastOperation;
            layout._guards[lastOperation] = lastGuard;
        }
        delete layout._guards[operation];
        layout._operations.pop(); // delete guard in last index and decrement length

        emit GuardUpdated(operation, oldGuard.implementation, address(0));
    }
}


// Chain: POLYGON - File: src/extension/interface/IExtensions.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IExtensionsInternal {
    struct Extension {
        bytes4 selector;
        address implementation;
        uint40 updatedAt;
        string signature;
    }

    // events
    event ExtensionUpdated(bytes4 indexed selector, address indexed oldExtension, address indexed newExtension);

    // errors
    error ExtensionDoesNotExist(bytes4 selector);
    error ExtensionAlreadyExists(bytes4 selector);
    error ExtensionUnchanged(bytes4 selector, address oldImplementation, address newImplementation);
}

/// @notice Since the Solidity compiler ignores inherited functions, function declarations are made
/// at the top level so their selectors are properly XORed into a nonzero `interfaceId`
interface IExtensions is IExtensionsInternal {
    // IExtensionsInternal views
    function extensionOf(bytes4 selector) external view returns (address implementation);
    function getAllExtensions() external view returns (Extension[] memory extensions);
    // external setters
    function setExtension(bytes4 selector, address implementation) external;
    function removeExtension(bytes4 selector) external;
}


// Chain: POLYGON - File: src/extension/ExtensionsInternal.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IExtensions} from "./interface/IExtensions.sol";
import {IExtension} from "./interface/IExtension.sol";
import {ExtensionsStorage} from "./ExtensionsStorage.sol";
import {Contract} from "../lib/Contract.sol";

abstract contract ExtensionsInternal is IExtensions {
    /*===========
        VIEWS
    ===========*/

    function hasExtended(bytes4 selector) public view virtual returns (bool) {
        ExtensionsStorage.Layout storage layout = ExtensionsStorage.layout();
        return layout._extensions[selector].implementation != address(0);
    }

    function extensionOf(bytes4 selector) public view virtual returns (address implementation) {
        ExtensionsStorage.Layout storage layout = ExtensionsStorage.layout();
        return layout._extensions[selector].implementation;
    }

    function getAllExtensions() public view virtual returns (Extension[] memory extensions) {
        ExtensionsStorage.Layout storage layout = ExtensionsStorage.layout();
        uint256 len = layout._selectors.length;
        extensions = new Extension[](len);
        for (uint256 i; i < len; i++) {
            bytes4 selector = layout._selectors[i];
            ExtensionsStorage.ExtensionData memory extension = layout._extensions[selector];
            extensions[i] = Extension(
                selector,
                extension.implementation,
                extension.updatedAt,
                IExtension(extension.implementation).signatureOf(selector)
            );
        }
        return extensions;
    }

    /*=============
        SETTERS
    =============*/

    function _setExtension(bytes4 selector, address implementation) internal {
        ExtensionsStorage.Layout storage layout = ExtensionsStorage.layout();
        Contract._requireContract(implementation);
        ExtensionsStorage.ExtensionData memory oldExtension = layout._extensions[selector];
        address oldImplementation = oldExtension.implementation;
        if (oldImplementation != address(0)) {
            // update existing Extension, reverting if `implementation` is unchanged
            if (implementation == oldImplementation) {
                revert ExtensionUnchanged(selector, oldImplementation, implementation);
            }

            // update only necessary struct members to save on SSTOREs
            layout._extensions[selector].updatedAt = uint40(block.timestamp);
            layout._extensions[selector].implementation = implementation;
        } else {
            // add new Extension
            // new length will be `len + 1`, so this extension has index `len`
            ExtensionsStorage.ExtensionData memory extension = 
                ExtensionsStorage.ExtensionData(
                    uint24(layout._selectors.length), 
                    uint40(block.timestamp), 
                    implementation
                ); 

            layout._extensions[selector] = extension;
            layout._selectors.push(selector); // set new selector at index and increment length
        }

        emit ExtensionUpdated(selector, oldImplementation, implementation);
    }

    function _removeExtension(bytes4 selector) internal {
        ExtensionsStorage.Layout storage layout = ExtensionsStorage.layout();
        ExtensionsStorage.ExtensionData memory oldExtension = layout._extensions[selector];
        if (oldExtension.implementation == address(0)) revert ExtensionDoesNotExist(selector);

        uint256 lastIndex = layout._selectors.length - 1;
        // if removing extension not at the end of the array, swap extension with last in array
        if (oldExtension.index < lastIndex) {
            bytes4 lastSelector = layout._selectors[lastIndex];
            ExtensionsStorage.ExtensionData memory lastExtension = layout._extensions[lastSelector];
            lastExtension.index = oldExtension.index;
            layout._selectors[oldExtension.index] = lastSelector;
            layout._extensions[lastSelector] = lastExtension;
        }
        delete layout._extensions[selector];
        layout._selectors.pop(); // delete extension in last index and decrement length

        emit ExtensionUpdated(selector, oldExtension.implementation, address(0));
    }
}


// Chain: POLYGON - File: src/lib/ERC165/ISupportsInterface.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ISupportsInterfaceInternal {
    // events
    event InterfaceAdded(bytes4 indexed interfaceId);
    event InterfaceRemoved(bytes4 indexed interfaceId);

    // errors
    error InterfaceAlreadyAdded(bytes4 interfaceId);
    error InterfaceNotAdded(bytes4 interfaceId);
}

interface ISupportsInterfaceExternal {
    // views
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    // setters
    function addInterface(bytes4 interfaceId) external;
    function removeInterface(bytes4 interfaceId) external;
}

interface ISupportsInterface is ISupportsInterfaceInternal, ISupportsInterfaceExternal {}


// Chain: POLYGON - File: src/lib/ERC165/SupportsInterfaceInternal.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ISupportsInterfaceInternal} from "./ISupportsInterface.sol";
import {SupportsInterfaceStorage} from "./SupportsInterfaceStorage.sol";

abstract contract SupportsInterfaceInternal is ISupportsInterfaceInternal {

    /// @dev For explicit EIP165 compliance, the interfaceId of the standard IERC165 implementation
    /// which is derived from `bytes4(keccak256('supportsInterface(bytes4)'))` 
    /// is stored directly as a constant in order to preserve Mage's ERC7201 namespace pattern
    bytes4 public constant erc165Id = 0x01ffc9a7;

    /*===========
        VIEWS
    ===========*/

    /// @dev To remain EIP165 compliant, this function must not be called with `bytes4(type(uint32).max)`
    /// Setting `0xffffffff` as true by providing it as `interfaceId` will disable support of EIP165 in child contracts 
    function _supportsInterface(bytes4 interfaceId) internal view returns (bool) {
        SupportsInterfaceStorage.Layout storage layout = SupportsInterfaceStorage.layout();
        return interfaceId == erc165Id || layout._supportsInterface[interfaceId];
    }

    /*=============
        SETTERS
    =============*/

    function _addInterface(bytes4 interfaceId) internal {
        SupportsInterfaceStorage.Layout storage layout = SupportsInterfaceStorage.layout();
        if (layout._supportsInterface[interfaceId]) revert InterfaceAlreadyAdded(interfaceId);
        layout._supportsInterface[interfaceId] = true;
    }

    function _removeInterface(bytes4 interfaceId) internal {
        SupportsInterfaceStorage.Layout storage layout = SupportsInterfaceStorage.layout();
        if (!layout._supportsInterface[interfaceId]) revert InterfaceNotAdded(interfaceId);
        delete layout._supportsInterface[interfaceId];
    }

    /*====================
        AUTHORIZATION
    ====================*/
}


// Chain: POLYGON - File: src/lib/ERC165/SupportsInterfaceStorage.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library SupportsInterfaceStorage {
    bytes32 internal constant SLOT = keccak256(abi.encode(uint256(keccak256("mage.SupportsInterface")) - 1));

    struct Layout {
        mapping(bytes4 => bool) _supportsInterface;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: src/access/ownable/OwnableStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

library OwnableStorage {
    bytes32 internal constant SLOT = keccak256(abi.encode(uint256(keccak256("mage.Owner")) - 1));

    struct Layout {
        address owner;
        address pendingOwner;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }
}


// Chain: POLYGON - File: src/access/permissions/interface/IPermissions.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PermissionsStorage} from "../PermissionsStorage.sol";

interface IPermissionsInternal {
    struct Permission {
        bytes8 operation;
        address account;
        uint40 updatedAt;
    }

    // events
    event PermissionAdded(bytes8 indexed operation, address indexed account);
    event PermissionRemoved(bytes8 indexed operation, address indexed account);

    // errors
    error PermissionAlreadyExists(bytes8 operation, address account);
    error PermissionDoesNotExist(bytes8 operation, address account);
}

/// @notice Since the Solidity compiler ignores inherited functions, function declarations are made
/// at the top level so their selectors are properly XORed into a nonzero `interfaceId`
interface IPermissions is IPermissionsInternal {
    // IPermissionsInternal views
    function hashOperation(string memory name) external view returns (bytes8);
    function hasPermission(bytes8 operation, address account) external view returns (bool);
    function getAllPermissions() external view returns (Permission[] memory permissions);
    // external setters
    function addPermission(bytes8 operation, address account) external;
    function removePermission(bytes8 operation, address account) external;
}


// Chain: POLYGON - File: src/access/permissions/PermissionsInternal.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPermissions} from "./interface/IPermissions.sol";
import {PermissionsStorage as Storage} from "./PermissionsStorage.sol";

abstract contract PermissionsInternal is IPermissions {
    /*===========
        VIEWS
    ===========*/

    function hashOperation(string memory name) public pure returns (bytes8) {
        return Storage._hashOperation(name);
    }

    function hasPermission(bytes8 operation, address account) public view virtual returns (bool) {
        Storage.PermissionData memory permission = Storage.layout()._permissions[Storage._packKey(operation, account)];
        return permission.exists;
    }

    function getAllPermissions() public view returns (Permission[] memory permissions) {
        Storage.Layout storage layout = Storage.layout();
        uint256 len = layout._permissionKeys.length;
        permissions = new Permission[](len);
        for (uint256 i; i < len; i++) {
            uint256 permissionKey = layout._permissionKeys[i];
            (bytes8 operation, address account) = Storage._unpackKey(permissionKey);
            Storage.PermissionData memory permission = layout._permissions[permissionKey];
            permissions[i] = Permission(operation, account, permission.updatedAt);
        }
        return permissions;
    }

    /*=============
        SETTERS
    =============*/

    function _addPermission(bytes8 operation, address account) internal {
        Storage.Layout storage layout = Storage.layout();
        uint256 permissionKey = Storage._packKey(operation, account);
        if (layout._permissions[permissionKey].exists) {
            revert PermissionAlreadyExists(operation, account);
        }
        // new length will be `len + 1`, so this permission has index `len`
        Storage.PermissionData memory permission =
            Storage.PermissionData(uint24(layout._permissionKeys.length), uint40(block.timestamp), true);

        layout._permissions[permissionKey] = permission;
        layout._permissionKeys.push(permissionKey); // set new permissionKey at index and increment length

        emit PermissionAdded(operation, account);
    }

    function _removePermission(bytes8 operation, address account) internal {
        Storage.Layout storage layout = Storage.layout();
        uint256 permissionKey = Storage._packKey(operation, account);
        Storage.PermissionData memory oldPermissionData = layout._permissions[permissionKey];
        if (!oldPermissionData.exists) {
            revert PermissionDoesNotExist(operation, account);
        }

        uint256 lastIndex = layout._permissionKeys.length - 1;
        // if removing item not at the end of the array, swap item with last in array
        if (oldPermissionData.index < lastIndex) {
            uint256 lastPermissionKey = layout._permissionKeys[lastIndex];
            Storage.PermissionData memory lastPermissionData = layout._permissions[lastPermissionKey];
            lastPermissionData.index = oldPermissionData.index;
            layout._permissionKeys[oldPermissionData.index] = lastPermissionKey;
            layout._permissions[lastPermissionKey] = lastPermissionData;
        }
        delete layout._permissions[permissionKey];
        layout._permissionKeys.pop(); // delete guard in last index and decrement length

        emit PermissionRemoved(operation, account);
    }

    /*===================
        AUTHORIZATION
    ===================*/

    modifier onlyPermission(bytes8 operation) {
        _checkPermission(operation, msg.sender);
        _;
    }

    function _checkPermission(bytes8 operation, address account) internal view {
        if (!hasPermission(operation, account)) revert PermissionDoesNotExist(operation, account);
    }
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol
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


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/interfaces/IERC1967.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC1967.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 *
 * _Available since v4.8.3._
 */
interface IERC1967 {
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);
}


// Chain: POLYGON - File: lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.0;

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
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, `uint256`._
 * _Available since v4.9 for `string`, `bytes`._
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


// Chain: POLYGON - File: src/guard/interface/IGuard.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IGuard {
    function checkBefore(address operator, bytes calldata data) external view returns (bytes memory checkBeforeData);
    function checkAfter(bytes calldata checkBeforeData, bytes calldata executionData) external view;
}


// Chain: POLYGON - File: src/guard/GuardsStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

library GuardsStorage {
    bytes32 internal constant SLOT = keccak256(abi.encode(uint256(keccak256("mage.Guards")) - 1));
    address internal constant MAX_ADDRESS = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;

    struct Layout {
        bytes8[] _operations;
        mapping(bytes8 => GuardData) _guards;
    }

    struct GuardData {
        uint24 index; //           [0..23]
        uint40 updatedAt; //       [24..63]
        address implementation; // [64..223]
    }
    // thought: add parameters `bool useBefore` and `bool useAfter` to configure if a guard should use both checks or just one

    enum CheckType {
        BEFORE,
        AFTER
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }

    function autoReject(address guard) internal pure returns (bool) {
        return guard == MAX_ADDRESS;
    }

    function autoApprove(address guard) internal pure returns (bool) {
        return guard == address(0);
    }
}


// Chain: POLYGON - File: src/lib/Contract.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Address} from "openzeppelin-contracts/utils/Address.sol";

library Contract {
    error InvalidContract(address implementation);

    function _requireContract(address implementation) internal view {
        if (!Address.isContract(implementation)) revert InvalidContract(implementation);
    }
}


// Chain: POLYGON - File: src/extension/interface/IExtension.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IExtension {
    function signatureOf(bytes4 selector) external pure returns (string memory signature);
    function getAllSelectors() external pure returns (bytes4[] memory selectors);
    function getAllSignatures() external pure returns (string[] memory signatures);
}


// Chain: POLYGON - File: src/extension/ExtensionsStorage.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

library ExtensionsStorage {
    bytes32 internal constant SLOT = keccak256(abi.encode(uint256(keccak256("mage.Extensions")) - 1));

    struct Layout {
        bytes4[] _selectors;
        mapping(bytes4 => ExtensionData) _extensions;
    }

    struct ExtensionData {
        uint24 index; //           [0..23]
        uint40 updatedAt; //       [24..63]
        address implementation; // [64..223]
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }
}