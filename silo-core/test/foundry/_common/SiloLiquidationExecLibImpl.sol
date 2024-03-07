// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {SiloLiquidationLib} from "silo-core/contracts/lib/SiloLiquidationLib.sol";
import {SiloLiquidationExecLib} from "silo-core/contracts/lib/SiloLiquidationExecLib.sol";

contract SiloLiquidationExecLibImpl {
    function liquidationPreview(
        SiloSolvencyLib.LtvData memory _ltvData,
        SiloLiquidationLib.LiquidationPreviewParams memory _params
    )
        external
        view
        returns (uint256 receiveCollateralAssets, uint256 repayDebtAssets)
    {
        return SiloLiquidationExecLib.liquidationPreview(_ltvData, _params);
    }
}
