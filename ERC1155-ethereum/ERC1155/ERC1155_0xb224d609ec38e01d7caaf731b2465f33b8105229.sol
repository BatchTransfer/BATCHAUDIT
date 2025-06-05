// File: HouseOfPanda.sol
pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

/**
 *
 * This contract is a part of the House of Panda project.
 *
 * House of Panda is an NFT-based real estate investment platform that gives you access to high-yield, short-term loans.
 * This contract is built with BlackRoof engine.
 *
 */

import "SafeERC20.sol";

import "ICoin.sol";
import "ProjectInfo.sol";
import "HoldingInfo.sol";
import "StakeInfo.sol";
import "HasAdmin.sol";
import "SigVerifier.sol";
import "Staker.sol";

contract HouseOfPanda is
    ERC1155Tradable,
    IProjectMan,
    HasAdmin,
    SigVerifier,
    ReentrancyGuard
{
    using SafeERC20 for ICoin;
    using Strings for uint256;

    ICoin internal stableCoin;
    uint32 public projectIndex;
    IStaker public staker;

    mapping(uint32 => uint128) private _supplyFor;

    bool public paused = false;

    event ProjectCreated(uint32 indexed id);
    event ProjectStatusChanged(uint32 indexed projectId, bytes1 indexed status);
    event Mint(
        uint32 indexed projectId,
        uint128 indexed qty,
        address minter,
        address indexed to
    );
    event Burn(
        uint32 indexed projectId,
        uint128 indexed qty,
        address indexed burner
    );

    /**
     * Constructor for the HouseOfPanda contract, which inherits from the
     * ERC1155Tradable and Stake contracts.
     * Set the contract's base URI and proxy address and set the admin address.
     *
     * @param _admin The contract's admin address.
     * @param _baseUri The contract's base URI.
     * @param _stableCoin The address of the stablecoin for calculating rewards.
     * @param _proxyAddress The address of the proxy contract.
     */
    constructor(
        address _admin,
        string memory _baseUri,
        address _stableCoin,
        IStaker _staker,
        address _proxyAddress
    ) ERC1155Tradable("House of Panda", "HOPNFT", _baseUri, _proxyAddress) {
        _staker.setProjectMan(address(this));
        staker = _staker;
        stableCoin = ICoin(_stableCoin);
        _setAdmin(_admin);
    }

    function changeAdmin(address newAdmin_) external onlyOwner {
        _setAdmin(newAdmin_);
    }

    modifier onlyAdminOrOwner() {
        require(_isAdmin(msg.sender) || _isOwner(msg.sender), "!admin !owner");
        _;
    }

    /**
     * This function checks if the parameter 'account' is the owner of the contract.
     * @param account The address of the account to be checked.
     * @return {bool} A boolean indicating whether the account is the owner or not.
     */
    function _isOwner(address account) internal view returns (bool) {
        return owner() == account;
    }

    function min(uint64 a, uint64 b) internal pure returns (uint64) {
        return a <= b ? a : b;
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
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
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        if (from == address(0) && to == address(0)) {
            return;
        }

        HoldingInfo memory holding;

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            ProjectInfo memory project = _getProject(uint32(id));

            // cannot be transferred while staking
            StakeInfo memory sti = staker.getStakingInfoRaw(from, uint32(id));
            if (sti.qty > 0) {
                require(balanceOf(from, uint32(id)) - amount >= sti.qty, "in staking");
            }

            uint64 prevStartTime = uint64(block.timestamp);

            if (from != address(0)) {
                holding = staker.getHoldingInfoRaw(from, uint32(id));

                // if already exists, then update holding info
                if (holding.qty > 0) {

                    uint64 endTime = min(uint64(block.timestamp), project.endTime);

                    holding.qty -= amount;
                    if (endTime > holding.startTime) {
                        holding.accumRewards += staker.calculateRewards(
                            holding.qty * project.price,
                            holding.startTime,
                            endTime,
                            project.apy // regular
                        );
                    }
                }

                prevStartTime = holding.startTime;

                holding.startTime = uint64(block.timestamp);

                // update holding info for `from`
                staker.setHoldingInfoData(from, uint32(id), holding);
            }

            if (to != address(0)) {
                // update holding info for `to`
                holding = staker.getHoldingInfoRaw(to, uint32(id));

                uint64 endTime = min(uint64(block.timestamp), project.endTime);

                if (holding.qty > 0 && endTime > holding.startTime) {
                    holding.accumRewards += staker.calculateRewards(
                        holding.qty * project.price,
                        holding.startTime,
                        endTime,
                        project.apy // regular
                    );
                }

                holding.qty += amount;
                holding.startTime = prevStartTime;

                staker.setHoldingInfoData(to, uint32(id), holding);
            }
        }
    }

    /**
     * @dev Creates a new project. This can only be done by the contract admin or owner.
     * @param typeId project type.
     * @param title Title of the project.
     * @param price Price to mint one NFT from this project (in wei). Cannot be zero if `authorizedOnly`=true.
     * @param authorizedOnly If true the project only mintable by admin.
     * @param supplyLimit Supply limit of the project. Minting will fail if max limit.
     * @param term Term of the project in months.
     * @param apy APY of the project.
     * @param stakedApy APY for staked NFT.
     * @param startTime Start time of the project.
     * @param endTime End time of the project.
     */
    function createProject(
        uint16 typeId,
        string memory title,
        uint256 price,
        bool authorizedOnly,
        uint128 supplyLimit,
        uint16 term,
        uint256 apy,
        uint256 stakedApy,
        uint64 startTime,
        uint64 endTime
    ) external onlyAdminOrOwner {
        if (authorizedOnly) {
            require(price > 0, "price=0");
        }
        require(term > 0 && term <= 60, "x term");

        uint32 pid = projectIndex + 1;
        ProjectInfo memory project = ProjectInfo({
            id: pid,
            title: title,
            creator: msg.sender,
            typeId: typeId,
            price: price,
            authorizedOnly: authorizedOnly,
            status: ACTIVE,
            supplyLimit: supplyLimit,
            term: term,
            apy: apy,
            stakedApy: stakedApy,
            startTime: startTime,
            endTime: endTime
        });
        _projects[pid] = project;
        projectIndex = pid;

        emit ProjectCreated(project.id);
    }

    function _exists(uint32 projectId) internal view returns (bool) {
        return _projects[projectId].id == projectId;
    }

    function projectExists(
        uint32 projectId
    ) public view override returns (bool) {
        return _exists(projectId);
    }

    function _getProject(
        uint32 projectId
    ) internal view returns (ProjectInfo memory) {
        require(projectId > 0, "!projectId");
        require(_projects[projectId].id == projectId, "!project");
        return _projects[projectId];
    }

    function getProject(
        uint32 projectId
    ) public view override returns (ProjectInfo memory) {
        return _getProject(projectId);
    }

    /**
     * @dev check is project exists
     */
    function _checkProject(ProjectInfo memory project) internal pure {
        require(project.id > 0, "!project");
    }

    /**
     * This function is used to set the status of a project.
     * The caller of this function must be either the owner or an admin of the
     * contract.
     * It takes in two parameters: the projectId and a bytes1 status.
     * It first checks to make sure the project exists, before setting the status
     * and emitting a ProjectStatusChanged event.
     *
     * @param projectId The ID of the project to set the status for.
     * @param status A bytes1 indicating the new status.
     */
    function setProjectStatus(
        uint32 projectId,
        bytes1 status
    ) external onlyAdminOrOwner {
        require(_exists(projectId), "!project");
        _projects[projectId].status = status;
        emit ProjectStatusChanged(projectId, status);
    }

    /**
     * @dev Mint NFT for specific project. This function demands the exact amount of price,
     *      except for the authorizedOnly project.
     * @param projectId Project id.
     * @param qty Quantity of NFTs to mint.
     */
    function mint(
        uint32 projectId,
        uint32 qty,
        address to
    ) external payable nonReentrant returns (bool) {
        require(!paused, "paused");
        ProjectInfo memory project = _projects[projectId];
        _checkProject(project);
        require(project.status == ACTIVE, "!active");
        require(project.startTime <= block.timestamp, "!start");
        require(project.endTime > block.timestamp, "!ended");

        address _sender = _msgSender();

        bool isAuthority = _isAdmin(_sender) || _isOwner(_sender);

        if (project.authorizedOnly) {
            require(isAuthority, "unauthorized");
        } else {
            require(
                isAuthority ||
                    stableCoin.balanceOf(_sender) >= qty * project.price,
                "balance <"
            );
        }

        // check max supply limit if configured (positive value).
        uint128 supply = _supplyFor[projectId];
        if (project.supplyLimit > 0) {
            require(supply + qty <= project.supplyLimit, "limit");
        }

        _supplyFor[projectId] += qty;

        // deduct stable coin from minter
        if (!project.authorizedOnly && !isAuthority) {
            stableCoin.safeTransferFrom(
                _sender,
                address(staker),
                qty * project.price
            );
        }

        _mint(to, projectId, qty, "");

        emit Mint(projectId, qty, _msgSender(), to);

        return true;
    }

    /**
     * @dev Permissioned version of mint, use signature for verification,
     *      Anyone with valid signature can mint NFTs.
     */
    function authorizedMint(
        uint32 projectId,
        uint32 qty,
        address to,
        uint64 nonce,
        Sig memory sig
    ) external payable nonReentrant returns (bool) {
        require(nonce >= uint64(block.timestamp) / 60, "x nonce");
        _checkAddress(to);

        // require payment
        ProjectInfo memory project = _projects[projectId];
        _checkProject(project);

        // check supply
        uint128 supply = _supplyFor[projectId];
        if (project.supplyLimit > 0) {
            require(supply + qty <= project.supplyLimit, "limit");
        }

        address _sender = _msgSender();

        bytes32 message = sigPrefixed(
            keccak256(abi.encodePacked(projectId, _sender, to, qty, nonce))
        );

        require(_isSigner(admin, message, sig), "x signature");

        bool isAuthority = _isAdmin(_sender) || _isOwner(_sender);

        require(
            isAuthority || stableCoin.balanceOf(_sender) >= qty * project.price,
            "balance <"
        );

        _supplyFor[projectId] += qty;

        // deduct stable coin from minter
        stableCoin.safeTransferFrom(
            _sender,
            address(this),
            qty * project.price
        );

        _mint(to, projectId, qty, "");

        emit Mint(projectId, qty, _sender, to);

        return true;
    }

    /**
     * @dev check supply for specific item.
     */
    function supplyFor(uint32 projectId) external view returns (uint128) {
        return _supplyFor[projectId];
    }

    /**
     * Returns the URI of a given project.
     * If the project has a custom URI (stored in the 'customUri' mapping),
     * the custom URI is returned. Otherwise, the default uri defined in the super
     * class is returned.
     *
     * @param _projectId The ID of the project.
     * @return {string} The URI of the project.
     */
    function uri(
        uint256 _projectId
    ) public view override returns (string memory) {
        require(_exists(uint32(_projectId)), "!project");
        // We have to convert string to bytes to check for existence
        bytes memory customUriBytes = bytes(customUri[_projectId]);
        if (customUriBytes.length > 0) {
            return customUri[_projectId];
        } else {
            // return super.uri(_projectId);
            string memory baseURI = super.uri(_projectId);
            return
                bytes(baseURI).length > 0
                    ? string(
                        abi.encodePacked(
                            baseURI,
                            _projectId.toString(),
                            ".json"
                        )
                    )
                    : "";
        }
    }

    function _checkAddress(address addr) private pure {
        require(addr != address(0), "x addr");
    }

    /**
     * This function is used to pause or unpause contract.
     * Caller of this function must be the owner of the contract.
     * It updates the paused state of the contract and calls the pause function of
     * the staker.
     * @param _paused A boolean indicating whether staking should be paused or
     * unpaused.
     */
    function pause(bool _paused) external onlyOwner {
        paused = _paused;
        staker.pause(_paused);
    }

    function _burnInternal(
        uint32 projectId,
        uint32 qty,
        address to
    ) private returns (bool) {
        _checkAddress(to);
        require(projectId > 0, "!projectId");
        require(qty > 0, "!qty");

        ProjectInfo memory project = _projects[projectId];
        _checkProject(project);

        // check max supply limit if configured (positive value).
        uint128 supply = _supplyFor[projectId];
        require(supply >= qty, "exceed supply");

        // cannot be burned while staking
        StakeInfo memory sti = staker.getStakingInfoRaw(to, projectId);
        if (sti.qty > 0) {
            require(balanceOf(to, projectId) - qty >= sti.qty, "in staking");
        }

        _supplyFor[projectId] -= qty;

        _burn(to, projectId, qty);

        if (project.authorizedOnly) {
            // do nothing
        } else {
            uint256 amount = qty * project.price;
            // payable(to).transfer(amount);
            stableCoin.safeTransferFrom(address(staker), to, amount);
        }

        emit Burn(projectId, qty, to);

        return true;
    }

    /**
     * @dev Burn NFT and claim back the mint price to the NFT owner.
     *      this will emit Burn event when success.
     * @param projectId Project id.
     * @param qty Quantity of NFTs to burn.
     */
    function burn(
        uint32 projectId,
        uint32 qty
    ) external nonReentrant returns (bool) {
        address _sender = _msgSender();
        uint256 _ownedQty = balanceOf(_sender, projectId);
        require(_ownedQty >= qty, "qty >");
        return _burnInternal(projectId, qty, _sender);
    }

    /**
     * @dev Burn NFT by admin and return the mint price to the NFT owner.
     *      Caller of this function must be admin.
     *      this will emit Burn event when success.
     * @param projectId Project id.
     * @param qty Quantity of NFTs to burn.
     * @param to the owner of the NFT to be burned.
     */
    function adminBurn(
        uint32 projectId,
        uint32 qty,
        address to
    ) external payable onlyAdmin nonReentrant returns (bool) {
        return _burnInternal(projectId, qty, to);
    }

    function getHoldingInfo(
        address account,
        uint32 projectId
    ) external view returns (HoldingInfo memory) {
        return staker.getHoldingInfo(account, uint32(projectId));
    }

    /**
     * This function is used to update contract staker.
     * It must be called by the owner of the contract. 
     * It checks that the staker's owner is the same as the contract's owner.
     * @param _staker address of the staker.
     */
    function updateStaker(address _staker) external onlyOwner {
        // check staker owner
        require(IStaker(_staker).owner() == this.owner(), "!owner");
        staker = IStaker(_staker);
    }

    /**
     * This function allows users to retrieve the asset allocation and staking
     * information of the given investor and project ID.
     * It takes in two parameters: 'investor' (the address of the investor) and
     * 'projectId' (the ID of the project).
     * It first checks to make sure the investor address is valid and that a valid
     * project ID was supplied.
     * It then retrieves the holding information and staking information of the
     * respective investor and project,
     * and returns a tuple containing both pieces of information.
     * 
     * @param investor The address of the investor.
     * @param projectId The ID of the project.
     * @return (HoldingInfo memory, StakeInfo memory) A tuple containing the asset
     * allocation and staking information of the investor and project.
     */
    function getAssetAlloc(address investor, uint32 projectId)
        external
        view
        returns (HoldingInfo memory, StakeInfo memory)
    {
        _checkAddress(investor);
        require(projectId > 0, "!projectId");
        HoldingInfo memory hld = staker.getHoldingInfo(investor, projectId);
        StakeInfo memory stk = staker.getStakingInfo(investor, projectId);
        return (hld, stk);
    }
}


