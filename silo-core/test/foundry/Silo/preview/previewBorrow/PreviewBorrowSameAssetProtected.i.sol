// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {PreviewBorrowTest} from "./PreviewBorrow.i.sol";

/*
    forge test -vv --ffi --mc PreviewBorrowSameAssetProtectedTest
*/
contract PreviewBorrowSameAssetProtectedTest is PreviewBorrowTest {
    function _sameAsset() internal pure virtual override returns (bool) {
        return true;
    }

    function _collateralType() internal pure virtual override returns (ISilo.CollateralType) {
        return ISilo.CollateralType.Protected;
    }
}
