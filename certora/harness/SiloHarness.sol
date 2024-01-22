// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Silo} from "silo-core/contracts/Silo.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";

contract SiloHarness is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {}

    function getSiloDataInterestRateTimestamp() external view returns (uint256) {
        return siloData.interestRateTimestamp;
    }

    function getSiloDataDaoAndDeployerFees() external view returns (uint256) {
        return siloData.daoAndDeployerFees;
    }

    function _accrueInterest()
        internal
        virtual
        returns (uint256 accruedInterest, ISiloConfig.ConfigData memory configData)
    {
        configData = config.getConfig(address(this));

        accruedInterest = _callAccrueInterestForAsset(
            configData.interestRateModel, configData.daoFee, configData.deployerFee
        );
    }
}
