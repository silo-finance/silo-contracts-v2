// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICheck} from "silo-core/deploy/silo/verifier/checks/ICheck.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

contract CheckHookOwner is ICheck {
    ISiloConfig.ConfigData internal configData;
    string internal siloName;
    address internal realOwner;

    constructor(ISiloConfig.ConfigData memory _configData, bool _isSiloZero) {
        configData = _configData;
        siloName = _isSiloZero ? "silo0" : "silo1";
    }

    function checkName() external view override returns (string memory name) {
        name = string.concat(siloName, " hook receiver owner is a DAO");
    }

    function successMessage() external override returns (string memory message) {
        message = string.concat("owner is a DAO ", Strings.toHexString(AddrLib.getAddress(AddrKey.DAO)));
    }

    function errorMessage() external view override returns (string memory message) {
        message = string.concat("owner is NOT a DAO ", Strings.toHexString(realOwner));
    }

    function execute() external override returns (bool result) {
        GaugeHookReceiver hookReceiver = GaugeHookReceiver(configData.hookReceiver);
        realOwner = Ownable(hookReceiver).owner();

        // check zero in case of DAO key is not set for a new chain.
        result = realOwner != address(0) && realOwner == AddrLib.getAddress(AddrKey.DAO);
    }
}
