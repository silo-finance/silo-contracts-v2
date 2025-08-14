
import "leverage_base.spec";

/*
Main properties of the Leverage contract:

Even with unlimited allowance to the leverage contract, a user's assets can not be decreased either by increasing debt or reducing collateral or transferring tokens.

This property is proven by:
1) proving that certain functions preserving balances for all users 
2) proving that on closeLeveragePosition() and openLeveragePosition() a msg.sender can not decrease other's account assets or increase debt of another account.
Notes:
1. This property holds only for users that have not giving any allowance to the generalSwapModule()
2. We assume a limiting options for the calls in GeneralSwapModule.fillQuote() and for each option have a distinct certoraRun output .
To run this file:
certoraRun certora/config/silo/leverage.conf 


results with the different options for the fillQuote dispatcher. In option also include all options of transferFrom():
onFlashLoan - https://prover.certora.com/output/40726/df2a8289a92642b798925e5ee028f102/?anonymousKey=91b09db29d355f1a326f14d874985a724c46cee0
closeLeveragePosition - https://prover.certora.com/output/40726/2c218d8368564ea4a45cebf520bf2ea0/?anonymousKey=e18758c519bb10da05b5001a45c55b681894eade
openLeveragePosition - https://prover.certora.com/output/40726/8da2db8a019349c485a1c373c0919d07/?anonymousKey=b6b49c037dd36cd718af911b826ccde436f594dd
repayShares - https://prover.certora.com/output/40726/29d76a344d7e4bfea305dfee26062838/?anonymousKey=629a64678a55a6f2e8545d69b3fa154354c34da7
deposit - https://prover.certora.com/output/40726/8786144f71f24c7480b8b00955ecbe71/?anonymousKey=ebf77f7ffde5e4a4afec16c38d98de183d13de1c
borrow - https://prover.certora.com/output/40726/71f2350982754270954c7b2cf3e145d9/?anonymousKey=d9a98fd0a306e0bf8c236a26dc851670a8d290cb


mutation testing: https://mutation-testing.certora.com/?id=4d85f052-d8fd-40d5-8305-8f486a45eb6a&anonymousKey=3d392b7c-6ba6-444d-91fe-4909157b9f8f
on mutation in certora/mutates/LeverageUsing* and more 

*/

methods {


    // Resolution for the dynamic calls in fillQuote. Need to run separetly on each option as on all options there is a path explosion 
    unresolved external in GeneralSwapModule.fillQuote(IGeneralSwapModule.SwapArgs memory, uint256) => DISPATCH [
    //    TrustedSilo0.borrow(uint256,address,address),
    //    TrustedSilo0.deposit(uint256,address,uint8),
    //      TrustedSilo0.repayShares(uint256,address),
    //      TrustedSilo0.flashLoan(address,address,uint256,bytes),
    //    LeverageUsingSiloFlashloanWithGeneralSwap.openLeveragePosition(address,ILeverageUsingSiloFlashloan.FlashArgs,bytes,
    //                                ILeverageUsingSiloFlashloan.DepositArgs),
    //     LeverageUsingSiloFlashloanWithGeneralSwap.closeLeveragePosition(address,bytes,ILeverageUsingSiloFlashloan.CloseLeverageArgs),
    //     LeverageUsingSiloFlashloanWithGeneralSwap.onFlashLoan(address,address,uint256,uint256,bytes),
        _.transferFrom(address,address,uint256), 
    ] default NONDET;
    

    //call back to leverage
    function _.onFlashLoan(address,address,uint256,uint256,bytes) external => DISPATCHER(true);


}


function userIsNotContract(address user) returns (bool)  {
    return user != silo0 && user != silo1 &&
    user != generalSwapModule && user != currentContract;
}

function noAllowance(address contract, address user) returns (bool) {
    return  debtToken0.allowance(user,contract) == 0 &&
     debtToken1.allowance(user,contract) == 0 &&
     collateralToken0.allowance(user,contract) == 0 && 
     collateralToken1.allowance(user,contract) == 0 && 
     weth.allowance(user,contract) == 0 &&
     token0.allowance(user,contract) == 0 &&
     token1.allowance(user,contract) == 0;
}


