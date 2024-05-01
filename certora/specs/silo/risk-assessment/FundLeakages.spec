import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
//import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/priceOracle.spec";
//import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SiloSolvencyLib.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";


rule HLP_Mint2RedeemNotProfitable(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    sharesToAssetsFixedRatio(e);
    //sharesToAssetsNotTooHigh(e, 2);
    sharesAndAssetsNotTooHigh(e, 10^6);


    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);    

    uint256 assets1; uint256 assets2; uint256 shares;
    mathint sharesM1 = mint(e, assets1, receiver);
    mathint balanceCollateralM1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM1 = token0.balanceOf(e.msg.sender);    

    mathint sharesM2 = mint(e, assets2, receiver);
    mathint balanceCollateralM2 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM2 = token0.balanceOf(e.msg.sender);    
   
    mathint assetsR = redeem(e, shares, receiver, receiver);
    mathint balanceCollateralR = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR = token0.balanceOf(e.msg.sender);    
   
    assert balanceCollateralR >= balanceCollateralBefore => balanceTokenR <= balanceTokenBefore;
}

rule HLP_Mint2Redeem2NotProfitable(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);    

    uint256 assets1; uint256 assets2; uint256 shares1; uint256 shares2;
    mathint sharesM1 = mint(e, assets1, receiver);
    mathint balanceCollateralM1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM1 = token0.balanceOf(e.msg.sender);    

    mathint sharesM2 = mint(e, assets2, receiver);
    mathint balanceCollateralM2 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM2 = token0.balanceOf(e.msg.sender);    
   
    mathint assetsR1 = redeem(e, shares1, receiver, receiver);
    mathint balanceCollateralR1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR1 = token0.balanceOf(e.msg.sender);    
    
    mathint assetsR2 = redeem(e, shares2, receiver, receiver);
    mathint balanceCollateralR2 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR2 = token0.balanceOf(e.msg.sender);    
   
    assert balanceCollateralR2 >= balanceCollateralBefore => balanceTokenR2 <= balanceTokenBefore;
}

rule HLP_MintRedeem2NotProfitable(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    sharesToAssetsFixedRatio(e);
    //sharesToAssetsNotTooHigh(e, 2);
    sharesAndAssetsNotTooHigh(e, 10^6);

    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);    

    uint256 assets1; uint256 assets2; uint256 shares1; uint256 shares2;
    mathint sharesM1 = mint(e, assets1, receiver);
    mathint balanceCollateralM1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM1 = token0.balanceOf(e.msg.sender);    

    //mathint sharesM2 = mint(e, assets2, receiver);
    //mathint balanceCollateralM2 = shareCollateralToken0.balanceOf(receiver);  
    //mathint balanceTokenM2 = token0.balanceOf(e.msg.sender);    
   
    mathint assetsR1 = redeem(e, shares1, receiver, receiver);
    mathint balanceCollateralR1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR1 = token0.balanceOf(e.msg.sender);    
    
    mathint assetsR2 = redeem(e, shares2, receiver, receiver);
    mathint balanceCollateralR2 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR2 = token0.balanceOf(e.msg.sender);    
   
    assert balanceCollateralR2 >= balanceCollateralBefore => balanceTokenR2 <= balanceTokenBefore;
}

rule HLP_MintWithdrawNotProfitable(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    sharesToAssetsFixedRatio(e);
    //sharesToAssetsNotTooHigh(e, 2);
    sharesAndAssetsNotTooHigh(e, 10^6);

    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);    

    uint256 shares; 
    mathint assetsM = mint(e, shares, receiver);
    mathint balanceCollateralM = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM = token0.balanceOf(e.msg.sender);    

    uint256 assets;
    mathint sharesW = withdraw(e, assets, e.msg.sender, receiver);
    mathint balanceCollateralW = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenW = token0.balanceOf(e.msg.sender);    
   
    assert balanceCollateralW > balanceCollateralBefore => balanceTokenW < balanceTokenBefore;
    assert balanceTokenW > balanceTokenBefore => balanceCollateralW < balanceCollateralBefore;

    satisfy balanceCollateralW > balanceCollateralBefore => balanceTokenW < balanceTokenBefore;
    satisfy balanceTokenW > balanceTokenBefore => balanceCollateralW < balanceCollateralBefore;
}

