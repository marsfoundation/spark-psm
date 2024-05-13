// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMConvertToSharesTests is PSMTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversion();
    }

    function testFuzz_convertToShares_noValue(uint256 amount) public view {
        assertEq(psm.convertToShares(amount), amount);
    }

    function test_convertToShares_depositAndWithdrawUsdcAndSDai_noChange() public {
        _assertOneToOneConversion();

        _deposit(address(this), address(usdc), 100e6);
        _assertOneToOneConversion();

        _deposit(address(this), address(sDai), 80e18);
        _assertOneToOneConversion();

        _withdraw(address(this), address(usdc), 100e6);
        _assertOneToOneConversion();

        _withdraw(address(this), address(sDai), 80e18);
        _assertOneToOneConversion();
    }

    function test_convertToShares_updateSDaiValue() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(this), address(usdc), 100e6);
        _deposit(address(this), address(sDai), 80e18);

        _assertOneToOneConversion();

        // 80 sDAI now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10.
        rateProvider.__setConversionRate(1.5e27);

        assertEq(psm.convertToShares(10), 9);
        assertEq(psm.convertToShares(11), 10);
        assertEq(psm.convertToShares(12), 10);

        assertEq(psm.convertToShares(1e18),   0.909090909090909090e18);
        assertEq(psm.convertToShares(1.1e18), 1e18);
        assertEq(psm.convertToShares(1.2e18), 1.090909090909090909e18);
    }

    function _assertOneToOneConversion() internal view {
        assertEq(psm.convertToShares(1), 1);
        assertEq(psm.convertToShares(2), 2);
        assertEq(psm.convertToShares(3), 3);
        assertEq(psm.convertToShares(4), 4);

        assertEq(psm.convertToShares(1e18), 1e18);
        assertEq(psm.convertToShares(2e18), 2e18);
        assertEq(psm.convertToShares(3e18), 3e18);
        assertEq(psm.convertToShares(4e18), 4e18);
    }

}

contract PSMConvertToSharesWithUsdcTests is PSMTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversionUsdc();
    }

    function testFuzz_convertToShares_noValue(uint256 amount) public view {
        amount = _bound(amount, 0, USDC_TOKEN_MAX);
        assertEq(psm.convertToShares(address(usdc), amount), amount * 1e12);
    }

    function test_convertToShares_depositAndWithdrawUsdcAndSDai_noChange() public {
        _assertOneToOneConversionUsdc();

        _deposit(address(this), address(usdc), 100e6);
        _assertOneToOneConversionUsdc();

        _deposit(address(this), address(sDai), 80e18);
        _assertOneToOneConversionUsdc();

        _withdraw(address(this), address(usdc), 100e6);
        _assertOneToOneConversionUsdc();

        _withdraw(address(this), address(sDai), 80e18);
        _assertOneToOneConversionUsdc();
    }

    function test_convertToShares_updateSDaiValue() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(this), address(usdc), 100e6);
        _deposit(address(this), address(sDai), 80e18);

        _assertOneToOneConversionUsdc();

        // 80 sDAI now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10.
        rateProvider.__setConversionRate(1.5e27);

        assertEq(psm.convertToShares(address(usdc), 10), 9.090909090909e12);
        assertEq(psm.convertToShares(address(usdc), 11), 10e12);
        assertEq(psm.convertToShares(address(usdc), 12), 10.909090909090e12);

        assertEq(psm.convertToShares(address(usdc), 10e6), 9.090909090909090909e18);
        assertEq(psm.convertToShares(address(usdc), 11e6), 10e18);
        assertEq(psm.convertToShares(address(usdc), 12e6), 10.909090909090909090e18);
    }

    function _assertOneToOneConversionUsdc() internal view {
        assertEq(psm.convertToShares(address(usdc), 1), 1e12);
        assertEq(psm.convertToShares(address(usdc), 2), 2e12);
        assertEq(psm.convertToShares(address(usdc), 3), 3e12);
        assertEq(psm.convertToShares(address(usdc), 4), 4e12);

        assertEq(psm.convertToShares(address(usdc), 1e6), 1e18);
        assertEq(psm.convertToShares(address(usdc), 2e6), 2e18);
        assertEq(psm.convertToShares(address(usdc), 3e6), 3e18);
        assertEq(psm.convertToShares(address(usdc), 4e6), 4e18);
    }

}