// File: SafeERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC20.sol";
import "Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// File: IERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}


// File: Address.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
        return functionCall(target, data, "Address: low-level call failed");
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
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
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


// File: ICoin.sol
pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "ERC20.sol";

interface ICoin is IERC20, IERC20Metadata {}



// File: ERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC20.sol";
import "IERC20Metadata.sol";
import "Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}


// File: IERC20Metadata.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// File: Context.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
}


// File: ProjectInfo.sol
pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

/**
 *
 * This code is a part of the House of Panda project.
 *
 */

struct ProjectInfo {
    uint32 id;
    string title;
    address creator;
    uint16 typeId;
    uint256 price;
    bool authorizedOnly; // whether this should be created by authorization or not.
    bytes1 status; // 0 not active, 1 active, 2 market non availability, 3 closed, 4 paused.
    uint16 term; // term in months
    uint128 supplyLimit;
    uint256 apy; // regular APY
    uint256 stakedApy; // staked APY
    uint64 startTime; // start time where user can start mint/stake.
    uint64 endTime; // end time where user can no longer mint/stake, only unstake and collect rewards.
}



// File: HoldingInfo.sol
pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

/**
 *
 * This code is a part of the House of Panda project.
 *
 */


struct HoldingInfo {
    uint256 qty;
    uint64 startTime;
    uint256 accumRewards;
    uint256 claimedRewards;
}


