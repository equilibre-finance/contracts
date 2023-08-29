// 1:1 with Hardhat test
pragma solidity 0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Vara} from "contracts/Vara.sol";
import {bVara} from "contracts/bVara.sol";
import {ERC20} from 'lib/solmate/src/tokens/ERC20.sol';
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {VotingEscrow} from "contracts/VotingEscrow.sol";

contract bVaraTest is Test {
    using Strings for uint256;
    Vara private vara;
    bVara private main;
    VotingEscrow private ve;

    address private user = makeAddr("user");

    function setUp() public {
        vara = new Vara();
        ve = new VotingEscrow(address(vara), address(0) );
        main = new bVara(ERC20(address(vara)), address(ve));
    }

    /// @dev we should get max penalty for <= 1 day:
    function testMaxPenalty() public {
        uint penalty = main.maxPenaltyPct();
        assertEq(main.penalty(1 days), penalty, "MAX PENALTY should be 90");
    }

    /// @dev for 2 months passed, we should get only 30% penalty:
    function test2MonthsPassedPenalty() public {
        uint penalty = 30;
        uint twoMonthsPassed = 60 days;
        assertEq(main.penalty(twoMonthsPassed), penalty, "2 MONTHS PASSED PENALTY should be 67");
    }

    /// @dev we should get 50% penalty for 45 days:
    function test50pctPenalty() public {
        uint penalty = main.maxPenaltyPct() / 2;
        uint halfPeriod = main.minWithdrawDays() / 2;
        assertEq(main.penalty(halfPeriod), penalty, "HALF PENALTY should be 45");
    }

    /// @dev we should get 0% penalty for 90 days:
    function testMinPenalty() public {
        uint penalty = 0;
        uint fullPeriod = main.minWithdrawDays();
        assertEq(main.penalty(fullPeriod), penalty, "MIN PENALTY should be 0");
    }

    /// @dev we should get 0% penalty after 90 days:
    function testNoPenalty() public {
        uint penalty = 0;
        uint fullPeriod = main.minWithdrawDays() + 1;
        assertEq(main.penalty(fullPeriod), penalty, "NO PENALTY should be 0");
    }

    function testEndpointSetup() public {
        address testEndpoint = makeAddr("testEndpoint");
        /// @dev we should be able to set endpoint as owner:
        main.setEndpoint(testEndpoint);
        assertEq(address(main.lzEndpoint()), testEndpoint, "LZ ENDPOINT should be this");

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
        main.setWithdrawalWindow(testWindow);
        assertEq(main.minWithdrawDays(), testWindow, "WITHDRAWAL WINDOW should be this");

        /// @dev we should not be able to set withdrawal window as non-owner:
        vm.startPrank(user);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        main.setWithdrawalWindow(testWindow);
        vm.stopPrank();
    }

    function testSetWhitelist() public {
        /// @dev we should be able to set whitelist as owner:
        main.setWhitelist(user, true);
        assertEq(main.whiteList(user), true, "not whitelisted");

        /// @dev we should not be able to set whitelist as non-owner:
        vm.startPrank(user);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        main.setWhitelist(user, true);
        vm.stopPrank();
    }

    function testMintSecurity() public {
        /// @dev mint and allow test tokens:

        vara.mint(address(this), 100);
        vara.approve(address(main), 100);

        /// @dev we should be able to mint as owner:
        main.mint(user, 100);
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
        vara.mint(address(this), 100);
        vara.approve(address(main), 100);

        /// @dev we should be able to mint as owner:
        main.mint(user, 100);
        assertEq(main.balanceOf(user), 100, "bVARA BALANCE should be 100");
    }

    /// @dev test user transfers:
    function testUserTransfer() public {
        /// @dev create some users for transfer testing:
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        /// @dev mint and allow test tokens:
        vara.mint(address(this), 100);
        vara.approve(address(main), 100);

        /// @dev we should be able to mint as owner:
        main.mint(user1, 100);
        assertEq(main.balanceOf(user1), 100, "bVARA BALANCE should be this");

        /// @dev should revert if not whitelisted:
        vm.startPrank(user1);
        vm.expectRevert(abi.encodePacked(bVara.NonWhiteListed.selector));
        main.transfer(user1, 100);
        vm.stopPrank();


        /// @dev whitelist user1:
        main.setWhitelist(user1, true);

        /// @dev user1 should be able to transfer to user2:
        vm.startPrank(user1);
        main.transfer(user2, 100);
        assertEq(main.balanceOf(user2), 100, "bVARA BALANCE should be this");
        vm.stopPrank();
    }

    function testBurnSecurity() public {
        /// @dev mint and allow test tokens:
        vara.mint(address(this), 100);
        vara.approve(address(main), 100);

        /// @dev mint tokens for user:
        main.mint(user, 100);
        assertEq(main.balanceOf(user), 100, "bVARA BALANCE should be this");

        uint assetBalanceBefore = vara.balanceOf(user);
        /// @dev we should be able to burn as owner:
        main.burn(user, 100);
        assertEq(main.balanceOf(user), 0, "bVARA BALANCE should be 0");
        uint assetBalanceAfter = vara.balanceOf(user);
        uint assetReceived = assetBalanceAfter - assetBalanceBefore;
        assertEq(assetReceived, 100, "VARA BALANCE should be 100");

        /// @dev asset balance should be 0:

        /// @dev we should not be able to burn as non-owner:
        vm.startPrank(user);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        main.burn(user, 100);
        vm.stopPrank();
    }

    function _redemption( uint _days, uint _deposit, uint _expected ) private{
        /// @dev create a random user for testing:
        address _user = makeAddr("rnd");
        /// @dev we should be able to redeem with 50% penalty:
        vara.mint(address(this), _deposit);
        vara.approve(address(main), _deposit);
        main.mint(_user, _deposit);
        vm.startPrank(_user);

        uint balanceBefore = vara.balanceOf(_user);
        /// @dev forward half of withdrawal window:
        vm.warp(block.timestamp + _days );
        main.redeem(_deposit);
        uint balanceAfter = vara.balanceOf(_user);
        uint received = balanceAfter - balanceBefore;

        string memory assertMsg = string(abi.encodePacked("VARA BALANCE should be ", _expected.toString(), ", received ", received.toString() ));
        assertEq(received, _expected, assertMsg);
        vm.stopPrank();
    }

    function testRedeem() public {
        /// @dev mint and allow test tokens:
        vara.mint(address(this), 100);
        vara.approve(address(main), 100);

        /// @dev mint tokens for user:
        main.mint(user, 100);
        assertEq(main.balanceOf(user), 100, "bVARA BALANCE should be 100");

        uint minWithdrawDays = main.minWithdrawDays();
        uint halfPeriod = minWithdrawDays / 2;

        /// @dev we should be able to redeem with 90% penalty:
        _redemption( 1 days, 100, 10 );

        /// @dev we should be able to redeem with 50% penalty:
        _redemption( halfPeriod, 100, 55 );

        /// @dev we should be able to redeem with 0% penalty:
        _redemption( minWithdrawDays, 100, 100 );

        /// @dev after 2 months passed, we should be able to redeem with 33% penalty:
        _redemption( 60 days, 100, 70 );

    }

    function testConvertToVe() public{
        uint amount = 100 ether;
        uint lockFor = 100 days;
        /// @dev mint and allow test tokens:
        vara.mint(address(this), amount);
        vara.approve(address(main), amount);

        /// @dev mint tokens for user:
        main.mint(user, amount);
        assertEq(main.balanceOf(user), amount, "bVARA BALANCE should be 100");

        /// @dev we should be able to convert to veVARA:
        vm.startPrank(user);
        uint tokenId = main.convertToVe(amount, lockFor);
        vm.stopPrank();

        assertEq(main.balanceOf(user), 0, "bVARA BALANCE should be 0");
        assertEq(ve.ownerOf(tokenId), user, "OWNER should be user");

        (int128 _amount, uint end) = ve.locked(tokenId);
        uint deposited = uint(uint128(_amount));

        uint unlock_time = (block.timestamp + lockFor) / 1 weeks * 1 weeks;
        assertEq(deposited, amount, "veVARA BALANCE should be 100");
        assertEq(end, unlock_time, "END should be 100 days");

    }

}
