// SPDX-License-Identifier: GPL-2.0-or-later
import "Tokens.spec";
using ERC20Helper as ERC20Helper;

methods {

    function ERC20.balanceOf(address, address) external returns(uint256) envfree;
    function ERC20.totalSupply(address) external returns(uint256) envfree;
    function ERC20.safeTransferFrom(address, address, address, uint256) external envfree;
    function ERC20.allowance(address, address, address) external returns (uint256) envfree;
    
    function _.allowance(address owner, address spender) external => DISPATCHER(true);
    function market0.getTotalSupply(address) external returns(uint256) envfree;

    //function _.mint(uint256, address) external => DISPATCHER(true);
    
    function _.safeTransfer(address token, address to, uint256 value) internal
        => cvlTransfer(token, to, value) expect (bool, bytes memory);

    function _.safeTransferFrom(address token, address from, address to, uint256 value) internal
        => cvlTransferFrom(token, from, to, value) expect (bool, bytes memory);
    
    function _.forceApprove(address, address, uint256) internal => NONDET;

    // methods on markets
    function _.previewRedeem(uint256 shares) external => previewRedeem_cvl(shares) expect (uint256);

    //
    function approve(address,uint256) external returns bool;
    function deposit(uint256,address) external;
    function mint(uint256,address) external;
    function withdraw(uint256,address,address) external;
    function redeem(uint256,address,address) external;

    function totalAssets() external returns uint256 envfree;
    function convertToShares(uint256) external returns uint256 envfree;
    function convertToAssets(uint256) external returns uint256 envfree;
    function previewDeposit(uint256) external returns uint256 envfree;
    function previewMint(uint256) external returns uint256 envfree;
    function previewWithdraw(uint256) external returns uint256 envfree;
    function previewRedeem(uint256) external returns uint256 envfree;

    function maxDeposit(address) external returns uint256 envfree;
    function maxMint(address) external returns uint256 envfree;
    function maxWithdraw(address) external returns uint256 envfree;
    function maxRedeem(address) external returns uint256 envfree;

    function permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external;
    function totalSupply() external returns uint256 envfree;
    function balanceOf(address) external returns uint256 envfree;
    function nonces(address) external returns uint256 envfree;
}
 
function cvlTransfer(address token, address to, uint256 value) returns (bool, bytes) {
    env e;
    require e.msg.sender == currentContract;
    require e.msg.value == 0;
    require e.msg.value == 0;
    token.transfer(e, to, value);
    bool success;
    bytes resBytes;
    return (success, resBytes);
}

function cvlTransferFrom(address token, address from, address to, uint256 value) returns (bool, bytes) {
    env e;
    require e.msg.sender == currentContract;
    require e.msg.value == 0;
    token.transferFrom(e, from, to, value);
    bool success;
    bytes resBytes;
    return (success, resBytes);
}

persistent ghost previewRedeemGhost(uint256) returns uint256 {     
    axiom previewRedeemGhost(0) == 0;   
    axiom forall uint256 x. forall uint256 y. x < y => previewRedeemGhost(x) <= previewRedeemGhost(y);
}

ghost uint256 totalAssetsSupplied;


function previewRedeem_cvl(uint256 _shares) returns uint256
{
    return previewRedeemGhost(_shares);
}


// rule sharePriceDoesntDecrease(env e, method f)
//     filtered { f -> !f.isView }
// {
//     // address receiver;
//     requireConsistentState(e.msg.sender, siloVaultHarness);
//     requireConsistentState(e.msg.sender, asset());

//     uint256 totalAssets_pre = totalAssets(e); //lastTotalAssets(e); 
//     uint256 totalShares_pre = totalSupply(e);
//     calldataarg args;
//     f(e, args);
//     uint256 totalAssets_post = lastTotalAssets(e); // totalAssets(e);
//     uint256 totalShares_post = totalSupply(e);

//     // totalAssets_pre / totalShares_pre  <= totalAssets_post / totalShares_post
//     assert totalAssets_pre * totalShares_post  <= totalAssets_post * totalShares_pre;
    
// }

////////////// from examples


////////////////////////////////////////////////////////////////////////////////
////           Dynamic Calls                                               /////
////////////////////////////////////////////////////////////////////////////////

persistent ghost bool callMade;
persistent ghost bool delegatecallMade;


hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (addr != currentContract.asset()) {
        callMade = true;
    }
}

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    delegatecallMade = true;
}

/*
This rule proves there are no instances in the code in which the user can act as the contract.
By proving this rule we can safely assume in our spec that e.msg.sender != currentContract.
*/
rule noDynamicCalls {
    method f;
    env e;
    calldataarg args;

    require !callMade && !delegatecallMade;

    f(e, args);

    assert !callMade && !delegatecallMade;
}

////////////////////////////////////////////////////////////////////////////////
////           #  asset To shares mathematical properties                  /////
////////////////////////////////////////////////////////////////////////////////

