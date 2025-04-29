// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

using ERC20Helper as ERC20Helper;
using SiloVaultHarness as siloVaultHarness;
using Vault1 as vault1;
using SiloVaultActionsLib as siloVaultActionsLib;
using UtilsLib as utilsLib;


methods {

    function SiloVaultHarness.convertToAssets(uint256) external returns(uint256) envfree;
    function SiloVaultHarness.convertToShares(uint256) external returns(uint256) envfree;
    function SiloVaultHarness.balanceOf(address) external returns(uint256) envfree;
    function SiloVaultHarness.totalSupply() external returns(uint256) envfree;
    function SiloVaultHarness.totalAssets() external returns(uint256) envfree;

    function ERC20.balanceOf(address, address) external returns(uint256) envfree;
    function ERC20.totalSupply(address) external returns(uint256) envfree;
    function ERC20.safeTransferFrom(address, address, address, uint256) external envfree;
    function ERC20.allowance(address, address, address) external returns (uint256) envfree;
    
    function _.allowance(address owner, address spender) external => DISPATCHER(true);
    function vault0.getTotalSupply(address) external returns(uint256) envfree;

    function vault0.asset() external returns(address) envfree;
    function vault1.asset() external returns(address) envfree;
    
    //function _.mint(uint256, address) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);
    function _.ERC20BalanceOf(address token, address account) internal => balanceOf_cvl(token, account) expect (uint256);
    
    function _.safeTransfer(address token, address to, uint256 value) internal
        => cvlTransfer(token, to, value) expect (bool, bytes memory);

    function _.safeTransferFrom(address token, address from, address to, uint256 value) internal
        => cvlTransferFrom(token, from, to, value) expect (bool, bytes memory);
    
    function _.forceApprove(address, address, uint256) internal => NONDET;

    // methods on markets
    function _.previewRedeem(uint256 shares) external => previewRedeem_cvl(calledContract, shares) expect (uint256);
    function _.deposit(uint256 assets, address receiver) external => deposit_cvl(currentContract, calledContract, assets, receiver) expect (uint256) ALL;
    function _.withdraw(uint256 assets, address receiver, address spender) external => withdraw_cvl(spender, calledContract, assets, receiver) expect (uint256) ALL;
    function _.redeem(uint256 shares, address receiver, address spender) external => redeem_cvl(spender, calledContract, shares, receiver) expect (uint256) ALL;

    // math summaries for speed
    
}
 
function cvlTransfer(address token, address to, uint256 value) returns (bool, bytes) {
    env e;
    require e.msg.sender == currentContract;
    require e.msg.value == 0;
    require require_uint256(balanceOf_cvl(token, currentContract) + balanceOf_cvl(token, to)) 
            <= ERC20.totalSupply(token);
    token.transfer(e, to, value);
    bool success;
    bytes resBytes;
    return (success, resBytes);
}

function cvlTransferFrom(address token, address from, address to, uint256 value) returns (bool, bytes) {
    env e;
    require e.msg.sender == currentContract;
    require e.msg.value == 0;
    require require_uint256(balanceOf_cvl(token, from) + balanceOf_cvl(token, to)) 
            <= ERC20.totalSupply(token);

    token.transferFrom(e, from, to, value);
    bool success;
    bytes resBytes;
    return (success, resBytes);
}

function balanceOf_cvl(address token, address user) returns uint256
{
    return ERC20Helper.balanceOf(token, user);
}

ghost mapping (address => uint256) currentTotalAssets;
ghost mapping (address => uint256) currentTotalShares;
ghost mapping (address => address) tokenByMarket;

function convertToAssets_cvl(uint256 shares, uint256 totalAssets, uint256 totalShares) returns uint256
{
    require shares <= totalShares;
    if (shares == 0) return 0;
    if (totalAssets == 0) return 0;

    return cvlMulDiv(shares, totalAssets, totalShares);
}

function convertToShares_cvl(uint256 assets, uint256 totalAssets, uint256 totalShares) returns uint256
{
    require assets <= totalAssets;
    if (assets == 0) return 0;
    if (totalShares == 0) return 0;

    return cvlMulDiv(assets, totalShares, totalAssets);
}

function previewRedeem_cvl(address market, uint256 shares) returns uint256
{
    return convertToAssets_cvl(shares, currentTotalAssets[market], currentTotalShares[market]);
}

