// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

library ShareTokenDecimalsPowLib {
    function decimalsOffsetPow(uint256 _number) internal pure returns (uint256 result) {
        result = _number * SiloMathLib._DECIMALS_OFFSET_POW;
    }
}
