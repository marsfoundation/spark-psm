// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract MockDsrOracle {

    uint256 public conversionRateBinomialApprox;

    function __setConversionRateBinomialApprox(uint256 rate) external {
        conversionRateBinomialApprox = rate;
    }

    function getConversionRateBinomialApprox() external view returns (uint256) {
        return conversionRateBinomialApprox;
    }

}
