// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISilo, IERC3156FlashLender} from "../interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {ISiloLeverage} from "../interfaces/ISiloLeverage.sol";

import {ZeroExSwapModule} from "./modules/ZeroExSwapModule.sol";
import {RevenueModule} from "./modules/RevenueModule.sol";

// TODO nonReentrant
contract SiloLeverage is ISiloLeverage, ZeroExSwapModule, RevenueModule, IERC3156FlashBorrower {
    using SafeERC20 for IERC20;

    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");
    uint256 internal constant _DECIMALS = 1e18;
    uint256 internal constant _LEVERAGE_FEE_IN_DEBT_TOKEN = 1e18;

    uint256 internal constant _ACTION_OPEN_LEVERAGE = 1;
    uint256 internal constant _ACTION_CLOSE_LEVERAGE = 2;

    // TODO transient
    address internal _lock;
    uint256 internal _action;

    constructor (address _initialOwner) Ownable(_initialOwner) {}

    /// @inheritdoc ISiloLeverage
    function leverage(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        DepositArgs calldata _depositArgs,
        // TODO _borrowSilo is mostly optimisation, to not spend gas on figure out "other" silo,
        // but if you think it is worth, we can remove it from interface and resolve internally
        ISilo _borrowSilo
    ) external virtual returns (uint256 multiplier) {
        _lock = _flashArgs.flashDebtLender;
        _action = _ACTION_OPEN_LEVERAGE;

        bytes memory data = abi.encode(_swapArgs, _depositArgs, _borrowSilo);

        _borrowFlashloan(_flashArgs, data);

        multiplier = _flashArgs.amount * _DECIMALS / _depositArgs.amount;

        // transient lock will force design pattern, eg flashloan can not be module
        _lock = address(0);
        _action = 0;
        // TODO: does is worth to add check for delta balance + fee at the end?
    }

    function closeLeverage(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        CloseLeverageArgs calldata _closeLeverageArgs
    ) external virtual {
        _lock = _flashArgs.flashDebtLender;
        _action = _ACTION_CLOSE_LEVERAGE;

        bytes memory data = abi.encode(_swapArgs, _closeLeverageArgs);

        _repayFlashloan(_flashArgs, data);

        _lock = address(0);
        _action = 0;
    }

    function _borrowFlashloan(FlashArgs memory _flashArgs, bytes memory _data) internal virtual {
        require(IERC3156FlashLender(_flashArgs.flashDebtLender).flashLoan({
            _receiver: this,
            _token: _flashArgs.token,
            _amount: _flashArgs.amount,
            _data: _data
        }), FlashloanFailed());
    }

    function _repayFlashloan(FlashArgs memory _flashArgs, bytes memory _data) internal virtual {
        require(IERC3156FlashLender(_flashArgs.flashDebtLender).flashLoan({
            _receiver: this,
            _token: _flashArgs.token,
            _amount: _flashArgs.amount,
            _data: _data
        }), FlashloanFailed());
    }

    function onFlashLoan(
        address _initiator,
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        external
        returns (bytes32)
    {
        // this check prevents call `onFlashLoan` directly
        require(_lock == msg.sender, InvalidFlashloanLender());

        // TODO: _initiator check might be redundant, because of how `_lock` works, but atm I see no harm to check it
        require(_initiator == address(this), InvalidInitiator());

        if (_action == _ACTION_OPEN_LEVERAGE) _openLeverage(_borrowToken, _flashloanAmount, _flashloanFee, _data);
        else if (_action == _ACTION_CLOSE_LEVERAGE) _closeLeverage(_borrowToken, _flashloanAmount, _flashloanFee, _data);
        else revert UnknownAction();

        return _FLASHLOAN_CALLBACK;
    }

    function _openLeverage(
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
    {
        (
            SwapArgs memory swapArgs,
            DepositArgs memory depositArgs,
            ISilo borrowSilo
        ) = abi.decode(_data, (SwapArgs, DepositArgs, ISilo));

        uint256 amountOut = _fillQuote(swapArgs, _flashloanAmount);

        _deposit(depositArgs, amountOut, IERC20(swapArgs.buyToken));

        uint256 leverageFee = calculateLeverageFee(_flashloanAmount);

        borrowSilo.borrow({
            _assets: _flashloanAmount + _flashloanFee + leverageFee,
            _receiver: address(this),
            _borrower: depositArgs.receiver
        });

        // TODO we could cumulate fees and withdraw later, but it will not save much gas
        // and direct transfer allow us to keep leverage contract clean (not have any tokens)
        if (leverageFee != 0) IERC20(_borrowToken).safeTransfer(revenueReceiver, leverageFee);

        IERC20(_borrowToken).forceApprove(_lock, _flashloanAmount + _flashloanFee);
    }

    function _closeLeverage(
        address _debtToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
    {
        (
            SwapArgs memory swapArgs,
            CloseLeverageArgs memory closeArgs
        ) = abi.decode(_data, (SwapArgs, CloseLeverageArgs));

        IERC20(_debtToken).forceApprove(address(closeArgs.siloWithDebt), _flashloanAmount);
        closeArgs.siloWithDebt.repayShares(closeArgs.borrowerDebtShares, closeArgs.borrower);

        closeArgs.siloWithCollateral.redeem(closeArgs.collateralShares, address(this), closeArgs.borrower);

        uint256 amountOut = _fillQuote(swapArgs, _flashloanAmount);

        uint256 obligation = _flashloanAmount + _flashloanFee;
        require(amountOut >= obligation, SwapDidNotCoverObligations());

        uint256 change = amountOut - obligation;

        IERC20(_debtToken).safeTransfer(closeArgs.borrower, change);

        IERC20(_debtToken).forceApprove(_lock, obligation);
    }

    function _deposit(DepositArgs memory _depositArgs, uint256 _swapAmountOut, IERC20 _asset)
        internal
        virtual
        returns (uint256 totalDeposit)
    {
        _asset.safeTransferFrom(_depositArgs.receiver, address(this), _depositArgs.amount);

        totalDeposit = _depositArgs.amount + _swapAmountOut;

        _asset.forceApprove(address(_depositArgs.silo), totalDeposit);
        _depositArgs.silo.deposit(totalDeposit, _depositArgs.receiver, _depositArgs.collateralType);
        _asset.forceApprove(address(_depositArgs.silo), 1);
    }
}