// violated
rule HLP_AssetsPerShareNondecreasing(env e, method f)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    sharesToAssetsNotTooHigh(e, 2);
    requireTokensTotalAndBalanceIntegrity();

    mathint totalCollateralAssetsB; mathint totalProtectedAssetsB;
    totalCollateralAssetsB, totalProtectedAssetsB = getCollateralAndProtectedAssets(e);  
    mathint totalSumColateralB = totalCollateralAssetsB + totalProtectedAssetsB;
    mathint totalSharesB = shareCollateralToken0.totalSupply();
    mathint totalProtectedSharesB = shareProtectedCollateralToken0.totalSupply();

    calldataarg args;
    f(e, args);
    
    mathint totalCollateralAssetsA; mathint totalProtectedAssetsA;
    totalCollateralAssetsA, totalProtectedAssetsA = getCollateralAndProtectedAssets(e);  
    mathint totalSumColateralA = totalCollateralAssetsA + totalProtectedAssetsA;
    mathint totalSharesA = shareCollateralToken0.totalSupply();
    mathint totalProtectedSharesA = shareProtectedCollateralToken0.totalSupply();
    
    require totalSharesB > 0;
    require totalSharesA > 0;

    assert totalCollateralAssetsB * totalSharesA <= totalCollateralAssetsA * totalSharesB +  totalSharesA * totalSharesB;

    /*
    assert differsAtMost(totalProtectedAssetsB * totalProtectedSharesA,
        totalProtectedAssetsA * totalProtectedSharesB, totalProtectedSharesA * totalProtectedSharesB);
    assert differsAtMost(totalSumColateralB * totalSumSharesA,
        totalSumColateralA * totalSumSharesB, totalSumSharesA * totalSumSharesB);
    */
    //assert totalCollateralAssetsB * totalSharesA <= totalCollateralAssetsA * totalSharesB;
    //assert totalProtectedAssetsB * totalProtectedSharesA <= totalProtectedAssetsA * totalProtectedSharesB;
    //assert totalSumColateralB * totalSumSharesA <= totalSumColateralA * totalSumSharesB;
}

rule HLP_OthersCantDecreaseMyRedeem(env e, env eOther, method f)
    filtered { f -> !f.isView }
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    completeSiloSetupEnv(eOther);
    totalSupplyMoreThanBalance(eOther.msg.sender);
    require e.msg.sender != eOther.msg.sender;
    sharesToAssetsNotTooHigh(e, 2);
    sharesToAssetsNotTooHigh(eOther, 2);

    storage init = lastStorage;
    uint256 shares;
    mathint assetsReceived = redeem(e, shares, e.msg.sender, e.msg.sender);
    
    calldataarg args;
    f(eOther, args) at init;
    mathint assetsReceived2 = redeem(e, shares, e.msg.sender, e.msg.sender);

    assert assetsReceived2 >= assetsReceived;
}

rule HLP_OthersCantDecreaseMyRedeem_viaDeposit(env e, env eOther)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    completeSiloSetupEnv(eOther);
    totalSupplyMoreThanBalance(eOther.msg.sender);
    require e.msg.sender != eOther.msg.sender;
    sharesToAssetsFixedRatio(e);
    //sharesToAssetsNotTooHigh(e, 2);
    sharesAndAssetsNotTooHigh(e, 10^6);

    storage init = lastStorage;
    uint256 shares;
    // check conversion func instead
    mathint assetsReceived = redeem(e, shares, e.msg.sender, e.msg.sender);
    
    uint256 assets;
    address receiver;
    require receiver != e.msg.sender;
    deposit(eOther, assets, receiver) at init;
    mathint assetsReceived2 = redeem(e, shares, e.msg.sender, e.msg.sender);

    assert assetsReceived2 >= assetsReceived;
}

rule HLP_OthersCantDecreaseMyRedeem_viaWithdraw(env e, env eOther)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    completeSiloSetupEnv(eOther);
    totalSupplyMoreThanBalance(eOther.msg.sender);
    require e.msg.sender != eOther.msg.sender;
    sharesToAssetsFixedRatio(e);
    //sharesToAssetsNotTooHigh(e, 2);
    sharesToAssetsNotTooHigh(eOther, 2);

    storage init = lastStorage;
    uint256 shares;
    mathint assetsReceived = redeem(e, shares, e.msg.sender, e.msg.sender);
    
    uint256 assets;
    address receiver;
    require receiver != e.msg.sender;
    withdraw(eOther, assets, receiver, receiver) at init;
    mathint assetsReceived2 = redeem(e, shares, e.msg.sender, e.msg.sender);

    assert assetsReceived2 >= assetsReceived;
}

// vv SIMPLIFIED CALCULATIONS - UNDERAPPROXIMATIONS vv

function simpleDeposit(mathint assets, mathint totalAssets, 
    mathint totalShares) returns mathint
{
    return mulDivDown(assets, totalShares + 1, totalAssets + 1);
}

function simpleWithdraw(mathint assets, mathint totalAssets, 
    mathint totalShares) returns mathint
{
    return mulDivUp(assets, totalShares + 1, totalAssets + 1);
}

function simpleMint(mathint shares, mathint totalAssets, 
    mathint totalShares) returns mathint
{
    return mulDivUp(shares, totalAssets + 1, totalShares + 1);
}

function simpleRedeem(mathint shares, mathint totalAssets, 
    mathint totalShares) returns mathint
{
    return mulDivDown(shares, totalAssets + 1, totalShares + 1);
}

function mulDivDown(mathint x, mathint y, mathint z) returns mathint {
    require z !=0;
    return x * y / z;
}

function mulDivUp(mathint x, mathint y, mathint z) returns mathint {
    require z !=0;
    return (x * y + z - 1) / z;
}

