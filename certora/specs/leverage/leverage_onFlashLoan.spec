
/***
Verification of onFlashLoan() function by summarizing the function 
To run this spec file:
certoraRun certora/config/silo/leverage_onFlashLoan.conf 
results:https://prover.certora.com/output/40726/b781ebc4e8dd4625befda44aef45c3d6/?anonymousKey=b2d48d6ff66d30dc474092a6234b41de07fe83b9

mutation run: https://mutation-testing.certora.com/?id=85347f3e-828b-4b09-90d9-162f4ff97c46&anonymousKey=a08f113a-0cde-4af8-b02d-de6600d7a608 
on mutation in certora/mutates/LeverageUsing* and more 

**/
import "leverage_base.spec";

methods {
    //call back to leverage
    function _.onFlashLoan(
        address, address _borrowToken, uint256 _flashloanAmount, uint256 _flashloanFee ,bytes _data) external with (env e)
            => onFlashLoanCalled(e, _borrowToken, _flashloanAmount) expect (bytes32) ALL;

    unresolved external in GeneralSwapModule.fillQuote(IGeneralSwapModule.SwapArgs memory, uint256) => DISPATCH [
        LeverageUsingSiloFlashloanWithGeneralSwap.onFlashLoan(address,address,uint256,uint256,bytes), 
    ] default NONDET;
    

}
    
    
ghost address transientMsgSender;
ghost bool flashLoanWasCalled;
ghost address msgSenderToOnFlashLoan;

ghost onFlashLoanResult(address, address, uint256 ) returns bytes32;
function onFlashLoanCalled(env e, 
        address _borrowToken,
        uint256 _flashloanAmount) returns (bytes32) {
    
    flashLoanWasCalled = true;
    transientMsgSender = currentContract._txMsgSender;
    msgSenderToOnFlashLoan = e.msg.sender;
    if (currentContract._txFlashloanTarget == 0 || currentContract._txFlashloanTarget != e.msg.sender)
        revert();
    return onFlashLoanResult(transientMsgSender, _borrowToken, _flashloanAmount);
}

/// @title only listed functions will invoke a call to onFlahsLoan  
rule noCallsToFlashLoan(method f) filtered { f -> 
                        f.selector!=sig:closeLeveragePosition(address,bytes,ILeverageUsingSiloFlashloan.CloseLeverageArgs).selector &&
                        f.selector!=sig:openLeveragePosition(address,ILeverageUsingSiloFlashloan.FlashArgs,bytes,
                                    ILeverageUsingSiloFlashloan.DepositArgs).selector &&
                        f.selector!=sig:closeLeveragePositionPermit(address,bytes,ILeverageUsingSiloFlashloan.CloseLeverageArgs, ILeverageUsingSiloFlashloan.Permit ).selector &&
                        f.selector!=sig:openLeveragePositionPermit(address,ILeverageUsingSiloFlashloan.FlashArgs,bytes,
                                    ILeverageUsingSiloFlashloan.DepositArgs,ILeverageUsingSiloFlashloan.Permit).selector &&
                        f.selector!=sig:onFlashLoan(address,address,uint256,uint256,bytes).selector &&
                        f.selector!=sig:silo0.flashLoan(address,address,uint256,bytes).selector
                        }
    {
    // assume transaction level
    require currentContract._txMsgSender == 0 && currentContract._txFlashloanTarget == 0 ;
    require !flashLoanWasCalled;
    env e;
    calldataarg args;
    require e.msg.sender != 0, "safe assume address 0 does not call anything"; 
    f(e,args);
    assert !flashLoanWasCalled;
}

/// @title onFlahsLoan reverts if called directly 
rule onFlashLoanReverts() { 
    env e;
    bool stateBefore =  currentContract._txFlashloanTarget != e.msg.sender ;
    calldataarg args;
    require e.msg.sender != 0, "safe assume address 0 does not call anything"; 
    onFlashLoan@withrevert(e,args);
    assert stateBefore => lastReverted; 
}

/// @title Silo.FlashLoan() reverts if called top level and attempt to call Leverage.onFlashLoan 
rule siloFlashLoanReverts() { 
    bool stateBefore =  currentContract._txFlashloanTarget == 0 ;
    env e;
    calldataarg args;
    silo0.flashLoan@withrevert(e,args);
    assert stateBefore => lastReverted; 
}

/// @title openLeveragePosition reaches onFlashLoan on valid states only 
rule validCallsToFlashLoan_open() {
    require !flashLoanWasCalled;
    env e;
    address msgSender;
    ILeverageUsingSiloFlashloan.FlashArgs flashArgs;
    bytes b;
    ILeverageUsingSiloFlashloan.DepositArgs depositArgs; 
    openLeveragePosition(e,msgSender,flashArgs, b, depositArgs);
    
    assert flashLoanWasCalled;
    assert transientMsgSender == msgSender ;
    assert msgSenderToOnFlashLoan == flashArgs.flashloanTarget && flashArgs.flashloanTarget != 0 ;
    assert e.msg.sender == currentContract.ROUTER;
}

/// @title closeLeveragePosition reaches onFlashLoan on valid states only
rule validCallsToFlashLoan_close() {
    require !flashLoanWasCalled;
    
    env e;
    bytes b;
    address msgSender;
    ILeverageUsingSiloFlashloan.CloseLeverageArgs closeArgs; 
    closeLeveragePosition(e,msgSender,b,closeArgs);
    
    assert flashLoanWasCalled;
    assert transientMsgSender == msgSender ;
    assert msgSenderToOnFlashLoan == closeArgs.flashloanTarget && closeArgs.flashloanTarget != 0 ;
    assert e.msg.sender == currentContract.ROUTER;
}

/// @title Leverage contract can not have debt in Silo nor allowance to any EOA user 
rule noDebtOnLeverage(address user, method f)
{ 
    require debtToken0.balanceOf(currentContract)==0 &&
            debtToken1.balanceOf(currentContract)==0 &&
            debtToken0.allowance(currentContract,user) == 0  && 
            debtToken1.allowance(currentContract,user) == 0;
    require currentContract._txFlashloanTarget == 0 ;

    env e;
    calldataarg args;
    require e.msg.sender == user;
    require user != currentContract && user != silo0 && user != silo1;
    f@withrevert(e,args);

    assert lastReverted ||
        (   debtToken0.balanceOf(currentContract)==0 &&
            debtToken1.balanceOf(currentContract)==0 &&
            debtToken0.allowance(currentContract,user) == 0  && 
            debtToken1.allowance(currentContract,user) == 0 );
    }