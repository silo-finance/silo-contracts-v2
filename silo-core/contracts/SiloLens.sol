// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISiloLens, ISilo} from "./interfaces/ISiloLens.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";

import {SiloLensLib} from "./lib/SiloLensLib.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";


/// @title SiloLens has some helper methods that can be useful with integration
contract SiloLens is ISiloLens {
    using SiloLensLib for ISilo;

    function getRawLiquidity(ISilo _silo) external view virtual returns (uint256 liquidity) {
        return _silo.getRawLiquidity();
    }

    /// @inheritdoc ISiloLens
    function getMaxLtv(ISilo _silo) external view virtual returns (uint256 maxLtv) {
        return _silo.getMaxLtv();
    }

    /// @inheritdoc ISiloLens
    function getLt(ISilo _silo) external view virtual returns (uint256 lt) {
        return _silo.getLt();
    }

    /// @inheritdoc ISiloLens
    function getLtv(ISilo _silo, address _borrower) external view virtual returns (uint256 ltv) {
        return _silo.getLtv(_borrower);
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
        returns (uint256 borrowerCollateral)
    {
        return _collateralBalanceOfUnderlying(_silo, _borrower);
    }

    /// @inheritdoc ISiloLens
    function collateralBalanceOfUnderlying(ISilo _silo, address _borrower)
        external
        view
        returns (uint256 borrowerCollateral)
    {
        return _collateralBalanceOfUnderlying(_silo, _borrower);
    }

    /// @inheritdoc ISiloLens
    function debtBalanceOfUnderlying(ISilo _silo, address, address _borrower) external view returns (uint256) {
        return _silo.maxRepay(_borrower);
    }

    function debtBalanceOfUnderlying(ISilo _silo, address _borrower) public view returns (uint256 borrowerDebt) {
        return _silo.maxRepay(_borrower);
    }

    function _collateralBalanceOfUnderlying(ISilo _silo, address _borrower)
        internal
        view
        returns (uint256 borrowerCollateral)
    {
        (
            address protectedShareToken, address collateralShareToken,
        ) = _silo.config().getShareTokens(address(_silo));

        uint256 protectedShareBalance = IShareToken(protectedShareToken).balanceOf(_borrower);
        uint256 collateralShareBalance = IShareToken(collateralShareToken).balanceOf(_borrower);

        if (protectedShareBalance != 0) {
            borrowerCollateral = _silo.previewRedeem(protectedShareBalance, ISilo.CollateralType.Protected);
        }

        if (collateralShareBalance != 0) {
            unchecked {
                // if silo not reverting during calculation of sum of collateral, we will not either
                borrowerCollateral += _silo.previewRedeem(collateralShareBalance, ISilo.CollateralType.Collateral);
            }
        }
    }
}
