// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {Utils} from "silo-core/deploy/silo/verifier/Utils.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {IDynamicKinkModelFactory} from "silo-core/contracts/interfaces/IDynamicKinkModelFactory.sol";
import {SiloCoreDeployments, SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";


contract CheckIrmConfig is ICheck {
    ISiloConfig.ConfigData internal configData;
    string internal siloName;

    string internal irmName;

    bool internal isKinkIrm;

    constructor(ISiloConfig.ConfigData memory _configData, bool _isSiloZero) {
        configData = _configData;
        siloName = _isSiloZero ? "silo0" : "silo1";
    }

    function checkName() external view override returns (string memory name) {
        name = string.concat(siloName, " IRM config should be known");
    }

    function successMessage() external view override returns (string memory message) {
        string memory oldIrm = string.concat(unicode"🚨", " OLD IRM ");
        message = string.concat("IRM is `", irmName, "`", isKinkIrm ? " (KINK)" : oldIrm);
    }

    function errorMessage() external pure override returns (string memory message) {
        message = "IRM is NOT known";
    }

    function execute() external override returns (bool result) {
        if (_isKinkIrm(configData.interestRateModel)) {
            isKinkIrm = true;
            (irmName, result) = Utils.findKinkIrmName(configData);
        } else {
            (irmName, result) = Utils.findIrmName(configData);
        }
    }

    function _isKinkIrm(address _irm) internal returns (bool isKinkIrm) {
        address factory = AddrLib.getAddress(SiloCoreContracts.DYNAMIC_KINK_MODEL_FACTORY);
        if (factory == address(0)) return false;
        
        return IDynamicKinkModelFactory(factory).createdByFactory(_irm);
    }
}
