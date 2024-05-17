// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISilo, IERC3156FlashLender} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {ILeverageBorrower} from "silo-core/contracts/interfaces/ILeverageBorrower.sol";
import {IHookReceiver} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {CrossEntrancy} from "silo-core/contracts/lib/CrossEntrancy.sol";

import {SiloLittleHelper} from  "../../_common/SiloLittleHelper.sol";
import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {SiloFixtureWithFeeDistributor as SiloFixture} from "../../_common/fixtures/SiloFixtureWithFeeDistributor.sol";

/*
FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc HookCallsOutsideActionTest
*/
contract HookCallsOutsideActionTest is IHookReceiver, ILeverageBorrower, IERC3156FlashBorrower, SiloLittleHelper, Test {
    using Hook for uint256;
    using SiloLensLib for ISilo;

    bytes32 internal constant _LEVERAGE_CALLBACK = keccak256("ILeverageBorrower.onLeverage");
    bytes32 constant FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    ISiloConfig internal _siloConfig;
    uint256 hookAfterFired;
    uint256 hookBeforeFired;

    function setUp() public {
        token0 = new MintableToken(6);
        token1 = new MintableToken(18);

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.hookReceiver = address(this);

        SiloFixture siloFixture = new SiloFixture();
        (_siloConfig, silo0, silo1,,, partialLiquidation) = siloFixture.deploy_local(overrides);

        silo0.updateHooks();
        silo1.updateHooks();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vv --mt test_ifHooksAreNotCalledInsideAction
    */
    function test_ifHooksAreNotCalledInsideAction() public {
        (bool entered, uint256 status) = _siloConfig.crossReentrantStatus();
        assertFalse(entered, "initial state for entered");
        assertEq(status, CrossEntrancy.NOT_ENTERED, "initial state for status");

        address depositor = makeAddr("depositor");
        address borrower = makeAddr("borrower");
        bool sameAsset = true;

        // execute all possible actions

        _depositForBorrow(200e18, depositor);

        _depositCollateral(200e18, borrower, !sameAsset);
        _borrow(50e18, borrower, !sameAsset);
        _repay(1e18, borrower);
        _withdraw(10e18, borrower);

        vm.warp(block.timestamp + 10);

        silo0.accrueInterest();
        silo1.accrueInterest();

        vm.prank(borrower);
        silo0.transitionCollateral(100e18, borrower, ISilo.CollateralType.Collateral);

        _depositCollateral(100e18, borrower, sameAsset);

        vm.prank(borrower);
        silo0.switchCollateralTo(sameAsset);

        vm.prank(borrower);
        silo1.leverageSameAsset(10, 1, borrower, ISilo.CollateralType.Protected);

        silo0.leverage(1e18, this, address(this), !sameAsset, abi.encode(address(silo1)));

        (
            address protectedShareToken, address collateralShareToken, address debtShareToken
        ) = _siloConfig.getShareTokens(address(silo1));

        vm.prank(borrower);
        IERC20(protectedShareToken).transfer(depositor, 1);

        vm.prank(borrower);
        IERC20(collateralShareToken).transfer(depositor, 1);

        vm.prank(depositor);
        IERC20R(debtShareToken).setReceiveApproval(borrower, 1);

        vm.prank(borrower);
        IERC20(debtShareToken).transfer(depositor, 1);

        vm.prank(borrower);
        silo1.withdraw(48e18, borrower, borrower);

        // TODO flashLoan
        silo0.flashLoan(this, address(token0), token0.balanceOf(address(silo0)), "");


        // TODO hook custom call


        // liquidation

        emit log_named_decimal_uint("borrower LTV", silo0.getLtv(borrower), 16);

        vm.warp(block.timestamp + 200 days);
        emit log_named_decimal_uint("borrower LTV", silo0.getLtv(borrower), 16);

        partialLiquidation.liquidationCall(
            address(silo1),
            address(token1),
            address(token1),
            borrower,
            type(uint256).max,
            false // _receiveSToken
        );

        emit log_named_decimal_uint("borrower LTV", silo0.getLtv(borrower), 16);

        silo1.withdrawFees();
    }

    function initialize(ISiloConfig _config, bytes calldata) external {
        assertEq(address(_siloConfig), address(_config), "SiloConfig addresses should match");
    }

    function beforeAction(address, uint256 _action, bytes calldata) external {
        hookBeforeFired = _action;

        (bool entered, uint256 status) = _siloConfig.crossReentrantStatus();

        if (entered && status == CrossEntrancy.ENTERED_FROM_LEVERAGE && _action.matchAction(Hook.DEPOSIT)) {
            // we inside leverage
        } else {
            assertFalse(entered, "hook before must be called before any action");
        }

        emit log_named_uint("[before] action", _action);
        _printAction(_action);
        emit log("[before] action --------------------- ");

    }

    function afterAction(address, uint256 _action, bytes calldata _inputAndOutput) external {
        hookAfterFired = _action;

        (bool entered,) = _siloConfig.crossReentrantStatus();

        if (_action.matchAction(Hook.SHARE_TOKEN_TRANSFER)) {
            (address sender, address recipient,,,,) = Hook.afterTokenTransferDecode(_inputAndOutput);

            if (sender == address(0) || recipient == address(0)) {
                assertTrue(entered, "only when minting/burning we can be inside action");
            } else {
                assertTrue(entered, "on regular transfer we are also inside action, silo is locked");
            }
        } else {
            assertFalse(entered, "hook after must be called after any action");
        }

        emit log_named_uint("[after] action", _action);
        _printAction(_action);
        emit log("[after] action --------------------- ");
    }

    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
        external
        returns (bytes32)
    {
        IERC20(_token).transfer(address(msg.sender), _amount);
        return FLASHLOAN_CALLBACK;
    }

    function hookReceiverConfig(address) external pure returns (uint24 hooksBefore, uint24 hooksAfter) {
        // we want all possible combinations to be ON
        hooksBefore = type(uint24).max;
        hooksAfter = type(uint24).max;
    }

    function onLeverage(address, address _borrower, address, uint256 _assets, bytes calldata _data)
        external
        returns (bytes32)
    {
        (address silo) = abi.decode(_data, (address));
        ISilo(silo).deposit(_assets * 2, _borrower, ISilo.CollateralType.Protected);

        return _LEVERAGE_CALLBACK;
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
    }
}