// File: StakeInfo.sol
pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

/**
 *
 * This code is a part of the House of Panda project.
 *
 */

struct StakeInfo {
    uint32 qty;
    uint32 term; // term in months
    uint64 startTime;
    uint256 accumRewards;
    uint256 claimedRewards;
}


// File: HasAdmin.sol
pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

abstract contract IHasAdmin {
    // function admin() public virtual view returns (address);
    function _isAdmin(address account) internal virtual view returns (bool);
    function _setAdmin(address account) internal virtual;
}

contract HasAdmin is IHasAdmin {
    address public admin;

    event AdminChanged(address indexed admin);

    modifier onlyAdmin {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() private view {
        require(_isAdmin(msg.sender), "!admin");
    }

    // function admin() public override view returns(address) {
    //     return admin;
    // }

    function _setAdmin(address account) internal override {
        admin = account;
        emit AdminChanged(admin);
    }

    function _isAdmin(address account) internal override view returns(bool) {
        return account == admin;
    }

}


// File: SigVerifier.sol
pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

/**
 *
 * This code is part of HouseOfPanda project.
 *
 */

struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
}

abstract contract ISigVerifier {
    function sigPrefixed(bytes32 hash) internal virtual pure returns (bytes32);
    function _isSigner(
        address account,
        bytes32 message,
        Sig memory sig
    ) internal virtual pure returns (bool);
}

