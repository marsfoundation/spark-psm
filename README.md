# Spark PSM

![Foundry CI](https://github.com/marsfoundation/spark-psm/actions/workflows/ci.yml/badge.svg)
[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/marsfoundation/spark-psm/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repository contains the implementation of a Peg Stability Module (PSM) contract, which facilitates the swapping, depositing, and withdrawing of three given assets to maintain stability and ensure the peg of involved assets. The PSM supports both yield-bearing and non-yield-bearing assets.

`asset0` and `asset1` are two ERC20 tokens that are directly correlated and are non-yield-bearing, referred to as "base assets". `asset2` is a yield-bearing version of both `asset0` and `asset1`. The PSM contract allows users to swap between these assets, deposit any of the assets to mint shares, and withdraw any of the assets by burning shares.

The conversion between a base asset and `asset2` is provided by a rate provider contract. The rate provider returns the conversion rate between `asset2` and the base asset in 1e27 precision. The conversion between the base assets is one to one.

The conversion rate between assets and shares is based on the total value of assets held by the PSM. The total value is calculated by converting the assets to their equivalent value in the base asset with 18 decimal precision. The shares represent the ownership of the underlying assets in the PSM. Since three assets are used, each with different precisions and values, they are converted to a common base asset-denominated value for share conversions.

This README provides the essential information needed to understand and interact with the PSM contract. For detailed implementation, refer to the contract code and `IPSM` interface documentation.

## Contracts

- **PSM Contract**: The core contract implementing the `IPSM` interface, providing functionality for swapping, depositing, and withdrawing assets.
- **IPSM Interface**: Defines the essential functions and events that the PSM contract implements.
- **IRateProviderLike Interface**: Defines the function to get the conversion rate between yield-bearing and non-yield-bearing assets.

## PSM Contract Details

### State Variables and Immutables

- **`asset0`**: Non-yield-bearing base asset (e.g., USDC).
- **`asset1`**: Another non-yield-bearing base asset that is directly correlated to `asset0` (e.g., DAI).
- **`asset2`**: Yield-bearing version of both `asset0` and `asset1` (e.g., sDAI).
- **`rateProvider`**: Contract that returns a conversion rate between and `asset2` and the base asset (e.g., sDAI to USD) in 1e27 precision.
- **`initialBurnAmount`**: Initial shares burned to prevent an inflation frontrunning attack (more info on this [here](https://mixbytes.io/blog/overview-of-the-inflation-attack)).
- **`totalShares`**: Total shares in the PSM. Shares represent the ownership of the underlying assets in the PSM.
- **`shares`**: Mapping of user addresses to their shares.

### Functions

#### Swap Functions

- **`swap`**: Allows swapping of assets based on current conversion rates. Ensures the output amount meets the minimum required before executing the transfer and emitting the swap event. Includes a referral code.

#### Liquidity Provision Functions

- **`deposit`**: Deposits assets into the PSM, minting new shares. Handles the initial burn amount for the first deposit to prevent inflation frontrunning. Includes a referral code.
- **`withdraw`**: Withdraws assets from the PSM by burning shares. Ensures the user has sufficient shares for the withdrawal and adjusts the total shares accordingly. Includes a referral code.

#### Preview Functions

- **`previewDeposit`**: Estimates the number of shares minted for a given deposit amount.
- **`previewWithdraw`**: Estimates the number of shares burned and the amount of assets withdrawn for a specified amount.
- **`previewSwap`**: Estimates the amount of one asset received for a given amount of another asset in a swap.

#### Conversion Functions

NOTE: These functions do not round in the same way as preview functions, so they are meant to be used for general quoting purposes.

- **`convertToAssets`**: Converts shares to the equivalent amount of a specified asset.
- **`convertToAssetValue`**: Converts shares to their equivalent value in base asset terms with 18 decimal precision (e.g., USD).
- **`convertToShares`**: Converts asset values to shares based on the current exchange rate.

#### Asset Value Functions

- **`getPsmTotalValue`**: Returns the total value of all assets held by the PSM denominated in the base asset with 18 decimal precision. (e.g., USD).

### Events

- **`Swap`**: Emitted on asset swaps.
- **`InitialSharesBurned`**: Emitted on the initial burn of shares.
- **`Deposit`**: Emitted on asset deposits.
- **`Withdraw`**: Emitted on asset withdrawals.

## Running Tests

To run tests in this repo, run:

```bash
forge test
```

***
*The IP in this repository was assigned to Mars SPC Limited in respect of the MarsOne SP.*

<p align="center">
  <img src="https://1827921443-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FjvdfbhgN5UCpMtP1l8r5%2Fuploads%2Fgit-blob-c029bb6c918f8c042400dbcef7102c4e5c1caf38%2Flogomark%20colour.svg?alt=media" height="150" />
</p>
