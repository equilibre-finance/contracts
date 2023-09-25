// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ERC20} from '../lib/solmate/src/tokens/ERC20.sol';
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {bVaraImplementation} from "contracts/bVaraImplementation.sol";
import {IVotingEscrow} from "contracts/interfaces/IVotingEscrow.sol";

contract bVaraMock is bVaraImplementation {
    function initialize( ERC20 _asset, address _ve ) initializer public {

        __OFTUpgradeable_init("bVara Token", "bVARA", address(0));

        asset = _asset;
        ve = IVotingEscrow(_ve);

        /// @dev set default values for proxy:
        minWithdrawDays = 90 days;
        maxPenaltyPct = 90;

        /// @dev set owner as whiteListed:
        whiteList[_msgSender()] = true;
        emit WhiteList(_msgSender(), true);

        /// @dev whitelist 0 address as it is the minter:
        whiteList[address(0)] = true;
        emit WhiteList(address(0), true);

    }
}