contract SigVerifier is ISigVerifier {
    function sigPrefixed(bytes32 hash) internal override pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function _isSigner(
        address account,
        bytes32 message,
        Sig memory sig
    ) internal override pure returns (bool) {
        return ecrecover(message, sig.v, sig.r, sig.s) == account;
    }
}


// File: Staker.sol
pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

/**
 *
 * This contract is a part of the House of Panda project.
 *
 * House of Panda is an NFT-based real estate investment platform that gives you access to high-yield, short-term loans.
 * This contract is built with BlackRoof engine.
 *
 */

import "ERC1155.sol";
import "SafeERC20.sol";
import "ReentrancyGuard.sol";
import "Ownable.sol";

import "ERC1155Tradable.sol";
import "ICoin.sol";
import "IProjectMan.sol";
import "ProjectInfo.sol";
import "HoldingInfo.sol";
import "StakeInfo.sol";
import "SigVerifier.sol";
import "HasAdmin.sol";

uint16 constant REWARD_TYPE_HOLDING = 1;
uint16 constant REWARD_TYPE_STAKING = 2;

interface IStaker {
    function setProjectMan(address _projectMan) external;

    function getHoldingInfo(
        address user,
        uint32 projectId
    ) external view returns (HoldingInfo memory);

    function getHoldingInfoRaw(
        address user,
        uint32 projectId
    ) external view returns (HoldingInfo memory);

    function setHoldingInfoData(
        address user,
        uint32 projectId,
        HoldingInfo memory holding
    ) external;

    function getStakingInfo(
        address _staker,
        uint32 projectId
    ) external view returns (StakeInfo memory);

    function getStakingInfoRaw(
        address user,
        uint32 projectId
    ) external view returns (StakeInfo memory);

    function calculateRewards(
        uint256 _amount,
        uint64 _startTime,
        uint64 _endTime,
        uint256 apy
    ) external pure returns (uint256 rewards);

    function collectRewards(uint32 projectId) external returns (bool);

    function pause(bool _paused) external;

    function owner() external view returns (address);
}

