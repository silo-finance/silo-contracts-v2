// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo, IERC3156FlashLender} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";

import {ISilo, IERC4626, IERC3156FlashLender} from "./interfaces/ISilo.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {ISiloOracle} from "./interfaces/ISiloOracle.sol";

import {ShareCollateralToken} from "./utils/ShareCollateralToken.sol";

import {Actions} from "./lib/Actions.sol";
import {Views} from "./lib/Views.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";
import {SiloERC4626Lib} from "./lib/SiloERC4626Lib.sol";
import {SiloMathLib} from "./lib/SiloMathLib.sol";
import {Rounding} from "./lib/Rounding.sol";
import {Hook} from "./lib/Hook.sol";
import {ShareTokenLib} from "./lib/ShareTokenLib.sol";
import {SiloStorageLib} from "./lib/SiloStorageLib.sol";

interface ISiloLeverage {
    /// @param _silo Silo address on which we doing leverage
    /// @param _deposit deposit amount that user actually do
    /// @param _collateralType collateral type
    /// @param _multiplier leverage multiplier in 18 decimals, eg x1 == 1e18
    /// @param _flashLoanLender source for flashloan
    /// @returns borrowAmount amount of debt that leverage will create.
    /// This amount will be used to repay flashloan, pay fees and change will be transferred to user
    function leverage(
        ISilo _silo,
        uint256 _deposit,
        ISilo.CollateralType _collateralType,
        uint64 _multiplier,
        IERC3156FlashLender _flashLoanLender,
        uint256 _borrowAmount
    ) external view virtual override returns (ISilo);

    /// @param _silo Silo address on which we doing leverage
    /// @param _deposit deposit amount that user actually do
    /// @param _multiplier leverage multiplier in 18 decimals, eg x1 == 1e18
    /// @param _flashLoanLender source for flashloan
    /// @param _swapSlippage max slippage for swap user will use to generate quote for swap data for leverage
    /// Slippage is taken into consideration for calculate borrow amount, it increases amount of collateral by slippage
    /// to have 100% guarantee that after swap we can cover all expenses
    /// @returns flashLoanAmount flashloan amount that is required for leverage
    /// @returns borrowAmount amount of debt that leverage will create
    /// Borrow amount must be enough to:
    /// - cover leverage fee (fee is in debt token)
    /// - after swap it to collateral token cover flashloan repay + flashloan fee
    /// @returns finalMultiplier final multiplier of leverage (might be different from input _multiplier)
    function previewLeverage(
        ISilo _silo,
        uint256 _deposit,
        uint64 _multiplier,
        IERC3156FlashLender _flashLoanLender,
        uint64 _swapSlippage
    ) external view virtual override returns (
        uint256 flashLoanAmount,
        uint256 borrowAmount,
        uint64 finalMultiplier
    );

    function closeLeverage(
        ISilo _silo,
        ISilo.CollateralType _collateralType,
        IERC3156FlashLender _flashloanLender
    ) external view virtual override returns (ISilo);

    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
        external
        returns (bytes32);
}
