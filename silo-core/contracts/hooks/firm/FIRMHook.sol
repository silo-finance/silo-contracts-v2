// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {PartialLiquidation} from "silo-core/contracts/hooks/liquidation/PartialLiquidation.sol";
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IFIRMHook} from "silo-core/contracts/interfaces/IFIRMHook.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {ShareTokenLib} from "silo-core/contracts/lib/ShareTokenLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {FIRMHookStorage} from "silo-core/contracts/hooks/firm/FIRMHookStorage.sol";

import {
    Silo0ProtectedSilo1CollateralOnly
} from "silo-core/contracts/hooks/_common/Silo0ProtectedSilo1CollateralOnly.sol";

import {
    IFixedInterestRateModel
} from "silo-core/contracts/interestRateModel/fixedInterestRateModel/interfaces/IFixedInterestRateModel.sol";

/// @title Fixed Interest Rate Model Hook
/// @dev We assume that `Silo0` is always a collateral silo, and `Silo1` is always the silo from which users borrow.
/// And this is guaranteed by `Silo0ProtectedSilo1CollateralOnly` hook.
/// `FIRMHook` supports the following actions:
/// - before deposit for `Silo0` and `Silo1` (verifies maturity date)
/// - before borrow same asset for `Silo1` (not allowed)
/// - before borrow for `Silo1` (executes FIRM logic see `_beforeBorrowAction`)
/// - after token transfer for `Silo0` and `Silo1` (verifies recipient)
/// - after token transfer for `Silo0` (allows only protected token deposits/transfers)
/// - after token transfer for `Silo1` (allows only collateral token deposits/transfers)
contract FIRMHook is
    IFIRMHook,
    GaugeHookReceiver,
    PartialLiquidation,
    Silo0ProtectedSilo1CollateralOnly
{
    using Hook for uint256;

    /// @inheritdoc IFIRMHook
    function mintSharesAndUpdateSiloState(
        uint256 _debtShares,
        uint256 _collateralShares,
        address _borrower,
        uint256 _interestToDistribute,
        uint256 _interestPayment,
        uint192 _daoAndDeployerRevenue,
        address _firm
    ) external {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        // Update Silo state
        $.totalAssets[ISilo.AssetType.Collateral] += _interestToDistribute;
        $.totalAssets[ISilo.AssetType.Debt] += _interestPayment;
        $.daoAndDeployerRevenue += _daoAndDeployerRevenue;

        // Mint shares
        ISiloConfig config = ShareTokenLib.getShareTokenStorage().siloConfig;

        (, address collateral, address debt) = config.getShareTokens(address(this));

        IShareToken(debt).mint(_borrower, _borrower, _debtShares);
        IShareToken(collateral).mint(_firm, _firm, _collateralShares);
    }

    /// @inheritdoc IFIRMHook
    function maturityDate() external view returns (uint256 maturity) {
        maturity = FIRMHookStorage.maturityDate();
    }

    /// @inheritdoc IFIRMHook
    function firm() external view returns (address firmAddress) {
        firmAddress = FIRMHookStorage.firm();
    }

    /// @inheritdoc IFIRMHook
    function firmVault() external view returns (address firmVaultAddress) {
        firmVaultAddress = FIRMHookStorage.firmVault();
    }

    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _config, bytes calldata _data)
        public
        initializer
        virtual
    {
        address owner;
        address siloFirmVault;
        uint256 siloMaturityDate;

        (owner, siloFirmVault, siloMaturityDate) = abi.decode(_data, (address, address, uint256));

        BaseHookReceiver.__BaseHookReceiver_init(_config);
        GaugeHookReceiver.__GaugeHookReceiver_init(owner);
        FIRMHook.__FIRMHook_init(siloMaturityDate, siloFirmVault);
        Silo0ProtectedSilo1CollateralOnly.__Silo0ProtectedSilo1CollateralOnly_init();
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySilo()
        override
    {
        if (_action.matchAction(Hook.DEPOSIT)) {
            require(FIRMHookStorage.maturityDate() >= block.timestamp, MaturityDateReached());
        }

        (, address silo1) = siloConfig.getSilos();
        if (_silo != silo1) return;

        require(!_action.matchAction(Hook.BORROW_SAME_ASSET), BorrowSameAssetNotAllowed());

        if (_action.matchAction(Hook.BORROW)) {
            _beforeBorrowAction(ISilo(silo1), _inputAndOutput);
        }
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySiloOrShareToken()
        override(
            GaugeHookReceiver,
            Silo0ProtectedSilo1CollateralOnly,
            IHookReceiver
        )
    {
        Silo0ProtectedSilo1CollateralOnly.afterAction(_silo, _action, _inputAndOutput);

        (,address silo1) = siloConfig.getSilos();
        uint256 collateralTokenTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);

        if (_silo == silo1 && _action.matchAction(collateralTokenTransferAction)) {
            Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);

            require(
                input.recipient == address(0) || // allow to burn collateral shares
                input.recipient == FIRMHookStorage.firmVault() ||
                input.recipient == FIRMHookStorage.firm(),
                OnlyFIRMVaultOrFirmCanReceiveCollateral()
            );
        }
    }

    /// @notice Initialize the FIRM hook
    /// @param _maturityDate maturity date of the FIRM
    /// @param _firmVault vault address for the firm market
    function __FIRMHook_init(uint256 _maturityDate, address _firmVault) internal {
        require(_maturityDate > block.timestamp && _maturityDate < type(uint64).max, InvalidMaturityDate());
        require(_firmVault != address(0), EmptyFirmVault());

        (address silo0, address silo1) = siloConfig.getSilos();
        ISiloConfig.ConfigData memory silo1Config = siloConfig.getConfig(silo1);

        FIRMHookStorage.FIRMHookStorageData storage $ = FIRMHookStorage.get();

        $.maturityDate = uint64(_maturityDate);
        $.firmVault = _firmVault;
        $.firm = silo1Config.interestRateModel;

        _configureHooks(silo0, silo1);
    }

    /// @notice Configure the hooks for the FIRM hook
    /// silo0: after token transfer, before protected deposit
    /// silo1: after token transfer, before borrow, before borrow same asset, before collateral deposit
    function _configureHooks(address _silo0, address _silo1) internal {
        uint256 protectedTransferAction = Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN);
        uint256 collateralTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);

        // Silo0 hooks configuration
        uint256 hooksAfter0 = _getHooksAfter(_silo0);
        hooksAfter0 = hooksAfter0.addAction(protectedTransferAction);
        hooksAfter0 = hooksAfter0.addAction(collateralTransferAction);

        uint256 hooksBefore0 = _getHooksBefore(_silo0);

        uint256 depositActionProtected = Hook.depositAction(ISilo.CollateralType.Protected);
        hooksBefore0 = hooksBefore0.addAction(depositActionProtected);

        _setHookConfig(_silo0, uint24(hooksBefore0), uint24(hooksAfter0));

        // Silo1 hooks configuration
        uint256 hooksAfter1 = _getHooksAfter(_silo1);
        hooksAfter1 = hooksAfter1.addAction(protectedTransferAction);
        hooksAfter1 = hooksAfter1.addAction(collateralTransferAction);

        uint256 hooksBefore1 = _getHooksBefore(_silo1);
        hooksBefore1 = hooksBefore1.addAction(Hook.BORROW);
        hooksBefore1 = hooksBefore1.addAction(Hook.BORROW_SAME_ASSET);

        uint256 depositActionCollateral = Hook.depositAction(ISilo.CollateralType.Collateral);
        hooksBefore1 = hooksBefore1.addAction(depositActionCollateral);

        _setHookConfig(_silo1, uint24(hooksBefore1), uint24(hooksAfter1));
    }

    /// @notice Before borrow action for `Silo1`
    /// @param _inputAndOutput input of the borrow action (see `Hook.BeforeBorrowInput`)
    function _beforeBorrowAction(ISilo _silo1, bytes calldata _inputAndOutput) internal {
        uint64 maturity = FIRMHookStorage.maturityDate();
        require(maturity >= block.timestamp, MaturityDateReached());

        IFixedInterestRateModel fixedIRM = IFixedInterestRateModel(FIRMHookStorage.firm());

        fixedIRM.accrueInterest();

        Hook.BeforeBorrowInput memory borrowInput = Hook.beforeBorrowDecode(_inputAndOutput);

        uint256 interestTimeDelta = maturity - block.timestamp;
        uint256 rcur = fixedIRM.getCurrentInterestRate(address(_silo1), block.timestamp);
        uint256 effectiveInterestRate = rcur * interestTimeDelta / 365 days;
        uint256 interestPayment = borrowInput.assets * effectiveInterestRate / 1e18;

        // minimal interest is 10 wei to make sure
        // an attacker can not round down interest to 0.
        if (interestPayment < 10) interestPayment = 10;

        uint192 daoAndDeployerRevenue = _getDaoAndDeployerRevenue(address(_silo1), interestPayment);
        uint256 interestToDistribute = interestPayment - daoAndDeployerRevenue;

        bytes memory input = abi.encodeWithSelector(
            this.mintSharesAndUpdateSiloState.selector,
            _silo1.convertToShares(interestPayment, ISilo.AssetType.Debt),
            _silo1.convertToShares(interestToDistribute, ISilo.AssetType.Collateral),
            borrowInput.borrower,
            interestToDistribute,
            interestPayment,
            daoAndDeployerRevenue,
            fixedIRM
        );

        _silo1.callOnBehalfOfSilo({
            _target: address(this),
            _value: 0,
            _callType: ISilo.CallType.Delegatecall,
            _input: input
        });
    }

    /// @notice Get the dao and deployer revenue
    /// @param _silo address of the silo
    /// @param _interestPayment amount of interest payment
    /// @return daoAndDeployerRevenue amount of dao and deployer revenue
    function _getDaoAndDeployerRevenue(address _silo, uint256 _interestPayment)
        internal
        view
        returns (uint192 daoAndDeployerRevenue)
    {
        (uint256 daoFee, uint256 deployerFee,,) = siloConfig.getFeesWithAsset(_silo);
        uint256 fees = daoFee + deployerFee;

        daoAndDeployerRevenue = uint192(_interestPayment * fees / 1e18);
        if (daoAndDeployerRevenue == 0) daoAndDeployerRevenue = 1;
    }
}
