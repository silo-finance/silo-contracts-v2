// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IInterestRateModelV2} from "../../../contracts/interfaces/IInterestRateModelV2.sol";

contract InterestRateModelConfigs {
    function _defaultConfig() internal pure returns (IInterestRateModelV2.Config memory config) {
        config = IInterestRateModelV2.Config({
            uopt:  800000000000000000,
            ucrit:  900000000000000000,
            ulow:  500000000000000000,
            ki:  183506,
            kcrit:  237823439878,
            klow:  31709791984,
            klin:  1585489599,
            beta:  27777777777778,
            ri:  10,
            Tcrit:  1
        });
    }
}
