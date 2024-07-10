using ShareDebtToken1 as shareDebtToken1;
using ShareCollateralToken1 as shareCollateralToken1;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1;

methods {
    function shareProtectedCollateralToken1.totalSupply() external returns(uint256) envfree;
    function shareDebtToken1.totalSupply() external returns(uint256) envfree;
    function shareCollateralToken1.totalSupply() external returns(uint256) envfree;

    function shareProtectedCollateralToken1.balanceOf(address) external returns(uint256) envfree;
    function shareDebtToken1.balanceOf(address) external returns(uint256) envfree;
    function shareCollateralToken1.balanceOf(address) external returns(uint256) envfree;

    function shareProtectedCollateralToken1.hookReceiver() external returns(address) envfree;
    function shareDebtToken1.hookReceiver() external returns(address) envfree;
    function shareCollateralToken1.hookReceiver() external returns(address) envfree;

    function shareProtectedCollateralToken1.silo() external returns(address) envfree;
    function shareDebtToken1.silo() external returns(address) envfree;
    function shareCollateralToken1.silo() external returns(address) envfree;
}

// https://github.com/Certora/tutorials-code/blob/master/lesson4_invariants/erc20/total_supply.spec#L57
// Collateral token
ghost mapping(address => uint256) collateral1BalanceOfMirror {
    init_state axiom forall address a. collateral1BalanceOfMirror[a] == 0;
}

ghost mathint sumBalancesCollateral1 {
    init_state axiom sumBalancesCollateral1 == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesCollateral1 >= collateral1BalanceOfMirror[a] + collateral1BalanceOfMirror[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesCollateral1 >= collateral1BalanceOfMirror[a] + collateral1BalanceOfMirror[b] + collateral1BalanceOfMirror[c]
    );
}

hook Sstore shareCollateralToken1._balances[KEY address user] uint256 newBalance (uint256 oldBalance)  {
    sumBalancesCollateral1 = sumBalancesCollateral1 + newBalance - oldBalance;
    collateral1BalanceOfMirror[user] = newBalance;
}

hook Sload uint256 balance shareCollateralToken1._balances[KEY address user]  {
    require collateral1BalanceOfMirror[user] == balance;
    require sumBalancesCollateral1 >= to_mathint(collateral1BalanceOfMirror[user]);
}

// Protected collateral token
ghost mapping(address => uint256) protected1BalanceOfMirror {
    init_state axiom forall address a. protected1BalanceOfMirror[a] == 0;
}

ghost mathint sumBalancesProtected1 {
    init_state axiom sumBalancesProtected1 == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesProtected1 >= protected1BalanceOfMirror[a] + protected1BalanceOfMirror[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesProtected1 >= protected1BalanceOfMirror[a] + protected1BalanceOfMirror[b] + protected1BalanceOfMirror[c]
    );
}

hook Sstore shareProtectedCollateralToken1._balances[KEY address user] uint256 newBalance (uint256 oldBalance)  {
    sumBalancesProtected1 = sumBalancesProtected1 + newBalance - oldBalance;
    protected1BalanceOfMirror[user] = newBalance;
}

hook Sload uint256 balance shareProtectedCollateralToken1._balances[KEY address user]  {
    require protected1BalanceOfMirror[user] == balance;
    require sumBalancesProtected1 >= to_mathint(protected1BalanceOfMirror[user]);
}

// Debt token
ghost mapping(address => uint256) debt1BalanceOfMirror {
    init_state axiom forall address a. debt1BalanceOfMirror[a] == 0;
}

ghost mathint sumBalancesDebt1 {
    init_state axiom sumBalancesDebt1 == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesDebt1 >= debt1BalanceOfMirror[a] + debt1BalanceOfMirror[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesDebt1 >= debt1BalanceOfMirror[a] + debt1BalanceOfMirror[b] + debt1BalanceOfMirror[c]
    );
}

hook Sstore shareDebtToken1._balances[KEY address user] uint256 newBalance (uint256 oldBalance)  {
    sumBalancesDebt1 = sumBalancesDebt1 + newBalance - oldBalance;
    debt1BalanceOfMirror[user] = newBalance;
}

hook Sload uint256 balance shareDebtToken1._balances[KEY address user]  {
    require debt1BalanceOfMirror[user] == balance;
    require sumBalancesDebt1 >= to_mathint(debt1BalanceOfMirror[user]);
}

function requireProtectedToken1TotalAndBalancesIntegrity() {
    require to_mathint(shareProtectedCollateralToken1.totalSupply()) == sumBalancesProtected1;
}

function requireDebtToken1TotalAndBalancesIntegrity() {
    require to_mathint(shareDebtToken1.totalSupply()) == sumBalancesDebt1;
}

function requireCollateralToken1TotalAndBalancesIntegrity() {
    require to_mathint(shareCollateralToken1.totalSupply()) == sumBalancesCollateral1;
}