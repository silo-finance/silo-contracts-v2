// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IInterestRateModelV2} from "./IInterestRateModelV2.sol";
import {ISiloConfig} from "./ISiloConfig.sol";

/// @notice Silo Deployer
interface ISiloDeployer {
    struct HookReceivers {
        address protectedHookReceiver;
        address collateralHookReceiver;
        address debtHookReceiver;
    }

    /// @dev Details of the oracle creation transaction
    struct OracleCreationTxData {
        address factory; // oracle factory (chainlinkV3, uniswapV3, etc)
        bytes txInput; // fn input `abi.encodeCall(fn, params...)`
    }

    /// @dev Oracles to be create during the Silo creation.
    /// If an oracle for the provided config is already created an oracle factory will return its address.
    struct Oracles {
        OracleCreationTxData solvencyOracle0;
        OracleCreationTxData maxLtvOracle0;
        OracleCreationTxData solvencyOracle1;
        OracleCreationTxData maxLtvOracle1;
    }

    /// @dev Emit after the Silo creation
    event SiloCreated(ISiloConfig siloConfig);

    /// @dev Revert if an oracle factory fails to create an oracle
    error FailedToCreateAnOracle(address _factory);

    /// @dev Revert if for the deployment provided both hook receiver and hook receiver implementation
    error HookReceiverMissconfigured();

    /// @notice Deploy silo
    /// @param _oracles Oracles to be create during the silo creation
    /// @param _irmConfigData0 IRM config data for a silo `_TOKEN0`
    /// @param _irmConfigData1 IRM config data for a silo `_TOKEN1`
    /// @param _siloInitData Silo configuration for the silo creation
    /// @param _hookReceiverImplementation Hook receiver implementation to clone (ignored if address(0))
    function deploy(
        Oracles calldata _oracles,
        IInterestRateModelV2.Config calldata _irmConfigData0,
        IInterestRateModelV2.Config calldata _irmConfigData1,
        ISiloConfig.InitData memory _siloInitData,
        address _hookReceiverImplementation
    )
        external
        returns (ISiloConfig siloConfig);
}
