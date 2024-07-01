// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {PartialLiquidationLib} from "silo-core/contracts/utils/hook-receivers/liquidation/lib/PartialLiquidationLib.sol";
import {PartialLiquidationExecLib} from "silo-core/contracts/utils/hook-receivers/liquidation/lib/PartialLiquidationExecLib.sol";

contract PartialLiquidationExecLibImpl {
    function liquidationPreview(
        SiloSolvencyLib.LtvData memory _ltvData,
        PartialLiquidationLib.LiquidationPreviewParams memory _params
    )
        external
        view
        returns (uint256 receiveCollateralAssets, uint256 repayDebtAssets)
    {
        return PartialLiquidationExecLib.liquidationPreview(_ltvData, _params);
    }
}
