using LeverageUsingSiloFlashloanWithGeneralSwap as leverageContract;

methods {
    // ShareDebtTokenLike methods
    function balanceOf(address) external returns (uint256) envfree;
    function totalSupply() external returns (uint256) envfree;
    function receiveAllowance(address, address) external returns (uint256) envfree;
    function increaseReceiveAllowance(address, uint256) external;
    function mintFor(address, uint256) external;
    function setReceiveAllowance(address, address, uint256) external;

    // Leverage contract methods
    function leverageContract._ external => NONDET;
}

/// @title Rule: Only user or approved leverage contract can update user's debt token balance
/// @notice If a user gives an infinite receive approval of the Debt share token for a leverage smart contract,
///         only the user can update its Debt share token balance via leverage contract
rule onlyUserCanUpdateDebtBalanceViaLeverageContract(env e, method f, calldataarg args) {
    address user;
    address otherUser;
    address leverageContractAddr = leverageContract;

    // Setup: Different users
    require user != otherUser;
    require user != leverageContractAddr;
    require otherUser != leverageContractAddr;

    // Record initial state
    uint256 userBalanceBefore = balanceOf(user);
    uint256 otherUserBalanceBefore = balanceOf(otherUser);
    uint256 userReceiveAllowanceBefore = receiveAllowance(user, leverageContractAddr);

    // User gives infinite receive approval to leverage contract
    env e1;
    require e1.msg.sender == user;
    increaseReceiveAllowance(e1, user, max_uint256);

    // Someone else (not the user) calls a method on the leverage contract
    require e.msg.sender == otherUser;
    require f.contract == leverageContractAddr;

    f(e, args);

    // Check final state
    uint256 userBalanceAfter = balanceOf(user);
    uint256 otherUserBalanceAfter = balanceOf(otherUser);

    // Verify: user's balance should not change when someone else calls the leverage contract
    assert userBalanceAfter == userBalanceBefore, 
        "User's debt balance changed when someone else called leverage contract";
}

/// @title Rule: User can mint for themselves via leverage contract with approval
/// @notice Verifies that when a user has given receive approval to leverage contract,
///         the leverage contract can mint tokens for that user
rule leverageContractCanMintWithApproval(env e) {
    address user;
    address leverageContractAddr = leverageContract;
    uint256 mintAmount;

    require user != leverageContractAddr;
    require mintAmount > 0 && mintAmount < max_uint256;

    // Record initial state
    uint256 userBalanceBefore = balanceOf(user);

    // User gives receive approval to leverage contract
    env e1;
    require e1.msg.sender == user;
    increaseReceiveAllowance(e1, user, mintAmount);

    // Leverage contract mints for user
    env e2;
    require e2.msg.sender == leverageContractAddr;
    mintFor(e2, user, mintAmount);

    // Check final state
    uint256 userBalanceAfter = balanceOf(user);

    // Verify: user's balance increased by mint amount
    assert userBalanceAfter == userBalanceBefore + mintAmount,
        "User's balance did not increase correctly after mint";
}

/// @title Rule: Cannot mint without sufficient receive approval
/// @notice Verifies that minting fails when there's insufficient receive approval
rule cannotMintWithoutApproval(env e) {
    address user;
    address spender;
    uint256 mintAmount;

    require user != spender;
    require mintAmount > 0;

    // Ensure no pre-existing approval
    require receiveAllowance(user, spender) == 0;

    // Try to mint without approval
    require e.msg.sender == spender;
    mintFor@withrevert(e, user, mintAmount);

    // Verify: mint should revert
    assert lastReverted,
        "Mint succeeded without receive approval";
}

/// @title Rule: Receive allowance can only be modified by authorized actions
/// @notice Verifies that receive allowance changes only through proper channels
/// @dev This rule is useful for debugging
rule receiveAllowanceOnlyModifiedByAuthorizedActions(env e, method f, calldataarg args, address user, address spender)
    filtered { f -> !f.isView }
{

    uint256 allowanceBefore = receiveAllowance(user, spender);

    f(e, args);

    uint256 allowanceAfter = receiveAllowance(user, spender);

    // If allowance changed, it must be through one of these authorized actions
    assert allowanceAfter != allowanceBefore =>
        (f.selector == sig:increaseReceiveAllowance(address, uint256).selector && e.msg.sender == user) ||
        (f.selector == sig:setReceiveAllowance(address, address, uint256).selector) ||
        (f.selector == sig:mintFor(address, uint256).selector && e.msg.sender == spender);
}
