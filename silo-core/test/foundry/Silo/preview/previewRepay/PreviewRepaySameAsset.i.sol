// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {PreviewRepayTest} from "./PreviewRepay.i.sol";

/*
    forge test -vv --ffi --mc PreviewRepaySameAssetsTest
*/
contract PreviewRepaySameAssetsTest is PreviewRepayTest {
    function _sameAsset() internal pure override returns (bool) {
        return true;
    }
}
