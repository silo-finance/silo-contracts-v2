// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISilo, IERC3156FlashLender} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";
import {ErrorsLib} from "./modules/ErrorsLib.sol";

import {ISilo, IERC4626, IERC3156FlashLender} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";

import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISiloFactory} from "../interfaces/ISiloFactory.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISiloLeverage} from "../interfaces/ISiloLeverage.sol";

contract SiloLeverage is ISiloLeverage, IERC3156FlashBorrower {
    uint256 internal constant _DECIMALS = 1e18;
    uint256 internal constant _LEVERAGE_FEE_IN_DEBT_TOKEN = 1e18;

    address internal _lock;

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
        IERC3156FlashLender _flashDebtLender,
        uint256 _flashBorrow
    ) external virtual {
        _lock = _flashDebtLender;

        _borrowFlashloan();

        // transient lock will force some design part eg flashloan can not be module
        _lock = address(0);
    }

    // TODO I see this issues with preview:
    // 1. it will not be deterministic, because it depends on swap result and swap has fee and slippage
    // so expected result will be always lower than preview method can estimate
    //
    // 2. we have another approximation: collateral/debt ratio, it will affect result as well
    //
    //
    // so in general IDK if it will not be better to simply do static call to `leverage` instead
    // if method is not deterministic does it bring value for UI?

    /// @inheritdoc ISiloLeverage
    function previewLeverage(
        ISilo _silo,
        uint256 _deposit, // 2e18
        uint64 _multiplier, // 1.5e18
        IERC3156FlashLender _flashDebtLender,
        uint256 _debtFlashloan // 1.5e18 * $2000 = 3000e6,
    ) external view virtual returns (
        uint256 flashLoanAmount,
        uint256 debtPreview,
        uint64 finalMultiplier
    ) {
        ISiloConfig config = _silo.config();

        (address silo0, address silo1) = config.getSilos();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = config.getConfigsForBorrow(silo0 == address(_silo) ? silo1 : silo0);

        // maxFlashLoan: unlimited
        uint256 maxFlashLoan = _flashDebtLender.maxFlashLoan(debtConfig.token);
        // flashLoanAmount = 3000e6 = 3000e6
        flashLoanAmount = Math.min(_debtFlashloan, maxFlashLoan);
        // finalMultiplier = 3000e6 * 1.5e18 / 3000e6 = 1.5e18
        finalMultiplier = uint64(flashLoanAmount * _multiplier / _debtFlashloan);

        // flashLoanFeeInCollateralToken = 0.005e18
        uint256 flashLoanFeeInCollateralToken = _flashDebtLender.flashFee(debtConfig.token, flashLoanAmount);
        uint256 leverageFee = flashLoanAmount * _LEVERAGE_FEE_IN_DEBT_TOKEN / _DECIMALS;
        debtPreview = flashLoanAmount + flashLoanFeeInCollateralToken + leverageFee;

        // TODO notice we using maxLtvOracle
        // we not using `_collateralToDebtRatio` here, because quote in this case is more precise, quote is what Silo uses to calculate value
        // flashValue = 3e18 * $2000 = 6000e6
        uint256 flashValue = _quote(collateralConfig.maxLtvOracle, flashLoanAmount, collateralConfig.token);
        // totalCollateral = 3e18 + 2e18 = 5e18
        uint256 totalCollateral = (finalMultiplier + _DECIMALS) * _deposit / _DECIMALS;

        // TODO this is another estimation
        uint256 collateralToDebtRatio = _multiplier * _deposit / _debtFlashloan;

        // we need to calculate amount to borrow,
        // for that we need to figure out ratio between collateral token and borrow token
        // would that be easier to provide by BE? our oracles are not ment for swap

        // maxLTV % of total collateral (flashLoanAmount + _deposit)
        // maxPossibleBorrowAmount = 5e18 * 0.80e18 / 500000000e18 = 8000e6
        uint256 maxPossibleBorrowAmount = totalCollateral * collateralConfig.maxLtv / collateralToDebtRatio;

        if (debtPreview > maxPossibleBorrowAmount) {
            // CAP on maxLTV
            debtPreview = maxPossibleBorrowAmount;
            // DO reverse calculation to provide new multiplier and new flashLoanAmount
        }
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

    /// @param _flashDebtLender
    function _borrowFlashloan(
        address _flashDebtLender,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) internal {
        // TODO
        require(IERC3156FlashLender(_flashDebtLender).flashLoan({
            _receiver: address(this),
            _token: _token,
            _amount: _amount,
            _data: _data
        }), ErrorsLib.FlashloanFailed());
    }

    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
        external
        returns (bytes32)
    {
        require(_lock == msg.sender, ErrorsLib.InvalidFlashloanLender());

        // TODO
        // swap
        // transfer from
        // deposit
        // borrow
        // take leverage fee
        // repay flashloan
        // calculate leverage
    }

}
