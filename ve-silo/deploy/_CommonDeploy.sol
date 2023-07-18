// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";

library VeSiloContracts {
    // smart contracts list
    string public constant VOTING_ESCROW = "VotingEscrow.vy";
    string public constant VE_BOOST = "VeBoostV2.vy";
    string public constant TIMELOCK_CONTROLLER = "TimelockController.sol";
    string public constant SILO_GOVERNOR = "SiloGovernor.sol";
    string public constant GAUGE_CONTROLLER = "GaugeController.vy";
    string public constant SILO_LIQUIDITY_GAUGE = "SiloLiquidityGauge.vy";
    string public constant LIQUIDITY_GAUGE_FACTORY = "LiquidityGaugeFactory.sol";
    string public constant MAINNET_BALANCER_MINTER = "MainnetBalancerMinter.sol";
    string public constant BALANCER_TOKEN_ADMIN = "BalancerTokenAdmin.sol";
    string public constant OMNI_VOTING_ESCROW = "OmniVotingEscrow.sol";
    string public constant OMNI_VOTING_ESCROW_ADAPTER = "OmniVotingEscrowAdaptor.sol";
    string public constant VOTING_ESCROW_REMAPPER = "VotingEscrowRemapper.sol";
}

contract CommonDeploy is Deployer {
    // Common variables
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/ve-silo";
    string internal constant _DEPLOYMENTS_SUB_DIR = "ve-silo";

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return _DEPLOYMENTS_SUB_DIR;
    }
}
