// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9.0;

import {Deployments} from "silo-foundry-utils/lib/Deployments.sol";

library SiloCoreContracts {
    // smart contracts list
    string public constant SILO_FACTORY = "SiloFactory.sol";
    string public constant INTEREST_RATE_MODEL_V2_FACTORY = "InterestRateModelV2Factory.sol";
    string public constant INTEREST_RATE_MODEL_V2 = "InterestRateModelV2.sol";
    string public constant GAUGE_HOOK_RECEIVER = "GaugeHookReceiver.sol";
    string public constant SILO_DEPLOYER = "SiloDeployer.sol";
    string public constant SILO = "Silo.sol";
    string public constant PARTIAL_LIQUIDATION = "PartialLiquidation.sol";
    string public constant LIQUIDATION_HELPER = "LiquidationHelper.sol";
    string public constant TOWER = "Tower.sol";
    string public constant SHARE_PROTECTED_COLLATERAL_TOKEN = "ShareProtectedCollateralToken.sol";
    string public constant SHARE_DEBT_TOKEN = "ShareDebtToken.sol";
    string public constant SILO_LENS = "SiloLens.sol";
    string public constant SILO_ROUTER = "SiloRouter.sol";
}

/// @notice SiloCoreDeployments library
/// @dev This library is used to get the deployed via deployment scripts address of the contracts.
/// Supported deployment scripts are in the `silo-core/deploy` directory except for the `silo`,
/// as it has a separate deployment script. Also, this library will not resolve the address of the
/// smart contract that was cloned during the `silo` deployment.
library SiloCoreDeployments {
    string public constant DEPLOYMENTS_DIR = "silo-core";

    function get(string memory _contract, string memory _network) internal returns (address) {
        return Deployments.getAddress(DEPLOYMENTS_DIR, _network, _contract);
    }
}