function deposit_cvl(address caller, address market, uint256 assets, address receiver) returns uint256
{
    // we assume that the inner markets are resistant to inflation attacks
    require currentTotalAssets[market] >= currentTotalShares[market];
    uint shares = convertToShares_cvl(assets, currentTotalAssets[market], currentTotalShares[market]);
    cvlTransferFrom(tokenByMarket[market], caller, market, assets);
    cvlTransferFrom(market, market, receiver, shares);
    currentTotalAssets[market] = require_uint256(currentTotalAssets[market] + assets);
    currentTotalShares[market] = require_uint256(currentTotalShares[market] + shares);
    return shares;
}

function withdraw_cvl(address caller, address market, uint256 assets, address receiver) returns uint256
{
    // we assume that the inner markets are resistant to inflation attacks
    require currentTotalAssets[market] >= currentTotalShares[market];
    uint shares = convertToShares_cvl(assets, currentTotalAssets[market], currentTotalShares[market]);
    cvlTransferFrom(market, caller, market, shares);
    cvlTransferFrom(tokenByMarket[market], market, receiver, assets);
    currentTotalAssets[market] = require_uint256(currentTotalAssets[market] - assets);
    currentTotalShares[market] = require_uint256(currentTotalShares[market] - shares);
    return shares;
}

function redeem_cvl(address caller, address market, uint256 shares, address receiver) returns uint256
{
    // we assume that the inner markets are resistant to inflation attacks
    require currentTotalAssets[market] >= currentTotalShares[market];
    uint assets = convertToAssets_cvl(shares, currentTotalAssets[market], currentTotalShares[market]);
    cvlTransferFrom(market, caller, market, shares);
    cvlTransferFrom(tokenByMarket[market], market, receiver, assets);
    currentTotalAssets[market] = require_uint256(currentTotalAssets[market] - assets);
    currentTotalShares[market] = require_uint256(currentTotalShares[market] - shares);
    return assets;
}

function setupMarkets()
{    
    require supplyQLength() == 1;
    require withdrawQLength() == 2;

    require supplyQGetAt(0) == vault0;
    require withdrawQGetAt(0) == vault0;
    require withdrawQGetAt(1) == vault1;
    
    require vault0.asset() == asset();
    require vault1.asset() == asset();

    require tokenByMarket[vault0] == asset();
    require tokenByMarket[vault1] == asset();

}

function balanceAssumptions(address user)
{
    require require_uint256(balanceOf_cvl(asset(), siloVaultHarness) + balanceOf_cvl(asset(), user)) 
         <= ERC20.totalSupply(asset());
    
    require require_uint256(balanceOf_cvl(siloVaultHarness, siloVaultHarness) + balanceOf_cvl(siloVaultHarness, user)) 
         <= ERC20.totalSupply(siloVaultHarness);
}

function notInTheSceneAssumptions(address user)
{
    require user != siloVaultHarness; //Vault doesn't call public methods on itself
    require user != asset();
    require user != vault0;
    require user != vault1;
}
////////////////////////////
//      FINISHED RULES    //
////////////////////////////

// holds for two markets
// https://prover.certora.com/output/6893/2facfa6ca76f46dc919fb6f12d058053/?anonymousKey=2dde6258f43ba5d9dc8189b37996f5d030367f8a
rule onlyContributionMethodsReduceAssets(method f) {
    address user; require user != currentContract;
    uint256 userAssetsBefore = userAssets(user);

    env e; 
    calldataarg args;
    safeAssumptions(e, user, _);

    setupMarkets();
    notInTheSceneAssumptions(e.msg.sender);
    notInTheSceneAssumptions(user);
    
    balanceAssumptions(e.msg.sender);
    balanceAssumptions(user);

    f(e, args);

    uint256 userAssetsAfter = userAssets(user);

    assert userAssetsBefore > userAssetsAfter =>
        (f.selector == sig:deposit(uint256,address).selector ||
         f.selector == sig:mint(uint256,address).selector),
        "a user's assets must not go down except on calls to contribution methods or calls directly to the asset.";
}

persistent ghost bool callMade;
persistent ghost bool delegatecallMade;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    // calls to libraries and markets are allowed
    if (addr != currentContract.asset() && addr != utilsLib && addr != vault0 && addr != vault1) 
    {
        callMade = true;
    }
}

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (addr != siloVaultActionsLib)    // calls to libraries are safe
        delegatecallMade = true;
}

/*
This rule proves there are no instances in the code in which the user can act as the contract.
By proving this rule we can safely assume in our spec that e.msg.sender != currentContract.
*/
rule noDynamicCalls {
    method f;
    env e;
    setupMarkets();
    calldataarg args;

    require !callMade && !delegatecallMade;

    f(e, args);

    assert !callMade && !delegatecallMade;
}

