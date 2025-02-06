// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloLens, ISilo} from "./interfaces/ISiloLens.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";
import {SiloLensLib} from "./lib/SiloLensLib.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {IPartialLiquidation} from "./interfaces/IPartialLiquidation.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";

/// @title SiloLens is a helper contract for integrations and UI
contract SiloLens is ISiloLens {
    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /// @inheritdoc ISiloLens
    function getRawLiquidity(ISilo _silo) external view virtual returns (uint256 liquidity) {
        return SiloLensLib.getRawLiquidity(_silo);
    }

    /// @inheritdoc ISiloLens
    function getInterestRateModel(ISilo _silo) external view virtual returns (address irm) {
        return SiloLensLib.getInterestRateModel(_silo);
    }

    /// @inheritdoc ISiloLens
    function getBorrowAPR(ISilo _silo) external view virtual returns (uint256 borrowAPR) {
        return SiloLensLib.getBorrowAPR(_silo);
    }

    /// @inheritdoc ISiloLens
    function getDepositAPR(ISilo _silo) external view virtual returns (uint256 depositAPR) {
        return SiloLensLib.getDepositAPR(_silo);
    }

    /// @inheritdoc ISiloLens
    function getMaxLtv(ISilo _silo) external view virtual returns (uint256 maxLtv) {
        return SiloLensLib.getMaxLtv(_silo);
    }

    /// @inheritdoc ISiloLens
    function getLt(ISilo _silo) external view virtual returns (uint256 lt) {
        return SiloLensLib.getLt(_silo);
    }

    /// @inheritdoc ISiloLens
    function getLtv(ISilo _silo, address _borrower) external view virtual returns (uint256 ltv) {
        return SiloLensLib.getLtv(_silo, _borrower);
    }

    /// @inheritdoc ISiloLens
    function getFeesAndFeeReceivers(ISilo _silo)
        external
        view
        virtual
        returns (address daoFeeReceiver, address deployerFeeReceiver, uint256 daoFee, uint256 deployerFee)
    {
        (daoFeeReceiver, deployerFeeReceiver, daoFee, deployerFee,) = SiloStdLib.getFeesAndFeeReceiversWithAsset(_silo);
    }

    /// @inheritdoc ISiloLens
    function collateralBalanceOfUnderlying(ISilo _silo, address, address _borrower)
        external
        view
        virtual
        returns (uint256 borrowerCollateral)
    {
        return SiloLensLib.collateralBalanceOfUnderlying(_silo, _borrower);
    }

    /// @inheritdoc ISiloLens
    function collateralBalanceOfUnderlying(ISilo _silo, address _borrower)
        external
        view
        virtual
        returns (uint256 borrowerCollateral)
    {
        return SiloLensLib.collateralBalanceOfUnderlying(_silo, _borrower);
    }

    /// @inheritdoc ISiloLens
    function debtBalanceOfUnderlying(ISilo _silo, address, address _borrower) external view virtual returns (uint256) {
        return _silo.maxRepay(_borrower);
    }

    function debtBalanceOfUnderlying(ISilo _silo, address _borrower)
        public
        view
        virtual
        returns (uint256 borrowerDebt)
    {
        return _silo.maxRepay(_borrower);
    }

    /// @inheritdoc ISiloLens
    function maxLiquidation(ISilo _silo, IPartialLiquidation _hook, address _borrower)
        external
        view
        virtual
        returns (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired, bool fullLiquidation)
    {
        (collateralToLiquidate, debtToRepay, sTokenRequired) = _hook.maxLiquidation(_borrower);

        uint256 maxRepay = _silo.maxRepay(_borrower);
        fullLiquidation = maxRepay == debtToRepay;
    }

    function borrowAPY(ISilo _silo, address _asset) public view returns (uint256 rcur) {
        IInterestRateModel irm = getModel(_silo, _asset);

        rcur = irm.getCurrentInterestRate(address(_silo), block.timestamp);
    }

    function getDepositAmount(ISilo _silo, address _asset, address _user)
        public
        view
        returns (uint256 totalUserDeposits)
    {
        ISiloConfig _config = _silo.config();

        (, address collateralShareToken,) = _config.getShareTokens(address(_silo));

        uint256 share = IERC20(collateralShareToken).balanceOf(_user);

        if (share == 0) {
            return 0;
        }

        IInterestRateModel irm = IInterestRateModel(getModel(_silo, _asset));

        uint256 rcomp = irm.getCompoundInterestRate(address(_silo), block.timestamp);

        (,, uint256 daoFee, uint256 deployerFee,) = SiloStdLib.getFeesAndFeeReceiversWithAsset(_silo);

        (,,, uint256 collateralAssets, uint256 debtAssets) = _silo.getSiloStorage();

        totalUserDeposits = _totalDepositsWithInterest(collateralAssets, debtAssets, daoFee + deployerFee, rcomp);
    }

    function totalBorrowAmountWithInterest(ISilo _silo, address _asset)
        public
        view
        returns (uint256 totalBorrowAmount)
    {
        _requireAsset(_silo, _asset);

        totalBorrowAmount = _silo.getDebtAssets();
    }

    function getModel(ISilo _silo, address _asset) public view returns (IInterestRateModel irm) {
        _requireAsset(_silo, _asset);

        irm = IInterestRateModel(_silo.config().getConfig(address(_silo)).interestRateModel);
    }

    function _totalDepositsWithInterest(
        uint256 _assetTotalDeposits,
        uint256 _assetTotalBorrows,
        uint256 _protocolShareFee,
        uint256 _rcomp
    )
        internal
        pure
        returns (uint256 _totalDepositsWithInterests)
    {
        uint256 depositorsShare = _PRECISION_DECIMALS - _protocolShareFee;

        return _assetTotalDeposits + _assetTotalBorrows * _rcomp / _PRECISION_DECIMALS * depositorsShare /
            _PRECISION_DECIMALS;
    }

    function _totalBorrowAmountWithInterest(uint256 _totalBorrowAmount, uint256 _rcomp)
        internal
        pure
        returns (uint256 totalBorrowAmountWithInterests)
    {
        totalBorrowAmountWithInterests = _totalBorrowAmount + _totalBorrowAmount * _rcomp / _PRECISION_DECIMALS;
    }

    function _requireAsset(ISilo _silo, address _asset) internal view {
        require(_silo.asset() == _asset, InvalidAsset());
    }
}
