// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "contracts/interfaces/IBribeFactory.sol";
import 'contracts/InternalBribe.sol';
import 'contracts/ExternalBribe.sol';

contract BribeFactory is OwnableUpgradeable, IBribeFactory {
    enum BribeType {
        Internal,
        External
    }

    address public last_internal_bribe;
    address public last_external_bribe;
    UpgradeableBeacon internalBeacon;
    UpgradeableBeacon externalBeacon;
    
    event BeaconUpdated(address indexed implGauge, BribeType _type);

    function initialize(address implInternalBribe, address implExternalBribe) external initializer {
        __Ownable_init();
        internalBeacon = new UpgradeableBeacon(implInternalBribe);
        externalBeacon = new UpgradeableBeacon(implExternalBribe);
    }

    function createInternalBribe(address[] memory allowedRewards) external returns (address) {
        last_internal_bribe = address(new BeaconProxy(address(internalBeacon), 
            abi.encodeWithSelector(InternalBribe.initialize.selector, msg.sender, allowedRewards)
        ));
        return last_internal_bribe;
    }

    function createExternalBribe(address[] memory allowedRewards) external returns (address) {
        last_external_bribe = address(new BeaconProxy(address(externalBeacon), 
            abi.encodeWithSelector(ExternalBribe.initialize.selector, msg.sender, allowedRewards)
        ));
        return last_external_bribe;
    }

    function updateBeacon(address implBribe, BribeType _type) external onlyOwner {
        if(_type == BribeType.Internal) internalBeacon.upgradeTo(implBribe);
        else externalBeacon.upgradeTo(implBribe);
        emit BeaconUpdated(implBribe, _type);
    }
}
