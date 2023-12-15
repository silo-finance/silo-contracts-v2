// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract FlasLoanTakerMock is IERC3156FlashBorrower {
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    function takeFlashLoan(ISilo _silo, address _token, uint256 _amount) external {
        bytes memory data;

        _silo.flashLoan(IERC3156FlashBorrower(address(this)), _token, _amount, data);
    }

     function onFlashLoan(address, address _token, uint256 _amount, uint256 _fee, bytes calldata)
        external
        returns (bytes32)
    {
        IERC20(_token).approve(msg.sender, _amount + _fee);

        return _FLASHLOAN_CALLBACK;
    }
}
