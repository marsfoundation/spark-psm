// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

interface IPSM3 {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    // TODO: Add natspec
    event PocketSet(
        address indexed oldPocket,
        address indexed newPocket,
        uint256 amountTransferred
    );

    /**
     *  @dev   Emitted when an asset is swapped in the PSM.
     *  @param assetIn       Address of the asset swapped in.
     *  @param assetOut      Address of the asset swapped out.
     *  @param sender        Address of the sender of the swap.
     *  @param receiver      Address of the receiver of the swap.
     *  @param amountIn      Amount of the asset swapped in.
     *  @param amountOut     Amount of the asset swapped out.
     *  @param referralCode  Referral code for the swap.
     */
    event Swap(
        address indexed assetIn,
        address indexed assetOut,
        address sender,
        address indexed receiver,
        uint256 amountIn,
        uint256 amountOut,
        uint256 referralCode
    );

    /**
     *  @dev   Emitted when an asset is deposited into the PSM.
     *  @param asset           Address of the asset deposited.
     *  @param user            Address of the user that deposited the asset.
     *  @param receiver        Address of the receiver of the resulting shares from the deposit.
     *  @param assetsDeposited Amount of the asset deposited.
     *  @param sharesMinted    Number of shares minted to the user.
     */
    event Deposit(
        address indexed asset,
        address indexed user,
        address indexed receiver,
        uint256 assetsDeposited,
        uint256 sharesMinted
    );

    /**
     *  @dev   Emitted when an asset is withdrawn from the PSM.
     *  @param asset           Address of the asset withdrawn.
     *  @param user            Address of the user that withdrew the asset.
     *  @param receiver        Address of the receiver of the withdrawn assets.
     *  @param assetsWithdrawn Amount of the asset withdrawn.
     *  @param sharesBurned    Number of shares burned from the user.
     */
    event Withdraw(
        address indexed asset,
        address indexed user,
        address indexed receiver,
        uint256 assetsWithdrawn,
        uint256 sharesBurned
    );

    /**********************************************************************************************/
    /*** State variables and immutables                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev    Returns the IERC20 interface representing asset0. This asset is one of the non-yield
     *          bearing assets in the PSM (e.g., USDC or DAI).
     *  @return The IERC20 interface of asset0.
     */
    function asset0() external view returns (IERC20);

    /**
     *  @dev    Returns the IERC20 interface representing asset1. This asset is one of the non-yield
     *          bearing assets in the PSM (e.g., USDC or DAI).
     *  @return The IERC20 interface of asset1.
     */
    function asset1() external view returns (IERC20);

    /**
     *  @dev    Returns the IERC20 interface representing asset2. This asset is the yield-bearing
     *          asset in the PSM (e.g., sDAI). The value of this asset is queried from the
     *          rate provider.
     *  @return The IERC20 interface of asset2.
     */
    function asset2() external view returns (IERC20);

    /**
     *  @dev    Returns the address of the pocket, an address that holds custody of USDC in the
     *          PSM and can deploy it to yield-bearing strategies. Settable by the owner.
     *  @return The address of the pocket.
     */
    function pocket() external view returns (address);

    /**
     *  @dev    Returns the address of the rate provider, a contract that provides the conversion
     *          rate between asset2 and the other two assets in the PSM (e.g., sDAI to USD).
     *  @return The address of the rate provider.
     */
    function rateProvider() external view returns (address);

    /**
     *  @dev    Returns the total number of shares in the PSM. Shares represent ownership of the
     *          assets in the PSM and can be converted to assets at any time.
     *  @return The total number of shares.
     */
    function totalShares() external view returns (uint256);

    /**
     *  @dev    Returns the number of shares held by a specific user.
     *  @param  user The address of the user.
     *  @return The number of shares held by the user.
     */
    function shares(address user) external view returns (uint256);

