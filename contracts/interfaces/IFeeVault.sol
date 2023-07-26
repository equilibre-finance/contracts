// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IFeeVault {
    function claimFees() external returns (uint256, uint256);
    function tokens() external view returns (address, address);
}
