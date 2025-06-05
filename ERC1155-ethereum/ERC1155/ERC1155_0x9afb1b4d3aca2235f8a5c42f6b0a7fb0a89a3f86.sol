// File: @openzeppelin/contracts/security/ReentrancyGuard.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
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
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
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


// File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol
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


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


// File: @openzeppelin/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

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


// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol
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


// File: @openzeppelin/contracts/utils/Address.sol
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


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol
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


// File: contracts/AA.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./interfaces/IAA.sol";
import {IWETH, IERC20} from "./interfaces/IWETH.sol";
import "./interfaces/IIntentHelper.sol";
import "./interfaces/IIntentManager.sol";

contract AA is IAA, IERC1155Receiver, IERC721Receiver, ReentrancyGuard {
    using Address for address;
    using Address for address payable;

    // solhint-disable-next-line var-name-mixedcase
    address public immutable WETH;
    IIntentManager public immutable intentManager;

    uint8 private _initialized;
    uint80 public taxUnclaimed;
    address public admin;

    struct ExecContext {
        uint256 preETH;
        uint256 preWETH;
        uint256 gasAmended;
        uint256 gasUnwrap;
        uint256 tax;
        uint256 taxPoint;
        uint256 taxThreshold;
        address taxRecipient;
    }

    modifier initializer() {
        require(_initialized < 1, "AA: already initialized");
        _initialized = 1;
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "AA: not admin");
        _;
    }

    receive() external payable {}

    // solhint-disable-next-line var-name-mixedcase
    constructor(address _WETH, IIntentManager _intentManager) {
        WETH = _WETH;
        intentManager = _intentManager;
        _initialized = 1;
    }

    function initialize(address _admin) external initializer {
        admin = _admin;
    }

    function initialize(address _operator, address _admin, uint256 _outerGas) external initializer {
        uint256 preGas = gasleft();
        admin = _admin;
        unchecked {
            payable(_operator).sendValue((preGas + _outerGas - gasleft()) * tx.gasprice);
        }
    }

    function handleIntent(Intent calldata intent, bytes32[] calldata proofs) external nonReentrant {
        uint256 preGas = gasleft();

        ExecContext memory ctx = ExecContext(
            address(this).balance,
            IWETH(WETH).balanceOf(address(this)),
            0,
            0,
            0,
            0,
            0,
            address(0)
        );

        address helper;
        (helper, ctx.taxThreshold, ctx.taxRecipient, ctx.gasAmended, ctx.gasUnwrap) = intentManager
            .verifyForHandle(intent.intentId, msg.sender, proofs);
        unchecked {
            preGas += ctx.gasAmended;
        }

        if (ctx.preWETH < intent.ensureMinimumWETH) {
            unchecked {
                _wrapETH(intent.ensureMinimumWETH - ctx.preWETH);
            }
        }

        IIntentHelper.Call[] memory calls;
        (ctx.taxPoint, calls) = IIntentHelper(helper).parse(intent.params);
        uint256 size = calls.length;
        for (uint256 i = 0; i < size; ++i) {
            IIntentHelper.Call memory call = calls[i];
            call.target.functionCallWithValue(call.data, call.value, "AA: call failed");
            if (call.gas < 0) {
                preGas -= uint256(-call.gas);
            } else if (call.gas > 0) {
                preGas += uint256(call.gas);
            }
        }

        (uint256 postETH, uint256 postWETH) = _updateTax(ctx);

        uint256 taxAmount = taxUnclaimed;

        require(postETH + postWETH >= taxAmount, "AA: insufficient funds for fee");
        emit BotAAIntentHandled(msg.sender, address(this), intent.intentId, ctx.tax);

        unchecked {
            uint256 maxGasCost = (preGas - gasleft() + ctx.gasUnwrap) * tx.gasprice;
            if (postETH < (maxGasCost + taxAmount) && postWETH > 0) {
                _unwrapWETH(postWETH);
                postETH = address(this).balance;
            }

            if (taxAmount > 0 && taxAmount >= ctx.taxThreshold) {
                taxUnclaimed = 0;
                _sendEther(ctx.taxRecipient, taxAmount);
            }
            _sendEther(msg.sender, (preGas - gasleft()) * tx.gasprice);
        }
    }

    function _updateTax(
        ExecContext memory ctx
    ) internal returns (uint256 postETH, uint256 postWETH) {
        postETH = address(this).balance;
        postWETH = IWETH(WETH).balanceOf(address(this));
        if (ctx.taxPoint > 0) {
            unchecked {
                uint256 postTotal = postETH + postWETH;
                uint256 preTotal = ctx.preETH + ctx.preWETH;
                ctx.tax =
                    ((preTotal > postTotal ? (preTotal - postTotal) : (postTotal - preTotal)) *
                        ctx.taxPoint) /
                    10000;
            }
            require(ctx.tax <= type(uint80).max, "AA: tax overflow");
        }
        if (ctx.tax > 0) {
            taxUnclaimed += uint80(ctx.tax);
        }
    }

    function operatorSafeWithdraw(
        address token,
        uint256 amount,
        bytes32[] calldata proofs
    ) external nonReentrant {
        uint256 preGas = gasleft();

        // unwrapp all
        uint256 balWETH = IWETH(WETH).balanceOf(address(this));
        if (balWETH > 0) {
            _unwrapWETH(balWETH);
        }

        (address recipient, uint32 gasAmended) = intentManager.verifyForWithdraw(
            msg.sender,
            proofs
        );

        // send tax
        uint256 taxAmount = taxUnclaimed;
        if (taxAmount > 0) {
            taxUnclaimed = 0;
            _sendEther(recipient, taxAmount);
        }

        uint256 gasCost;
        // send token
        unchecked {
            if (token == address(0) || token == address(WETH)) {
                uint256 available = address(this).balance;
                gasCost = (preGas + gasAmended - gasleft()) * tx.gasprice;
                if (available <= gasCost) {
                    available = 0;
                } else {
                    available -= gasCost;
                }
                if (amount > available) {
                    amount = available;
                }
                require(amount > 0, "AA: no withdrawable funds");
                _sendEther(admin, amount);
                emit BotAAOperatorWithdrawn(msg.sender, admin, address(0), amount);
            } else {
                IWETH(token).transfer(admin, amount);
                emit BotAAOperatorWithdrawn(msg.sender, admin, token, amount);

                gasCost = (preGas + gasAmended - gasleft()) * tx.gasprice;
            }
        }

        // pay gas
        _sendEther(msg.sender, gasCost);
    }

    function adminWithdraw(address token, uint256 amount) external onlyAdmin nonReentrant {
        // regardless of threshold
        uint256 taxAmount = taxUnclaimed;
        if (taxAmount > 0) {
            if (address(this).balance < taxAmount) {
                uint256 balWETH = IWETH(WETH).balanceOf(address(this));
                if (balWETH > 0) {
                    _unwrapWETH(balWETH);
                }
            }

            taxUnclaimed = 0;
            _sendEther(intentManager.getTaxRecipient(), taxAmount);
        }

        if (token != address(0) && token != address(WETH)) {
            IWETH(token).transfer(msg.sender, amount);
            emit BotAAAdminWithdrawn(msg.sender, token, amount);
        } else {
            if (address(this).balance < amount) {
                uint256 balWETH = IWETH(WETH).balanceOf(address(this));
                if (balWETH > 0) {
                    _unwrapWETH(balWETH);
                }
                if (address(this).balance < amount) {
                    amount = address(this).balance;
                }
            }
            require(amount > 0, "AA: no withdrawable funds");
            _sendEther(msg.sender, amount);
            emit BotAAAdminWithdrawn(msg.sender, address(0), amount);
        }
    }

    function tokenBalance(address token) public view returns (uint256) {
        if (token != address(0) && token != address(WETH)) {
            return IWETH(token).balanceOf(address(this));
        } else {
            uint256 balance = IWETH(WETH).balanceOf(address(this)) + address(this).balance;
            return (balance <= taxUnclaimed) ? 0 : (balance - taxUnclaimed);
        }
    }

    function claimTax() external nonReentrant {
        uint256 taxAmount = taxUnclaimed;
        require(taxAmount > 0, "AA: no tax");
        uint256 balETH = address(this).balance;
        if (balETH < taxAmount) _unwrapWETH(taxAmount - balETH);
        taxUnclaimed = 0;
        address recipient = intentManager.getTaxRecipient();
        _sendEther(recipient, taxAmount);

        emit BotAATaxClaimed(msg.sender, recipient, taxAmount);
    }

    function _sendEther(address to, uint256 amount) internal {
        if (amount == 0) return;
        payable(to).sendValue(amount);
    }

    function _unwrapWETH(uint256 amount) internal {
        WETH.functionCall(
            abi.encodeWithSelector(IWETH.withdraw.selector, amount),
            "AA: unwrap WETH failed"
        );
    }

    function _wrapETH(uint256 amount) internal {
        WETH.functionCallWithValue(
            abi.encodeWithSelector(IWETH.deposit.selector),
            amount,
            "AA: wrap ETH failed"
        );
    }

    function adminWithdraw721(
        address[] calldata tokenAddresses,
        uint256[] calldata tokenIds
    ) external onlyAdmin nonReentrant {
        for (uint256 i = 0; i < tokenAddresses.length; ++i) {
            IERC721(tokenAddresses[i]).transferFrom(address(this), msg.sender, tokenIds[i]);
        }
        emit BotAAAdminWithdrawn721(msg.sender, tokenAddresses, tokenIds);
    }

    function adminWithdraw1155(
        address tokenAddress,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyAdmin nonReentrant {
        IERC1155(tokenAddress).safeBatchTransferFrom(address(this), msg.sender, ids, amounts, "");
        emit BotAAAdminWithdrawn1155(msg.sender, tokenAddress, ids, amounts);
    }

    function operatorSafeWithdraw721(
        address[] calldata tokenAddresses,
        uint256[] calldata tokenIds,
        bytes32[] calldata proofs
    ) external nonReentrant {
        require(intentManager.isAAOperator(msg.sender, proofs), "AA: not allowed");
        for (uint256 i = 0; i < tokenAddresses.length; ++i) {
            IERC721(tokenAddresses[i]).transferFrom(address(this), admin, tokenIds[i]);
        }
        emit BotAAOperatorWithdrawn721(msg.sender, admin, tokenAddresses, tokenIds);
    }

    function operatorSafeWithdraw1155(
        address tokenAddress,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes32[] calldata proofs
    ) external nonReentrant {
        require(intentManager.isAAOperator(msg.sender, proofs), "AA: not allowed");
        IERC1155(tokenAddress).safeBatchTransferFrom(address(this), admin, ids, amounts, "");
        emit BotAAOperatorWithdrawn1155(msg.sender, admin, tokenAddress, ids, amounts);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return (interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId);
    }

    event BotAAAdminWithdrawn(address indexed admin, address indexed token, uint256 amount);
    event BotAAAdminWithdrawn721(
        address indexed admin,
        address[] tokenAddresses,
        uint256[] tokenIds
    );
    event BotAAAdminWithdrawn1155(
        address indexed admin,
        address indexed tokenAddress,
        uint256[] ids,
        uint256[] amounts
    );

    event BotAAOperatorWithdrawn(
        address indexed operator,
        address indexed recipient,
        address indexed token,
        uint256 amount
    );
    event BotAAOperatorWithdrawn721(
        address indexed operator,
        address indexed recipient,
        address[] tokenAddresses,
        uint256[] tokenIds
    );
    event BotAAOperatorWithdrawn1155(
        address indexed operator,
        address indexed recipient,
        address indexed tokenAddress,
        uint256[] ids,
        uint256[] amounts
    );
    event BotAATaxClaimed(address indexed user, address indexed recipient, uint256 amount);

    event BotAAIntentHandled(
        address indexed operator,
        address indexed aa,
        uint256 indexed intentId,
        uint256 tax
    );
}