    /**********************************************************************************************/
    /*** Swap functions                                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev    Swaps a specified amount of assetIn for assetOut in the PSM. The amount swapped is
     *          converted based on the current value of the two assets used in the swap. This
     *          function will revert if there is not enough balance in the PSM to facilitate the
     *          swap. Both assets must be supported in the PSM in order to succeed.
     *  @param  assetIn      Address of the ERC-20 asset to swap in.
     *  @param  assetOut     Address of the ERC-20 asset to swap out.
     *  @param  amountIn     Amount of the asset to swap in.
     *  @param  minAmountOut Minimum amount of the asset to receive.
     *  @param  receiver     Address of the receiver of the swapped assets.
     *  @param  referralCode Referral code for the swap.
     *  @return amountOut    Resulting amount of the asset that will be received in the swap.
     */
    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountOut);

    /**
     *  @dev    Swaps a derived amount of assetIn for a specific amount of assetOut in the PSM. The
     *          amount swapped is converted based on the current value of the two assets used in
     *          the swap. This function will revert if there is not enough balance in the PSM to
     *          facilitate the swap. Both assets must be supported in the PSM in order to succeed.
     *  @param  assetIn      Address of the ERC-20 asset to swap in.
     *  @param  assetOut     Address of the ERC-20 asset to swap out.
     *  @param  amountOut    Amount of the asset to receive from the swap.
     *  @param  maxAmountIn  Max amount of the asset to use for the swap.
     *  @param  receiver     Address of the receiver of the swapped assets.
     *  @param  referralCode Referral code for the swap.
     *  @return amountIn     Resulting amount of the asset swapped in.
     */
    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountIn);

    /**********************************************************************************************/
    /*** Liquidity provision functions                                                          ***/
    /**********************************************************************************************/

    /**
     *  @dev    Deposits an amount of a given asset into the PSM. Must be one of the supported
     *          assets in order to succeed. The amount deposited is converted to shares based on
     *          the current exchange rate.
     *  @param  asset           Address of the ERC-20 asset to deposit.
     *  @param  receiver        Address of the receiver of the resulting shares from the deposit.
     *  @param  assetsToDeposit Amount of the asset to deposit into the PSM.
     *  @return newShares       Number of shares minted to the user.
     */
    function deposit(address asset, address receiver, uint256 assetsToDeposit)
        external returns (uint256 newShares);

    /**
     *  @dev    Withdraws an amount of a given asset from the PSM up to `maxAssetsToWithdraw`.
     *          Must be one of the supported assets in order to succeed. The amount withdrawn is
     *          the minimum of the balance of the PSM, the max amount, and the max amount of assets
     *          that the user's shares can be converted to.
     *  @param  asset               Address of the ERC-20 asset to withdraw.
     *  @param  receiver            Address of the receiver of the withdrawn assets.
     *  @param  maxAssetsToWithdraw Max amount that the user is willing to withdraw.
     *  @return assetsWithdrawn     Resulting amount of the asset withdrawn from the PSM.
     */
    function withdraw(
        address asset,
        address receiver,
        uint256 maxAssetsToWithdraw
    ) external returns (uint256 assetsWithdrawn);

    /**********************************************************************************************/
    /*** Deposit/withdraw preview functions                                                     ***/
    /**********************************************************************************************/

    /**
     *  @dev    View function that returns the exact number of shares that would be minted for a
     *          given asset and amount to deposit.
     *  @param  asset  Address of the ERC-20 asset to deposit.
     *  @param  assets Amount of the asset to deposit into the PSM.
     *  @return shares Number of shares to be minted to the user.
     */
    function previewDeposit(address asset, uint256 assets) external view returns (uint256 shares);

    /**
     *  @dev    View function that returns the exact number of assets that would be withdrawn and
     *          corresponding shares that would be burned in a withdrawal for a given asset and max
     *          withdraw amount. The amount returned is the minimum of the balance of the PSM,
     *          the max amount, and the max amount of assets that the user's shares
     *          can be converted to.
     *  @param  asset               Address of the ERC-20 asset to withdraw.
     *  @param  maxAssetsToWithdraw Max amount that the user is willing to withdraw.
     *  @return sharesToBurn        Number of shares that would be burned in the withdrawal.
     *  @return assetsWithdrawn     Resulting amount of the asset withdrawn from the PSM.
     */
    function previewWithdraw(address asset, uint256 maxAssetsToWithdraw)
        external view returns (uint256 sharesToBurn, uint256 assetsWithdrawn);

    /**********************************************************************************************/
    /*** Swap preview functions                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev    View function that returns the exact amount of assetOut that would be received for a
     *         given amount of assetIn in a swap. The amount returned is converted based on the
     *         current value of the two assets used in the swap.
     * @param  assetIn   Address of the ERC-20 asset to swap in.
     * @param  assetOut  Address of the ERC-20 asset to swap out.
     * @param  amountIn  Amount of the asset to swap in.
     * @return amountOut Amount of the asset that will be received in the swap.
     */
    function previewSwapExactIn(address assetIn, address assetOut, uint256 amountIn)
        external view returns (uint256 amountOut);

    /**
     * @dev    View function that returns the exact amount of assetIn that would be required to
     *         receive a given amount of assetOut in a swap. The amount returned is
     *         converted based on the current value of the two assets used in the swap.
     * @param  assetIn   Address of the ERC-20 asset to swap in.
     * @param  assetOut  Address of the ERC-20 asset to swap out.
     * @param  amountOut Amount of the asset to receive from the swap.
     * @return amountIn  Amount of the asset that is required to receive amountOut.
     */
    function previewSwapExactOut(address assetIn, address assetOut, uint256 amountOut)
        external view returns (uint256 amountIn);

    /**********************************************************************************************/
    /*** Conversion functions                                                                   ***/
    /**********************************************************************************************/

    /**
     *  @dev    View function that converts an amount of a given shares to the equivalent amount of
     *          assets for a specified asset.
     *  @param  asset     Address of the asset to use to convert.
     *  @param  numShares Number of shares to convert to assets.
     *  @return assets    Value of assets in asset-native units.
     */
    function convertToAssets(address asset, uint256 numShares) external view returns (uint256);

    /**
     *  @dev    View function that converts an amount of a given shares to the equivalent
     *          amount of assetValue.
     *  @param  numShares  Number of shares to convert to assetValue.
     *  @return assetValue Value of assets in asset0 denominated in 18 decimals.
     */
    function convertToAssetValue(uint256 numShares) external view returns (uint256);

    /**
     *  @dev    View function that converts an amount of assetValue (18 decimal value denominated in
     *          asset0 and asset1) to shares in the PSM based on the current exchange rate.
     *          Note that this rounds down on calculation so is intended to be used for quoting the
     *          current exchange rate.
     *  @param  assetValue 18 decimal value denominated in asset0 (e.g., 1e6 USDC = 1e18)
     *  @return shares     Number of shares that the assetValue is equivalent to.
     */
    function convertToShares(uint256 assetValue) external view returns (uint256);

    /**
     *  @dev    View function that converts an amount of a given asset to shares in the PSM based
     *          on the current exchange rate. Note that this rounds down on calculation so is
     *          intended to be used for quoting the current exchange rate.
     *  @param  asset  Address of the ERC-20 asset to convert to shares.
     *  @param  assets Amount of assets in asset-native units.
     *  @return shares Number of shares that the assetValue is equivalent to.
     */
    function convertToShares(address asset, uint256 assets) external view returns (uint256);

    /**********************************************************************************************/
    /*** Asset value functions                                                                  ***/
    /**********************************************************************************************/

    /**
     *  @dev View function that returns the total value of the balance of all assets in the PSM
     *       converted to asset0/asset1 terms denominated in 18 decimal precision.
     */
    function totalAssets() external view returns (uint256);

}
