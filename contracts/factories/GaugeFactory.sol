// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import 'contracts/interfaces/IGaugeFactory.sol';
import 'contracts/Gauge.sol';

contract GaugeFactory is OwnableUpgradeable, IGaugeFactory {
    address public last_gauge;
    UpgradeableBeacon beacon;
    
    event BeaconUpdated(address indexed implGauge);

    function initialize(address implGauge) external initializer {
        __Ownable_init();
        beacon = new UpgradeableBeacon(implGauge);
    }

    function createGauge(address _pool, address _internal_bribe, address _external_bribe, address _ve, bool isPair, address[] memory allowedRewards) external returns (address) {
        last_gauge = address(new BeaconProxy(address(beacon), 
            abi.encodeWithSelector(Gauge.initialize.selector, _pool, _internal_bribe, _external_bribe, _ve, msg.sender, isPair, allowedRewards)
        ));
        return last_gauge;
    }

    function updateBeacon(address implGauge) external onlyOwner {
        beacon.upgradeTo(implGauge);
        emit BeaconUpdated(implGauge);
    }
}