// File: contracts/interfaces/IAA.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAA {
    struct Intent {
        uint256 intentId;
        uint256 ensureMinimumWETH;
        bytes params;
    }

    function initialize(address admin) external;

    function initialize(address operator, address admin, uint256 outerGas) external;

    function handleIntent(Intent calldata intent, bytes32[] calldata) external;
}


// File: contracts/interfaces/IIntentHelper.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IIntentHelper {
    struct Call {
        address target;
        uint256 value;
        bytes data;
        int256 gas;
    }

    // Keep it mutable
    function parse(bytes calldata params) external returns (uint256 taxPoint, Call[] memory calls);
}


// File: contracts/interfaces/IIntentManager.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IIntentManager {
    function getValidHelper(uint256) external view returns (address);

    function verifyForDeploy(
        address account,
        bytes32[] calldata proofs
    ) external view returns (uint32);

    function verifyForHandle(
        uint256 id,
        address account,
        bytes32[] calldata proofs
    ) external view returns (address, uint80, address, uint32, uint32);

    function verifyForWithdraw(
        address account,
        bytes32[] calldata proofs
    ) external view returns (address, uint32);

    function getTaxRecipient() external view returns (address);

    function isAAOperator(address, bytes32[] calldata) external view returns (bool);

    function isAdmin(address account) external view returns (bool);

    function getTaxPoints(
        address[] calldata tokenAddresses
    ) external view returns (bool[] memory isCustom, uint256[] memory taxPoints);
}


// File: contracts/interfaces/IWETH.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint) external;
}


