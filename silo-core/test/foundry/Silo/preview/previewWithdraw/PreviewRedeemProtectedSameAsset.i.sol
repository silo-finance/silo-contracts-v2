// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {PreviewWithdrawTest} from "./PreviewWithdraw.i.sol";

/*
    forge test -vv --ffi --mc PreviewRedeemSameAssetTest
*/
contract PreviewRedeemSameAssetTest is PreviewWithdrawTest {
    function _useRedeem() internal pure override returns (bool) {
        return true;
    }

    function _sameAsset() internal pure override returns (bool) {
        return true;
    }

    function _collateralType() internal pure override returns (ISilo.CollateralType) {
        return ISilo.CollateralType.Protected;
    }
}
