// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/Vault.sol";

// VaultManager is used to manage vaults for different lp, tick pairs
contract VaultFactory is Ownable {
    /// vault address per each tick range & fee pair
    mapping(int24 => mapping(int24 => mapping(uint24 => address))) public vaults;

    event VaultCreated(address indexed vault, int24 lowerTick, int24 upperTick, uint24 fee);

    function createVault(
        address token0,
        address token1,
        int24 lowerTick,
        int24 upperTick,
        uint24 fee
    ) external onlyOwner returns (Vault vault) {
        require(vaults[lowerTick][upperTick][fee] == address(0), "vault exists");
        vault = new Vault(token0, token1, lowerTick, upperTick, fee);
        vaults[lowerTick][upperTick][fee] = address(vault);
        emit VaultCreated(address(vault), lowerTick, upperTick, fee);
    }
}
