// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {ISiloConfig} from "../interface/ISiloConfig.sol";
import {ISilo} from "../interface/ISilo.sol";
import {IInterestRateModel} from "../interface/IInterestRateModel.sol";
import {IShareToken} from "../interface/IShareToken.sol";

// solhint-disable ordering

library SiloStdLib {
    enum TokenType {
        Protected,
        Collateral,
        Debt
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    error ZeroAssets();
    error ZeroShares();
    error WrongToken();

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

    // TODO: check rounding up/down
    function toAssets(uint256 _shares, uint256 _totalAmount, uint256 _totalShares) internal pure returns (uint256) {
        if (_totalShares == 0 || _totalAmount == 0) {
            return 0;
        }

        uint256 result = _shares * _totalAmount / _totalShares;

        // Prevent rounding error
        if (result == 0 && _shares != 0) {
            revert ZeroAssets();
        }

        return result;
    }

    // TODO: check rounding up/down
    function toShare(uint256 _amount, uint256 _totalAmount, uint256 _totalShares) internal pure returns (uint256) {
        if (_totalShares == 0 || _totalAmount == 0) {
            return _amount;
        }

        uint256 result = _amount * _totalShares / _totalAmount;

        // Prevent rounding error
        if (result == 0 && _amount != 0) {
            revert ZeroShares();
        }

        return result;
    }

    function amountWithInterest(address _asset, uint256 _amount, address _model)
        internal
        view
        returns (uint256 amount)
    {
        uint256 rcomp = IInterestRateModel(_model).getCompoundInterestRate(address(this), _asset, block.timestamp);

        // deployer and dao fee can be ignored because interest is fully added to AssetStorage anyway
        amount = _amount + _amount * rcomp / _PRECISION_DECIMALS;
    }

    // solhint-disable-next-line code-complexity
    function findShareToken(ISiloConfig.ConfigData memory _configData, TokenType _tokenType, address _token)
        internal
        pure
        returns (IShareToken shareToken)
    {
        if (_configData.token0 == _token) {
            if (_tokenType == TokenType.Protected) return IShareToken(_configData.protectedCollateralShareToken0);
            else if (_tokenType == TokenType.Collateral) return IShareToken(_configData.collateralShareToken0);
            else if (_tokenType == TokenType.Debt) return IShareToken(_configData.debtShareToken0);
        } else if (_configData.token1 == _token) {
            if (_tokenType == TokenType.Protected) return IShareToken(_configData.protectedCollateralShareToken1);
            else if (_tokenType == TokenType.Collateral) return IShareToken(_configData.collateralShareToken1);
            else if (_tokenType == TokenType.Debt) return IShareToken(_configData.debtShareToken1);
        } else {
            revert WrongToken();
        }
    }

    function findModel(ISiloConfig.ConfigData memory _configData, address _token) internal pure returns (address) {
        if (_configData.token0 == _token) {
            return _configData.interestRateModel0;
        } else if (_configData.token1 == _token) {
            return _configData.interestRateModel1;
        } else {
            revert WrongToken();
        }
    }

    function liquidity(address _token, mapping(address => ISilo.AssetStorage) storage _assetStorage)
        internal
        view
        returns (uint256 liquidAssets)
    {
        liquidAssets = _assetStorage[_token].collateralAssets - _assetStorage[_token].debtAssets;
    }

    function tokens(ISiloConfig _config) internal view returns (address[2] memory assetTokenAddresses) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        assetTokenAddresses[0] = configData.token0;
        assetTokenAddresses[1] = configData.token1;
    }

    function totalAssets(
        ISiloConfig _config,
        address _token,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        if (configData.token0 == _token || configData.token1 == _token) {
            /// @dev sum of assets cannot be bigger than total supply which must fit in uint256
            unchecked {
                return _assetStorage[_token].protectedAssets + _assetStorage[_token].collateralAssets;
            }
        } else {
            revert WrongToken();
        }
    }

    function getTotalAmountAndTotalShares(
        ISiloConfig.ConfigData memory _configData,
        address _token,
        TokenType _tokenType,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 totalAmount, uint256 totalShares) {
        IShareToken shareToken = findShareToken(_configData, _tokenType, _token);
        totalShares = shareToken.totalSupply();

        if (_tokenType == TokenType.Collateral) {
            totalAmount =
                amountWithInterest(_token, _assetStorage[_token].collateralAssets, findModel(_configData, _token));
        } else if (_tokenType == TokenType.Debt) {
            totalAmount = amountWithInterest(_token, _assetStorage[_token].debtAssets, findModel(_configData, _token));
        } else if (_tokenType == TokenType.Protected) {
            totalAmount = _assetStorage[_token].protectedAssets;
        }
    }

    function _convertToSharesInternal(
        ISiloConfig.ConfigData memory _configData,
        address _token,
        uint256 _assets,
        TokenType _tokenType,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256) {
        if (_assets == 0) return 0;

        (uint256 totalAmount, uint256 totalShares) =
            getTotalAmountAndTotalShares(_configData, _token, _tokenType, _assetStorage);

        return toShare(_assets, totalAmount, totalShares);
    }

    function convertToShares(
        ISiloConfig _config,
        address _token,
        uint256 _assets,
        TokenType _tokenType,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return _convertToSharesInternal(configData, _token, _assets, _tokenType, _assetStorage);
    }

    function _convertToAssetsInternal(
        ISiloConfig.ConfigData memory _configData,
        address _token,
        uint256 _shares,
        TokenType _tokenType,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256) {
        if (_shares == 0) return 0;

        (uint256 totalAmount, uint256 totalShares) =
            getTotalAmountAndTotalShares(_configData, _token, _tokenType, _assetStorage);

        return toAssets(_shares, totalAmount, totalShares);
    }

    function convertToAssets(
        ISiloConfig _config,
        address _token,
        uint256 _shares,
        TokenType _tokenType,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return _convertToAssetsInternal(configData, _token, _shares, _tokenType, _assetStorage);
    }
}
