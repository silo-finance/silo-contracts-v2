import "./ShareTokensCommonMethods.spec";

using ShareDebtToken0 as shareDebtToken0;
using ShareCollateralToken0 as shareCollateralToken0;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0;

methods {
    function shareProtectedCollateralToken0.totalSupply() external returns(uint256) envfree;
    function shareDebtToken0.totalSupply() external returns(uint256) envfree;
    function shareCollateralToken0.totalSupply() external returns(uint256) envfree;

    function shareProtectedCollateralToken0.balanceOf(address) external returns(uint256) envfree;
    function shareDebtToken0.balanceOf(address) external returns(uint256) envfree;
    function shareCollateralToken0.balanceOf(address) external returns(uint256) envfree;

    function shareProtectedCollateralToken0.hookReceiver() external returns(address) envfree;
    function shareDebtToken0.hookReceiver() external returns(address) envfree;
    function shareCollateralToken0.hookReceiver() external returns(address) envfree;

    function shareProtectedCollateralToken0.silo() external returns(address) envfree;
    function shareDebtToken0.silo() external returns(address) envfree;
    function shareCollateralToken0.silo() external returns(address) envfree;
}

// https://github.com/Certora/tutorials-code/blob/master/lesson4_invariants/erc20/total_supply.spec#L57
// Collateral token
ghost mapping(address => uint256) collateral0BalanceOfMirror {
    init_state axiom forall address a. collateral0BalanceOfMirror[a] == 0;
}

ghost mathint sumBalancesCollateral {
    init_state axiom sumBalancesCollateral == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesCollateral >= collateral0BalanceOfMirror[a] + collateral0BalanceOfMirror[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesCollateral >= collateral0BalanceOfMirror[a] + collateral0BalanceOfMirror[b] + collateral0BalanceOfMirror[c]
    );
}

hook Sstore shareCollateralToken0._balances[KEY address user] uint256 newBalance (uint256 oldBalance) {
    sumBalancesCollateral = sumBalancesCollateral + newBalance - oldBalance;
    collateral0BalanceOfMirror[user] = newBalance;
}

hook Sload uint256 balance shareCollateralToken0._balances[KEY address user] {
    require collateral0BalanceOfMirror[user] == balance;
    require sumBalancesCollateral >= to_mathint(collateral0BalanceOfMirror[user]);
}

// Protected collateral token
ghost mapping(address => uint256) protected0BalanceOfMirror {
    init_state axiom forall address a. protected0BalanceOfMirror[a] == 0;
}

ghost mathint sumBalancesProtected {
    init_state axiom sumBalancesProtected == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesProtected >= protected0BalanceOfMirror[a] + protected0BalanceOfMirror[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesProtected >= protected0BalanceOfMirror[a] + protected0BalanceOfMirror[b] + protected0BalanceOfMirror[c]
    );
}

hook Sstore shareProtectedCollateralToken0._balances[KEY address user] uint256 newBalance (uint256 oldBalance) {
    sumBalancesProtected = sumBalancesProtected + newBalance - oldBalance;
    protected0BalanceOfMirror[user] = newBalance;
}

hook Sload uint256 balance shareProtectedCollateralToken0._balances[KEY address user] {
    require protected0BalanceOfMirror[user] == balance;
    require sumBalancesProtected >= to_mathint(protected0BalanceOfMirror[user]);
}

// Debt token
ghost mapping(address => uint256) debt0BalanceOfMirror {
    init_state axiom forall address a. debt0BalanceOfMirror[a] == 0;
}

ghost mathint sumBalancesDebt {
    init_state axiom sumBalancesDebt == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesDebt >= debt0BalanceOfMirror[a] + debt0BalanceOfMirror[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesDebt >= debt0BalanceOfMirror[a] + debt0BalanceOfMirror[b] + debt0BalanceOfMirror[c]
    );
}

hook Sstore shareDebtToken0._balances[KEY address user] uint256 newBalance (uint256 oldBalance) {
    sumBalancesDebt = sumBalancesDebt + newBalance - oldBalance;
    debt0BalanceOfMirror[user] = newBalance;
}

hook Sload uint256 balance shareDebtToken0._balances[KEY address user] {
    require debt0BalanceOfMirror[user] == balance;
    require sumBalancesDebt >= to_mathint(debt0BalanceOfMirror[user]);
}

function requireProtectedToken0TotalAndBalancesIntegrity() {
    require to_mathint(shareProtectedCollateralToken0.totalSupply()) == sumBalancesProtected;
}

function requireDebtToken0TotalAndBalancesIntegrity() {
    require to_mathint(shareDebtToken0.totalSupply()) == sumBalancesDebt;
}

function requireCollateralToken0TotalAndBalancesIntegrity() {
    require to_mathint(shareCollateralToken0.totalSupply()) == sumBalancesCollateral;
}
