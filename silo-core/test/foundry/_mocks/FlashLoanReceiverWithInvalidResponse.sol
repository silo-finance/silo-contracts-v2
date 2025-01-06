// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";

contract FlashLoanReceiverWithInvalidResponse is IERC3156FlashBorrower {
    function onFlashLoan(address, address, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes32)
    {
        return bytes32(0); // invalid flashloan callback response
    }
}
