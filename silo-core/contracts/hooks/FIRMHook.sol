// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {PartialLiquidation} from "silo-core/contracts/hooks/liquidation/PartialLiquidation.sol";
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {ShareTokenLib} from "silo-core/contracts/lib/ShareTokenLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {
    Silo0ProtectedSilo1CollateralOnly
} from "silo-core/contracts/hooks/_common/Silo0ProtectedSilo1CollateralOnly.sol";

interface IFIRM {
    function accrueInterest() external;
    function getCurrentInterestRate() external view returns (uint256);
}

contract FIRMHook is
    GaugeHookReceiver,
    PartialLiquidation,
    Silo0ProtectedSilo1CollateralOnly
{
    using Hook for uint256;

    uint256 public maturityDate;
    address public firm;
    address public firmVault;

    error BorrowSameAssetNotAllowed();
    error OnlyFIRMVaultCanReceiveCollateral();

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

    /// @dev Mint shares and update Silo state
    /// This function is designed to be called by the hook from the silo via delegatecall.
    /// @param _debtShares amount of debt shares to mint
    /// @param _collateralShares amount of collateral shares to mint
    /// @param _borrower address of the borrower
    /// @param _interestToDistribute amount of interest to distribute
    /// @param _interestPayment amount of interest payment
    /// @param _daoAndDeployerRevenue amount of dao and deployer revenue
    /// @param _firm address of the firm
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

    /// @inheritdoc IHookReceiver
    function beforeAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySilo()
        override
    {
        (, address silo1) = siloConfig.getSilos();
        if (_silo != silo1) return;

        require(_action != Hook.BORROW_SAME_ASSET, BorrowSameAssetNotAllowed());

        if (_action != Hook.BORROW) return;

        IFIRM(firm).accrueInterest();

        Hook.BeforeBorrowInput memory borrowInput = Hook.beforeBorrowDecode(_inputAndOutput);

        uint256 interestTimeDelta = maturityDate - block.timestamp;
        uint256 effectiveInterestRate = IFIRM(firm).getCurrentInterestRate() * interestTimeDelta / 365 days;

        uint256 interestPayment = borrowInput.assets * effectiveInterestRate / 1e18;

        // minimal interest is 10 wei to make sure
        // an attacker can not round down interest to 0.
        if (interestPayment < 10) interestPayment = 10;

        uint192 daoAndDeployerRevenue = _getDaoAndDeployerRevenue(silo1, interestPayment);
        uint256 interestToDistribute = interestPayment - daoAndDeployerRevenue;
        uint256 collateralShares = ISilo(silo1).convertToShares(interestToDistribute, ISilo.AssetType.Collateral);
        uint256 debtShares = ISilo(silo1).convertToShares(interestPayment, ISilo.AssetType.Debt);

        bytes memory input = abi.encodeWithSelector(
            this.mintSharesAndUpdateSiloState.selector,
            debtShares,
            collateralShares,
            borrowInput.borrower,
            interestToDistribute,
            interestPayment,
            daoAndDeployerRevenue,
            firm
        );

        ISilo(silo1).callOnBehalfOfSilo({
            _target: address(this),
            _value: 0,
            _callType: ISilo.CallType.Delegatecall,
            _input: input
        });
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

        (address silo1,) = siloConfig.getSilos();
        uint256 collateralTokenTransferAction = Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN);

        if (_silo == silo1 && _action.matchAction(collateralTokenTransferAction)) {
            Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);
            require(input.recipient == firmVault, OnlyFIRMVaultCanReceiveCollateral());
        }
    }

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

    function __FIRMHook_init(uint256 _maturityDate, address _firmVault) internal {
        maturityDate = _maturityDate;
        firmVault = _firmVault;

        (, address silo1) = siloConfig.getSilos();

        ISiloConfig.ConfigData memory silo1Config = siloConfig.getConfig(silo1);

        firm = silo1Config.interestRateModel;
    }
}
