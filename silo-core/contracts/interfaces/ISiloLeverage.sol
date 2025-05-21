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

import {IZeroExSwapModule} from "../interfaces/IZeroExSwapModule.sol";

interface ISiloLeverage {
    /// @param flashDebtLender address from where contract will get flashloan
    /// @param token token address
    /// @param amount flash amount
    struct FlashArgs {
        address flashDebtLender;
        address token;
        uint256 amount;
    }

    /// @param leverageAmount total deposit amount (sum of user deposit amount + flashloan amount)
    struct DepositArgs {
        ISilo silo;
        uint256 leverageAmount;
        ISilo.CollateralType collateralType;
        address receiver;
    }

    /// @param amount amount to borrow, should be equal to flashloan amount + flashloan fee + leverage fee
    struct BorrowArgs {
        ISilo silo;
        uint256 amount;
        address receiver;
    }

    error FlashloanFailed();
    error InvalidFlashloanLender();

    /// @dev It can revert when:
    /// - amount is so hi we can not calculate fee
    function leverage(
        FlashArgs calldata _flashArgs,
        IZeroExSwapModule.SwapArgs calldata _swapArgs,
        DepositArgs calldata _depositArgs,
        ISilo _borrowSilo
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
