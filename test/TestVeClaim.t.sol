pragma solidity 0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IVotingEscrow} from "contracts/interfaces/IVotingEscrow.sol";
import {IVoter} from "contracts/interfaces/IVoter.sol";
import {IPairFactory} from "contracts/interfaces/IPairFactory.sol";
import {IBribe} from "contracts/interfaces/IBribe.sol";
import {IERC20} from "contracts/interfaces/IERC20.sol";
import {IGauge} from "contracts/interfaces/IGauge.sol";
import {veClaimAllFees} from "contracts/veClaimAllFees.sol";

contract TestVeClaim is Test {
    IVotingEscrow private ve;
    IVoter private voter;
    IPairFactory private pairFactory;
    address private veAddress = 0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A;
    address private voterAddress = 0x4eB2B9768da9Ea26E3aBe605c9040bC12F236a59;
    address private pairFactoryAddress = 0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95;

    error NotApproved();

    function setUp() public {
        // get from env:
        fork();
        ve = IVotingEscrow(veAddress);
        voter = IVoter(voterAddress);
        pairFactory = IPairFactory(pairFactoryAddress);
    }

    function fork() public {
        string memory FORK_URL = vm.rpcUrl("mainnet");
        console2.log("Forking from:", FORK_URL);
        vm.createSelectFork(FORK_URL, 6_126_302);
    }
    function testVeClaimAllFees() public{
        address claimerAddress = 0xd05ED49C98d4759362EFC05De15017351e191257;
        veClaimAllFees claimer = veClaimAllFees(claimerAddress);

        address user = 0x78B3Ec25D285F7a9EcA8Da8eb6b20Be4d5D70E84;

        vm.startPrank(user);
        ve.setApprovalForAll(claimerAddress, true);
        vm.stopPrank();

        claimer.claimByAddress(user);
    }
    function XtestUserClaim() public {
        address user = 0x78B3Ec25D285F7a9EcA8Da8eb6b20Be4d5D70E84;

        vm.startPrank(user);
        ve.setApprovalForAll(address(this), true);
        vm.stopPrank();

        claimByAddress(user);

    }

    function claimByAddress(address user) public {
        uint userTokens = ve.balanceOf(user);
        console2.log("User:", user, "tokens:", userTokens);
        for (uint i = 0; i < userTokens; i++) {
            uint tokenId = ve.tokenOfOwnerByIndex(user, i);
            console2.log("- Claiming for tokenId:", tokenId);
            claimAllByTokenId(tokenId);
        }
    }

    function claimAllByTokenId(uint tokenId) public {
        address user = ve.ownerOf(tokenId);
        if (!ve.isApprovedForAll(user, address(this)))
            revert NotApproved();
        // get all pools from factory:
        uint totalPools = pairFactory.allPairsLength();

        // get all gauges by pools address from voter:
        for (uint i = 0; i < totalPools; i++) {
            address pool = pairFactory.allPairs(i);
            address gaugeAddress = voter.gauges(pool);
            if (voter.gauges(pool) == address(0)) continue;
            _prepareBribes(user, tokenId, IGauge(gaugeAddress));
        }
    }

    function _prepareBribes(address user, uint tokenId, IGauge gauge) internal {
        address bribeInternalAddress = gauge.internal_bribe();
        address bribeExternalAddress = gauge.external_bribe();

        IBribe internalBribe = IBribe(bribeInternalAddress);
        IBribe externalBribe = IBribe(bribeExternalAddress);

        uint rewardTokensInternal = internalBribe.rewardsListLength();
        uint rewardTokensExternal = externalBribe.rewardsListLength();

        //console2.log(" -- bribeInternalAddress:", bribeInternalAddress, rewardTokensInternal);
        //console2.log(" -- bribeExternalAddress:", bribeExternalAddress, rewardTokensExternal);

        address[] memory _rewardsInternal = new address[](rewardTokensInternal);
        address[] memory _rewardsExternal = new address[](rewardTokensExternal);

        for (uint j = 0; j < rewardTokensInternal; j++) {
            address token = internalBribe.rewards(j);
            if (token == address(0)) continue;
            _rewardsInternal[j] = token;
        }
        for (uint j = 0; j < rewardTokensExternal; j++) {
            address token = externalBribe.rewards(j);
            if (token == address(0)) continue;
            _rewardsExternal[j] = token;
        }

        _claimFeesFor(bribeInternalAddress, user, tokenId, _rewardsInternal);
        _claimFeesFor(bribeExternalAddress, user, tokenId, _rewardsExternal);
    }

    event ClaimFees(uint tokenId, address bribe, address token, uint amount, string symbol);

    function _claimFeesFor(address bribe, address user, uint tokenId, address[] memory tokens) internal
    {
        address[] memory _bribes = new address[](1);
        _bribes[0] = bribe;

        address[][] memory _tokens = new address[][](1);
        _tokens[0] = tokens;

        uint[] memory balancesBefore = new uint[](tokens.length);
        for (uint i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            balancesBefore[i] = token.balanceOf(user);
        }

        voter.claimFees(_bribes, _tokens, tokenId);

        uint[] memory balancesAfter = new uint[](tokens.length);
        for (uint i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            balancesAfter[i] = token.balanceOf(user);
            uint balanceDiff = balancesAfter[i] - balancesBefore[i];
            if (balanceDiff > 0) {
                console2.log("  -- claimFees reward:", token.symbol(), balanceDiff);
                emit ClaimFees(tokenId, bribe, tokens[i], balanceDiff, token.symbol());
            }
        }
    }

}
