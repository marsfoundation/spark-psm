// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "src/PSM.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract PSMTestBase is Test {

    PSM public psm;

    // NOTE: Using sDAI and USDC as example assets
    MockERC20 public sDai;
    MockERC20 public usdc;

    MockRateProvider public rateProvider;

    modifier assertAtomicPsmValueDoesNotChange {
        uint256 beforeValue = _getPsmValue();
        _;
        assertEq(_getPsmValue(), beforeValue);
    }

    // 1,000,000,000,000 of each token
    uint256 public constant USDC_TOKEN_MAX = 1e18;
    uint256 public constant SDAI_TOKEN_MAX = 1e30;

    function setUp() public virtual {
        sDai = new MockERC20("sDai", "sDai", 18);
        usdc = new MockERC20("usdc", "usdc", 6);

        rateProvider = new MockRateProvider();

        // NOTE: Using 1.25 for easy two way conversions
        rateProvider.__setConversionRate(1.25e27);

        psm = new PSM(address(usdc), address(sDai), address(rateProvider));

        vm.label(address(sDai), "sDAI");
        vm.label(address(usdc), "USDC");
    }

    function _getPsmValue() internal view returns (uint256) {
        return (sDai.balanceOf(address(psm)) * rateProvider.getConversionRate() / 1e27)
            + usdc.balanceOf(address(psm)) * 1e12;
    }

    function _deposit(address user, address asset, uint256 amount) internal {
        vm.startPrank(user);
        MockERC20(asset).mint(user, amount);
        MockERC20(asset).approve(address(psm), amount);
        psm.deposit(asset, amount);
        vm.stopPrank();
    }

    function _withdraw(address user, address asset, uint256 amount) internal {
        vm.prank(user);
        psm.withdraw(asset, amount);
        vm.stopPrank();
    }

}
