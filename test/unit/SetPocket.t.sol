// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMSetPocketFailureTests is PSMTestBase {

    function test_setPocket_invalidOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)",
            address(this))
        );
        psm.setPocket(address(1));
    }

    function test_setPocket_invalidPocket() public {
        vm.prank(owner);
        vm.expectRevert("PSM3/invalid-pocket");
        psm.setPocket(address(0));
    }

    function test_setPocket_samePocket() public {
        vm.prank(owner);
        vm.expectRevert("PSM3/same-pocket");
        psm.setPocket(pocket);
    }


    // NOTE: In practice this won't happen because pockets will infinite approve PSM
    function test_setPocket_insufficientAllowanceBoundary() public {
        address pocket1 = makeAddr("pocket1");
        address pocket2 = makeAddr("pocket2");

        vm.prank(owner);
        psm.setPocket(pocket1);

        vm.prank(pocket1);
        usdc.approve(address(psm), 1_000_000e6);

        deal(address(usdc), pocket1, 1_000_000e6 + 1);

        vm.prank(owner);
        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.setPocket(pocket2);

        deal(address(usdc), pocket1, 1_000_000e6);

        vm.prank(owner);
        psm.setPocket(pocket2);
    }

}

contract PSMSetPocketSuccessTests is PSMTestBase {

    address pocket1 = makeAddr("pocket1");
    address pocket2 = makeAddr("pocket2");

    event PocketSet(
        address indexed oldPocket,
        address indexed newPocket,
        uint256 amountTransferred
    );

    function test_setPocket_pocketIsPsm() public {
        deal(address(usdc), address(psm), 1_000_000e6);

        assertEq(usdc.balanceOf(address(psm)), 1_000_000e6);
        assertEq(usdc.balanceOf(pocket1),      0);

        assertEq(psm.pocket(), pocket);

        vm.prank(owner);
        vm.expectEmit(address(psm));
        emit PocketSet(pocket, pocket1, 1_000_000e6);
        psm.setPocket(pocket1);

        assertEq(usdc.balanceOf(address(psm)), 0);
        assertEq(usdc.balanceOf(pocket1),      1_000_000e6);

        assertEq(psm.pocket(), pocket1);
    }

    function test_setPocket_pocketIsNotPsm() public {
        vm.prank(owner);
        psm.setPocket(pocket1);

        vm.prank(pocket1);
        usdc.approve(address(psm), 1_000_000e6);

        deal(address(usdc), address(pocket1), 1_000_000e6);

        assertEq(usdc.allowance(pocket1, address(psm)), 1_000_000e6);

        assertEq(usdc.balanceOf(pocket1), 1_000_000e6);
        assertEq(usdc.balanceOf(pocket2), 0);

        assertEq(psm.totalAssets(), 0);

        assertEq(psm.pocket(), pocket1);

        vm.prank(owner);
        vm.expectEmit(address(psm));
        emit PocketSet(pocket1, pocket2, 1_000_000e6);
        psm.setPocket(pocket2);

        assertEq(usdc.allowance(pocket1, address(psm)), 0);

        assertEq(usdc.balanceOf(pocket1), 0);
        assertEq(usdc.balanceOf(pocket2), 1_000_000e6);

        assertEq(psm.totalAssets(), 0);

        assertEq(psm.pocket(), pocket2);
    }

    function test_setPocket_valueStaysConstant() public {
        // NOTE: Need to set pocket to PSM because setUp sets pocket to `pocket`, and zero funds
        //       are transferred from `pocket1` to `pocket`
        vm.prank(owner);
        psm.setPocket(address(psm));

        _deposit(address(usdc),  owner, 1_000_000e6);
        _deposit(address(usds),  owner, 1_000_000e18);
        _deposit(address(susds), owner, 800_000e18);

        assertEq(psm.totalAssets(), 3_000_000e18);

        vm.prank(owner);
        psm.setPocket(pocket1);

        assertEq(psm.totalAssets(), 2_000_000e18);
    }

}
