// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { L2PSM } from "../src/L2PSM.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { MockDsrOracle } from "./mocks/MockDsrOracle.sol";

contract L2PSMTest is Test {

    L2PSM public psm;

    MockERC20 public sDai;
    MockERC20 public asset;

    MockDsrOracle public oracle;

    function setUp() public {
        sDai   = new MockERC20("sDai",  "sDai",  18);
        asset  = new MockERC20("asset", "asset", 6);
        oracle = new MockDsrOracle();

        // NOTE: Using 1.25 for easy two way conversions
        oracle.__setConversionRateBinomialApprox(1.25e27);

        psm = new L2PSM(address(sDai), address(asset), address(oracle));
    }

    function test_constructor() public view {
        assertEq(address(psm.sDai()),   address(sDai));
        assertEq(address(psm.asset()),  address(asset));
        assertEq(address(psm.oracle()), address(oracle));

        assertEq(psm.sDaiPrecision(),  10 ** sDai.decimals());
        assertEq(psm.assetPrecision(), 10 ** asset.decimals());
    }

    function test_getBuySDaiQuote() public {
        assertEq(psm.getBuySDaiQuote(1), 0.8e12);
        assertEq(psm.getBuySDaiQuote(2), 1.6e12);
        assertEq(psm.getBuySDaiQuote(3), 2.4e12);

        assertEq(psm.getBuySDaiQuote(1e6), 0.8e18);
        assertEq(psm.getBuySDaiQuote(2e6), 1.6e18);
        assertEq(psm.getBuySDaiQuote(3e6), 2.4e18);

        assertEq(psm.getBuySDaiQuote(1.000001e6), 0.8000008e18);

        oracle.__setConversionRateBinomialApprox(1.6e27);

        assertEq(psm.getBuySDaiQuote(1), 0.625e12);
        assertEq(psm.getBuySDaiQuote(2), 1.25e12);
        assertEq(psm.getBuySDaiQuote(3), 1.875e12);

        assertEq(psm.getBuySDaiQuote(1e6), 0.625e18);
        assertEq(psm.getBuySDaiQuote(2e6), 1.25e18);
        assertEq(psm.getBuySDaiQuote(3e6), 1.875e18);

        assertEq(psm.getBuySDaiQuote(1.000001e6), 0.625000625e18);

        oracle.__setConversionRateBinomialApprox(0.8e27);

        assertEq(psm.getBuySDaiQuote(1), 1.25e12);
        assertEq(psm.getBuySDaiQuote(2), 2.5e12);
        assertEq(psm.getBuySDaiQuote(3), 3.75e12);

        assertEq(psm.getBuySDaiQuote(1e6), 1.25e18);
        assertEq(psm.getBuySDaiQuote(2e6), 2.5e18);
        assertEq(psm.getBuySDaiQuote(3e6), 3.75e18);

        assertEq(psm.getBuySDaiQuote(1.000001e6), 1.25000125e18);
    }

    function test_getSellSDaiQuote() public {
        assertEq(psm.getSellSDaiQuote(1), 0);
        assertEq(psm.getSellSDaiQuote(2), 0);
        assertEq(psm.getSellSDaiQuote(3), 0);
        assertEq(psm.getSellSDaiQuote(4), 0);

        // 1e-6 with 18 decimal precision
        assertEq(psm.getSellSDaiQuote(1e12), 1);
        assertEq(psm.getSellSDaiQuote(2e12), 2);
        assertEq(psm.getSellSDaiQuote(3e12), 3);
        assertEq(psm.getSellSDaiQuote(4e12), 5);

        assertEq(psm.getSellSDaiQuote(1e18), 1.25e6);
        assertEq(psm.getSellSDaiQuote(2e18), 2.5e6);
        assertEq(psm.getSellSDaiQuote(3e18), 3.75e6);
        assertEq(psm.getSellSDaiQuote(4e18), 5e6);

        assertEq(psm.getSellSDaiQuote(1.000001e18), 1.250001e6);

        oracle.__setConversionRateBinomialApprox(1.6e27);

        assertEq(psm.getSellSDaiQuote(1), 0);
        assertEq(psm.getSellSDaiQuote(2), 0);
        assertEq(psm.getSellSDaiQuote(3), 0);
        assertEq(psm.getSellSDaiQuote(4), 0);

        // 1e-6 with 18 decimal precision
        assertEq(psm.getSellSDaiQuote(1e12), 1);
        assertEq(psm.getSellSDaiQuote(2e12), 3);
        assertEq(psm.getSellSDaiQuote(3e12), 4);
        assertEq(psm.getSellSDaiQuote(4e12), 6);

        assertEq(psm.getSellSDaiQuote(1e18), 1.6e6);
        assertEq(psm.getSellSDaiQuote(2e18), 3.2e6);
        assertEq(psm.getSellSDaiQuote(3e18), 4.8e6);
        assertEq(psm.getSellSDaiQuote(4e18), 6.4e6);

        oracle.__setConversionRateBinomialApprox(0.8e27);

        assertEq(psm.getSellSDaiQuote(1), 0);
        assertEq(psm.getSellSDaiQuote(2), 0);
        assertEq(psm.getSellSDaiQuote(3), 0);
        assertEq(psm.getSellSDaiQuote(4), 0);

        // 1e-6 with 18 decimal precision
        assertEq(psm.getSellSDaiQuote(1e12), 0);
        assertEq(psm.getSellSDaiQuote(2e12), 1);
        assertEq(psm.getSellSDaiQuote(3e12), 2);
        assertEq(psm.getSellSDaiQuote(4e12), 3);

        assertEq(psm.getSellSDaiQuote(1e18), 0.8e6);
        assertEq(psm.getSellSDaiQuote(2e18), 1.6e6);
        assertEq(psm.getSellSDaiQuote(3e18), 2.4e6);
        assertEq(psm.getSellSDaiQuote(4e18), 3.2e6);
    }

}
