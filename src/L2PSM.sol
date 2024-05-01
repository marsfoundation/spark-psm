// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

interface IDSROracleLike {
    function getConversionRateBinomialApprox() external view returns (uint256);
}

// TODO: Get better name
// TODO: Add events and corresponding tests
// TODO: Determine what admin functionality we want (fees?)
// TODO: Add interface with natspec and inherit
// TODO: Discuss rounding up/down
contract L2PSM {

    using SafeERC20 for IERC20;

    IERC20 public immutable sDai;
    IERC20 public immutable asset;

    IDSROracleLike public immutable oracle;

    uint256 public immutable sDaiPrecision;
    uint256 public immutable assetPrecision;

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

        uint256 amountOut = getBuySDaiQuote(amountIn);

        require(amountOut >= minAmountOut, "L2PSM/invalid-amountOut");

        asset.safeTransferFrom(msg.sender, address(this), amountIn);
        sDai.safeTransfer(msg.sender, amountOut);
    }

    function sellSDai(uint256 amountIn, uint256 minAmountOut) external {
        require(amountIn != 0, "L2PSM/invalid-amountIn");

        uint256 amountOut = getSellSDaiQuote(amountIn);

        require(amountOut >= minAmountOut, "L2PSM/invalid-amountOut");

        sDai.safeTransferFrom(msg.sender, address(this), amountIn);
        asset.safeTransfer(msg.sender, amountOut);
    }

    function getBuySDaiQuote(uint256 amountIn) public view returns (uint256) {
        return amountIn
            * 1e27
            * sDaiPrecision
            / oracle.getConversionRateBinomialApprox()
            / assetPrecision;
    }

    function getSellSDaiQuote(uint256 amountIn) public view returns (uint256) {
        return amountIn
            * oracle.getConversionRateBinomialApprox()
            * assetPrecision
            / 1e27
            / sDaiPrecision;
    }

}