// these 4 hold
// https://prover.certora.com/output/6893/f84684efde2d4e6ba43a2bb9646436fa/?anonymousKey=739062a05b542f6dbe81d5a704824e885731a3f1
rule S_othersCantDecreaseMyRedeem_viaDeposit(env e, env eOther)
{
    mathint initAssets; mathint initShares;
    require initAssets > 0; require initShares > 0;
    mathint shares;
    require shares > 0 && shares <= initShares;
    mathint assetsReceived1 = simpleRedeem(shares, initAssets, initShares);
    
    mathint assets; require assets > 0;
    mathint sharesGained = simpleDeposit(assets, initAssets, initShares);
    mathint assetsReceived2 = 
        simpleRedeem(shares, initAssets + assets, initShares + sharesGained);

    assert assetsReceived2 >= assetsReceived1;
}

rule S_othersCantDecreaseMyRedeem_viaWithdraw(env e, env eOther)
{
    mathint initAssets; mathint initShares;
    require initAssets > 0; require initShares > 0;
    mathint shares; require shares > 0 && shares <= initShares;
    mathint assetsReceived1 = simpleRedeem(shares, initAssets, initShares);
    
    mathint assets; require assets > 0;
    require assets <= initAssets;
    mathint sharesPaid = simpleWithdraw(assets, initAssets, initShares);
    mathint assetsReceived2 = 
        simpleRedeem(shares, initAssets - assets, initShares - sharesPaid);
    assert assetsReceived2 >= assetsReceived1;
}

rule S_othersCantDecreaseMyRedeem_viaMint(env e, env eOther)
{
    mathint initAssets; mathint initShares;
    require initAssets > 0; require initShares > 0;
    mathint shares; require shares > 0 && shares <= initShares;
    mathint assetsReceived1 = simpleRedeem(shares, initAssets, initShares);
    
    mathint sharesOther; require sharesOther > 0;
    mathint assetsPaid = simpleMint(sharesOther, initAssets, initShares);
    mathint assetsReceived2 = 
        simpleRedeem(shares, initAssets + assetsPaid, initShares + sharesOther);
    assert assetsReceived2 >= assetsReceived1;
}

rule S_othersCantDecreaseMyRedeem_viaRedeem(env e, env eOther)
{
    mathint initAssets; mathint initShares;
    require initAssets > 0; require initShares > 0;
    mathint shares; require shares > 0 && shares <= initShares;
    mathint assetsReceived1 = simpleRedeem(shares, initAssets, initShares);
    
    mathint sharesOther; require sharesOther > 0;
    require sharesOther <= initShares;
    mathint assetsGained = simpleRedeem(sharesOther, initAssets, initShares);
    mathint assetsReceived2 = 
        simpleRedeem(shares, initAssets - assetsGained, initShares - sharesOther);
    assert assetsReceived2 >= assetsReceived1;
}

rule S_mint2RedeemNotProfitable(env e, address receiver)
{
    mathint initAssets; mathint initShares;
    require initAssets > 0; require initShares > 0;
    
    mathint shares1; require shares1 > 0;
    mathint assetsPaid1 = simpleMint(shares1, initAssets, initShares);
    
    mathint shares2; require shares2 > 0;
    mathint assetsPaid2 = 
        simpleMint(shares2, initAssets + assetsPaid1, initShares + shares1);
    
    mathint shares3; require shares3 > 0;
    mathint assetsReceived = 
        simpleRedeem(shares3, initAssets + assetsPaid1 + assetsPaid2, 
            initShares + shares1 + shares2);

    assert !(shares1 + shares2 > shares3 && 
        assetsReceived >= assetsPaid1 + assetsPaid2);

    assert !(shares1 + shares2 >= shares3 && 
        assetsReceived > assetsPaid1 + assetsPaid2);
}

// holds
// https://prover.certora.com/output/6893/9cbb9c7397c8480ab86fb752551509ec/?anonymousKey=896b00d616f9357c3ff004795b73faba71b5afac
rule S_mintRedeem2NotProfitable(env e, address receiver)
{
    mathint initAssets; mathint initShares;
    require initAssets > 0; require initShares > 0;
    
    mathint shares1; require shares1 > 0;
    mathint assetsPaid1 = simpleMint(shares1, initAssets, initShares);
    
    mathint shares2; require shares2 > 0;
    mathint assetsReceived1 = 
        simpleRedeem(shares2, initAssets + assetsPaid1, initShares + shares1);
    
    mathint shares3; require shares3 > 0;
    mathint assetsReceived2 = 
        simpleRedeem(shares3, initAssets + assetsPaid1 - assetsReceived1, 
            initShares + shares1 - shares2);

    assert !(shares1 >= shares2 + shares3 && 
        assetsReceived1 + assetsReceived2 > assetsPaid1);

    assert !(shares1 > shares2 + shares3 && 
        assetsReceived1 + assetsReceived2 >= assetsPaid1);
}