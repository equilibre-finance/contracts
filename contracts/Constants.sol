// SPDX-License-Identifier: MIT
import {FullMath} from "contracts/libraries/FullMath.sol";
pragma solidity =0.8.13;
abstract contract Constants {

    // Algebra contracts:
    address wEthAddr = address(0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b);
    address factoryAddr = address(0xf20eD2e7856961FA8dba2530B604CE3E2076621E);
    address routerAddr = address(0x783aD1f0FCaF0e1ddb951826275E40E2e9596eE6);
    address positionAddr = address(0x678216C3BB2e2dECf866D13Cd61C7b32633055cb);

    function getSqrtPriceX96(uint256 amountA, uint256 amountB) internal pure returns (uint160) {
        bool scale = amountA >= 100e18 || amountB >= 100e18;
        // scaling down to 10x to avoid overflow
        amountA = scale ? amountA / 10 : amountA;
        amountB = scale ? amountB / 10 : amountB;
        uint256 ratioQ96 = FullMath.mulDiv(amountA, 1 << 192, amountB);
        //TODO: review as if we scale up it produces a too big amount of shares:
        //ratioQ96 = scale ? ratioQ96 * 10 : ratioQ96;
        return uint160(sqrt(ratioQ96));
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

}
