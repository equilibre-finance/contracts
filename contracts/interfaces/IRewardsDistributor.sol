// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IRewardsDistributor {
    function checkpoint_token() external;
    function checkpoint_total_supply() external;
    function claimable(uint) external view returns (uint256);
    function claim(uint _tokenId) external returns (uint);
}
