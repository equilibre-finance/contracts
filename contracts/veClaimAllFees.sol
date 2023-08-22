// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import {IVotingEscrow} from "contracts/interfaces/IVotingEscrow.sol";
import {IVoter} from "contracts/interfaces/IVoter.sol";
import {IPairFactory} from "contracts/interfaces/IPairFactory.sol";
import {IBribe} from "contracts/interfaces/IBribe.sol";
import {IERC20} from "contracts/interfaces/IERC20.sol";
import {IGauge} from "contracts/interfaces/IGauge.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title veClaimAllFees
 * @dev veClaimAllFees contract
 *      This contract allow users to claim all fees from all bribe contracts
 *      using a single transaction, this contract is used to subsidize the gas
 *      fees for the users that are in the auto-claim list.
 */
contract veClaimAllFees is Ownable {

    /// @dev mainnet addresses:
    IVotingEscrow public ve = IVotingEscrow(0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A);
    IVoter public voter = IVoter(0x4eB2B9768da9Ea26E3aBe605c9040bC12F236a59);
    IPairFactory public pairFactory = IPairFactory(0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95);

    /// @dev last claimed index for each token, used to continue process if we run out of gas:
    mapping(uint => uint) public lastClaimedIndex;

    /// @dev list of address in the auto-claim list, once user is added to this list
    ///      we call claimAllByTokenId() for user, so we subsidize the gas fees for the user:
    address[] public autoClaimAddresses;

    /// @dev status of each user is present in the auto-claim list:
    mapping(address => bool) public autoClaimStatus;

    /// @dev event emitted when a user claim fees:
    event ClaimFees(uint tokenId, address bribe, address token, uint amount, string symbol);

    /// @dev error messages:
    error NotApproved(address owner, address operator, uint tokenId);
    error InvalidTokenId(uint tokenId);
    error UserExists();
    error UserNtFound();
    error NotAuthorized();

    /// @dev list of all gauges and bribes, pre-computed to save gas, on each claim:
    address[] public gauges;
    address[] public bribes;
    uint public allPairsLength;
    uint public gaugesLength;
    uint public bribesLength;
    address[][] public rewardsByBribe;

    /// @dev max number of claims per transaction to avoid gas problem:
    uint public maxClaimPerTx = 100;

    /**
     * @dev used by our backend to check if we need to re-sync the list of gauges and bribes:
     */
    function needToSyncGauges() public view returns(bool){
        return allPairsLength != pairFactory.allPairsLength();
    }

    /**
     * @dev This function is called to re-sync the list of gauges and bribes,
     *      it is called from time to time from our backend to make sure
     *      we have the latest list of gauges and bribes.
     */
    function syncGauges() public {
        uint totalPools = pairFactory.allPairsLength();
        allPairsLength = totalPools;
        gauges = new address[](0);
        for (uint i = 0; i < totalPools; i++) {
            address pool = pairFactory.allPairs(i);
            address gaugeAddress = voter.gauges(pool);
            if (voter.gauges(pool) == address(0)) continue;
            gauges.push(gaugeAddress);
        }
        gaugesLength = gauges.length;
    }

    /// @dev used by our backend to check if we need to re-sync the list of bribes:
    function syncBribes() public {
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
    }

    /// @dev used by our backend to check if we need to re-sync the list of rewards:
    function syncRewards() public {
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

    /**
     * @dev claim all fees for a tokenId, this function is called from the auto-claim list,
     *      we use the lastClaimedIndex to continue the claim process if we run out of gas.
     *      Also, this function can be called by the ui too by any user.
     */
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

        uint claimed = 0;
        /// @dev claim until maxClaimPerTx:
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
            claimed++;
            if( claimed >= maxClaimPerTx )
                break;
        }

    }

    /// @dev modifier to check permission on user list operations:
    modifier onlyAutoClaimAddresses( address user ) {
        if( msg.sender != user &&
            msg.sender != owner() &&
            msg.sender != ve.team() &&
            ve.isApprovedForAll(user, msg.sender) == false )
            revert NotAuthorized();
        _;
    }

    /// @dev return the list of address in the auto-claim list:
    function autoClaimAddressesLength() public view returns(uint){
        return autoClaimAddresses.length;
    }

    /// @dev return the list of address in the auto-claim list:
    function getAllUsers() public view returns(address[] memory){
        return autoClaimAddresses;
    }

    /// @dev add a new address to the auto-claim, user must need some ETH to pay for the gas:
    function addToAutoClaimAddresses(address user) public onlyAutoClaimAddresses(user) {

        if( autoClaimStatus[user] == true )
            revert UserExists();

        autoClaimStatus[user] = true;
        autoClaimAddresses.push(user);

    }

    ///
    function removeFromAutoClaimAddresses(address user) public onlyAutoClaimAddresses(user) {

        if( autoClaimStatus[user] == false )
            revert UserNtFound();

        autoClaimStatus[user] = false;

        // remove user from the array list:
        for (uint i = 0; i < autoClaimAddresses.length; i++) {
            if( autoClaimAddresses[i] == user ){
                autoClaimAddresses[i] = autoClaimAddresses[autoClaimAddresses.length - 1];
                autoClaimAddresses.pop();
                break;
            }
        }
    }

    function setMaxClaimPerTx(uint _maxClaimPerTx) public onlyOwner {
        maxClaimPerTx = _maxClaimPerTx;
    }

}
