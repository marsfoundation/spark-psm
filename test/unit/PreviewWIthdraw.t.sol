// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockRateProvider, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMPreviewWithdraw_FailureTests is PSMTestBase {

    function test_previewWithdraw_invalidAsset() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewWithdraw(makeAddr("other-token"), 1);
    }

}

contract PSMPreviewWithdraw_SuccessTests is PSMTestBase {

    function setUp() public override {
        super.setUp();
        _deposit(address(this),          address(dai),  100e18);
        _deposit(makeAddr("other-user"), address(usdc), 10e6);
    }

    function test_previewWithdraw_amountLtPsmBalance_amountLtShares() public {
        assertEq(psm.previewWithdraw(address(dai),  1), 1);


    }
}
