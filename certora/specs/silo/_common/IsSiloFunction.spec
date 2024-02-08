import "../_common/SiloFunctionSelector.spec";

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
