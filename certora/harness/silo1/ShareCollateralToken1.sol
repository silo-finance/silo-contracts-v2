// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShareCollateralToken} from "silo-core/contracts/utils/ShareCollateralToken.sol";

contract ShareCollateralToken1 is ShareCollateralToken {


    function getTransferWithChecks() external view returns (bool) {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        return $.transferWithChecks;
    }
}
