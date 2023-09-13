// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWrappedExternalBribeFactory {
    function oldBribeToNew(address _bribe) external view returns (address);
}