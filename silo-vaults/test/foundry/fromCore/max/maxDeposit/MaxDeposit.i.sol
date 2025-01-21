// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {VaultsLittleHelper} from "../../_common/VaultsLittleHelper.sol";
import {CAP, NB_MARKETS} from "../../../helpers/BaseTest.sol";

/*
    FOUNDRY_PROFILE=vaults-tests forge test -vv --ffi --mc MaxDepositTest
*/
contract MaxDepositTest is VaultsLittleHelper {
    uint256 internal constant _REAL_ASSETS_LIMIT = type(uint128).max;
    uint256 internal constant _IDLE_CAP = type(uint184).max;

    /*
    forge test -vv --ffi --mt test_maxDeposit
    */
    function test_maxDeposit() public view {
        assertEq(
            vault.maxDeposit(address(1)),
            CAP + _IDLE_CAP,
            "ERC4626 expect to return summary CAP for all markets"
        );
    }
}
