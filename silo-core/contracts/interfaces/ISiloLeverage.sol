// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISilo, IERC3156FlashLender} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";

import {ISilo, IERC4626, IERC3156FlashLender} from "./ISilo.sol";
import {IShareToken} from "./IShareToken.sol";

import {IERC3156FlashBorrower} from "./IERC3156FlashBorrower.sol";
import {ISiloConfig} from "./ISiloConfig.sol";
import {ISiloFactory} from "./ISiloFactory.sol";
import {ISiloOracle} from "./ISiloOracle.sol";

interface ISiloLeverage {
    /// @param _silo Silo address on which we doing leverage
    /// @param _deposit deposit amount that user actually do
    /// @param _collateralType collateral type
    /// @param _multiplier leverage multiplier in 18 decimals, eg x1 == 1e18
    /// @param _flashDebtLender source for flashloan
    /// @param _borrowAmount amount of debt that leverage will create.
    /// This amount will be used to repay flashloan, pay fees and change will be transferred to user
    function leverage(
        ISilo _silo,
        uint256 _deposit,
        ISilo.CollateralType _collateralType,
        uint64 _multiplier,
        IERC3156FlashLender _flashDebtLender,
        uint256 _borrowAmount
    ) external;

    /// @param _silo Silo address on which we doing leverage
    /// @param _deposit deposit amount that user actually do
    /// @param _multiplier leverage multiplier in 18 decimals, eg x1 == 1e18
    /// @param _flashDebtLender source for flashloan of debt token
    /// @param _debtFlashloan amount of debt token that will be flashloaned
    /// debt Flashloan amount should be calculated in this way: quote(deposit * leverage)
    /// Swap fee and slippage are not considered. That means actual result will be UP TO provided leverage (usually less)
     /// @return flashLoanAmount flashloan amount that is required for leverage
    /// @return debtPreview amount of debt that leverage will create
    /// Borrow amount must be enough to:
    /// - cover leverage fee (fee is in debt token)
    /// - cover flashloan repay + flashloan fee
    /// @return finalMultiplier final multiplier of leverage (might be different from input _multiplier)
    function previewLeverage(
        ISilo _silo,
        uint256 _deposit,
        uint64 _multiplier,
        IERC3156FlashLender _flashDebtLender,
        uint256 _debtFlashloan
    ) external view returns (
        uint256 flashLoanAmount,
        uint256 debtPreview,
        uint64 finalMultiplier
    );
//
//    function closeLeverage(
//        ISilo _silo,
//        ISilo.CollateralType _collateralType,
//        IERC3156FlashLender _flashloanLender
//    ) external view virtual override returns (ISilo);
//
//    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
//        external
//        returns (bytes32);
}