//holds
rule conversionOfZero {
    uint256 convertZeroShares = convertToAssets(0);
    uint256 convertZeroAssets = convertToShares(0);

    assert convertZeroShares == 0,
        "converting zero shares must return zero assets";
    assert convertZeroAssets == 0,
        "converting zero assets must return zero shares";
}

// holds
rule zeroDepositZeroShares(uint assets, address receiver)
{
    env e;
    
    uint shares = deposit(e,assets, receiver);

    assert shares == 0 <=> assets == 0;
}

// holds
rule underlyingCannotChange() {
    address originalAsset = asset();

    method f; env e; calldataarg args;
    f(e, args);

    address newAsset = asset();

    assert originalAsset == newAsset,
        "the underlying asset of a contract must not change";
}

// holds
rule dustFavorsTheHouse(uint assetsIn )
{
    env e;
        
    require e.msg.sender != currentContract;
    safeAssumptions(e, e.msg.sender, e.msg.sender);
    uint256 totalSupplyBefore = totalSupply();

    uint balanceBefore = ERC20Helper.balanceOf(asset(), currentContract);

    uint shares = deposit(e, assetsIn, e.msg.sender);
    uint assetsOut = redeem(e, shares, e.msg.sender, e.msg.sender);

    uint balanceAfter = ERC20Helper.balanceOf(asset(), currentContract);

    assert balanceAfter >= balanceBefore;
}

// holds
rule redeemingAllValidity() { 
    address owner; 
    uint256 shares; require shares == balanceOf(owner);
    env e; safeAssumptions(e, _, owner);
    
    require owner != feeRecipient();

    redeem(e, shares, _, owner);
    uint256 ownerBalanceAfter = balanceOf(owner);
    assert ownerBalanceAfter == 0;
}

// holds
invariant zeroAllowanceOnAssets(address user)
    ERC20Helper.allowance(asset(), currentContract, user) == 0 {
        preserved with(env e) {
            require e.msg.sender != currentContract;
        }
}

// holds for two markets
// https://prover.certora.com/output/6893/6753403e8b7241de9a49adfbc7274464/?anonymousKey=147e9d534c319cc5fa96075840ab6646a344f50a
rule contributingProducesShares(method f)
filtered {
    f -> f.selector == sig:deposit(uint256,address).selector
      || f.selector == sig:mint(uint256,address).selector
}
{
    env e; uint256 assets; uint256 shares;
    address contributor; require contributor == e.msg.sender;
    address receiver;
    require currentContract != contributor
         && currentContract != receiver;

    require previewDeposit(e, assets) + balanceOf(receiver) <= max_uint256; // safe assumption because call to _mint will revert if totalSupply += amount overflows
    require shares + balanceOf(receiver) <= max_uint256; // same as above

    setupMarkets();
    notInTheSceneAssumptions(e.msg.sender);
    notInTheSceneAssumptions(receiver);
    
    balanceAssumptions(e.msg.sender);
    balanceAssumptions(receiver);

    safeAssumptions(e, contributor, receiver);

    uint256 contributorAssetsBefore = userAssets(contributor);
    uint256 receiverSharesBefore = balanceOf(receiver);

    callContributionMethods(e, f, assets, shares, receiver);

    uint256 contributorAssetsAfter = userAssets(contributor);
    uint256 receiverSharesAfter = balanceOf(receiver);

    assert contributorAssetsBefore > contributorAssetsAfter <=> receiverSharesBefore < receiverSharesAfter,
        "a contributor's assets must decrease if and only if the receiver's shares increase";
}

// holds
rule conversionWeakMonotonicity_assets {
    uint256 smallerShares; uint256 largerShares;
    
    assert smallerShares < largerShares => convertToAssets(smallerShares) <= convertToAssets(largerShares),
        "converting more shares must yield equal or greater assets";
}

// holds
rule conversionWeakMonotonicity_shares {
    uint256 smallerAssets; uint256 largerAssets;

    assert smallerAssets < largerAssets => convertToShares(smallerAssets) <= convertToShares(largerAssets),
        "converting more assets must yield equal or greater shares";
}

/////////////////////
//  IN DEVELOPMENT //
/////////////////////

