// 1:1 with Hardhat test
pragma solidity 0.8.13;

import './BaseTest.sol';

contract StakingTest is BaseTest {
    GaugeFactory gaugeFactory;
    Gauge gauge;
    TestStakingRewards staking;
    TestVotingEscrow escrow;
    TestVoter voter;

    function deployBaseCoins() public {
        deployProxyAdmin();
        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1e27;
        amounts[1] = 1e27;
        amounts[2] = 1e27;
        mintVara(owners, amounts);
        mintLR(owners, amounts);
        mintStake(owners, amounts);
        escrow = new TestVotingEscrow(address(VARA));
        voter = new TestVoter();
    }

    function createLock() public {
        deployBaseCoins();

        VARA.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, 4 * 365 * 86400);
    }

    function createLock2() public {
        createLock();

        owner2.approve(address(VARA), address(escrow), TOKEN_1);
        owner2.create_lock(address(escrow), TOKEN_1, 4 * 365 * 86400);
    }

    function createLock3() public {
        createLock2();

        owner3.approve(address(VARA), address(escrow), TOKEN_1);
        owner3.create_lock(address(escrow), TOKEN_1, 4 * 365 * 86400);
    }

    function deployFactory() public {
        createLock3();

        Gauge implGauge = new Gauge();
        GaugeFactory implGaugeFactory = new GaugeFactory();
        proxy = new TransparentUpgradeableProxy(address(implGaugeFactory), address(admin), abi.encodeWithSelector(GaugeFactory.initialize.selector, address(implGauge)));
        gaugeFactory = GaugeFactory(address(proxy));

        address[] memory allowedRewards = new address[](1);
        vm.prank(address(voter));
        gaugeFactory.createGauge(address(stake), address(owner), address(owner), address(escrow), false, allowedRewards);
        address gaugeAddr = gaugeFactory.last_gauge();
        gauge = Gauge(gaugeAddr);

        staking = new TestStakingRewards(address(stake), address(VARA));
    }

    function depositEmpty() public {
        deployFactory();

        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);

        assertEq(gauge.earned(address(VARA), address(owner)), staking.earned(address(owner)));
    }

    function depositEmpty2() public {
        depositEmpty();

        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);

        assertEq(gauge.earned(address(VARA), address(owner2)), staking.earned(address(owner2)));
    }

    function depositEmpty3() public {
        depositEmpty2();

        owner3.approve(address(stake), address(staking), 1e21);
        owner3.approve(address(stake), address(gauge), 1e21);
        owner3.stakeStake(address(staking), 1e21);
        owner3.deposit(address(gauge), 1e21, 3);

        assertEq(gauge.earned(address(VARA), address(owner3)), staking.earned(address(owner3)));
    }

    function notifyRewardsAndCompare() public {
        depositEmpty3();

        VARA.approve(address(staking), TOKEN_1M);
        VARA.approve(address(gauge), TOKEN_1M);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        staking.notifyRewardAmount(TOKEN_1M);
        gauge.notifyRewardAmount(address(VARA), TOKEN_1M);
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        VARA.approve(address(staking), TOKEN_1M);
        VARA.approve(address(gauge), TOKEN_1M);
        staking.notifyRewardAmount(TOKEN_1M);
        gauge.notifyRewardAmount(address(VARA), TOKEN_1M);
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
    }

    function notifyReward2AndCompare() public {
        notifyRewardsAndCompare();

        LR.approve(address(gauge), TOKEN_1M);
        gauge.notifyRewardAmount(address(LR), TOKEN_1M);
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
        LR.approve(address(gauge), TOKEN_1M);
        gauge.notifyRewardAmount(address(LR), TOKEN_1M);
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
    }

    function notifyRewardsAndCompareOwner1() public {
        notifyReward2AndCompare();
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        vm.warp(block.timestamp + 604800);
        vm.roll(block.number + 1);
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
    }

    function notifyRewardsAndCompareOwner2() public {
        notifyRewardsAndCompareOwner1();

        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
    }

    function notifyRewardsAndCompareOwner3() public {
        notifyRewardsAndCompareOwner2();

        owner3.withdrawStake(address(staking), 1e21);
        owner3.withdrawGauge(address(gauge), 1e21);
        owner3.approve(address(stake), address(staking), 1e21);
        owner3.approve(address(stake), address(gauge), 1e21);
        owner3.stakeStake(address(staking), 1e21);
        owner3.deposit(address(gauge), 1e21, 3);
        owner3.withdrawStake(address(staking), 1e21);
        owner3.withdrawGauge(address(gauge), 1e21);
        owner3.approve(address(stake), address(staking), 1e21);
        owner3.approve(address(stake), address(gauge), 1e21);
        owner3.stakeStake(address(staking), 1e21);
        owner3.deposit(address(gauge), 1e21, 3);
        owner3.withdrawStake(address(staking), 1e21);
        owner3.withdrawGauge(address(gauge), 1e21);
        owner3.approve(address(stake), address(staking), 1e21);
        owner3.approve(address(stake), address(gauge), 1e21);
        owner3.stakeStake(address(staking), 1e21);
        owner3.deposit(address(gauge), 1e21, 3);
        owner3.withdrawStake(address(staking), 1e21);
        owner3.withdrawGauge(address(gauge), 1e21);
        owner3.approve(address(stake), address(staking), 1e21);
        owner3.approve(address(stake), address(gauge), 1e21);
        owner3.stakeStake(address(staking), 1e21);
        owner3.deposit(address(gauge), 1e21, 3);
        owner3.withdrawStake(address(staking), 1e21);
        owner3.withdrawGauge(address(gauge), 1e21);
        owner3.approve(address(stake), address(staking), 1e21);
        owner3.approve(address(stake), address(gauge), 1e21);
        owner3.stakeStake(address(staking), 1e21);
        owner3.deposit(address(gauge), 1e21, 3);
        owner3.withdrawStake(address(staking), 1e21);
        owner3.withdrawGauge(address(gauge), 1e21);
        owner3.approve(address(stake), address(staking), 1e21);
        owner3.approve(address(stake), address(gauge), 1e21);
        owner3.stakeStake(address(staking), 1e21);
        owner3.deposit(address(gauge), 1e21, 3);
    }

    function depositAndWithdrawWithoutRewards() public {
        notifyRewardsAndCompareOwner3();

        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        vm.warp(block.timestamp + 604800);
        vm.roll(block.number + 1);
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
    }

    function notifyRewardsAndCompareSet2() public {
        depositAndWithdrawWithoutRewards();

        VARA.approve(address(staking), TOKEN_1M);
        VARA.approve(address(gauge), TOKEN_1M);
        staking.notifyRewardAmount(TOKEN_1M);
        gauge.notifyRewardAmount(address(VARA), TOKEN_1M);
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        VARA.approve(address(staking), TOKEN_1M);
        VARA.approve(address(gauge), TOKEN_1M);
        staking.notifyRewardAmount(TOKEN_1M);
        gauge.notifyRewardAmount(address(VARA), TOKEN_1M);
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        assertEq(gauge.derivedSupply(), staking.totalSupply());
    }

    function notifyReward2AndCompareSet2() public {
        notifyRewardsAndCompareSet2();

        LR.approve(address(gauge), TOKEN_1M);
        gauge.notifyRewardAmount(address(LR), TOKEN_1M);
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
        LR.approve(address(gauge), TOKEN_1M);
        gauge.notifyRewardAmount(address(LR), TOKEN_1M);
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
    }

    function notifyRewardsAndCompareOwner1Again() public {
        notifyReward2AndCompareSet2();

        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        // uint256 sb = VARA.balanceOf(address(owner));
        staking.getReward();
        // uint256 sa = VARA.balanceOf(address(owner));
        // uint256 gb = VARA.balanceOf(address(owner));
        address[] memory tokens = new address[](1);
        tokens[0] = address(VARA);
        gauge.getReward(address(owner), tokens);
        // uint256 ga = VARA.balanceOf(address(owner));
        vm.warp(block.timestamp + 604800);
        vm.roll(block.number + 1);
        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(VARA), 200);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        assertGt(staking.rewardPerTokenStored(), 1330355346300364281191);
    }

    function notifyRewardsAndCompareOwner2Again() public {
        notifyRewardsAndCompareOwner1Again();

        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        vm.warp(block.timestamp + 1800);
        vm.roll(block.number + 1);
        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        owner2.getStakeReward(address(staking));
        address[] memory tokens = new address[](1);
        tokens[0] = address(VARA);
        owner2.getGaugeReward(address(gauge), address(owner2), tokens);
        vm.warp(block.timestamp + 604800);
        vm.roll(block.number + 1);
        owner2.withdrawStake(address(staking), 1e21);
        owner2.withdrawGauge(address(gauge), 1e21);
        owner2.approve(address(stake), address(staking), 1e21);
        owner2.approve(address(stake), address(gauge), 1e21);
        owner2.stakeStake(address(staking), 1e21);
        owner2.deposit(address(gauge), 1e21, 2);
        assertEq(staking.rewardPerTokenStored(), gauge.rewardPerTokenStored(address(VARA)));
        assertGt(staking.rewardPerTokenStored(), 1330355346300364281191);
    }

    function testClaimReward2Owner1() public {
        notifyRewardsAndCompareOwner2Again();

        staking.withdraw(1e21);
        gauge.withdraw(1e21);
        stake.approve(address(staking), 1e21);
        stake.approve(address(gauge), 1e21);
        staking.stake(1e21);
        gauge.deposit(1e21, 1);
        gauge.batchRewardPerToken(address(LR), 200);
        uint256 assertEqed1 = gauge.earned(address(LR), address(owner));

        uint256 before = LR.balanceOf(address(owner));

        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);
        gauge.getReward(address(owner), rewards);
        uint256 after_ = LR.balanceOf(address(owner));

        assertEq(after_ - before, assertEqed1);
        assertGt(assertEqed1, 0);
    }
}
