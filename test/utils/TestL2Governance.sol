// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "contracts/governance/L2Governor.sol";
import "contracts/governance/L2GovernorVotes.sol";
import "contracts/governance/L2GovernorCountingSimple.sol";
import "contracts/governance/L2GovernorVotesQuorumFraction.sol";

contract TestL2Governance is
    Initializable,
    L2Governor,
    L2GovernorVotes,
    L2GovernorCountingSimple,
    L2GovernorVotesQuorumFraction
{
    address public team;
    function initialize(IVotes _ve) external initializer {
        __L2Governor_init("TestL2Governor");
        __L2GovernorVotes_init(_ve);
        __L2GovernorVotesQuorumFraction_init(4); // 4%
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
