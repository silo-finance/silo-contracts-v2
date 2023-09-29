// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";

library SiloLendingLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _BASIS_POINTS = 1e4;

    function borrow(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        ISilo.Assets storage _totalDebt,
        uint256 _totalCollateralAssets
    ) external returns (uint256 borrowedAssets, uint256 borrowedShares) {
        if (
            !borrowPossible(
                _configData.protectedShareToken, _configData.collateralShareToken, _configData.borrowable, _borrower
            )
        ) revert ISilo.BorrowNotPossible();

        IShareToken debtShareToken = IShareToken(_configData.debtShareToken);
        uint256 totalDebtAssets = _totalDebt.assets;

        (borrowedAssets, borrowedShares) = SiloMathLib.convertToAssetsAndToShares(
            _assets,
            _shares,
            totalDebtAssets,
            debtShareToken.totalSupply(),
            MathUpgradeable.Rounding.Down,
            MathUpgradeable.Rounding.Up,
            ISilo.AssetType.Debt
        );

        if (borrowedAssets > SiloMathLib.liquidity(_totalCollateralAssets, totalDebtAssets)) {
            revert ISilo.NotEnoughLiquidity();
        }

        // add new debt
        _totalDebt.assets = totalDebtAssets + borrowedAssets;
        // `mint` checks if _spender is allowed to borrow on the account of _borrower. Hook receiver can
        // potentially reenter but the state is correct.
        debtShareToken.mint(_borrower, _spender, borrowedShares);
        // fee-on-transfer is ignored. If token reenters, state is already finilized, no harm done.
        IERC20Upgradeable(_configData.token).safeTransferFrom(address(this), _receiver, borrowedAssets);
    }

    function repay(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer,
        ISilo.Assets storage _totalDebt
    ) external returns (uint256 assets, uint256 shares) {
        IShareToken debtShareToken = IShareToken(_configData.debtShareToken);
        uint256 totalDebtAssets = _totalDebt.assets;

        (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
            _assets,
            _shares,
            totalDebtAssets,
            debtShareToken.totalSupply(),
            MathUpgradeable.Rounding.Up,
            MathUpgradeable.Rounding.Down,
            ISilo.AssetType.Debt
        );

        // fee-on-transfer is ignored
        // If token reenters, no harm done because we didn't change the state yet.
        IERC20Upgradeable(_configData.token).safeTransferFrom(_repayer, address(this), assets);
        // subtract repayment from debt
        _totalDebt.assets = totalDebtAssets - assets;
        // Anyone can repay anyone's debt so no approval check is needed. If hook receiver reenters then
        // no harm done because state changes are completed.
        debtShareToken.burn(_borrower, _repayer, shares);
    }

    /// @dev this method will accrue interest for ONE asset ONLY, to calculate all you have to call it twice
    /// with `_configData` for each token
    function accrueInterestForAsset(
        address _interestRateModel,
        uint256 _daoFeeInBp,
        uint256 _deployerFeeInBp,
        ISilo.SiloData storage _siloData,
        ISilo.Assets storage _totalCollateral,
        ISilo.Assets storage _totalDebt
    ) external returns (uint256 accruedInterest) {
        uint64 lastTimestamp = _siloData.interestRateTimestamp;

        // This is the first time, so we can return early and save some gas
        if (lastTimestamp == 0) {
            _siloData.interestRateTimestamp = uint64(block.timestamp);
            return 0;
        }

        // Interest has already been accrued this block
        if (lastTimestamp == block.timestamp) {
            return 0;
        }

        uint256 totalFees;

        (
            _totalCollateral.assets, _totalDebt.assets, totalFees, accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(
            _totalCollateral.assets,
            _totalDebt.assets,
            IInterestRateModel(_interestRateModel).getCompoundInterestRateAndUpdate(block.timestamp),
            _daoFeeInBp,
            _deployerFeeInBp
        );

        // update remaining contract state
        _siloData.interestRateTimestamp = uint64(block.timestamp);
        _siloData.daoAndDeployerFees += totalFees;
    }

    function maxBorrow(ISiloConfig _config, address _borrower, uint256 _totalDebtAssets, uint256 _totalDebtShares)
        external
        view
        returns (uint256 assets, uint256 shares)
    {
        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            _config.getConfigs(address(this));

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            collateralConfig, debtConfig, _borrower, ISilo.OracleType.MaxLtv, ISilo.AccrueInterestInMemory.Yes
        );

        (uint256 sumOfBorrowerCollateralValue, uint256 borrowerDebtValue) =
            SiloSolvencyLib.getPositionValues(ltvData, debtConfig.token, collateralConfig.token);

        uint256 maxBorrowValue = SiloMathLib.calculateMaxBorrowValue(
            collateralConfig.maxLtv,
            sumOfBorrowerCollateralValue,
            borrowerDebtValue
        );

        if (maxBorrowValue == 0) {
            return (0, 0);
        }

        if (borrowerDebtValue == 0) {
            uint256 oneDebtToken = 10 ** IERC20MetadataUpgradeable(debtConfig.token).decimals();

            uint256 oneDebtTokenValue = address(ltvData.debtOracle) == address(0)
                ? oneDebtToken
                : ltvData.debtOracle.quote(oneDebtToken, debtConfig.token);

            assets = maxBorrowValue * _PRECISION_DECIMALS / oneDebtTokenValue;

            shares = SiloMathLib.convertToShares(
                assets, _totalDebtAssets, _totalDebtShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            );
        } else {
            uint256 shareBalance = IShareToken(debtConfig.token).balanceOf(_borrower);
            shares = maxBorrowValue * shareBalance / borrowerDebtValue;

            assets = SiloMathLib.convertToAssets(
                shares, _totalDebtAssets, _totalDebtShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            );
        }
    }

    function borrowPossible(
        address _protectedShareToken,
        address _collateralShareToken,
        bool _borrowable,
        address _borrower
    ) public view returns (bool possible) {
        // token must be marked as borrowable
        if (!_borrowable) return false;

        // _borrower cannot have any collateral deposited
        possible = IShareToken(_protectedShareToken).balanceOf(_borrower) == 0
            && IShareToken(_collateralShareToken).balanceOf(_borrower) == 0;
    }
}
