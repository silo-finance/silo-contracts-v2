// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IInterestRateModel} from "../../../contracts/interfaces/IInterestRateModel.sol";

contract InterestRateModelConfigs {
    function _configWithState() internal pure returns (IInterestRateModel.ConfigWithState memory config) {
        config = IInterestRateModel.ConfigWithState({
            uopt:  800000000000000000,
            ucrit:  900000000000000000,
            ulow:  500000000000000000,
            ki:  183506,
            kcrit:  237823439878,
            klow:  31709791984,
            klin:  1585489599,
            beta:  27777777777778,
            ri:  0,
            Tcrit:  0
        });
    }
}
