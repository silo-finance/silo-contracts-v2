// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShareCollateralToken} from "silo-core/contracts/utils/ShareCollateralToken.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ShareTokenLib} from "silo-core/contracts/lib/ShareTokenLib.sol";
contract ShareProtectedCollateralToken1 is ShareCollateralToken {


    function getTransferWithChecks() external view returns (bool) {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        return $.transferWithChecks;
    }
}