///@title Beside closeLeveragePosition() and openLeveragePosition() and the filteredFunctions, no function changes any balance 
rule noChangeToBalances_functions(method f) filtered {f -> !f.isView && !filteredFunctions(f) &&  
                        f.selector!=sig:closeLeveragePosition(address,bytes,ILeverageUsingSiloFlashloan.CloseLeverageArgs).selector && 
                        f.selector!=sig:openLeveragePosition(address,ILeverageUsingSiloFlashloan.FlashArgs,bytes,
                                    ILeverageUsingSiloFlashloan.DepositArgs).selector} {
    address user; 
    address leverageUser;
    require uniqueUserLeverageContract(leverageUser) == currentContract;
    
    uint256 asset0_before = token0.balanceOf(user); 
    uint256 asset1_before = token1.balanceOf(user); 
    uint256 debt0_before = debtToken0.balanceOf(user);
    uint256 debt1_before = debtToken1.balanceOf(user);
    uint256 collateral0_before = collateralToken0.balanceOf(user);
    uint256 collateral1_before = collateralToken1.balanceOf(user);
    uint256 weth_before = weth.balanceOf(user);
    require collateralToken0.balanceOf(currentContract) == 0; 
    require collateralToken1.balanceOf(currentContract) == 0;
    require debtToken0.balanceOf(currentContract) == 0;
    require debtToken1.balanceOf(currentContract) == 0;

    env e;
    calldataarg args;
    f(e,args);
    
    require  (f.selector == sig:rescueTokens(address).selector || f.selector == sig:rescueNativeTokens().selector) =>
            ( user != currentContract && user != leverageUser ); 

    assert asset0_before == token0.balanceOf(user);
    assert asset1_before == token1.balanceOf(user);
    assert debt0_before == debtToken0.balanceOf(user);
    assert debt1_before == debtToken1.balanceOf(user);
    assert collateral0_before == collateralToken0.balanceOf(user);
    assert collateral1_before == collateralToken1.balanceOf(user);
    assert weth_before == weth.balanceOf(user);
}

///@ title No debt on the account of a Leverage contract
rule noLeverageDebtInSilo(method f) filtered { f-> 
                        f.selector==sig:closeLeveragePosition(address,bytes,ILeverageUsingSiloFlashloan.CloseLeverageArgs).selector || 
                        f.selector==sig:openLeveragePosition(address,ILeverageUsingSiloFlashloan.FlashArgs,bytes,
                                    ILeverageUsingSiloFlashloan.DepositArgs).selector} {

    require collateralToken0.balanceOf(currentContract) == 0; 
    require collateralToken1.balanceOf(currentContract) == 0;
    require debtToken0.balanceOf(currentContract) == 0;
    require debtToken1.balanceOf(currentContract) == 0;
    require collateralToken0.balanceOf(generalSwapModule) == 0; 
    require collateralToken1.balanceOf(generalSwapModule) == 0;
    require noAllowance(generalSwapModule,currentContract);

    env e;
    calldataarg args;
    address msgSender;
    require msgSender!=currentContract;
    if (f.selector==sig:closeLeveragePosition(address,bytes,ILeverageUsingSiloFlashloan.CloseLeverageArgs).selector ) {
        bytes b; ILeverageUsingSiloFlashloan.CloseLeverageArgs c;
        closeLeveragePosition(e,msgSender, b, c);
    }
    else {
        ILeverageUsingSiloFlashloan.FlashArgs a; bytes b; ILeverageUsingSiloFlashloan.DepositArgs d;
        openLeveragePosition(e,msgSender, a, b, d);
    }

    assert debtToken0.balanceOf(currentContract) == 0;
    assert debtToken1.balanceOf(currentContract) == 0;
    assert noAllowance(generalSwapModule,currentContract);
}


///@title Function closeLeveragePosition() and openLeveragePosition() do not decrease assets in token or collateral token, nor increase debt of other users than the msg.sender. 
rule balanceOfOther_close_open(method f) filtered { f-> 
                        f.selector==sig:closeLeveragePosition(address,bytes,ILeverageUsingSiloFlashloan.CloseLeverageArgs).selector || 
                        f.selector==sig:openLeveragePosition(address,ILeverageUsingSiloFlashloan.FlashArgs,bytes,
                                    ILeverageUsingSiloFlashloan.DepositArgs).selector}   
    {
    address user; 
    require userIsNotContract(user);
    //assume no allowance to swap contracts
    require noAllowance(generalSwapModule,user);

    uint256 asset0_before = token0.balanceOf(user); 
    uint256 asset1_before = token1.balanceOf(user); 
    uint256 debt0_before = debtToken0.balanceOf(user);
    uint256 debt1_before = debtToken1.balanceOf(user);
    uint256 collateral0_before = collateralToken0.balanceOf(user);
    uint256 collateral1_before = collateralToken1.balanceOf(user);
    uint256 weth_before = weth.balanceOf(user);

    env e;
    address msgSender;
    if (f.selector==sig:closeLeveragePosition(address,bytes,ILeverageUsingSiloFlashloan.CloseLeverageArgs).selector ) {
        bytes b; ILeverageUsingSiloFlashloan.CloseLeverageArgs c;
        closeLeveragePosition(e,msgSender, b, c);
    }
    else {
        ILeverageUsingSiloFlashloan.FlashArgs a; bytes b; ILeverageUsingSiloFlashloan.DepositArgs d;
        openLeveragePosition(e,msgSender, a, b, d);
    }
    //some contract's balance is expected to change 
    assert msgSender != user => asset0_before <= token0.balanceOf(user);
    satisfy msgSender != user && asset0_before < token0.balanceOf(user);

    assert msgSender != user => asset1_before <= token1.balanceOf(user);
    satisfy msgSender != user && asset1_before < token1.balanceOf(user);

    assert msgSender != user => debt0_before >= debtToken0.balanceOf(user);
    satisfy msgSender != user && debt0_before > debtToken0.balanceOf(user);

    assert msgSender != user => debt1_before >= debtToken1.balanceOf(user);
    satisfy msgSender != user && debt1_before > debtToken1.balanceOf(user);

    assert msgSender != user => collateral0_before <= collateralToken0.balanceOf(user); 
    satisfy msgSender != user && collateral0_before < collateralToken0.balanceOf(user); 

    assert msgSender != user => collateral1_before <= collateralToken1.balanceOf(user); 
    satisfy msgSender != user && collateral1_before < collateralToken1.balanceOf(user); 
}

