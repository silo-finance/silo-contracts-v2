// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {PreviewBorrowTest} from "./PreviewBorrow.i.sol";

/*
    forge test -vv --ffi --mc PreviewBorrowSharesProtectedTest
*/
contract PreviewBorrowSharesProtectedTest is PreviewBorrowTest {
    function _borrowShares() internal pure virtual override returns (bool) {
        return true;
    }

    function _collateralType() internal pure virtual override returns (ISilo.CollateralType) {
        return ISilo.CollateralType.Protected;
    }
}
