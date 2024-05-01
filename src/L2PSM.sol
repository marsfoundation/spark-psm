// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

interface IDSROracleLike {
    function getConversionRateBinomialApprox() external view returns (uint256);
}

// TODO: Get better name
contract L2PSM {

    using SafeERC20 for IERC20;

    IERC20 public sDai;
    IERC20 public asset;

    IDSROracleLike public oracle;

    uint256 public sDaiPrecision;
    uint256 public assetPrecision;

    constructor(address sDai_, address asset_, address oracle_) {
        require(sDai_   != address(0), "L2PSM/invalid-sDai");
        require(asset_  != address(0), "L2PSM/invalid-asset");
        require(oracle_ != address(0), "L2PSM/invalid-oracle");

        sDai   = IERC20(sDai_);
        asset  = IERC20(asset_);
        oracle = IDSROracleLike(oracle_);

        sDaiPrecision  = 10 ** IERC20(sDai_).decimals();
        assetPrecision = 10 ** IERC20(asset_).decimals();
    }

    function buySDai(uint256 amountIn, uint256 minAmountOut) external {
        require(amountIn != 0, "L2PSM/invalid-amountIn");

        uint256 amountOut
            = amountIn * sDaiPrecision / oracle.getConversionRateBinomialApprox() / assetPrecision;

        require(amountOut >= minAmountOut, "L2PSM/invalid-amountOut");

        asset.safeTransferFrom(msg.sender, address(this), amountIn);
        sDai.safeTransfer(msg.sender, amountOut);
    }

    function sellSDai(uint256 amountIn, uint256 minAmountOut) external {
        require(amountIn != 0, "L2PSM/invalid-amountIn");

        uint256 amountOut
            = amountIn * assetPrecision / oracle.getConversionRateBinomialApprox() / sDaiPrecision;

        require(amountOut >= minAmountOut, "L2PSM/invalid-amountOut");

        sDai.safeTransferFrom(msg.sender, address(this), amountIn);
        asset.safeTransfer(msg.sender, amountOut);
    }

}