contract Staker is ReentrancyGuard, Ownable, HasAdmin, SigVerifier {
    using SafeERC20 for ICoin;

    IProjectMan internal projectMan;
    ICoin internal stableCoin;

    bool public paused = false;

    event StakeEvent(address indexed staker, uint256 amount);
    event CollectRewards(
        address indexed staker,
        uint32 indexed projectId,
        uint256 amount
    );
    event BalanceDeposit(address indexed who, uint256 indexed amount);
    event BalanceWithdraw(address indexed who, uint256 indexed amount);

    // user -> projectId -> StakeInfo
    mapping(address => mapping(uint32 => StakeInfo)) internal stakers;
    mapping(uint64 => uint8) internal usedNonce_;
    mapping(address => mapping(uint32 => HoldingInfo)) internal holdings;

    constructor(address _stableCoin, address _admin) {
        stableCoin = ICoin(_stableCoin);
        _setAdmin(_admin);

        // approve owner
        stableCoin.safeIncreaseAllowance(address(this), type(uint256).max);
    }

    modifier onlyProjectMan() {
        require(msg.sender == address(projectMan), "!projectMan");
        _;
    }

    function setProjectMan(address _projectMan) external {
        require(projectMan == IProjectMan(address(0)), "pm set");
        require(tx.origin == owner(), "!owner");
        projectMan = IProjectMan(_projectMan);
        stableCoin.safeIncreaseAllowance(_projectMan, type(uint256).max);
    }

    function _getProject(
        uint32 projectId
    ) internal view returns (ProjectInfo memory) {
        return projectMan.getProject(projectId);
    }

    function changeAdmin(address newAdmin_) external onlyOwner {
        _setAdmin(newAdmin_);
    }

    /**
     * @dev function to calculate rewards,
     *      rewards is progressive to 12% per year.
     * @param _amount amount of stable coin.
     * @param _startTime time when staking started.
     * @param _endTime time when staking ended.
     * @return rewards amount of rewards
     */
    function calculateRewards(
        uint256 _amount,
        uint64 _startTime,
        uint64 _endTime,
        uint256 apy
    ) public pure returns (uint256 rewards) {
        uint32 a_days = uint32((_endTime - _startTime) / 1 days);
        uint256 a_amount = (_amount * apy);
        rewards = (a_amount * a_days) / 365;
        return rewards / 100;
    }

    function stake(uint32 projectId, uint32 qty) external returns (bool) {
        require(!paused, "paused");
        require(qty > 0, "!qty");

        address _sender = msg.sender;

        ProjectInfo memory project = _getProject(projectId);

        _checkProject(project);
        require(project.status == ACTIVE, "!active");
        require(project.startTime <= block.timestamp, "!start");
        require(project.endTime > block.timestamp, "!ended");

        // check is user has enough NFT to stake
        require(
            IERC1155(address(projectMan)).balanceOf(_sender, projectId) >= qty,
            "balance <"
        );

        // update stake info
        StakeInfo memory staker = stakers[_sender][projectId];

        HoldingInfo memory hld = holdings[_sender][project.id];

        uint256 holdingRewards = _accumHoldingRewards(_sender, project, hld);

        // claim remaining holding rewards first if any
        if (holdingRewards > 0) {
            stableCoin.safeTransfer(_sender, holdingRewards);
            emit CollectRewards(_sender, projectId, holdingRewards);
        }

        uint64 endTime = min(uint64(block.timestamp), project.endTime);

        // update accum if already staked before
        if (staker.qty > 0 && staker.startTime < endTime) {
            staker.accumRewards += calculateRewards(
                staker.qty * project.price,
                staker.startTime,
                endTime,
                project.stakedApy
            );
        }

        staker.qty += qty;
        staker.startTime = uint64(block.timestamp);

        hld.qty -= qty;

        stakers[_sender][projectId] = staker;
        holdings[_sender][project.id] = hld;

        return true;
    }

    function max(uint64 a, uint64 b) internal pure returns (uint64) {
        return a >= b ? a : b;
    }

    function min(uint64 a, uint64 b) internal pure returns (uint64) {
        return a <= b ? a : b;
    }

    /**
     * @dev get user stake info.
     */
    function getStakingInfo(
        address _staker,
        uint32 projectId
    ) external view returns (StakeInfo memory) {
        StakeInfo memory _stakeInfo = stakers[_staker][projectId];
        ProjectInfo memory project = _getProject(projectId);
        uint64 endTime = min(uint64(block.timestamp), project.endTime);

        if (_stakeInfo.startTime > endTime) {
            return _stakeInfo;
        }

        _stakeInfo.accumRewards += calculateRewards(
            _stakeInfo.qty * project.price,
            _stakeInfo.startTime,
            endTime,
            project.stakedApy
        );
        return _stakeInfo;
    }

    function _projectEnd(
        ProjectInfo memory project
    ) internal view returns (bool) {
        return block.timestamp >= project.startTime + ((1 days) * project.term);
    }

    function isProjectEnd(uint32 id) external view returns (bool) {
        ProjectInfo memory project = _getProject(id);
        return _projectEnd(project);
    }

    function unstake(uint32 projectId, uint32 qty) external returns (bool) {
        require(!paused, "paused");
        require(qty > 0, "!qty");

        address _sender = msg.sender;

        ProjectInfo memory project = _getProject(projectId);
        require(project.status == ACTIVE, "!active");

        StakeInfo memory _stakerInfo = stakers[_sender][projectId];

        require(_stakerInfo.qty != 0, "!staker.qty");

        // check is user has enough staked amount to unstake
        require(_stakerInfo.qty >= qty, "qty >");

        // unable to unstake until project end
        require(_projectEnd(project), "!end");

        uint64 endsTime = min(uint64(block.timestamp), project.endTime);

        if (_stakerInfo.startTime < endsTime) {
            // update accum rewards
            _stakerInfo.accumRewards += calculateRewards(
                _stakerInfo.qty * project.price,
                _stakerInfo.startTime,
                endsTime,
                project.stakedApy
            );
        }

        _stakerInfo.qty -= qty;
        _stakerInfo.startTime = uint64(block.timestamp);

        stakers[_sender][projectId] = _stakerInfo;

        // update holding's qty
        HoldingInfo memory hld = holdings[_sender][project.id];
        hld.qty += qty;
        holdings[_sender][project.id] = hld;

        return true;
    }

    /**
     * This function allows the user to collect rewards from staking and holding
     * tokens in a given project.
     * It takes in two parameters: 'projectId' and 'rewardType'. It first checks to
     * make sure staking is not paused
     * and that a valid type of reward is specified. Afterward, it checks that the
     * project status is active and then
     * collects rewards. If the reward type indicates staking rewards, it calculates
     * the rewards earned,
     * updates the stake information and starts a new stake period. Afterwards, it
     * transfers the collected rewards
     * to the user and emits the CollectRewards event.
     *
     * @param projectId The ID of the project to collect rewards from.
     * @param rewardType {uint16} The type of reward to collect. Can be
     *                   REWARD_TYPE_HOLDING, REWARD_TYPE_STAKING or both.
     * @return {bool} Boolean indicating success.
     */
    function collectRewards(
        uint32 projectId,
        uint16 rewardType
    ) external nonReentrant returns (bool) {
        require(!paused, "paused");
        require(
            (rewardType & REWARD_TYPE_HOLDING) != 0 ||
                (rewardType & REWARD_TYPE_STAKING) != 0,
            "!type"
        );

        address _sender = msg.sender;

        ProjectInfo memory project = _getProject(projectId);
        require(project.status == ACTIVE, "!active");
        require(project.startTime <= block.timestamp, "!start");

        StakeInfo memory stk = stakers[_sender][projectId];

        uint256 _collectedTotal = 0;

        if ((rewardType & REWARD_TYPE_HOLDING) != 0) {
            // collect holding rewards
            HoldingInfo memory _holding = holdings[_sender][project.id];
            _collectedTotal = _accumHoldingRewards(_sender, project, _holding);
        }

        if ((rewardType & REWARD_TYPE_STAKING) != 0) {
            require(stk.qty > 0, "!staked");

            // if staked, then claim for staked rewards
            // update accum rewards
            uint64 endTime = min(uint64(block.timestamp), project.endTime);

            if (stk.startTime > endTime) {
                return false;
            }

            uint256 _accumRewards = stk.accumRewards;
            _accumRewards = calculateRewards(
                stk.qty * project.price,
                stk.startTime,
                endTime,
                project.stakedApy
            );

            stk.startTime = uint64(block.timestamp);
            stk.accumRewards = 0;
            stk.claimedRewards += _accumRewards;

            stakers[_sender][projectId] = stk;

            holdings[_sender][projectId].startTime = stk.startTime;

            _collectedTotal += _accumRewards;
        }

        // transfer rewards to user
        if (_collectedTotal > 0) {
            stableCoin.safeTransfer(_sender, _collectedTotal);
            emit CollectRewards(_sender, projectId, _collectedTotal);
            return true;
        }
        // stableCoin.safeTransfer(_sender, _accumRewards);

        return false;
    }

    /**
     * This function calculates the total accumulated rewards for a given user and
     * project.
     * It takes in an '_sender' address and 'project' object.
     * It then checks if the user has any tokens in holdings and calculates the
     * rewards accordingly.
     * Finally, it updates the holding information and returns the accumulated
     * rewards.
     *
     * @param _sender The address of the user who's rewards will be calculated.
     * @param project Project object containing project info.
     * @return {uint256} The total accumulated rewards for the given user and
     * project.
     */
    function _accumHoldingRewards(
        address _sender,
        ProjectInfo memory project,
        HoldingInfo memory hld
    ) private returns (uint256) {
        if (hld.qty == 0) {
            return 0;
        }

        uint64 endTime = min(uint64(block.timestamp), project.endTime);

        if (hld.startTime > endTime) {
            return 0;
        }

        uint256 _accumRewards = hld.accumRewards;

        _accumRewards += calculateRewards(
            hld.qty * project.price,
            hld.startTime,
            endTime,
            project.apy
        );
        hld.startTime = uint64(block.timestamp);
        hld.accumRewards = 0;
        hld.claimedRewards += _accumRewards;

        holdings[_sender][project.id] = hld;

        return _accumRewards;
    }

    /**
     * @dev Function to collect specific amount of rewards from project manually,
     *      rewards is calculated off-chain and need authorization signature to proceed.
     *      This procedure can work in paused state (for emergency purpose).
     * @param projectId the ID of project.
     * @param amount the amount of rewards to collect.
     * @param nonce the nonce of the signature.
     * @param sig the signature to authorize the transaction.
     */
    function collectRewardsBy(
        uint32 projectId,
        uint256 amount,
        uint64 nonce,
        Sig memory sig
    ) external nonReentrant returns (bool) {
        require(nonce >= uint64(block.timestamp) / 60, "x nonce");
        require(usedNonce_[nonce] == 0, "x nonce");

        ProjectInfo memory project = _getProject(projectId);

        require(project.id != 0, "!project");

        address _sender = msg.sender;

        StakeInfo memory stk = stakers[_sender][projectId];

        require(stk.qty != 0, "!staker.qty");

        // check signature
        bytes32 message = sigPrefixed(
            keccak256(abi.encodePacked(projectId, _sender, amount, nonce))
        );

        require(_isSigner(admin, message, sig), "x signature");

        usedNonce_[nonce] = 1;

        uint256 _accumRewards = stk.accumRewards;

        uint64 endTime = min(uint64(block.timestamp), project.endTime);

        // if (stk.startTime > endTime) {
        //     return false;
        // }

        _accumRewards += calculateRewards(
            stk.qty * project.price,
            stk.startTime,
            endTime,
            project.stakedApy
        );

        // amount must be less or equal to accumRewards
        require(amount <= _accumRewards, "x amount");

        stk.startTime = uint64(block.timestamp);
        stk.accumRewards = _accumRewards - amount;
        stk.claimedRewards += amount;

        stakers[_sender][projectId] = stk;

        // transfer rewards to staker
        stableCoin.safeTransfer(_sender, amount);

        emit CollectRewards(_sender, projectId, amount);

        return true;
    }

    /**
     * @dev check is project exists
     */
    function _checkProject(ProjectInfo memory project) internal pure {
        require(project.id > 0, "!project");
    }

    /**
     * @dev get holding information on project of user
     */
    function getHoldingInfo(
        address user,
        uint32 projectId
    ) external view returns (HoldingInfo memory) {
        HoldingInfo memory _holding = holdings[user][projectId];
        ProjectInfo memory project = _getProject(projectId);
        uint64 endTime = min(uint64(block.timestamp), project.endTime);

        if (_holding.startTime > endTime) {
            return _holding;
        }

        _holding.accumRewards += calculateRewards(
            _holding.qty * project.price,
            _holding.startTime,
            endTime,
            project.apy
        );
        return _holding;
    }

    function getHoldingInfoRaw(
        address user,
        uint32 projectId
    ) external view returns (HoldingInfo memory) {
        return holdings[user][projectId];
    }

    function setHoldingInfoData(
        address user,
        uint32 projectId,
        HoldingInfo memory holding
    ) external onlyProjectMan {
        holdings[user][projectId] = holding;
    }

    function getStakingInfoRaw(
        address user,
        uint32 projectId
    ) public view returns (StakeInfo memory) {
        StakeInfo memory staker = stakers[user][projectId];
        return staker;
    }

    function _checkAddress(address addr) private pure {
        require(addr != address(0), "x addr");
    }

    /**
     * @dev Withdraw amount of deposit from this contract to `to` address.
     *      Caller of this function must be owner.
     * @param amount to withdraw.
     * @param to address to withdraw to.
     */
    function withdrawTo(uint256 amount, address to) external onlyOwner {
        _checkAddress(to);
        require(amount > 0, "!amount");

        require(stableCoin.balanceOf(address(this)) >= amount, "balance <");

        stableCoin.safeTransferFrom(address(this), to, amount);

        emit BalanceWithdraw(to, amount);
    }

    /**
     * This function is used to pause or unpause contract.
     * Only the owner of the contract or the project manager contract can call this function.
     *
     * @param _paused A boolean indicating whether should be paused or not.
     */
    function pause(bool _paused) external {
        require(
            owner() == _msgSender() || address(projectMan) == _msgSender(),
            "!owner"
        );
        paused = _paused;
    }
}


