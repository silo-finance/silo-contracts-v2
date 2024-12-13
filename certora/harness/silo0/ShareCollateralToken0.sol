// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShareCollateralToken} from "silo-core/contracts/utils/ShareCollateralToken.sol";
//import {ISiloConfig} from "./interfaces/ISiloConfig.sol";

contract ShareCollateralToken0 is ShareCollateralToken {


    function getTransferWithChecks() external view returns (bool) {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        return $.transferWithChecks;
    }

}
