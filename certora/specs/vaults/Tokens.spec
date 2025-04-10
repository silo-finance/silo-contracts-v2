// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

using SiloVaultHarness as siloVaultHarness;

methods {
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);

    function _.deposit(uint256 assets, address receiver) external => summaryDeposit(calledContract, assets, receiver) expect (uint256) ALL;
    function _.withdraw(uint256 assets, address receiver, address spender) external => summaryWithdraw(calledContract, assets, receiver, spender) expect (uint256) ALL;
    function _.redeem(uint256 shares, address receiver, address spender) external => summaryRedeem(calledContract, shares, receiver, spender) expect (uint256) ALL;
    
    function vault0.getConvertToShares(address vault, uint256 assets) external returns(uint256) envfree;
    function vault0.getConvertToAssets(address vault, uint256 shares) external returns(uint256) envfree;
}

function summaryDeposit(address market, uint256 assets, address receiver) returns uint256 {
    assert assets != 0;
    assert receiver == currentContract;
    require market != currentContract;

    requireInvariant supplyCapIsEnabled(market);
    requireInvariant enabledHasConsistentAsset(market);
    
    ERC20.safeTransferFrom(asset(), currentContract, market, assets);
    return vault0.getConvertToShares(market, assets);
}

function summaryWithdraw(address market, uint256 assets, address receiver, address spender) returns uint256 {
    assert receiver == currentContract;
    assert spender == currentContract;
    require market != currentContract;

    // Safe require because it is verified in MarketInteractions.
    require config_(market).enabled;
    requireInvariant enabledHasConsistentAsset(market);

    address asset = asset();

    ERC20.safeTransferFrom(asset, market, currentContract, assets);

    return vault0.getConvertToShares(market, assets);
}

function summaryRedeem(address market, uint256 shares, address receiver, address spender) returns uint256 {
    assert receiver == currentContract;
    assert spender == currentContract;
    require market != currentContract;

    // Safe require because it is verified in MarketInteractions.
    require config_(market).enabled;
    requireInvariant enabledHasConsistentAsset(market);

    address asset = asset();
    uint256 assets = vault0.getConvertToAssets(market, shares);

    ERC20.safeTransferFrom(asset, market, currentContract, assets);

    return assets;
}

// Check balances change on deposit.
rule depositTokenChange(env e, uint256 assets, address receiver) {
    address asset = asset();

    // Trick to require that all the following addresses are different.
    require asset == 0x11;
    require currentContract == 0x12;
    require e.msg.sender == 0x13;

    //this together with loop_iter == 2 ensures that the markets don't call "deposit" on the Vault
    require supplyQGetAt(0) != e.msg.sender;
    require supplyQGetAt(1) != e.msg.sender;

    require ERC20.balanceOf(asset, currentContract) + 
        ERC20.balanceOf(asset, e.msg.sender) <= ERC20.totalSupply(asset);

    uint256 balanceVaultBefore = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderBefore = ERC20.balanceOf(asset, e.msg.sender);
    deposit(e, assets, receiver);
    uint256 balanceVaultAfter = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderAfter = ERC20.balanceOf(asset, e.msg.sender);

    require balanceSenderBefore > balanceSenderAfter;

    assert balanceVaultAfter == balanceVaultBefore;
    assert assert_uint256(balanceSenderBefore - balanceSenderAfter) == assets;
}

// Check balance changes on withdraw.
rule withdrawTokenChange(env e, uint256 assets, address receiver, address owner) {
    address asset = asset();

    // Trick to require that all the following addresses are different.
    require asset == 0x11;
    require currentContract == 0x12;
    require receiver == 0x13;

    //this togehter with loop_iter == 2 ensures that the markets don't withdraw from the Vault
    require withdrawQGetAt(0) != e.msg.sender;
    require withdrawQGetAt(1) != e.msg.sender;

    //with loop_iter = 2 this shows whether the reveiver is among the markets in the WithdrawQ
    //(the caller of withdraw may set any receiver address so shouldn't discard this option)
    bool isReceiverAVault = receiver == withdrawQGetAt(0) || receiver == withdrawQGetAt(1);

    require ERC20.balanceOf(asset, currentContract) + 
        ERC20.balanceOf(asset, e.msg.sender) <= ERC20.totalSupply(asset);
    require ERC20.balanceOf(asset, currentContract) + 
        ERC20.balanceOf(asset, receiver) <= ERC20.totalSupply(asset);

    uint256 balanceVaultBefore = ERC20.balanceOf(asset, currentContract);
    uint256 balanceReceiverBefore = ERC20.balanceOf(asset, receiver);
    withdraw(e, assets, receiver, owner);
    uint256 balanceVaultAfter = ERC20.balanceOf(asset, currentContract);
    uint256 balanceReceiverAfter = ERC20.balanceOf(asset, receiver);

    // no overflow happened. 
    // Another way to ensure this is to require sum_i{balanceOf(withdrawQ[i])} + balanceOf(receiver) <= totalSupply
    require balanceReceiverAfter > balanceReceiverBefore;

    assert balanceVaultAfter == balanceVaultBefore;

    // the balance of receiver must change unless the receiver is one of the markets in the queue
    assert !isReceiverAVault => assert_uint256(balanceReceiverAfter - balanceReceiverBefore) == assets;
}

