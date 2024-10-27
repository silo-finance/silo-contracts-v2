// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {PreviewRepayTest} from "./PreviewRepay.i.sol";

/*
    forge test -vv --ffi --mc PreviewRepaySharesTest
*/
contract PreviewRepaySharesTest is PreviewRepayTest {
    function _useShares() internal pure override returns (bool) {
        return true;
    }
}
