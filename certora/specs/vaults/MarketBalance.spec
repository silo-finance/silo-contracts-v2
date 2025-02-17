// SPDX-License-Identifier: GPL-2.0-or-later
import "Tokens.spec";

methods {

    function ERC20.balanceOf(address, address) external returns(uint256) envfree;
    function ERC20.totalSupply(address) external returns(uint256) envfree;
    function ERC20.safeTransferFrom(address, address, address, uint256) external envfree;
    function ERC20.allowance(address, address, address) external returns (uint256) envfree;
    
    function _.allowance(address owner, address spender) external => DISPATCHER(true);
    function vault0.getTotalSupply(address) external returns(uint256) envfree;

    //function _.mint(uint256, address) external => DISPATCHER(true);
    
    function _.safeTransfer(address token, address to, uint256 value) internal
        => cvlTransfer(token, to, value) expect (bool, bytes memory);

    function _.safeTransferFrom(address token, address from, address to, uint256 value) internal
        => cvlTransferFrom(token, from, to, value) expect (bool, bytes memory);
    
    function _.forceApprove(address, address, uint256) internal => NONDET;
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

// https://prover.certora.com/output/6893/4c8aa7184e9940f7afd740b15e4889ed/?anonymousKey=949c6dfcb5ef3bfede0b9c97d4d23e8bf9307aae
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
