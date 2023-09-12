// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {WrappedExternalBribe} from 'contracts/WrappedExternalBribe.sol';

contract WrappedExternalBribeFactory is Initializable {
    address public voter;
    mapping(address => address) public oldBribeToNew;
    address public last_bribe;

    function initialize(address _voter) external initializer {
        voter = _voter;
    }

    function createBribe(address existing_bribe) external returns (address) {
        require(
            oldBribeToNew[existing_bribe] == address(0),
            "Wrapped bribe already created"
        );
        last_bribe = address(new WrappedExternalBribe(voter, existing_bribe));
        oldBribeToNew[existing_bribe] = last_bribe;
        return last_bribe;
    }
}
