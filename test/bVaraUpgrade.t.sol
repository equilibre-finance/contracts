// 1:1 with Hardhat test
pragma solidity 0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Vara} from "contracts/Vara.sol";
import {bVaraImplementation} from "contracts/bVaraImplementation.sol";
import {ERC20} from 'lib/solmate/src/tokens/ERC20.sol';
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {VotingEscrow} from "contracts/VotingEscrow.sol";
import {Voter} from "contracts/Voter.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {InternalBribe} from "contracts/InternalBribe.sol";
import {ExternalBribe} from "contracts/ExternalBribe.sol";
import {Gauge} from "contracts/Gauge.sol";

import "forge-std/StdStorage.sol";

contract bVaraImplementationTest is Test {
    using stdStorage for StdStorage;
    using Strings for uint256;
    Vara private vara;
    bVaraImplementation private main;
    bVaraImplementation private implementation;
    VotingEscrow private ve;
    Voter private voter;
    TransparentUpgradeableProxy private proxy;
    ProxyAdmin private proxyAdmin;

    /// @dev the admin address only for proxy upgrade:
    address private proxyAdminAddress = address(0x52B9Ff6f13ca7A871a7112d2a3912adc07F054c4);
    address private admin = address(0x7cef2432A2690168Fb8eb7118A74d5f8EfF9Ef55);
    address private user = makeAddr("user");

    address private votingEscrow = 0x35361C9c2a324F5FB8f3aed2d7bA91CE1410893A;
    address private voterAddress = 0x4eB2B9768da9Ea26E3aBe605c9040bC12F236a59;
    address private varaAddress = 0xE1da44C0dA55B075aE8E2e4b6986AdC76Ac77d73;
    address private bVaraProxyAddress = 0x9d8054aaf108A5B5fb9fE27F89F3Db11E82fc94F;

    Gauge private gauge;
    ExternalBribe private bribe;
    address private poolAddress;
    address private gaugeAddress;

    function testUpgrade() public {

        // fork mainnet:
        vm.createSelectFork("mainnet", 6_358_000);
        assertEq(2222, block.chainid, "INVALID FORK NETWORK ID");

        vara = Vara(varaAddress);
        voter = Voter(voterAddress);
        ve = VotingEscrow(votingEscrow);
        proxyAdmin = new ProxyAdmin();

        /// @dev upgrade contract to:
        implementation = new bVaraImplementation();
        ITransparentUpgradeableProxy _proxy = ITransparentUpgradeableProxy(bVaraProxyAddress);
        vm.startPrank(proxyAdminAddress);
        _proxy.upgradeTo(address(implementation));
        vm.stopPrank();
        main = bVaraImplementation(address(_proxy));

        /// @dev whitelist admin, so admin can bribe:
        vm.startPrank(address(admin));
        main.setWhitelist(address(admin), true);
        vm.stopPrank();

        /// @dev let's vote:
        poolAddress = voter.pools(0);
        gaugeAddress = voter.gauges(poolAddress);

        gauge = Gauge(gaugeAddress);
        bribe = ExternalBribe(gauge.external_bribe());

        /// @dev: whitelist the bribe or user will not be able to claim:
        vm.startPrank(address(admin));
        main.setWhitelist(address(bribe), true);
        vm.stopPrank();

        /// @dev approve and add reward to bribe as bVara:
        address governor = voter.governor();
        vm.startPrank(governor);
        voter.whitelist(address(main));
        assertEq(voter.isWhitelisted(address(main)), true, "bVARA SHOULD BE WHITELISTED");
        vm.stopPrank();
    }

}
