// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {PreviewBorrowTest} from "./PreviewBorrow.i.sol";

/*
    forge test -vv --ffi --mc PreviewBorrowSameAssetTest
*/
contract PreviewBorrowSameAssetTest is PreviewBorrowTest {
    function _sameAsset() internal pure virtual override returns (bool) {
        return true;
    }
}
