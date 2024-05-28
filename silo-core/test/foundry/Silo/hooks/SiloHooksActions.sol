// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {HookReceiverMock} from "silo-core/test/foundry/_mocks/HookReceiverMock.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {SiloFixtureWithFeeDistributor as SiloFixture} from "../../_common/fixtures/SiloFixtureWithFeeDistributor.sol";
import {SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {HookReceiverAllActionsWithEvents as HookMock} from "../../_mocks/HookReceiverAllActionsWithEvents.sol";

/// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mc SiloHooksActionsTest
contract SiloHooksActionsTest is SiloLittleHelper, Test, HookMock {
    using Hook for uint256;
 
    uint256 constant NO_ACTIONS = 0;
    uint256 constant SHARES_0 = 0;
    uint256 constant ASSETS_0 = 0;
    bool constant EXPECT_BEFORE = true;
    bool constant EXPECT_AFTER = false;

    SiloFixture internal _siloFixture;
    ISiloConfig internal _siloConfig;
    HookMock internal _siloHookReceiver;

    address internal _depositor = makeAddr("Depositor");

    // `HookReceiverAllActionsWithEvents` has a lot events
    // to avoid copying them all `SiloHooksActionsTest` derives from it so we can use them in the test
    constructor() HookMock(0, 0, 0, 0) {}

    function setUp() public {
        // Mock addresses that we need for the `SiloFactoryDeploy` script
        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, makeAddr("Timelock"));
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, makeAddr("FeeDistributor"));
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testDepositFnBeforeAfterHookActions
    function testDepositFnBeforeAfterHookActions() public {
        ISilo.CollateralType collateral = ISilo.CollateralType.Collateral;
        ISilo.CollateralType protected = ISilo.CollateralType.Protected;

        uint256 beforeActions = Hook.depositAction(collateral);
        uint256 afterActions = Hook.depositAction(protected);

        HookMock hookReceiverMock = new HookMock(beforeActions, NO_ACTIONS, NO_ACTIONS, afterActions);
        deploySiloWithHook(address(hookReceiverMock));

        uint256 amount = 1e18;

        _siloDepositWithEvent(silo0, token0, _depositor, _depositor, amount, collateral, EXPECT_BEFORE);
        _siloDepositWithEvent(silo1, token1, _depositor, _depositor, amount, protected, EXPECT_AFTER);

        // Ensure there are no other hook calls.
        _siloHookReceiver.revertAnyAction();
        // Following deposits should not trigger any hook. If it will trigger the hook will revert
        _siloDepositNoEvent(silo0, token0, _depositor, _depositor, amount, protected);
        _siloDepositNoEvent(silo1, token1, _depositor, _depositor, amount, collateral);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testDepositFnBothHookActions
    function testDepositFnBeforeAndAfterHookActions() public {
        ISilo.CollateralType collateral = ISilo.CollateralType.Collateral;
        ISilo.CollateralType protected = ISilo.CollateralType.Protected;

        uint256 beforeActions = Hook.depositAction(collateral)
            .addAction(Hook.depositAction(protected));

        uint256 afterActions = beforeActions;

        HookMock hookReceiverMock = new HookMock(beforeActions, afterActions, NO_ACTIONS, NO_ACTIONS);
        deploySiloWithHook(address(hookReceiverMock));

        uint256 amount = 1e18;

        _siloDepositBothEvents(silo0, token0, _depositor, _depositor, amount, collateral);
        _siloDepositBothEvents(silo0, token0, _depositor, _depositor, amount, protected);

        // Ensure there are no other hook calls.
        _siloHookReceiver.revertAnyAction();
        // Following deposits should not trigger any hook. If it will trigger the hook will revert
        _siloDepositNoEvent(silo1, token1, _depositor, _depositor, amount, collateral);
        _siloDepositNoEvent(silo1, token1, _depositor, _depositor, amount, protected);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testDepositFnAllHookActions
    function testDepositFnAllHookActions() public {
        ISilo.CollateralType collateral = ISilo.CollateralType.Collateral;
        ISilo.CollateralType protected = ISilo.CollateralType.Protected;

        uint256 beforeActions = Hook.depositAction(collateral)
            .addAction(Hook.depositAction(protected));

        uint256 afterActions = beforeActions
            .addAction(Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN))
            .addAction(Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN));

        HookMock hookReceiverMock = new HookMock(beforeActions, afterActions, NO_ACTIONS, NO_ACTIONS);
        deploySiloWithHook(address(hookReceiverMock));

        uint256 amount = 1e18;

        _siloDepositAllEvents(silo0, token0, _depositor, _depositor, amount, collateral);
        _siloDepositAllEvents(silo0, token0, _depositor, _depositor, amount, protected);

        // Ensure there are no other hook calls.
        _siloHookReceiver.revertAnyAction();
        // Following deposits should not trigger any hook. If it will trigger the hook will revert
        _siloDepositNoEvent(silo1, token1, _depositor, _depositor, amount, collateral);
        _siloDepositNoEvent(silo1, token1, _depositor, _depositor, amount, protected);
    }

    function _siloDepositWithEvent(
        ISilo _silo,
        MintableToken _token,
        address _receiver,
        address _depositorAddr,
        uint256 _amount,
        ISilo.CollateralType _collateralType,
        bool _expectBefore
    ) internal {
        _token.mint(_depositorAddr, _amount);

        vm.prank(_depositorAddr);
        _token.approve(address(_silo), _amount);

        vm.prank(_depositorAddr);
        vm.expectEmit(true, true, true, true);

        if (_expectBefore) {
            emit DepositBeforeHA(address(_silo), _amount, SHARES_0, _receiver, _collateralType);
        } else {
            emit DepositAfterHA(address(_silo), _amount, SHARES_0, _amount, _amount, _receiver, _collateralType);
        }

        _silo.deposit(_amount, _depositor, _collateralType);
    }

    function _siloDepositBothEvents(
        ISilo _silo,
        MintableToken _token,
        address _receiver,
        address _depositorAddr,
        uint256 _amount,
        ISilo.CollateralType _collateralType
    ) internal {
        _token.mint(_depositorAddr, _amount);

        vm.prank(_depositorAddr);
        _token.approve(address(_silo), _amount);

        vm.prank(_depositorAddr);

        vm.expectEmit(true, true, true, true);
        emit DepositBeforeHA(address(_silo), _amount, SHARES_0, _receiver, _collateralType);
        vm.expectEmit(true, true, true, true);
        emit DepositAfterHA(address(_silo), _amount, SHARES_0, _amount, _amount, _receiver, _collateralType);

        _silo.deposit(_amount, _depositorAddr, _collateralType);
    }

    function _siloDepositAllEvents(
        ISilo _silo,
        MintableToken _token,
        address _receiver,
        address _depositorAddr,
        uint256 _amount,
        ISilo.CollateralType _collateralType
    ) internal {
        _token.mint(_depositorAddr, _amount);

        vm.prank(_depositorAddr);
        _token.approve(address(_silo), _amount);

        vm.prank(_depositorAddr);

        vm.expectEmit(true, true, true, true);
        emit DepositBeforeHA(address(_silo), _amount, SHARES_0, _receiver, _collateralType);

        vm.expectEmit(true, true, true, true);

        emit ShareTokenAfterHA(
            address(_silo),
            address(0), // because we mint tokens on deposit
            _receiver,
            _amount,
            0, // not balance for the sender
            _amount, // balance
            _amount, // total supply
            _collateralType
        );

        vm.expectEmit(true, true, true, true);
        emit DepositAfterHA(address(_silo), _amount, SHARES_0, _amount, _amount, _receiver, _collateralType);

        _silo.deposit(_amount, _receiver, _collateralType);
    }

    function _siloDepositNoEvent(
        ISilo _silo,
        MintableToken _token,
        address _receiver,
        address _depositorAddr,
        uint256 _amount,
        ISilo.CollateralType _collateralType
    ) internal {
        _token.mint(_depositorAddr, _amount);

        vm.prank(_depositorAddr);
        _token.approve(address(_silo), _amount);

        vm.prank(_depositorAddr);
        _silo.deposit(_amount, _receiver, _collateralType);
    }

    function deploySiloWithHook(address _hookReceiver) internal {
        _siloFixture = new SiloFixture();
        SiloConfigOverride memory configOverride;

        configOverride.token0 = address(new MintableToken(18));
        configOverride.token1 = address(new MintableToken(18));
        configOverride.hookReceiverImplementation = _hookReceiver;
        configOverride.configName = SiloConfigsNames.LOCAL_DEPLOYER;

        (_siloConfig, silo0, silo1,,,) = _siloFixture.deploy_local(configOverride);

        __init(MintableToken(configOverride.token0), MintableToken(configOverride.token1), silo0, silo1);

        ISiloConfig.ConfigData memory configData = _siloConfig.getConfig(address(silo0));

        _siloHookReceiver = HookMock(configData.hookReceiver);
    }
}
