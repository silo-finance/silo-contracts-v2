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
 
    uint256 constant public NO_ACTIONS = 0;
    uint256 constant public SHARES_0 = 0;
    uint256 constant public ASSETS_0 = 0;
    bool constant public EXPECT_BEFORE = true;
    bool constant public EXPECT_AFTER = false;

    ISilo.CollateralType constant public COLLATERAL = ISilo.CollateralType.Collateral;
    ISilo.CollateralType constant public PROTECTED = ISilo.CollateralType.Protected;

    SiloFixture internal _siloFixture;
    ISiloConfig internal _siloConfig;
    HookMock internal _siloHookReceiver;

    address internal _depositor = makeAddr("Depositor");
    address internal _borrower = makeAddr("Borrower");

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
        uint256 beforeActions = Hook.depositAction(COLLATERAL);
        uint256 afterActions = Hook.depositAction(PROTECTED);

        HookMock hookReceiverMock = new HookMock(beforeActions, NO_ACTIONS, NO_ACTIONS, afterActions);
        deploySiloWithHook(address(hookReceiverMock));

        uint256 amount = 1e18;

        _siloDepositWithHook(silo0, token0, _depositor, _depositor, amount, COLLATERAL, EXPECT_BEFORE);
        _siloDepositWithHook(silo1, token1, _depositor, _depositor, amount, PROTECTED, EXPECT_AFTER);

        // Ensure there are no other hook calls.
        _siloHookReceiver.revertAnyAction();
        // Following deposits should not trigger any hook. If it will trigger the hook will revert
        _siloDepositWithoutHook(silo0, token0, _depositor, _depositor, amount, PROTECTED);
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, COLLATERAL);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testDepositFnBeforeAndAfterHookActions
    function testDepositFnBeforeAndAfterHookActions() public {
        uint256 beforeActions = Hook.depositAction(COLLATERAL)
            .addAction(Hook.depositAction(PROTECTED));

        uint256 afterActions = beforeActions;

        HookMock hookReceiverMock = new HookMock(beforeActions, afterActions, NO_ACTIONS, NO_ACTIONS);
        deploySiloWithHook(address(hookReceiverMock));

        uint256 amount = 1e18;

        _siloDepositBothHooks(silo0, token0, _depositor, _depositor, amount, COLLATERAL);
        _siloDepositBothHooks(silo0, token0, _depositor, _depositor, amount, PROTECTED);

        // Ensure there are no other hook calls.
        _siloHookReceiver.revertAnyAction();
        // Following deposits should not trigger any hook. If it will trigger the hook will revert
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, COLLATERAL);
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, PROTECTED);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testDepositFnAllHookActions
    function testDepositFnAllHookActions() public {
        uint256 beforeActions = Hook.depositAction(COLLATERAL)
            .addAction(Hook.depositAction(PROTECTED));

        uint256 afterActions = beforeActions
            .addAction(Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN))
            .addAction(Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN));

        HookMock hookReceiverMock = new HookMock(beforeActions, afterActions, NO_ACTIONS, NO_ACTIONS);
        deploySiloWithHook(address(hookReceiverMock));

        uint256 amount = 1e18;

        _siloDepositAllHooks(silo0, token0, _depositor, _depositor, amount, COLLATERAL);
        _siloDepositAllHooks(silo0, token0, _depositor, _depositor, amount, PROTECTED);

        // Ensure there are no other hook calls.
        _siloHookReceiver.revertAnyAction();
        // Following deposits should not trigger any hook. If it will trigger the hook will revert
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, COLLATERAL);
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, PROTECTED);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testWithdrawFnBeforeAfterHookActions
    function testWithdrawFnBeforeAfterHookActions() public {
        uint256 beforeActions = Hook.withdrawAction(COLLATERAL);
        uint256 afterActions = Hook.withdrawAction(PROTECTED);

        HookMock hookReceiverMock = new HookMock(beforeActions, NO_ACTIONS, NO_ACTIONS, afterActions);
        deploySiloWithHook(address(hookReceiverMock));

        uint256 amount = 1e18;

        _siloDepositWithoutHook(silo0, token0, _depositor, _depositor, amount, COLLATERAL);
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, PROTECTED);

        _siloWithdrawWithHook(silo0, _depositor, _depositor, _depositor, amount, COLLATERAL, EXPECT_BEFORE);
        _siloWithdrawWithHook(silo1, _depositor, _depositor, _depositor, amount, PROTECTED, EXPECT_AFTER);

        // Ensure there are no other hook calls.
        _siloHookReceiver.revertAnyAction();
        // Following deposits should not trigger any hook. If it will trigger the hook will revert
        _siloDepositWithoutHook(silo0, token0, _depositor, _depositor, amount, PROTECTED);
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, COLLATERAL);
        _siloWithdrawWithoutHook(silo0, _depositor, _depositor, _depositor, amount, PROTECTED);
        _siloWithdrawWithoutHook(silo1, _depositor, _depositor, _depositor, amount, COLLATERAL);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testWithdrawFnBeforeAndAfterHookActions
    function testWithdrawFnBeforeAndAfterHookActions() public {
        uint256 beforeActions = Hook.withdrawAction(COLLATERAL).addAction(Hook.withdrawAction(PROTECTED));
        
        uint256 afterActions = beforeActions;

        HookMock hookReceiverMock = new HookMock(beforeActions, afterActions, NO_ACTIONS, NO_ACTIONS);
        deploySiloWithHook(address(hookReceiverMock));

        uint256 amount = 1e18;

        _siloDepositWithoutHook(silo0, token0, _depositor, _depositor, amount, COLLATERAL);
        _siloDepositWithoutHook(silo0, token0, _depositor, _depositor, amount, PROTECTED);

        _siloWithdrawBothHooks(silo0, _depositor, _depositor, _depositor, amount, COLLATERAL);
        _siloWithdrawBothHooks(silo0, _depositor, _depositor, _depositor, amount, PROTECTED);

        // Ensure there are no other hook calls.
        _siloHookReceiver.revertAnyAction();
        // Following deposits should not trigger any hook. If it will trigger the hook will revert
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, PROTECTED);
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, COLLATERAL);
        _siloWithdrawWithoutHook(silo1, _depositor, _depositor, _depositor, amount, PROTECTED);
        _siloWithdrawWithoutHook(silo1, _depositor, _depositor, _depositor, amount, COLLATERAL);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testWithdrawFnAllHookActions
    function testWithdrawFnAllHookActions() public {
        uint256 beforeActions = Hook.withdrawAction(COLLATERAL).addAction(Hook.withdrawAction(PROTECTED));
        
        uint256 afterActions = beforeActions
            .addAction(Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN))
            .addAction(Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN));

        HookMock hookReceiverMock = new HookMock(beforeActions, afterActions, NO_ACTIONS, NO_ACTIONS);
        deploySiloWithHook(address(hookReceiverMock));

        uint256 amount = 1e18;

        _siloDepositWithoutHook(silo0, token0, _depositor, _depositor, amount, COLLATERAL);
        _siloDepositWithoutHook(silo0, token0, _depositor, _depositor, amount, PROTECTED);

        _siloWithdrawAllHooks(silo0, _depositor, _depositor, _depositor, amount, COLLATERAL);
        _siloWithdrawAllHooks(silo0, _depositor, _depositor, _depositor, amount, PROTECTED);

        // Ensure there are no other hook calls.
        _siloHookReceiver.revertAnyAction();
        // Following deposits should not trigger any hook. If it will trigger the hook will revert
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, PROTECTED);
        _siloDepositWithoutHook(silo1, token1, _depositor, _depositor, amount, COLLATERAL);
        _siloWithdrawWithoutHook(silo1, _depositor, _depositor, _depositor, amount, PROTECTED);
        _siloWithdrawWithoutHook(silo1, _depositor, _depositor, _depositor, amount, COLLATERAL);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testBorrowNotLeverageNotSameAsset
    function testBorrowNotLeverageNotSameAsset() public {
        uint256 beforeActions = Hook.borrowAction(_NOT_LEVERAGE, _NOT_SAME_ASSET);
        uint256 afterActions = beforeActions;

        HookMock hookReceiverMock = new HookMock(beforeActions, afterActions, NO_ACTIONS, NO_ACTIONS);
        deploySiloWithHook(address(hookReceiverMock));

        uint256 depositAmount = 100e18;
        uint256 collateralAmount = 100e18;
        uint256 borrowAmount = 1e18;

        _siloDepositWithoutHook(silo0, token0, _depositor, _depositor, depositAmount, COLLATERAL);
        _siloDepositWithoutHook(silo1, token1, _borrower, _borrower, collateralAmount, PROTECTED);

        _siloBorrowBothHooks(silo0, _borrower, _borrower, borrowAmount, _NOT_SAME_ASSET);
    }

    function _siloDepositWithHook(
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

    function _siloDepositBothHooks(
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

    function _siloDepositAllHooks(
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
            0, // no balance for the sender
            _amount, // balance
            _amount, // total supply
            _collateralType
        );

        vm.expectEmit(true, true, true, true);
        emit DepositAfterHA(address(_silo), _amount, SHARES_0, _amount, _amount, _receiver, _collateralType);

        _silo.deposit(_amount, _receiver, _collateralType);
    }

    function _siloDepositWithoutHook(
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

    function _siloWithdrawWithHook(
        ISilo _silo,
        address _receiver,
        address _owner,
        address _spender,
        uint256 _amount,
        ISilo.CollateralType _collateralType,
        bool _expectBefore
    ) internal {
        vm.expectEmit(true, true, true, true);

        if (_expectBefore) {
            emit WithdrawBeforeHA(address(_silo), _amount, SHARES_0, _receiver, _owner, _spender, _collateralType);
        } else {
            emit WithdrawAfterHA(
                address(_silo),
                _amount,
                SHARES_0,
                _receiver,
                _owner,
                _spender,
                _amount,
                _amount,
                _collateralType
            );
        }

        vm.prank(_spender);
        _silo.withdraw(_amount, _receiver, _owner, _collateralType);
    }

    function _siloWithdrawBothHooks(
        ISilo _silo,
        address _receiver,
        address _owner,
        address _spender,
        uint256 _amount,
        ISilo.CollateralType _collateralType
    ) internal {
        vm.expectEmit(true, true, true, true);
        emit WithdrawBeforeHA(address(_silo), _amount, SHARES_0, _receiver, _owner, _spender, _collateralType);

        vm.expectEmit(true, true, true, true);

        emit WithdrawAfterHA(
            address(_silo),
            _amount,
            SHARES_0,
            _receiver,
            _owner,
            _spender,
            _amount,
            _amount,
            _collateralType
        );

        vm.prank(_spender);
        _silo.withdraw(_amount, _receiver, _owner, _collateralType);
    }

    function _siloWithdrawAllHooks(
        ISilo _silo,
        address _receiver,
        address _owner,
        address _spender,
        uint256 _amount,
        ISilo.CollateralType _collateralType
    ) internal {
        vm.expectEmit(true, true, true, true);
        emit WithdrawBeforeHA(address(_silo), _amount, SHARES_0, _receiver, _owner, _spender, _collateralType);

        vm.expectEmit(true, true, true, true);

        emit ShareTokenAfterHA(
            address(_silo),
            _receiver,
            address(0), // because we burn tokens on withdrawal
            _amount,
            0, // no balance for the sender
            0, // no balance
            0, // mo total supply
            _collateralType
        );

        vm.expectEmit(true, true, true, true);

        emit WithdrawAfterHA(
            address(_silo),
            _amount,
            SHARES_0,
            _receiver,
            _owner,
            _spender,
            _amount,
            _amount,
            _collateralType
        );

        vm.prank(_spender);
        _silo.withdraw(_amount, _receiver, _owner, _collateralType);
    }

    function _siloWithdrawWithoutHook(
        ISilo _silo,
        address _receiver,
        address _owner,
        address _spender,
        uint256 _amount,
        ISilo.CollateralType _collateralType
    ) internal {
        vm.prank(_spender);
        _silo.withdraw(_amount, _receiver, _owner, _collateralType);
    }

    function _siloBorrowBothHooks(
        ISilo _silo,
        address _borrowerAddr,
        address _receiver,
        uint256 _amount,
        bool _isSameAsset
    ) internal {
        vm.expectEmit(true, true, true, true);
        emit BorrowBeforeHA(address(_silo), _amount, SHARES_0, _borrowerAddr, _receiver, _NOT_LEVERAGE, _isSameAsset);

        vm.expectEmit(true, true, true, true);

        emit BorrowAfterHA(
            address(_silo),
            _amount,
            SHARES_0,
            _borrowerAddr,
            _receiver,
            _amount,
            _amount,
            _NOT_LEVERAGE,
            _isSameAsset
        );

        vm.prank(_borrowerAddr);
        _silo.borrow(_amount, _borrowerAddr, _receiver, _isSameAsset);
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
