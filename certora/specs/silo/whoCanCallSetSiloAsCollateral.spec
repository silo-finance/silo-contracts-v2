import "../previousAudits/CompleteSiloSetup.spec";

ghost bool wasCalled_setThisSiloAsCollateralSilo;
ghost bool wasCalled_setOtherSiloAsCollateralSilo;

function setThisSiloAsCollateralSilo_CVL(address user)
{
    wasCalled_setThisSiloAsCollateralSilo = true;
}

function setOtherSiloAsCollateralSilo_CVL(address user)
{
    wasCalled_setOtherSiloAsCollateralSilo = true;
}

methods {

    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external => NONDET;
    function _.beforeQuote(address) external => NONDET DELETE;

    function siloConfig.setThisSiloAsCollateralSilo(address _borrower) external => 
        setThisSiloAsCollateralSilo_CVL(_borrower);

    function siloConfig.setOtherSiloAsCollateralSilo(address _borrower) external => 
        setOtherSiloAsCollateralSilo_CVL(_borrower);
}

definition canCall_setThisSiloAsCollateralSilo(method f) returns bool =
    f.selector == sig:borrowSameAsset(uint256,address,address).selector ||
    //f.selector == sig:leverageSameAsset(uint256,address).selector ||
    f.selector == sig:switchCollateralToThisSilo().selector;

definition canCall_setOtherSiloAsCollateralSilo(method f) returns bool =
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector;
    

// setThisSiloAsCollateralSilo() should be called only by: borrowSameAsset, leverageSameAsset, switchCollateralToThisSilo
rule whoCalls_setThisSiloAsCollateralSilo(env e, method f)
{
    require wasCalled_setThisSiloAsCollateralSilo == false;
    calldataarg args;
    f(e, args);
    assert wasCalled_setThisSiloAsCollateralSilo => canCall_setThisSiloAsCollateralSilo(f);
}

// setOtherSiloAsCollateralSilo() should be called only by: borrow, borrowShares
rule whoCalls_setOtherSiloAsCollateralSilo(env e, method f)
{
    require wasCalled_setOtherSiloAsCollateralSilo == false;
    calldataarg args;
    f(e, args);
    assert wasCalled_setOtherSiloAsCollateralSilo => canCall_setOtherSiloAsCollateralSilo(f);
}