// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISilo, IERC3156FlashLender} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";

import {ISilo, IERC4626, IERC3156FlashLender} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";

import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISiloFactory} from "../interfaces/ISiloFactory.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISiloLeverage} from "../interfaces/ISiloLeverage.sol";

contract SiloLeverage is ISiloLeverage
//, IERC3156FlashBorrower
{
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
    ) external virtual {
        // TODO
    }

    /// @inheritdoc ISiloLeverage
    function previewLeverage(
        ISilo _silo,
        uint256 _deposit, // 2e18
        uint64 _multiplier, // 1.5e18
        IERC3156FlashLender _flashLoanLender,
        uint64 _swapSlippage, // 0.01e18,
        uint256 _collateralToDebtRatio // 500000000e18
    ) external view virtual returns (
        uint256 flashLoanAmount,
        uint256 borrowAmount,
        uint64 finalMultiplier
    ) {
        uint256 leverageFeeInDebtToken = 1;
        ISiloConfig config = _silo.config();

        (address silo0, address silo1) = config.getSilos();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = config.getConfigsForBorrow(silo0 == address(_silo) ? silo1 : silo0);

        // maxFlashLoan: unlimited
        uint256 maxFlashLoan = _flashLoanLender.maxFlashLoan(collateralConfig.token);
        // flashLoanAmount = (2e18 * 1.5e18 / 1e18) = 3e18
        flashLoanAmount = Math.min(_deposit * _multiplier / _DECIMALS, maxFlashLoan);
        // finalMultiplier = 3e18 * 1e18 / 2e18 = 1.5e18
        finalMultiplier = uint64(flashLoanAmount * _DECIMALS / _deposit);

        // flashLoanFeeInCollateralToken = 0.005e18
        uint256 flashLoanFeeInCollateralToken = _flashLoanLender.flashFee(collateralConfig.token, flashLoanAmount);

        // TODO notice we using maxLtvOracle
        // flashValue = 3e18 * $2000 = 6000e6
        uint256 flashValue = _quote(collateralConfig.maxLtvOracle, flashLoanAmount, collateralConfig.token);
        // totalCollateral = 3e18 + 2e18 = 5e18
        uint256 totalCollateral = flashLoanAmount + _deposit;

        // totalCollateralValue = 5e18 * $2000 = 10_000e6
        uint256 totalCollateralValue = collateralConfig.maxLtvOracle == address(0)
            ? totalCollateral
            : _calculateValueBasedOnRatio(flashLoanAmount, flashValue, totalCollateral);

        // we need to calculate amount to borrow,
        // for that we need to figure out ratio between collateral token and borrow token
        // would that be easier to provide by BE? our oracles are not ment for swap

        // maxLTV % of total collateral (flashLoanAmount + _deposit)
        // maxPossibleBorrowAmount = 5e18 * 0.80e18 / 500000000e18 = 8000e6
        uint256 maxPossibleBorrowAmount = totalCollateral * collateralConfig.maxLtv / _collateralToDebtRatio;

        // collateralSlippage = 0.01e18 * (3e18 + 0.005e18) / 1e18 = 0.03005e18
        uint256 collateralSlippage = _swapSlippage * (flashLoanAmount + flashLoanFeeInCollateralToken) / _DECIMALS;
        // amount of collateral needed after swap
        // amountOut = 3e18 + 0.005e18 + 0.03005e18 = 3.03505e18
        uint256 amountOut = flashLoanAmount + flashLoanFeeInCollateralToken + collateralSlippage;
        // amountOutInDebtToken = 3.03505e18 * 1e18 / 500000000e18 = 6070.1e18
        uint256 amountOutInDebtToken = amountOut * _DECIMALS / _collateralToDebtRatio;

        // borrowAmount = min(6070.1e18 + 1, 8000e6) = 6070.1e18
        borrowAmount = Math.min(amountOutInDebtToken + leverageFeeInDebtToken, maxPossibleBorrowAmount);
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
        IERC3156FlashLender _flashLoanLender
    ) external view virtual returns (ISilo) {
        // TODO
    }

    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
        external
        returns (bytes32)
    {
        // TODO
    }
//
//    function borrowFlashloan(
//        IERC3156FlashBorrower _receiver,
//        address _token,
//        uint256 _amount,
//        bytes calldata _data
//    ) {
//        // TODO
//        IERC3156FlashLender.flashLoan({
//            _receiver: _receiver,
//            _token: _token,
//            _amount: _amount,
//            _data: _data
//        });
//    }
}
