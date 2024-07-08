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

import {SiloStorage} from "silo-core/contracts/SiloStorage.sol";

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
contract PartialLiquidation is SiloStorage, IPartialLiquidation, IHookReceiver {
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

    /// @inheritdoc IPartialLiquidation
    function liquidationCall( // solhint-disable-line function-max-lines
        address _siloWithDebt,
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
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
        ) = _fetchConfigs(siloConfigCached, _siloWithDebt, _collateralAsset, _debtAsset, _borrower);

        uint256 collateralShares;
        uint256 protectedShares;

        { // too deep
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
            if (repayDebtAssets > _debtToCover) revert DebtToCoverTooSmall();

            emit LiquidationCall(msg.sender, _receiveSToken);

            IERC20(debtConfig.token).safeTransferFrom(msg.sender, address(this), repayDebtAssets);
            IERC20(debtConfig.token).safeIncreaseAllowance(debtConfig.silo, repayDebtAssets);
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
        }

        if (_receiveSToken) {
            // this two value were split from total collateral to withdraw, so we will not overflow
            unchecked { withdrawCollateral = withdrawAssetsFromCollateral + withdrawAssetsFromProtected; }
        } else {
            // in case of liquidation redeem, hook transfers sTokens to itself and it has no debt
            // so solvency will not be checked in silo on redeem action

            if (collateralShares != 0) {
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
    function maxLiquidation(address _siloWithDebt, address _borrower)
        external
        view
        virtual
        returns (uint256 collateralToLiquidate, uint256 debtToRepay)
    {
        return PartialLiquidationExecLib.maxLiquidation(ISilo(_siloWithDebt), _borrower);
    }

    function _fetchConfigs(
        ISiloConfig _siloConfigCached,
        address _siloWithDebt,
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
        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = _siloConfigCached.getConfigs(
            _siloWithDebt,
            _borrower,
            Hook.LIQUIDATION
        );

        if (!debtInfo.debtPresent) revert UserIsSolvent();
        if (!debtInfo.debtInThisSilo) revert ISilo.ThereIsDebtInOtherSilo();
        if (_siloWithDebt != debtConfig.silo) revert WrongSilo();

        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        ISilo(debtConfig.silo).accrueInterest();

        if (!debtInfo.sameAsset) {
            ISilo(debtConfig.otherSilo).accrueInterest();
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
        
        shares = SiloMathLib.convertToShares(
            _withdrawAssets,
            ISilo(_silo).total(_assetType),
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
