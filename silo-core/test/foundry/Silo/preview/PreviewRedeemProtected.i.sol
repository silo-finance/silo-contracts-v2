// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {PreviewWithdrawTest} from "./PreviewWithdraw.i.sol";

/*
    forge test -vv --ffi --mc PreviewWithdrawTest
*/
contract PreviewRedeemTest is PreviewWithdrawTest {
    function _useRedeem() internal pure override returns (bool) {
        return true;
    }

    function _collateralType() internal pure virtual returns (ISilo.CollateralType) {
        return ISilo.CollateralType.Protected;
    }
}
