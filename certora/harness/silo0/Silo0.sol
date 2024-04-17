// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloHarness} from "../SiloHarness.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";

contract Silo0 is SiloHarness {
    constructor(ISiloFactory _siloFactory) SiloHarness(_siloFactory) {}

    function _accrueInterest_orig() external
        returns (uint256 accruedInterest, ISiloConfig.ConfigData memory configData)
    {
        configData = config.getConfig(address(this));

        accruedInterest = _callAccrueInterestForAsset(
            configData.interestRateModel, configData.daoFee, configData.deployerFee, address(0)
        );
    }

}
