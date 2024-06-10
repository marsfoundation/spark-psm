// // SPDX-License-Identifier: AGPL-3.0-or-later
// pragma solidity ^0.8.13;

// import { MockERC20 } from "erc20-helpers/MockERC20.sol";

// contract LPHandler {

//     MockERC20 public asset0;
//     MockERC20 public asset1;
//     MockERC20 public asset2;

//     constructor(MockERC20 asset0_, MockERC20 asset1_, MockERC20 asset2_) {
//         asset0 = asset0_;
//         asset1 = asset1_;
//         asset2 = asset2_;
//     }

//     function deposit(address asset, address user, address receiver, uint256 amount) public {
//         vm.startPrank(user);
//         MockERC20(asset).mint(user, amount);
//         MockERC20(asset).approve(address(psm), amount);
//         psm.deposit(asset, receiver, amount);
//         vm.stopPrank();
//     }
// }
