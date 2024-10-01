// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {IERC20} from "openzeppelin5/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";

import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {Actions} from "silo-core/contracts/lib/Actions.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {Rounding} from "silo-core/contracts/lib/Rounding.sol";
import {RevertBytes} from "silo-core/contracts/lib/RevertBytes.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";
import {CallBeforeQuoteLib} from "silo-core/contracts/lib/CallBeforeQuoteLib.sol";

import {PartialLiquidationExecLib} from "./lib/PartialLiquidationExecLib.sol";

/// @title PartialLiquidation module for executing liquidations
/// @dev if we need additional hook functionality, this contract should be included as parent
contract PartialLiquidation is IPartialLiquidation, IHookReceiver {
    using SafeERC20 for IERC20;
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    ISiloConfig public siloConfig;

    function initialize(ISiloConfig _siloConfig, bytes calldata) external virtual {
        _initialize(_siloConfig);
    }

    function beforeAction(address, uint256, bytes calldata) external virtual {
        // not in use
    }

    function afterAction(address, uint256, bytes calldata) external virtual {
        // not in use
    }

    // liquidationFee: 5%
    // collateral: 1000 USDC
    // debt: 900 USDC
    // LTV: 90%
    // LT: 90%
    // min LTV after liquidation: 90% - 10% = 80%

    // liquidationCall(x)

    // collateral: 1000 USDC - x - x * 5% = 1000 USDC - 1.05x
    // debt: 900 USDC - x

    // LTV: (900 USDC - x) / (1000 USDC - 1.05x) >= 80%

    // 300 / 370 = 0.8108 LTV
    // 900 / 1000 = 0.9 LTV

    // liquidation
    //   - GLOBAL
    //     - liquidator never repay more than debtToCover
    //     - user must be insolvent
    //   - liquidation by third party
    //     - user is solvent => revert
    //     - LTV change:
    //         |    partial liquidation       |     full liquidation      |      bad debt - any liquidation    | 
    //       - LTV decreases:
    //         - partial liquidation on a user that liquidaiton size is below dust
    //       - LTV increases:
    //         - partial liquidation with bad debt
    //       - LTV is 0:
    //         - full liquidation
    //     - partial liquidation
    //       - debtToCover is set to above allowed LTV after liquidation => adjust to maximum allowed value
    //     - full liquidaiton
    //       - if liqudatior repays more than 90% of debt
    //     - partial/full liquidation
    //       - bad debt
    //         - give collateral + liquidation fee
    //         - if not enough collateral give all collateral
    //         - if 0 collateral - revert => use repay instead
    //   - liquidation by third party with sToken

    // TODO: add natspec
    // TODO: remove self liquidation
    /// @inheritdoc IPartialLiquidation
    function liquidationCall( // solhint-disable-line function-max-lines, code-complexity
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        // TODO: rename to _maxDebtToCover and do not revert
        uint256 _debtToCover,
        bool _receiveSToken
    )
        external
        virtual
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        ISiloConfig siloConfigCached = siloConfig;

        if (address(siloConfigCached) == address(0)) revert EmptySiloConfig();
        if (_debtToCover == 0) revert NoDebtToCover();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _fetchConfigs(siloConfigCached, _collateralAsset, _debtAsset, _borrower);

        uint256 collateralShares;
        uint256 protectedShares;
        uint256 withdrawAssetsFromCollateral;
        uint256 withdrawAssetsFromProtected;

        bool selfLiquidation = _borrower == msg.sender;

        (
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected, repayDebtAssets
        ) = PartialLiquidationExecLib.getExactLiquidationAmounts(
            collateralConfig,
            debtConfig,
            _borrower,
            _debtToCover,
            selfLiquidation ? 0 : collateralConfig.liquidationFee,
            selfLiquidation
        );

        if (repayDebtAssets == 0) revert NoDebtToCover();
        // TODO: change the name of revert to reflect the nature of revert which is we do not allow dust so full liqudiation is required
        if (repayDebtAssets > _debtToCover) revert DebtToCoverTooSmall();

        emit LiquidationCall(msg.sender, _receiveSToken);

        siloConfigCached.turnOnReentrancyProtection();
        IERC20(debtConfig.token).safeTransferFrom(msg.sender, address(this), repayDebtAssets);
        IERC20(debtConfig.token).safeIncreaseAllowance(debtConfig.silo, repayDebtAssets);
        siloConfigCached.turnOffReentrancyProtection();

        ISilo(debtConfig.silo).repay(repayDebtAssets, _borrower);

        address shareTokenReceiver = _receiveSToken ? msg.sender : address(this);

        collateralShares = _callShareTokenForwardTransferNoChecks(
            collateralConfig.silo,
            _borrower,
            shareTokenReceiver,
            withdrawAssetsFromCollateral,
            collateralConfig.collateralShareToken,
            AssetTypes.COLLATERAL
        );

        protectedShares = _callShareTokenForwardTransferNoChecks(
            collateralConfig.silo,
            _borrower,
            shareTokenReceiver,
            withdrawAssetsFromProtected,
            collateralConfig.protectedShareToken,
            AssetTypes.PROTECTED
        );

        if (_receiveSToken) {
            // TODO: call previewRedeem() for both to get correct result
            // this two value were split from total collateral to withdraw, so we will not overflow
            unchecked { withdrawCollateral = withdrawAssetsFromCollateral + withdrawAssetsFromProtected; }
        } else {
            // in case of liquidation redeem, hook transfers sTokens to itself and it has no debt
            // so solvency will not be checked in silo on redeem action

            // if share token offset is more than 0, positive number of shares can generate 0 assets
            // so there is a need to check assets before we withdraw collateral/protected

            if (collateralShares != 0) {
                // TODO: named params
                withdrawCollateral = ISilo(collateralConfig.silo).redeem(
                    collateralShares,
                    msg.sender,
                    address(this),
                    ISilo.CollateralType.Collateral
                );
            }

            if (protectedShares != 0) {
                unchecked {
                    // protected and collateral values were split from total collateral to withdraw,
                    // so we will not overflow when we sum them back, especially that on redeem, we rounding down
                    // TODO: named params
                    withdrawCollateral += ISilo(collateralConfig.silo).redeem(
                        protectedShares,
                        msg.sender,
                        address(this),
                        ISilo.CollateralType.Protected
                    );
                }
            }
        }
    }

    function hookReceiverConfig(address) external virtual view returns (uint24 hooksBefore, uint24 hooksAfter) {
        return (0, 0);
    }

    /// @inheritdoc IPartialLiquidation
    function maxLiquidation(address _borrower)
        external
        view
        virtual
        returns (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired)
    {
        return PartialLiquidationExecLib.maxLiquidation(siloConfig, _borrower);
    }

    function _fetchConfigs(
        ISiloConfig _siloConfigCached,
        address _collateralAsset,
        address _debtAsset,
        address _borrower
    )
        internal
        virtual
        returns (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        )
    {
        (collateralConfig, debtConfig) = _siloConfigCached.getConfigsForSolvency(_borrower);

        if (debtConfig.silo == address(0)) revert UserIsSolvent();
        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        ISilo(debtConfig.silo).accrueInterest();

        if (collateralConfig.silo != debtConfig.silo) {
            ISilo(collateralConfig.silo).accrueInterest();
            collateralConfig.callSolvencyOracleBeforeQuote();
            debtConfig.callSolvencyOracleBeforeQuote();
        }
    }

    function _callShareTokenForwardTransferNoChecks(
        address _silo,
        address _borrower,
        address _receiver,
        uint256 _withdrawAssets,
        address _shareToken,
        uint256 _assetType
    ) internal virtual returns (uint256 shares) {
        if (_withdrawAssets == 0) return 0;
        
        // TODO: do we have a test to check if it is possible to overestimate shares?
        shares = SiloMathLib.convertToShares(
            _withdrawAssets,
            ISilo(_silo).getTotalAssetsStorage(_assetType),
            IShareToken(_shareToken).totalSupply(),
            Rounding.LIQUIDATE_TO_SHARES,
            ISilo.AssetType(_assetType)
        );

        if (shares == 0) return 0;

        (bool success, bytes memory result) = ISilo(_silo).callOnBehalfOfSilo(
            _shareToken,
            0 /* eth value */,
            ISilo.CallType.Call,
            abi.encodeWithSelector(IShareToken.forwardTransferFromNoChecks.selector, _borrower, _receiver, shares)
        );

        if (!success) RevertBytes.revertBytes(result, "");
    }

    function _initialize(ISiloConfig _siloConfig) internal virtual {
        if (address(_siloConfig) == address(0)) revert EmptySiloConfig();
        if (address(siloConfig) != address(0)) revert AlreadyConfigured();

        siloConfig = _siloConfig;
    }
}
