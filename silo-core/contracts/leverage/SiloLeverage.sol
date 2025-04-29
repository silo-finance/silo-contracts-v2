// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISilo, IERC3156FlashLender} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";

import {ISilo, IERC4626, IERC3156FlashLender} from "./interfaces/ISilo.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {ISiloOracle} from "./interfaces/ISiloOracle.sol";
import {ISiloLeverage} from "./ISiloLeverage.sol";

contract SiloLeverage is ISiloLeverage, IERC3156FlashBorrower {
    uint256 internal constant _DECIMALS = 1e18;
    
    /// @dev Silo is not designed to work with ether, but it can act as a middleware
    /// between any third-party contract and hook receiver. So, this is the responsibility
    /// of the hook receiver developer to handle it if needed.
    receive() external payable {}

    /// @inheritdoc ISiloLeverage
    function leverage(
        ISilo _silo,
        uint256 _deposit,
        ISilo.CollateralType _collateralType,
        uint64 _multiplier,
        IERC3156FlashLender _flashLoanLender,
        uint256 _borrowAmount
    ) external view virtual override {
        // TODO
    }

    /// @inheritdoc ISiloLeverage
    function previewLeverage(
        ISilo _silo,
        uint256 _deposit,
        uint64 _multiplier,
        IERC3156FlashLender _flashloanLender,
        uint64 _swapSlippage
    ) external view virtual override returns (
        uint256 flashLoanAmount,
        uint256 borrowAmount,
        uint64 finalMultiplier
    ) {
        ISiloConfig config = _silo.config();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = config.getConfigsForBorrow();

        uint256 maxFlashLoan = _flashloanLender.maxFlashLoan(collateralConfig.token);
        flashLoanAmount = Math.min(_deposit * _multiplier / _DECIMALS, maxFlashLoan);
        finalMultiplier = flashLoanAmount * _DECIMALS / _deposit;

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = config.getConfigsForBorrow();

        // TODO notice we using maxLtvOracle
        uint256 flashValue = _quote(collateralConfig.maxLtvOracle, flashLoanAmount, collateralConfig.token);

        uint256 totalCollateralValue = collateralConfig.maxLtvOracle == address(0)
            ? flashLoanAmount
            : _calculateValueBasedOnRatio(flashLoanAmount, flashValue, flashLoanAmount + _deposit);

        // we don't know debt
        uint256 debtSampleAmount = 1e18;
        uint256 debtSampleValue = _quote(debtConfig.maxLtvOracle, debtSampleAmount, debtConfig.token);

        uint256 maxBorrowValue = totalCollateralValue * collateralConfig.maxLtv / _DECIMALS;

        uint256 borrowAmountForWholeCollateral = debtSampleAmount * totalCollateralValue / debtSampleValue;
        // maxLTV % of total collateral (flashLoanAmount + _deposit)
        uint256 maxBorrowAmount = debtSampleAmount * maxBorrowValue / debtSampleValue;
        uint256 collateralToDebtRatio = totalCollateralValue * _DECIMALS / borrowAmountForWholeCollateral;

        uint256 collateralSlippage = _swapSlippage * (flashLoanAmount + flashLoanFeeInCollateralToken) / _DECIMALS;
        uint256 collateralSlippageInDebtToken = collateralSlippage * _DECIMALS / collateralToDebtRatio;
        uint256 flashLoanFeeInDebtToken = _flashloanLender.flashFee(collateralConfig.token, flashLoanAmount) * _DECIMALS / collateralToDebtRatio;

        borrowAmount = Math.min(
            debtSampleAmount * flashValue / debtSampleValue
                + flashLoanFeeInDebtToken + leverageFeeInDebtToken + collateralSlippageInDebtToken,
            maxBorrowAmount
        );
    }

    function _calculateValueBasedOnRatio(uint256 _amount, uint256 _value, uint256 _inputAmount)
        internal
        view
        returns (uint256 outputValue)
    {
        outputValue = _inputAmount * _value / _amount;
    }

    function _quote(address _oracle, uint256 _baseAmount, address _baseToken)
        internal
        view
        returns (uint256 quoteAmount)
    {
        quoteAmount = _oracle == address(0)
            ? _baseAmount
            : ISiloOracle(_oracle).quote(_baseAmount, _baseToken);
    }

    function closeLeverage(
        ISilo _silo,
        ISilo.CollateralType _collateralType,
        IERC3156FlashLender _flashloanLender
    ) external view virtual override returns (ISilo) {
        // TODO
    }

    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
        external
        returns (bytes32)
    {
        // TODO
    }

    function borrowFlashloan(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) {
        // TODO
        IERC3156FlashLender.flashLoan({
            _receiver: _receiver,
            _token: _token,
            _amount: _amount,
            _data: _data
        });
    }
}
