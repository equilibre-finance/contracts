// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (governance/extensions/GovernorVotes.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {L2Governor} from "contracts/governance/L2Governor.sol";

/**
 * @author Modified from RollCall (https://github.com/withtally/rollcall/blob/main/src/standards/L2GovernorVotes.sol)
 *
 * @dev Extension of {Governor} for voting weight extraction from an {ERC20Votes} token, or since v4.5 an {ERC721Votes} token.
 *
 * _Available since v4.3._
 */
abstract contract L2GovernorVotes is Initializable, L2Governor {
    IVotes public token;

    function __L2GovernorVotes_init(IVotes tokenAddress) internal onlyInitializing {
        __L2GovernorVotes_init_unchained(tokenAddress);
    }

    function __L2GovernorVotes_init_unchained(IVotes tokenAddress) internal onlyInitializing {
        token = tokenAddress;
    }
    /**
     * Read the voting weight from the token's built in snapshot mechanism (see {Governor-_getVotes}).
     */
    function _getVotes(
        address account,
        uint256 blockTimestamp,
        bytes memory /*params*/
    ) internal view virtual override returns (uint256) {
        return token.getPastVotes(account, blockTimestamp);
    }
}
