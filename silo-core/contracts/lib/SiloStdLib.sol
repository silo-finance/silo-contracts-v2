// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISiloFactory} from "../interfaces/ISiloFactory.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {SiloMathLib} from "./SiloMathLib.sol";

library SiloStdLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _BASIS_POINTS = 1e4;

    function withdrawFees(ISiloConfig _config, ISiloFactory _factory, ISilo.SiloData storage _siloData) external {
        (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFeeInBp,
            uint256 deployerFeeInBp,
            address asset
        ) = getFeesAndFeeReceiversWithAsset(_config, _factory);

        uint256 earnedFees = _siloData.daoAndDeployerFees;
        uint256 balanceOf = IERC20Upgradeable(asset).balanceOf(address(this));
        if (earnedFees > balanceOf) earnedFees = balanceOf;

        // we will never underflow because earnedFees max value is `_siloData.daoAndDeployerFees`
        unchecked { _siloData.daoAndDeployerFees -= uint192(earnedFees); }

        if (daoFeeReceiver == address(0) && deployerFeeReceiver == address(0)) {
            // just in case, should never happen...
            revert ISilo.NothingToPay();
        } else if (deployerFeeReceiver == address(0)) {
            // deployer was never setup or deployer NFT has been burned
            IERC20Upgradeable(asset).safeTransferFrom(address(this), daoFeeReceiver, earnedFees);
        } else if (daoFeeReceiver == address(0)) {
            // should never happen... but we assume DAO does not want to make money so all is going to deployer
            IERC20Upgradeable(asset).safeTransferFrom(address(this), deployerFeeReceiver, earnedFees);
        } else {
            // split fees proportionally
            uint256 daoFees = earnedFees * daoFeeInBp / (daoFeeInBp + deployerFeeInBp);
            uint256 deployerFees = earnedFees - daoFees;

            IERC20Upgradeable(asset).safeTransferFrom(address(this), daoFeeReceiver, daoFees);
            IERC20Upgradeable(asset).safeTransferFrom(address(this), deployerFeeReceiver, deployerFees);
        }
    }

    /// @notice Returns flash fee amount
    /// @param _config address of config contract for Silo
    /// @param _token for which fee is calculated
    /// @param _amount for which fee is calculated
    /// @return fee flash fee amount
    function flashFee(ISiloConfig _config, address _token, uint256 _amount) external view returns (uint256 fee) {
        // all user set fees are in basis points
        (,, uint256 flashloanFeeInBp, address asset) = _config.getFeesWithAsset(address(this));

        if (_token != asset) revert ISilo.Unsupported();

        fee = _amount * flashloanFeeInBp;

        unchecked {
            fee /= _BASIS_POINTS;
        }
    }

    function getFeesAndFeeReceiversWithAsset(ISiloConfig _config, ISiloFactory _factory)
        public
        view
        returns (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFeeInBp,
            uint256 deployerFeeInBp,
            address asset
        )
    {
        (daoFeeInBp, deployerFeeInBp,, asset) = _config.getFeesWithAsset(address(this));
        (daoFeeReceiver, deployerFeeReceiver) = _factory.getFeeReceivers(address(this));
    }

    /// @notice Returns totalAssets and totalShares for conversion math (convertToAssets and convertToShares)
    /// @dev This is useful for view functions that do not accrue interest before doing calculations. To work on
    ///      updated numbers, interest should be added on the fly.
    /// @param _configData for a single token for which to do calculations
    /// @param _assetType used to read proper storage data
    /// @return totalAssets total assets in Silo with interest for given asset type
    /// @return totalShares total shares in Silo for given asset type
    function getTotalAssetsAndTotalSharesWithInterest(
        ISiloConfig.ConfigData memory _configData,
        ISilo.AssetType _assetType
    )
        internal
        view
        returns (uint256 totalAssets, uint256 totalShares)
    {
        if (_assetType == ISilo.AssetType.Protected) {
            totalAssets = ISilo(_configData.silo).getProtectedAssets();
            totalShares = IShareToken(_configData.protectedShareToken).totalSupply();
        } else if (_assetType == ISilo.AssetType.Collateral) {
            totalAssets = getTotalCollateralAssetsWithInterest(
                _configData.silo,
                _configData.interestRateModel,
                _configData.daoFeeInBp,
                _configData.deployerFeeInBp
            );

            totalShares = IShareToken(_configData.collateralShareToken).totalSupply();
        } else if (_assetType == ISilo.AssetType.Debt) {
            totalAssets = getTotalDebtAssetsWithInterest(_configData.silo, _configData.interestRateModel);
            totalShares = IShareToken(_configData.debtShareToken).totalSupply();
        } else {
            revert ISilo.WrongAssetType();
        }
    }

    /// @param _balanceCached if balance of `_owner` is unknown beforehand, then pass `0`
    function getSharesAndTotalSupply(address _shareToken, address _owner, uint256 _balanceCached)
        internal
        view
        returns (uint256 shares, uint256 totalSupply)
    {
        shares = _balanceCached == 0 ? IShareToken(_shareToken).balanceOf(_owner) : _balanceCached;
        totalSupply = IShareToken(_shareToken).totalSupply();
    }

    /// @dev do not use this method when accrueInterest were executed already, in that case total does not change
    function getTotalCollateralAssetsWithInterest(
        address _silo,
        address _interestRateModel,
        uint256 _daoFeeInBp,
        uint256 _deployerFeeInBp
    ) internal view returns (uint256 totalCollateralAssetsWithInterest) {
        uint256 rcomp = IInterestRateModel(_interestRateModel).getCompoundInterestRate(_silo, block.timestamp);

        (totalCollateralAssetsWithInterest,,,) = SiloMathLib.getCollateralAmountsWithInterest(
            ISilo(_silo).getCollateralAssets(), ISilo(_silo).getDebtAssets(), rcomp, _daoFeeInBp, _deployerFeeInBp
        );
    }

    function getTotalDebtAssetsWithInterest(address _silo, address _interestRateModel)
        internal
        view
        returns (uint256 totalDebtAssetsWithInterest)
    {
        uint256 rcomp = IInterestRateModel(_interestRateModel).getCompoundInterestRate(_silo, block.timestamp);
        (totalDebtAssetsWithInterest,) = SiloMathLib.getDebtAmountsWithInterest(ISilo(_silo).getDebtAssets(), rcomp);
    }
}
