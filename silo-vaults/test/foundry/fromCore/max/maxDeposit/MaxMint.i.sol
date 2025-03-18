// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {VaultsLittleHelper} from "../../_common/VaultsLittleHelper.sol";
import {CAP} from "../../../helpers/BaseTest.sol";

/*
    FOUNDRY_PROFILE=vaults-tests forge test -vv --ffi --mc MaxMintTest
*/
contract MaxMintTest is VaultsLittleHelper {
    uint256 internal constant _REAL_ASSETS_LIMIT = type(uint128).max;
    uint256 internal constant _IDLE_CAP = type(uint184).max;

    /*
    forge test -vv --ffi --mt test_maxMint
    */
    function test_maxMint() public view {
        assertEq(
            vault.maxMint(address(1)),
            (CAP + _IDLE_CAP) * OFFSET_POW,
            "ERC4626 expect to return summary CAP for all markets"
        );
    }

    /*
    forge test -vv --ffi --mt test_maxMint_withDeposit
    */
    function test_maxMint_withDeposit2() public {
        uint256 deposit = 123;

        _deposit(deposit, address(1));

        emit log_named_uint("OFFSET_POW", OFFSET_POW);
        emit log_named_uint("CAP + _IDLE_CAP - deposit - 1", CAP + _IDLE_CAP - deposit - 1);

        assertEq(
            vault.maxMint(address(1)),
            // -1 because of the rounding in the Silo previewRedeem fn
            (CAP + _IDLE_CAP - deposit - 1) * OFFSET_POW,
            "ERC4626 expect to return summary CAP for all markets - deposit"
        );
    }
}
