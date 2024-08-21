// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

/// @dev Ignore collateral share token as it is a silo and it has a separate reentrancy test.
abstract contract ShareTokenMethodReentrancyTest is MethodReentrancyTest {
    function _executeForAllShareTokens(function(address) internal func) internal {
        ISiloConfig config = TestStateLib.siloConfig();
        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();

        (address protected0,, address debt0) = config.getShareTokens(address(silo0));
        (address protected1,, address debt1) = config.getShareTokens(address(silo1));

        func(protected0);
        func(debt0);

        func(protected1);
        func(debt1);
    }

    function _executeForAllShareTokensForSilo(function(address,address) internal func) internal {
        ISiloConfig config = TestStateLib.siloConfig();
        address silo0 = address(TestStateLib.silo0());
        address silo1 = address(TestStateLib.silo1());

        (address protected0,, address debt0) = config.getShareTokens(silo0);
        (address protected1,, address debt1) = config.getShareTokens(silo1);

        func(silo0, protected0);
        func(silo0, debt0);

        func(silo1, protected1);
        func(silo1, debt1);
    }
}
