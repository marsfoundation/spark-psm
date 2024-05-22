// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

// contract PSMPreviewFunctionTests is PSMTestBase {

//     function test_previewSwapAssetZeroToOne() public {
//         assertEq(psm.previewSwapAssetZeroToOne(1), 0.8e12);
//         assertEq(psm.previewSwapAssetZeroToOne(2), 1.6e12);
//         assertEq(psm.previewSwapAssetZeroToOne(3), 2.4e12);

//         assertEq(psm.previewSwapAssetZeroToOne(1e6), 0.8e18);
//         assertEq(psm.previewSwapAssetZeroToOne(2e6), 1.6e18);
//         assertEq(psm.previewSwapAssetZeroToOne(3e6), 2.4e18);

//         assertEq(psm.previewSwapAssetZeroToOne(1.000001e6), 0.8000008e18);

//         rateProvider.__setConversionRate(1.6e27);

//         assertEq(psm.previewSwapAssetZeroToOne(1), 0.625e12);
//         assertEq(psm.previewSwapAssetZeroToOne(2), 1.25e12);
//         assertEq(psm.previewSwapAssetZeroToOne(3), 1.875e12);

//         assertEq(psm.previewSwapAssetZeroToOne(1e6), 0.625e18);
//         assertEq(psm.previewSwapAssetZeroToOne(2e6), 1.25e18);
//         assertEq(psm.previewSwapAssetZeroToOne(3e6), 1.875e18);

//         assertEq(psm.previewSwapAssetZeroToOne(1.000001e6), 0.625000625e18);

//         rateProvider.__setConversionRate(0.8e27);

//         assertEq(psm.previewSwapAssetZeroToOne(1), 1.25e12);
//         assertEq(psm.previewSwapAssetZeroToOne(2), 2.5e12);
//         assertEq(psm.previewSwapAssetZeroToOne(3), 3.75e12);

//         assertEq(psm.previewSwapAssetZeroToOne(1e6), 1.25e18);
//         assertEq(psm.previewSwapAssetZeroToOne(2e6), 2.5e18);
//         assertEq(psm.previewSwapAssetZeroToOne(3e6), 3.75e18);

//         assertEq(psm.previewSwapAssetZeroToOne(1.000001e6), 1.25000125e18);
//     }

//     function test_previewSwapAssetOneToZero() public {
//         assertEq(psm.previewSwapAssetOneToZero(1), 0);
//         assertEq(psm.previewSwapAssetOneToZero(2), 0);
//         assertEq(psm.previewSwapAssetOneToZero(3), 0);
//         assertEq(psm.previewSwapAssetOneToZero(4), 0);

//         // 1e-6 with 18 decimal precision
//         assertEq(psm.previewSwapAssetOneToZero(1e12), 1);
//         assertEq(psm.previewSwapAssetOneToZero(2e12), 2);
//         assertEq(psm.previewSwapAssetOneToZero(3e12), 3);
//         assertEq(psm.previewSwapAssetOneToZero(4e12), 5);

//         assertEq(psm.previewSwapAssetOneToZero(1e18), 1.25e6);
//         assertEq(psm.previewSwapAssetOneToZero(2e18), 2.5e6);
//         assertEq(psm.previewSwapAssetOneToZero(3e18), 3.75e6);
//         assertEq(psm.previewSwapAssetOneToZero(4e18), 5e6);

//         assertEq(psm.previewSwapAssetOneToZero(1.000001e18), 1.250001e6);

//         rateProvider.__setConversionRate(1.6e27);

//         assertEq(psm.previewSwapAssetOneToZero(1), 0);
//         assertEq(psm.previewSwapAssetOneToZero(2), 0);
//         assertEq(psm.previewSwapAssetOneToZero(3), 0);
//         assertEq(psm.previewSwapAssetOneToZero(4), 0);

//         // 1e-6 with 18 decimal precision
//         assertEq(psm.previewSwapAssetOneToZero(1e12), 1);
//         assertEq(psm.previewSwapAssetOneToZero(2e12), 3);
//         assertEq(psm.previewSwapAssetOneToZero(3e12), 4);
//         assertEq(psm.previewSwapAssetOneToZero(4e12), 6);

//         assertEq(psm.previewSwapAssetOneToZero(1e18), 1.6e6);
//         assertEq(psm.previewSwapAssetOneToZero(2e18), 3.2e6);
//         assertEq(psm.previewSwapAssetOneToZero(3e18), 4.8e6);
//         assertEq(psm.previewSwapAssetOneToZero(4e18), 6.4e6);

//         rateProvider.__setConversionRate(0.8e27);

//         assertEq(psm.previewSwapAssetOneToZero(1), 0);
//         assertEq(psm.previewSwapAssetOneToZero(2), 0);
//         assertEq(psm.previewSwapAssetOneToZero(3), 0);
//         assertEq(psm.previewSwapAssetOneToZero(4), 0);

//         // 1e-6 with 18 decimal precision
//         assertEq(psm.previewSwapAssetOneToZero(1e12), 0);
//         assertEq(psm.previewSwapAssetOneToZero(2e12), 1);
//         assertEq(psm.previewSwapAssetOneToZero(3e12), 2);
//         assertEq(psm.previewSwapAssetOneToZero(4e12), 3);

//         assertEq(psm.previewSwapAssetOneToZero(1e18), 0.8e6);
//         assertEq(psm.previewSwapAssetOneToZero(2e18), 1.6e6);
//         assertEq(psm.previewSwapAssetOneToZero(3e18), 2.4e6);
//         assertEq(psm.previewSwapAssetOneToZero(4e18), 3.2e6);
//     }

// }
