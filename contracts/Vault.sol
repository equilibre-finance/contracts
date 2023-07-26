// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "contracts/interfaces/INonfungiblePositionManager.sol";
import "contracts/interfaces/IGauge.sol";
import "contracts/interfaces/IFeeVault.sol";

// Vaults are used as a intermediate contract between gauges and uniswap v3 pools
contract Vault is IFeeVault, IERC721Receiver, ERC20("Equilibre Vaults", "EQV") {
    using SafeERC20 for IERC20;

    // Uniswap V3 Nonfungible Position Manager
    INonfungiblePositionManager private constant positionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address public token0;
    address public token1;
    int24 public lowerTick;
    int24 public upperTick;
    uint24 public fee;
    uint256 public positionId;
    address public gauge;

    constructor(address _token0, address _token1, int24 _tick0, int24 _tick1, uint24 _fee) {
        token0 = _token0;
        token1 = _token1;
        lowerTick = _tick0;
        upperTick = _tick1;
        fee = _fee;
    }

    function claimFees() public override returns (uint256 claimed0, uint256 claimed1) {
        require(gauge != address(0), "gauge not set");
        require(msg.sender == gauge, "caller is not gauge");

        if (positionId > 0) {
            INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams(
                positionId,
                msg.sender,
                type(uint128).max,
                type(uint128).max
            );
            (claimed0, claimed1) = positionManager.collect(params);
        }
    }

    function deposit(uint256 posId) public {
        require(posId > 0, "zero position id");

        (
            ,
            ,
            address token0_,
            address token1_,
            uint24 fee_,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = positionManager.positions(posId);
        require(token0_ == token0 && token1_ == token1, "incorrect tokens");

        if (positionId > 0 || tickLower != lowerTick || tickUpper != upperTick || fee_ != fee) {
            // if different tick range remove liquidity (burn position) and add liquidity (mint new position) again
            INonfungiblePositionManager.DecreaseLiquidityParams memory decParams = INonfungiblePositionManager
                .DecreaseLiquidityParams(posId, liquidity, 0, 0, block.timestamp);
            (uint256 amount0, uint256 amount1) = positionManager.decreaseLiquidity(decParams);
            INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams(
                posId,
                address(this),
                type(uint128).max,
                type(uint128).max
            );
            positionManager.collect(params);

            IERC20(token0_).approve(address(positionManager), amount0);
            IERC20(token1_).approve(address(positionManager), amount1);

            if (positionId > 0) {
                INonfungiblePositionManager.IncreaseLiquidityParams memory incParams = INonfungiblePositionManager
                    .IncreaseLiquidityParams(positionId, amount0, amount1, 0, 0, block.timestamp);
                (liquidity, , ) = positionManager.increaseLiquidity(incParams);
            } else {
                INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams(
                    token0,
                    token1,
                    fee,
                    lowerTick,
                    upperTick,
                    amount0,
                    amount1,
                    0,
                    0,
                    address(this),
                    block.timestamp
                );
                (positionId, , , ) = positionManager.mint(mintParams);
            }
        } else {
            positionManager.safeTransferFrom(msg.sender, address(this), posId);
            positionId = posId;
        }

        _mint(msg.sender, liquidity);
    }

    function withdraw(uint256 amount) public {
        (, , , , , , , uint128 liquidity, , , , ) = positionManager.positions(positionId);
        uint128 amountToWithdraw = uint128((amount * uint256(liquidity)) / totalSupply());

        INonfungiblePositionManager.DecreaseLiquidityParams memory decParams = INonfungiblePositionManager
            .DecreaseLiquidityParams(positionId, uint128(amountToWithdraw), 0, 0, block.timestamp);
        positionManager.decreaseLiquidity(decParams);
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams(
            positionId,
            msg.sender,
            type(uint128).max,
            type(uint128).max
        );
        positionManager.collect(params);
        _burn(msg.sender, amount);
    }

    function tokens() external view override returns (address, address) {
        return (token0, token1);
    }

    function setGauge(address _gauge) public {
        require(_gauge != address(0), "gauge 0x0");
        gauge = _gauge;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