// Check that balances do not change on reallocate.
rule reallocateTokenChange(env e, SiloVaultHarness.MarketAllocation[] allocations) {
    address asset = asset();

    // Trick to require that all the following addresses are different.
    require asset == 0x11;
    require currentContract == 0x12;
    require e.msg.sender == 0x13;

    // this together with loop_iter = 2 ensures that markets in the withdrawQ are not Allocators and not SiloVault
    // based on enabledIsInWithdrawQueue
    require config_(allocations[0].market).enabled => allocations[0].market != e.msg.sender;
    require config_(allocations[1].market).enabled => allocations[1].market != e.msg.sender;
    require config_(allocations[0].market).enabled => allocations[0].market != currentContract;
    require config_(allocations[1].market).enabled => allocations[1].market != currentContract;

    uint256 balanceVaultBefore = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderBefore = ERC20.balanceOf(asset, e.msg.sender);
    reallocate(e, allocations);

    uint256 balanceVaultAfter = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderAfter = ERC20.balanceOf(asset, e.msg.sender);

    assert balanceVaultAfter == balanceVaultBefore;
    assert balanceSenderAfter == balanceSenderBefore;
}

ghost mathint balanceTrackerChange;
ghost mathint vaultBalanceIncrease;
ghost mathint vaultBalanceDecrease;

hook Sstore SiloVaultHarness.balanceTracker[KEY address market] uint256 newBalance (uint256 oldBalance) {
    balanceTrackerChange = balanceTrackerChange + newBalance - oldBalance;
}

// we just want to track the increases and decreases of SiloVault's balance
hook Sstore Token0._balances[KEY address user] uint256 newBalance (uint256 oldBalance) {
    if (user == siloVaultHarness)
    {
        if (newBalance > oldBalance) vaultBalanceIncrease = vaultBalanceIncrease + newBalance - oldBalance;
        if (newBalance < oldBalance) vaultBalanceDecrease = vaultBalanceDecrease - newBalance + oldBalance;
    }
}

// After calling any external function, if the sum of deltas of all balanceTracker[market] 
// (sum of balanceTracker[market] before minus sum of balanceTracker[market] after) 
// is negative then balanceOf(asset, SiloVault) must increase by at least sumDelta (before the funds are sent to the receiver). 
// This should hold for every function except syncBalanceTracker() 
rule balanceTrackerDecreasesThenBalanceIncreases(env e, method f)
    filtered { f -> !f.isView && f.selector != sig:syncBalanceTracker(address,uint256,bool).selector }
{
    require e.msg.sender != vault0;
    require balanceTrackerChange == 0;
    require vaultBalanceIncrease == 0;
    require vaultBalanceDecrease == 0;
    address asset = asset();
    calldataarg args;
    f(e, args);

    // if the balanceTracker goes down, the SiloVault really received the funds
    assert balanceTrackerChange < 0 => vaultBalanceIncrease >= -balanceTrackerChange;    
}

// Shows that SiloVault doesn't hoard the tokens, i.e., that it sends outs everything that it receives.
rule vaultBalanceNeutral(env e, method f)
    filtered { f -> !f.isView }
{
    require e.msg.sender != siloVaultHarness;
    require e.msg.sender != vault0;
    address receiver;
    require receiver != siloVaultHarness;
    address asset = asset();
    uint256 balance_pre = ERC20.balanceOf(asset, siloVaultHarness);
    dispatchCall(e, f, receiver);
    uint256 balance_post = ERC20.balanceOf(asset, siloVaultHarness);
    
    assert balance_pre == balance_post; 
}

// a manual dispatcher that allows to constrain the receiver
function dispatchCall(env e, method f, address receiver)
{
    if (f.selector == sig:withdraw(uint256, address, address).selector)
    {
        uint256 _assets; address _owner;
        withdraw(e, _assets, receiver, _owner);
    }
    else if (f.selector == sig:redeem(uint256, address, address).selector)
    {
        uint256 _shares; address _owner;
        redeem(e, _shares, receiver, _owner);
    }
    else if (f.selector == sig:deposit(uint256, address).selector)
    {
        uint256 _assets;
        deposit(e, _assets, receiver);
    }
    else if (f.selector == sig:mint(uint256, address).selector)
    {
        uint256 _shares;
        mint(e, _shares, receiver);
    }
    else
    {
        calldataarg args;
        f(e, args);
    }
}