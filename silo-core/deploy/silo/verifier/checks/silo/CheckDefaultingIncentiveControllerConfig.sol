// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Utils} from "silo-core/deploy/silo/verifier/Utils.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";

contract CheckDefaultingIncentiveControllerConfig is ICheck {
    ISiloConfig.ConfigData internal configData;
    string internal siloName;

    string internal _msg;

    bool internal isKinkIrm;

    constructor(ISiloConfig.ConfigData memory _configData, bool _isSiloZero) {
        configData = _configData;
        siloName = _isSiloZero ? "silo0" : "silo1";
    }

    function checkName() external view override returns (string memory name) {
        name = string.concat(siloName, " SiloIncentivesController is required for defaulting liquidation");
    }

    function successMessage() external view override returns (string memory message) {
        message = _msg;
    }

    function errorMessage() external pure override returns (string memory message) {
        message = "NOT created";
    }

    function execute() external override returns (bool result) {
        if (!Utils.isDefaultingON(configData.hookReceiver)) {
            _msg = "Defaulting is not enabled";
            return true;
        }

        if (configData.lt != 0) {
            _msg = "this is collateral silo (no defaulting here)";
            return true;
        }

        try IPartialLiquidationByDefaulting(configData.hookReceiver).validateControllerForCollateral(configData.silo)
        {
            result = true;
        } catch {
            result = false;
        }
    }
}
