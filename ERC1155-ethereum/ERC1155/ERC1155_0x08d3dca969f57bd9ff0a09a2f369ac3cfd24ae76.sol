// File: src/extensions/ExtensionsDraw.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC1155Burnable} from "../interfaces/IERC1155Burnable.sol";
import {IERC1155Transfer} from "../interfaces/IERC1155Transfer.sol";
import {IERC721Transfer} from "../interfaces/IERC721Transfer.sol";
import {IERC20Transfer} from "../interfaces/IERC20Transfer.sol";

import {Ownable} from "solady/src/auth/Ownable.sol";

interface IExtensions is IERC1155Burnable, IERC1155Transfer {}

struct Submission {
    address owner;
    uint96 balance;
}

contract ExtensionsDraw is Ownable {
    error SubmissionsPaused();
    error InvalidExtensionId();
    error InvalidQuantity();
    error ArrayLengthMismatch();
    error NoSubmissionForUser();
    error CantRecoverSubmittedTokens();
    error NotTokenSubmission();

    event Winners(uint256 indexed extensionId, uint256 indexed round, address[] winners);

    IExtensions public immutable EXTENSIONS;

    uint248 public validTokenIds;
    bool public submissionEnabled;

    // Current round for each extension
    mapping(uint256 => uint256) public currentRound;

    // Users committed to extension mapping
    mapping(uint256 => Submission[]) public submissionsByExtension;

    // Mapping of user => extension id => submission index
    mapping(address => mapping(uint256 => uint256)) private submissionIndex;

    constructor(address extensions) {
        EXTENSIONS = IExtensions(extensions);
        _initializeOwner(tx.origin);

        currentRound[1] = 4; // 3 video extensions already allocated
        currentRound[2] = 2; // 2 music extensions already allocated
        currentRound[3] = 3; // 2 toy extensions already allocated
        currentRound[4] = 1; // 0 game extensions already allocated

        validTokenIds = 15;
    }

    /**
     * @notice Submit an extension to the contract for drawing in the next round. Extensions must be
     * approved for transfer by the contract.
     * @param extensionId The ID of the extension to submit.
     * @param quantity The quantity of the extension to submit.
     */
    function submit(uint256 extensionId, uint96 quantity) external {
        if (!submissionEnabled) {
            revert SubmissionsPaused();
        }

        createOrUpdateSubmission(extensionId, quantity);

        EXTENSIONS.safeTransferFrom(msg.sender, address(this), extensionId, quantity, "");
    }

    function batchSubmit(uint256[] calldata extensionIds, uint256[] calldata quantities) external {
        if (!submissionEnabled) {
            revert SubmissionsPaused();
        }

        uint256 length = extensionIds.length;
        if (length != quantities.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i; i < length;) {
            createOrUpdateSubmission(extensionIds[i], uint96(quantities[i]));

            unchecked {
                ++i;
            }
        }

        EXTENSIONS.safeBatchTransferFrom(msg.sender, address(this), extensionIds, quantities, "");
    }

    function createOrUpdateSubmission(uint256 extensionId, uint96 quantity) private {
        if (!isValidTokenId(extensionId)) {
            revert InvalidExtensionId();
        }
        if (quantity == 0) {
            revert InvalidQuantity();
        }

        uint256 userSubmissionIndex = submissionIndex[msg.sender][extensionId];
        unchecked {
            if (userSubmissionIndex == 0) {
                submissionsByExtension[extensionId].push(Submission(msg.sender, quantity));
                uint256 newIndex = submissionsByExtension[extensionId].length;
                // storing 1 based index to delineate between first item and no item in the array
                submissionIndex[msg.sender][extensionId] = newIndex;
            } else {
                // use the 1 based index to get the submission from the array
                Submission storage submission =
                    submissionsByExtension[extensionId][userSubmissionIndex - 1];
                submission.balance = uint96(submission.balance + quantity);
            }
        }
    }

    /**
     * @notice Revoke all submissions for a specific extension id. The user must have a submission
     * for the extension. All tokens will be returned to the user.
     * @param extensionId The ID of the extension to revoke.
     */
    function revokeSubmission(uint256 extensionId) external {
        uint256 balance = removeUserSubmission(extensionId);
        EXTENSIONS.safeTransferFrom(address(this), msg.sender, extensionId, balance, "");
    }

    function batchRevokeSubmissions(uint256[] calldata extensionIds) external {
        uint256 length = extensionIds.length;
        uint256[] memory balances = new uint256[](length);
        for (uint256 i; i < length;) {
            uint256 extensionId = extensionIds[i];
            balances[i] = removeUserSubmission(extensionId);
            unchecked {
                ++i;
            }
        }

        EXTENSIONS.safeBatchTransferFrom(address(this), msg.sender, extensionIds, balances, "");
    }

    function removeUserSubmission(uint256 extensionId) private returns (uint256) {
        if (!isValidTokenId(extensionId)) {
            revert InvalidExtensionId();
        }
        uint256 rawSubmissionIndex = submissionIndex[msg.sender][extensionId];
        if (rawSubmissionIndex == 0) {
            revert NoSubmissionForUser();
        }

        // user submission index is 1 based, so decrement to get the index in the array
        uint256 userSubmissionIndex = rawSubmissionIndex - 1;

        Submission[] storage submissions = submissionsByExtension[extensionId];
        uint256 balance = submissions[userSubmissionIndex].balance;

        if (rawSubmissionIndex < submissions.length) {
            submissions[userSubmissionIndex] = submissions[submissions.length - 1];
        }
        submissions.pop();
        // clear the submission index for the user
        delete submissionIndex[msg.sender][extensionId];

        return balance;
    }

    /**
     * @notice Set whether or not submissions are enabled for the contract.
     */
    function setSubmissionEnabled(bool enabled) external onlyOwner {
        submissionEnabled = enabled;
    }

    /**
     * @notice Enable a token id for submission.
     * @param tokenId The ID of the token to enable.
     */
    function enableTokenId(uint248 tokenId) external onlyOwner {
        if (tokenId > 255) {
            revert InvalidExtensionId();
        }
        if (!isValidTokenId(tokenId)) {
            currentRound[tokenId] = 1;
            validTokenIds |= uint248(1 << (tokenId - 1));
        }
    }

    /**
     * @dev Draw winners for a given extension ID. The number of winners drawn is the minimum of the
     * number of submissions and the maxWinners parameter.
     * @param extensionId The ID of the extension to draw winners for.
     * @param maxWinners The maximum number of winners to draw.
     */
    function draw(uint256 extensionId, uint256 maxWinners) external onlyOwner {
        if (maxWinners == 0) {
            revert InvalidQuantity();
        }
        Submission[] storage submissions = submissionsByExtension[extensionId];
        uint256 length = submissions.length;

        uint256 startIndex;
        if (length < maxWinners) {
            maxWinners = length;
        } else {
            startIndex = _random(length);
        }

        processDraw(extensionId, maxWinners, startIndex, submissions);

        EXTENSIONS.burn(address(this), extensionId, maxWinners);
    }

    /**
     * @dev Processes a draw for a given token ID, selecting `winners` number of winners from the
     * `submissions` array starting at `startIndex`. decrements the balance of each selected
     * submission by 1, and removes any submission with a balance of 0 from the array.
     * If a submission is removed, swaps it with the last element of the array and pops
     * it off the end. Emits a `Winner` event for each selected submission, containing the token ID,
     * the current extension round, and the owner of the submission.
     * @param tokenId The ID of the token for which to process the draw.
     * @param winners The number of winners to select from the submissions array.
     * @param startIndex The index of the first submission to consider in the submissions array.
     * @param submissions The array of submissions to select winners from.
     */
    function processDraw(
        uint256 tokenId,
        uint256 winners,
        uint256 startIndex,
        Submission[] storage submissions
    ) internal {
        unchecked {
            address[] memory winnersArray = new address[](winners);

            uint256 extensionRound = currentRound[tokenId];
            currentRound[tokenId] = extensionRound + 1;

            uint256 length = submissions.length;

            uint256 index = startIndex;
            for (uint256 i; i < winners;) {
                Submission memory submission = submissions[index];

                winnersArray[i] = submission.owner;
                // if the submission would be decremented to a balance of 0, swap in the last element
                // of the array and pop it off the end, otherwise decrement the balance
                if (submission.balance == 1) {
                    // clear the submission index for the user
                    delete submissionIndex[submission.owner][tokenId];

                    --length;

                    if (index < length) {
                        Submission memory lastItem = submissions[length];
                        submissions[index] = lastItem;
                        submissionIndex[lastItem.owner][tokenId] = (index + 1);
                    }
                    submissions.pop();
                } else {
                    submissions[index].balance = submission.balance - 1;
                    ++index;
                }

                ++i;
                if (index >= length) {
                    index = 0;
                }
            }

            emit Winners(tokenId, extensionRound, winnersArray);
        }
    }

    /**
     * @notice Returns the submission index of a user for a given token ID.
     * @param user The address of the user.
     * @param tokenId The ID of the token.
     * @return index of the user's submission record for the given token ID.
     */
    function getSubmissionIndex(address user, uint256 tokenId) external view returns (uint256) {
        uint256 index = submissionIndex[user][tokenId];
        if (index == 0) {
            revert NoSubmissionForUser();
        }
        return index - 1;
    }

    /**
     * @notice Returns an array of all submissions for a given token ID.
     * @param tokenId The ID of the token.
     * @return submissions for the given token ID.
     */
    function getAllSubmissions(uint256 tokenId) external view returns (Submission[] memory) {
        return submissionsByExtension[tokenId];
    }

    /**
     * @notice Generates a random number between 0 and max (exclusive).
     * @param max The maximum value of the random number (exclusive).
     * @return random number between 0 and max (exclusive).
     */
    function _random(uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % max;
    }

    /**
     * @notice Checks if a given token ID is valid.
     * @param tokenId The ID of the token.
     * @return True if the token ID is valid, false otherwise.
     */
    function isValidTokenId(uint256 tokenId) internal view returns (bool) {
        if (tokenId == 0) {
            return false;
        }

        return (1 << (tokenId - 1) & validTokenIds) != 0;
    }

    function recoverERC721(address token, uint256 tokenId) external onlyOwner {
        IERC721Transfer(token).transferFrom(address(this), msg.sender, tokenId);
    }

    function recoverERC20(address token, uint256 amount) external onlyOwner {
        IERC20Transfer(token).transfer(msg.sender, amount);
    }

    /**
     * @notice Handle the receipt of a single ERC1155 token type.
     * @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeTransferFrom` after the balance has been updated.
     * This function MUST return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` (i.e. 0xf23a6e61) if it accepts the transfer.
     * This function MUST revert if it rejects the transfer.
     * Return of any other value than the prescribed keccak256 generated value MUST result in the transaction being reverted by the caller.
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     */
    function onERC1155Received(address operator, address, uint256, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        if (operator != address(this)) {
            revert NotTokenSubmission();
        }
        return 0xf23a6e61;
    }

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external view returns (bytes4) {
        if (operator != address(this)) {
            revert NotTokenSubmission();
        }
        return 0xbc197c81;
    }
}