// violated
rule zeroAssetsZeroShares(env e, method f)
    filtered { f -> !f.isView 
        && f.selector != sig:updateWithdrawQueue(uint256[]).selector    // admin method, can violate
        && f.selector != sig:reallocate(SiloVaultHarness.MarketAllocation[]).selector // admin method, needs to be handled separately 
        //&& f.selector != sig:withdraw(uint256,address,address).selector     //timeout
        //&& f.selector != sig:redeem(uint256,address,address).selector       //timeout
        //&& f.selector == sig:transfer(address,uint256).selector 
        //&& f.selector == sig:deposit(uint256, address).selector 
        //&& f.selector == sig:setIsAllocator(address,bool).selector 
        

    }
{
    address receiver; address owner;
    setupMarkets();
    notInTheSceneAssumptions(e.msg.sender);
    notInTheSceneAssumptions(owner);
    
    balanceAssumptions(e.msg.sender);
    balanceAssumptions(owner);
    balanceAssumptions(receiver);
    
    uint256 totalAssets_pre = totalAssets(e);
    require lastTotalAssets(e) == totalAssets_pre;
    uint256 totalShares_pre = totalSupply(e);
    
    uint256 assets; uint256 shares; 
    callFunctionsWithReceiverAndOwner(e, f, assets, shares, receiver, owner);
    uint256 totalAssets_post = totalAssets(e);
    uint256 totalShares_post = totalSupply(e);

    assert (totalAssets_pre == 0 && totalShares_pre == 0) => 
        (totalAssets_post <= 1  <=> totalShares_post <= 1);    
}

// violated
rule moreAssetsThanShares(env e, method f)
    filtered { f -> !f.isView 
        && f.selector != sig:updateWithdrawQueue(uint256[]).selector    // admin method, can violate
        && f.selector != sig:reallocate(SiloVaultHarness.MarketAllocation[]).selector // admin method, needs to be handled separately 
        && f.selector != sig:withdraw(uint256,address,address).selector     //timeout
        && f.selector != sig:redeem(uint256,address,address).selector       //timeout
        //&& f.selector == sig:transfer(address,uint256).selector 
        //&& f.selector == sig:deposit(uint256, address).selector 
        //&& f.selector == sig:setIsAllocator(address,bool).selector 
        

    }
{
    address receiver; address owner;
    setupMarkets();
    notInTheSceneAssumptions(e.msg.sender);
    notInTheSceneAssumptions(owner);

    balanceAssumptions(e.msg.sender);
    balanceAssumptions(owner);
    balanceAssumptions(receiver);
    
    uint256 totalAssets_pre = totalAssets(e);
    require lastTotalAssets(e) == totalAssets_pre;
    uint256 totalShares_pre = totalSupply(e);
    
    uint256 assets; uint256 shares; 
    callFunctionsWithReceiverAndOwner(e, f, assets, shares, receiver, owner);
    uint256 totalAssets_post = totalAssets(e);
    uint256 totalShares_post = totalSupply(e);

    assert (totalAssets_pre == 0 && totalShares_pre == 0) => 
        (totalAssets_post + 1 >= totalShares_post);    
}

// timeout
rule convertToAssetsWeakAdditivity() {
    uint256 sharesA; uint256 sharesB;
    require sharesA + sharesB < max_uint128
         && convertToAssets(sharesA) + convertToAssets(sharesB) < max_uint256
         && convertToAssets(require_uint256(sharesA + sharesB)) < max_uint256;
    assert convertToAssets(sharesA) + convertToAssets(sharesB) <= convertToAssets(require_uint256(sharesA + sharesB)),
        "converting sharesA and sharesB to assets then summing them must yield a smaller or equal result to summing them then converting";
}

// timeout
rule convertToSharesWeakAdditivity() {
    uint256 assetsA; uint256 assetsB;
    require assetsA + assetsB < max_uint128
         && convertToAssets(assetsA) + convertToAssets(assetsB) < max_uint256
         && convertToAssets(require_uint256(assetsA + assetsB)) < max_uint256;
    assert convertToAssets(assetsA) + convertToAssets(assetsB) <= convertToAssets(require_uint256(assetsA + assetsB)),
        "converting assetsA and assetsB to shares then summing them must yield a smaller or equal result to summing them then converting";
}


// timeout
rule conversionWeakIntegrity() {
    uint256 sharesOrAssets;
    //assert convertToShares(convertToAssets(sharesOrAssets)) <= sharesOrAssets,
    //    "converting shares to assets then back to shares must return shares less than or equal to the original amount";
    assert convertToAssets(convertToShares(sharesOrAssets)) <= sharesOrAssets,
        "converting assets to shares then back to assets must return assets less than or equal to the original amount";
}

// timeout
rule convertToCorrectness(uint256 amount, uint256 shares)
{
    //assert amount >= convertToAssets(convertToShares(amount));
    assert shares >= convertToShares(convertToAssets(shares));
}

