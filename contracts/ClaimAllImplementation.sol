// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IVotingEscrow} from "contracts/interfaces/IVotingEscrow.sol";
import {IVoter} from "contracts/interfaces/IVoter.sol";
import {IPairFactory} from "contracts/interfaces/IPairFactory.sol";
import {IBribe} from "contracts/interfaces/IBribe.sol";
import {IERC20} from "contracts/interfaces/IERC20.sol";
import {IGauge} from "contracts/interfaces/IGauge.sol";
import {IRewardsDistributor} from "contracts/interfaces/IRewardsDistributor.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title ClaimAllImplementation
 * @dev ClaimAllImplementation contract
 *      This contract allow users to claim all fees from all bribe contracts
 *      using a single transaction, this contract is used to subsidize the gas
 *      fees for the users that are in the auto-claim list.
 */
contract ClaimAllImplementation is Initializable, OwnableUpgradeable {

    /// @dev mainnet addresses:
    IVotingEscrow internal ve;
    IVoter internal voter;
    IPairFactory internal pairFactory;
    IRewardsDistributor internal rewards;

    event Claimed(address indexed _address, uint256 _tokenId, uint256 _claimable, uint256 _claimed);
    event AutoClaimStatus(address indexed _address, bool _status);

    function initialize() initializer public {

        __Ownable_init();

        ve = IVotingEscrow(0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A);
        voter = IVoter(0x4eB2B9768da9Ea26E3aBe605c9040bC12F236a59);
        pairFactory = IPairFactory(0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95);
        rewards = IRewardsDistributor(0x8825be873e6578F1703628281600d5887C41C55A);

    }

    /// @dev list of address in the auto-claim list, once user is added to this list
    ///      we call claimAllByTokenId() for user, so we subsidize the gas fees for the user:
    address[] public autoClaimAddresses;

    /// @dev status of each user is present in the auto-claim list:
    mapping(address => bool) public autoClaimStatus;

    /// @dev error messages:
    error NotApproved(address owner, address operator, uint tokenId);
    error InvalidTokenId(uint tokenId);
    error UserExists();
    error UserNtFound();
    error NotAuthorized();

    /// @dev modifier to check permission on user list operations:
    modifier onlyAutoClaimAddresses(address user) {
        if (msg.sender != user &&
        msg.sender != owner() &&
        msg.sender != ve.team() &&
            ve.isApprovedForAll(user, msg.sender) == false)
            revert NotAuthorized();
        _;
    }

    /// @dev return the list of address in the auto-claim list:
    function autoClaimAddressesLength() public view returns (uint){
        return autoClaimAddresses.length;
    }

    /// @dev return the list of address in the auto-claim list:
    function getAllUsers() public view returns (address[] memory){
        return autoClaimAddresses;
    }

    /// @dev add a new address to the auto-claim, user must need some ETH to pay for the gas:
    function addToAutoClaimAddresses(address user) public onlyAutoClaimAddresses(user) {

        if (autoClaimStatus[user] == true)
            revert UserExists();

        autoClaimStatus[user] = true;
        autoClaimAddresses.push(user);

        emit AutoClaimStatus(user, true);

    }

    /// @dev remove an address from the auto-claim list:
    function removeFromAutoClaimAddresses(address user) public onlyAutoClaimAddresses(user) {

        if (autoClaimStatus[user] == false)
            revert UserNtFound();

        autoClaimStatus[user] = false;

        // remove user from the array list:
        for (uint i = 0; i < autoClaimAddresses.length; i++) {
            if (autoClaimAddresses[i] == user) {
                autoClaimAddresses[i] = autoClaimAddresses[autoClaimAddresses.length - 1];
                autoClaimAddresses.pop();
                emit AutoClaimStatus(user, false);
                break;
            }
        }
    }

    /// @dev this is just an alias that allow user to approve this contract to claim fees on his behalf:
    function claimFees(address[] memory _fees, address[][] memory _tokens, uint _tokenId) external {
        /// @dev check approval:
        if (ve.isApprovedForAll(ve.ownerOf(_tokenId), address(this)) == false &&
            ve.getApproved(_tokenId) != address(this)) {
            revert NotApproved(msg.sender, address(this), _tokenId);
        }
        voter.claimFees(_fees, _tokens, _tokenId);
    }

    /// @dev claim all reward from all tokenIds:
    function claimRewards(address _address) public {
        uint balanceOf = ve.balanceOf(_address);
        for (uint i = 0; i < balanceOf; i++) {
            uint tokenId = ve.tokenOfOwnerByIndex(_address, i);
            uint claimable = rewards.claimable(tokenId);
            if( claimable > 0 ){
                uint claimed = rewards.claim(tokenId);
                emit Claimed(_address, tokenId, claimable, claimed);
            }
        }

    }
}
