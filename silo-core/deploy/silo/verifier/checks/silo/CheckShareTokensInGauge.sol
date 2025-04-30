// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

contract CheckShareTokensInGauge is ICheck {
    ISiloConfig.ConfigData internal configData;
    string internal siloName;

    address internal shareToken;
    constructor(ISiloConfig.ConfigData memory _configData, bool _isSiloZero) {
        configData = _configData;
        siloName = _isSiloZero ? "silo0" : "silo1";
    }

    function checkName() external view override returns (string memory name) {
        name = string.concat(siloName, " hookReceiver.configuredGauges(shareToken).shareToken == shareToken");
    }

    function successMessage() external pure override returns (string memory message) {
        message = "property holds";
    }

    function errorMessage() external view override returns (string memory message) {
        message = string.concat("property does not hold for share token ", Strings.toHexString(shareToken));
    }

    function execute() external override returns (bool result) {
        GaugeHookReceiver hookReceiver = GaugeHookReceiver(configData.hookReceiver);

        address protectedShareTokensGauge =
            address(hookReceiver.configuredGauges(IShareToken(configData.protectedShareToken)));

        address collateralShareTokensGauge =
            address(hookReceiver.configuredGauges(IShareToken(configData.collateralShareToken)));

        address debtShareTokensGauge =
            address(hookReceiver.configuredGauges(IShareToken(configData.debtShareToken)));

        if (!_checkGauge(protectedShareTokensGauge, configData.protectedShareToken)) return false;
        if (!_checkGauge(collateralShareTokensGauge, configData.collateralShareToken)) return false;
        if (!_checkGauge(debtShareTokensGauge, configData.debtShareToken)) return false;

        return true;
    }

    function _checkGauge(address _gauge, address _shareToken) internal returns (bool success) {
        if (_gauge == address(0)) {
            return true;
        }

        if (address(ISiloIncentivesController(_gauge).SHARE_TOKEN()) != _shareToken) {
            shareToken = _shareToken;
            return false;
        }

        return true;
    }
}
