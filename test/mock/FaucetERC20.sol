// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FaucetERC20 is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 value
    ) ERC20(name, symbol) {
        if( value > 0 ){
            _mint(msg.sender, value);
        }
    }
    function mint(uint256 value) public onlyOwner {
        _mint(msg.sender, value);
    }
}
