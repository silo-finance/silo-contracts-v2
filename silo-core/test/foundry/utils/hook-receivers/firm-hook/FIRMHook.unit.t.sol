// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {IFIRMHook} from "silo-core/contracts/interfaces/IFIRMHook.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {FIRMHook} from "silo-core/contracts/hooks/firm/FIRMHook.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {SiloShareTokenMock} from "silo-core/test/foundry/_mocks/SiloShareTokenMock.sol";

import {
    Silo0ProtectedSilo1CollateralOnly
} from "silo-core/contracts/hooks/_common/Silo0ProtectedSilo1CollateralOnly.sol";

import {
    IFixedInterestRateModel,
    IInterestRateModel
} from "silo-core/contracts/interestRateModel/fixedInterestRateModel/interfaces/IFixedInterestRateModel.sol";

/**
FOUNDRY_PROFILE=core_test forge test --ffi --mc FIRMHookUnitTest -vv
 */
contract FIRMHookUnitTest is Test {
    struct BorrowTestValues {
        uint256 borrowAmount;
        uint256 interestRate;
        uint256 timeToMaturity;
        uint256 totalFees;
        uint256 calculatedEffectiveRate;
        uint256 calculatedInterestPayment;
        uint256 expectedInterestPayment;
        uint256 expectedDaoDeployerRevenue;
        uint256 expectedInterestToDistribute;
    }

    FIRMHook internal _hook;
    
    Silo internal _silo0;
    Silo internal _silo1;

    address internal _token0 = makeAddr("Token0");
    address internal _token1 = makeAddr("Token1");
    address internal _siloFactory = makeAddr("SiloFactory");

    address internal _firm = makeAddr("Firm");
    address internal _firmVault = makeAddr("FirmVault");
    address internal _owner = makeAddr("Owner");
    address internal _borrower = makeAddr("borrower");
    uint256 internal _maturityDate = block.timestamp + 180 days;

    SiloConfig internal _siloConfig;

    function setUp() public {
        ISiloConfig.ConfigData memory silo1Config = _silo1Config();
        ISiloConfig.ConfigData memory silo0Config = _silo0Config();

        _systemSetupWithConfigs(silo0Config, silo1Config, _maturityDate);

        vm.label(_borrower, "borrower");
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
        uint256 depositActionProtected = Hook.depositAction(ISilo.CollateralType.Protected);
        uint256 depositActionCollateral = Hook.depositAction(ISilo.CollateralType.Collateral);

        (uint24 hooksBefore0, uint24 hooksAfter0) = _hook.hookReceiverConfig(address(_silo0));
        assertTrue(Hook.matchAction(hooksAfter0, protectedTransferAction), "Silo0 protected transfer");
        assertTrue(Hook.matchAction(hooksAfter0, collateralTransferAction), "Silo0 collateral transfer");
        assertTrue(Hook.matchAction(hooksBefore0, Hook.DEPOSIT), "Silo0 deposit");
        assertTrue(Hook.matchAction(hooksBefore0, depositActionProtected), "Silo0 protected deposit");

        (uint24 hooksBefore1, uint24 hooksAfter1) = _hook.hookReceiverConfig(address(_silo1));
        assertTrue(Hook.matchAction(hooksAfter1, protectedTransferAction), "Silo1 protected transfer");
        assertTrue(Hook.matchAction(hooksAfter1, collateralTransferAction), "Silo1 collateral transfer");
        assertTrue(Hook.matchAction(hooksBefore1, Hook.BORROW), "Silo1 borrow");
        assertTrue(Hook.matchAction(hooksBefore1, Hook.BORROW_SAME_ASSET), "Silo1 borrow same asset");
        assertTrue(Hook.matchAction(hooksBefore1, Hook.DEPOSIT), "Silo1 deposit");
        assertTrue(Hook.matchAction(hooksBefore1, depositActionCollateral), "Silo1 collateral deposit");
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

        vm.expectRevert(abi.encodeWithSelector(IFIRMHook.EmptyFirmVault.selector));
        hook.initialize(_siloConfig, abi.encode(_owner, address(0), _maturityDate));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_initialize_InvalidMaturityDate -vv
     */
    function test_firmHook_initialize_InvalidMaturityDate() public {
        FIRMHook hook = FIRMHook(Clones.clone(address(new FIRMHook())));
        
        vm.expectRevert(abi.encodeWithSelector(IFIRMHook.InvalidMaturityDate.selector));
        hook.initialize(_siloConfig, abi.encode(_owner, _firmVault, block.timestamp - 1));

        vm.expectRevert(abi.encodeWithSelector(IFIRMHook.InvalidMaturityDate.selector));
        hook.initialize(_siloConfig, abi.encode(_owner, _firmVault, type(uint64).max));
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
        vm.expectRevert(abi.encodeWithSelector(IFIRMHook.OnlyFIRMVaultOrFirmCanReceiveCollateral.selector));
        _hook.afterAction(address(_silo1), collateralTokenTransferAction, input);
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_afterTokenTransfer_recipientZero_doesNotRevert -vv
     */
    function test_firmHook_afterTokenTransfer_recipientZero_doesNotRevert() public {
        uint256 collateralTokenTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);

        bytes memory input = _getAfterTokenTransferInput(address(0));

        vm.prank(address(_silo1));
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
        vm.expectRevert(abi.encodeWithSelector(IFIRMHook.BorrowSameAssetNotAllowed.selector));
        _hook.beforeAction(address(_silo1), Hook.BORROW_SAME_ASSET, abi.encode(0));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_beforeBorrowAction_silo1_MaturityDateReached -vv
     */
    function test_firmHook_beforeBorrowAction_silo1_MaturityDateReached() public {
        vm.warp(block.timestamp + _maturityDate);

        vm.prank(address(_silo1));
        vm.expectRevert(abi.encodeWithSelector(IFIRMHook.MaturityDateReached.selector));
        _hook.beforeAction(address(_silo1), Hook.BORROW, abi.encode(0));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_beforeDepositAction_MaturityDateReached -vv
     */
    function test_firmHook_beforeDepositAction_MaturityDateReached() public {
        vm.warp(block.timestamp + _maturityDate);

        uint256 depositActionProtected = Hook.depositAction(ISilo.CollateralType.Protected);

        vm.prank(address(_silo0));
        vm.expectRevert(abi.encodeWithSelector(IFIRMHook.MaturityDateReached.selector));
        _hook.beforeAction(address(_silo0), depositActionProtected, abi.encode(0));

        uint256 depositActionCollateral = Hook.depositAction(ISilo.CollateralType.Collateral);

        vm.prank(address(_silo1));
        vm.expectRevert(abi.encodeWithSelector(IFIRMHook.MaturityDateReached.selector));
        _hook.beforeAction(address(_silo1), depositActionCollateral, abi.encode(0));
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_borrow_beforeAction_minimumInterest -vvv
     */
    function test_firmHook_borrow_beforeAction_minimumInterest() public {
        // Test that minimum interest payment of 10 wei is enforced
        // when calculated interest would be less than 10 wei

        BorrowTestValues memory values;

        // Test parameters - very small borrow amount and very short time
        values.borrowAmount = 1 wei; // Minimal borrow
        values.interestRate = 0.1e18; // 10% APR
        values.timeToMaturity = 1 seconds; // Very short time
        values.totalFees = 0.2e18; // 20% (10% dao + 10% deployer)

        vm.warp(_maturityDate - values.timeToMaturity);

        // Mock IRM with 10% APR
        _mockFixedIRMCalls(values.interestRate);

        // Calculate what the interest would be without minimum
        // Effective Interest Rate = 0.1e18 * 1 second / 365 days
        // = 0.1e18 * 1 / 31536000
        // = 100000000000000000 / 31536000 = 3170979 (about 0.000003171)
        values.calculatedEffectiveRate = values.interestRate * values.timeToMaturity / 365 days;
        
        // Interest Payment = 1 wei * 3170979 / 1e18 = 0 (rounds down to 0)
        values.calculatedInterestPayment = values.borrowAmount * values.calculatedEffectiveRate / 1e18;

        // The contract should enforce minimum of 10 wei
        values.expectedInterestPayment = 10; // Minimum enforced

        // DAO/Deployer Revenue with minimum interest
        // Revenue = 10 * 0.2e18 / 1e18 = 2
        values.expectedDaoDeployerRevenue = values.expectedInterestPayment * values.totalFees / 1e18;
        // = 10 * 200000000000000000 / 1e18 = 2

        // Interest to Distribute = 10 - 2 = 8
        values.expectedInterestToDistribute = values.expectedInterestPayment - values.expectedDaoDeployerRevenue;

        bytes memory input = _getBorrowInput(values.borrowAmount);

        (,address collateralShareToken, address debtShareToken) = _siloConfig.getShareTokens(address(_silo1));

        // Verify initial state
        assertEq(IERC20(collateralShareToken).balanceOf(_firm), 0, "FIRM should have no collateral shares initially");
        assertEq(IERC20(debtShareToken).balanceOf(_borrower), 0, "Borrower should have no debt shares initially");

        (uint192 revenueBefore,,, uint256 collateralAssetsBefore, uint256 debtAssetsBefore) = _silo1.getSiloStorage();

        assertEq(collateralAssetsBefore, 0, "No collateral assets initially");
        assertEq(debtAssetsBefore, 0, "No debt assets initially");
        assertEq(revenueBefore, 0, "No revenue initially");

        // Execute borrow action
        vm.prank(address(_silo1));
        _hook.beforeAction(address(_silo1), Hook.BORROW, input);

        // Verify final state
        (uint192 revenueAfter,,, uint256 collateralAssetsAfter, uint256 debtAssetsAfter) = _silo1.getSiloStorage();

        // Assert that minimum interest was enforced
        assertEq(values.calculatedInterestPayment, 0, "Calculated interest should round to 0");
        assertEq(debtAssetsAfter, values.expectedInterestPayment, "Debt should equal minimum interest payment of 10 wei");
        assertEq(collateralAssetsAfter, values.expectedInterestToDistribute, "Collateral should equal interest minus fees");
        assertEq(revenueAfter, values.expectedDaoDeployerRevenue, "Revenue should be calculated from minimum interest");

        // Verify exact expected values
        assertEq(values.expectedInterestPayment, 10, "Minimum interest should be 10 wei");
        assertEq(values.expectedDaoDeployerRevenue, 2, "Revenue should be 2 wei (20% of 10)");
        assertEq(values.expectedInterestToDistribute, 8, "Interest to distribute should be 8 wei");

        // Verify shares were minted correctly
        // Collateral shares: 8 * 1e3 = 8000 (with decimals offset)
        assertEq(IERC20(collateralShareToken).balanceOf(_firm), values.expectedInterestToDistribute * 1e3, "FIRM collateral shares");
        // Debt shares: 10 (no offset for debt)
        assertEq(IERC20(debtShareToken).balanceOf(_borrower), values.expectedInterestPayment, "Borrower debt shares");
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_borrow_beforeAction_minimumRevenue -vvv
     */
    function test_firmHook_borrow_beforeAction_minimumRevenue() public {
        // Test that minimum DAO/deployer revenue of 1 wei is enforced
        // when calculated revenue would be less than 1 wei
        _hook = FIRMHook(Clones.clone(address(new FIRMHook())));

        // Need to create a custom config with very low fees
        ISiloConfig.ConfigData memory silo0Config = _silo0Config();
        ISiloConfig.ConfigData memory silo1Config = _silo1Config();

        // Set very low fees that would result in revenue < 1 wei
        silo0Config.daoFee = 0.0001e18; // 0.01%
        silo0Config.deployerFee = 0.0001e18; // 0.01%
        silo1Config.daoFee = 0.0001e18; // 0.01%
        silo1Config.deployerFee = 0.0001e18; // 0.01%

        _systemSetupWithConfigs(silo0Config, silo1Config, _maturityDate);

        BorrowTestValues memory values;

        // Test parameters - small borrow amount with very low fees
        values.borrowAmount = 100 wei; // Small borrow
        values.interestRate = 0.1e18; // 10% APR  
        values.timeToMaturity = 10 seconds; // Short time
        values.totalFees = 0.0002e18; // 0.02% (0.01% dao + 0.01% deployer)

        vm.warp(_maturityDate - values.timeToMaturity);

        // Mock IRM with 10% APR
        _mockFixedIRMCalls(values.interestRate);

        // Calculate interest and revenue
        // Effective Interest Rate = 0.1e18 * 10 seconds / 365 days
        // = 0.1e18 * 10 / 31536000
        // = 100000000000000000 * 10 / 31536000 = 31709791983 (about 0.0000317098)
        values.calculatedEffectiveRate = values.interestRate * values.timeToMaturity / 365 days;

        // Interest Payment = 100 wei * 31709791983 / 1e18 = 0 (rounds down)
        // But minimum interest of 10 wei will be enforced
        values.calculatedInterestPayment = values.borrowAmount * values.calculatedEffectiveRate / 1e18;
        values.expectedInterestPayment = 10; // Minimum interest enforced

        // DAO/Deployer Revenue calculation
        // Revenue = 10 * 0.0002e18 / 1e18 = 0.002 = 0 (rounds down)
        // But minimum revenue of 1 wei will be enforced
        uint256 calculatedRevenue = values.expectedInterestPayment * values.totalFees / 1e18;
        values.expectedDaoDeployerRevenue = 1; // Minimum revenue enforced

        // Interest to Distribute = 10 - 1 = 9
        values.expectedInterestToDistribute = values.expectedInterestPayment - values.expectedDaoDeployerRevenue;

        bytes memory input = _getBorrowInput(values.borrowAmount);

        (,address collateralShareToken, address debtShareToken) = _siloConfig.getShareTokens(address(_silo1));

        // Verify initial state
        assertEq(IERC20(collateralShareToken).balanceOf(_firm), 0, "FIRM should have no collateral shares initially");
        assertEq(IERC20(debtShareToken).balanceOf(_borrower), 0, "Borrower should have no debt shares initially");

        (uint192 revenueBefore,,, uint256 collateralAssetsBefore, uint256 debtAssetsBefore) = _silo1.getSiloStorage();

        assertEq(collateralAssetsBefore, 0, "No collateral assets initially");
        assertEq(debtAssetsBefore, 0, "No debt assets initially");
        assertEq(revenueBefore, 0, "No revenue initially");

        // Execute borrow action
        vm.prank(address(_silo1));
        _hook.beforeAction(address(_silo1), Hook.BORROW, input);

        // Verify final state
        (uint192 revenueAfter,,, uint256 collateralAssetsAfter, uint256 debtAssetsAfter) = _silo1.getSiloStorage();

        // Assert that minimum revenue was enforced
        assertEq(calculatedRevenue, 0, "Calculated revenue should round to 0");
        assertEq(revenueAfter, values.expectedDaoDeployerRevenue, "Revenue should be minimum 1 wei");
        assertEq(debtAssetsAfter, values.expectedInterestPayment, "Debt should equal minimum interest payment");
        assertEq(collateralAssetsAfter, values.expectedInterestToDistribute, "Collateral should equal interest minus minimum revenue");

        // Verify exact expected values
        assertEq(values.expectedInterestPayment, 10, "Minimum interest should be 10 wei");
        assertEq(values.expectedDaoDeployerRevenue, 1, "Minimum revenue should be 1 wei");
        assertEq(values.expectedInterestToDistribute, 9, "Interest to distribute should be 9 wei");

        // Verify shares were minted correctly
        // Collateral shares: 9 * 1e3 = 9000 (with decimals offset)
        assertEq(IERC20(collateralShareToken).balanceOf(_firm), values.expectedInterestToDistribute * 1e3, "FIRM collateral shares");
        // Debt shares: 10 (no offset for debt)
        assertEq(IERC20(debtShareToken).balanceOf(_borrower), values.expectedInterestPayment, "Borrower debt shares");
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_borrow_beforeAction_highPrecision -vvv
     */
    function test_firmHook_borrow_beforeAction_highPrecision() public {
        // Test with non-round numbers to verify precision of calculations

        BorrowTestValues memory values;

        // Test parameters with non-round numbers
        values.borrowAmount = 1234567890123456789; // ~1.234 ETH
        values.interestRate = 0.0725e18; // 7.25% APR
        values.timeToMaturity = 90 days; // 90 days
        values.totalFees = 0.2e18; // 20% (10% dao + 10% deployer from setUp)

        vm.warp(_maturityDate - values.timeToMaturity);

        // Mock IRM with 7.25% APR
        _mockFixedIRMCalls(values.interestRate);

        // Calculate expected values with high precision
        // Effective Interest Rate = 0.0725e18 * 90 days / 365 days
        // = 72500000000000000 * 7776000 / 31536000
        // = 72500000000000000 * 7776000 / 31536000 = 17876712328767123
        values.calculatedEffectiveRate = values.interestRate * values.timeToMaturity / 365 days;

        // Interest Payment = 1234567890123456789 * 17876712328767123 / 1e18
        // Let's calculate this step by step:
        // = 1234567890123456789 * 17876712328767123 / 1000000000000000000
        // = 22070015022070014.547... rounds down to 22070015022070014
        values.expectedInterestPayment = values.borrowAmount * values.calculatedEffectiveRate / 1e18;

        // DAO/Deployer Revenue = 22070015022070014 * 0.2e18 / 1e18
        // = 22070015022070014 * 200000000000000000 / 1e18
        // = 4414003004414002.8 rounds down to 4414003004414002
        values.expectedDaoDeployerRevenue = values.expectedInterestPayment * values.totalFees / 1e18;

        // Interest to Distribute = 22070015022070014 - 4414003004414002
        // = 17656012017656012
        values.expectedInterestToDistribute = values.expectedInterestPayment - values.expectedDaoDeployerRevenue;

        bytes memory input = _getBorrowInput(values.borrowAmount);

        (,address collateralShareToken, address debtShareToken) = _siloConfig.getShareTokens(address(_silo1));

        // Verify initial state
        assertEq(IERC20(collateralShareToken).balanceOf(_firm), 0, "FIRM should have no collateral shares initially");
        assertEq(IERC20(debtShareToken).balanceOf(_borrower), 0, "Borrower should have no debt shares initially");
        
        (uint192 revenueBefore,,, uint256 collateralAssetsBefore, uint256 debtAssetsBefore) = _silo1.getSiloStorage();
        
        assertEq(collateralAssetsBefore, 0, "No collateral assets initially");
        assertEq(debtAssetsBefore, 0, "No debt assets initially");
        assertEq(revenueBefore, 0, "No revenue initially");

        // Execute borrow action
        vm.prank(address(_silo1));
        _hook.beforeAction(address(_silo1), Hook.BORROW, input);

        // Verify final state
        (uint192 revenueAfter,,, uint256 collateralAssetsAfter, uint256 debtAssetsAfter) = _silo1.getSiloStorage();

        // Assert exact calculated values
        assertEq(collateralAssetsAfter, values.expectedInterestToDistribute, "Collateral total should equal interest to distribute");
        assertEq(debtAssetsAfter, values.expectedInterestPayment, "Debt total should equal interest payment");
        assertEq(revenueAfter, values.expectedDaoDeployerRevenue, "Revenue should equal DAO/deployer revenue");

        // Verify exact expected values with high precision
        assertEq(values.calculatedEffectiveRate, 17876712328767123, "Effective interest rate calculation");
        assertEq(values.expectedInterestPayment, 22070015022070014, "Interest payment calculation");
        assertEq(values.expectedDaoDeployerRevenue, 4414003004414002, "DAO/Deployer revenue calculation");
        assertEq(values.expectedInterestToDistribute, 17656012017656012, "Interest to distribute calculation");

        // Verify shares were minted correctly
        // Collateral shares with 1e3 decimals offset
        assertEq(IERC20(collateralShareToken).balanceOf(_firm), values.expectedInterestToDistribute * 1e3, "FIRM collateral shares");
        // Debt shares (no offset for debt)
        assertEq(IERC20(debtShareToken).balanceOf(_borrower), values.expectedInterestPayment, "Borrower debt shares");
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_borrow_beforeAction_largeValues -vvv
     */
    function test_firmHook_borrow_beforeAction_largeValues() public {
        // Test with very large values to verify no overflow issues

        BorrowTestValues memory values;

        // Test parameters with large values
        values.borrowAmount = type(uint128).max; // Max uint128: 340282366920938463463374607431768211455
        values.interestRate = 1e18; // 100% APR (maximum realistic rate)
        values.timeToMaturity = 364 days; // Almost full year
        values.totalFees = 0.2e18; // 20% (10% dao + 10% deployer from setUp)

        uint256 maturityDate = block.timestamp + 365 days;
        _systemSetupWithConfigs(_silo0Config(), _silo1Config(), maturityDate);

        vm.warp(maturityDate - values.timeToMaturity);

        // Mock IRM with 100% APR
        _mockFixedIRMCalls(values.interestRate);

        // Calculate expected values with large numbers
        // Effective Interest Rate = 1e18 * 364 days / 365 days
        // = 1000000000000000000 * 31449600 / 31536000 = 997260273972602739
        values.calculatedEffectiveRate = values.interestRate * values.timeToMaturity / 365 days;

        // Interest Payment = type(uint128).max * 997260273972602739 / 1e18
        // = 340282366920938463463374607431768211455 * 997260273972602739 / 1e18
        // = 339350086463620823590393232523602564799 (actual value from test)
        values.expectedInterestPayment = values.borrowAmount * values.calculatedEffectiveRate / 1e18;

        // DAO/Deployer Revenue = 339350086463620823590393232523602564799 * 0.2e18 / 1e18
        // = 339350086463620823590393232523602564799 * 200000000000000000 / 1e18
        // = 67870017292724164718078646504720512959
        values.expectedDaoDeployerRevenue = values.expectedInterestPayment * values.totalFees / 1e18;

        // Interest to Distribute = 339350086463620823590393232523602564799 - 67870017292724164718078646504720512959
        // = 271480069170896658872314586018882051840
        values.expectedInterestToDistribute = values.expectedInterestPayment - values.expectedDaoDeployerRevenue;

        bytes memory input = _getBorrowInput(values.borrowAmount);

        (,address collateralShareToken, address debtShareToken) = _siloConfig.getShareTokens(address(_silo1));

        // Verify initial state
        assertEq(IERC20(collateralShareToken).balanceOf(_firm), 0, "FIRM should have no collateral shares initially");
        assertEq(IERC20(debtShareToken).balanceOf(_borrower), 0, "Borrower should have no debt shares initially");

        (uint192 revenueBefore,,, uint256 collateralAssetsBefore, uint256 debtAssetsBefore) = _silo1.getSiloStorage();

        assertEq(collateralAssetsBefore, 0, "No collateral assets initially");
        assertEq(debtAssetsBefore, 0, "No debt assets initially");
        assertEq(revenueBefore, 0, "No revenue initially");

        // Execute borrow action
        vm.prank(address(_silo1));
        _hook.beforeAction(address(_silo1), Hook.BORROW, input);

        // Verify final state
        (uint192 revenueAfter,,, uint256 collateralAssetsAfter, uint256 debtAssetsAfter) = _silo1.getSiloStorage();

        // Assert exact calculated values
        assertEq(collateralAssetsAfter, values.expectedInterestToDistribute, "Collateral total should equal interest to distribute");
        assertEq(debtAssetsAfter, values.expectedInterestPayment, "Debt total should equal interest payment");
        assertEq(revenueAfter, values.expectedDaoDeployerRevenue, "Revenue should equal DAO/deployer revenue");

        // Verify exact expected values for large numbers
        assertEq(values.calculatedEffectiveRate, 997260273972602739, "Effective interest rate calculation");
        assertEq(values.expectedInterestPayment, 339350086463620823590393232523602564799, "Interest payment calculation");
        assertEq(values.expectedDaoDeployerRevenue, 67870017292724164718078646504720512959, "DAO/Deployer revenue calculation");
        assertEq(values.expectedInterestToDistribute, 271480069170896658872314586018882051840, "Interest to distribute calculation");

        // Verify shares were minted correctly
        // Collateral shares with 1e3 decimals offset - use mulDiv to prevent overflow
        uint256 expectedCollateralShares = values.expectedInterestToDistribute * 1e3;
        assertEq(IERC20(collateralShareToken).balanceOf(_firm), expectedCollateralShares, "FIRM collateral shares");
        // Debt shares (no offset for debt)
        assertEq(IERC20(debtShareToken).balanceOf(_borrower), values.expectedInterestPayment, "Borrower debt shares");

        // Verify no overflow occurred (values should be reasonable)
        assertLt(values.expectedInterestPayment, type(uint256).max / 2, "Interest payment should not overflow");
        assertLt(values.expectedDaoDeployerRevenue, type(uint192).max, "Revenue fits in uint192");
    }

    /**
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmHook_borrow_beforeAction_standardCase -vvv
     */
    function test_firmHook_borrow_beforeAction_standardCase() public {
        // Test parameters
        uint256 borrowAmount = 100e18; // 100 ETH
        uint256 interestRate = 0.1e18; // 10% APR
        uint256 timeToMaturity = 180 days;

        // Mock IRM with 10% APR
        _mockFixedIRMCalls(interestRate);

        // Calculate expected values
        // Effective Interest Rate = rcur * interestTimeDelta / 365 days
        // = 0.1e18 * 180 days / 365 days
        // = 0.1e18 * 15552000 / 31536000
        // = 0.1e18 * 0.493150684931506849315...
        uint256 expectedEffectiveInterestRate = interestRate * timeToMaturity / 365 days;
        // = 100000000000000000 * 15552000 / 31536000 = 49315068493150684

        // Interest Payment = borrowAmount * effectiveInterestRate / 1e18
        // = 100e18 * 49315068493150684 / 1e18
        uint256 expectedInterestPayment = borrowAmount * expectedEffectiveInterestRate / 1e18;
        // = 100000000000000000000 * 49315068493150684 / 1e18 = 4931506849315068400

        // DAO and Deployer fees are each 10%, total 20%
        // DAO/Deployer Revenue = interestPayment * 0.2e18 / 1e18
        uint256 totalFees = 0.2e18; // 20% (10% dao + 10% deployer from setUp)
        uint256 expectedDaoDeployerRevenue = expectedInterestPayment * totalFees / 1e18;
        // = 4931506849315068400 * 200000000000000000 / 1e18 = 986301369863013680

        // Interest to Distribute = interestPayment - daoDeployerRevenue
        uint256 expectedInterestToDistribute = expectedInterestPayment - expectedDaoDeployerRevenue;
        // = 4931506849315068400 - 986301369863013680 = 3945205479452054720

        bytes memory input = _getBorrowInput(borrowAmount);

        (,address collateralShareToken, address debtShareToken) = _siloConfig.getShareTokens(address(_silo1));

        // Verify initial state
        assertEq(IERC20(collateralShareToken).balanceOf(_firm), 0, "FIRM should have no collateral shares initially");
        assertEq(IERC20(debtShareToken).balanceOf(_borrower), 0, "Borrower should have no debt shares initially");

        (uint192 revenueBefore,,, uint256 collateralAssetsBefore, uint256 debtAssetsBefore) = _silo1.getSiloStorage();

        assertEq(collateralAssetsBefore, 0, "No collateral assets initially");
        assertEq(debtAssetsBefore, 0, "No debt assets initially");
        assertEq(revenueBefore, 0, "No revenue initially");

        // Execute borrow action
        vm.prank(address(_silo1));
        _hook.beforeAction(address(_silo1), Hook.BORROW, input);

        // Verify final state
        (uint192 revenueAfter,,, uint256 collateralAssetsAfter, uint256 debtAssetsAfter) = _silo1.getSiloStorage();

        // Assert exact values
        assertEq(collateralAssetsAfter, expectedInterestToDistribute, "Collateral total should equal interest to distribute");
        assertEq(debtAssetsAfter, expectedInterestPayment, "Debt total should equal interest payment");
        assertEq(revenueAfter, expectedDaoDeployerRevenue, "Revenue should equal DAO/deployer revenue");

        // Verify exact calculated values
        assertEq(expectedEffectiveInterestRate, 49315068493150684, "Effective interest rate calculation");
        assertEq(expectedInterestPayment, 4931506849315068400, "Interest payment calculation");
        assertEq(expectedDaoDeployerRevenue, 986301369863013680, "DAO/Deployer revenue calculation");
        assertEq(expectedInterestToDistribute, 3945205479452054720, "Interest to distribute calculation");

        // Verify shares were minted correctly.
        // Since it's the first borrow, shares should be 1:1 with assets.
        // We multiply by 1e3 to account for decimals offset in the silo.
        assertEq(IERC20(collateralShareToken).balanceOf(_firm), expectedInterestToDistribute * 1e3, "FIRM should receive collateral shares");
        assertEq(IERC20(debtShareToken).balanceOf(_borrower), expectedInterestPayment, "Borrower should receive debt shares");
    }

    function _mockFixedIRMCalls() internal {
        _mockFixedIRMCalls(1e18); // Default to 100% APR for backward compatibility
    }

    function _mockFixedIRMCalls(uint256 _interestRate) internal {
        bytes memory inputAccrueInterest = abi.encodeWithSelector(IFixedInterestRateModel.accrueInterest.selector);

        vm.mockCall(address(_firm), inputAccrueInterest, abi.encode(true));
        vm.expectCall(address(_firm), inputAccrueInterest);

        bytes memory inputGetCurrentInterestRate = abi.encodeWithSelector(
            IInterestRateModel.getCurrentInterestRate.selector,
            address(_silo1),
            block.timestamp
        );

        vm.mockCall(address(_firm), inputGetCurrentInterestRate, abi.encode(_interestRate));
        vm.expectCall(address(_firm), inputGetCurrentInterestRate);

        bytes memory inputGetCompoundInterestRate = abi.encodeWithSelector(
            IInterestRateModel.getCompoundInterestRate.selector,
            address(_silo1),
            block.timestamp
        );

        vm.mockCall(address(_firm), inputGetCompoundInterestRate, abi.encode(0));
        vm.expectCall(address(_firm), inputGetCompoundInterestRate);
    }

    function _silo1Config() internal returns (ISiloConfig.ConfigData memory) {
        address collateralShareToken = address(new SiloShareTokenMock());
        address debtShareToken = address(new SiloShareTokenMock());

        vm.label(collateralShareToken, "collateralShareToken");
        vm.label(debtShareToken, "debtShareToken");

        return ISiloConfig.ConfigData({
            daoFee: 0.1e18,
            deployerFee: 0.1e18,
            silo: address(_silo1),
            token: _token1,
            protectedShareToken: _firm,
            collateralShareToken: collateralShareToken,
            debtShareToken: debtShareToken,
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
        address collateralShareToken = address(new SiloShareTokenMock());
        address debtShareToken = address(new SiloShareTokenMock());

        vm.label(collateralShareToken, "collateralShareToken");
        vm.label(debtShareToken, "debtShareToken");

        return ISiloConfig.ConfigData({
            daoFee: 0.1e18,
            deployerFee: 0.1e18,
            silo: address(_silo0),
            token: _token0,
            protectedShareToken: _firm,
            collateralShareToken: collateralShareToken,
            debtShareToken: debtShareToken,
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

    function _systemSetupWithConfigs(
        ISiloConfig.ConfigData memory _silo0ConfigData,
        ISiloConfig.ConfigData memory _silo1ConfigData,
        uint256 _siloMaturityDate
    ) internal {
        _hook = FIRMHook(Clones.clone(address(new FIRMHook())));

        _silo0 = Silo(payable(Clones.clone(address(new Silo(ISiloFactory(_siloFactory))))));
        _silo1 = Silo(payable(Clones.clone(address(new Silo(ISiloFactory(_siloFactory))))));

        _silo0ConfigData.silo = address(_silo0);
        _silo1ConfigData.silo = address(_silo1);

        _mockSynchronizeHooks(_silo0ConfigData.debtShareToken);
        _mockSynchronizeHooks(_silo0ConfigData.protectedShareToken);
        _mockSynchronizeHooks(_silo1ConfigData.debtShareToken);
        _mockSynchronizeHooks(_silo1ConfigData.protectedShareToken);

        _silo0ConfigData.hookReceiver = address(_hook);
        _silo1ConfigData.hookReceiver = address(_hook);

        _siloConfig = new SiloConfig(1, _silo0ConfigData, _silo1ConfigData);

        _silo0.initialize(_siloConfig);
        _silo1.initialize(_siloConfig);

        _hook.initialize(_siloConfig, abi.encode(_owner, _firmVault, _siloMaturityDate));
    }

    function _mockSynchronizeHooks(address _shareToken) internal {
        bytes memory input = abi.encodeWithSelector(IShareToken.synchronizeHooks.selector);

        vm.mockCall(address(_shareToken), input, abi.encode(true));
        vm.expectCall(address(_shareToken), input);
    }

    function _getBorrowInput(uint256 _borrowAmount) internal view returns (bytes memory input) {
        input = abi.encodePacked(
            _borrowAmount,
            _borrowAmount, // shares (1:1 initially)
            _borrower,
            _borrower,
            _borrower
        );
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
}
