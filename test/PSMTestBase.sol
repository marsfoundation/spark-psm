// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "src/PSM.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract PSMTestBase is Test {

    PSM public psm;

    // NOTE: Using DAI, sDAI and USDC as example assets
    MockERC20 public dai;
    MockERC20 public usdc;
    MockERC20 public sDai;

    MockRateProvider public rateProvider;

    modifier assertAtomicPsmValueDoesNotChange {
        uint256 beforeValue = _getPsmValue();
        _;
        assertEq(_getPsmValue(), beforeValue);
    }

    // 1,000,000,000,000 of each token
    uint256 public constant USDC_TOKEN_MAX = 1e18;
    uint256 public constant SDAI_TOKEN_MAX = 1e30;
    uint256 public constant DAI_TOKEN_MAX  = 1e30;

    function setUp() public virtual {
        dai  = new MockERC20("dai",  "dai",  18);
        usdc = new MockERC20("usdc", "usdc", 6);
        sDai = new MockERC20("sDai", "sDai", 18);

        rateProvider = new MockRateProvider();

        // NOTE: Using 1.25 for easy two way conversions
        rateProvider.__setConversionRate(1.25e27);

        psm = new PSM(address(dai), address(usdc), address(sDai), address(rateProvider), 1000);

        vm.label(address(dai),  "DAI");
        vm.label(address(usdc), "USDC");
        vm.label(address(sDai), "sDAI");
    }

    // TODO: Refactor for three assets
    function _getPsmValue() internal view returns (uint256) {
        return (sDai.balanceOf(address(psm)) * rateProvider.getConversionRate() / 1e27)
            + usdc.balanceOf(address(psm)) * 1e12
            + dai.balanceOf(address(psm));
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