// File: src/interfaces/IERC1155Burnable.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC1155Burnable {
    function burn(address from, uint256 id, uint256 amount) external;
    function batchBurn(address from, uint256[] memory ids, uint256[] memory amounts) external;
}


// File: src/interfaces/IERC1155Transfer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC1155Transfer {
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;
    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external;
}


// File: src/interfaces/IERC721Transfer.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC721Transfer {
    function transferFrom(address, address, uint256) external;
}


// File: src/interfaces/IERC20Transfer.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20Transfer {
    function transfer(address, uint256) external;
}


// File: lib/solady/src/auth/Ownable.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple single owner authorization mixin.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/auth/Ownable.sol)
///
/// @dev Note:
/// This implementation does NOT auto-initialize the owner to `msg.sender`.
/// You MUST call the `_initializeOwner` in the constructor / initializer.
///
/// While the ownable portion follows
/// [EIP-173](https://eips.ethereum.org/EIPS/eip-173) for compatibility,
/// the nomenclature for the 2-step ownership handover may be unique to this codebase.
abstract contract Ownable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev The `newOwner` cannot be the zero address.
    error NewOwnerIsZeroAddress();

    /// @dev The `pendingOwner` does not have a valid handover request.
    error NoHandoverRequest();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ownership is transferred from `oldOwner` to `newOwner`.
    /// This event is intentionally kept the same as OpenZeppelin's Ownable to be
    /// compatible with indexers and [EIP-173](https://eips.ethereum.org/EIPS/eip-173),
    /// despite it not being as lightweight as a single argument event.
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /// @dev An ownership handover to `pendingOwner` has been requested.
    event OwnershipHandoverRequested(address indexed pendingOwner);

    /// @dev The ownership handover to `pendingOwner` has been canceled.
    event OwnershipHandoverCanceled(address indexed pendingOwner);

    /// @dev `keccak256(bytes("OwnershipTransferred(address,address)"))`.
    uint256 private constant _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE =
        0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0;

    /// @dev `keccak256(bytes("OwnershipHandoverRequested(address)"))`.
    uint256 private constant _OWNERSHIP_HANDOVER_REQUESTED_EVENT_SIGNATURE =
        0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d;

    /// @dev `keccak256(bytes("OwnershipHandoverCanceled(address)"))`.
    uint256 private constant _OWNERSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE =
        0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The owner slot is given by: `not(_OWNER_SLOT_NOT)`.
    /// It is intentionally chosen to be a high value
    /// to avoid collision with lower slots.
    /// The choice of manual storage layout is to enable compatibility
    /// with both regular and upgradeable contracts.
    uint256 private constant _OWNER_SLOT_NOT = 0x8b78c6d8;

    /// The ownership handover slot of `newOwner` is given by:
    /// ```
    ///     mstore(0x00, or(shl(96, user), _HANDOVER_SLOT_SEED))
    ///     let handoverSlot := keccak256(0x00, 0x20)
    /// ```
    /// It stores the expiry timestamp of the two-step ownership handover.
    uint256 private constant _HANDOVER_SLOT_SEED = 0x389a75e1;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Initializes the owner directly without authorization guard.
    /// This function must be called upon initialization,
    /// regardless of whether the contract is upgradeable or not.
    /// This is to enable generalization to both regular and upgradeable contracts,
    /// and to save gas in case the initial owner is not the caller.
    /// For performance reasons, this function will not check if there
    /// is an existing owner.
    function _initializeOwner(address newOwner) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Clean the upper 96 bits.
            newOwner := shr(96, shl(96, newOwner))
            // Store the new value.
            sstore(not(_OWNER_SLOT_NOT), newOwner)
            // Emit the {OwnershipTransferred} event.
            log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, 0, newOwner)
        }
    }

    /// @dev Sets the owner directly without authorization guard.
    function _setOwner(address newOwner) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            let ownerSlot := not(_OWNER_SLOT_NOT)
            // Clean the upper 96 bits.
            newOwner := shr(96, shl(96, newOwner))
            // Emit the {OwnershipTransferred} event.
            log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(ownerSlot), newOwner)
            // Store the new value.
            sstore(ownerSlot, newOwner)
        }
    }

    /// @dev Throws if the sender is not the owner.
    function _checkOwner() internal view virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // If the caller is not the stored owner, revert.
            if iszero(eq(caller(), sload(not(_OWNER_SLOT_NOT)))) {
                mstore(0x00, 0x82b42900) // `Unauthorized()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Returns how long a two-step ownership handover is valid for in seconds.
    /// Override to return a different value if needed.
    /// Made internal to conserve bytecode. Wrap it in a public function if needed.
    function _ownershipHandoverValidFor() internal view virtual returns (uint64) {
        return 48 * 3600;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  PUBLIC UPDATE FUNCTIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Allows the owner to transfer the ownership to `newOwner`.
    function transferOwnership(address newOwner) public payable virtual onlyOwner {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(shl(96, newOwner)) {
                mstore(0x00, 0x7448fbae) // `NewOwnerIsZeroAddress()`.
                revert(0x1c, 0x04)
            }
        }
        _setOwner(newOwner);
    }

    /// @dev Allows the owner to renounce their ownership.
    function renounceOwnership() public payable virtual onlyOwner {
        _setOwner(address(0));
    }

    /// @dev Request a two-step ownership handover to the caller.
    /// The request will automatically expire in 48 hours (172800 seconds) by default.
    function requestOwnershipHandover() public payable virtual {
        unchecked {
            uint256 expires = block.timestamp + _ownershipHandoverValidFor();
            /// @solidity memory-safe-assembly
            assembly {
                // Compute and set the handover slot to `expires`.
                mstore(0x0c, _HANDOVER_SLOT_SEED)
                mstore(0x00, caller())
                sstore(keccak256(0x0c, 0x20), expires)
                // Emit the {OwnershipHandoverRequested} event.
                log2(0, 0, _OWNERSHIP_HANDOVER_REQUESTED_EVENT_SIGNATURE, caller())
            }
        }
    }

    /// @dev Cancels the two-step ownership handover to the caller, if any.
    function cancelOwnershipHandover() public payable virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and set the handover slot to 0.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, caller())
            sstore(keccak256(0x0c, 0x20), 0)
            // Emit the {OwnershipHandoverCanceled} event.
            log2(0, 0, _OWNERSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE, caller())
        }
    }

    /// @dev Allows the owner to complete the two-step ownership handover to `pendingOwner`.
    /// Reverts if there is no existing ownership handover requested by `pendingOwner`.
    function completeOwnershipHandover(address pendingOwner) public payable virtual onlyOwner {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and set the handover slot to 0.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, pendingOwner)
            let handoverSlot := keccak256(0x0c, 0x20)
            // If the handover does not exist, or has expired.
            if gt(timestamp(), sload(handoverSlot)) {
                mstore(0x00, 0x6f5e8818) // `NoHandoverRequest()`.
                revert(0x1c, 0x04)
            }
            // Set the handover slot to 0.
            sstore(handoverSlot, 0)
        }
        _setOwner(pendingOwner);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   PUBLIC READ FUNCTIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the owner of the contract.
    function owner() public view virtual returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := sload(not(_OWNER_SLOT_NOT))
        }
    }

    /// @dev Returns the expiry timestamp for the two-step ownership handover to `pendingOwner`.
    function ownershipHandoverExpiresAt(address pendingOwner)
        public
        view
        virtual
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the handover slot.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, pendingOwner)
            // Load the handover slot.
            result := sload(keccak256(0x0c, 0x20))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MODIFIERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Marks a function as only callable by the owner.
    modifier onlyOwner() virtual {
        _checkOwner();
        _;
    }
}


