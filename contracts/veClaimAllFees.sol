pragma solidity 0.8.13;
import {VotingEscrow} from "contracts/VotingEscrow.sol";
import {Voter} from "contracts/Voter.sol";
import {PairFactory} from "contracts/factories/PairFactory.sol";
import {IBribe} from "contracts/interfaces/IBribe.sol";
import {IERC20} from "contracts/interfaces/IERC20.sol";
import {IGauge} from "contracts/interfaces/IGauge.sol";

contract veClaimAllFees {
    VotingEscrow public ve;
    Voter public voter;
    PairFactory public pairFactory;

    address public veAddress = 0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A;
    address public voterAddress = 0x4eB2B9768da9Ea26E3aBe605c9040bC12F236a59;
    address public pairFactoryAddress = 0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95;

    event ClaimFees(uint tokenId, address bribe, address token, uint amount, string symbol);
    error NotApproved(address owner, address operator, uint tokenId);
    error InvalidTokenId(uint tokenId);

    constructor(){
        ve = VotingEscrow(veAddress);
        voter = Voter(voterAddress);
        pairFactory = PairFactory(pairFactoryAddress);
    }

    address[] public gauges;
    address[] public bribes;

    uint public allPairsLength;
    uint public gaugesLength;
    uint public bribesLength;
    address[][] public rewardsByBribe;

    function syncGauges() public {
        uint totalPools = pairFactory.allPairsLength();
        if( allPairsLength == totalPools )
            return;
        allPairsLength = totalPools;
        gauges = new address[](0);
        for (uint i = 0; i < totalPools; i++) {
            address pool = pairFactory.allPairs(i);
            address gaugeAddress = voter.gauges(pool);
            if (voter.gauges(pool) == address(0)) continue;
            gauges.push(gaugeAddress);
        }
        gaugesLength = gauges.length;

        bribes = new address[](0);
        for (uint i = 0; i < gaugesLength; i++) {
            address bribeInternalAddress = IGauge(gauges[i]).internal_bribe();
            address bribeExternalAddress = IGauge(gauges[i]).external_bribe();
            if (bribeInternalAddress != address(0)){
                bribes.push(bribeInternalAddress);
            }
            if (bribeExternalAddress != address(0)){
                bribes.push(bribeExternalAddress);
            }
        }

        bribesLength = bribes.length;
        rewardsByBribe = new address[][](bribesLength);
        for (uint i = 0; i < bribesLength; i++) {
            address bribe = bribes[i];
            uint bribeTokens = IBribe(bribe).rewardsListLength();
            for (uint j = 0; j < bribeTokens; j++) {
                address token = IBribe(bribe).rewards(j);
                if (token == address(0)){
                    continue;
                }
                rewardsByBribe[i].push(token);
            }
        }

    }

    function claimByAddress(address user) public {
        uint userTokens = ve.balanceOf(user);
        for (uint i = 0; i < userTokens; i++) {
            uint tokenId = ve.tokenOfOwnerByIndex(user, i);
            claimAllByTokenId(tokenId);
        }
    }

    mapping(uint => uint) public lastClaimedIndex;
    function claimAllByTokenId(uint tokenId) public {

        address user = ve.ownerOf(tokenId);

        if( user == address(0) )
            revert InvalidTokenId(tokenId);

        if( ve.getApproved(tokenId) != address(this) &&
            ve.isApprovedForAll(user, address(this)) == false )
            revert NotApproved(user, address(this), tokenId);

        /// @dev check and reset last claimed index of this token,
        ///      this allow us to restart the claim process if we run out of gas
        if( lastClaimedIndex[tokenId] >= bribesLength )
            lastClaimedIndex[tokenId] = 0;

        for (uint i = lastClaimedIndex[tokenId]; i < bribesLength; i++) {
            address[] memory bribe = new address[](1);
            bribe[0] = bribes[i];
            address[][] memory tokens = new address[][](1);
            tokens[0] = rewardsByBribe[i];

            /// @dev claim fees on a try as may a token can cause problems
            ///     if it fails we will try again on the next claim
            try voter.claimFees(bribe, tokens, tokenId) {
                emit ClaimFees(tokenId, bribes[i], address(0), 0, "");
            } catch {
                continue;
            }
            lastClaimedIndex[tokenId] = i;

            /// @dev if we are running out of gas, stop the claim process
            ///      and wait for the next claim
            if( gasleft() * 100 / block.gaslimit < 5 )
                return;

        }

    }

}
