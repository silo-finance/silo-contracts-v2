// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

contract GetExactLiquidationAmountsTestData {
    uint256 constant SHARES_OFFSET = SiloMathLib._DECIMALS_OFFSET_POW;

    struct Input {
        address user;
        uint256 debtToCover;
        uint256 liquidationFee;
        bool selfLiquidation;
    }

    struct Mocks {
        uint256 protectedUserSharesBalanceOf;
        uint256 protectedSharesTotalSupply;
        uint256 siloTotalProtectedAssets;

        uint256 collateralUserSharesBalanceOf;
        uint256 collateralSharesTotalSupply;
        uint256 siloTotalCollateralAssets;

        uint256 debtUserSharesBalanceOf;
        uint256 debtSharesTotalSupply;
        uint256 siloTotalDebtAssets;
    }

    struct Output {
        uint256 fromCollateral;
        uint256 fromProtected;
        uint256 repayDebtAssets;
    }

    struct GELAData {
        string name;
        Input input;
        Mocks mocks;
        Output output;
    }

    function getData() external pure returns (GELAData[] memory data) {
        data = new GELAData[](8);
        uint256 i;

        data[i].name = "all zeros => zero output";
        data[i].input.user = address(1);
        data[i].input.debtToCover = 1e18;

        i++;
        data[i].name = "expect zero output if user has no debt";
        data[i].input.user = address(1);
        data[i].input.debtToCover = 1e18;

        data[i].mocks.protectedUserSharesBalanceOf = 1e18 * SHARES_OFFSET;
        data[i].mocks.protectedSharesTotalSupply = 10e18 * SHARES_OFFSET;
        data[i].mocks.siloTotalProtectedAssets = 10e18;

        data[i].mocks.collateralUserSharesBalanceOf = 1e18 * SHARES_OFFSET;
        data[i].mocks.collateralSharesTotalSupply = 10e18 * SHARES_OFFSET;
        data[i].mocks.siloTotalCollateralAssets = 10e18;

        data[i].mocks.debtUserSharesBalanceOf = 1e18 * SHARES_OFFSET;
        data[i].mocks.debtSharesTotalSupply = 10e18 * SHARES_OFFSET;
        data[i].mocks.siloTotalDebtAssets = 10e18;

        i++;
        data[i].name = "expect zero when user solvent, protected collateral";
        data[i].input.user = address(1);
        data[i].input.debtToCover = 0.5e18;

        data[i].mocks.protectedUserSharesBalanceOf = 1e18 * SHARES_OFFSET;
        data[i].mocks.protectedSharesTotalSupply = 10e18 * SHARES_OFFSET;
        data[i].mocks.siloTotalProtectedAssets = 10e18;

        data[i].mocks.debtUserSharesBalanceOf = 0.79e18 * SHARES_OFFSET;
        data[i].mocks.debtSharesTotalSupply = 10e18 * SHARES_OFFSET;
        data[i].mocks.siloTotalDebtAssets = 10e18;

        i++;
        data[i] = _clone(data[i-1]);
        data[i].name = "expect zero when user solvent, protected + collateral";

        data[i].mocks.collateralUserSharesBalanceOf = 1e18 * SHARES_OFFSET;
        data[i].mocks.collateralSharesTotalSupply = 10e18 * SHARES_OFFSET;
        data[i].mocks.siloTotalCollateralAssets = 10e18;

        data[i].mocks.debtUserSharesBalanceOf = 1.59e18 * SHARES_OFFSET;

        i++;
        data[i] = _clone(data[i-1]);
        data[i].name = "with above, expect NON zero if user self liquidating, Cv=2, Dv=1.59, ltv=0.795";
        data[i].input.selfLiquidation = true;

        data[i].output.fromProtected = 0.5e18;
        data[i].output.fromCollateral = 0;
        data[i].output.repayDebtAssets = 0.5e18;

        i++;
        data[i] = _clone(data[i-1]);
        data[i].name = "as above, same result because we ignoring on self-liquidation fee";
        data[i].input.liquidationFee = 0.2e18;

        data[i].output.fromProtected = data[i - 1].output.fromProtected;
        data[i].output.fromCollateral = 0;
        data[i].output.repayDebtAssets = data[i - 1].output.repayDebtAssets;

        i++;
        data[i] = _clone(data[i-1]);
        data[i].name = "with above, self-liquidate too much";
        data[i].input.debtToCover = 99999e18;
        data[i].input.selfLiquidation = true;

        // on self liquidation, when we repay all, we receive all collateral back
        data[i].output.fromProtected = 1e18;
        data[i].output.fromCollateral = 1e18;
        data[i].output.repayDebtAssets = 1.59e18;
    }

    function _clone(GELAData memory _src) private pure returns (GELAData memory dst) {
        dst.input.user = address(1);
        dst.input.debtToCover = _src.input.debtToCover;
        dst.input.liquidationFee = _src.input.liquidationFee;
        dst.input.selfLiquidation = _src.input.selfLiquidation;

        dst.mocks.protectedUserSharesBalanceOf = _src.mocks.protectedUserSharesBalanceOf;
        dst.mocks.protectedSharesTotalSupply = _src.mocks.protectedSharesTotalSupply;
        dst.mocks.siloTotalProtectedAssets = _src.mocks.siloTotalProtectedAssets;

        dst.mocks.collateralUserSharesBalanceOf = _src.mocks.collateralUserSharesBalanceOf;
        dst.mocks.collateralSharesTotalSupply = _src.mocks.collateralSharesTotalSupply;
        dst.mocks.siloTotalCollateralAssets = _src.mocks.siloTotalCollateralAssets;

        dst.mocks.debtUserSharesBalanceOf = _src.mocks.debtUserSharesBalanceOf;
        dst.mocks.debtSharesTotalSupply = _src.mocks.debtSharesTotalSupply;
        dst.mocks.siloTotalDebtAssets = _src.mocks.siloTotalDebtAssets;
    }
}
