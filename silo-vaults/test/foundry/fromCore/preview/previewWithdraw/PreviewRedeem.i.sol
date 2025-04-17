// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {PreviewWithdrawTest} from "./PreviewWithdraw.i.sol";

/*
    FOUNDRY_PROFILE=vaults_tests forge test -vv --ffi --mc PreviewRedeemTest
*/
contract PreviewRedeemTest is PreviewWithdrawTest {
    function _useRedeem() internal pure override returns (bool) {
        return true;
    }
}
