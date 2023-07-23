pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "contracts/factories/BribeFactory.sol";
import "contracts/factories/GaugeFactory.sol";
import "contracts/factories/PairFactory.sol";
import "contracts/redeem/MerkleClaim.sol";
import "contracts/InternalBribe.sol";
import "contracts/ExternalBribe.sol";
import "contracts/Gauge.sol";
import "contracts/Minter.sol";
import "contracts/Pair.sol";
import "contracts/PairFees.sol";
import "contracts/RewardsDistributor.sol";
import "contracts/Router.sol";
import "contracts/Router2.sol";
import "contracts/Vara.sol";
import "contracts/VaraLibrary.sol";
import "contracts/Voter.sol";
import "contracts/VeArtProxy.sol";
import "contracts/VotingEscrow.sol";
import "contracts/VaraGovernor.sol";
import "utils/TestOwner.sol";
import "utils/TestStakingRewards.sol";
import "utils/TestToken.sol";
import "utils/TestVoter.sol";
import "utils/TestVotingEscrow.sol";
import "utils/TestWETH.sol";
import "contracts/veSplitter.sol";
import 'contracts/interfaces/IPair.sol';

contract veSplitterTest is Test {
    TestWETH WETH;
    MockERC20 DAI;
    uint TOKEN_100 = 100 * 1e18;
    Vara vara;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    PairFactory pairFactory;
    Router2 router;
    VeArtProxy artProxy;
    VotingEscrow escrow;
    RewardsDistributor distributor;
    Voter voter;
    Minter minter;
    VaraGovernor governor;
    Pair pool_eth_dai;
    Pair pool_eth_vara;
    address[] whitelist;
    Gauge gauge_eth_vara;

    TransparentUpgradeableProxy proxy;
    ProxyAdmin admin;

    veSplitter main;
    uint tokenId;
    function setUp() public {
        console.logAddress(address(this));
        admin = new ProxyAdmin();

        Vara implVara = new Vara();
        proxy = new TransparentUpgradeableProxy(address(implVara), address(admin), abi.encodeWithSelector(Vara.initialize.selector));
        vara = Vara(address(proxy));

        Gauge implGauge = new Gauge();
        GaugeFactory implGaugeFactory = new GaugeFactory();
        proxy = new TransparentUpgradeableProxy(address(implGaugeFactory), address(admin), abi.encodeWithSelector(GaugeFactory.initialize.selector, address(implGauge)));
        gaugeFactory = GaugeFactory(address(proxy));
        
        InternalBribe implInternalBribe = new InternalBribe();
        ExternalBribe implExternalBribe = new ExternalBribe();
        BribeFactory implBribeFactory = new BribeFactory();
        proxy = new TransparentUpgradeableProxy(address(implBribeFactory), address(admin), abi.encodeWithSelector(BribeFactory.initialize.selector, address(implInternalBribe), address(implExternalBribe)));
        bribeFactory = BribeFactory(address(proxy));

        Pair implPair = new Pair();
        PairFactory implPairFactory = new PairFactory();
        proxy = new TransparentUpgradeableProxy(address(implPairFactory), address(admin), abi.encodeWithSelector(PairFactory.initialize.selector, address(implPair)));
        pairFactory = PairFactory(address(proxy));

        WETH = new TestWETH();
        DAI = new MockERC20("DAI", "DAI", 18);
        Router2 implRouter = new Router2();
        proxy = new TransparentUpgradeableProxy(address(implRouter), address(admin), abi.encodeWithSelector(Router.initialize.selector, address(pairFactory), address(WETH)));
        router = Router2(payable(address(proxy)));
        console.logAddress(address(router));

        artProxy = new VeArtProxy();

        VotingEscrow implEscrow = new VotingEscrow();
        proxy = new TransparentUpgradeableProxy(address(implEscrow), address(admin), abi.encodeWithSelector(VotingEscrow.initialize.selector, address(vara), address(artProxy)));
        escrow = VotingEscrow(address(proxy));

        RewardsDistributor implDistributor = new RewardsDistributor();
        proxy = new TransparentUpgradeableProxy(address(implDistributor), address(admin), abi.encodeWithSelector(RewardsDistributor.initialize.selector, address(escrow)));
        distributor = RewardsDistributor(address(proxy));

        Voter implVoter = new Voter();
        proxy = new TransparentUpgradeableProxy(address(implVoter), address(admin), abi.encodeWithSelector(Voter.initialize.selector, address(escrow), address(pairFactory), address(gaugeFactory), address(bribeFactory)));
        voter = Voter(address(proxy));

        Minter implMinter = new Minter();
        proxy = new TransparentUpgradeableProxy(address(implMinter), address(admin), abi.encodeWithSelector(Minter.initialize.selector, address(voter), address(escrow), address(distributor)));
        minter = Minter(address(proxy));

        VaraGovernor implVaraGovernor = new VaraGovernor();
        proxy = new TransparentUpgradeableProxy(address(implVaraGovernor), address(admin), abi.encodeWithSelector(VaraGovernor.initialize.selector, escrow));
        governor = VaraGovernor(payable(address(proxy)));

        // ---
        vara.initialMint(address(this));
        vara.setMinter(address(minter));
        escrow.setVoter(address(voter));
        escrow.setTeam(address(this));
        voter.setGovernor(address(this));
        voter.setEmergencyCouncil(address(this));
        distributor.setDepositor(address(minter));
        governor.setTeam(address(this));


        whitelist.push(address(vara));
        whitelist.push(address(DAI));
        voter.init(whitelist, address(minter));
        //minter.init([], [], 0);
        minter.setTeam(address(this));

        // ---
        DAI.mint(address(this), TOKEN_100);
        DAI.approve(address(router), TOKEN_100);
        vara.approve(address(router), TOKEN_100);
        router.addLiquidityETH{value : TOKEN_100}(address(DAI), false, TOKEN_100, 0, 0, address(this), block.timestamp);
        
        router.addLiquidityETH{value : TOKEN_100}(address(vara), false, TOKEN_100, 0, 0, address(this), block.timestamp);

        pool_eth_dai = Pair(pairFactory.getPair(address(WETH), address(DAI), false));
        pool_eth_vara = Pair(pairFactory.getPair(address(WETH), address(vara), false));

        address[] memory emptyAddresses = new address[](1);
        emptyAddresses[0] = address(this);
        uint[] memory emptyAmounts = new uint[](1);
        emptyAmounts[0] = 1e18;
        minter.init(emptyAddresses, emptyAmounts, 1e18);

        main = new veSplitter( address(voter) );

    }

    function runEpochs() public {
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);

        gauge_eth_vara = Gauge(voter.createGauge(address(pool_eth_vara)));
        vm.roll(block.number + 1);
        uint duration = 4 * 365 * 86400;
        vara.approve(address(escrow), vara.balanceOf(address(this)));
        tokenId = escrow.create_lock(vara.balanceOf(address(this)), duration);

        address[] memory pools = new address[](1);
        pools[0] = address(pool_eth_vara);
        uint256[] memory locks = new uint256[](1);
        locks[0] = 5000;

        vm.warp(block.timestamp + 86400 * 3);
        vm.roll(block.number + 1);

        voter.vote(tokenId, pools, locks);
        voter.distro();

        vm.roll(block.number + 1);

        voter.distro();

        vm.warp(block.timestamp + (86400 * 7) + 1);
        vm.roll(block.number + 1);

        voter.distro();
    }

    function testExec() public {
        runEpochs();

        pool_eth_vara.approve(address(gauge_eth_vara), pool_eth_vara.balanceOf(address(this)));
        gauge_eth_vara.depositAll(tokenId);

        uint[] memory amounts = new uint[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        uint[] memory locks = new uint[](2);
        locks[0] = 7 days;
        locks[1] = 14 days;

        voter.poke(tokenId);

        vm.expectRevert(abi.encodePacked(veSplitter.TokenIdIsAttached.selector));
        main.split(amounts, locks, tokenId);

        voter.reset(tokenId);
        gauge_eth_vara.withdrawAll();

        vm.expectRevert(abi.encodePacked(veSplitter.NftNotApproved.selector));
        main.split(amounts, locks, tokenId);
        escrow.approve(address(main), tokenId);

        uint[] memory amountsInvalid = new uint[](2);
        amountsInvalid[0] = 1 ether;
        amountsInvalid[1] = 1 ether;
        uint[] memory locksInvalid = new uint[](1);
        locksInvalid[0] = 1 days;

        vm.expectRevert(abi.encodePacked(veSplitter.InvalidAmountAndLocksData.selector));
        main.split(amountsInvalid, locksInvalid, tokenId);

        vm.expectRevert(abi.encodePacked(veSplitter.NftLocked.selector));
        main.split(amounts, locks, tokenId);

        uint duration = 4 * 365 * 86400;
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint balanceOfTokenBefore = vara.balanceOf(address(this));
        main.split(amounts, locks, tokenId);

        uint balanceOfNft = escrow.balanceOf(address(this));
        assert( balanceOfNft == 3 );
        uint balanceOfTokenAfter = vara.balanceOf(address(this));
        uint tokensReceived = balanceOfTokenAfter - balanceOfTokenBefore;
        assert( tokensReceived == 39999897000000000000000000);

    }

}
