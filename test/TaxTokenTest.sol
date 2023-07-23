pragma solidity 0.8.13;

import './BaseTest.sol';
import "contracts/mock/TaxToken.sol";

contract TaxTokenTest is BaseTest {

    Pair _pair;
    TaxToken taxToken;

    uint TAX_TOKEN_100K = 100_000 * 1e9;
    uint TAX_TOKEN_1 = 1e9;
    uint TAX_TOKEN_100 = 100e9;
    uint TOKEN_100 = 100 * 1e18;
    uint liquidityAdded;
    function setUp() public {
        deployProxyAdmin();
        Pair implPair = new Pair();
        PairFactory implPairFactory = new PairFactory();
        proxy = new TransparentUpgradeableProxy(address(implPairFactory), address(admin), abi.encodeWithSelector(PairFactory.initialize.selector, address(implPair)));
        factory = PairFactory(address(proxy));
        
        WETH = new TestWETH();

        Router2 implRouter = new Router2();
        proxy = new TransparentUpgradeableProxy(address(implRouter), address(admin), abi.encodeWithSelector(Router.initialize.selector, address(factory), address(WETH)));
        router2 = Router2(payable(address(proxy)));

        taxToken = new TaxToken(address(this));
        taxToken.initialize(address(router2));
        _pair = Pair(factory.getPair(address(taxToken), address(WETH), false));
    }

    function testAddRemoveLiquidity() public {
        taxToken.approve(address(router2), TAX_TOKEN_100K);
        WETH.approve(address(router2), TOKEN_100);

        uint amountEthBefore = address(this).balance;
        (,, liquidityAdded) =
        router2.addLiquidityETH{value : TOKEN_100}(address(taxToken), false, TAX_TOKEN_100K, 0, 0, address(this), block.timestamp);
        uint amountEthAfter = address(this).balance;
        uint amountEthAdded = amountEthBefore - amountEthAfter;
        console2.log('amountEthBefore', amountEthBefore);
        console2.log('amountEthAfter', amountEthAfter);
        console2.log('amountEthAdded', amountEthAdded);
        assertEq(amountEthAfter, amountEthBefore - TOKEN_100);
        assertEq(amountEthAdded, TOKEN_100);

        _pair.approve(address(router2), liquidityAdded);
        router2.removeLiquidityETHSupportingFeeOnTransferTokens(address(taxToken), false, liquidityAdded, 0, 0, address(this), block.timestamp);
        uint amountEthAfterRemove = address(this).balance;
        console2.log('amountEthAfterRemove', amountEthAfterRemove);
        assertEq(amountEthAfterRemove, amountEthBefore-1000000);

    }

    function testSwap() public{

        taxToken.approve(address(router2), TAX_TOKEN_100K);
        WETH.approve(address(router2), TOKEN_100);

        uint amountEthBefore = address(this).balance;
        (,, liquidityAdded) =
        router2.addLiquidityETH{value : TOKEN_100}(address(taxToken), false, TAX_TOKEN_100K, 0, 0, address(this), block.timestamp);
        uint amountEthAfter = address(this).balance;
        uint amountEthAdded = amountEthBefore - amountEthAfter;
        console2.log('amountEthBefore', amountEthBefore);
        console2.log('amountEthAfter', amountEthAfter);
        console2.log('amountEthAdded', amountEthAdded);
        assertEq(amountEthAfter, amountEthBefore - TOKEN_100);
        assertEq(amountEthAdded, TOKEN_100);

        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(taxToken), address(WETH), false);
        uint256[] memory expectedOutput = router2.getAmountsOut(TAX_TOKEN_100, routes);
        taxToken.approve(address(router2), TAX_TOKEN_100);

        console2.log('tokenBalanceBeforeSwap', taxToken.balanceOf(address(this))/1e9);
        router2.swapExactTokensForETHSupportingFeeOnTransferTokens(TAX_TOKEN_100, expectedOutput[1], routes, address(this), block.timestamp);
        console2.log('expectedOutput token', expectedOutput[0]/1e9);
        console2.log('expectedOutput eth', expectedOutput[1]);
        console2.log('tokenBalanceAfterSwap', taxToken.balanceOf(address(this))/1e9);
        console2.log('amountEthAfterSwap', (address(this).balance - amountEthAfter));

        _pair.approve(address(router2), liquidityAdded);
        router2.removeLiquidityETHSupportingFeeOnTransferTokens(address(taxToken), false, liquidityAdded, 0, 0, address(this), block.timestamp);
        uint amountEthAfterRemove = address(this).balance;
        console2.log('amountTokenAfterRemove', taxToken.balanceOf(address(this)));
        console2.log('amountEthAfterRemove', amountEthAfterRemove/1e18);
        assertEq(amountEthAfterRemove, amountEthBefore - 999_004);

    }
}
