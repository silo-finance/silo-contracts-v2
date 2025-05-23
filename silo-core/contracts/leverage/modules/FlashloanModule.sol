// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;


import {ISiloLeverage} from "../../interfaces/ISiloLeverage.sol";
import {IERC3156FlashBorrower} from "../../interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../../interfaces/IERC3156FlashLender.sol";

abstract contract FlashloanModule is IERC3156FlashBorrower {
    // TODO transient
    ISiloLeverage.LeverageAction internal __action;
    address internal __flashloanTarget;

    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    function _executeFlashloan(ISiloLeverage.FlashArgs memory _flashArgs, bytes memory _data) internal virtual {
        require(IERC3156FlashLender(_flashArgs.flashloanTarget).flashLoan({
            _receiver: this,
            _token: _flashArgs.token,
            _amount: _flashArgs.amount,
            _data: _data
        }), ISiloLeverage.FlashloanFailed());
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
        require(__flashloanTarget == msg.sender, ISiloLeverage.InvalidFlashloanLender());

        // TODO: _initiator check might be redundant, because of how `__flashloanTarget` works, but atm I see no harm to check it
        require(_initiator == address(this), ISiloLeverage.InvalidInitiator());

        if (__action == ISiloLeverage.LeverageAction.Open) {
            _openLeverage(_borrowToken, _flashloanAmount, _flashloanFee, _data);
        } else if (__action == ISiloLeverage.LeverageAction.Close) {
            _closeLeverage(_borrowToken, _flashloanAmount, _flashloanFee, _data);
        } else revert ISiloLeverage.UnknownAction();

        // approval for repay flashloan
        _giveMaxAllowance(IERC20(_borrowToken), __flashloanTarget, _flashloanAmount + _flashloanFee);

        return _FLASHLOAN_CALLBACK;
    }

    function _giveMaxAllowance(IERC20 _asset, address _spender, uint256 _requiredAmount) internal;

    function _openLeverage(
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    ) internal virtual;

    function _closeLeverage(
        address _debtToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    ) internal virtual;
}
