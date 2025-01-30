// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISiloLens, ISilo} from "./interfaces/ISiloLens.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";
import {SiloLensLib} from "./lib/SiloLensLib.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {IPartialLiquidation} from "./interfaces/IPartialLiquidation.sol";


/// @title SiloLens is a helper contract for integrations and UI
contract SiloLens is ISiloLens {
    /// @inheritdoc ISiloLens
    function isSolvent(ISilo _silo, address _user) external view returns (bool) {
        return _silo.isSolvent(_user);
    }

    /// @inheritdoc ISiloLens
    function liquidity(ISilo _silo, address _asset) external view returns (uint256) {
        require(_silo.asset() == _asset, InvalidAsset());

        return _silo.getLiquidity();
    }

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
    function getUserLTV(ISilo _silo, address _borrower) external view returns (uint256 userLTV) {
        return SiloLensLib.getLtv(_silo, _borrower);
    }

    /// @inheritdoc ISiloLens
    function getLtv(ISilo _silo, address _borrower) external view virtual returns (uint256 ltv) {
        return SiloLensLib.getLtv(_silo, _borrower);
    }

    /// @inheritdoc ISiloLens
    function hasPosition(ISilo _silo, address _borrower) external view virtual returns (bool has) {
        return SiloLensLib.hasPosition(_silo, _borrower);
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

    /// @inheritdoc ISiloLens
    function totalDeposits(ISilo _silo, address _asset) external view returns (uint256) {
        require(_silo.asset() == _asset, InvalidAsset());

        return _silo.getTotalAssetsStorage(ISilo.AssetType.Collateral);
    }

    /// @inheritdoc ISiloLens
    function collateralOnlyDeposits(ISilo _silo, address _asset) external view returns (uint256) {
        require(_silo.asset() == _asset, InvalidAsset());

        return _silo.getTotalAssetsStorage(ISilo.AssetType.Protected);
    }

    /// @inheritdoc ISiloLens
    function totalBorrowAmount(ISilo _silo, address _asset) external view returns (uint256) {
        require(_silo.asset() == _asset, InvalidAsset());

        return _silo.getTotalAssetsStorage(ISilo.AssetType.Debt);
    }

    /// @inheritdoc ISiloLens
    function totalBorrowShare(ISilo _silo, address _asset) external view returns (uint256) {
        require(_silo.asset() == _asset, InvalidAsset());

        return SiloLensLib.totalBorrowShare(_silo);
    }

    /// @inheritdoc ISiloLens
    function protocolFees(ISilo _silo, address _asset) external view returns (uint256 daoAndDeployerRevenue) {
        require(_silo.asset() == _asset, InvalidAsset());

        (daoAndDeployerRevenue,,,,) = _silo.getSiloStorage();
    }
}