/// @title Function openLeverage can increase the debt and collateral of the user 
rule integrityOpenLeverage() {
    env e;
    address user;
    require noAllowance(generalSwapModule,user);
    require userIsNotContract(user);
    uint256 asset0_before = token0.balanceOf(user); 
    uint256 asset1_before = token1.balanceOf(user); 
    uint256 debt0_before = debtToken0.balanceOf(user);
    uint256 debt1_before = debtToken1.balanceOf(user);
    uint256 collateral0_before = collateralToken0.balanceOf(user);
    uint256 collateral1_before = collateralToken1.balanceOf(user);
    uint256 silo0_before = silo0.balanceOf(user);
    uint256 silo1_before = silo1.balanceOf(user);
    uint256 weth_before = weth.balanceOf(user);

    ILeverageUsingSiloFlashloan.FlashArgs a; bytes b; ILeverageUsingSiloFlashloan.DepositArgs d;
    openLeveragePosition(e,user, a, b, d);

    satisfy asset0_before < token0.balanceOf(user); 
    satisfy debt0_before < debtToken0.balanceOf(user);
    satisfy collateral0_before < collateralToken0.balanceOf(user); 
    satisfy silo0_before < silo0.balanceOf(user);
}


rule integrityCloseLeverage() {
    env e;
    address user;
    require noAllowance(generalSwapModule,user);
    require userIsNotContract(user);
    uint256 asset0_before = token0.balanceOf(user); 
    uint256 asset1_before = token1.balanceOf(user); 
    uint256 debt0_before = debtToken0.balanceOf(user);
    uint256 debt1_before = debtToken1.balanceOf(user);
    uint256 collateral0_before = collateralToken0.balanceOf(user);
    uint256 collateral1_before = collateralToken1.balanceOf(user);
    uint256 silo0_before = silo0.balanceOf(user);
    uint256 silo1_before = silo1.balanceOf(user);
    uint256 weth_before = weth.balanceOf(user);

    bytes b; ILeverageUsingSiloFlashloan.CloseLeverageArgs c;
    closeLeveragePosition(e,user, b, c);

    satisfy asset0_before < token0.balanceOf(user); 
    assert debt0_before >= debtToken0.balanceOf(user) && debt1_before >= debtToken1.balanceOf(user);
    satisfy debt0_before > debtToken0.balanceOf(user);
    satisfy collateral0_before > collateralToken0.balanceOf(user); 
    satisfy silo0_before > silo0.balanceOf(user);
}


/// @title Rescue tokens can be executed but only by the leverageUSer. On successful call all tokens are transferred to the leverageUser   
rule ownerAndOnlyOwnerCanRescue(address token) {
    env e;
    calldataarg args;
    address leverageUser;
    require debtToken0.balanceOf(currentContract)==0 &&
            debtToken1.balanceOf(currentContract)==0; 
    require uniqueUserLeverageContract(leverageUser) == currentContract && leverageUser != currentContract;
    require !currentContract._lock, "assume not in reentrancy";

    uint256 balanceInLeverageBefore = token.balanceOf(e,currentContract);
    uint256 userBalanceBefore = token.balanceOf(e,leverageUser);
    require balanceInLeverageBefore + userBalanceBefore <= max_uint256; 

    rescueTokens@withrevert(e,token);
    bool reverted = lastReverted;

    assert e.msg.sender != leverageUser  => reverted;
    
    satisfy e.msg.sender == leverageUser && balanceInLeverageBefore >0 && !reverted;
    assert !reverted => token.balanceOf(e,leverageUser) == balanceInLeverageBefore + userBalanceBefore;
}


/// @title Rescue Eth can be executed but only by the leverageUSer. On successful call all eth are transferred to the leverageUser   
rule ownerAndOnlyOwnerCanRescueEth(address token) {
    env e;
    address leverageUser;
    require !currentContract._lock, "assume not in reentrancy";
    require uniqueUserLeverageContract(leverageUser) == currentContract;


    uint256 balanceInLeverageBefore = nativeBalances[currentContract];
    uint256 userBalanceBefore = nativeBalances[leverageUser];
    
    rescueNativeTokens@withrevert(e);
    bool reverted = lastReverted;

    assert e.msg.sender != leverageUser  => reverted;
    satisfy (e.msg.sender == leverageUser && balanceInLeverageBefore >0 &&!reverted);
    assert !reverted => nativeBalances[leverageUser] == balanceInLeverageBefore + userBalanceBefore;
}