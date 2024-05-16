// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface IPSM {

    event AssetDeposited(address indexed user, address indexed asset, uint256 amount);
    event AssetWithdrawn(address indexed user, address indexed asset, uint256 amount);

    /**
     *  @dev   Deposits a specified amount of a given asset into the PSM. Must be one of the
     *         supported assets in order to succeed.
     *  @param asset           Address of the ERC-20 asset to deposit.
     *  @param assetsToDeposit Amount of the asset to deposit into the PSM.
     */
    function deposit(address asset, uint256 assetsToDeposit) external;

    /**
     *  @dev    Withdraws an amount of a given asset from the PSM up to `maxAssetsToWithdraw`.
     *          Must be one of the supported assets in order to succeed. The amount withdrawn is
     *          the minimum of the balance of the PSM, the max amount, and the max amount of assets
     *          that the user's shares can be converted to.
     *  @param  asset               Address of the ERC-20 asset to deposit.
     *  @param  maxAssetsToWithdraw Amount of the asset to deposit into the PSM.
     *  @return assetsWithdrawn     Resulting amount of the asset withdrawn from the PSM.
     */
    function withdraw(address asset, uint256 maxAssetsToWithdraw)
        external returns (uint256 assetsWithdrawn);

    /**
     *  @dev    Converts an amount of assetValue (18 decimal value denominated in asset0)
     *          to shares in the PSM based on the current exchange rate.
     *  @param  assetValue 18 decimal value denominated in asset0 (e.g., 1e6 USDC = 1e18)
     *  @return shares     Number of shares that the assetValue is equivalent to.
     */
    function convertToShares(uint256 assetValue) external view returns (uint256);

    /**
     *  @dev    Converts an amount of a given asset to shares in the PSM based on the
     *          current exchange rate.
     *  @param  asset  Address of the ERC-20 asset to convert to shares.
     *  @param  assets Amount of assets in asset-native units.
     *  @return shares Number of shares that the assetValue is equivalent to.
     */
    function convertToShares(address asset, uint256 assets) external view returns (uint256);

    /**
     *  @dev    Converts an amount of a given shares to the equivalent amount of assetValue.
     *  @param  numShares  Number of shares to convert to assetValue.
     *  @return assetValue Value of assets in asset0 denominated in 18 decimals.
     */
    function convertToAssetValue(uint256 numShares) external view returns (uint256);

    /**
     *  @dev    Converts an amount of a given shares to the equivalent amount of
     *          assets for a specified asset.
     *  @param  asset      Address of the asset to use to convert.
     *  @param  numShares  Number of shares to convert to assets.
     *  @return assets     Value of assets in asset-native units.
     */
    function convertToAssets(address asset, uint256 numShares) external view returns (uint256);

    /**
     *  @dev Returns the total value of the balance of all assets in the PSM converted to
     *       asset0 denominated in 18 decimal precision.
     */
    function getPsmTotalValue() external view returns (uint256);

}
