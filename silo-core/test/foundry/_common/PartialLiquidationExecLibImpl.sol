// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {PartialLiquidationLib} from "silo-core/contracts/hooks/liquidation/lib/PartialLiquidationLib.sol";
import {PartialLiquidationExecLib} from "silo-core/contracts/hooks/liquidation/lib/PartialLiquidationExecLib.sol";

contract PartialLiquidationExecLibImpl {
    function liquidationPreview(
        SiloSolvencyLib.LtvData memory _ltvData,
        PartialLiquidationLib.LiquidationPreviewParams memory _params
    )
        external
        view
        returns (uint256 receiveCollateralAssets, uint256 repayDebtAssets, bytes4 customError)
    {
        return PartialLiquidationExecLib.liquidationPreview(_ltvData, _params);
    }
}
