// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IInterestRateModelV2} from "./IInterestRateModelV2.sol";
import {ISiloConfig} from "./ISiloConfig.sol";

interface ISiloDeployer {
    struct HookReceivers {
        address protectedHookReceiver;
        address collateralHookReceiver;
        address debtHookReceiver;
    }

    struct OracleCreationTxData {
        address factory;
        bytes txInput;
    }

    struct Oracles {
        OracleCreationTxData solvencyOracle0;
        OracleCreationTxData maxLtvOracle0;
        OracleCreationTxData solvencyOracle1;
        OracleCreationTxData maxLtvOracle1;
    }

    event SiloCreated(ISiloConfig siloConfig);

    error FailedToCreateAnOracle(address _factory);

    function deploy(
        Oracles calldata _oracles,
        IInterestRateModelV2.Config calldata _irmConfigData0,
        IInterestRateModelV2.Config calldata _irmConfigData1,
        ISiloConfig.InitData memory _siloInitData
    )
        external
        returns (ISiloConfig siloConfig);
}