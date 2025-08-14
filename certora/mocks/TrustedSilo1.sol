// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {TrustedSilo0} from "./TrustedSilo0.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";



contract TrustedSilo1 is TrustedSilo0  {

    // In order to avoid duplicating the options and exploding the call graph, flashLoan is only on Silo0
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data) 
        external override
        returns (bool) {
            require(false);
            return false;
        }


}