// SPDX-License-Identifier: GPL-2.0-or-later
import "Tokens.spec";

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

}
 
function cvlTransfer(address token, address to, uint256 value) returns (bool, bytes) {
    env e;
    require e.msg.sender == currentContract;
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

/*
 * @title Only certain methods may decrease balance of the Vault
 * @status Verified
 */
rule onlySpecicifiedMethodsCanDecreaseMarketBalance(env e, method f, address market)
{ 
    require e.msg.sender != currentContract;
    address asset = asset();

    // otherwise deposit overflows and decreases the balance
    require ERC20.balanceOf(asset, currentContract) + 
        ERC20.balanceOf(asset, e.msg.sender) <= ERC20.totalSupply(asset);

    uint balanceBefore = ERC20.balanceOf(asset, currentContract);
    calldataarg args;
    f(e, args);
    bool isAllowedToDecreaseBalance = 
        (f.selector == sig:withdraw(uint256, address, address).selector ||
        f.selector == sig:redeem(uint256, address, address).selector ||
        f.selector == sig:reallocate(SiloVaultHarness.MarketAllocation[]).selector);
    uint balanceAfter = ERC20.balanceOf(asset, currentContract);
    assert balanceAfter < balanceBefore => isAllowedToDecreaseBalance;
}


/////////////////////
//  IN DEVELOPMENT //
/////////////////////

persistent ghost previewRedeemGhost(uint256) returns uint256 {       
    axiom forall uint256 x. forall uint256 y. x < y => previewRedeemGhost(x) <= previewRedeemGhost(y);
}

function previewRedeem_cvl(uint256 _shares) returns uint256
{
    return previewRedeemGhost(_shares);
}

function requireConsistentState(address user, address token)
{
    require token != user;

    require require_uint256(ERC20.balanceOf(token, user) + ERC20.balanceOf(token, siloVaultHarness))
        <= ERC20.totalSupply(token);
    require (supplyQLength() > 0) => (
        supplyQGetAt(0) != siloVaultHarness &&
        require_uint256(ERC20.balanceOf(token, user) + 
        ERC20.balanceOf(token, siloVaultHarness) +
        ERC20.balanceOf(token, supplyQGetAt(0))) <= ERC20.totalSupply(token));

    require (supplyQLength() > 1) => (
        supplyQGetAt(0) != siloVaultHarness &&
        supplyQGetAt(1) != siloVaultHarness &&
        require_uint256(ERC20.balanceOf(token, user) + 
        ERC20.balanceOf(token, siloVaultHarness) +
        ERC20.balanceOf(token, supplyQGetAt(0)) +
        ERC20.balanceOf(token, supplyQGetAt(1))) <= ERC20.totalSupply(token));

    require (withdrawQLength() > 0) => (
        withdrawQGetAt(0) != siloVaultHarness &&
        require_uint256(ERC20.balanceOf(token, user) + 
        ERC20.balanceOf(token, siloVaultHarness) +
        ERC20.balanceOf(token, withdrawQGetAt(0))) <= ERC20.totalSupply(token));

    require (withdrawQLength() > 1) => (
        withdrawQGetAt(0) != siloVaultHarness &&
        withdrawQGetAt(1) != siloVaultHarness &&
        require_uint256(ERC20.balanceOf(token, user) + 
        ERC20.balanceOf(token, siloVaultHarness) +
        ERC20.balanceOf(token, withdrawQGetAt(0)) +
        ERC20.balanceOf(token, withdrawQGetAt(1))) <= ERC20.totalSupply(token));
}

rule sharePriceDoesntDecrease(env e, method f)
    filtered { f -> !f.isView }
{
    // address receiver;
    requireConsistentState(e.msg.sender, siloVaultHarness);
    requireConsistentState(e.msg.sender, asset());

    uint256 totalAssets_pre = totalAssets(e); //lastTotalAssets(e); 
    uint256 totalShares_pre = totalSupply(e);
    calldataarg args;
    f(e, args);
    uint256 totalAssets_post = lastTotalAssets(e); // totalAssets(e);
    uint256 totalShares_post = totalSupply(e);

    // totalAssets_pre / totalShares_pre  <= totalAssets_post / totalShares_post
    assert totalAssets_pre * totalShares_post  <= totalAssets_post * totalShares_pre;
    
}

rule whoCanDecreaseTotalAssets(env e, method f)
    filtered { f -> !f.isView }
{
    // address receiver;
    requireConsistentState(e.msg.sender, siloVaultHarness);
    requireConsistentState(e.msg.sender, asset());

    uint256 totalAssets_pre = totalAssets(e); //lastTotalAssets(e); 
    //uint256 totalShares_pre = totalSupply(e);
    calldataarg args;
    f(e, args);
    uint256 totalAssets_post = lastTotalAssets(e); // totalAssets(e);
    //uint256 totalShares_post = totalSupply(e);

    // totalAssets_pre / totalShares_pre  <= totalAssets_post / totalShares_post
    //assert totalAssets_pre * totalShares_post  <= totalAssets_post * totalShares_pre;
    assert totalAssets_post >= totalAssets_pre;
}

rule totalAssets_lastTotalAssets(env e, method f)
    filtered { f -> !f.isView }
{
    // address receiver;
    requireConsistentState(e.msg.sender, siloVaultHarness);
    requireConsistentState(e.msg.sender, asset());

    uint256 totalAssets_pre = totalAssets(e); //lastTotalAssets(e); 
    uint256 lasttotalAssets_pre = lastTotalAssets(e); 
    //uint256 totalShares_pre = totalSupply(e);
    calldataarg args;
    f(e, args);
    uint256 totalAssets_post = totalAssets(e); //lastTotalAssets(e); 
    uint256 lasttotalAssets_post = lastTotalAssets(e); 
    
    assert totalAssets_pre == lasttotalAssets_pre =>
        totalAssets_post == lasttotalAssets_post;
}
