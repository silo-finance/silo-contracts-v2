// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

contract CheckDaoFee is ICheck {
    ISiloConfig.ConfigData internal configData;
    string internal siloName;

    constructor(ISiloConfig.ConfigData memory _configData, bool _isSiloZero) {
        configData = _configData;
        siloName = _isSiloZero ? "silo0" : "silo1";
    }

    function checkName() external view override returns (string memory name) {
        name = string.concat(siloName, " dao fee is >0.01% or <25%");
    }

    function successMessage() external pure override returns (string memory message) {
        message = "dao fee is within the expected range";
    }

    function errorMessage() external view override returns (string memory message) {
        message = string.concat(
            Strings.toString(configData.daoFee),
            " dao fee is NOT within the expected range"
        );
    }

    function execute() external view override returns (bool result) {
        result = configData.daoFee > 10 ** 18 / 10_000 && configData.daoFee < 10 ** 18 / 4;
    }
}