rule conversionOfZero {
    uint256 convertZeroShares = convertToAssets(0);
    uint256 convertZeroAssets = convertToShares(0);

    assert convertZeroShares == 0,
        "converting zero shares must return zero assets";
    assert convertZeroAssets == 0,
        "converting zero assets must return zero shares";
}

rule convertToAssetsWeakAdditivity() {
    uint256 sharesA; uint256 sharesB;
    require sharesA + sharesB < max_uint128
         && convertToAssets(sharesA) + convertToAssets(sharesB) < max_uint256
         && convertToAssets(require_uint256(sharesA + sharesB)) < max_uint256;
    assert convertToAssets(sharesA) + convertToAssets(sharesB) <= convertToAssets(require_uint256(sharesA + sharesB)),
        "converting sharesA and sharesB to assets then summing them must yield a smaller or equal result to summing them then converting";
}

rule convertToSharesWeakAdditivity() {
    uint256 assetsA; uint256 assetsB;
    require assetsA + assetsB < max_uint128
         && convertToAssets(assetsA) + convertToAssets(assetsB) < max_uint256
         && convertToAssets(require_uint256(assetsA + assetsB)) < max_uint256;
    assert convertToAssets(assetsA) + convertToAssets(assetsB) <= convertToAssets(require_uint256(assetsA + assetsB)),
        "converting assetsA and assetsB to shares then summing them must yield a smaller or equal result to summing them then converting";
}

rule conversionWeakMonotonicity {
    uint256 smallerShares; uint256 largerShares;
    uint256 smallerAssets; uint256 largerAssets;

    assert smallerShares < largerShares => convertToAssets(smallerShares) <= convertToAssets(largerShares),
        "converting more shares must yield equal or greater assets";
    assert smallerAssets < largerAssets => convertToShares(smallerAssets) <= convertToShares(largerAssets),
        "converting more assets must yield equal or greater shares";
}

rule conversionWeakIntegrity() {
    uint256 sharesOrAssets;
    assert convertToShares(convertToAssets(sharesOrAssets)) <= sharesOrAssets,
        "converting shares to assets then back to shares must return shares less than or equal to the original amount";
    assert convertToAssets(convertToShares(sharesOrAssets)) <= sharesOrAssets,
        "converting assets to shares then back to assets must return assets less than or equal to the original amount";
}

rule convertToCorrectness(uint256 amount, uint256 shares)
{
    assert amount >= convertToAssets(convertToShares(amount));
    assert shares >= convertToShares(convertToAssets(shares));
}


////////////////////////////////////////////////////////////////////////////////
////                   #    Unit Test                                      /////
////////////////////////////////////////////////////////////////////////////////

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


rule zeroDepositZeroShares(uint assets, address receiver)
{
    env e;
    
    uint shares = deposit(e,assets, receiver);

    assert shares == 0 <=> assets == 0;
}

////////////////////////////////////////////////////////////////////////////////
////                    #    Valid State                                   /////
////////////////////////////////////////////////////////////////////////////////

invariant assetsMoreThanSupply()
    totalAssets() >= totalSupply()
    {
        preserved with (env e) {
            require e.msg.sender != currentContract;
            address any;
            safeAssumptions(e, any , e.msg.sender);
        }
    }

function userAssets(address user) returns uint256
{
    return ERC20Helper.balanceOf(asset(), user);
}

invariant noAssetsIfNoSupply() 
    (userAssets(currentContract) == 0 => totalSupply() == 0) &&
    (totalAssets() == 0 => (totalSupply() == 0)) {
        preserved with (env e) {
            address any;
            safeAssumptions(e, any, e.msg.sender);
        }
    }

invariant noSupplyIfNoAssets()
    noSupplyIfNoAssetsDef()     // see defition in "helpers and miscellaneous" section
    {
        preserved with (env e) {
            safeAssumptions(e, _, e.msg.sender);
        }
    }

////////////////////////////////////////////////////////////////////////////////
////                    #     State Transition                             /////
////////////////////////////////////////////////////////////////////////////////


