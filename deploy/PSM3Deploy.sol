// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { PSM3 } from "src/PSM3.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

library PSM3Deploy {

    function deploy(
        address asset0,
        address asset1,
        address asset2,
        address rateProvider
    )
        external returns (address psm)
    {
        psm = address(new PSM3(asset0, asset1, asset2, rateProvider));

        IERC20(asset0).approve(psm, 1e18);
        PSM3(psm).deposit(asset0, address(0), 1e18);
    }

}
