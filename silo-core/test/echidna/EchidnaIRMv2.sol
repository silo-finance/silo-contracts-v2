// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {InterestRateModelV2Factory} from "silo-core/contracts/interestRateModel/InterestRateModelV2Factory.sol";
import {InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2Config.sol";
import {PropertiesAsserts} from "properties/util/PropertiesHelper.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

/*
./silo-core/scripts/echidnaBefore.sh
SOLC_VERSION=0.8.24 echidna silo-core/test/echidna/EchidnaIRMv2.sol --contract EchidnaIRMv2 --config silo-core/test/echidna/irm.yaml --workers 10
*/
contract EchidnaIRMv2 is PropertiesAsserts {
    using SafeCast for int256;
    using SafeCast for uint256;

    InterestRateModelV2 IRMv2;

    uint256 internal constant _DP = 1e18;

    enum AccrueInterestInMemory {
        No,
        Yes
    }

    enum OracleType {
        Solvency,
        MaxLtv
    }

    enum AssetType {
        Protected, // default
        Collateral,
        Debt
    }

    struct Assets {
        uint256 assets;
    }

    /// @param assets map of assets
    struct SiloData {
        uint192 daoAndDeployerRevenue;
        uint64 interestRateTimestamp;
    }

    struct UtilizationData {
        /// @dev COLLATERAL: Amount of asset token that has been deposited to Silo plus interest earned by depositors.
        /// It also includes token amount that has been borrowed.
        uint256 collateralAssets;
        /// @dev DEBT: Amount of asset token that has been borrowed plus accrued interest.
        uint256 debtAssets;
        /// @dev timestamp of the last interest accrual
        uint64 interestRateTimestamp;
    }

    uint256 totalCollateral;
    uint256 totalDebt;
    uint64 interestRateTimestamp;

    constructor() {
        InterestRateModelV2Factory factory = new InterestRateModelV2Factory();

        IInterestRateModelV2.Config memory _config = IInterestRateModelV2.Config({
            uopt: 500000000000000000,
            ucrit: 900000000000000000,
            ulow: 300000000000000000,
            ki: 146805,
            kcrit: 317097919838,
            klow: 105699306613,
            klin: 4439370878,
            beta: 69444444444444,
            ri: 0,
            Tcrit: 0
        });

        (, IInterestRateModelV2 createdIRM) = factory.create(_config, bytes32(0));

        IRMv2 = InterestRateModelV2(address(createdIRM));
    }

    /* ================================================================
                Setter functions to simplify setup
       ================================================================ */

    function setUtilizationData(uint256 _totalCollateral, uint256 _totalDebt) public {
        totalCollateral = _totalCollateral;
        totalDebt = _totalDebt;
        interestRateTimestamp = uint40(block.timestamp);
    }

    function utilizationData() external view virtual returns (UtilizationData memory) {
        return UtilizationData({
            collateralAssets: totalCollateral,
            debtAssets: totalDebt,
            interestRateTimestamp: interestRateTimestamp
        });
    }

    function _fetchConfigAndUtilization() internal view returns (IInterestRateModelV2.Config memory config, int256 utilization) {
        config = IRMv2.getConfig(address(this));
        utilization = SiloMathLib.calculateUtilization(_DP, totalCollateral, totalDebt).toInt256();
    }

    /* ================================================================
                                Properties
       ================================================================ */
    function interestRateCannotBeLargerThanMax() public {
        uint256 rcur = IRMv2.getCurrentInterestRate(address(this), block.timestamp);
        assertLte(rcur, 1e20, "Interest rate is higher than 1e20");
    }

    function compInterestRateCannotBeLargerThanMax() public {
        int256 _t = (block.timestamp - interestRateTimestamp).toInt256();
        uint256 cap = 3170979198376 * _t.toUint256();
        uint256 rcomp = IRMv2.getCompoundInterestRate(address(this), block.timestamp);
        assertLte(rcomp, cap, "Compound interest rate is higher than maximum");
    }

    function compInterest_criticalUtilizationGrowth() public {
        require(block.timestamp > interestRateTimestamp);

        (IInterestRateModelV2.Config memory config, int256 utilization) = _fetchConfigAndUtilization();
        uint256 rcomp;
        int256 ri;
        int256 Tcrit;
        
        if (utilization > config.ucrit && config.beta != 0) {
            (rcomp, ri, Tcrit) = IRMv2.calculateCompoundInterestRate(config, totalCollateral, totalDebt, interestRateTimestamp, block.timestamp);
            require(Tcrit != 0, "Tcrit overflow");
            assertGt(Tcrit, config.Tcrit, "Tcrit does not grow");
        }
    }

    function compInterest_optimalUtilizationGrowth() public {
        require(block.timestamp > interestRateTimestamp);

        (IInterestRateModelV2.Config memory config, int256 utilization) = _fetchConfigAndUtilization();
        uint256 rcomp;
        int256 ri;
        int256 Tcrit;
        
        if (utilization > config.uopt && config.beta != 0) {
            (rcomp, ri, Tcrit) = IRMv2.calculateCompoundInterestRate(config, totalCollateral, totalDebt, interestRateTimestamp, block.timestamp);
            assertGte(ri, config.ri, "Tcrit does not grow");
        }
    }

    function checkOperatorPrecedance(int256 kcrit, int256 Tcrit, int256 beta, int256 T, int256 u, int256 ucrit) public {
        int256 DP = 1e18;
        Tcrit = clampGte(Tcrit, 0);
        kcrit = clampGte(kcrit, 0);
        ucrit = clampGte(ucrit, 0);

        int256 a = kcrit * (DP + Tcrit + beta * T) / DP;
        int256 b = (u - ucrit);
        int256 expected = a * b / DP;
        int256 result = kcrit * (DP + Tcrit + beta * T) / DP * (u - ucrit) / DP;

        assertEq(result, expected, "Incorrect operator precedence");
    }

}
