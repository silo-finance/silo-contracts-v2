// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig, SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

// covered cases:
// - `withdraw`             no debt
// - `withdraw`             debt silo0  | debt not the same asset
// - `withdraw`             debt silo0  | debt same asset
// - `withdraw`             debt silo1  | debt not the same asset
// - `withdraw`             debt silo1  | debt same asset
// - `borrow`               no debt     | debt not the same asset
// - `borrow`               no debt     | debt the same asset
// - `transitionCollateral` no debt
// - `transitionCollateral` debt silo0  | debt not the same asset
// - `transitionCollateral` debt silo0  | debt the same asset
// - `transitionCollateral` debt silo1  | debt not the same asset
// - `transitionCollateral` debt silo1  | debt the same asset
// - `switchCollateralTo`   no debt     | swith not to the same asset
// - `switchCollateralTo`   no debt     | swith to the same asset
// - `switchCollateralTo`   debt silo0  | swith not to the same asset   | debt not the same asset
// - `switchCollateralTo`   debt silo0  | swith to the same asset       | debt not the same asset
// - `switchCollateralTo`   debt silo1  | swith not to the same asset   | debt not the same asset
// - `switchCollateralTo`   debt silo1  | swith to the same asset       | debt not the same asset
// - `switchCollateralTo`   debt silo0  | swith not to the same asset   | debt the same asset
// - `switchCollateralTo`   debt silo0  | swith to the same asset       | debt the same asset
// - `switchCollateralTo`   debt silo1  | swith not to the same asset   | debt the same asset
// - `switchCollateralTo`   debt silo1  | swith to the same asset       | debt the same asset
// - `liquidationCall`      debt silo0  | debt not the same asset
// - `liquidationCall`      debt silo0  | debt the same asset
// - `liquidationCall`      debt silo1  | debt not the same asset
// - `liquidationCall`      debt silo1  | debt the same asset
//
// FOUNDRY_PROFILE=core-test forge test -vv --mc OrderedConfigsTest
contract OrderedConfigsTest is Test {
    bool constant internal _SAME_ASSET = true;

    address internal _siloUser = makeAddr("siloUser");
    address internal _wrongSilo = makeAddr("wrongSilo");
    address internal _silo0 = makeAddr("silo0");
    address internal _silo1 = makeAddr("silo1");
    address internal _hookReceiver = makeAddr("hookReceiver");

    ISiloConfig.ConfigData internal _configData0;
    ISiloConfig.ConfigData internal _configData1;

    SiloConfig internal _siloConfig;

    function setUp() public {
        _configData0.silo = _silo0;
        _configData0.token = makeAddr("token0");
        _configData0.collateralShareToken = makeAddr("collateralShareToken0");
        _configData0.protectedShareToken = makeAddr("protectedShareToken0");
        _configData0.debtShareToken = makeAddr("debtShareToken0");
        _configData0.hookReceiver = _hookReceiver;

        _configData1.silo = _silo1;
        _configData1.token = makeAddr("token1");
        _configData1.collateralShareToken = makeAddr("collateralShareToken1");
        _configData1.protectedShareToken = makeAddr("protectedShareToken1");
        _configData1.debtShareToken = makeAddr("debtShareToken1");
        _configData1.hookReceiver = _hookReceiver;

        _siloConfig = siloConfigDeploy(1, _configData0, _configData1);

        _mockAccrueInterestCalls(_configData0, _configData1);
        _mockShareTokensBlances(_siloUser, 0, 0);
    }

    function siloConfigDeploy(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configDataInput0,
        ISiloConfig.ConfigData memory _configDataInput1
    ) public returns (SiloConfig siloConfig) {
        vm.assume(_configDataInput0.silo != _wrongSilo);
        vm.assume(_configDataInput1.silo != _wrongSilo);
        vm.assume(_configDataInput0.silo != _configDataInput1.silo);
        vm.assume(_configDataInput0.daoFee < 0.5e18);
        vm.assume(_configDataInput0.deployerFee < 0.5e18);

        // when using assume, it reject too many inputs
        _configDataInput0.hookReceiver = _configDataInput1.hookReceiver; 
        _configDataInput0.hookReceiver = _configDataInput1.hookReceiver;

        _configDataInput0.otherSilo = _configDataInput1.silo;
        _configDataInput1.otherSilo = _configDataInput0.silo;
        _configDataInput1.daoFee = _configDataInput0.daoFee;
        _configDataInput1.deployerFee = _configDataInput0.deployerFee;

        siloConfig = new SiloConfig(_siloId, _configDataInput0, _configDataInput1);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsWithdrawNoDebt
    function testOrderedConfigsWithdrawNoDebt() public view {
        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.withdrawAction(ISilo.CollateralType.Collateral)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertNoDebt(debtInfo);

        (collateralConfig, debtConfig,) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.withdrawAction(ISilo.CollateralType.Collateral)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertNoDebt(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsWithdrawDebtSilo0NotSameAsset
    function testOrderedConfigsWithdrawDebtSilo0NotSameAsset() public {
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;
        
        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.withdrawAction(ISilo.CollateralType.Collateral)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo0NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.withdrawAction(ISilo.CollateralType.Collateral)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsWithdrawDebtSilo1NotSameAsset
    function testOrderedConfigsWithdrawDebtSilo1NotSameAsset() public {
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;
        
        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.withdrawAction(ISilo.CollateralType.Collateral)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.withdrawAction(ISilo.CollateralType.Collateral)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo1NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsWithdrawWithDebtSilo0SameAsset
    function testOrderedConfigsWithdrawWithDebtSilo0SameAsset() public {
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;
        
        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.withdrawAction(ISilo.CollateralType.Collateral)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.withdrawAction(ISilo.CollateralType.Collateral)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0SameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsWithdrawWithDebtSilo1SameAsset
    function testOrderedConfigsWithdrawWithDebtSilo1SameAsset() public {
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;
        
        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.withdrawAction(ISilo.CollateralType.Collateral)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.withdrawAction(ISilo.CollateralType.Collateral)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsBorrowNoDebtNotSameAsset
    function testOrderedConfigsBorrowNoDebtNotSameAsset() public {
        vm.prank(_silo0);
        _siloConfig.setCollateralSilo(_siloUser, !_SAME_ASSET);

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        
        (collateralConfig, debtConfig) = _siloConfig.getConfigsForBorrow(_silo0, !_SAME_ASSET);

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);

        vm.prank(_silo1);
        _siloConfig.setCollateralSilo(_siloUser, !_SAME_ASSET);

        (collateralConfig, debtConfig) = _siloConfig.getConfigsForBorrow(_silo1, !_SAME_ASSET);

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsBorrowNoDebtSameAsset
    function testOrderedConfigsBorrowNoDebtSameAsset() public {
        vm.prank(_silo0);
        _siloConfig.setCollateralSilo(_siloUser, _SAME_ASSET);

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        
        (collateralConfig, debtConfig) = _siloConfig.getConfigsForBorrow(_silo0, _SAME_ASSET);

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);

        vm.prank(_silo1);
        _siloConfig.setCollateralSilo(_siloUser, _SAME_ASSET);

        (collateralConfig, debtConfig) = _siloConfig.getConfigsForBorrow(_silo1, _SAME_ASSET);

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsLeverageSameAssetsNoDebt
    function testOrderedConfigsLeverageSameAssetsNoDebt() public view {
        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.LEVERAGE_SAME_ASSET
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertNoDebt(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.LEVERAGE_SAME_ASSET
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertNoDebt(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsLeverageSameAssetsDebtSilo0NotSameAsset
    function testOrderedConfigsLeverageSameAssetsDebtSilo0NotSameAsset() public {
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.LEVERAGE_SAME_ASSET
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.LEVERAGE_SAME_ASSET
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsLeverageSameAssetsDebtSilo1NotSameAsset
    function testOrderedConfigsLeverageSameAssetsDebtSilo1NotSameAsset() public {
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.LEVERAGE_SAME_ASSET
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.LEVERAGE_SAME_ASSET
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo1DebtSilo1NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsLeverageSameAssetsDebtSilo0SameAsset
    function testOrderedConfigsLeverageSameAssetsDebtSilo0SameAsset() public {
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.LEVERAGE_SAME_ASSET
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.LEVERAGE_SAME_ASSET
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0SameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsLeverageSameAssetsDebtSilo1SameAsset
    function testOrderedConfigsLeverageSameAssetsDebtSilo1SameAsset() public {
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.LEVERAGE_SAME_ASSET
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.LEVERAGE_SAME_ASSET
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo1DebtSilo1SameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsTransitionCollateralNoDebt
    function testOrderedConfigsTransitionCollateralNoDebt() public view {
        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.TRANSITION_COLLATERAL
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertNoDebt(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.TRANSITION_COLLATERAL
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertNoDebt(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsTransitionCollateralDebtSilo0NotSameAsset
    function testOrderedConfigsTransitionCollateralDebtSilo0NotSameAsset() public {
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.TRANSITION_COLLATERAL
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.TRANSITION_COLLATERAL
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsTransitionCollateralDebtSilo0SameAsset
    function testOrderedConfigsTransitionCollateralDebtSilo0SameAsset() public {
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;
        
        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.TRANSITION_COLLATERAL
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.TRANSITION_COLLATERAL
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0SameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsTransitionCollateralDebtSilo1NotSameAsset
    function testOrderedConfigsTransitionCollateralDebtSilo1NotSameAsset() public {
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;
        
        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.TRANSITION_COLLATERAL
        );
        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.TRANSITION_COLLATERAL
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo1DebtSilo1NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedConfigsTransitionCollateralDebtSilo1SameAsset
    function testOrderedConfigsTransitionCollateralDebtSilo1SameAsset() public {
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;
        
        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.TRANSITION_COLLATERAL
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.TRANSITION_COLLATERAL
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo1DebtSilo1SameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedSwitchConfigsCollateralToNotSameAssetNoDebt
    function testOrderedSwitchConfigsCollateralToNotSameAssetNoDebt() public view {
        bool switchToSameAsset;

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertNoDebt(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertNoDebt(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedSwitchConfigsCollateralToSameAssetNoDebt
    function testOrderedSwitchConfigsCollateralToSameAssetNoDebt() public view {
        bool switchToSameAsset = true;

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertNoDebt(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertNoDebt(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedSwitchConfigsCollateralToNotSameDebtSilo0NotSameAsset
    function testOrderedSwitchConfigsCollateralToNotSameDebtSilo0NotSameAsset() public {
        bool switchToSameAsset;
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedSwitchConfigsCollateralToSameDebtSilo0NotSameAsset
    function testOrderedSwitchConfigsCollateralToSameDebtSilo0NotSameAsset() public {
        bool switchToSameAsset = true;
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedSwitchConfigsCollateralToNotSameDebtSilo1NotSameAsset
    function testOrderedSwitchConfigsCollateralToNotSameDebtSilo1NotSameAsset() public {
        bool switchToSameAsset;
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo1DebtSilo1NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedSwitchConfigsCollateralToSameDebtSilo1NotSameAsset
    function testOrderedSwitchConfigsCollateralToSameDebtSilo1NotSameAsset() public {
        bool switchToSameAsset = true;
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo1DebtSilo1NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedSwitchConfigsCollateralToNotSameDebtSilo0SameAsset
    function testOrderedSwitchConfigsCollateralToNotSameDebtSilo0SameAsset() public {
        bool switchToSameAsset;
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0SameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedSwitchConfigsCollateralToSameDebtSilo0SameAsset
    function testOrderedSwitchConfigsCollateralToSameDebtSilo0SameAsset() public {
        bool switchToSameAsset = true;
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0SameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedSwitchConfigsCollateralToNotSameDebtSilo1NotSameAsset
    function testOrderedSwitchConfigsCollateralToNotSameDebtSilo1SameAsset() public {
        bool switchToSameAsset;
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;
        
        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo1DebtSilo1SameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedSwitchConfigsCollateralToSameDebtSilo1SameAsset
    function testOrderedSwitchConfigsCollateralToSameDebtSilo1SameAsset() public {
        bool switchToSameAsset = true;
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.switchCollateralAction(switchToSameAsset)
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo1DebtSilo1SameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedLiqudaitionDebtSilo0NotSameAsset
    function testOrderedLiqudaitionDebtSilo0NotSameAsset() public {
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.LIQUIDATION
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.LIQUIDATION
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedLiqudaitionDebtSilo1NotSameAsset
    function testOrderedLiqudaitionDebtSilo1NotSameAsset() public {
        bool sameAsset;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.LIQUIDATION
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1NotSameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.LIQUIDATION
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo1DebtSilo1NotSameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedLiqudaitionDebtSilo0SameAsset
    function testOrderedLiqudaitionDebtSilo0SameAsset() public {
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 1, 0);

        vm.prank(_silo0);
        _siloConfig.accrueInterestAndGetConfigs(_silo0, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.LIQUIDATION
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo0DebtSilo0SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.LIQUIDATION
        );

        assertEq(collateralConfig.silo, _silo0);
        assertEq(debtConfig.silo, _silo0);
        _assertForSilo1DebtSilo0SameAsset(debtInfo);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt testOrderedLiqudaitionDebtSilo1SameAsset
    function testOrderedLiqudaitionDebtSilo1SameAsset() public {
        bool sameAsset = true;

        _mockShareTokensBlances(_siloUser, 0, 1);

        vm.prank(_silo1);
        _siloConfig.accrueInterestAndGetConfigs(_silo1, _siloUser, Hook.borrowAction(sameAsset));

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo0,
            _siloUser,
            Hook.LIQUIDATION
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo0DebtSilo1SameAsset(debtInfo);

        (collateralConfig, debtConfig, debtInfo) = _siloConfig.getConfigs(
            _silo1,
            _siloUser,
            Hook.LIQUIDATION
        );

        assertEq(collateralConfig.silo, _silo1);
        assertEq(debtConfig.silo, _silo1);
        _assertForSilo1DebtSilo1SameAsset(debtInfo);
    }

    function _assertNoDebt(ISiloConfig.DebtInfo memory _debtInfo) internal pure {
        assertEq(_debtInfo.debtPresent, false);
        assertEq(_debtInfo.sameAsset, false);
        assertEq(_debtInfo.debtInSilo0, false);
        assertEq(_debtInfo.debtInThisSilo, false);
    }

    function _assertForSilo0DebtSilo1SameAsset(ISiloConfig.DebtInfo memory _debtInfo) internal pure {
        assertEq(_debtInfo.debtPresent, true);
        assertEq(_debtInfo.sameAsset, true);
        assertEq(_debtInfo.debtInSilo0, false);
        assertEq(_debtInfo.debtInThisSilo, false);
    }

    function _assertForSilo1DebtSilo1SameAsset(ISiloConfig.DebtInfo memory _debtInfo) internal pure {
        assertEq(_debtInfo.debtPresent, true);
        assertEq(_debtInfo.sameAsset, true);
        assertEq(_debtInfo.debtInSilo0, false);
        assertEq(_debtInfo.debtInThisSilo, true);
    }

    function _assertForSilo0DebtSilo1NotSameAsset(ISiloConfig.DebtInfo memory _debtInfo) internal pure {
        assertEq(_debtInfo.debtPresent, true);
        assertEq(_debtInfo.sameAsset, false);
        assertEq(_debtInfo.debtInSilo0, false);
        assertEq(_debtInfo.debtInThisSilo, false);
    }

    function _assertForSilo1DebtSilo1NotSameAsset(ISiloConfig.DebtInfo memory _debtInfo) internal pure {
        assertEq(_debtInfo.debtPresent, true);
        assertEq(_debtInfo.sameAsset, false);
        assertEq(_debtInfo.debtInSilo0, false);
        assertEq(_debtInfo.debtInThisSilo, true);
    }

    function _assertForSilo0DebtSilo0SameAsset(ISiloConfig.DebtInfo memory _debtInfo) internal pure {
        assertEq(_debtInfo.debtPresent, true);
        assertEq(_debtInfo.sameAsset, true);
        assertEq(_debtInfo.debtInSilo0, true);
        assertEq(_debtInfo.debtInThisSilo, true);
    }

    function _assertForSilo1DebtSilo0SameAsset(ISiloConfig.DebtInfo memory _debtInfo) internal pure {
        assertEq(_debtInfo.debtPresent, true);
        assertEq(_debtInfo.sameAsset, true);
        assertEq(_debtInfo.debtInSilo0, true);
        assertEq(_debtInfo.debtInThisSilo, false);
    }

    function _assertForSilo0DebtSilo0NotSameAsset(ISiloConfig.DebtInfo memory _debtInfo) internal pure {
        assertEq(_debtInfo.debtPresent, true);
        assertEq(_debtInfo.sameAsset, false);
        assertEq(_debtInfo.debtInSilo0, true);
        assertEq(_debtInfo.debtInThisSilo, true);
    }

    function _assertForSilo1DebtSilo0NotSameAsset(ISiloConfig.DebtInfo memory _debtInfo) internal pure {
        assertEq(_debtInfo.debtPresent, true);
        assertEq(_debtInfo.sameAsset, false);
        assertEq(_debtInfo.debtInSilo0, true);
        assertEq(_debtInfo.debtInThisSilo, false);
    }

    function _mockAccrueInterestCalls(
        ISiloConfig.ConfigData memory _configDataInput0,
        ISiloConfig.ConfigData memory _configDataInput1
    ) internal {
        vm.mockCall(
            _silo0,
            abi.encodeCall(
                ISilo.accrueInterestForConfig,
                (_configDataInput0.interestRateModel, _configDataInput0.daoFee, _configDataInput0.deployerFee)
            ),
            abi.encode(true)
        );

        vm.mockCall(
            _silo1,
            abi.encodeCall(
                ISilo.accrueInterestForConfig,
                (_configDataInput1.interestRateModel, _configDataInput1.daoFee, _configDataInput1.deployerFee)
            ),
            abi.encode(true)
        );
    }

    function _mockShareTokensBlances(address _user, uint256 _balance0, uint256 _balance1) internal {
        vm.mockCall(
            _configData0.debtShareToken,
            abi.encodeCall(IERC20.balanceOf, _user),
            abi.encode(_balance0)
        );

        vm.mockCall(
            _configData1.debtShareToken,
            abi.encodeCall(IERC20.balanceOf, _user),
            abi.encode(_balance1)
        );
    }
}
