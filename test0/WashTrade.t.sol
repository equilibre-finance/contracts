// 1:1 with Hardhat test
pragma solidity 0.8.13;

import "../test/BaseTest.sol";

contract WashTradeTest is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    Gauge gauge3;
    InternalBribe bribe3;
    uint initialBalanceUSDC;
    uint initialBalanceFRAX;
    function deployBaseCoins() public {
        vm.warp(block.timestamp + 1 weeks); // put some initial time in

        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e25;
        mintVara(owners, amounts);

        VeArtProxy artProxy = new VeArtProxy();
        escrow = new VotingEscrow(address(VARA), address(artProxy));
    }

    function createLock() public {
        deployBaseCoins();

        VARA.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, 4 * 365 * 86400);
        vm.roll(block.number + 1); // fwd 1 block because escrow.balanceOfNFT() returns 0 in same block
        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(VARA.balanceOf(address(escrow)), TOKEN_1);
    }

    function votingEscrowMerge() public {
        createLock();

        VARA.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, 4 * 365 * 86400);
        vm.roll(block.number + 1);
        assertGt(escrow.balanceOfNFT(2), 995063075414519385);
        assertEq(VARA.balanceOf(address(escrow)), 2 * TOKEN_1);
        escrow.merge(2, 1);
        assertGt(escrow.balanceOfNFT(1), 1990039602248405587);
        assertEq(escrow.balanceOfNFT(2), 0);
    }

    function confirmTokensForFraxUsdc() public {
        votingEscrowMerge();
        deployPairFactoryAndRouter();
        deployPairWithOwner(address(owner));

        (address token0, address token1) = router.sortTokens(address(USDC), address(FRAX));
        assertEq(pair.token0(), token0);
        assertEq(pair.token1(), token1);
    }

    function mintAndBurnTokensForPairFraxUsdc() public {
        confirmTokensForFraxUsdc();

        USDC.transfer(address(pair), USDC_1);
        FRAX.transfer(address(pair), TOKEN_1);
        pair.mint(address(owner));
        assertEq(pair.getAmountOut(USDC_1, address(USDC)), 945128557522723966);
    }

    function routerAddLiquidity() public {
        mintAndBurnTokensForPairFraxUsdc();

        USDC.approve(address(router), USDC_100K);
        FRAX.approve(address(router), TOKEN_100K);
        router.addLiquidity(address(FRAX), address(USDC), true, TOKEN_100K, USDC_100K, TOKEN_100K, USDC_100K, address(owner), block.timestamp);
        USDC.approve(address(router), USDC_100K);
        FRAX.approve(address(router), TOKEN_100K);
        router.addLiquidity(address(FRAX), address(USDC), false, TOKEN_100K, USDC_100K, TOKEN_100K, USDC_100K, address(owner), block.timestamp);
        DAI.approve(address(router), TOKEN_100M);
        FRAX.approve(address(router), TOKEN_100M);
        router.addLiquidity(address(FRAX), address(DAI), true, TOKEN_100M, TOKEN_100M, 0, 0, address(owner), block.timestamp);
    }

    function deployVoter() public {
        routerAddLiquidity();

        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();
        voter = new Voter(address(escrow), address(factory), address(gaugeFactory), address(bribeFactory));
        address[] memory tokens = new address[](4);
        tokens[0] = address(USDC);
        tokens[1] = address(FRAX);
        tokens[2] = address(DAI);
        tokens[3] = address(VARA);
        voter.initialize(tokens, address(owner));

        assertEq(voter.length(), 0);
    }

    function deployPairFactoryGauge() public {
        deployVoter();

        VARA.approve(address(gaugeFactory), 5 * TOKEN_100K);
        voter.createGauge(address(pair));
        assertFalse(voter.gauges(address(pair)) == address(0));

        address gaugeAddr3 = voter.gauges(address(pair));
        address bribeAddr3 = voter.internal_bribes(gaugeAddr3);

        gauge3 = Gauge(gaugeAddr3);

        bribe3 = InternalBribe(bribeAddr3);
        uint256 total = pair.balanceOf(address(owner));
        pair.approve(address(gauge3), total);
        gauge3.deposit(total, 0);
        assertEq(gauge3.totalSupply(), total);
        assertEq(gauge3.earned(address(escrow), address(owner)), 0);
    }

    function routerPair3GetAmountsOutAndSwapExactTokensForTokens() public {
        deployPairFactoryGauge();

        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(FRAX), address(USDC), true);
        Router.route[] memory routes2 = new Router.route[](1);
        routes2[0] = Router.route(address(USDC), address(FRAX), true);


        uint256 i;
        for (i = 0; i < 10; i++) {
            assertEq(router.getAmountsOut(TOKEN_1M, routes)[1], pair.getAmountOut(TOKEN_1M, address(FRAX)));

            uint256[] memory expectedOutput = router.getAmountsOut(TOKEN_1M, routes);
            FRAX.approve(address(router), TOKEN_1M);
            router.swapExactTokensForTokens(TOKEN_1M, expectedOutput[1], routes, address(owner), block.timestamp);

            assertEq(router.getAmountsOut(USDC_1M, routes2)[1], pair.getAmountOut(USDC_1M, address(USDC)));

            uint256[] memory expectedOutput2 = router.getAmountsOut(USDC_1M, routes2);
            USDC.approve(address(router), USDC_1M);
            router.swapExactTokensForTokens(USDC_1M, expectedOutput2[1], routes2, address(owner), block.timestamp);
        }

    }

    function voterReset() public {
        routerPair3GetAmountsOutAndSwapExactTokensForTokens();

        escrow.setVoter(address(voter));
        voter.reset(1);
    }

    function voterPokeSelf() public {
        voterReset();

        voter.poke(1);
    }

    function voterVoteAndBribeBalanceOf() public {
        voterPokeSelf();

        vm.warp(block.timestamp + 1 weeks);

        address[] memory pairs = new address[](2);
        pairs[0] = address(pair);
        pairs[1] = address(pair2);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 5000;
        voter.vote(1, pairs, weights);
        assertFalse(voter.totalWeight() == 0);
        assertFalse(bribe3.balanceOf(1) == 0);
    }
    function balances(string memory title) public{
        console2.log(title);
        console2.log("- bribe3 USDC/FRAX earned:", bribe3.earned(address(USDC), 1)/1e6, bribe3.earned(address(FRAX), 1)/1e18 );
        console2.log("- bribe3 USDC/FRAX balance:", USDC.balanceOf(address(bribe3))/1e6, FRAX.balanceOf(address(bribe3))/1e18);
        console2.log("* USER USDC/FRAX earned:", bribe3.earned(address(USDC), 1)/1e6, bribe3.earned(address(FRAX), 1)/1e18 );
        console2.log("* USER USDC/FRAX balace:", (USDC.balanceOf(address(this)) - initialBalanceUSDC)/1e6,
        (FRAX.balanceOf(address(this)) - initialBalanceFRAX)/1e18 );


    }
    function bribeClaimRewards() public {
        voterVoteAndBribeBalanceOf();

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);
        tokens[1] = address(USDC);

        initialBalanceUSDC = USDC.balanceOf(address(this));
        initialBalanceFRAX = FRAX.balanceOf(address(this));

        balances("before get reward");
        bribe3.getReward(1, tokens);
//        vm.warp(block.timestamp + 691200);
//        vm.roll(block.number + 1);

        balances("after get reward and 1 week pass");
        bribe3.getReward(1, tokens);
    }

    function distributeAndClaimFees() public {
        bribeClaimRewards();

//        vm.warp(block.timestamp + 691200);
//        vm.roll(block.number + 1);
        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);
        tokens[1] = address(USDC);

        balances("after 1 week pass again");
        bribe3.getReward(1, tokens);
        balances("after 1 week pass again and after get reward");
        address[] memory gauges = new address[](1);
        gauges[0] = address(gauge3);
        voter.distributeFees(gauges);
        balances("after voter.distributeFees");
    }

    function testBribeClaimRewards() public {
        distributeAndClaimFees();
        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);
        tokens[1] = address(USDC);
        balances("before 1 week pass again");
        bribe3.getReward(1, tokens);
        vm.warp(block.timestamp + 691200);
        vm.roll(block.number + 1);
        balances("after 1 week pass again");
        bribe3.getReward(1, tokens);
        balances("after getReward");
    }
}
