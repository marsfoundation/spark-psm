// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockRateProvider, PSMTestBase } from "test/PSMTestBase.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

contract RoundingTests is PSMTestBase {

    address user = makeAddr("user");

    function setUp() public override {
        super.setUp();

        // Seed the PSM with max liquidity so withdrawals can always be performed
        _deposit(address(usds),  address(this), USDS_TOKEN_MAX);
        _deposit(address(susds), address(this), SUSDS_TOKEN_MAX);
        _deposit(address(usdc),  address(this), USDC_TOKEN_MAX);

        // Set an exchange rate that will cause rounding
        mockRateProvider.__setConversionRate(1.25e27 * uint256(100) / 99);
    }

    function test_roundAgainstUser_usds() public {
        _deposit(address(usds), address(user), 1e18);

        assertEq(usds.balanceOf(address(user)), 0);

        vm.prank(user);
        psm.withdraw(address(usds), address(user), 1e18);

        assertEq(usds.balanceOf(address(user)), 1e18 - 1);  // Rounds against user
    }

    function test_roundAgainstUser_usdc() public {
        _deposit(address(usdc), address(user), 1e6);

        assertEq(usdc.balanceOf(address(user)), 0);

        vm.prank(user);
        psm.withdraw(address(usdc), address(user), 1e6);

        assertEq(usdc.balanceOf(address(user)), 1e6 - 1);  // Rounds against user
    }

    function test_roundAgainstUser_susds() public {
        _deposit(address(susds), address(user), 1e18);

        assertEq(susds.balanceOf(address(user)), 0);

        vm.prank(user);
        psm.withdraw(address(susds), address(user), 1e18);

        assertEq(susds.balanceOf(address(user)), 1e18 - 1);  // Rounds against user
    }

    function testFuzz_roundingAgainstUser_multiUser_usds(
        uint256 rate1,
        uint256 rate2,
        uint256 amount1,
        uint256 amount2
    )
        public
    {
        _runRoundingAgainstUsersFuzzTest(
            usds,
            USDS_TOKEN_MAX,
            rate1,
            rate2,
            amount1,
            amount2,
            4
        );
    }

    function testFuzz_roundingAgainstUser_multiUser_usdc(
        uint256 rate1,
        uint256 rate2,
        uint256 amount1,
        uint256 amount2
    )
        public
    {
        _runRoundingAgainstUsersFuzzTest(
            usdc,
            USDC_TOKEN_MAX,
            rate1,
            rate2,
            amount1,
            amount2,
            1  // Lower precision so rounding errors are lower
        );
    }

    function testFuzz_roundingAgainstUser_multiUser_susds(
        uint256 rate1,
        uint256 rate2,
        uint256 amount1,
        uint256 amount2
    )
        public
    {
        _runRoundingAgainstUsersFuzzTest(
            susds,
            SUSDS_TOKEN_MAX,
            rate1,
            rate2,
            amount1,
            amount2,
            4  // susds has higher rounding errors that can be introduced because of rate conversion
        );
    }

    function _runRoundingAgainstUsersFuzzTest(
        MockERC20 asset,
        uint256   tokenMax,
        uint256   rate1,
        uint256   rate2,
        uint256   amount1,
        uint256   amount2,
        uint256   roundingTolerance
    ) internal {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        rate1 = _bound(rate1, 1e27,  10e27);
        rate2 = _bound(rate2, rate1, 10e27);

        amount1 = _bound(amount1, 1, tokenMax);
        amount2 = _bound(amount2, 1, tokenMax);

        mockRateProvider.__setConversionRate(rate1);

        _deposit(address(asset), address(user1), amount1);

        assertEq(asset.balanceOf(address(user1)), 0);

        vm.prank(user1);
        psm.withdraw(address(asset), address(user1), amount1);

        // Rounds against user up to one unit, always rounding down
        assertApproxEqAbs(asset.balanceOf(address(user1)), amount1, roundingTolerance);
        assertLe(asset.balanceOf(address(user1)), amount1);

        mockRateProvider.__setConversionRate(rate2);

        _deposit(address(asset), address(user2), amount2);

        assertEq(asset.balanceOf(address(user2)), 0);

        vm.prank(user2);
        psm.withdraw(address(asset), address(user2), amount2);

        // Rounds against user up to one unit, always rounding down

        assertApproxEqAbs(asset.balanceOf(address(user2)), amount2, roundingTolerance);
        assertLe(asset.balanceOf(address(user2)), amount2);
    }
}
