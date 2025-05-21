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

import {ZeroExSwapModule} from "./modules/ZeroExSwapModule.sol";
import {RevenueModule} from "./modules/RevenueModule.sol";

// TODO nonReentrant
contract SiloLeverage is ISiloLeverage, ZeroExSwapModule, RevenueModule, IERC3156FlashBorrower {
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");
    uint256 internal constant _DECIMALS = 1e18;
    uint256 internal constant _LEVERAGE_FEE_IN_DEBT_TOKEN = 1e18;

    address internal _lock;

    /// @inheritdoc ISiloLeverage
    function leverage(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        DepositArgs calldata _depositArgs,
        ISilo _borrowSilo
    ) external virtual returns (uint256 multiplier) {
        _lock = _flashArgs.flashDebtLender;

        bytes memory data = abi.encode(_swapArgs, _depositArgs, _borrowSilo);

        _borrowFlashloan(_flashArgs, data);

        multiplier = _flashArgs.amount * _DECIMALS / _depositArgs.amount;

        // transient lock will force design pattern, eg flashloan can not be module
        _lock = address(0);

        // TODO: does is worth to add check for delta balance + fee at the end?
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
    ) external view virtual returns (ISilo silo) {
        // TODO
    }

    function _borrowFlashloan(FlashArgs calldata _flashArgs, bytes calldata _data) internal virtual {
        require(IERC3156FlashLender(_flashArgs.flashDebtLender).flashLoan({
            _receiver: address(this),
            _token: _flashArgs.token,
            _amount: _flashArgs.amount,
            _data: _data
        }), FlashloanFailed());
    }

    function onFlashLoan(
        address _initiator,
        address _borrowToken,
        uint256 _amount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        external
        returns (bytes32)
    {
        require(_lock == msg.sender, InvalidFlashloanLender());

        (
            SwapArgs memory swapArgs,
            DepositArgs memory depositArgs,
            ISilo borrowSilo
        ) = abi.decode(_data, (SwapArgs, DepositArgs, ISilo));

        // TODO it is better to transfer fee imediately to receiver? otherwise we wil have to deal with balances locally
        // eg. after swap, we can simply do balanceOf(token) OR we have to add compelcity and track balance bofore and after
        uint256 amountOut = _fillQuote(swapArgs, _amount);

        _deposit(depositArgs, IERC20(swapArgs.buyToken));

        uint256 leverageFee = _calculateLeverageFee(depositArgs.totalDeposit);

        // leverage fee will be leftover after borrow and repay flashloan
        BorrowArgs memory borrowArgs = BorrowArgs(borrowSilo, _amount + _flashloanFee + leverageFee, depositArgs.receiver);
        _borrow(borrowArgs);

        if (leverageFee != 0) IERC20(_borrowToken).safeTransfer(leverageFee, revenueReceiver);

        return _FLASHLOAN_CALLBACK;
    }

    function _deposit(DepositArgs memory _depositArgs, IERC20 _asset) virtual internal {
        _asset.forceApprove(address(_depositArgs.silo), _depositArgs.depositAmount);
        _depositArgs.silo.deposit(_depositArgs.depositAmount, _depositArgs.receiver, _depositArgs.collateralType);
        _asset.forceApprove(address(_depositArgs.silo), 1);
    }

    function _borrow(BorrowArgs memory _borrowArgs) virtual internal {
        uint256 borrowAmount = _borrowArgs.flashloanAmountWithFee + _calculateLeverageFee(_borrowArgs.totalDeposit);
        _borrowArgs.silo.borrow(borrowAmount, _borrowArgs.receiver, _borrowArgs.receiver);
    }
}