// File: ERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC1155.sol";
import "IERC1155Receiver.sol";
import "IERC1155MetadataURI.sol";
import "Address.sol";
import "Context.sol";
import "ERC165.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

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
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
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
        require(_msgSender() != operator, "ERC1155: setting approval status for self");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
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
            "ERC1155: caller is not owner nor approved"
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
            "ERC1155: transfer caller is not owner nor approved"
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

        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

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
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `account`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - If `account` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(account != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), account, _asSingletonArray(id), _asSingletonArray(amount), data);

        _balances[id][account] += amount;
        emit TransferSingle(operator, address(0), account, id, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), account, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
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

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `account`
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

        uint256 accountBalance = _balances[id][account];
        require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][account] = accountBalance - amount;
        }

        emit TransferSingle(operator, account, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balances[id][account];
            require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][account] = accountBalance - amount;
            }
        }

        emit TransferBatch(operator, account, address(0), ids, amounts);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
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
    function _beforeTokenTransfer(
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
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
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
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}


// File: IERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC165.sol";

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
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

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
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

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


// File: IERC165.sol
// SPDX-License-Identifier: MIT

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


// File: IERC1155Receiver.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC165.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
        @dev Handles the receipt of a single ERC1155 token type. This function is
        called at the end of a `safeTransferFrom` after the balance has been updated.
        To accept the transfer, this must return
        `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
        (i.e. 0xf23a6e61, or its own function selector).
        @param operator The address which initiated the transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param id The ID of the token being transferred
        @param value The amount of tokens being transferred
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
    */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
        @dev Handles the receipt of a multiple ERC1155 token types. This function
        is called at the end of a `safeBatchTransferFrom` after the balances have
        been updated. To accept the transfer(s), this must return
        `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
        (i.e. 0xbc197c81, or its own function selector).
        @param operator The address which initiated the batch transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param ids An array containing ids of each token being transferred (order and length must match values array)
        @param values An array containing amounts of each token being transferred (order and length must match ids array)
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
    */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}


