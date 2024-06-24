// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface IRateProviderLike {
    function getConversionRate() external view returns (uint256);
}
