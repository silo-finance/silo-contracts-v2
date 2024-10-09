// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Interfaces
import {
    IERC3156FlashBorrower
} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";

// Test Contracts
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {PropertiesAsserts} from "../utils/PropertiesAsserts.sol";

contract MockFlashLoanReceiver is IERC3156FlashBorrower, PropertiesAsserts {
    constructor() {}

    function onFlashLoan(
        address _initiator,
        address _token,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _data
    ) external returns (bytes32) {
        (uint256 amountToRepay, address sender) = abi.decode(
            _data,
            (uint256, address)
        );

        assertEq(_initiator, sender, "onFlashLoan: wrong initiator"); // TODO add this as a property
        _setAmountBack(_token, amountToRepay, _amount + _fee);
    }

    function _setAmountBack(
        address _token,
        uint256 _amountToRepay,
        uint256 _amountWithFee
    ) internal {
        if (_amountToRepay > _amountWithFee) {
            TestERC20(_token).mint(
                address(this),
                _amountToRepay - _amountWithFee
            );
        } else if (_amountToRepay < _amountWithFee) {
            TestERC20(_token).burn(msg.sender, _amountWithFee - _amountToRepay);
        }
    }
}
