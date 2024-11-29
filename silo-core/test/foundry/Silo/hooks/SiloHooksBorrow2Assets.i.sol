// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {HookReceiverMock} from "silo-core/test/foundry/_mocks/HookReceiverMock.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ContractThatAcceptsETH} from "silo-core/test/foundry/_mocks/ContractThatAcceptsETH.sol";
import {SiloStorageExtension} from "silo-core/test/foundry/_mocks/SiloStorageExtension.sol";
import {SiloFixtureWithVeSilo as SiloFixture} from "../../_common/fixtures/SiloFixtureWithVeSilo.sol";
import {SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {MintableToken} from "../../_common/MintableToken.sol";


contract HookReceiver is IHookReceiver, Test {
    bool imIn;

    uint24 hooksBefore;
    uint24 hooksAfter;
    ISiloConfig siloConfig;

    function initialize(ISiloConfig _siloConfig, bytes calldata) external {
        siloConfig = _siloConfig;
    }

    /// @notice state of Silo before action, can be also without interest, if you need them, call silo.accrueInterest()
    function beforeAction(address _silo, uint256 _action, bytes calldata _input) external {
        // return to not create infinite loop
        if (imIn) return;

        (address silo0, address silo1) = siloConfig.getSilos();

        imIn = true;
        address receiver;

        if (Hook.matchAction(Hook.BORROW, _action)) {
            Hook.BeforeBorrowInput memory input = Hook.beforeBorrowDecode(_input);
            receiver = input.receiver;

            // create debt in two silos
            vm.prank(receiver);
            ISilo(silo0).borrowSameAsset(1, receiver, receiver);
        } else if (Hook.matchAction(Hook.BORROW_SAME_ASSET, _action)) {
            Hook.BeforeBorrowInput memory input = Hook.beforeBorrowDecode(_input);
            receiver = input.receiver;

            // create debt in two silos
            vm.prank(receiver);
            ISilo(silo1).borrow(1, receiver, receiver);
        } else if (Hook.matchAction(Hook.SWITCH_COLLATERAL, _action)) {
            Hook.SwitchCollateralInput memory input = Hook.switchCollateralDecode(_input);
            receiver = input.user;

            // we want to use higher collateral, to create debt, and then when we back from hook,
            // we want to try to switch
            vm.prank(receiver);
            ISilo(silo1).borrow(1, receiver, receiver);
        } else {
            revert("should not happen");
        }

        imIn = false;
    }

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external {
        revert("not in use");
    }

    /// @notice return hooksBefore and hooksAfter configuration
    function hookReceiverConfig(address _silo) external view returns (uint24, uint24) {
        return (hooksBefore, hooksAfter);
    }

    function setBefore(uint24 _before) external {
        hooksBefore = _before;
    }
}

/*
FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mc SiloHooksBorrow2AssetsTest
*/
contract SiloHooksBorrow2AssetsTest is SiloLittleHelper, Test {
    address immutable BORROWER;
    address immutable DEPOSITOR;

    ISiloConfig internal _siloConfig;
    HookReceiver internal _hookReceiver;
    address internal _hookReceiverAddr;

    constructor() {
        BORROWER = makeAddr("BORROWER");
        DEPOSITOR = makeAddr("DEPOSITOR");
    }

    function setUp() public {
        _hookReceiver = new HookReceiver();
        _hookReceiverAddr = address(_hookReceiver);

        SiloFixture siloFixture = new SiloFixture();
        SiloConfigOverride memory configOverride;

        token0 = new MintableToken(18);
        token1 = new MintableToken(18);
        token0.setOnDemand(true);
        token1.setOnDemand(true);

        configOverride.token0 = address(token0);
        configOverride.token1 = address(token1);

        configOverride.hookReceiver = _hookReceiverAddr;
        configOverride.configName = SiloConfigsNames.LOCAL_DEPLOYER;

        (_siloConfig, silo0, silo1,,,) = siloFixture.deploy_local(configOverride);

        _depositCollateral(1e18, BORROWER, TWO_ASSETS);
        _depositForBorrow(10, DEPOSITOR);

        _hookReceiver.initialize(_siloConfig, "");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_borrow_2debt
    */
    function test_borrow_2debt() public {
        _hookReceiver.setBefore(uint24(Hook.BORROW));
        silo1.updateHooks();

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        vm.prank(BORROWER);
        silo1.borrow(8, BORROWER, BORROWER);

        _hookReceiver.setBefore(uint24(0));
        silo1.updateHooks();

        vm.prank(BORROWER);
        silo1.borrow(8, BORROWER, BORROWER);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_borrowSmeAsset_2debt
    */
    function test_borrowSmeAsset_2debt() public {
        _hookReceiver.setBefore(uint24(Hook.BORROW_SAME_ASSET));
        silo0.updateHooks();

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        vm.prank(BORROWER);
        silo0.borrowSameAsset(8, BORROWER, BORROWER);

        _hookReceiver.setBefore(uint24(0));
        silo0.updateHooks();

        vm.prank(BORROWER);
        silo0.borrowSameAsset(8, BORROWER, BORROWER);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_switchCollateralToThisSilo_debt
    */
    function test_switchCollateralToThisSilo_debt() public {
        _hookReceiver.setBefore(uint24(Hook.SWITCH_COLLATERAL));
        silo0.updateHooks();

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        vm.prank(BORROWER);
        silo0.borrowSameAsset(0.5e18, BORROWER, BORROWER);

        _hookReceiver.setBefore(uint24(0));
        silo0.updateHooks();

        vm.prank(BORROWER);
        silo0.borrowSameAsset(0.5e18, BORROWER, BORROWER);
    }
}
