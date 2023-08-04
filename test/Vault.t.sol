pragma solidity 0.8.13;

import "./BaseTest.sol";
import {VaultFactory, Vault} from "contracts/factories/VaultFactory.sol";
import "contracts/interfaces/INonfungiblePositionManager.sol";

contract VaultTest is BaseTest {
    VaultFactory vaultFactory;
    Vault vault;

    GaugeFactory gaugeFactory;
    Gauge gauge;
    TestVotingEscrow escrow;
    TestVoter voter;

    INonfungiblePositionManager constant positionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    uint256 constant positionId = 539325;

    address positionOwner;
    address token0;
    address token1;
    int24 lowerTick;
    int24 upperTick;
    uint24 fee;
    address posOwner;

    function setUp() public {
        deployOwners();

        // fork mainnet
        vm.createSelectFork("https://eth.llamarpc.com", 17_777_800);

        // fetch target position's tick range and fee
        (, , token0, token1, fee, lowerTick, upperTick, , , , , ) = positionManager.positions(positionId);
        positionOwner = positionManager.ownerOf(positionId);

        vaultFactory = new VaultFactory();
        vault = vaultFactory.createVault(token0, token1, lowerTick, upperTick, fee);

        escrow = new TestVotingEscrow(address(VARA));
        voter = new TestVoter();
        gaugeFactory = new GaugeFactory();
        address[] memory allowedRewards = new address[](1);
        vm.prank(address(voter));
        gaugeFactory.createGauge(address(vault), address(owner), address(owner), address(escrow), true, allowedRewards);
        address gaugeAddr = gaugeFactory.last_gauge();
        gauge = Gauge(gaugeAddr);

        vault.setGauge(address(gauge));
    }

    function testVaultDepositFirstWithSameRange() public {
        // first deposit to vault with same tick range and fee value
        vm.startPrank(positionOwner);
        positionManager.setApprovalForAll(address(vault), true);
        vault.deposit(positionId);
        vm.stopPrank();
        assertEq(vault.positionId(), positionId);
        assertEq(positionManager.ownerOf(positionId), address(vault));
    }

    function testVaultDepositFirstWithDifferentRange() public {
        // first deposit to vault with different tick range or fee value
        uint256 diffPosId = 542101;
        posOwner = positionManager.ownerOf(diffPosId);
        vm.startPrank(posOwner);
        positionManager.setApprovalForAll(address(vault), true);
        vault.deposit(diffPosId);
        vm.stopPrank();
        assertEq(positionManager.balanceOf(address(vault)), 1);
        (
            ,
            ,
            address token0_,
            address token1_,
            uint24 fee_,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,

        ) = positionManager.positions(vault.positionId());
        assertEq(token0, token0_);
        assertEq(token1, token1_);
        assertEq(fee, fee_);
        assertEq(lowerTick, tickLower);
        assertEq(upperTick, tickUpper);
    }

    function testVaultDepositSecondWithDifferentRange() public {
        // second deposit to vault with different tick range or fee value
        testVaultDepositFirstWithSameRange();
        (, , , , , , , uint128 liquidity, , , , ) = positionManager.positions(positionId);
        uint256 otherPosId = 350456;
        address otherOwner = positionManager.ownerOf(otherPosId);
        vm.startPrank(otherOwner);
        positionManager.setApprovalForAll(address(vault), true);
        vault.deposit(otherPosId);
        vm.stopPrank();
        assertEq(vault.positionId(), positionId);
        (, , , , , , , uint128 liquidityNew, , , , ) = positionManager.positions(positionId);
        assertGt(liquidityNew, liquidity);
    }

    function testVaultWithdraw() public {
        // withdraw tokens
        testVaultDepositFirstWithDifferentRange();
        assertGt(vault.balanceOf(posOwner), 0);
        uint256 prev0Bal = IERC20(token0).balanceOf(posOwner);
        uint256 prev1Bal = IERC20(token1).balanceOf(posOwner);
        vm.startPrank(posOwner);
        vault.withdraw(vault.balanceOf(posOwner) / 2);
        vm.stopPrank();
        assertGt(IERC20(token0).balanceOf(posOwner), prev0Bal);
        assertGt(IERC20(token1).balanceOf(posOwner), prev1Bal);
    }
}
