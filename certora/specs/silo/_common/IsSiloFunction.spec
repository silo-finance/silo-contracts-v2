import "../_common/SiloFunctionSelector.spec";

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
            transitionCollateralSig() == f.selector ||
            redeemSig() == f.selector ||
            repaySig() == f.selector ||
            repaySharesSig() == f.selector;
}

function fnAllowedToDecreaseShareDebtTotalSupply(method f) returns bool {
    return f.selector == repaySig() ||
        f.selector == repaySharesSig();
}

function fnAllowedToIncreaseShareDebtTotalSupply(method f) returns bool {
    return f.selector == borrowSig() ||
        f.selector == borrowSharesSig() ||
        f.selector == leverageSig();
}

function fnAllowedToDecreaseShareProtectedTotalSupply(method f) returns bool {
    return f.selector == withdrawSig() ||
        f.selector == withdrawWithTypeSig() ||
        f.selector == withdrawWithTypeSig() ||
        f.selector == redeemSig() ||
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

function fnAllowedToChangeCollateralBalanceWithoutTotalAssets(method f) returns bool {
    return f.selector == transferSig() || f.selector == transferFromSig();
}