// File: IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
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


// File: ERC165.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC165.sol";

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
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


// File: ReentrancyGuard.sol
// SPDX-License-Identifier: MIT

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
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


// File: Ownable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "Context.sol";

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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File: ERC1155Tradable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "Ownable.sol";
import "ERC1155.sol";
import "SafeMath.sol";
import "Strings.sol";

import "NativeMetaTransaction.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

/** 
 * @title ERC1155Tradable
 * ERC1155Tradable - ERC1155 contract that whitelists an operator address, has create and mint functionality, and supports useful standards from OpenZeppelin,
  like _exists() , name(), symbol(), and totalSupply()
 */
contract ERC1155Tradable is
    ERC1155,
    NativeMetaTransaction,
    Ownable
{
    using Strings for string;
    using SafeMath for uint256;

    address proxyRegistryAddress;
    mapping(uint256 => string) internal customUri;
    // Contract name
    string public name;
    // Contract symbol
    string public symbol;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address _proxyRegistryAddress
    ) ERC1155(_uri) {
        name = _name;
        symbol = _symbol;
        proxyRegistryAddress = _proxyRegistryAddress;
        // _initializeEIP712(name);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     * @param _newURI New URI for all tokens
     */
    function setURI(string memory _newURI) public onlyOwner {
        _setURI(_newURI);
    }

    /**
     * @dev Will update the base URI for the token
     * @param _tokenId The token to update. _msgSender() must be its creator.
     * @param _newURI New URI for the token.
     */
    function setCustomURI(uint256 _tokenId, string memory _newURI)
        public
        onlyOwner
    {
        customUri[_tokenId] = _newURI;
        emit URI(_newURI, _tokenId);
    }

    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-free listings.
     */
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool isOperator)
    {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(_owner)) == _operator) {
            return true;
        }

        return ERC1155.isApprovedForAll(_owner, _operator);
    }
}


