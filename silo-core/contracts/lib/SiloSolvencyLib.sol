// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {ISiloOracle} from "../interface/ISiloOracle.sol";
import {SiloStdLib, ISiloConfig, IShareToken, ISilo} from "./SiloStdLib.sol";

// solhint-disable ordering

library SiloSolvencyLib {
    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /// @notice Emitted on deposit
    /// @param token asset address that was deposited
    /// @param depositor wallet address that deposited asset
    /// @param receiver wallet address that received shares in Silo
    /// @param assets amount of asset that was deposited
    /// @param shares amount of shares that was minted
    /// @param isProtected type of deposit, if true, deposited as protected (cannot be borrowed by other users)
    event Deposit(
        address indexed token,
        address indexed depositor,
        address indexed receiver,
        uint256 assets,
        uint256 shares,
        bool isProtected
    );

    /// @notice Emitted on withdraw
    /// @param token asset address that was withdrew
    /// @param owner wallet address that deposited asset
    /// @param receiver wallet address that received asset
    /// @param assets amount of asset that was withdrew
    /// @param shares amount of shares that was burn
    /// @param isProtected type of withdraw, if true, withdraw protected deposit
    event Withdraw(
        address indexed token,
        address indexed owner,
        address indexed receiver,
        uint256 assets,
        uint256 shares,
        bool isProtected
    );

    /// @notice Emitted on borrow
    /// @param token asset address that was borrowed
    /// @param borrower wallet address that borrowed asset
    /// @param receiver wallet address that received asset
    /// @param assets amount of asset that was borrowed
    /// @param shares amount of shares that was minted
    event Borrow(address token, address borrower, address receiver, uint256 assets, uint256 shares);

    /// @notice Emitted on repayment
    /// @param token asset address that was borrowed
    /// @param borrower wallet address that borrowed asset
    /// @param repayer wallet address that repaid asset
    /// @param assets amount of asset that was repaid
    /// @param shares amount of shares that was burn
    event Repay(address token, address borrower, address repayer, uint256 assets, uint256 shares);

    struct LtvData {
        address debtToken;
        address collateralToken;
        IShareToken protectedCollateralShareToken;
        IShareToken collateralShareToken;
        ISiloOracle debtOracle;
        ISiloOracle collateralOracle;
        address collateralInterestRateModel;
        uint256 debtAssets;
        uint256 collateralAssets;
        uint256 debtValue;
        uint256 collateralValue;
        bool isToken0Collateral;
    }

    // solhint-disable-next-line function-max-lines
    function getLtvInternal(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        bool _useLtOracle,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (LtvData memory ltvData) {
        uint256 debtShareToken0Balance = IShareToken(_configData.debtShareToken0).balanceOf(_borrower);

        if (debtShareToken0Balance != 0) {
            // borrowed token0, collateralized token1
            ltvData.debtAssets = SiloStdLib.toAssets(
                debtShareToken0Balance,
                SiloStdLib.amountWithInterest(
                    _configData.token0, _assetStorage[_configData.token0].debtAssets, _configData.interestRateModel0
                ),
                IShareToken(_configData.debtShareToken0).totalSupply()
            );

            ltvData.debtToken = _configData.token0;
            ltvData.collateralToken = _configData.token1;

            ltvData.collateralInterestRateModel = _configData.interestRateModel1;

            // If LTV is needed for solvency, ltOracle should be used. If ltOracle is not set, fallback to ltvOracle.
            ltvData.debtOracle = _useLtOracle && _configData.ltOracle0 != address(0)
                ? ISiloOracle(_configData.ltOracle0)
                : ISiloOracle(_configData.ltvOracle0);
            ltvData.collateralOracle = _useLtOracle && _configData.ltOracle1 != address(0)
                ? ISiloOracle(_configData.ltOracle1)
                : ISiloOracle(_configData.ltvOracle1);

            ltvData.protectedCollateralShareToken = IShareToken(_configData.protectedCollateralShareToken1);
            ltvData.collateralShareToken = IShareToken(_configData.collateralShareToken1);
        } else {
            uint256 debtShareToken1Balance = IShareToken(_configData.debtShareToken1).balanceOf(_borrower);

            if (debtShareToken1Balance != 0) {
                // borrowed token1, collateralized token0
                ltvData.debtAssets = SiloStdLib.toAssets(
                    debtShareToken1Balance,
                    SiloStdLib.amountWithInterest(
                        _configData.token1, _assetStorage[_configData.token1].debtAssets, _configData.interestRateModel1
                    ),
                    IShareToken(_configData.debtShareToken1).totalSupply()
                );

                ltvData.debtToken = _configData.token1;
                ltvData.collateralToken = _configData.token0;

                ltvData.collateralInterestRateModel = _configData.interestRateModel0;

                // If LTV is needed for solvency, ltOracle should be used. If ltOracle is not set,
                // fallback to ltvOracle.
                ltvData.debtOracle = _useLtOracle && _configData.ltOracle1 != address(0)
                    ? ISiloOracle(_configData.ltOracle1)
                    : ISiloOracle(_configData.ltvOracle1);
                ltvData.collateralOracle = _useLtOracle && _configData.ltOracle0 != address(0)
                    ? ISiloOracle(_configData.ltOracle0)
                    : ISiloOracle(_configData.ltvOracle0);

                ltvData.protectedCollateralShareToken = IShareToken(_configData.protectedCollateralShareToken0);
                ltvData.collateralShareToken = IShareToken(_configData.collateralShareToken0);

                ltvData.isToken0Collateral = true;
            } else {
                // nothing borrowed
                return ltvData;
            }
        }

        uint256 protectedBalance = ltvData.protectedCollateralShareToken.balanceOf(_borrower);
        uint256 protectedAssets;

        if (protectedBalance != 0) {
            protectedAssets = SiloStdLib.toAssets(
                protectedBalance,
                _assetStorage[ltvData.collateralToken].protectedAssets,
                IShareToken(ltvData.protectedCollateralShareToken).totalSupply()
            );
        }

        uint256 collateralBalance = ltvData.collateralShareToken.balanceOf(_borrower);
        uint256 collateralAssets;

        if (collateralBalance != 0) {
            collateralAssets = SiloStdLib.toAssets(
                collateralBalance,
                SiloStdLib.amountWithInterest(
                    ltvData.collateralToken,
                    _assetStorage[ltvData.collateralToken].collateralAssets,
                    ltvData.collateralInterestRateModel
                ),
                IShareToken(ltvData.collateralShareToken).totalSupply()
            );
        }

        /// @dev sum of assets cannot be bigger than total supply which must fit in uint256
        unchecked {
            ltvData.collateralAssets = protectedAssets + collateralAssets;
        }
    }

    function getLtvView(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        bool _useLtOracle,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256, bool, uint256, uint256, uint256) {
        LtvData memory ltvData = getLtvInternal(_configData, _borrower, _useLtOracle, _assetStorage);

        if (ltvData.debtAssets == 0) return (0, false, 0, 0, 0);

        // if no oracle is set, assume price 1
        ltvData.debtValue = address(ltvData.debtOracle) != address(0)
            ? ltvData.debtOracle.quoteView(ltvData.debtAssets, ltvData.debtToken)
            : ltvData.debtAssets;

        // if no oracle is set, assume price 1
        ltvData.collateralValue = address(ltvData.collateralOracle) != address(0)
            ? ltvData.collateralOracle.quoteView(ltvData.collateralAssets, ltvData.collateralToken)
            : ltvData.collateralAssets;

        return (
            ltvData.debtValue * _PRECISION_DECIMALS / ltvData.collateralValue,
            ltvData.isToken0Collateral,
            ltvData.debtValue,
            ltvData.collateralValue,
            ltvData.collateralAssets
        );
    }

    /// @return LTV
    /// @return isToken0Collateral
    /// @return debtValue
    /// @return collateralValue
    /// @return collateralAssets
    function getLtv(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        bool _useLtOracle,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256, bool, uint256, uint256, uint256) {
        LtvData memory ltvData = getLtvInternal(_configData, _borrower, _useLtOracle, _assetStorage);

        if (ltvData.debtAssets == 0) return (0, false, 0, 0, 0);

        // if no oracle is set, assume price 1
        ltvData.debtValue = address(ltvData.debtOracle) != address(0)
            ? ltvData.debtOracle.quote(ltvData.debtAssets, ltvData.debtToken)
            : ltvData.debtAssets;

        // if no oracle is set, assume price 1
        ltvData.collateralValue = address(ltvData.collateralOracle) != address(0)
            ? ltvData.collateralOracle.quote(ltvData.collateralAssets, ltvData.collateralToken)
            : ltvData.collateralAssets;

        return (
            ltvData.debtValue * _PRECISION_DECIMALS / ltvData.collateralValue,
            ltvData.isToken0Collateral,
            ltvData.debtValue,
            ltvData.collateralValue,
            ltvData.collateralAssets
        );
    }

    function isSolventInternal(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (bool) {
        (uint256 ltv, bool isToken0Collateral,,,) = getLtv(_configData, _borrower, true, _assetStorage);

        if (isToken0Collateral) {
            return ltv <= _configData.lt0;
        } else {
            return ltv <= _configData.lt1;
        }
    }

    function isSolvent(
        ISiloConfig _config,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (bool) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return isSolventInternal(configData, _borrower, _assetStorage);
    }

    function getMaxLtv(ISiloConfig _config, address _token) internal view returns (uint256) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        if (configData.token0 == _token) {
            return configData.maxLtv0;
        } else if (configData.token1 == _token) {
            return configData.maxLtv1;
        } else {
            revert SiloStdLib.WrongToken();
        }
    }

    function getLt(ISiloConfig _config, address _token) internal view returns (uint256) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        if (configData.token0 == _token) {
            return configData.lt0;
        } else if (configData.token1 == _token) {
            return configData.lt1;
        } else {
            revert SiloStdLib.WrongToken();
        }
    }
}
