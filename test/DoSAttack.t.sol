// I've thought about it some more and to keep things simple I don't think we should include any
// custom logic for ensuring an initial burn amount. There are actually a lot of ways to brick the
//  contract with an initial deposit. This current method prevents the share inflation attack,
//  but you can also just send a non-zero balance to the contract before the first call to deposit
//   to DoS any deposit after that as convertToShares(...) will return 0 always
//   since psm value is > 0 and totalShares = 0.

// I think instead let's just make it very clear a small seed amount should be deposited as
// the first action in all cases. This is what other protocols do, and I think it's easier to not
// go overly fancy as it introduces complexity.

// For the deposit and withdraw functions let's add a receiver param and during deployment we will
//  just deposit some initial amount and send it to the zero address.

// As part of the deployment script we can include this initial deposit to force the deployer
//  address to have a seed balance inside it's wallet.

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract InflationAttackTests is PSMTestBase {


}
