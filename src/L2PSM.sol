// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface IDSROracleLike {
    function getConversionRateBinomialApprox() external view returns (uint256);
}

interface IERC20Like {
    function decimals() external view returns (uint8);
}

// TODO: Get better name
contract L2PSM {

    address public sDai;
    address public asset;
    address public oracle;

    uint256 public sDaiPrecision;
    uint256 public assetPrecision;

    constructor(address sDai_, address asset_, address oracle_) {
        require(sDai_   != address(0), "L2PSM/invalid-sDai");
        require(asset_  != address(0), "L2PSM/invalid-asset");
        require(oracle_ != address(0), "L2PSM/invalid-oracle");

        sDai   = sDai_;
        asset  = asset_;
        oracle = oracle_;

        sDaiPrecision  = 10 ** IERC20Like(sDai_).decimals();
        assetPrecision = 10 ** IERC20Like(asset_).decimals();
    }

    function buySDai(uint256 amountIn) external {
        require(amountIn != 0, "L2PSM/invalid-amountIn");

        uint256 amountOut = amountIn * sDaiPrecision / IDSROracleLike(oracle).getConversionRateBinomialApprox() / assetPrecision;

        require(amountOut != 0, "L2PSM/invalid-amountOut");
    }
}
