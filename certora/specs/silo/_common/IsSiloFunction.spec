import "./SiloFunctionSelector.spec";

function isDeposit(method f) returns bool {
    return f.selector == depositSig() || f.selector == depositWithTypeSig();
}

function isMint(method f) returns bool {
    return f.selector == mintSig() || f.selector == mintWithTypeSig();
}

function fnAllowedToCallAccrueInterest(method f) returns bool {
    return accrueInterestSig() == f.selector ||
            depositSig() == f.selector ||
            depositWithTypeSig() == f.selector ||
            withdrawSig() == f.selector ||
            withdrawWithTypeSig() == f.selector ||
            mintSig() == f.selector ||
            mintWithTypeSig() == f.selector ||
            liquidationCallSig() == f.selector ||
            transitionCollateralSig() == f.selector ||
            redeemSig() == f.selector ||
            repaySig() == f.selector ||
            repaySharesSig() == f.selector;
}

function fnAllowedToDecreaseShareDebtTotalSupply(method f) returns bool {
    return f.selector == repaySig() ||
        f.selector == repaySharesSig() ||
        f.selector == liquidationCallSig();
}

function fnAllowedToIncreaseShareDebtTotalSupply(method f) returns bool {
    return f.selector == borrowSig() ||
        f.selector == borrowSharesSig() ||
        f.selector == leverageSig();
}

function fnAllowedToDecreaseShareProtectedTotalSupply(method f) returns bool {
    return f.selector == withdrawWithTypeSig() ||
        f.selector == redeemWithTypeSig() ||
        f.selector == liquidationCallSig() ||
        f.selector == withdrawCollateralToLiquidatorSig() ||
        f.selector == transitionCollateralSig();
}

function fnAllowedToIncreaseShareProtectedTotalSupply(method f) returns bool {
    return f.selector == depositSig() ||
        f.selector == depositWithTypeSig() ||
        f.selector == mintSig() ||
        f.selector == mintWithTypeSig() ||
        f.selector == transitionCollateralSig();
}

function fnAllowedToIncreaseShareCollateralTotalSupply(method f) returns bool {
    return fnAllowedToIncreaseShareProtectedTotalSupply(f); // the same as for share protected collateral token
}

function fnAllowedToDecreaseShareCollateralTotalSupply(method f) returns bool {
    return fnAllowedToDecreaseShareProtectedTotalSupply(f) || f.selector == redeemSig() || f.selector == withdrawSig();
}

function fnAllowedToChangeCollateralBalanceWithoutTotalAssets(method f) returns bool {
    return f.selector == transferSig() || f.selector == transferFromSig();
}