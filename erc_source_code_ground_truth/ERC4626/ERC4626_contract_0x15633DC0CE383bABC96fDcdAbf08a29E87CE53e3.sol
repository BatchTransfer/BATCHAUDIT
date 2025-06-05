// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { Yearn4626Router } from "Yearn-ERC4626-Router/Yearn4626Router.sol";
import { IYearnVaultV2 } from "./interfaces/deps/yearn/veYFI/IYearnVaultV2.sol";
import { IPermit2 } from "permit2/interfaces/IPermit2.sol";
import { ISignatureTransfer } from "permit2/interfaces/ISignatureTransfer.sol";
import { IWETH9 } from "Yearn-ERC4626-Router/external/PeripheryPayments.sol";
import { IYearn4626RouterExt } from "./interfaces/IYearn4626RouterExt.sol";
import { YearnVaultV2Helper } from "./libraries/YearnVaultV2Helper.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IStakeDaoGauge } from "./interfaces/deps/stakeDAO/IStakeDaoGauge.sol";
import { IStakeDaoVault } from "./interfaces/deps/stakeDAO/IStakeDaoVault.sol";

/**
 * @title Yearn4626Router Extension
 * @notice Extends the Yearn4626Router with additional functionality for depositing to Yearn Vault V2 and pulling tokens
 * with Permit2.
 * @dev This contract introduces two key functions: depositing to Yearn Vault V2 and pulling tokens with a signature via
 * Permit2.
 * The contract holds an immutable reference to a Permit2 contract to facilitate token transfers with permits.
 */
