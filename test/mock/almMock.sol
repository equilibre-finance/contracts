// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "contracts/interfaces/IEquilibrePool.sol";
import "contracts/libraries/TickMath.sol";
import "contracts/libraries/FullMath.sol";
import "contracts/libraries/LiquidityAmounts.sol";
import "contracts/libraries/SqrtPrice.sol";
import {Strings as STR} from "@openzeppelin/contracts/utils/Strings.sol";
import {Constants} from "contracts/Constants.sol";
import {INonfungiblePositionManager as NPM} from 'contracts/interfaces/INonfungiblePositionManager.sol';

contract almMock is ERC20, Ownable, Constants {
    using STR for uint256;
    IEquilibrePool public pool;
    IERC20 public token0;
    address public token0Address;
    IERC20 public token1;
    address public token1Address;
    NPM public pm;
    uint public tokenId;
    int24 public tickLower;
    int24 public tickUpper;
    address public gauge;
    address public gaugeFactoryAddress;
    uint256 constant PRECISION = 1e18;

    //NOTE: emulates shares balances for testing purposes only:
    mapping(address => uint) public liquidityByAddress;

    constructor(
        address _pool,
        NPM _pm,
        string memory _symbol,
        address _gaugeFactory
    )

    ERC20(_symbol, _symbol)
    {
        pool = IEquilibrePool(_pool);
        token0Address = pool.token0();
        token1Address = pool.token1();
        token0 = IERC20(token0Address);
        token1 = IERC20(token1Address);
        pm = _pm;
        int24 tickSpacing = pool.tickSpacing();
        tickLower = (int24(TickMath.MIN_TICK) / tickSpacing) * tickSpacing;
        tickUpper = (int24(TickMath.MAX_TICK) / tickSpacing) * tickSpacing;
        gaugeFactoryAddress = _gaugeFactory;
    }

    function deposit(uint256 amount0, uint256 amount1) public returns (uint256 shares) {
        return deposit(token0, token1, amount0, amount1);
    }

    function sharesAmount(uint amount) external pure returns (uint256){
        /// @dev this is not accurate, but it's ok for testing purposes.
        /// @dev right now we are using the same amount for both tokens.
        // TODO: ask ALM team to a way to compute shares amount.
        return getShareValueByDeposit(amount, amount);
    }

    function deposit(IERC20 tokenA, IERC20 tokenB, uint256 amount0, uint256 amount1) public returns (uint256 shares) {
        // check allowance
        require(tokenA.allowance(msg.sender, address(this)) >= amount0, "ALM: allowance not enough");
        require(tokenB.allowance(msg.sender, address(this)) >= amount1, "ALM: allowance not enough");
        // check balances:
        require(tokenA.balanceOf(msg.sender) >= amount0, "ALM: balance 1 not enough");
        require(tokenB.balanceOf(msg.sender) >= amount1, "ALM: balance 2 not enough");
        tokenA.transferFrom(msg.sender, address(this), amount0);
        tokenB.transferFrom(msg.sender, address(this), amount1);
        tokenA.approve(address(pm), amount0);
        tokenB.approve(address(pm), amount1);
        uint liquidity;
        if (tokenId == 0) {
            liquidity = initialize(amount0, amount1);
        } else {
            liquidity = increaseLiquidity(amount0, amount1);
        }
        shares = getShareValueByDeposit(amount0, amount1);
        require(liquidity > 0, "ALM: liquidity is 0");
        require(shares > 0, "ALM: shares is 0");
        _mint(msg.sender, shares);

        //NOTE: emulates shares balances for testing purposes only:
        liquidityByAddress[msg.sender] += liquidity;

        // send any token left:
        if (tokenA.balanceOf(address(this)) > 0) {
            tokenA.transfer(msg.sender, tokenA.balanceOf(address(this)));
        }
        if (tokenB.balanceOf(address(this)) > 0) {
            tokenB.transfer(msg.sender, tokenB.balanceOf(address(this)));
        }

    }

    function withdraw() public returns (uint256 amount0, uint256 amount1) {

        //NOTE: this is not accurate, but it's ok for testing purposes
        uint128 liquidity = uint128( liquidityByAddress[msg.sender] );
        liquidityByAddress[msg.sender] = 0;
        require(liquidity > 0, "ALM: liquidity is 0");
        (amount0, amount1) = pm.decreaseLiquidity(
            NPM.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        require(amount0 > 0 && amount1 > 0, "ALM: an amounts is 0");
        _burn(msg.sender, balanceOf(msg.sender) );
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
    }

    function initialize(uint amount0, uint amount1) internal returns (uint256 liquidity) {
        uint160 sqrtPriceX96 = getSqrtPriceX96(amount0, amount1);
        pm.createAndInitializePoolIfNecessary(token0Address, token1Address, sqrtPriceX96);
        (tokenId, liquidity,,) = pm.mint(
            NPM.MintParams({
                token0: token0Address,
                token1: token1Address,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
        require(tokenId > 0, "tokenId not set");
        require(liquidity > 0, "ALM: liquidity is 0");
    }

    function increaseLiquidity(uint256 amount0, uint256 amount1) internal returns (uint256 liquidity) {
        require(tokenId > 0, "tokenId not set");
        (liquidity,,) = pm.increaseLiquidity(
            NPM.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        require(liquidity > 0, "ALM: liquidity is 0");
    }

    function getPriceFromSqrtPrice(uint256 sqrtPrice) internal pure returns (uint256 price) {
        price = (sqrtPrice * PRECISION) / (2 ** 96);
        price = (price * sqrtPrice) / (2 ** 96);
        return price;
    }
    function getShareValueByDeposit(uint256 amount0, uint256 amount1) public pure returns (uint256 shares) {
        uint160 sqrtPrice = getSqrtPriceX96(amount0, amount1);
        uint256 price = getPriceFromSqrtPrice(sqrtPrice);
        shares = amount1 + (amount0 * price) / 1e18;
    }
    function setGauge(address _gauge) public {
        require(gauge == address(0), "AE0");
        require(gaugeFactoryAddress == msg.sender, "AE3");
        gauge = _gauge;
    }

    function claimFees() public returns (uint256 claimed0, uint256 claimed1) {
        require(gauge != address(0), "Acf1");
        require(msg.sender == gauge, "Acf2");
        if (tokenId == 0)
            return (0, 0);
        NPM.CollectParams memory params = NPM.CollectParams(
            tokenId,
            msg.sender,
            type(uint128).max,
            type(uint128).max
        );
        //AUDIT: we are collecting all fees for this almMock.sol and sending them to the gauge.
        (claimed0, claimed1) = pm.collect(params);
    }
}
