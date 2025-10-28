// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

// solhint-disable ordering

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISilo} from "../../../interfaces/ISilo.sol";
import {IShareToken} from "../../../interfaces/IShareToken.sol";
import {SiloMathLib} from "../../../lib/SiloMathLib.sol";
import {Rounding} from "../../../lib/Rounding.sol";
import {SiloStorageLib} from "../../../lib/SiloStorageLib.sol";

/// @dev This is a copy of lib/SiloLendingLib.sol repay() function with a single line changed.
library RepayNoTransferLib {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    /// @dev If SILO has low total debt, interest might be lost to rounding for low deposits.
    /// Value is based on minimal deposit needed to accrue two digit wei interest for 1 second at 0.01% APR.
    /// Example of calculations for 1 second at 0.01% APR and totalDebtAssets 1e13:
    /// 1e13 * (0.0001/365/24/3600*1e18) * 1 / 1e18 = 31.70979198376459
    uint256 internal constant _ROUNDING_THRESHOLD = 1e13;

    /// @notice Allows repaying borrowed assets either partially or in full
    /// @param _debtShareToken debt share token address
    /// @param _assets The amount of assets to repay. Use 0 if shares are used.
    /// @param _shares The number of corresponding shares associated with the debt. Use 0 if assets are used.
    /// @param _borrower The account that has the debt
    /// @param _repayer The account that is repaying the debt
    /// @return assets The amount of assets that was repaid
    /// @return shares The corresponding number of debt shares that were repaid
    function repay(
        IShareToken _debtShareToken,
        address /* _debtAsset */,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer
    ) internal returns (uint256 assets, uint256 shares) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        uint256 totalDebtAssets = $.totalAssets[ISilo.AssetType.Debt];
        (uint256 debtSharesBalance, uint256 totalDebtShares) = _debtShareToken.balanceOfAndTotalSupply(_borrower);

        (assets, shares) = SiloMathLib.convertToAssetsOrToShares({
            _assets: _assets,
            _shares: _shares,
            _totalAssets: totalDebtAssets,
            _totalShares: totalDebtShares,
            _roundingToAssets: Rounding.REPAY_TO_ASSETS,
            _roundingToShares: Rounding.REPAY_TO_SHARES,
            _assetType: ISilo.AssetType.Debt
        });

        if (shares > debtSharesBalance) {
            shares = debtSharesBalance;

            (assets, shares) = SiloMathLib.convertToAssetsOrToShares({
                _assets: 0,
                _shares: shares,
                _totalAssets: totalDebtAssets,
                _totalShares: totalDebtShares,
                _roundingToAssets: Rounding.REPAY_TO_ASSETS,
                _roundingToShares: Rounding.REPAY_TO_SHARES,
                _assetType: ISilo.AssetType.Debt
            });
        }

        require(totalDebtAssets >= assets, ISilo.RepayTooHigh());

        // subtract repayment from debt, save to unchecked because of above `totalDebtAssets < assets`
        unchecked { $.totalAssets[ISilo.AssetType.Debt] = totalDebtAssets - assets; }

        // Anyone can repay anyone's debt so no approval check is needed.
        _debtShareToken.burn(_borrower, _repayer, shares);

        // _debtAsset transfer from repayer removed.
        // This is the only change in the function in comparison to lib/SiloLendingLib.sol repay() function.
    }
}