contract Yearn4626RouterExt is IYearn4626RouterExt, Yearn4626Router {
    using SafeERC20 for IERC20;
    using YearnVaultV2Helper for IYearnVaultV2;

    // slither-disable-next-line naming-convention
    IPermit2 private immutable _PERMIT2;

    /// @notice Error for when the number of shares received is less than the minimum expected.
    error InsufficientShares();
    /// @notice Error for when the amount of assets received is less than the minimum expected.
    error InsufficientAssets();
    /// @notice Error for when the amount of shares burned is more than the maximum expected.
    error RequiresMoreThanMaxShares();
    /// @notice Error for when the `to` address in the Permit2 transfer is not the router contract.
    error InvalidPermit2TransferTo();
    /// @notice Error for when the amount in the Permit2 transfer is not the same as the requested amount.
    error InvalidPermit2TransferAmount();
    /// @notice Error for when the serialized deposit path is too short.
    error InvalidPathLength();
    /// @notice Error for when the path is too short to preview the deposits/mints/withdraws/redeems.
    error PreviewPathIsTooShort();
    /// @notice Error for when the address in the path is not a vault.
    error PreviewNonVaultAddressInPath(address invalidVault);
    /// @notice Error for when an address in the path does not match previous or next vault's asset.
    error PreviewVaultMismatch();

    /**
     * @notice Constructs the Yearn4626RouterExt contract.
     * @dev Sets up the router with the name for the vault, WETH address, and Permit2 contract address.
     * @param name_ The name of the vault.
     * @param weth_ The address of the WETH contract.
     * @param permit2_ The address of the Permit2 contract.
     */
    // slither-disable-next-line locked-ether
    constructor(string memory name_, address weth_, address permit2_) payable Yearn4626Router(name_, IWETH9(weth_)) {
        _PERMIT2 = IPermit2(permit2_);
    }

    /**
     * @notice Deposits the specified `amount` of assets into series of ERC4626 vaults or Yearn Vault V2.
     * @param path The array of addresses that represents the vaults to deposit into.
     * @param assetsIn The amount of assets to deposit into the first vault.
     * @param to The address to which the shares will be transferred.
     * @param minSharesOut The minimum amount of shares expected to be received.
     * @return sharesOut The actual amount of shares received by the `to` address.
     */
    function serializedDeposits(
        address[] calldata path,
        uint256 assetsIn,
        address to,
        uint256 minSharesOut
    )
        external
        payable
        returns (uint256 sharesOut)
    {
        unchecked {
            if (path.length == 0) revert InvalidPathLength();
            uint256 last = path.length - 1;
            for (uint256 i; i < path.length;) {
                address receiver = address(this);
                if (i == last) {
                    receiver = to;
                }
                // slither-disable-next-line calls-loop
                assetsIn = sharesOut = IERC4626(path[i]).deposit(assetsIn, receiver);
                ++i;
            }
            if (sharesOut < minSharesOut) revert InsufficientShares();
        }
    }

    /**
     * @notice Redeems the specified `shares` from a series of ERC4626 vaults or Yearn Vault V2.
     * @param path The array of addresses that represents the vaults to redeem from.
     * @param isYearnVaultV2 The array of boolean values that represent whether the vault is a Yearn Vault V2.
     * @param sharesIn The amount of shares to redeem from the first vault.
     * @param to The address to which the assets will be transferred.
     * @param minAssetsOut The minimum amount of assets expected to be received.
     * @return assetsOut The actual amount of assets received by the `to` address.
     */
    function serializedRedeems(
        address[] calldata path,
        bool[] calldata isYearnVaultV2,
        uint256 sharesIn,
        address to,
        uint256 minAssetsOut
    )
        external
        payable
        returns (uint256 assetsOut)
    {
        unchecked {
            uint256 length = path.length;
            if (length == 0) revert InvalidPathLength();
            if (length != isYearnVaultV2.length) revert InvalidPathLength();
            uint256 last = length - 1;
            for (uint256 i; i < length;) {
                address receiver = address(this);
                if (i == last) {
                    receiver = to;
                }
                if (isYearnVaultV2[i]) {
                    // slither-disable-next-line calls-loop
                    sharesIn = assetsOut = IYearnVaultV2(path[i]).withdraw(sharesIn, receiver);
                } else {
                    // slither-disable-next-line calls-loop
                    sharesIn = assetsOut = IERC4626(path[i]).redeem(sharesIn, receiver, address(this));
                }
                ++i;
            }
            if (assetsOut < minAssetsOut) revert InsufficientAssets();
        }
    }

    // ------------- YEARN VAULT V2 FUNCTIONS ------------- //

    /**
     * @notice Redeems the specified `shares` from the Yearn Vault V2.
     * @dev The shares must exist in this router before calling this function.
     * @param vault The Yearn Vault V2 contract instance.
     * @param shares The amount of shares to redeem.
     * @param to The address to which the assets will be transferred.
     * @param minAssetsOut The minimum amount of assets expected to be received.
     * @return amountOut The actual amount of assets received by the `to` address.
     */
    function redeemVaultV2(
        IYearnVaultV2 vault,
        uint256 shares,
        address to,
        uint256 minAssetsOut
    )
        public
        payable
        returns (uint256 amountOut)
    {
        if ((amountOut = vault.withdraw(shares, to)) < minAssetsOut) revert InsufficientAssets();
    }

    // ------------- ERC4626 VAULT FUNCTIONS  ------------- //

    /**
     * @notice Redeems the specified IERC4626 vault `shares` that this router is holding.
     * @param vault The IERC4626 vault contract instance.
     * @param shares The amount of shares to redeem.
     * @param to The address to which the assets will be transferred.
     * @param minAmountOut The minimum amount of assets expected to be received.
     * @return amountOut The actual amount of assets received by the `to` address.
     */
    function redeemFromRouter(
        IERC4626 vault,
        uint256 shares,
        address to,
        uint256 minAmountOut
    )
        public
        payable
        virtual
        returns (uint256 amountOut)
    {
        if ((amountOut = vault.redeem(shares, to, address(this))) < minAmountOut) revert InsufficientAssets();
    }

    /**
     * @notice Withdraws the specified `assets` from the IERC4626 vault.
     * @param vault The IERC4626 vault contract instance.
     * @param assets The amount of assets to withdraw.
     * @param to The address to which the assets will be transferred.
     * @param maxSharesIn The maximum amount of vault shares expected to be burned.
     * @return sharesOut The actual amount of shares burned from the `vault`.
     */
    function withdrawFromRouter(
        IERC4626 vault,
        uint256 assets,
        address to,
        uint256 maxSharesIn
    )
        public
        payable
        virtual
        returns (uint256 sharesOut)
    {
        if ((sharesOut = vault.withdraw(assets, to, address(this))) > maxSharesIn) revert RequiresMoreThanMaxShares();
    }

    // ------------- STAKEDAO FUNCTIONS  ------------- //

    /**
     * @notice Redeems the specified `shares` of the StakeDAO Gauge.
     * @dev Assumes the assets withdrawn will be the the yearn vault tokens and will always be the same amount as the
     * `shares` of the burned StakeDAO gauge tokens.
     * @param gauge The StakeDAO Gauge contract instance.
     * @param shares The amount of StakeDAO gauge tokens to burn.
     */
    function redeemStakeDaoGauge(IStakeDaoGauge gauge, uint256 shares, address to) public payable returns (uint256) {
        IStakeDaoVault vault = IStakeDaoVault(gauge.staking_token());
        vault.withdraw(shares);
        if (to != address(this)) {
            IERC20(vault.token()).safeTransfer(to, shares);
        }
        return shares;
    }

    // ------------- PERMIT2 FUNCTIONS  ------------- //

    /**
     * @notice Pulls tokens to the contract using a signature via Permit2.
     * @dev Verifies that the `to` address in `transferDetails` is the contract itself and then calls
     * `permitTransferFrom` on the Permit2 contract.
     * Reverts with `InvalidTo` if the `to` address is not the contract itself.
     * @param permit The PermitTransferFrom struct containing the permit details.
     * @param transferDetails The details of the transfer, including the `to` address.
     * @param signature The signature to authorize the token transfer.
     */
    function pullTokenWithPermit2(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    )
        public
        payable
    {
        if (transferDetails.to != address(this)) revert InvalidPermit2TransferTo();
        if (permit.permitted.amount != transferDetails.requestedAmount) revert InvalidPermit2TransferAmount();
        _PERMIT2.permitTransferFrom(permit, transferDetails, msg.sender, signature);
    }

    // ------------- PREVIEW FUNCTIONS  ------------- //

    /**
     * @notice Calculate the amount of shares to be received from a series of deposits to ERC4626 vaults or Yearn Vault
     * V2.
     * @param path The array of addresses that represents the path from input token to output token
     * @param assetsIn The amount of assets to deposit into the first vault.
     * @return sharesOut The amount of shares to be received from each deposit. The length of the array is `path.length
     * - 1`.
     */
    // slither-disable-start calls-loop,low-level-calls
    function previewDeposits(
        address[] calldata path,
        uint256 assetsIn
    )
        external
        view
        returns (uint256[] memory sharesOut)
    {
        if (path.length < 2) revert PreviewPathIsTooShort();
        uint256 sharesOutLength = path.length - 1;
        sharesOut = new uint256[](sharesOutLength);
        for (uint256 i; i < sharesOutLength;) {
            address vault = path[i + 1];
            if (!Address.isContract(vault)) {
                revert PreviewNonVaultAddressInPath(vault);
            }
            address vaultAsset = address(0);
            (bool success, bytes memory data) = vault.staticcall(abi.encodeCall(IERC4626.asset, ()));
            if (success) {
                vaultAsset = abi.decode(data, (address));
                assetsIn = sharesOut[i] = IERC4626(vault).previewDeposit(assetsIn);
            } else {
                (success, data) = vault.staticcall(abi.encodeCall(IYearnVaultV2.token, ()));
                if (success) {
                    vaultAsset = abi.decode(data, (address));
                    assetsIn = sharesOut[i] = IYearnVaultV2(vault).previewDeposit(assetsIn);
                } else {
                    revert PreviewNonVaultAddressInPath(vault);
                }
            }
            if (vaultAsset != path[i]) {
                revert PreviewVaultMismatch();
            }

            /// @dev Increment the loop index `i` without checking for overflow.
            /// This is safe because the loop's termination condition ensures that `i` will not exceed
            /// the bounds of the `sharesOut` array, which would be the only case where an overflow could occur.
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculate the amount of assets required to mint a given amount of shares from a series of deposits to
     * ERC4626 vaults or Yearn Vault V2.
     * @param path The array of addresses that represents the path from input to output.
     * @param sharesOut The amount of shares to mint from the last vault.
     * @return assetsIn The amount of assets required at each step. The length of the array is `path.length - 1`.
     * @dev sharesOut is the expected result at the last vault, and the path = [tokenIn, vault0, vault1, ..., vaultN].
     * First calculate the amount of assets in to get the desired sharesOut from the last vault, then using that amount
     * as the next sharesOut to get the amount of assets in for the penultimate vault.
     */
    function previewMints(
        address[] calldata path,
        uint256 sharesOut
    )
        external
        view
        returns (uint256[] memory assetsIn)
    {
        if (path.length < 2) revert PreviewPathIsTooShort();
        uint256 assetsInLength = path.length - 1;
        assetsIn = new uint256[](assetsInLength);
        for (uint256 i = assetsInLength; i > 0;) {
            address vault = path[i];
            if (!Address.isContract(vault)) {
                revert PreviewNonVaultAddressInPath(vault);
            }
            address vaultAsset = address(0);
            (bool success, bytes memory data) = vault.staticcall(abi.encodeCall(IERC4626.asset, ()));
            if (success) {
                vaultAsset = abi.decode(data, (address));
                sharesOut = assetsIn[i - 1] = IERC4626(vault).previewMint(sharesOut);
            } else {
                (success, data) = vault.staticcall(abi.encodeCall(IYearnVaultV2.token, ()));
                if (success) {
                    vaultAsset = abi.decode(data, (address));
                    sharesOut = assetsIn[i - 1] = IYearnVaultV2(vault).previewMint(sharesOut);
                } else {
                    revert PreviewNonVaultAddressInPath(vault);
                }
            }

            if (vaultAsset != path[i - 1]) {
                revert PreviewVaultMismatch();
            }

            /// @dev Decrement the loop counter within an unchecked block to avoid redundant gas cost associated with
            /// underflow checking. This is safe because the loop's initialization and exit condition ensure that `i`
            /// will not underflow.
            unchecked {
                --i;
            }
        }
    }

    /**
     * @notice Calculate the amount of shares required to withdraw a given amount of assets from a series of withdraws
     * from ERC4626 vaults or Yearn Vault V2.
     * @param path The array of addresses that represents the path from input to output.
     * @param assetsOut The amount of assets to withdraw from the last vault.
     * @dev assetsOut is the desired result of the output token, and the path = [vault0, vault1, ..., vaultN, tokenOut].
     * First calculate the amount of shares in to get the desired assetsOut from the last vault, then using that amount
     * as the next assetsOut to get the amount of shares in for the penultimate vault.
     * @return sharesIn The amount of shares required at each step. The length of the array is `path.length - 1`.
     */
    function previewWithdraws(
        address[] calldata path,
        uint256 assetsOut
    )
        external
        view
        returns (uint256[] memory sharesIn)
    {
        if (path.length < 2) revert PreviewPathIsTooShort();
        uint256 sharesInLength = path.length - 1;
        sharesIn = new uint256[](sharesInLength);
        for (uint256 i = path.length - 2;;) {
            address vault = path[i];
            if (!Address.isContract(vault)) {
                revert PreviewNonVaultAddressInPath(vault);
            }
            address vaultAsset = address(0);
            (bool success, bytes memory data) = vault.staticcall(abi.encodeCall(IERC4626.asset, ()));
            if (success) {
                vaultAsset = abi.decode(data, (address));
                assetsOut = sharesIn[i] = IERC4626(vault).previewWithdraw(assetsOut);
            } else {
                (success, data) = vault.staticcall(abi.encodeCall(IYearnVaultV2.token, ()));
                if (success) {
                    vaultAsset = abi.decode(data, (address));
                    assetsOut = sharesIn[i] = IYearnVaultV2(vault).previewWithdraw(assetsOut);
                } else {
                    // StakeDAO gauge token
                    // StakeDaoGauge.staking_token().token() is the yearn vault v2 token
                    (success, data) = vault.staticcall(abi.encodeCall(IStakeDaoGauge.staking_token, ()));
                    if (success) {
                        vaultAsset = IStakeDaoVault(abi.decode(data, (address))).token();
                        sharesIn[i] = assetsOut;
                    } else {
                        revert PreviewNonVaultAddressInPath(vault);
                    }
                }
            }
            if (vaultAsset != path[i + 1]) {
                revert PreviewVaultMismatch();
            }
            if (i == 0) return sharesIn;

            /// @dev Decrement the loop counter without checking for overflow.  This is safe because the for loop
            /// naturally ensures that `i` will not underflow as it is bounded by i == 0 check.
            unchecked {
                --i;
            }
        }
    }

    /**
     * @notice Calculate the amount of assets to be received from a series of withdraws from ERC4626 vaults or Yearn
     * Vault V2.
     * @param path The array of addresses that represents the path from input to output.
     * @param sharesIn The amount of shares to withdraw from the first vault.
     * @return assetsOut The amount of assets to be received at each step. The length of the array is `path.length - 1`.
     */
    function previewRedeems(
        address[] calldata path,
        uint256 sharesIn
    )
        external
        view
        returns (uint256[] memory assetsOut)
    {
        if (path.length < 2) revert PreviewPathIsTooShort();
        uint256 assetsOutLength = path.length - 1;
        assetsOut = new uint256[](assetsOutLength);
        for (uint256 i; i < assetsOutLength;) {
            address vault = path[i];
            if (!Address.isContract(vault)) {
                revert PreviewNonVaultAddressInPath(vault);
            }
            address vaultAsset = address(0);
            (bool success, bytes memory data) = vault.staticcall(abi.encodeCall(IERC4626.asset, ()));
            if (success) {
                vaultAsset = abi.decode(data, (address));
                sharesIn = assetsOut[i] = IERC4626(vault).previewRedeem(sharesIn);
            } else {
                (success, data) = vault.staticcall(abi.encodeCall(IYearnVaultV2.token, ()));
                if (success) {
                    vaultAsset = abi.decode(data, (address));
                    sharesIn = assetsOut[i] = IYearnVaultV2(vault).previewRedeem(sharesIn);
                } else {
                    // StakeDAO gauge token
                    // StakeDaoGauge.staking_token().token() is the yearn vault v2 token
                    (success, data) = vault.staticcall(abi.encodeCall(IStakeDaoGauge.staking_token, ()));
                    if (success) {
                        vaultAsset = IStakeDaoVault(abi.decode(data, (address))).token();
                        assetsOut[i] = sharesIn;
                    } else {
                        revert PreviewNonVaultAddressInPath(vault);
                    }
                }
            }
            if (vaultAsset != path[i + 1]) {
                revert PreviewVaultMismatch();
            }

            /// @dev The unchecked block is used here to prevent overflow checking for the loop increment, which is not
            /// necessary since the loop's exit condition ensures `i` will not exceed `assetsOutLength`.
            unchecked {
                ++i;
            }
        }
    }
    // slither-disable-end calls-loop,low-level-calls
}// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import "./Yearn4626RouterBase.sol";
import {IYearn4626Router, IYearnV2} from "./interfaces/IYearn4626Router.sol";

/**
 * @title Yearn4626Router contract
 * @notice
 *  Router that is meant to be used with Yearn V3 vaults and strategies
 *  for deposits, withdraws and migrations.
 *  
 *  The router was developed from the original router by FEI protocol
 *  https://github.com/fei-protocol/ERC4626
 *
 *  The router is designed to be used with permit and multicall for the 
 *  optimal experience.
 *
 *  NOTE: It is important to never leave tokens in the router at the 
 *  end of a call, otherwise they can be swept by anyone.
 */
contract Yearn4626Router is IYearn4626Router, Yearn4626RouterBase {
    using SafeTransferLib for ERC20;

    // Store name as bytes so it can be immutable
    bytes32 private immutable _name;

    constructor(string memory _name_, IWETH9 weth) PeripheryPayments(weth) {
        _name = bytes32(abi.encodePacked(_name_));
    }

    // Getter function to unpack stored name.
    function name() external view returns(string memory) {
        return string(abi.encodePacked(_name));
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT
    //////////////////////////////////////////////////////////////*/

    // For the below, no approval needed, assumes vault is already max approved

    /// @inheritdoc IYearn4626Router
    function depositToVault(
        IYearn4626 vault,
        uint256 amount,
        address to,
        uint256 minSharesOut
    ) public payable override returns (uint256) {
        pullToken(ERC20(vault.asset()), amount, address(this));
        return deposit(vault, amount, to, minSharesOut);
    }

    //-------- DEPOSIT FUNCTIONS WITH DEFAULT VALUES --------\\ 

    /**
     @notice See {depositToVault} in IYearn4626Router.
     @dev Uses msg.sender as the default for `to`.
    */
    function depositToVault(
        IYearn4626 vault,
        uint256 amount,
        uint256 minSharesOut
    ) external payable returns (uint256) {
        return depositToVault(vault, amount, msg.sender, minSharesOut);
    }

    /**
     @notice See {depositToVault} in IYearn4626Router.
     @dev Uses msg.sender as the default for `to` and their full 
     balance of msg.sender as `amount`.
    */
    function depositToVault(
        IYearn4626 vault, 
        uint256 minSharesOut
    ) external payable returns (uint256) {
        uint256 amount = ERC20(vault.asset()).balanceOf(msg.sender);
        return depositToVault(vault, amount, msg.sender, minSharesOut);
    }

    /**
     @notice See {depositToVault} in IYearn4626Router.
     @dev Uses msg.sender as the default for `to`, their full balance 
     of msg.sender as `amount` and 1 Basis point for `maxLoss`.
     
     NOTE: The slippage tollerance is only useful if {previewDeposit}
     cannot be manipulated for the `vault`.
    */
    function depositToVault(
        IYearn4626 vault
    ) external payable returns (uint256) {
        uint256 assets =  ERC20(vault.asset()).balanceOf(msg.sender);
        // This give a default 1Basis point acceptance for loss. This is only 
        // considered safe if the vaults PPS can not be manipulated.
        uint256 minSharesOut = vault.previewDeposit(assets) * 9_999 / 10_000;
        return depositToVault(vault, assets, msg.sender, minSharesOut);
    }

    /*//////////////////////////////////////////////////////////////
                            REDEEM
    //////////////////////////////////////////////////////////////*/

    //-------- REDEEM FUNCTIONS WITH DEFAULT VALUES --------\\

    /**
     @notice See {redeem} in IYearn4626RouterBase.
     @dev Uses msg.sender as `receiver`.
    */
    function redeem(
        IYearn4626 vault,
        uint256 shares,
        uint256 maxLoss
    ) external payable returns (uint256) {
        return redeem(vault, shares, msg.sender, maxLoss);
    }

    /**
     @notice See {redeem} in IYearn4626RouterBase.
     @dev Uses msg.sender as `receiver` and their full balance as `shares`.
    */
    function redeem(
        IYearn4626 vault,
        uint256 maxLoss
    ) external payable returns (uint256) {
        uint256 shares = vault.balanceOf(msg.sender);
        return redeem(vault, shares, msg.sender, maxLoss);
    }

    /**
     @notice See {redeem} in IYearn4626RouterBase.
     @dev Uses msg.sender as `receiver`, their full balance as `shares`
     and 1 Basis Point for `maxLoss`.
    */
    function redeem(
        IYearn4626 vault
    ) external payable returns (uint256) {
        uint256 shares = vault.balanceOf(msg.sender);
        return redeem(vault, shares, msg.sender, 1);
    }

    /*//////////////////////////////////////////////////////////////
                            MIGRATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IYearn4626Router
    function migrate(
        IYearn4626 fromVault,
        IYearn4626 toVault,
        uint256 shares,
        address to,
        uint256 minSharesOut
    ) public payable override returns (uint256) {
        // amount out passes through so only one slippage check is needed
        uint256 amount = redeem(fromVault, shares, address(this), 10_000);
        return deposit(toVault, amount, to, minSharesOut);
    }

    //-------- MIGRATE FUNCTIONS WITH DEFAULT VALUES --------\\

    /**
     @notice See {migrate} in IYearn4626Router.
     @dev Uses msg.sender as `to`.
    */
    function migrate(
        IYearn4626 fromVault,
        IYearn4626 toVault,
        uint256 shares,
        uint256 minSharesOut
    ) external payable returns (uint256) {
        return migrate(fromVault, toVault, shares, msg.sender, minSharesOut);
    }

    /**
     @notice See {migrate} in IYearn4626Router.
     @dev Uses msg.sender as `to` and their full balance for `shares`.
    */
    function migrate(
        IYearn4626 fromVault,
        IYearn4626 toVault,
        uint256 minSharesOut
    ) external payable returns (uint256) {
        uint256 shares = fromVault.balanceOf(msg.sender);
        return migrate(fromVault, toVault, shares, msg.sender, minSharesOut);
    }

    /**
     @notice See {migrate} in IYearn4626Router.
     @dev Uses msg.sender as `to`, their full balance for `shares` and no `minamountOut`.

     NOTE: Using this will enforce no slippage checks and should be used with care.
    */
    function migrate(
        IYearn4626 fromVault, 
        IYearn4626 toVault
    ) external payable returns (uint256) {
        uint256 shares = fromVault.balanceOf(msg.sender);
        return migrate(fromVault, toVault, shares, msg.sender, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        V2 MIGRATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IYearn4626Router
    function migrateFromV2(
        IYearnV2 fromVault,
        IYearn4626 toVault,
        uint256 shares,
        address to,
        uint256 minSharesOut
    ) public payable override returns (uint256) {
        // V2 can't specify owner so we need to first pull the shares
        fromVault.transferFrom(msg.sender, address(this), shares);
        // amount out passes through so only one slippage check is needed
        uint256 redeemed = fromVault.withdraw(shares, address(this));
        return deposit(toVault, redeemed, to, minSharesOut);
    }

    //-------- migrateFromV2 FUNCTIONS WITH DEFAULT VALUES --------\\

    /**
     @notice See {migrateFromV2} in IYearn4626Router.
     @dev Uses msg.sender as `to`.
    */
    function migrateFromV2(
        IYearnV2 fromVault,
        IYearn4626 toVault,
        uint256 shares,
        uint256 minSharesOut
    ) external payable returns (uint256) {
        return migrateFromV2(fromVault, toVault, shares, msg.sender, minSharesOut);
    }

    /**
     @notice See {migrateFromV2} in IYearn4626Router.
     @dev Uses msg.sender as `to` and their full balance as `shares`.
    */
    function migrateFromV2(
        IYearnV2 fromVault,
        IYearn4626 toVault,
        uint256 minSharesOut
    ) external payable returns (uint256) {
        uint256 shares = fromVault.balanceOf(msg.sender);
        return migrateFromV2(fromVault, toVault, shares, msg.sender, minSharesOut);
    }

    /**
     @notice See {migrate} in IYearn4626Router.
     @dev Uses msg.sender as `to`, their full balance for `shares` and no `minamountOut`.

     NOTE: Using this will enforce no slippage checks and should be used with care.
    */
    function migrateFromV2(
        IYearnV2 fromVault,
        IYearn4626 toVault
    ) external payable returns (uint256 sharesOut) {
        uint256 shares = fromVault.balanceOf(msg.sender);
        return migrateFromV2(fromVault, toVault, shares, msg.sender, 0);
    }
}// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// @dev YearnVaultV2 does not follow ERC4626 interface for `asset()` instead it uses `token()`
interface IYearnVaultV2 {
    function token() external view returns (address);
    function deposit(uint256 amount, address recipient) external returns (uint256 shares);
    function deposit(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shares, address recipient) external returns (uint256 amount);
    function pricePerShare() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function lastReport() external view returns (uint256);
    function lockedProfitDegradation() external view returns (uint256);
    function lockedProfit() external view returns (uint256);
}   // SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import { IYearn4626Router } from "Yearn-ERC4626-Router/interfaces/IYearn4626Router.sol";
import { IYearnVaultV2 } from "./deps/yearn/veYFI/IYearnVaultV2.sol";
import { ISignatureTransfer } from "permit2/interfaces/ISignatureTransfer.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IStakeDaoGauge } from "./deps/stakeDAO/IStakeDaoGauge.sol";

interface IYearn4626RouterExt is IYearn4626Router {
    function redeemVaultV2(
        IYearnVaultV2 vault,
        uint256 shares,
        address to,
        uint256 minAmountOut
    )
        external
        payable
        returns (uint256 amountOut);

    function redeemFromRouter(
        IERC4626 vault,
        uint256 shares,
        address to,
        uint256 minAmountOut
    )
        external
        payable
        returns (uint256 amountOut);

    function withdrawFromRouter(
        IERC4626 vault,
        uint256 assets,
        address to,
        uint256 maxSharesIn
    )
        external
        payable
        returns (uint256 sharesIn);

    function redeemStakeDaoGauge(
        IStakeDaoGauge gauge,
        uint256 shares,
        address to
    )
        external
        payable
        returns (uint256 amountOut);

    function previewDeposits(
        address[] calldata path,
        uint256 assetsIn
    )
        external
        view
        returns (uint256[] memory sharesOut);
    function previewMints(
        address[] calldata path,
        uint256 sharesOut
    )
        external
        view
        returns (uint256[] memory assetsIn);
    function previewWithdraws(
        address[] calldata path,
        uint256 assetsOut
    )
        external
        view
        returns (uint256[] memory sharesIn);
    function previewRedeems(
        address[] calldata path,
        uint256 sharesIn
    )
        external
        view
        returns (uint256[] memory assetsOut);

    function pullTokenWithPermit2(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    )
        external
        payable;
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
import "../../../utils/Address.sol";

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

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC4626.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";
import "../token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev Interface of the ERC4626 "Tokenized Vault Standard", as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626].
 *
 * _Available since v4.7._
 */
interface IERC4626 is IERC20, IERC20Metadata {
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @dev Returns the address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
     *
     * - MUST be an ERC-20 token contract.
     * - MUST NOT revert.
     */
    function asset() external view returns (address assetTokenAddress);

    /**
     * @dev Returns the total amount of the underlying asset that is “managed” by Vault.
     *
     * - SHOULD include any compounding that occurs from yield.
     * - MUST be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT revert.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @dev Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
     * through a deposit call.
     *
     * - MUST return a limited value if receiver is subject to some deposit limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
     * - MUST NOT revert.
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of Vault shares that would be minted in a deposit
     *   call in the same transaction. I.e. deposit should return the same or more shares as previewDeposit if called
     *   in the same transaction.
     * - MUST NOT account for deposit limits like those returned from maxDeposit and should always act as though the
     *   deposit would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   deposit execution, and are accounted for during deposit.
     * - MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
     * - MUST return a limited value if receiver is subject to some mint limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
     * - MUST NOT revert.
     */
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of assets that would be deposited in a mint call
     *   in the same transaction. I.e. mint should return the same or fewer assets as previewMint if called in the
     *   same transaction.
     * - MUST NOT account for mint limits like those returned from maxMint and should always act as though the mint
     *   would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewMint SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by minting.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint
     *   execution, and are accounted for during mint.
     * - MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, through a withdraw call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of Vault shares that would be burned in a withdraw
     *   call in the same transaction. I.e. withdraw should return the same or fewer shares as previewWithdraw if
     *   called
     *   in the same transaction.
     * - MUST NOT account for withdrawal limits like those returned from maxWithdraw and should always act as though
     *   the withdrawal would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Burns shares from owner and sends exactly assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   withdraw execution, and are accounted for during withdraw.
     * - MUST revert if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
     * through a redeem call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call
     *   in the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the
     *   same transaction.
     * - MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the
     *   redemption would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewRedeem SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by redeeming.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Burns exactly shares from owner and sends assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   redeem execution, and are accounted for during redeem.
     * - MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * NOTE: some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import {IYearn4626RouterBase, IYearn4626} from "./interfaces/IYearn4626RouterBase.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {SelfPermit} from "./external/SelfPermit.sol";
import {Multicall} from "./external/Multicall.sol";
import {PeripheryPayments, IWETH9} from "./external/PeripheryPayments.sol";

/// @title ERC4626 Router Base Contract
abstract contract Yearn4626RouterBase is
    IYearn4626RouterBase,
    SelfPermit,
    Multicall,
    PeripheryPayments
{
    using SafeTransferLib for ERC20;

    /// @inheritdoc IYearn4626RouterBase
    function mint(
        IYearn4626 vault,
        uint256 shares,
        address to,
        uint256 maxAmountIn
    ) public payable virtual override returns (uint256 amountIn) {
        require ((amountIn = vault.mint(shares, to)) <= maxAmountIn, "!MaxAmount");
    }

    /// @inheritdoc IYearn4626RouterBase
    function deposit(
        IYearn4626 vault,
        uint256 amount,
        address to,
        uint256 minSharesOut
    ) public payable virtual override returns (uint256 sharesOut) {
        require ((sharesOut = vault.deposit(amount, to)) >= minSharesOut, "!MinShares");
    }

    /// @inheritdoc IYearn4626RouterBase
    function withdraw(
        IYearn4626 vault,
        uint256 amount,
        address to,
        uint256 maxLoss
    ) public payable virtual override returns (uint256) {
        return vault.withdraw(amount, to, msg.sender, maxLoss);
    }

    /// @inheritdoc IYearn4626RouterBase
    function withdrawDefault(
        IYearn4626 vault,
        uint256 amount,
        address to,
        uint256 maxSharesOut
    ) public payable virtual override returns (uint256 sharesOut) {
        require ((sharesOut = vault.withdraw(amount, to, msg.sender)) <= maxSharesOut, "!MaxShares");
    }

    /// @inheritdoc IYearn4626RouterBase
    function redeem(
        IYearn4626 vault,
        uint256 shares,
        address to,
        uint256 maxLoss
    ) public payable virtual override returns (uint256) {
        return vault.redeem(shares, to, msg.sender, maxLoss);
    }

    /// @inheritdoc IYearn4626RouterBase
    function redeemDefault(
        IYearn4626 vault,
        uint256 shares,
        address to,
        uint256 minAmountOut
    ) public payable virtual override returns (uint256 amountOut) {
        require ((amountOut = vault.redeem(shares, to, msg.sender)) >= minAmountOut, "!MinAmount");
    }
}// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import "./IYearn4626.sol";
import "./IYearnV2.sol";

/** 
 @title ERC4626Router Interface
 @notice Extends the ERC4626RouterBase with specific flows to save gas
 */
interface IYearn4626Router {
    /*//////////////////////////////////////////////////////////////
                            DEPOSIT
    //////////////////////////////////////////////////////////////*/

    /** 
     @notice deposit `amount` to an ERC4626 vault.
     @param vault The ERC4626 vault to deposit assets to.
     @param to The destination of ownership shares.
     @param amount The amount of assets to deposit to `vault`.
     @param minSharesOut The min amount of `vault` shares received by `to`.
     @return . the amount of shares received by `to`.
     @dev throws "!minShares" Error.
    */
    function depositToVault(
        IYearn4626 vault,
        uint256 amount,
        address to,
        uint256 minSharesOut
    ) external payable returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            MIGRATION
    //////////////////////////////////////////////////////////////*/

    /** 
     @notice will redeem `shares` from one vault and deposit amountOut to a different ERC4626 vault.
     @param fromVault The ERC4626 vault to redeem shares from.
     @param toVault The ERC4626 vault to deposit assets to.
     @param shares The amount of shares to redeem from fromVault.
     @param to The destination of ownership shares.
     @param minSharesOut The min amount of toVault shares received by `to`.
     @return . the amount of shares received by `to`.
     @dev throws "!minAmount", "!minShares" Errors.
    */
    function migrate(
        IYearn4626 fromVault,
        IYearn4626 toVault,
        uint256 shares,
        address to,
        uint256 minSharesOut
    ) external payable returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            V2 MIGRATION
    //////////////////////////////////////////////////////////////*/

    /**
     @notice migrate from Yearn V2 vault to a V3 vault'.
     @param fromVault The Yearn V2 vault to withdraw from.
     @param toVault The Yearn V3 vault to deposit assets to.
     @param shares The amount of V2 shares to redeem form 'fromVault'.
     @param to The destination of ownership shares
     @param minSharesOut The min amount of 'toVault' shares to be received by 'to'.
     @return . The actual amount of 'toVault' shares received by 'to'.
     @dev throws "!minAmount", "!minShares" Errors.
    */
    function migrateFromV2(
        IYearnV2 fromVault,
        IYearn4626 toVault,
        uint256 shares,
        address to,
        uint256 minSharesOut
    ) external payable returns (uint256);
}// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "../tokens/ERC20.sol";

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
            mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "APPROVE_FAILED");
    }
}// SPDX-License-Identifier: MIT
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
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

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
}// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import "./IYearn4626.sol";

/** 
 @title ERC4626Router Base Interface
 @notice A canonical router between ERC4626 Vaults https://eips.ethereum.org/EIPS/eip-4626

 The base router is a multicall style router inspired by Uniswap v3 with built-in features for permit, WETH9 wrap/unwrap, and ERC20 token pulling/sweeping/approving.
 It includes methods for the four mutable ERC4626 functions deposit/mint/withdraw/redeem as well.

 These can all be arbitrarily composed using the multicall functionality of the router.

 NOTE the router is capable of pulling any approved token from your wallet. This is only possible when your address is msg.sender, but regardless be careful when interacting with the router or ERC4626 Vaults.
 The router makes no special considerations for unique ERC20 implementations such as fee on transfer. 
 There are no built in protections for unexpected behavior beyond enforcing the minSharesOut is received.
 */
interface IYearn4626RouterBase {
    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/

    /** 
     @notice mint `shares` from an ERC4626 vault.
     @param vault The ERC4626 vault to mint shares from.
     @param shares The amount of shares to mint from `vault`.
     @param to The destination of ownership shares.
     @param maxAmountIn The max amount of assets used to mint.
     @return amountIn the amount of assets used to mint by `to`.
     @dev throws "!maxAmount" Error   
    */
    function mint(
        IYearn4626 vault,
        uint256 shares,
        address to,
        uint256 maxAmountIn
    ) external payable returns (uint256 amountIn);

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    /** 
     @notice deposit `amount` to an ERC4626 vault.
     @param vault The ERC4626 vault to deposit assets to.
     @param amount The amount of assets to deposit to `vault`.
     @param to The destination of ownership shares.
     @param minSharesOut The min amount of `vault` shares received by `to`.
     @return sharesOut the amount of shares received by `to`.
     @dev throws "!minShares" Error   
    */
    function deposit(
        IYearn4626 vault,
        uint256 amount,
        address to,
        uint256 minSharesOut
    ) external payable returns (uint256 sharesOut);

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /** 
     @notice withdraw `amount` from an ERC4626 vault.
     @dev Uses the Yearn specific 'maxLoss' accounting.
     @param vault The ERC4626 vault to redeem shares from.
     @param vault The ERC4626 vault to withdraw assets from.
     @param amount The amount of assets to withdraw from vault.
     @param to The destination of assets.
     @param maxLoss The acceptable loss in Basis Points.
     @return sharesOut the amount of shares received by `to`.
     @dev throws "to much loss" Error   
    */
    function withdraw(
        IYearn4626 vault,
        uint256 amount,
        address to,
        uint256 maxLoss
    ) external payable returns (uint256);

    /** 
     @notice withdraw `amount` from an ERC4626 vault.
     @dev Uses the default 4626 syntax, throws !maxShares" Error.
     @param vault The ERC4626 vault to withdraw assets from.
     @param amount The amount of assets to withdraw from vault.
     @param to The destination of assets.
     @param minSharesOut The min amount of shares received by `to`.
     @return sharesOut the amount of shares received by `to`. 
    */
    function withdrawDefault(
        IYearn4626 vault,
        uint256 amount,
        address to,
        uint256 minSharesOut
    ) external payable returns (uint256 sharesOut);

    /*//////////////////////////////////////////////////////////////
                                REDEEM
    //////////////////////////////////////////////////////////////*/

    /** 
     @notice redeem `shares` shares from an ERC4626 vault.
     @dev Uses the Yearn specific 'maxLoss' accounting.
     @param vault The ERC4626 vault to redeem shares from.
     @param shares The amount of shares to redeem from vault.
     @param to The destination of assets.
     @param maxLoss The acceptable loss in Basis Points.
     @return amountOut the amount of assets received by `to`.
     @dev throws "to much loss" Error   
    */
    function redeem(
        IYearn4626 vault,
        uint256 shares,
        address to,
        uint256 maxLoss
    ) external payable returns (uint256);

    /** 
     @notice redeem `shares` shares from an ERC4626 vault.
     @dev Uses the default 4626 syntax, throws "!minAmount" Error.
     @param vault The ERC4626 vault to redeem shares from.
     @param shares The amount of shares to redeem from vault.
     @param to The destination of assets.
     @param minAmountOut The min amount of assets received by `to`.
     @return amountOut the amount of assets received by `to`.
    */
    function redeemDefault(
        IYearn4626 vault,
        uint256 shares,
        address to,
        uint256 minAmountOut
    ) external payable returns (uint256 amountOut);
}// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import "./interfaces/ISelfPermit.sol";
import "./interfaces/IERC20PermitAllowed.sol";

/// @title Self Permit
/// @notice Functionality to call permit on any EIP-2612-compliant token for use in the route
/// @dev These functions are expected to be embedded in multicalls to allow EOAs to approve a contract and call a function
/// that requires an approval in a single transaction.
abstract contract SelfPermit is ISelfPermit {
    /// @inheritdoc ISelfPermit
    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable override {
        ERC20(token).permit(msg.sender, address(this), value, deadline, v, r, s);
    }

    /// @inheritdoc ISelfPermit
    function selfPermitIfNecessary(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override {
        if (ERC20(token).allowance(msg.sender, address(this)) < value) selfPermit(token, value, deadline, v, r, s);
    }

    /// @inheritdoc ISelfPermit
    function selfPermitAllowed(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable override {
        IERC20PermitAllowed(token).permit(msg.sender, address(this), nonce, expiry, true, v, r, s);
    }

    /// @inheritdoc ISelfPermit
    function selfPermitAllowedIfNecessary(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override {
        if (ERC20(token).allowance(msg.sender, address(this)) < type(uint256).max)
            selfPermitAllowed(token, nonce, expiry, v, r, s);
    }
}// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import {IERC4626} from "./IERC4626.sol";

/// @title Yearn V3 ERC4626 interface
/// @notice Extends the normal 4626 standard with some added Yearn specific functionality
abstract contract IYearn4626 is IERC4626 {
    /*////////////////////////////////////////////////////////
                    Yearn Specific Functions
    ////////////////////////////////////////////////////////*/

    function withdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxLoss
    ) external virtual returns (uint256 shares);

    /// @notice Yearn Specific "withdraw" with withdrawal stack included
    function withdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxLoss,
        address[] memory strategies
    ) external virtual returns (uint256 shares);

    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 maxLoss
    ) external virtual returns (uint256 assets);

    /// @notice Yearn Specific "redeem" with withdrawal stack included
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 maxLoss,
        address[] memory strategies
    ) external virtual returns (uint256 assets);
}// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import {ERC20} from "solmate/tokens/ERC20.sol";

abstract contract IYearnV2 is ERC20 {
    // NOTE: Vyper produces multiple signatures for a given function with "default" args
    function withdraw() external virtual returns (uint256);

    function withdraw(uint256 maxShares) external virtual returns (uint256);

    function withdraw(uint256 maxShares, address recipient) external virtual returns (uint256);

    function withdraw(
        uint256 maxShares,
        address recipient,
        uint256 maxLoss
    ) external virtual returns (uint256);
}// forked from https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/ISelfPermit.sol

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

/// @title Self Permit
/// @notice Functionality to call permit on any EIP-2612-compliant token for use in the route
interface ISelfPermit {
    /// @notice Permits this contract to spend a given token from `msg.sender`
    /// @dev The `owner` is always msg.sender and the `spender` is always address(this).
    /// @param token The address of the token spent
    /// @param value The amount that can be spent of token
    /// @param deadline A timestamp, the current blocktime must be less than or equal to this timestamp
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice Permits this contract to spend a given token from `msg.sender`
    /// @dev The `owner` is always msg.sender and the `spender` is always address(this).
    /// Can be used instead of #selfPermit to prevent calls from failing due to a frontrun of a call to #selfPermit
    /// @param token The address of the token spent
    /// @param value The amount that can be spent of token
    /// @param deadline A timestamp, the current blocktime must be less than or equal to this timestamp
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function selfPermitIfNecessary(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice Permits this contract to spend the sender's tokens for permit signatures that have the `allowed` parameter
    /// @dev The `owner` is always msg.sender and the `spender` is always address(this)
    /// @param token The address of the token spent
    /// @param nonce The current nonce of the owner
    /// @param expiry The timestamp at which the permit is no longer valid
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function selfPermitAllowed(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice Permits this contract to spend the sender's tokens for permit signatures that have the `allowed` parameter
    /// @dev The `owner` is always msg.sender and the `spender` is always address(this)
    /// Can be used instead of #selfPermitAllowed to prevent calls from failing due to a frontrun of a call to #selfPermitAllowed.
    /// @param token The address of the token spent
    /// @param nonce The current nonce of the owner
    /// @param expiry The timestamp at which the permit is no longer valid
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function selfPermitAllowedIfNecessary(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
}// forked from https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/external/IERC20PermitAllowed.sol

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Interface for permit
/// @notice Interface used by DAI/CHAI for permit
interface IERC20PermitAllowed {
    /// @notice Approve the spender to spend some tokens via the holder signature
    /// @dev This is the permit interface used by DAI and CHAI
    /// @param holder The address of the token holder, the token owner
    /// @param spender The address of the token spender
    /// @param nonce The holder's nonce, increases at each call to permit
    /// @param expiry The timestamp at which the permit is no longer valid
    /// @param allowed Boolean that sets approval amount, true for type(uint256).max and false for 0
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @title ERC4626 interface
/// See: https://eips.ethereum.org/EIPS/eip-4626
abstract contract IERC4626 is ERC20 {
    /*////////////////////////////////////////////////////////
                      Events
    ////////////////////////////////////////////////////////*/

    /// @notice `sender` has exchanged `assets` for `shares`,
    /// and transferred those `shares` to `receiver`.
    event Deposit(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);

    /// @notice `sender` has exchanged `shares` for `assets`,
    /// and transferred those `assets` to `receiver`.
    event Withdraw(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);

    /*////////////////////////////////////////////////////////
                      Vault properties
    ////////////////////////////////////////////////////////*/

    /// @notice The address of the underlying ERC20 token used for
    /// the Vault for accounting, depositing, and withdrawing.
    function asset() external view virtual returns (address asset);

    /// @notice Total amount of the underlying asset that
    /// is "managed" by Vault.
    function totalAssets() external view virtual returns (uint256 totalAssets);

    /*////////////////////////////////////////////////////////
                      Deposit/Withdrawal Logic
    ////////////////////////////////////////////////////////*/

    /// @notice Mints `shares` Vault shares to `receiver` by
    /// depositing exactly `assets` of underlying tokens.
    function deposit(uint256 assets, address receiver) external virtual returns (uint256 shares);

    /// @notice Mints exactly `shares` Vault shares to `receiver`
    /// by depositing `assets` of underlying tokens.
    function mint(uint256 shares, address receiver) external virtual returns (uint256 assets);

    /// @notice Redeems `shares` from `owner` and sends `assets`
    /// of underlying tokens to `receiver`.
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external virtual returns (uint256 shares);

    /// @notice Redeems `shares` from `owner` and sends `assets`
    /// of underlying tokens to `receiver`.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external virtual returns (uint256 assets);

    /*////////////////////////////////////////////////////////
                      Vault Accounting Logic
    ////////////////////////////////////////////////////////*/

    /// @notice The amount of shares that the vault would
    /// exchange for the amount of assets provided, in an
    /// ideal scenario where all the conditions are met.
    function convertToShares(uint256 assets) external view virtual returns (uint256 shares);

    /// @notice The amount of assets that the vault would
    /// exchange for the amount of shares provided, in an
    /// ideal scenario where all the conditions are met.
    function convertToAssets(uint256 shares) external view virtual returns (uint256 assets);

    /// @notice Total number of underlying assets that can
    /// be deposited by `owner` into the Vault, where `owner`
    /// corresponds to the input parameter `receiver` of a
    /// `deposit` call.
    function maxDeposit(address owner) external view virtual returns (uint256 maxAssets);

    /// @notice Allows an on-chain or off-chain user to simulate
    /// the effects of their deposit at the current block, given
    /// current on-chain conditions.
    function previewDeposit(uint256 assets) external view virtual returns (uint256 shares);

    /// @notice Total number of underlying shares that can be minted
    /// for `owner`, where `owner` corresponds to the input
    /// parameter `receiver` of a `mint` call.
    function maxMint(address owner) external view virtual returns (uint256 maxShares);

    /// @notice Allows an on-chain or off-chain user to simulate
    /// the effects of their mint at the current block, given
    /// current on-chain conditions.
    function previewMint(uint256 shares) external view virtual returns (uint256 assets);

    /// @notice Total number of underlying assets that can be
    /// withdrawn from the Vault by `owner`, where `owner`
    /// corresponds to the input parameter of a `withdraw` call.
    function maxWithdraw(address owner) external view virtual returns (uint256 maxAssets);

    /// @notice Allows an on-chain or off-chain user to simulate
    /// the effects of their withdrawal at the current block,
    /// given current on-chain conditions.
    function previewWithdraw(uint256 assets) external view virtual returns (uint256 shares);

    /// @notice Total number of underlying shares that can be
    /// redeemed from the Vault by `owner`, where `owner` corresponds
    /// to the input parameter of a `redeem` call.
    function maxRedeem(address owner) external view virtual returns (uint256 maxShares);

    /// @notice Allows an on-chain or off-chain user to simulate
    /// the effects of their redeemption at the current block,
    /// given current on-chain conditions.
    function previewRedeem(uint256 shares) external view virtual returns (uint256 assets);
}