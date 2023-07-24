pragma solidity 0.8.13;

import './BaseTest.sol';
import "contracts/EquilibreTvlOracle.sol";
import "contracts/Vara.sol";

contract EquilibreTvlOracleTest is BaseTest {
    uint TOKEN_100 = 100 * 1e18;
    uint TOKEN_100e6 = 100 * 1e6;
    EquilibreTvlOracle oracle;
    EquilibreTvlOracle oracle_vara;
    Pair poolVara;
    function setUp() public {
        deployProxyAdmin();
        deployCoins();
        Pair implPair = new Pair();
        PairFactory implPairFactory = new PairFactory();
        proxy = new TransparentUpgradeableProxy(address(implPairFactory), address(admin), abi.encodeWithSelector(PairFactory.initialize.selector, address(implPair)));
        factory = PairFactory(address(proxy));

        Router2 implRouter2 = new Router2();
        proxy = new TransparentUpgradeableProxy(address(implRouter2), address(admin), abi.encodeWithSelector(Router.initialize.selector, address(factory), address(WETH)));
        router2 = Router2(payable(address(proxy)));

        // weth/usdc
        USDC.mint(address(this), TOKEN_100e6);
        USDC.approve(address(router2), TOKEN_100e6);
        router2.addLiquidityETH{value : TOKEN_100}(address(USDC), false, TOKEN_100e6, 0, 0, address(this), block.timestamp);
        pair = Pair(factory.getPair(address(USDC), address(WETH), false));

        // vara/usdc
        USDC.mint(address(this), TOKEN_100e6);
        USDC.approve(address(router2), TOKEN_100e6);
        VARA.mint(address(this), TOKEN_100);
        VARA.approve(address(router2), TOKEN_100);
        router2.addLiquidity(address(VARA), address(USDC), false, TOKEN_100, TOKEN_100e6, 0, 0, address(this), block.timestamp);
        poolVara = Pair(factory.getPair(address(USDC), address(VARA), false));

        address[3] memory uwl = [address(USDC), address(WETH), address(pair)];
        oracle = new EquilibreTvlOracle(uwl, 6);

        address[3] memory uwl_vara = [address(USDC), address(VARA), address(poolVara)];
        oracle_vara = new EquilibreTvlOracle(uwl_vara, 6);

    }

    function testCmd() public{
        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(WETH), address(USDC), false);
        router2.swapExactETHForTokensSupportingFeeOnTransferTokens{value: TOKEN_1}(0, routes, address(this), block.timestamp);

        uint price_eth = oracle.p_t_coin_usd(address(pair));
        console2.log('eth/usdc price', price_eth);

        uint price_vara = oracle.p_t_coin_usd(address(poolVara));
        console2.log('vara/usdc price', price_vara);

    }
}
