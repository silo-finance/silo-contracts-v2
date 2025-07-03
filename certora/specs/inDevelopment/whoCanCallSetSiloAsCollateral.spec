import "../setup/CompleteSiloSetup.spec";
import "../silo/unresolved.spec";
import "../simplifications/SiloMathLib_SAFE.spec";

ghost bool wasCalled_setThisSiloAsCollateralSilo;
ghost bool wasCalled_setOtherSiloAsCollateralSilo;

function setThisSiloAsCollateralSilo_CVL(address user) returns bool
{
    wasCalled_setThisSiloAsCollateralSilo = true;
    return true;
}

function setOtherSiloAsCollateralSilo_CVL(address user) returns bool
{
    wasCalled_setOtherSiloAsCollateralSilo = true;
    return true;
}

methods {
    function siloConfig.setThisSiloAsCollateralSilo(address _borrower) external returns bool => 
        setThisSiloAsCollateralSilo_CVL(_borrower);

    function siloConfig.setOtherSiloAsCollateralSilo(address _borrower) external returns bool => 
        setOtherSiloAsCollateralSilo_CVL(_borrower);
}

definition canCall_setThisSiloAsCollateralSilo(method f) returns bool =
    f.selector == sig:borrowSameAsset(uint256,address,address).selector ||
    //f.selector == sig:leverageSameAsset(uint256,address).selector ||
    f.selector == sig:switchCollateralToThisSilo().selector;

definition canCall_setOtherSiloAsCollateralSilo(method f) returns bool =
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector;
    

// setThisSiloAsCollateralSilo() should be called only by: borrowSameAsset, switchCollateralToThisSilo
rule whoCalls_setThisSiloAsCollateralSilo(env e, method f) filtered { f -> !filterOutInInvariants(f) }
{
    SafeAssumptionsEnv_withInvariants(e);
    require wasCalled_setThisSiloAsCollateralSilo == false;
    calldataarg args;
    f(e, args);
    assert wasCalled_setThisSiloAsCollateralSilo => canCall_setThisSiloAsCollateralSilo(f);
}

// setOtherSiloAsCollateralSilo() should be called only by: borrow, borrowShares
rule whoCalls_setOtherSiloAsCollateralSilo(env e, method f) filtered { f -> !filterOutInInvariants(f) }
{
    SafeAssumptionsEnv_withInvariants(e);
    require wasCalled_setOtherSiloAsCollateralSilo == false;
    calldataarg args;
    f(e, args);
    assert wasCalled_setOtherSiloAsCollateralSilo => canCall_setOtherSiloAsCollateralSilo(f);
}