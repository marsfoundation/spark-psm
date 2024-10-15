// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { PSM3 } from "src/PSM3.sol";

library PSM3Deploy {

    function deploy(
        address owner,
        address usdc,
        address usds,
        address susds,
        address rateProvider
    )
        internal returns (address psm)
    {
        psm = address(new PSM3(owner, usdc, usds, susds, rateProvider));

        IERC20(usds).approve(psm, 1e18);
        PSM3(psm).deposit(usds, address(0), 1e18);
    }

}
