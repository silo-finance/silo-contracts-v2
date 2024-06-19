// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";

import {SiloStorage} from "silo-core/contracts/SiloStorage.sol";

import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {Actions} from "silo-core/contracts/lib/Actions.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {RevertBytes} from "silo-core/contracts/lib/RevertBytes.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";
import {CallBeforeQuoteLib} from "silo-core/contracts/lib/CallBeforeQuoteLib.sol";

import {PartialLiquidationExecLib} from "./lib/PartialLiquidationExecLib.sol";
import {LiquidationWithdrawLib} from "./lib/LiquidationWithdrawLib.sol";


/// @title PartialLiquidation module for executing liquidations
/// @dev if we need additional hook functionality, this contract should be included as parent
contract PartialLiquidation is SiloStorage, IPartialLiquidation, IHookReceiver {
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    mapping(address silo => HookSetup) private _hooksSetup;

    modifier onlyDelegateCall() {
        if (msg.sender != address(this)) revert OnlyDelegateCall();

        _;
    }

    function initialize(ISiloConfig, bytes calldata) external virtual {
        // nothing to do
    }

    function beforeAction(address, uint256, bytes calldata) external virtual {
        // not in use
    }

    function afterAction(address, uint256, bytes calldata) external virtual {
        // not in use
    }

    function hookReceiverConfig(address) external virtual view returns (uint24 hooksBefore, uint24 hooksAfter) {
        return (0, 0);
    }

    /// @inheritdoc IPartialLiquidation
    function liquidationCall(
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
        (
            ISiloConfig siloConfigCached,
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _fetchConfigs(_siloWithDebt, _collateralAsset, _debtAsset, _borrower);

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

        // this two value were split from total collateral to withdraw, so we will not overflow
        unchecked { withdrawCollateral = withdrawAssetsFromCollateral + withdrawAssetsFromProtected; }

        emit LiquidationCall(msg.sender, _receiveSToken);

        _delegateRepayLiquidator(debtConfig.silo, repayDebtAssets, _borrower, msg.sender);

        _delegateWithdrawCollateralsToLiquidator(
            collateralConfig.silo,
            withdrawAssetsFromCollateral,
            withdrawAssetsFromProtected,
            _borrower,
            _receiveSToken
        );

        siloConfigCached.crossNonReentrantAfter();
    }

    /// @inheritdoc IPartialLiquidation
    function liquidationRepay(uint256 _assets, address _borrower, address _repayer)
        onlyDelegateCall
        external
        virtual
        returns (uint256 shares)
    {
        (
            , shares
        ) = Actions.repay(_sharedStorage, _assets, 0 /* shares */, _borrower, _repayer, _total[AssetTypes.DEBT]);

        emit ISilo.Repay(_repayer, _borrower, _assets, shares);
    }

    /// @inheritdoc IPartialLiquidation
    // TODO if we want hooks, we need to ad them to withdraw as well, so maybe it is better to call regular withdraw?
    function withdrawCollateralsToLiquidator(
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        bool _receiveSToken
    ) onlyDelegateCall external virtual {
        LiquidationWithdrawLib.withdrawCollateralsToLiquidator(
            _sharedStorage.siloConfig,
            _withdrawAssetsFromCollateral,
            _withdrawAssetsFromProtected,
            _borrower,
            _liquidator,
            _receiveSToken,
            _getRawLiquidity(),
            _total
        );
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

    function _getRawLiquidity() internal view virtual returns (uint256 liquidity) {
        return SiloMathLib.liquidity(_total[AssetTypes.COLLATERAL].assets, _total[AssetTypes.DEBT].assets);
    }

    function _fetchConfigs(
        address _siloWithDebt,
        address _collateralAsset,
        address _debtAsset,
        address _borrower
    )
        internal
        returns (
            ISiloConfig siloConfigCached,
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        )
    {
        siloConfigCached = ISilo(_siloWithDebt).config();

        ISiloConfig.DebtInfo memory debtInfo;

        (collateralConfig, debtConfig, debtInfo) = siloConfigCached.accrueInterestAndGetConfigs(
            _siloWithDebt,
            _borrower,
            Hook.LIQUIDATION
        );

        // We validate that both Silos have the same config data which means that potential attacker has no choice
        // but provide either two real silos or two fake silos. While providing two fake silos, neither silo has access
        // to real balances so the attack is pointless.
        (address silo0, address silo1) = ISilo(collateralConfig.silo).config().getSilos();
        if (_siloWithDebt != silo0 && _siloWithDebt != silo1) revert WrongSilo();

        if (!debtInfo.debtPresent) revert UserIsSolvent();
        if (!debtInfo.debtInThisSilo) revert ISilo.ThereIsDebtInOtherSilo();

        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        if (!debtInfo.sameAsset) {
            ISilo(debtConfig.otherSilo).accrueInterest();
            collateralConfig.callSolvencyOracleBeforeQuote();
            debtConfig.callSolvencyOracleBeforeQuote();
        }
    }

    function _delegateWithdrawCollateralsToLiquidator(
        address _silo,
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        bool _receiveSToken
    ) internal {
        (bool success, bytes memory result) = ISilo(_silo).callOnBehalfOfSilo(
            address(this),
            0 /* eth value */,
            ISilo.CallType.Delegatecall,
            abi.encodeWithSelector(
                IPartialLiquidation.withdrawCollateralsToLiquidator.selector,
                _withdrawAssetsFromCollateral,
                _withdrawAssetsFromProtected,
                _borrower,
                msg.sender,
                _receiveSToken
            )
        );

        if (!success) RevertBytes.revertBytes(result, "");
    }

    function _delegateRepayLiquidator(
        address _silo,
        uint256 _assets,
        address _borrower,
        address _repayer
    ) internal {
        (bool success, bytes memory result) = ISilo(_silo).callOnBehalfOfSilo(
            address(this),
            0 /* eth value */,
            ISilo.CallType.Delegatecall,
            abi.encodeWithSelector(IPartialLiquidation.liquidationRepay.selector, _assets, _borrower, _repayer)
        );

        if (!success) RevertBytes.revertBytes(result, "");
    }
}
