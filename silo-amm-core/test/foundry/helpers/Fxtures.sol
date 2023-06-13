// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../contracts/AmmPriceModel.sol";

contract Fxtures {
    AmmPriceModel.AmmPriceConfig ammPriceConfig;
    
    constructor(){
        _ammPriceConfig();
    }

    function _ammPriceConfig() internal {
        ammPriceConfig.tSlow = 1 hours;

        ammPriceConfig.q = 1e16;
        ammPriceConfig.kMax = 1e18;
        ammPriceConfig.kMin = 0;

        ammPriceConfig.vFast = 4629629629629;
        ammPriceConfig.deltaK = 3564;
    }
}
