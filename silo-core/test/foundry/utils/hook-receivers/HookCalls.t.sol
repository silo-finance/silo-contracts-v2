// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {SiloFixture, SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IHookReceiver} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

import {SiloLittleHelper} from  "../../_common/SiloLittleHelper.sol";
import {MintableToken} from "../../_common/MintableToken.sol";

/*
FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc HookCallsTest
*/
contract HookCallsTest is IHookReceiver, SiloLittleHelper, Test {
    using Hook for uint256;

    ISiloConfig internal _siloConfig;
    uint256 hookAfterFired;
    uint256 hookBeforeFired;

    function setUp() public {
        token0 = new MintableToken(6);
        token1 = new MintableToken(18);

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.hookReceiver = address(this);

        SiloFixture siloFixture = new SiloFixture();
        (_siloConfig, silo0, silo1,,, partialLiquidation) = siloFixture.deploy_local(overrides);

        silo0.updateHooks();
        silo1.updateHooks();
    }

    // FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt testReinitialization
    function test_ifHooksAreNotCalledInsideAction() public {
        (bool entered, uint256 status) = _siloConfig.crossReentrantStatus();
        assertFalse(entered, "dummy check");

        address depositor = makeAddr("depositor");
        address borrower = makeAddr("borrower");
        bool sameAsset = false;

        // execute all possible actions
        _depositForBorrow(200e18, depositor);

        vm.startPrank(borrower);

        _depositCollateral(200e18, borrower, sameAsset);
        _borrow(50e18, borrower, sameAsset);
        _repay(1e18, borrower);
        _withdraw(10e18, borrower);

        vm.warp(block.timestamp + 100);
        silo0.accrueInterest();
        silo1.accrueInterest();

//        silo0.transitionCollateral(100e18, borrower, ISilo.CollateralType.Protected);
//        silo0.switchCollateralTo(!sameAsset);

        // leverageSameAsset(uint256 _deposit, uint256 _borrow, address _borrower, CollateralType _collateralType);

//        function leverage(
//        uint256 _assets,
//        ILeverageBorrower _receiver,
//        address _borrower,
//        bool _sameAsset,
//        bytes calldata _data
//        );


        silo1.withdrawFees();
        vm.stopPrank();
    }

    function initialize(ISiloConfig _config, bytes calldata _data) external {
        assertEq(address(_siloConfig), address(_config), "SiloConfig addresses should match");
    }

    /// @notice state of Silo before action, can be also without interest, if you need them, call silo.accrueInterest()
    function beforeAction(address _silo, uint256 _action, bytes calldata _input) external {
        hookBeforeFired = _action;

        emit log_named_uint("[before] action", _action);
        (bool entered, uint256 status) = _siloConfig.crossReentrantStatus();

        assertFalse(entered, "hook before must be called before any action");
    }

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external {
        hookAfterFired = _action;

        emit log_named_uint("[after] action", _action);
        _printAction(_action);
        (bool entered, uint256 status) = _siloConfig.crossReentrantStatus();

        if (_action.matchAction(Hook.SHARE_TOKEN_TRANSFER)) {
            // decode args to see if we mint/burn
            (
                address sender,
                address recipient,
                uint256 amount,
                uint256 senderBalance,
                uint256 recipientBalance,
                uint256 totalSupply
            ) = Hook.afterTokenTransferDecode(_inputAndOutput);

            if (sender == address(0) || recipient == address(0)) {
                assertTrue(entered, "only when minting/burning we can be inside action");
            } else {
                assertFalse(entered, "hook after must be called after any action");
            }
        } else {
            assertFalse(entered, "hook after must be called after any action");
        }
    }

    /// @notice return hooksBefore and hooksAfter configuration
    function hookReceiverConfig(address _silo) external view returns (uint24 hooksBefore, uint24 hooksAfter) {
        // we want all possible combinations to be ON
        hooksBefore = type(uint24).max;
        hooksAfter = type(uint24).max;
    }

    function _printAction(uint256 _action) internal {
        if (_action.matchAction(Hook.SAME_ASSET)) emit log("SAME_ASSET");
        if (_action.matchAction(Hook.TWO_ASSETS)) emit log("TWO_ASSETS");
        if (_action.matchAction(Hook.BEFORE)) emit log("BEFORE");
        if (_action.matchAction(Hook.AFTER)) emit log("AFTER");
        if (_action.matchAction(Hook.DEPOSIT)) emit log("DEPOSIT");
        if (_action.matchAction(Hook.BORROW)) emit log("BORROW");
        if (_action.matchAction(Hook.REPAY)) emit log("REPAY");
        if (_action.matchAction(Hook.WITHDRAW)) emit log("WITHDRAW");
        if (_action.matchAction(Hook.LEVERAGE)) emit log("LEVERAGE");
        if (_action.matchAction(Hook.FLASH_LOAN)) emit log("FLASH_LOAN");
        if (_action.matchAction(Hook.TRANSITION_COLLATERAL)) emit log("TRANSITION_COLLATERAL");
        if (_action.matchAction(Hook.SWITCH_COLLATERAL)) emit log("SWITCH_COLLATERAL");
        if (_action.matchAction(Hook.LIQUIDATION)) emit log("LIQUIDATION");
        if (_action.matchAction(Hook.SHARE_TOKEN_TRANSFER)) emit log("SHARE_TOKEN_TRANSFER");
        if (_action.matchAction(Hook.COLLATERAL_TOKEN)) emit log("COLLATERAL_TOKEN");
        if (_action.matchAction(Hook.PROTECTED_TOKEN)) emit log("PROTECTED_TOKEN");
        if (_action.matchAction(Hook.DEBT_TOKEN)) emit log("DEBT_TOKEN");
//        if (_action.matchAction(Hook.SHARE_TOKEN_MINT)) emit log("SHARE_TOKEN_MINT");
//        if (_action.matchAction(Hook.SHARE_TOKEN_BURN)) emit log("SHARE_TOKEN_BURN");
    }
}
