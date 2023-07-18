// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

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
    function initialize(IVotes _ve) external initializer {
        __L2Governor_init("Vara Governor");
        __L2GovernorVotes_init(_ve);
        __L2GovernorVotesQuorumFraction_init(4); // 4%
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
}
