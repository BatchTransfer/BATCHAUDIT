// File: contracts/Lock.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.9;

error InvalidUnlockTime(uint256 unlockTime);
error NotOwner(address owner);
error UnlockTimeNotReached(uint256 unlockTime);

contract Lock {
    uint256 public unlockTime;
    address payable public owner;

    event Withdrawal(uint256 amount, uint256 when);

    constructor(uint256 _unlockTime) payable {
        if (block.timestamp >= _unlockTime) {
            // revert InvalidUnlockTime(_unlockTime);
            _unlockTime += block.timestamp;
        }

        unlockTime = _unlockTime + block.timestamp;
        owner = payable(msg.sender);
    }

    function withdraw() public {
        if (block.timestamp < unlockTime) {
            revert UnlockTimeNotReached(unlockTime);
        }

        if (msg.sender != owner) {
            revert NotOwner(owner);
        }

        emit Withdrawal(address(this).balance, block.timestamp);

        owner.transfer(address(this).balance);
    }
}


// File: contracts/X7100DiscountAuthority.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-19
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for X7100 series token fee discounts

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setEcosystemMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(ecoMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(ecoMaxiNFT);
        ecoMaxiNFT = IERC721(tokenAddress);
        emit EcosystemMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function setLiquidityMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(liqMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(liqMaxiNFT);
        liqMaxiNFT = IERC721(tokenAddress);
        emit LiquidityMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function setMagisterNFT(address tokenAddress) external onlyOwner {
        require(address(magisterNFT) != tokenAddress);
        address oldTokenAddress = address(magisterNFT);
        magisterNFT = IERC721(tokenAddress);
        emit MagisterNFTSet(oldTokenAddress, tokenAddress);
    }

    function setX7DAO(address tokenAddress) external onlyOwner {
        require(address(x7dao) != tokenAddress);
        address oldTokenAddress = address(x7dao);
        x7dao = IERC20(tokenAddress);
        emit X7DAOTokenSet(oldTokenAddress, tokenAddress);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
}

interface IDiscountAuthority {
    function discountRatio(address) external view returns (uint256, uint256);
}

contract X7100DiscountAuthority is Ownable {
    IERC721 public ecoMaxiNFT;
    IERC721 public liqMaxiNFT;
    IERC721 public magisterNFT;
    IERC20 public x7dao;

    event EcosystemMaxiNFTSet(address indexed oldTokenAddress, address indexed newTokenAddress);
    event LiquidityMaxiNFTSet(address indexed oldTokenAddress, address indexed newTokenAddress);
    event MagisterNFTSet(address indexed oldTokenAddress, address indexed newTokenAddress);
    event X7DAOTokenSet(address indexed oldTokenAddress, address indexed newTokenAddress);

    constructor() Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {}

    function setEcosystemMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(ecoMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(ecoMaxiNFT);
        ecoMaxiNFT = IERC721(tokenAddress);
        emit EcosystemMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function setLiquidityMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(liqMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(liqMaxiNFT);
        liqMaxiNFT = IERC721(tokenAddress);
        emit LiquidityMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function setMagisterNFT(address tokenAddress) external onlyOwner {
        require(address(magisterNFT) != tokenAddress);
        address oldTokenAddress = address(magisterNFT);
        magisterNFT = IERC721(tokenAddress);
        emit MagisterNFTSet(oldTokenAddress, tokenAddress);
    }

    function setX7DAO(address tokenAddress) external onlyOwner {
        require(address(x7dao) != tokenAddress);
        address oldTokenAddress = address(x7dao);
        x7dao = IERC20(tokenAddress);
        emit X7DAOTokenSet(oldTokenAddress, tokenAddress);
    }

    function discountRatio(address swapper) external view returns (uint256 numerator, uint256 denominator) {
        numerator = 1;
        denominator = 1;

        if (liqMaxiNFT.balanceOf(swapper) > 0 || x7dao.balanceOf(swapper) >= 50000 * 10 ** 18) {
            // 50% Fee Discount
            numerator = 50;
            denominator = 100;
        } else if (ecoMaxiNFT.balanceOf(swapper) > 0 || magisterNFT.balanceOf(swapper) > 0) {
            // 25% Fee Discount
            numerator = 75;
            denominator = 100;
        }
    }
}


// File: contracts/X7100LiquidityHub.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for managing X7100 fee tokens

This liquidity hub is shared by the X7100 series tokens (X7101-X7105).
It uses a simple liquidity balancing algorithm to add liquidity to the least liquified token.
It has been upgraded from the X7000 series to improve the gas for any individual trade.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setShares(uint256 distributeShare_, uint256 liquidityShare_, uint256 lendingPoolShare_, uint256 treasuryShare_) external onlyOwner {
        require(distributeShare + liquidityShare + lendingPoolShare + treasuryShare == 1000);

        require(distributeShare_ >= minShare && distributeShare_ <= maxShare);
        require(liquidityShare_ >= minShare && liquidityShare_ <= maxShare);
        require(lendingPoolShare_ >= minShare && lendingPoolShare_ <= maxShare);
        require(treasuryShare_ >= minShare && treasuryShare_ <= maxShare);

        distributeShare = distributeShare_;
        liquidityShare = liquidityShare_;
        lendingPoolShare = lendingPoolShare_;
        treasuryShare = treasuryShare_;

        emit SharesSet(distributeShare_, liquidityShare_, lendingPoolShare_, treasuryShare_);
    }

    function setRouter(address router_) external onlyOwner {
        require(router_ != address(router));
        router = IUniswapV2Router(router_);
        emit RouterSet(router_);
    }

    function setOffRampPair(address tokenAddress, address offRampPairAddress) external onlyOwner {
        require(nativeTokenPairs[tokenAddress] != offRampPairAddress);
        nativeTokenPairs[tokenAddress] = offRampPairAddress;
        emit OffRampPairSet(tokenAddress, offRampPairAddress);
    }

    function setBalanceThreshold(uint256 threshold) external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThreshold = threshold;
        emit BalanceThresholdSet(threshold);
    }

    function setLiquidityBalanceThreshold(uint256 threshold) external onlyOwner {
        require(!liquidityBalanceThresholdFrozen);
        liquidityBalanceThreshold = threshold;
        emit LiquidityBalanceThresholdSet(threshold);
    }

    function setLiquidityRatioTarget(uint256 liquidityRatioTarget_) external onlyOwner {
        require(liquidityRatioTarget_ != liquidityRatioTarget);
        require(liquidityRatioTarget_ >= minLiquidityRatioTarget && liquidityRatioTarget <= maxLiquidityRatioTarget);
        liquidityRatioTarget = liquidityRatioTarget_;
        emit LiquidityRatioTargetSet(liquidityRatioTarget_);
    }

    function setLiquidityTokenReceiver(address liquidityTokenReceiver_) external onlyOwner {
        require(
            liquidityTokenReceiver_ != address(0)
            && liquidityTokenReceiver_ != address(0x000000000000000000000000000000000000dEaD)
            && liquidityTokenReceiver != liquidityTokenReceiver_
        );

        address oldLiquidityTokenReceiver = liquidityTokenReceiver;
        liquidityTokenReceiver = liquidityTokenReceiver_;
        emit LiquidityTokenReceiverSet(oldLiquidityTokenReceiver, liquidityTokenReceiver_);
    }

    function setDistributionTarget(address target) external onlyOwner {
        require(
            target != address(0)
            && target != address(0x000000000000000000000000000000000000dEaD)
            && distributeTarget != payable(target)
        );
        require(!distributeTargetFrozen);
        address oldTarget = address(distributeTarget);
        distributeTarget = payable(target);
        emit DistributeTargetSet(oldTarget, distributeTarget);
    }

    function setLendingPoolTarget(address target) external onlyOwner {
        require(
            target != address(0) &&
            target != address(0x000000000000000000000000000000000000dEaD)
            && lendingPoolTarget != payable(target)
        );
        require(!lendingPoolTargetFrozen);
        address oldTarget = address(lendingPoolTarget);
        lendingPoolTarget = payable(target);
        emit LendingPoolTargetSet(oldTarget, target);
    }

    function setTreasuryTarget(address target) external onlyOwner {
        require(
            target != address(0)
            && target != address(0x000000000000000000000000000000000000dEaD)
            && treasuryTarget != payable(target)
        );
        require(!treasuryTargetFrozen);
        address oldTarget = address(treasuryTarget);
        treasuryTarget = payable(target);
        emit TreasuryTargetSet(oldTarget, target);
    }

    function freezeTreasuryTarget() external onlyOwner {
        require(!treasuryTargetFrozen);
        treasuryTargetFrozen = true;
        emit TreasuryTargetFrozen();
    }

    function freezeDistributeTarget() external onlyOwner {
        require(!distributeTargetFrozen);
        distributeTargetFrozen = true;
        emit DistributeTargetFrozen();
    }

    function freezeLendingPoolTarget() external onlyOwner {
        require(!lendingPoolTargetFrozen);
        lendingPoolTargetFrozen = true;
        emit LendingPoolTargetFrozen();
    }

    function freezeBalanceThreshold() external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThresholdFrozen = true;
        emit BalanceThresholdFrozen();
    }

    function freezeLiquidityBalanceThreshold() external onlyOwner {
        require(!liquidityBalanceThresholdFrozen);
        liquidityBalanceThresholdFrozen = true;
        emit LiquidityBalanceThresholdFrozen();
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    function circulatingSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Router {
    function WETH() external returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface ILiquidityHub {
    function processFees(address) external;
}

interface IX7EcosystemSplitter {
    function takeBalance() external;
}

interface IWETH {
    function withdraw(uint) external;
}

contract X7100LiquidityHub is Ownable, ILiquidityHub {
    IUniswapV2Router public router;

    address public liquidityTokenReceiver;

    // This is "equivalent" to 5-99%.
    // There really is only ~20m tokens circulating per (average number)
    // So a 198/200 is a 99 Percent
    uint256 public minLiquidityRatioTarget = 10;
    uint256 public maxLiquidityRatioTarget = 198;

    // For the constellation, the target liquidity is in the ~75% range to create extremely
    // low price slippage for parking of LP providing capital.
    uint256 public liquidityRatioTarget = 150;

    uint256 public minShare = 150;
    uint256 public maxShare = 400;

    uint256 public distributeShare = 300;
    uint256 public liquidityShare = 300;
    uint256 public lendingPoolShare = 250;
    uint256 public treasuryShare = 150;

    uint256 public balanceThreshold = 1 ether;
    uint256 public liquidityBalanceThreshold = 10 ** 16;

    uint256 public distributeBalance;
    uint256 public lendingPoolBalance;
    uint256 public treasuryBalance;
    uint256 public liquidityBalance;
    mapping(address => uint256) public liquidityTokenBalance;

    address payable public distributeTarget;
    address payable public lendingPoolTarget;
    address payable public treasuryTarget;

    bool public distributeTargetFrozen;
    bool public lendingPoolTargetFrozen;
    bool public treasuryTargetFrozen;
    bool public balanceThresholdFrozen;
    bool public liquidityBalanceThresholdFrozen;
    bool public constellationTokensFrozen;

    address public leastLiquidTokenAddress;
    mapping(address => address) public nativeTokenPairs;
    mapping(address => bool) public isConstellationToken;

    event SharesSet(uint256 distributeShare, uint256 liquidityShare, uint256 lendingPoolShare, uint256 treasuryShare);
    event OffRampPairSet(address indexed token, address indexed offRampPair);
    event DistributeTargetSet(address indexed oldTarget, address indexed newTarget);
    event LendingPoolTargetSet(address indexed oldTarget, address indexed newTarget);
    event TreasuryTargetSet(address indexed oldTarget, address indexed newTarget);
    event LiquidityRatioTargetSet(uint256 liquidityRatioTarget);
    event LiquidityTokenReceiverSet(address indexed oldReciever, address indexed newReceiver);
    event BalanceThresholdSet(uint256 threshold);
    event LiquidityBalanceThresholdSet(uint256 threshold);
    event ConstellationTokenSet(address indexed tokenAddress, bool isQuint);
    event RouterSet(address router);
    event TreasuryTargetFrozen();
    event LendingPoolTargetFrozen();
    event DistributeTargetFrozen();
    event BalanceThresholdFrozen();
    event LiquidityBalanceThresholdFrozen();
    event ConstellationTokensFrozen();

    constructor(address router_) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        router = IUniswapV2Router(router_);
        emit RouterSet(router_);
    }

    receive() external payable {}

    function setShares(
        uint256 distributeShare_,
        uint256 liquidityShare_,
        uint256 lendingPoolShare_,
        uint256 treasuryShare_
    ) external onlyOwner {
        require(distributeShare + liquidityShare + lendingPoolShare + treasuryShare == 1000);

        require(distributeShare_ >= minShare && distributeShare_ <= maxShare);
        require(liquidityShare_ >= minShare && liquidityShare_ <= maxShare);
        require(lendingPoolShare_ >= minShare && lendingPoolShare_ <= maxShare);
        require(treasuryShare_ >= minShare && treasuryShare_ <= maxShare);

        distributeShare = distributeShare_;
        liquidityShare = liquidityShare_;
        lendingPoolShare = lendingPoolShare_;
        treasuryShare = treasuryShare_;

        emit SharesSet(distributeShare_, liquidityShare_, lendingPoolShare_, treasuryShare_);
    }

    function setRouter(address router_) external onlyOwner {
        require(router_ != address(router));
        router = IUniswapV2Router(router_);
        emit RouterSet(router_);
    }

    function setOffRampPair(address tokenAddress, address offRampPairAddress) external onlyOwner {
        require(nativeTokenPairs[tokenAddress] != offRampPairAddress);
        nativeTokenPairs[tokenAddress] = offRampPairAddress;
        emit OffRampPairSet(tokenAddress, offRampPairAddress);
    }

    function setBalanceThreshold(uint256 threshold) external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThreshold = threshold;
        emit BalanceThresholdSet(threshold);
    }

    function setLiquidityBalanceThreshold(uint256 threshold) external onlyOwner {
        require(!liquidityBalanceThresholdFrozen);
        liquidityBalanceThreshold = threshold;
        emit LiquidityBalanceThresholdSet(threshold);
    }

    function setLiquidityRatioTarget(uint256 liquidityRatioTarget_) external onlyOwner {
        require(liquidityRatioTarget_ != liquidityRatioTarget);
        require(liquidityRatioTarget_ >= minLiquidityRatioTarget && liquidityRatioTarget <= maxLiquidityRatioTarget);
        liquidityRatioTarget = liquidityRatioTarget_;
        emit LiquidityRatioTargetSet(liquidityRatioTarget_);
    }

    function setLiquidityTokenReceiver(address liquidityTokenReceiver_) external onlyOwner {
        require(
            liquidityTokenReceiver_ != address(0) &&
                liquidityTokenReceiver_ != address(0x000000000000000000000000000000000000dEaD) &&
                liquidityTokenReceiver != liquidityTokenReceiver_
        );

        address oldLiquidityTokenReceiver = liquidityTokenReceiver;
        liquidityTokenReceiver = liquidityTokenReceiver_;
        emit LiquidityTokenReceiverSet(oldLiquidityTokenReceiver, liquidityTokenReceiver_);
    }

    function setDistributionTarget(address target) external onlyOwner {
        require(
            target != address(0) &&
                target != address(0x000000000000000000000000000000000000dEaD) &&
                distributeTarget != payable(target)
        );
        require(!distributeTargetFrozen);
        address oldTarget = address(distributeTarget);
        distributeTarget = payable(target);
        emit DistributeTargetSet(oldTarget, distributeTarget);
    }

    function setLendingPoolTarget(address target) external onlyOwner {
        require(
            target != address(0) &&
                target != address(0x000000000000000000000000000000000000dEaD) &&
                lendingPoolTarget != payable(target)
        );
        require(!lendingPoolTargetFrozen);
        address oldTarget = address(lendingPoolTarget);
        lendingPoolTarget = payable(target);
        emit LendingPoolTargetSet(oldTarget, target);
    }

    function setConstellationToken(address tokenAddress, bool isQuint) external onlyOwner {
        require(isConstellationToken[tokenAddress] != isQuint);
        isConstellationToken[tokenAddress] = isQuint;
        emit ConstellationTokenSet(tokenAddress, isQuint);
    }

    function setTreasuryTarget(address target) external onlyOwner {
        require(
            target != address(0) &&
                target != address(0x000000000000000000000000000000000000dEaD) &&
                treasuryTarget != payable(target)
        );
        require(!treasuryTargetFrozen);
        address oldTarget = address(treasuryTarget);
        treasuryTarget = payable(target);
        emit TreasuryTargetSet(oldTarget, target);
    }

    function freezeTreasuryTarget() external onlyOwner {
        require(!treasuryTargetFrozen);
        treasuryTargetFrozen = true;
        emit TreasuryTargetFrozen();
    }

    function freezeDistributeTarget() external onlyOwner {
        require(!distributeTargetFrozen);
        distributeTargetFrozen = true;
        emit DistributeTargetFrozen();
    }

    function freezeLendingPoolTarget() external onlyOwner {
        require(!lendingPoolTargetFrozen);
        lendingPoolTargetFrozen = true;
        emit LendingPoolTargetFrozen();
    }

    function freezeBalanceThreshold() external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThresholdFrozen = true;
        emit BalanceThresholdFrozen();
    }

    function freezeLiquidityBalanceThreshold() external onlyOwner {
        require(!liquidityBalanceThresholdFrozen);
        liquidityBalanceThresholdFrozen = true;
        emit LiquidityBalanceThresholdFrozen();
    }

    function freezeConstellationTokens() external onlyOwner {
        require(!constellationTokensFrozen);
        constellationTokensFrozen = true;
        emit ConstellationTokensFrozen();
    }

    function processFees(address tokenAddress) external {
        require(tokenAddress != address(0), "Invalid token address");
        require(IERC20(tokenAddress).balanceOf(address(this)) > 0, "No tokens to process");

        uint256 startingETHBalance = address(this).balance;

        uint256 tokensToSwap = IERC20(tokenAddress).balanceOf(address(this));

        bool processingConstellationToken = isConstellationToken[tokenAddress];

        if (processingConstellationToken) {
            tokensToSwap -= liquidityTokenBalance[tokenAddress];
        }

        if (tokensToSwap > 0) {
            swapTokensForEth(tokenAddress, tokensToSwap);
        }

        if (leastLiquidTokenAddress == address(0) && processingConstellationToken) {
            leastLiquidTokenAddress = tokenAddress;
        } else if (processingConstellationToken && tokenAddress != leastLiquidTokenAddress) {
            uint256 pairETHBalance = IERC20(router.WETH()).balanceOf(nativeTokenPairs[tokenAddress]);
            uint256 leastLiquidTokenPairETHBalance = IERC20(router.WETH()).balanceOf(
                nativeTokenPairs[leastLiquidTokenAddress]
            );

            if (pairETHBalance <= leastLiquidTokenPairETHBalance) {
                leastLiquidTokenAddress = tokenAddress;
            }
        }

        uint256 ETHForDistribution = address(this).balance - startingETHBalance;

        distributeBalance += (ETHForDistribution * distributeShare) / 1000;
        lendingPoolBalance += (ETHForDistribution * lendingPoolShare) / 1000;
        treasuryBalance += (ETHForDistribution * treasuryShare) / 1000;
        liquidityBalance = address(this).balance - distributeBalance - lendingPoolBalance - treasuryBalance;

        if (distributeBalance >= balanceThreshold) {
            sendDistributeBalance();
        }

        if (lendingPoolBalance >= balanceThreshold) {
            sendLendingPoolBalance();
        }

        if (treasuryBalance >= balanceThreshold) {
            sendTreasuryBalance();
        }

        if (liquidityBalance >= liquidityBalanceThreshold) {
            buyBackAndAddLiquidity(leastLiquidTokenAddress);
        }
    }

    function sendDistributeBalance() public {
        if (distributeTarget == address(0)) {
            return;
        }

        IX7EcosystemSplitter(distributeTarget).takeBalance();

        uint256 ethToSend = distributeBalance;
        distributeBalance = 0;

        (bool success, ) = distributeTarget.call{ value: ethToSend }("");

        if (!success) {
            distributeBalance = ethToSend;
        }
    }

    function sendTreasuryBalance() public {
        if (treasuryTarget == address(0)) {
            return;
        }

        uint256 ethToSend = treasuryBalance;
        treasuryBalance = 0;

        (bool success, ) = treasuryTarget.call{ value: ethToSend }("");

        if (!success) {
            treasuryBalance = ethToSend;
        }
    }

    function sendLendingPoolBalance() public {
        if (lendingPoolTarget == address(0)) {
            return;
        }

        uint256 ethToSend = lendingPoolBalance;
        lendingPoolBalance = 0;

        (bool success, ) = lendingPoolTarget.call{ value: ethToSend }("");

        if (!success) {
            lendingPoolBalance = ethToSend;
        }
    }

    function buyBackAndAddLiquidity(address tokenAddress) internal {
        uint256 ethForSwap;
        uint256 startingETHBalance = address(this).balance;

        IERC20 token = IERC20(tokenAddress);
        address offRampPair = nativeTokenPairs[tokenAddress];

        if (token.balanceOf(offRampPair) > (token.circulatingSupply() * liquidityRatioTarget) / 1000) {
            ethForSwap = liquidityBalance;
            liquidityBalance = 0;
            swapEthForTokens(tokenAddress, ethForSwap);
        } else {
            ethForSwap = liquidityBalance;
            liquidityBalance = 0;

            if (token.balanceOf(address(this)) > 0) {
                addLiquidityETH(tokenAddress, token.balanceOf(address(this)), ethForSwap);
                ethForSwap = ethForSwap - (startingETHBalance - address(this).balance);
            }

            if (ethForSwap > 0) {
                uint256 ethLeft = ethForSwap;
                ethForSwap = ethLeft / 2;
                uint256 ethForLiquidity = ethLeft - ethForSwap;
                swapEthForTokens(tokenAddress, ethForSwap);
                addLiquidityETH(tokenAddress, token.balanceOf(address(this)), ethForLiquidity);
            }
        }

        liquidityTokenBalance[tokenAddress] = token.balanceOf(address(this));
    }

    function addLiquidityETH(address tokenAddress, uint256 tokenAmount, uint256 ethAmount) internal {
        IERC20(tokenAddress).approve(address(router), tokenAmount);
        router.addLiquidityETH{ value: ethAmount }(
            tokenAddress,
            tokenAmount,
            0,
            0,
            liquidityTokenReceiver,
            block.timestamp
        );
    }

    function swapTokensForEth(address tokenAddress, uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();

        IERC20(tokenAddress).approve(address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function swapEthForTokens(address tokenAddress, uint256 ethAmount) internal {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = tokenAddress;
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: ethAmount }(
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function rescueWETH() external {
        address wethAddress = router.WETH();
        IWETH(wethAddress).withdraw(IERC20(wethAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7101.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-20 Token X7101

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
    }

    function setAMM(address ammAddress, bool isAMM) external {
        require(msg.sender == address(liquidityHub) || msg.sender == owner(), "Only the owner or the liquidity hub may add a new pair");
        ammPair[ammAddress] = isAMM;
    }

    function setOffRampPair(address ammAddress) external {
        require(msg.sender == address(liquidityHub) || msg.sender == owner(), "Only the owner or the liquidity hub may add a new pair");
        offRampPair = ammAddress;
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }

        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

interface ILiquidityHub {
    function processFees(address) external;
}

interface IDiscountAuthority {
    function discountRatio(address) external view returns (uint256, uint256);
}

contract X7101 is ERC20, Ownable {
    IDiscountAuthority public discountAuthority;
    ILiquidityHub public liquidityHub;

    mapping(address => bool) public ammPair;
    address public offRampPair;

    // max 6% fee
    uint256 public maxFeeNumerator = 600;

    // 2 % fee
    uint256 public feeNumerator = 200;
    uint256 public feeDenominator = 10000;

    bool discountAuthorityFrozen;
    bool liquidityHubFrozen;

    bool transfersEnabled;

    event LiquidityHubSet(address indexed liquidityHub);
    event DiscountAuthoritySet(address indexed discountAuthority);
    event FeeNumeratorSet(uint256 feeNumerator);
    event AMMSet(address indexed pairAddress, bool isAMM);
    event OffRampPairSet(address indexed offRampPair);
    event LiquidityHubFrozen();
    event DiscountAuthorityFrozen();

    constructor(
        address discountAuthority_,
        address liquidityHub_
    ) ERC20("X7101", "X7101") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        discountAuthority = IDiscountAuthority(discountAuthority_);
        liquidityHub = ILiquidityHub(liquidityHub_);

        _mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 100000000 * 10 ** 18);
    }

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
        emit LiquidityHubSet(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
        emit DiscountAuthoritySet(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
        emit FeeNumeratorSet(feeNumerator_);
    }

    function setAMM(address ammAddress, bool isAMM) external {
        require(
            msg.sender == address(liquidityHub) || msg.sender == owner(),
            "Only the owner or the liquidity hub may add a new pair"
        );
        ammPair[ammAddress] = isAMM;
        emit AMMSet(ammAddress, isAMM);
    }

    function setOffRampPair(address ammAddress) external {
        require(
            msg.sender == address(liquidityHub) || msg.sender == owner(),
            "Only the owner or the liquidity hub may add a new pair"
        );
        offRampPair = ammAddress;
        emit OffRampPairSet(ammAddress);
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
        emit LiquidityHubFrozen();
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
        emit DiscountAuthorityFrozen();
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0)) - balanceOf(address(0x000000000000000000000000000000000000dEaD));
    }

    function enableTrading() external onlyOwner {
        require(!transfersEnabled);
        transfersEnabled = true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(transfersEnabled || from == owner());

        uint256 transferAmount = amount;

        if (from == address(liquidityHub) || to == address(liquidityHub)) {
            super._transfer(from, to, amount);
            return;
        }

        if (ammPair[to] || ammPair[from]) {
            address effectivePrincipal;
            if (ammPair[to]) {
                effectivePrincipal = from;
            } else {
                effectivePrincipal = to;
            }

            (uint256 feeModifierNumerator, uint256 feeModifierDenominator) = discountAuthority.discountRatio(
                effectivePrincipal
            );
            if (feeModifierNumerator > feeModifierDenominator || feeModifierDenominator == 0) {
                feeModifierNumerator = 1;
                feeModifierDenominator = 1;
            }

            uint256 feeAmount = (amount * feeNumerator * feeModifierNumerator) /
                feeDenominator /
                feeModifierDenominator;

            super._transfer(from, address(liquidityHub), feeAmount);
            transferAmount = amount - feeAmount;
        }

        if (to == offRampPair) {
            liquidityHub.processFees(address(this));
        }

        super._transfer(from, to, transferAmount);
    }

    function rescueETH() external {
        (bool success, ) = payable(address(liquidityHub)).call{ value: address(this).balance }("");
        require(success);
    }

    function rescueTokens(address tokenAddress) external {
        IERC20(tokenAddress).transfer(address(liquidityHub), IERC20(tokenAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7102.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-20 Token X7102

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
    }

    function setAMM(address ammAddress, bool isAMM) external {
        require(msg.sender == address(liquidityHub) || msg.sender == owner(), "Only the owner or the liquidity hub may add a new pair");
        ammPair[ammAddress] = isAMM;
    }

    function setOffRampPair(address ammAddress) external {
        require(msg.sender == address(liquidityHub) || msg.sender == owner(), "Only the owner or the liquidity hub may add a new pair");
        offRampPair = ammAddress;
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }

        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

interface ILiquidityHub {
    function processFees(address) external;
}

interface IDiscountAuthority {
    function discountRatio(address) external view returns (uint256, uint256);
}

contract X7102 is ERC20, Ownable {
    IDiscountAuthority public discountAuthority;
    ILiquidityHub public liquidityHub;

    mapping(address => bool) public ammPair;
    address public offRampPair;

    // max 6% fee
    uint256 public maxFeeNumerator = 600;

    // 2 % fee
    uint256 public feeNumerator = 200;
    uint256 public feeDenominator = 10000;

    bool discountAuthorityFrozen;
    bool liquidityHubFrozen;

    bool transfersEnabled;

    event LiquidityHubSet(address indexed liquidityHub);
    event DiscountAuthoritySet(address indexed discountAuthority);
    event FeeNumeratorSet(uint256 feeNumerator);
    event AMMSet(address indexed pairAddress, bool isAMM);
    event OffRampPairSet(address indexed offRampPair);
    event LiquidityHubFrozen();
    event DiscountAuthorityFrozen();

    constructor(
        address discountAuthority_,
        address liquidityHub_
    ) ERC20("X7102", "X7102") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        discountAuthority = IDiscountAuthority(discountAuthority_);
        liquidityHub = ILiquidityHub(liquidityHub_);

        _mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 100000000 * 10 ** 18);
    }

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
        emit LiquidityHubSet(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
        emit DiscountAuthoritySet(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
        emit FeeNumeratorSet(feeNumerator_);
    }

    function setAMM(address ammAddress, bool isAMM) external {
        require(
            msg.sender == address(liquidityHub) || msg.sender == owner(),
            "Only the owner or the liquidity hub may add a new pair"
        );
        ammPair[ammAddress] = isAMM;
        emit AMMSet(ammAddress, isAMM);
    }

    function setOffRampPair(address ammAddress) external {
        require(
            msg.sender == address(liquidityHub) || msg.sender == owner(),
            "Only the owner or the liquidity hub may add a new pair"
        );
        offRampPair = ammAddress;
        emit OffRampPairSet(ammAddress);
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
        emit LiquidityHubFrozen();
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
        emit DiscountAuthorityFrozen();
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0)) - balanceOf(address(0x000000000000000000000000000000000000dEaD));
    }

    function enableTrading() external onlyOwner {
        require(!transfersEnabled);
        transfersEnabled = true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(transfersEnabled || from == owner());

        uint256 transferAmount = amount;

        if (from == address(liquidityHub) || to == address(liquidityHub)) {
            super._transfer(from, to, amount);
            return;
        }

        if (ammPair[to] || ammPair[from]) {
            address effectivePrincipal;
            if (ammPair[to]) {
                effectivePrincipal = from;
            } else {
                effectivePrincipal = to;
            }

            (uint256 feeModifierNumerator, uint256 feeModifierDenominator) = discountAuthority.discountRatio(
                effectivePrincipal
            );
            if (feeModifierNumerator > feeModifierDenominator || feeModifierDenominator == 0) {
                feeModifierNumerator = 1;
                feeModifierDenominator = 1;
            }

            uint256 feeAmount = (amount * feeNumerator * feeModifierNumerator) /
                feeDenominator /
                feeModifierDenominator;

            super._transfer(from, address(liquidityHub), feeAmount);
            transferAmount = amount - feeAmount;
        }

        if (to == offRampPair) {
            liquidityHub.processFees(address(this));
        }

        super._transfer(from, to, transferAmount);
    }

    function rescueETH() external {
        (bool success, ) = payable(address(liquidityHub)).call{ value: address(this).balance }("");
        require(success);
    }

    function rescueTokens(address tokenAddress) external {
        IERC20(tokenAddress).transfer(address(liquidityHub), IERC20(tokenAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7103.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-20 Token X7103

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
    }

    function setAMM(address ammAddress, bool isAMM) external {
        require(msg.sender == address(liquidityHub) || msg.sender == owner(), "Only the owner or the liquidity hub may add a new pair");
        ammPair[ammAddress] = isAMM;
    }

    function setOffRampPair(address ammAddress) external {
        require(msg.sender == address(liquidityHub) || msg.sender == owner(), "Only the owner or the liquidity hub may add a new pair");
        offRampPair = ammAddress;
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }

        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

interface ILiquidityHub {
    function processFees(address) external;
}

interface IDiscountAuthority {
    function discountRatio(address) external view returns (uint256, uint256);
}

contract X7103 is ERC20, Ownable {
    IDiscountAuthority public discountAuthority;
    ILiquidityHub public liquidityHub;

    mapping(address => bool) public ammPair;
    address public offRampPair;

    // max 6% fee
    uint256 public maxFeeNumerator = 600;

    // 2 % fee
    uint256 public feeNumerator = 200;
    uint256 public feeDenominator = 10000;

    bool discountAuthorityFrozen;
    bool liquidityHubFrozen;

    bool transfersEnabled;

    event LiquidityHubSet(address indexed liquidityHub);
    event DiscountAuthoritySet(address indexed discountAuthority);
    event FeeNumeratorSet(uint256 feeNumerator);
    event AMMSet(address indexed pairAddress, bool isAMM);
    event OffRampPairSet(address indexed offRampPair);
    event LiquidityHubFrozen();
    event DiscountAuthorityFrozen();

    constructor(
        address discountAuthority_,
        address liquidityHub_
    ) ERC20("X7103", "X7103") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        discountAuthority = IDiscountAuthority(discountAuthority_);
        liquidityHub = ILiquidityHub(liquidityHub_);

        _mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 100000000 * 10 ** 18);
    }

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
        emit LiquidityHubSet(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
        emit DiscountAuthoritySet(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
        emit FeeNumeratorSet(feeNumerator_);
    }

    function setAMM(address ammAddress, bool isAMM) external {
        require(
            msg.sender == address(liquidityHub) || msg.sender == owner(),
            "Only the owner or the liquidity hub may add a new pair"
        );
        ammPair[ammAddress] = isAMM;
        emit AMMSet(ammAddress, isAMM);
    }

    function setOffRampPair(address ammAddress) external {
        require(
            msg.sender == address(liquidityHub) || msg.sender == owner(),
            "Only the owner or the liquidity hub may add a new pair"
        );
        offRampPair = ammAddress;
        emit OffRampPairSet(ammAddress);
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
        emit LiquidityHubFrozen();
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
        emit DiscountAuthorityFrozen();
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0)) - balanceOf(address(0x000000000000000000000000000000000000dEaD));
    }

    function enableTrading() external onlyOwner {
        require(!transfersEnabled);
        transfersEnabled = true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(transfersEnabled || from == owner());

        uint256 transferAmount = amount;

        if (from == address(liquidityHub) || to == address(liquidityHub)) {
            super._transfer(from, to, amount);
            return;
        }

        if (ammPair[to] || ammPair[from]) {
            address effectivePrincipal;
            if (ammPair[to]) {
                effectivePrincipal = from;
            } else {
                effectivePrincipal = to;
            }

            (uint256 feeModifierNumerator, uint256 feeModifierDenominator) = discountAuthority.discountRatio(
                effectivePrincipal
            );
            if (feeModifierNumerator > feeModifierDenominator || feeModifierDenominator == 0) {
                feeModifierNumerator = 1;
                feeModifierDenominator = 1;
            }

            uint256 feeAmount = (amount * feeNumerator * feeModifierNumerator) /
                feeDenominator /
                feeModifierDenominator;

            super._transfer(from, address(liquidityHub), feeAmount);
            transferAmount = amount - feeAmount;
        }

        if (to == offRampPair) {
            liquidityHub.processFees(address(this));
        }

        super._transfer(from, to, transferAmount);
    }

    function rescueETH() external {
        (bool success, ) = payable(address(liquidityHub)).call{ value: address(this).balance }("");
        require(success);
    }

    function rescueTokens(address tokenAddress) external {
        IERC20(tokenAddress).transfer(address(liquidityHub), IERC20(tokenAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7104.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-20 Token X7104

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
    }

    function setAMM(address ammAddress, bool isAMM) external {
        require(msg.sender == address(liquidityHub) || msg.sender == owner(), "Only the owner or the liquidity hub may add a new pair");
        ammPair[ammAddress] = isAMM;
    }

    function setOffRampPair(address ammAddress) external {
        require(msg.sender == address(liquidityHub) || msg.sender == owner(), "Only the owner or the liquidity hub may add a new pair");
        offRampPair = ammAddress;
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }

        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

interface ILiquidityHub {
    function processFees(address) external;
}

interface IDiscountAuthority {
    function discountRatio(address) external view returns (uint256, uint256);
}

contract X7104 is ERC20, Ownable {
    IDiscountAuthority public discountAuthority;
    ILiquidityHub public liquidityHub;

    mapping(address => bool) public ammPair;
    address public offRampPair;

    // max 6% fee
    uint256 public maxFeeNumerator = 600;

    // 2 % fee
    uint256 public feeNumerator = 200;
    uint256 public feeDenominator = 10000;

    bool discountAuthorityFrozen;
    bool liquidityHubFrozen;

    bool transfersEnabled;

    event LiquidityHubSet(address indexed liquidityHub);
    event DiscountAuthoritySet(address indexed discountAuthority);
    event FeeNumeratorSet(uint256 feeNumerator);
    event AMMSet(address indexed pairAddress, bool isAMM);
    event OffRampPairSet(address indexed offRampPair);
    event LiquidityHubFrozen();
    event DiscountAuthorityFrozen();

    constructor(
        address discountAuthority_,
        address liquidityHub_
    ) ERC20("X7104", "X7104") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        discountAuthority = IDiscountAuthority(discountAuthority_);
        liquidityHub = ILiquidityHub(liquidityHub_);

        _mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 100000000 * 10 ** 18);
    }

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
        emit LiquidityHubSet(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
        emit DiscountAuthoritySet(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
        emit FeeNumeratorSet(feeNumerator_);
    }

    function setAMM(address ammAddress, bool isAMM) external {
        require(
            msg.sender == address(liquidityHub) || msg.sender == owner(),
            "Only the owner or the liquidity hub may add a new pair"
        );
        ammPair[ammAddress] = isAMM;
        emit AMMSet(ammAddress, isAMM);
    }

    function setOffRampPair(address ammAddress) external {
        require(
            msg.sender == address(liquidityHub) || msg.sender == owner(),
            "Only the owner or the liquidity hub may add a new pair"
        );
        offRampPair = ammAddress;
        emit OffRampPairSet(ammAddress);
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
        emit LiquidityHubFrozen();
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
        emit DiscountAuthorityFrozen();
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0)) - balanceOf(address(0x000000000000000000000000000000000000dEaD));
    }

    function enableTrading() external onlyOwner {
        require(!transfersEnabled);
        transfersEnabled = true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(transfersEnabled || from == owner());

        uint256 transferAmount = amount;

        if (from == address(liquidityHub) || to == address(liquidityHub)) {
            super._transfer(from, to, amount);
            return;
        }

        if (ammPair[to] || ammPair[from]) {
            address effectivePrincipal;
            if (ammPair[to]) {
                effectivePrincipal = from;
            } else {
                effectivePrincipal = to;
            }

            (uint256 feeModifierNumerator, uint256 feeModifierDenominator) = discountAuthority.discountRatio(
                effectivePrincipal
            );
            if (feeModifierNumerator > feeModifierDenominator || feeModifierDenominator == 0) {
                feeModifierNumerator = 1;
                feeModifierDenominator = 1;
            }

            uint256 feeAmount = (amount * feeNumerator * feeModifierNumerator) /
                feeDenominator /
                feeModifierDenominator;

            super._transfer(from, address(liquidityHub), feeAmount);
            transferAmount = amount - feeAmount;
        }

        if (to == offRampPair) {
            liquidityHub.processFees(address(this));
        }

        super._transfer(from, to, transferAmount);
    }

    function rescueETH() external {
        (bool success, ) = payable(address(liquidityHub)).call{ value: address(this).balance }("");
        require(success);
    }

    function rescueTokens(address tokenAddress) external {
        IERC20(tokenAddress).transfer(address(liquidityHub), IERC20(tokenAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7105.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-20 Token X7105

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
    }

    function setAMM(address ammAddress, bool isAMM) external {
        require(msg.sender == address(liquidityHub) || msg.sender == owner(), "Only the owner or the liquidity hub may add a new pair");
        ammPair[ammAddress] = isAMM;
    }

    function setOffRampPair(address ammAddress) external {
        require(msg.sender == address(liquidityHub) || msg.sender == owner(), "Only the owner or the liquidity hub may add a new pair");
        offRampPair = ammAddress;
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }

        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

interface ILiquidityHub {
    function processFees(address) external;
}

interface IDiscountAuthority {
    function discountRatio(address) external view returns (uint256, uint256);
}

contract X7105 is ERC20, Ownable {
    IDiscountAuthority public discountAuthority;
    ILiquidityHub public liquidityHub;

    mapping(address => bool) public ammPair;
    address public offRampPair;

    // max 6% fee
    uint256 public maxFeeNumerator = 600;

    // 2 % fee
    uint256 public feeNumerator = 200;
    uint256 public feeDenominator = 10000;

    bool discountAuthorityFrozen;
    bool liquidityHubFrozen;

    bool transfersEnabled;

    event LiquidityHubSet(address indexed liquidityHub);
    event DiscountAuthoritySet(address indexed discountAuthority);
    event FeeNumeratorSet(uint256 feeNumerator);
    event AMMSet(address indexed pairAddress, bool isAMM);
    event OffRampPairSet(address indexed offRampPair);
    event LiquidityHubFrozen();
    event DiscountAuthorityFrozen();

    constructor(
        address discountAuthority_,
        address liquidityHub_
    ) ERC20("X7105", "X7105") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        discountAuthority = IDiscountAuthority(discountAuthority_);
        liquidityHub = ILiquidityHub(liquidityHub_);

        _mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 100000000 * 10 ** 18);
    }

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
        emit LiquidityHubSet(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
        emit DiscountAuthoritySet(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
        emit FeeNumeratorSet(feeNumerator_);
    }

    function setAMM(address ammAddress, bool isAMM) external {
        require(
            msg.sender == address(liquidityHub) || msg.sender == owner(),
            "Only the owner or the liquidity hub may add a new pair"
        );
        ammPair[ammAddress] = isAMM;
        emit AMMSet(ammAddress, isAMM);
    }

    function setOffRampPair(address ammAddress) external {
        require(
            msg.sender == address(liquidityHub) || msg.sender == owner(),
            "Only the owner or the liquidity hub may add a new pair"
        );
        offRampPair = ammAddress;
        emit OffRampPairSet(ammAddress);
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
        emit LiquidityHubFrozen();
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
        emit DiscountAuthorityFrozen();
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0)) - balanceOf(address(0x000000000000000000000000000000000000dEaD));
    }

    function enableTrading() external onlyOwner {
        require(!transfersEnabled);
        transfersEnabled = true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(transfersEnabled || from == owner());

        uint256 transferAmount = amount;

        if (from == address(liquidityHub) || to == address(liquidityHub)) {
            super._transfer(from, to, amount);
            return;
        }

        if (ammPair[to] || ammPair[from]) {
            address effectivePrincipal;
            if (ammPair[to]) {
                effectivePrincipal = from;
            } else {
                effectivePrincipal = to;
            }

            (uint256 feeModifierNumerator, uint256 feeModifierDenominator) = discountAuthority.discountRatio(
                effectivePrincipal
            );
            if (feeModifierNumerator > feeModifierDenominator || feeModifierDenominator == 0) {
                feeModifierNumerator = 1;
                feeModifierDenominator = 1;
            }

            uint256 feeAmount = (amount * feeNumerator * feeModifierNumerator) /
                feeDenominator /
                feeModifierDenominator;

            super._transfer(from, address(liquidityHub), feeAmount);
            transferAmount = amount - feeAmount;
        }

        if (to == offRampPair) {
            liquidityHub.processFees(address(this));
        }

        super._transfer(from, to, transferAmount);
    }

    function rescueETH() external {
        (bool success, ) = payable(address(liquidityHub)).call{ value: address(this).balance }("");
        require(success);
    }

    function rescueTokens(address tokenAddress) external {
        IERC20(tokenAddress).transfer(address(liquidityHub), IERC20(tokenAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7BorrowingIncentive.sol
/**
 *Submitted for verification at Etherscan.io on 2023-01-26
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-721 Token "X7 Borrowing Incentive" NFT

A consumable utility NFT offering fee discounts when borrowing funds for initial liquidity on Xchange.

The discount will be determined by the X7 Lending Discount Authority smart contract.

Usage will cause a token owned by the holder to be burned.

The contract owner may permanently discontinue minting once a sufficient number of tokens have been minted.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setAuthorizedConsumer(address consumer, bool isAuthorized) external onlyOwner {
        require(_authorizedConsumers[consumer] != isAuthorized);
        _authorizedConsumers[consumer] = isAuthorized;
        emit AuthorizedConsumerSet(consumer, isAuthorized);
    }

    function discontinueMinting() external onlyOwner {
        require(mintingOpen);
        mintingOpen = false;
        emit MintingDiscontinued();
    }

    function mint(address to) external onlyOwner {
        _mintMany(1, to);
    }

    function mintMany(uint256 numMints, address to) external onlyOwner {
        _mintMany(numMints, to);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{ value: amount }("");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{ value: value }(data);
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
}

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

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

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

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

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
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
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
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
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
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
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

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
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
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract X7BorrowingIncentive is ERC721Enumerable, ERC721Holder, Ownable {
    bool public mintingOpen = true;

    string public _internalBaseURI;

    mapping(address => bool) public authorizedConsumers;

    uint256 nextTokenID = 1;

    event BaseURISet(string oldURI, string newURI);
    event MintingDiscontinued();
    event AuthorizedConsumerSet(address indexed consumer, bool isAuthorized);
    event IncentiveTokenConsumed(address indexed recipient, uint256 indexed tokenID);

    constructor()
        ERC721("X7 Borrowing Incentive", "X7BINCENTIVE")
        Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266))
    {}

    modifier onlyAuthorizedConsumers() {
        require(authorizedConsumers[msg.sender]);
        _;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setAuthorizedConsumer(address consumer, bool isAuthorized) external onlyOwner {
        require(authorizedConsumers[consumer] != isAuthorized);
        authorizedConsumers[consumer] = isAuthorized;
        emit AuthorizedConsumerSet(consumer, isAuthorized);
    }

    function discontinueMinting() external onlyOwner {
        require(mintingOpen);
        mintingOpen = false;
        emit MintingDiscontinued();
    }

    function mint(address to) external onlyOwner {
        _mintMany(1, to);
    }

    function mintMany(uint256 numMints, address to) external onlyOwner {
        _mintMany(numMints, to);
    }

    function consumeOne(address holder) external onlyAuthorizedConsumers {
        uint256 aTokenID = tokenOfOwnerByIndex(holder, 0);
        _burn(aTokenID);
        emit IncentiveTokenConsumed(holder, aTokenID);
    }

    function consumeMany(address holder, uint256 n) external onlyAuthorizedConsumers {
        uint256 aTokenID;
        for (uint i = 0; i < n; i++) {
            aTokenID = tokenOfOwnerByIndex(holder, 0);
            _burn(aTokenID);
            emit IncentiveTokenConsumed(holder, aTokenID);
        }
    }

    function _mintMany(uint256 numMints, address to) internal {
        require(mintingOpen);
        uint256 nextTokenId_ = nextTokenID;

        for (uint i = 0; i < numMints; i++) {
            super._mint(to, nextTokenId_ + i);
        }

        nextTokenID = nextTokenId_ + numMints;
    }

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }
}


// File: contracts/X7BorrowingMaxi.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-721 Token "X7 Borrowing Maxi" NFT

A utility NFT offering fee discounts when borrowing funds for initial liquidity on the X7 DEX.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setMintFeeDestination(address mintFeeDestination_) external onlyOwner {
        require(mintFeeDestination != mintFeeDestination_);
        address oldMintFeeDestination = mintFeeDestination;
        mintFeeDestination = mintFeeDestination_;
        emit MintFeeDestinationSet(oldMintFeeDestination, mintFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        require(mintPrice_ > mintPrice);
        uint256 oldPrice = mintPrice;
        mintPrice = mintPrice_;
        emit MintPriceSet(oldPrice, mintPrice_);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{ value: amount }("");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{ value: value }(data);
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
}

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

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

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

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

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
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
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
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
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
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
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

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
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
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

interface IX7Migration {
    function inMigration(address) external view returns (bool);
}

contract X7BorrowingMaxi is ERC721Enumerable, ERC721Holder, Ownable {
    address payable public mintFeeDestination;
    address payable public treasury;
    string public _internalBaseURI;

    uint256 public maxSupply = 100;
    uint256 public mintPrice = 10 ** 18;
    uint256 public maxMintsPerTransaction = 2;

    bool public mintingOpen;
    bool public whitelistComplete;

    bool public whitelistActive = true;
    IX7Migration public whitelistAuthority;

    event MintingOpen();
    event MintFeeDestinationSet(address indexed oldDestination, address indexed newDestination);
    event MintPriceSet(uint256 oldPrice, uint256 newPrice);
    event BaseURISet(string oldURI, string newURI);
    event WhitelistActivitySet(bool whitelistActive);
    event WhitelistAuthoritySet(address indexed oldWhitelistAuthority, address indexed newWhitelistAuthority);

    constructor(
        address mintFeeDestination_,
        address treasury_
    ) ERC721("X7 Borrowing Maxi", "X7BMAXI") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        mintFeeDestination = payable(mintFeeDestination_);
        treasury = payable(treasury_);
    }

    function whitelist(address holder) external view returns (bool) {
        return whitelistAuthority.inMigration(holder);
    }

    function setMintFeeDestination(address mintFeeDestination_) external onlyOwner {
        require(mintFeeDestination != mintFeeDestination_);
        address oldMintFeeDestination = mintFeeDestination;
        mintFeeDestination = payable(mintFeeDestination_);
        emit MintFeeDestinationSet(oldMintFeeDestination, mintFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        require(mintPrice_ > mintPrice);
        uint256 oldPrice = mintPrice;
        mintPrice = mintPrice_;
        emit MintPriceSet(oldPrice, mintPrice_);
    }

    function setWhitelist(bool isActive) external onlyOwner {
        require(!whitelistComplete);
        require(whitelistActive != isActive);
        whitelistActive = isActive;
        emit WhitelistActivitySet(isActive);
    }

    function setWhitelistComplete() external onlyOwner {
        require(!whitelistComplete);
        whitelistComplete = true;
        whitelistActive = false;
    }

    function setWhitelistAuthority(address whitelistAuthority_) external onlyOwner {
        require(address(whitelistAuthority) != whitelistAuthority_);
        address oldWhitelistAuthority = address(whitelistAuthority);
        whitelistAuthority = IX7Migration(whitelistAuthority_);
        emit WhitelistAuthoritySet(oldWhitelistAuthority, whitelistAuthority_);
    }

    function openMinting() external onlyOwner {
        require(!mintingOpen);
        require(mintFeeDestination != address(0));
        mintingOpen = true;
        emit MintingOpen();
    }

    function mint() external payable {
        _mintMany(1);
    }

    function mintMany(uint256 numMints) external payable {
        _mintMany(numMints);
    }

    function _mintMany(uint256 numMints) internal {
        require(mintingOpen);
        require(!whitelistActive || whitelistAuthority.inMigration(msg.sender));
        require(totalSupply() + numMints <= maxSupply);
        require(numMints > 0 && numMints <= maxMintsPerTransaction);
        require(msg.value == numMints * mintPrice);

        uint256 treasuryFee = (msg.value * 10) / 100;

        bool success;

        (success, ) = treasury.call{ value: treasuryFee }("");
        require(success);

        (success, ) = mintFeeDestination.call{ value: msg.value - treasuryFee }("");
        require(success);

        uint256 nextTokenId = ERC721Enumerable.totalSupply();

        for (uint i = 0; i < numMints; i++) {
            super._mint(msg.sender, nextTokenId + i);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }
}


// File: contracts/X7D.sol
/**
 *Submitted for verification at Etherscan.io on 2023-01-16
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-20 Token X7 Deposit (X7D)

NOTE: DO NOT SEND FUNDS DIRECTLY TO THIS CONTRACT! THEY WILL BE CLAIMED BY THE ECOSYSTEM!

X7D is the ETH backed token of the X7 ecosystem. X7D can be minted from ETH by authorizedMinters and burned to ETH by authorizedRedeemers.
All ETH underpinning X7D will be custodied by smart contracts.

Unlike a strictly wrapped token like WETH, the X7D token contract does not custody any ETH itself. It instead defers this job to authorizedMinters and authorizedRedeemers. This provides flexibility to deploy multiple mechanisms for minting X7D and redeeming X7D into ETH at various timescales, with various associated caveats, and with various multipliers or percentage returns.

The X7D Lending Pool Reserve smart contract will be the first authorizedMinter and authorizedRedeemer.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setAuthorizedMinter(address minterAddress, bool isAuthorized) external onlyOwner {
        require(authorizedMinter[minterAddress] != isAuthorized, "Minter already has specified authorization");
        authorizedMinter[minterAddress] = isAuthorized;

        if (isAuthorized) {
            authorizedMintersIndex[minterAddress] = authorizedMinters.length;
            authorizedMinters.push(minterAddress);
        } else {
            uint256 lastMinterIndex = authorizedMinters.length - 1;
            address lastMinter = authorizedMinters[lastMinterIndex];
            uint256 minterIndex = authorizedMintersIndex[minterAddress];
            authorizedMinters[minterIndex] = lastMinter;
            authorizedMintersIndex[lastMinter] = minterIndex;
            delete authorizedMintersIndex[minterAddress];
            authorizedMinters.pop();
        }

        emit AuthorizedMinterSet(minterAddress, isAuthorized);
    }

    function setAuthorizedRedeemer(address redeemerAddress, bool isAuthorized) external onlyOwner {
        require(authorizedRedeemer[redeemerAddress] != isAuthorized, "Redeemer already has specified authorization");
        authorizedRedeemer[redeemerAddress] = isAuthorized;

        if (isAuthorized) {
            authorizedRedeemersIndex[redeemerAddress] = authorizedRedeemers.length;
            authorizedRedeemers.push(redeemerAddress);
        } else {
            uint256 lastRedeemerIndex = authorizedRedeemers.length - 1;
            address lastRedeemer = authorizedRedeemers[lastRedeemerIndex];
            uint256 redeemerIndex = authorizedRedeemersIndex[redeemerAddress];
            authorizedRedeemers[redeemerIndex] = lastRedeemer;
            authorizedRedeemersIndex[lastRedeemer] = redeemerIndex;
            delete authorizedRedeemersIndex[redeemerAddress];
            authorizedRedeemers.pop();
        }

        emit AuthorizedRedeemerSet(redeemerAddress, isAuthorized);
    }

    function setRecoveredTokenRecipient(address tokenRecipient_) external onlyOwner {
        require(recoveredTokenRecipient != tokenRecipient_);
        address oldRecipient = recoveredTokenRecipient;
        recoveredTokenRecipient = tokenRecipient_;
        emit RecoveredTokenRecipientSet(oldRecipient, tokenRecipient_);
    }

    function setRecoveredETHRecipient(address ETHRecipient_) external onlyOwner {
        require(recoveredETHRecipient != ETHRecipient_);
        address oldRecipient = recoveredETHRecipient;
        recoveredETHRecipient = ETHRecipient_;
        emit RecoveredETHRecipientSet(oldRecipient, ETHRecipient_);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }

        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

// The primary X7D interface for minting and burning from authorized Minters and Burners.
interface IX7D {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface X7DMinter {
    // A minter should implement the following two functions.

    // Call this function to explicitly mint X7D
    function depositETH() external payable;

    // Call this function to return ETH to this contract without minting X7D
    //
    //  This is important as a valid mechanism for a minter to mint from ETH
    //  would be to implement a receive function to automatically mint X7D.
    function returnETH() external payable;
}

interface X7DBurner {
    // A burner/redeemer should implement the following two functions.

    // Call this function to redeem (burn) X7D for ETH
    function withdrawETH(uint256 amount) external;
}

abstract contract TokensCanBeRecovered is Ownable {
    bytes4 private constant TRANSFERSELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    address public recoveredTokenRecipient;

    event RecoveredTokenRecipientSet(address oldRecipient, address newRecipient);

    function setRecoveredTokenRecipient(address tokenRecipient_) external onlyOwner {
        require(recoveredTokenRecipient != tokenRecipient_);
        address oldRecipient = recoveredTokenRecipient;
        recoveredTokenRecipient = tokenRecipient_;
        emit RecoveredTokenRecipientSet(oldRecipient, tokenRecipient_);
    }

    function recoverTokens(address tokenAddress) external {
        require(recoveredTokenRecipient != address(0));
        _safeTransfer(tokenAddress, recoveredTokenRecipient, IERC20(tokenAddress).balanceOf(address(this)));
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(TRANSFERSELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }
}

abstract contract ETHCanBeRecovered is Ownable {
    address public recoveredETHRecipient;

    event RecoveredETHRecipientSet(address oldRecipient, address newRecipient);

    function setRecoveredETHRecipient(address ETHRecipient_) external onlyOwner {
        require(recoveredETHRecipient != ETHRecipient_);
        address oldRecipient = recoveredETHRecipient;
        recoveredETHRecipient = ETHRecipient_;
        emit RecoveredETHRecipientSet(oldRecipient, ETHRecipient_);
    }

    function recoverETH() external {
        require(recoveredETHRecipient != address(0));
        (bool success, ) = recoveredETHRecipient.call{ value: address(this).balance }("");
        require(success);
    }
}

contract X7D is ERC20, Ownable, TokensCanBeRecovered, ETHCanBeRecovered, IX7D {
    mapping(address => bool) public authorizedMinter;
    mapping(address => bool) public authorizedRedeemer;

    address[] public authorizedMinters;
    address[] public authorizedRedeemers;

    // Internal index mapping for array maintenance
    mapping(address => uint256) authorizedMintersIndex;
    mapping(address => uint256) authorizedRedeemersIndex;

    event AuthorizedMinterSet(address indexed minterAddress, bool isAuthorized);
    event AuthorizedRedeemerSet(address indexed redeemerAddress, bool isAuthorized);

    constructor() ERC20("X7 Deposit", "X7D") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {}

    receive() external payable {}

    function authorizedMintersCount() external view returns (uint256) {
        return authorizedMinters.length;
    }

    function authorizedRedeemersCount() external view returns (uint256) {
        return authorizedRedeemers.length;
    }

    function setAuthorizedMinter(address minterAddress, bool isAuthorized) external onlyOwner {
        require(authorizedMinter[minterAddress] != isAuthorized, "Minter already has specified authorization");
        authorizedMinter[minterAddress] = isAuthorized;

        if (isAuthorized) {
            authorizedMintersIndex[minterAddress] = authorizedMinters.length;
            authorizedMinters.push(minterAddress);
        } else {
            uint256 lastMinterIndex = authorizedMinters.length - 1;
            address lastMinter = authorizedMinters[lastMinterIndex];
            uint256 minterIndex = authorizedMintersIndex[minterAddress];
            authorizedMinters[minterIndex] = lastMinter;
            authorizedMintersIndex[lastMinter] = minterIndex;
            delete authorizedMintersIndex[minterAddress];
            authorizedMinters.pop();
        }

        emit AuthorizedMinterSet(minterAddress, isAuthorized);
    }

    function setAuthorizedRedeemer(address redeemerAddress, bool isAuthorized) external onlyOwner {
        require(authorizedRedeemer[redeemerAddress] != isAuthorized, "Redeemer already has specified authorization");
        authorizedRedeemer[redeemerAddress] = isAuthorized;

        if (isAuthorized) {
            authorizedRedeemersIndex[redeemerAddress] = authorizedRedeemers.length;
            authorizedRedeemers.push(redeemerAddress);
        } else {
            uint256 lastRedeemerIndex = authorizedRedeemers.length - 1;
            address lastRedeemer = authorizedRedeemers[lastRedeemerIndex];
            uint256 redeemerIndex = authorizedRedeemersIndex[redeemerAddress];
            authorizedRedeemers[redeemerIndex] = lastRedeemer;
            authorizedRedeemersIndex[lastRedeemer] = redeemerIndex;
            delete authorizedRedeemersIndex[redeemerAddress];
            authorizedRedeemers.pop();
        }

        emit AuthorizedRedeemerSet(redeemerAddress, isAuthorized);
    }

    function mint(address to, uint256 amount) external {
        require(authorizedMinter[msg.sender], "Not authorized to mint X7D");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(authorizedRedeemer[msg.sender], "Not authorized to burn X7D");
        _burn(from, amount);
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0xdEaD));
    }
}


// File: contracts/X7DAO.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-20 Token X7DAO

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
    }

    function setAMM(address ammAddress, bool isAMM) external onlyOwner {
        ammPair[ammAddress] = isAMM;
    }

    function setOffRampPair(address ammAddress) external onlyOwner {
        offRampPair = ammAddress;
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }

        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

interface ILiquidityHub {
    function processFees(address) external;
}

interface IDiscountAuthority {
    function discountRatio(address) external view returns (uint256, uint256);
}

contract X7DAO is ERC20, Ownable {
    IDiscountAuthority public discountAuthority;
    ILiquidityHub public liquidityHub;

    mapping(address => bool) public ammPair;
    address public offRampPair;

    // max 7% fee
    uint256 public maxFeeNumerator = 700;

    // 6 % fee
    uint256 public feeNumerator = 600;
    uint256 public feeDenominator = 10000;

    bool discountAuthorityFrozen;
    bool liquidityHubFrozen;

    bool transfersEnabled;

    event LiquidityHubSet(address indexed liquidityHub);
    event DiscountAuthoritySet(address indexed discountAuthority);
    event FeeNumeratorSet(uint256 feeNumerator);
    event AMMSet(address indexed pairAddress, bool isAMM);
    event OffRampPairSet(address indexed offRampPair);
    event LiquidityHubFrozen();
    event DiscountAuthorityFrozen();

    constructor(
        address discountAuthority_,
        address liquidityHub_
    ) ERC20("X7DAO", "X7DAO") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        discountAuthority = IDiscountAuthority(discountAuthority_);
        liquidityHub = ILiquidityHub(liquidityHub_);

        _mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 100000000 * 10 ** 18);
    }

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
        emit LiquidityHubSet(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
        emit DiscountAuthoritySet(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
        emit FeeNumeratorSet(feeNumerator_);
    }

    function setAMM(address ammAddress, bool isAMM) external onlyOwner {
        ammPair[ammAddress] = isAMM;
        emit AMMSet(ammAddress, isAMM);
    }

    function setOffRampPair(address ammAddress) external onlyOwner {
        offRampPair = ammAddress;
        emit OffRampPairSet(ammAddress);
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
        emit LiquidityHubFrozen();
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
        emit DiscountAuthorityFrozen();
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0)) - balanceOf(address(0x000000000000000000000000000000000000dEaD));
    }

    function enableTrading() external onlyOwner {
        require(!transfersEnabled);
        transfersEnabled = true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(transfersEnabled || from == owner());

        uint256 transferAmount = amount;

        if (from == address(liquidityHub) || to == address(liquidityHub)) {
            super._transfer(from, to, amount);
            return;
        }

        if (ammPair[to] || ammPair[from]) {
            address effectivePrincipal;
            if (ammPair[to]) {
                effectivePrincipal = from;
            } else {
                effectivePrincipal = to;
            }

            (uint256 feeModifierNumerator, uint256 feeModifierDenominator) = discountAuthority.discountRatio(
                effectivePrincipal
            );
            if (feeModifierNumerator > feeModifierDenominator || feeModifierDenominator == 0) {
                feeModifierNumerator = 1;
                feeModifierDenominator = 1;
            }

            uint256 feeAmount = (amount * feeNumerator * feeModifierNumerator) /
                feeDenominator /
                feeModifierDenominator;

            super._transfer(from, address(liquidityHub), feeAmount);
            transferAmount = amount - feeAmount;
        }

        if (to == offRampPair) {
            liquidityHub.processFees(address(this));
        }

        super._transfer(from, to, transferAmount);
    }

    function rescueETH() external {
        (bool success, ) = payable(address(liquidityHub)).call{ value: address(this).balance }("");
        require(success);
    }

    function rescueTokens(address tokenAddress) external {
        IERC20(tokenAddress).transfer(address(liquidityHub), IERC20(tokenAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7DAODiscountAuthority.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-19
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for X7DAO fee discounts

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setEcosystemMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(ecoMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(ecoMaxiNFT);
        ecoMaxiNFT = IERC721(tokenAddress);
        emit EcosystemMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function setLiquidityMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(liqMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(liqMaxiNFT);
        liqMaxiNFT = IERC721(tokenAddress);
        emit LiquidityMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
}

interface IDiscountAuthority {
    function discountRatio(address) external view returns (uint256, uint256);
}

contract X7DAODiscountAuthority is Ownable {
    IERC721 public ecoMaxiNFT;
    IERC721 public liqMaxiNFT;

    event EcosystemMaxiNFTSet(address indexed oldTokenAddress, address indexed newTokenAddress);
    event LiquidityMaxiNFTSet(address indexed oldTokenAddress, address indexed newTokenAddress);

    constructor() Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {}

    function setEcosystemMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(ecoMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(ecoMaxiNFT);
        ecoMaxiNFT = IERC721(tokenAddress);
        emit EcosystemMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function setLiquidityMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(liqMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(liqMaxiNFT);
        liqMaxiNFT = IERC721(tokenAddress);
        emit LiquidityMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function discountRatio(address swapper) external view returns (uint256 numerator, uint256 denominator) {
        numerator = 1;
        denominator = 1;

        if (liqMaxiNFT.balanceOf(swapper) > 0) {
            // 15% discount
            numerator = 85;
            denominator = 100;
        } else if (ecoMaxiNFT.balanceOf(swapper) > 0) {
            // 10% discount
            numerator = 90;
            denominator = 100;
        }
    }
}


// File: contracts/X7DAOLiquidityHub.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-27
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for managing X7DAO fee tokens

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setShares(uint256 distributeShare_, uint256 liquidityShare_, uint256 auxiliaryShare_, uint256 treasuryShare_) external onlyOwner {
        require(distributeShare + liquidityShare + auxiliaryShare + treasuryShare == 1000);

        require(distributeShare_ >= minShare && distributeShare_ <= maxShare);
        require(liquidityShare_ >= minShare && liquidityShare_ <= maxShare);
        require(auxiliaryShare_ >= minShare && auxiliaryShare_ <= maxShare);
        require(treasuryShare_ >= minShare && treasuryShare_ <= maxShare);

        distributeShare = distributeShare_;
        liquidityShare = liquidityShare_;
        auxiliaryShare = auxiliaryShare_;
        treasuryShare = treasuryShare_;

        emit SharesSet(distributeShare_, liquidityShare_, auxiliaryShare_, treasuryShare_);
    }

    function setRouter(address router_) external onlyOwner {
        require(router_ != address(router));
        router = IUniswapV2Router(router_);
        emit RouterSet(router_);
    }

    function setOffRampPair(address offRampPairAddress) external onlyOwner {
        require(offRampPair != offRampPairAddress);
        offRampPair = offRampPairAddress;
        emit OffRampPairSet(offRampPairAddress);
    }

    function setBalanceThreshold(uint256 threshold) external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThreshold = threshold;
        emit BalanceThresholdSet(threshold);
    }

    function setLiquidityRatioTarget(uint256 liquidityRatioTarget_) external onlyOwner {
        require(liquidityRatioTarget_ != liquidityRatioTarget);
        require(liquidityRatioTarget_ >= minLiquidityRatioTarget && liquidityRatioTarget <= maxLiquidityRatioTarget);
        liquidityRatioTarget = liquidityRatioTarget_;
        emit LiquidityRatioTargetSet(liquidityRatioTarget_);
    }

    function setLiquidityTokenReceiver(address liquidityTokenReceiver_) external onlyOwner {
        require(
            liquidityTokenReceiver_ != address(0)
            && liquidityTokenReceiver_ != address(0x000000000000000000000000000000000000dEaD)
            && liquidityTokenReceiver != liquidityTokenReceiver_
        );

        address oldLiquidityTokenReceiver = liquidityTokenReceiver;
        liquidityTokenReceiver = liquidityTokenReceiver_;
        emit LiquidityTokenReceiverSet(oldLiquidityTokenReceiver, liquidityTokenReceiver_);
    }

    function setDistributionTarget(address target) external onlyOwner {
        require(
            target != address(0)
            && target != address(0x000000000000000000000000000000000000dEaD)
            && distributeTarget != payable(target)
        );
        require(!distributeTargetFrozen);
        address oldTarget = address(distributeTarget);
        distributeTarget = payable(target);
        emit DistributeTargetSet(oldTarget, distributeTarget);
    }

    function setAuxiliaryTarget(address target) external onlyOwner {
        require(
            target != address(0) &&
            target != address(0x000000000000000000000000000000000000dEaD)
            && auxiliaryTarget != payable(target)
        );
        require(!auxiliaryTargetFrozen);
        address oldTarget = address(auxiliaryTarget);
        auxiliaryTarget = payable(target);
        emit AuxiliaryTargetSet(oldTarget, target);
    }

    function setTreasuryTarget(address target) external onlyOwner {
        require(
            target != address(0)
            && target != address(0x000000000000000000000000000000000000dEaD)
            && treasuryTarget != payable(target)
        );
        require(!treasuryTargetFrozen);
        address oldTarget = address(treasuryTarget);
        treasuryTarget = payable(target);
        emit TreasuryTargetSet(oldTarget, target);
    }

    function freezeTreasuryTarget() external onlyOwner {
        require(!treasuryTargetFrozen);
        treasuryTargetFrozen = true;
        emit TreasuryTargetFrozen();
    }

    function freezeDistributeTarget() external onlyOwner {
        require(!distributeTargetFrozen);
        distributeTargetFrozen = true;
        emit DistributeTargetFrozen();
    }

    function freezeAuxiliaryTarget() external onlyOwner {
        require(!auxiliaryTargetFrozen);
        auxiliaryTargetFrozen = true;
        emit AuxiliaryTargetFrozen();
    }

    function freezeBalanceThreshold() external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThresholdFrozen = true;
        emit BalanceThresholdFrozen();
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    function circulatingSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Router {
    function WETH() external returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface ILiquidityHub {
    function processFees(address) external;
}

interface IX7EcosystemSplitter {
    function takeBalance() external;
}

interface IWETH {
    function withdraw(uint) external;
}

contract X7DAOLiquidityHub is Ownable, ILiquidityHub {
    IUniswapV2Router public router;
    address public offRampPair;

    IERC20 public x7dao;
    address public liquidityTokenReceiver;
    uint256 public minLiquidityRatioTarget = 5;
    uint256 public maxLiquidityRatioTarget = 99;

    uint256 public liquidityRatioTarget = 15;

    uint256 public minShare = 150;
    uint256 public maxShare = 400;

    uint256 public distributeShare = 300;
    uint256 public liquidityShare = 200;
    uint256 public auxiliaryShare = 250;
    uint256 public treasuryShare = 250;

    uint256 public balanceThreshold = 1 ether;

    uint256 public distributeBalance;
    uint256 public auxiliaryBalance;
    uint256 public treasuryBalance;
    uint256 public liquidityBalance;
    uint256 public x7daoLiquidityBalance;

    address payable public distributeTarget;
    address payable public auxiliaryTarget;
    address payable public treasuryTarget;

    bool public distributeTargetFrozen;
    bool public auxiliaryTargetFrozen;
    bool public treasuryTargetFrozen;
    bool public balanceThresholdFrozen;

    event SharesSet(uint256 distributeShare, uint256 liquidityShare, uint256 auxiliaryShare, uint256 treasuryShare);
    event OffRampPairSet(address indexed offRampPair);
    event DistributeTargetSet(address indexed oldTarget, address indexed newTarget);
    event AuxiliaryTargetSet(address indexed oldTarget, address indexed newTarget);
    event TreasuryTargetSet(address indexed oldTarget, address indexed newTarget);
    event LiquidityRatioTargetSet(uint256 liquidityRatioTarget);
    event LiquidityTokenReceiverSet(address indexed oldReciever, address indexed newReceiver);
    event BalanceThresholdSet(uint256 threshold);
    event RouterSet(address router);
    event TreasuryTargetFrozen();
    event AuxiliaryTargetFrozen();
    event DistributeTargetFrozen();
    event BalanceThresholdFrozen();

    constructor(address x7dao_, address router_) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        router = IUniswapV2Router(router_);
        x7dao = IERC20(x7dao_);
        emit RouterSet(router_);
    }

    receive() external payable {}

    function setShares(
        uint256 distributeShare_,
        uint256 liquidityShare_,
        uint256 auxiliaryShare_,
        uint256 treasuryShare_
    ) external onlyOwner {
        require(distributeShare + liquidityShare + auxiliaryShare + treasuryShare == 1000);

        require(distributeShare_ >= minShare && distributeShare_ <= maxShare);
        require(liquidityShare_ >= minShare && liquidityShare_ <= maxShare);
        require(auxiliaryShare_ >= minShare && auxiliaryShare_ <= maxShare);
        require(treasuryShare_ >= minShare && treasuryShare_ <= maxShare);

        distributeShare = distributeShare_;
        liquidityShare = liquidityShare_;
        auxiliaryShare = auxiliaryShare_;
        treasuryShare = treasuryShare_;

        emit SharesSet(distributeShare_, liquidityShare_, auxiliaryShare_, treasuryShare_);
    }

    function setRouter(address router_) external onlyOwner {
        require(router_ != address(router));
        router = IUniswapV2Router(router_);
        emit RouterSet(router_);
    }

    function setOffRampPair(address offRampPairAddress) external onlyOwner {
        require(offRampPair != offRampPairAddress);
        offRampPair = offRampPairAddress;
        emit OffRampPairSet(offRampPairAddress);
    }

    function setBalanceThreshold(uint256 threshold) external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThreshold = threshold;
        emit BalanceThresholdSet(threshold);
    }

    function setLiquidityRatioTarget(uint256 liquidityRatioTarget_) external onlyOwner {
        require(liquidityRatioTarget_ != liquidityRatioTarget);
        require(liquidityRatioTarget_ >= minLiquidityRatioTarget && liquidityRatioTarget <= maxLiquidityRatioTarget);
        liquidityRatioTarget = liquidityRatioTarget_;
        emit LiquidityRatioTargetSet(liquidityRatioTarget_);
    }

    function setLiquidityTokenReceiver(address liquidityTokenReceiver_) external onlyOwner {
        require(
            liquidityTokenReceiver_ != address(0) &&
                liquidityTokenReceiver_ != address(0x000000000000000000000000000000000000dEaD) &&
                liquidityTokenReceiver != liquidityTokenReceiver_
        );

        address oldLiquidityTokenReceiver = liquidityTokenReceiver;
        liquidityTokenReceiver = liquidityTokenReceiver_;
        emit LiquidityTokenReceiverSet(oldLiquidityTokenReceiver, liquidityTokenReceiver_);
    }

    function setDistributionTarget(address target) external onlyOwner {
        require(
            target != address(0) &&
                target != address(0x000000000000000000000000000000000000dEaD) &&
                distributeTarget != payable(target)
        );
        require(!distributeTargetFrozen);
        address oldTarget = address(distributeTarget);
        distributeTarget = payable(target);
        emit DistributeTargetSet(oldTarget, distributeTarget);
    }

    function setAuxiliaryTarget(address target) external onlyOwner {
        require(
            target != address(0) &&
                target != address(0x000000000000000000000000000000000000dEaD) &&
                auxiliaryTarget != payable(target)
        );
        require(!auxiliaryTargetFrozen);
        address oldTarget = address(auxiliaryTarget);
        auxiliaryTarget = payable(target);
        emit AuxiliaryTargetSet(oldTarget, target);
    }

    function setTreasuryTarget(address target) external onlyOwner {
        require(
            target != address(0) &&
                target != address(0x000000000000000000000000000000000000dEaD) &&
                treasuryTarget != payable(target)
        );
        require(!treasuryTargetFrozen);
        address oldTarget = address(treasuryTarget);
        treasuryTarget = payable(target);
        emit TreasuryTargetSet(oldTarget, target);
    }

    function freezeTreasuryTarget() external onlyOwner {
        require(!treasuryTargetFrozen);
        treasuryTargetFrozen = true;
        emit TreasuryTargetFrozen();
    }

    function freezeDistributeTarget() external onlyOwner {
        require(!distributeTargetFrozen);
        distributeTargetFrozen = true;
        emit DistributeTargetFrozen();
    }

    function freezeAuxiliaryTarget() external onlyOwner {
        require(!auxiliaryTargetFrozen);
        auxiliaryTargetFrozen = true;
        emit AuxiliaryTargetFrozen();
    }

    function freezeBalanceThreshold() external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThresholdFrozen = true;
        emit BalanceThresholdFrozen();
    }

    function processFees(address tokenAddress) external {
        require(tokenAddress != address(0), "Invalid token address");
        require(IERC20(tokenAddress).balanceOf(address(this)) > 0, "No tokens to process");

        uint256 startingETHBalance = address(this).balance;

        uint256 tokensToSwap = IERC20(tokenAddress).balanceOf(address(this));

        if (tokenAddress == address(x7dao)) {
            tokensToSwap -= x7daoLiquidityBalance;
        }

        if (tokensToSwap > 0) {
            swapTokensForEth(tokenAddress, tokensToSwap);
        }

        uint256 ETHForDistribution = address(this).balance - startingETHBalance;

        distributeBalance += (ETHForDistribution * distributeShare) / 1000;
        auxiliaryBalance += (ETHForDistribution * auxiliaryShare) / 1000;
        treasuryBalance += (ETHForDistribution * treasuryShare) / 1000;
        liquidityBalance = address(this).balance - distributeBalance - auxiliaryBalance - treasuryBalance;

        if (distributeBalance >= balanceThreshold) {
            sendDistributeBalance();
        }

        if (auxiliaryBalance >= balanceThreshold) {
            sendAuxiliaryBalance();
        }

        if (treasuryBalance >= balanceThreshold) {
            sendTreasuryBalance();
        }

        if (liquidityBalance >= balanceThreshold) {
            buyBackAndAddLiquidity();
        }
    }

    function sendDistributeBalance() public {
        if (distributeTarget == address(0)) {
            return;
        }

        IX7EcosystemSplitter(distributeTarget).takeBalance();

        uint256 ethToSend = distributeBalance;
        distributeBalance = 0;

        (bool success, ) = distributeTarget.call{ value: ethToSend }("");

        if (!success) {
            distributeBalance = ethToSend;
        }
    }

    function sendTreasuryBalance() public {
        if (treasuryTarget == address(0)) {
            return;
        }

        uint256 ethToSend = treasuryBalance;
        treasuryBalance = 0;

        (bool success, ) = treasuryTarget.call{ value: ethToSend }("");

        if (!success) {
            treasuryBalance = ethToSend;
        }
    }

    function sendAuxiliaryBalance() internal {
        if (auxiliaryTarget == address(0)) {
            return;
        }

        uint256 ethToSend = auxiliaryBalance;
        auxiliaryBalance = 0;

        (bool success, ) = auxiliaryTarget.call{ value: ethToSend }("");

        if (!success) {
            auxiliaryBalance = ethToSend;
        }
    }

    function buyBackAndAddLiquidity() internal {
        uint256 ethForSwap;
        uint256 startingETHBalance = address(this).balance;

        if (x7dao.balanceOf(offRampPair) > (x7dao.circulatingSupply() * liquidityRatioTarget) / 100) {
            ethForSwap = liquidityBalance;
            liquidityBalance = 0;
            swapEthForTokens(ethForSwap);
        } else {
            ethForSwap = liquidityBalance;
            liquidityBalance = 0;

            if (x7dao.balanceOf(address(this)) > 0) {
                addLiquidityETH(x7dao.balanceOf(address(this)), ethForSwap);
                ethForSwap = ethForSwap - (startingETHBalance - address(this).balance);
            }

            if (ethForSwap > 0) {
                uint256 ethLeft = ethForSwap;
                ethForSwap = ethLeft / 2;
                uint256 ethForLiquidity = ethLeft - ethForSwap;
                swapEthForTokens(ethForSwap);
                addLiquidityETH(x7dao.balanceOf(address(this)), ethForLiquidity);
            }
        }

        x7daoLiquidityBalance = x7dao.balanceOf(address(this));
    }

    function addLiquidityETH(uint256 tokenAmount, uint256 ethAmount) internal {
        x7dao.approve(address(router), tokenAmount);
        router.addLiquidityETH{ value: ethAmount }(
            address(x7dao),
            tokenAmount,
            0,
            0,
            liquidityTokenReceiver,
            block.timestamp
        );
    }

    function swapTokensForEth(address tokenAddress, uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();

        IERC20(tokenAddress).approve(address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function swapEthForTokens(uint256 ethAmount) internal {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(x7dao);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: ethAmount }(
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function rescueWETH() external {
        address wethAddress = router.WETH();
        IWETH(wethAddress).withdraw(IERC20(wethAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7DEXMaxi.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-721 Token "X7 DEX Maxi" NFT

A utility NFT offering LP fee discounts while trading on the X7 DEX.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setMintFeeDestination(address mintFeeDestination_) external onlyOwner {
        require(mintFeeDestination != mintFeeDestination_);
        address oldMintFeeDestination = mintFeeDestination;
        mintFeeDestination = mintFeeDestination_;
        emit MintFeeDestinationSet(oldMintFeeDestination, mintFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        require(mintPrice_ > mintPrice);
        uint256 oldPrice = mintPrice;
        mintPrice = mintPrice_;
        emit MintPriceSet(oldPrice, mintPrice_);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{ value: amount }("");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{ value: value }(data);
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
}

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

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

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

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

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
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
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
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
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
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
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

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
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
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

interface IX7Migration {
    function inMigration(address) external view returns (bool);
}

contract X7DEXMaxi is ERC721Enumerable, ERC721Holder, Ownable {
    address payable public mintFeeDestination;
    address payable public treasury;
    string public _internalBaseURI;

    uint256 public maxSupply = 150;
    uint256 public mintPrice = 5 * 10 ** 17;
    uint256 public maxMintsPerTransaction = 3;

    bool public mintingOpen;
    bool public whitelistComplete;

    bool public whitelistActive = true;
    IX7Migration public whitelistAuthority;

    event MintingOpen();
    event MintFeeDestinationSet(address indexed oldDestination, address indexed newDestination);
    event MintPriceSet(uint256 oldPrice, uint256 newPrice);
    event BaseURISet(string oldURI, string newURI);
    event WhitelistActivitySet(bool whitelistActive);
    event WhitelistAuthoritySet(address indexed oldWhitelistAuthority, address indexed newWhitelistAuthority);

    constructor(
        address mintFeeDestination_,
        address treasury_
    ) ERC721("X7 DEX Maxi", "X7DMAXI") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        mintFeeDestination = payable(mintFeeDestination_);
        treasury = payable(treasury_);
    }

    function whitelist(address holder) external view returns (bool) {
        return whitelistAuthority.inMigration(holder);
    }

    function setMintFeeDestination(address mintFeeDestination_) external onlyOwner {
        require(mintFeeDestination != mintFeeDestination_);
        address oldMintFeeDestination = mintFeeDestination;
        mintFeeDestination = payable(mintFeeDestination_);
        emit MintFeeDestinationSet(oldMintFeeDestination, mintFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        require(mintPrice_ > mintPrice);
        uint256 oldPrice = mintPrice;
        mintPrice = mintPrice_;
        emit MintPriceSet(oldPrice, mintPrice_);
    }

    function setWhitelist(bool isActive) external onlyOwner {
        require(!whitelistComplete);
        require(whitelistActive != isActive);
        whitelistActive = isActive;
        emit WhitelistActivitySet(isActive);
    }

    function setWhitelistComplete() external onlyOwner {
        require(!whitelistComplete);
        whitelistComplete = true;
        whitelistActive = false;
    }

    function setWhitelistAuthority(address whitelistAuthority_) external onlyOwner {
        require(address(whitelistAuthority) != whitelistAuthority_);
        address oldWhitelistAuthority = address(whitelistAuthority);
        whitelistAuthority = IX7Migration(whitelistAuthority_);
        emit WhitelistAuthoritySet(oldWhitelistAuthority, whitelistAuthority_);
    }

    function openMinting() external onlyOwner {
        require(!mintingOpen);
        require(mintFeeDestination != address(0));
        mintingOpen = true;
        emit MintingOpen();
    }

    function mint() external payable {
        _mintMany(1);
    }

    function mintMany(uint256 numMints) external payable {
        _mintMany(numMints);
    }

    function _mintMany(uint256 numMints) internal {
        require(mintingOpen);
        require(!whitelistActive || whitelistAuthority.inMigration(msg.sender));
        require(totalSupply() + numMints <= maxSupply);
        require(numMints > 0 && numMints <= maxMintsPerTransaction);
        require(msg.value == numMints * mintPrice);

        uint256 treasuryFee = (msg.value * 10) / 100;

        bool success;

        (success, ) = treasury.call{ value: treasuryFee }("");
        require(success);

        (success, ) = mintFeeDestination.call{ value: msg.value - treasuryFee }("");
        require(success);

        uint256 nextTokenId = ERC721Enumerable.totalSupply();

        for (uint i = 0; i < numMints; i++) {
            super._mint(msg.sender, nextTokenId + i);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }
}


// File: contracts/X7EcosystemMaxi.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-721 Token "X7 Ecosystem Maxi" NFT

A utility NFT offering fee discounts across the X7 ecosystem.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setMintFeeDestination(address mintFeeDestination_) external onlyOwner {
        require(mintFeeDestination != mintFeeDestination_);
        address oldMintFeeDestination = mintFeeDestination;
        mintFeeDestination = mintFeeDestination_;
        emit MintFeeDestinationSet(oldMintFeeDestination, mintFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        require(mintPrice_ > mintPrice);
        uint256 oldPrice = mintPrice;
        mintPrice = mintPrice_;
        emit MintPriceSet(oldPrice, mintPrice_);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{ value: amount }("");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{ value: value }(data);
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
}

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

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

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

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

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
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
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
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
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
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
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

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
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
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

interface IX7Migration {
    function inMigration(address) external view returns (bool);
}

contract X7EcosystemMaxi is ERC721Enumerable, ERC721Holder, Ownable {
    address payable public mintFeeDestination;
    address payable public treasury;
    string public _internalBaseURI;

    uint256 public maxSupply = 500;
    uint256 public mintPrice = 10 ** 17;
    uint256 public maxMintsPerTransaction = 5;

    bool public mintingOpen;
    bool public whitelistComplete;

    bool public whitelistActive = true;
    IX7Migration public whitelistAuthority;

    event MintingOpen();
    event MintFeeDestinationSet(address indexed oldDestination, address indexed newDestination);
    event MintPriceSet(uint256 oldPrice, uint256 newPrice);
    event BaseURISet(string oldURI, string newURI);
    event WhitelistActivitySet(bool whitelistActive);
    event WhitelistAuthoritySet(address indexed oldWhitelistAuthority, address indexed newWhitelistAuthority);

    constructor(
        address mintFeeDestination_,
        address treasury_
    ) ERC721("X7 Ecosystem Maxi", "X7EMAXI") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        mintFeeDestination = payable(mintFeeDestination_);
        treasury = payable(treasury_);
    }

    function whitelist(address holder) external view returns (bool) {
        return whitelistAuthority.inMigration(holder);
    }

    function setMintFeeDestination(address mintFeeDestination_) external onlyOwner {
        require(mintFeeDestination != mintFeeDestination_);
        address oldMintFeeDestination = mintFeeDestination;
        mintFeeDestination = payable(mintFeeDestination_);
        emit MintFeeDestinationSet(oldMintFeeDestination, mintFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        require(mintPrice_ > mintPrice);
        uint256 oldPrice = mintPrice;
        mintPrice = mintPrice_;
        emit MintPriceSet(oldPrice, mintPrice_);
    }

    function setWhitelist(bool isActive) external onlyOwner {
        require(!whitelistComplete);
        require(whitelistActive != isActive);
        whitelistActive = isActive;
        emit WhitelistActivitySet(isActive);
    }

    function setWhitelistComplete() external onlyOwner {
        require(!whitelistComplete);
        whitelistComplete = true;
        whitelistActive = false;
    }

    function setWhitelistAuthority(address whitelistAuthority_) external onlyOwner {
        require(address(whitelistAuthority) != whitelistAuthority_);
        address oldWhitelistAuthority = address(whitelistAuthority);
        whitelistAuthority = IX7Migration(whitelistAuthority_);
        emit WhitelistAuthoritySet(oldWhitelistAuthority, whitelistAuthority_);
    }

    function openMinting() external onlyOwner {
        require(!mintingOpen);
        require(mintFeeDestination != address(0));
        mintingOpen = true;
        emit MintingOpen();
    }

    function mint() external payable {
        _mintMany(1);
    }

    function mintMany(uint256 numMints) external payable {
        _mintMany(numMints);
    }

    function _mintMany(uint256 numMints) internal {
        require(mintingOpen);
        require(!whitelistActive || whitelistAuthority.inMigration(msg.sender));
        require(totalSupply() + numMints <= maxSupply);
        require(numMints > 0 && numMints <= maxMintsPerTransaction);
        require(msg.value == numMints * mintPrice);

        uint256 treasuryFee = (msg.value * 10) / 100;

        bool success;

        (success, ) = treasury.call{ value: treasuryFee }("");
        require(success);

        (success, ) = mintFeeDestination.call{ value: msg.value - treasuryFee }("");
        require(success);

        uint256 nextTokenId = ERC721Enumerable.totalSupply();

        for (uint i = 0; i < numMints; i++) {
            super._mint(msg.sender, nextTokenId + i);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }
}


// File: contracts/X7EcosystemSplitter.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-28
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for balancing revenue across all revenue streams in the X7 system

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setWETH(address weth_) external onlyOwner {
        weth = weth_;
    }

    function setOutlet(Outlet outlet, address recipient) external onlyOwner {
        require(!isFrozen[outlet]);
        require(outletRecipient[outlet] != recipient);
        address oldRecipient = outletRecipient[outlet];
        outletLookup[recipient] = outlet;
        outletRecipient[outlet] = recipient;

        emit OutletRecipientSet(outlet, oldRecipient, recipient);
    }

    function freezeOutletChange(Outlet outlet) external onlyOwner {
        require(!isFrozen[outlet]);
        isFrozen[outlet] = true;

        emit OutletFrozen(outlet);
    }

    function setShares(uint256 x7rShare_, uint256 x7daoShare_, uint256 x7100Share_, uint256 lendingPoolShare_, uint256 treasuryShare_) external onlyOwner {
        require(treasuryShare_ >= treasuryMinShare);
        require(x7rShare_ + x7daoShare_ + x7100Share_ + lendingPoolShare_ + treasuryShare_ == 1000);
        require(x7rShare_ >= minShare && x7daoShare_ >= minShare && x7100Share_ >= minShare && lendingPoolShare_ >= minShare);
        require(x7rShare_ <= maxShare && x7daoShare_ <= maxShare && x7100Share_ <= maxShare && lendingPoolShare_ <= maxShare);

        outletShare[Outlet.X7R] = x7rShare_;
        outletShare[Outlet.X7DAO] = x7daoShare_;
        outletShare[Outlet.X7100] = x7100Share_;
        outletShare[Outlet.LENDING_POOL] = lendingPoolShare_;
        outletShare[Outlet.TREASURY] = treasuryShare_;

        emit SharesSet(x7rShare_, x7daoShare_, x7100Share_, lendingPoolShare_, treasuryShare_);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IX7EcosystemSplitter {
    function takeBalance() external;
}

contract X7EcosystemSplitter is Ownable, IX7EcosystemSplitter {
    enum Outlet {
        NONE,
        X7R,
        X7DAO,
        X7100,
        LENDING_POOL,
        TREASURY
    }

    mapping(Outlet => uint256) public outletBalance;
    mapping(Outlet => address) public outletRecipient;
    mapping(Outlet => uint256) public outletShare;
    mapping(address => Outlet) public outletLookup;
    mapping(Outlet => bool) public isFrozen;

    uint256 public minShare = 100;
    uint256 public maxShare = 500;

    uint256 public treasuryMinShare = 200;

    address public weth;

    event SharesSet(
        uint256 x7RShare,
        uint256 x7DAOShare,
        uint256 x7100Share,
        uint256 lendingPoolShare,
        uint256 treasuryShare
    );
    event OutletRecipientSet(Outlet outlet, address oldRecipient, address newRecipient);
    event OutletFrozen(Outlet outlet);

    constructor() Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        outletShare[Outlet.X7R] = 200;
        outletShare[Outlet.X7DAO] = 200;
        outletShare[Outlet.X7100] = 200;
        outletShare[Outlet.LENDING_POOL] = 200;
        outletShare[Outlet.TREASURY] = 200;

        emit SharesSet(200, 200, 200, 200, 200);
    }

    receive() external payable {
        outletBalance[Outlet.X7R] += (msg.value * outletShare[Outlet.X7R]) / 1000;
        outletBalance[Outlet.X7DAO] += (msg.value * outletShare[Outlet.X7DAO]) / 1000;
        outletBalance[Outlet.X7100] += (msg.value * outletShare[Outlet.X7100]) / 1000;
        outletBalance[Outlet.LENDING_POOL] += (msg.value * outletShare[Outlet.LENDING_POOL]) / 1000;
        outletBalance[Outlet.TREASURY] =
            address(this).balance -
            outletBalance[Outlet.X7R] -
            outletBalance[Outlet.X7DAO] -
            outletBalance[Outlet.X7100] -
            outletBalance[Outlet.LENDING_POOL];
    }

    function setWETH(address weth_) external onlyOwner {
        weth = weth_;
    }

    function setOutlet(Outlet outlet, address recipient) external onlyOwner {
        require(!isFrozen[outlet]);
        require(outletRecipient[outlet] != recipient);
        address oldRecipient = outletRecipient[outlet];
        outletLookup[recipient] = outlet;
        outletRecipient[outlet] = recipient;

        emit OutletRecipientSet(outlet, oldRecipient, recipient);
    }

    function freezeOutletChange(Outlet outlet) external onlyOwner {
        require(!isFrozen[outlet]);
        isFrozen[outlet] = true;

        emit OutletFrozen(outlet);
    }

    function setShares(
        uint256 x7rShare_,
        uint256 x7daoShare_,
        uint256 x7100Share_,
        uint256 lendingPoolShare_,
        uint256 treasuryShare_
    ) external onlyOwner {
        require(treasuryShare_ >= treasuryMinShare);
        require(x7rShare_ + x7daoShare_ + x7100Share_ + lendingPoolShare_ + treasuryShare_ == 1000);
        require(
            x7rShare_ >= minShare && x7daoShare_ >= minShare && x7100Share_ >= minShare && lendingPoolShare_ >= minShare
        );
        require(
            x7rShare_ <= maxShare && x7daoShare_ <= maxShare && x7100Share_ <= maxShare && lendingPoolShare_ <= maxShare
        );

        outletShare[Outlet.X7R] = x7rShare_;
        outletShare[Outlet.X7DAO] = x7daoShare_;
        outletShare[Outlet.X7100] = x7100Share_;
        outletShare[Outlet.LENDING_POOL] = lendingPoolShare_;
        outletShare[Outlet.TREASURY] = treasuryShare_;

        emit SharesSet(x7rShare_, x7daoShare_, x7100Share_, lendingPoolShare_, treasuryShare_);
    }

    function takeBalance() external {
        Outlet outlet = outletLookup[msg.sender];
        require(outlet != Outlet.NONE);
        _sendBalance(outlet);
    }

    function _sendBalance(Outlet outlet) internal {
        if (outletRecipient[outlet] == address(0)) {
            return;
        }

        uint256 ethToSend = outletBalance[outlet];

        if (ethToSend > 0) {
            outletBalance[outlet] = 0;

            (bool success, ) = outletRecipient[outlet].call{ value: ethToSend }("");
            if (!success) {
                outletBalance[outlet] += ethToSend;
            }
        }
    }

    function pushAll() external {
        _sendBalance(Outlet.X7R);
        _sendBalance(Outlet.X7DAO);
        _sendBalance(Outlet.X7100);
        _sendBalance(Outlet.LENDING_POOL);
        _sendBalance(Outlet.TREASURY);
    }

    function rescueWETH() external {
        IWETH(weth).withdraw(IERC20(weth).balanceOf(address(this)));
    }

    function rescueTokens(address tokenAddress) external {
        IERC20(tokenAddress).transfer(outletRecipient[Outlet.TREASURY], IERC20(tokenAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7LendingDiscountAuthorityV1.sol
/**
 *Submitted for verification at Etherscan.io on 2023-01-26
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for calculating lending discounts

There are four mechanisms to receive loan origination and premium discounts:

    1. Holding the Borrowing Maxi NFT
    2. Holding (and having consumed) the Borrowing Incentive NFT
    3. Borrowing a greater amount
    4. Borrowing for a shorter time

All discounts are additive.

The NFTs provide a fixed percentage discount. The Borrowing Incentive NFT is consumed upon loan origination.

The latter two discounts provide a linear sliding scale, based on the minimum and maximum loan amounts and loan periods.
The starting values for these discounts are 0-10% discount.

The time based discount is imposing an opportunity cost of lent funds - and incentivizing taking out the shortest loan possible.
The amount based discount is recognizing that a loan origination now is more valuable than a possible loan origination later.

These sliding scales can be modified to ensure they have optimal market fit.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setAuthorizedConsumer(address consumer, bool isAuthorized) external onlyOwner {
        require(authorizedConsumers[consumer] != isAuthorized);
        authorizedConsumers[consumer] = isAuthorized;
        emit AuthorizedConsumerSet(consumer, isAuthorized);
    }

    function setTimeBasedDiscount(uint256 min, uint256 max) external onlyOwner {
        require(min != timeBasedFeeDiscountMin || max != timeBasedFeeDiscountMax);
        uint256 oldMin = timeBasedFeeDiscountMin;
        uint256 oldMax = timeBasedFeeDiscountMax;
        timeBasedFeeDiscountMin = min;
        timeBasedFeeDiscountMax = max;
        emit TimeBasedDiscountSet(oldMin, oldMax, min, max);
    }

    function setAmountBasedDiscount(uint256 min, uint256 max) external onlyOwner {
        require(min != amountBasedFeeDiscountMin || max != amountBasedFeeDiscountMax);
        uint256 oldMin = amountBasedFeeDiscountMin;
        uint256 oldMax = amountBasedFeeDiscountMax;
        amountBasedFeeDiscountMin = min;
        amountBasedFeeDiscountMax = max;
        emit AmountBasedDiscountSet(oldMin, oldMax, min, max);
    }

    function setDiscountNFT(address discountNFTAddress) external onlyOwner {
        require(discountNFTAddress != address(discountNFT));
        address oldDiscountNFTAddress = address(discountNFT);
        discountNFT = IDiscountNFT(discountNFTAddress);
        emit DiscountNFTSet(oldDiscountNFTAddress, discountNFTAddress);
    }

    function setConsumableDiscountNFT(address consumableDiscountNFTAddress) external onlyOwner {
        require(consumableDiscountNFTAddress != address(consumableDiscountNFT));
        address oldConsumableDiscountNFTAddress = address(consumableDiscountNFT);
        consumableDiscountNFT = IConsumableDiscountNFT(consumableDiscountNFTAddress);
        emit ConsumableDiscountNFTSet(oldConsumableDiscountNFTAddress, consumableDiscountNFTAddress);
    }

    function setDiscountNFTDiscounts(uint256 premiumFeeDiscount, uint256 originationFeeDiscount) external onlyOwner {
        require(premiumFeeDiscount != discountNFTPremiumFeeDiscount || originationFeeDiscount != discountNFTOriginationFeeDiscount);
        require(premiumFeeDiscount <= 10000);
        require(originationFeeDiscount <= 10000);
        uint256 oldPremiumFeeDiscount = discountNFTPremiumFeeDiscount;
        uint256 oldOriginationFeeDiscount = discountNFTOriginationFeeDiscount;
        discountNFTPremiumFeeDiscount = premiumFeeDiscount;
        discountNFTOriginationFeeDiscount = originationFeeDiscount;

        emit DiscountNFTDiscountsSet(oldOriginationFeeDiscount, oldPremiumFeeDiscount, originationFeeDiscount, premiumFeeDiscount);
    }

    function setConsumableDiscountNFTDiscounts(uint256 premiumFeeDiscount, uint256 originationFeeDiscount) external onlyOwner {
        require(premiumFeeDiscount != consumableDiscountNFTPremiumFeeDiscount || originationFeeDiscount != consumableDiscountNFTOriginationFeeDiscount);
        require(premiumFeeDiscount <= 10000);
        require(originationFeeDiscount <= 10000);
        uint256 oldPremiumFeeDiscount = consumableDiscountNFTPremiumFeeDiscount;
        uint256 oldOriginationFeeDiscount = consumableDiscountNFTOriginationFeeDiscount;
        consumableDiscountNFTPremiumFeeDiscount = premiumFeeDiscount;
        consumableDiscountNFTOriginationFeeDiscount = originationFeeDiscount;

        emit ConsumableDiscountNFTDiscountsSet(oldOriginationFeeDiscount, oldPremiumFeeDiscount, originationFeeDiscount, premiumFeeDiscount);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IX7LendingDiscountAuthority {
    function getFeeModifiers(
        address borrower,
        uint256[3] memory loanAmountDetails,
        uint256[3] memory loanDurationDetails
    ) external view returns (uint256, uint256);

    function useFeeModifiers(
        address borrower,
        uint256[3] memory loanAmountDetails,
        uint256[3] memory loanDurationDetails
    ) external returns (uint256, uint256);
}

interface IDiscountNFT {
    function balanceOf(address) external view returns (uint256);
}

interface IConsumableDiscountNFT {
    function balanceOf(address) external view returns (uint256);
    function consumeOne(address) external;
    function consumeMany(address, uint256) external;
}

contract X7LendingDiscountAuthorityV1 is Ownable, IX7LendingDiscountAuthority {
    IDiscountNFT public discountNFT;
    IConsumableDiscountNFT public consumableDiscountNFT;

    // Only addresses in this mapping may call useFeeModifiers
    mapping(address => bool) public authorizedConsumers;

    // Discounts as a fraction of 10,000
    uint256 public discountNFTOriginationFeeDiscount;
    uint256 public discountNFTPremiumFeeDiscount;

    // Discounts as a fraction of 10,000
    uint256 public consumableDiscountNFTOriginationFeeDiscount;
    uint256 public consumableDiscountNFTPremiumFeeDiscount;

    // Time based discount scale as a fraction of 10,000
    uint256 public timeBasedFeeDiscountMin;
    uint256 public timeBasedFeeDiscountMax;

    // Amount based discount scale as a fraction of 10,000
    uint256 public amountBasedFeeDiscountMin;
    uint256 public amountBasedFeeDiscountMax;

    event AuthorizedConsumerSet(address indexed consumer, bool isAuthorized);
    event TimeBasedDiscountSet(uint256 oldMin, uint256 oldMax, uint256 min, uint256 max);
    event AmountBasedDiscountSet(uint256 oldMin, uint256 oldMax, uint256 min, uint256 max);
    event DiscountNFTSet(address indexed oldAddress, address indexed newAddress);
    event ConsumableDiscountNFTSet(address indexed oldAddress, address indexed newAddress);
    event DiscountNFTDiscountsSet(
        uint256 oldOriginationFeeDiscount,
        uint256 oldPremiumFeeDiscount,
        uint256 originationFeeDiscount,
        uint256 premiumFeeDiscount
    );
    event ConsumableDiscountNFTDiscountsSet(
        uint256 oldOriginationFeeDiscount,
        uint256 oldPremiumFeeDiscount,
        uint256 originationFeeDiscount,
        uint256 premiumFeeDiscount
    );

    constructor(
        address discountNFT_,
        address consumableDiscountNFT_
    ) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        discountNFT = IDiscountNFT(discountNFT_);
        consumableDiscountNFT = IConsumableDiscountNFT(consumableDiscountNFT_);
        emit DiscountNFTSet(address(0), discountNFT_);
        emit ConsumableDiscountNFTSet(address(0), consumableDiscountNFT_);
    }

    modifier onlyAuthorizedConsumers() {
        require(authorizedConsumers[msg.sender]);
        _;
    }

    function setAuthorizedConsumer(address consumer, bool isAuthorized) external onlyOwner {
        require(authorizedConsumers[consumer] != isAuthorized);
        authorizedConsumers[consumer] = isAuthorized;
        emit AuthorizedConsumerSet(consumer, isAuthorized);
    }

    function setTimeBasedDiscount(uint256 min, uint256 max) external onlyOwner {
        require(min != timeBasedFeeDiscountMin || max != timeBasedFeeDiscountMax);
        uint256 oldMin = timeBasedFeeDiscountMin;
        uint256 oldMax = timeBasedFeeDiscountMax;
        timeBasedFeeDiscountMin = min;
        timeBasedFeeDiscountMax = max;
        emit TimeBasedDiscountSet(oldMin, oldMax, min, max);
    }

    function setAmountBasedDiscount(uint256 min, uint256 max) external onlyOwner {
        require(min != amountBasedFeeDiscountMin || max != amountBasedFeeDiscountMax);
        uint256 oldMin = amountBasedFeeDiscountMin;
        uint256 oldMax = amountBasedFeeDiscountMax;
        amountBasedFeeDiscountMin = min;
        amountBasedFeeDiscountMax = max;
        emit AmountBasedDiscountSet(oldMin, oldMax, min, max);
    }

    function setDiscountNFT(address discountNFTAddress) external onlyOwner {
        require(discountNFTAddress != address(discountNFT));
        address oldDiscountNFTAddress = address(discountNFT);
        discountNFT = IDiscountNFT(discountNFTAddress);
        emit DiscountNFTSet(oldDiscountNFTAddress, discountNFTAddress);
    }

    function setConsumableDiscountNFT(address consumableDiscountNFTAddress) external onlyOwner {
        require(consumableDiscountNFTAddress != address(consumableDiscountNFT));
        address oldConsumableDiscountNFTAddress = address(consumableDiscountNFT);
        consumableDiscountNFT = IConsumableDiscountNFT(consumableDiscountNFTAddress);
        emit ConsumableDiscountNFTSet(oldConsumableDiscountNFTAddress, consumableDiscountNFTAddress);
    }

    function setDiscountNFTDiscounts(uint256 premiumFeeDiscount, uint256 originationFeeDiscount) external onlyOwner {
        require(
            premiumFeeDiscount != discountNFTPremiumFeeDiscount ||
                originationFeeDiscount != discountNFTOriginationFeeDiscount
        );
        require(premiumFeeDiscount <= 10000);
        require(originationFeeDiscount <= 10000);
        uint256 oldPremiumFeeDiscount = discountNFTPremiumFeeDiscount;
        uint256 oldOriginationFeeDiscount = discountNFTOriginationFeeDiscount;
        discountNFTPremiumFeeDiscount = premiumFeeDiscount;
        discountNFTOriginationFeeDiscount = originationFeeDiscount;

        emit DiscountNFTDiscountsSet(
            oldOriginationFeeDiscount,
            oldPremiumFeeDiscount,
            originationFeeDiscount,
            premiumFeeDiscount
        );
    }

    function setConsumableDiscountNFTDiscounts(
        uint256 premiumFeeDiscount,
        uint256 originationFeeDiscount
    ) external onlyOwner {
        require(
            premiumFeeDiscount != consumableDiscountNFTPremiumFeeDiscount ||
                originationFeeDiscount != consumableDiscountNFTOriginationFeeDiscount
        );
        require(premiumFeeDiscount <= 10000);
        require(originationFeeDiscount <= 10000);
        uint256 oldPremiumFeeDiscount = consumableDiscountNFTPremiumFeeDiscount;
        uint256 oldOriginationFeeDiscount = consumableDiscountNFTOriginationFeeDiscount;
        consumableDiscountNFTPremiumFeeDiscount = premiumFeeDiscount;
        consumableDiscountNFTOriginationFeeDiscount = originationFeeDiscount;

        emit ConsumableDiscountNFTDiscountsSet(
            oldOriginationFeeDiscount,
            oldPremiumFeeDiscount,
            originationFeeDiscount,
            premiumFeeDiscount
        );
    }

    function getFeeModifiers(
        address borrower,
        uint256[3] memory loanAmountDetails,
        uint256[3] memory loanDurationDetails
    ) external view returns (uint256, uint256) {
        (uint256 premiumFeeModifier, uint256 originationFeeModifier, ) = _getFeeModifiers(
            borrower,
            loanAmountDetails,
            loanDurationDetails
        );

        return (premiumFeeModifier, originationFeeModifier);
    }

    function useFeeModifiers(
        address borrower,
        uint256[3] memory loanAmountDetails,
        uint256[3] memory loanDurationDetails
    ) external onlyAuthorizedConsumers returns (uint256, uint256) {
        (uint256 premiumFeeModifier, uint256 originationFeeModifier, bool usedConsumable) = _getFeeModifiers(
            borrower,
            loanAmountDetails,
            loanDurationDetails
        );

        if (usedConsumable) {
            consumableDiscountNFT.consumeOne(borrower);
        }

        return (premiumFeeModifier, originationFeeModifier);
    }

    function _getFeeModifiers(
        address borrower,
        uint256[3] memory loanAmountDetails,
        uint256[3] memory loanDurationDetails
    ) internal view returns (uint256 premiumFeeModifier, uint256 originationFeeModifier, bool usedConsumable) {
        uint256 premiumDiscount;
        uint256 originationDiscount;

        if (discountNFT.balanceOf(borrower) > 0) {
            premiumDiscount = discountNFTPremiumFeeDiscount;
            originationDiscount = discountNFTOriginationFeeDiscount;
        }

        if (consumableDiscountNFT.balanceOf(borrower) > 0) {
            premiumDiscount += consumableDiscountNFTPremiumFeeDiscount;
            originationDiscount += consumableDiscountNFTOriginationFeeDiscount;
            usedConsumable = true;
        } else {
            usedConsumable = false;
        }

        uint256 amountBasedDiscount = amountBasedFeeDiscountMin +
            (((amountBasedFeeDiscountMax - amountBasedFeeDiscountMin) * (loanAmountDetails[1] - loanAmountDetails[0])) /
                (loanAmountDetails[2] - loanAmountDetails[0]));

        uint256 timeBasedDiscount = timeBasedFeeDiscountMax -
            (((timeBasedFeeDiscountMax - timeBasedFeeDiscountMin) * (loanDurationDetails[1] - loanDurationDetails[0])) /
                (loanDurationDetails[2] - loanDurationDetails[0]));

        premiumDiscount += (amountBasedDiscount + timeBasedDiscount);
        originationDiscount += (amountBasedDiscount + timeBasedDiscount);

        if (premiumDiscount > 10000) {
            premiumFeeModifier = 0;
        } else {
            premiumFeeModifier = 10000 - premiumDiscount;
        }

        if (originationDiscount > 10000) {
            originationFeeModifier = 0;
        } else {
            originationFeeModifier = 10000 - originationDiscount;
        }
    }
}


// File: contracts/X7LendingPoolReserve.sol
/**
 *Submitted for verification at Etherscan.io on 2023-01-16
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for minting and redeeming X7D and funding the Lending Pool with ETH.

This contract may be used to mint X7D and redeem X7D.

For ease of integration, contracts may choose to simply send ETH to this contract and they will receive X7D.
X7 ecosystem contracts that deposit funds in this manner have X7D minted to the X7 Token Time Lock.

However, it is recommended to use depositETH or depositETHForRecipient to guarantee that the X7D is only ever minted to the desired location.

A word of CAUTION for minters:

The full X7D ecosystem will evolve over time. While all ETH funds deposited to this contract will remain locked in X7 ecosystem smart contracts not all ETH will remain in THIS contract.
There is no risk for minting X7D on this contract - however, withdrawals will be on a first come/first serve basis. Some funds may be servicing loans.
the X7100 series tokens will eventually act as a liquidity sink and will backstop X7D redemptions if there is a temporary funding gap (due to outstanding loans).
You should NOT mint X7D from this contract unless you are willing to wait an indeterminate amount of time to withdraw your ETH on the first come/first serve basis.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setLendingPool(address lendingPool_) external onlyOwner {
        require(lendingPool != lendingPool_);
        address oldLendingPool = lendingPool;
        lendingPool = lendingPool_;

        emit LendingPoolSet(oldLendingPool, lendingPool_);
    }

    function setEcosystemRecipientAddress(address recipient) external onlyOwner {
        require(ecosystemRecipient != recipient);
        address oldRecipient = ecosystemRecipient;
        ecosystemRecipient = recipient;

        emit EcosystemRecipientSet(oldRecipient, recipient);
    }

    function setX7D(address X7DAddress) external onlyOwner {
        require(address(X7D) != X7DAddress);
        address oldX7D = address(X7D);
        X7D = IX7D(X7DAddress);

        emit X7DSet(oldX7D, X7DAddress);
    }

    function setEcosystemPayer(address ecosystemPayerAddress, bool value) external onlyOwner {
        require(isEcosystemPayer[ecosystemPayerAddress] != value);
        isEcosystemPayer[ecosystemPayerAddress] = value;

        emit EcosystemPayerSet(ecosystemPayerAddress, value);
    }

    function fundLendingPool(uint256 amount) external onlyOwner {
        require(lendingPool != address(0));
        require(amount <= address(this).balance);

        (bool success,) = lendingPool.call{value: amount}("");
        require(success);

        emit FundsSent(lendingPool, amount);
    }

    function setRecoveredTokenRecipient(address tokenRecipient_) external onlyOwner {
        require(recoveredTokenRecipient != tokenRecipient_);
        address oldRecipient = recoveredTokenRecipient;
        recoveredTokenRecipient = tokenRecipient_;

        emit RecoveredTokenRecipientSet(oldRecipient, tokenRecipient_);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

interface IX7D {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface X7DMinter {
    // Call this function to explicitly mint X7D
    function depositETH() external payable;

    // Call this function to return ETH to this contract without minting X7D
    function returnETH() external payable;

    // Call this function to mint X7D to a recipient of your choosing
    function depositETHForRecipient(address recipient) external payable;
}

interface X7DBurner {
    // Call this function to redeem (burn) X7D for ETH
    function withdrawETH(uint256 amount) external;
}

abstract contract TokensCanBeRecovered is Ownable {
    bytes4 private constant TRANSFERSELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    address public recoveredTokenRecipient;

    event RecoveredTokenRecipientSet(address oldRecipient, address newRecipient);

    function setRecoveredTokenRecipient(address tokenRecipient_) external onlyOwner {
        require(recoveredTokenRecipient != tokenRecipient_);
        address oldRecipient = recoveredTokenRecipient;
        recoveredTokenRecipient = tokenRecipient_;
        emit RecoveredTokenRecipientSet(oldRecipient, tokenRecipient_);
    }

    function recoverTokens(address tokenAddress) external {
        require(recoveredTokenRecipient != address(0));
        _safeTransfer(tokenAddress, recoveredTokenRecipient, IERC20(tokenAddress).balanceOf(address(this)));
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(TRANSFERSELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }
}

contract X7LendingPoolReserve is Ownable, TokensCanBeRecovered, X7DMinter, X7DBurner {
    IX7D public X7D;
    address public lendingPool;
    address public ecosystemRecipient;
    mapping(address => bool) public isEcosystemPayer;

    event X7DSet(address oldAddress, address newAddress);
    event EcosystemRecipientSet(address oldAddress, address newAddress);
    event EcosystemPayerSet(address payorAddress, bool isPayer);
    event LendingPoolSet(address oldAddress, address newAddress);
    event FundsSent(address indexed recipient, uint256 amount);
    event FundsReturned(address indexed sender, uint256 amount);

    constructor(
        address X7DAddress,
        address ecosystemRecipientAddress
    ) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        X7D = IX7D(X7DAddress);
        ecosystemRecipient = ecosystemRecipientAddress;

        emit X7DSet(address(0), X7DAddress);
        emit EcosystemRecipientSet(address(0), ecosystemRecipientAddress);
    }

    receive() external payable {
        address recipient = msg.sender;

        if (isEcosystemPayer[msg.sender]) {
            recipient = ecosystemRecipient;
        }

        X7D.mint(recipient, msg.value);
    }

    function depositETH() external payable {
        X7D.mint(msg.sender, msg.value);
    }

    function depositETHForRecipient(address recipient) external payable {
        X7D.mint(recipient, msg.value);
    }

    function withdrawETH(uint256 amount) external {
        require(amount <= address(this).balance, "Insufficient funds to redeem that amount of X7D");
        X7D.burn(msg.sender, amount);
        (bool success, ) = msg.sender.call{ value: amount }("");
        require(success);
    }

    function returnETH() external payable {
        emit FundsReturned(msg.sender, msg.value);
    }

    function setLendingPool(address lendingPool_) external onlyOwner {
        require(lendingPool != lendingPool_);
        address oldLendingPool = lendingPool;
        lendingPool = lendingPool_;

        emit LendingPoolSet(oldLendingPool, lendingPool_);
    }

    function setEcosystemRecipientAddress(address recipient) external onlyOwner {
        require(ecosystemRecipient != recipient);
        address oldRecipient = ecosystemRecipient;
        ecosystemRecipient = recipient;

        emit EcosystemRecipientSet(oldRecipient, recipient);
    }

    function setX7D(address X7DAddress) external onlyOwner {
        require(address(X7D) != X7DAddress);
        address oldX7D = address(X7D);
        X7D = IX7D(X7DAddress);

        emit X7DSet(oldX7D, X7DAddress);
    }

    function setEcosystemPayer(address ecosystemPayerAddress, bool value) external onlyOwner {
        require(isEcosystemPayer[ecosystemPayerAddress] != value);
        isEcosystemPayer[ecosystemPayerAddress] = value;

        emit EcosystemPayerSet(ecosystemPayerAddress, value);
    }

    function fundLendingPool(uint256 amount) external onlyOwner {
        require(lendingPool != address(0));
        require(amount <= address(this).balance);

        (bool success, ) = lendingPool.call{ value: amount }("");
        require(success);

        emit FundsSent(lendingPool, amount);
    }
}


// File: contracts/X7LendingPoolV2.sol
/**
 *Submitted for verification at Etherscan.io on 2024-03-20
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for originating initial liquidity loans and managing payments and distributions
Version: V2

Fixes:

    1. A bug in returnETHToLendingPoolReserve has been fixed to ensure the correct ETH can be returned to the lending pool reserve
    2. nextLoanID has been set to start at 21 (1-20 are managed via the V1 contract 0x740015c39da5D148fcA25A467399D00bcE10c001)

The critical usage functions on this contract are:

    // Used to get a quote for a loan according to a specific borrower, loan term, amount, and duration
    function getDiscountedQuote(
        address borrower,
        IX7InitialLiquidityLoanTerm loanTerm,
        uint256 loanAmount,
        uint256 loanDurationSeconds
    ) external view returns (uint256[7] memory);

    // Used to originate the actual loan
    function getInitialLiquidityLoan(
        address tokenAddress,
        uint256 amount,
        address loanTermContract,
        uint256 loanAmount,
        uint256 loanDurationSeconds,
        address liquidityReceiver,
        uint256 deadline
    ) external lock payable returns (uint256 loanID);

    // Used to pay against any outstanding loan liability. See the loan term contract to understand how payment is applied.
    function payLiability(uint256 loanID) external lock payable;

    // Used to see the amount of the loan that can be liquidated. If the amount is greater than 0 the loan is eligible for a liquidation event.
    // For the initial loan terms any past due payments makes the entire loan eligible for liquidation
    function canLiquidate(uint256 loanID) external view returns (uint256)

    // Used to liquidate the loan. If the loan term allows, this will only be a partial liquidation.
    // The initial loan terms all liquidate in full.
    function liquidate(uint256 loanID) external lock;

    // Used to check the cost to buyout the loan (this is the remaining principal due)
    function buyoutLoanQuote(uint256 loanID) external view returns (uint256);

    // Used to buy out the loan. Doing so will cause the loan term NFT to be transferred to the caller
    function buyoutLoan(uint256 loanID) external payable;

    // Used to buy out the loan to a specific address. This will cause the loan term NFT to be transferred to the specified address
    function buyoutLoanTo(uint256 loanID, address to) external payable;

    Please see provided technical documentation for a full description of all the functionality of this contract.

There is an operational function that allows for ETH held by this contract to be returned to the lending pool reserve. A caller must be a capital manager to call this. This contract is an X7D minter but not an X7D redeemer. As such capital may need to be transferred back to the reserve pool on an as needed basis to ensure depositors are always capable of withdrawing their X7D deposits.

    function returnETHToLendingPoolReserve(uint256 amount) external {
        require(authorizedCapitalManagers[msg.sender]);
        require(amount <= address(this).balance);
        require(lendingPoolReserve != address(0));
        X7DMinter(lendingPoolReserve).returnETH{value: amount}();
    }

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setEcosystemRecipientAddress(address recipient) external onlyOwner {
        require(ecosystemRecipient != recipient);
        address oldRecipient = ecosystemRecipient;
        ecosystemRecipient = recipient;
        emit EcosystemRecipientSet(oldRecipient, recipient);
    }

    function setRouter(address routerAddress) external onlyOwner {
        require(address(router) != routerAddress);
        address oldRouter = address(router);
        router = IXchangeRouter(routerAddress);
        emit RouterSet(oldRouter, routerAddress);
    }

    function setWETH(address wethAddress) external onlyOwner {
        require(weth != wethAddress);
        address oldWethAddress = weth;
        weth = wethAddress;
        emit WETHSet(oldWethAddress, wethAddress);
    }

    function setX7D(address X7DAddress) external onlyOwner {
        require(address(X7D) != X7DAddress);
        address oldAddress = address(X7D);
        X7D = IX7D(X7DAddress);
        emit X7DSet(oldAddress, X7DAddress);
    }

    function setLoanTermActiveState(address loanTermAddress, bool isActive) external onlyOwner {
        require(loanTermActive[loanTermAddress] != isActive);
        loanTermActive[loanTermAddress] = isActive;

        if (isActive) {
            activeLoanTerms.push(loanTermAddress);
            loanTermIndex[loanTermAddress] = activeLoanTerms.length - 1;
        } else {
            address otherLoanTermAddress = activeLoanTerms[activeLoanTerms.length-1];
            activeLoanTerms[loanTermIndex[loanTermAddress]] = otherLoanTermAddress;
            loanTermIndex[otherLoanTermAddress] = loanTermIndex[loanTermAddress];
            delete loanTermIndex[loanTermAddress];
            activeLoanTerms.pop();
        }

        emit LoanTermActiveStateSet(loanTermAddress, isActive);
    }

    function setLiquidationReward(uint256 reward) external onlyOwner {
        require(liquidationReward != reward);
        uint256 oldReward = liquidationReward;
        liquidationReward = reward;
        emit LiquidationRewardSet(oldReward, reward);
    }

    function setOriginationShares(
        uint256 ecosystemSplitterOriginationShare_,
        uint256 X7DAOOriginationShare_,
        uint256 X7100OriginationShare_,
        uint256 lendingPoolOriginationShare_
    ) external onlyOwner {
        require(ecosystemSplitterOriginationShare_ + X7DAOOriginationShare_ + X7100OriginationShare_ + lendingPoolOriginationShare_ == 10000);

        uint256 oldEcosystemSplitterOriginationShare = ecosystemSplitterOriginationShare;
        uint256 oldX7DAOOriginationShare = X7DAOOriginationShare;
        uint256 oldX7100OriginationShare = X7100OriginationShare;
        uint256 oldLendingPoolOriginationShare = lendingPoolOriginationShare;

        ecosystemSplitterOriginationShare = ecosystemSplitterOriginationShare_;
        X7DAOOriginationShare = X7DAOOriginationShare_;
        X7100OriginationShare = X7100OriginationShare_;
        lendingPoolOriginationShare = lendingPoolOriginationShare_;

        emit OriginationSharesSet(
            oldEcosystemSplitterOriginationShare,
            oldX7DAOOriginationShare,
            oldX7100OriginationShare,
            oldLendingPoolOriginationShare,
            ecosystemSplitterOriginationShare_,
            X7DAOOriginationShare_,
            X7100OriginationShare_,
            lendingPoolOriginationShare_
        );
    }

    function setPremiumShares(
        uint256 ecosystemSplitterPremiumShare_,
        uint256 X7DAOPremiumShare_,
        uint256 X7100PremiumShare_,
        uint256 lendingPoolPremiumShare_
    ) external onlyOwner {
        require(ecosystemSplitterPremiumShare_ + X7DAOPremiumShare_ + X7100PremiumShare_ + lendingPoolPremiumShare_ == 10000);

        uint256 oldEcosystemSplitterPremiumShare = ecosystemSplitterPremiumShare;
        uint256 oldX7DAOPremiumShare = X7DAOPremiumShare;
        uint256 oldX7100PremiumShare = X7100PremiumShare;
        uint256 oldLendingPoolPremiumShare = lendingPoolPremiumShare;

        ecosystemSplitterPremiumShare = ecosystemSplitterPremiumShare_;
        X7DAOPremiumShare = X7DAOPremiumShare_;
        X7100PremiumShare = X7100PremiumShare_;
        lendingPoolPremiumShare = lendingPoolPremiumShare_;

        emit PremiumSharesSet(
            oldEcosystemSplitterPremiumShare,
            oldX7DAOPremiumShare,
            oldX7100PremiumShare,
            oldLendingPoolPremiumShare,
            ecosystemSplitterPremiumShare_,
            X7DAOPremiumShare_,
            X7100PremiumShare_,
            lendingPoolPremiumShare_
        );
    }

    function setEcosystemSplitter(address recipient) external onlyOwner {
        require(ecosystemSplitter != recipient);
        address oldEcosystemSplitterAddress = ecosystemSplitter;
        ecosystemSplitter = recipient;
        emit EcosystemSplitterSet(oldEcosystemSplitterAddress, recipient);
    }

    function setX7100ReserveRecipient(address recipient) external onlyOwner {
        require(X7100ReserveRecipient != recipient);
        address oldX7100ReserveRecipient = X7100ReserveRecipient;
        X7100ReserveRecipient = recipient;
        emit X7100ReserveRecipientSet(oldX7100ReserveRecipient, recipient);
    }

    function setX7DAORewardRecipient(address recipient) external onlyOwner {
        require(X7DAORewardRecipient != recipient);
        address oldX7DAORewardRecipient = X7DAORewardRecipient;
        X7DAORewardRecipient = recipient;
        emit X7DAORewardRecipientSet(oldX7DAORewardRecipient, recipient);
    }

    function setDiscountAuthority(address discountAuthorityAddress) external onlyOwner {
        require(address(discountAuthority) != discountAuthorityAddress);

        address oldDiscountAuthority = address(discountAuthority);

        discountAuthority = IX7LendingDiscountAuthority(discountAuthorityAddress);

        emit DiscountAuthoritySet(oldDiscountAuthority, discountAuthorityAddress);
    }

    function setRetainedFeeNumerator(uint256 numerator) external onlyOwner {
        require(retainedFeeNumerator != numerator);
        uint256 oldRetainedFeeNumerator = retainedFeeDenominator;
        retainedFeeNumerator = numerator;

        emit RetainedFeeNumeratorSet(oldRetainedFeeNumerator, numerator);
    }

    function setLendingPoolReserve(address reserveAddress) external onlyOwner {
        require(lendingPoolReserve != reserveAddress);

        address oldLendingPoolReserve = lendingPoolReserve;
        lendingPoolReserve = reserveAddress;

        emit LendingPoolReserveSet(oldLendingPoolReserve, reserveAddress);

    }

    function setLendingHalted(bool isHalted) external onlyOwner {
        require(lendingHalted != isHalted);
        lendingHalted = isHalted;

        if (isHalted) {
            emit LendingHalted();
        } else {
            emit LendingCommenced();
        }
    }

    function setAllowLoanBuyout(bool isAllowed) external onlyOwner {
        require(allowLoanBuyout != isAllowed);
        allowLoanBuyout = isAllowed;

        emit LoanBuyoutAllowed(isAllowed);
    }

    function setAuthorizedCapitalManager(address manager, bool isTrusted) external onlyOwner {
        require(authorizedCapitalManagers[manager] != isTrusted);
        authorizedCapitalManagers[manager] = isTrusted;

        emit AuthorizedCapitalManagerSet(manager, isTrusted);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IX7D {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface IX7LendingTerm {
    function createLoan() external returns (uint256);
    function fundLoan(uint256 loanID) external;
}

// 1. Loan origination fee
// 2. Loan retention premium fee schedule
// 3. Principal repayment condition/maximum loan duration
// 4. Liquidation conditions and Reward
// 5. Loan duration

interface IX7LendingDiscountAuthority {
    function getFeeModifiers(
        address borrower,
        uint256[3] memory loanAmountDetails,
        uint256[3] memory loanDurationDetails
    ) external view returns (uint256, uint256);

    function useFeeModifiers(
        address borrower,
        uint256[3] memory loanAmountDetails,
        uint256[3] memory loanDurationDetails
    ) external returns (uint256, uint256);
}

interface IX7InitialLiquidityLoanTerm {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;

    function originateLoan(
        uint256 loanAmount,
        uint256 originationFee,
        uint256 loanLengthSeconds_,
        uint256 premiumFeeModifierNumerator_,
        uint256 originationFeeModifierNumerator_,
        address receiver,
        uint256 tokenId
    ) external payable;

    function minimumLoanAmount() external view returns (uint256);
    function maximumLoanAmount() external view returns (uint256);
    function minimumLoanLengthSeconds() external view returns (uint256);
    function maximumLoanLengthSeconds() external view returns (uint256);

    function getPrincipalDue(uint256 loanID, uint256 asOf) external view returns (uint256);
    function getPremiumsDue(uint256 loanID, uint256 asOf) external view returns (uint256);
    function getTotalDue(uint256 loanID, uint256 asOf) external view returns (uint256);
    function getRemainingLiability(uint256 loanID) external view returns (uint256);
    function getPremiumPaymentSchedule(uint256 loanID) external view returns (uint256[] memory, uint256[] memory);
    function getPrincipalPaymentSchedule(uint256 loanID) external view returns (uint256[] memory, uint256[] memory);

    function isComplete(uint256 loanID) external view returns (bool);
    function getOriginationAmounts(
        uint256 loanAmount
    ) external view returns (uint256 loanAmountRounded, uint256 originationFee);
    function getQuote(
        uint256 loanAmount
    ) external view returns (uint256 loanAmountRounded, uint256 originationFee, uint256 totalPremium);
    function getDiscountedQuote(
        uint256 loanAmount_,
        uint256 premiumFeeModifier,
        uint256 originationFeeModifier
    ) external view returns (uint256 loanAmountRounded, uint256 originationFee, uint256 totalPremium);
    function recordPrincipalRepayment(
        uint256 loanID,
        uint256 amount
    ) external returns (uint256 premiumPaid, uint256 principalPaid, uint256 refundAmount, uint256 remainingLiability);
    function recordPayment(
        uint256 loanID,
        uint256 amount
    ) external returns (uint256 premiumPaid, uint256 principalPaid, uint256 refundAmount, uint256 remainingLiability);
    function liquidationAmount(uint256 loanID) external view returns (uint256);

    function loanAmount(uint256 loanID) external view returns (uint256);
    function principalAmountPaid(uint256 loanID) external view returns (uint256);
}

interface IXchangeFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IXchangeRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IXchangePair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function syncSafe(uint256, uint256) external;
    function withdrawTokensAgainstMinimumBalance(
        address tokenAddress,
        address to,
        uint112 amount
    ) external returns (uint256);
    function setMinimumBalance(address tokenAddress, uint112 minimumAmount) external;
    function tokenMinimumBalance(address) external view returns (uint256);
}

interface X7DMinter {
    event FundsReturned(address indexed sender, uint256 amount);

    // Call this function to explicitly mint X7D
    function depositETH() external payable;

    // Call this function to return ETH to this contract without minting X7D
    function returnETH() external payable;

    // Call this function to mint X7D to a recipient of your choosing
    function depositETHForRecipient(address recipient) external payable;
}

contract X7LendingPoolV2 is X7DMinter, Ownable {
    mapping(address => bool) public loanTermActive;
    address[] public activeLoanTerms;
    mapping(address => uint256) loanTermIndex;

    mapping(uint256 => address) public loanTermLookup;
    mapping(uint256 => address) public loanPair;
    mapping(uint256 => address) public loanToken;
    mapping(uint256 => uint256) public loanLiquidationReward;
    mapping(uint256 => address) public loanLiquidationReturnTo;

    mapping(address => uint256[]) public loanLookupByBorrower;
    mapping(uint256 => address) public loanBorrower;
    mapping(uint256 => uint256) loanBorrowerIndex;

    // LoanIDs 1-20 are on 0x740015c39da5D148fcA25A467399D00bcE10c001
    uint256 public nextLoanID = 21;
    bool lendingHalted = true;
    bool allowLoanBuyout = false;

    IX7LendingDiscountAuthority public discountAuthority;
    mapping(address => bool) public authorizedCapitalManagers;

    address public lendingPoolReserve;

    address public ecosystemSplitter;
    address public X7100ReserveRecipient;
    address public X7DAORewardRecipient;
    IX7D public X7D;

    uint256 public ecosystemSplitterPremiumShare;
    uint256 public X7DAOPremiumShare;
    uint256 public X7100PremiumShare;
    uint256 public lendingPoolPremiumShare;

    uint256 public ecosystemSplitterOriginationShare;
    uint256 public X7DAOOriginationShare;
    uint256 public X7100OriginationShare;
    uint256 public lendingPoolOriginationShare;

    IXchangeRouter public router;
    address public weth;
    address public ecosystemRecipient;

    uint256 public liquidationEscrow;
    uint256 public liquidationReward;

    uint256 public retainedFeeNumerator;
    uint256 public retainedFeeDenominator = 100;

    uint256 public syncSafeGasAmount = 100000;

    event EcosystemRecipientSet(address oldAddress, address newAddress);
    event RouterSet(address oldAddress, address newAddress);
    event WETHSet(address oldAddress, address newAddress);
    event X7DSet(address oldAddress, address newAddress);
    event LoanTermActiveStateSet(address indexed newAddress, bool isActive);
    event LiquidationRewardSet(uint256 oldReward, uint256 newReward);
    event OriginationSharesSet(
        uint256 oldEcosystemSplitterOriginationShare,
        uint256 oldX7DAOOriginationShare,
        uint256 oldX7100OriginationShare,
        uint256 oldLendingPoolOriginationShare,
        uint256 newEcosystemSplitterOriginationShare,
        uint256 newX7DAOOriginationShare,
        uint256 newX7100OriginationShare,
        uint256 newLendingPoolOriginationShare
    );
    event PremiumSharesSet(
        uint256 oldEcosystemSplitterOriginationShare,
        uint256 oldX7DAOOriginationShare,
        uint256 oldX7100OriginationShare,
        uint256 oldLendingPoolOriginationShare,
        uint256 newEcosystemSplitterOriginationShare,
        uint256 newX7DAOOriginationShare,
        uint256 newX7100OriginationShare,
        uint256 newLendingPoolOriginationShare
    );
    event EcosystemSplitterSet(address oldAddress, address newAddress);
    event X7100ReserveRecipientSet(address oldAddress, address newAddress);
    event X7DAORewardRecipientSet(address oldAddress, address newAddress);
    event DiscountAuthoritySet(address oldAddress, address newAddress);
    event RetainedFeeNumeratorSet(uint256 oldValue, uint256 newValue);
    event LendingPoolReserveSet(address oldAddress, address newAddress);
    event LendingHalted();
    event LendingCommenced();
    event AuthorizedCapitalManagerSet(address managerAddress, bool isTrusted);
    event LoanBuyoutAllowed(bool isAllowed);
    event SyncSafeGasAmountSet(uint256 oldValue, uint256 newValue);
    event LoanBoughtOut(address indexed buyer, uint256 indexed loanID);

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "LendingPool: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address routerAddress) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        router = IXchangeRouter(routerAddress);
    }

    receive() external payable {}

    function activeLoansByBorrower(address borrower) external view returns (uint256) {
        return loanLookupByBorrower[borrower].length;
    }

    function countOfActiveLoanTerms() external view returns (uint256) {
        return activeLoanTerms.length;
    }

    function availableCapital() external view returns (uint256) {
        return address(this).balance - liquidationEscrow;
    }

    function getDiscountedQuote(
        address borrower,
        IX7InitialLiquidityLoanTerm loanTerm,
        uint256 loanAmount,
        uint256 loanDurationSeconds
    ) external view returns (uint256[7] memory) {
        require(loanTerm.minimumLoanAmount() <= loanAmount);
        require(loanTerm.maximumLoanAmount() >= loanAmount);
        require(loanTerm.minimumLoanLengthSeconds() <= loanDurationSeconds);
        require(loanTerm.maximumLoanLengthSeconds() >= loanDurationSeconds);
        return _getDiscountedQuote(borrower, loanTerm, loanAmount, loanDurationSeconds);
    }

    function canLiquidate(uint256 loanID) external view returns (uint256) {
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        return loanTerm.liquidationAmount(loanID);
    }

    function getPrincipalDue(uint256 loanID, uint256 asOf) external view returns (uint256) {
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        return loanTerm.getPrincipalDue(loanID, asOf);
    }

    function getPremiumsDue(uint256 loanID, uint256 asOf) external view returns (uint256) {
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        return loanTerm.getPremiumsDue(loanID, asOf);
    }

    function getTotalDue(uint256 loanID, uint256 asOf) external view returns (uint256) {
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        return loanTerm.getTotalDue(loanID, asOf);
    }

    function getRemainingLiability(uint256 loanID) external view returns (uint256) {
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        return loanTerm.getRemainingLiability(loanID);
    }

    function getPremiumPaymentSchedule(uint256 loanID) external view returns (uint256[] memory, uint256[] memory) {
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        (uint256[] memory dueDates, uint256[] memory paymentAmounts) = loanTerm.getPremiumPaymentSchedule(loanID);
        return (dueDates, paymentAmounts);
    }

    function getPrincipalPaymentSchedule(uint256 loanID) external view returns (uint256[] memory, uint256[] memory) {
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        (uint256[] memory dueDates, uint256[] memory paymentAmounts) = loanTerm.getPrincipalPaymentSchedule(loanID);
        return (dueDates, paymentAmounts);
    }

    function getQuote(
        address borrower,
        IX7InitialLiquidityLoanTerm loanTerm,
        uint256 loanAmount,
        uint256 loanDurationSeconds
    ) external view returns (uint256[5] memory) {
        require(loanTerm.minimumLoanAmount() <= loanAmount);
        require(loanTerm.maximumLoanAmount() >= loanAmount);
        require(loanTerm.minimumLoanLengthSeconds() <= loanDurationSeconds);
        require(loanTerm.maximumLoanLengthSeconds() >= loanDurationSeconds);
        return _getQuote(borrower, loanTerm, loanAmount, loanDurationSeconds);
    }

    function buyoutLoanQuote(uint256 loanID) external view returns (uint256) {
        require(allowLoanBuyout);
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        address owner_ = loanTerm.ownerOf(loanID);
        require(owner_ == address(this));

        uint256 buyoutAmount = loanTerm.loanAmount(loanID) - loanTerm.principalAmountPaid(loanID);
        return buyoutAmount;
    }

    function setEcosystemRecipientAddress(address recipient) external onlyOwner {
        require(ecosystemRecipient != recipient);
        address oldRecipient = ecosystemRecipient;
        ecosystemRecipient = recipient;
        emit EcosystemRecipientSet(oldRecipient, recipient);
    }

    function setRouter(address routerAddress) external onlyOwner {
        require(address(router) != routerAddress);
        address oldRouter = address(router);
        router = IXchangeRouter(routerAddress);
        emit RouterSet(oldRouter, routerAddress);
    }

    function setWETH(address wethAddress) external onlyOwner {
        require(weth != wethAddress);
        address oldWethAddress = weth;
        weth = wethAddress;
        emit WETHSet(oldWethAddress, wethAddress);
    }

    function setX7D(address X7DAddress) external onlyOwner {
        require(address(X7D) != X7DAddress);
        address oldAddress = address(X7D);
        X7D = IX7D(X7DAddress);
        emit X7DSet(oldAddress, X7DAddress);
    }

    function setLoanTermActiveState(address loanTermAddress, bool isActive) external onlyOwner {
        require(loanTermActive[loanTermAddress] != isActive);
        loanTermActive[loanTermAddress] = isActive;

        if (isActive) {
            activeLoanTerms.push(loanTermAddress);
            loanTermIndex[loanTermAddress] = activeLoanTerms.length - 1;
        } else {
            address otherLoanTermAddress = activeLoanTerms[activeLoanTerms.length - 1];
            activeLoanTerms[loanTermIndex[loanTermAddress]] = otherLoanTermAddress;
            loanTermIndex[otherLoanTermAddress] = loanTermIndex[loanTermAddress];
            delete loanTermIndex[loanTermAddress];
            activeLoanTerms.pop();
        }

        emit LoanTermActiveStateSet(loanTermAddress, isActive);
    }

    function setLiquidationReward(uint256 reward) external onlyOwner {
        require(liquidationReward != reward);
        uint256 oldReward = liquidationReward;
        liquidationReward = reward;
        emit LiquidationRewardSet(oldReward, reward);
    }

    function setOriginationShares(
        uint256 ecosystemSplitterOriginationShare_,
        uint256 X7DAOOriginationShare_,
        uint256 X7100OriginationShare_,
        uint256 lendingPoolOriginationShare_
    ) external onlyOwner {
        require(
            ecosystemSplitterOriginationShare_ +
                X7DAOOriginationShare_ +
                X7100OriginationShare_ +
                lendingPoolOriginationShare_ ==
                10000
        );

        uint256 oldEcosystemSplitterOriginationShare = ecosystemSplitterOriginationShare;
        uint256 oldX7DAOOriginationShare = X7DAOOriginationShare;
        uint256 oldX7100OriginationShare = X7100OriginationShare;
        uint256 oldLendingPoolOriginationShare = lendingPoolOriginationShare;

        ecosystemSplitterOriginationShare = ecosystemSplitterOriginationShare_;
        X7DAOOriginationShare = X7DAOOriginationShare_;
        X7100OriginationShare = X7100OriginationShare_;
        lendingPoolOriginationShare = lendingPoolOriginationShare_;

        emit OriginationSharesSet(
            oldEcosystemSplitterOriginationShare,
            oldX7DAOOriginationShare,
            oldX7100OriginationShare,
            oldLendingPoolOriginationShare,
            ecosystemSplitterOriginationShare_,
            X7DAOOriginationShare_,
            X7100OriginationShare_,
            lendingPoolOriginationShare_
        );
    }

    function setPremiumShares(
        uint256 ecosystemSplitterPremiumShare_,
        uint256 X7DAOPremiumShare_,
        uint256 X7100PremiumShare_,
        uint256 lendingPoolPremiumShare_
    ) external onlyOwner {
        require(
            ecosystemSplitterPremiumShare_ + X7DAOPremiumShare_ + X7100PremiumShare_ + lendingPoolPremiumShare_ == 10000
        );

        uint256 oldEcosystemSplitterPremiumShare = ecosystemSplitterPremiumShare;
        uint256 oldX7DAOPremiumShare = X7DAOPremiumShare;
        uint256 oldX7100PremiumShare = X7100PremiumShare;
        uint256 oldLendingPoolPremiumShare = lendingPoolPremiumShare;

        ecosystemSplitterPremiumShare = ecosystemSplitterPremiumShare_;
        X7DAOPremiumShare = X7DAOPremiumShare_;
        X7100PremiumShare = X7100PremiumShare_;
        lendingPoolPremiumShare = lendingPoolPremiumShare_;

        emit PremiumSharesSet(
            oldEcosystemSplitterPremiumShare,
            oldX7DAOPremiumShare,
            oldX7100PremiumShare,
            oldLendingPoolPremiumShare,
            ecosystemSplitterPremiumShare_,
            X7DAOPremiumShare_,
            X7100PremiumShare_,
            lendingPoolPremiumShare_
        );
    }

    function setEcosystemSplitter(address recipient) external onlyOwner {
        require(ecosystemSplitter != recipient);
        address oldEcosystemSplitterAddress = ecosystemSplitter;
        ecosystemSplitter = recipient;
        emit EcosystemSplitterSet(oldEcosystemSplitterAddress, recipient);
    }

    function setX7100ReserveRecipient(address recipient) external onlyOwner {
        require(X7100ReserveRecipient != recipient);
        address oldX7100ReserveRecipient = X7100ReserveRecipient;
        X7100ReserveRecipient = recipient;
        emit X7100ReserveRecipientSet(oldX7100ReserveRecipient, recipient);
    }

    function setX7DAORewardRecipient(address recipient) external onlyOwner {
        require(X7DAORewardRecipient != recipient);
        address oldX7DAORewardRecipient = X7DAORewardRecipient;
        X7DAORewardRecipient = recipient;
        emit X7DAORewardRecipientSet(oldX7DAORewardRecipient, recipient);
    }

    function setDiscountAuthority(address discountAuthorityAddress) external onlyOwner {
        require(address(discountAuthority) != discountAuthorityAddress);

        address oldDiscountAuthority = address(discountAuthority);

        discountAuthority = IX7LendingDiscountAuthority(discountAuthorityAddress);

        emit DiscountAuthoritySet(oldDiscountAuthority, discountAuthorityAddress);
    }

    function setRetainedFeeNumerator(uint256 numerator) external onlyOwner {
        require(retainedFeeNumerator != numerator);
        uint256 oldRetainedFeeNumerator = retainedFeeDenominator;
        retainedFeeNumerator = numerator;

        emit RetainedFeeNumeratorSet(oldRetainedFeeNumerator, numerator);
    }

    function setLendingPoolReserve(address reserveAddress) external onlyOwner {
        require(lendingPoolReserve != reserveAddress);

        address oldLendingPoolReserve = lendingPoolReserve;
        lendingPoolReserve = reserveAddress;

        emit LendingPoolReserveSet(oldLendingPoolReserve, reserveAddress);
    }

    function setLendingHalted(bool isHalted) external onlyOwner {
        require(lendingHalted != isHalted);
        lendingHalted = isHalted;

        if (isHalted) {
            emit LendingHalted();
        } else {
            emit LendingCommenced();
        }
    }

    function setAllowLoanBuyout(bool isAllowed) external onlyOwner {
        require(allowLoanBuyout != isAllowed);
        allowLoanBuyout = isAllowed;

        emit LoanBuyoutAllowed(isAllowed);
    }

    function setAuthorizedCapitalManager(address manager, bool isTrusted) external onlyOwner {
        require(authorizedCapitalManagers[manager] != isTrusted);
        authorizedCapitalManagers[manager] = isTrusted;

        emit AuthorizedCapitalManagerSet(manager, isTrusted);
    }

    function setSyncSafeGasAmount(uint256 amount) external onlyOwner {
        require(amount != syncSafeGasAmount);
        uint256 oldSyncSafeGasAmount = syncSafeGasAmount;
        syncSafeGasAmount = amount;
        emit SyncSafeGasAmountSet(oldSyncSafeGasAmount, amount);
    }

    function returnETHToLendingPoolReserve(uint256 amount) external {
        require(authorizedCapitalManagers[msg.sender]);
        require(amount <= address(this).balance - liquidationEscrow);
        require(lendingPoolReserve != address(0));
        X7DMinter(lendingPoolReserve).returnETH{ value: amount }();
    }

    function getInitialLiquidityLoan(
        address tokenAddress,
        uint256 amount,
        address loanTermContract,
        uint256 loanAmount,
        uint256 loanDurationSeconds,
        address liquidityReceiver,
        uint256 deadline
    ) external payable lock returns (uint256 loanID) {
        require(!lendingHalted);
        loanID = nextLoanID;
        nextLoanID += 1;

        require(loanTermActive[loanTermContract]);
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermContract);

        loanTermLookup[loanID] = loanTermContract;

        uint256[5] memory quote = _useQuote(loanTerm, loanAmount, loanDurationSeconds);

        // Duplicates logic from loan terms
        uint256 originationFee = ((quote[1] * quote[4]) / 10000 / 1 gwei) * 1 gwei;
        uint256 roundedLoanAmount = quote[0];

        address loanOwner;
        uint256 amountToCollect;

        if (msg.value >= roundedLoanAmount + originationFee + liquidationReward) {
            // Case when externally funded
            loanOwner = msg.sender;
            amountToCollect = roundedLoanAmount + originationFee + liquidationReward;
        } else if (msg.value >= originationFee + liquidationReward) {
            require(address(this).balance - liquidationEscrow >= roundedLoanAmount);
            loanOwner = address(this);
            amountToCollect = originationFee + liquidationReward;
        } else {
            revert("Insufficient funds provided");
        }

        address pair = _addLiquidity(tokenAddress, amount, roundedLoanAmount, liquidityReceiver, deadline);

        loanPair[loanID] = pair;
        loanToken[loanID] = tokenAddress;

        loanLiquidationReward[loanID] = liquidationReward;
        loanLiquidationReturnTo[loanID] = msg.sender;
        liquidationEscrow += liquidationReward;

        loanTerm.originateLoan(
            roundedLoanAmount,
            originationFee,
            loanDurationSeconds,
            quote[3],
            quote[4],
            loanOwner,
            loanID
        );

        loanBorrower[loanID] = msg.sender;
        loanLookupByBorrower[msg.sender].push(loanID);

        if (loanOwner != address(this)) {
            uint256 returnToSender = msg.value - amountToCollect;
            uint256 retainedFee = (originationFee * retainedFeeNumerator) / retainedFeeDenominator;
            _splitOriginationFee(retainedFee);
            returnToSender += (originationFee - retainedFee);
            if (returnToSender > 0) {
                (bool success, ) = msg.sender.call{ value: returnToSender }("");
                require(success);
            }
        } else {
            _splitOriginationFee(originationFee);
            uint256 returnToSender = msg.value - amountToCollect;
            if (returnToSender > 0) {
                (bool success, ) = msg.sender.call{ value: returnToSender }("");
                require(success);
            }
        }
    }

    function payLiability(uint256 loanID) external payable lock {
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        address owner_ = loanTerm.ownerOf(loanID);
        if (loanTerm.isComplete(loanID) && msg.value > 0) {
            (bool success, ) = msg.sender.call{ value: msg.value }("");
            require(success);
            return;
        }

        (uint256 premiumPaid, uint256 principalPaid, uint256 refundAmount, uint256 remainingLiability) = loanTerm
            .recordPayment(loanID, msg.value);

        if (owner_ != address(this)) {
            uint256 toPayOwner = principalPaid;
            uint256 retainedFee = (premiumPaid * retainedFeeNumerator) / retainedFeeDenominator;

            _splitPremiumFee(retainedFee);
            toPayOwner += premiumPaid - retainedFee;

            if (toPayOwner > 0) {
                // Gas limit imposed to prevent owner griefing repayment
                // Failure is ignored and considered a donation to lending pool
                owner_.call{ gas: 10000, value: toPayOwner }("");
            }
        } else {
            if (premiumPaid > 0) {
                _splitPremiumFee(premiumPaid);
            }
        }

        if (refundAmount > 0) {
            (bool success, ) = msg.sender.call{ value: refundAmount }("");
            require(success);
        }

        IXchangePair pair = IXchangePair(loanPair[loanID]);
        uint256 remainingLockedCapital = pair.tokenMinimumBalance(weth);

        if (remainingLiability < remainingLockedCapital) {
            pair.setMinimumBalance(weth, uint112(remainingLiability));
        }

        if (remainingLiability == 0) {
            _payLiquidationFee(loanID, loanLiquidationReturnTo[loanID]);
            _removeLoanFromIndex(loanID);
        }
    }

    function liquidate(uint256 loanID) external lock {
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        address owner_ = loanTerm.ownerOf(loanID);

        uint256 amountToLiquidate = loanTerm.liquidationAmount(loanID);
        require(amountToLiquidate > 0);

        IXchangePair pair = IXchangePair(loanPair[loanID]);
        uint256 withdrawnTokens = pair.withdrawTokensAgainstMinimumBalance(
            weth,
            address(this),
            uint112(amountToLiquidate)
        );

        // Try to sync the pair. If the paired token is malicious or broken it will not prevent a withdrawal.
        try pair.syncSafe(syncSafeGasAmount, syncSafeGasAmount) {} catch {}

        uint256 remainingLockedTokens = pair.tokenMinimumBalance(weth);

        IWETH(weth).withdraw(withdrawnTokens);

        (uint256 premiumPaid, uint256 principalPaid, uint256 excessAmount, uint256 remainingLiability) = loanTerm
            .recordPrincipalRepayment(loanID, withdrawnTokens);

        if (principalPaid > 0 && owner_ != address(this)) {
            // Gas limit imposed to prevent owner griefing repayment
            // Failure is ignored and considered a donation to lending pool
            owner_.call{ gas: 10000, value: principalPaid }("");
        }

        if (premiumPaid > 0) {
            _splitPremiumFee(premiumPaid);
        }

        if (remainingLiability == 0 || remainingLockedTokens == 0) {
            _payLiquidationFee(loanID, msg.sender);
        }

        if (remainingLiability == 0) {
            _removeLoanFromIndex(loanID);
        }

        if (excessAmount > 0) {
            X7D.mint(ecosystemRecipient, excessAmount);
        }
    }

    function buyoutLoan(uint256 loanID) external payable {
        _buyoutLoan(loanID, msg.sender);
    }

    function buyoutLoanTo(uint256 loanID, address to) external payable {
        _buyoutLoan(loanID, to);
    }

    function depositETH() external payable {
        X7D.mint(msg.sender, msg.value);
    }

    function depositETHForRecipient(address recipient) external payable {
        X7D.mint(recipient, msg.value);
    }

    function returnETH() external payable {
        emit FundsReturned(msg.sender, msg.value);
    }

    function _buyoutLoan(uint256 loanID, address to) internal {
        require(allowLoanBuyout);
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermLookup[loanID]);
        address owner_ = loanTerm.ownerOf(loanID);
        require(owner_ == address(this));

        uint256 buyoutAmount = loanTerm.loanAmount(loanID) - loanTerm.principalAmountPaid(loanID);
        require(buyoutAmount == msg.value);
        loanTerm.transferFrom(address(this), to, loanID);
        emit LoanBoughtOut(to, loanID);
    }

    function _removeLoanFromIndex(uint256 loanID) internal {
        address borrower = loanBorrower[loanID];
        uint256 loanIndex = loanBorrowerIndex[loanID];
        uint256 length = loanLookupByBorrower[borrower].length;
        uint256 lastLoanID = loanLookupByBorrower[borrower][length - 1];
        loanLookupByBorrower[borrower][loanIndex] = lastLoanID;
        loanBorrowerIndex[lastLoanID] = loanIndex;
        loanLookupByBorrower[borrower].pop();
        delete loanBorrowerIndex[loanID];
    }

    function _getQuote(
        address borrower,
        IX7InitialLiquidityLoanTerm loanTerm,
        uint256 loanAmount,
        uint256 loanDurationSeconds
    ) internal view returns (uint256[5] memory) {
        uint256 roundedLoanAmount;
        uint256 originationFee;
        uint256 totalPremium;
        uint256 premiumFeeModifier;
        uint256 originationFeeModifier;

        (roundedLoanAmount, originationFee, totalPremium) = loanTerm.getQuote(loanAmount);
        (premiumFeeModifier, originationFeeModifier) = discountAuthority.getFeeModifiers(
            borrower,
            [loanTerm.minimumLoanAmount(), roundedLoanAmount, loanTerm.maximumLoanAmount()],
            [loanTerm.minimumLoanLengthSeconds(), loanDurationSeconds, loanTerm.maximumLoanLengthSeconds()]
        );

        return [roundedLoanAmount, originationFee, totalPremium, premiumFeeModifier, originationFeeModifier];
    }

    function _getDiscountedQuote(
        address borrower,
        IX7InitialLiquidityLoanTerm loanTerm,
        uint256 loanAmount,
        uint256 loanDurationSeconds
    )
        internal
        view
        returns (
            uint256[7] memory discountedQuote // roundedLoanAmount
        )
    // originationFee
    // totalPremium
    // discountedOriginationFee
    // discountedTotalPremium
    // premiumFeeModifier
    // originationFeeModifier
    {
        uint256 ret1;
        uint256 ret2;
        uint256 ret3;

        // roundedLoanAmount, originationFee, totalPremium
        (ret1, ret2, ret3) = loanTerm.getQuote(loanAmount);
        discountedQuote[0] = ret1; // roundedLoanAmount
        discountedQuote[1] = ret2; // originationFee
        discountedQuote[2] = ret3; // totalPremium

        // premiumFeeModifier, originationFeeModifier
        (ret1, ret2) = discountAuthority.getFeeModifiers(
            borrower,
            [loanTerm.minimumLoanAmount(), ret1, loanTerm.maximumLoanAmount()],
            [loanTerm.minimumLoanLengthSeconds(), loanDurationSeconds, loanTerm.maximumLoanLengthSeconds()]
        );

        discountedQuote[5] = ret1;
        discountedQuote[6] = ret2;

        // roundedLoanAmount, discountedOriginationFee, discountedTotalPremium
        (ret1, ret2, ret3) = loanTerm.getDiscountedQuote(loanAmount, ret1, ret2);

        discountedQuote[3] = ret2;
        discountedQuote[4] = ret3;

        return discountedQuote;
    }

    function _useQuote(
        IX7InitialLiquidityLoanTerm loanTerm,
        uint256 loanAmount,
        uint256 loanDurationSeconds
    ) internal returns (uint256[5] memory) {
        uint256 roundedLoanAmount;
        uint256 originationFee;
        uint256 totalPremium;
        uint256 premiumFeeModifier;
        uint256 originationFeeModifier;

        (roundedLoanAmount, originationFee) = loanTerm.getOriginationAmounts(loanAmount);
        (premiumFeeModifier, originationFeeModifier) = discountAuthority.useFeeModifiers(
            msg.sender,
            [loanTerm.minimumLoanAmount(), roundedLoanAmount, loanTerm.maximumLoanAmount()],
            [loanTerm.minimumLoanLengthSeconds(), loanDurationSeconds, loanTerm.maximumLoanLengthSeconds()]
        );

        return [roundedLoanAmount, originationFee, totalPremium, premiumFeeModifier, originationFeeModifier];
    }

    function _splitOriginationFee(uint256 amount) internal {
        uint256 ecosystemSplitterAmount = (amount * ecosystemSplitterOriginationShare) / 10000;
        uint256 X7100LiquidityAmount = (amount * X7100OriginationShare) / 10000;
        uint256 X7DAOAmount = (amount * X7DAOOriginationShare) / 10000;
        uint256 lendingPoolAmount = amount - ecosystemSplitterAmount - X7100LiquidityAmount - X7DAOAmount;

        bool success;

        if (ecosystemSplitterAmount > 0) {
            (success, ) = ecosystemSplitter.call{ value: ecosystemSplitterAmount }("");
            require(success);
        }

        if (X7100LiquidityAmount > 0) {
            (success, ) = X7100ReserveRecipient.call{ value: X7100LiquidityAmount }("");
            require(success);
        }

        if (X7DAOAmount > 0) {
            (success, ) = X7DAORewardRecipient.call{ value: X7DAOAmount }("");
            require(success);
        }

        if (lendingPoolAmount > 0) {
            X7D.mint(ecosystemRecipient, lendingPoolAmount);
        }
    }

    function _splitPremiumFee(uint256 amount) internal {
        uint256 ecosystemSplitterAmount = (amount * ecosystemSplitterPremiumShare) / 10000;
        uint256 X7100Amount = (amount * X7100PremiumShare) / 10000;
        uint256 X7DAOAmount = (amount * X7DAOPremiumShare) / 10000;
        uint256 lendingPoolAmount = amount - ecosystemSplitterAmount - X7100Amount - X7DAOAmount;

        bool success;
        if (ecosystemSplitterAmount > 0) {
            (success, ) = ecosystemSplitter.call{ value: ecosystemSplitterAmount }("");
            require(success);
        }

        if (X7100Amount > 0) {
            (success, ) = X7100ReserveRecipient.call{ value: X7100Amount }("");
            require(success);
        }

        if (X7DAOAmount > 0) {
            (success, ) = X7DAORewardRecipient.call{ value: X7DAOAmount }("");
            require(success);
        }

        if (lendingPoolAmount > 0) {
            X7D.mint(ecosystemRecipient, lendingPoolAmount);
        }
    }

    function _payLiquidationFee(uint256 loanID, address recipient) internal {
        uint256 amount = loanLiquidationReward[loanID];
        if (amount == 0) {
            return;
        }

        // Ensures liquidation reward is only ever paid out once
        loanLiquidationReward[loanID] = 0;

        (bool success, ) = recipient.call{ value: amount }("");
        require(success);
        liquidationEscrow -= amount;
    }

    function _addLiquidity(
        address tokenAddress,
        uint256 amount,
        uint256 roundedLoanAmount,
        address liquidityTokenReceiver,
        uint256 timestamp
    ) internal returns (address) {
        IXchangeFactory factory = IXchangeFactory(router.factory());
        address pairAddress = factory.getPair(tokenAddress, router.WETH());
        IXchangePair pair;

        if (pairAddress != address(0)) {
            pair = IXchangePair(pairAddress);
            (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
            require(reserve0 == 0 && reserve1 == 0);
        } else {
            pairAddress = factory.createPair(tokenAddress, router.WETH());
            pair = IXchangePair(pairAddress);
        }

        pair.setMinimumBalance(weth, uint112(roundedLoanAmount));

        TransferHelper.safeTransferFrom(tokenAddress, msg.sender, address(this), amount);
        TransferHelper.safeApprove(tokenAddress, address(router), amount);

        router.addLiquidityETH{ value: roundedLoanAmount }(
            tokenAddress,
            amount,
            0,
            0,
            liquidityTokenReceiver,
            timestamp
        );

        return address(pair);
    }
}

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: APPROVE_FAILED");
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FROM_FAILED");
    }
}


// File: contracts/X7LiquidityMaxi.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-721 Token "X7 Liquidity Maxi" NFT

A utility NFT offering fee discounts across the X7 ecosystem.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setMintFeeDestination(address mintFeeDestination_) external onlyOwner {
        require(mintFeeDestination != mintFeeDestination_);
        address oldMintFeeDestination = mintFeeDestination;
        mintFeeDestination = mintFeeDestination_;
        emit MintFeeDestinationSet(oldMintFeeDestination, mintFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        require(mintPrice_ > mintPrice);
        uint256 oldPrice = mintPrice;
        mintPrice = mintPrice_;
        emit MintPriceSet(oldPrice, mintPrice_);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{ value: amount }("");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{ value: value }(data);
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
}

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

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

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

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

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
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
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
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
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
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
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

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
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
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

interface IX7Migration {
    function inMigration(address) external view returns (bool);
}

contract X7LiquidityMaxi is ERC721Enumerable, ERC721Holder, Ownable {
    address payable public mintFeeDestination;
    address payable public treasury;
    string public _internalBaseURI;

    uint256 public maxSupply = 250;
    uint256 public mintPrice = 5 * 10 ** 17;
    uint256 public maxMintsPerTransaction = 4;

    bool public mintingOpen;
    bool public whitelistComplete;

    bool public whitelistActive = true;
    IX7Migration public whitelistAuthority;

    event MintingOpen();
    event MintFeeDestinationSet(address indexed oldDestination, address indexed newDestination);
    event MintPriceSet(uint256 oldPrice, uint256 newPrice);
    event BaseURISet(string oldURI, string newURI);
    event WhitelistActivitySet(bool whitelistActive);
    event WhitelistAuthoritySet(address indexed oldWhitelistAuthority, address indexed newWhitelistAuthority);

    constructor(
        address mintFeeDestination_,
        address treasury_
    ) ERC721("X7 Liquidity Maxi", "X7LMAXI") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        mintFeeDestination = payable(mintFeeDestination_);
        treasury = payable(treasury_);
    }

    function whitelist(address holder) external view returns (bool) {
        return whitelistAuthority.inMigration(holder);
    }

    function setMintFeeDestination(address mintFeeDestination_) external onlyOwner {
        require(mintFeeDestination != mintFeeDestination_);
        address oldMintFeeDestination = mintFeeDestination;
        mintFeeDestination = payable(mintFeeDestination_);
        emit MintFeeDestinationSet(oldMintFeeDestination, mintFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        require(mintPrice_ > mintPrice);
        uint256 oldPrice = mintPrice;
        mintPrice = mintPrice_;
        emit MintPriceSet(oldPrice, mintPrice_);
    }

    function setWhitelist(bool isActive) external onlyOwner {
        require(!whitelistComplete);
        require(whitelistActive != isActive);
        whitelistActive = isActive;
        emit WhitelistActivitySet(isActive);
    }

    function setWhitelistComplete() external onlyOwner {
        require(!whitelistComplete);
        whitelistComplete = true;
        whitelistActive = false;
    }

    function setWhitelistAuthority(address whitelistAuthority_) external onlyOwner {
        require(address(whitelistAuthority) != whitelistAuthority_);
        address oldWhitelistAuthority = address(whitelistAuthority);
        whitelistAuthority = IX7Migration(whitelistAuthority_);
        emit WhitelistAuthoritySet(oldWhitelistAuthority, whitelistAuthority_);
    }

    function openMinting() external onlyOwner {
        require(!mintingOpen);
        require(mintFeeDestination != address(0));
        mintingOpen = true;
        emit MintingOpen();
    }

    function mint() external payable {
        _mintMany(1);
    }

    function mintMany(uint256 numMints) external payable {
        _mintMany(numMints);
    }

    function _mintMany(uint256 numMints) internal {
        require(mintingOpen);
        require(!whitelistActive || whitelistAuthority.inMigration(msg.sender));
        require(totalSupply() + numMints <= maxSupply);
        require(numMints > 0 && numMints <= maxMintsPerTransaction);
        require(msg.value == numMints * mintPrice);

        uint256 treasuryFee = (msg.value * 10) / 100;

        bool success;

        (success, ) = treasury.call{ value: treasuryFee }("");
        require(success);

        (success, ) = mintFeeDestination.call{ value: msg.value - treasuryFee }("");
        require(success);

        uint256 nextTokenId = ERC721Enumerable.totalSupply();

        for (uint i = 0; i < numMints; i++) {
            super._mint(msg.sender, nextTokenId + i);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }
}


// File: contracts/X7Magister.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-721 Token "X7 Magister" NFT

A utility NFT offering strong influence on DAO governance.

Within the DAO, governance votes will typically pass by simple majority votes.
This creates risk in the ecosystem in scenarios where the ecosystem or a minority of investors would be severely
hurt by such a decision.

The Magister NFT is the answer to this riddle. The Magister NFT will grant voting access to a second tier of
veto-only voting.

This Magister tier voting can vote AGAINST proposals. If a majority of Magister NFT holders votes against a proposal
it increases the threshold that must be attained by the DAO to pass that proposal. The Magister NFT is a check on
simply majority voting.

At contract creation, seven will be minted for free and transferred to the seven active developers of the project.
This will grant this initial group a level of influence initially while still maintaining decentralized autonomy.

We expect that highly invested parties will purchase one or more of these NFTs as insurance for their holdings.

90% of the mint at launch will go into V2 liquidity.
Post v1 to v2 migration, the 90% of the mint fee go to the Revenue Splitter.

10% goes into the Treasury.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setMintFeeDestination(address mintFeeDestination_) external onlyOwner {
        require(mintFeeDestination != mintFeeDestination_);
        address oldMintFeeDestination = mintFeeDestination;
        mintFeeDestination = mintFeeDestination_;
        emit MintFeeDestinationSet(oldMintFeeDestination, mintFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        require(mintPrice_ > mintPrice);
        uint256 oldPrice = mintPrice;
        mintPrice = mintPrice_;
        emit MintPriceSet(oldPrice, mintPrice_);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{ value: amount }("");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{ value: value }(data);
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
}

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

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

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

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

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
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
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
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
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
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
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

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
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
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

interface IX7Migration {
    function inMigration(address) external view returns (bool);
}

contract X7Magister is ERC721Enumerable, ERC721Holder, Ownable {
    address payable public mintFeeDestination;
    address payable public treasury;
    string public _internalBaseURI;

    uint256 public maxSupply = 49;
    uint256 public mintPrice = 50 ether;
    uint256 public maxMintsPerTransaction = 1;

    bool public mintingOpen;
    bool public whitelistComplete;

    bool public whitelistActive = true;
    IX7Migration public whitelistAuthority;

    event MintingOpen();
    event MintFeeDestinationSet(address indexed oldDestination, address indexed newDestination);
    event MintPriceSet(uint256 oldPrice, uint256 newPrice);
    event BaseURISet(string oldURI, string newURI);
    event WhitelistActivitySet(bool whitelistActive);
    event WhitelistAuthoritySet(address indexed oldWhitelistAuthority, address indexed newWhitelistAuthority);

    constructor(
        address mintFeeDestination_,
        address treasury_
    ) ERC721("X7 Magister", "X7MAGISTER") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        mintFeeDestination = payable(mintFeeDestination_);
        treasury = payable(treasury_);

        // These mints will be transferred to the active developers as soon
        // as positive control on the profit splitter is demonstrated.
        super._mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 0);
        super._mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 1);
        super._mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 2);
        super._mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 3);
        super._mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 4);
        super._mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 5);
        super._mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 6);
    }

    function whitelist(address holder) external view returns (bool) {
        return whitelistAuthority.inMigration(holder);
    }

    function setMintFeeDestination(address mintFeeDestination_) external onlyOwner {
        require(mintFeeDestination != mintFeeDestination_);
        address oldMintFeeDestination = mintFeeDestination;
        mintFeeDestination = payable(mintFeeDestination_);
        emit MintFeeDestinationSet(oldMintFeeDestination, mintFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        require(mintPrice_ > mintPrice);
        uint256 oldPrice = mintPrice;
        mintPrice = mintPrice_;
        emit MintPriceSet(oldPrice, mintPrice_);
    }

    function setWhitelist(bool isActive) external onlyOwner {
        require(!whitelistComplete);
        require(whitelistActive != isActive);
        whitelistActive = isActive;
        emit WhitelistActivitySet(isActive);
    }

    function setWhitelistComplete() external onlyOwner {
        require(!whitelistComplete);
        whitelistComplete = true;
        whitelistActive = false;
    }

    function setWhitelistAuthority(address whitelistAuthority_) external onlyOwner {
        require(address(whitelistAuthority) != whitelistAuthority_);
        address oldWhitelistAuthority = address(whitelistAuthority);
        whitelistAuthority = IX7Migration(whitelistAuthority_);
        emit WhitelistAuthoritySet(oldWhitelistAuthority, whitelistAuthority_);
    }

    function openMinting() external onlyOwner {
        require(!mintingOpen);
        require(mintFeeDestination != address(0));
        mintingOpen = true;
        emit MintingOpen();
    }

    function mint() external payable {
        _mintMany(1);
    }

    function mintMany(uint256 numMints) external payable {
        _mintMany(numMints);
    }

    function _mintMany(uint256 numMints) internal {
        require(mintingOpen);
        require(!whitelistActive || whitelistAuthority.inMigration(msg.sender));
        require(totalSupply() + numMints <= maxSupply);
        require(numMints > 0 && numMints <= maxMintsPerTransaction);
        require(msg.value == numMints * mintPrice);

        uint256 treasuryFee = (msg.value * 10) / 100;

        bool success;

        (success, ) = treasury.call{ value: treasuryFee }("");
        require(success);

        (success, ) = mintFeeDestination.call{ value: msg.value - treasuryFee }("");
        require(success);

        uint256 nextTokenId = ERC721Enumerable.totalSupply();

        for (uint i = 0; i < numMints; i++) {
            super._mint(msg.sender, nextTokenId + i);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }
}


// File: contracts/X7Pioneer.sol
/**
 *Submitted for verification at Etherscan.io on 2022-11-09
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-721 Token "X7 Pioneer" NFT

A utility NFT offering reward withdrawal.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setTransferUnlockFeeDestination(address transferUnlockFeeDestination_) external onlyOwner {
        require(transferUnlockFeeDestination != transferUnlockFeeDestination_);
        address oldTransferUnlockFeeDestination = transferUnlockFeeDestination;
        transferUnlockFeeDestination = payable(transferUnlockFeeDestination_);
        emit TransferUnlockFeeDestinationSet(oldTransferUnlockFeeDestination, transferUnlockFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setTransferUnlockFee(uint256 transferUnlockFee_) external onlyOwner {
        require(transferUnlockFee_ != transferUnlockFee);
        uint256 oldTransferUnlockFee = transferUnlockFee;
        transferUnlockFee = transferUnlockFee_;
        emit TransferUnlockFeeSet(oldTransferUnlockFee, transferUnlockFee_);
    }

    function SetAllowTokenOwnerVariantSelection(bool allowed) external onlyOwner {
        require(allowTokenOwnerVariantSelection != allowed);
        allowTokenOwnerVariantSelection = allowed;
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

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

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{ value: amount }("");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{ value: value }(data);
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
}

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

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

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

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

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
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
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
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
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
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
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

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
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
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract X7Pioneer is ERC721Enumerable, ERC721Holder, Ownable, ReentrancyGuard {
    enum Variant {
        NOT_SELECTED,
        SELECTION1,
        SELECTION2,
        SELECTION3,
        SELECTION4,
        SELECTION5,
        SELECTION6,
        SELECTION7
    }

    address payable public transferUnlockFeeDestination;
    string public _internalBaseURI;

    mapping(uint256 => bool) public transferUnlocked;

    uint256 public lastETHBalance;
    uint256 public totalRewards;

    // token ID => claimed rewards
    mapping(uint256 => uint256) public rewardsClaimed;

    // 0.07 ETH
    uint256 public transferUnlockFee = 7 * 10 ** 16;

    bool public airdropActive = true;
    mapping(address => bool) public receivedAirdrop;

    bool public allowTokenOwnerVariantSelection = true;

    // tokenId => Variant
    mapping(uint256 => Variant) public selectedVariantIndex;

    event TransferUnlockFeeDestinationSet(address indexed oldDestination, address indexed newDestination);
    event TransferUnlockFeeSet(uint256 oldPrice, uint256 newPrice);

    event BaseURISet(string oldURI, string newURI);
    event TransferUnlocked(uint256 indexed tokenId);

    event RewardsClaimed(uint256 indexed tokenId, address indexed receipient, uint256 amount);

    event AirdropDisabled();
    event VariantSelected(uint256 indexed tokenId, Variant variantIndex);

    constructor(
        address transferUnlockFeeDestination_
    ) ERC721("X7 Pioneer", "X7PIONEER") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        transferUnlockFeeDestination = payable(transferUnlockFeeDestination_);
    }

    receive() external payable {}

    function setTransferUnlockFeeDestination(address transferUnlockFeeDestination_) external onlyOwner {
        require(transferUnlockFeeDestination != transferUnlockFeeDestination_);
        address oldTransferUnlockFeeDestination = transferUnlockFeeDestination;
        transferUnlockFeeDestination = payable(transferUnlockFeeDestination_);
        emit TransferUnlockFeeDestinationSet(oldTransferUnlockFeeDestination, transferUnlockFeeDestination_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        require(keccak256(abi.encodePacked(_internalBaseURI)) != keccak256(abi.encodePacked(baseURI_)));
        string memory oldBaseURI = _internalBaseURI;
        _internalBaseURI = baseURI_;
        emit BaseURISet(oldBaseURI, baseURI_);
    }

    function setTransferUnlockFee(uint256 transferUnlockFee_) external onlyOwner {
        require(transferUnlockFee_ != transferUnlockFee);
        uint256 oldTransferUnlockFee = transferUnlockFee;
        transferUnlockFee = transferUnlockFee_;
        emit TransferUnlockFeeSet(oldTransferUnlockFee, transferUnlockFee_);
    }

    function SetAllowTokenOwnerVariantSelection(bool allowed) external onlyOwner {
        require(allowTokenOwnerVariantSelection != allowed);
        allowTokenOwnerVariantSelection = allowed;
    }

    function airdropTokens(address[] memory recipients) external onlyOwner {
        require(airdropActive);
        for (uint i = 0; i < recipients.length; i++) {
            if (!receivedAirdrop[recipients[i]]) {
                uint256 nextTokenId = ERC721Enumerable.totalSupply();
                super._mint(recipients[i], nextTokenId + i);
            }
        }
    }

    function disableAirDrop() external onlyOwner {
        require(airdropActive);
        airdropActive = false;
        emit AirdropDisabled();
    }

    function unlockTransfer(uint256 tokenId) external payable {
        require(!transferUnlocked[tokenId]);
        require(ownerOf(tokenId) == msg.sender);
        require(msg.value == transferUnlockFee);
        (bool ok, ) = transferUnlockFeeDestination.call{ value: msg.value }("");
        require(ok);
        transferUnlocked[tokenId] = true;
        emit TransferUnlocked(tokenId);
    }

    function claimRewards(uint256[] memory tokenIds) public nonReentrant {
        if (lastETHBalance < address(this).balance) {
            totalRewards += (address(this).balance - lastETHBalance);
        }

        uint256 claimable;
        uint256 tokenClaimable;

        for (uint i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender);
            uint256 tokenTotalRewards = totalRewards / totalSupply();
            uint256 tokenClaimedRewards = rewardsClaimed[tokenIds[i]];
            if (tokenClaimedRewards < tokenTotalRewards) {
                rewardsClaimed[tokenIds[i]] = tokenTotalRewards;
                tokenClaimable = tokenTotalRewards - tokenClaimedRewards;
                claimable += tokenClaimable;
                emit RewardsClaimed(tokenIds[i], msg.sender, tokenClaimable);
            }
        }

        if (claimable > 0) {
            lastETHBalance = address(this).balance - claimable;
            (bool ok, ) = msg.sender.call{ value: claimable }("");
            require(ok);
        }
    }

    function unclaimedRewards(uint256 tokenId) public view returns (uint256) {
        uint256 totalRewards_ = totalRewards;
        if (lastETHBalance < address(this).balance) {
            totalRewards_ += (address(this).balance - lastETHBalance);
        }
        return (totalRewards / totalSupply()) - rewardsClaimed[tokenId];
    }

    function unclaimedRewards(uint[] memory tokenIds) public view returns (uint256) {
        uint256 totalRewards_ = totalRewards;
        if (lastETHBalance < address(this).balance) {
            totalRewards_ += (address(this).balance - lastETHBalance);
        }

        uint256 claimable;
        uint256 tokenClaimable;

        for (uint i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender);
            uint256 tokenTotalRewards = totalRewards / totalSupply();
            uint256 tokenClaimedRewards = rewardsClaimed[tokenIds[i]];
            if (tokenClaimedRewards < tokenTotalRewards) {
                tokenClaimable = tokenTotalRewards - tokenClaimedRewards;
                claimable += tokenClaimable;
            }
        }

        return claimable;
    }

    function selectVariant(uint256 tokenId, Variant variant) external {
        require(allowTokenOwnerVariantSelection);
        require(ownerOf(tokenId) == msg.sender);
        require(variant != Variant.NOT_SELECTED);
        require(variant != selectedVariantIndex[tokenId]);
        selectedVariantIndex[tokenId] = variant;
        emit VariantSelected(tokenId, variant);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        require(transferUnlocked[tokenId] || msg.sender == owner());
        super._beforeTokenTransfer(from, to, tokenId);
    }
    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }
}


// File: contracts/X7ProfitShareSplitterV1.sol
/**
 *Submitted for verification at Etherscan.io on 2023-08-28
 */

/**
 *Submitted for verification at Etherscan.io on 2023-08-28
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract representing a profit sharing agreement

This contract will NOT be renounced.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IWETH {
    function withdraw(uint) external;
}

interface IERC20 {
    function transfer(address to, uint value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract X7ProfitShareSplitterV1 is Ownable {
    uint256 public reservedETH;
    uint256 public totalShares = 0;

    uint256[] public outletShares;
    mapping(uint256 => uint256) public outletBalance;
    mapping(uint256 => address) public outletRecipient;
    mapping(address => uint256) public outletLookup;
    mapping(uint256 => mapping(address => bool)) public outletController;
    mapping(uint256 => bool) public outletFrozen;

    address public WETH;
    address public tokenReceiver;
    bool public initialized = false;

    event TokenReceiverSet(address indexed oldReceiver, address indexed newReceiver);
    event OutletControllerAuthorizationSet(
        uint256 indexed outlet,
        address indexed setter,
        address indexed controller,
        bool authorization
    );
    event OutletRecipientSet(uint256 indexed outlet, address indexed oldRecipient, address indexed newRecipient);
    event OutletSharesSet(uint256 indexed outlet, uint256 oldShares, uint256 newShares);
    event OutletFrozen(uint256 indexed outlet);
    event NewRecipientAdded(
        uint256 indexed outlet,
        address indexed recipient,
        address indexed controller,
        uint256 shares
    );
    event TotalSharesChanged(uint256 oldShareCount, uint256 newShareCount);

    constructor(address weth, address tokenReceiver_) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        // index 0 is skipped
        outletShares.push(0);
        WETH = weth;
        tokenReceiver = tokenReceiver_;
    }

    receive() external payable {}

    function setInitialized() external onlyOwner {
        require(!initialized);
        initialized = true;
    }

    function setTokenReceiver(address receiver) external onlyOwner {
        address oldReceiver = tokenReceiver;
        tokenReceiver = receiver;

        emit TokenReceiverSet(oldReceiver, receiver);
    }

    function addNewRecipient(address newRecipient, address controller, uint256 shares) external onlyOwner {
        // A new recipient can only be added after the current state has been resolved
        divvyUp();

        // No duplicate recipients allowed
        require(outletLookup[newRecipient] == 0);

        // All new recipients must have shares
        require(shares > 0);

        outletShares.push(shares);

        uint256 outlet = outletShares.length - 1;

        outletRecipient[outlet] = newRecipient;
        outletLookup[newRecipient] = outlet;

        outletController[outlet][owner()] = true;

        // New recipient is advised to remove the above entry as a signal
        // of positive control of their controller address
        outletController[outlet][controller] = true;
        totalShares += shares;

        emit NewRecipientAdded(outlet, newRecipient, controller, shares);
        emit TotalSharesChanged(totalShares - shares, totalShares);
    }

    function setOutletShares(uint256 outlet, uint256 newShares) external onlyOwner {
        // Shares can only be reset if the current state has been resolved
        divvyUp();

        require(outlet != 0 && outlet < outletShares.length);
        uint256 currentShares = outletShares[outlet];
        uint originalTotalShares = totalShares;

        if (newShares > currentShares) {
            outletShares[outlet] = newShares;
            totalShares += (newShares - currentShares);
        } else if (newShares < currentShares) {
            outletShares[outlet] = newShares;
            totalShares -= (currentShares - newShares);
        }

        if (originalTotalShares != totalShares) {
            emit TotalSharesChanged(originalTotalShares, totalShares);
        }

        if (newShares != currentShares) {
            emit OutletSharesSet(outlet, currentShares, newShares);
        }
    }

    function divvyUp() public {
        if (!initialized) {
            return;
        }

        uint256 newETH = address(this).balance - reservedETH;
        uint256 spentETH = 0;

        if (newETH > 0) {
            for (uint256 i = 1; i < outletShares.length - 1; i++) {
                uint256 addBalance = (newETH * outletShares[i]) / totalShares;
                spentETH += addBalance;
                outletBalance[i] += addBalance;
            }

            outletBalance[outletShares.length - 1] += (newETH - spentETH);
            reservedETH = address(this).balance;
        }
    }

    function setOutletControllerAuthorization(uint256 outlet, address controller, bool authorization) external {
        require(!outletFrozen[outlet]);
        require(outletController[outlet][msg.sender]);
        outletController[outlet][controller] = authorization;
        emit OutletControllerAuthorizationSet(outlet, msg.sender, controller, authorization);
    }

    function setOutletRecipient(uint256 outlet, address recipient) external {
        require(!outletFrozen[outlet]);
        require(outletRecipient[outlet] != recipient);
        require(outletController[outlet][msg.sender]);
        require(outletLookup[recipient] == 0);

        address oldRecipient = outletRecipient[outlet];

        outletLookup[recipient] = outlet;
        outletLookup[oldRecipient] = 0;
        outletRecipient[outlet] = recipient;

        emit OutletRecipientSet(outlet, oldRecipient, recipient);
    }

    function freezeOutlet(uint256 outlet) external {
        require(outletController[outlet][msg.sender]);
        outletFrozen[outlet] = true;
        emit OutletFrozen(outlet);
    }

    function takeBalance() external {
        uint256 outlet = outletLookup[msg.sender];
        require(outlet != 0);
        divvyUp();
        _sendBalance(outlet);
    }

    function takeCurrentBalance() external {
        uint256 outlet = outletLookup[msg.sender];
        require(outlet != 0);
        _sendBalance(outlet);
    }

    function pushAll() public {
        divvyUp();
        for (uint256 i = 1; i < outletShares.length; i++) {
            _sendBalance(i);
        }
    }

    function rescueWETH() public {
        IWETH(WETH).withdraw(IERC20(WETH).balanceOf(address(this)));
        pushAll();
    }

    function rescueTokens(address tokenAddress) external {
        if (tokenAddress == WETH) {
            rescueWETH();
        } else {
            IERC20(tokenAddress).transfer(tokenReceiver, IERC20(tokenAddress).balanceOf(address(this)));
        }
    }

    function _sendBalance(uint256 outlet) internal {
        bool success;
        address recipient = outletRecipient[outlet];

        if (recipient == address(0)) {
            return;
        }

        uint256 ethToSend = outletBalance[outlet];

        if (ethToSend > 0) {
            outletBalance[outlet] = 0;
            reservedETH -= ethToSend;

            (success, ) = recipient.call{ value: ethToSend }("");
            if (!success) {
                outletBalance[outlet] += ethToSend;
                reservedETH += ethToSend;
            }
        }
    }
}


// File: contracts/X7R.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-24
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-20 Token X7R

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
    }

    function setAMM(address ammAddress, bool isAMM) external onlyOwner {
        ammPair[ammAddress] = isAMM;
    }

    function setOffRampPair(address ammAddress) external onlyOwner {
        offRampPair = ammAddress;
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }

        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

interface ILiquidityHub {
    function processFees(address) external;
}

interface IDiscountAuthority {
    function discountRatio(address) external view returns (uint256, uint256);
}

contract X7R is ERC20, Ownable {
    IDiscountAuthority public discountAuthority;
    ILiquidityHub public liquidityHub;

    mapping(address => bool) public ammPair;
    address public offRampPair;

    // max 7% fee
    uint256 public maxFeeNumerator = 700;

    // 6 % fee
    uint256 public feeNumerator = 600;
    uint256 public feeDenominator = 10000;

    bool discountAuthorityFrozen;
    bool liquidityHubFrozen;

    bool transfersEnabled;

    event LiquidityHubSet(address indexed liquidityHub);
    event DiscountAuthoritySet(address indexed discountAuthority);
    event FeeNumeratorSet(uint256 feeNumerator);
    event AMMSet(address indexed pairAddress, bool isAMM);
    event OffRampPairSet(address indexed offRampPair);
    event LiquidityHubFrozen();
    event DiscountAuthorityFrozen();

    constructor(
        address discountAuthority_,
        address liquidityHub_
    ) ERC20("X7R", "X7R") Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        discountAuthority = IDiscountAuthority(discountAuthority_);
        liquidityHub = ILiquidityHub(liquidityHub_);

        _mint(address(0xC71a68467c5e090a61079797E1ED96df7DA69266), 100000000 * 10 ** 18);
    }

    function setLiquidityHub(address liquidityHub_) external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHub = ILiquidityHub(liquidityHub_);
        emit LiquidityHubSet(liquidityHub_);
    }

    function setDiscountAuthority(address discountAuthority_) external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthority = IDiscountAuthority(discountAuthority_);
        emit DiscountAuthoritySet(discountAuthority_);
    }

    function setFeeNumerator(uint256 feeNumerator_) external onlyOwner {
        require(feeNumerator_ <= maxFeeNumerator);
        feeNumerator = feeNumerator_;
        emit FeeNumeratorSet(feeNumerator_);
    }

    function setAMM(address ammAddress, bool isAMM) external onlyOwner {
        ammPair[ammAddress] = isAMM;
        emit AMMSet(ammAddress, isAMM);
    }

    function setOffRampPair(address ammAddress) external onlyOwner {
        offRampPair = ammAddress;
        emit OffRampPairSet(ammAddress);
    }

    function freezeLiquidityHub() external onlyOwner {
        require(!liquidityHubFrozen);
        liquidityHubFrozen = true;
        emit LiquidityHubFrozen();
    }

    function freezeDiscountAuthority() external onlyOwner {
        require(!discountAuthorityFrozen);
        discountAuthorityFrozen = true;
        emit DiscountAuthorityFrozen();
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0)) - balanceOf(address(0x000000000000000000000000000000000000dEaD));
    }

    function enableTrading() external onlyOwner {
        require(!transfersEnabled);
        transfersEnabled = true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(transfersEnabled || from == owner());

        uint256 transferAmount = amount;

        if (from == address(liquidityHub) || to == address(liquidityHub)) {
            super._transfer(from, to, amount);
            return;
        }

        if (ammPair[to] || ammPair[from]) {
            address effectivePrincipal;
            if (ammPair[to]) {
                effectivePrincipal = from;
            } else {
                effectivePrincipal = to;
            }

            (uint256 feeModifierNumerator, uint256 feeModifierDenominator) = discountAuthority.discountRatio(
                effectivePrincipal
            );
            if (feeModifierNumerator > feeModifierDenominator || feeModifierDenominator == 0) {
                feeModifierNumerator = 1;
                feeModifierDenominator = 1;
            }

            uint256 feeAmount = (amount * feeNumerator * feeModifierNumerator) /
                feeDenominator /
                feeModifierDenominator;

            super._transfer(from, address(liquidityHub), feeAmount);
            transferAmount = amount - feeAmount;
        }

        if (to == offRampPair) {
            liquidityHub.processFees(address(this));
        }

        super._transfer(from, to, transferAmount);
    }

    function rescueETH() external {
        (bool success, ) = payable(address(liquidityHub)).call{ value: address(this).balance }("");
        require(success);
    }

    function rescueTokens(address tokenAddress) external {
        IERC20(tokenAddress).transfer(address(liquidityHub), IERC20(tokenAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7RDiscountAuthority.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-19
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for X7R fee discounts

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setEcosystemMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(ecoMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(ecoMaxiNFT);
        ecoMaxiNFT = IERC721(tokenAddress);
        emit EcosystemMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function setLiquidityMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(liqMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(liqMaxiNFT);
        liqMaxiNFT = IERC721(tokenAddress);
        emit LiquidityMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function setMagisterNFT(address tokenAddress) external onlyOwner {
        require(address(magisterNFT) != tokenAddress);
        address oldTokenAddress = address(magisterNFT);
        magisterNFT = IERC721(tokenAddress);
        emit MagisterNFTSet(oldTokenAddress, tokenAddress);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
}

interface IDiscountAuthority {
    function discountRatio(address) external view returns (uint256, uint256);
}

contract X7RDiscountAuthority is Ownable {
    IERC721 public ecoMaxiNFT;
    IERC721 public liqMaxiNFT;
    IERC721 public magisterNFT;

    event EcosystemMaxiNFTSet(address indexed oldTokenAddress, address indexed newTokenAddress);
    event LiquidityMaxiNFTSet(address indexed oldTokenAddress, address indexed newTokenAddress);
    event MagisterNFTSet(address indexed oldTokenAddress, address indexed newTokenAddress);

    constructor() Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {}

    function setEcosystemMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(ecoMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(ecoMaxiNFT);
        ecoMaxiNFT = IERC721(tokenAddress);
        emit EcosystemMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function setLiquidityMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(liqMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(liqMaxiNFT);
        liqMaxiNFT = IERC721(tokenAddress);
        emit LiquidityMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function setMagisterNFT(address tokenAddress) external onlyOwner {
        require(address(magisterNFT) != tokenAddress);
        address oldTokenAddress = address(magisterNFT);
        magisterNFT = IERC721(tokenAddress);
        emit MagisterNFTSet(oldTokenAddress, tokenAddress);
    }

    function discountRatio(address swapper) external view returns (uint256 numerator, uint256 denominator) {
        numerator = 1;
        denominator = 1;

        if (liqMaxiNFT.balanceOf(swapper) > 0 || magisterNFT.balanceOf(swapper) > 0) {
            // 25% discount
            numerator = 75;
            denominator = 100;
        } else if (ecoMaxiNFT.balanceOf(swapper) > 0) {
            // 10% discount
            numerator = 90;
            denominator = 100;
        }
    }
}


// File: contracts/X7RLiquidityHub.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-27
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for managing X7R fee tokens

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setShares(uint256 distributeShare_, uint256 liquidityShare_, uint256 treasuryShare_) external onlyOwner {
        require(distributeShare + liquidityShare + treasuryShare == 1000);

        require(distributeShare_ >= minShare && distributeShare_ <= maxShare);
        require(liquidityShare_ >= minShare && liquidityShare_ <= maxShare);
        require(treasuryShare_ >= minShare && treasuryShare_ <= maxShare);

        distributeShare = distributeShare_;
        liquidityShare = liquidityShare_;
        treasuryShare = treasuryShare_;

        emit SharesSet(distributeShare_, liquidityShare_, treasuryShare_);
    }

    function setRouter(address router_) external onlyOwner {
        require(router_ != address(router));
        router = IUniswapV2Router(router_);
        emit RouterSet(router_);
    }

    function setOffRampPair(address offRampPairAddress) external onlyOwner {
        require(offRampPair != offRampPairAddress);
        offRampPair = offRampPairAddress;
        emit OffRampPairSet(offRampPairAddress);
    }

    function setBalanceThreshold(uint256 threshold) external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThreshold = threshold;
        emit BalanceThresholdSet(threshold);
    }

    function setLiquidityRatioTarget(uint256 liquidityRatioTarget_) external onlyOwner {
        require(liquidityRatioTarget_ != liquidityRatioTarget);
        require(liquidityRatioTarget_ >= minLiquidityRatioTarget && liquidityRatioTarget <= maxLiquidityRatioTarget);
        liquidityRatioTarget = liquidityRatioTarget_;
        emit LiquidityRatioTargetSet(liquidityRatioTarget_);
    }

    function setLiquidityTokenReceiver(address liquidityTokenReceiver_) external onlyOwner {
        require(
            liquidityTokenReceiver_ != address(0)
            && liquidityTokenReceiver_ != address(0x000000000000000000000000000000000000dEaD)
            && liquidityTokenReceiver != liquidityTokenReceiver_
        );

        address oldLiquidityTokenReceiver = liquidityTokenReceiver;
        liquidityTokenReceiver = liquidityTokenReceiver_;
        emit LiquidityTokenReceiverSet(oldLiquidityTokenReceiver, liquidityTokenReceiver_);
    }

    function setDistributionTarget(address target) external onlyOwner {
        require(
            target != address(0)
            && target != address(0x000000000000000000000000000000000000dEaD)
            && distributeTarget != payable(target)
        );
        require(!distributeTargetFrozen);
        address oldTarget = address(distributeTarget);
        distributeTarget = payable(target);
        emit DistributeTargetSet(oldTarget, distributeTarget);
    }

    function setTreasuryTarget(address target) external onlyOwner {
        require(
            target != address(0)
            && target != address(0x000000000000000000000000000000000000dEaD)
            && treasuryTarget != payable(target)
        );
        require(!treasuryTargetFrozen);
        address oldTarget = address(treasuryTarget);
        treasuryTarget = payable(target);
        emit TreasuryTargetSet(oldTarget, target);
    }

    function freezeTreasuryTarget() external onlyOwner {
        require(!treasuryTargetFrozen);
        treasuryTargetFrozen = true;
        emit TreasuryTargetFrozen();
    }

    function freezeDistributeTarget() external onlyOwner {
        require(!distributeTargetFrozen);
        distributeTargetFrozen = true;
        emit DistributeTargetFrozen();
    }

    function freezeBalanceThreshold() external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThresholdFrozen = true;
        emit BalanceThresholdFrozen();
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    function circulatingSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Router {
    function WETH() external returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface ILiquidityHub {
    function processFees(address) external;
}

interface IX7EcosystemSplitter {
    function takeBalance() external;
}

interface IWETH {
    function withdraw(uint) external;
}

contract X7RLiquidityHub is Ownable, ILiquidityHub {
    IUniswapV2Router public router;
    address public offRampPair;

    IERC20 public x7r;
    address public liquidityTokenReceiver;
    uint256 public minLiquidityRatioTarget = 5;
    uint256 public maxLiquidityRatioTarget = 99;

    uint256 public liquidityRatioTarget = 15;

    uint256 public minShare = 200;
    uint256 public maxShare = 500;

    uint256 public distributeShare = 300;
    uint256 public liquidityShare = 400;
    uint256 public treasuryShare = 300;

    uint256 public balanceThreshold = 1 ether;

    uint256 public distributeBalance;
    uint256 public treasuryBalance;
    uint256 public liquidityBalance;
    uint256 public x7rLiquidityBalance;

    address payable public distributeTarget;
    address payable public treasuryTarget;

    bool public distributeTargetFrozen;
    bool public treasuryTargetFrozen;
    bool public balanceThresholdFrozen;

    event SharesSet(uint256 distributeShare, uint256 liquidityShare, uint256 treasuryShare);
    event OffRampPairSet(address indexed offRampPair);
    event DistributeTargetSet(address indexed oldTarget, address indexed newTarget);
    event TreasuryTargetSet(address indexed oldTarget, address indexed newTarget);
    event LiquidityRatioTargetSet(uint256 liquidityRatioTarget);
    event LiquidityTokenReceiverSet(address indexed oldReciever, address indexed newReceiver);
    event BalanceThresholdSet(uint256 threshold);
    event RouterSet(address router);
    event TreasuryTargetFrozen();
    event DistributeTargetFrozen();
    event BalanceThresholdFrozen();

    constructor(address x7r_, address router_) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        router = IUniswapV2Router(router_);
        x7r = IERC20(x7r_);

        emit RouterSet(router_);
    }

    receive() external payable {}

    function setShares(uint256 distributeShare_, uint256 liquidityShare_, uint256 treasuryShare_) external onlyOwner {
        require(distributeShare + liquidityShare + treasuryShare == 1000);

        require(distributeShare_ >= minShare && distributeShare_ <= maxShare);
        require(liquidityShare_ >= minShare && liquidityShare_ <= maxShare);
        require(treasuryShare_ >= minShare && treasuryShare_ <= maxShare);

        distributeShare = distributeShare_;
        liquidityShare = liquidityShare_;
        treasuryShare = treasuryShare_;

        emit SharesSet(distributeShare_, liquidityShare_, treasuryShare_);
    }

    function setRouter(address router_) external onlyOwner {
        require(router_ != address(router));
        router = IUniswapV2Router(router_);
        emit RouterSet(router_);
    }

    function setOffRampPair(address offRampPairAddress) external onlyOwner {
        require(offRampPair != offRampPairAddress);
        offRampPair = offRampPairAddress;
        emit OffRampPairSet(offRampPairAddress);
    }

    function setBalanceThreshold(uint256 threshold) external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThreshold = threshold;
        emit BalanceThresholdSet(threshold);
    }

    function setLiquidityRatioTarget(uint256 liquidityRatioTarget_) external onlyOwner {
        require(liquidityRatioTarget_ != liquidityRatioTarget);
        require(liquidityRatioTarget_ >= minLiquidityRatioTarget && liquidityRatioTarget <= maxLiquidityRatioTarget);
        liquidityRatioTarget = liquidityRatioTarget_;
        emit LiquidityRatioTargetSet(liquidityRatioTarget_);
    }

    function setLiquidityTokenReceiver(address liquidityTokenReceiver_) external onlyOwner {
        require(
            liquidityTokenReceiver_ != address(0) &&
                liquidityTokenReceiver_ != address(0x000000000000000000000000000000000000dEaD) &&
                liquidityTokenReceiver != liquidityTokenReceiver_
        );

        address oldLiquidityTokenReceiver = liquidityTokenReceiver;
        liquidityTokenReceiver = liquidityTokenReceiver_;
        emit LiquidityTokenReceiverSet(oldLiquidityTokenReceiver, liquidityTokenReceiver_);
    }

    function setDistributionTarget(address target) external onlyOwner {
        require(
            target != address(0) &&
                target != address(0x000000000000000000000000000000000000dEaD) &&
                distributeTarget != payable(target)
        );
        require(!distributeTargetFrozen);
        address oldTarget = address(distributeTarget);
        distributeTarget = payable(target);
        emit DistributeTargetSet(oldTarget, distributeTarget);
    }

    function setTreasuryTarget(address target) external onlyOwner {
        require(
            target != address(0) &&
                target != address(0x000000000000000000000000000000000000dEaD) &&
                treasuryTarget != payable(target)
        );
        require(!treasuryTargetFrozen);
        address oldTarget = address(treasuryTarget);
        treasuryTarget = payable(target);
        emit TreasuryTargetSet(oldTarget, target);
    }

    function freezeTreasuryTarget() external onlyOwner {
        require(!treasuryTargetFrozen);
        treasuryTargetFrozen = true;
        emit TreasuryTargetFrozen();
    }

    function freezeDistributeTarget() external onlyOwner {
        require(!distributeTargetFrozen);
        distributeTargetFrozen = true;
        emit DistributeTargetFrozen();
    }

    function freezeBalanceThreshold() external onlyOwner {
        require(!balanceThresholdFrozen);
        balanceThresholdFrozen = true;
        emit BalanceThresholdFrozen();
    }

    function processFees(address tokenAddress) external {
        require(tokenAddress != address(0), "Invalid token address");
        require(IERC20(tokenAddress).balanceOf(address(this)) > 0, "No tokens to process");

        uint256 startingETHBalance = address(this).balance;

        uint256 tokensToSwap = IERC20(tokenAddress).balanceOf(address(this));

        if (tokenAddress == address(x7r)) {
            tokensToSwap -= x7rLiquidityBalance;
        }

        if (tokensToSwap > 0) {
            swapTokensForEth(tokenAddress, tokensToSwap);
        }

        uint256 ETHForDistribution = address(this).balance - startingETHBalance;

        distributeBalance += (ETHForDistribution * distributeShare) / 1000;
        treasuryBalance += (ETHForDistribution * treasuryShare) / 1000;
        liquidityBalance = address(this).balance - distributeBalance - treasuryBalance;

        if (distributeBalance >= balanceThreshold) {
            sendDistributeBalance();
        }

        if (treasuryBalance >= balanceThreshold) {
            sendTreasuryBalance();
        }

        if (liquidityBalance >= balanceThreshold) {
            buyBackAndAddLiquidity();
        }
    }

    function sendDistributeBalance() public {
        if (distributeTarget == address(0)) {
            return;
        }

        IX7EcosystemSplitter(distributeTarget).takeBalance();

        uint256 ethToSend = distributeBalance;
        distributeBalance = 0;

        (bool success, ) = distributeTarget.call{ value: ethToSend }("");

        if (!success) {
            distributeBalance = ethToSend;
        }
    }

    function sendTreasuryBalance() public {
        if (treasuryTarget == address(0)) {
            return;
        }

        uint256 ethToSend = treasuryBalance;
        treasuryBalance = 0;

        (bool success, ) = treasuryTarget.call{ value: ethToSend }("");

        if (!success) {
            treasuryBalance = ethToSend;
        }
    }

    function buyBackAndAddLiquidity() internal {
        uint256 ethForSwap;
        uint256 startingETHBalance = address(this).balance;

        if (x7r.balanceOf(offRampPair) > (x7r.circulatingSupply() * liquidityRatioTarget) / 100) {
            ethForSwap = liquidityBalance;
            liquidityBalance = 0;
            swapEthForTokens(ethForSwap);
        } else {
            ethForSwap = liquidityBalance;
            liquidityBalance = 0;

            if (x7r.balanceOf(address(this)) > 0) {
                addLiquidityETH(x7r.balanceOf(address(this)), ethForSwap);
                ethForSwap = ethForSwap - (startingETHBalance - address(this).balance);
            }

            if (ethForSwap > 0) {
                uint256 ethLeft = ethForSwap;
                ethForSwap = ethLeft / 2;
                uint256 ethForLiquidity = ethLeft - ethForSwap;
                swapEthForTokens(ethForSwap);
                addLiquidityETH(x7r.balanceOf(address(this)), ethForLiquidity);
            }
        }

        x7rLiquidityBalance = x7r.balanceOf(address(this));
    }

    function addLiquidityETH(uint256 tokenAmount, uint256 ethAmount) internal {
        x7r.approve(address(router), tokenAmount);
        router.addLiquidityETH{ value: ethAmount }(
            address(x7r),
            tokenAmount,
            0,
            0,
            liquidityTokenReceiver,
            block.timestamp
        );
    }

    function swapTokensForEth(address tokenAddress, uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();

        IERC20(tokenAddress).approve(address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function swapEthForTokens(uint256 ethAmount) internal {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(x7r);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: ethAmount }(
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function rescueWETH() external {
        address wethAddress = router.WETH();
        IWETH(wethAddress).withdraw(IERC20(wethAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7TokenBurner.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-17
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for burning tokens, X7TokenBurner

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setRouter(address router_) external onlyOwner {
        router = IUniswapV2Router(router_);
        emit RouterSet(router_);
    }

    function setTargetToken(address targetToken_) external onlyOwner {
        targetToken = targetToken_;
        emit TargetTokenSet(targetToken_);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Router {
    function WETH() external pure returns (address);
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IWETH {
    function withdraw(uint) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract X7TokenBurner is Ownable {
    IUniswapV2Router public router;
    address public targetToken;

    event RouterSet(address indexed routerAddress);
    event TargetTokenSet(address indexed tokenAddress);
    event TokensBurned(address indexed tokenAddress, uint256 ETHAmount);

    constructor(address router_, address targetToken_) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        targetToken = targetToken_;
        router = IUniswapV2Router(router_);
        emit RouterSet(router_);
        emit TargetTokenSet(targetToken_);
    }

    function setRouter(address router_) external onlyOwner {
        require(router_ != address(router));
        router = IUniswapV2Router(router_);
        emit RouterSet(router_);
    }

    function setTargetToken(address targetToken_) external onlyOwner {
        require(targetToken_ != targetToken);
        targetToken = targetToken_;
        emit TargetTokenSet(targetToken_);
    }

    receive() external payable {
        if (targetToken == address(0)) {
            return;
        }

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = targetToken;

        uint256 purchaseAmount = address(this).balance;
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: purchaseAmount }(
            0,
            path,
            address(0x000000000000000000000000000000000000dEaD),
            block.timestamp
        );

        emit TokensBurned(targetToken, purchaseAmount);
    }

    function swapTokensForEth(address tokenAddress, uint256 tokenAmount) internal {
        require(tokenAmount > 0);

        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();

        IERC20(tokenAddress).approve(address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function rescueTokens(address tokenAddress) external {
        swapTokensForEth(tokenAddress, IERC20(tokenAddress).balanceOf(address(this)));
    }

    function rescueWETH() external {
        address wethAddress = router.WETH();
        IWETH(wethAddress).withdraw(IERC20(wethAddress).balanceOf(address(this)));
    }
}


// File: contracts/X7TokenTimeLock.sol
/**
 *Submitted for verification at Etherscan.io on 2022-09-16
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: ERC-20 Token Time Lock

This contract will NOT be renounced.

The X7TokenTimeLock is a general purpose token time lock suitable for holding the Liquidity Provider tokens for all X7 ecosystem uniswap pairs.

There is a global unlock time and token specific unlock times. If a token is locked either by the global lock or the token specific lock, it will be locked.

Withdrawals should be orchestrated by contracts to enable trustless withdrawal in the event of an upgrade.

The following are the only functions that can be called on the contract that affect the contract:

    function setWETH(address weth_) external onlyOwner {
        weth = IWETH(weth_);
    }

    function setGlobalUnlockTimestamp(uint256 unlockTimestamp) external onlyOwner {
        require(unlockTimestamp > globalUnlockTimestamp);
        globalUnlockTimestamp = unlockTimestamp;
        emit GlobalUnlockTimestampSet(unlockTimestamp);
    }

    function extendGlobalUnlockTimestamp(uint256 extendSeconds) external onlyOwner {
        globalUnlockTimestamp += extendSeconds;
        emit GlobalUnlockTimeExtended(extendSeconds, globalUnlockTimestamp);
    }

    function setTokenUnlockTimestamp(address tokenAddress, uint256 unlockTimestamp) external onlyOwner {
        require(unlockTimestamp > tokenUnlockTimestamp[tokenAddress]);
        tokenUnlockTimestamp[tokenAddress] = unlockTimestamp;
        emit TokenUnlockTimestampSet(tokenAddress, unlockTimestamp);
    }

    function extendTokenUnlockTimestamp(address tokenAddress, uint256 extendSeconds) external onlyOwner {
        tokenUnlockTimestamp[tokenAddress] += extendSeconds;
        emit TokenUnlockTimeExtended(tokenAddress, extendSeconds, tokenUnlockTimestamp[tokenAddress]);
    }

    function setTokenOwner(address tokenAddress, address ownerAddress) external onlyOwner {
        require(tokenOwner[tokenAddress] != ownerAddress);
        address oldOwner = tokenOwner[tokenAddress];
        tokenOwner[tokenAddress] = ownerAddress;
        emit TokenOwnerSet(tokenAddress, oldOwner, ownerAddress);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract X7TokenTimeLock is Ownable {
    IWETH weth;

    // The timestamp after which tokens without their own unlock timestamp will unlock
    uint256 public globalUnlockTimestamp;

    // token => unlock timestamp
    mapping(address => uint256) public tokenUnlockTimestamp;

    // The token owner is the only identity permitted to withdraw tokens.
    // The contract owner may SET the token owner, but does not have any
    // ability to withdraw tokens.
    // token address => owner address
    mapping(address => address) public tokenOwner;

    event GlobalUnlockTimestampSet(uint256 unlockTimestamp);
    event GlobalUnlockTimeExtended(uint256 secondsExtended, uint256 newUnlockTimestamp);
    event TokenUnlockTimestampSet(address indexed tokenAddress, uint256 unlockTimestamp);
    event TokenUnlockTimeExtended(address indexed tokenAddress, uint256 secondsExtended, uint256 newUnlockTimestamp);
    event TokenOwnerSet(address indexed tokenAddress, address indexed oldTokenOwner, address indexed newTokenOwner);
    event TokensWithdrawn(address indexed tokenAddress, address indexed recipientAddress, uint256 amount);

    constructor(address weth_) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        weth = IWETH(weth_);
    }

    receive() external payable {
        weth.deposit{ value: msg.value }();
    }

    function setWETH(address weth_) external onlyOwner {
        weth = IWETH(weth_);
    }

    function setGlobalUnlockTimestamp(uint256 unlockTimestamp) external onlyOwner {
        require(unlockTimestamp > globalUnlockTimestamp);
        globalUnlockTimestamp = unlockTimestamp;
        emit GlobalUnlockTimestampSet(unlockTimestamp);
    }

    function extendGlobalUnlockTimestamp(uint256 extendSeconds) external onlyOwner {
        globalUnlockTimestamp += extendSeconds;
        emit GlobalUnlockTimeExtended(extendSeconds, globalUnlockTimestamp);
    }

    function setTokenUnlockTimestamp(address tokenAddress, uint256 unlockTimestamp) external onlyOwner {
        require(unlockTimestamp > tokenUnlockTimestamp[tokenAddress]);
        tokenUnlockTimestamp[tokenAddress] = unlockTimestamp;
        emit TokenUnlockTimestampSet(tokenAddress, unlockTimestamp);
    }

    function extendTokenUnlockTimestamp(address tokenAddress, uint256 extendSeconds) external onlyOwner {
        tokenUnlockTimestamp[tokenAddress] += extendSeconds;
        emit TokenUnlockTimeExtended(tokenAddress, extendSeconds, tokenUnlockTimestamp[tokenAddress]);
    }

    function setTokenOwner(address tokenAddress, address ownerAddress) external onlyOwner {
        require(tokenOwner[tokenAddress] != ownerAddress);
        address oldOwner = tokenOwner[tokenAddress];
        tokenOwner[tokenAddress] = ownerAddress;
        emit TokenOwnerSet(tokenAddress, oldOwner, ownerAddress);
    }

    function getTokenUnlockTimestamp(address tokenAddress) public view returns (uint256) {
        uint256 unlockTimestamp = tokenUnlockTimestamp[tokenAddress];

        if (globalUnlockTimestamp > unlockTimestamp) {
            return globalUnlockTimestamp;
        }

        return unlockTimestamp;
    }

    function withdrawTokens(address tokenAddress, uint256 amount) external {
        require(tokenOwner[tokenAddress] == msg.sender);
        require(block.timestamp >= getTokenUnlockTimestamp(tokenAddress));
        IERC20(tokenAddress).transfer(msg.sender, amount);
        emit TokensWithdrawn(tokenAddress, msg.sender, amount);
    }
}


// File: contracts/X7TreasurySplitterV3.sol
/**
 *Submitted for verification at Etherscan.io on 2023-08-28
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract representing the treasury (v3)

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function freezeOutlet(Outlet outlet) external onlyOwner {
        require(outlet != Outlet.OTHER_SLOT1 && outlet != Outlet.OTHER_SLOT2 && outlet != Outlet.NONE);
        require(!outletFrozen[outlet]);
        outletFrozen[outlet] = true;
        emit OutletFrozen(outlet);
    }

    function setOutletRecipient(Outlet outlet, address recipient) external onlyOwner {
        // Check that outlet is not frozen
        require(!outletFrozen[outlet]);

        // Check that the recipient is not already in use
        require(outletLookup[recipient] == Outlet.NONE);

        address oldRecipient = outletRecipient[outlet];
        outletLookup[recipient] = outlet;
        outletRecipient[outlet] = recipient;

        emit OutletRecipientSet(outlet, oldRecipient, recipient);
    }

    function setSlotShares(uint256 slot1Share, uint256 slot2Share, uint256 rewardPoolShare) external onlyOwner {
        require(slot1Share + slot2Share + rewardPoolShare == 51000);
        divvyUp();

        uint256 oldOtherSlot1Share = outletShare[Outlet.OTHER_SLOT1];
        uint256 oldOtherSlot2Share = outletShare[Outlet.OTHER_SLOT2];
        uint256 oldRewardPoolShare = outletShare[Outlet.REWARD_POOL];
        outletShare[Outlet.OTHER_SLOT1] = slot1Share;
        outletShare[Outlet.OTHER_SLOT2] = slot2Share;
        outletShare[Outlet.REWARD_POOL] = rewardPoolShare;

        emit SharesSet(oldOtherSlot1Share, oldOtherSlot2Share, oldRewardPoolShare, slot1Share, slot2Share, rewardPoolShare);
    }

These functions will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IWETH {
    function withdraw(uint) external;
}

interface IERC20 {
    function transfer(address to, uint value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract X7TreasurySplitterV3 is Ownable {
    enum Outlet {
        NONE,
        PROFITSHARE,
        REWARD_POOL,
        OTHER_SLOT1,
        OTHER_SLOT2
    }

    uint256 public reservedETH;
    address public WETH;

    mapping(Outlet => uint256) public outletBalance;
    mapping(Outlet => address) public outletRecipient;
    mapping(Outlet => uint256) public outletShare;
    mapping(address => Outlet) public outletLookup;
    mapping(Outlet => bool) public outletFrozen;

    event OutletRecipientSet(Outlet indexed outlet, address indexed oldRecipient, address indexed newRecipient);
    event SharesSet(
        uint256 oldOtherSlot1Share,
        uint256 oldOtherSlot2Share,
        uint256 oldRewardPoolShare,
        uint256 newOtherSlot1Share,
        uint256 newOtherSlot2Share,
        uint256 newRewardPoolShare
    );
    event OutletFrozen(Outlet indexed outlet);

    constructor(address weth) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        WETH = weth;

        outletShare[Outlet.PROFITSHARE] = 49000;
        outletShare[Outlet.REWARD_POOL] = 6000;
        outletShare[Outlet.OTHER_SLOT1] = 15000;
        outletShare[Outlet.OTHER_SLOT2] = 30000;

        // Profit Share
        outletRecipient[Outlet.PROFITSHARE] = address(0x0000000000000000000000000000000000000000);

        // Reward Pool
        outletRecipient[Outlet.REWARD_POOL] = address(0x0000000000000000000000000000000000000000);

        // Initial Community Gnosis Wallet
        outletRecipient[Outlet.OTHER_SLOT1] = address(0x0000000000000000000000000000000000000000);

        // Initial Project Gnosis Wallet
        outletRecipient[Outlet.OTHER_SLOT2] = address(0x0000000000000000000000000000000000000000);
    }

    receive() external payable {}

    function divvyUp() public {
        uint256 newETH = address(this).balance - reservedETH;

        if (newETH > 0) {
            outletBalance[Outlet.PROFITSHARE] += (newETH * outletShare[Outlet.PROFITSHARE]) / 100000;
            outletBalance[Outlet.REWARD_POOL] += (newETH * outletShare[Outlet.REWARD_POOL]) / 100000;
            outletBalance[Outlet.OTHER_SLOT1] += (newETH * outletShare[Outlet.OTHER_SLOT1]) / 100000;

            outletBalance[Outlet.OTHER_SLOT2] =
                address(this).balance -
                outletBalance[Outlet.PROFITSHARE] -
                outletBalance[Outlet.OTHER_SLOT1] -
                outletBalance[Outlet.REWARD_POOL];

            reservedETH = address(this).balance;
        }
    }

    function freezeOutlet(Outlet outlet) external onlyOwner {
        require(outlet != Outlet.OTHER_SLOT1 && outlet != Outlet.OTHER_SLOT2 && outlet != Outlet.NONE);
        require(!outletFrozen[outlet]);
        outletFrozen[outlet] = true;
        emit OutletFrozen(outlet);
    }

    function setOutletRecipient(Outlet outlet, address recipient) external onlyOwner {
        // Check that outlet is not frozen
        require(!outletFrozen[outlet]);

        // Check that the recipient is not already in use
        require(outletLookup[recipient] == Outlet.NONE);

        address oldRecipient = outletRecipient[outlet];
        outletLookup[recipient] = outlet;
        outletRecipient[outlet] = recipient;

        emit OutletRecipientSet(outlet, oldRecipient, recipient);
    }

    function setSlotShares(uint256 slot1Share, uint256 slot2Share, uint256 rewardPoolShare) external onlyOwner {
        require(slot1Share + slot2Share + rewardPoolShare == 51000);
        divvyUp();

        uint256 oldOtherSlot1Share = outletShare[Outlet.OTHER_SLOT1];
        uint256 oldOtherSlot2Share = outletShare[Outlet.OTHER_SLOT2];
        uint256 oldRewardPoolShare = outletShare[Outlet.REWARD_POOL];
        outletShare[Outlet.OTHER_SLOT1] = slot1Share;
        outletShare[Outlet.OTHER_SLOT2] = slot2Share;
        outletShare[Outlet.REWARD_POOL] = rewardPoolShare;

        emit SharesSet(
            oldOtherSlot1Share,
            oldOtherSlot2Share,
            oldRewardPoolShare,
            slot1Share,
            slot2Share,
            rewardPoolShare
        );
    }

    function takeBalance() external {
        Outlet outlet = outletLookup[msg.sender];
        require(outlet != Outlet.NONE);
        divvyUp();
        _sendBalance(outlet);
    }

    function takeCurrentBalance() external {
        Outlet outlet = outletLookup[msg.sender];
        require(outlet != Outlet.NONE);
        _sendBalance(outlet);
    }

    function pushAll() public {
        divvyUp();
        _sendBalance(Outlet.PROFITSHARE);
        _sendBalance(Outlet.REWARD_POOL);
        _sendBalance(Outlet.OTHER_SLOT1);
        _sendBalance(Outlet.OTHER_SLOT2);
    }

    function rescueWETH() public {
        IWETH(WETH).withdraw(IERC20(WETH).balanceOf(address(this)));
        pushAll();
    }

    function rescueTokens(address tokenAddress) external {
        if (tokenAddress == WETH) {
            rescueWETH();
        } else {
            IERC20(tokenAddress).transfer(
                outletRecipient[Outlet.OTHER_SLOT2],
                IERC20(tokenAddress).balanceOf(address(this))
            );
        }
    }

    function _sendBalance(Outlet outlet) internal {
        bool success;
        address recipient = outletRecipient[outlet];

        if (recipient == address(0)) {
            return;
        }

        uint256 ethToSend = outletBalance[outlet];

        if (ethToSend > 0) {
            outletBalance[outlet] = 0;
            reservedETH -= ethToSend;

            (success, ) = recipient.call{ value: ethToSend }("");
            if (!success) {
                outletBalance[outlet] += ethToSend;
                reservedETH += ethToSend;
            }
        }
    }
}


// File: contracts/XchangeDiscountAuthority.sol
/**
 *Submitted for verification at Etherscan.io on 2023-01-26
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Smart Contract for Xchange fee discounts

The trading fee discount is 50%. It is represented as the fee amount as a fraction of 100000
This discount is hard coded into this contract.
If it should need to change, a new discount authority contract would be deployed.

This contract will NOT be renounced.

The following are the only functions that can be called on the contract that affect the contract:

    function setDEXMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(dexMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(dexMaxiNFT);
        dexMaxiNFT = IERC721(tokenAddress);
        emit DEXMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

This function will be passed to DAO governance once the ecosystem stabilizes.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
}

interface IXchangeDiscountAuthority {
    function fee(address) external view returns (uint256);
}

contract XchangeDiscountAuthority is Ownable, IXchangeDiscountAuthority {
    IERC721 public dexMaxiNFT;

    event DEXMaxiNFTSet(address indexed oldTokenAddress, address indexed newTokenAddress);

    constructor() Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {}

    function setDEXMaxiNFT(address tokenAddress) external onlyOwner {
        require(address(dexMaxiNFT) != tokenAddress);
        address oldTokenAddress = address(dexMaxiNFT);
        dexMaxiNFT = IERC721(tokenAddress);
        emit DEXMaxiNFTSet(oldTokenAddress, tokenAddress);
    }

    function fee(address swapper) external view returns (uint256 feeAmount) {
        if (dexMaxiNFT.balanceOf(swapper) > 0) {
            feeAmount = 100;
        } else {
            feeAmount = 200;
        }
    }
}


// File: contracts/XchangeFeeOnTransferDetector.sol
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

pragma abicoder v2;

interface IXchangeV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IMulticall {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}

interface IMulticallExtended is IMulticall {
    function multicall(uint256 deadline, bytes[] calldata data) external payable returns (bytes[] memory results);

    function multicall(
        bytes32 previousBlockhash,
        bytes[] calldata data
    ) external payable returns (bytes[] memory results);
}

abstract contract Multicall is IMulticall {
    /// @inheritdoc IMulticall
    function multicall(bytes[] calldata data) public payable override returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }
}

abstract contract BlockTimestamp {
    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}

abstract contract PeripheryValidation is BlockTimestamp {
    modifier checkDeadline(uint256 deadline) {
        require(_blockTimestamp() <= deadline, "Transaction too old");
        _;
    }
}

abstract contract PeripheryValidationExtended is PeripheryValidation {
    modifier checkPreviousBlockhash(bytes32 previousBlockhash) {
        require(blockhash(block.number - 1) == previousBlockhash, "Blockhash");
        _;
    }
}

abstract contract MulticallExtended is IMulticallExtended, Multicall, PeripheryValidationExtended {
    function multicall(
        uint256 deadline,
        bytes[] calldata data
    ) external payable override checkDeadline(deadline) returns (bytes[] memory) {
        return multicall(data);
    }

    function multicall(
        bytes32 previousBlockhash,
        bytes[] calldata data
    ) external payable override checkPreviousBlockhash(previousBlockhash) returns (bytes[] memory) {
        return multicall(data);
    }
}

abstract contract ERC20 {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 internal immutable INITIAL_CHAIN_ID;
    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

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

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
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
}

struct TokenFees {
    uint256 buyFeeBps;
    uint256 sellFeeBps;
}

struct Validate {
    address token;
    address baseToken;
    uint256 amountToBorrow;
    address factory;
    bytes32 initCodeHash;
}

struct BatchValidate {
    address[] tokens;
    address baseToken;
    uint256 amountToBorrow;
    address factory;
    bytes32 initCodeHash;
}

/// @notice Detects the buy and sell fee for a fee-on-transfer token
contract FeeOnTransferDetector {
    error SameToken();
    error PairLookupFailed();

    uint256 public constant BPS = 10_000;

    /// @notice detects FoT fees for a single token
    function validate(Validate memory validateData) public returns (TokenFees memory fotResult) {
        return _validate(validateData);
    }

    /// @notice detects FoT fees for a batch of tokens
    function batchValidate(BatchValidate memory validateData) public returns (TokenFees[] memory fotResults) {
        fotResults = new TokenFees[](validateData.tokens.length);
        for (uint256 i = 0; i < validateData.tokens.length; i++) {
            fotResults[i] = _validate(
                Validate(
                    validateData.tokens[i],
                    validateData.baseToken,
                    validateData.amountToBorrow,
                    validateData.factory,
                    validateData.initCodeHash
                )
            );
        }
    }

    function _validate(Validate memory validateData) internal returns (TokenFees memory result) {
        if (validateData.token == validateData.baseToken) {
            revert SameToken();
        }

        address pairAddress = XchangeV2Library.pairFor(
            validateData.factory,
            validateData.token,
            validateData.baseToken,
            validateData.initCodeHash
        );

        // If the token/baseToken pair exists, get token0.
        // Must do low level call as try/catch does not support case where contract does not exist.
        (, bytes memory returnData) = address(pairAddress).call(abi.encodeWithSelector(IXchangeV2Pair.token0.selector));

        if (returnData.length == 0) {
            revert PairLookupFailed();
        }

        address token0Address = abi.decode(returnData, (address));

        // Flash loan {amountToBorrow}
        (uint256 amount0Out, uint256 amount1Out) = validateData.token == token0Address
            ? (validateData.amountToBorrow, uint256(0))
            : (uint256(0), validateData.amountToBorrow);

        uint256 balanceBeforeLoan = ERC20(validateData.token).balanceOf(address(this));

        IXchangeV2Pair pair = IXchangeV2Pair(pairAddress);

        try
            pair.swap(amount0Out, amount1Out, address(this), abi.encode(balanceBeforeLoan, validateData.amountToBorrow))
        {} catch (bytes memory reason) {
            result = parseRevertReason(reason);
        }
    }

    function parseRevertReason(bytes memory reason) private pure returns (TokenFees memory) {
        if (reason.length != 64) {
            assembly {
                revert(add(32, reason), mload(reason))
            }
        } else {
            return abi.decode(reason, (TokenFees));
        }
    }

    function xchangeV2Call(address, uint256 amount0, uint256, bytes calldata data) external {
        IXchangeV2Pair pair = IXchangeV2Pair(msg.sender);
        (address token0, address token1) = (pair.token0(), pair.token1());

        ERC20 tokenBorrowed = ERC20(amount0 > 0 ? token0 : token1);

        (uint256 balanceBeforeLoan, uint256 amountRequestedToBorrow) = abi.decode(data, (uint256, uint256));
        uint256 amountBorrowed = tokenBorrowed.balanceOf(address(this)) - balanceBeforeLoan;

        uint256 buyFeeBps = ((amountRequestedToBorrow - amountBorrowed) * BPS) / amountRequestedToBorrow;
        balanceBeforeLoan = tokenBorrowed.balanceOf(address(pair));
        uint256 sellFeeBps;
        try tokenBorrowed.transfer(address(pair), amountBorrowed) {
            uint256 sellFee = amountBorrowed - (tokenBorrowed.balanceOf(address(pair)) - balanceBeforeLoan);
            sellFeeBps = (sellFee * BPS) / amountBorrowed;
        } catch (bytes memory) {
            sellFeeBps = buyFeeBps;
        }

        bytes memory fees = abi.encode(TokenFees({ buyFeeBps: buyFeeBps, sellFeeBps: sellFeeBps }));

        // revert with the abi encoded fees
        assembly {
            revert(add(32, fees), mload(fees))
        }
    }
}

library XchangeV2Library {
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB);
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(
        address factory,
        address tokenA,
        address tokenB,
        bytes32 initCodeHash
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex"ff", factory, keccak256(abi.encodePacked(token0, token1)), initCodeHash)
                    )
                )
            )
        );
    }
}


// File: contracts/XchangeRouterV3.sol
/**
 *Submitted for verification at basescan.org on 2024-06-10
 */
// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.25;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Uniswapv2 Fork - XchangeRouterV3

In addition to the standard Uniswap V2 Router, this contract includes functionality to remove liquidity in a failsafe manner to permit liquidation of fee liquidity in all cases.

XchangeRouterV2 contains a bugfix compared to XchangeRouter related to calculations of amount in.

XchangeRouterV3 includes the multicall functionality.

The authority to call that function is assigned via the Xchange Factory.

This contract will NOT be renounced, however it has no functions which affect the contract. The contract is "owned" solely as a formality.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IMulticall {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}

interface IMulticallExtended is IMulticall {
    function multicall(uint256 deadline, bytes[] calldata data) external payable returns (bytes[] memory results);

    function multicall(
        bytes32 previousBlockhash,
        bytes[] calldata data
    ) external payable returns (bytes[] memory results);
}

abstract contract Multicall is IMulticall {
    /// @inheritdoc IMulticall
    function multicall(bytes[] calldata data) public payable override returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }
}

abstract contract BlockTimestamp {
    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}

abstract contract PeripheryValidation is BlockTimestamp {
    modifier checkDeadline(uint256 deadline) {
        require(_blockTimestamp() <= deadline, "Transaction too old");
        _;
    }
}

abstract contract PeripheryValidationExtended is PeripheryValidation {
    modifier checkPreviousBlockhash(bytes32 previousBlockhash) {
        require(blockhash(block.number - 1) == previousBlockhash, "Blockhash");
        _;
    }
}

abstract contract MulticallExtended is IMulticallExtended, Multicall, PeripheryValidationExtended {
    function multicall(
        uint256 deadline,
        bytes[] calldata data
    ) external payable override checkDeadline(deadline) returns (bytes[] memory) {
        return multicall(data);
    }

    function multicall(
        bytes32 previousBlockhash,
        bytes[] calldata data
    ) external payable override checkPreviousBlockhash(previousBlockhash) returns (bytes[] memory) {
        return multicall(data);
    }
}

interface IXchangeFactory {
    function isFailsafeLiquidator(address) external view returns (bool);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IXchangePair {
    function transferFrom(address from, address to, uint value) external returns (bool);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function mustBurn(address to, uint256 gasAmount) external returns (uint256 amount0, uint256 amount1);
}

interface IXchangeRouter {
    function factory() external view returns (address);

    function WETH() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function mustRemoveLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint gasAmount
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IERC20 {
    function balanceOf(address owner) external view returns (uint);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IXchangeDiscountAuthority {
    function fee(address) external view returns (uint256);
}

contract XchangeRouterV3 is IXchangeRouter, Ownable, MulticallExtended {
    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "Xchange: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        require(msg.sender == WETH);
        // only accept ETH via fallback from the WETH contract
    }

    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return XchangeLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual override returns (uint amountOut) {
        return XchangeLibrary.getAmountOut(amountIn, reserveIn, reserveOut, 20);
    }

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual override returns (uint amountIn) {
        return XchangeLibrary.getAmountIn(amountOut, reserveIn, reserveOut, 20);
    }

    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts) {
        return XchangeLibrary.getAmountsOut(factory, amountIn, 20, path);
    }

    function getAmountsIn(
        uint amountOut,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts) {
        return XchangeLibrary.getAmountsIn(factory, amountOut, 20, path);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = XchangeLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IXchangePair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = XchangeLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{ value: amountETH }();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IXchangePair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = XchangeLibrary.pairFor(factory, tokenA, tokenB);
        IXchangePair(pair).transferFrom(msg.sender, pair, liquidity);
        // send liquidity to pair
        (uint amount0, uint amount1) = IXchangePair(pair).burn(to);
        (address token0, ) = XchangeLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "Xchange: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "Xchange: INSUFFICIENT_B_AMOUNT");
    }

    function mustRemoveLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint gasAmount
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        require(IXchangeFactory(factory).isFailsafeLiquidator(msg.sender));
        address pair = XchangeLibrary.pairFor(factory, tokenA, tokenB);

        // send liquidity to pair
        IXchangePair(pair).transferFrom(msg.sender, pair, liquidity);

        // call the modified "mustBurn" function to ensure no token behavior can
        // prevent this call from succeeding
        (uint amount0, uint amount1) = IXchangePair(pair).mustBurn(to, gasAmount);
        (address token0, ) = XchangeLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "Xchange: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "Xchange: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = XchangeLibrary.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? type(uint256).max : liquidity;
        IXchangePair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = XchangeLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? type(uint256).max : liquidity;
        IXchangePair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = XchangeLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? type(uint256).max : liquidity;
        IXchangePair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = XchangeLibrary.getAmountsOut(factory, amountIn, 20, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Xchange: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = XchangeLibrary.getAmountsIn(factory, amountOut, 20, path);
        require(amounts[0] <= amountInMax, "Xchange: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, "Xchange: INVALID_PATH");
        amounts = XchangeLibrary.getAmountsOut(factory, msg.value, 20, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Xchange: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).deposit{ value: amounts[0] }();
        assert(IWETH(WETH).transfer(XchangeLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, "Xchange: INVALID_PATH");
        amounts = XchangeLibrary.getAmountsIn(factory, amountOut, 20, path);
        require(amounts[0] <= amountInMax, "Xchange: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, "Xchange: INVALID_PATH");
        amounts = XchangeLibrary.getAmountsOut(factory, amountIn, 20, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Xchange: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, "Xchange: INVALID_PATH");
        amounts = XchangeLibrary.getAmountsIn(factory, amountOut, 20, path);
        require(amounts[0] <= msg.value, "Xchange: EXCESSIVE_INPUT_AMOUNT");
        IWETH(WETH).deposit{ value: amounts[0] }();
        assert(IWETH(WETH).transfer(XchangeLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "Xchange: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WETH, "Xchange: INVALID_PATH");
        uint amountIn = msg.value;
        IWETH(WETH).deposit{ value: amountIn }();
        assert(IWETH(WETH).transfer(XchangeLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "Xchange: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WETH, "Xchange: INVALID_PATH");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, "Xchange: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IXchangeFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IXchangeFactory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = XchangeLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = XchangeLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Xchange: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = XchangeLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "Xchange: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = XchangeLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? XchangeLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IXchangePair(XchangeLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = XchangeLibrary.sortTokens(input, output);
            IXchangePair pair = IXchangePair(XchangeLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint reserve0, uint reserve1, ) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = XchangeLibrary.getAmountOut(amountInput, reserveInput, reserveOutput, 20);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? XchangeLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
}

library XchangeLibrary {
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "XchangeLibrary: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "XchangeLibrary: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"d75846df8bac2f946ea9ee78caa53b6812e7514197698275b8322d75e1543193" // init code hash
                        )
                    )
                )
            )
        );
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint reserveA, uint reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1, ) = IXchangePair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, "XchangeLibrary: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "XchangeLibrary: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut,
        uint feeAmount
    ) internal pure returns (uint amountOut) {
        require(amountIn > 0, "XchangeLibrary: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "XchangeLibrary: INSUFFICIENT_LIQUIDITY");
        require(feeAmount <= 20, "XchangeLibrary: EXCESSIVE_FEE");
        uint amountInWithFee = amountIn * (10000 - feeAmount);
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut,
        uint feeAmount
    ) internal pure returns (uint amountIn) {
        require(amountOut > 0, "XchangeLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "XchangeLibrary: INSUFFICIENT_LIQUIDITY");
        require(feeAmount <= 20, "XchangeLibrary: EXCESSIVE_FEE");
        uint numerator = reserveIn * amountOut * 10000;
        uint denominator = (reserveOut - amountOut) * (10000 - feeAmount);
        amountIn = (numerator / denominator) + 1;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address factory,
        uint amountIn,
        uint feeAmount,
        address[] memory path
    ) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, "XchangeLibrary: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, feeAmount);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(
        address factory,
        uint amountOut,
        uint feeAmount,
        address[] memory path
    ) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, "XchangeLibrary: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, feeAmount);
        }
    }
}

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FAILED");
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FROM_FAILED");
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success, ) = to.call{ value: value }(new bytes(0));
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }
}


// File: contracts/XchangeRouterWithDiscounts.sol
/**
 *Submitted for verification at Etherscan.io on 2023-09-04
 */

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

/*

 /$$   /$$ /$$$$$$$$       /$$$$$$$$ /$$
| $$  / $$|_____ $$/      | $$_____/|__/
|  $$/ $$/     /$$/       | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
 \  $$$$/     /$$/        | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
  >$$  $$    /$$/         | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
 /$$/\  $$  /$$/          | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
| $$  \ $$ /$$/           | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
|__/  |__/|__/            |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/

Contract: Uniswapv2 Fork - XchangeRouterWithDiscountsV2

This router implements all the familiar Uniswap V2 router swapping functions but checks the discount authority and applies the discount to the swap.
If you will not receive a discount, you can just use the XchangeRouter.

XchangeRouterWithDiscountsV2 contains a bugfix compared to XchangeRouter related to calculations of amount in.

This contract will be trusted by the factory to send accurate discounts to liquidity pairs while swapping.

This contract will NOT be renounced, however it has no functions which affect the contract. The contract is "owned" solely as a formality.

*/

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IXchangeFactory {
    function discountAuthority() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IXchangePair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function swapWithDiscount(
        uint amount0Out,
        uint amount1Out,
        address to,
        uint feeAmountOverride,
        bytes calldata data
    ) external;
}

interface IXchangeRouterWithDiscounts {
    function factory() external view returns (address);

    function WETH() external view returns (address);

    function swapExactTokensForTokensWithDiscount(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokensWithDiscount(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokensWithDiscount(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETHWithDiscount(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETHWithDiscount(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokensWithDiscount(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function getAmountOutWithDiscount(
        uint amountIn,
        uint reserveIn,
        uint reserveOut,
        uint feeAmount
    ) external pure returns (uint amountOut);

    function getAmountInWithDiscount(
        uint amountOut,
        uint reserveIn,
        uint reserveOut,
        uint feeAmount
    ) external pure returns (uint amountIn);

    function getAmountsOutWithDiscount(
        uint amountIn,
        uint feeAmount,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function getAmountsInWithDiscount(
        uint amountOut,
        uint feeAmount,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokensWithDiscount(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokensWithDiscount(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokensWithDiscount(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}

interface IXchangeDiscountAuthority {
    function fee(address) external view returns (uint256);
}

contract XchangeRouterWithDiscountsV2 is IXchangeRouterWithDiscounts, Ownable {
    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "Xchange: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) Ownable(address(0xC71a68467c5e090a61079797E1ED96df7DA69266)) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        require(msg.sender == WETH);
        // only accept ETH via fallback from the WETH contract
    }

    function getAmountsOutWithDiscount(
        uint amountIn,
        uint feeAmount,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts) {
        return XchangeLibrary.getAmountsOut(factory, amountIn, feeAmount, path);
    }

    function getAmountsInWithDiscount(
        uint amountOut,
        uint feeAmount,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts) {
        return XchangeLibrary.getAmountsIn(factory, amountOut, feeAmount, path);
    }

    function swapExactTokensForTokensWithDiscount(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        uint feeAmount = IXchangeDiscountAuthority(IXchangeFactory(factory).discountAuthority()).fee(msg.sender);
        amounts = XchangeLibrary.getAmountsOut(factory, amountIn, feeAmount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Xchange: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swapWithDiscount(amounts, path, to, feeAmount);
    }

    function swapTokensForExactTokensWithDiscount(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        uint feeAmount = IXchangeDiscountAuthority(IXchangeFactory(factory).discountAuthority()).fee(msg.sender);
        amounts = XchangeLibrary.getAmountsIn(factory, amountOut, feeAmount, path);
        require(amounts[0] <= amountInMax, "Xchange: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swapWithDiscount(amounts, path, to, feeAmount);
    }

    function swapExactETHForTokensWithDiscount(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, "Xchange: INVALID_PATH");

        uint feeAmount = IXchangeDiscountAuthority(IXchangeFactory(factory).discountAuthority()).fee(msg.sender);
        amounts = XchangeLibrary.getAmountsOut(factory, msg.value, feeAmount, path);

        require(amounts[amounts.length - 1] >= amountOutMin, "Xchange: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).deposit{ value: amounts[0] }();
        assert(IWETH(WETH).transfer(XchangeLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swapWithDiscount(amounts, path, to, feeAmount);
    }

    function swapTokensForExactETHWithDiscount(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, "Xchange: INVALID_PATH");

        uint feeAmount = IXchangeDiscountAuthority(IXchangeFactory(factory).discountAuthority()).fee(msg.sender);
        amounts = XchangeLibrary.getAmountsIn(factory, amountOut, feeAmount, path);
        require(amounts[0] <= amountInMax, "Xchange: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swapWithDiscount(amounts, path, address(this), feeAmount);
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETHWithDiscount(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, "Xchange: INVALID_PATH");
        uint feeAmount = IXchangeDiscountAuthority(IXchangeFactory(factory).discountAuthority()).fee(msg.sender);
        amounts = XchangeLibrary.getAmountsOut(factory, amountIn, feeAmount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Xchange: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swapWithDiscount(amounts, path, address(this), feeAmount);
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokensWithDiscount(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, "Xchange: INVALID_PATH");
        uint feeAmount = IXchangeDiscountAuthority(IXchangeFactory(factory).discountAuthority()).fee(msg.sender);
        amounts = XchangeLibrary.getAmountsIn(factory, amountOut, feeAmount, path);
        require(amounts[0] <= msg.value, "Xchange: EXCESSIVE_INPUT_AMOUNT");
        IWETH(WETH).deposit{ value: amounts[0] }();
        assert(IWETH(WETH).transfer(XchangeLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swapWithDiscount(amounts, path, to, feeAmount);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokensWithDiscount(
        address[] memory path,
        address _to,
        uint feeAmount
    ) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = XchangeLibrary.sortTokens(input, output);
            IXchangePair pair = IXchangePair(XchangeLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint reserve0, uint reserve1, ) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = XchangeLibrary.getAmountOut(amountInput, reserveInput, reserveOutput, feeAmount);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? XchangeLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swapWithDiscount(amount0Out, amount1Out, to, feeAmount, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokensWithDiscount(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        uint feeAmount = IXchangeDiscountAuthority(IXchangeFactory(factory).discountAuthority()).fee(msg.sender);
        _swapSupportingFeeOnTransferTokensWithDiscount(path, to, feeAmount);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "Xchange: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokensWithDiscount(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WETH, "Xchange: INVALID_PATH");
        uint amountIn = msg.value;
        IWETH(WETH).deposit{ value: amountIn }();
        assert(IWETH(WETH).transfer(XchangeLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        uint feeAmount = IXchangeDiscountAuthority(IXchangeFactory(factory).discountAuthority()).fee(msg.sender);
        _swapSupportingFeeOnTransferTokensWithDiscount(path, to, feeAmount);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "Xchange: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokensWithDiscount(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WETH, "Xchange: INVALID_PATH");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            XchangeLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint feeAmount = IXchangeDiscountAuthority(IXchangeFactory(factory).discountAuthority()).fee(msg.sender);
        _swapSupportingFeeOnTransferTokensWithDiscount(path, address(this), feeAmount);
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, "Xchange: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    function getAmountOutWithDiscount(
        uint amountIn,
        uint reserveIn,
        uint reserveOut,
        uint feeAmount
    ) public pure virtual override returns (uint amountOut) {
        return XchangeLibrary.getAmountOut(amountIn, reserveIn, reserveOut, feeAmount);
    }

    function getAmountInWithDiscount(
        uint amountOut,
        uint reserveIn,
        uint reserveOut,
        uint feeAmount
    ) public pure virtual override returns (uint amountIn) {
        return XchangeLibrary.getAmountIn(amountOut, reserveIn, reserveOut, feeAmount);
    }

    function _swapWithDiscount(
        uint[] memory amounts,
        address[] memory path,
        address _to,
        uint256 feeAmount
    ) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = XchangeLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? XchangeLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IXchangePair(XchangeLibrary.pairFor(factory, input, output)).swapWithDiscount(
                amount0Out,
                amount1Out,
                to,
                feeAmount,
                new bytes(0)
            );
        }
    }
}

library XchangeLibrary {
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "XchangeLibrary: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "XchangeLibrary: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"8ef3e731dfb0265c5b89d4d1ef69c1d448b1335eb48d76cb6df26c198f75bc68" // init code hash
                        )
                    )
                )
            )
        );
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint reserveA, uint reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1, ) = IXchangePair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, "XchangeLibrary: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "XchangeLibrary: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut,
        uint feeAmount
    ) internal pure returns (uint amountOut) {
        require(amountIn > 0, "XchangeLibrary: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "XchangeLibrary: INSUFFICIENT_LIQUIDITY");
        require(feeAmount <= 200, "XchangeLibrary: EXCESSIVE_FEE");
        uint amountInWithFee = amountIn * (100000 - feeAmount);
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 100000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut,
        uint feeAmount
    ) internal pure returns (uint amountIn) {
        require(amountOut > 0, "XchangeLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "XchangeLibrary: INSUFFICIENT_LIQUIDITY");
        require(feeAmount <= 200, "XchangeLibrary: EXCESSIVE_FEE");
        uint numerator = reserveIn * amountOut * 10000;
        uint denominator = (reserveOut - amountOut) * (100000 - feeAmount);
        amountIn = (numerator / denominator) + 1;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address factory,
        uint amountIn,
        uint feeAmount,
        address[] memory path
    ) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, "XchangeLibrary: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, feeAmount);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(
        address factory,
        uint amountOut,
        uint feeAmount,
        address[] memory path
    ) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, "XchangeLibrary: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, feeAmount);
        }
    }
}

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FAILED");
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FROM_FAILED");
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success, ) = to.call{ value: value }(new bytes(0));
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }
}


// File: contracts/XchangeTokenList.sol
/**
 *Submitted for verification at basescan.org on 2024-04-07
 */

// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract XchangeTokenList {
    address public treasury;
    uint256 public fee;
    address public owner;

    mapping(address => bool) public registeredTokens;
    address[] public registeredTokenList;

    event TokenAdded(address indexed tokenAddress, address indexed addedBy);
    event FeeAmended(uint256 newFee, address indexed amendedBy);
    event OwnerChanged(address indexed newOwner, address indexed changedBy);
    event TokenRemoved(address indexed tokenAddress, address indexed removedBy);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address _treasury, uint256 _initialFee, address[] memory _initialTokens) {
        treasury = _treasury;
        fee = _initialFee;
        owner = msg.sender;

        initializeDefaultTokens(_initialTokens);
    }

    function initializeDefaultTokens(address[] memory _initialTokens) internal {
        require(_initialTokens.length > 0, "Mismatched array lengths");

        for (uint256 i = 0; i < _initialTokens.length; i++) {
            address token = _initialTokens[i];

            registeredTokens[token] = true;
            registeredTokenList.push(token);
            emit TokenAdded(token, msg.sender);
        }
    }

    function addToken(address _tokenAddress, address _pairedAddress, address _factoryAddress) external payable {
        require(!registeredTokens[_tokenAddress], "Token already registered");

        // Check if the token has a liquidity pair on a dex
        require(pairExists(_tokenAddress, _pairedAddress, _factoryAddress), "Token has no liquidity pair on a dex");

        if (fee > 0) {
            require(msg.value == fee, "Incorrect fee sent");
            payable(treasury).transfer(msg.value);
        }

        registeredTokens[_tokenAddress] = true;
        registeredTokenList.push(_tokenAddress);
        emit TokenAdded(_tokenAddress, msg.sender);
    }

    function amendFee(uint256 _newFee) external onlyOwner {
        fee = _newFee;
        emit FeeAmended(_newFee, msg.sender);
    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner address");
        owner = _newOwner;
        emit OwnerChanged(_newOwner, msg.sender);
    }

    function getRegisteredTokens() external view returns (address[] memory) {
        return registeredTokenList;
    }

    function pairExists(
        address _tokenAddress,
        address _pairedAddress,
        address _factoryAddress
    ) internal view returns (bool) {
        address pair = IFactory(_factoryAddress).getPair(_tokenAddress, _pairedAddress);
        return pair != address(0);
    }

    function removeToken(address _tokenAddress) external onlyOwner {
        require(registeredTokens[_tokenAddress], "Token not registered");

        for (uint256 i = 0; i < registeredTokenList.length; i++) {
            if (registeredTokenList[i] == _tokenAddress) {
                registeredTokenList[i] = registeredTokenList[registeredTokenList.length - 1];
                registeredTokenList.pop();
                break;
            }
        }

        delete registeredTokens[_tokenAddress];

        emit TokenRemoved(_tokenAddress, msg.sender);
    }
}