rule totalsMonotonicity() {
    method f; env e; calldataarg args;
    require e.msg.sender != currentContract; 
    uint256 totalSupplyBefore = totalSupply();
    uint256 totalAssetsBefore = totalAssets();
    address receiver;
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

rule underlyingCannotChange() {
    address originalAsset = asset();

    method f; env e; calldataarg args;
    f(e, args);

    address newAsset = asset();

    assert originalAsset == newAsset,
        "the underlying asset of a contract must not change";
}

////////////////////////////////////////////////////////////////////////////////
////                    #   High Level                                    /////
////////////////////////////////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////////////////////////
////                       #   Risk Analysis                           /////////
////////////////////////////////////////////////////////////////////////////////

invariant vaultSolvency()
    totalAssets() >= totalSupply() && userAssets(currentContract) >= totalAssets()  {
      preserved with(env e){
            requireInvariant zeroAllowanceOnAssets(e.msg.sender);
            //requireInvariant totalSupplyIsSumOfBalances();
            require e.msg.sender != currentContract;
            require currentContract != asset(); 
        }
    }



rule redeemingAllValidity() { 
    address owner; 
    uint256 shares; require shares == balanceOf(owner);
    
    env e; safeAssumptions(e, _, owner);
    redeem(e, shares, _, owner);
    uint256 ownerBalanceAfter = balanceOf(owner);
    assert ownerBalanceAfter == 0;
}

invariant zeroAllowanceOnAssets(address user)
    ERC20Helper.allowance(asset(), currentContract, user) == 0 {
        preserved with(env e) {
            require e.msg.sender != currentContract;
        }
    }

////////////////////////////////////////////////////////////////////////////////
////               # stakeholder properties  (Risk Analysis )         //////////
////////////////////////////////////////////////////////////////////////////////

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

    require previewDeposit(assets) + balanceOf(receiver) <= max_uint256; // safe assumption because call to _mint will revert if totalSupply += amount overflows
    require shares + balanceOf(receiver) <= max_uint256; // same as above

    safeAssumptions(e, contributor, receiver);

    uint256 contributorAssetsBefore = userAssets(contributor);
    uint256 receiverSharesBefore = balanceOf(receiver);

    callContributionMethods(e, f, assets, shares, receiver);

    uint256 contributorAssetsAfter = userAssets(contributor);
    uint256 receiverSharesAfter = balanceOf(receiver);

    assert contributorAssetsBefore > contributorAssetsAfter <=> receiverSharesBefore < receiverSharesAfter,
        "a contributor's assets must decrease if and only if the receiver's shares increase";
}

rule onlyContributionMethodsReduceAssets(method f) {
    address user; require user != currentContract;
    uint256 userAssetsBefore = userAssets(user);

    env e; 
    calldataarg args;
    safeAssumptions(e, user, _);

    f(e, args);

    uint256 userAssetsAfter = userAssets(user);

    assert userAssetsBefore > userAssetsAfter =>
        (f.selector == sig:deposit(uint256,address).selector ||
         f.selector == sig:mint(uint256,address).selector),
        "a user's assets must not go down except on calls to contribution methods or calls directly to the asset.";
}

rule reclaimingProducesAssets(method f)
filtered {
    f -> f.selector == sig:withdraw(uint256,address,address).selector
      || f.selector == sig:redeem(uint256,address,address).selector
}
{
    env e; uint256 assets; uint256 shares;
    address receiver; address owner;
    require currentContract != e.msg.sender
         && currentContract != receiver
         && currentContract != owner;

    safeAssumptions(e, receiver, owner);

    uint256 ownerSharesBefore = balanceOf(owner);
    uint256 receiverAssetsBefore = userAssets(receiver);

    callReclaimingMethods(e, f, assets, shares, receiver, owner);

    uint256 ownerSharesAfter = balanceOf(owner);
    uint256 receiverAssetsAfter = userAssets(receiver);

    assert ownerSharesBefore > ownerSharesAfter <=> receiverAssetsBefore < receiverAssetsAfter,
        "an owner's shares must decrease if and only if the receiver's assets increase";
}



////////////////////////////////////////////////////////////////////////////////
////                        # helpers and miscellaneous                //////////
////////////////////////////////////////////////////////////////////////////////

definition noSupplyIfNoAssetsDef() returns bool = 
    ( userAssets(currentContract) == 0 => totalSupply() == 0 ) &&
    ( totalAssets() == 0 <=> ( totalSupply() == 0 ));


function safeAssumptions(env e, address receiver, address owner) {
    require currentContract != asset(); // Although this is not disallowed, we assume the contract's underlying asset is not the contract itself
    //requireInvariant totalSupplyIsSumOfBalances();
    requireInvariant vaultSolvency();
    requireInvariant noAssetsIfNoSupply();
    requireInvariant noSupplyIfNoAssets();
    requireInvariant assetsMoreThanSupply();

    require e.msg.sender != currentContract;  // This is proved by rule noDynamicCalls
    requireInvariant zeroAllowanceOnAssets(e.msg.sender);

    require ( (receiver != owner => balanceOf(owner) + balanceOf(receiver) <= totalSupply())  && 
                balanceOf(receiver) <= totalSupply() &&
                balanceOf(owner) <= totalSupply());
}


// A helper function to set the receiver 
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
    if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
}

function callReclaimingMethods(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    }
}

function callFunctionsWithReceiverAndOwner(env e, method f, uint256 assets, uint256 shares, address receiver, address owner) {
    if (f.selector == sig:withdraw(uint256,address,address).selector) {
        withdraw(e, assets, receiver, owner);
    }
    if (f.selector == sig:redeem(uint256,address,address).selector) {
        redeem(e, shares, receiver, owner);
    } 
    if (f.selector == sig:deposit(uint256,address).selector) {
        deposit(e, assets, receiver);
    }
    if (f.selector == sig:mint(uint256,address).selector) {
        mint(e, shares, receiver);
    }
    if (f.selector == sig:transferFrom(address,address,uint256).selector) {
        transferFrom(e, owner, receiver, shares);
    }
    else {
        calldataarg args;
        f(e, args);
    }
}