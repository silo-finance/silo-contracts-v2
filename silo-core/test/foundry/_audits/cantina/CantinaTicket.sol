// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

contract CantinaTicket is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public virtual {
        siloConfig = _setUpLocalFixture();
    }
}
