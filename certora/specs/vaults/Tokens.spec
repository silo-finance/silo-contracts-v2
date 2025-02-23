// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

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

function summaryDeposit(address id, uint256 assets, address receiver) returns uint256 {
    assert assets != 0;
    assert receiver == currentContract;
    require id != currentContract;

    requireInvariant supplyCapIsEnabled(id);
    requireInvariant enabledHasConsistentAsset(id);
    
    ERC20.safeTransferFrom(asset(), currentContract, id, assets);
    return vault0.getConvertToShares(id, assets);
}

function summaryWithdraw(address id, uint256 assets, address receiver, address spender) returns uint256 {
    assert receiver == currentContract;
    assert spender == currentContract;
    require id != currentContract;

    // Safe require because it is verified in MarketInteractions.
    require config_(id).enabled;
    requireInvariant enabledHasConsistentAsset(id);

    address asset = asset();

    ERC20.safeTransferFrom(asset, id, currentContract, assets);

    return vault0.getConvertToShares(id, assets);
}

function summaryRedeem(address id, uint256 shares, address receiver, address spender) returns uint256 {
    assert receiver == currentContract;
    assert spender == currentContract;
    require id != currentContract;

    // Safe require because it is verified in MarketInteractions.
    require config_(id).enabled;
    requireInvariant enabledHasConsistentAsset(id);

    address asset = asset();
    uint256 assets = vault0.getConvertToAssets(id, shares);

    ERC20.safeTransferFrom(asset, id, currentContract, assets);

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

