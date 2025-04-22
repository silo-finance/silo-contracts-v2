// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

using ERC20Helper as ERC20Helper;
using SiloVaultHarness as siloVaultHarness;
using Vault1 as vault1;

methods {

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

    return mulDiv_cvl(shares, totalAssets, totalShares);
}

function convertToShares_cvl(uint256 assets, uint256 totalAssets, uint256 totalShares) returns uint256
{
    require assets <= totalAssets;
    if (assets == 0) return 0;
    if (totalShares == 0) return 0;

    return mulDiv_cvl(assets, totalShares, totalAssets);
}

function previewRedeem_cvl(address market, uint256 shares) returns uint256
{
    return convertToAssets_cvl(shares, currentTotalAssets[market], currentTotalShares[market]);
}

function deposit_cvl(address caller, address market, uint256 assets, address receiver) returns uint256
{
    // we assume that the inner markets are resistant to inflation attacks
    require currentTotalAssets[market] <= currentTotalShares[market];
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
    require currentTotalAssets[market] <= currentTotalShares[market];
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
    require currentTotalAssets[market] <= currentTotalShares[market];
    uint assets = convertToAssets_cvl(shares, currentTotalAssets[market], currentTotalShares[market]);
    cvlTransferFrom(market, caller, market, shares);
    cvlTransferFrom(tokenByMarket[market], market, receiver, assets);
    currentTotalAssets[market] = require_uint256(currentTotalAssets[market] - assets);
    currentTotalShares[market] = require_uint256(currentTotalShares[market] - shares);
    return assets;
}

function setupVaults()
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
    setupVaults();
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

    assert totalAssets_pre >= totalShares_pre => totalAssets_post >= totalShares_post;    
}

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
    setupVaults();
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
        (totalAssets_post == 0 <=> totalShares_post == 0);    
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
