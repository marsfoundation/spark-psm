// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockERC20, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMEventTests is PSMTestBase {

    event Swap(
        address indexed assetIn,
        address indexed assetOut,
        address sender,
        address indexed receiver,
        uint256 amountIn,
        uint256 amountOut,
        uint256 referralCode
    );

    event Deposit(
        address indexed asset,
        address indexed user,
        address indexed receiver,
        uint256 assetsDeposited,
        uint256 sharesMinted
    );

    event Withdraw(
        address indexed asset,
        address indexed user,
        address indexed receiver,
        uint256 assetsWithdrawn,
        uint256 sharesBurned
    );

    address sender   = makeAddr("sender");
    address receiver = makeAddr("receiver");

    function test_deposit_events() public {
        vm.startPrank(sender);

        usds.mint(sender, 100e18);
        usds.approve(address(psm), 100e18);

        vm.expectEmit(address(psm));
        emit Deposit(address(usds), sender, receiver, 100e18, 100e18);
        psm.deposit(address(usds), receiver, 100e18);

        usdc.mint(sender, 100e6);
        usdc.approve(address(psm), 100e6);

        vm.expectEmit(address(psm));
        emit Deposit(address(usdc), sender, receiver, 100e6, 100e18);
        psm.deposit(address(usdc), receiver, 100e6);

        susds.mint(sender, 100e18);
        susds.approve(address(psm), 100e18);

        vm.expectEmit(address(psm));
        emit Deposit(address(susds), sender, receiver, 100e18, 125e18);
        psm.deposit(address(susds), receiver, 100e18);
    }

    function test_withdraw_events() public {
        _deposit(address(usds),  sender, 100e18);
        _deposit(address(usdc), sender, 100e6);
        _deposit(address(susds), sender, 100e18);

        vm.startPrank(sender);

        vm.expectEmit(address(psm));
        emit Withdraw(address(usds), sender, receiver, 100e18, 100e18);
        psm.withdraw(address(usds), receiver, 100e18);

        vm.expectEmit(address(psm));
        emit Withdraw(address(usdc), sender, receiver, 100e6, 100e18);
        psm.withdraw(address(usdc), receiver, 100e6);

        vm.expectEmit(address(psm));
        emit Withdraw(address(susds), sender, receiver, 100e18, 125e18);
        psm.withdraw(address(susds), receiver, 100e18);
    }

    function test_swap_events() public {
        usds.mint(address(psm),  1000e18);
        usdc.mint(pocket, 1000e6);
        susds.mint(address(psm), 1000e18);

        vm.startPrank(sender);

        _swapEventTest(address(usds), address(usdc),  100e18, 100e6, 1);
        _swapEventTest(address(usds), address(susds), 100e18, 80e18, 2);

        _swapEventTest(address(usdc), address(usds),  100e6, 100e18, 3);
        _swapEventTest(address(usdc), address(susds), 100e6, 80e18,  4);

        _swapEventTest(address(susds), address(usds), 100e18, 125e18, 5);
        _swapEventTest(address(susds), address(usdc), 100e18, 125e6,  6);
    }

    function _swapEventTest(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 expectedAmountOut,
        uint16  referralCode
    ) internal {
        MockERC20(assetIn).mint(sender, amountIn);
        MockERC20(assetIn).approve(address(psm), amountIn);

        vm.expectEmit(address(psm));
        emit Swap(assetIn, assetOut, sender, receiver, amountIn, expectedAmountOut, referralCode);
        psm.swapExactIn(assetIn, assetOut, amountIn, 0, receiver, referralCode);
    }

}
