// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {IBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IBalancerMinter.sol";
import {ISiloIncentivesController} from "../interfaces/ISiloIncentivesController.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";

/// @title VeSiloGaugeClaimingLogic example
contract VeSiloGaugeClaimingLogic {
    ISiloIncentivesController public immutable VAULT_INCENTIVES_CONTROLLER;
    address public immutable VE_SILO_GAUGE;
    address public immutable MINTER;
    address public immutable SILO_TOKEN; // ve-silo incentives token

    string public immutable SILO_PROGRAM_NAME;
    bytes32 public immutable SILO_PROGRAM_ID;

    constructor(
        address _vaultIncentivesController,
        address _veSiloGauge,
        address _minter,
        address _siloToken,
        string memory _siloProgramName
    ) {
        VAULT_INCENTIVES_CONTROLLER = ISiloIncentivesController(_vaultIncentivesController);
        VE_SILO_GAUGE = _veSiloGauge;
        MINTER = _minter;
        SILO_TOKEN = _siloToken;
        SILO_PROGRAM_NAME = _siloProgramName;
        SILO_PROGRAM_ID = VAULT_INCENTIVES_CONTROLLER.getProgramId(_siloProgramName);
    }

    function claimRewardsAndDistribute() external {
        uint256 siloIncentivesAmount = IBalancerMinter(MINTER).mintFor(VE_SILO_GAUGE, address(this));

        IERC20(SILO_TOKEN).transfer(address(VAULT_INCENTIVES_CONTROLLER), siloIncentivesAmount);

        // total staked amount via the `totalSupply()` fn or read from the storage if possible
        uint256 totalStaked = IERC20(address(VAULT_INCENTIVES_CONTROLLER)).totalSupply();

        VAULT_INCENTIVES_CONTROLLER.immediateDistribution(SILO_PROGRAM_ID, siloIncentivesAmount, totalStaked);
    }
}
