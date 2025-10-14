// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {CommonDeploy} from "silo-core/deploy/_CommonDeploy.sol";

contract CheckSiloFactory is ICheck, CommonDeploy {
    ISiloConfig.ConfigData internal configData;
    string internal siloName;

    address internal siloFactory;
    address internal deployedSiloFactory;

    constructor(ISiloConfig.ConfigData memory _configData, bool _isSiloZero) {
        configData = _configData;
        siloName = _isSiloZero ? "silo0" : "silo1";

        siloFactory = address(ISilo(_configData.silo).factory());
        deployedSiloFactory = getDeployedAddress(SiloCoreContracts.SILO_FACTORY);
    }

    function checkName() external view override returns (string memory name) {
        name = string.concat(siloName, " expect factory to be ", Strings.toHexString(deployedSiloFactory));
    }

    function successMessage() external pure override returns (string memory message) {
        message = "factory() match SiloFactory address";
    }

    function errorMessage() external view override returns (string memory message) {
        message = string.concat(
            Strings.toHexString(siloFactory), " DOES NOT match SiloFactory address or factory does not have the silo"
        );
    }

    function execute() external view override returns (bool result) {
        if (siloFactory != deployedSiloFactory) return false;
        result = ISiloFactory(siloFactory).isSilo(configData.silo);
    }
}
