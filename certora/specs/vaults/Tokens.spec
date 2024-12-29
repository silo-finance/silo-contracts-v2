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

    requireInvariant supplyCapIsEnabled(id);
    requireInvariant enabledHasConsistentAsset(id);
    
    ERC20.safeTransferFrom(asset(), currentContract, id, assets);
    return vault0.getConvertToShares(id, assets);
}

function summaryWithdraw(address id, uint256 assets, address receiver, address spender) returns uint256 {
    assert receiver == currentContract;
    assert spender == currentContract;

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

    // Safe require because it is verified in MarketInteractions.
    require config_(id).enabled;
    requireInvariant enabledHasConsistentAsset(id);

    address asset = asset();
    uint256 assets = vault0.getConvertToAssets(id, shares);

    ERC20.safeTransferFrom(asset, id, currentContract, assets);

    return assets;
}

// Check balances change on deposit.
rule depositTokenChange(env e, uint256 assets, address receiver, address id) {
    address asset = asset();

    // Trick to require that all the following addresses are different.
    require asset == 0x11;
    require currentContract == 0x12;
    require e.msg.sender == 0x13;
    require id == 0x14;

    uint256 balanceMorphoBefore = ERC20.balanceOf(asset, id);
    uint256 balanceMetaMorphoBefore = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderBefore = ERC20.balanceOf(asset, e.msg.sender);
    deposit(e, assets, receiver);
    uint256 balanceMorphoAfter = ERC20.balanceOf(asset, id);
    uint256 balanceMetaMorphoAfter = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderAfter = ERC20.balanceOf(asset, e.msg.sender);

    require balanceMorphoAfter > balanceMorphoBefore;
    require balanceSenderBefore > balanceSenderAfter;

    assert assert_uint256(balanceMorphoAfter - balanceMorphoBefore) == assets;
    assert balanceMetaMorphoAfter == balanceMetaMorphoBefore;
    assert assert_uint256(balanceSenderBefore - balanceSenderAfter) == assets;
}

// Check balance changes on withdraw.
rule withdrawTokenChange(env e, uint256 assets, address receiver, address owner, address id) {
    address asset = asset();

    // Trick to require that all the following addresses are different.
    require asset == 0x11;
    require currentContract == 0x12;
    require receiver == 0x13;
    require id == 0x14;

    uint256 balanceMorphoBefore = ERC20.balanceOf(asset, id);
    uint256 balanceMetaMorphoBefore = ERC20.balanceOf(asset, currentContract);
    uint256 balanceReceiverBefore = ERC20.balanceOf(asset, receiver);
    withdraw(e, assets, receiver, owner);
    uint256 balanceMorphoAfter = ERC20.balanceOf(asset, id);
    uint256 balanceMetaMorphoAfter = ERC20.balanceOf(asset, currentContract);
    uint256 balanceReceiverAfter = ERC20.balanceOf(asset, receiver);

    require balanceMorphoBefore > balanceMorphoAfter;
    require balanceReceiverAfter > balanceReceiverBefore;

    assert assert_uint256(balanceMorphoBefore - balanceMorphoAfter) == assets;
    assert balanceMetaMorphoAfter == balanceMetaMorphoBefore;
    assert assert_uint256(balanceReceiverAfter - balanceReceiverBefore) == assets;
}

// Check that balances do not change on reallocate.
rule reallocateTokenChange(env e, MetaMorphoHarness.MarketAllocation[] allocations, address id) {
    address asset = asset();

    // Trick to require that all the following addresses are different.
    require id == 0x10;
    require asset == 0x11;
    require currentContract == 0x12;

    uint256 balanceMorphoBefore = ERC20.balanceOf(asset, id);
    uint256 balanceMetaMorphoBefore = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderBefore = ERC20.balanceOf(asset, e.msg.sender);
    reallocate(e, allocations);
    uint256 balanceMorphoAfter = ERC20.balanceOf(asset, id);
    uint256 balanceMetaMorphoAfter = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderAfter = ERC20.balanceOf(asset, e.msg.sender);

    assert balanceMetaMorphoAfter == balanceMetaMorphoBefore;
    assert balanceSenderAfter == balanceSenderBefore;
}
