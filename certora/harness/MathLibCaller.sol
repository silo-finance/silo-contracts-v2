// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

contract MathLibCaller {

    function liquidity(uint256 _collateralAssets, uint256 _debtAssets) external pure returns (uint256 liquidAssets) {
        return SiloMathLib.liquidity(_collateralAssets, _debtAssets);
    }
    function getCollateralAmountsWithInterest(
        uint256 _collateralAssets, uint256 _debtAssets, uint256 _rcomp,
        uint256 _daoFee, uint256 _deployerFee)
        external pure returns (uint256 collateralAssetsWithInterest, uint256 debtAssetsWithInterest,
            uint256 daoAndDeployerRevenue, uint256 accruedInterest)
    {
        (collateralAssetsWithInterest, debtAssetsWithInterest, daoAndDeployerRevenue, accruedInterest)
            = SiloMathLib.getCollateralAmountsWithInterest(_collateralAssets, _debtAssets, _rcomp, _daoFee, _deployerFee);
    }

    function getDebtAmountsWithInterest(uint256 _totalDebtAssets, uint256 _rcomp)
        external pure returns (uint256 debtAssetsWithInterest, uint256 accruedInterest)
    {
        (debtAssetsWithInterest, accruedInterest) = SiloMathLib.getDebtAmountsWithInterest(_totalDebtAssets, _rcomp);
    }

    function calculateUtilization(uint256 _dp, uint256 _collateralAssets, uint256 _debtAssets)
        external pure returns (uint256 utilization)
    {
        return SiloMathLib.calculateUtilization(_dp, _collateralAssets, _debtAssets);
    }

}