// File: SafeMath.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
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
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}


// File: Strings.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}


// File: NativeMetaTransaction.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {SafeMath} from  "SafeMath.sol";
import {EIP712Base} from "EIP712Base.sol";

contract NativeMetaTransaction is EIP712Base {
    using SafeMath for uint256;
    bytes32 private constant META_TRANSACTION_TYPEHASH = keccak256(
        bytes(
            "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
        )
    );
    event MetaTransactionExecuted(
        address userAddress,
        address payable relayerAddress,
        bytes functionSignature
    );
    mapping(address => uint256) nonces;

    /*
     * Meta transaction structure.
     * No point of including value field here as if user is doing value transfer then he has the funds to pay for gas
     * He should call the desired function directly in that case.
     */
    struct MetaTransaction {
        uint256 nonce;
        address from;
        bytes functionSignature;
    }

    function executeMetaTransaction(
        address userAddress,
        bytes memory functionSignature,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) public payable returns (bytes memory) {
        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[userAddress],
            from: userAddress,
            functionSignature: functionSignature
        });

        require(
            verify(userAddress, metaTx, sigR, sigS, sigV),
            "Signer and signature do not match"
        );

        // increase nonce for user (to avoid re-use)
        nonces[userAddress] = nonces[userAddress].add(1);

        emit MetaTransactionExecuted(
            userAddress,
            payable(msg.sender),
            functionSignature
        );

        // Append userAddress and relayer address at the end to extract it from calling context
        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(functionSignature, userAddress)
        );
        require(success, "Function call not successful");

        return returnData;
    }

    function hashMetaTransaction(MetaTransaction memory metaTx)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    META_TRANSACTION_TYPEHASH,
                    metaTx.nonce,
                    metaTx.from,
                    keccak256(metaTx.functionSignature)
                )
            );
    }

    function getNonce(address user) public view returns (uint256 nonce) {
        nonce = nonces[user];
    }

    function verify(
        address signer,
        MetaTransaction memory metaTx,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) internal view returns (bool) {
        require(signer != address(0), "NativeMetaTransaction: INVALID_SIGNER");
        return
            signer ==
            ecrecover(
                toTypedMessageHash(hashMetaTransaction(metaTx)),
                sigV,
                sigR,
                sigS
            );
    }
}


// File: EIP712Base.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Initializable} from "Initializable.sol";

contract EIP712Base is Initializable {
    struct EIP712Domain {
        string name;
        string version;
        address verifyingContract;
        bytes32 salt;
    }

    string constant public ERC712_VERSION = "1";

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(
        bytes(
            "EIP712Domain(string name,string version,address verifyingContract,bytes32 salt)"
        )
    );
    bytes32 internal domainSeperator;

    // supposed to be called once while initializing.
    // one of the contracts that inherits this contract follows proxy pattern
    // so it is not possible to do this in a constructor
    function _initializeEIP712(
        string memory name
    )
        internal
        initializer
    {
        _setDomainSeperator(name);
    }

    function _setDomainSeperator(string memory name) internal {
        domainSeperator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(ERC712_VERSION)),
                address(this),
                bytes32(getChainId())
            )
        );
    }

    function getDomainSeperator() public view returns (bytes32) {
        return domainSeperator;
    }

    function getChainId() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * Accept message hash and returns hash message in EIP712 compatible form
     * So that it can be used to recover signer from signature signed using EIP712 formatted data
     * https://eips.ethereum.org/EIPS/eip-712
     * "\\x19" makes the encoding deterministic
     * "\\x01" is the version byte to make it compatible to EIP-191
     */
    function toTypedMessageHash(bytes32 messageHash)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19\x01", getDomainSeperator(), messageHash)
            );
    }
}

// File: Initializable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Initializable {
    bool inited = false;

    modifier initializer() {
        require(!inited, "already inited");
        _;
        inited = true;
    }
}


// File: IProjectMan.sol
pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "ProjectInfo.sol";

bytes1 constant NOT_ACTIVE = 0x00;
bytes1 constant ACTIVE = 0x01;
bytes1 constant MARKET_UNAVAILABLE = 0x02;
bytes1 constant CLOSED = 0x03;
bytes1 constant PAUSED = 0x04;


abstract contract IProjectMan {
    mapping(uint32 => ProjectInfo) internal _projects;

    function projectExists(uint32 projectId) public virtual view returns (bool);
    function getProject(uint32 projectId) public virtual view returns (ProjectInfo memory);
}



