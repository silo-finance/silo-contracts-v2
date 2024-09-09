// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {UpgradeableBeacon} from "openzeppelin5/proxy/beacon/UpgradeableBeacon.sol";

contract CCIPGaugeArbitrumUpgradeableBeacon is UpgradeableBeacon {
    constructor(address implementation_, address initialOwner) UpgradeableBeacon(implementation_, initialOwner) {}
}
