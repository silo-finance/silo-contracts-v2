// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {ISiloOracle} from "../interface/ISiloOracle.sol";
import {ISiloFactory} from "../interface/ISilo.sol";
import {SiloStdLib, ISiloConfig, ISilo, IShareToken, IInterestRateModel} from "./SiloStdLib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";

// solhint-disable ordering
// solhint-disable function-max-lines

library SiloLendingLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    error DepositNotPossible();
    error BorrowNotPossible();
    error NothingToWithdraw();
    error NotSolvent();
    error NotEnoughLiquidity();

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

    function depositPossibleInternal(ISiloConfig.ConfigData memory _configData, address _token, address _depositor)
        internal
        view
        returns (bool)
    {
        IShareToken shareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.TokenType.Debt, _token);
        return shareToken.balanceOf(_depositor) == 0;
    }

    function depositPossible(ISiloConfig _config, address _token, address _depositor) internal view returns (bool) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return depositPossibleInternal(configData, _token, _depositor);
    }

    function borrowPossibleInternal(ISiloConfig.ConfigData memory _configData, address _token, address _borrower)
        internal
        view
        returns (bool)
    {
        IShareToken protectedShareToken =
            SiloStdLib.findShareToken(_configData, SiloStdLib.TokenType.Protected, _token);
        IShareToken collateralShareToken =
            SiloStdLib.findShareToken(_configData, SiloStdLib.TokenType.Collateral, _token);

        return protectedShareToken.balanceOf(_borrower) == 0 && collateralShareToken.balanceOf(_borrower) == 0;
    }

    function borrowPossible(ISiloConfig _config, address _token, address _borrower) internal view returns (bool) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return borrowPossibleInternal(configData, _token, _borrower);
    }

    function maxDeposit(
        ISiloConfig _config,
        address _receiver,
        address _token,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxAssets) {
        if (!depositPossible(_config, _token, _receiver)) return 0;

        if (_isProtected) {
            /// @dev protectedAssets cannot be bigger then uin256 itself
            unchecked {
                return type(uint256).max - _assetStorage[_token].protectedAssets;
            }
        } else {
            /// @dev collateralAssets cannot be bigger then uin256 itself
            unchecked {
                return type(uint256).max - _assetStorage[_token].collateralAssets;
            }
        }
    }

    function previewDeposit(
        ISiloConfig _config,
        address _receiver,
        address _token,
        uint256 _assets,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();
        SiloStdLib.TokenType tokenType = SiloStdLib.TokenType.Collateral;
        if (_isProtected) tokenType = SiloStdLib.TokenType.Protected;

        if (!depositPossibleInternal(configData, _token, _receiver)) revert DepositNotPossible();

        return SiloStdLib.convertToSharesInternal(configData, _token, _assets, tokenType, _assetStorage);
    }

    function depositInternal(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        address _receiver,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 collateralAssets, IShareToken collateralShareToken) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        accrueInterestInternal(configData, _factory, _token, _assetStorage);

        if (!depositPossible(_config, _token, _receiver)) revert DepositNotPossible();

        if (_isProtected) {
            collateralAssets = _assetStorage[_token].protectedAssets;
            collateralShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Protected, _token);
        } else {
            collateralAssets = _assetStorage[_token].collateralAssets;
            collateralShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Collateral, _token);
        }
    }

    function deposit(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        address _depositor,
        address _receiver,
        uint256 _assets,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 shares) {
        (uint256 collateralAssets, IShareToken collateralShareToken) =
            depositInternal(_config, _factory, _token, _receiver, _isProtected, _assetStorage);

        shares = SiloStdLib.toShare(_assets, collateralAssets, collateralShareToken.totalSupply());
        collateralShareToken.mint(_receiver, msg.sender, shares);

        IERC20Upgradeable(_token).safeTransferFrom(_depositor, address(this), _assets);

        emit Deposit(_token, _depositor, _receiver, _assets, shares, _isProtected);
    }

    function maxMint(ISiloConfig _config, address _receiver, address _token, bool _isProtected)
        internal
        view
        returns (uint256 maxShares)
    {
        if (!depositPossible(_config, _token, _receiver)) return 0;

        ISiloConfig.ConfigData memory configData = _config.getConfig();

        IShareToken shareToken;

        if (_isProtected) {
            shareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Protected, _token);
        } else {
            shareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Collateral, _token);
        }

        return type(uint256).max - shareToken.totalSupply();
    }

    function previewMint(
        ISiloConfig _config,
        address _receiver,
        address _token,
        uint256 _shares,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        if (!depositPossible(_config, _token, _receiver)) revert DepositNotPossible();

        SiloStdLib.TokenType tokenType = SiloStdLib.TokenType.Collateral;
        if (_isProtected) tokenType = SiloStdLib.TokenType.Protected;

        return SiloStdLib.convertToAssets(_config, _token, _shares, tokenType, _assetStorage);
    }

    function mint(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        address _depositor,
        address _receiver,
        uint256 _shares,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        (uint256 collateralAssets, IShareToken collateralToken) =
            depositInternal(_config, _factory, _token, _receiver, _isProtected, _assetStorage);

        assets = SiloStdLib.toAssets(_shares, collateralAssets, collateralToken.totalSupply());
        collateralToken.mint(_receiver, msg.sender, _shares);

        IERC20Upgradeable(_token).safeTransferFrom(_depositor, address(this), assets);

        emit Deposit(_token, _depositor, _receiver, assets, _shares, _isProtected);
    }

    function maxWithdrawInternal(
        ISiloConfig.ConfigData memory _configData,
        address _token,
        address _owner,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares, uint256 assets) {
        IShareToken shareToken;
        bool isToken0Collateral;
        uint256 totalAmount;
        uint256 debtValue;
        uint256 collateralValue;
        uint256 liquidAssets = SiloStdLib.liquidity(_token, _assetStorage);

        if (_isProtected) {
            shareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.TokenType.Protected, _token);
            totalAmount = _assetStorage[_token].protectedAssets;
        } else {
            shareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.TokenType.Collateral, _token);
            totalAmount = _assetStorage[_token].collateralAssets;
        }

        shares = shareToken.balanceOf(_owner);

        // no deposits of _token
        if (shares == 0) return (0, 0);

        (, isToken0Collateral, debtValue, collateralValue, assets) =
            SiloSolvencyLib.getLtvView(_configData, _owner, true, _assetStorage);

        // must deduct debt
        if (debtValue > 0) {
            uint256 lt = isToken0Collateral ? _configData.lt0 : _configData.lt1;
            uint256 spareCollateralValue = collateralValue - (debtValue * _PRECISION_DECIMALS / lt);
            assets = spareCollateralValue * _PRECISION_DECIMALS / collateralValue * assets / _PRECISION_DECIMALS;
            shares = SiloStdLib.toShare(assets, totalAmount, shareToken.totalSupply());
        }

        // cannot withdraw more then liquidity
        if (assets > liquidAssets) {
            assets = liquidAssets;
            shares = SiloStdLib.toShare(assets, totalAmount, shareToken.totalSupply());
        }
    }

    function maxWithdraw(
        ISiloConfig _config,
        address _token,
        address _owner,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxAssets) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();
        (, maxAssets) = maxWithdrawInternal(configData, _token, _owner, _isProtected, _assetStorage);
    }

    function previewWithdraw(
        ISiloConfig _config,
        address _token,
        uint256 _assets,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        SiloStdLib.TokenType tokenType = SiloStdLib.TokenType.Collateral;
        if (_isProtected) tokenType = SiloStdLib.TokenType.Protected;

        return SiloStdLib.convertToShares(_config, _token, _assets, tokenType, _assetStorage);
    }

    // solhint-disable-next-line code-complexity
    function withdrawInternal(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        bool _isProtected,
        bool _isWithdraw,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        accrueInterestInternal(configData, _factory, _token, _assetStorage);

        IShareToken shareToken;
        uint256 totalAmount;

        if (_isProtected) {
            shareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Protected, _token);
            totalAmount = _assetStorage[_token].protectedAssets;
        } else {
            shareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Collateral, _token);
            totalAmount = _assetStorage[_token].collateralAssets;
        }

        uint256 totalShares = shareToken.totalSupply();
        uint256 shareBalance = shareToken.balanceOf(_owner);

        if (_isWithdraw) {
            // it's withdraw so assets are user input
            shares = SiloStdLib.toShare(_assets, totalAmount, totalShares);
            assets = _assets;
        } else {
            // it's redeem so shares are user input
            shares = _shares;
            assets = SiloStdLib.toAssets(_shares, totalAmount, totalShares);
        }

        if (assets == 0 || shareBalance == 0 || shares == 0) revert NothingToWithdraw();

        // withdraw max
        if (shareBalance < shares) {
            shares = shareBalance;
            assets = SiloStdLib.toAssets(shares, totalAmount, totalShares);
        }

        if (assets > SiloStdLib.liquidity(_token, _assetStorage)) revert NotEnoughLiquidity();

        if (_isProtected) {
            // TODO: write FV (formal verification) rule and comment
            unchecked {
                _assetStorage[_token].protectedAssets = totalAmount - assets;
            }
        } else {
            // TODO: write FV (formal verification) rule and comment
            unchecked {
                _assetStorage[_token].collateralAssets = totalAmount - assets;
            }
        }

        /// @dev `burn` checks if `_spender` is allowed to withdraw `_owner` assets
        shareToken.burn(_owner, _spender, shares);
        /// @dev fee-on-transfer is ignored
        IERC20Upgradeable(_token).safeTransferFrom(address(this), _receiver, assets);

        /// @dev `_owner` must be solvent
        if (!SiloSolvencyLib.isSolventInternal(configData, _owner, _assetStorage)) revert NotSolvent();

        emit Withdraw(_token, _owner, _receiver, assets, shares, _isProtected);
    }

    function withdraw(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _assets,
        address _receiver,
        address _owner,
        address _spender,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 shares) {
        (, shares) = withdrawInternal(
            _config, _factory, _token, _assets, 0, _receiver, _owner, _spender, _isProtected, true, _assetStorage
        );
    }

    function maxRedeem(
        ISiloConfig _config,
        address _token,
        address _owner,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxShares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();
        (maxShares,) = maxWithdrawInternal(configData, _token, _owner, _isProtected, _assetStorage);
    }

    function previewRedeem(
        ISiloConfig _config,
        address _token,
        uint256 _shares,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) external view returns (uint256 assets) {
        SiloStdLib.TokenType tokenType = SiloStdLib.TokenType.Collateral;
        if (_isProtected) tokenType = SiloStdLib.TokenType.Protected;

        return SiloStdLib.convertToAssets(_config, _token, _shares, tokenType, _assetStorage);
    }

    function redeem(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        (assets,) = withdrawInternal(
            _config, _factory, _token, 0, _shares, _receiver, _owner, _spender, _isProtected, false, _assetStorage
        );
    }

    function transitionInternal(
        ISiloConfig.ConfigData memory _configData,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _owner,
        address _spender,
        bool _toProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        accrueInterestInternal(_configData, _factory, _token, _assetStorage);

        IShareToken fromShareToken;
        uint256 fromTotalAmount;
        IShareToken toShareToken;
        uint256 toTotalAmount;

        if (_toProtected) {
            fromShareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.TokenType.Collateral, _token);
            fromTotalAmount = _assetStorage[_token].collateralAssets;
            toShareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.TokenType.Protected, _token);
            toTotalAmount = _assetStorage[_token].protectedAssets;
        } else {
            fromShareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.TokenType.Protected, _token);
            fromTotalAmount = _assetStorage[_token].protectedAssets;
            toShareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.TokenType.Collateral, _token);
            toTotalAmount = _assetStorage[_token].collateralAssets;
        }

        uint256 fromTotalShares = fromShareToken.totalSupply();
        uint256 shareBalance = fromShareToken.balanceOf(_owner);
        assets = SiloStdLib.toAssets(_shares, fromTotalAmount, fromTotalShares);

        if (assets == 0 || shareBalance == 0 || _shares == 0) revert NothingToWithdraw();

        // withdraw max
        if (shareBalance < _shares) {
            _shares = shareBalance;
            assets = SiloStdLib.toAssets(_shares, fromTotalAmount, fromTotalShares);
        }

        uint256 toShares = SiloStdLib.toShare(assets, toTotalAmount, toShareToken.totalSupply());

        if (_toProtected) {
            _assetStorage[_token].protectedAssets = toTotalAmount + assets;
            _assetStorage[_token].collateralAssets = fromTotalAmount - assets;
        } else {
            _assetStorage[_token].protectedAssets = fromTotalAmount - assets;
            _assetStorage[_token].collateralAssets = toTotalAmount + assets;
        }

        /// @dev burn checks if _spender is allowed to transition _owner tokens
        fromShareToken.burn(_owner, _spender, _shares);
        toShareToken.mint(_owner, _spender, toShares);

        /// @dev `_owner` must be solvent
        if (!SiloSolvencyLib.isSolventInternal(_configData, _owner, _assetStorage)) revert NotSolvent();

        emit Withdraw(_token, _owner, _owner, assets, _shares, !_toProtected);
        emit Deposit(_token, _owner, _owner, assets, toShares, _toProtected);
    }

    function transitionToProtected(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _owner,
        address _spender,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return transitionInternal(configData, _factory, _token, _shares, _owner, _spender, true, _assetStorage);
    }

    function transitionFromProtected(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _owner,
        address _spender,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return transitionInternal(configData, _factory, _token, _shares, _owner, _spender, false, _assetStorage);
    }

    // solhint-disable-next-line code-complexity
    function maxBorrowInternal(
        ISiloConfig _config,
        address _token,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxAssets, uint256 maxShares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        if (!borrowPossibleInternal(configData, _token, _borrower)) return (0, 0);

        IShareToken protectedShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Protected, _token);
        IShareToken collateralShareToken =
            SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Collateral, _token);
        IShareToken debtShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Debt, _token);

        uint256 protectedShareBalance = protectedShareToken.balanceOf(_borrower);
        uint256 collateralShareBalance = collateralShareToken.balanceOf(_borrower);
        uint256 debtShareBalance = debtShareToken.balanceOf(_borrower);

        // no collateral, no borrow
        if (protectedShareBalance + collateralShareBalance == 0) return (0, 0);

        uint256 totalCollateralAssets;
        uint256 debtAssets;

        if (protectedShareBalance != 0) {
            totalCollateralAssets += SiloStdLib.convertToAssetsInternal(
                configData, _token, protectedShareBalance, SiloStdLib.TokenType.Protected, _assetStorage
            );
        }

        if (collateralShareBalance != 0) {
            totalCollateralAssets += SiloStdLib.convertToAssetsInternal(
                configData, _token, collateralShareBalance, SiloStdLib.TokenType.Collateral, _assetStorage
            );
        }

        if (debtShareBalance != 0) {
            debtAssets = SiloStdLib.convertToAssetsInternal(
                configData, _token, debtShareBalance, SiloStdLib.TokenType.Debt, _assetStorage
            );
        }

        ISiloOracle collateralOracle;
        address collateralToken;
        uint256 maxLtv;

        ISiloOracle debtOracle;
        address debtToken;

        if (_token == configData.token0) {
            collateralToken = configData.token1;
            collateralOracle = ISiloOracle(configData.ltvOracle1);
            maxLtv = configData.maxLtv1;

            debtToken = configData.token0;
            debtOracle = ISiloOracle(configData.ltvOracle0);
        } else {
            collateralToken = configData.token0;
            collateralOracle = ISiloOracle(configData.ltvOracle0);
            maxLtv = configData.maxLtv0;

            debtToken = configData.token1;
            debtOracle = ISiloOracle(configData.ltvOracle1);
        }

        // if no oracle is set, assume price 1
        uint256 collateralValue = address(collateralOracle) != address(0)
            ? collateralOracle.quoteView(totalCollateralAssets, collateralToken)
            : totalCollateralAssets;

        uint256 maxDebtValue = collateralValue * maxLtv / _PRECISION_DECIMALS;

        uint256 debtValue =
            address(debtOracle) != address(0) ? debtOracle.quoteView(debtAssets, debtToken) : debtAssets;

        // if LTV is higher than LT user cannot borrow more
        if (debtValue >= maxDebtValue) return (0, 0);

        maxAssets = debtAssets * maxDebtValue / debtValue - debtAssets;
        maxShares = SiloStdLib.toShare(maxAssets, debtAssets, debtShareToken.totalSupply());
    }

    function maxBorrow(
        ISiloConfig _config,
        address _token,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxAssets) {
        (maxAssets,) = maxBorrowInternal(_config, _token, _borrower, _assetStorage);
    }

    function previewBorrow(
        ISiloConfig _config,
        address _token,
        uint256 _assets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        return SiloStdLib.convertToShares(_config, _token, _assets, SiloStdLib.TokenType.Debt, _assetStorage);
    }

    function borrowInternal(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        bool _isAssets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        if (!borrowPossibleInternal(configData, _token, _borrower)) revert BorrowNotPossible();

        accrueInterestInternal(configData, _factory, _token, _assetStorage);

        IShareToken debtShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Debt, _token);
        uint256 totalDebtAmount = _assetStorage[_token].debtAssets;
        uint256 totalDebtShares = debtShareToken.totalSupply();

        if (_isAssets) {
            // borrowing assets
            shares = SiloStdLib.toShare(_assets, totalDebtAmount, totalDebtShares);
            assets = _assets;
        } else {
            // borrowing shares
            shares = _shares;
            assets = SiloStdLib.toAssets(_shares, totalDebtAmount, totalDebtShares);
        }

        if (assets > SiloStdLib.liquidity(_token, _assetStorage)) revert NotEnoughLiquidity();

        /// @dev add new debt
        _assetStorage[_token].debtAssets += assets;
        /// @dev mint checks if _spender is allowed to borrow on the account of _borrower
        debtShareToken.mint(_borrower, _spender, shares);
        /// @dev/ @dev fee-on-transfer is ignored
        IERC20Upgradeable(_token).safeTransferFrom(address(this), _receiver, assets);

        /// @dev `_owner` must be solvent
        if (!SiloSolvencyLib.isSolventInternal(configData, _borrower, _assetStorage)) revert NotSolvent();

        emit Borrow(_token, _borrower, _receiver, assets, shares);
    }

    function borrow(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _assets,
        address _receiver,
        address _borrower,
        address _spender,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 shares) {
        (, shares) =
            borrowInternal(_config, _factory, _token, _assets, 0, _receiver, _borrower, _spender, true, _assetStorage);
    }

    function maxBorrowShares(
        ISiloConfig _config,
        address _token,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxShares) {
        (, maxShares) = maxBorrowInternal(_config, _token, _borrower, _assetStorage);
    }

    function previewBorrowShares(
        ISiloConfig _config,
        address _token,
        uint256 _shares,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        return SiloStdLib.convertToAssets(_config, _token, _shares, SiloStdLib.TokenType.Debt, _assetStorage);
    }

    function borrowShares(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        (assets,) = borrowInternal(
            _config, _factory, _token, 0, _shares, _receiver, _borrower, _spender, false, _assetStorage
        );
    }

    function maxRepayInternal(
        ISiloConfig _config,
        address _token,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets, uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        IShareToken debtShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Debt, _token);
        shares = debtShareToken.balanceOf(_borrower);
        assets =
            SiloStdLib.convertToAssetsInternal(configData, _token, shares, SiloStdLib.TokenType.Debt, _assetStorage);
    }

    function maxRepay(
        ISiloConfig _config,
        address _token,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        (assets,) = maxRepayInternal(_config, _token, _borrower, _assetStorage);
    }

    function previewRepay(
        ISiloConfig _config,
        address _token,
        uint256 _assets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        shares = SiloStdLib.convertToShares(_config, _token, _assets, SiloStdLib.TokenType.Debt, _assetStorage);
    }

    function repayInternal(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer,
        bool _isAssets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        accrueInterestInternal(configData, _factory, _token, _assetStorage);

        IShareToken debtShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.TokenType.Debt, _token);
        uint256 totalDebtAmount = _assetStorage[_token].debtAssets;
        uint256 totalDebtShares = debtShareToken.totalSupply();
        uint256 shareDebtBalance = debtShareToken.balanceOf(_borrower);

        if (_isAssets) {
            // repaying assets
            shares = SiloStdLib.toShare(_assets, totalDebtAmount, totalDebtShares);
            assets = _assets;
        } else {
            // repaying shares
            shares = _shares;
            assets = SiloStdLib.toAssets(_shares, totalDebtAmount, totalDebtShares);
        }

        // repay max if shares above balance
        if (shares > shareDebtBalance) {
            shares = shareDebtBalance;
            assets = SiloStdLib.toAssets(shares, totalDebtAmount, totalDebtShares);
        }

        /// @dev/ @dev fee-on-transfer is ignored
        IERC20Upgradeable(_token).safeTransferFrom(_repayer, address(this), assets);
        /// @dev subtract repayment from debt
        _assetStorage[_token].debtAssets -= assets;
        /// @dev burn debt shares
        debtShareToken.burn(_borrower, _repayer, shares);

        emit Repay(_token, _borrower, _repayer, assets, shares);
    }

    function repay(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _assets,
        address _borrower,
        address _repayer,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 shares) {
        (, shares) = repayInternal(_config, _factory, _token, _assets, 0, _borrower, _repayer, true, _assetStorage);
    }

    function maxRepayShares(
        ISiloConfig _config,
        address _token,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        (, shares) = maxRepayInternal(_config, _token, _borrower, _assetStorage);
    }

    function previewRepayShares(
        ISiloConfig _config,
        address _token,
        uint256 _shares,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        assets = SiloStdLib.convertToAssets(_config, _token, _shares, SiloStdLib.TokenType.Debt, _assetStorage);
    }

    struct RepayVars {
        ISiloConfig _config;
        ISiloFactory _factory;
        address _token;
        uint256 _shares;
        address _borrower;
        address _repayer;
    }

    function repayShares(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _borrower,
        address _repayer,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        (assets,) = repayInternal(_config, _factory, _token, 0, _shares, _borrower, _repayer, false, _assetStorage);
    }

    function accrueInterestInternal(
        ISiloConfig.ConfigData memory _configData,
        ISiloFactory _factory,
        address _token,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 accruedInterest) {
        uint256 lastTimestamp = _assetStorage[_token].interestRateTimestamp;

        // This is the first time, so we can return early and save some gas
        if (lastTimestamp == 0) {
            _assetStorage[_token].interestRateTimestamp = uint64(block.timestamp);
            return 0;
        }

        // Interest has already been accrued this block
        if (lastTimestamp == block.timestamp) {
            return 0;
        }

        IInterestRateModel model;
        IShareToken collateralToken;

        if (_configData.token0 == _token) {
            model = IInterestRateModel(_configData.interestRateModel0);
            collateralToken = IShareToken(_configData.collateralShareToken0);
        } else if (_configData.token1 == _token) {
            model = IInterestRateModel(_configData.interestRateModel1);
            collateralToken = IShareToken(_configData.collateralShareToken1);
        } else {
            revert SiloStdLib.WrongToken();
        }

        uint256 rcomp = model.getCompoundInterestRateAndUpdate(_token, block.timestamp);
        // TODO: deployer and DAO fee should be immutable
        uint256 totalFee = _factory.getFee();

        uint256 collateralAssetsCache = _assetStorage[_token].collateralAssets;
        uint256 debtAssetsCache = _assetStorage[_token].debtAssets;
        uint256 daoAndDeployerAmount;
        uint256 depositorsAmount;

        accruedInterest = debtAssetsCache * rcomp / _PRECISION_DECIMALS;

        unchecked {
            // If we overflow on multiplication it should not revert tx, we will get lower fees
            daoAndDeployerAmount = accruedInterest * totalFee / _PRECISION_DECIMALS;
            depositorsAmount = accruedInterest - daoAndDeployerAmount;
        }

        // TODO: should we mint without veSILO notification? It could save significant amount of gas.
        uint256 totalShares = collateralToken.totalSupply();
        uint256 daoAndDeployerShare =
            SiloStdLib.toShare(daoAndDeployerAmount, collateralAssetsCache + depositorsAmount, totalShares);
        collateralToken.mint(address(_factory), address(this), daoAndDeployerShare);

        // update contract state
        _assetStorage[_token].debtAssets = debtAssetsCache + accruedInterest;
        _assetStorage[_token].collateralAssets = collateralAssetsCache + accruedInterest;
        _assetStorage[_token].interestRateTimestamp = uint64(block.timestamp);
    }

    function accrueInterest(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 accruedInterest) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        accruedInterest = accrueInterestInternal(configData, _factory, _token, _assetStorage);
    }
}
