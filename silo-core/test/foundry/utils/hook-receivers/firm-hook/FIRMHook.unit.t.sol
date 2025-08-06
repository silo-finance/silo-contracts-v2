// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {FIRMHook} from "silo-core/contracts/hooks/firm/FIRMHook.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {
    Silo0ProtectedSilo1CollateralOnly
} from "silo-core/contracts/hooks/_common/Silo0ProtectedSilo1CollateralOnly.sol";

/**
FOUNDRY_PROFILE=core_test forge test --ffi --mc FIRMHookUnitTest -vv
 */
contract FIRMHookUnitTest is Test {
    FIRMHook internal _hook;
    
    Silo internal _silo0;
    Silo internal _silo1;

    address internal _token0 = makeAddr("Token0");
    address internal _token1 = makeAddr("Token1");
    address internal _siloFactory = makeAddr("SiloFactory");

    address internal _firm = makeAddr("Firm");
    address internal _firmVault = makeAddr("FirmVault");
    address internal _owner = makeAddr("Owner");
    uint256 internal _maturityDate = block.timestamp + 180 days;

    SiloConfig internal _siloConfig;

    function setUp() public {
        _hook = FIRMHook(Clones.clone(address(new FIRMHook())));

        _silo0 = Silo(payable(Clones.clone(address(new Silo(ISiloFactory(_siloFactory))))));
        _silo1 = Silo(payable(Clones.clone(address(new Silo(ISiloFactory(_siloFactory))))));

        ISiloConfig.ConfigData memory silo1Config = _silo1Config();
        ISiloConfig.ConfigData memory silo0Config = _silo0Config();

        _mockSynchronizeHooks(silo0Config.debtShareToken);
        _mockSynchronizeHooks(silo0Config.protectedShareToken);
        _mockSynchronizeHooks(silo1Config.debtShareToken);
        _mockSynchronizeHooks(silo1Config.protectedShareToken);

        silo1Config.hookReceiver = address(_hook);
        silo0Config.hookReceiver = address(_hook);

        _siloConfig = new SiloConfig(1, silo0Config, silo1Config);

        _silo0.initialize(_siloConfig);
        _silo1.initialize(_siloConfig);

        _hook.initialize(_siloConfig, abi.encode(_owner, _firmVault, _maturityDate));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_initialize -vv
     */
    function test_firmHook_initialize() public view {
        assertEq(_hook.maturityDate(), _maturityDate, "maturityDate");
        assertEq(_hook.firm(), _firm, "firm");
        assertEq(_hook.firmVault(), _firmVault, "firmVault");
        assertEq(Ownable(_hook).owner(), _owner, "owner");

        uint256 protectedTransferAction = Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN);
        uint256 collateralTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);

        (, uint24 hooksAfter0) = _hook.hookReceiverConfig(address(_silo0));
        assertTrue(Hook.matchAction(hooksAfter0, protectedTransferAction), "Silo0 protected transfer");
        assertTrue(Hook.matchAction(hooksAfter0, collateralTransferAction), "Silo0 collateral transfer");

        (uint24 hooksBefore1, uint24 hooksAfter1) = _hook.hookReceiverConfig(address(_silo1));
        assertTrue(Hook.matchAction(hooksAfter1, protectedTransferAction), "Silo1 protected transfer");
        assertTrue(Hook.matchAction(hooksAfter1, collateralTransferAction), "Silo1 collateral transfer");
        assertTrue(Hook.matchAction(hooksBefore1, Hook.BORROW), "Silo1 borrow");
        assertTrue(Hook.matchAction(hooksBefore1, Hook.BORROW_SAME_ASSET), "Silo1 borrow same asset");
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_initialize_InvalidInitialization -vv
     */
    function test_firmHook_initialize_InvalidInitialization() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        _hook.initialize(_siloConfig, abi.encode(makeAddr("otherOwner"), _firmVault, _maturityDate));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_initialize_EmptyFirmVault -vv
     */
    function test_firmHook_initialize_EmptyFirmVault() public {
        FIRMHook hook = FIRMHook(Clones.clone(address(new FIRMHook())));

        vm.expectRevert(abi.encodeWithSelector(FIRMHook.EmptyFirmVault.selector));
        hook.initialize(_siloConfig, abi.encode(_owner, address(0), _maturityDate));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_initialize_InvalidMaturityDate -vv
     */
    function test_firmHook_initialize_InvalidMaturityDate() public {
        FIRMHook hook = FIRMHook(Clones.clone(address(new FIRMHook())));
        
        vm.expectRevert(abi.encodeWithSelector(FIRMHook.InvalidMaturityDate.selector));
        hook.initialize(_siloConfig, abi.encode(_owner, _firmVault, block.timestamp - 1));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_initialize_Silo0LTVNotSet -vv
     */
    function test_firmHook_initialize_Silo0LTVNotSet() public {
        ISiloConfig.ConfigData memory silo1Config = _silo1Config();
        ISiloConfig.ConfigData memory silo0Config = _silo0Config();

        silo0Config.maxLtv = 0;

        ISiloConfig siloConfig = ISiloConfig(address(new SiloConfig(1, silo0Config, silo1Config)));

        FIRMHook hook = FIRMHook(Clones.clone(address(new FIRMHook())));

        vm.expectRevert(abi.encodeWithSelector(Silo0ProtectedSilo1CollateralOnly.Silo0LTVNotSet.selector));
        hook.initialize(siloConfig, abi.encode(_owner, _firmVault, _maturityDate));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_initialize_Silo1LTVMustBeZero -vv
     */
    function test_firmHook_initialize_Silo1LTVMustBeZero() public {
        ISiloConfig.ConfigData memory silo1Config = _silo1Config();
        ISiloConfig.ConfigData memory silo0Config = _silo0Config();

        silo1Config.maxLtv = 0.8e18;

        ISiloConfig siloConfig = ISiloConfig(address(new SiloConfig(1, silo0Config, silo1Config)));

        FIRMHook hook = FIRMHook(Clones.clone(address(new FIRMHook())));

        vm.expectRevert(abi.encodeWithSelector(Silo0ProtectedSilo1CollateralOnly.Silo1LTVMustBeZero.selector));
        hook.initialize(siloConfig, abi.encode(_owner, _firmVault, _maturityDate));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_afterAction_OnlySiloOrShareToken -vv
     */
    function test_firmHook_afterAction_OnlySiloOrShareToken() public {
        vm.expectRevert(abi.encodeWithSelector(IHookReceiver.OnlySiloOrShareToken.selector));
        _hook.afterAction(address(0), Hook.SHARE_TOKEN_TRANSFER, abi.encode(0));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_afterAction_invalidSilo -vv
     */
    function test_firmHook_afterAction_invalidSilo() public {
        vm.prank(address(_silo0));
        vm.expectRevert(abi.encodeWithSelector(Silo0ProtectedSilo1CollateralOnly.InvalidSilo.selector));
        _hook.afterAction(makeAddr("invalidSilo"), Hook.SHARE_TOKEN_TRANSFER, abi.encode(0));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_afterAction_CollateralTransferNotAllowed -vv
     */
    function test_firmHook_afterAction_CollateralTransferNotAllowed() public {
        uint256 collateralTokenTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);

        vm.prank(address(_silo0));
        vm.expectRevert(abi.encodeWithSelector(Silo0ProtectedSilo1CollateralOnly.CollateralTransferNotAllowed.selector));
        _hook.afterAction(address(_silo0), collateralTokenTransferAction, abi.encode(0));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_afterAction_ProtectedTransferNotAllowed -vv
     */
    function test_firmHook_afterAction_ProtectedTransferNotAllowed() public {
        uint256 protectedTokenTransferAction = Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN);

        vm.prank(address(_silo1));
        vm.expectRevert(abi.encodeWithSelector(Silo0ProtectedSilo1CollateralOnly.ProtectedTransferNotAllowed.selector));
        _hook.afterAction(address(_silo1), protectedTokenTransferAction, abi.encode(0));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_afterAction_OnlyFIRMVaultOrFirmCanReceiveCollateral -vv
     */
    function test_firmHook_afterAction_OnlyFIRMVaultOrFirmCanReceiveCollateral() public {
        uint256 collateralTokenTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);

        bytes memory input = _getAfterTokenTransferInput(makeAddr("otherRecipient"));

        vm.prank(address(_silo1));
        vm.expectRevert(abi.encodeWithSelector(FIRMHook.OnlyFIRMVaultOrFirmCanReceiveCollateral.selector));
        _hook.afterAction(address(_silo1), collateralTokenTransferAction, input);
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_afterAction_firmVault_recipient_doesNotRevert -vv
     */
    function test_firmHook_afterAction_firmVault_recipient_doesNotRevert() public {
        uint256 collateralTokenTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);

        bytes memory input = _getAfterTokenTransferInput(_firmVault);

        vm.prank(address(_silo1));
        _hook.afterAction(address(_silo1), collateralTokenTransferAction, input);
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_afterAction_firm_recipient_doesNotRevert -vv
     */
    function test_firmHook_afterAction_firm_recipient_doesNotRevert() public {
        uint256 collateralTokenTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);

        bytes memory input = _getAfterTokenTransferInput(_firm);

        vm.prank(address(_silo1));
        _hook.afterAction(address(_silo1), collateralTokenTransferAction, input);
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_afterAction_otherActions_doesNotRevert_fuzz -vv
     */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_firmHook_afterAction_otherActions_doesNotRevert_fuzz(uint8 _action, bool _isSilo0) public {
        // restricted actions:
        // - Silo0: collateral token transfer
        // - Silo1: protected token transfer

        address silo = _isSilo0 ? address(_silo0) : address(_silo1);

        // see silo-core/contracts/lib/Hook.sol
        if (_isSilo0) {
            vm.assume(_action != 12); // PROTECTED_TOKEN
        } else {
            vm.assume(_action != 11); // COLLATERAL_TOKEN
        }

        vm.prank(silo);
        _hook.afterAction(silo, 2 ** _action, abi.encode(0));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_mintSharesAndUpdateSiloState_reverts -vv
     */
    function test_firmHook_mintSharesAndUpdateSiloState_reverts() public {
        vm.expectRevert();
        _hook.mintSharesAndUpdateSiloState(1e18, 1e18, address(address(this)), 1e18, 1e18, 1e18, address(this));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_beforeAction_doesNothingForSilo0 -vv
     */
    function test_firmHook_beforeAction_doesNothingForSilo0() public {
        vm.prank(address(_silo0));
        _hook.beforeAction(address(_silo0), Hook.BORROW_SAME_ASSET, abi.encode(0));

        vm.prank(address(_silo0));
        _hook.beforeAction(address(_silo0), Hook.DEPOSIT, abi.encode(0));

        bytes memory input = abi.encode(
            uint256(1e18),
            uint256(1e18),
            address(this),
            address(this),
            address(this)
        );

        uint256 collateralTotalBefore = _silo0.getTotalAssetsStorage(ISilo.AssetType.Collateral);
        uint256 debtTotalBefore = _silo0.getTotalAssetsStorage(ISilo.AssetType.Debt);

        assertEq(collateralTotalBefore, 0, "collateralTotalBefore");
        assertEq(debtTotalBefore, 0, "debtTotalBefore");

        vm.prank(address(_silo0));
        _hook.beforeAction(address(_silo0), Hook.BORROW, input);

        uint256 collateralTotalAfter = _silo0.getTotalAssetsStorage(ISilo.AssetType.Collateral);
        uint256 debtTotalAfter = _silo0.getTotalAssetsStorage(ISilo.AssetType.Debt);

        assertEq(collateralTotalAfter, 0, "collateralTotalAfter");
        assertEq(debtTotalAfter, 0, "debtTotalAfter");
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_beforeAction_silo1_BorrowSameAssetNotAllowed -vv
     */
    function test_firmHook_beforeAction_silo1_BorrowSameAssetNotAllowed() public {
        vm.prank(address(_silo1));
        vm.expectRevert(abi.encodeWithSelector(FIRMHook.BorrowSameAssetNotAllowed.selector));
        _hook.beforeAction(address(_silo1), Hook.BORROW_SAME_ASSET, abi.encode(0));
    }



    function _silo1Config() internal returns (ISiloConfig.ConfigData memory) {
        return ISiloConfig.ConfigData({
            daoFee: 0.1e18,
            deployerFee: 0.1e18,
            silo: address(_silo1),
            token: _token1,
            protectedShareToken: _firm,
            collateralShareToken: address(new ERC20Mock()),
            debtShareToken: address(new ERC20Mock()),
            solvencyOracle: address(0),
            maxLtvOracle: address(0),
            interestRateModel: _firm,
            maxLtv: 0,
            lt: 0,
            liquidationTargetLtv: 0,
            liquidationFee: 0,
            flashloanFee: 0,
            hookReceiver: address(0),
            callBeforeQuote: false
        });
    }

    function _silo0Config() internal returns (ISiloConfig.ConfigData memory) {
        return ISiloConfig.ConfigData({
            daoFee: 0.1e18,
            deployerFee: 0.1e18,
            silo: address(_silo0),
            token: _token0,
            protectedShareToken: _firm,
            collateralShareToken: address(new ERC20Mock()),
            debtShareToken: address(new ERC20Mock()),
            solvencyOracle: address(0),
            maxLtvOracle: address(0),
            interestRateModel: _firm,
            maxLtv: 0.8e18,
            lt: 0.8e18,
            liquidationTargetLtv: 0.8e18,
            liquidationFee: 0.01e18,
            flashloanFee: 0.01e18,
            hookReceiver: address(0),
            callBeforeQuote: false
        });
    }

    function _getAfterTokenTransferInput(address _recipient) internal pure returns (bytes memory input) {
        input = abi.encodePacked(
            address(0),
            _recipient,
            uint256(1e18),
            uint256(1e18),
            uint256(1e18),
            uint256(1e18)
        );
    }

    function _mockSynchronizeHooks(address _shareToken) internal {
        bytes memory input = abi.encodeWithSelector(IShareToken.synchronizeHooks.selector);

        vm.mockCall(address(_shareToken), input, abi.encode(true));
        vm.expectCall(address(_shareToken), input);
    }
}
