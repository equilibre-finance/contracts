// 1:1 with Hardhat test
pragma solidity 0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Vara} from "contracts/Vara.sol";
import {bVaraMock} from "./mock/bVaraMock.sol";
import {bVaraImplementation} from "contracts/bVaraImplementation.sol";
import {ERC20} from 'lib/solmate/src/tokens/ERC20.sol';
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {VotingEscrow} from "contracts/VotingEscrow.sol";
import {Voter} from "contracts/Voter.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {InternalBribe} from "contracts/InternalBribe.sol";
import {ExternalBribe} from "contracts/ExternalBribe.sol";
import {Gauge} from "contracts/Gauge.sol";

import "forge-std/StdStorage.sol";

contract bVaraTest is Test {
    using stdStorage for StdStorage;
    using Strings for uint256;
    Vara private vara;
    bVaraMock private main;
    bVaraMock private implementation;
    VotingEscrow private ve;
    Voter private voter;
    TransparentUpgradeableProxy private proxy;
    ProxyAdmin private proxyAdmin;

    /// @dev the admin address only for proxy upgrade:
    address private proxyAdminAddress = address(0x52B9Ff6f13ca7A871a7112d2a3912adc07F054c4);
    address private admin = address(0x7cef2432A2690168Fb8eb7118A74d5f8EfF9Ef55);
    address private user = makeAddr("user");

    address private votingEscrow = 0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A;
    address private voterAddress = 0x4eB2B9768da9Ea26E3aBe605c9040bC12F236a59;
    address private varaAddress = 0xE1da44C0dA55B075aE8E2e4b6986AdC76Ac77d73;
    address private bVaraProxyAddress = 0x9f80f639Ff87BE7299Eec54a08dB20dB3b3a4171;

    Gauge private gauge;
    ExternalBribe private bribe;
    address private poolAddress;
    address private gaugeAddress;

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
        .target(token)
        .sig(ERC20(token).balanceOf.selector)
        .with_key(who)
        .checked_write(amt);
    }

    function warp(uint ttl) public {
        vm.warp(block.timestamp + ttl + 1);
        vm.roll(block.number + 1);
    }

    function setUp() public {

        // fork mainnet:
        vm.createSelectFork("https://evm.data.equilibre.kava.io", 6629400);
        assertEq(2222, block.chainid, "INVALID FORK NETWORK ID");

        vara = Vara(varaAddress);
        voter = Voter(voterAddress);
        ve = VotingEscrow(votingEscrow);
        proxyAdmin = new ProxyAdmin();

        /// @dev deploy proxy:
        implementation = new bVaraMock();
        bytes memory _data = abi.encodeWithSignature("initialize(address,address)", ERC20(address(vara)), address(ve));
        main = bVaraMock(address(proxy = new TransparentUpgradeableProxy(address(implementation), address(proxyAdmin), _data)));
        // @dev transfer contract to admin:
        main.transferOwnership(address(admin));

        /// @dev whitelist admin, so admin can bribe:
        vm.startPrank(address(admin));
        main.setWhitelist(address(admin), true);
        vm.stopPrank();

        /// @dev let's vote:
        poolAddress = voter.pools(0);
        gaugeAddress = voter.gauges(poolAddress);

        gauge = Gauge(gaugeAddress);
        bribe = ExternalBribe(gauge.external_bribe());

        /// @dev: whitelist the bribe or user will not be able to claim:
        vm.startPrank(address(admin));
        main.setWhitelist(address(bribe), true);
        vm.stopPrank();

        /// @dev approve and add reward to bribe as bVara:
        address governor = voter.governor();
        vm.startPrank(governor);
        voter.whitelist(address(main));
        assertEq(voter.isWhitelisted(address(main)), true, "bVARA SHOULD BE WHITELISTED");
        vm.stopPrank();
    }

    function testAddToTokenId() public {
        writeTokenBalance(admin, address(vara), 1_000_000 ether);
        _addToTokenId(6081);
        _addToTokenId(6207);
    }

    function _addToTokenId(uint tokenId) private {
        uint total = 200 ether;
        uint amount = total / 2;
        /// @dev mint and allow test tokens:
        vm.startPrank(admin);
        vara.approve(address(main), total);
        vm.stopPrank();

        address owner = ve.ownerOf(tokenId);

        /// @dev mint tokens for user:
        vm.startPrank(admin);
        main.mint(owner, amount);
        vm.stopPrank();

        assertGe(main.balanceOf(owner), amount, "bVARA BALANCE should be >= 100");

        /*
        (int128 _oldAmount, uint oldLockEndsIn) = ve.locked(tokenId);
        uint oldAmount = uint(int256(_oldAmount));
        uint WEEK = 1 weeks;
        uint _lock_duration = 4 * 365 days;
        uint unlock_time = (block.timestamp + _lock_duration) / WEEK * WEEK; // Locktime is rounded down to weeks
        */

        /// @dev let's add to the tokenId and push the lock to 4y:
        vm.startPrank(owner);
        ve.setApprovalForAll(address(main), true);
        main.addToVe(tokenId, amount);
        vm.stopPrank();

    }


    /// @dev test if revert when user try to deposit into implementation:
    function testDepositRevert() public {
        /// @dev mint and allow test tokens:
        writeTokenBalance(admin, address(vara), 1_000_000 ether ); // (admin, 100);
        vara.approve(address(implementation), 100);


        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        implementation.mint(user, 100);

    }

    /// @dev test if minWithdrawDays is 90 days and maxPenaltyPct is 90:
    function testProxyMinWithdrawDays() public {
        assertEq(main.minWithdrawDays(), 90 days, "WITHDRAWAL WINDOW should be 90 days");
        assertEq(main.maxPenaltyPct(), 90, "MAX PENALTY should be 90");
    }

    /// @dev for 2/3 passed, we should get only 33% penalty:
    function test2MonthsPassedPenalty() public {
        uint startAt = block.timestamp;
        uint endsAt = startAt + 90 days;
        warp(60 days);
        (uint256 _received,,) = main.penalty(block.timestamp, startAt, endsAt, 100 ether);
        assertEq(_received, 66_67e16, "HALF PENALTY should be 66.6");
    }

    /// @dev we should get 50% penalty for 45 days:
    function test50pctPenalty() public {
        uint startAt = block.timestamp;
        uint endsAt = startAt + 90 days;
        warp(45 days);
        (uint256 _received,,) = main.penalty(block.timestamp, startAt, endsAt, 100 ether);
        assertEq(_received, 50_01e16, "HALF PENALTY should be 50");
    }

    /// @dev we should get 0% penalty for 90 days:
    function testMinPenalty() public {
        (uint256 _received,,) = main.penalty(block.timestamp, block.timestamp, block.timestamp, 100);
        assertEq(_received, 100, "MIN PENALTY should be 100");
    }
    /// @dev we should get max penalty for <= 1 day:
    function testMaxPenalty() public {
        uint fullPeriod = main.minWithdrawDays();
        (uint256 _received,,) = main.penalty(block.timestamp, block.timestamp, block.timestamp + fullPeriod, 100);
        assertEq(_received, 10, "MAX PENALTY should be 10");
    }

    /// @dev we should get 0% penalty after 90 days:
    function testNoPenalty() public {
        uint fullPeriod = main.minWithdrawDays() + 1;
        (uint256 _received,,) = main.penalty(block.timestamp, block.timestamp, fullPeriod, 100);
        assertEq(_received, 100, "NO PENALTY should be 100");
    }

    function testEndpointSetup() public {
        address testEndpoint = makeAddr("testEndpoint");
        /// @dev we should be able to set endpoint as owner:
        vm.startPrank(admin);
        main.setEndpoint(testEndpoint);
        assertEq(address(main.lzEndpoint()), testEndpoint, "LZ ENDPOINT should be this");
        vm.stopPrank();

        /// @dev we should not be able to set endpoint as non-owner:
        vm.startPrank(user);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        main.setEndpoint(testEndpoint);
        vm.stopPrank();
    }

    /// @dev we should be able to set withdrawal window as owner:
    function testWithdrawalWindowSetup() public {
        uint testWindow = 100 days;
        /// @dev we should be able to set withdrawal window as owner:
        vm.startPrank(admin);
        main.setWithdrawalWindow(testWindow);
        vm.stopPrank();
        assertEq(main.minWithdrawDays(), testWindow, "WITHDRAWAL WINDOW should be this");

        /// @dev we should not be able to set withdrawal window as non-owner:
        vm.startPrank(user);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        main.setWithdrawalWindow(testWindow);
        vm.stopPrank();
    }

    function testSetWhitelist() public {
        /// @dev we should be able to set whitelist as owner:
        vm.startPrank(admin);
        main.setWhitelist(user, true);
        vm.stopPrank();
        assertEq(main.whiteList(user), true, "not whitelisted");

        /// @dev we should not be able to set whitelist as non-owner:
        vm.startPrank(user);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        main.setWhitelist(user, true);
        vm.stopPrank();
    }

    function testMintSecurity() public {
        /// @dev mint and allow test tokens:

        writeTokenBalance(admin, address(vara), 1_000_000 ether); // (admin, 100);
        vm.startPrank(admin);
        vara.approve(address(main), 100);
        vm.stopPrank();

        /// @dev we should be able to mint as owner:
        vm.startPrank(admin);
        main.mint(user, 100);
        vm.stopPrank();
        assertEq(main.balanceOf(user), 100, "bVARA BALANCE should be 100");

        /// @dev we should not be able to mint as non-owner:
        vm.startPrank(user);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        main.mint(user, 100);
        vm.stopPrank();
    }

    /// @dev test mint to users:
    function testMintToUser() public {
        /// @dev mint and allow test tokens:
        writeTokenBalance(admin, address(vara), 1_000_000 ether); // (admin, 100);
        vm.startPrank(admin);
        vara.approve(address(main), 100);
        vm.stopPrank();

        /// @dev we should be able to mint as owner:
        vm.startPrank(admin);
        main.mint(user, 100);
        vm.stopPrank();
        assertEq(main.balanceOf(user), 100, "bVARA BALANCE should be 100");
    }

    /// @dev test user transfers:
    function testUserTransfer() public {

        uint amount = 100 ether;
        writeTokenBalance(admin, address(vara), 1_000_000 ether);

        /// @dev create some users for transfer testing:
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        /// @dev mint and allow test tokens:
        writeTokenBalance(admin, address(vara), 1_000_000 ether); // (admin, amount);
        vm.startPrank(admin);
        vara.approve(address(main), amount);
        vm.stopPrank();

        /// @dev we should be able to mint as owner:
        vm.startPrank(admin);
        main.mint(user1, amount);
        vm.stopPrank();
        assertEq(main.balanceOf(user1), amount, "bVARA BALANCE should be this");

        /// @dev should revert if not whitelisted:
        vm.startPrank(user1);
        vm.expectRevert(abi.encodePacked(bVaraImplementation.NonWhiteListed.selector));
        main.transfer(user1, amount);
        vm.stopPrank();

        /// @dev whitelist user1:
        vm.startPrank(admin);
        main.setWhitelist(user1, true);
        vm.stopPrank();

        /// @dev user1 should be able to transfer to user2:
        vm.startPrank(user1);
        main.transfer(user2, amount);
        assertEq(main.balanceOf(user2), amount, "bVARA BALANCE should be this");
        vm.stopPrank();
    }

    function testConvertToVe() public {
        uint amount = vara.balanceOf(admin);
        /// @dev mint and allow test tokens:
        vm.startPrank(admin);
        vara.approve(address(main), amount);
        vm.stopPrank();

        /// @dev mint tokens for user:
        vm.startPrank(admin);
        main.mint(user, amount);
        vm.stopPrank();

        assertEq(main.balanceOf(user), amount, "bVARA BALANCE should be 100");

        /// @dev we should be able to convert to veVARA:
        vm.startPrank(user);
        uint tokenId = main.convertToVe(amount);
        vm.stopPrank();

        assertEq(main.balanceOf(user), 0, "bVARA BALANCE should be 0");
        assertEq(ve.ownerOf(tokenId), user, "OWNER should be user");

        (int128 _amount, uint end) = ve.locked(tokenId);
        uint deposited = uint(uint128(_amount));

        /// @dev conversion always lock for 4y:
        uint _lock_duration = ((block.timestamp + (365 days * 4)) / 1 weeks * 1 weeks);
        assertEq(deposited, amount, "veVARA BALANCE should be 100");
        assertEq(end, _lock_duration, "END should be 100 days");

    }

    function testVest() public {
        /// @dev mint and allow test tokens:
        uint amount = vara.balanceOf(admin);
        assertGt(amount, 0, "VARA BALANCE should be > 0");
        vm.startPrank(admin);
        vara.approve(address(main), amount);
        vm.stopPrank();

        /// @dev mint tokens for user:
        vm.startPrank(admin);
        main.mint(user, amount);
        vm.stopPrank();

        amount = main.balanceOf(user);
        assertGt(amount, 0, "bVARA BALANCE should be > 0");

        /// @dev conversion always lock for 4y:
        vm.startPrank(address(user));
        uint vestID = main.vest(amount);
        vm.stopPrank();

        uint getVestLength = main.getVestLength(user);
        assertEq(getVestLength, 1, "VEST LENGTH should be 1");

        bVaraMock.VestPosition[] memory vestInfo = main.getAllVestInfo(user);
        assertEq(vestInfo[0].amount, amount, "VEST AMOUNT should be 100");
        assertEq(vestInfo[0].exitIn, 0, "VEST EXIT IN should be 0");
        assertEq(vestInfo[0].vestID, vestID, "VEST ID should be 0");


    }

    function testCancelVest() public {
        /// @dev mint and allow test tokens:
        uint amount = vara.balanceOf(admin);
        assertGt(amount, 0, "VARA BALANCE should be > 0");
        vm.startPrank(admin);
        vara.approve(address(main), amount);
        vm.stopPrank();

        /// @dev mint tokens for user:
        vm.startPrank(admin);
        main.mint(user, amount);
        vm.stopPrank();

        amount = main.balanceOf(user);
        assertGt(amount, 0, "bVARA BALANCE should be > 0");

        /// @dev conversion always lock for 4y:
        vm.startPrank(address(user));
        uint vestID = main.vest(amount);
        vm.stopPrank();

        warp(30 days);

        vm.startPrank(address(user));
        main.cancelVest(vestID);
        vm.stopPrank();

        /// @dev user balance should be the same:
        assertEq(main.balanceOf(user), amount, "bVARA BALANCE should be 100");

        bVaraMock.VestPosition[] memory vestInfo = main.getAllVestInfo(user);
        assertGt(vestInfo[0].exitIn, 0, "VEST EXIT IN should be gt 0");

        /// @dev should revert if try a new cancel:
        vm.startPrank(address(user));
        vm.expectRevert();
        main.cancelVest(vestID);
        vm.stopPrank();

    }

    function testVestExitSecurity() public {
        /// @dev mint and allow test tokens:
        uint amount = vara.balanceOf(admin);
        assertGt(amount, 0, "VARA BALANCE should be > 0");
        vm.startPrank(admin);
        vara.approve(address(main), amount);
        vm.stopPrank();

        /// @dev mint tokens for user:
        vm.startPrank(admin);
        main.mint(user, amount);
        vm.stopPrank();

        amount = main.balanceOf(user);
        assertGt(amount, 0, "bVARA BALANCE should be > 0");

        /// @dev conversion always lock for 4y:
        vm.startPrank(address(user));
        main.vest(amount);
        vm.stopPrank();

        warp(30 days);

        /// @dev should revert if try to convert to ve:
        vm.startPrank(address(user));
        vm.expectRevert();
        main.convertToVe(amount);
        vm.stopPrank();

    }


    function testExternalBribeAndClaim() public {

        /// @dev mint and allow test tokens:
        uint fullBalance = vara.balanceOf(admin);
        assertGt(fullBalance, 0, "VARA BALANCE should be > 0 FOR ADMIN");
        uint amount = fullBalance / 2;
        assertGt(amount, 0, "VARA BALANCE should be > 0");
        vm.startPrank(admin);
        vara.approve(address(main), amount);
        main.mint(user, amount);
        amount = main.balanceOf(user);
        assertGt(amount, 0, "bVARA BALANCE should be > 0");
        vm.stopPrank();

        /// @dev conversion always lock for 4y:
        vm.startPrank(address(user));
        uint tokenId = main.convertToVe(amount);
        assertGt(tokenId, 0, "TOKEN ID should be > 0");
        vm.stopPrank();

        /// @dev approve and add reward to bribe as bVara:
        vm.startPrank(address(admin));
        uint bribedAmount = vara.balanceOf(admin);
        assertGt(bribedAmount, 0, "VARA BALANCE should be > 0 TO BRIBE");
        vara.approve(address(main), bribedAmount);
        main.mint(admin, bribedAmount);

        bribedAmount = main.balanceOf(address(admin));
        main.approve(address(bribe), bribedAmount);
        assertGt(bribedAmount, 0, "bVARA BALANCE should be > 0 TO BRIBE");
        bribe.notifyRewardAmount(address(main), bribedAmount);
        assertEq(main.balanceOf(address(bribe)), bribedAmount, "bVARA BALANCE INCORRECT IN THE BRIBE");

        vm.stopPrank();

        /// @dev do a voter:
        address[] memory _poolVote = new address[](1);
        _poolVote[0] = poolAddress;
        uint256[] memory _weights = new uint256[](1);
        _weights[0] = 5000;
        vm.startPrank(address(user));
        voter.vote(tokenId, _poolVote, _weights);
        vm.stopPrank();

        /// @dev check user rewards:

        // fwd half a week
        warp(1 weeks);
        uint256 pre = main.balanceOf(address(user));
        vm.startPrank(address(user));
        address[] memory _bribes = new address[](1);
        address[][] memory _tokens = new address[][](1);

        _bribes[0] = address(bribe);
        _tokens[0] = new address[](1);
        _tokens[0][0] = address(main);

        voter.claimBribes(_bribes, _tokens, tokenId);
        vm.stopPrank();
        uint256 post = main.balanceOf(address(user));
        assertGt(post - pre, 0, "bVARA BALANCE should be > 0");

    }

    function testPassedPeriod() public{
        (uint256 _received,,) = main.penalty(block.timestamp + 1 days, block.timestamp, block.timestamp, 100);
        assertEq(_received, 100, "NO PENALTY should be 100");
    }


    function _redemption(uint _days, uint _deposit, uint _expected) private {
        _days;
        //console2.log("_redemption", _days, _deposit, _expected);
        /// @dev create a random user for testing:
        address _user = makeAddr("rnd");

        vm.startPrank(admin);
        vara.approve(address(main), _deposit);
        main.mint(_user, _deposit);
        vm.stopPrank();

        vm.startPrank(_user);
        uint balanceBefore = main.balanceOf(_user);
        assertEq(balanceBefore, _deposit, "VARA BALANCE should be 100");

        /// @dev first, we vest:
        uint vestId = main.vest(balanceBefore);

        /// @dev forward half of withdrawal window:
        warp(_days);
        (uint _received, ,) = main.redeem(vestId);

        vm.stopPrank();

        uint daysPassed = _days / 1 days;
        string memory assertMsg = string(abi.encodePacked(" Redemption: for ",daysPassed.toString()," days, expected should be ", (_expected/1e18).toString(), ", received ", (_received/1e18).toString()));
        console2.log(assertMsg);
        assertEq(_received, _expected, assertMsg);

    }

    function testRedeem() public {
        /// @dev mint and allow test tokens:
        uint amount = 100 ether;
        writeTokenBalance(admin, address(vara), 1_000_000 ether);
        vm.startPrank(admin);
        vara.approve(address(main), amount);
        main.mint(user, amount);
        vm.stopPrank();

        assertEq(main.balanceOf(user), amount, "bVARA BALANCE should be 100");

        uint minWithdrawDays = main.minWithdrawDays();
        uint halfPeriod = minWithdrawDays / 2;

        /// @dev we should be able to redeem with 90% penalty:
        _redemption(1 days, amount, 10 ether);

        /// @dev we should be able to redeem with 50% penalty:
        _redemption(halfPeriod, amount, 50_01e16);

        /// @dev we should be able to redeem with 0% penalty:
        _redemption(minWithdrawDays, amount, 100 ether);

        /// @dev after 2 months passed, we should be able to redeem with 33% penalty:
        _redemption(60 days, amount, 66_67e16);

    }

    function testAddToVe() public {
        uint total = vara.balanceOf(admin);
        uint amount = total / 2;
        /// @dev mint and allow test tokens:
        vm.startPrank(admin);
        vara.approve(address(main), total);
        vm.stopPrank();

        /// @dev mint tokens for user:
        vm.startPrank(admin);
        main.mint(user, amount);
        vm.stopPrank();

        assertEq(main.balanceOf(user), amount, "bVARA BALANCE should be 100");

        /// @dev we should be able to convert to veVARA:
        vm.startPrank(user);
        uint tokenId = main.convertToVe(amount);
        vm.stopPrank();

        assertEq(main.balanceOf(user), 0, "bVARA BALANCE should be 0");
        assertEq(ve.ownerOf(tokenId), user, "OWNER should be user");

        (int128 _amount, uint end) = ve.locked(tokenId);
        uint deposited = uint(uint128(_amount));

        /// @dev conversion always lock for 4y:
        uint _lock_duration = ((block.timestamp + (365 days * 4)) / 1 weeks * 1 weeks);
        assertEq(deposited, amount, "veVARA BALANCE should be 100");
        assertEq(end, _lock_duration, "END should be 100 days");


        /// @dev user receive another batch of tokens:
        vm.startPrank(admin);
        main.mint(user, amount);
        vm.stopPrank();

        assertEq(main.balanceOf(user), amount, "bVARA BALANCE should be 100");
        warp(365 days * 2);

        /// @dev let's get the current lock expire ts and value:
        (int128 _oldAmount, ) = ve.locked(tokenId);
        uint oldAmount = uint(int256(_oldAmount));

        /// @dev let's add to the tokenId and push the lock to 4y:
        vm.startPrank(user);
        ve.setApprovalForAll(address(main), true);
        main.addToVe(tokenId, amount);
        vm.stopPrank();

        // @dev let's get the new lock expire ts and value:
        (int128 _newAmount, uint newLockEndsIn) = ve.locked(tokenId);
        uint newAmount = uint(int256(_newAmount));
        assertEq(newAmount, oldAmount + amount, "AMOUNT should be 200");

        uint MAXTIME = 4 * 365 days;
        uint _MAXTIME_ROUNDED = ((block.timestamp + MAXTIME) / 1 weeks * 1 weeks);

        assertEq(newLockEndsIn, _MAXTIME_ROUNDED, "new lock should be 4y");
    }



}