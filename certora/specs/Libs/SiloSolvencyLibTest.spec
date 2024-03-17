import "../_simplifications/SiloSolvencyLib.spec";
import "../_simplifications/priceOracle.spec";
import "../silo/_common/CommonSummarizations.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

using SiloMock0 as silo0;
using SiloMock1 as silo1;

use builtin rule sanity;

methods {
    function _.balanceOf(address borrower) external => generalBalance(calledContract, borrower) expect uint256;
    function _.totalSupply() external => generalTotalSupply(calledContract) expect uint256;
    function _.getCollateralAndDebtAssets() external => DISPATCHER(true);
    function _.getCollateralAndProtectedAssets() external => DISPATCHER(true);
    function _.total(ISiloMock.AssetType) external => DISPATCHER(true);
    function silo0.getSiloDataInterestRateTimestamp() external returns (uint256) envfree;
    function silo1.getSiloDataInterestRateTimestamp() external returns (uint256) envfree;
}

ghost generalBalance(address, address) returns uint256 {
    axiom forall address token. forall address account. 
        generalBalance(token,account) <= generalTotalSupply(token);
    axiom forall address token. 
        forall address account1. forall address account2.
            account1 != account2 =>
            generalBalance(token,account1) + generalBalance(token,account2) <= 
            to_mathint(generalTotalSupply(token));
}

ghost generalTotalSupply(address) returns uint256;

