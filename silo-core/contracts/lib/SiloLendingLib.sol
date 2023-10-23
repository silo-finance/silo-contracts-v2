// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

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
    uint256 internal constant _TOTAL128_CAP = type(uint128).max - 1;

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
        if (_assets == 0 && _shares == 0) revert ISilo.ZeroAssets();
        if (_assets > type(uint128).max) revert ISilo.Overflow();

        if (!borrowPossible(
            _configData.protectedShareToken, _configData.collateralShareToken, _borrower
        )) {
            revert ISilo.BorrowNotPossible();
        }

        IShareToken debtShareToken = IShareToken(_configData.debtShareToken);
        uint256 totalDebtAssets = _totalDebt.assets;
        uint256 debtShareTokenTotalSupply = debtShareToken.totalSupply();

        (borrowedAssets, borrowedShares) = SiloMathLib.convertToAssetsAndToShares(
            _assets,
            _shares,
            totalDebtAssets,
            debtShareTokenTotalSupply,
            SiloMathLib.Rounding.Down,
            SiloMathLib.Rounding.Up,
            ISilo.AssetType.Debt
        );

        if (borrowedShares == 0) revert ISilo.ZeroShares();

        unchecked {
            // `debtShareTokenTotalSupply` is always lt max, because of this check, so we will not underflow
            // `-1` is here because we using decimals offset, and we need "space" for it. Offset is 0 or 1.
            // this CAP can allow us to optimise in other places where we are working with total shares
            if (_TOTAL128_CAP - debtShareTokenTotalSupply < borrowedShares) revert ISilo.ShareOverflow();
        }

        if (borrowedAssets > SiloMathLib.liquidity(_totalCollateralAssets, totalDebtAssets)) {
            revert ISilo.NotEnoughLiquidity();
        }

        unchecked {
            // add new debt
            uint256 total;
            // `borrowedAssets` is uint128. Every time we are checking for `total > type(uint128).max`,
            // We can safely uncheck sum because we adding up two uint128 numbers.
            // `-1` is to have space for decimals offset, offset is 0 or 1.
            // This condition should allow us to uncheck every operation on assets and total in our code.
            total = totalDebtAssets + borrowedAssets;
            if (total > _TOTAL128_CAP) revert ISilo.Overflow();

            _totalDebt.assets = uint128(total);
        }

        // `mint` checks if _spender is allowed to borrow on the account of _borrower. Hook receiver can
        // potentially reenter but the state is correct.
        debtShareToken.mint(_borrower, _spender, borrowedShares);
        // fee-on-transfer is ignored. If token reenters, state is already finalized, no harm done.
        IERC20Upgradeable(_configData.token).safeTransfer(_receiver, borrowedAssets);
    }

    function repay(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer,
        ISilo.Assets storage _totalDebt
    ) external returns (uint256 assets, uint256 shares) {
        if (_assets == 0 && _shares == 0) revert ISilo.ZeroAssets();
        if (_assets > type(uint128).max) revert ISilo.Overflow();

        IShareToken debtShareToken = IShareToken(_configData.debtShareToken);
        uint256 totalDebtAssets = _totalDebt.assets;

        (assets, shares) = SiloMathLib.convertToAssetsAndToShares(
            _assets,
            _shares,
            totalDebtAssets,
            debtShareToken.totalSupply(),
            SiloMathLib.Rounding.Up,
            SiloMathLib.Rounding.Down,
            ISilo.AssetType.Debt
        );

        if (shares == 0) revert ISilo.ZeroShares();

        // fee-on-transfer is ignored
        // If token reenters, no harm done because we didn't change the state yet.
        IERC20Upgradeable(_configData.token).safeTransferFrom(_repayer, address(this), assets);
        // subtract repayment from debt
        // `SiloMathLib.convertToAssetsAndToShares` should never return more assets than total TODO add test case
        unchecked { _totalDebt.assets = uint128(totalDebtAssets - assets); }
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
        uint256 totalCollateralAssets = _totalCollateral.assets;
        uint256 totalDebtAssets = _totalDebt.assets;

        (
            totalCollateralAssets, totalDebtAssets, totalFees, accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(
            totalCollateralAssets,
            totalDebtAssets,
            IInterestRateModel(_interestRateModel).getCompoundInterestRateAndUpdate(
                totalCollateralAssets,
                totalDebtAssets,
                lastTimestamp
            ),
            _daoFeeInBp,
            _deployerFeeInBp
        );

        _totalCollateral.assets = uint128(totalCollateralAssets);
        _totalDebt.assets = uint128(totalDebtAssets);

        // update remaining contract state
        _siloData.interestRateTimestamp = uint64(block.timestamp);

        // we operating on chunks (fees) of real tokens, so overflow should not happen
        // fee is simply to small to overflow on cast to uint192, even if, we will get lower fee
        unchecked { _siloData.daoAndDeployerFees += uint192(totalFees); }
    }

    function maxBorrow(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        uint256 _totalDebtAssets,
        uint256 _totalDebtShares
    )
        external
        view
        returns (uint256 assets, uint256 shares)
    {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig, _debtConfig, _borrower, ISilo.OracleType.MaxLtv, ISilo.AccrueInterestInMemory.Yes
        );

        (uint256 sumOfBorrowerCollateralValue, uint256 borrowerDebtValue) =
            SiloSolvencyLib.getPositionValues(ltvData, _collateralConfig.token, _debtConfig.token);

        uint256 maxBorrowValue = SiloMathLib.calculateMaxBorrowValue(
            _collateralConfig.maxLtv,
            sumOfBorrowerCollateralValue,
            borrowerDebtValue
        );

        return maxBorrowValueToAssetsAndShares(
            maxBorrowValue,
            borrowerDebtValue,
            _borrower,
            _debtConfig.token,
            _debtConfig.debtShareToken,
            ltvData.debtOracle,
            _totalDebtAssets,
            _totalDebtShares
        );
    }

    function borrowPossible(
//        uint256 _otherSiloMaxLtv,
        address _protectedShareToken,
        address _collateralShareToken,
        address _borrower
    ) public view returns (bool possible) {
//        if (_otherSiloMaxLtv == 0)
        // _borrower cannot have any collateral deposited
        possible = IShareToken(_protectedShareToken).balanceOf(_borrower) == 0
            && IShareToken(_collateralShareToken).balanceOf(_borrower) == 0;
    }

    function maxBorrowValueToAssetsAndShares(
        uint256 _maxBorrowValue,
        uint256 _borrowerDebtValue,
        address _borrower,
        address _debtToken,
        address _debtShareToken,
        ISiloOracle _debtOracle,
        uint256 _totalDebtAssets,
        uint256 _totalDebtShares
    )
        internal
        view
        returns (uint256 assets, uint256 shares)
    {
        if (_maxBorrowValue == 0) {
            return (0, 0);
        }

        if (_borrowerDebtValue == 0) {
            uint256 oneDebtToken;
            // if this tokens is "normal", we will not overflow on decimals
            unchecked { oneDebtToken = 10 ** IERC20MetadataUpgradeable(_debtToken).decimals(); }

            uint256 oneDebtTokenValue = address(_debtOracle) == address(0)
                ? oneDebtToken
                : _debtOracle.quote(oneDebtToken, _debtToken);

            assets = _maxBorrowValue * _PRECISION_DECIMALS / oneDebtTokenValue;

            shares = SiloMathLib.convertToShares(
                assets, _totalDebtAssets, _totalDebtShares, SiloMathLib.Rounding.Down, ISilo.AssetType.Debt
            );
        } else {
            uint256 shareBalance = IShareToken(_debtShareToken).balanceOf(_borrower);
            shares = _maxBorrowValue * shareBalance / _borrowerDebtValue;

            assets = SiloMathLib.convertToAssets(
                shares, _totalDebtAssets, _totalDebtShares, SiloMathLib.Rounding.Up, ISilo.AssetType.Debt
            );
        }
    }
}
