// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloConfigsNames, SiloDeployments} from "silo-core/deploy/silo/SiloDeployments.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {GaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IGaugeLike} from "silo-core/contracts/interfaces/IGaugeLike.sol";
import {ShareTokenDecimalsPowLib} from "silo-core/test/foundry/_common/ShareTokenDecimalsPowLib.sol";
import {VeSiloFeatures} from "./VeSiloFeatures.sol";

/**
    Steps to run the test:

    1. Run Anvil './silo-core/test/scripts/anvil.sh'
    2. Run deployments './silo-core/test/scripts/mainnet-deployments.sh'
    3. Run test './silo-core/test/scripts/run-test.sh'
    4. Clean deployments artifacts './silo-core/test/scripts/deployments-clean.sh'
 */
contract SiloIntegrationTest is VeSiloFeatures {
    using ShareTokenDecimalsPowLib for uint256;

    function test_anvil_VeSiloWithSiloCoreAndSiloOracles() public {
        _printContracts();
        _configureSmartWalletChecker();
        _setVeSiloFees();
        _whiteListUser(_bob);

        uint256 siloTokens = 1000_000e18;
        deal(address(_siloToken), _bob, siloTokens);

        _getVotingPower(_bob, siloTokens);
        ISiloConfig siloConfig = ISiloConfig(SiloDeployments.get(getChainAlias(), SiloConfigsNames.SILO_FULL_CONFIG_TEST));
        _activeteBlancerTokenAdmin();
        (address hookReceiver, address shareToken) = _getHookReceiverForCollateralToken(siloConfig);
        address gauge = _createGauge(shareToken);
        _configureGaugeHookReceiver(hookReceiver, IShareToken(shareToken), gauge);
        _addGauge(gauge);
        _voteForGauge(gauge);
        _depositIntoSilo(siloConfig, ISiloLiquidityGauge(gauge));
        _checkpointUsers(ISiloLiquidityGauge(gauge));
        _verifyClaimable(ISiloLiquidityGauge(gauge));
        _getIncentives(gauge);
        _borrowFromSilo(siloConfig);
        _repay(siloConfig);
    }

    function _configureGaugeHookReceiver(address _hookReceiver, IShareToken _shareToken, address _gauge) internal {
         address[] memory targets = new address[](1);
         targets[0] = _hookReceiver;

        // Empty values
        uint256[] memory values = new uint256[](1);

        // Functions inputs
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(IGaugeHookReceiver.setGauge, (IGaugeLike(_gauge), _shareToken));

        assertEq(address(GaugeHookReceiver(_hookReceiver).configuredGauges(_shareToken)), address(0), "Hook receiver should not be initialized");

        _executeProposal(targets, values, calldatas);

        assertEq(address(GaugeHookReceiver(_hookReceiver).configuredGauges(_shareToken)), _gauge, "Hook receiver should be initialized");
    }

    function _depositIntoSilo(ISiloConfig _siloConfig, ISiloLiquidityGauge _gauge) internal {
        (,address silo1) = _siloConfig.getSilos();
        (, address collateralShareToken,) = _siloConfig.getShareTokens(silo1);

        uint256 amountToDeposit = 20_000e6;

        deal(address(_usdcToken), _bob, amountToDeposit);

        assertEq(IERC20(collateralShareToken).balanceOf(_bob), 0, "Should not have shares tokens");
        assertEq(_gauge.working_balances(_bob), 0, "Should not have working balance");

        vm.startPrank(_bob);
        _usdcToken.approve(silo1, amountToDeposit);
        ISilo(silo1).deposit(amountToDeposit, _bob, ISilo.CollateralType.Collateral);
        vm.stopPrank();

        assertEq(
            IERC20(collateralShareToken).balanceOf(_bob),
            amountToDeposit.decimalsOffsetPow(),
            "Invalid number of shares tokens"
        );

        assertEq(
            _gauge.working_balances(_bob),
            amountToDeposit.decimalsOffsetPow(),
            "Should have working balance"
        );
    }

    function _borrowFromSilo(ISiloConfig _siloConfig) internal {
        (address silo0, address silo1) = _siloConfig.getSilos();
        (,,address debtShareToken) = _siloConfig.getShareTokens(silo1);
        vm.label(debtShareToken, "silo1 debtShareToken");

        assertEq(IERC20(debtShareToken).balanceOf(_alice), 0, "Should not have debt shares tokens");

        uint256 amountToDeposit = 10e18;

        deal(address(_wethToken), _alice, amountToDeposit);

        vm.startPrank(_alice);
        _wethToken.approve(silo0, amountToDeposit);
        ISilo(silo0).deposit(amountToDeposit, _alice, ISilo.CollateralType.Collateral);
        vm.stopPrank();

        uint256 borrowAmount = ISilo(silo1).maxBorrow(_alice);

        vm.prank(_alice);
        ISilo(silo1).borrow(borrowAmount, _alice, _alice);

        assertEq(IERC20(debtShareToken).balanceOf(_alice), borrowAmount, "Should have debt shares tokens");
    }

    function _repay(ISiloConfig _siloConfig) internal {
        (, address silo1) = _siloConfig.getSilos();
        (,,address debtShareToken) = _siloConfig.getShareTokens(silo1);

        uint256 toRepay = ISilo(silo1).maxRepay(_alice);

        vm.startPrank(_alice);
        _usdcToken.approve(silo1, toRepay);
        ISilo(silo1).repay(toRepay, _alice);
        vm.stopPrank();

        assertEq(IERC20(debtShareToken).balanceOf(_alice), 0, "Should not have debt shares tokens");
    }

    function _getHookReceiverForCollateralToken(ISiloConfig _siloConfig) internal returns (address hookReceiver, address shareToken) {
        (,address silo1) = _siloConfig.getSilos();
        vm.label(silo1, "silo1");

        ISiloConfig.ConfigData memory cfg = _siloConfig.getConfig(silo1);
        hookReceiver = cfg.hookReceiver;
        shareToken = cfg.collateralShareToken;
    }

    function _printContracts() internal {
        emit log("Resolved smart contracts from deployments:");
        emit log("\n  ve-silo:");
        emit log_named_address("BalancerMinter", address(minter));
        emit log_named_address("GaugeController", address(gaugeController));
        emit log_named_address("BalancerTokenAdmin", address(balancerTokenAdmin));
        emit log_named_address("LiquidityGaugeFactory", address(factory));
        emit log_named_address("VeSilo", address(veSilo));
        emit log_named_address("SiloTimelockController", address(timelock));
        emit log_named_address("SiloGovernor", address(siloGovernor));
        emit log_named_address("GaugeAdder", address(gaugeAdder));
        emit log_named_address("SmartWalletChecker", address(smartWalletChecker));
        emit log("\n  silo-core:");
        emit log_named_address("SiloFactory", address(siloFactory));
        emit log_named_address("InterestRateModelV2", address(interestRateModelV2));
        emit log_named_address("InterestRateModelV2Factory", address(interestRateModelV2ConfigFactory));
        emit log_named_address("HookReceiver", address(gaugeHookReceiver));
        emit log("\n  silo-oracles:");
        emit log_named_address("ChainlinkV3OracleFactory", address(chainlinkV3OracleFactory));
        emit log_named_address("DIAOracleFactory", address(diaOracleFactory));
    }
}
