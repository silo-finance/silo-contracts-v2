// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract ShareDebtToken0 is ShareDebtToken {

    
    function getTransferWithChecks() external view returns (bool) {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        return $.transferWithChecks;
    }
}
