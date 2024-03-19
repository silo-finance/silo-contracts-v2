// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloStdLib} from "silo-core/contracts/lib/SiloStdLib.sol";
import {PartialLiquidationLib} from "silo-core/contracts/liquidation/lib/PartialLiquidationLib.sol";
import {PartialLiquidationExecLib} from "silo-core/contracts/liquidation/lib/PartialLiquidationExecLib.sol";

contract PartialLiquidationExecLibImpl {
    function liquidationPreview(
        ISilo.LtvData memory _ltvData,
        PartialLiquidationLib.LiquidationPreviewParams memory _params
    )
        external
        view
        returns (uint256 receiveCollateralAssets, uint256 repayDebtAssets)
    {
        return PartialLiquidationExecLib.liquidationPreview(_ltvData, _params);
    }
}
