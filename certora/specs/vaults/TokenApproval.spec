// SPDX-License-Identifier: GPL-2.0-or-later
import "ConsistentState.spec";

using ERC20Helper as ERC20;

methods {
    function ERC20.balanceOf(address, address) external returns(uint256) envfree;
    function ERC20.totalSupply(address) external returns(uint256) envfree;
    function ERC20.safeTransferFrom(address, address, address, uint256) external envfree;
    function ERC20.allowance(address, address, address) external returns (uint256) envfree;
    
    function _.allowance(address owner, address spender) external => DISPATCHER(true);
    
    //function _.approve(address spender, uint256 value) external => DISPATCHER(true);
    function _.deposit(uint256, address) external => NONDET;
    function _.mint(uint256, address) external => NONDET;
    function _.withdraw(uint256,address,address) external => NONDET;
    function _.redeem(uint256 shares, address receiver, address owner) external => NONDET;
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    //function _.asset() external => DISPATCHER(true);
    //function _.transfer(address,uint256) external => DISPATCHER(true);
    //function _.maxDeposit(address) external => DISPATCHER(true);
    //function _.maxWithdraw(address) external => DISPATCHER(true);
    //function _.totalSupply() external => DISPATCHER(true);

   function _.safeTransfer(address token, address to, uint256 value) internal
        => cvlTransfer(token, to, value) expect (bool, bytes memory);

    function _.safeTransferFrom(address token, address from, address to, uint256 value) internal
        => cvlTransferFrom(token, from, to, value) expect (bool, bytes memory);
    
    function _.forceApprove(address token, address spender, uint256 amount) internal
        => cvlForceApprove(token, spender, amount) expect void;
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

function cvlForceApprove(address token, address spender, uint256 amount) {
    env e;
    require e.msg.sender == currentContract;
    require e.msg.value == 0;
    token.approve(e, spender, amount);
}

invariant noCapThenNoApproval(address market)
    config_(market).cap == 0 => ERC20.allowance(asset(), currentContract, market) == 0;

// https://prover.certora.com/output/6893/ab48156c65684c99bab2436cdbde58db/?anonymousKey=05f0b5ed6865e1386cefacf72bd2345af0c919b0
invariant notInWithdrawQThenNoApproval(address market)
    withdrawRank(market) == 0 => ERC20.allowance(asset(), currentContract, market) == 0
    {
    preserved with (env e) {
        require e.msg.sender != currentContract;
        requireInvariant pendingCapIsUint184(market);
        requireInvariant enabledHasPositiveRank(market);
        requireInvariant supplyCapIsEnabled(market);
        requireInvariant withdrawRankCorrect(market);
        requireInvariant noBadPendingCap(market);
        requireInvariant noCapThenNoApproval(market);
    }
}

// new features
// internal balances tracking
// write rules for this. whoCanIncrease.., decrease, include also in integrity rules
// also for
// balanceTracker and other