contract PSMConvertToSharesWithSDaiTests is PSMTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversion();
    }

    // TODO: Figure out growing diff
    // function testFuzz_convertToShares_noValue(uint256 amount) public view {
    //     amount = _bound(amount, 0, SDAI_TOKEN_MAX);
    //     assertApproxEqAbs(psm.convertToShares(address(sDai), amount), amount * 100/125, 2);
    // }

    function test_convertToShares_depositAndWithdrawUsdcAndSDai_noChange() public {
        _assertOneToOneConversion();

        _deposit(address(this), address(usdc), 100e6);
        _assertStartingConversionSDai();

        _deposit(address(this), address(sDai), 80e18);
        _assertStartingConversionSDai();

        _withdraw(address(this), address(usdc), 100e6);
        _assertStartingConversionSDai();

        _withdraw(address(this), address(sDai), 80e18);
        _assertStartingConversionSDai();
    }

    function test_convertToShares_updateSDaiValue() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(this), address(usdc), 100e6);
        _deposit(address(this), address(sDai), 80e18);

        _assertStartingConversionSDai();

        // 80 sDAI now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10. Since 1 sDAI is now worth 1.5 USDC, 1 sDAI is worth
        // 1.50/1.10 = 1.3636... shares
        rateProvider.__setConversionRate(1.5e27);

        // TODO: Reinvestigate this, interesting difference in rounding
        assertEq(psm.convertToShares(address(sDai), 1), 0);
        assertEq(psm.convertToShares(address(sDai), 2), 2);
        assertEq(psm.convertToShares(address(sDai), 3), 3);
        assertEq(psm.convertToShares(address(sDai), 4), 5);

        assertEq(psm.convertToShares(address(sDai), 1e18), 1.363636363636363636e18);
        assertEq(psm.convertToShares(address(sDai), 2e18), 2.727272727272727272e18);
        assertEq(psm.convertToShares(address(sDai), 3e18), 4.090909090909090909e18);
        assertEq(psm.convertToShares(address(sDai), 4e18), 5.454545454545454545e18);
    }

    function _assertOneToOneConversion() internal view {
        assertEq(psm.convertToShares(1), 1);
        assertEq(psm.convertToShares(2), 2);
        assertEq(psm.convertToShares(3), 3);
        assertEq(psm.convertToShares(4), 4);

        assertEq(psm.convertToShares(1e18), 1e18);
        assertEq(psm.convertToShares(2e18), 2e18);
        assertEq(psm.convertToShares(3e18), 3e18);
        assertEq(psm.convertToShares(4e18), 4e18);
    }

    // NOTE: This is different because the dollar value of sDAI is 1.25x that of USDC
    function _assertStartingConversionSDai() internal view {
        assertEq(psm.convertToShares(address(sDai), 1), 1);
        assertEq(psm.convertToShares(address(sDai), 2), 2);
        assertEq(psm.convertToShares(address(sDai), 3), 3);
        assertEq(psm.convertToShares(address(sDai), 4), 5);

        assertEq(psm.convertToShares(address(sDai), 1e18), 1.25e18);
        assertEq(psm.convertToShares(address(sDai), 2e18), 2.5e18);
        assertEq(psm.convertToShares(address(sDai), 3e18), 3.75e18);
        assertEq(psm.convertToShares(address(sDai), 4e18), 5e18);
    }

}

contract PSMConvertToAssetValueTests is PSMTestBase {

    function testFuzz_convertToAssetValue_noValue(uint256 amount) public view {
        assertEq(psm.convertToAssetValue(amount), amount);
    }

}

contract PSMConvertToAssetsTests is PSMTestBase {}


