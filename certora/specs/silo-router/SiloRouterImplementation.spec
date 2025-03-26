import "SiloInCVL.spec";

rule doesntAlwaysRevert(method f, env e)
{
    calldataarg args;
    f(e, args);
    satisfy true;
}

rule depositWithdrawInverse(env e)
{
    require originalCaller == e.msg.sender;
    require e.msg.value == 0;
    uint256 _assets; ISilo.CollateralType _collateralType;
    address silo;

    storage init = lastStorage;
    deposit(e, silo, _assets, _collateralType);
    withdraw(e, silo, _assets, e.msg.sender, _collateralType);
    storage after = lastStorage;
    assert init == after;
    satisfy true;
}

rule borrowRepayInverse(env e)
{
    require e.msg.value == 0;
    uint256 _assets; address silo; address receiver;

    storage init = lastStorage;
    borrow(e, silo, _assets, receiver);
    repay(e, silo,_assets);
    storage after = lastStorage;
    assert init == after;
    satisfy true;
}

rule depositDoesntAffectOthers(env e, address other)
{
    require originalCaller == e.msg.sender;
    require e.msg.value == 0;
    require other != e.msg.sender;
    uint256 _assets; ISilo.CollateralType _collateralType;
    address silo;

    uint256 depositedCollateralOtherBefore = depositedCollateral[other];
    uint256 depositedProtCollateralOtherBefore = depositedProtCollateral[other];
    uint256 debtSharesHoldingOtherBefore = debtSharesHolding[other];
    uint256 receivedSharesOtherBefore = receivedShares[other];
    uint256 receivedProtSharesOtherBefore = receivedProtShares[other];

    deposit(e, silo, _assets, _collateralType);

    uint256 depositedCollateralOtherAfter = depositedCollateral[other];
    uint256 depositedProtCollateralOtherAfter = depositedProtCollateral[other];
    uint256 debtSharesHoldingOtherAfter = debtSharesHolding[other];
    uint256 receivedSharesOtherAfter = receivedShares[other];
    uint256 receivedProtSharesOtherAfter = receivedProtShares[other]; 

    assert depositedCollateralOtherBefore == depositedCollateralOtherAfter &&
        depositedProtCollateralOtherBefore == depositedProtCollateralOtherAfter &&
        debtSharesHoldingOtherBefore == debtSharesHoldingOtherAfter && 
        receivedSharesOtherBefore == receivedSharesOtherAfter &&
        receivedProtSharesOtherBefore == receivedProtSharesOtherAfter;
}

rule withdrawDoesntAffectOthers(env e, address other)
{
    require originalCaller == e.msg.sender;
    require e.msg.value == 0;
    address receiver;
    require other != receiver;
    require other != e.msg.sender;
    uint256 _assets; ISilo.CollateralType _collateralType;
    address silo;

    uint256 depositedCollateralOtherBefore = depositedCollateral[other];
    uint256 depositedProtCollateralOtherBefore = depositedProtCollateral[other];
    uint256 debtSharesHoldingOtherBefore = debtSharesHolding[other];
    uint256 receivedSharesOtherBefore = receivedShares[other];
    uint256 receivedProtSharesOtherBefore = receivedProtShares[other];

    withdraw(e, silo, _assets, receiver, _collateralType);

    uint256 depositedCollateralOtherAfter = depositedCollateral[other];
    uint256 depositedProtCollateralOtherAfter = depositedProtCollateral[other];
    uint256 debtSharesHoldingOtherAfter = debtSharesHolding[other];
    uint256 receivedSharesOtherAfter = receivedShares[other];
    uint256 receivedProtSharesOtherAfter = receivedProtShares[other]; 

    assert depositedCollateralOtherBefore == depositedCollateralOtherAfter &&
        depositedProtCollateralOtherBefore == depositedProtCollateralOtherAfter &&
        debtSharesHoldingOtherBefore == debtSharesHoldingOtherAfter && 
        receivedSharesOtherBefore == receivedSharesOtherAfter &&
        receivedProtSharesOtherBefore == receivedProtSharesOtherAfter;
}

rule borrowDoesntAffectOthers(env e, address other)
{
    require originalCaller == e.msg.sender;
    require e.msg.value == 0;
    address receiver;
    require other != receiver;
    require other != e.msg.sender;
    uint256 _assets; address silo;

    uint256 depositedCollateralOtherBefore = depositedCollateral[other];
    uint256 depositedProtCollateralOtherBefore = depositedProtCollateral[other];
    uint256 debtSharesHoldingOtherBefore = debtSharesHolding[other];
    uint256 receivedSharesOtherBefore = receivedShares[other];
    uint256 receivedProtSharesOtherBefore = receivedProtShares[other];

    borrow(e, silo, _assets, receiver);

    uint256 depositedCollateralOtherAfter = depositedCollateral[other];
    uint256 depositedProtCollateralOtherAfter = depositedProtCollateral[other];
    uint256 debtSharesHoldingOtherAfter = debtSharesHolding[other];
    uint256 receivedSharesOtherAfter = receivedShares[other];
    uint256 receivedProtSharesOtherAfter = receivedProtShares[other]; 

    assert depositedCollateralOtherBefore == depositedCollateralOtherAfter &&
        depositedProtCollateralOtherBefore == depositedProtCollateralOtherAfter &&
        debtSharesHoldingOtherBefore == debtSharesHoldingOtherAfter && 
        receivedSharesOtherBefore == receivedSharesOtherAfter &&
        receivedProtSharesOtherBefore == receivedProtSharesOtherAfter;
}

rule repayDoesntAffectOthers(env e, address other)
{
    require originalCaller == e.msg.sender;
    require e.msg.value == 0;
    address borrower;
    require other != borrower;
    require other != e.msg.sender;
    uint256 _assets; address silo;

    uint256 depositedCollateralOtherBefore = depositedCollateral[other];
    uint256 depositedProtCollateralOtherBefore = depositedProtCollateral[other];
    uint256 debtSharesHoldingOtherBefore = debtSharesHolding[other];
    uint256 receivedSharesOtherBefore = receivedShares[other];
    uint256 receivedProtSharesOtherBefore = receivedProtShares[other];

    repay(e, silo,_assets /*, borrower */);

    uint256 depositedCollateralOtherAfter = depositedCollateral[other];
    uint256 depositedProtCollateralOtherAfter = depositedProtCollateral[other];
    uint256 debtSharesHoldingOtherAfter = debtSharesHolding[other];
    uint256 receivedSharesOtherAfter = receivedShares[other];
    uint256 receivedProtSharesOtherAfter = receivedProtShares[other]; 

    assert depositedCollateralOtherBefore == depositedCollateralOtherAfter &&
        depositedProtCollateralOtherBefore == depositedProtCollateralOtherAfter &&
        debtSharesHoldingOtherBefore == debtSharesHoldingOtherAfter && 
        receivedSharesOtherBefore == receivedSharesOtherAfter &&
        receivedProtSharesOtherBefore == receivedProtSharesOtherAfter;
}