//timeout
rule depositMonotonicity() {
    env e; storage start = lastStorage;

    uint256 smallerAssets; uint256 largerAssets;
    address receiver;
    require currentContract != e.msg.sender && currentContract != receiver; 

    safeAssumptions(e, e.msg.sender, receiver);

    deposit(e, smallerAssets, receiver);
    uint256 smallerShares = balanceOf(receiver) ;

    deposit(e, largerAssets, receiver) at start;
    uint256 largerShares = balanceOf(receiver) ;

    assert smallerAssets < largerAssets => smallerShares <= largerShares,
            "when supply tokens outnumber asset tokens, a larger deposit of assets must produce an equal or greater number of shares";
}

// violated because moreAssetsThanShares is violated even for assets_pre == 0 and shares_pre == 0
invariant assetsMoreThanSupply()
    totalAssets() >= totalSupply()
    {
        preserved with (env e) {
            require e.msg.sender != currentContract;
            address any;
            safeAssumptions(e, any , e.msg.sender);
        }
}

// violated because moreAssetsThanShares is violated even for assets_pre == 0 and shares_pre == 0
rule totalsMonotonicity() {
    method f; env e; calldataarg args;
    require e.msg.sender != currentContract; 
    uint256 totalSupplyBefore = totalSupply();
    uint256 totalAssetsBefore = totalAssets();
    address receiver;

    setupMarkets();
    notInTheSceneAssumptions(e.msg.sender);
    // notInTheSceneAssumptions(receiver); try adding this if the rule fails
    
    balanceAssumptions(e.msg.sender);
    balanceAssumptions(receiver);

    require lastTotalAssets(e) == totalAssetsBefore;

    safeAssumptions(e, receiver, e.msg.sender);
    callReceiverFunctions(f, e, receiver);

    uint256 totalSupplyAfter = totalSupply();
    uint256 totalAssetsAfter = totalAssets();
    
    // possibly assert totalSupply and totalAssets must not change in opposite directions
    assert totalSupplyBefore < totalSupplyAfter  <=> totalAssetsBefore < totalAssetsAfter,
        "if totalSupply changes by a larger amount, the corresponding change in totalAssets must remain the same or grow";
    assert totalSupplyAfter == totalSupplyBefore => totalAssetsBefore == totalAssetsAfter,
        "equal size changes to totalSupply must yield equal size changes to totalAssets";
}

////////////////////////////////////////////////////////////////////////////////
////                        # helpers and miscellaneous                //////////
////////////////////////////////////////////////////////////////////////////////

function userAssets(address user) returns uint256
{
    return ERC20Helper.balanceOf(asset(), user);
}

function safeAssumptions(env e, address receiver, address owner) {
    require currentContract != asset(); // Although this is not disallowed, we assume the contract's underlying asset is not the contract itself
    // requireInvariant totalSupplyIsSumOfBalances();
    // requireInvariant vaultSolvency();
    // requireInvariant noAssetsIfNoSupply(); doesnt hold for the Vault
    // requireInvariant noSupplyIfNoAssets();
    requireInvariant assetsMoreThanSupply();

    require e.msg.sender != currentContract;  // This is proved by rule noDynamicCalls
    requireInvariant zeroAllowanceOnAssets(e.msg.sender);

    require ( (receiver != owner => balanceOf(owner) + balanceOf(receiver) <= totalSupply())  && 
                balanceOf(receiver) <= totalSupply() &&
                balanceOf(owner) <= totalSupply());
}

// A helper functions to set the receiver 
function callReceiverFunctions(method f, env e, address receiver) {
    uint256 amount;
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, amount, receiver);
    } else if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, amount, receiver);
    } else if (f.selector == sig:withdraw(uint256,address,address).selector) {
        address owner;
        withdraw(e, amount, receiver, owner);
    } else if (f.selector == sig:redeem(uint256,address,address).selector) {
        address owner;
        redeem(e, amount, receiver, owner);
    } else {
        calldataarg args;
        f(e, args);
    }
}

function callContributionMethods(env e, method f, uint256 assets, uint256 shares, address receiver) {
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, assets, receiver);
    }
    else if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
}

function callReclaimingMethods(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    else if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    }
}

function callFunctionsWithReceiverAndOwner(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    else if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    } 
    else if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, assets, receiver);
    }
    else if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
    else if (f.selector == sig:transferFrom(address,address,uint256).selector) {
        transferFrom(e, owner, receiver, shares);
    }
    else {
        calldataarg args;
        f(e, args);
    }
}

