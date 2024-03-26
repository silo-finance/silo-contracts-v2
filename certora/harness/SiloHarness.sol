// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Silo} from "silo-core/contracts/Silo.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

contract SiloHarness is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {}

    function getSiloDataInterestRateTimestamp() external view returns (uint256) {
        return siloData.interestRateTimestamp;
    }

    function getSiloDataDaoAndDeployerFees() external view returns (uint256) {
        return siloData.daoAndDeployerFees;
    }

    function getFlashloanFee0() external view returns (uint256) {
        (,, uint256 flashloanFee, ) = config.getFeesWithAsset(address(this));
        return flashloanFee;
    }

    function getFlashloanFee1() external view returns (uint256) {
        (, ISiloConfig.ConfigData memory otherConfig, ) = config.getConfigs(address(this), address(0));
        return otherConfig.flashloanFee;
    }

    function reentrancyGuardEntered() external view returns (bool) {
        return _reentrancyGuardEntered();
    }

    function getDaoFee() external view returns (uint256) {
        (uint256 daoFee,,, ) = config.getFeesWithAsset(address(this));
        return daoFee;
    }

    function getDeployerFee() external view returns (uint256) {
        (, uint256 deployerFee,, ) = config.getFeesWithAsset(address(this));
        return deployerFee;
    }
}
