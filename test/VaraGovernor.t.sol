pragma solidity 0.8.13;

import "./BaseTest.sol";
import "contracts/VaraGovernor.sol";

contract VaraGovernorTest is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    RewardsDistributor distributor;
    Minter minter;
    Gauge gauge;
    InternalBribe bribe;
    VaraGovernor governor;

    function setUp() public {
        deployProxyAdmin();
        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 2e25;
        amounts[1] = 1e25;
        amounts[2] = 1e25;
        mintVara(owners, amounts);

        VeArtProxy artProxy = new VeArtProxy();

        VotingEscrow implEscrow = new VotingEscrow();
        proxy = new TransparentUpgradeableProxy(address(implEscrow), address(admin), abi.encodeWithSelector(VotingEscrow.initialize.selector, address(VARA), address(artProxy)));
        escrow = VotingEscrow(address(proxy));

        VARA.approve(address(escrow), 97 * TOKEN_1);
        escrow.create_lock(97 * TOKEN_1, 4 * 365 * 86400);
        vm.roll(block.number + 1);

        // owner2 owns less than quorum, 3%
        vm.startPrank(address(owner2));
        VARA.approve(address(escrow), 3 * TOKEN_1);
        escrow.create_lock(3 * TOKEN_1, 4 * 365 * 86400);
        vm.roll(block.number + 1);
        vm.stopPrank();

        deployPairFactoryAndRouter();

        USDC.approve(address(router), USDC_100K);
        FRAX.approve(address(router), TOKEN_100K);
        router.addLiquidity(address(FRAX), address(USDC), true, TOKEN_100K, USDC_100K, TOKEN_100K, USDC_100K, address(owner), block.timestamp);

        Gauge implGauge = new Gauge();
        GaugeFactory implGaugeFactory = new GaugeFactory();
        proxy = new TransparentUpgradeableProxy(address(implGaugeFactory), address(admin), abi.encodeWithSelector(GaugeFactory.initialize.selector, address(implGauge)));
        gaugeFactory = GaugeFactory(address(proxy));

        InternalBribe implInternalBribe = new InternalBribe();
        ExternalBribe implExternalBribe = new ExternalBribe();
        BribeFactory implBribeFactory = new BribeFactory();
        proxy = new TransparentUpgradeableProxy(address(implBribeFactory), address(admin), abi.encodeWithSelector(BribeFactory.initialize.selector, address(implInternalBribe), address(implExternalBribe)));
        bribeFactory = BribeFactory(address(proxy));

        Voter implVoter = new Voter();
        proxy = new TransparentUpgradeableProxy(address(implVoter), address(admin), abi.encodeWithSelector(Voter.initialize.selector, address(escrow), address(factory), address(gaugeFactory), address(bribeFactory)));
        voter = Voter(address(proxy));

        escrow.setVoter(address(voter));

        RewardsDistributor implDistributor = new RewardsDistributor();
        proxy = new TransparentUpgradeableProxy(address(implDistributor), address(admin), abi.encodeWithSelector(RewardsDistributor.initialize.selector, address(escrow)));
        distributor = RewardsDistributor(address(proxy));

        Minter implMinter = new Minter();
        proxy = new TransparentUpgradeableProxy(address(implMinter), address(admin), abi.encodeWithSelector(Minter.initialize.selector, address(voter), address(escrow), address(distributor)));
        minter = Minter(address(proxy));
        
        distributor.setDepositor(address(minter));
        VARA.setMinter(address(minter));

        VARA.approve(address(gaugeFactory), 15 * TOKEN_100K);
        voter.createGauge(address(pair));
        address gaugeAddress = voter.gauges(address(pair));
        address bribeAddress = voter.internal_bribes(gaugeAddress);
        gauge = Gauge(gaugeAddress);
        bribe = InternalBribe(bribeAddress);

        VaraGovernor implVaraGovernor = new VaraGovernor();
        proxy = new TransparentUpgradeableProxy(address(implVaraGovernor), address(admin), abi.encodeWithSelector(VaraGovernor.initialize.selector, escrow));
        governor = VaraGovernor(payable(address(proxy)));
        voter.setGovernor(address(governor));
    }

    function testGovernorCanWhitelistTokens(address token) public {
        vm.startPrank(address(governor));
        voter.whitelist(token);
        vm.stopPrank();
    }

    function testFailNonGovernorCannotWhitelistTokens(address user, address token) public {
        vm.assume(user != address(governor));

        vm.startPrank(address(user));
        voter.whitelist(token);
        vm.stopPrank();
    }

    function testGovernorCanCreateGaugesForAnyAddress(address a) public {
        vm.assume(a != address(0));

        vm.startPrank(address(governor));
        voter.createGauge(a);
        vm.stopPrank();
    }

    function testVeVaraMergesAutoDelegates() public {
        // owner2 + owner3 > quorum
        vm.startPrank(address(owner3));
        VARA.approve(address(escrow), 3 * TOKEN_1);
        escrow.create_lock(3 * TOKEN_1, 4 * 365 * 86400);
        vm.roll(block.number + 1);
        uint256 pre2 = escrow.getVotes(address(owner2));
        uint256 pre3 = escrow.getVotes(address(owner3));

        // merge
        escrow.approve(address(owner2), 3);
        escrow.transferFrom(address(owner3), address(owner2), 3);
        vm.stopPrank();
        vm.startPrank(address(owner2));
        escrow.merge(3, 2);
        vm.stopPrank();

        // assert vote balances
        uint256 post2 = escrow.getVotes(address(owner2));
        assertApproxEqAbs(
            pre2 + pre3,
            post2,
            4 * 365 * 86400 // merge rounds down time lock
        );
    }

    function testFailCannotProposeWithoutSufficientBalance() public {
        // propose
        vm.startPrank(address(owner3));
        address[] memory targets = new address[](1);
        targets[0] = address(voter);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(voter.whitelist.selector, address(USDC));
        string memory description = "Whitelist USDC";

        governor.propose(targets, values, calldatas, description);
        vm.stopPrank();
    }

    function testFailProposalsNeedQuorumToPass() public {
        assertFalse(voter.isWhitelisted(address(USDC)));

        address[] memory targets = new address[](1);
        targets[0] = address(voter);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(voter.whitelist.selector, address(USDC));
        string memory description = "Whitelist USDC";

        // propose
        vm.startPrank(address(owner));
        uint256 pid = governor.propose(targets, values, calldatas, description);
        vm.warp(block.timestamp + 16 minutes); // delay
        vm.stopPrank();

        // vote
        vm.startPrank(address(owner2));
        governor.castVote(pid, 1);
        vm.warp(block.timestamp + 1 weeks); // voting period
        vm.stopPrank();

        // execute
        vm.startPrank(address(owner));
        governor.execute(targets, values, calldatas, keccak256(bytes(description)));
        vm.stopPrank();
    }

    function testProposalHasQuorum() public {
        assertFalse(voter.isWhitelisted(address(USDC)));

        address[] memory targets = new address[](1);
        targets[0] = address(voter);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(voter.whitelist.selector, address(USDC));
        string memory description = "Whitelist USDC";

        // propose
        vm.startPrank(address(owner));
        uint256 pid = governor.propose(targets, values, calldatas, description);
        vm.warp(block.timestamp + 16 minutes); // delay
        vm.stopPrank();

        // vote
        vm.startPrank(address(owner));
        governor.castVote(pid, 1);
        vm.warp(block.timestamp + 1 weeks); // voting period
        vm.stopPrank();

        // execute
        vm.startPrank(address(owner));
        governor.execute(targets, values, calldatas, keccak256(bytes(description)));
        vm.stopPrank();

        assertTrue(voter.isWhitelisted(address(USDC)));
    }
}
