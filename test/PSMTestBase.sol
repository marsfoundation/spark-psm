// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract PSMTestBase is Test {

    address public owner  = makeAddr("owner");
    address public pocket = makeAddr("pocket");

    PSM3 public psm;

    MockERC20 public usdc;
    MockERC20 public usds;
    MockERC20 public susds;

    IRateProviderLike public rateProvider;  // Can be overridden by ssrOracle using same interface

    MockRateProvider public mockRateProvider;  // Interface used for mocking

    modifier assertAtomicPsmValueDoesNotChange {
        uint256 beforeValue = _getPsmValue();
        _;
        assertEq(_getPsmValue(), beforeValue);
    }

    // 1,000,000,000,000 of each token
    uint256 public constant USDS_TOKEN_MAX  = 1e30;
    uint256 public constant SUSDS_TOKEN_MAX = 1e30;
    uint256 public constant USDC_TOKEN_MAX  = 1e18;

    function setUp() public virtual {
        usdc  = new MockERC20("usdc",  "usdc",  6);
        usds  = new MockERC20("usds",  "usds",  18);
        susds = new MockERC20("susds", "susds", 18);

        mockRateProvider = new MockRateProvider();

        // NOTE: Using 1.25 for easy two way conversions
        mockRateProvider.__setConversionRate(1.25e27);

        rateProvider = IRateProviderLike(address(mockRateProvider));

        psm = new PSM3(owner, address(usdc), address(usds), address(susds), address(rateProvider));

        vm.prank(owner);
        psm.setPocket(pocket);

        vm.prank(pocket);
        usdc.approve(address(psm), type(uint256).max);

        vm.label(address(usds),  "USDS");
        vm.label(address(usdc),  "USDC");
        vm.label(address(susds), "sUSDS");
    }

    function _getPsmValue() internal view returns (uint256) {
        return (susds.balanceOf(address(psm)) * rateProvider.getConversionRate() / 1e27)
            + usdc.balanceOf(psm.pocket()) * 1e12
            + usds.balanceOf(address(psm));
    }

    function _deposit(address asset, address user, uint256 amount) internal {
        _deposit(asset, user, user, amount);
    }

    function _deposit(address asset, address user, address receiver, uint256 amount) internal {
        vm.startPrank(user);
        MockERC20(asset).mint(user, amount);
        MockERC20(asset).approve(address(psm), amount);
        psm.deposit(asset, receiver, amount);
        vm.stopPrank();
    }

    function _withdraw(address asset, address user, uint256 amount) internal {
        _withdraw(asset, user, user, amount);
    }

    function _withdraw(address asset, address user, address receiver, uint256 amount) internal {
        vm.prank(user);
        psm.withdraw(asset, receiver, amount);
        vm.stopPrank();
    }

}
