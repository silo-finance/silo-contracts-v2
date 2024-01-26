using Token1 as token1;

methods {
    function token1.balanceOf(address) external returns(uint256) envfree;
    function token1.totalSupply() external returns(uint256) envfree;
}

// https://github.com/Certora/tutorials-code/blob/master/lesson4_invariants/erc20/total_supply.spec#L57
ghost mapping(address => uint256) token1BalanceOfMirror {
    init_state axiom forall address a. token1BalanceOfMirror[a] == 0;
}

ghost mathint sumBalancesToken1 {
    init_state axiom sumBalancesToken1 == 0;
    axiom forall address a. forall address b. (
        (a != b => sumBalancesToken1 >= token1BalanceOfMirror[a] + token1BalanceOfMirror[b])
    );
    axiom forall address a. forall address b. forall address c. (
        (a != b && a != c && b != c) => 
        sumBalancesToken1 >= token1BalanceOfMirror[a] + token1BalanceOfMirror[b] + token1BalanceOfMirror[c]
    );
}

hook Sstore token1._balances[KEY address user] uint256 newBalance (uint256 oldBalance) STORAGE {
    sumBalancesToken1 = sumBalancesToken1 + newBalance - oldBalance;
    token1BalanceOfMirror[user] = newBalance;
}

hook Sload uint256 balance token1._balances[KEY address user] STORAGE {
    require token1BalanceOfMirror[user] == balance;
}

function requireToken1TotalAndBalancesIntegrity() {
    require to_mathint(token1.totalSupply()) == sumBalancesToken1;
}
