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

    error ZeroAmount();

    /// @notice Withdraws accumulated fees and distributes them proportionally to the DAO and deployer
    /// @dev This function takes into account scenarios where either the DAO or deployer may not be set, distributing
    /// accordingly
    /// @param _config The configuration contract for retrieving fee-related data
    /// @param _factory The factory contract for retrieving fee-related data
    /// @param _siloData Storage reference containing silo-related data, including accumulated fees
    function withdrawFees(ISiloConfig _config, ISiloFactory _factory, ISilo.SiloData storage _siloData) external {
        (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFee,
            uint256 deployerFee,
            address asset
        ) = getFeesAndFeeReceiversWithAsset(_config, _factory);

        uint256 earnedFees = _siloData.daoAndDeployerFees;
        uint256 balanceOf = IERC20Upgradeable(asset).balanceOf(address(this));
        if (balanceOf == 0) revert ISilo.BalanceZero();

        if (earnedFees > balanceOf) earnedFees = balanceOf;
        if (earnedFees == 0) revert ISilo.EarnedZero();

        // we will never underflow because earnedFees max value is `_siloData.daoAndDeployerFees`
        unchecked { _siloData.daoAndDeployerFees -= uint192(earnedFees); }

        if (daoFeeReceiver == address(0) && deployerFeeReceiver == address(0)) {
            // just in case, should never happen...
            revert ISilo.NothingToPay();
        } else if (deployerFeeReceiver == address(0)) {
            // deployer was never setup or deployer NFT has been burned
            IERC20Upgradeable(asset).safeTransfer(daoFeeReceiver, earnedFees);
        } else if (daoFeeReceiver == address(0)) {
            // should never happen... but we assume DAO does not want to make money so all is going to deployer
            IERC20Upgradeable(asset).safeTransfer(deployerFeeReceiver, earnedFees);
        } else {
            // split fees proportionally
            uint256 daoFees = earnedFees * daoFee;
            uint256 deployerFees;

            unchecked {
                // fees are % in decimal point so safe to uncheck
                daoFees = daoFees / (daoFee + deployerFee);
                // `daoFees` is chunk of earnedFees, so safe to uncheck
                deployerFees = earnedFees - daoFees;
            }

            IERC20Upgradeable(asset).safeTransfer(daoFeeReceiver, daoFees);
            IERC20Upgradeable(asset).safeTransfer(deployerFeeReceiver, deployerFees);
        }
    }

    /// @notice Returns flash fee amount
    /// @param _config address of config contract for Silo
    /// @param _token for which fee is calculated
    /// @param _amount for which fee is calculated
    /// @return fee flash fee amount
    function flashFee(ISiloConfig _config, address _token, uint256 _amount) external view returns (uint256 fee) {
        if (_amount == 0) revert ZeroAmount();

        // all user set fees are in 18 decimals points
        (,, uint256 flashloanFee, address asset) = _config.getFeesWithAsset(address(this));
        if (_token != asset) revert ISilo.Unsupported();
        if (flashloanFee == 0) return 0;

        fee = _amount * flashloanFee;
        unchecked { fee /= _PRECISION_DECIMALS; }

        // round up
        if (fee == 0) return 1;
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
            totalAssets = ISilo(_configData.silo).total(ISilo.AssetType.Protected);
            totalShares = IShareToken(_configData.protectedShareToken).totalSupply();
        } else if (_assetType == ISilo.AssetType.Collateral) {
            totalAssets = getTotalCollateralAssetsWithInterest(
                _configData.silo,
                _configData.interestRateModel,
                _configData.daoFee,
                _configData.deployerFee
            );

            totalShares = IShareToken(_configData.collateralShareToken).totalSupply();
        } else if (_assetType == ISilo.AssetType.Debt) {
            totalAssets = getTotalDebtAssetsWithInterest(_configData.silo, _configData.interestRateModel);
            totalShares = IShareToken(_configData.debtShareToken).totalSupply();
        } else {
            revert ISilo.WrongAssetType();
        }
    }

    /// @notice Retrieves fee amounts in 18 decimals points and their respective receivers along with the asset
    /// @param _config The configuration contract used to fetch fee-related data
    /// @param _factory The factory contract used to fetch fee receiver addresses
    /// @return daoFeeReceiver Address of the DAO fee receiver
    /// @return deployerFeeReceiver Address of the deployer fee receiver
    /// @return daoFee DAO fee amount in 18 decimals points
    /// @return deployerFee Deployer fee amount in 18 decimals points
    /// @return asset Address of the associated asset
    function getFeesAndFeeReceiversWithAsset(ISiloConfig _config, ISiloFactory _factory)
        public
        view
        returns (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFee,
            uint256 deployerFee,
            address asset
        )
    {
        (daoFee, deployerFee,, asset) = _config.getFeesWithAsset(address(this));
        (daoFeeReceiver, deployerFeeReceiver) = _factory.getFeeReceivers(address(this));
    }

    /// @notice Calculates the total collateral assets with accrued interest
    /// @dev Do not use this method when accrueInterest were executed already, in that case total does not change
    /// @param _silo Address of the silo contract
    /// @param _interestRateModel Interest rate model to fetch compound interest rates
    /// @param _daoFee DAO fee in 18 decimals points
    /// @param _deployerFee Deployer fee in 18 decimals points
    /// @return totalCollateralAssetsWithInterest Accumulated collateral amount with interest
    function getTotalCollateralAssetsWithInterest(
        address _silo,
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee
    ) internal view returns (uint256 totalCollateralAssetsWithInterest) {
        uint256 rcomp = IInterestRateModel(_interestRateModel).getCompoundInterestRate(_silo, block.timestamp);

        (uint256 collateralAssets, uint256 debtAssets) = ISilo(_silo).getCollateralAndDebtAssets();

        (totalCollateralAssetsWithInterest,,,) = SiloMathLib.getCollateralAmountsWithInterest(
            collateralAssets, debtAssets, rcomp, _daoFee, _deployerFee
        );
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

    /// @notice Calculates the total debt assets with accrued interest
    /// @param _silo Address of the silo contract
    /// @param _interestRateModel Interest rate model to fetch compound interest rates
    /// @return totalDebtAssetsWithInterest Accumulated debt amount with interest
    function getTotalDebtAssetsWithInterest(address _silo, address _interestRateModel)
        internal
        view
        returns (uint256 totalDebtAssetsWithInterest)
    {
        uint256 rcomp = IInterestRateModel(_interestRateModel).getCompoundInterestRate(_silo, block.timestamp);

        (
            totalDebtAssetsWithInterest,
        ) = SiloMathLib.getDebtAmountsWithInterest(ISilo(_silo).total(ISilo.AssetType.Debt), rcomp);
    }
}
