// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloFactory} from "../interfaces/ISiloFactory.sol";

import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {Rounding} from "./Rounding.sol";
import {AssetTypes} from "./AssetTypes.sol";
import {ShareTokenLib} from "./ShareTokenLib.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";

// solhint-disable ordering

library Views {
    /// @dev max percent is 1e18 == 100%
    uint256 internal constant _MAX_PERCENT = 1e18;

    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    function isSolvent(address _borrower) external view returns (bool) {
        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt
        ) = ShareTokenLib.siloConfig().getConfigsForSolvency(_borrower);

        return SiloSolvencyLib.isSolvent(collateral, debt, _borrower, ISilo.AccrueInterestInMemory.Yes);
    }

    /// @notice Returns flash fee amount
    /// @param _token for which fee is calculated
    /// @param _amount for which fee is calculated
    /// @return fee flash fee amount
    function flashFee(address _token, uint256 _amount) external view returns (uint256 fee) {
        fee = SiloStdLib.flashFee(ShareTokenLib.siloConfig(), _token, _amount);
    }

    function maxBorrow(address _borrower, bool _sameAsset)
        external
        view
        returns (uint256 maxAssets, uint256 maxShares)
    {
        return SiloLendingLib.maxBorrow(_borrower, _sameAsset);
    }

    function maxWithdraw(address _owner, ISilo.CollateralType _collateralType)
        external
        view
        returns (uint256 assets, uint256 shares)
    {
        return SiloERC4626Lib.maxWithdraw(
            _owner,
            _collateralType,
            // 0 for CollateralType.Collateral because it will be calculated internally
            _collateralType == ISilo.CollateralType.Protected
                ? SiloStorageLib.getSiloStorage().totalAssets[ISilo.AssetType.Protected]
                : 0
        );
    }

    function maxRepay(address _borrower) external view returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = ShareTokenLib.getConfig();
        uint256 shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, ISilo.AssetType.Debt);

        return SiloMathLib.convertToAssets(
            shares, totalSiloAssets, totalShares, Rounding.MAX_REPAY_TO_ASSETS, ISilo.AssetType.Debt
        );
    }

    function getSiloStorage()
        internal
        view
        returns (
            uint192 daoAndDeployerRevenue,
            uint64 interestRateTimestamp,
            uint256 protectedAssets,
            uint256 collateralAssets,
            uint256 debtAssets
        )
    {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        daoAndDeployerRevenue = $.daoAndDeployerRevenue;
        interestRateTimestamp = $.interestRateTimestamp;
        protectedAssets = $.totalAssets[ISilo.AssetType.Protected];
        collateralAssets = $.totalAssets[ISilo.AssetType.Collateral];
        debtAssets = $.totalAssets[ISilo.AssetType.Debt];
    }

    function utilizationData() internal view returns (ISilo.UtilizationData memory) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        return ISilo.UtilizationData({
            collateralAssets: $.totalAssets[ISilo.AssetType.Collateral],
            debtAssets: $.totalAssets[ISilo.AssetType.Debt],
            interestRateTimestamp: $.interestRateTimestamp
        });
    }

    function getCollateralAssets() internal view returns (uint256 totalCollateralAssets) {
        ISiloConfig.ConfigData memory thisSiloConfig = ShareTokenLib.getConfig();

        totalCollateralAssets = SiloStdLib.getTotalCollateralAssetsWithInterest(
            thisSiloConfig.silo,
            thisSiloConfig.interestRateModel,
            thisSiloConfig.daoFee,
            thisSiloConfig.deployerFee
        );
    }

    function getDebtAssets() internal view returns (uint256 totalDebtAssets) {
        ISiloConfig.ConfigData memory thisSiloConfig = ShareTokenLib.getConfig();

        totalDebtAssets = SiloStdLib.getTotalDebtAssetsWithInterest(
            thisSiloConfig.silo, thisSiloConfig.interestRateModel
        );
    }

    function getCollateralAndProtectedAssets()
        internal
        view
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets)
    {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        totalCollateralAssets = $.totalAssets[ISilo.AssetType.Collateral];
        totalProtectedAssets = $.totalAssets[ISilo.AssetType.Protected];
    }

    function getCollateralAndDebtAssets()
        internal
        view
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets)
    {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        totalCollateralAssets = $.totalAssets[ISilo.AssetType.Collateral];
        totalDebtAssets = $.totalAssets[ISilo.AssetType.Debt];
    }

    function copySiloConfig(
        ISiloConfig.InitData memory _initData,
        uint256 _maxDeployerFee,
        uint256 _maxFlashloanFee,
        uint256 _maxLiquidationFee
    )
        internal
        view
        returns (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1)
    {
        validateSiloInitData(_initData, _maxDeployerFee, _maxFlashloanFee, _maxLiquidationFee);

        configData0.hookReceiver = _initData.hookReceiver;
        configData0.token = _initData.token0;
        configData0.solvencyOracle = _initData.solvencyOracle0;
        // If maxLtv oracle is not set, fallback to solvency oracle
        configData0.maxLtvOracle = _initData.maxLtvOracle0 == address(0)
            ? _initData.solvencyOracle0
            : _initData.maxLtvOracle0;
        configData0.interestRateModel = _initData.interestRateModel0;
        configData0.maxLtv = _initData.maxLtv0;
        configData0.lt = _initData.lt0;
        configData0.deployerFee = _initData.deployerFee;
        configData0.liquidationFee = _initData.liquidationFee0;
        configData0.flashloanFee = _initData.flashloanFee0;
        configData0.callBeforeQuote = _initData.callBeforeQuote0;

        configData1.hookReceiver = _initData.hookReceiver;
        configData1.token = _initData.token1;
        configData1.solvencyOracle = _initData.solvencyOracle1;
        // If maxLtv oracle is not set, fallback to solvency oracle
        configData1.maxLtvOracle = _initData.maxLtvOracle1 == address(0)
            ? _initData.solvencyOracle1
            : _initData.maxLtvOracle1;
        configData1.interestRateModel = _initData.interestRateModel1;
        configData1.maxLtv = _initData.maxLtv1;
        configData1.lt = _initData.lt1;
        configData1.deployerFee = _initData.deployerFee;
        configData1.liquidationFee = _initData.liquidationFee1;
        configData1.flashloanFee = _initData.flashloanFee1;
        configData1.callBeforeQuote = _initData.callBeforeQuote1;
    }

    function validateSiloInitData(
        ISiloConfig.InitData memory _initData,
        uint256 _maxDeployerFee,
        uint256 _maxFlashloanFee,
        uint256 _maxLiquidationFee
    ) internal view returns (bool) {
        // solhint-disable-previous-line code-complexity
        if (_initData.hookReceiver == address(0)) revert ISiloFactory.MissingHookReceiver();

        if (_initData.token0 == address(0)) revert ISiloFactory.EmptyToken0();
        if (_initData.token1 == address(0)) revert ISiloFactory.EmptyToken1();

        if (_initData.token0 == _initData.token1) revert ISiloFactory.SameAsset();
        if (_initData.maxLtv0 == 0 && _initData.maxLtv1 == 0) revert ISiloFactory.InvalidMaxLtv();
        if (_initData.maxLtv0 > _initData.lt0) revert ISiloFactory.InvalidMaxLtv();
        if (_initData.maxLtv1 > _initData.lt1) revert ISiloFactory.InvalidMaxLtv();
        if (_initData.lt0 > _MAX_PERCENT || _initData.lt1 > _MAX_PERCENT) revert ISiloFactory.InvalidLt();

        if (_initData.maxLtvOracle0 != address(0) && _initData.solvencyOracle0 == address(0)) {
            revert ISiloFactory.OracleMisconfiguration();
        }

        if (_initData.callBeforeQuote0 && _initData.solvencyOracle0 == address(0)) {
            revert ISiloFactory.InvalidCallBeforeQuote();
        }

        if (_initData.maxLtvOracle1 != address(0) && _initData.solvencyOracle1 == address(0)) {
            revert ISiloFactory.OracleMisconfiguration();
        }

        if (_initData.callBeforeQuote1 && _initData.solvencyOracle1 == address(0)) {
            revert ISiloFactory.InvalidCallBeforeQuote();
        }

        verifyQuoteTokens(_initData);

        if (_initData.deployerFee > 0 && _initData.deployer == address(0)) revert ISiloFactory.InvalidDeployer();
        if (_initData.deployerFee > _maxDeployerFee) revert ISiloFactory.MaxDeployerFeeExceeded();
        if (_initData.flashloanFee0 > _maxFlashloanFee) revert ISiloFactory.MaxFlashloanFeeExceeded();
        if (_initData.flashloanFee1 > _maxFlashloanFee) revert ISiloFactory.MaxFlashloanFeeExceeded();
        if (_initData.liquidationFee0 > _maxLiquidationFee) revert ISiloFactory.MaxLiquidationFeeExceeded();
        if (_initData.liquidationFee1 > _maxLiquidationFee) revert ISiloFactory.MaxLiquidationFeeExceeded();

        if (_initData.interestRateModel0 == address(0) || _initData.interestRateModel1 == address(0)) {
            revert ISiloFactory.InvalidIrm();
        }

        return true;
    }

    function verifyQuoteTokens(ISiloConfig.InitData memory _initData) internal view {
        address expectedQuoteToken;

        expectedQuoteToken = verifyQuoteToken(expectedQuoteToken, _initData.solvencyOracle0);
        expectedQuoteToken = verifyQuoteToken(expectedQuoteToken, _initData.maxLtvOracle0);
        expectedQuoteToken = verifyQuoteToken(expectedQuoteToken, _initData.solvencyOracle1);
        expectedQuoteToken = verifyQuoteToken(expectedQuoteToken, _initData.maxLtvOracle1);
    }

    function verifyQuoteToken(address _expectedQuoteToken, address _oracle)
        internal
        view
        returns (address quoteToken)
    {
        if (_oracle == address(0)) return _expectedQuoteToken;

        quoteToken = ISiloOracle(_oracle).quoteToken();

        if (_expectedQuoteToken == address(0)) return quoteToken;
        if (_expectedQuoteToken != quoteToken) revert ISiloFactory.InvalidQuoteToken();
    }
}
