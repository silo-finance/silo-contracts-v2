import "../silo/_common/CommonSummarizations.spec";
import "../_simplifications/Oracle_quote_one.spec";
import "../_simplifications/Silo_isSolvent_ghost.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

using Silo0 as silo0;
using Silo1 as silo1;

methods {
    // SiloConfig.sol
    function _.getConfigs(address, address, uint256) external => DISPATCHER(true);
    
    // Silo.sol
    function _.config() external => DISPATCHER(true);
    function _.getCollateralAndProtectedAssets() external => DISPATCHER(true);
    function _.getCollateralAndDebtAssets() external => DISPATCHER(true);

    //  ShareToken.sol
    function _.balanceOfAndTotalSupply(address) external => DISPATCHER(true);

    function silo0.getSiloDataInterestRateTimestamp() external returns (uint256) envfree;
    function silo1.getSiloDataInterestRateTimestamp() external returns (uint256) envfree;
}

rule sanity(env e, method f) {
    calldataarg args;
    f(e, args);
    satisfy true;
}