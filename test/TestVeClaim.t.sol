pragma solidity 0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {veClaimAllFees} from "contracts/veClaimAllFees.sol";
import {IVotingEscrow} from "contracts/interfaces/IVotingEscrow.sol";
import {IPair} from "contracts/interfaces/IPair.sol";
import {IERC20} from "contracts/interfaces/IERC20.sol";
import {IPairFactory} from "contracts/interfaces/IPairFactory.sol";

contract TestVeClaim is Test {
    IPairFactory public pairFactory = IPairFactory(0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95);
    veClaimAllFees private claimer;
    IVotingEscrow ve = IVotingEscrow(0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A);
    mapping(address => uint) private balanceBefore;
    mapping(address => bool) private tokenFound;
    mapping(address => bool) private tokenBalanceDisplayed;

    function setUp() public {
        string memory FORK_URL = vm.rpcUrl("mainnet");
        console2.log("Forking from:", FORK_URL);
        vm.createSelectFork(FORK_URL, 6_126_302);
        address veClaimAllFeesAddress = 0xd05ED49C98d4759362EFC05De15017351e191257;
        //claimer = new veClaimAllFees();
        claimer = veClaimAllFees(veClaimAllFeesAddress);

    }
    function testVeClaimAllFees() public{
        address user = 0x78B3Ec25D285F7a9EcA8Da8eb6b20Be4d5D70E84;
        vm.startPrank(user);
        ve.setApprovalForAll(address(claimer), true);
        vm.stopPrank();
        console2.log("Claiming for user:", user);

        computeBalance(user, false);
        claimer.claimByAddress(user);
        computeBalance(user, true);
    }

    function computeBalance(address user, bool showDifference) public {
        uint totalPools = pairFactory.allPairsLength();
        for (uint i = 0; i < totalPools; i++) {
            address pool = pairFactory.allPairs(i);
            IPair pair = IPair(pool);
            (, , , , , address token0Address, address token1Address) = pair.metadata();
            compareOrSaveBalance(user, token0Address, showDifference);
            compareOrSaveBalance(user, token1Address, showDifference);
        }
    }
    function compareOrSaveBalance(address user, address tokenAddress, bool showDifference) public {
        IERC20 token = IERC20(tokenAddress);
        uint balance = token.balanceOf(user);
        if (!showDifference){
            if ( ! tokenFound[tokenAddress] ){
                tokenFound[tokenAddress] = true;
                balanceBefore[tokenAddress] = balance;
            }
        }else{
            uint diff = balance - balanceBefore[tokenAddress];
            if (diff > 0 && !tokenBalanceDisplayed[tokenAddress]){
                console2.log("- Reward:", token.symbol(), diff);
                tokenBalanceDisplayed[tokenAddress] = true;
            }
        }

    }
}
