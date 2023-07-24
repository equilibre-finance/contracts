// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "contracts/governance/L2Governor.sol";
import "contracts/governance/L2GovernorVotes.sol";
import "contracts/governance/L2GovernorCountingSimple.sol";
import "contracts/governance/L2GovernorVotesQuorumFraction.sol";

contract TestL2Governance is
    L2Governor,
    L2GovernorVotes,
    L2GovernorCountingSimple,
    L2GovernorVotesQuorumFraction
{
    address public team;
    constructor(IVotes _token)
        L2Governor("TestL2Governor")
        L2GovernorVotes(_token)
        L2GovernorVotesQuorumFraction(4)
    {
        team = _msgSender();
    }

    function votingDelay() public pure override returns (uint256) {
        return 1;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 7;
    }

    function proposalThreshold() public pure override returns (uint256) {
        return 0;
    }

    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public override returns (uint256) {
        require( _msgSender() == team, "Governor: not team");
        return _cancel(targets, values, calldatas, descriptionHash);
    }

}
